#!/bin/bash
# monitor-livekit.sh
# Connects to the Hetzner VM and live-tails the LiveKit Prometheus metrics
#
# Shows:
# - Active Rooms & Participants
# - Total Packets Sent/Received
# - Packet Loss %
# - CPU / Go Routines

set -euo pipefail

STATE_FILE="$HOME/.openclaw/workspace/oboon/.vm-state.json"

if [[ ! -f "$STATE_FILE" ]]; then
    echo "Error: State file not found ($STATE_FILE)"
    exit 1
fi

VM_IP=$(jq -r '.vm_ip' "$STATE_FILE")

echo -e "\033[1;34mConnecting to LiveKit metrics on $VM_IP...\033[0m"
echo -e "Press Ctrl+C to stop.\n"

while true; do
    # Fetch metrics from LiveKit's Prometheus port securely via SSH
    METRICS=$(ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no root@$VM_IP "curl -s http://127.0.0.1:6789/metrics" 2>/dev/null || echo "FAILED")
    
    if [[ "$METRICS" == "FAILED" ]]; then
        echo -e "\033[0;31mFailed to connect to LiveKit Metrics on port 6789.\033[0m"
        echo "Make sure prometheus_port: 6789 is in /etc/livekit/config.yaml and firewall allows it (or run from VM)."
        sleep 2
        continue
    fi

    # Parse key metrics using awk/grep
    ROOMS=$(echo "$METRICS" | awk '/^livekit_room_total/ {print $2}')
    PARTICIPANTS=$(echo "$METRICS" | awk '/^livekit_participant_total/ {print $2}')
    
    # Packet counts
    PKT_IN=$(echo "$METRICS" | awk '/^livekit_packet_total\{.*dir="in".*\}/ {sum += $2} END {print sum}')
    PKT_OUT=$(echo "$METRICS" | awk '/^livekit_packet_total\{.*dir="out".*\}/ {sum += $2} END {print sum}')
    
    PKT_LOSS_IN=$(echo "$METRICS" | awk '/^livekit_packet_loss_total\{.*dir="in".*\}/ {sum += $2} END {print sum}')
    PKT_LOSS_OUT=$(echo "$METRICS" | awk '/^livekit_packet_loss_total\{.*dir="out".*\}/ {sum += $2} END {print sum}')
    
    # Handle empty/zero variables
    PKT_IN=${PKT_IN:-0}; PKT_OUT=${PKT_OUT:-0}
    PKT_LOSS_IN=${PKT_LOSS_IN:-0}; PKT_LOSS_OUT=${PKT_LOSS_OUT:-0}

    # Calculate Loss %
    LOSS_PCT_IN="0.00"
    if [[ $(echo "$PKT_IN > 0" | bc -l) -eq 1 ]]; then
        LOSS_PCT_IN=$(echo "scale=4; ($PKT_LOSS_IN / $PKT_IN) * 100" | bc -l)
    fi
    
    LOSS_PCT_OUT="0.00"
    if [[ $(echo "$PKT_OUT > 0" | bc -l) -eq 1 ]]; then
        LOSS_PCT_OUT=$(echo "scale=4; ($PKT_LOSS_OUT / $PKT_OUT) * 100" | bc -l)
    fi

    # System metrics
    GOROUTINES=$(echo "$METRICS" | awk '/^go_goroutines/ {print $2}')
    
    # Print Dashboard
    clear
    echo -e "\033[1;32m=== LiveKit Server Monitor ===\033[0m"
    echo -e "Time: $(date '+%H:%M:%S')"
    echo -e "Host: $VM_IP"
    echo -e "---------------------------------"
    echo -e "\033[1mActive Rooms:\033[0m        ${ROOMS:-0}"
    echo -e "\033[1mActive Participants:\033[0m ${PARTICIPANTS:-0}"
    echo -e "---------------------------------"
    echo -e "\033[1mINBOUND Media (From Publishers)\033[0m"
    echo -e "  Packets Received:  $PKT_IN"
    echo -e "  Packets Lost:      $PKT_LOSS_IN"
    
    if [[ $(echo "$LOSS_PCT_IN > 1.0" | bc -l) -eq 1 ]]; then
        echo -e "  Packet Loss %:     \033[0;31m${LOSS_PCT_IN}%\033[0m"
    else
        echo -e "  Packet Loss %:     \033[0;32m${LOSS_PCT_IN}%\033[0m"
    fi
    
    echo -e "---------------------------------"
    echo -e "\033[1mOUTBOUND Media (To Subscribers)\033[0m"
    echo -e "  Packets Sent:      $PKT_OUT"
    echo -e "  Packets Lost:      $PKT_LOSS_OUT"
    
    if [[ $(echo "$LOSS_PCT_OUT > 1.0" | bc -l) -eq 1 ]]; then
        echo -e "  Packet Loss %:     \033[0;31m${LOSS_PCT_OUT}%\033[0m"
    else
        echo -e "  Packet Loss %:     \033[0;32m${LOSS_PCT_OUT}%\033[0m"
    fi
    echo -e "---------------------------------"
    echo -e "\033[1mSystem Load\033[0m"
    echo -e "  Go Routines:       ${GOROUTINES:-0}"
    
    sleep 2
done
