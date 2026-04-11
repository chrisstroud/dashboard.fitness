# Story 2.2: Analytics Service + Endpoint

**Epic:** [Epic 2: API Layer](../epics/epic-2-api-layer.md)
**Status:** Not Started
**Points:** 3

---

## User Story

**As a** user
**I want to** see my streak, completion rates, and history for each protocol
**So that** I can track my consistency and identify patterns

---

## Acceptance Criteria

- [ ] **AC1:** `GET /api/protocols/{id}/analytics` returns `{ current_streak, longest_streak, rate_7d, rate_30d, total_completions, last_completed }`
- [ ] **AC2:** Current streak = consecutive days with `status='completed'` ending today or yesterday
- [ ] **AC3:** Longest streak = max consecutive completed days ever
- [ ] **AC4:** 7d/30d rate = completed days / expected days in window (accounting for `weekly_target`)
- [ ] **AC5:** For protocols with `weekly_target`: expected = target * weeks in window (not every day)
- [ ] **AC6:** Endpoint returns within 200ms for 90 days of data

---

## Technical Context

### New Files to Create
| File | Purpose |
|------|---------|
| `api/services/analytics.py` | Streak computation, rate calculation, analytics aggregation |

### Files to Modify
| File | Purpose | Changes |
|------|---------|---------|
| `api/routes/protocols.py` | Protocol endpoints | Add analytics endpoint calling service |

### Implementation Guidance

```python
# api/services/analytics.py
def compute_analytics(protocol_id: str, user_id: str) -> dict:
    completions = ProtocolCompletion.query.filter_by(
        protocol_id=protocol_id, user_id=user_id, status="completed"
    ).order_by(ProtocolCompletion.date.desc()).limit(90).all()
    
    dates = {c.date for c in completions}
    today = date.today()
    
    # Current streak
    current_streak = 0
    check_date = today
    # If not completed today, check from yesterday
    if today not in dates:
        check_date = today - timedelta(days=1)
    while check_date in dates:
        current_streak += 1
        check_date -= timedelta(days=1)
    
    # Longest streak (iterate all sorted dates)
    # ... standard consecutive-days algorithm
    
    # Rates — account for weekly_target
    protocol = Protocol.query.get(protocol_id)
    if protocol.weekly_target:
        expected_7d = protocol.weekly_target
        expected_30d = protocol.weekly_target * 4  # approximate
    else:
        expected_7d = 7
        expected_30d = 30
    
    completed_7d = len([d for d in dates if d >= today - timedelta(days=7)])
    completed_30d = len([d for d in dates if d >= today - timedelta(days=30)])
    
    return {
        "current_streak": current_streak,
        "longest_streak": longest_streak,
        "rate_7d": min(completed_7d / max(expected_7d, 1), 1.0),
        "rate_30d": min(completed_30d / max(expected_30d, 1), 1.0),
        "total_completions": len(completions),
        "last_completed": completions[0].date.isoformat() if completions else None,
    }
```

### Gotchas
- Weekly target protocols: a 3x/week protocol shouldn't show 57% rate after 4/7 days — rate should be 4/3 = 100%+, capped at 1.0
- Streak for weekly protocols: count "weeks with at least N completions" not consecutive days
- Limit query to 90 days to bound performance

---

## Dependencies

### Blocked By
- Story 1.1: Models
- Story 2.1: Completions must exist to compute analytics

### Blocks
- Story 3.1: Analytics card needs this data

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Analytics tested with various scenarios (0 completions, daily streak, weekly protocol, gap days)
- [ ] PEP 8, type hints
- [ ] Response time < 200ms on test data
