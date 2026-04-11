# Architecture: Habit Stacks — Section → Stack → Protocol Hierarchy

**PRD Reference:** `docs/product/prd/prd-habit-stacks.md`
**Date:** 2026-04-11
**Status:** Draft

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Data model | No changes — reuse `ProtocolSection → ProtocolGroup → UserProtocol` as-is | All three levels already have `position` fields. `DailyTask` already stores `groupName` + `groupPosition`. Zero migration. |
| "Habit Stack" identity | UI label only — code stays `ProtocolGroup`, `DailyGroup` | Avoids renaming across codebase. UI strings say "Habit Stack"; model layer unchanged. |
| Single-stack collapsing | `section.groups.count == 1 && group.name == section.name` → hide stack header | Backward-compatible with current flat look. Users who never add a second stack see no change. |
| Reorder mechanism | SwiftUI `List` + `.onMove` modifier on `ForEach` | Native, battle-tested. Requires `EditButton` or `editMode` binding. Handles all three levels within a `List`. |
| Reorder surface | My Protocols page only (P0). Daily page is read-only + check-off. | Keeps the editing surface in one place. Daily page reorder deferred to P2. |
| Position sync | Optimistic local write → `PATCH /api/protocols/reorder` batch endpoint | One API call per reorder gesture, not N. Offline-resilient — local positions are immediately correct. |
| Cross-stack move | Context menu "Move to…" (P1), not cross-section drag | Drag across sections is complex (different `ForEach` scopes). Context menu is reliable and discoverable. |
| Stack card design | Reuse `.regularMaterial` rounded-rect from existing `DailySectionView` | Visual consistency with current card styling. No new design tokens. |
| `mergedSections` restore groups | Merge at group level, not just section level | `tasksBySections()` already returns `DailySection.groups`. Current code ignores groups — restore them. |

---

## Data Model

### No Schema Changes

The full hierarchy already exists:

```
ProtocolSection        (id, name, position, user_id)
  └── ProtocolGroup    (id, name, position, section_id)     ← "Habit Stack" in UI
        └── UserProtocol (id, label, position, group_id)
```

`DailyTask` already captures:
```
sectionName, sectionPosition, groupName, groupPosition, label, position
```

`DailyInstance.tasksBySections()` already returns `[DailySection] → [DailyGroup] → [DailyTask]`.

**The only data-level addition (optional, P2):** `subtitle` on `ProtocolGroup` / `protocol_groups` for cue text ("After I wake up…").

### Seed Data Adjustment

`MasterTemplateEditor.seedDefaultSectionsIfNeeded()` already creates a `ProtocolGroup` for each section with the same name. This satisfies the "one default stack per section" rule. No change needed.

---

## API Design

### New Endpoint

| Method | Endpoint | Purpose |
|--------|----------|---------|
| PATCH | `/api/protocols/reorder` | Batch position update for sections, groups, and protocols |

**Request body:**

```json
{
  "sections": [
    { "id": "uuid", "position": 0 },
    { "id": "uuid", "position": 1 }
  ],
  "groups": [
    { "id": "uuid", "position": 0, "section_id": "uuid" },
    { "id": "uuid", "position": 1, "section_id": "uuid" }
  ],
  "protocols": [
    { "id": "uuid", "position": 0, "group_id": "uuid" },
    { "id": "uuid", "position": 1, "group_id": "uuid" }
  ]
}
```

All three arrays are optional — only include items whose positions changed. The `section_id`/`group_id` fields support cross-section stack moves and cross-stack protocol moves (P1).

**Response:** `204 No Content` on success.

**Implementation:**

```python
@protocols_bp.route("/reorder", methods=["PATCH"])
def reorder():
    data = request.get_json()
    user_id = g.user_id

    for s in data.get("sections", []):
        section = db.session.get(ProtocolSection, s["id"])
        if section and section.user_id == user_id:
            section.position = s["position"]

    for g_item in data.get("groups", []):
        group = db.session.get(ProtocolGroup, g_item["id"])
        if group and group.section.user_id == user_id:
            group.position = g_item["position"]
            if "section_id" in g_item:
                group.section_id = g_item["section_id"]

    for p in data.get("protocols", []):
        proto = db.session.get(UserProtocol, p["id"])
        if proto and proto.group.section.user_id == user_id:
            proto.position = p["position"]
            if "group_id" in p:
                proto.group_id = p["group_id"]

    db.session.commit()
    return "", 204
```

