import sys, json

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
print(f"Avg Latency: {avg_latency:.1f}ms")
print(f"Min Latency: {min_latency}ms")
print(f"Max Latency: {max_latency}ms")
print(f"Total GPU Time: {total_gpu_time_s:.2f}s")
print(f"Estimated Cost: ${estimated_cost:.6f} (${(estimated_cost / total_inferences)*1000:.4f} per 1K inferences)")
