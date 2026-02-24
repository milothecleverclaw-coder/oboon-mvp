#!/bin/bash
# run-loadtest.sh
# Orchestrates load testing with N concurrent video calls
#
# Usage:
#   ./run-loadtest.sh --calls <number> [--video <path>] [--duration <seconds>]
#
# Prerequisites:
#   - VM created with create-resources.sh --calls <number>
#   - test_video.h264 already built (via build-test-video.sh or run-pipeline.sh)

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# ── Config ────────────────────────────────────────────────────────────────────
STATE_FILE="$HOME/.openclaw/workspace/oboon/.vm-state.json"
REPO_DIR="/root/oboon-mvp"
SSH_KEY=""
VM_IP=""
CALLS=2
TEST_DURATION=60
SAMPLE_EVERY=2
VIDEO_PATH=""

BUILD_VIDEO=false

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --calls)    CALLS="$2"; shift 2 ;;
        --duration) TEST_DURATION="$2"; shift 2 ;;
        --video)    VIDEO_PATH="$2"; shift 2 ;;
        --build-video) BUILD_VIDEO=true; shift ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
log()     { echo -e "${BLUE}▶ $*${NC}"; }
success() { echo -e "${GREEN}✓ $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $*${NC}"; }
error()   { echo -e "${RED}✗ $*${NC}"; }
fatal()   { error "$*"; exit 1; }

ssh_vm() {
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "root@$VM_IP" "$@"
}
scp_to_vm() {
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no "$1" "root@$VM_IP:$2"
}

# ── Initialization ────────────────────────────────────────────────────────────
resolve_ssh_key() {
    local candidates=("/home/node/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa")
    for key in "${candidates[@]}"; do
        if [[ -f "$key" ]]; then SSH_KEY="$key"; return; fi
    done
    fatal "No SSH key found"
}

load_state() {
    if [[ ! -f "$STATE_FILE" ]]; then fatal "State file not found: $STATE_FILE"; fi
    VM_IP=$(jq -r '.vm_ip' "$STATE_FILE")
    success "VM IP: $VM_IP"
}

# ── Check VM connectivity ─────────────────────────────────────────────────────
check_vm() {
    log "Checking VM connectivity..."
    if ! ssh_vm "echo ok" &>/dev/null; then
        fatal "Cannot SSH to VM at $VM_IP"
    fi
    success "VM reachable"
}

# ── Build test video on VM ────────────────────────────────────────────────────
build_video() {
    if [[ "$BUILD_VIDEO" != "true" ]]; then
        return
    fi
    
    log "Fetching dataset credentials..."
    local hf_token kaggle_user kaggle_key
    hf_token=$(bw get item "Hugging Face API" --session "$(bw unlock --raw "y3&tHVAg0s%70")" 2>/dev/null | jq -r '.login.password' 2>/dev/null || echo "")
    kaggle_user="pandavirtual"
    kaggle_key="KGAT_239e9640075c8b85d10beaef0f252cfb"
    
    log "Building test video on VM (this takes time)..."
    ssh_vm HF_TOKEN="$hf_token" KAGGLE_USER="$kaggle_user" KAGGLE_KEY="$kaggle_key" bash <<'ENDSSH'
        set -euo pipefail
        cd /root/oboon-mvp
        bash scripts/build-test-video.sh --output test_video.mp4 --count 20
ENDSSH
    success "Test video built"
}

