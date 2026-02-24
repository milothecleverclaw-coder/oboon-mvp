#!/bin/bash
# run-loadtest.sh
# Orchestrates load testing with N concurrent video calls
#
# Usage:
#   ./run-loadtest.sh --calls <number> [--video <path>] [--duration <seconds>] [--build-video]

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

check_vm() {
    log "Checking VM connectivity..."
    if ! ssh_vm "echo ok" &>/dev/null; then
        fatal "Cannot SSH to VM at $VM_IP"
    fi
    success "VM reachable"
}

setup_vm() {
    log "Setting up VM environment..."
    ssh_vm bash <<'ENDSSH'
        set -euo pipefail
        cd /root
        export PATH="$HOME/.local/bin:$PATH"
        if [[ -d "oboon-mvp" ]]; then
            cd oboon-mvp && git fetch --all >/dev/null 2>&1 && git reset --hard origin/main >/dev/null 2>&1
        else
            git clone https://github.com/milothecleverclaw-coder/oboon-mvp.git
            cd oboon-mvp
        fi
        if [[ ! -d "venv" ]]; then python3 -m venv venv; fi
        source venv/bin/activate
        pip install -q --upgrade pip
        pip install -q livekit livekit-agents livekit-api modal Pillow opencv-python-headless numpy huggingface_hub kaggle
ENDSSH
    success "VM environment set up"
}

deploy_modal() {
    log "Deploying Modal GPU worker..."
    local tid=$(bw get item "Modal" --session "$(bw unlock --raw "y3&tHVAg0s%70")" 2>/dev/null | jq -r '.login.username' 2>/dev/null || echo "")
    local tsec=$(bw get item "Modal" --session "$(bw unlock --raw "y3&tHVAg0s%70")" 2>/dev/null | jq -r '.login.password' 2>/dev/null || echo "")
    ssh_vm bash <<ENDSSH
        set -euo pipefail
        cd /root/oboon-mvp
        source venv/bin/activate
        if [[ -n "$tid" ]]; then modal token new --token-id "$tid" --token-secret "$tsec" 2>/dev/null || true; fi
        python -m modal deploy modal_gpu_worker.py
ENDSSH
    success "Modal GPU worker deployed"
}

build_video() {
    if [[ "$BUILD_VIDEO" != "true" ]]; then return; fi
    log "Fetching dataset credentials..."
    local hft=$(bw get item "Hugging Face API" --session "$(bw unlock --raw "y3&tHVAg0s%70")" 2>/dev/null | jq -r '.login.password' 2>/dev/null || echo "")
    local ku="pandavirtual"
    local kk="KGAT_239e9640075c8b85d10beaef0f252cfb"
    log "Building test video on VM..."
    ssh_vm HF_TOKEN="$hft" KAGGLE_USER="$ku" KAGGLE_KEY="$kk" bash <<'ENDSSH'
        set -euo pipefail
        cd /root/oboon-mvp
        bash scripts/build-test-video.sh --output test_video.mp4 --count 20
ENDSSH
    success "Test video built"
}

run_load_test() {
    log "Preparing Load Test for $CALLS concurrent calls..."
    local lk_url=$(jq -r '.livekit_url' "$STATE_FILE")
    local lk_key=$(jq -r '.api_key' "$STATE_FILE")
    local lk_secret=$(jq -r '.api_secret' "$STATE_FILE")
    if [[ -n "$VIDEO_PATH" ]]; then
        log "Uploading custom video..."
        scp_to_vm "$VIDEO_PATH" "$REPO_DIR/test_video.mp4"
    fi
    ssh_vm bash << ENDSSH
        set -euo pipefail
        cd /root/oboon-mvp
        source venv/bin/activate
        export PATH="\$HOME/.local/bin:\$PATH"
        export LIVEKIT_URL="$lk_url"
        export LIVEKIT_API_KEY="$lk_key"
        export LIVEKIT_API_SECRET="$lk_secret"
        export SAMPLE_EVERY="$SAMPLE_EVERY"
        pkill -f "agent_server.py" 2>/dev/null || true
        pkill -f "lk room join" 2>/dev/null || true
        rm -f /tmp/nsfw_results.jsonl
        sleep 2
        if [[ ! -f "test_video.h264" ]]; then
            ffmpeg -y -i test_video.mp4 -vcodec copy -bsf:v h264_mp4toannexb test_video.h264 2>/dev/null
        fi
        AGENT_COUNT=\$(( ($CALLS + 9) / 10 ))
        if [[ \$AGENT_COUNT -gt 8 ]]; then AGENT_COUNT=8; fi
        echo "Starting \$AGENT_COUNT Agent Worker processes..."
        for i in \$(seq 1 \$AGENT_COUNT); do
            export AGENT_PORT="\$((8080 + i))"
            python agent_server.py start --url "\$LIVEKIT_URL" --api-key "\$LIVEKIT_API_KEY" --api-secret "\$LIVEKIT_API_SECRET" > "agent_\$i.log" 2>&1 &
            sleep 2
        done
        sleep 5
        echo "Starting $CALLS concurrent video publishers..."
        for i in \$(seq 1 $CALLS); do
            lk room join "\$LIVEKIT_URL" --api-key "\$LIVEKIT_API_KEY" --api-secret "\$LIVEKIT_API_SECRET" --room "nsfw-loadtest-\$i" --identity "publisher-\$i" --publish test_video.h264 --fps 30 > /dev/null 2>&1 &
        done
        echo "Waiting for processing ($TEST_DURATION seconds)..."
        sleep "$TEST_DURATION"
        pkill -f "lk room join" 2>/dev/null || true
        sleep 2
        pkill -f "agent_server.py" 2>/dev/null || true
ENDSSH
    success "Load test execution finished"
}

fetch_results() {
    log "Analyzing load test results..."
    ssh_vm "cat /tmp/nsfw_results.jsonl 2>/dev/null || echo ''" > /tmp/nsfw_loadtest_results.jsonl
    echo ""
    echo -e "${BOLD}=== Load Test Summary ===${NC}"
    echo -e "Target Calls:      ${CALLS}"
    python3 scripts/analyze_results.py
}

main() {
    echo -e "${BOLD}=== Scaling Test: $CALLS Calls ===${NC}"
    resolve_ssh_key
    load_state
    check_vm
    setup_vm
    build_video
    deploy_modal
    run_load_test
    fetch_results
}

main
