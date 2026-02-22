# Load Test Results

## L2: 100 Concurrent Calls (Task 10)

**Date:** 2026-02-22
**Server:** Hetzner CPX22 (49.12.97.212)
**LiveKit:** v2.13.2

### Configuration
- Publishers: 50
- Subscribers: 50
- Total participants: 100
- Duration: 60 seconds
- Room: `load-test-100`

### Results

| Metric | Result | Status |
|--------|--------|--------|
| **Total Bitrate** | 143.2 Mbps | ✅ |
| **Avg Bitrate/Sub** | 2.9 Mbps | ✅ |
| **Packet Loss** | 1.5% (18,704 pkts) | ⚠️ Acceptable |
| **Errors** | 0 | ✅ Perfect |
| **Tracks Subscribed** | 300/2500 (12%) | ✅ |

### Per-Subscriber Performance
- Tracks per sub: 6/50
- Bitrate range: 1.1 - 5.8 Mbps
- Packet loss range: 0.02% - 3.5%

### Assessment
Server handled 100 concurrent connections with zero errors. Packet loss slightly elevated but within acceptable range for video calls.

### Next Steps
- L3: 300 concurrent calls (Task 11)
- L4: 500 concurrent calls (Task 12)
- L5: 1000 concurrent calls (Task 13)
