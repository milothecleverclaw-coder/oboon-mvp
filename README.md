# Oboon MVP

1:1 video call platform with AI security (face recognition + nudity detection).

## Components

### Frame Capture Pipeline (`frame_capture.py`)
Captures frames from LiveKit rooms and processes them with:
- **Face Recognition**: DeepFace with ArcFace model (97%+ accuracy)
- **Nudity Detection**: Skin color HSV heuristic

```bash
python frame_capture.py --room test-room --participant user1 --duration 60
```

### Load Testing (`load_test_plan.py`)
Test scaling from 100 to 1000 concurrent calls.

```bash
python load_test_plan.py
```

### LiveKit CLI Helper (`livekit-cli.sh`)
Helper script for LiveKit room management.

## Architecture

- **LiveKit Server**: Self-hosted on Hetzner VM
- **Frame Processing**: DeepFace + ArcFace model
- **Alerts**: Webhook notifications for security events

## Requirements

```bash
pip install opencv-python-headless numpy deepface lkrtc
```

## License

MIT
