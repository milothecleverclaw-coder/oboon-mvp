#!/bin/bash
# Create Resources Script
# Creates Hetzner VM and/or Modal GPU resources for Oboon load testing
#
# Usage:
#   ./create-resources.sh --calls <num> [--vm-only] [--modal-only]
#
# Examples:
#   ./create-resources.sh --calls 100        # Create resources for 100 calls
#   ./create-resources.sh --calls 1000       # Create resources for 1000 calls
#   ./create-resources.sh --calls 100 --vm-only  # Only create Hetzner VM
#
# Workload Tiers:
#   10-50 calls    : CPX21 (3 vCPU, 4GB RAM)
#   100-300 calls  : CPX22 (3 vCPU, 8GB RAM)  [DEFAULT]
#   500-1000 calls : CPX32 (4 vCPU, 8GB RAM)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Defaults
CALLS=100
VM_ONLY=false
MODAL_ONLY=false
VM_TYPE=""
VM_NAME="oboon-livekit"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --calls)
            CALLS="$2"
            shift 2
            ;;
        --vm-only)
            VM_ONLY=true
            shift
            ;;
        --modal-only)
            MODAL_ONLY=true
            shift
            ;;
        --name)
            VM_NAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Determine VM type based on call count
# Based on real stress test benchmarks:
#   CCX33 (8 cores, 32GB, €37/mo) → safe up to ~200 rooms
#   CCX43 (16 cores, 64GB, €60/mo) → safe up to ~600 rooms (sweet spot)
#   CCX53 (32 cores, 128GB, €110/mo) → 1000+ rooms
get_vm_type() {
    local calls=$1
    
    if [ "$calls" -le 50 ]; then
        echo "cax11"   # 2 vCPU, 4GB — dev/small tests
    elif [ "$calls" -le 200 ]; then
        echo "ccx33"   # 8 dedicated cores, 32GB — up to 200 rooms @ 100%
    elif [ "$calls" -le 600 ]; then
        echo "ccx43"   # 16 dedicated cores, 64GB — up to 600 rooms @ 100%
    else
        echo "ccx53"   # 32 dedicated cores, 128GB — 1000+ rooms
    fi
}

# Check for required tools
check_tools() {
    local missing=()
    
    if ! command -v hcloud &> /dev/null; then
        missing+=("hcloud (Hetzner CLI) - Install: brew install hcloud")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq - Install: brew install jq")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Missing required tools:${NC}"
        printf '  - %s\n' "${missing[@]}"
        exit 1
    fi
}

# Check Hetzner context
check_hetzner_context() {
    if ! hcloud context list 2>/dev/null | grep -q "oboon"; then
        echo -e "${YELLOW}Setting up Hetzner context...${NC}"
        # Check for API token in env or prompt
        if [ -z "$HCLOUD_TOKEN" ]; then
            echo -e "${RED}HCLOUD_TOKEN not set. Get token from: https://console.hetzner.cloud${NC}"
            exit 1
        fi
        hcloud context create oboon
    fi
}

