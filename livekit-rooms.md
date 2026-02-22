# LiveKit Room Configuration

## Room Settings for Oboon MVP

### Default Room Configuration
```yaml
# Room settings for 1:1 video calls with AI security
room:
  max_participants: 2
  empty_timeout: 300  # 5 minutes
  max_room_lifetime: 1200  # 20 minutes (session duration)

# Egress settings for frame capture
egress:
  room_composite:
    file_prefix: "oboon-frames-"
    segment_duration: 3  # 3 seconds per frame capture
```

## Room Types

### 1. Standard Room (1:1 call)
- **max_participants:** 2
- **empty_timeout:** 300s (5 min)
- **max_room_lifetime:** 1200s (20 min)
- **codecs:** VP8, H.264

### 2. Test Room (for load testing)
- **max_participants:** 2
- **empty_timeout:** 60s (1 min)
- **max_room_lifetime:** 300s (5 min)
- **auto_create:** Yes

## Room Naming Convention
- Production: `oboon-{user1_id}-{user2_id}-{timestamp}`
- Test: `test-{load_test_id}-{room_number}`

## Room Creation via API
Rooms are created dynamically using LiveKit Server SDK or CLI.

### Using lk CLI
```bash
# Create a room
lk create-room --url ws://49.12.97.212:7880 \
  --api-key ff656dd287ce4aa63f60df2eeb7d5194 \
  --api-secret e8c0200218351c3ec0eabf05ce1dba84f1d0e8118d4a9927687fb0165a2f7438 \
  --name test-room-001 \
  --max-participants 2 \
  --empty-timeout 300
```

### Using curl (REST API)
```bash
# Create room via Twirp API
curl -X POST http://49.12.97.212:7880/twirp/livekit.RoomService/CreateRoom \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -d '{
    "name": "test-room-001",
    "max_participants": 2,
    "empty_timeout": 300
  }'
```

## Access Tokens

### Participant Token Generation
Access tokens are JWTs signed with the API secret. They contain:
- Room name
- Participant identity
- Permissions (can_publish, can_subscribe, can_publish_data)
- Expiration time

### Token Structure
```json
{
  "iss": "ff656dd287ce4aa63f60df2eeb7d5194",
  "sub": "participant-identity",
  "aud": "livekit",
  "room": "test-room-001",
  "exp": 1234567890,
  "video": {
    "roomCreate": false,
    "roomJoin": true,
    "canPublish": true,
    "canSubscribe": true,
    "canPublishData": true
  }
}
```

## Next Steps
1. Install LiveKit CLI (lk) for room management
2. Create room creation script for load tests
3. Set up access token generation service
