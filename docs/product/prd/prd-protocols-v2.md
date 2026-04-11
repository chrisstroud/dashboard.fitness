# PRD: Protocols v2 — First-Class Atomic Protocols

**Status:** Approved
**Date:** 2026-04-11
**Brief:** `briefs/brief-protocols-v2.md`

---

## Executive Summary

### Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Protocol type system | Discriminated union (`workout` \| `task`) with extensible `type` field | Avoids class hierarchy; new types (medication, journaling) = new enum value + type-specific metadata, no schema migration |
| Documents model | Many-to-many via ProtocolDocument join table | A protocol can have multiple notes; a doc (e.g., "Supplement Reference") could be shared across protocols |
| Habit stacking | Groups renamed to Stacks with explicit `position` ordering | Maps to James Clear's model; existing data migrates 1:1 since groups already have position |
| HealthKit pattern | `HKWorkoutSession` + `HKLiveWorkoutBuilder` on iOS 26+ | Apple's recommended path; enables real-time data, activity ring credit, and future Watch mirroring |
| Analytics storage | Computed from completion history, not stored separately | Streaks and rates change daily — computing from source avoids stale data and extra sync |
| Apple ecosystem priority | HealthKit > Interactive Widgets > App Intents > Notifications > Live Activities > Watch | Solo-dev priority order; each layer unlocks the next |
| Docs tab | Removed; replaced by protocol-attached documents + "Notes" section | Simplifies mental model from two systems to one |
| Backend | Keep Flask/Railway as source of truth; SwiftData for offline-first | CloudKit would require optional properties everywhere and limits cross-platform future |

### Scope

**In:** Protocol type system, per-protocol completion history + analytics, document attachment, HealthKit workout sessions, interactive widgets (streak/today), App Intents (log habit, start workout), habit-stacking UX, migration of existing data

**Out:** Apple Watch app, location-based triggers, social/multi-user features, AI coaching, Focus mode filters, CloudKit sync

### Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Protocol types supported | 1 (implicit, all same) | 2 (workout, task) |
| Per-protocol analytics | None | Streak, 7d/30d completion rate, history |
| HealthKit integration | None | Workout start/stop with calories + duration saved |
| Document access | Separate Docs tab, manual linking | Inline from protocol detail view |
| Widget surfaces | None | Lock screen streak + home screen today checklist |
| Siri/Shortcuts actions | None | "Log [habit]", "Start [workout]" |

---

## Problem Statement

Protocols are an undifferentiated checklist — a 60-minute bench press workout and "take supplements" get the same checkbox. There's no type awareness, no per-protocol history, no system integration. Documents live in a separate silo. The app can't leverage HealthKit, Widgets, Siri, or Notifications because protocols lack the metadata and type information these systems require.

**Current workarounds:** Workouts are tracked via a separate WorkoutCompletion system tied to Documents (not Protocols). Streaks don't exist. Analytics don't exist. Users mentally map "which doc goes with which protocol" with no system support.

---

## User Stories

### US-1: Protocol Types

**As a** user **I want** my workouts and daily tasks to behave differently **so that** a bench press session gets HealthKit tracking while "take vitamins" is a simple checkbox.

- [ ] AC1: Each protocol has a visible `type` indicator in the UI (workout icon vs task icon)
- [ ] AC2: Creating a new protocol requires selecting a type
- [ ] AC3: Workout protocols show duration, activity type, and frequency target
- [ ] AC4: Task protocols show streak count and completion rate
- [ ] AC5: Type is immutable after creation (prevents data inconsistency)

### US-2: Per-Protocol Analytics

**As a** user **I want** to see my streak and completion history for each protocol **so that** I can track consistency and identify what I'm skipping.

- [ ] AC1: Protocol detail view shows current streak (consecutive days completed)
- [ ] AC2: Protocol detail view shows longest streak
- [ ] AC3: Protocol detail view shows 7-day and 30-day completion rate
- [ ] AC4: Protocol detail view shows a calendar heatmap of last 30 days (done/skipped/missed)
- [ ] AC5: Analytics are computed from completion history, not cached

