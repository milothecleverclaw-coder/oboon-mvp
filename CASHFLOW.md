# Oboon MVP - Cashflow & Spending Breakdown

> **Based on:** 6 prisons, 10,000 prisoners  
> **Currency:** Thai Baht (฿)  
> **Total Project Cost:** ~฿86M over 5 years  
> **Last Updated:** March 2026

---

## Thai Compliance Requirements

| Law/Standard | Full Name | Key Requirements |
|--------------|-----------|------------------|
| **PDPA** | Personal Data Protection Act B.E. 2562 | Consent, data minimization, DPO required, cross-border transfer restrictions |
| **ISO27001** | Information Security Management | Security controls, risk assessment, continuous improvement |
| **Cybersecurity Act** | Cybersecurity Act B.E. 2562 | Security measures, incident reporting, risk assessment |
| **ETDA** | Electronic Transactions Development Agency B.E. 2563 | E-transaction standards, digital signature requirements |

### Compliance Timeline

| Year | Compliance Milestone | Cost |
|------|---------------------|------|
| Year 1 | Basic security practices | ฿100k |
| Year 2 | PDPA + Cybersecurity Act + ETDA | ฿3.5M |
| Year 2-3 | ISO27001 certification | ฿3M |
| Years 2-5 | Annual security audits | ฿2M |
| **Total** | | **฿8.6M** |

---

## 5-Year Financial Summary

| Year | Income | Spending | Cumulative |
|------|--------|----------|------------|
| Year 1 | ฿195M | ฿3M | ฿3M |
| Year 2 | - | ฿38M | ฿41M |
| Year 3 | - | ฿15M | ฿56M |
| Year 4 | - | ฿15M | ฿71M |
| Year 5 | - | ฿15M | ฿86M |

**Total Spend:** ~฿86M  
**Margin:** ฿195M - ฿86M = ฿109M (56%)

---

## Year 1 Phase Breakdown

### Phase 1: Pilot (Month 1-3)

| Category | Cost |
|----------|------|
| Hardware (11 AIOs) | ฿110,000 |
| Cloud VMs (3 months) | ฿300,000 |
| GPU Inference (Modal) | ฿150,000 |
| Deployment & Training | ฿150,000 |
| Contractor (1 dev) | ฿90,000 |
| **Phase 1 Total** | **฿800,000** |

### Phase 2: Validate (Month 4-6)

| Category | Cost |
|----------|------|
| Cloud VMs (3 months) | ฿300,000 |
| GPU Inference | ฿150,000 |
| Load Testing | ฿50,000 |
| Security Audit | ฿100,000 |
| **Phase 2 Total** | **฿600,000** |

### Phase 3: Rollout (Month 7-12)

| Category | Cost |
|----------|------|
| Hardware (51 AIOs) | ฿510,000 |
| Cloud VMs (6 months) | ฿350,000 |
| GPU Inference | ฿200,000 |
| Deployment & Training | ฿160,000 |
| **Phase 3 Total** | **฿1,220,000** |

### Year 1 Total

| Phase | Cost |
|-------|------|
| Phase 1: Pilot | ฿800,000 |
| Phase 2: Validate | ฿600,000 |
| Phase 3: Rollout | ฿1,220,000 |
| **Year 1 Total** | **฿2,620,000** |

---

## Year 1 Infrastructure (Cloud)

### NIPA Cloud VMs

| Server | Spec | Monthly | Year 1 |
|--------|------|---------|--------|
| LiveKit Server | 32 vCPU, 64GB | ฿54,400 | ฿650,000 |
| Agent VM | 48 vCPU, 96GB | ฿108,800 | ฿350,000 |
| **Total** | | **฿163,200** | **฿1,000,000** |

### GPU Inference (Modal/Runpod)

| Phase | Duration | Cost |
|-------|----------|------|
| Phase 1 | 3 months | ฿150,000 |
| Phase 2 | 3 months | ฿150,000 |
| Phase 3 | 6 months | ฿200,000 |
| **Total** | 12 months | **฿500,000** |

---

## Years 2-5: Owned Infrastructure

### Compute Servers (Year 2)

| Item | Qty | Unit | Total | Purpose |
|------|-----|------|-------|---------|
| **LiveKit Servers** | | | | |
| 2U Server (64-core AMD EPYC, 256GB RAM) | 2 | ฿800k | ฿1,600,000 | Video routing, 200+ concurrent |
| **Application Servers** | | | | |
| 2U Server (32-core, 128GB RAM) | 2 | ฿500k | ฿1,000,000 | Agent workers, API |
| **Database Servers** | | | | |
| 2U Server (16-core, 64GB RAM, 4TB NVMe) | 2 | ฿400k | ฿800,000 | PostgreSQL primary + replica |
| 1U Server (8-core, 32GB RAM) | 2 | ฿200k | ฿400,000 | Redis cache cluster |
| **Compute Total** | | | **฿3,800,000** | |

### GPU Servers (Year 2)

