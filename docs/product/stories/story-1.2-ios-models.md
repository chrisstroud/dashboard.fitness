# Story 1.2: iOS SwiftData Model Updates

**Epic:** [Epic 1: Data Layer](../epics/epic-1-data-layer.md)
**Status:** Not Started
**Points:** 2

---

## User Story

**As a** developer
**I want to** update SwiftData models with protocol type, completion, and document-link support
**So that** the iOS app can store and display typed protocols with analytics data locally

---

## Acceptance Criteria

- [ ] **AC1:** `UserProtocol` has `type`, `activityType`, `durationMinutes`, `weeklyTarget`, `reminderTime`, `icon`, `color` properties
- [ ] **AC2:** `DailyTask` has `type`, `activityType`, `durationMinutes` properties
- [ ] **AC3:** New `ProtocolCompletion` @Model with protocol relationship, date, status, workout metadata
- [ ] **AC4:** App launches without SwiftData migration error on existing data
- [ ] **AC5:** `ModelContainer` schema includes `ProtocolCompletion`
- [ ] **AC6:** All new properties have sensible defaults (type defaults to "task")

---

## Technical Context

### Files to Modify
| File | Purpose | Changes |
|------|---------|---------|
| `ios/Dashboard Fitness/Models/UserProtocol.swift` | Protocol + Group + Section models | Add type properties to `UserProtocol`. Add `ProtocolCompletion` model. |
| `ios/Dashboard Fitness/Models/DailyInstance.swift` | Daily task model | Add type properties to `DailyTask` |
| `ios/Dashboard Fitness/Dashboard_FitnessApp.swift` | App entry + model container | Add `ProtocolCompletion.self` to schema |

### Implementation Guidance

1. Add properties to `UserProtocol`:
   ```swift
   var type: String = "task"
   var activityType: String?
   var durationMinutes: Int?
   var weeklyTarget: Int?
   var reminderTime: Date?
   var icon: String?
   var color: String?
   @Relationship(deleteRule: .cascade) var completions: [ProtocolCompletion] = []
   ```

2. Add properties to `DailyTask`:
   ```swift
   var type: String = "task"
   var activityType: String?
   var durationMinutes: Int?
   ```

3. Create `ProtocolCompletion` model (in `UserProtocol.swift` or new file):
   ```swift
   @Model
   final class ProtocolCompletion {
       @Attribute(.unique) var id: UUID = UUID()
       var userProtocol: UserProtocol?
       var date: Date
       var status: String = "completed"
       var completedAt: Date?
       var durationMinutes: Int?
       var calories: Int?
       var avgHeartRate: Int?
       var notes: String?
   }
   ```

4. Add `ProtocolCompletion.self` to the `Schema` in `Dashboard_FitnessApp.swift`.

### Gotchas
- All new properties MUST have default values for lightweight migration to work
- SwiftData lightweight migration handles additive properties with defaults — no `SchemaMigrationPlan` needed
- If migration fails on existing installs, worst case: delete local store and re-sync from API

---

## Dependencies

### Blocked By
- None (can parallel with Story 1.1)

### Blocks
- All Epic 3 and 4 stories (iOS UI needs these models)

### Can Parallel With
- Story 1.1 (different layer)

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] App builds and runs in simulator
- [ ] Existing local data survives model update (lightweight migration)
- [ ] SwiftUI previews using new properties compile
