# Story 3.2: Protocol Documents Section

**Epic:** [Epic 3: Protocol Detail View](../epics/epic-3-protocol-detail.md)
**Status:** Not Started
**Points:** 3

---

## User Story

**As a** user viewing a protocol's detail page
**I want to** see, attach, and create documents for this protocol
**So that** my notes and references are right where I need them

---

## Acceptance Criteria

- [ ] **AC1:** Documents section lists all attached documents with title and preview text
- [ ] **AC2:** Tapping a document pushes to full markdown view
- [ ] **AC3:** "Add Document" button shows sheet: pick existing doc or create new
- [ ] **AC4:** Swipe-to-detach removes document link (does NOT delete the document)
- [ ] **AC5:** "New Document" creates document, attaches to protocol, opens editor
- [ ] **AC6:** Empty state: "No documents attached" with add button

---

## Technical Context

### New Files to Create
| File | Purpose |
|------|---------|
| `ios/Dashboard Fitness/Views/ProtocolDocumentsSection.swift` | Document list + attach/detach + create |
| `ios/Dashboard Fitness/Views/DocumentPickerSheet.swift` | Sheet to pick existing or create new doc |

### Implementation Guidance

- Fetch attached docs from API on appear
- Attach: POST to `/api/protocols/{id}/documents`
- Detach: DELETE to `/api/protocols/{id}/documents/{doc_id}`
- Create: POST to `/api/documents` then attach
- Reuse existing `MarkdownView` for document content display

### Patterns to Follow
- List with swipe: see existing `ForEach` + `.onDelete` patterns
- Sheet presentation: see `MasterTemplateEditor` sheet usage

---

## Dependencies

### Blocked By
- Story 2.3: Document linking endpoints

### Can Parallel With
- Story 3.1 (analytics card — no shared files)

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] SwiftUI previews: 0 docs, 3 docs, long doc titles
- [ ] File size < 300 lines per file
