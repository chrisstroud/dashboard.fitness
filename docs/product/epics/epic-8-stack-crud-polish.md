# Epic 8: Stack Management + Polish

**PRD Reference:** [Habit Stacks](../prd/prd-habit-stacks.md)
**Architecture:** [Habit Stacks](../architecture/arch-habit-stacks.md)
**Status:** Not Started
**Owner:** Chris

---

## Overview

Add stack CRUD operations (create, rename, delete) via context menus, cross-stack/section move actions, and visual polish (stack completion ring, haptic feedback on drag).

### Value

Epics 6-7 render and reorder stacks, but users can't create, rename, or delete them yet. This epic completes the stack management story and adds the finishing touches that make the interaction feel native.

### Success Criteria

- [ ] Section header "…" menu includes "Add Habit Stack"
- [ ] Stack header "…" menu includes "Rename" and "Delete Stack"
- [ ] Deleting a stack moves its protocols to the section's default stack
- [ ] Deleting the last stack in a section is prevented
- [ ] (P1) Protocol row context menu includes "Move to…" with stack picker
- [ ] (P1) Stack header context menu includes "Move to Section…"
- [ ] (P1) Stack header shows completion ring
- [ ] (P1) Drag actions trigger haptic feedback

---

## Scope

### In Scope
- Stack creation from section context menu (alert with name field)
- Stack rename from stack context menu (alert with text field)
- Stack deletion with protocol reassignment (confirmation + API call)
- Default stack enforcement (prevent deleting last stack)
- (P1) Move protocol between stacks — context menu with stack picker
- (P1) Move stack between sections — context menu with section picker
- (P1) Stack completion ring on header
- (P1) Haptic feedback on drag pickup/drop

### Out of Scope
- Stack collapse/expand toggle (P2)
- Stack description/cue text field (P2)
- Bulk complete stack (P2)
- Daily page reorder (P2)

### Dependencies
- Epic 5: `DELETE /api/protocols/groups/{id}` endpoint
- Epic 6: Stack headers must exist to attach context menus
- Epic 7: Reorder infrastructure (for haptic feedback integration)

---

## Stories

| ID | Story | Points | Status |
|----|-------|--------|--------|
| 8.1 | Stack CRUD — Create, Rename, Delete from Context Menus | 5 | Not Started |
| 8.2 | Cross-Moves + Completion Ring + Haptics | 3 | Not Started |

---

## Technical Context

### Affected Components
- `ios/Dashboard Fitness/Views/MasterTemplateEditor.swift`
- `ios/Dashboard Fitness/Views/HomeTab.swift` (completion ring on Daily page stack headers)
- `ios/Dashboard Fitness/Services/SyncService.swift` (delete sync)

### Key Files
- `ios/Dashboard Fitness/Views/MasterTemplateEditor.swift` — context menus on section and stack headers
- `ios/Dashboard Fitness/Views/HomeTab.swift` — `DailyStackHeader` completion ring
- `ios/Dashboard Fitness/Models/UserProtocol.swift` — `ProtocolGroup` model (for local operations)

### Architecture Notes
Stack CRUD is local-first: create/rename write to SwiftData immediately, then sync. Deletion calls the server endpoint (to handle protocol reassignment atomically), then refreshes local state. Context menus use SwiftUI's `.contextMenu { }` modifier on the stack header views created in Epic 6.

---

## Context Digest

> Compressed from PRD and Architecture. Read these for full detail:
> - PRD: `docs/product/prd/prd-habit-stacks.md`
> - Architecture: `docs/product/architecture/arch-habit-stacks.md`

### Decisions Affecting This Epic
- **Stack CRUD:** Local-first for create/rename. Server-first for delete (to handle protocol reassignment atomically).
- **Delete safety:** Last stack in a section cannot be deleted. Protocols reassigned to first remaining stack (by position).
- **Cross-moves:** Context menu actions, not drag targets. Simpler and more reliable than cross-section drag.
- **Naming:** "Habit Stack" in UI labels, `ProtocolGroup` in code.

