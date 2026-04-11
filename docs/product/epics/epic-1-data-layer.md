# Epic 1: Data Layer — Protocol Type System & Completion History

**PRD Reference:** [Protocols v2](../prd/prd-protocols-v2.md)
**Architecture:** [Protocols v2](../architecture/arch-protocols-v2.md)
**Status:** Not Started
**Owner:** Chris

---

## Overview

Add the protocol type system, completion history tracking, and protocol-document linking to both backend (PostgreSQL) and frontend (SwiftData) data layers. Includes the Alembic migration, SwiftData model updates, and data backfill for existing records.

### Value

Every subsequent epic depends on this. No analytics, no type-aware UI, no document attachment, and no HealthKit integration are possible until the data model supports types, completions, and document links.

### Success Criteria

- [ ] Backend migration runs cleanly on Railway production database
- [ ] All existing protocols have `type='task'` after migration
- [ ] Workout documents are migrated to workout-type protocols with linked docs
- [ ] iOS app launches without SwiftData migration errors
- [ ] New `protocol_completions` and `protocol_documents` tables exist and accept writes

---

## Scope

### In Scope
- Alembic migration: new columns on `protocols` and `daily_tasks`, new `protocol_completions` and `protocol_documents` tables
- Data backfill: existing protocols → `type='task'`, workout docs → workout protocols
- SwiftData model updates: `UserProtocol`, `DailyTask`, new `ProtocolCompletion`
- SQLAlchemy model updates: `Protocol`, `DailyTask`, new `ProtocolCompletion`, `ProtocolDocument`

### Out of Scope
- API endpoints (Epic 2)
- UI changes (Epics 3-4)
- HealthKit (Phase 2)

### Dependencies
- None — this is the foundation epic

---

## Stories

| ID | Story | Points | Status |
|----|-------|--------|--------|
| 1.1 | Backend Alembic migration + SQLAlchemy models | 3 | Not Started |
| 1.2 | iOS SwiftData model updates | 2 | Not Started |
| 1.3 | Data backfill — migrate existing protocols and workout docs | 3 | Not Started |

---

## Technical Context

### Affected Components
- `api/models/protocol.py`
- `api/models/document.py`
- `api/migrations/versions/`
- `ios/Dashboard Fitness/Models/UserProtocol.swift`
- `ios/Dashboard Fitness/Models/DailyInstance.swift`
- `ios/Dashboard Fitness/Models/Document.swift`

### Key Files
- `api/models/protocol.py` — add columns to Protocol, DailyTask; new ProtocolCompletion, ProtocolDocument models
- `ios/Dashboard Fitness/Models/UserProtocol.swift` — add type, activityType, etc. to UserProtocol; new ProtocolCompletion model

### Architecture Notes
All changes are additive (new columns with defaults, new tables). No destructive changes. SwiftData lightweight migration handles additive properties. Alembic handles backend.

---

## Context Digest

> Compressed from PRD and Architecture. Read these for full detail:
> - PRD: `docs/product/prd/prd-protocols-v2.md`
> - Architecture: `docs/product/architecture/arch-protocols-v2.md`

### Decisions Affecting This Epic
- Type discrimination: `type` String column + nullable type-specific columns — no joins for common reads
- Completion tracking: New `protocol_completions` alongside DailyTask — DailyTask for today view, ProtocolCompletion for history
- Document attachment: Join table `protocol_documents` — many-to-many

### Data Model
See Architecture doc "Data Model" section for full schema.

### API Surface
None in this epic — models only.

### UI Changes
None in this epic — models only.

### Patterns to Follow
- SQLAlchemy model pattern: see existing `api/models/protocol.py` (string UUIDs, timezone-aware datetimes, cascade deletes)
- SwiftData model pattern: see existing `ios/Dashboard Fitness/Models/UserProtocol.swift` (@Model, @Attribute(.unique), @Relationship)

### Dependencies
- Requires: Nothing
- Provides: Data layer for Epics 2, 3, 4

---

## Risks

| Risk | Mitigation |
|------|------------|
| Alembic migration fails on production | Test against production data snapshot. Run in transaction. |
| SwiftData migration rejects additive properties | All new properties are optional/defaulted. If fails, can use SchemaMigrationPlan. Worst case: reset local store, re-sync from API. |
| Workout doc → protocol backfill creates duplicates | Use unique constraint on (group_id, label) to prevent doubles. Idempotent script. |

---

## Progress Log

| Date | Update |
|------|--------|
| 2026-04-11 | Epic created |
