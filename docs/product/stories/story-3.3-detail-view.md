# Story 3.3: Protocol Detail View Assembly

**Epic:** [Epic 3: Protocol Detail View](../epics/epic-3-protocol-detail.md)
**Status:** Not Started
**Points:** 3

---

## User Story

**As a** user
**I want to** tap any protocol and see a rich detail page with analytics, documents, and type-specific actions
**So that** each protocol feels like a first-class, self-contained unit

---

## Acceptance Criteria

- [ ] **AC1:** Detail view shows protocol name, type badge, subtitle
- [ ] **AC2:** Analytics card embedded (Story 3.1 component)
- [ ] **AC3:** Documents section embedded (Story 3.2 component)
- [ ] **AC4:** Workout type: shows activity icon, estimated duration, weekly target with frequency dots
- [ ] **AC5:** Workout type: "Start Workout" button (placeholder — navigates to existing workout view or shows "Coming in Phase 2")
- [ ] **AC6:** Task type: shows completion history list (last 10 entries)
- [ ] **AC7:** Edit button in toolbar opens edit sheet (existing MasterTemplateEditor fields + new type fields)
- [ ] **AC8:** View pushed from both DailyTaskRow and MasterTemplateEditor

---

## Technical Context

### Files to Modify
| File | Purpose | Changes |
|------|---------|---------|
| `ios/Dashboard Fitness/Views/HomeTab.swift` | Contains existing minimal `ProtocolDetailView` | Rewrite or replace with new version |

### New Files to Create
| File | Purpose |
|------|---------|
| `ios/Dashboard Fitness/Views/ProtocolDetailView.swift` | New standalone file for the detail view (extract from HomeTab.swift) |

### Implementation Guidance

```swift
struct ProtocolDetailView: View {
    let protocolId: String
    @State private var analytics: ProtocolAnalytics?
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header: icon + name + type badge
                ProtocolHeader(...)
                
                // Analytics (fetched from API)
                if let analytics {
                    ProtocolAnalyticsCard(
                        currentStreak: analytics.currentStreak,
                        // ...
                    )
                }
                
                // Documents
                ProtocolDocumentsSection(protocolId: protocolId)
                
                // Type-specific section
                if protocol.type == "workout" {
                    WorkoutProtocolSection(...)
                } else {
                    TaskProtocolSection(...)
                }
            }
        }
        .navigationTitle(protocol.label)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAnalytics() }
    }
}
```

### Gotchas
- Current `ProtocolDetailView` in `HomeTab.swift` is minimal — extract to standalone file
- Navigation: pushed from `DailyTaskRow` (via NavigationLink) and from `MasterTemplateEditor` (via NavigationLink)
- DailyTaskRow currently passes `protocolId`, `label`, `subtitle`, `documentId` — may need to pass `type` too

---

## Dependencies

### Blocked By
- Story 3.1: Analytics card component
- Story 3.2: Documents section component

### Blocks
- Nothing — this is the assembly story

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] SwiftUI previews: task protocol with streak, workout protocol with frequency
- [ ] File size < 500 lines
- [ ] Old ProtocolDetailView in HomeTab.swift removed/replaced
