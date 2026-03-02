# Oboon MVP - Cashflow & Spending Breakdown

> **Based on:** 6 prisons, 10,000 prisoners  
> **Currency:** Thai Baht (฿)  
> **Total Project Cost:** ~฿60M over 5 years  
> **Last Updated:** March 2026

---

## 5-Year Financial Summary

| Year | Income | Spending | Cumulative |
|------|--------|----------|------------|
| Year 1 | ฿195M | ฿3M | ฿3M |
| Year 2 | - | ฿18M | ฿21M |
| Year 3 | - | ฿12M | ฿33M |
| Year 4 | - | ฿9M | ฿42M |
| Year 5 | - | ฿9M | ฿51M |

**Total Spend:** ~฿51M  
**Margin:** ฿195M - ฿51M = ฿144M (74%)

---

## Year 1: Ultra-Lean (<฿3M)

### Infrastructure (Cloud-Only)

| Service | Monthly | Year 1 |
|---------|---------|--------|
| LiveKit Server (32 vCPU) | ฿13,600 | ฿163,200 |
| Agent VM (48 vCPU) | ฿27,200 | ฿326,400 |
| GPU Inference (Modal) | ฿42,000 | ฿500,000 |
| Storage | ฿15,000 | ฿180,000 |
| **Total** | **฿97,800** | **฿1,170,000** |

### Hardware

| Item | Unit Cost | Qty | Total |
|------|-----------|-----|-------|
| Prisoner AIO | ฿10,000 | 50 | ฿500,000 |
| Officer AIO | ฿10,000 | 12 | ฿120,000 |
| **Total** | | | **฿620,000** |

### Year 1 Budget

| Category | Amount |
|----------|--------|
| Cloud Infrastructure | ฿1,170,000 |
| Hardware (AIOs) | ฿620,000 |
| Deployment & Training | ฿300,000 |
| Contractors | ฿500,000 |
| Contingency | ฿100,000 |
| **Year 1 Total** | **฿2,690,000** |

---

## Years 2-5: Thai Sovereignty (~฿48M)

### GPU Infrastructure

| Item | Qty | Unit | Total |
|------|-----|------|-------|
| B200 GPU | 4 | ฿2M | ฿8,000,000 |
| Server Chassis | 2 | ฿500k | ฿1,000,000 |
| Storage Server (50TB) | 2 | ฿800k | ฿1,600,000 |
| Network (100G switch) | 2 | ฿200k | ฿400,000 |
| **Total** | | | **฿11,000,000** |

### Engineering Team (Years 2-5)

| Year | Team Size | Annual Cost |
|------|-----------|-------------|
| Year 2 | 5 | ฿4,800,000 |
| Year 3 | 10 | ฿9,600,000 |
| Year 4 | 13 | ฿7,200,000 |
| Year 5 | 13 | ฿7,200,000 |
| **Total** | | **฿28,800,000** |

### Team Composition (Year 5)

| Role | Count | Monthly |
|------|-------|---------|
| Senior Software Engineer | 4 | ฿100,000 |
| DevOps Engineer | 2 | ฿80,000 |
| AI/ML Engineer | 2 | ฿120,000 |
| QA Engineer | 2 | ฿60,000 |
| Operations Manager | 1 | ฿100,000 |
| Support | 2 | ฿40,000 |

### Compliance

| Item | Cost |
|------|------|
| ISO27001 | ฿2,000,000 |
| PDPA Compliance | ฿800,000 |
| Annual Pen Testing | ฿200,000 |
| **Total** | **฿3,000,000** |

### Office & Operations

| Item | 4 Years |
|------|---------|
| Office (Bangkok) | ฿3,600,000 |
| Equipment | ฿800,000 |
| Utilities | ฿600,000 |
| **Total** | **฿5,000,000** |

---

## Spending by Category

```
Team:        ████████████████████████████████████████████ 55% (฿29M)
GPU/Infra:   █████████████████ 21% (฿11M)
Operations:  ████████████ 12% (฿6M)
Compliance:  ████████ 6% (฿3M)
Cloud Y1:    ████ 3% (฿2M)
Hardware:    ██ 1% (฿0.6M)
Contingency: ████ 3% (฿2M)
```

---

## Team Growth

```
Year 1: ███ 3-4 (founders + contractors)
Year 2: ████████ 5-8
Year 3: ████████████████████ 10-12
Year 4: ██████████████████████████ 12-15
Year 5: ██████████████████████████ 12-15
```

---

## Infrastructure Timeline

| Year | Compute | GPU | Storage | Data Location |
|------|---------|-----|---------|---------------|
| 1 | NIPA Cloud | Modal (US) | NIPA Cloud | Thailand + US |
| 2 | Owned + Cloud | Owned (TH) | Owned | Thailand |
| 3-5 | Owned | Owned | Owned | Thailand |

---

## Key Numbers

| Metric | Value |
|--------|-------|
| Year 1 Spend | ฿3M |
| Years 2-5 Spend | ฿48M |
| **Total Project Cost** | **฿51M** |
| Funding Request | ฿195M |
| **Margin** | **฿144M (74%)** |

---

## NIPA Cloud Pricing

| Service | Price |
|---------|-------|
| Compute (1:2 vCPU:RAM) | ฿1,700/vCPU/month |
| Object Storage | ฿0.77/GB/month |
| Domestic Bandwidth | FREE |
| International Egress | ฿2.31/GiB |

---

## Assumptions

- B200 GPU: ~฿2M each
- Thai senior engineer: ฿80k-120k/month
- Bangkok office: ฿75k/month
- Colocation: ฿50k/rack/month
- 6 prisons, 10,000 prisoners
- Peak: 100 concurrent calls
