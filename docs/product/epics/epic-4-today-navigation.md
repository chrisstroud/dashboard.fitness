# Epic 4: UI — Type-Aware Today View & Navigation Cleanup

**PRD Reference:** [Protocols v2](../prd/prd-protocols-v2.md)
**Architecture:** [Protocols v2](../architecture/arch-protocols-v2.md)
**Status:** Not Started
**Owner:** Chris

---

## Overview

Update the Today tab to render type-aware protocol rows (workout card vs task checkbox), remove the Docs tab, surface orphan documents from the protocols view, and update the sync service to handle completions and protocol-document links.

### Value

This is where the user experiences the type system daily. Workout protocols look and feel different from tasks. The Docs tab disappearing simplifies the app's navigation model. Sync updates make the whole system work end-to-end.

### Success Criteria

- [ ] Workout-type tasks render with activity icon, duration badge, and frequency dots
- [ ] Task-type tasks render with streak badge
- [ ] Completing a task in Today view also writes a `protocol_completions` record (via API)
- [ ] Docs tab is removed from tab bar
- [ ] Orphan documents accessible from MasterTemplateEditor ("Notes" section)
- [ ] SyncService syncs completions and protocol-document links
- [ ] Groups display as "Stacks" in UI labels

---

## Scope

### In Scope
- `DailyTaskRow` type-aware rendering
- Remove Docs tab from `ContentView`
- Orphan documents section in MasterTemplateEditor
- SyncService updates for completions + protocol-documents
- "Stacks" label in UI (groups already ordered by position)

### Out of Scope
- Protocol detail view content (Epic 3)
- Habit stacking sequential flow (Phase 3)
- Notifications (Phase 3)

### Dependencies
- Epic 1: SwiftData models (type field on DailyTask)
- Epic 2: API endpoints (completion dual-write, orphan docs)
- Epic 3 (parallel): Detail view is separate; task row navigates to it

---

## Stories

| ID | Story | Points | Status |
|----|-------|--------|--------|
| 4.1 | Type-aware DailyTaskRow — workout card vs task checkbox | 3 | Not Started |
| 4.2 | Remove Docs tab + orphan docs in MasterTemplateEditor | 2 | Not Started |
| 4.3 | SyncService updates — completions + protocol-documents | 3 | Not Started |

---

## Technical Context

### Affected Components
- `ios/Dashboard Fitness/Views/HomeTab.swift` — `DailyTaskRow`, section headers
- `ios/Dashboard Fitness/ContentView.swift` — remove Docs tab
- `ios/Dashboard Fitness/Views/MasterTemplateEditor.swift` — add orphan docs section
- `ios/Dashboard Fitness/Services/SyncService.swift` — sync completions + doc links

### Key Files
- `HomeTab.swift` `DailyTaskRow` (line ~493) — needs type branching
- `ContentView.swift` (line ~11) — remove `DocsTab()` tab
- `SyncService.swift` — add `syncCompletions()`, `syncProtocolDocuments()`

### Architecture Notes
DailyTask now has `type` field populated by `refresh_today()`. Task rows branch on type for rendering. Completion sync is bidirectional: local completion → API POST → API writes `protocol_completions`. On sync-all, pull recent completions to populate SwiftData `ProtocolCompletion` records.

---

## Context Digest

### UI Changes
- `DailyTaskRow`: workout type shows activity icon (figure.run, figure.strengthtraining, etc.), estimated duration pill, weekly frequency dots. Task type shows streak count badge.
- `ContentView`: 3 tabs (Today, History, Settings) instead of 4
- `MasterTemplateEditor`: new "Notes" section at bottom with orphan documents
- Section headers: "STACKS" labeling for groups (cosmetic)

### Patterns to Follow
- Task row pattern: see existing `DailyTaskRow` in `HomeTab.swift`
- Workout frequency dots: see existing `WorkoutSlots` in `HomeTab.swift`
- Sync pattern: see existing `SyncService.syncAll()` for fetch-and-merge approach

### Dependencies
- Requires: Epic 1 (models), Epic 2 (API)
- Provides: Complete Phase 1 user experience

---

## Risks

| Risk | Mitigation |
|------|------------|
| Removing Docs tab breaks navigation for existing users | Orphan docs are still accessible from MasterTemplateEditor. No data loss. |
| Type field missing on DailyTask for existing instances | Default to "task" if type is nil. Server stamps type on refresh. |
| Sync complexity increases with completions + doc links | Separate sync methods. Each is independent — failure in one doesn't block others. |

---

## Progress Log

| Date | Update |
|------|--------|
| 2026-04-11 | Epic created |
