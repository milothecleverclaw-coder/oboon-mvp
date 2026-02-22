# Oboon MVP Design Document

## Project Overview
**Goal:** 1:1 video call platform with AI security (face recognition + nudity detection)

**Target Scale:** 100-1000 concurrent video calls

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLIENT APPS                                  │
│              (Web / iOS / Android - WebRTC)                          │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      LIVEKIT SERVER                                  │
│  - WebRTC media routing                                              │
│  - Room management                                                   │
│  - Participant management                                            │
│  - Recording hooks (optional)                                        │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
┌───────────────────────────┐   ┌───────────────────────────┐
│    AI PROCESSING WORKER    │   │    AI PROCESSING WORKER    │
│  (Egress Hook Recipient)   │   │  (Egress Hook Recipient)   │
│                            │   │                            │
│  • Frame extraction        │   │  • Frame extraction        │
│  • Face recognition        │   │  • Face recognition        │
│  • Nudity detection        │   │  • Nudity detection        │
│  • Alert dispatch          │   │  • Alert dispatch          │
└───────────────────────────┘   └───────────────────────────┘
                    │                         │
                    └────────────┬────────────┘
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      ALERT / ACTION SERVICE                          │
│  - Policy enforcement                                                │
│  - Admin notifications                                               │
│  - Call termination (if needed)                                      │
│  - Audit logging                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

### Core Infrastructure
| Component | Technology | Notes |
|-----------|------------|-------|
| Video Infrastructure | **LiveKit Cloud** or **Self-hosted LiveKit** | SFU for WebRTC |
| AI Processing | **Modal** (GPU) | On-demand GPU for inference |
| Face Recognition | **DeepFace (ArcFace)** | 97%+ accuracy, tested |
| Nudity Detection | **Nudenet** or **Yahoo OpenNSFW** | Pre-trained models |
| Queue/Broker | **Redis** or **Cloud Pub/Sub** | Frame queue management |

### LiveKit Configuration
```yaml
# room composite recording or participant egress
egress:
  room_composite:
    file: false  # Don't save to file
    webhook: "https://ai-worker.example.com/process"
    # Custom egress to send frames to AI worker
```

---

## Scaling Analysis

### Resource Requirements Per Call

| Component | CPU | GPU | Memory | Network |
|-----------|-----|-----|--------|---------|
| LiveKit SFU | Low | No | 512MB | 2-4 Mbps (up+down) |
| Frame Extraction | Low | No | 256MB | Minimal |
| Face Recognition | Low | **Yes** | 2GB | - |
| Nudity Detection | Low | **Yes** | 1GB | - |

### Processing Strategies

**Option A: Full Frame Processing (Expensive)**
- Process every frame from both participants
- ~30 fps × 2 streams = 60 frames/sec per call
- GPU needed: 1 per ~5-10 calls

**Option B: Sampling (Recommended)**
- Sample 1 frame every 2-3 seconds per participant
- ~0.5 fps × 2 streams = 1 frame/sec per call
- 1 GPU can handle ~50-100 calls

**Option C: Triggered Processing**
- Only process when motion/face detected
- Most cost-effective, but may miss violations

---

## Cost Analysis

### Option 1: LiveKit Cloud + Modal (Recommended for MVP)

| Component | 100 concurrent calls | 1000 concurrent calls |
|-----------|---------------------|----------------------|
| LiveKit Cloud | ~$100-200/mo | ~$1000-2000/mo |
| Modal GPU (A10G) | ~$50-100/mo | ~$500-1000/mo |
| Redis/Queue | ~$10-30/mo | ~$50-100/mo |
| **Total** | **~$160-330/mo** | **~$1550-3100/mo** |

**Modal Pricing:**
- A10G GPU: ~$1.10/hr
- With 1 frame/sec sampling at 0.1s inference:
- 100 calls = 10 GPU-seconds/sec = 36 GPU-hours/hour ≈ $40/hr at peak
- With batching and efficient scheduling: ~$1-2/hr actual

### Option 2: Self-hosted LiveKit + Dedicated GPU Server

| Component | 100 concurrent calls | 1000 concurrent calls |
|-----------|---------------------|----------------------|
| VPS (LiveKit) | $40-80/mo (2 vCPU) | $200-400/mo (8 vCPU) |
| GPU Server | $200-400/mo (RTX 4090) | $1000-2000/mo (multiple) |
| Bandwidth | Variable | Variable |
| **Total** | **~$240-480/mo** | **~$1200-2400/mo** |

---

## Test Plan

### Phase 1: Single Call Validation
**Goal:** Prove AI works in real-time video context

| Test | Description | Success Criteria |
|------|-------------|------------------|
| T1.1 | Face recognition on live stream | Verified user detected <500ms |
| T1.2 | Unknown face detection | Alert raised <500ms |
| T1.3 | Nudity detection (test images) | Alert raised <500ms |
| T1.4 | End-to-end latency | Frame→AI→Alert < 2s |