### US-3: Document Attachment

**As a** user **I want** to attach notes and reference docs to a protocol **so that** my bench press protocol has my program notes right there, not in a separate tab.

- [ ] AC1: Protocol detail view shows attached documents
- [ ] AC2: User can attach existing documents or create new ones from protocol detail
- [ ] AC3: Documents support markdown rendering
- [ ] AC4: A protocol can have 0-N documents
- [ ] AC5: Orphan documents (not attached to any protocol) are accessible from a "Notes" section
- [ ] AC6: The standalone "Docs" tab is removed from the tab bar

### US-4: HealthKit Workout Sessions

**As a** user **I want** to start a workout from a protocol and have it tracked in Apple Health **so that** my activity rings close and I have heart rate / calorie data.

- [ ] AC1: Workout protocol detail has a "Start Workout" button
- [ ] AC2: Starting a workout creates an `HKWorkoutSession` with the correct activity type
- [ ] AC3: Active workout shows elapsed time, heart rate, and active calories
- [ ] AC4: Ending a workout saves the session to HealthKit and marks the protocol complete for the day
- [ ] AC5: HealthKit authorization is requested on first workout start, not at app launch
- [ ] AC6: Live Activity shows workout name, elapsed time, and current exercise during active session

### US-5: Interactive Widgets

**As a** user **I want** to check off habits from my home screen and see my streak on the lock screen **so that** I don't have to open the app for quick completions.

- [ ] AC1: Lock screen widget (`.accessoryCircular`) shows today's completion ring
- [ ] AC2: Lock screen widget (`.accessoryRectangular`) shows top 3 protocols with status
- [ ] AC3: Home screen widget (`.systemMedium`) shows today's protocols with tap-to-complete buttons
- [ ] AC4: Widget taps execute `AppIntent` to toggle protocol completion
- [ ] AC5: Widgets update within 15 minutes of a completion in the main app

### US-6: Siri & Shortcuts Integration

**As a** user **I want** to say "Log morning routine" or "Start bench day" **so that** I can interact with protocols hands-free.

- [ ] AC1: `LogProtocol` App Intent marks a named protocol complete for today
- [ ] AC2: `StartWorkout` App Intent opens the app to the workout session for a named protocol
- [ ] AC3: `GetTodayProgress` App Intent returns "5 of 12 protocols done" via Siri
- [ ] AC4: Protocols are exposed as `AppEntity` instances with dynamic enumeration
- [ ] AC5: Shortcuts app can build automations using these intents

### US-7: Habit Stacking

**As a** user **I want** my protocols grouped in ordered stacks **so that** completing "brush teeth" naturally leads to "take supplements" leads to "morning meditation."

- [ ] AC1: Stacks display protocols in explicit order
- [ ] AC2: Completing a protocol in a stack visually highlights the next one
- [ ] AC3: Stack completion percentage is visible at the stack level
- [ ] AC4: User can reorder protocols within a stack via drag-and-drop
- [ ] AC5: Stacks can have an optional anchor time (e.g., "6:00 AM")

### US-8: Notification Reminders

**As a** user **I want** to set reminders for specific protocols **so that** I don't forget time-sensitive items like supplements or workouts.

- [ ] AC1: Protocol detail has an optional reminder time setting
- [ ] AC2: Reminders fire as `.timeSensitive` notifications at the scheduled time
- [ ] AC3: Notification includes "Done" and "Skip" quick actions (no app open required)
- [ ] AC4: Completed protocols don't fire their reminder for that day
- [ ] AC5: User can disable all reminders globally from Settings

---

## Functional Requirements

### P0 (Must Have) — Phase 1: Foundation

