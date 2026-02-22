# Load Test Success Criteria

## Overview
This document defines success criteria for Oboon MVP load tests, ranging from 10 to 1000 concurrent 1:1 video calls.

## Test Scenarios

| Test ID | Concurrent Calls | Duration | Purpose |
|---------|-----------------|----------|---------|
| L1 | 10 | 5 min | Baseline functionality |
| L2 | 100 | 10 min | MVP target validation |
| L3 | 300 | 10 min | Scale validation |
| L4 | 500 | 10 min | Near-capacity test |
| L5 | 1000 | 10 min | Maximum capacity test |

## Success Criteria

### 1. Connectivity & Stability
- ✅ **Room Creation**: 100% rooms created successfully
- ✅ **Participant Join**: 100% participants join rooms within 5 seconds
- ✅ **Session Completion**: >95% sessions complete without drops
- ✅ **Zero Crashes**: No server crashes during test

### 2. Video Quality
- ✅ **Frame Rate**: >15 fps for all participants
- ✅ **Latency**: <500ms end-to-end latency
- ✅ **Resolution**: Minimum 320x240 per participant
- ✅ **No Freezing**: <1% frame drops

### 3. AI Processing Performance
- ✅ **Frame Capture Rate**: Frames captured every 3 seconds per call
- ✅ **Face Recognition**: >95% faces detected correctly
- ✅ **Processing Latency**: <2 seconds per frame analysis
- ✅ **Alert Delivery**: <5 seconds from detection to alert

### 4. Resource Utilization (Hetzner cpx22 - 2 cores, 4GB)
- ✅ **CPU**: <80% average utilization
- ✅ **Memory**: <3.5GB used (leave 0.5GB buffer)
- ✅ **Network**: <80% bandwidth capacity
- ✅ **Disk I/O**: No I/O bottlenecks

### 5. Cost Efficiency
- ✅ **Cost per Call**: <$0.10 per 20-minute session
- ✅ **GPU Cost**: <$0.05 per session (if using cloud GPU)
- ✅ **Total Cost**: Within $525/month for 100 calls (7hr/day)

## Load Test Metrics to Collect

### Server Metrics
- CPU usage (%)
- Memory usage (MB)
- Network I/O (Mbps)
- Disk I/O (MB/s)
- Process count
- WebSocket connections

### LiveKit Metrics
- Rooms active
- Participants per room
- Track subscriptions
- Packet loss (%)
- Jitter (ms)
- RTT (ms)

### AI Pipeline Metrics
- Frames captured
- Faces detected
- Processing time per frame (ms)
- Alert count
- False positive rate

### Client Metrics (if measurable)
- Connection time (ms)
- Video quality score
- Frame rate (fps)
- Reconnection count

## Failure Thresholds (Test Invalid If)

| Metric | Failure Threshold |
|--------|------------------|
| Room creation failure | >5% |
| Participant join failure | >5% |
| Session drops | >10% |
| Server crash | Any |
| Memory exhaustion | OOM errors |
| Network saturation | >90% bandwidth |

## Test Pass Criteria

| Test | Pass | Pass with Warnings | Fail |
|------|------|-------------------|------|
| L1 (10 calls) | All success criteria met | 1-2 warnings | Any failure |
| L2 (100 calls) | All success criteria met | 1-3 warnings | Any failure |
| L3 (300 calls) | All success criteria met | 1-4 warnings | Any failure |
| L4 (500 calls) | Core criteria met | Performance degradation | Instability |
| L5 (1000 calls) | Basic connectivity | Some degradation | System failure |

## Recommendations by Test Result

### All Pass
- System ready for production
- Proceed to next scale tier

### Pass with Warnings
- Document warnings
- Investigate root causes
- Consider optimizations before next tier

### Fail
- Stop further scale testing
- Identify and fix bottlenecks
- Re-run failed test before proceeding

## Next Steps After Load Tests
1. Document all test results
2. Create performance report
3. Identify optimization opportunities
4. Update capacity planning
5. Prepare production deployment guide
