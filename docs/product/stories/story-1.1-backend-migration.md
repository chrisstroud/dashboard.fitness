# Story 1.1: Backend Alembic Migration + SQLAlchemy Models

**Epic:** [Epic 1: Data Layer](../epics/epic-1-data-layer.md)
**Status:** Not Started
**Points:** 3

---

## User Story

**As a** developer
**I want to** extend the database schema with protocol types, completion history, and document linking
**So that** the backend can support typed protocols with per-protocol analytics and attached documents

---

## Acceptance Criteria

- [ ] **AC1:** Alembic migration adds `type`, `activity_type`, `duration_minutes`, `weekly_target`, `reminder_time`, `icon`, `color` columns to `protocols` table
- [ ] **AC2:** Alembic migration adds `type`, `activity_type`, `duration_minutes` columns to `daily_tasks` table
- [ ] **AC3:** Alembic migration creates `protocol_completions` table with unique constraint on `(protocol_id, user_id, date)`
- [ ] **AC4:** Alembic migration creates `protocol_documents` table with unique constraint on `(protocol_id, document_id)`
- [ ] **AC5:** SQLAlchemy `Protocol` model has new columns with correct types and defaults
- [ ] **AC6:** SQLAlchemy `DailyTask` model has new type columns
- [ ] **AC7:** New `ProtocolCompletion` and `ProtocolDocument` SQLAlchemy models with relationships
- [ ] **AC8:** Migration runs cleanly on fresh database AND on existing production database
- [ ] **AC9:** `flask db upgrade` completes without errors locally

---

## Technical Context

### Architecture Reference
See `docs/product/architecture/arch-protocols-v2.md` "Data Model" section for full schema.

### Files to Modify
| File | Purpose | Changes |
|------|---------|---------|
| `api/models/protocol.py` | Protocol + DailyTask models | Add columns to `Protocol` and `DailyTask`. Add `ProtocolCompletion` and `ProtocolDocument` classes. |
| `api/models/__init__.py` | Model imports | Import new models so Alembic detects them |

### New Files to Create
| File | Purpose |
|------|---------|
| `api/migrations/versions/XXXX_protocols_v2.py` | Alembic migration for all schema changes |

---

## Implementation Guidance

### Approach
Add new columns and tables via a single Alembic migration. Update SQLAlchemy models to match. All changes are additive — no column renames, no type changes, no destructive operations.

### Layer Sequence
1. SQLAlchemy models (add columns + new classes)
2. Generate Alembic migration via `flask db migrate`
3. Verify migration runs on fresh and existing databases

### Step-by-Step

1. **Modify `Protocol` model** in `api/models/protocol.py`:
   ```python
   # Add after existing columns:
   type = db.Column(db.String(20), nullable=False, default="task", server_default="task")
   activity_type = db.Column(db.String(50), nullable=True)
   duration_minutes = db.Column(db.Integer, nullable=True)
   weekly_target = db.Column(db.Integer, nullable=True)
   reminder_time = db.Column(db.Time, nullable=True)
   icon = db.Column(db.String(50), nullable=True)
   color = db.Column(db.String(20), nullable=True)
   ```

2. **Modify `DailyTask` model** in `api/models/protocol.py`:
   ```python
   # Add after existing columns:
   type = db.Column(db.String(20), nullable=False, default="task", server_default="task")
   activity_type = db.Column(db.String(50), nullable=True)
   duration_minutes = db.Column(db.Integer, nullable=True)
   ```

3. **Add `ProtocolCompletion` model** in `api/models/protocol.py`:
   ```python
   class ProtocolCompletion(db.Model):
       __tablename__ = "protocol_completions"
       id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid4()))
       protocol_id = db.Column(db.String(36), db.ForeignKey("protocols.id", ondelete="CASCADE"), nullable=False)
       user_id = db.Column(db.String(36), db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
       date = db.Column(db.Date, nullable=False)
       status = db.Column(db.String(20), nullable=False, default="completed")
       completed_at = db.Column(db.DateTime(timezone=True))
       duration_minutes = db.Column(db.Integer, nullable=True)
       calories = db.Column(db.Integer, nullable=True)
       avg_heart_rate = db.Column(db.Integer, nullable=True)
       notes = db.Column(db.Text, nullable=True)
       metadata = db.Column(db.JSON, nullable=True)
       created_at = db.Column(db.DateTime(timezone=True), server_default=db.func.now())
       __table_args__ = (db.UniqueConstraint("protocol_id", "user_id", "date"),)
       protocol = db.relationship("Protocol", backref=db.backref("completions", cascade="all, delete-orphan"))
   ```