### Phase 2: Load Testing (10 concurrent calls)
**Goal:** Validate batching and queue management

| Test | Description | Success Criteria |
|------|-------------|------------------|
| T2.1 | 10 calls, all verified users | All processed < 3s |
| T2.2 | 10 calls, mixed scenarios | All alerts triggered correctly |
| T2.3 | GPU utilization | < 50% with sampling |
| T2.4 | Memory leaks | Stable over 1 hour |

### Phase 3: Scale Testing (100 concurrent calls)
**Goal:** Prove cost-effective scaling

| Test | Description | Success Criteria |
|------|-------------|------------------|
| T3.1 | 100 concurrent calls | < 5s processing latency |
| T3.2 | Auto-scaling GPU workers | Scale up/down correctly |
| T3.3 | Failure recovery | No lost frames/frames |
| T3.4 | Cost measurement | <$0.10 per call-hour |

### Phase 4: Stress Testing (1000 concurrent calls)
**Goal:** Find limits and degradation behavior

| Test | Description | Success Criteria |
|------|-------------|------------------|
| T4.1 | 1000 concurrent calls | < 10s processing latency (P99) |
| T4.2 | Degradation curve | Graceful, not crash |
| T4.3 | Cost at scale | <$500/day at peak |
| T4.4 | Recovery time | < 30s after load drops |

---

## Load Test Implementation

### Tools Required
- **k6** or **Locust**: HTTP load testing
- **LiveKit CLI**: Room creation
- **Synthetic WebRTC clients**: Simulate video streams
- **Test video files**: Looped video as "camera" input

### Test Script Architecture
```python
# Pseudo-code for load test
class VideoCallSimulator:
    def __init__(self, room_id, video_file):
        self.room = room_id
        self.video = video_file
    
    async def join_and_stream(self):
        # Connect to LiveKit room
        # Stream video file as camera
        # Listen for AI alerts
        
async def load_test(num_calls, duration):
    simulators = [VideoCallSimulator(f"room-{i}", "test_video.mp4") 
                  for i in range(num_calls)]
    
    # Start all at once (stress) or ramp up (load)
    await gather(*[s.join_and_stream() for s in simulators])
    
    # Monitor: latency, alerts, GPU usage, costs
```

---

## Face Recognition Pipeline (Refined)

```python
# AI Worker - per frame
async def process_frame(frame, room_id, participant_id):
    results = {}
    
    # 1. Face Detection
    faces = detect_faces(frame)
    
    if len(faces) == 0:
        return {"status": "no_face", "alert": True}  # Policy: face required
    
    if len(faces) > 2:
        return {"status": "multiple_faces", "alert": True}
    
    # 2. Face Recognition (against registered users)
    for face in faces:
        match = verify_face(face, registered_users)
        if match:
            results["verified_user"] = match
        else:
            results["unknown_face"] = True
            results["alert"] = True
    
    # 3. Nudity Detection
    nudity_score = detect_nudity(frame)
    if nudity_score > 0.7:
        results["nudity_detected"] = True
        results["alert"] = True
    
    return results
```

---

## MVP Feature Checklist

### Must Have (P0)
- [ ] LiveKit room creation/management
- [ ] Client SDK integration (web demo)
- [ ] Frame capture from video streams
- [ ] Face recognition (verified vs unknown)
- [ ] Nudity detection
- [ ] Alert system (webhook/notification)
- [ ] Admin dashboard to view alerts

### Should Have (P1)
- [ ] Auto-scaling GPU workers
- [ ] Recording on violation
- [ ] Call termination API
- [ ] Audit log storage

### Nice to Have (P2)
- [ ] Liveness detection
- [ ] Deepfake detection
- [ ] Mask detection
- [ ] Multiple camera support

---

## Next Steps

1. **Week 1:** 
   - Set up LiveKit Cloud account
   - Build basic web client with video
   - Create frame extraction pipeline

2. **Week 2:**
   - Integrate face recognition (use tested code)
   - Add nudity detection model
   - Build alert webhook system

3. **Week 3:**
   - Load test with 10 concurrent calls
   - Measure latency and costs
   - Optimize sampling rate

4. **Week 4:**
   - Scale test to 100 calls
   - Document limits and costs
   - Present findings

---

## Questions for You

1. **Budget:** What's the target cost per call-hour?
2. **Latency requirement:** How fast must alerts be? (<1s? <5s?)
3. **False positive tolerance:** How many wrong alerts acceptable?
4. **Deployment preference:** Cloud (LiveKit Cloud + Modal) or self-hosted?
5. **Nudity policy:** Auto-terminate call or just alert?
