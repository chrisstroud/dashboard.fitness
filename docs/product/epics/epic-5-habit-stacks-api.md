# Epic 5: API — Batch Reorder + Stack Deletion Endpoints

**PRD Reference:** [Habit Stacks](../prd/prd-habit-stacks.md)
**Architecture:** [Habit Stacks](../architecture/arch-habit-stacks.md)
**Status:** Not Started
**Owner:** Chris

---

## Overview

Add two new API endpoints that support the Habit Stacks feature: a batch reorder endpoint for updating positions of sections, stacks (groups), and protocols in a single call, and a stack deletion endpoint that safely reassigns orphan protocols.

### Value

Without the reorder endpoint, every drag-and-drop action would require N individual API calls. Without the delete endpoint, removing a stack would orphan protocols. These are small but foundational — the UI epics depend on them.

### Success Criteria

- [ ] `PATCH /api/protocols/reorder` accepts batch position updates for sections, groups, and protocols
- [ ] `DELETE /api/protocols/groups/{id}` reassigns protocols to the first remaining group and prevents deleting the last group in a section
- [ ] Both endpoints are auth-guarded and scoped to the requesting user

---

## Scope

### In Scope
- Batch reorder endpoint (sections, groups, protocols)
- Stack deletion endpoint with protocol reassignment
- Ownership validation on both endpoints

### Out of Scope
- UI changes (Epic 6-8)
- SyncService integration (Epic 7)
- Group rename endpoint (already handled by existing CRUD or trivial PATCH)

### Dependencies
- None — existing `ProtocolSection`, `ProtocolGroup`, `UserProtocol` models are unchanged

---

## Stories

| ID | Story | Points | Status |
|----|-------|--------|--------|
| 5.1 | Batch Reorder Endpoint | 2 | Not Started |
| 5.2 | Stack Deletion Endpoint | 2 | Not Started |

---

## Technical Context

### Affected Components
- `api/routes/protocols.py`

### Key Files
- `api/routes/protocols.py` — add two route handlers
- `api/models/protocol.py` — existing models, no changes

### Architecture Notes
Both endpoints are simple CRUD operations on existing `position`, `section_id`, and `group_id` fields. No new tables or columns.

---

## Context Digest

> Compressed from PRD and Architecture. Read these for full detail:
> - PRD: `docs/product/prd/prd-habit-stacks.md`
> - Architecture: `docs/product/architecture/arch-habit-stacks.md`

### Decisions Affecting This Epic
- **Reorder mechanism:** Batch PATCH, not individual updates — one API call per drag gesture
- **Position sync:** Optimistic local write → async PATCH to server. Fire-and-forget.
- **Cross-moves:** `section_id` on groups and `group_id` on protocols support P1 cross-moves

### Scope for This Epic
- In: Two new endpoints on `protocols_bp`
- Out: All UI, SyncService, SwiftData changes

### Data Model
No changes. Existing fields used:
- `ProtocolSection.position` (Integer)
- `ProtocolGroup.position` (Integer), `ProtocolGroup.section_id` (FK)
- `UserProtocol.position` (Integer), `UserProtocol.group_id` (FK)

### API Surface

**`PATCH /api/protocols/reorder`**
```json
{
  "sections": [{ "id": "uuid", "position": 0 }],
  "groups": [{ "id": "uuid", "position": 0, "section_id": "uuid" }],
  "protocols": [{ "id": "uuid", "position": 0, "group_id": "uuid" }]
}
```
All three arrays optional. `section_id`/`group_id` optional (only for cross-moves). Returns `204`.

**`DELETE /api/protocols/groups/{id}`**
- Reassigns protocols to first remaining group in section (sorted by position)
- Returns `400` if last group in section
- Returns `204` on success

### Patterns to Follow

Existing endpoint pattern in `protocols.py`:
```python
@protocols_bp.route("/sections", methods=["POST"])
def create_section():
    data = request.get_json()
    # ... validate, check ownership via g.user_id
    db.session.commit()
    return jsonify({...}), 201
```

Ownership check pattern: `section.user_id == g.user_id` for sections, traverse `group.section.user_id` for groups, `proto.group.section.user_id` for protocols.

### Dependencies
- Requires: Nothing — pure API addition
- Provides: `PATCH /api/protocols/reorder` for Epic 7 (SyncService.syncPositions), `DELETE` for Epic 8 (Stack CRUD)

---

## Risks

| Risk | Mitigation |
|------|------------|
| Ownership traversal on nested objects (proto → group → section → user) could be slow | N is tiny (~30 items max). If needed, add user_id directly to groups/protocols table later. |

---

## Progress Log

| Date | Update |
|------|--------|
| 2026-04-11 | Epic created |
