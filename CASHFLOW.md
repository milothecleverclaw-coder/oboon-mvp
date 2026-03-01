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

### Objective
Deploy and validate the complete Oboon system in a single prison to prove technical feasibility and identify operational issues before full rollout.

### Scope
- **1 Prison** (~1,667 prisoners)
- **9 Prisoner AIOs** (video call kiosks)
- **2 Officer AIOs** (approval & scheduling management)

### Deliverables
| Deliverable | Description |
|-------------|-------------|
| LiveKit Server | Deployed on NIPA Cloud, fully configured |
| Agent VM | Video processing workers operational |
| GPU Inference | Modal/Runpod integration tested |
| AIO Hardware | 11 units installed and configured |
| Prisoner App | Working video calls from AIOs |
| Officer App | Relationship approval, scheduling |
| Basic Monitoring | System health dashboards |

### Key Activities
1. **Week 1-2:** Infrastructure setup (VMs, LiveKit, GPU integration)
2. **Week 3-4:** Hardware procurement and OS configuration
3. **Week 5-6:** On-site deployment at pilot prison
4. **Week 7-8:** Staff training and user testing
5. **Week 9-12:** Live operation, bug fixes, performance tuning

### Success Criteria
- [ ] 100+ successful video calls completed
- [ ] Average latency < 1 second
- [ ] Zero dropped calls during testing
- [ ] Officer approval workflow functional
- [ ] NSFW moderation working correctly

### Risk Mitigation
| Risk | Mitigation |
|------|------------|
| Network issues at prison | Test bandwidth before deployment |
| Hardware failures | Keep 1-2 spare AIOs on-site |
| Staff resistance | Hands-on training sessions |

### Costs

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

### Objective
Refine the system based on pilot feedback, optimize performance, and prepare infrastructure for full-scale deployment across all 6 prisons.

### Scope
- Continue pilot prison operation
- Load testing and optimization
- Backend hardening
- Documentation and runbooks

### Deliverables
| Deliverable | Description |
|-------------|-------------|
| Performance Report | Benchmark results, bottlenecks identified |
| Optimized Backend | Tuned for 200+ concurrent calls |
| Deployment Playbook | Step-by-step rollout guide |
| Monitoring Alerts | Automated incident detection |
| Staff Training Materials | Videos, manuals, quick-start guides |
| Security Audit | Vulnerability assessment passed |

### Key Activities
1. **Week 1-3:** Analyze pilot data, identify improvements
2. **Week 4-6:** Backend optimization (caching, connection pooling)
3. **Week 7-9:** Load testing (simulate 200+ concurrent calls)
4. **Week 10-12:** Documentation and training material creation
5. **Ongoing:** Security hardening, compliance review

### Success Criteria
- [ ] System handles 200 concurrent calls
- [ ] Average latency < 800ms under load
- [ ] 99.9% uptime during testing period
- [ ] All critical bugs from pilot resolved
- [ ] Deployment playbook approved

### Risk Mitigation
| Risk | Mitigation |
|------|------------|
| Scaling bottlenecks | Load test early, identify limits |
| Security vulnerabilities | Third-party audit |
| Feature creep | Lock scope, defer to later phases |

### Costs

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

### Objective
Deploy Oboon to all 6 prisons, train staff at each location, and achieve full operational capacity for 10,000 prisoners.

### Scope
- **5 Remaining Prisons** (~8,333 prisoners)
- **41 Prisoner AIOs**
- **10 Officer AIOs**
- Full production deployment

### Deliverables
| Deliverable | Description |
|-------------|-------------|
| 6 Live Prisons | All locations operational |
| 52 AIOs Deployed | All hardware installed and working |
| Trained Staff | Officers at all prisons trained |
| Production Monitoring | 24/7 system visibility |
| Incident Response Plan | Escalation procedures |
| User Guides | Prisoner and officer documentation |

### Key Activities
1. **Week 1-2:** Bulk hardware procurement (51 AIOs)
2. **Week 3-4:** Pre-deployment configuration (OS, apps, network)
3. **Week 5-8:** Prison 2 deployment + training
4. **Week 9-12:** Prison 3 deployment + training
5. **Week 13-16:** Prison 4 deployment + training
6. **Week 17-20:** Prison 5 deployment + training
7. **Week 21-24:** Prison 6 deployment + training
8. **Ongoing:** Support, bug fixes, optimization

### Deployment Schedule
| Prison | Deployment | Training | Go-Live |
|--------|------------|----------|---------|
| Prison 2 | Week 5-6 | Week 7 | Week 8 |
| Prison 3 | Week 9-10 | Week 11 | Week 12 |
| Prison 4 | Week 13-14 | Week 15 | Week 16 |
| Prison 5 | Week 17-18 | Week 19 | Week 20 |
| Prison 6 | Week 21-22 | Week 23 | Week 24 |

