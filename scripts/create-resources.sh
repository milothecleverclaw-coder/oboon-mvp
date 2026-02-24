#!/bin/bash
# Create Resources Script
# Creates Hetzner VM and/or Modal GPU resources for Oboon load testing

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
CALLS=100
VM_ONLY=false
MODAL_ONLY=false
VM_TYPE=""
VM_NAME="oboon-livekit"
STATE_FILE="$HOME/.openclaw/workspace/oboon/.vm-state.json"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --calls) CALLS="$2"; shift 2 ;;
        --vm-only) VM_ONLY=true; shift ;;
        --modal-only) MODAL_ONLY=true; shift ;;
        --name) VM_NAME="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

get_vm_type() {
    local calls=$1
    if [ "$calls" -le 50 ]; then echo "ccx13"; elif [ "$calls" -le 200 ]; then echo "ccx23"; elif [ "$calls" -le 600 ]; then echo "ccx33"; else echo "ccx43"; fi
}

check_tools() {
    for tool in hcloud jq; do
        if ! command -v $tool &> /dev/null; then echo -e "${RED}Missing $tool${NC}"; exit 1; fi
    done
}

ensure_firewall() {
    if ! hcloud firewall describe livekit-firewall &>/dev/null; then
        hcloud firewall create --name livekit-firewall
        hcloud firewall add-rule livekit-firewall --direction in --protocol tcp --port 22 --source-ips 0.0.0.0/0 --description "SSH"
        hcloud firewall add-rule livekit-firewall --direction in --protocol tcp --port 7880 --source-ips 0.0.0.0/0 --description "LiveKit HTTP"
        hcloud firewall add-rule livekit-firewall --direction in --protocol udp --port 50000-60000 --source-ips 0.0.0.0/0 --description "RTC"
    fi
}

create_hetzner_vm() {
    local vm_type=$1
    local vm_name=$2
    
    ensure_firewall
    
    if hcloud server describe "$vm_name" &>/dev/null; then
        hcloud server delete "$vm_name"
        sleep 2
    fi

    # Using cloud-init to force SSH key injection since --ssh-key is being flaky
    PUB_KEY=$(cat ~/.ssh/id_ed25519.pub)
    cat > /tmp/livekit-cloud-config.yaml <<EOF
#cloud-config
ssh_authorized_keys:
  - $PUB_KEY
EOF

    echo -e "${BLUE}Creating VM $vm_name ($vm_type)...${NC}"
    hcloud server create \
        --name "$vm_name" \
        --type "$vm_type" \
        --image ubuntu-24.04 \
        --location fsn1 \
        --ssh-key milo-openclaw \
        --user-data-from-file /tmp/livekit-cloud-config.yaml \
        --firewall livekit-firewall \
        --label "app=oboon"

    VM_IP=$(hcloud server describe "$vm_name" -o json | jq -r '.public_net.ipv4.ip')
    ssh-keygen -R "$VM_IP" 2>/dev/null || true

    echo -e "${YELLOW}Waiting for SSH on $VM_IP...${NC}"
    until ssh -i /home/node/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes root@$VM_IP "echo SSH_READY" 2>/dev/null; do
        echo -n "."
        sleep 5
    done
    echo -e "${GREEN}✓ SSH Ready${NC}"

    echo -e "${BLUE}Installing LiveKit...${NC}"
    ssh -i /home/node/.ssh/id_ed25519 -o StrictHostKeyChecking=no root@$VM_IP PUBLIC_IP=$VM_IP bash <<'ENDSSH'
        set -e
        apt-get update -qq && apt-get install -y -qq curl jq openssl
        
        # Install Server Binary
        echo "Downloading LiveKit server..."
        curl -sSL -o /tmp/livekit.tar.gz https://github.com/livekit/livekit/releases/download/v1.9.11/livekit_1.9.11_linux_amd64.tar.gz
        tar -xz -f /tmp/livekit.tar.gz -C /usr/local/bin livekit-server
        chmod +x /usr/local/bin/livekit-server
        rm /tmp/livekit.tar.gz
        
        # Install CLI
        curl -sSL https://get.livekit.io/cli | bash
        
        # Config with fixed node_ip
        mkdir -p /etc/livekit
        cat > /etc/livekit/config.yaml <<YAML
port: 7880
bind_addresses:
  - "0.0.0.0"
rtc:
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
  node_ip: "$PUBLIC_IP"
room:
  auto_create: true
logging:
  level: info
keys:
  $(openssl rand -hex 16): $(openssl rand -hex 32)
YAML

        # Manual systemd service setup
        cat > /etc/systemd/system/livekit.service <<SERVICE
[Unit]
Description=LiveKit Server
After=network.target

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
ENDSSH

    # Get the generated keys
    CREDS=$(ssh -i /home/node/.ssh/id_ed25519 root@$VM_IP "cat /etc/livekit/config.yaml | grep -A 1 'keys:' | tail -n 1")
    API_KEY=$(echo "$CREDS" | cut -d: -f1 | xargs)
    API_SECRET=$(echo "$CREDS" | cut -d: -f2 | xargs)

    mkdir -p "$(dirname "$STATE_FILE")"
    echo "{\"vm_ip\": \"$VM_IP\", \"api_key\": \"$API_KEY\", \"api_secret\": \"$API_SECRET\"}" > "$STATE_FILE"
    
    echo -e "${GREEN}=== Setup Complete ===${NC}"
    echo "LiveKit URL: ws://$VM_IP:7880"
    echo "API Key:     $API_KEY"
    echo "API Secret:  $API_SECRET"
}

main() {
    check_tools
    VM_TYPE=$(get_vm_type "$CALLS")
    create_hetzner_vm "$VM_TYPE" "$VM_NAME"
}

main
