#!/bin/bash
# run-pipeline.sh
# Runs the full NSFW detection pipeline on the Hetzner VM
#
# Usage:
#   ./run-pipeline.sh [--video <path>] [--duration <seconds>] [--build-video]
#
# Prerequisites:
#   - VM created with create-resources.sh
#   - State file at ~/.openclaw/workspace/oboon/.vm-state.json

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# ── Config ────────────────────────────────────────────────────────────────────
STATE_FILE="$HOME/.openclaw/workspace/oboon/.vm-state.json"
REPO_URL="https://github.com/milothecleverclaw-coder/oboon-mvp.git"
REPO_DIR="/root/oboon-mvp"
SSH_KEY=""
VM_IP=""
VIDEO_PATH=""
TEST_DURATION=20
BUILD_VIDEO=false

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --video) VIDEO_PATH="$2"; shift 2 ;;
        --duration) TEST_DURATION="$2"; shift 2 ;;
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

# ── Resolve SSH key ───────────────────────────────────────────────────────────
resolve_ssh_key() {
    local candidates=(
        "/home/node/.ssh/id_ed25519"
        "$HOME/.ssh/id_ed25519"
        "$HOME/.ssh/id_rsa"
    )
    for key in "${candidates[@]}"; do
        if [[ -f "$key" ]]; then
            SSH_KEY="$key"
            return
        fi
    done
    fatal "No SSH key found"
}

# ── Load state ────────────────────────────────────────────────────────────────
load_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        fatal "State file not found: $STATE_FILE\nRun: ./scripts/create-resources.sh --calls 50"
    fi
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