### Scope for This Epic
- In: Stack create/rename/delete, cross-moves (P1), completion ring (P1), haptics (P1)
- Out: Stack collapse/expand, stack description field, bulk complete

### Data Model
No changes. Uses existing:
- `ProtocolGroup(name: String, position: Int, section: ProtocolSection?)`
- `UserProtocol.group: ProtocolGroup?`

### API Surface
Consumes (from Epic 5):
- `DELETE /api/protocols/groups/{id}` — reassigns protocols, returns 204 or 400
Existing endpoints:
- `POST /api/protocols/sections/{id}/groups` — create group (stack)
- Group rename: extend with `PATCH /api/protocols/groups/{id}` or handle locally

### UI Changes

**Section header context menu (extend existing "…" menu):**
```swift
Menu {
    Button { showingAddProtocol = true } label: {
        Label("Add Protocol", systemImage: "plus.circle")
    }
    Button { createStack(in: section) } label: {       // ← NEW
        Label("Add Habit Stack", systemImage: "square.stack")
    }
    // ... existing rename/delete section items
}
```

**Stack header context menu (new):**
```swift
HabitStackHeader(stack: stack, section: section)
    .contextMenu {
        Button { addProtocol(to: stack) } label: {
            Label("Add Protocol Here", systemImage: "plus.circle")
        }
        Button { renameStack(stack) } label: {
            Label("Rename", systemImage: "pencil")
        }
        // P1: Move to Section
        Button { moveStack(stack) } label: {
            Label("Move to Section…", systemImage: "folder")
        }
        Button(role: .destructive) { deleteStack(stack, in: section) } label: {
            Label("Delete Stack", systemImage: "trash")
        }
    }
```

**Protocol row context menu (P1):**
```swift
ProtocolRow(proto: proto)
    .contextMenu {
        Button { moveProtocol(proto) } label: {
            Label("Move to Stack…", systemImage: "arrow.right.square")
        }
    }
```

**Stack completion ring (P1):**
```swift
// In HabitStackHeader
let completionRate = Double(completedCount) / Double(totalCount)
ZStack {
    Circle().stroke(Color(.systemGray5), lineWidth: 2)
    Circle().trim(from: 0, to: completionRate)
        .stroke(.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .rotationEffect(.degrees(-90))
}
.frame(width: 20, height: 20)
```

**Haptic feedback (P1):**
```swift
// In onMove handlers
UIImpactFeedbackGenerator(style: .light).impactOccurred()  // on pickup
UIImpactFeedbackGenerator(style: .medium).impactOccurred() // on drop
```

### Patterns to Follow

Existing alert pattern for section rename in MasterTemplateEditor:
```swift
.alert("Rename Section", isPresented: Binding(...)) {
    TextField("Section name", text: $newSectionName)
    Button("Rename") { /* ... */ }
    Button("Cancel", role: .cancel) { }
}
```

Stack create/rename uses the same alert pattern. Stack delete uses a confirmation dialog:
```swift
.confirmationDialog("Delete Stack?", isPresented: $showingDeleteConfirm) {
    Button("Delete", role: .destructive) { /* ... */ }
}
```

### Dependencies
- Requires: Epic 5 (DELETE endpoint), Epic 6 (stack headers to attach menus), Epic 7 (reorder infra for haptics)
- Provides: Complete stack management — the final Habit Stacks epic

---

## Risks

| Risk | Mitigation |
|------|------------|
| Delete stack fails server-side but local state expects success | Show error alert. Refresh local state from server on failure. |
| Cross-stack move changes protocol's group FK — sync might revert | Write locally + PATCH position immediately (same as reorder). Eventually consistent. |
| Context menu on stack header conflicts with drag gesture | Context menu is long-press + hold. Drag is long-press + move. iOS distinguishes these natively. Test on device. |

---

## Progress Log

| Date | Update |
|------|--------|
| 2026-04-11 | Epic created |