| Item | Qty | Unit | Total |
|------|-----|------|-------|
| NVIDIA B200 | 8 | ฿2.2M | ฿17,600,000 |
| 4U GPU Server (4x B200) | 2 | ฿800k | ฿1,600,000 |
| CPU (AMD EPYC 9654) | 2 | ฿300k | ฿600,000 |
| RAM (512GB DDR5) | 2 | ฿200k | ฿400,000 |
| **GPU Total** | | | **฿20,200,000** |

### Storage (Year 2)

| Item | Qty | Unit | Total |
|------|-----|------|-------|
| NVMe Storage Server (50TB) | 2 | ฿1.5M | ฿3,000,000 |

### Network (Year 2)

| Item | Qty | Unit | Total |
|------|-----|------|-------|
| 100G Core Switch | 2 | ฿400k | ฿800,000 |
| 25G ToR Switch | 2 | ฿200k | ฿400,000 |
| Cabling + SFP | 1 | ฿300k | ฿300,000 |
| **Network Total** | | | **฿1,500,000** |

### Datacenter Setup (Year 2)

| Item | Qty | Unit | Total |
|------|-----|------|-------|
| Rack + Power + Setup | 2 | ฿500k | ฿1,000,000 |

### Total Infrastructure (Year 2)

| Category | Amount |
|----------|--------|
| Compute Servers | ฿3,800,000 |
| GPU Servers | ฿20,200,000 |
| Storage | ฿3,000,000 |
| Network | ฿1,500,000 |
| Datacenter Setup | ฿1,000,000 |
| **Total** | **฿29,500,000** |

---

## Why Own All Infrastructure?

| Reason | Cloud (Year 1) | Owned (Year 2+) |
|--------|----------------|-----------------|
| PDPA Compliance | ❌ Data may leave Thailand | ✅ Data stays in Thailand |
| Cost (5 years) | ฿25M+ (renting) | ฿29.5M (owned, 1-time) |
| Control | ❌ Vendor dependent | ✅ Full control |
| Latency | ~50ms | ~5ms |
| Security | Shared responsibility | Full control |
| Government Trust | ❌ Foreign cloud | ✅ Thai-owned |

---

## Team Details (Years 2-5)

### Year 2: 5 Engineers (฿4.8M)

| Role | Count | Monthly | Annual |
|------|-------|---------|--------|
| Senior Software Engineer | 2 | ฿100k | ฿2,400,000 |
| DevOps Engineer | 1 | ฿80k | ฿960,000 |
| AI/ML Engineer | 1 | ฿120k | ฿1,440,000 |
| **Total** | 4 | | **฿4,800,000** |

### Year 3: 10 Engineers (฿9.6M)

| Role | Count | Monthly | Annual |
|------|-------|---------|--------|
| Senior Software Engineer | 4 | ฿100k | ฿4,800,000 |
| DevOps Engineer | 2 | ฿80k | ฿1,920,000 |
| AI/ML Engineer | 2 | ฿120k | ฿2,880,000 |
| **Total** | 8 | | **฿9,600,000** |

### Year 4-5: 13 Engineers (฿12.5M)

| Role | Count | Monthly | Annual |
|------|-------|---------|--------|
| Senior Software Engineer | 5 | ฿100k | ฿6,000,000 |
| DevOps Engineer | 2 | ฿80k | ฿1,920,000 |
| AI/ML Engineer | 2 | ฿120k | ฿2,880,000 |
| QA Engineer | 2 | ฿60k | ฿1,440,000 |
| Operations Manager | 1 | ฿100k | ฿1,200,000 |
| Support Specialist | 1 | ฿40k | ฿480,000 |
| **Total** | 13 | | **฿13,920,000** |

*Budgeted at ฿12.5M assuming retention benefits and no recruitment costs*

---

## Spending by Category

```
Infrastructure: ███████████████████████████████████ 34% (฿29.5M)
Team:           ████████████████████████████████████████ 42% (฿36M)
Compliance:     ██████████ 10% (฿8.5M)
Operations:     █████ 5% (฿4.5M)
Cloud Y1:       ██ 2% (฿1.7M)
Hardware:       █ 1% (฿0.6M)
Contingency:    ██████ 6% (฿5.2M)
```

---

## NIPA Cloud Pricing (Year 1)

| Service | Price |
|---------|-------|
| Compute (1:2 vCPU:RAM) | ฿1,700/vCPU/month |
| Object Storage | ฿0.77/GB/month |
| Domestic Bandwidth | FREE |
| International Egress | ฿2.31/GiB |

---

## Colocation Costs (Year 2+)

| Item | Monthly | Annual |
|------|---------|--------|
| Rack Space (2 racks) | ฿100,000 | ฿1,200,000 |
| Power (20kW) | ฿80,000 | ฿960,000 |
| Bandwidth (1Gbps) | ฿50,000 | ฿600,000 |
| **Total** | **฿230,000** | **฿2,760,000** |

---

## Assumptions

- B200 GPU: ~฿2.2M each (~$65k USD)
- AMD EPYC server: ~฿800k for 64-core
- Thai senior engineer: ฿80k-120k/month
- Bangkok office: ฿100k/month
- Colocation: ฿50k/rack/month
- 6 prisons, 10,000 prisoners
- Peak: 100 concurrent calls
- 8x B200 + 8 compute servers for full Thai sovereignty
