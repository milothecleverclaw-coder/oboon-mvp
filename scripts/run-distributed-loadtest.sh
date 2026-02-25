#!/bin/bash
# run-distributed-loadtest.sh
# Orchestrates load testing with N concurrent video calls using a 2-VM architecture.
#
# Usage:
#   ./run-distributed-loadtest.sh --calls <number> [--duration <seconds>] [--build-video]
#
# Prerequisites:
#   1. Server VM running LiveKit (created via create-resources.sh)
#   2. Client VM (created via create-client-vm.sh)

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# ── Config ────────────────────────────────────────────────────────────────────
SERVER_STATE_FILE="$HOME/.openclaw/workspace/oboon/.vm-state.json"
CLIENT_STATE_FILE="$HOME/.openclaw/workspace/oboon/.client-vm-state.json"
SSH_KEY=""
CLIENT_IP=""
CALLS=100
TEST_DURATION=60
SAMPLE_EVERY=2
BUILD_VIDEO=false

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --calls)       CALLS="$2"; shift 2 ;;
        --duration)    TEST_DURATION="$2"; shift 2 ;;
        --build-video) BUILD_VIDEO=true; shift ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

log()     { echo -e "${BLUE}▶ $*${NC}"; }
success() { echo -e "${GREEN}✓ $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $*${NC}"; }
fatal()   { echo -e "${RED}✗ $*${NC}"; exit 1; }

ssh_client() {
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "root@$CLIENT_IP" "$@"
}

# ── Initialization ────────────────────────────────────────────────────────────
resolve_ssh_key() {
    local candidates=("/home/node/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa")
    for key in "${candidates[@]}"; do
        if [[ -f "$key" ]]; then SSH_KEY="$key"; return; fi
    done
    fatal "No SSH key found"
}

export BW_SESSION=$(bw unlock --raw "y3&tHVAg0s%70" 2>/dev/null || echo "")

load_state() {
    if [[ ! -f "$SERVER_STATE_FILE" ]]; then fatal "Server state file not found: $SERVER_STATE_FILE. Run create-resources.sh first."; fi
    if [[ ! -f "$CLIENT_STATE_FILE" ]]; then fatal "Client state file not found: $CLIENT_STATE_FILE. Run create-client-vm.sh first."; fi
    
    CLIENT_IP=$(jq -r '.vm_ip' "$CLIENT_STATE_FILE")
    success "Client VM IP: $CLIENT_IP"
}

setup_client_env() {
    log "Setting up Client VM environment..."
    ssh_client bash <<'ENDSSH'
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
    success "Client VM environment set up"
}

build_video() {
    if [[ "$BUILD_VIDEO" != "true" ]]; then return; fi
    log "Fetching dataset credentials..."
    local hft=$(bw get item "Hugging Face API" --session "$BW_SESSION" 2>/dev/null | jq -r '.login.password' 2>/dev/null || echo "")
    local ku="pandavirtual"
    local kk="KGAT_239e9640075c8b85d10beaef0f252cfb"
    
    log "Building test video on Client VM (this takes time)..."
    ssh_client HF_TOKEN="$hft" KAGGLE_USER="$ku" KAGGLE_KEY="$kk" bash <<'ENDSSH'
        set -euo pipefail
        cd /root/oboon-mvp
        bash scripts/build-test-video.sh --output test_video.mp4 --count 20
ENDSSH
    success "Test video built on Client"
}

deploy_modal() {
    log "Deploying Modal GPU worker from Client VM..."
    local tid=$(bw get item "Modal" --session "$BW_SESSION" 2>/dev/null | jq -r '.login.username' 2>/dev/null || echo "")
    local tsec=$(bw get item "Modal" --session "$BW_SESSION" 2>/dev/null | jq -r '.login.password' 2>/dev/null || echo "")
    ssh_client bash <<ENDSSH
        set -euo pipefail
        cd /root/oboon-mvp
        source venv/bin/activate
        if [[ -n "$tid" ]]; then python -m modal token set --token-id "$tid" --token-secret "$tsec" >/dev/null 2>&1 || true; fi
        python -m modal deploy modal_gpu_worker.py
ENDSSH
    success "Modal GPU worker deployed"
}

run_load_test() {
    log "Preparing Distributed Load Test for $CALLS concurrent calls..."
    local lk_url=$(jq -r '.livekit_url' "$SERVER_STATE_FILE")
    local lk_key=$(jq -r '.api_key' "$SERVER_STATE_FILE")
    local lk_secret=$(jq -r '.api_secret' "$SERVER_STATE_FILE")

    log "Target LiveKit Server: $lk_url"

    ssh_client bash << ENDSSH
        set -euo pipefail
        cd /root/oboon-mvp
        source venv/bin/activate
        export PATH="\$HOME/.local/bin:\$PATH"
        export LIVEKIT_URL="$lk_url"
        export LIVEKIT_API_KEY="$lk_key"
        export LIVEKIT_API_SECRET="$lk_secret"
        export SAMPLE_EVERY="$SAMPLE_EVERY"
        
        echo "Cleaning up old processes on Client..."
        pkill -f "agent_server.py" 2>/dev/null || true
        pkill -f "lk room join" 2>/dev/null || true
        rm -f /tmp/nsfw_results.jsonl
        sleep 2
        
        if [[ ! -f "test_video.h264" ]]; then
            ffmpeg -y -i test_video.mp4 -vcodec copy -bsf:v h264_mp4toannexb test_video.h264 2>/dev/null
        fi
        
        # 1 Agent per 10 calls
        AGENT_COUNT=\$(( ($CALLS + 9) / 10 ))
        if [[ \$AGENT_COUNT -gt 50 ]]; then AGENT_COUNT=50; fi
        
        echo "Starting \$AGENT_COUNT Agent Worker processes on Client..."
        for i in \$(seq 1 \$AGENT_COUNT); do
            export AGENT_PORT="\$((8080 + i))"
            python agent_server.py start --url "\$LIVEKIT_URL" --api-key "\$LIVEKIT_API_KEY" --api-secret "\$LIVEKIT_API_SECRET" > "agent_\$i.log" 2>&1 &
            sleep 1
        done
        sleep 5
        
        echo "Starting $CALLS concurrent video publishers on Client..."
        for i in \$(seq 1 $CALLS); do
            lk room join "\$LIVEKIT_URL" --api-key "\$LIVEKIT_API_KEY" --api-secret "\$LIVEKIT_API_SECRET" --room "nsfw-loadtest-\$i" --identity "publisher-\$i" --publish test_video.h264 --fps 30 > "pub_\$i.log" 2>&1 &
        done
        
        echo "Waiting for processing ($TEST_DURATION seconds)..."
        sleep "$TEST_DURATION"
        
        pkill -f "lk room join" 2>/dev/null || true
        sleep 2
        pkill -f "agent_server.py" 2>/dev/null || true
ENDSSH
    success "Distributed Load test execution finished"
}

fetch_results() {
    log "Analyzing load test results from Client VM..."
    ssh_client "cat /tmp/nsfw_results.jsonl 2>/dev/null || echo ''" > /tmp/nsfw_loadtest_results.jsonl
    echo ""
    echo -e "${BOLD}=== Distributed Load Test Summary ===${NC}"
    echo -e "Target Calls:      ${CALLS}"
    python3 scripts/analyze_results.py
}

main() {
    echo -e "${BOLD}=== DISTRIBUTED Scaling Test: $CALLS Calls ===${NC}"
    resolve_ssh_key
    load_state
    setup_client_env
    build_video
    deploy_modal
    run_load_test
    fetch_results
}

main
