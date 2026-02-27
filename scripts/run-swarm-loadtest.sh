#!/bin/bash
set -euo pipefail

SWARM_SIZE=4
CALLS_PER_VM=100
DURATION=60

SERVER_STATE_FILE="$HOME/.openclaw/workspace/oboon/.vm-state.json"
LK_URL=$(jq -r '.livekit_url' "$SERVER_STATE_FILE")
LK_KEY=$(jq -r '.api_key' "$SERVER_STATE_FILE")
LK_SECRET=$(jq -r '.api_secret' "$SERVER_STATE_FILE")

echo "=== Launching Swarm Load Test ($((SWARM_SIZE * CALLS_PER_VM)) total calls) ==="

for i in $(seq 1 $SWARM_SIZE); do
    IP=$(hcloud server describe "oboon-client-$i" -o json | jq -r '.public_net.ipv4.ip')
    
    echo "Starting $CALLS_PER_VM calls on node oboon-client-$i ($IP)..."
    
    ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no root@$IP bash << ENDSSH &
        cd /root/oboon-mvp
        source venv/bin/activate
        export PATH="\$HOME/.local/bin:\$PATH"
        export LIVEKIT_URL="$LK_URL"
        export LIVEKIT_API_KEY="$LK_KEY"
        export LIVEKIT_API_SECRET="$LK_SECRET"
        # Set dummy Modal tokens if MOCK_MODAL=true, or use actual ones if you switch it to false
        export MODAL_TOKEN_ID="ak-zlQnVh0VKNJwClPm915JV2"
        export MODAL_TOKEN_SECRET="as-RULd6fOxl73iPsR6uCS7Kh"
        export SAMPLE_SECONDS="2.0"
        export MOCK_MODAL="false"
        export NODE_ID="$i"
        
        pkill -f "multiplex_agent.py" 2>/dev/null || true
        pkill -f "agent_server.py" 2>/dev/null || true
        pkill -f "lk room join" 2>/dev/null || true
        rm -f /tmp/nsfw_results.jsonl
        sleep 2
        
        # Start Multiplex Python Agents (2 processes per VM, each handling 50 rooms)
        # This dramatically reduces CPU/RAM overhead compared to 100 processes
        START_ID=1 END_ID=50 python multiplex_agent.py > "agent_multiplex_1.log" 2>&1 &
        START_ID=51 END_ID=100 python multiplex_agent.py > "agent_multiplex_2.log" 2>&1 &
        
        # Give the agents time to connect to all their rooms
        sleep 10
        
        # Start Publishers
        for j in \$(seq 1 $CALLS_PER_VM); do
            ROOM_ID="nsfw-loadtest-node${i}-\$j"
            lk room join "\$LIVEKIT_URL" --api-key "\$LIVEKIT_API_KEY" --api-secret "\$LIVEKIT_API_SECRET" --room "\$ROOM_ID" --identity "publisher-\$j" --publish test_video.h264 --fps 30 > "pub_\$j.log" 2>&1 &
            sleep 0.1
        done
        
        sleep $DURATION
        pkill -f "lk room join" 2>/dev/null || true
        sleep 5
        pkill -f "multiplex_agent.py" 2>/dev/null || true
ENDSSH
done

echo "Waiting for all swarm nodes to finish..."
wait
echo "Test complete. Fetching results..."

rm -f /tmp/swarm_results.jsonl
for i in $(seq 1 $SWARM_SIZE); do
    IP=$(hcloud server describe "oboon-client-$i" -o json | jq -r '.public_net.ipv4.ip')
    ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no root@$IP "cat /tmp/nsfw_results.jsonl 2>/dev/null || echo ''" >> /tmp/swarm_results.jsonl
done

cp /tmp/swarm_results.jsonl /tmp/nsfw_loadtest_results.jsonl
python3 scripts/analyze_results.py
