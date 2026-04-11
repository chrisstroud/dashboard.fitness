# Epic 7: Drag-and-Drop Reorder + Position Sync

**PRD Reference:** [Habit Stacks](../prd/prd-habit-stacks.md)
**Architecture:** [Habit Stacks](../architecture/arch-habit-stacks.md)
**Status:** Not Started
**Owner:** Chris

---

## Overview

Make sections, habit stacks, and protocols drag-reorderable on the My Protocols page. Position changes save locally to SwiftData immediately and sync to the server via the batch reorder API.

### Value

Currently there is no way to reorder anything — items are locked in creation order. This epic makes everything movable with zero extra taps (long-press + drag). Combined with Epic 6's stack cards, users can fully customize their daily structure.

### Success Criteria

- [ ] Sections can be reordered by dragging on My Protocols
- [ ] Habit stacks can be reordered within their section by dragging
- [ ] Protocols can be reordered within their stack by dragging
- [ ] Position changes persist across app restart
- [ ] Position changes sync to server via `PATCH /api/protocols/reorder`
- [ ] A full sync (`syncProtocols()`) does not reset locally-reordered positions before the PATCH completes

---

## Scope

### In Scope
- `.onMove` modifiers at all three `ForEach` levels in `MasterTemplateEditor`
- Edit mode management (toggle or persistent)
- Position update handlers that renumber affected items
- `SyncService.syncPositions()` — fire-and-forget batch PATCH
- Sync conflict handling (last writer wins)

### Out of Scope
- Reorder on Daily Today page (P2, deferred)
- Cross-stack protocol moves (Epic 8)
- Cross-section stack moves (Epic 8)
- Haptic feedback (Epic 8)

### Dependencies
- Epic 5: `PATCH /api/protocols/reorder` endpoint must exist
- Epic 6: Stack card layer must be rendered (can't reorder stacks if they're not visible)

---

## Stories

| ID | Story | Points | Status |
|----|-------|--------|--------|
| 7.1 | Three-Level onMove + Edit Mode on MasterTemplateEditor | 5 | Not Started |
| 7.2 | SyncService.syncPositions() + Conflict Handling | 3 | Not Started |

---

## Technical Context

### Affected Components
- `ios/Dashboard Fitness/Views/MasterTemplateEditor.swift`
- `ios/Dashboard Fitness/Services/SyncService.swift`

### Key Files
- `ios/Dashboard Fitness/Views/MasterTemplateEditor.swift` — List structure with nested ForEach
- `ios/Dashboard Fitness/Services/SyncService.swift` — new `syncPositions()` method, existing `syncProtocols()`

### Architecture Notes
SwiftUI `List` with `ForEach(...).onMove(perform:)` is the native reorder mechanism. It requires the view to be in edit mode (`EditButton()` in toolbar or `@Environment(\.editMode)`). Each `onMove` closure receives `IndexSet` (source) and `Int` (destination), which map directly to array reorder + position renumbering.

---

## Context Digest

> Compressed from PRD and Architecture. Read these for full detail:
> - PRD: `docs/product/prd/prd-habit-stacks.md`
> - Architecture: `docs/product/architecture/arch-habit-stacks.md`

### Decisions Affecting This Epic
- **Reorder surface:** My Protocols only (P0). Daily is read-only.
- **Mechanism:** SwiftUI `.onMove` on `ForEach` — native, battle-tested
- **Position sync:** Optimistic local → async PATCH. Fire-and-forget.
- **Conflict rule:** Server is source of truth. If PATCH fails, next `syncProtocols()` pulls server positions. Positions are low-stakes (cosmetic).

### Scope for This Epic
- In: `.onMove` at 3 levels, edit mode, position handlers, SyncService.syncPositions()
- Out: Cross-stack/section moves (Epic 8), Daily page reorder (P2)

### Data Model
No changes. Uses existing `position` fields:
- `ProtocolSection.position: Int`
- `ProtocolGroup.position: Int`
- `UserProtocol.position: Int`

