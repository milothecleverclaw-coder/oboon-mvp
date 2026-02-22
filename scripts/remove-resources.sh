#!/bin/bash
# Remove Resources Script
# Cleans up all resources created by create-resources.sh
#
# Usage:
#   ./remove-resources.sh [--all] [--vm] [--modal]
#
# Options:
#   --all     Remove everything (default)
#   --vm      Remove Hetzner VM only
#   --modal   Remove Modal resources only

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
REMOVE_ALL=true
REMOVE_VM=false
REMOVE_MODAL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            REMOVE_ALL=true
            shift
            ;;
        --vm)
            REMOVE_VM=true
            REMOVE_ALL=false
            shift
            ;;
        --modal)
            REMOVE_MODAL=true
            REMOVE_ALL=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check for required tools
check_tools() {
    local missing=()
    
    if [[ "$REMOVE_ALL" == "true" || "$REMOVE_VM" == "true" ]]; then
        if ! command -v hcloud &> /dev/null; then
            missing+=("hcloud (Hetzner CLI)")
        fi
    fi
    
    if [[ "$REMOVE_ALL" == "true" || "$REMOVE_MODAL" == "true" ]]; then
        if ! command -v modal &> /dev/null; then
            missing+=("modal (Modal CLI)")
        fi
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Missing required tools:${NC}"
        printf '  - %s\n' "${missing[@]}"
        exit 1
    fi
}

# Remove Hetzner VM
remove_hetzner_vm() {
    echo -e "${YELLOW}Removing Hetzner VM...${NC}"
    
    # Find VMs with oboon prefix
    VMS=$(hcloud server list -o noheader -o columns=name | grep "^oboon-" || true)
    
    if [ -z "$VMS" ]; then
        echo -e "${YELLOW}No Oboon VMs found${NC}"
        return 0
    fi
    
    for vm in $VMS; do
        echo -e "${YELLOW}Deleting VM: $vm${NC}"
        hcloud server delete "$vm"
        echo -e "${GREEN}✓ Deleted: $vm${NC}"
    done
    
    echo -e "${GREEN}Hetzner VM cleanup complete${NC}"
}

# Remove Modal apps and volumes
remove_modal_resources() {
    echo -e "${YELLOW}Removing Modal resources...${NC}"
    
    # List and stop Modal apps
    APPS=$(modal app list --json 2>/dev/null | jq -r '.[].app_id' 2>/dev/null || true)
    
    if [ -z "$APPS" ]; then
        echo -e "${YELLOW}No Modal apps found${NC}"
        return 0
    fi
    
    for app in $APPS; do
        if [[ "$app" == *"oboon"* ]]; then
            echo -e "${YELLOW}Stopping Modal app: $app${NC}"
            modal app stop "$app" 2>/dev/null || true
            echo -e "${GREEN}✓ Stopped: $app${NC}"
        fi
    done
    
    echo -e "${GREEN}Modal cleanup complete${NC}"
}

# Clean up local state files
cleanup_local_state() {
    echo -e "${YELLOW}Cleaning up local state...${NC}"
    
    # Remove state files
    rm -f ~/.openclaw/workspace/oboon/.vm-state.json 2>/dev/null || true
    rm -f ~/.openclaw/workspace/oboon/.modal-state.json 2>/dev/null || true
    
    echo -e "${GREEN}✓ Local state cleaned${NC}"
}

# Main
main() {
    echo -e "${GREEN}=== Oboon Resource Cleanup ===${NC}"
    echo ""
    
    check_tools
    
    if [[ "$REMOVE_ALL" == "true" || "$REMOVE_VM" == "true" ]]; then
        echo ""
        remove_hetzner_vm
    fi
    
    if [[ "$REMOVE_ALL" == "true" || "$REMOVE_MODAL" == "true" ]]; then
        echo ""
        remove_modal_resources
    fi
    
    if [[ "$REMOVE_ALL" == "true" ]]; then
        echo ""
        cleanup_local_state
    fi
    
    echo ""
    echo -e "${GREEN}=== Cleanup Complete ===${NC}"
}

main
