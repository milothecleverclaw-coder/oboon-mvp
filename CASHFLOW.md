# Oboon MVP - Cashflow & Spending Breakdown

> **Based on:** 6 prisons, 10,000 prisoners  
> **Currency:** GBP (£)  
> **Last Updated:** March 2026

---

## Overview

| Metric | Value |
|--------|-------|
| Total Prisoners | 10,000 |
| Number of Prisons | 6 |
| Prisoner AIOs | 50 (200:1 ratio) |
| Officer AIOs | 12 (2 per prison) |
| Total AIOs | 62 |
| Family Accounts (est.) | 50,000 |
| Peak Concurrent Calls | ~100 |
| **Total 5-Year Spend** | **~£120,000** |

---

## Phase 1: Pilot (Months 1-3)

**Total Spend: ~£8,000**

| Item | Cost | Notes |
|------|------|-------|
| **Hardware** | | |
| Prisoner AIOs (9 units) | £2,070 | 9 × 10,000 THB |
| Officer AIOs (2 units) | £460 | 2 × 10,000 THB |
| **VMs (3 months)** | | |
| LiveKit Server (32 vCPU) | £939 | £313 × 3 |
| Agent VM (48 vCPU) | £1,881 | £627 × 3 |
| **GPU (3 months)** | | |
| Modal/Runpod inference | £150 | Light testing |
| **Egress (3 months)** | | |
| International (to GPU) | £190 | Light load |
| **Storage** | | |
| Object storage | £15 | Minimal |
| **Setup/Misc** | | |
| Travel, deployment, testing | £1,500 | |
| Contingency (10%) | £800 | |
| **Phase 1 Total** | **£8,005** | |

---

## Phase 2: Validation (Months 4-6)

**Total Spend: ~£4,000**

| Item | Cost | Notes |
|------|------|-------|
| **VMs (3 months)** | | |
| LiveKit Server | £939 | £313 × 3 |
| Agent VM | £1,881 | £627 × 3 |
| **GPU (3 months)** | | |
| Modal/Runpod | £300 | More testing |
| **Egress (3 months)** | | |
| International | £380 | Increased load |
| **Storage** | | |
| Object storage | £30 | Growing |
| **Optimization/Testing** | | |
| Load testing, tuning | £500 | |
| Contingency (10%) | £350 | |
| **Phase 2 Total** | **£4,380** | |

---

## Phase 3: Full Rollout (Months 7-12)

**Total Spend: ~£25,000**

| Item | Cost | Notes |
|------|------|-------|
| **Hardware** | | |
| Prisoner AIOs (41 units) | £9,430 | 41 × 10,000 THB |
| Officer AIOs (10 units) | £2,300 | 10 × 10,000 THB |
| **VMs (6 months)** | | |
| LiveKit Server | £1,878 | £313 × 6 |
| Agent VM | £3,762 | £627 × 6 |
| **GPU (6 months)** | | |
| Modal/Runpod | £600 | Production load |
| **Egress (6 months)** | | |
| International | £760 | Full scale |
| **Storage** | | |
| Object storage | £90 | Growing |
| **Deployment** | | |
| Travel, setup (5 prisons) | £3,000 | |
| Training materials | £1,500 | |
| Contingency (10%) | £2,000 | |
| **Phase 3 Total** | **£25,320** | |

---

## Phase 4: Family App Scale (Months 10-18)

**Total Spend: ~£12,500**

| Item | Cost | Notes |
|------|------|-------|
| **VMs (9 months)** | | |
| LiveKit Server | £2,817 | £313 × 9 |
| Agent VM | £5,643 | £627 × 9 |
| **GPU (9 months)** | | |
| Modal/Runpod | £900 | |
| **Egress (9 months)** | | |
| International | £1,140 | |
| **Storage** | | |
| Object storage (growing) | £270 | 500GB target |
| **Marketing/Launch** | | |
| App store optimization, support | £1,000 | |
| Contingency (10%) | £730 | |
| **Phase 4 Total** | **£12,500** | |

