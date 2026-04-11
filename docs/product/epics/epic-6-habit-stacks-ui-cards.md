# Epic 6: UI — Habit Stack Cards + Page Parity

**PRD Reference:** [Habit Stacks](../prd/prd-habit-stacks.md)
**Architecture:** [Habit Stacks](../architecture/arch-habit-stacks.md)
**Status:** Not Started
**Owner:** Chris

---

## Overview

Re-introduce the Habit Stack (group) visual layer on both My Protocols and Daily Today pages. Each stack renders as a card with a header and protocol rows. Both pages use identical hierarchy and styling. Single-stack sections collapse the stack header for backward compatibility.

### Value

This is the core visual change — transforms both pages from flat protocol lists into structured habit stacks. My Protocols and Daily Today become visually identical, eliminating the current layout mismatch. Users can see their behavioral chains grouped logically.

### Success Criteria

- [ ] My Protocols shows Section → Habit Stack card(s) → Protocol rows
- [ ] Daily Today shows the same hierarchy with identical card styling
- [ ] Single-stack sections (where stack name == section name) hide the stack header
- [ ] Adding a second stack to a section causes both stack headers to appear
- [ ] CreateProtocolSheet shows stack picker only when section has 2+ stacks
- [ ] Empty stacks show placeholder text

---

## Scope

### In Scope
- Shared `HabitStackCard` component (used by both pages)
- `MasterTemplateEditor` rewrite to render stacks between sections and protocols
- `HomeTab` / `DailySectionView` update to render `DailyGroup` level
- `mergedSections` restoration to include group-level merging
- `CreateProtocolSheet` stack picker (conditional)
- Single-stack collapsing logic
- Default stack enforcement (every section has at least one group)

### Out of Scope
- Drag-and-drop reorder (Epic 7)
- Stack CRUD — create/rename/delete (Epic 8)
- Stack context menus (Epic 8)
- Stack completion ring animation (Epic 8)

### Dependencies
- None — this is purely UI restructuring of existing data

---

## Stories

| ID | Story | Points | Status |
|----|-------|--------|--------|
| 6.1 | Shared HabitStackCard + HabitStackHeader Components | 3 | Not Started |
| 6.2 | MasterTemplateEditor Stack Card Layer | 5 | Not Started |
| 6.3 | HomeTab Group-Level Rendering + mergedSections Restore | 5 | Not Started |
| 6.4 | CreateProtocolSheet Stack Picker | 2 | Not Started |

---

## Technical Context

### Affected Components
- `ios/Dashboard Fitness/Views/HomeTab.swift`
- `ios/Dashboard Fitness/Views/MasterTemplateEditor.swift`
- `ios/Dashboard Fitness/Views/CreateProtocolSheet.swift`
- New shared components (HabitStackCard, HabitStackHeader)

### Key Files
- `ios/Dashboard Fitness/Views/HomeTab.swift` — `DailySectionView`, `DailyInstanceView.mergedSections`
- `ios/Dashboard Fitness/Views/MasterTemplateEditor.swift` — main list structure, `protocols(in:)` helper
- `ios/Dashboard Fitness/Views/CreateProtocolSheet.swift` — section picker, save flow
- `ios/Dashboard Fitness/Models/DailyInstance.swift` — `DailySection`, `DailyGroup` structs, `tasksBySections()`
- `ios/Dashboard Fitness/Models/UserProtocol.swift` — `ProtocolSection`, `ProtocolGroup`, `UserProtocol`

### Architecture Notes
The data model already supports this. `ProtocolSection.sortedGroups` and `ProtocolGroup.sortedProtocols` exist. `DailyInstance.tasksBySections()` already returns `DailySection → DailyGroup → DailyTask`. The current views flatten the group level — this epic restores it.

---

## Context Digest

> Compressed from PRD and Architecture. Read these for full detail:
> - PRD: `docs/product/prd/prd-habit-stacks.md`
> - Architecture: `docs/product/architecture/arch-habit-stacks.md`

