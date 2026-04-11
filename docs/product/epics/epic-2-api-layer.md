# Epic 2: API Layer — Completion, Analytics & Document Linking Endpoints

**PRD Reference:** [Protocols v2](../prd/prd-protocols-v2.md)
**Architecture:** [Protocols v2](../architecture/arch-protocols-v2.md)
**Status:** Not Started
**Owner:** Chris

---

## Overview

Build the API endpoints for protocol completion tracking, per-protocol analytics computation, protocol-document linking, and update existing protocol CRUD to handle the new type system fields.

### Value

The API layer is the bridge between data and UI. Without these endpoints, the iOS app can't write completions, read analytics, or manage document attachments. This epic makes the type system operational.

### Success Criteria

- [ ] POST/DELETE `/api/protocols/{id}/complete` writes/removes completion records
- [ ] GET `/api/protocols/{id}/analytics` returns streak, 7d/30d rates, total completions
- [ ] POST/DELETE `/api/protocols/{id}/documents` attaches/detaches documents
- [ ] GET `/api/documents/orphans` returns unattached documents
- [ ] Protocol CRUD accepts `type`, rejects type changes on existing protocols
- [ ] Daily task status updates also write `protocol_completions`
- [ ] `refresh_today()` stamps type info on DailyTask

---

## Scope

### In Scope
- New analytics service (`services/analytics.py`)
- New completion endpoints (complete, undo, history)
- New analytics endpoint
- New document linking endpoints (attach, detach, list, orphans)
- Modified protocol CRUD (new fields, type immutability)
- Modified daily task update (dual-write to `protocol_completions`)
- Modified `refresh_today()` (stamp type on DailyTask)

### Out of Scope
- iOS UI (Epics 3-4)
- HealthKit workout metadata on completion (Phase 2)
- Notification scheduling (Phase 3)

### Dependencies
- Epic 1: Data layer must be complete (models + migration)

---

## Stories

| ID | Story | Points | Status |
|----|-------|--------|--------|
| 2.1 | Protocol completion endpoints — complete, undo, history | 3 | Not Started |
| 2.2 | Analytics service + endpoint — streaks, rates, totals | 3 | Not Started |
| 2.3 | Protocol-document linking endpoints | 2 | Not Started |
| 2.4 | Modified protocol CRUD + daily task type stamping | 2 | Not Started |

---

## Technical Context

### Affected Components
- `api/routes/protocols.py`
- `api/routes/documents.py`
- `api/services/daily.py`
- New: `api/services/analytics.py`

### Key Files
- `api/routes/protocols.py` — add completion, analytics, document endpoints; modify CRUD
- `api/services/daily.py` — modify `refresh_today()` to stamp type
- `api/services/analytics.py` — new: streak computation, rate calculation

### Architecture Notes
All endpoints behind existing JWT `before_request` guard. Analytics computed on-read from `protocol_completions`, not cached. Dual-write on task completion: DailyTask status + ProtocolCompletion record.

---

## Context Digest

### Decisions Affecting This Epic
- Analytics computed, not stored — compute from `protocol_completions` on each request
- Type immutability — `type` field rejected on PUT if different from current value
- Dual-write — daily task status change also creates/updates `protocol_completions`

### API Surface
| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/protocols/{id}/complete` | Mark complete for today |
| DELETE | `/api/protocols/{id}/complete` | Undo completion |
| GET | `/api/protocols/{id}/analytics` | Streak, rates, totals |
| GET | `/api/protocols/{id}/history` | Completion records |
| POST | `/api/protocols/{id}/documents` | Attach document |
| DELETE | `/api/protocols/{id}/documents/{doc_id}` | Detach document |
| GET | `/api/protocols/{id}/documents` | List attached docs |
| GET | `/api/documents/orphans` | Unattached documents |

### Patterns to Follow
- Endpoint pattern: see `api/routes/protocols.py` existing CRUD
- Service pattern: see `api/services/daily.py` for query + commit patterns

### Dependencies
- Requires: Epic 1 (data models)
- Provides: API for Epics 3, 4 (iOS views + sync)

---

## Risks

| Risk | Mitigation |
|------|------------|
| Analytics query slow on large completion history | Index on (protocol_id, user_id, date). Limit streak lookback to 90 days. |
| Dual-write consistency (DailyTask + ProtocolCompletion) | Both writes in same transaction. If ProtocolCompletion fails, DailyTask rolls back. |
| Orphan doc query slow with many documents | Simple LEFT JOIN exclusion query; performant with index on protocol_documents.document_id |

---

## Progress Log

| Date | Update |
|------|--------|
| 2026-04-11 | Epic created |