### Existing Endpoints Used

| Method | Endpoint | Used For |
|--------|----------|----------|
| POST | `/api/protocols/sections/{id}/groups` | Create new stack |
| POST | `/api/protocols/sections` | Create section (already idempotent) |
| DELETE | (new) `/api/protocols/groups/{id}` | Delete stack (reassign protocols) |

**Delete stack implementation** (new):

```python
@protocols_bp.route("/groups/<group_id>", methods=["DELETE"])
def delete_group(group_id):
    group = db.session.get(ProtocolGroup, group_id)
    if not group or group.section.user_id != g.user_id:
        return jsonify({"error": "Not found"}), 404

    section = group.section
    remaining = [g for g in section.groups if g.id != group.id]
    if not remaining:
        return jsonify({"error": "Cannot delete last stack in section"}), 400

    # Reassign orphan protocols to first remaining group
    target = sorted(remaining, key=lambda g: g.position)[0]
    max_pos = max((p.position for p in target.protocols), default=-1)
    for i, proto in enumerate(group.protocols):
        proto.group = target
        proto.position = max_pos + 1 + i

    db.session.delete(group)
    db.session.commit()
    return "", 204
```

### Authentication

No changes. Existing JWT guard on `protocols_bp` scopes by `g.user_id`.

---

## UI Components

### View Changes

| View | Change | Phase |
|------|--------|-------|
| `MasterTemplateEditor` | Re-introduce stack card layer. `ForEach(sections).onMove` + `ForEach(stacks).onMove` + `ForEach(protocols).onMove`. Stack CRUD in context menus. | P0 |
| `HomeTab` → `DailyInstanceView` | `mergedSections` returns groups. New `DailyStackCard` renders group-level cards. Single-stack collapsing. | P0 |
| `HomeTab` → `DailySectionView` | Refactor to render `DailyGroup` cards inside each section. | P0 |
| `CreateProtocolSheet` | Add stack picker (conditional: hidden if single-stack section). Accept `initialStack` for context menu shortcuts. | P0 |
| New: `HabitStackCard` | Shared card component used by both pages. Header (name + completion) + protocol rows. | P0 |
| New: `HabitStackHeader` | Stack name + completion count + context menu (rename, delete, add protocol). | P0 |

### UI Architecture

**View hierarchy (My Protocols page):**

```
NavigationStack
  List {
    ForEach(sections, onMove: moveSections) { section in     ← LEVEL 1: sections reorderable
      Section {
        ForEach(stacks, onMove: moveStacks) { stack in       ← LEVEL 2: stacks reorderable
          if !shouldCollapseStack(section, stack) {
            HabitStackHeader(stack, section)
          }
          ForEach(protocols, onMove: moveProtocols) { proto in ← LEVEL 3: protocols reorderable
            ProtocolRow(proto)
          }
          .onDelete { ... }
        }
      } header: {
        sectionHeader(section)
      }
    }
  }
  .environment(\.editMode, $editMode)
```

**View hierarchy (Daily Today page):**

```
ScrollView {
  VStack {
    DayHeader(instance)

    ForEach(mergedSections) { section in                    ← sections
      DailySectionHeader(section)

      ForEach(section.groups) { group in                    ← stacks (groups)
        if !shouldCollapseStack(section, group) {
          DailyStackHeader(group)
        }
        VStack {
          ForEach(group.tasks) { task in                    ← protocols (tasks)
            DailyTaskRow(task)
          }
        }
        .background(.regularMaterial, in: RoundedRectangle(...))
      }
    }
  }
}
```

**Single-stack collapsing rule** (shared helper):

```swift
func shouldCollapseStack(sectionName: String, stackName: String, stackCount: Int) -> Bool {
    stackCount == 1 && stackName == sectionName
}
```

When this returns `true`, the stack header is hidden. The stack's protocols render directly under the section header inside a single card — visually identical to today's flat layout.

### State Management

