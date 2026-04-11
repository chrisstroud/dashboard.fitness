# Story 1.3: Data Backfill — Migrate Existing Protocols & Workout Docs

**Epic:** [Epic 1: Data Layer](../epics/epic-1-data-layer.md)
**Status:** Not Started
**Points:** 3

---

## User Story

**As a** user with existing protocols and workout documents
**I want to** have my data automatically migrated to the new type system
**So that** my existing protocols are typed correctly and workout docs become workout protocols

---

## Acceptance Criteria

- [ ] **AC1:** All existing protocols have `type='task'` after backfill
- [ ] **AC2:** Each Document in the "Workouts" folder becomes a new Protocol with `type='workout'`
- [ ] **AC3:** New workout protocols inherit `weekly_target`, `duration_minutes`, `activity_type` from their source Document
- [ ] **AC4:** New workout protocols are linked to their source Document via `protocol_documents`
- [ ] **AC5:** Existing `workout_completions` are copied to `protocol_completions` mapped to the new workout protocols
- [ ] **AC6:** New workout protocols are placed in a "Training" section (create if needed)
- [ ] **AC7:** Backfill is idempotent — running twice doesn't create duplicates
- [ ] **AC8:** Backfill runs as part of Alembic migration (data migration in `upgrade()`)

---

## Technical Context

### Files to Modify
| File | Purpose | Changes |
|------|---------|---------|
| `api/migrations/versions/XXXX_protocols_v2.py` | Alembic migration | Add data backfill operations after schema changes |

### Implementation Guidance

The backfill runs inside the Alembic migration `upgrade()` function, after table/column creation:

1. **Set type on existing protocols:** `UPDATE protocols SET type = 'task' WHERE type IS NULL`
2. **Find workout documents:** Query documents where folder name = 'Workouts'
3. **For each workout document:**
   - Find or create a "Training" protocol section for the user
   - Find or create a "Workouts" protocol group in that section
   - Create a Protocol with `type='workout'`, copying `weekly_target`, `duration_minutes`, `activity_type`, `label=doc.title`
   - Create a `protocol_documents` link
   - Copy `workout_completions` rows to `protocol_completions`
4. **Idempotency:** Check if protocol with same label already exists in the group before creating

### Gotchas
- Use raw SQL via `op.execute()` in Alembic, not ORM (migration should not depend on model code)
- Workout documents may have NULL `activity_type` — default to 'strength'
- `workout_completions.document_id` maps to new `protocol_completions.protocol_id` (via the new protocol created from that document)
- Keep `workout_completions` table intact — deprecated but not dropped until Phase 2

---

## Dependencies

### Blocked By
- Story 1.1: Migration + models must exist first (same migration file, but schema changes run before data backfill)

### Blocks
- Epic 2: API needs typed protocols to exist

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Backfill tested on local SQLite with seed data
- [ ] Backfill tested on Railway Postgres snapshot
- [ ] Running migration twice doesn't duplicate data
