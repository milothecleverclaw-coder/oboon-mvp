#!/usr/bin/env python3
"""
Oboon Load Test - Concurrent Video Call Simulator
Tests: 10 → 100 → 1000 concurrent calls

Prerequisites:
- LiveKit server running
- API keys configured
- Test video files prepared
"""

import asyncio
import json
import time
import statistics
from dataclasses import dataclass, field
from typing import Optional
import aiohttp
import websockets

# Configuration
LIVEKIT_URL = "ws://localhost:7880"  # Change to your LiveKit server
LIVEKIT_API_KEY = "your-api-key"
LIVEKIT_API_SECRET = "your-api-secret"

@dataclass
class CallMetrics:
    room_id: str
    start_time: float
    frames_processed: int = 0
    alerts_received: int = 0
    latencies: list = field(default_factory=list)
    errors: list = field(default_factory=list)
    
    def add_latency(self, latency_ms: float):
        self.latencies.append(latency_ms)
    
    def summary(self) -> dict:
        return {
            "room_id": self.room_id,
            "duration_s": time.time() - self.start_time,
            "frames_processed": self.frames_processed,
            "alerts_received": self.alerts_received,
            "avg_latency_ms": statistics.mean(self.latencies) if self.latencies else 0,
            "p99_latency_ms": sorted(self.latencies)[int(len(self.latencies)*0.99)] if len(self.latencies) > 100 else 0,
            "errors": len(self.errors)
        }


class VideoCallSimulator:
    """Simulates a single video call participant"""
    
    def __init__(self, room_id: str, participant_id: str, video_file: str = "test_video.mp4"):
        self.room_id = room_id
        self.participant_id = participant_id
        self.video_file = video_file
        self.metrics = CallMetrics(room_id=room_id, start_time=time.time())
        self.running = False
    
    async def connect(self):
        """Connect to LiveKit room"""
        # In real implementation, use livekit-server-sdk
        # This is a placeholder for the test framework
        self.running = True
        print(f"[{self.room_id}] Connected")
    
    async def stream_video(self):
        """Stream video frames (simulated)"""
        frame_count = 0
        while self.running:
            # Simulate frame capture every 33ms (30fps)
            await asyncio.sleep(0.033)
            frame_count += 1
            
            # Send frame to AI processing queue
            # In real impl: publish to WebRTC track
            if frame_count % 60 == 0:  # Log every 2s
                self.metrics.frames_processed = frame_count
    
    async def listen_for_alerts(self):
        """Listen for AI alerts via websocket"""
        # In real implementation, connect to alert service
        while self.running:
            await asyncio.sleep(0.1)
            # Simulate receiving alert
            # self.metrics.alerts_received += 1
            # self.metrics.add_latency(latency_ms)
    
    async def run(self):
        """Run the full simulation"""
        await self.connect()
        await asyncio.gather(
            self.stream_video(),
            self.listen_for_alerts()
        )
    
    async def stop(self):
        """Stop the simulation"""
        self.running = False
        return self.metrics.summary()


async def run_load_test(num_calls: int, duration_s: int = 60):
    """
    Run a load test with specified number of concurrent calls
    
    Args:
        num_calls: Number of concurrent video calls to simulate
        duration_s: Test duration in seconds
    """
    print(f"\n{'='*60}")
    print(f"LOAD TEST: {num_calls} concurrent calls for {duration_s}s")
    print(f"{'='*60}\n")
    
    # Create simulators
    simulators = [
        VideoCallSimulator(
            room_id=f"room-{i}",
            participant_id=f"participant-{i}"
        )
        for i in range(num_calls)
    ]
    
    # Start all simulators
    start_time = time.time()
    tasks = [asyncio.create_task(s.run()) for s in simulators]
    
    # Run for specified duration
    await asyncio.sleep(duration_s)
    
    # Stop all simulators and collect metrics
    results = []
    for sim in simulators:
        sim.running = False
        results.append(await sim.stop())
    
    # Cancel tasks
    for task in tasks:
        task.cancel()
    
    # Aggregate results
    total_frames = sum(r["frames_processed"] for r in results)
    total_alerts = sum(r["alerts_received"] for r in results)
    all_latencies = []
    for r in results:
        all_latencies.extend([r["avg_latency_ms"]] if r["avg_latency_ms"] > 0 else [])
    
    avg_latency = statistics.mean(all_latencies) if all_latencies else 0
    
    print(f"\n{'='*60}")
    print("RESULTS")
    print(f"{'='*60}")
    print(f"Total calls:        {num_calls}")
    print(f"Test duration:      {duration_s}s")
    print(f"Total frames:       {total_frames}")
    print(f"Total alerts:       {total_alerts}")
    print(f"Avg latency:        {avg_latency:.1f}ms")
    print(f"Frames/sec:         {total_frames/duration_s:.1f}")
    print(f"Calls with errors:  {sum(1 for r in results if r['errors'] > 0)}")
    print(f"{'='*60}\n")
    
    return {
        "num_calls": num_calls,
        "duration_s": duration_s,
        "total_frames": total_frames,
        "total_alerts": total_alerts,
        "avg_latency_ms": avg_latency,
        "frames_per_sec": total_frames/duration_s
    }


async def main():
    """Run progressive load tests"""
    
    test_configs = [
        (10, 30),    # 10 calls, 30 seconds
        (50, 30),    # 50 calls, 30 seconds
        (100, 60),   # 100 calls, 60 seconds
        (500, 60),   # 500 calls, 60 seconds
        (1000, 120), # 1000 calls, 2 minutes
    ]
    
    all_results = []
    
    for num_calls, duration in test_configs:
        result = await run_load_test(num_calls, duration)
        all_results.append(result)
        
        # Cool down between tests
        print("Cooling down for 30s...")
        await asyncio.sleep(30)
    
    # Final summary
    print("\n" + "="*60)
    print("FINAL SUMMARY")
    print("="*60)
    print(f"{'Calls':<10} {'Frames/s':<15} {'Avg Latency':<15}")
    print("-"*40)
    for r in all_results:
        print(f"{r['num_calls']:<10} {r['frames_per_sec']:<15.1f} {r['avg_latency_ms']:<15.1f}ms")
    print("="*60)


if __name__ == "__main__":
    print("""
    ╔═══════════════════════════════════════════════════════════╗
    ║           OBOON LOAD TEST - VIDEO CALL SIMULATOR          ║
    ╠═══════════════════════════════════════════════════════════╣
    ║  This tests concurrent video call capacity                ║
    ║  Requirements:                                            ║
    ║    - LiveKit server running                               ║
    ║    - API keys configured                                  ║
    ║    - AI worker processing frames                          ║
    ╚═══════════════════════════════════════════════════════════╝
    """)
    
    # For initial testing, run single small test
    asyncio.run(run_load_test(10, 30))
