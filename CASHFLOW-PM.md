# Oboon Prison Video Call System - Deployment Plan

> **Scope:** 6 prisons, 10,000 prisoners  
> **Contract Duration:** 5 years  
> **Last Updated:** March 2026

---

## Overview

| Metric | Value |
|--------|-------|
| Total Prisoners | 10,000 |
| Number of Prisons | 6 |
| Prisoner Call Kiosks | 50 (200:1 ratio) |
| Officer Management Tablets | 12 (2 per prison) |
| Total Devices | 62 |
| Expected Family Accounts | 50,000 |
| Peak Concurrent Calls | ~100 |

---

## Phase 1: Pilot (Months 1-3)

### Objective
Deploy and validate the complete system in a single prison to prove technical feasibility and identify operational issues before full rollout.

### Scope
- 1 Prison (~1,667 prisoners)
- 9 Prisoner Call Kiosks
- 2 Officer Management Tablets

### Deliverables
| Deliverable | Description |
|-------------|-------------|
| Video Call Server | Cloud infrastructure operational |
| AI Moderation | Content scanning integration tested |
| Call Kiosks | 9 units installed and configured |
| Prisoner App | Working video calls from kiosks |
| Officer App | Relationship approval, scheduling |
| Basic Monitoring | System health dashboards |

### Key Activities
1. Week 1-2: Cloud infrastructure setup
2. Week 3-4: Hardware procurement and configuration
3. Week 5-6: On-site deployment at pilot prison
4. Week 7-8: Staff training and user testing
5. Week 9-12: Live operation, bug fixes, tuning

### Success Criteria
- [ ] 100+ successful video calls completed
- [ ] Average latency < 1 second
- [ ] Zero dropped calls during testing
- [ ] Officer approval workflow functional
- [ ] AI moderation working correctly

### Risk Mitigation
| Risk | Mitigation |
|------|------------|
| Network issues at prison | Pre-deployment bandwidth test |
| Hardware failures | Keep spare units on-site |
| Staff resistance | Hands-on training sessions |

### Budget
| Category | Cost |
|----------|------|
| Hardware (11 devices) | £2,530 |
| Cloud Infrastructure (3 months) | £2,800 |
| GPU/AI Processing (3 months) | £340 |
| Storage | £15 |
| Travel, Deployment, Testing | £1,500 |
| Contingency (10%) | £800 |
| **Phase 1 Total** | **£8,000** |

---

## Phase 2: Validation (Months 4-6)

### Objective
Refine the system based on pilot feedback, optimize performance, and prepare for full-scale deployment.

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
1. Week 1-3: Analyze pilot data, identify improvements
2. Week 4-6: Backend optimization
3. Week 7-9: Load testing (simulate 200+ concurrent calls)
4. Week 10-12: Documentation and training material creation
5. Ongoing: Security hardening, compliance review

### Success Criteria
- [ ] System handles 200 concurrent calls
- [ ] Average latency < 800ms under load
- [ ] 99.9% uptime during testing period
- [ ] All critical bugs from pilot resolved
- [ ] Deployment playbook approved

### Budget
| Category | Cost |
|----------|------|
| Cloud Infrastructure (3 months) | £2,820 |
| GPU/AI Processing (3 months) | £680 |
| Storage | £30 |
| Load Testing, Tuning | £500 |
| Contingency (10%) | £350 |
| **Phase 2 Total** | **£4,400** |

---

## Phase 3: Full Rollout (Months 7-12)

### Objective
Deploy to all 6 prisons, train staff at each location, and achieve full operational capacity for 10,000 prisoners.

### Scope
- 5 Remaining Prisons (~8,333 prisoners)
- 41 Prisoner Call Kiosks
- 10 Officer Management Tablets
- Full production deployment

### Deliverables
| Deliverable | Description |
|-------------|-------------|
| 6 Live Prisons | All locations operational |
| 52 Devices Deployed | All hardware installed and working |
| Trained Staff | Officers at all prisons trained |
| Production Monitoring | 24/7 system visibility |
| Incident Response Plan | Escalation procedures |
| User Guides | Prisoner and officer documentation |

### Deployment Schedule
| Prison | Deployment | Training | Go-Live |
|--------|------------|----------|---------|
| Prison 2 | Week 5-6 | Week 7 | Week 8 |
| Prison 3 | Week 9-10 | Week 11 | Week 12 |
| Prison 4 | Week 13-14 | Week 15 | Week 16 |
| Prison 5 | Week 17-18 | Week 19 | Week 20 |
| Prison 6 | Week 21-22 | Week 23 | Week 24 |

### Key Activities
1. Week 1-2: Bulk hardware procurement (51 devices)
2. Week 3-4: Pre-deployment configuration
3. Week 5-24: Sequential prison deployments + training
4. Ongoing: Support, bug fixes, optimization

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

### Budget
| Category | Cost |
|----------|------|
| Hardware (51 devices) | £11,730 |
| Cloud Infrastructure (6 months) | £5,640 |
| GPU/AI Processing (6 months) | £1,360 |
| Storage | £90 |
| Travel, Setup (5 prisons) | £3,000 |
| Training Materials | £1,500 |
| Contingency (10%) | £2,000 |
| **Phase 3 Total** | **£25,300** |

