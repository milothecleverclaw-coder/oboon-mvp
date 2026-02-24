#!/bin/bash
# create-resources.sh
# Creates Hetzner VM with LiveKit server for Oboon load testing
#
# Usage:
#   ./create-resources.sh --calls <num> [options]
#
# Options:
#   --calls  <n>    Target concurrent calls (determines VM size)
#   --name   <n>    VM name (default: oboon-livekit)
#   --vm-only       Skip Modal GPU worker setup
#   --force         Recreate VM even if already healthy
#
# Workload tiers (x86 dedicated CPU):
#   ≤50    : ccx13  (2 vCPU,  8GB,  ~€16/mo)
#   ≤200   : ccx23  (4 vCPU,  16GB, ~€28/mo)
#   ≤600   : ccx33  (8 vCPU,  32GB, ~€37/mo)
#   ≤1000  : ccx43  (16 vCPU, 64GB, ~€60/mo)
#   >1000  : ccx53  (32 vCPU, 128GB, ~€110/mo)

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# ── Defaults ──────────────────────────────────────────────────────────────────
CALLS=100
VM_NAME="oboon-livekit"
VM_ONLY=false
FORCE=false
LIVEKIT_VERSION="1.9.11"
LOCATION="fsn1"
STATE_FILE="$HOME/.openclaw/workspace/oboon/.vm-state.json"
SSH_KEY=""
VM_IP=""

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --calls)   CALLS="$2";   shift 2 ;;
        --name)    VM_NAME="$2"; shift 2 ;;
        --vm-only) VM_ONLY=true; shift ;;
        --force)   FORCE=true;   shift ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
log()     { echo -e "${BLUE}▶ $*${NC}"; }
success() { echo -e "${GREEN}✓ $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $*${NC}"; }
error()   { echo -e "${RED}✗ $*${NC}"; }
fatal()   { error "$*"; cleanup_on_failure; exit 1; }

# ── Cleanup on failure ────────────────────────────────────────────────────────
cleanup_on_failure() {
    if [[ -n "$VM_IP" ]]; then
        warn "Script failed — cleaning up VM to avoid wasted spend..."
        hcloud server delete "$VM_NAME" 2>/dev/null && warn "VM deleted." || true
    fi
}
trap 'cleanup_on_failure' ERR

# ── VM sizing ─────────────────────────────────────────────────────────────────
get_vm_type() {
    local c=$1
    if   [ "$c" -le 50   ]; then echo "ccx13"
    elif [ "$c" -le 200  ]; then echo "ccx23"
    elif [ "$c" -le 600  ]; then echo "ccx33"
    elif [ "$c" -le 1000 ]; then echo "ccx43"
    else                         echo "ccx53"
    fi
}

# ── Check required tools ──────────────────────────────────────────────────────
check_tools() {
    local missing=()
    for tool in hcloud jq curl; do
        command -v "$tool" &>/dev/null || missing+=("$tool")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        fatal "Missing tools: ${missing[*]}"
    fi
    success "Tools OK"
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
            success "SSH key: $SSH_KEY"
            return
        fi
    done
    fatal "No SSH private key found. Tried: ${candidates[*]}"
}

# ── Verify SSH key matches Hetzner ───────────────────────────────────────────
verify_ssh_key_in_hetzner() {
    local local_fp
    local_fp=$(ssh-keygen -l -E md5 -f "${SSH_KEY}.pub" 2>/dev/null | awk '{print $2}' | sed 's/MD5://')

    local match
    match=$(hcloud ssh-key list -o json | jq -r --arg fp "$local_fp" \
        '.[] | select(.fingerprint == $fp) | .name')

    if [[ -z "$match" ]]; then
        warn "Local SSH key fingerprint ($local_fp) not found in Hetzner."
        warn "Uploading it now..."
        local key_name="openclaw-$(date +%s)"
        hcloud ssh-key create --name "$key_name" --public-key-from-file "${SSH_KEY}.pub"
        success "Uploaded SSH key as '$key_name'"
    else
        success "SSH key matched in Hetzner: $match"
    fi
}

# ── Firewall ──────────────────────────────────────────────────────────────────
ensure_firewall() {
    if hcloud firewall describe livekit-firewall &>/dev/null; then
        success "Firewall 'livekit-firewall' already exists"
        return
    fi
    log "Creating firewall..."
    hcloud firewall create --name livekit-firewall
    hcloud firewall add-rule livekit-firewall --direction in --protocol tcp \
        --port 22 --source-ips 0.0.0.0/0 --description "SSH"
    hcloud firewall add-rule livekit-firewall --direction in --protocol tcp \
        --port 7880 --source-ips 0.0.0.0/0 --description "LiveKit HTTP/WS"
    hcloud firewall add-rule livekit-firewall --direction in --protocol udp \
        --port 50000-60000 --source-ips 0.0.0.0/0 --description "RTC UDP"
    success "Firewall created"
}

