# Epic 3: UI — Protocol Detail View with Analytics & Documents

**PRD Reference:** [Protocols v2](../prd/prd-protocols-v2.md)
**Architecture:** [Protocols v2](../architecture/arch-protocols-v2.md)
**Status:** Not Started
**Owner:** Chris

---

## Overview

Build the new Protocol Detail View — the central screen for each protocol. Shows type-aware content: analytics (streak, completion rate, calendar heatmap), attached documents, and type-specific actions. Also includes the Create Protocol sheet with type picker.

### Value

This is where the "first-class citizen" experience lives. Every protocol gets its own rich detail page instead of being a flat row in a checklist. Users can see their consistency, reference their notes, and take type-specific actions — all from one screen.

### Success Criteria

- [ ] Protocol detail view displays current streak, longest streak, 7d/30d completion rate
- [ ] Calendar heatmap shows 30-day completion pattern
- [ ] Attached documents listed and viewable inline (markdown rendering)
- [ ] User can attach/detach documents from protocol detail
- [ ] Workout protocols show activity type, duration, frequency target
- [ ] Task protocols show streak badge and completion history
- [ ] Create Protocol sheet has type picker (workout/task) with type-specific fields
- [ ] SwiftUI previews render for both types with hardcoded data

---

## Scope

### In Scope
- `ProtocolDetailView` (rewrite from current minimal view)
- `ProtocolAnalyticsCard` component
- `CalendarHeatmap` component
- `ProtocolDocumentsSection` component
- `CreateProtocolSheet` with type picker
- SwiftUI previews for all new views

### Out of Scope
- HealthKit workout session (Phase 2 — detail will show a placeholder "Start Workout" that doesn't connect to HealthKit yet)
- Interactive widgets (Phase 2)
- Drag-and-drop reorder (Phase 3)

### Dependencies
- Epic 1: SwiftData models
- Epic 2: Analytics + document endpoints
- Epic 4 (parallel): Can develop independently; detail view is pushed from task row

---

## Stories

| ID | Story | Points | Status |
|----|-------|--------|--------|
| 3.1 | Protocol analytics card + calendar heatmap components | 3 | Not Started |
| 3.2 | Protocol documents section (view, attach, detach, create) | 3 | Not Started |
| 3.3 | Protocol detail view assembly — type-aware layout | 3 | Not Started |
| 3.4 | Create Protocol sheet with type picker | 2 | Not Started |

---

## Technical Context

### Affected Components
- `ios/Dashboard Fitness/Views/HomeTab.swift` — existing `ProtocolDetailView` (currently minimal)
- New: `ios/Dashboard Fitness/Views/ProtocolAnalyticsCard.swift`
- New: `ios/Dashboard Fitness/Views/CalendarHeatmap.swift`
- New: `ios/Dashboard Fitness/Views/ProtocolDocumentsSection.swift`
- New: `ios/Dashboard Fitness/Views/CreateProtocolSheet.swift`
- `ios/Dashboard Fitness/Services/SyncService.swift` — fetch analytics + documents

### Architecture Notes
Analytics fetched from API on view appear, not stored locally (computed server-side). Documents fetched via protocol-documents endpoint. State via `@State` for local UI + `@Query` for SwiftData reads. Detail view is push destination from DailyTaskRow and MasterTemplateEditor.

---

## Context Digest

### UI Changes

```
ProtocolDetailView
├── Header (icon + label + type badge)
├── ProtocolAnalyticsCard
│   ├── StreakDisplay (current + longest)
│   ├── CompletionRates (7d, 30d pills)
│   └── CalendarHeatmap (30-day grid)
├── ProtocolDocumentsSection
│   ├── DocumentRow (tap → MarkdownView)
│   └── AddDocumentButton (sheet)
├── type == "workout"
│   ├── Activity type + duration + frequency
│   └── StartWorkoutButton (placeholder in Phase 1)
└── type == "task"
    └── CompletionHistoryList (recent completions)
```

### Patterns to Follow
- Card pattern: see `CollapsibleGroupCard` in `HomeTab.swift` — `.regularMaterial` background, rounded rectangle
- Markdown rendering: see `MarkdownView` (existing component)
- Sheet pattern: see existing `.sheet` modifiers in `MasterTemplateEditor.swift`

### Dependencies
- Requires: Epic 1 (models), Epic 2 (analytics + doc endpoints)
- Provides: Detail destination for Epic 4 (task row tap)

---

## Risks

| Risk | Mitigation |
|------|------------|
| Analytics API latency causes visible loading spinner | Fetch on appear with placeholder shimmer. Cache last-known values in SwiftData. |
| Calendar heatmap performance with many days | Limit to 30 days. Fixed grid layout, no dynamic sizing. |
| Document attachment UX is confusing | Simple sheet with existing doc picker + "New Document" option. Match Apple Notes attachment pattern. |

---

## Progress Log

| Date | Update |
|------|--------|
| 2026-04-11 | Epic created |
