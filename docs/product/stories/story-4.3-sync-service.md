# Story 4.3: SyncService Updates — Completions + Protocol-Documents

**Epic:** [Epic 4: Today & Navigation](../epics/epic-4-today-navigation.md)
**Status:** Not Started
**Points:** 3

---

## User Story

**As a** user
**I want** my completion history and document attachments synced between device and server
**So that** analytics are accurate and documents appear on the right protocols

---

## Acceptance Criteria

- [ ] **AC1:** `SyncService.syncAll()` includes completion sync and protocol-document sync
- [ ] **AC2:** Completing a protocol locally pushes to `POST /api/protocols/{id}/complete`
- [ ] **AC3:** Protocol completions pulled from API populate local `ProtocolCompletion` SwiftData records
- [ ] **AC4:** Protocol-document links synced: local model reflects server-side attachments
- [ ] **AC5:** Sync failures are non-blocking — app works with stale local data
- [ ] **AC6:** New type fields (`type`, `activityType`, `durationMinutes`) synced on protocol pull

---

## Technical Context

### Files to Modify
| File | Purpose | Changes |
|------|---------|---------|
| `ios/Dashboard Fitness/Services/SyncService.swift` | Sync orchestration | Add `syncCompletions()`, `syncProtocolDocuments()`, update protocol mapping |

### Implementation Guidance

1. **On protocol sync** — include new fields in the protocol JSON → SwiftData mapping
2. **On task completion** — after local status update, fire POST to completions endpoint
3. **On full sync** — pull recent completions (last 30 days) and upsert into local `ProtocolCompletion` records
4. **Protocol-documents** — pull linked doc IDs per protocol, update local relationships

Pattern: match existing `syncAll()` fetch-and-merge approach. Each sync method is independent — failure in one doesn't block others.

### Gotchas
- Don't sync ALL completions — limit to last 90 days for performance
- Handle offline: queue completion writes, push on next sync
- `ProtocolCompletion` upsert: match on `(protocolId, date)` since user is implicit

---

## Dependencies

### Blocked By
- Story 1.2: iOS models
- Story 2.1: Completion endpoints
- Story 2.3: Document linking endpoints

### Blocks
- Nothing — this is the integration glue

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Full sync cycle tested: launch app → sync → data appears → complete task → syncs to server
- [ ] Offline completion queues and syncs when connectivity returns
- [ ] File size within limits