*Note: Overlaps with Phase 3 end and Phase 5 start*

---

## Phase 5: Operations (Years 2-5)

**Total Spend: ~£70,000**

| Item | Annual Cost | 4 Years |
|------|-------------|---------|
| **VMs** | | |
| LiveKit Server | £3,756/yr | £15,024 |
| Agent VM | £7,524/yr | £30,096 |
| **GPU** | | |
| Modal/Runpod | £1,200/yr | £4,800 |
| **Egress** | | |
| International | £1,520/yr | £6,080 |
| **Storage** | | |
| Object storage | £120/yr | £480 |
| **Maintenance** | | |
| Hardware replacements | £1,000/yr | £4,000 |
| Software updates | £500/yr | £2,000 |
| Support (part-time) | £1,000/yr | £4,000 |
| **Contingency** | | £4,000 |
| **Phase 5 Total** | | **£70,480** |

---

## Cash Flow Timeline

| Phase | Months | Spend | Cumulative |
|-------|--------|-------|------------|
| **1. Pilot** | 1-3 | £8,000 | £8,000 |
| **2. Validation** | 4-6 | £4,000 | £12,000 |
| **3. Rollout** | 7-12 | £25,000 | £37,000 |
| **4. Family Scale** | 10-18 | £12,500 | £49,500 |
| **5. Operations** | Year 2-5 | £70,000 | £119,500 |

---

## When Money Is Needed

| Milestone | When | Amount Needed |
|-----------|------|---------------|
| Start Pilot | Day 1 | **£8,000** |
| Start Validation | Month 4 | **£4,000** |
| Buy Bulk Hardware | Month 7 | **£12,000** |
| Complete Rollout | Month 7-12 | **£13,000** |
| Year 2 Ops | Month 13 | **£13,000/yr** |
| Years 3-5 | Ongoing | **£13,000/yr** |

**Peak cash need:** Month 7-12 (buying all hardware + running full infra)

---

## Infrastructure Cost Details

### NIPA Cloud VMs (Monthly)

| Server | Spec | Monthly (THB) | Monthly (£) |
|--------|------|---------------|-------------|
| LiveKit Server | 32 vCPU, 64GB | ฿13,600 | £313 |
| Agent VM | 48 vCPU, 96GB | ฿27,200 | £627 |

### NIPA Cloud Pricing Reference

| Service | Price |
|---------|-------|
| Compute Intensive (1:2 vCPU:RAM) | ฿1,700/vCPU/month |
| Object Storage | ฿0.77/GB/month |
| Block Storage (SSD) | ฿3/GB/month |
| **Domestic Bandwidth** | **FREE** |
| International Egress | ฿2.31/GiB (~£0.053/GB) |

### GPU Inference (Modal/Runpod)

| Metric | Value |
|--------|-------|
| Cost per 1,000 inferences | ~$0.11-0.14 |
| Peak frames/hour | ~18,000 (100 concurrent) |
| Estimated monthly | £100-200 |

### Hardware (One-Time)

| Item | Unit Cost | Qty | Total |
|------|-----------|-----|-------|
| Prisoner AIO | 10,000 THB (~£230) | 50 | £11,500 |
| Officer AIO | 10,000 THB (~£230) | 12 | £2,760 |
| **Total** | | **62** | **£14,260** |

---

## Assumptions

- Operating hours: 9am-4pm (6 hours/day), lunch break excluded
- Call frequency: 2 meetings/month per prisoner, 20 min each
- Peak concurrent calls: ~100 (based on scheduling)
- Video streaming: Domestic only (free egress within Thailand)
- Frame inference: International (to Modal/Runpod GPUs abroad)
- Exchange rate: 1 GBP ≈ 43 THB

---

## Budget vs Spend

| Category | Ask | Internal Spend | Margin |
|----------|-----|----------------|--------|
| Total | **£5,000,000** | **~£120,000** | **~£4,880,000** |

Margin covers: company overhead, future R&D, risk, profit, unexpected costs, feature expansion.
