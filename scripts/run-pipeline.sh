#!/bin/bash
# run-pipeline.sh
# Runs the full NSFW detection pipeline on the Hetzner VM
#
# Usage:
#   ./run-pipeline.sh [--video <path>]
#
# Prerequisites:
#   - VM created with create-resources.sh
#   - State file at ~/.openclaw/workspace/oboon/.vm-state.json
#
# This script will:
#   1. SSH into VM
#   2. Clone/update oboon-mvp repo
#   3. Set up Python venv with all dependencies
#   4. Deploy Modal GPU worker
#   5. Run agent + publish test video
#   6. Fetch results

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

        # Ensure lk CLI is in PATH (installed by create-resources.sh)
        export PATH="$HOME/.local/bin:$PATH"

        # Clone or update repo
        if [[ -d "oboon-mvp" ]]; then
            echo "Updating existing repo..."
            cd oboon-mvp && git pull
        else
            echo "Cloning repo..."
            git clone https://github.com/milothecleverclaw-coder/oboon-mvp.git
            cd oboon-mvp
        fi

        # Create venv if needed
        if [[ ! -d "venv" ]]; then
            echo "Creating Python venv..."
            python3 -m venv venv
        fi

        # Install dependencies
        echo "Installing Python dependencies..."
        source venv/bin/activate
        pip install -q --upgrade pip
        pip install -q livekit livekit-agents livekit-api modal Pillow opencv-python-headless numpy

        echo "✓ Environment ready"
ENDSSH

    success "VM environment set up"
}

# ── Build test video on VM ────────────────────────────────────────────────────
build_video() {
    if [[ "$BUILD_VIDEO" != "true" ]]; then
        return
    fi
    
    log "Building test video on VM..."
    ssh_vm bash <<'ENDSSH'
        set -euo pipefail
        cd /root/oboon-mvp
        
        # Run build-test-video.sh if it exists
        if [[ -f "scripts/build-test-video.sh" ]]; then
            bash scripts/build-test-video.sh --output test_video.mp4 --duration 10
        else
            echo "build-test-video.sh not found, generating synthetic video..."
            ffmpeg -y -f lavfi -i "testsrc=duration=10:size=640x480:rate=30" \
                -c:v libx264 -preset fast -pix_fmt yuv420p test_video.mp4 2>/dev/null
        fi
ENDSSH
    
    success "Test video built"
}

# ── Upload test video (if provided) ───────────────────────────────────────────
upload_video() {
    if [[ -n "$VIDEO_PATH" ]]; then
        # Option 1: User provided a video file
        if [[ ! -f "$VIDEO_PATH" ]]; then
            fatal "Video file not found: $VIDEO_PATH"
        fi
        log "Uploading provided test video..."
        scp_to_vm "$VIDEO_PATH" "$REPO_DIR/test_video.mp4"
        success "Video uploaded"
    elif ssh_vm "test -f $REPO_DIR/test_video.mp4" 2>/dev/null; then
        # Option 2: Pre-built test video exists on VM (from build-test-video.sh)
        log "Using pre-built test video on VM..."
        success "Found: $REPO_DIR/test_video.mp4"
    else
        # Option 3: Generate synthetic safe video (no NSFW detection will trigger)
        warn "No test video found, generating synthetic BLUE video (no NSFW content)..."
        warn "Run './scripts/build-test-video.sh' on VM first for proper testing"
        ssh_vm "ffmpeg -y -f lavfi -i color=c=blue:size=640x480:duration=${TEST_DURATION}:rate=30 -c:v libx264 -preset fast -pix_fmt yuv420p $REPO_DIR/test_video.mp4 2>/dev/null"
        success "Synthetic video generated"
    fi
}

# ── Deploy Modal GPU worker ───────────────────────────────────────────────────
deploy_modal() {
    log "Deploying Modal GPU worker..."

    # Get Modal credentials from Bitwarden
    local modal_token_id modal_token_secret
    modal_token_id=$(bw get item "Modal" --session "$(bw unlock --raw "y3&tHVAg0s%70")" 2>/dev/null | jq -r '.login.username' 2>/dev/null || echo "")
    modal_token_secret=$(bw get item "Modal" --session "$(bw unlock --raw "y3&tHVAg0s%70")" 2>/dev/null | jq -r '.login.password' 2>/dev/null || echo "")

    if [[ -z "$modal_token_id" || -z "$modal_token_secret" ]]; then
        warn "Could not fetch Modal credentials from Bitwarden, using environment"
        modal_token_id="${MODAL_TOKEN_ID:-}"
        modal_token_secret="${MODAL_TOKEN_SECRET:-}"
    fi

    ssh_vm MODAL_TOKEN_ID="$modal_token_id" MODAL_TOKEN_SECRET="$modal_token_secret" bash <<'ENDSSH'
        set -euo pipefail
        cd /root/oboon-mvp
        source venv/bin/activate

        # Set up Modal credentials
        if [[ -n "$MODAL_TOKEN_ID" && -n "$MODAL_TOKEN_SECRET" ]]; then
            modal token new --token-id "$MODAL_TOKEN_ID" --token-secret "$MODAL_TOKEN_SECRET" 2>/dev/null || true
        fi

        echo "Deploying Modal app..."
        python -m modal deploy modal_gpu_worker.py
        echo "✓ Modal deployed"
ENDSSH

    success "Modal GPU worker deployed"
}