- [ ] Protocol type field (`workout` | `task`) on backend model and SwiftData model
- [ ] Protocol completion history table (protocol_id, date, status, completed_at, metadata JSON)
- [ ] ProtocolDocument join table (protocol_id, document_id, position)
- [ ] Per-protocol detail view with type-appropriate UI
- [ ] Streak computation: current streak, longest streak, 7d/30d completion rate
- [ ] Calendar heatmap on protocol detail (last 30 days)
- [ ] Attach/detach documents from protocol detail view
- [ ] Create new document inline from protocol detail
- [ ] Remove Docs tab; add "Notes" section to Protocols view for orphan docs
- [ ] Migrate existing protocols to `task` type
- [ ] Migrate existing workout documents to `workout` type protocols
- [ ] API endpoints: protocol completion CRUD, protocol-document linking
- [ ] Groups renamed to Stacks in UI (data model field name stays for compatibility)

### P1 (Should Have) — Phase 2: HealthKit + System Integration

- [ ] HealthKit authorization flow (request on first workout, not at launch)
- [ ] `HKWorkoutSession` + `HKLiveWorkoutBuilder` for workout protocols
- [ ] Active workout view: elapsed time, heart rate, active calories, current exercise
- [ ] Live Activity for active workout (Dynamic Island + lock screen)
- [ ] Workout completion saves to HealthKit (duration, calories, activity type, heart rate samples)
- [ ] Interactive home screen widget (`.systemMedium`) — today's protocols with tap-to-complete
- [ ] Lock screen widgets — completion ring (`.accessoryCircular`) + top protocols (`.accessoryRectangular`)
- [ ] Shared App Group container for widget data access
- [ ] `LogProtocol` and `StartWorkout` App Intents with `AppEntity` for protocols
- [ ] `GetTodayProgress` App Intent for Siri summary
- [ ] `AppShortcutsProvider` with trigger phrases

### P2 (Nice to Have) — Phase 3: Polish + Habit Loop

- [ ] Habit stacking sequential flow (completing one highlights next in stack)
- [ ] Stack anchor time with notification at anchor time
- [ ] Per-protocol reminder notifications with Done/Skip actions
- [ ] Notification suppression for already-completed protocols
- [ ] Protocol templates (pre-built stacks: "Morning Routine", "Pre-Workout", "Evening Wind-Down")
- [ ] Drag-and-drop reorder within stacks
- [ ] Bulk operations: complete/skip entire stack
- [ ] Weekly summary notification (completion rate trends)
- [ ] Protocol archiving (soft delete, hide from daily but preserve history)

---

## Technical Considerations

### Affected Components

| Component | Change |
|-----------|--------|
| `api/models/protocol.py` | Add `type`, `activity_type`, `duration_minutes`, `weekly_target`, `reminder_time` to Protocol model. New `ProtocolCompletion` and `ProtocolDocument` tables. |
| `api/models/document.py` | No schema change; documents stay as-is. WorkoutCompletion may be deprecated in favor of ProtocolCompletion. |
| `api/routes/protocols.py` | New endpoints: completions CRUD, document attach/detach, protocol analytics |
| `api/routes/documents.py` | Deprecate workout-specific endpoints; keep core doc CRUD |
| `api/services/daily.py` | Update `refresh_today()` to stamp type info on DailyTask |
| `ios/.../Models/UserProtocol.swift` | Add `type`, `activityType`, `durationMinutes`, `weeklyTarget`, `reminderTime`. New `ProtocolCompletion` model. |
| `ios/.../Models/Document.swift` | Add relationship to protocols via join. WorkoutCompletion deprecated. |
| `ios/.../Views/HomeTab.swift` | Type-aware task rows (workout card vs task checkbox) |
| `ios/.../Views/ProtocolDetailView.swift` | New: analytics, docs, type-specific actions |
| `ios/.../Views/ContentView.swift` | Remove Docs tab, add Protocols tab |
| `ios/.../Services/SyncService.swift` | Sync completion history, protocol-document links |
| `ios/.../Services/HealthKitService.swift` | New: workout session management |
| New: Widget extension | WidgetKit target with timeline providers |
| New: App Intents | `AppIntent` structs + `AppShortcutsProvider` |
| New: ActivityKit | Live Activity attributes for workouts |

