# Oboon MVP - Quick Reference

## Cost Summary (Monthly)

| Scale | LiveKit | GPU (Modal) | Other | **Total** |
|-------|---------|-------------|-------|-----------|
| **100 calls** | $100-200 | $50-100 | $30 | **$180-330** |
| **500 calls** | $500-1000 | $250-500 | $100 | **$850-1600** |
| **1000 calls** | $1000-2000 | $500-1000 | $200 | **$1700-3200** |

## Key Specs

| Metric | Target |
|--------|--------|
| Alert latency | < 2 seconds |
| Face recognition accuracy | 97%+ |
| Nudity detection accuracy | 95%+ |
| Concurrent calls (MVP) | 100 |
| Concurrent calls (Scale goal) | 1000 |
| Frame sampling rate | 0.5 fps per stream |

## Recommended Stack

1. **LiveKit Cloud** - Managed WebRTC (fastest to start)
2. **Modal** - GPU inference (pay per use)
3. **DeepFace + ArcFace** - Face recognition
4. **NudeNet** - Nudity detection
5. **Redis** - Frame queue

## Test Phases

| Phase | Calls | Goal |
|-------|-------|------|
| Phase 1 | 1 | Single call validation |
| Phase 2 | 10 | Multi-call batching |
| Phase 3 | 100 | Cost/performance baseline |
| Phase 4 | 1000 | Stress test limits |

## Quick Commands

```bash
# Create oboon project structure
cd /home/node/.openclaw/workspace/oboon

# Install dependencies
pip install livekit-server-sdk livekit-api deepface nudenet redis

# Run face recognition test (already done)
python video-test/face_recognition_test.py

# Run load test (when ready)
python load_test_plan.py
```

## Files Created

```
oboon/
├── MVP_DESIGN.md      # Full design document
├── load_test_plan.py  # Load testing script
├── COST_CALCULATOR.md # This file
└── (more to come)
```
