# Architecture: Protocols v2 — First-Class Atomic Protocols

**PRD Reference:** `docs/product/prd/prd-protocols-v2.md`
**Date:** 2026-04-11
**Status:** Approved

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Type discrimination | `type` String column + type-specific nullable columns | Avoids joins for common reads; new types = new enum value + nullable columns, no migration |
| Completion tracking | New `protocol_completions` table alongside existing DailyTask | DailyTask = daily snapshot for today view; ProtocolCompletion = historical record for analytics. Both write on complete. |
| Daily system | Keep DailyInstance/DailyTask unchanged | Proven pattern; add `type` column to DailyTask for type-aware rendering |
| Document attachment | Join table `protocol_documents` | Many-to-many; a supplement reference doc can attach to multiple protocols |
| Analytics computation | Server-side computed endpoints, not stored | Streaks/rates change daily; computing from `protocol_completions` avoids stale cache and sync complexity |
| HealthKit service | Dedicated `HealthKitService` singleton, iOS-only | Isolates Apple framework dependency; backend never touches HealthKit data |
| Widget architecture | Shared App Group + `AppIntent`-powered buttons | Required for widget ↔ app data sharing; intents enable tap-to-complete from widget |
| Live Activity | Dedicated `WorkoutActivity` via ActivityKit | Separate from widget; driven by `HealthKitService` workout lifecycle |
| Orphan documents | Query-based (docs not in `protocol_documents`) | No special flag; orphan = no rows in join table |
| Stack ordering | `position` column on protocols within a group (already exists) | Current `position` field already supports this; UI change only |

---

## Data Model

### PostgreSQL Tables (API) — Source of Truth

#### Modified: `protocols`

```sql
-- Existing columns preserved
ALTER TABLE protocols ADD COLUMN type VARCHAR(20) NOT NULL DEFAULT 'task';
ALTER TABLE protocols ADD COLUMN activity_type VARCHAR(50);      -- workout only: strength|running|cycling|yoga|hiit|flexibility|other
ALTER TABLE protocols ADD COLUMN duration_minutes INTEGER;        -- estimated duration (both types)
ALTER TABLE protocols ADD COLUMN weekly_target INTEGER;           -- NULL = daily, else N/week
ALTER TABLE protocols ADD COLUMN reminder_time TIME;              -- optional notification trigger
ALTER TABLE protocols ADD COLUMN icon VARCHAR(50);                -- SF Symbol name
ALTER TABLE protocols ADD COLUMN color VARCHAR(20);               -- hex or system color name
```

#### New: `protocol_completions`

```sql
CREATE TABLE protocol_completions (
    id VARCHAR(36) PRIMARY KEY,
    protocol_id VARCHAR(36) NOT NULL REFERENCES protocols(id) ON DELETE CASCADE,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'completed',  -- completed | skipped
    completed_at TIMESTAMP WITH TIME ZONE,
    duration_minutes INTEGER,                          -- actual (workout type)
    calories INTEGER,                                  -- from HealthKit (workout type)
    avg_heart_rate INTEGER,                            -- from HealthKit (workout type)
    notes TEXT,                                        -- optional completion note
    metadata JSONB,                                    -- extensible type-specific data
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(protocol_id, user_id, date)
);
CREATE INDEX idx_protocol_completions_user_date ON protocol_completions(user_id, date);
CREATE INDEX idx_protocol_completions_protocol ON protocol_completions(protocol_id);
```

#### New: `protocol_documents`

```sql
CREATE TABLE protocol_documents (
    id VARCHAR(36) PRIMARY KEY,
    protocol_id VARCHAR(36) NOT NULL REFERENCES protocols(id) ON DELETE CASCADE,
    document_id VARCHAR(36) NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    position INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(protocol_id, document_id)
);
```

#### Modified: `daily_tasks`

```sql
-- Add type awareness for rendering
ALTER TABLE daily_tasks ADD COLUMN type VARCHAR(20) NOT NULL DEFAULT 'task';
ALTER TABLE daily_tasks ADD COLUMN activity_type VARCHAR(50);
ALTER TABLE daily_tasks ADD COLUMN duration_minutes INTEGER;
```

#### Tables Unchanged

- `protocol_sections` — still the top-level time-of-day container (Morning, Training, Evening)
- `protocol_groups` — becomes "Stacks" in UI only; schema stays as-is
- `protocol_change_logs` — still tracks master template edits
- `daily_instances` — still the daily snapshot container
- `documents` — schema unchanged; documents are generic markdown containers
- `folders` — schema unchanged; folders organize documents
- All workout tables (`exercises`, `workout_templates`, etc.) — unchanged, used by workout protocol type

