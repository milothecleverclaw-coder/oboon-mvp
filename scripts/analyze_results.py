import sys, json
from collections import defaultdict

results = []
try:
    with open('/tmp/nsfw_loadtest_results.jsonl', 'r') as f:
        for line in f:
            if line.strip():
                try:
                    results.append(json.loads(line))
                except:
                    pass
except Exception:
    pass

if not results:
    print("No results found.")
    sys.exit(0)

rooms = set(r.get('room_id') for r in results if r.get('room_id'))
latencies = [r.get('latency_ms', 0) for r in results if r.get('latency_ms', 0) > 0]

# Calculate NSFW detections per room to test stream stability
room_nsfw_counts = defaultdict(int)
room_total_frames = defaultdict(int)

for r in results:
    rid = r.get('room_id')
    if not rid:
        continue
    room_total_frames[rid] += 1
    if r.get('is_nsfw'):
        room_nsfw_counts[rid] += 1

nsfw_counts = list(room_nsfw_counts.values())
frame_counts = list(room_total_frames.values())

avg_nsfw_per_room = sum(nsfw_counts) / len(rooms) if rooms else 0
min_nsfw_per_room = min(nsfw_counts) if nsfw_counts else 0
max_nsfw_per_room = max(nsfw_counts) if nsfw_counts else 0

avg_frames_per_room = sum(frame_counts) / len(rooms) if rooms else 0
min_frames_per_room = min(frame_counts) if frame_counts else 0
max_frames_per_room = max(frame_counts) if frame_counts else 0

avg_latency = sum(latencies) / len(latencies) if latencies else 0
max_latency = max(latencies) if latencies else 0
min_latency = min(latencies) if latencies else 0

total_inferences = len(results)
# T4 GPU cost: $0.59 per hour = $0.000164 per second
# Assuming average latency represents the actual GPU compute time billed
total_gpu_time_s = sum(latencies) / 1000.0
estimated_cost = total_gpu_time_s * 0.000164

print(f"Rooms Processed: {len(rooms)}")
print(f"Total Inferences: {total_inferences}")
print(f"Avg Latency: {avg_latency:.1f}ms (Min: {min_latency}ms, Max: {max_latency}ms)")
print(f"Stream Stability (Frames Scanned per Room): Avg {avg_frames_per_room:.1f} | Min {min_frames_per_room} | Max {max_frames_per_room}")
print(f"Stream Stability (NSFW Caught per Room): Avg {avg_nsfw_per_room:.1f} | Min {min_nsfw_per_room} | Max {max_nsfw_per_room}")
print(f"Total GPU Time: {total_gpu_time_s:.2f}s")
print(f"Estimated Cost: ${estimated_cost:.6f} (${(estimated_cost / total_inferences)*1000:.4f} per 1K inferences)")

