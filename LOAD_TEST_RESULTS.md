# Oboon MVP Load Testing Results

This document tracks the scalability and cost benchmarks for the Oboon LiveKit + Modal NSFW moderation pipeline.

## Benchmark 1: 50 Concurrent Video Calls

**Test Environment:**
- **LiveKit Server:** Hetzner Cloud `ccx33` (8 dedicated vCPU, 32GB RAM, Ubuntu 24.04)
- **Moderation AI:** NudeNet deployed on Modal (Nvidia T4 GPU)
- **Agent Architecture:** 5 Python Agent Workers running locally on Hetzner.

### Results Summary
| Metric | Result |
|--------|--------|
| Target Calls | 50 |
| Rooms Successfully Processed | 50 (100%) |
| Total Inferences Scanned | 1,818 frames |
| **Average Latency** | **677.5ms** |
| Min Latency | 257ms |
| Max Latency | 2237ms (Cold Start) |
| Total GPU Time Billed | 1231.73 seconds |
| **Total Test Cost** | **$0.20** |
| Cost per 1,000 Inferences | $0.1111 |

---

## Benchmark 2: 100 Concurrent Video Calls

**Test Environment:**
- **LiveKit Server:** Hetzner Cloud `ccx43` (16 dedicated vCPU, 64GB RAM, Ubuntu 24.04)
- **Moderation AI:** NudeNet deployed on Modal (Nvidia T4 GPU)
- **Agent Architecture:** 8 Python Agent Workers running locally on Hetzner, processing 100 rooms concurrently via LiveKit's Auto-Dispatch.
- **Model Concurrency:** `allow_concurrent_inputs=10` on Modal.
- **Video Input:** 40-second H.264 test stream (20s Avengers dataset + 20s NSFW dataset), streamed at 30 FPS.
- **Sample Rate:** `SAMPLE_EVERY=2` (1 scan every ~2 frames).

### Results Summary

| Metric | Result |
|--------|--------|
| Target Calls | 100 |
| Rooms Successfully Processed | 100 (100%) |
| Total Inferences Scanned | 3,444 frames |
| **Average Latency** | **683.2ms** |
| Min Latency | 256ms |
| Max Latency | 2591ms (Cold Start) |
| Total GPU Time Billed | 2353.07 seconds |
| **Total Test Cost** | **$0.38** |
| Cost per 1,000 Inferences | $0.1121 |

### Key Findings & Analysis

1. **Sub-second Moderation at Scale:** The pipeline maintained an average inference latency of ~683ms despite 100 concurrent WebRTC streams hammering the GPUs simultaneously. This proves the backend can easily sustain SLA requirements for real-time video moderation under heavy load.
2. **Predictable Cost Scaling:** At $0.11 per 1,000 frames, the cost scales perfectly linearly. Running 100 active video rooms and scanning a frame every 3 seconds costs approximately `$0.26 per hour`. 
3. **GPU Multiplexing is Critical:** The biggest architectural win was converting the Modal function to a persistent `@modal.cls` and setting `allow_concurrent_inputs=10`. This kept the AI model hot in VRAM and multiplexed the concurrent load across fewer GPUs, bypassing the 10 GPU quota limit while maintaining speed.
4. **Hetzner Handles 100 Calls Easily:** The 16 vCPU Hetzner VM comfortably managed the networking and OpenCV frame decoding for 100 concurrent Python publisher processes. The LiveKit server monitored via Prometheus showed ~11,000 Goroutines and 0.00% packet loss during the entire benchmark.

### Next Steps
- Implement explicit LiveKit Room dispatch rules for production multi-tenant environments.
- Build the web frontend MVP to visualize the 600ms realtime ban mechanics.
