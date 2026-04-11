# PRD: Habit Stacks — Atomic Habits-Driven Protocol Hierarchy

**Status:** Draft
**Date:** 2026-04-11
**Brief:** `briefs/brief-habit-stacks.md`

---

## Executive Summary

### Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Grouping model | Section → Habit Stack → Protocol (3 levels) | Matches Atomic Habits' stacking model. "After [wake up], I do [Wake Up Stack]." Protocols chain within a stack. |
| Naming | "Habit Stack" in UI, `ProtocolGroup` in code | Reframe existing model — zero schema migration. Group already has section FK, position, name. |
| Default stacks | One auto-created per section, same name as section | Keeps simple cases simple. Single-stack sections hide the stack picker on add. |
| Reordering | Drag-and-drop on My Protocols for all three levels | Sections, stacks, and protocols all reorderable in-place. No "edit mode" required — long-press initiates drag. |
| Page parity | My Protocols and Daily Today render identical hierarchy and styling | One visual language. Section header → stack card(s) → protocol rows inside card. |
| Reorder persistence | Optimistic local update + PATCH to server | Position changes save to SwiftData immediately, then sync to API. Offline-friendly. |

### Scope

**In:** Habit Stack UI on both pages, drag-and-drop reorder at all three levels, stack CRUD (create/rename/delete), default stack auto-creation, stack completion progress, position sync API

**Out:** Sequential completion flow (auto-advance to next protocol), stack-level streaks/analytics, two-minute rule mode, notifications, cue/trigger metadata, temptation bundling

### Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Grouping levels visible | 1 (section → protocols) | 2 (section → stack card → protocols) |
| Reorderable elements | 0 | 3 (sections, stacks, protocols) |
| Taps to reorder a protocol | N/A (not possible) | 0 extra taps (long-press + drag) |
| Page layout parity | Different styling and hierarchy | Identical on both pages |
| Taps to add protocol (single-stack section) | 3 | 3 (no regression) |

---

## Problem Statement

The protocol hierarchy was flattened to Section → Protocol to fix UX bugs, but this loses the ability to express ordered behavioral chains — the mechanism behind habit stacking. A morning routine contains distinct sub-sequences (wake-up hygiene → supplements → mindfulness) that should be visually grouped and independently completable. Additionally, there is currently no way to reorder anything — sections, groups, or protocols are locked in creation order.

**Current workarounds:** Mental sequencing. Chris knows the stacks exist but the app shows a flat list. Reordering requires deleting and recreating items.

---

## User Stories

### US-1: Habit Stack Grouping

**As a** user **I want** my protocols organized into named stacks within each section **so that** I can see my morning routine as distinct behavioral chains (e.g., "Wake Up" stack and "Mindset" stack) rather than a flat list.

- [ ] AC1: My Protocols page shows Section → Habit Stack card(s) → Protocol rows
- [ ] AC2: Daily Today page shows the same hierarchy with identical styling
- [ ] AC3: Each stack card shows its name and completion count (e.g., "3/5")
- [ ] AC4: Completing all protocols in a stack shows a visual checkmark on the stack header
- [ ] AC5: Empty stacks show "No protocols — tap + to add one" placeholder text
- [ ] AC6: Sections with a single stack named identically to the section hide the stack header (visual simplification)

### US-2: Drag-and-Drop Reordering

**As a** user **I want** to rearrange sections, stacks, and protocols by dragging **so that** I can organize my day without deleting and recreating items.

- [ ] AC1: Long-press on a section header initiates section drag (reorder among other sections)
- [ ] AC2: Long-press on a stack card header initiates stack drag (reorder within its section)
- [ ] AC3: Long-press on a protocol row initiates protocol drag (reorder within its stack)
- [ ] AC4: Drag feedback shows the item lifting with a subtle shadow and the list reflows in real-time
- [ ] AC5: Dropping an item saves the new position immediately (no confirm button)
- [ ] AC6: Position changes persist across app restart (SwiftData + API sync)
- [ ] AC7: Reordering works on both My Protocols page (this is the canonical editing surface)

### US-3: Stack CRUD

**As a** user **I want** to create, rename, and delete habit stacks **so that** I can refine my routine structure over time.

