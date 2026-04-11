# Story 2.4: Modified Protocol CRUD + Daily Task Type Stamping

**Epic:** [Epic 2: API Layer](../epics/epic-2-api-layer.md)
**Status:** Not Started
**Points:** 2

---

## User Story

**As a** user
**I want to** create protocols with a type and have that type reflected in my daily tasks
**So that** my Today view knows how to render each protocol appropriately

---

## Acceptance Criteria

- [ ] **AC1:** `POST /groups/{id}/protocols` accepts `type`, `activity_type`, `duration_minutes`, `weekly_target`, `reminder_time`, `icon`, `color`
- [ ] **AC2:** `PUT /protocol/{id}` accepts new fields but rejects changes to `type` (returns 400)
- [ ] **AC3:** `GET /` (full hierarchy) includes new fields in protocol objects
- [ ] **AC4:** `refresh_today()` stamps `type`, `activity_type`, `duration_minutes` on DailyTask from source Protocol
- [ ] **AC5:** `GET /today` response includes type fields on each task
- [ ] **AC6:** Protocol detail endpoint `GET /protocol/{id}/detail` includes type fields

---

## Technical Context

### Files to Modify
| File | Purpose | Changes |
|------|---------|---------|
| `api/routes/protocols.py` | Protocol CRUD | Accept new fields on create/update, reject type change |
| `api/services/daily.py` | Daily task generation | Stamp type from protocol onto daily task |

### Implementation Guidance

1. **Protocol create** — add new fields to the create endpoint:
   ```python
   protocol = Protocol(
       group_id=group_id,
       label=data["label"],
       type=data.get("type", "task"),  # required on create
       activity_type=data.get("activity_type"),
       duration_minutes=data.get("duration_minutes"),
       # ... etc
   )
   ```

2. **Protocol update** — reject type change:
   ```python
   if "type" in data and data["type"] != protocol.type:
       return jsonify({"error": "Protocol type cannot be changed"}), 400
   ```

3. **refresh_today()** — when creating DailyTask from Protocol:
   ```python
   task = DailyTask(
       # ... existing fields ...
       type=protocol.type,
       activity_type=protocol.activity_type,
       duration_minutes=protocol.duration_minutes,
   )
   ```

---

## Dependencies

### Blocked By
- Story 1.1: Models

### Blocks
- Story 4.1: Type-aware task row needs type on DailyTask

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Creating a workout protocol and viewing today shows type='workout' on the task
- [ ] Attempting to change type returns 400
- [ ] PEP 8, type hints