| State | Type | Where |
|-------|------|-------|
| Edit mode | `@State private var editMode: EditMode = .inactive` | `MasterTemplateEditor` |
| Sections | `@Query(sort: \ProtocolSection.position)` | Both pages |
| Stacks (groups) | `section.sortedGroups` (existing computed property) | Both pages |
| Protocols | `group.sortedProtocols` (existing computed property) | Both pages |
| Merged sections | Computed from `instance.tasksBySections()` + master sections | Daily page |

### `mergedSections` Restoration

Current code in `DailyInstanceView.mergedSections` flattens groups into a single tasks list. Restore the group level:

```swift
private var mergedSections: [DailySection] {
    let taskSections = instance.tasksBySections()  // already returns DailySection with .groups
    let taskSectionByName = Dictionary(uniqueKeysWithValues: taskSections.map { ($0.name, $0) })

    var result: [DailySection] = []
    var seenNames = Set<String>()

    for master in masterSections {
        guard !seenNames.contains(master.name) else { continue }
        seenNames.insert(master.name)

        if let existing = taskSectionByName[master.name] {
            // Use task section's groups (has actual tasks with status)
            // Merge in any master groups that have no tasks yet
            var section = existing
            let existingGroupNames = Set(section.groups.map(\.name))
            for masterGroup in master.sortedGroups where !existingGroupNames.contains(masterGroup.name) {
                section.groups.append(DailyGroup(name: masterGroup.name, position: masterGroup.position, tasks: []))
            }
            section.groups.sort { $0.position < $1.position }
            result.append(section)
        } else {
            // Section exists in master but has no daily tasks — show empty with group structure
            let emptyGroups = master.sortedGroups.map { DailyGroup(name: $0.name, position: $0.position, tasks: []) }
            result.append(DailySection(name: master.name, position: master.position, groups: emptyGroups))
        }
    }

    // Edge case: task sections not in master
    for section in taskSections where !seenNames.contains(section.name) {
        seenNames.insert(section.name)
        result.append(section)
    }

    return result.sorted { $0.position < $1.position }
}
```

### Reorder Handlers

Three handler functions on `MasterTemplateEditor`:

```swift
// MARK: - Reorder Handlers

private func moveSections(_ indices: IndexSet, _ destination: Int) {
    var ordered = sections.sorted { $0.position < $1.position }
    ordered.move(fromOffsets: indices, toOffset: destination)
    for (i, section) in ordered.enumerated() {
        section.position = i
    }
    syncPositions(sections: ordered)
}

private func moveStacks(_ indices: IndexSet, _ destination: Int, in section: ProtocolSection) {
    var ordered = section.sortedGroups
    ordered.move(fromOffsets: indices, toOffset: destination)
    for (i, group) in ordered.enumerated() {
        group.position = i
    }
    syncPositions(groups: ordered)
}

private func moveProtocols(_ indices: IndexSet, _ destination: Int, in group: ProtocolGroup) {
    var ordered = group.sortedProtocols
    ordered.move(fromOffsets: indices, toOffset: destination)
    for (i, proto) in ordered.enumerated() {
        proto.position = i
    }
    syncPositions(protocols: ordered)
}
```

### SyncService Addition