- [ ] AC1: Section header "…" menu includes "Add Habit Stack" option
- [ ] AC2: Creating a stack requires only a name (added at the bottom of the section)
- [ ] AC3: Stack header "…" menu includes "Rename" with inline text field
- [ ] AC4: Stack header "…" menu includes "Delete Stack" (moves protocols to section's default stack, never deletes protocols)
- [ ] AC5: Deleting the last stack in a section is prevented (every section must have at least one stack)

### US-4: Default Stack Behavior

**As a** user **I want** sections to work simply by default **so that** I don't have to think about stacks until I need them.

- [ ] AC1: Creating a new section auto-creates one default stack with the same name
- [ ] AC2: Adding a protocol to a single-stack section skips the stack picker (auto-assigns)
- [ ] AC3: A section with one stack whose name matches the section name does not render a separate stack header — the section header is sufficient
- [ ] AC4: Once a user adds a second stack, both stacks render with their own headers
- [ ] AC5: The default seeded sections (Morning Routine, Evening Routine, Workouts) each have one default stack

### US-5: Protocol Addition with Stacks

**As a** user **I want** adding a protocol to remain fast even with the stack layer **so that** the hierarchy doesn't slow me down.

- [ ] AC1: "Add Protocol" sheet shows section picker, then stack picker (if section has multiple stacks)
- [ ] AC2: If a section has only one stack, the stack picker is hidden — feels like adding to the section directly
- [ ] AC3: Section header "…" → "Add Protocol Here" pre-selects that section
- [ ] AC4: Stack header "…" → "Add Protocol Here" pre-selects that section and stack
- [ ] AC5: New protocol is added at the bottom of its stack (highest position value)

---

## Functional Requirements

### P0 (Must Have)

- [ ] **Stack card UI on My Protocols:** Each stack renders as a rounded-rect card with header (name + completion count) and protocol rows inside. Matches current card styling from DailySectionView.
- [ ] **Stack card UI on Daily Today:** Identical layout. `DailyInstanceView` uses `mergedSections` → stacks → tasks hierarchy instead of flat section → tasks.
- [ ] **Single-stack collapsing:** Sections with one identically-named stack suppress the stack header — protocols appear directly under the section header (backward-compatible with current flat look).
- [ ] **Default stack auto-creation:** `seedDefaultSectionsIfNeeded()` ensures every section has at least one `ProtocolGroup`. New sections created by the user auto-get a default stack.
- [ ] **Stack CRUD:** Create, rename, delete stacks from section and stack context menus. Deletion moves orphan protocols to the section's first remaining stack.
- [ ] **Protocol add flow updated:** `CreateProtocolSheet` gains stack picker (visible only when target section has 2+ stacks). Pre-selection from context menus works.
- [ ] **Drag-and-drop sections:** `ForEach(sections) { ... }.onMove { }` on the sections list in My Protocols. Updates `position` on each affected `ProtocolSection`.
- [ ] **Drag-and-drop stacks:** `ForEach(stacks) { ... }.onMove { }` within each section. Updates `position` on each affected `ProtocolGroup`.
- [ ] **Drag-and-drop protocols:** `ForEach(protocols) { ... }.onMove { }` within each stack card. Updates `position` on each affected `UserProtocol`.
- [ ] **Position persistence:** All position changes write to SwiftData immediately. `SyncService` pushes updated positions to server.
- [ ] **API: Batch position update:** Single endpoint to update positions for a list of items (sections, stacks, or protocols) to avoid N individual PATCHes on reorder.
- [ ] **Server sync respects positions:** `syncProtocols()` preserves local position values and doesn't reset ordering on pull.

### P1 (Should Have)

- [ ] **Stack completion ring:** Small circular progress indicator on stack header (like the day-level ring, but per-stack).
- [ ] **Stack completion animation:** When all protocols in a stack are completed, the stack header shows a brief checkmark animation.
- [ ] **Move protocol between stacks:** Long-press context menu on a protocol row includes "Move to…" with stack picker. Allows cross-stack moves without delete/recreate.
- [ ] **Move stack between sections:** Long-press context menu on a stack header includes "Move to Section…" for cross-section reorganization.
- [ ] **Haptic feedback on drag:** Light impact on pickup, medium on drop.

### P2 (Nice to Have)

- [ ] **Collapse/expand stacks:** Tap stack header to toggle protocol visibility. Collapsed stacks show only the header with completion count.
- [ ] **Stack description field:** Optional subtitle on stack header for the cue/trigger ("After I wake up…").
- [ ] **Bulk complete stack:** Button or gesture to mark all protocols in a stack as complete at once.
- [ ] **Reorder on Daily page:** Allow drag-and-drop on the Today page too (currently My Protocols is the editing surface).

---

## Technical Considerations

### Affected Components

| Component | Change |
|-----------|--------|
| `ios/.../Views/HomeTab.swift` | `DailySectionView` → `DailySectionView` + `DailyStackCard`. Restore group-level rendering from `DailySection.groups`. Single-stack collapsing logic. |
| `ios/.../Views/MasterTemplateEditor.swift` | Re-introduce stack card layer between section and protocol rows. Stack CRUD (add/rename/delete) in context menus. `onMove` modifiers at all three levels. Edit mode for drag handles. |
| `ios/.../Views/CreateProtocolSheet.swift` | Add stack picker (conditional on multi-stack sections). Pre-selection support for section + stack context menu shortcuts. |
| `ios/.../Models/DailyInstance.swift` | `tasksBySections()` already produces `DailySection → DailyGroup → DailyTask`. Verify `mergedSections` in HomeTab uses the group level. |
| `ios/.../Models/UserProtocol.swift` | No schema changes. Possibly add `ProtocolGroup.subtitle` for stack descriptions (P2). |
| `ios/.../Services/SyncService.swift` | Add `syncPositions()` method for batch position updates. Ensure `syncProtocols()` doesn't overwrite local positions. |
| `api/routes/protocols.py` | New endpoint: `PATCH /api/protocols/reorder` for batch position updates. |
| `api/models/protocol.py` | No schema changes needed. `position` fields already exist on Section, Group, and Protocol. |

### Data Model Changes

**None required.** The existing schema already supports the full hierarchy:

```
ProtocolSection (position, name)
  └── ProtocolGroup (position, name, section_id)  ← this IS the Habit Stack
        └── UserProtocol (position, label, group_id)
```

`DailyTask` already stores `sectionName`, `sectionPosition`, `groupName`, `groupPosition`, and `position`. The daily snapshot already captures the full three-level hierarchy.

**Possible addition (P2):** `subtitle` field on `ProtocolGroup` / `protocol_groups` for stack description/cue text.

### API Changes

| Method | Endpoint | Purpose |
|--------|----------|---------|
| PATCH | `/api/protocols/reorder` | Batch position update. Body: `{ "sections": [{"id": "...", "position": 0}, ...], "groups": [...], "protocols": [...] }`. Only include items whose positions changed. |

Existing endpoints already handle group CRUD:
- `POST /api/protocols/sections/{id}/groups` — create group (= create stack)
- Extend with `PATCH /api/protocols/groups/{id}` — rename group
- Extend with `DELETE /api/protocols/groups/{id}` — delete group (reassign protocols)

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Drag-and-drop janky in List | M | M | Use `onMove` modifier (native SwiftUI) which handles reorder within `List` sections. Avoid custom gesture recognizers. Test on device early. |
| Sync conflicts on position | L | M | Optimistic local update. Server is source of truth on conflict — last writer wins. Positions are low-stakes (cosmetic, not data). |
| Single-stack collapsing edge cases | M | L | Clear rule: collapse only when `section.groups.count == 1 && group.name == section.name`. Unit test the condition. |
| Cross-stack protocol move complexity | L | M | P1 priority — ship basic same-stack reorder first (P0). Cross-stack move is a context menu action, not a drag target. |
| My Protocols EditMode interaction | M | L | SwiftUI `List` supports `EditButton()` with `onMove` and `onDelete`. Both can coexist in the same list. |

---

## References

- [Brief: Habit Stacks](../briefs/brief-habit-stacks.md) — Problem statement, Atomic Habits principle mapping
- [PRD: Protocols v2](prd-protocols-v2.md) — Parent feature, type system, analytics, HealthKit
- James Clear, *Atomic Habits* — Habit stacking (Ch. 5), Environment design (Ch. 6, 12), Four Laws (Ch. 3)
- Apple HIG — Lists, drag and drop, edit mode patterns
- Apple Developer Docs — `onMove`, `EditButton`, `moveDisabled()`, `List` with sections