### Success Criteria
- [ ] All 6 prisons operational
- [ ] 500+ successful calls per week across all prisons
- [ ] Staff satisfaction > 80%
- [ ] System uptime > 99.5%
- [ ] Zero critical security incidents

### Risk Mitigation
| Risk | Mitigation |
|------|------------|
| Hardware delays | Order early, buffer stock |
| Prison network issues | Pre-deployment site survey |
| Staff turnover | Record training videos |
| Budget overrun | Phased deployment, pause if needed |

### Costs

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

### Objective
Scale the family-facing application to support 50,000 registered users, with full evidence submission, approval workflows, and self-service scheduling.

### Scope
- **50,000 Family Accounts** (5x prisoner count)
- **Evidence Upload System** (ID docs, relationship proof)
- **Approval Workflow** (officers review submissions)
- **Self-Service Scheduling** (families book time slots)
- **Mobile Apps** (iOS/Android polished releases)

### Deliverables
| Deliverable | Description |
|-------------|-------------|
| Family App v1.0 | iOS & Android production release |
| User Registration | Google OAuth, profile creation |
| Evidence System | Upload, storage, officer review |
| Notification System | Call reminders, approval status |
| Scheduling Portal | Families book available slots |
| Help Center | FAQs, video tutorials, support chat |

### Key Activities
1. **Week 1-4:** User registration + OAuth integration
2. **Week 5-8:** Evidence upload + storage system
3. **Week 9-12:** Officer approval workflow enhancements
4. **Week 13-16:** Self-service scheduling for families
5. **Week 17-20:** Mobile app polish + app store optimization
6. **Week 21-28:** Gradual user onboarding (10k → 50k users)
7. **Week 29-36:** Support scaling, feedback iteration

### User Growth Timeline
| Month | Registered Families | Active Weekly |
|-------|---------------------|---------------|
| Month 10 | 5,000 | 1,000 |
| Month 12 | 15,000 | 5,000 |
| Month 14 | 30,000 | 12,000 |
| Month 16 | 45,000 | 20,000 |
| Month 18 | 50,000 | 25,000 |

### Success Criteria
- [ ] 50,000 family accounts registered
- [ ] 90%+ evidence approval within 48 hours
- [ ] App store rating > 4.0 stars
- [ ] < 5% support ticket rate
- [ ] Scheduling system used by 80% of families

### Risk Mitigation
| Risk | Mitigation |
|------|------------|
| Slow adoption | Marketing campaign, prison outreach |
| Support overload | In-app help, chatbot |
| Evidence fraud | Manual review, ID verification |
| App store rejection | Follow guidelines, test thoroughly |

### Costs

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

### Objective
Maintain reliable service, handle ongoing support, perform regular updates, and ensure system health across all 6 prisons for the contract duration.

### Scope
- **24/7 System Monitoring**
- **Regular Software Updates**
- **Hardware Replacement**
- **User Support**
- **Performance Optimization**
- **Security Patches**

### Deliverables (Annual)
| Deliverable | Frequency |
|-------------|-----------|
| System Uptime Report | Monthly |
| Security Audit | Quarterly |
| Software Updates | As needed |
| Hardware Health Check | Quarterly |
| User Satisfaction Survey | Bi-annually |
| Performance Optimization | Ongoing |

### Operational Activities
| Activity | Frequency | Owner |
|----------|-----------|-------|
| Monitor system health | 24/7 | Automated + on-call |
| Respond to incidents | As needed | Support team |
| Deploy security patches | Monthly | Dev team |
| Hardware inspections | Quarterly | On-site team |
| User training refresh | Bi-annually | Training team |
| Database backups | Daily | Automated |
| Cost optimization review | Quarterly | Finance |

### Support Structure
| Level | Response Time | Issues |
|-------|---------------|--------|
| L1 (Helpdesk) | < 4 hours | User questions, password resets |
| L2 (Technical) | < 8 hours | Bugs, configuration issues |
| L3 (Engineering) | < 24 hours | Critical bugs, infrastructure |

### Maintenance Windows
- **Planned:** Sundays 2-4 AM (low usage)
- **Emergency:** As needed with 2-hour notice
- **Target Downtime:** < 4 hours/month

### Success Criteria
- [ ] 99.9% uptime annually
- [ ] < 2 critical incidents per year
- [ ] User satisfaction > 85%
- [ ] All security patches applied within 30 days
- [ ] Hardware replacement < 5% annually

### Risk Mitigation
| Risk | Mitigation |
|------|------------|
| Staff availability | Cross-training, documentation |
| Hardware failures | Spare stock, rapid replacement |
| Security threats | Regular audits, monitoring |
| Budget overruns | Quarterly reviews, contingency fund |

### Costs

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
