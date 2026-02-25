#!/bin/bash

# Configuration
export BW_SESSION=$(bw unlock --raw "y3&tHVAg0s%70")

# LiveKit Credentials (Hardcoded from user)
export LIVEKIT_URL="wss://milo-cleverclaw-hzoz7qtl.livekit.cloud"
export LIVEKIT_API_KEY="APIqm8W7VKfhJWz"
export LIVEKIT_API_SECRET="RH9Gyb7gqr65vGf6hCNTVOUm7GcUj2i7gvmeqxEOWehB"

# Extract Modal secrets
export MODAL_TOKEN_ID=$(bw get item "Modal API" --session "$BW_SESSION" | jq -r '.username')
export MODAL_TOKEN_SECRET=$(bw get item "Modal API" --session "$BW_SESSION" | jq -r '.password')

source venv/bin/activate

echo "Starting Oboon AI Agent (LiveKit)..."
python backend/agent.py start &
AGENT_PID=$!

# Start FastAPI server
echo "Starting FastAPI Backend Server..."
uvicorn backend.server:app --host 0.0.0.0 --port 8010 &
FASTAPI_PID=$!

# Wait for API to start
sleep 3

# Start Cloudflare Tunnel (Named Tunnel)
echo "Exposing web app to oboon.hotserver.uk..."
cloudflared tunnel run --token "eyJhIjoiZmE1YzVkMTZmYTgwNzAzYjI3ZTkzZjZkZmJlMWE2YTkiLCJ0IjoiMjlmMWVkNDAtNGJlYy00MTljLWEwMTMtMzhmOWMwZDFkYmU3IiwicyI6ImRHVnpkSE5sWTNKbGRIUmxjM1J6WldOeVpYUjBaWE4wYzJWamNtVjBkR1Z6ZEE9PSJ9" &
TUNNEL_PID=$!

echo "🚀 App is live at: https://oboon.hotserver.uk"
echo "Press Ctrl+C to stop everything."

trap "kill $AGENT_PID $FASTAPI_PID $TUNNEL_PID" EXIT
wait