### Data Model Changes

**New Tables (Backend):**

```
protocol_completions:
  id              String(36) PK
  protocol_id     String(36) FK → protocols.id
  user_id         String(36) FK → users.id
  date            Date
  status          String(20)  -- completed | skipped | missed
  completed_at    DateTime(tz)
  metadata        JSON        -- type-specific: {duration_min, calories, avg_hr} for workout
  UNIQUE(protocol_id, user_id, date)

protocol_documents:
  id              String(36) PK
  protocol_id     String(36) FK → protocols.id
  document_id     String(36) FK → documents.id
  position        Integer
  UNIQUE(protocol_id, document_id)
```

**Modified Tables (Backend):**

```
protocols (add columns):
  type            String(20) NOT NULL DEFAULT 'task'  -- workout | task
  activity_type   String(50)  -- NULL for tasks; strength|running|cycling|etc for workouts
  duration_minutes Integer    -- estimated duration
  weekly_target   Integer     -- NULL = daily, else N times per week
  reminder_time   Time        -- optional notification time
```

**SwiftData (iOS) — mirrors backend changes.**

### API Changes

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/protocols/{id}/complete` | Mark protocol complete for today (accepts metadata JSON) |
| DELETE | `/api/protocols/{id}/complete?date=YYYY-MM-DD` | Undo completion |
| GET | `/api/protocols/{id}/analytics` | Streak, rates, last 90 days history |
| GET | `/api/protocols/{id}/completions?from=&to=` | Completion history range |
| POST | `/api/protocols/{id}/documents` | Attach document to protocol |
| DELETE | `/api/protocols/{id}/documents/{doc_id}` | Detach document |
| GET | `/api/protocols/{id}/documents` | List attached documents |
| GET | `/api/documents/orphans` | Documents not attached to any protocol |

### Migration Strategy

1. **Backend Alembic migration:** Add columns to `protocols`, create `protocol_completions` and `protocol_documents` tables. Backfill `type='task'` for all existing protocols.
2. **Workout document migration:** For each Document in the "Workouts" folder, create a corresponding Protocol with `type='workout'` and link via `protocol_documents`. Preserve existing WorkoutCompletion data by copying to `protocol_completions`.
3. **SwiftData migration:** Lightweight migration (additive columns) should work. If not, use `SchemaMigrationPlan`.
4. **Backward compatibility:** DailyTask continues to work as-is. The `type` field on DailyTask is additive — old tasks default to `task` type.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| HealthKit review rejection | M | H | Request only needed data types; follow Apple's HIG for health data. Submit for review early. |
| Data migration breaks existing users | M | H | Phase migration behind feature flag; test with production data snapshot. |
| Widget + App Intent complexity | M | M | Ship widget as separate phase after core is stable. Widget has its own target = isolated risk. |
| SwiftData migration failure | L | H | Use lightweight migration (additive only). If needed, reset local store and re-sync from API. |
| Scope creep across 3 phases | H | M | Hard phase boundaries. Ship Phase 1 before starting Phase 2. Each phase is independently valuable. |
| Live Activity 8-hour limit | L | L | End and restart activity for ultra-long sessions. Most workouts < 2 hours. |

---

## References

- James Clear, *Atomic Habits* — habit stacking, anchor habits, identity-based habits
- Things 3 — Area > Project > Task hierarchy, deadline vs schedule separation
- Todoist — Section-based organization, recurring task model
- Streaks — Minimal habit tracking with streak visualization, Apple Watch complications
- Strong/Hevy — Workout template → session instance pattern, HealthKit integration
- Apple WWDC25 — HKWorkoutSession on iPhone/iPad, App Intents advances, WidgetKit glass material
- Apple HIG — Managing notifications, health data privacy guidelines
- Apple Developer Docs — ActivityKit, HealthKit, App Intents, WidgetKit
