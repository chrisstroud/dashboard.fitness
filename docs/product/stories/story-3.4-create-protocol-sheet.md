# Story 3.4: Create Protocol Sheet with Type Picker

**Epic:** [Epic 3: Protocol Detail View](../epics/epic-3-protocol-detail.md)
**Status:** Not Started
**Points:** 2

---

## User Story

**As a** user creating a new protocol
**I want to** choose between workout and task types with appropriate fields for each
**So that** my protocols have the right metadata from the start

---

## Acceptance Criteria

- [ ] **AC1:** Sheet opens from MasterTemplateEditor "+" button
- [ ] **AC2:** Type picker shows "Workout" and "Task" as prominent options (segmented control or two cards)
- [ ] **AC3:** Selecting "Workout" shows: activity type picker, estimated duration, weekly target
- [ ] **AC4:** Selecting "Task" shows: label, subtitle, optional duration estimate
- [ ] **AC5:** Both types show: label (required), subtitle (optional), icon picker (optional)
- [ ] **AC6:** Save creates protocol via API with all fields
- [ ] **AC7:** Activity type picker shows SF Symbol icons for each type (figure.run, figure.strengthtraining.traditional, etc.)

---

## Technical Context

### New Files to Create
| File | Purpose |
|------|---------|
| `ios/Dashboard Fitness/Views/CreateProtocolSheet.swift` | Type picker + type-specific form |

### Files to Modify
| File | Purpose | Changes |
|------|---------|---------|
| `ios/Dashboard Fitness/Views/MasterTemplateEditor.swift` | Protocol editor | Wire "+" button to new sheet instead of existing simple add |

### Implementation Guidance

```swift
struct CreateProtocolSheet: View {
    @State private var type: ProtocolType = .task
    @State private var label = ""
    @State private var subtitle = ""
    @State private var activityType: ActivityType = .strength
    @State private var durationMinutes: Int?
    @State private var weeklyTarget: Int?
    
    enum ProtocolType: String, CaseIterable {
        case task, workout
    }
    
    enum ActivityType: String, CaseIterable {
        case strength, running, cycling, hiit, yoga, flexibility, other
        var icon: String { /* SF Symbol mapping */ }
    }
}
```

Activity type → SF Symbol mapping:
- strength → `figure.strengthtraining.traditional`
- running → `figure.run`
- cycling → `figure.outdoor.cycle`
- hiit → `figure.highintensity.intervaltraining`
- yoga → `figure.yoga`
- flexibility → `figure.flexibility`
- other → `figure.mixed.cardio`

---

## Dependencies

### Blocked By
- Story 2.4: API accepts type on protocol create

### Can Parallel With
- Stories 3.1, 3.2 (no shared files)

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] SwiftUI previews: both type forms, validation states
- [ ] File size < 250 lines