---

## Phase 4: Family App Scale (Months 10-18)

### Objective
Scale the family-facing application to support 50,000 registered users, with full evidence submission, approval workflows, and self-service scheduling.

### Scope
- 50,000 Family Accounts
- Evidence Upload System
- Approval Workflow
- Self-Service Scheduling
- Mobile Apps (iOS/Android)

### Deliverables
| Deliverable | Description |
|-------------|-------------|
| Family App v1.0 | iOS & Android production release |
| User Registration | Google OAuth, profile creation |
| Evidence System | Upload, storage, officer review |
| Notification System | Call reminders, approval status |
| Scheduling Portal | Families book available slots |
| Help Center | FAQs, video tutorials, support chat |

### User Growth Timeline
| Month | Registered Families | Active Weekly |
|-------|---------------------|---------------|
| Month 10 | 5,000 | 1,000 |
| Month 12 | 15,000 | 5,000 |
| Month 14 | 30,000 | 12,000 |
| Month 16 | 45,000 | 20,000 |
| Month 18 | 50,000 | 25,000 |

### Key Activities
1. Week 1-4: User registration + OAuth integration
2. Week 5-8: Evidence upload + storage system
3. Week 9-12: Officer approval workflow enhancements
4. Week 13-16: Self-service scheduling for families
5. Week 17-20: Mobile app polish + app store optimization
6. Week 21-28: Gradual user onboarding (10k → 50k users)
7. Week 29-36: Support scaling, feedback iteration

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

### Budget
| Category | Cost |
|----------|------|
| Cloud Infrastructure (9 months) | £8,460 |
| GPU/AI Processing (9 months) | £2,040 |
| Storage (500GB target) | £270 |
| Marketing, Launch, Support | £1,000 |
| Contingency (10%) | £730 |
| **Phase 4 Total** | **£12,500** |

---

## Phase 5: Operations (Years 2-5)

### Objective
Maintain reliable service, handle ongoing support, perform regular updates, and ensure system health across all 6 prisons.

### Scope
- 24/7 System Monitoring
- Regular Software Updates
- Hardware Replacement
- User Support
- Performance Optimization
- Security Patches

### Deliverables (Annual)
| Deliverable | Frequency |
|-------------|-----------|
| System Uptime Report | Monthly |
| Security Audit | Quarterly |
| Software Updates | As needed |
| Hardware Health Check | Quarterly |
| User Satisfaction Survey | Bi-annually |
| Performance Optimization | Ongoing |

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

### Budget (4 Years)
| Category | Annual | 4 Years |
|----------|--------|---------|
| Cloud Infrastructure | £11,280 | £45,120 |
| GPU/AI Processing | £1,200 | £4,800 |
| Storage | £120 | £480 |
| Hardware Replacements | £1,000 | £4,000 |
| Software Updates | £500 | £2,000 |
| Support Staff | £1,000 | £4,000 |
| Contingency | £1,000 | £4,000 |
| **Phase 5 Total** | **£16,100/yr** | **£64,400** |

---

## Cash Flow Timeline

| Phase | Months | Spend | Cumulative |
|-------|--------|-------|------------|
| 1. Pilot | 1-3 | £8,000 | £8,000 |
| 2. Validation | 4-6 | £4,400 | £12,400 |
| 3. Rollout | 7-12 | £25,300 | £37,700 |
| 4. Family Scale | 10-18 | £12,500 | £50,200 |
| 5. Operations | Year 2-5 | £64,400 | £114,600 |

---

## When Money Is Needed

| Milestone | When | Amount Needed |
|-----------|------|---------------|
| Start Pilot | Day 1 | £8,000 |
| Start Validation | Month 4 | £4,400 |
| Buy Bulk Hardware | Month 7 | £12,000 |
| Complete Rollout | Month 7-12 | £13,300 |
| Year 2 Ops | Month 13 | £16,000/yr |
| Years 3-5 | Ongoing | £16,000/yr |

**Peak cash need:** Month 7-12 (hardware procurement + full infrastructure)

---

## Hardware Summary

| Item | Quantity | Purpose |
|------|----------|---------|
| Prisoner Call Kiosk | 50 | Video call stations for prisoners |
| Officer Management Tablet | 12 | Approval, scheduling, management |
| **Total Devices** | **62** | |

---

## Assumptions

- Operating hours: 9am-4pm (6 hours/day), lunch break excluded
- Call frequency: 2 meetings/month per prisoner, 20 min each
- Peak concurrent calls: ~100 (based on scheduling)
- Video streaming: Domestic traffic only (Thailand)
- AI processing: Cloud-based, international traffic required
- Exchange rate: 1 GBP ≈ 43 THB

---

## Budget Summary

| Category | Amount |
|----------|--------|
| Hardware (62 devices) | £14,260 |
| Cloud Infrastructure (5 years) | £56,400 |
| AI Processing (5 years) | £8,180 |
| Storage (5 years) | £540 |
| Deployment, Training, Support | £22,000 |
| Contingency | £13,000 |
| **Total 5-Year Spend** | **~£114,600** |
