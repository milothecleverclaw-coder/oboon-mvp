#!/bin/bash
set -euo pipefail

SWARM_SIZE=4
for i in $(seq 1 $SWARM_SIZE); do
    IP=$(hcloud server describe "oboon-client-$i" -o json | jq -r '.public_net.ipv4.ip')
    echo "Deploying code & building video on oboon-client-$i ($IP)..."
    ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no root@$IP bash << 'ENDSSH' &
        set -euo pipefail
        cd /root
        if [[ ! -d "oboon-mvp" ]]; then
            git clone https://github.com/milothecleverclaw-coder/oboon-mvp.git
        fi
        cd oboon-mvp
        git fetch --all >/dev/null 2>&1
        git reset --hard origin/main >/dev/null 2>&1
        if [[ ! -d "venv" ]]; then python3 -m venv venv; fi
        source venv/bin/activate
        pip install -q --upgrade pip
        pip install -q livekit livekit-agents livekit-api modal Pillow opencv-python-headless numpy huggingface_hub kaggle
        
        # Pass the dummy environment variables so the script doesn't fail its internal check
        export HF_TOKEN="dummy"
        export KAGGLE_USER="pandavirtual"
        export KAGGLE_KEY="KGAT_239e9640075c8b85d10beaef0f252cfb"
        bash scripts/build-test-video.sh --output test_video.mp4 --count 35
ENDSSH
done
echo "Waiting for all nodes to finish setup and build..."
wait
echo "All nodes configured and videos built."
