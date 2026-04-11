# Story 4.1: Type-Aware DailyTaskRow

**Epic:** [Epic 4: Today & Navigation](../epics/epic-4-today-navigation.md)
**Status:** Not Started
**Points:** 3

---

## User Story

**As a** user viewing my Today page
**I want** workout protocols and task protocols to look and behave differently
**So that** I can instantly distinguish between a 60-minute bench session and a 5-second supplement check

---

## Acceptance Criteria

- [ ] **AC1:** Task-type rows show: checkbox + label + streak badge (e.g., "12-day streak")
- [ ] **AC2:** Workout-type rows show: activity icon + label + duration pill + frequency dots
- [ ] **AC3:** Activity icon uses SF Symbol based on `activityType` (figure.run, figure.strengthtraining.traditional, etc.)
- [ ] **AC4:** Duration pill shows estimated minutes (e.g., "45m")
- [ ] **AC5:** Frequency dots match existing WorkoutSlots pattern (filled dots = completed this week)
- [ ] **AC6:** Both types still navigate to ProtocolDetailView on tap
- [ ] **AC7:** Completion gesture (tap checkbox/circle) still works for both types
- [ ] **AC8:** Group headers show "Stack" label style (cosmetic rename from "group")

---

## Technical Context

### Files to Modify
| File | Purpose | Changes |
|------|---------|---------|
| `ios/Dashboard Fitness/Views/HomeTab.swift` | `DailyTaskRow` + `CollapsibleGroupCard` | Branch rendering on `task.type`; update group label |

### Implementation Guidance

Modify `DailyTaskRow` to branch on type:

```swift
struct DailyTaskRow: View {
    @Bindable var task: DailyTask
    
    var body: some View {
        if task.type == "workout" {
            WorkoutTaskRow(task: task)
        } else {
            StandardTaskRow(task: task)  // current DailyTaskRow content
        }
    }
}

struct WorkoutTaskRow: View {
    @Bindable var task: DailyTask
    
    var body: some View {
        HStack(spacing: 12) {
            // Activity icon
            Image(systemName: activityIcon)
                .font(.system(size: 22))
                .foregroundStyle(task.status == "completed" ? .green : .blue)
            
            VStack(alignment: .leading) {
                Text(task.label)
                HStack {
                    if let dur = task.durationMinutes {
                        Text("\(dur)m").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Frequency dots (reuse WorkoutSlots pattern)
            // Completion button
        }
    }
}
```

For streak badge on task type, compute from local `ProtocolCompletion` data or pass from API.

### Gotchas
- `task.type` may be nil for old DailyTasks created before migration — default to "task"
- WorkoutSlots frequency dots currently query DocFolder — need to adapt for protocol-based frequency tracking
- Keep `HomeTab.swift` under 2000-line limit — extract `WorkoutTaskRow` and `StandardTaskRow` if needed

---

## Dependencies

### Blocked By
- Story 1.2: iOS models (type field on DailyTask)
- Story 2.4: API stamps type on daily tasks

### Can Parallel With
- Story 4.2 (different views)

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Both task types render correctly in simulator
- [ ] Existing task-type protocols unchanged visually
- [ ] File size within limits (extract if needed)