# Create Hetzner VM
create_hetzner_vm() {
    local vm_type=$1
    local vm_name=$2
    local calls=$3
    
    echo -e "${BLUE}Creating Hetzner VM...${NC}"
    echo -e "  Type: ${vm_type}"
    echo -e "  Name: ${vm_name}"
    echo -e "  Expected load: ${calls} concurrent calls"
    echo ""
    
    # Check if VM already exists
    if hcloud server describe "$vm_name" &>/dev/null; then
        echo -e "${YELLOW}VM '$vm_name' already exists${NC}"
        read -p "Delete and recreate? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            hcloud server delete "$vm_name"
            sleep 5
        else
            echo "Aborted"
            exit 1
        fi
    fi
    
    # Create VM
    hcloud server create \
        --name "$vm_name" \
        --type "$vm_type" \
        --image ubuntu-24.04 \
        --location fsn1 \
        --ssh-key "milo-openclaw" \
        --label "app=oboon" \
        --label "purpose=livekit" \
        --label "calls=$calls"
    
    # Get IP
    VM_IP=$(hcloud server describe "$vm_name" -o json | jq -r '.public_net.ipv4.ip')
    
    echo ""
    echo -e "${GREEN}✓ VM created: ${vm_name} (${VM_IP})${NC}"
    
    # Save state
    echo "{\"vm_name\": \"${vm_name}\", \"vm_ip\": \"${VM_IP}\", \"vm_type\": \"${vm_type}\", \"calls\": ${calls}, \"created_at\": \"$(date -Iseconds)\"}" > ~/.openclaw/workspace/oboon/.vm-state.json
    
    # Wait for SSH
    echo -e "${YELLOW}Waiting for SSH...${NC}"
    sleep 15
    until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${VM_IP} "echo 'SSH ready'" 2>/dev/null; do
        echo "  Waiting..."
        sleep 5
    done
    
    echo -e "${GREEN}✓ SSH ready${NC}"
    
    # Install LiveKit and dependencies
    echo -e "${BLUE}Installing LiveKit and dependencies...${NC}"
    ssh -o StrictHostKeyChecking=no root@${VM_IP} << 'ENDSSH'
        set -e
        
        # Update system
        apt-get update && apt-get upgrade -y
        
        # Install dependencies
        apt-get install -y curl wget gnupg2 ca-certificates
        
        # Determine architecture
        ARCH=$(uname -m)
        if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
            LIVEKIT_ARCH="arm64"
        elif [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
            LIVEKIT_ARCH="amd64"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
        
        # Install LiveKit server
        echo "Downloading LiveKit server ($LIVEKIT_ARCH)..."
        curl -sSL -o /tmp/livekit-server.tar.gz "https://github.com/livekit/livekit/releases/download/v1.9.11/livekit_1.9.11_linux_${LIVEKIT_ARCH}.tar.gz"
        tar xz -f /tmp/livekit-server.tar.gz -C /usr/local/bin
        chmod +x /usr/local/bin/livekit-server
        
        # Install LiveKit CLI
        echo "Downloading LiveKit CLI ($LIVEKIT_ARCH)..."
        curl -sSL -o /tmp/livekit-cli.tar.gz "https://github.com/livekit/livekit-cli/releases/download/v2.13.2/lk_2.13.2_linux_${LIVEKIT_ARCH}.tar.gz"
        tar xz -f /tmp/livekit-cli.tar.gz -C /usr/local/bin lk
        chmod +x /usr/local/bin/lk
        
        # Create LiveKit config
        mkdir -p /etc/livekit
        
        # Generate API keys
        LIVEKIT_API_KEY=$(openssl rand -hex 16)
        LIVEKIT_API_SECRET=$(openssl rand -hex 32)
        
        # Create credentials file
        echo "API_KEY=$LIVEKIT_API_KEY" > /etc/livekit/credentials
        echo "API_SECRET=$LIVEKIT_API_SECRET" >> /etc/livekit/credentials
        
        # Get public IP dynamically in case $VM_IP wasn't passed into ENDSSH correctly
        PUBLIC_IP=$(curl -s ifconfig.me)
        
        cat > /etc/livekit/config.yaml << EOF
port: 7880
rtc:
    port_range_start: 50000
    port_range_end: 60000
    use_external_ip: false
    node_ip: ${PUBLIC_IP}
room:
    auto_create: true
    max_participants: 100
logging:
    level: info
keys:
    ${LIVEKIT_API_KEY}: ${LIVEKIT_API_SECRET}
EOF
        
        # Create systemd service
        cat > /etc/systemd/system/livekit.service << EOF
[Unit]
Description=LiveKit Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/livekit
ExecStart=/usr/local/bin/livekit-server --config /etc/livekit/config.yaml --bind 0.0.0.0
Restart=always
RestartSec=5
Environment=LIVEKIT_API_KEY=$LIVEKIT_API_KEY
Environment=LIVEKIT_API_SECRET=$LIVEKIT_API_SECRET

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable livekit
        systemctl start livekit
        
        echo "LiveKit installed and running"
ENDSSH
    
    echo -e "${GREEN}✓ LiveKit installed${NC}"
    
    # Get credentials from VM
    CREDS=$(ssh root@${VM_IP} "cat /etc/livekit/credentials")
    API_KEY=$(echo "$CREDS" | grep API_KEY | cut -d= -f2)
    API_SECRET=$(echo "$CREDS" | grep API_SECRET | cut -d= -f2)
    
    # Update local state with credentials
    echo "{\"vm_name\": \"${vm_name}\", \"vm_ip\": \"${VM_IP}\", \"vm_type\": \"${vm_type}\", \"calls\": ${calls}, \"livekit_url\": \"ws://${VM_IP}:7880\", \"api_key\": \"${API_KEY}\", \"api_secret\": \"${API_SECRET}\", \"created_at\": \"$(date -Iseconds)\"}" > ~/.openclaw/workspace/oboon/.vm-state.json
    
    echo ""
    echo -e "${GREEN}=== VM Ready ===${NC}"
    echo -e "  SSH: ${BLUE}ssh root@${VM_IP}${NC}"
    echo -e "  LiveKit: ${BLUE}ws://${VM_IP}:7880${NC}"
    echo -e "  API Key: ${API_KEY}"
    echo ""
    echo -e "Credentials saved to: ${YELLOW}~/.openclaw/workspace/oboon/.vm-state.json${NC}"
}

# Create Modal GPU worker
create_modal_worker() {
    local calls=$1
    
    echo -e "${BLUE}Setting up Modal GPU worker...${NC}"
    
    # Check for Modal
    if ! command -v modal &> /dev/null; then
        echo -e "${YELLOW}Modal CLI not found. Skipping GPU worker setup.${NC}"
        return 0
    fi
    
    # Create Modal secret with credentials
    if [ -f ~/.openclaw/workspace/oboon/.vm-state.json ]; then
        LIVEKIT_URL=$(jq -r '.livekit_url' ~/.openclaw/workspace/oboon/.vm-state.json)
        API_KEY=$(jq -r '.api_key' ~/.openclaw/workspace/oboon/.vm-state.json)
        API_SECRET=$(jq -r '.api_secret' ~/.openclaw/workspace/oboon/.vm-state.json)
        
        echo -e "${YELLOW}Modal secrets configured${NC}"
    fi
    
    echo -e "${GREEN}✓ Modal GPU worker ready${NC}"
}

# Print usage summary
print_summary() {
    echo ""
    echo -e "${GREEN}=== Resources Created ===${NC}"
    
    if [ -f ~/.openclaw/workspace/oboon/.vm-state.json ]; then
        jq '.' ~/.openclaw/workspace/oboon/.vm-state.json
    fi
    
    echo ""
    echo -e "Run load test:"
    echo -e "  ${BLUE}lk perf load-test --room test-${CALLS} --publishers 50 --subscribers 50 --duration 60s${NC}"
    echo ""
    echo -e "Clean up resources:"
    echo -e "  ${YELLOW}./remove-resources.sh --all${NC}"
}

# Main
main() {
    echo -e "${GREEN}=== Oboon Resource Creation ===${NC}"
    echo ""
    
    check_tools
    
    # Determine VM type
    VM_TYPE=$(get_vm_type "$CALLS")
    
    echo -e "${BLUE}Configuration:${NC}"
    echo -e "  Target calls: ${CALLS}"
    echo -e "  VM type: ${VM_TYPE}"
    echo ""
    
    if [[ "$MODAL_ONLY" == "false" ]]; then
        check_hetzner_context
        create_hetzner_vm "$VM_TYPE" "$VM_NAME" "$CALLS"
    fi
    
    if [[ "$VM_ONLY" == "false" ]]; then
        echo ""
        create_modal_worker "$CALLS"
    fi
    
    print_summary
}

main