#### Tables Deprecated (Phase 1 keeps, Phase 2 removes)

- `workout_completions` — replaced by `protocol_completions` with `type='workout'`

### Relationships

```
users
  ├── protocol_sections (1:N)
  │     └── protocol_groups (1:N)  [UI: "Stacks"]
  │           └── protocols (1:N)
  │                 ├── protocol_completions (1:N per user per date)
  │                 ├── protocol_documents (N:M) ──→ documents
  │                 └── protocol_change_logs (1:N)
  │
  ├── daily_instances (1:N, unique per date)
  │     └── daily_tasks (1:N)
  │           └── source_protocol_id ──→ protocols.id (soft ref)
  │
  ├── documents (1:N)
  │     └── folders (1:N, self-referencing tree)
  │
  └── workout infrastructure (unchanged)
        ├── workout_sessions → exercise_logs → set_logs
        └── workout_templates → template_exercises
```

### SwiftData Models (iOS)

#### Modified: `UserProtocol`

```swift
@Model
final class UserProtocol {
    @Attribute(.unique) var id: UUID
    var group: ProtocolGroup?
    var label: String
    var subtitle: String?
    var position: Int

    // v2 additions
    var type: String          // "workout" | "task"
    var activityType: String? // workout only: strength, running, etc.
    var durationMinutes: Int? // estimated
    var weeklyTarget: Int?    // NULL = daily
    var reminderTime: Date?   // time-of-day only
    var icon: String?         // SF Symbol name
    var color: String?        // system color name

    // Relationships
    @Relationship(deleteRule: .cascade) var completions: [ProtocolCompletion]
    var documents: [UserDocument]  // via SwiftData implicit many-to-many or explicit join
}
```

#### New: `ProtocolCompletion`

```swift
@Model
final class ProtocolCompletion {
    @Attribute(.unique) var id: UUID
    var userProtocol: UserProtocol?
    var date: Date
    var status: String          // "completed" | "skipped"
    var completedAt: Date?

    // Workout-specific
    var durationMinutes: Int?
    var calories: Int?
    var avgHeartRate: Int?
    var notes: String?
}
```

#### Modified: `DailyTask`

```swift
// Add to existing DailyTask model:
var type: String          // "workout" | "task" — for type-aware rendering
var activityType: String? // workout only
var durationMinutes: Int? // estimated duration
```

#### Modified: `UserDocument`

```swift
// Add relationship:
var protocols: [UserProtocol]  // documents attached to protocols
```

### Migration Notes

| Layer | Model/Table | Field | Change |
|-------|-------------|-------|--------|
| PostgreSQL | `protocols` | `type`, `activity_type`, `duration_minutes`, `weekly_target`, `reminder_time`, `icon`, `color` | Add columns |
| PostgreSQL | `daily_tasks` | `type`, `activity_type`, `duration_minutes` | Add columns |
| PostgreSQL | `protocol_completions` | (entire table) | Create |
| PostgreSQL | `protocol_documents` | (entire table) | Create |
| SwiftData | `UserProtocol` | `type`, `activityType`, `durationMinutes`, `weeklyTarget`, `reminderTime`, `icon`, `color`, `documents` | Add properties |
| SwiftData | `DailyTask` | `type`, `activityType`, `durationMinutes` | Add properties |
| SwiftData | `ProtocolCompletion` | (entire model) | Create |
| SwiftData | `UserDocument` | `protocols` relationship | Add |