# ── Create or reuse VM ────────────────────────────────────────────────────────
create_or_reuse_vm() {
    local vm_type=$1

    if hcloud server describe "$VM_NAME" &>/dev/null; then
        VM_IP=$(hcloud server describe "$VM_NAME" -o json | jq -r '.public_net.ipv4.ip')

        if [[ "$FORCE" == "false" ]]; then
            # Check if LiveKit is already healthy
            if curl -sf --connect-timeout 3 "http://${VM_IP}:7880" &>/dev/null; then
                success "VM '$VM_NAME' ($VM_IP) already healthy — skipping recreation (use --force to override)"
                return
            else
                warn "VM exists but LiveKit not responding. Recreating..."
            fi
        fi

        log "Deleting existing VM..."
        hcloud server delete "$VM_NAME"
        sleep 3
    fi

    # Inject SSH key via cloud-init (most reliable method)
    local pub_key
    pub_key=$(cat "${SSH_KEY}.pub")
    cat > /tmp/livekit-cloud-init.yaml <<EOF
#cloud-config
ssh_authorized_keys:
  - $pub_key
EOF

    log "Creating VM ($vm_type) in $LOCATION..."
    hcloud server create \
        --name "$VM_NAME" \
        --type "$vm_type" \
        --image ubuntu-24.04 \
        --location "$LOCATION" \
        --ssh-key "milo-openclaw" \
        --user-data-from-file /tmp/livekit-cloud-init.yaml \
        --firewall livekit-firewall \
        --label "app=oboon" \
        --label "calls=$CALLS"

    VM_IP=$(hcloud server describe "$VM_NAME" -o json | jq -r '.public_net.ipv4.ip')
    success "VM created: $VM_NAME ($VM_IP)"

    # Clear stale known_hosts
    ssh-keygen -R "$VM_IP" 2>/dev/null || true
}

# ── Wait for SSH ──────────────────────────────────────────────────────────────
wait_for_ssh() {
    log "Waiting for SSH on $VM_IP..."
    local retries=0
    local max=36  # 3 minutes max
    until ssh -i "$SSH_KEY" \
              -o StrictHostKeyChecking=no \
              -o ConnectTimeout=5 \
              -o BatchMode=yes \
              "root@$VM_IP" "echo ok" &>/dev/null; do
        retries=$((retries + 1))
        [[ $retries -ge $max ]] && fatal "SSH never became ready after $((max * 5))s"
        echo -n "."
        sleep 5
    done
    echo ""
    success "SSH ready (after $((retries * 5))s)"
}

# ── Install LiveKit ───────────────────────────────────────────────────────────
install_livekit() {
    # Generate credentials locally — avoids heredoc variable scoping issues
    local api_key api_secret
    api_key=$(openssl rand -hex 16)
    api_secret=$(openssl rand -hex 32)

    log "Installing LiveKit $LIVEKIT_VERSION on $VM_IP..."

    ssh -i "$SSH_KEY" \
        -o StrictHostKeyChecking=no \
        "root@$VM_IP" \
        LIVEKIT_VERSION="$LIVEKIT_VERSION" \
        PUBLIC_IP="$VM_IP" \
        API_KEY="$api_key" \
        API_SECRET="$api_secret" \
        bash <<'ENDSSH'
        set -euo pipefail
        DEBIAN_FRONTEND=noninteractive

        echo "==> Updating packages..."
        apt-get update -qq
        apt-get install -y -qq --no-install-recommends curl jq ca-certificates python3-pip python3-venv git ffmpeg libgl1-mesa-glx libglib2.0-0

        echo "==> Detecting architecture..."
        ARCH=$(uname -m)
        case "$ARCH" in
            x86_64|amd64)   LK_ARCH="amd64" ;;
            aarch64|arm64)  LK_ARCH="arm64" ;;
            *) echo "Unsupported arch: $ARCH"; exit 1 ;;
        esac

        echo "==> Downloading LiveKit server $LIVEKIT_VERSION ($LK_ARCH)..."
        curl -sSL -o /tmp/livekit.tar.gz \
            "https://github.com/livekit/livekit/releases/download/v${LIVEKIT_VERSION}/livekit_${LIVEKIT_VERSION}_linux_${LK_ARCH}.tar.gz"
        tar -xz -f /tmp/livekit.tar.gz -C /usr/local/bin livekit-server
        chmod +x /usr/local/bin/livekit-server
        rm /tmp/livekit.tar.gz
        echo "==> Server: $(livekit-server --version 2>&1 || echo 'installed')"

        echo "==> Installing LiveKit CLI (lk)..."
        curl -sSL https://get.livekit.io/cli | bash
        echo "==> CLI: $(lk --version 2>&1 || echo 'installed')"

        echo "==> Writing config..."
        mkdir -p /etc/livekit
        cat > /etc/livekit/config.yaml <<YAML
