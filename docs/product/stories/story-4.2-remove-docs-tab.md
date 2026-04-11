# Story 4.2: Remove Docs Tab + Orphan Docs in MasterTemplateEditor

**Epic:** [Epic 4: Today & Navigation](../epics/epic-4-today-navigation.md)
**Status:** Not Started
**Points:** 2

---

## User Story

**As a** user
**I want** documents integrated into protocols rather than a separate tab
**So that** the app has a simpler navigation model and my notes are where they belong

---

## Acceptance Criteria

- [ ] **AC1:** Docs tab removed from tab bar (3 tabs: Today, History, Settings)
- [ ] **AC2:** MasterTemplateEditor shows a "Notes" section at bottom listing orphan documents
- [ ] **AC3:** Orphan documents are tappable → opens existing markdown view
- [ ] **AC4:** "New Note" button in Notes section creates unattached document
- [ ] **AC5:** No data loss — all existing documents still accessible

---

## Technical Context

### Files to Modify
| File | Purpose | Changes |
|------|---------|---------|
| `ios/Dashboard Fitness/ContentView.swift` | Tab bar | Remove `DocsTab()` tab |
| `ios/Dashboard Fitness/Views/MasterTemplateEditor.swift` | Protocol editor | Add "Notes" section at bottom |

### Implementation Guidance

1. **ContentView.swift** — remove the Docs tab:
   ```swift
   TabView {
       Tab("Today", systemImage: "checkmark.square") { HomeTab() }
       Tab("History", systemImage: "calendar") { HistoryTab() }
       Tab("Settings", systemImage: "gear") { SettingsTab() }
   }
   ```

2. **MasterTemplateEditor** — add Notes section after protocol sections:
   ```swift
   Section("Notes") {
       if orphanDocs.isEmpty {
           Text("Unattached notes appear here")
               .foregroundStyle(.secondary)
       }
       ForEach(orphanDocs) { doc in
           NavigationLink { LinkedDocView(documentId: doc.id) } label: {
               Label(doc.title, systemImage: "doc.text")
           }
       }
       Button("New Note") { createOrphanDoc() }
   }
   ```

   Orphan docs: query all docs, subtract those in `protocol_documents`. Or fetch from `GET /api/documents/orphans`.

---

## Dependencies

### Blocked By
- Story 2.3: Orphan docs endpoint

### Can Parallel With
- Story 4.1 (different files)

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Tab bar shows 3 tabs
- [ ] Orphan docs visible and tappable in MasterTemplateEditor
- [ ] No document data lost