### Decisions Affecting This Epic
- **Page parity:** My Protocols and Daily Today render identical hierarchy and styling
- **Single-stack collapsing:** `stackCount == 1 && stackName == sectionName` → hide stack header. Protocols render directly under section header in a single card.
- **Naming:** "Habit Stack" in UI, `ProtocolGroup` / `DailyGroup` in code
- **Stack card design:** Reuse `.regularMaterial` rounded-rect from existing `DailySectionView`

### Scope for This Epic
- In: Visual restructure of both pages, shared components, CreateProtocolSheet stack picker
- Out: Reorder (Epic 7), CRUD (Epic 8), API changes (Epic 5)

### Data Model
No changes. Existing structures used:

**SwiftData (My Protocols):**
```
ProtocolSection → .sortedGroups → [ProtocolGroup] → .sortedProtocols → [UserProtocol]
```

**Daily snapshot (Today):**
```
DailyInstance.tasksBySections() → [DailySection] → .groups → [DailyGroup] → .tasks → [DailyTask]
```

**Single-stack collapsing helper:**
```swift
func shouldCollapseStack(sectionName: String, stackName: String, stackCount: Int) -> Bool {
    stackCount == 1 && stackName == sectionName
}
```

### UI Changes

**My Protocols (MasterTemplateEditor) — current → target:**
```
List {
  ForEach(sections) { section in         // ← exists
    Section {
      ForEach(protocols(in: section))     // ← currently flattens groups
    }
  }
}

// BECOMES:

List {
  ForEach(sections) { section in
    Section {
      ForEach(section.sortedGroups) { stack in    // ← NEW: iterate groups
        if !shouldCollapse(section, stack) {
          HabitStackHeader(stack)                   // ← NEW: stack header
        }
        ForEach(stack.sortedProtocols) { proto in
          ProtocolRow(proto)
        }
      }
    }
  }
}
```

**Daily Today (DailySectionView) — current → target:**
```
// Currently: flat tasks list
ForEach(tasks) { task in DailyTaskRow(task) }

// BECOMES: group-level cards
ForEach(section.groups) { group in
  if !shouldCollapse(section, group) {
    DailyStackHeader(group)
  }
  VStack {
    ForEach(group.tasks) { task in DailyTaskRow(task) }
  }
  .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
}
```

**mergedSections (DailyInstanceView) — must merge at group level:**
```swift
// Current: merges sections only, ignores groups
// Target: for each section, merge master groups with task groups
if let existing = taskSectionByName[master.name] {
    var section = existing
    let existingGroupNames = Set(section.groups.map(\.name))
    for masterGroup in master.sortedGroups where !existingGroupNames.contains(masterGroup.name) {
        section.groups.append(DailyGroup(name: masterGroup.name, position: masterGroup.position, tasks: []))
    }
    section.groups.sort { $0.position < $1.position }
    result.append(section)
}
```

### Patterns to Follow

Existing card pattern from `DailySectionView`:
```swift
VStack(alignment: .leading, spacing: 0) {
    ForEach(...) { ... }
}
.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
.padding(.horizontal, 16)
```

Existing section header pattern:
```swift
HStack {
    Text(section.name.uppercased())
        .font(.caption.bold())
        .foregroundStyle(.secondary)
        .tracking(0.8)
    // ...
}
.padding(.horizontal, 20)
```

### Dependencies
- Requires: Nothing (data model already supports this)
- Provides: Visual foundation for Epic 7 (reorder) and Epic 8 (CRUD)

---

## Risks

| Risk | Mitigation |
|------|------------|
| Single-stack collapsing flicker when adding second stack | Use `withAnimation` on stack creation. The collapsing rule is deterministic — no ambiguity. |
| mergedSections group-level merge edge cases | Write clear unit-testable logic. Edge case: task group exists but master group doesn't (server-only data). Include in merge with fallback position. |
| MasterTemplateEditor List with nested ForEach rendering | SwiftUI List handles Section + ForEach nesting well. Keep ForEach IDs stable (use model .id). |

---

## Progress Log

| Date | Update |
|------|--------|
| 2026-04-11 | Epic created |
