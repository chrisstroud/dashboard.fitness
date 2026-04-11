# Story 2.3: Protocol-Document Linking Endpoints

**Epic:** [Epic 2: API Layer](../epics/epic-2-api-layer.md)
**Status:** Not Started
**Points:** 2

---

## User Story

**As a** user
**I want to** attach and detach documents to/from protocols via the API
**So that** my notes and references are linked to the protocols they belong to

---

## Acceptance Criteria

- [ ] **AC1:** `POST /api/protocols/{id}/documents` attaches a document (body: `{ document_id, position? }`)
- [ ] **AC2:** `DELETE /api/protocols/{id}/documents/{doc_id}` detaches a document
- [ ] **AC3:** `GET /api/protocols/{id}/documents` returns attached documents with content
- [ ] **AC4:** `GET /api/documents/orphans` returns documents not attached to any protocol
- [ ] **AC5:** Attaching same document twice returns 409
- [ ] **AC6:** All endpoints scoped to authenticated user

---

## Technical Context

### Files to Modify
| File | Purpose | Changes |
|------|---------|---------|
| `api/routes/protocols.py` | Protocol endpoints | Add document linking endpoints |
| `api/routes/documents.py` | Document endpoints | Add orphans endpoint |

### Implementation Guidance

- Attach: Create `ProtocolDocument` row. Verify both protocol and document belong to user.
- Detach: Delete `ProtocolDocument` row. Document itself is NOT deleted.
- List: Join `protocol_documents` → `documents`, return full document objects.
- Orphans: `SELECT * FROM documents WHERE id NOT IN (SELECT document_id FROM protocol_documents) AND user_id = ?`

---

## Dependencies

### Blocked By
- Story 1.1: Models

### Blocks
- Story 3.2: iOS document section needs these endpoints
- Story 4.3: SyncService needs these endpoints

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Tested: attach, detach, re-attach, list, orphans
- [ ] PEP 8, type hints