### API Surface
Consumes (from Epic 5):
```
PATCH /api/protocols/reorder
Body: { sections?: [...], groups?: [...], protocols?: [...] }
Returns: 204
```

### UI Changes

**MasterTemplateEditor — add onMove to each ForEach level:**

```swift
@State private var editMode: EditMode = .inactive

List {
    ForEach(sections) { section in
        Section { ... }
    }
    .onMove(perform: moveSections)          // ← Level 1

    // Inside each section:
    ForEach(section.sortedGroups) { stack in
        ...
    }
    .onMove { indices, dest in              // ← Level 2
        moveStacks(indices, dest, in: section)
    }

    // Inside each stack:
    ForEach(stack.sortedProtocols) { proto in
        ProtocolRow(proto)
    }
    .onMove { indices, dest in              // ← Level 3
        moveProtocols(indices, dest, in: stack)
    }
}
.environment(\.editMode, $editMode)
.toolbar {
    ToolbarItem(placement: .primaryAction) { EditButton() }
}
```

**Reorder handlers:**
```swift
private func moveSections(_ indices: IndexSet, _ destination: Int) {
    var ordered = sections.sorted { $0.position < $1.position }
    ordered.move(fromOffsets: indices, toOffset: destination)
    for (i, section) in ordered.enumerated() { section.position = i }
    SyncService.shared.syncPositions(sections: ordered)
}

private func moveStacks(_ indices: IndexSet, _ destination: Int, in section: ProtocolSection) {
    var ordered = section.sortedGroups
    ordered.move(fromOffsets: indices, toOffset: destination)
    for (i, group) in ordered.enumerated() { group.position = i }
    SyncService.shared.syncPositions(groups: ordered)
}

private func moveProtocols(_ indices: IndexSet, _ destination: Int, in group: ProtocolGroup) {
    var ordered = group.sortedProtocols
    ordered.move(fromOffsets: indices, toOffset: destination)
    for (i, proto) in ordered.enumerated() { proto.position = i }
    SyncService.shared.syncPositions(protocols: ordered)
}
```

**SyncService.syncPositions():**
```swift
func syncPositions(sections: [ProtocolSection]? = nil, groups: [ProtocolGroup]? = nil, protocols: [UserProtocol]? = nil) {
    guard let token = AuthService.shared.token else { return }
    var body: [String: Any] = [:]
    if let sections { body["sections"] = sections.map { ["id": $0.id.uuidString, "position": $0.position] } }
    if let groups { body["groups"] = groups.map { ["id": $0.id.uuidString, "position": $0.position] } }
    if let protocols { body["protocols"] = protocols.map { ["id": $0.id.uuidString, "position": $0.position] } }
    Task {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/protocols/reorder")!)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }
}
```

### Patterns to Follow

Existing `onDelete` pattern in MasterTemplateEditor:
```swift
.onDelete { offsets in
    let items = protos
    for offset in offsets { modelContext.delete(items[offset]) }
}
```

The `onMove` pattern is parallel — same `ForEach` modifier, receives `IndexSet` + `Int`.

### Dependencies
- Requires: Epic 5 (API reorder endpoint), Epic 6 (stack card layer visible in List)
- Provides: Reorderable UI that Epic 8 enhances with cross-moves and haptics

---

## Risks

| Risk | Mitigation |
|------|------------|
| `onMove` in nested `ForEach` within `List` sections may conflict | SwiftUI handles this natively. Each `ForEach` gets its own `onMove`. Test on device — Simulator drag behaves differently. |
| Edit mode shows delete buttons alongside drag handles | Use `deleteDisabled(true)` on sections/stacks (only protocols should be deletable via swipe). Or keep edit mode toggled and use `moveDisabled()` selectively. |
| `@Query` sort order fights manual reorder | `@Query(sort: \ProtocolSection.position)` should reflect new positions immediately since SwiftData writes are synchronous. Verify in testing. |

---

## Progress Log

| Date | Update |
|------|--------|
| 2026-04-11 | Epic created |