# ── Setup VM environment ──────────────────────────────────────────────────────
setup_vm() {
    log "Setting up VM environment..."

    ssh_vm bash <<'ENDSSH'
        set -euo pipefail
        cd /root

        # Ensure lk CLI is in PATH
        export PATH="$HOME/.local/bin:$PATH"

        if [[ -d "oboon-mvp" ]]; then
            cd oboon-mvp && git pull
        else
            git clone https://github.com/milothecleverclaw-coder/oboon-mvp.git
            cd oboon-mvp
        fi

        if [[ ! -d "venv" ]]; then
            python3 -m venv venv
        fi

        source venv/bin/activate
        pip install -q --upgrade pip
        pip install -q livekit livekit-agents livekit-api modal Pillow opencv-python-headless numpy huggingface_hub kaggle
        echo "✓ Environment ready"
ENDSSH
    success "VM environment set up"
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

# ── Upload test video (if provided) ───────────────────────────────────────────
upload_video() {
    if [[ -n "$VIDEO_PATH" ]]; then
        if [[ ! -f "$VIDEO_PATH" ]]; then
            fatal "Video file not found: $VIDEO_PATH"
        fi
        log "Uploading provided test video..."
        scp_to_vm "$VIDEO_PATH" "$REPO_DIR/test_video.mp4"
        success "Video uploaded"
    elif ssh_vm "test -f $REPO_DIR/test_video.mp4" 2>/dev/null; then
        log "Using pre-built test video on VM..."
    else
        warn "No test video found, fallback to lk load-test"
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

# ── Run pipeline test ─────────────────────────────────────────────────────────
run_test() {
    log "Running NSFW detection pipeline..."
    local lk_url lk_key lk_secret
    lk_url=$(jq -r '.livekit_url' "$STATE_FILE")
    lk_key=$(jq -r '.api_key' "$STATE_FILE")
    lk_secret=$(jq -r '.api_secret' "$STATE_FILE")

    local modal_token_id modal_token_secret
    modal_token_id=$(bw get item "Modal" --session "$(bw unlock --raw "y3&tHVAg0s%70")" 2>/dev/null | jq -r '.login.username' 2>/dev/null || echo "")
    modal_token_secret=$(bw get item "Modal" --session "$(bw unlock --raw "y3&tHVAg0s%70")" 2>/dev/null | jq -r '.login.password' 2>/dev/null || echo "")

    ssh_vm bash << ENDSSH
        set -euo pipefail
        cd /root/oboon-mvp
        source venv/bin/activate
        export PATH="\$HOME/.local/bin:\$PATH"
        export LIVEKIT_URL="$lk_url"
        export LIVEKIT_API_KEY="$lk_key"
        export LIVEKIT_API_SECRET="$lk_secret"
        export MODAL_TOKEN_ID="$modal_token_id"
        export MODAL_TOKEN_SECRET="$modal_token_secret"
        export TEST_DURATION="${TEST_DURATION}"
        export SAMPLE_EVERY="2"

        echo "Cleaning up old processes..."
        pkill -f "agent_server.py" 2>/dev/null || true
        fuser -k 8081/tcp 2>/dev/null || true
        rm -f /tmp/nsfw_results.jsonl

        echo "Starting agent server..."
        python agent_server.py start --url "\$LIVEKIT_URL" --api-key "\$LIVEKIT_API_KEY" --api-secret "\$LIVEKIT_API_SECRET" > agent.log 2>&1 &
        AGENT_PID=\$!
        sleep 5

        if [[ -f "test_video.mp4" ]]; then
            echo "Converting custom video to H264..."
            ffmpeg -y -i test_video.mp4 -vcodec copy -bsf:v h264_mp4toannexb test_stream.h264 2>/dev/null
            echo "Publishing custom test video..."
            lk room join "\$LIVEKIT_URL" --api-key "\$LIVEKIT_API_KEY" --api-secret "\$LIVEKIT_API_SECRET" --room nsfw-test --identity clean-publisher --publish test_stream.h264 > publish.log 2>&1 &
            PUBLISH_PID=\$!
        else
            echo "No custom video found, using load-test..."
            lk load-test --url "\$LIVEKIT_URL" --api-key "\$LIVEKIT_API_KEY" --api-secret "\$LIVEKIT_API_SECRET" --room nsfw-test --video-publishers 1 --duration "\${TEST_DURATION}s" > publish.log 2>&1 &
            PUBLISH_PID=\$!
        fi

        echo "Waiting for processing (\${TEST_DURATION}s)..."
        sleep "\$TEST_DURATION"
        kill \$PUBLISH_PID 2>/dev/null || true
        sleep 5
        kill \$AGENT_PID 2>/dev/null || true
ENDSSH
    success "Pipeline test completed"
}

# ── Fetch results ─────────────────────────────────────────────────────────────
fetch_results() {
    log "Fetching results..."
    ssh_vm "cat /tmp/nsfw_results.jsonl 2>/dev/null || echo 'No results'" > /tmp/nsfw_results_local.jsonl
    if [[ -s /tmp/nsfw_results_local.jsonl && $(cat /tmp/nsfw_results_local.jsonl) != "No results" ]]; then
        echo ""
        echo -e "${BOLD}${GREEN}=== Detection Results ===${NC}"
        cat /tmp/nsfw_results_local.jsonl | jq -c '{frame: .frame, nsfw: .is_nsfw, score: .score, detections: [.detections[]?.class]}' 2>/dev/null || cat /tmp/nsfw_results_local.jsonl
        local nsfw_count=$(grep -c '"is_nsfw": true' /tmp/nsfw_results_local.jsonl 2>/dev/null || echo "0")
        local total_count=$(wc -l < /tmp/nsfw_results_local.jsonl)
        echo ""
        echo -e "${BOLD}Summary:${NC} $total_count samples analyzed, $nsfw_count NSFW detections"
    else
        warn "No results captured"
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}=== NSFW Pipeline Test ===${NC}"
    echo ""
    resolve_ssh_key
    load_state
    check_vm
    setup_vm
    build_video
    upload_video
    deploy_modal
    run_test
    fetch_results
    echo ""
    echo -e "${GREEN}=== Complete ===${NC}"
}

main
