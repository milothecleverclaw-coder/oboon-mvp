# Oboon MVP Load Testing Results

This document tracks the scalability and cost benchmarks for the Oboon LiveKit + Modal NSFW moderation pipeline.

## Benchmark: 50 Concurrent Video Calls

**Test Environment:**
- **LiveKit Server:** Hetzner Cloud `ccx33` (8 dedicated vCPU, 32GB RAM, Ubuntu 24.04)
- **Moderation AI:** NudeNet deployed on Modal (Nvidia T4 GPU)
- **Agent Architecture:** 5 Python Agent Workers running locally on Hetzner, processing 50 rooms concurrently via LiveKit's Auto-Dispatch.
- **Model Concurrency:** `allow_concurrent_inputs=10` on Modal to prevent GPU free-tier exhaustion and cold-start timeouts.
- **Video Input:** 40-second H.264 test stream (20s Avengers dataset + 20s NSFW dataset), streamed at 30 FPS.
- **Sample Rate:** `SAMPLE_EVERY=2` (1 scan every ~2 frames).

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

### Key Findings & Analysis

1. **Sub-second Moderation at Scale:** The pipeline maintained an average inference latency of ~677ms despite 50 concurrent WebRTC streams hammering the GPU. This means inappropriate content is flagged in under 1 second, well within our 5-second MVP SLA.
2. **Cost Efficiency:** At $0.11 per 1,000 frames, continuous moderation is incredibly cheap. If an active call samples a frame every 3 seconds (20 frames/min), 1 hour of moderation costs approximately `$0.13` per room.
3. **GPU Multiplexing is Critical:** The biggest architectural win was converting the Modal function to a persistent `@modal.cls` and setting `allow_concurrent_inputs=10`. This kept the AI model hot in VRAM and multiplexed the concurrent load across fewer GPUs, bypassing the 10 GPU quota limit while maintaining speed.
4. **Hetzner Handles 50 Calls Easily:** The 8 vCPU Hetzner VM comfortably managed the networking and OpenCV frame decoding for 50 concurrent Python publisher processes without crashing or dropping WebRTC streams.

### Next Steps
- Scale to 100 concurrent calls to test Hetzner CPU limits.
- Implement explicit LiveKit Room dispatch rules for production multi-tenant environments.