port: 7880
bind_addresses:
  - "0.0.0.0"
rtc:
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
  node_ip: "${PUBLIC_IP}"
room:
  auto_create: true
  max_participants: 500
logging:
  level: info
keys:
  ${API_KEY}: ${API_SECRET}
YAML

        echo "==> Saving credentials..."
        cat > /etc/livekit/credentials <<CREDS
API_KEY=${API_KEY}
API_SECRET=${API_SECRET}
CREDS
        chmod 600 /etc/livekit/credentials

        echo "==> Creating systemd service..."
        cat > /etc/systemd/system/livekit.service <<SERVICE
[Unit]
Description=LiveKit Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/livekit
ExecStart=/usr/local/bin/livekit-server --config /etc/livekit/config.yaml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

        systemctl daemon-reload
        systemctl enable livekit
        systemctl start livekit

        echo "==> Waiting for LiveKit to bind..."
        for i in $(seq 1 10); do
            sleep 1
            if curl -sf http://127.0.0.1:7880 &>/dev/null; then
                echo "==> LiveKit responding on port 7880 ✓"
                exit 0
            fi
        done
        echo "==> LiveKit did not respond in time!"
        journalctl -u livekit -n 30 --no-pager
        exit 1
ENDSSH

    success "LiveKit installed"

    # Save state
    mkdir -p "$(dirname "$STATE_FILE")"
    cat > "$STATE_FILE" <<JSON
{
  "vm_name": "$VM_NAME",
  "vm_ip": "$VM_IP",
  "livekit_url": "ws://${VM_IP}:7880",
  "api_key": "$api_key",
  "api_secret": "$api_secret",
  "created_at": "$(date -Iseconds)"
}
JSON
    success "State saved to $STATE_FILE"
}

# ── Health check ──────────────────────────────────────────────────────────────
health_check() {
    log "Running health check on ws://${VM_IP}:7880..."

    # HTTP check
    if ! curl -sf --connect-timeout 5 "http://${VM_IP}:7880" &>/dev/null; then
        fatal "Health check failed — LiveKit not responding on port 7880"
    fi
    success "HTTP check passed"

    # WebRTC signal check via lk
    local api_key api_secret
    api_key=$(jq -r '.api_key' "$STATE_FILE")
    api_secret=$(jq -r '.api_secret' "$STATE_FILE")

    if command -v lk &>/dev/null; then
        local result
        result=$(lk load-test \
            --url "ws://${VM_IP}:7880" \
            --api-key "$api_key" \
            --api-secret "$api_secret" \
            --room "healthcheck-$$" \
            --video-publishers 1 \
            --subscribers 1 \
            --duration 5s 2>&1 || true)

        if echo "$result" | grep -q "0 (0%)"; then
            success "WebRTC signal + media check passed (0% packet loss)"
        else
            warn "Load test output: $result"
            warn "WebRTC check inconclusive — manual verification recommended"
        fi
    else
        warn "lk CLI not found locally — skipping WebRTC check"
    fi
}

# ── Summary ───────────────────────────────────────────────────────────────────
print_summary() {
    local api_key api_secret
    api_key=$(jq -r '.api_key' "$STATE_FILE")
    api_secret=$(jq -r '.api_secret' "$STATE_FILE")

    echo ""
    echo -e "${BOLD}${GREEN}=== Setup Complete ===${NC}"
    echo -e "  VM:         $VM_NAME ($VM_IP)"
    echo -e "  LiveKit:    ws://${VM_IP}:7880"
    echo -e "  API Key:    $api_key"
    echo -e "  API Secret: $api_secret"
    echo ""
    echo -e "Load test:"
    echo -e "  ${BLUE}lk load-test \\"
    echo -e "    --url ws://${VM_IP}:7880 \\"
    echo -e "    --api-key $api_key \\"
    echo -e "    --api-secret $api_secret \\"
    echo -e "    --room test-room \\"
    echo -e "    --video-publishers 5 \\"
    echo -e "    --subscribers 20 \\"
    echo -e "    --duration 30s${NC}"
    echo ""
    echo -e "SSH access:"
    echo -e "  ${BLUE}ssh -i $SSH_KEY root@$VM_IP${NC}"
    echo ""
    echo -e "Clean up:"
    echo -e "  ${YELLOW}./remove-resources.sh --all${NC}"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}=== Oboon Resource Creation ===${NC}"
    echo -e "  Calls: $CALLS | VM: $VM_NAME | Force: $FORCE"
    echo ""

    local vm_type
    vm_type=$(get_vm_type "$CALLS")

    check_tools
    resolve_ssh_key
    verify_ssh_key_in_hetzner
    ensure_firewall
    create_or_reuse_vm "$vm_type"
    wait_for_ssh
    install_livekit
    health_check
    print_summary
}

main
