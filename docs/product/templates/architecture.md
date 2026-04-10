# Architecture: {{feature_name}}

**PRD Reference:** `docs/product/prd/{{feature_slug}}.md`
**Date:** {{date}}
**Status:** Draft | Approved

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| {{decision}} | {{choice}} | {{one_line_why}} |

---

## Data Model

### SwiftData Models (iOS)

{{On-device models for local caching and offline support.}}

```swift
// Example
@Model
class Workout {
    var date: Date
    var type: WorkoutType
    var exercises: [Exercise]
    // ...
}
```

### PostgreSQL Tables (API)

{{Server-side tables -- source of truth for multi-user data.}}

| Table | Columns | Notes |
|-------|---------|-------|
| {{table}} | {{columns}} | {{notes}} |

### Relationships

```
{{relationship_diagram}}
```

### Migration Notes

| Layer | Model/Table | Field | Change |
|-------|-------------|-------|--------|
| SwiftData | {{model}} | {{field}} | Add/Modify/Remove |
| PostgreSQL | {{table}} | {{column}} | Add/Modify/Remove |

---

## API Design

Flask JSON API deployed on Railway.

| Method | Endpoint | Purpose |
|--------|----------|---------|
| {{method}} | `/api/{{path}}` | {{purpose}} |

### Authentication

{{How this feature interacts with Sign in with Apple / JWT auth.}}

---

## UI Components

### SwiftUI Views

| View | Purpose |
|------|---------|
| {{ViewName}} | {{purpose}} |

### UI Architecture _(for UI-heavy features -- skip for data-only)_

**Entry points:** {{Tab, navigation link, sheet, or deeplink}}

**State management:** {{Where state lives -- @State, @Observable, @Query, @Environment}}

**View hierarchy:**
```
{{view tree, e.g.:
NavigationStack
  WorkoutListView
    WorkoutRowView
    WorkoutDetailView
      ExerciseSection
}}
```

**SwiftUI Previews:** {{List preview screens to create with hardcoded data}}

---

## Implementation Phases

### Phase 1: {{name}}
- [ ] {{task}}

### Phase 2: {{name}}
- [ ] {{task}}

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| {{risk}} | H/M/L | {{mitigation}} |