**Migration strategy:** All changes are additive (new columns with defaults, new tables). Alembic handles backend. SwiftData lightweight migration handles iOS (additive properties with defaults don't require a `SchemaMigrationPlan`).

**Data backfill (Alembic migration):**
1. Set `protocols.type = 'task'` for all existing protocols
2. For each Document in "Workouts" folder: create Protocol with `type='workout'`, copy `weekly_target`, `duration_minutes`, `activity_type` from Document, link via `protocol_documents`
3. Copy `workout_completions` rows into `protocol_completions` mapping `document_id` → new `protocol_id`

---

## API Design

Flask JSON API deployed on Railway. All endpoints require JWT auth (existing `before_request` guard).

### New Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/protocols/{id}/complete` | Mark protocol complete for today. Body: `{ status, duration_minutes?, calories?, avg_heart_rate?, notes?, metadata? }` |
| DELETE | `/api/protocols/{id}/complete` | Undo today's completion. Query: `?date=YYYY-MM-DD` |
| GET | `/api/protocols/{id}/analytics` | Returns `{ current_streak, longest_streak, rate_7d, rate_30d, total_completions }` |
| GET | `/api/protocols/{id}/history` | Returns completions array. Query: `?from=&to=&limit=90` |
| POST | `/api/protocols/{id}/documents` | Attach document. Body: `{ document_id, position? }` |
| DELETE | `/api/protocols/{id}/documents/{doc_id}` | Detach document |
| GET | `/api/protocols/{id}/documents` | List attached documents with content |
| GET | `/api/documents/orphans` | Documents not attached to any protocol |

### Modified Endpoints

| Method | Endpoint | Change |
|--------|----------|--------|
| POST | `/api/protocols/groups/{id}/protocols` | Accepts `type`, `activity_type`, `duration_minutes`, `weekly_target`, `reminder_time`, `icon`, `color` |
| PUT | `/api/protocols/protocol/{id}` | Accepts new fields; `type` is immutable (rejected if changed) |
| GET | `/api/protocols/` | Response includes new fields on each protocol |
| GET | `/api/protocols/today` | DailyTask response includes `type`, `activity_type`, `duration_minutes` |
| PUT | `/api/protocols/daily/task/{id}` | On status change to `completed`, also write `protocol_completions` row |

### Analytics Computation (Server-Side)

```python
def compute_analytics(protocol_id: str, user_id: str) -> dict:
    completions = ProtocolCompletion.query.filter_by(
        protocol_id=protocol_id, user_id=user_id
    ).order_by(ProtocolCompletion.date.desc()).all()

    # Current streak: consecutive completed days ending today (or yesterday)
    # Longest streak: max consecutive completed days ever
    # 7d/30d rate: completed count / expected count in window
    # Expected count: daily=7 or 30; weekly_target=target*weeks_in_window
    return {
        "current_streak": current_streak,
        "longest_streak": longest_streak,
        "rate_7d": rate_7d,
        "rate_30d": rate_30d,
        "total_completions": len([c for c in completions if c.status == "completed"]),
        "last_completed": completions[0].date.isoformat() if completions else None,
    }
```

### Authentication

No changes. Existing JWT `before_request` guards on `protocols_bp` and `documents_bp` continue to scope all queries by `g.user_id`.

---

## UI Components

### SwiftUI Views

| View | Purpose | Phase |
|------|---------|-------|
| `ProtocolDetailView` (rewrite) | Type-aware detail: analytics, docs, actions, history | P1 |
| `ProtocolAnalyticsCard` | Streak, rates, calendar heatmap component | P1 |
| `CalendarHeatmap` | 30-day grid showing completion status per day | P1 |
| `ProtocolDocumentsSection` | Attached docs list with add/remove | P1 |
| `CreateProtocolSheet` | Type picker → type-specific form fields | P1 |
| `DailyTaskRow` (modify) | Type-aware: workout card vs task checkbox | P1 |
| `WorkoutSessionView` (rewrite) | Active workout: timer, HR, calories, exercise list | P2 |
| `LiveActivityView` | Dynamic Island + lock screen workout display | P2 |
| `TodayWidget` | Interactive `.systemMedium` with protocol checkboxes | P2 |
| `StreakWidget` | `.accessoryCircular` completion ring for lock screen | P2 |
| `ProtocolsWidget` | `.accessoryRectangular` top 3 protocols | P2 |

### UI Architecture

**Entry points:**
- Today tab → DailyTaskRow tap → ProtocolDetailView
- Today tab → DayHeader protocols icon → MasterTemplateEditor (unchanged)
- MasterTemplateEditor → protocol row → ProtocolDetailView
- Widget tap → deep link to ProtocolDetailView
- Siri/Shortcut → deep link to ProtocolDetailView or WorkoutSessionView
- Notification action → AppIntent (no UI open required)

**State management:**
- `@Query` for SwiftData model reads (protocols, completions, documents)
- `@Observable HealthKitService.shared` for workout state (isActive, elapsed, heartRate, calories)
- `@Observable SyncService.shared` for sync status (existing)
- `@Environment(\.modelContext)` for writes (existing pattern)

**View hierarchy:**

```
TabView
├── Tab "Today" → HomeTab
│   └── NavigationStack
│       ├── DailyInstanceView
│       │   ├── DayHeader (date + protocols link + progress ring)
│       │   ├── WorkoutSection (unchanged)
│       │   └── CollapsibleSectionView
│       │       └── CollapsibleGroupCard  [UI label: "Stack"]
│       │           └── DailyTaskRow
│       │               ├── type == "task" → checkbox + label + streak badge
│       │               └── type == "workout" → workout card (activity icon, duration, frequency dots)
│       └── ProtocolDetailView (push on row tap)
│           ├── ProtocolAnalyticsCard
│           │   ├── StreakDisplay (current + longest)
│           │   ├── CompletionRates (7d, 30d pills)
│           │   └── CalendarHeatmap (30-day grid)
│           ├── ProtocolDocumentsSection
│           │   ├── DocumentRow (tap → MarkdownView)
│           │   └── AddDocumentButton
│           ├── type == "workout" section
│           │   ├── StartWorkoutButton → WorkoutSessionView
│           │   └── RecentWorkoutsList
│           └── type == "task" section
│               └── CompletionHistoryList
│
├── Tab "History" → HistoryTab (unchanged)
│
└── Tab "Settings" → SettingsTab
    └── (Docs tab removed, protocols link removed — already on Today)
```

**SwiftUI Previews to create:**
- `ProtocolDetailView_Previews` — task type with 15-day streak, 3 attached docs
- `ProtocolDetailView_Previews` — workout type with weekly target 3/4, HealthKit stats
- `ProtocolAnalyticsCard_Previews` — various streak lengths (0, 7, 30, 100+)
- `CalendarHeatmap_Previews` — mixed completion/skip/miss pattern
- `CreateProtocolSheet_Previews` — both type forms
- `DailyTaskRow_Previews` — workout type row, task type row, completed states

---

## New iOS Targets & Frameworks

### Widget Extension (Phase 2)

```
Dashboard Fitness Widget/
├── DashboardFitnessWidget.swift     -- WidgetBundle entry point
├── TodayWidget.swift                -- .systemMedium interactive checklist
├── StreakWidget.swift                -- .accessoryCircular completion ring
├── ProtocolsWidget.swift            -- .accessoryRectangular top 3
├── WidgetIntents.swift              -- AppIntents for widget buttons
└── SharedDataProvider.swift         -- Reads from App Group container
```

**App Group:** `group.com.chrisstroud.Dashboard-Fitness`
- Main app writes today's protocol state to shared `UserDefaults` suite
- Widget's `TimelineProvider` reads from shared suite
- No direct SwiftData access from widget (performance)

### App Intents (Phase 2)

```swift
// Protocols as AppEntity
struct ProtocolEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Protocol")
    var id: UUID
    var displayRepresentation: DisplayRepresentation { ... }
    static var defaultQuery = ProtocolEntityQuery()
}

// Core intents
struct LogProtocolIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Protocol"
    @Parameter(title: "Protocol") var protocol: ProtocolEntity
    func perform() async throws -> some IntentResult { ... }
}

struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Workout"
    @Parameter(title: "Workout") var workout: ProtocolEntity
    func perform() async throws -> some IntentResult { ... }
}

struct GetTodayProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Progress"
    func perform() async throws -> some IntentResult & ProvidesDialog { ... }
}
```

### HealthKit Service (Phase 2)

```swift
@Observable
final class HealthKitService {
    static let shared = HealthKitService()

    // State
    private(set) var isAuthorized = false
    private(set) var isWorkoutActive = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var heartRate: Double = 0
    private(set) var activeCalories: Double = 0

    // Lifecycle
    func requestAuthorization() async throws { ... }
    func startWorkout(activityType: HKWorkoutActivityType) async throws { ... }
    func endWorkout() async throws -> WorkoutResult { ... }
    func discardWorkout() async throws { ... }

    // Internal
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
}

struct WorkoutResult {
    let duration: TimeInterval
    let activeCalories: Double
    let avgHeartRate: Double?
    let samples: [HKQuantitySample]
}
```

### Live Activity (Phase 2)

```swift
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var elapsed: TimeInterval
        var heartRate: Int
        var calories: Int
        var currentExercise: String?
    }
    let workoutName: String
    let activityType: String
}
```

---

## Implementation Phases

### Phase 1: Foundation (Data Model + Analytics + Docs)

Target: Ship as TestFlight build. Core value: per-protocol tracking + docs inline.

**Backend:**
- [ ] Alembic migration: add columns to `protocols`, `daily_tasks`; create `protocol_completions`, `protocol_documents`
- [ ] Data backfill script: existing → `type='task'`; workout docs → workout protocols
- [ ] New service: `services/analytics.py` — streak, rates, history computation
- [ ] New endpoints: protocol complete/undo, analytics, history
- [ ] New endpoints: protocol-document attach/detach/list, orphan docs
- [ ] Modified endpoint: protocol CRUD accepts new fields, `type` immutable
- [ ] Modified endpoint: daily task status update also writes `protocol_completions`
- [ ] Modified endpoint: `refresh_today()` stamps `type` on DailyTask

**iOS:**
- [ ] SwiftData model updates: UserProtocol, DailyTask, ProtocolCompletion (additive migration)
- [ ] `ProtocolDetailView` rewrite: analytics card, docs section, type-specific actions
- [ ] `ProtocolAnalyticsCard` + `CalendarHeatmap` components
- [ ] `CreateProtocolSheet` with type picker
- [ ] `DailyTaskRow` type-aware rendering (workout card vs task checkbox)
- [ ] Remove Docs tab from `ContentView`
- [ ] `ProtocolDocumentsSection` for inline doc viewing/attaching
- [ ] Orphan docs accessible from MasterTemplateEditor ("Notes" section at bottom)
- [ ] `SyncService` additions: sync completions, protocol-document links

### Phase 2: Apple System Integration (HealthKit + Widgets + Intents)

Target: Ship as TestFlight build. Core value: system-level presence.

**HealthKit:**
- [ ] `HealthKitService` singleton: authorization, workout session lifecycle
- [ ] `WorkoutSessionView` rewrite: live HR, calories, elapsed, exercise list
- [ ] Workout completion writes HealthKit data + API + local completion
- [ ] Workout activity type mapping: protocol `activity_type` → `HKWorkoutActivityType`

**Widgets:**
- [ ] New target: Widget Extension with App Group
- [ ] Shared data provider: main app writes state to App Group `UserDefaults`
- [ ] `TodayWidget` (`.systemMedium`): interactive protocol checklist
- [ ] `StreakWidget` (`.accessoryCircular`): completion ring
- [ ] `ProtocolsWidget` (`.accessoryRectangular`): top 3 today

**App Intents:**
- [ ] `ProtocolEntity` as `AppEntity` with dynamic query
- [ ] `LogProtocolIntent`: mark protocol done
- [ ] `StartWorkoutIntent`: open app to workout session
- [ ] `GetTodayProgressIntent`: Siri summary
- [ ] `AppShortcutsProvider` with trigger phrases
- [ ] Widget buttons wired to intents

**Live Activity:**
- [ ] `WorkoutActivityAttributes` definition
- [ ] Start/update/end activity from `HealthKitService` lifecycle
- [ ] Dynamic Island: compact + expanded presentations
- [ ] Lock screen: workout name + elapsed + HR

### Phase 3: Habit Loop Polish

Target: Refinement build. Core value: delight + retention.

- [ ] Habit stacking sequential flow: completing protocol N highlights N+1
- [ ] Stack anchor time with notification at anchor time
- [ ] Per-protocol reminder notifications with Done/Skip actions
- [ ] Notification suppression for already-completed protocols
- [ ] Protocol templates (pre-built stacks)
- [ ] Drag-and-drop reorder within stacks (existing swipe-to-reorder upgraded)
- [ ] Bulk operations: complete/skip entire stack
- [ ] Weekly summary notification
- [ ] Protocol archiving (soft delete)

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| SwiftData lightweight migration fails on additive properties | H | All new properties are optional with defaults. If migration fails, delete local store and re-sync from API (API is source of truth). |
| HealthKit entitlement rejected in App Review | H | Request only types used (active energy, heart rate, workout). Include clear usage descriptions. Submit early. |
| Widget extension doubles build/test surface | M | Widget is a separate target — won't break main app. Test independently. |
| Backfill migration corrupts existing data | H | Run migration in transaction. Test against production data snapshot first. Keep `workout_completions` table until Phase 2 confirms data integrity. |
| Analytics computation slow for long history | L | Index on `(protocol_id, user_id, date)`. Limit to 90-day lookback for streaks. Paginate history endpoint. |
| App Group data stale in widgets | M | Write to App Group on every completion. Widget timeline refresh on app foreground. Accept 15-min staleness for background updates (WidgetKit limitation). |
