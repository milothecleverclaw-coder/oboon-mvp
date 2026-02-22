#!/bin/bash
# LiveKit Room Management Script
# Usage: ./livekit-cli.sh <command> [args]

# Configuration
export LIVEKIT_URL="http://49.12.97.212:7880"
export LIVEKIT_API_KEY="ff656dd287ce4aa63f60df2eeb7d5194"
export LIVEKIT_API_SECRET="e8c0200218351c3ec0eabf05ce1dba84f1d0e8118d4a9927687fb0165a2f7438"

case "$1" in
  create)
    # Create a room: ./livekit-cli.sh create room-name
    ROOM_NAME=${2:-"room-$(date +%s)"}
    lk room create "$ROOM_NAME" --empty-timeout 300
    ;;

  list)
    # List all rooms
    lk room list
    ;;

  delete)
    # Delete a room: ./livekit-cli.sh delete room-name
    lk room delete "$2"
    ;;

  token)
    # Create access token: ./livekit-cli.sh token room-name participant-id
    ROOM_NAME=${2:-"test-room"}
    IDENTITY=${3:-"participant-$(date +%s)"}
    DURATION=${4:-"1h"}
    lk token create --room "$ROOM_NAME" --identity "$IDENTITY" --join --valid-for "$DURATION"
    ;;

  token-admin)
    # Create admin token: ./livekit-cli.sh token-admin room-name
    ROOM_NAME=${2:-"test-room"}
    lk token create --room "$ROOM_NAME" --identity "admin-$(date +%s)" --join --admin --valid-for "1h"
    ;;

  bulk-create)
    # Create multiple rooms for load testing: ./livekit-cli.sh bulk-create prefix count
    PREFIX=${2:-"load-test"}
    COUNT=${3:-10}
    for i in $(seq 1 $COUNT); do
      lk room create "${PREFIX}-${i}" --empty-timeout 60 2>/dev/null &
    done
    wait
    echo "Created $COUNT rooms with prefix $PREFIX"
    ;;

  bulk-delete)
    # Delete all rooms matching prefix: ./livekit-cli.sh bulk-delete prefix
    PREFIX=${2:-"load-test"}
    ROOMS=$(lk room list --json 2>/dev/null | jq -r ".[] | select(.name | startswith(\"$PREFIX\")) | .name")
    for room in $ROOMS; do
      lk room delete "$room" 2>/dev/null &
    done
    wait
    echo "Deleted all rooms with prefix $PREFIX"
    ;;

  *)
    echo "LiveKit Room Management"
    echo ""
    echo "Commands:"
    echo "  create <name>          Create a room"
    echo "  list                   List all rooms"
    echo "  delete <name>          Delete a room"
    echo "  token <room> <id>      Create participant token"
    echo "  token-admin <room>     Create admin token"
    echo "  bulk-create <p> <n>    Create N rooms with prefix P"
    echo "  bulk-delete <prefix>   Delete all rooms with prefix"
    ;;
esac
