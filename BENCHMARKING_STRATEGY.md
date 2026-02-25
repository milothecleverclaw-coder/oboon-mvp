# Oboon Benchmarking & Load Testing Strategy

This document outlines how we currently test the Oboon LiveKit + Modal architecture, how the components scale, and how to perform isolated benchmarks to find specific system bottlenecks.

---

## 1. Current Strategy: End-to-End (E2E) Benchmarking

Right now, we use a fully integrated **End-to-End Load Test**. This test stresses the entire pipeline simultaneously: the LiveKit Server, the Python Agent Workers, and the Modal GPUs.

### How the E2E Test Works
When you run `./scripts/run-loadtest.sh --calls N`, the following happens automatically:
1. **Agent Parallelism:** The script spins up multiple Python Agent processes locally (roughly 1 worker per 10 calls) to ensure CPU-heavy tasks like OpenCV frame decoding don't bottleneck a single Python process.
2. **Concurrent Publishers:** The script uses the LiveKit CLI (`lk room join`) to simulate $N$ concurrent users connecting and streaming a 40-second H.264 video at 30 FPS into $N$ unique rooms.
3. **Auto-Dispatch:** Because the Agents maintain persistent WebSocket connections to the LiveKit Server, LiveKit automatically load-balances the new rooms and assigns jobs to the waiting Python workers.
4. **GPU Multiplexing:** The Agents sample frames and send them to the `NudeNetWorker` class on Modal. The Modal app is configured with `allow_concurrent_inputs=10`, allowing a single T4 GPU to process 10 concurrent requests from different rooms without triggering expensive "Cold Starts" or hitting the 10-GPU free-tier limit.
5. **Telemetry:** The agents log the inference latency and room ID for every frame. A Python analyzer script aggregates this data to prove 100% room processing and calculate the exact serverless GPU cost.

*Current Milestone: Successfully tested 50 concurrent calls on an 8 vCPU Hetzner VM with 0 dropped rooms and <700ms latency.*

---

## 2. Why & How to Perform Isolated Benchmarks

While the E2E test proves the system works, it makes it difficult to identify the **exact bottleneck** when the system finally crashes (e.g., at 200 or 500 calls). Does it crash because the VM ran out of network bandwidth? Because Python hit a CPU wall decoding JPEGs? Or because Modal rate-limited us?

To find out, we must decouple the architecture and run **Isolated Benchmarks**.

### Isolated Benchmark A: LiveKit Server (Network & WebRTC)
**Goal:** Determine how many concurrent video publishers/subscribers the Hetzner VM can route before packet loss or CPU starvation occurs.
**How to test:**
1. Disable the Agent Server completely (do not run `agent_server.py`).
2. Run `lk load-test` with a massive number of publishers (e.g., `--video-publishers 500`).
3. Monitor the VM using `htop` and network tools to find the breaking point.
*If this fails early, the fix is a larger VM network pipe or a clustered LiveKit deployment.*

### Isolated Benchmark B: LiveKit Agent Server (Python CPU Bound)
**Goal:** Determine how many video streams a single Python Agent can decode (YUV to JPEG via OpenCV) before the Global Interpreter Lock (GIL) or CPU maxes out.
**How to test:**
1. Modify `agent_server.py` to **mock out Modal**. Comment out the `await worker.detect_nsfw.remote.aio(...)` call.
2. Replace the AI call with a simple `await asyncio.sleep(0.1)` to simulate network delay.
3. Run the load test. 
*If the Agent crashes or drops frames at 50 calls here, we know the bottleneck is Python's CPU limitation, and we must horizontally scale the Agent workers across multiple machines (or rewrite the decoder in Rust/C++).*

### Isolated Benchmark C: Modal GPU Serverless Scaling
**Goal:** Determine Modal's cold-start latency, queue times, and rate limits when hit with massive, instantaneous concurrent traffic.
**How to test:**
1. Write a simple Python script (outside of LiveKit) that uses `asyncio.gather` to fire 1,000 asynchronous HTTP/RPC requests containing static images directly at the Modal endpoint simultaneously.
2. Measure the latency distribution (P50, P90, P99).
*If this fails, the fix is requesting a quota increase from Modal, adjusting the `allow_concurrent_inputs` tuning, or migrating to a Bare Metal rented GPU.*

---

## 3. The Path to Production

1. **Continue E2E Testing:** Push the current `run-loadtest.sh` script to 100, then 300 calls on the 8 vCPU VM.
2. **Isolate Failures:** The moment the E2E test fails (e.g., agents crash, frames are missed, or latency spikes to 10 seconds), stop and run the Isolated Benchmarks to identify the weak link.
3. **Transition to Explicit Dispatch:** For the final production build (where some rooms are private and shouldn't be moderated), switch the LiveKit Agents from "Auto-Dispatch" to "Explicit Dispatch" via a backend API (e.g., Maton or Node.js).
