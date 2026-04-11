# Story 2.1: Protocol Completion Endpoints

**Epic:** [Epic 2: API Layer](../epics/epic-2-api-layer.md)
**Status:** Not Started
**Points:** 3

---

## User Story

**As a** user
**I want to** mark protocols complete and view my completion history
**So that** my per-protocol tracking data is persistent and accurate

---

## Acceptance Criteria

- [ ] **AC1:** `POST /api/protocols/{id}/complete` creates a `protocol_completions` record for today
- [ ] **AC2:** POST accepts optional body: `{ status, duration_minutes, calories, avg_heart_rate, notes, metadata }`
- [ ] **AC3:** POST returns 409 if already completed today (idempotent — use upsert pattern)
- [ ] **AC4:** `DELETE /api/protocols/{id}/complete?date=YYYY-MM-DD` removes completion record
- [ ] **AC5:** `GET /api/protocols/{id}/history?from=&to=&limit=` returns completion records
- [ ] **AC6:** All endpoints scoped to authenticated user (`g.user_id`)
- [ ] **AC7:** Completing via daily task update (`PUT /daily/task/{id}`) also writes `protocol_completions`

---

## Technical Context

### Files to Modify
| File | Purpose | Changes |
|------|---------|---------|
| `api/routes/protocols.py` | Protocol endpoints | Add complete, undo, history endpoints |
| `api/services/daily.py` | Daily task logic | Modify task status update to dual-write completions |

### Implementation Guidance

1. **Complete endpoint** — upsert pattern:
   ```python
   @protocols_bp.route("/protocol/<protocol_id>/complete", methods=["POST"])
   def complete_protocol(protocol_id):
       # Verify protocol belongs to user (via group → section → user_id)
       # Upsert: INSERT ... ON CONFLICT (protocol_id, user_id, date) DO UPDATE
       # Return completion record
   ```

2. **Dual-write on daily task update** — in existing `update_task_status()`:
   ```python
   if new_status == "completed" and task.source_protocol_id:
       # Create/update protocol_completions record
   elif new_status != "completed" and task.source_protocol_id:
       # Remove protocol_completions record for today
   ```

3. **History endpoint** — simple paginated query with date range filter.

### Gotchas
- Protocol ownership check: protocol → group → section → user_id (3 joins). Consider adding `user_id` directly to protocols table in future.
- Date parameter on DELETE should default to today if not provided
- SQLite doesn't support `ON CONFLICT ... DO UPDATE` the same way as Postgres — use `db.session.merge()` or check-then-insert pattern

---

## Dependencies

### Blocked By
- Story 1.1: Models + migration

### Blocks
- Story 2.2: Analytics reads from completions
- Story 4.3: SyncService needs these endpoints

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Endpoints tested via curl
- [ ] Dual-write verified: completing a daily task creates a protocol_completion
- [ ] PEP 8, type hints on all new functions
