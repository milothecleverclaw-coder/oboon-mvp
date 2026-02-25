#!/bin/bash
# create-client-vm.sh
# Creates a Hetzner VM dedicated to running the Load Generator and Python Agents
#
# Usage:
#   ./create-client-vm.sh --calls <num> [options]

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# ── Defaults ──────────────────────────────────────────────────────────────────
CALLS=100
VM_NAME="oboon-client-swarm"
FORCE=false
LOCATION="fsn1"
CLIENT_STATE_FILE="$HOME/.openclaw/workspace/oboon/.client-vm-state.json"
SSH_KEY=""
CLIENT_IP=""

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --calls)   CALLS="$2";   shift 2 ;;
        --name)    VM_NAME="$2"; shift 2 ;;
        --force)   FORCE=true;   shift ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

log()     { echo -e "${BLUE}▶ $*${NC}"; }
success() { echo -e "${GREEN}✓ $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $*${NC}"; }
error()   { echo -e "${RED}✗ $*${NC}"; }
fatal()   { error "$*"; exit 1; }

# ── VM sizing for Load Generation ─────────────────────────────────────────────
# Video decoding (OpenCV) + Publisher spawning is VERY CPU intensive
get_client_vm_type() {
    local c=$1
    if   [ "$c" -le 10   ]; then echo "ccx13"  # 2 vCPU
    elif [ "$c" -le 50   ]; then echo "ccx33"  # 8 vCPU
    elif [ "$c" -le 200  ]; then echo "ccx43"  # 16 vCPU
    elif [ "$c" -le 500  ]; then echo "ccx53"  # 32 vCPU
    else                         echo "ccx63"  # 48 vCPU
    fi
}

resolve_ssh_key() {
    local candidates=("/home/node/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa")
    for key in "${candidates[@]}"; do
        if [[ -f "$key" ]]; then SSH_KEY="$key"; return; fi
    done
    fatal "No SSH key found"
}

create_client_vm() {
    local vm_type=$1

    if hcloud server describe "$VM_NAME" &>/dev/null; then
        CLIENT_IP=$(hcloud server describe "$VM_NAME" -o json | jq -r '.public_net.ipv4.ip')
        if [[ "$FORCE" == "false" ]]; then
            success "Client VM '$VM_NAME' ($CLIENT_IP) already exists. Use --force to recreate."
            return
        fi
        log "Deleting existing Client VM..."
        hcloud server delete "$VM_NAME"
        sleep 3
    fi

    local pub_key=$(cat "${SSH_KEY}.pub")
    cat > /tmp/client-cloud-init.yaml <<EOF
#cloud-config
ssh_authorized_keys:
  - $pub_key
EOF

    log "Creating Client VM ($vm_type) in $LOCATION..."
    hcloud server create \
        --name "$VM_NAME" \
        --type "$vm_type" \
        --image ubuntu-24.04 \
        --location "$LOCATION" \
        --ssh-key "milo-openclaw" \
        --user-data-from-file /tmp/client-cloud-init.yaml \
        --label "app=oboon-client" \
        --label "calls=$CALLS"

    CLIENT_IP=$(hcloud server describe "$VM_NAME" -o json | jq -r '.public_net.ipv4.ip')
    success "Client VM created: $VM_NAME ($CLIENT_IP)"
    ssh-keygen -R "$CLIENT_IP" 2>/dev/null || true
}

wait_for_ssh() {
    log "Waiting for SSH on $CLIENT_IP..."
    local retries=0
    until ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes "root@$CLIENT_IP" "echo ok" &>/dev/null; do
        retries=$((retries + 1))
        [[ $retries -ge 36 ]] && fatal "SSH never became ready"
        echo -n "."
        sleep 5
    done
    echo ""
    success "SSH ready"
}

setup_environment() {
    log "Installing dependencies on Client VM..."
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "root@$CLIENT_IP" bash <<'ENDSSH'
        set -euo pipefail
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -qq curl jq python3-pip python3-venv git ffmpeg libgl1 libglib2.0-0 unzip
        
        # Install LiveKit CLI
        curl -sSL https://get.livekit.io/cli | bash
ENDSSH
    success "Client environment ready"
    
    cat > "$CLIENT_STATE_FILE" <<JSON
{
  "vm_name": "$VM_NAME",
  "vm_ip": "$CLIENT_IP",
  "created_at": "$(date -Iseconds)"
}
JSON
}

main() {
    echo -e "${BOLD}=== Oboon Client VM Creation ===${NC}"
    local vm_type=$(get_client_vm_type "$CALLS")
    resolve_ssh_key
    create_client_vm "$vm_type"
    wait_for_ssh
    setup_environment
    echo -e "${GREEN}=== Setup Complete ===${NC}"
    echo "Client VM IP: $CLIENT_IP"
}

main