# ── Run pipeline test ─────────────────────────────────────────────────────────
run_test() {
    log "Running NSFW detection pipeline..."

    # Get LiveKit credentials from state
    local lk_url lk_key lk_secret
    lk_url=$(jq -r '.livekit_url' "$STATE_FILE")
    lk_key=$(jq -r '.api_key' "$STATE_FILE")
    lk_secret=$(jq -r '.api_secret' "$STATE_FILE")

    # Get Modal credentials
    local modal_token_id modal_token_secret
    modal_token_id=$(bw get item "Modal" --session "$(bw unlock --raw "y3&tHVAg0s%70")" 2>/dev/null | jq -r '.login.username' 2>/dev/null || echo "")
    modal_token_secret=$(bw get item "Modal" --session "$(bw unlock --raw "y3&tHVAg0s%70")" 2>/dev/null | jq -r '.login.password' 2>/dev/null || echo "")

    ssh_vm bash << ENDSSH
        set -euo pipefail
        cd /root/oboon-mvp
        source venv/bin/activate

        # Ensure lk CLI is in PATH
        export PATH="\$HOME/.local/bin:\$PATH"

        export LIVEKIT_URL="$lk_url"
        export LIVEKIT_API_KEY="$lk_key"
        export LIVEKIT_API_SECRET="$lk_secret"
        export MODAL_TOKEN_ID="$modal_token_id"
        export MODAL_TOKEN_SECRET="$modal_token_secret"
        export TEST_DURATION="${TEST_DURATION}"

        echo "Cleaning up old processes..."
        pkill -f "agent_server.py" 2>/dev/null || true
        fuser -k 8081/tcp 2>/dev/null || true
        sleep 2

        echo "Starting agent server..."
        python agent_server.py start \\
            --url "\$LIVEKIT_URL" \\
            --api-key "\$LIVEKIT_API_KEY" \\
            --api-secret "\$LIVEKIT_API_SECRET" \\
            > agent.log 2>&1 &

        AGENT_PID=\$!
        echo "Agent PID: \$AGENT_PID"

        sleep 5

        if [[ -f "test_video.mp4" ]]; then
            echo "Converting custom video to H264 bitstream..."
            ffmpeg -y -i test_video.mp4 -vcodec copy -bsf:v h264_mp4toannexb test_stream.h264 2>/dev/null
            
            echo "Publishing custom test video..."
            lk room join "\$LIVEKIT_URL" \\
                --api-key "\$LIVEKIT_API_KEY" \\
                --api-secret "\$LIVEKIT_API_SECRET" \\
                --room nsfw-test \\
                --identity clean-publisher \\
                --publish test_stream.h264 \\
                > publish.log 2>&1 &
            PUBLISH_PID=\$!
        else
            echo "No custom video found, publishing synthetic test stream..."
            lk load-test \\
                --url "\$LIVEKIT_URL" \\
                --api-key "\$LIVEKIT_API_KEY" \\
                --api-secret "\$LIVEKIT_API_SECRET" \\
                --room nsfw-test \\
                --video-publishers 1 \\
                --duration "\${TEST_DURATION}s" \\
                > publish.log 2>&1 &
            PUBLISH_PID=\$!
        fi

        echo "Waiting for agent to process video (\${TEST_DURATION}s)..."
        sleep "\$TEST_DURATION"

        kill \$PUBLISH_PID 2>/dev/null || true

        kill \$AGENT_PID 2>/dev/null || true

        echo ""
        echo "=== Agent Log ==="
        tail -20 agent.log

        echo ""
        echo "=== Results ==="
        if [[ -f "/tmp/nsfw_results.jsonl" ]]; then
            cat /tmp/nsfw_results.jsonl
        else
            echo "No results file found"
        fi
ENDSSH

    success "Pipeline test completed"
}

# ── Fetch results ─────────────────────────────────────────────────────────────
fetch_results() {
    log "Fetching results..."
    ssh_vm "cat /tmp/nsfw_results.jsonl 2>/dev/null || echo 'No results'" > /tmp/nsfw_results_local.jsonl

    if [[ -s /tmp/nsfw_results_local.jsonl ]]; then
        echo ""
        echo -e "${BOLD}${GREEN}=== Detection Results ===${NC}"
        cat /tmp/nsfw_results_local.jsonl | jq -c '{frame: .frame_num, nsfw: .is_nsfw, score: .score, detections: [.detections[]?.class]}' 2>/dev/null || cat /tmp/nsfw_results_local.jsonl

        local nsfw_count
        nsfw_count=$(grep -c '"is_nsfw": true' /tmp/nsfw_results_local.jsonl 2>/dev/null || echo "0")
        local total_count
        total_count=$(wc -l < /tmp/nsfw_results_local.jsonl)

        echo ""
        echo -e "${BOLD}Summary:${NC} $total_count frames analyzed, $nsfw_count NSFW detections"
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