```swift
// MARK: - Position Sync

func syncPositions(
    sections: [ProtocolSection]? = nil,
    groups: [ProtocolGroup]? = nil,
    protocols: [UserProtocol]? = nil
) {
    guard let token = AuthService.shared.token else { return }

    var body: [String: Any] = [:]
    if let sections {
        body["sections"] = sections.map { ["id": $0.id.uuidString, "position": $0.position] }
    }
    if let groups {
        body["groups"] = groups.map { ["id": $0.id.uuidString, "position": $0.position, "section_id": $0.section?.id.uuidString ?? ""] }
    }
    if let protocols {
        body["protocols"] = protocols.map { ["id": $0.id.uuidString, "position": $0.position, "group_id": $0.group?.id.uuidString ?? ""] }
    }

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

**Sync conflict rule:** `syncProtocols()` already overwrites local positions with server values. After a reorder, the local write happens immediately (SwiftData) and the PATCH fires async. If a full sync happens before the PATCH completes, server values win — but the PATCH will then re-correct the server. Net effect: transient flicker at worst, eventually consistent.

### SwiftUI Previews

| Preview | Data |
|---------|------|
| `MasterTemplateEditor_Previews` | 3 sections, "Morning Routine" with 2 stacks (Wake Up: 3 protocols, Mindset: 2 protocols), "Evening Routine" with 1 stack (collapsed), "Workouts" with 1 stack |
| `HabitStackCard_Previews` | Stack with 4 protocols (2 completed, 1 skipped, 1 pending); empty stack |
| `DailyInstanceView_Previews` | Full day with multi-stack morning, single-stack evening, workout section |

---

## Implementation Phases

### Phase 1: Stack Cards + Page Parity (P0)

Both pages render Section → Habit Stack → Protocol. Identical styling.

- [ ] **`HabitStackCard`** — shared card component: header (name + "3/5") + protocol rows. Used by both pages.
- [ ] **`HabitStackHeader`** — stack name + completion + context menu (rename, delete, add protocol here).
- [ ] **`MasterTemplateEditor` rewrite** — re-introduce `ForEach(section.sortedGroups)` between section and protocol levels. Stack card wrapping. Section "…" menu adds "Add Habit Stack". Stack header "…" menu with rename/delete.
- [ ] **`HomeTab` update** — `mergedSections` restored to use `DailyGroup` level. `DailySectionView` renders `DailyGroup` cards. Single-stack collapsing applied.
- [ ] **`CreateProtocolSheet` update** — stack picker visible when section has 2+ stacks. `initialStack` parameter for context menu pre-selection.
- [ ] **Default stack enforcement** — `seedDefaultSectionsIfNeeded()` already creates one group per section. Add guard: section creation always creates a default group. Stack deletion reassigns protocols and prevents deleting last stack.

### Phase 2: Drag-and-Drop Reorder (P0)

Everything movable from My Protocols page.

- [ ] **Section reorder** — `ForEach(sections).onMove(perform: moveSections)`.
- [ ] **Stack reorder** — `ForEach(stacks).onMove(perform: moveStacks)` within each section.
- [ ] **Protocol reorder** — `ForEach(protocols).onMove(perform: moveProtocols)` within each stack.
- [ ] **Edit mode** — `EditButton()` in toolbar or persistent edit mode for the List.
- [ ] **API: `PATCH /api/protocols/reorder`** — batch position update endpoint.
- [ ] **`SyncService.syncPositions()`** — fire-and-forget PATCH after each reorder.
- [ ] **`syncProtocols()` position handling** — ensure full sync doesn't reset positions to stale server values after a local reorder.

### Phase 3: Stack CRUD + Polish (P0/P1)

- [ ] **Create stack** — section "…" → "Add Habit Stack" → alert with name field → create `ProtocolGroup`.
- [ ] **Rename stack** — stack header "…" → "Rename" → alert with text field.
- [ ] **Delete stack** — stack header "…" → "Delete" → confirmation → reassign protocols → delete group. Block if last stack.
- [ ] **API: `DELETE /api/protocols/groups/{id}`** — server-side stack deletion with protocol reassignment.
- [ ] **(P1) Move protocol between stacks** — protocol row context menu → "Move to…" → stack picker.
- [ ] **(P1) Move stack between sections** — stack header context menu → "Move to Section…" → section picker.
- [ ] **(P1) Stack completion ring** — small circular progress on stack header.
- [ ] **(P1) Haptic feedback** — `UIImpactFeedbackGenerator` on drag pickup/drop.

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| `onMove` in nested `ForEach` conflicts | M | SwiftUI `List` with `Section` + nested `ForEach` supports `onMove` per level. Test on device — Simulator drag can behave differently. If issues arise, fall back to explicit `EditMode` toggle. |
| Single-stack collapsing flicker on add | L | When user adds a second stack, the first stack's header appears. Use `withAnimation` on the stack creation to smooth the transition. |
| Position sync race condition | L | Local SwiftData write is synchronous → UI is always correct. Server PATCH is fire-and-forget. If it fails, next full sync will pull server positions (which may be stale). Acceptable for a personal app. |
| My Protocols List performance with nested ForEach | L | Typical section count: 3-5. Stacks per section: 1-3. Protocols per stack: 2-8. Total items: ~30. No performance concern. |
| DailySection struct needs mutable groups | L | `DailySection.groups` is already `var` (mutable). The `mergedSections` computed property can append empty groups from master. |