# ── Run Load Test ─────────────────────────────────────────────────────────────
run_load_test() {
    log "Preparing Load Test for $CALLS concurrent calls..."
    build_video
    
    local lk_url=$(jq -r '.livekit_url' "$STATE_FILE")
    local lk_key=$(jq -r '.api_key' "$STATE_FILE")
    local lk_secret=$(jq -r '.api_secret' "$STATE_FILE")

    local modal_token_id=$(bw get item "Modal" --session "$(bw unlock --raw "y3&tHVAg0s%70")" 2>/dev/null | jq -r '.login.username' 2>/dev/null || echo "")
    local modal_token_secret=$(bw get item "Modal" --session "$(bw unlock --raw "y3&tHVAg0s%70")" 2>/dev/null | jq -r '.login.password' 2>/dev/null || echo "")

    if [[ -n "$VIDEO_PATH" ]]; then
        log "Uploading custom video for load test..."
        scp_to_vm "$VIDEO_PATH" "$REPO_DIR/test_video.mp4"
    fi

    log "Executing load test orchestration on VM..."
    ssh_vm bash << ENDSSH
        set -euo pipefail
        cd /root/oboon-mvp
        git fetch --all >/dev/null 2>&1 || true
        git reset --hard origin/main >/dev/null 2>&1 || true
        source venv/bin/activate
        export PATH="\$HOME/.local/bin:\$PATH"
        export LIVEKIT_URL="$lk_url"
        export LIVEKIT_API_KEY="$lk_key"
        export LIVEKIT_API_SECRET="$lk_secret"
        export MODAL_TOKEN_ID="$modal_token_id"
        export MODAL_TOKEN_SECRET="$modal_token_secret"
        export SAMPLE_EVERY="$SAMPLE_EVERY"
        
        # 1. Clean up old runs
        echo "Cleaning up old processes..."
        pkill -f "agent_server.py" 2>/dev/null || true
        pkill -f "lk room join" 2>/dev/null || true
        fuser -k 8081/tcp 2>/dev/null || true
        rm -f /tmp/nsfw_results.jsonl
        sleep 2
        
        # 2. Check for test video
        if [[ ! -f "test_video.h264" ]]; then
            if [[ -f "test_video.mp4" ]]; then
                echo "Converting test_video.mp4 to h264..."
                ffmpeg -y -i test_video.mp4 -vcodec copy -bsf:v h264_mp4toannexb test_video.h264 2>/dev/null
            else
                echo "No test_video.mp4 found! Run build-test-video.sh first."
                exit 1
            fi
        fi

        # 3. Calculate how many agent processes to spawn (1 agent per 10 calls to spread CPU load for cv2 decode)
        AGENT_COUNT=\$(( ($CALLS + 9) / 10 ))
        if [[ \$AGENT_COUNT -gt 8 ]]; then AGENT_COUNT=8; fi # Cap at 8 workers for now
        
        echo "Starting \$AGENT_COUNT Agent Worker processes..."
        for i in \$(seq 1 \$AGENT_COUNT); do
            PORT=\$((8080 + i))
            export AGENT_PORT="\$PORT"
            python agent_server.py start --url "\$LIVEKIT_URL" --api-key "\$LIVEKIT_API_KEY" --api-secret "\$LIVEKIT_API_SECRET" > "agent_\$i.log" 2>&1 &
            sleep 2 # Stagger startup to avoid hammering the CPU and hitting the 10s init timeout
        done
        sleep 5
        
        # 4. Start concurrent publishers
        echo "Starting $CALLS concurrent video publishers..."
        for i in \$(seq 1 $CALLS); do
            # Use lk room join in background for each room
            lk room join "\$LIVEKIT_URL" \\
                --api-key "\$LIVEKIT_API_KEY" \\
                --api-secret "\$LIVEKIT_API_SECRET" \\
                --room "nsfw-loadtest-\$i" \\
                --identity "publisher-\$i" \\
                --publish test_video.h264 \\
                --fps 30 > /dev/null 2>&1 &
        done
        
        echo "Waiting for processing ($TEST_DURATION seconds)..."
        sleep "$TEST_DURATION"
        
        # 5. Cleanup
        echo "Tearing down load test..."
        pkill -f "lk room join" 2>/dev/null || true
        sleep 2
        pkill -f "agent_server.py" 2>/dev/null || true
        
        echo "Done."
ENDSSH
    success "Load test execution finished"
}

# ── Fetch results ─────────────────────────────────────────────────────────────
fetch_results() {
    log "Analyzing load test results..."
    ssh_vm "cat /tmp/nsfw_results.jsonl 2>/dev/null || echo ''" > /tmp/nsfw_loadtest_results.jsonl
    
    local total_count=$(wc -l < /tmp/nsfw_loadtest_results.jsonl)
    local nsfw_count=$(grep -c '"is_nsfw": true' /tmp/nsfw_loadtest_results.jsonl 2>/dev/null || echo "0")
    
    # Extract unique rooms processed
    local rooms_processed=$(jq -r '.room_id' /tmp/nsfw_loadtest_results.jsonl 2>/dev/null | sort -u | wc -l || echo "0")
    
    echo ""
    echo -e "${BOLD}=== Load Test Summary ===${NC}"
    echo -e "Target Calls:      ${CALLS}"
    
    python3 scripts/analyze_results.py
    
    if [[ "$rooms_processed" -lt "$CALLS" ]]; then
        warn "Only $rooms_processed out of $CALLS rooms logged results!"
    else
        success "All $CALLS rooms processed successfully!"
    fi
}

# ── Deploy Modal GPU worker ───────────────────────────────────────────────────
deploy_modal() {
    log "Deploying Modal GPU worker..."
    local modal_token_id modal_token_secret
    modal_token_id=$(bw get item "Modal" --session "$(bw unlock --raw "y3&tHVAg0s%70")" 2>/dev/null | jq -r '.login.username' 2>/dev/null || echo "")
    modal_token_secret=$(bw get item "Modal" --session "$(bw unlock --raw "y3&tHVAg0s%70")" 2>/dev/null | jq -r '.login.password' 2>/dev/null || echo "")

    ssh_vm MODAL_TOKEN_ID="$modal_token_id" MODAL_TOKEN_SECRET="$modal_token_secret" bash <<'ENDSSH'
        set -euo pipefail
        cd /root/oboon-mvp
        source venv/bin/activate
        if [[ -n "$MODAL_TOKEN_ID" ]]; then
            modal token new --token-id "$MODAL_TOKEN_ID" --token-secret "$MODAL_TOKEN_SECRET" 2>/dev/null || true
        fi
        python -m modal deploy modal_gpu_worker.py
ENDSSH
    success "Modal GPU worker deployed"
}

main() {
    echo -e "${BOLD}=== Scaling Test: $CALLS Calls ===${NC}"
    resolve_ssh_key
    load_state
    check_vm
    deploy_modal
    run_load_test
    fetch_results
}

main