4. **Add `ProtocolDocument` model** in `api/models/protocol.py`:
   ```python
   class ProtocolDocument(db.Model):
       __tablename__ = "protocol_documents"
       id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid4()))
       protocol_id = db.Column(db.String(36), db.ForeignKey("protocols.id", ondelete="CASCADE"), nullable=False)
       document_id = db.Column(db.String(36), db.ForeignKey("documents.id", ondelete="CASCADE"), nullable=False)
       position = db.Column(db.Integer, nullable=False, default=0)
       created_at = db.Column(db.DateTime(timezone=True), server_default=db.func.now())
       __table_args__ = (db.UniqueConstraint("protocol_id", "document_id"),)
       protocol = db.relationship("Protocol", backref=db.backref("protocol_documents", cascade="all, delete-orphan"))
       document = db.relationship("Document", backref=db.backref("protocol_documents"))
   ```

5. **Update `__init__.py`** to import new models.

6. **Generate migration**: `flask db migrate -m "protocols v2 — types, completions, documents"`

7. **Add indexes** to migration manually:
   ```python
   op.create_index("idx_protocol_completions_user_date", "protocol_completions", ["user_id", "date"])
   op.create_index("idx_protocol_completions_protocol", "protocol_completions", ["protocol_id"])
   ```

8. **Test**: `flask db upgrade` on fresh SQLite + verify against Railway Postgres.

### Code Patterns to Follow
```python
# Existing pattern from api/models/protocol.py:
class Protocol(db.Model):
    __tablename__ = "protocols"
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid4()))
    # ... follow this pattern for new columns
```

### Gotchas / Watch Out For
- Railway Postgres uses `server_default` for defaults, not just Python-side `default`. Include both.
- `db.JSON` maps to `JSONB` on Postgres, `JSON` on SQLite. Both work.
- The `document_id` FK on `ProtocolDocument` references `documents.id` (table name `documents`), not `Document.id`.

---

## Dev Notes

### Architecture Constraints
- All new columns must have `server_default` or `nullable=True` to avoid breaking existing rows
- String PKs are 36-char UUIDs (existing pattern)
- Timestamps use `db.DateTime(timezone=True)` (existing pattern)

### Patterns to Follow
- Model file pattern: `api/models/protocol.py` — all protocol-related models in one file
- UUID generation: `default=lambda: str(uuid4())` on PK columns

### Previous Learnings
- The initial migration (`36935aa0bf3b`) created all tables in one shot. This migration is additive.

### References
- Architecture: `docs/product/architecture/arch-protocols-v2.md#data-model`

---

## Dependencies

### Blocked By
- Nothing

### Blocks
- Story 1.2: iOS models mirror these changes
- Story 1.3: Backfill depends on tables existing
- All Epic 2 stories: API needs models

### Can Parallel With
- Story 1.2 (different layer — iOS vs backend)

---

## Testing Notes

### Test Scenarios
1. Run `flask db upgrade` on fresh database — all tables created
2. Run `flask db upgrade` on existing database (with data) — migration succeeds, existing data untouched
3. Insert a `ProtocolCompletion` — unique constraint enforced on (protocol_id, user_id, date)
4. Insert a `ProtocolDocument` — unique constraint enforced on (protocol_id, document_id)
5. Delete a Protocol — cascades to completions and protocol_documents

### Edge Cases
- Existing protocols have no `type` value — `server_default='task'` fills it
- Existing daily_tasks have no `type` value — `server_default='task'` fills it

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Python code follows conventions (PEP 8, type hints)
- [ ] Migration runs on both SQLite (local) and PostgreSQL (Railway)
- [ ] No obvious bugs
- [ ] Self-reviewed before PR
