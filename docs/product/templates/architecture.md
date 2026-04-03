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

### New Data Structures

{{Describe new data files, schemas, or database tables. Framework/stack TBD -- describe the logical model, not the implementation.}}

```
# Example: YAML data structure
workout:
  date: 2026-04-03
  type: upper_a
  exercises:
    - name: bench_press
      sets: [{weight: 225, reps: 5}, ...]
```

### Relationships

```
{{relationship_diagram}}
```

### Model Changes

| Model/File | Field | Change |
|------------|-------|--------|
| {{model}} | {{field}} | Add/Modify/Remove |

---

## API Design

{{Stack TBD. Describe endpoints by intent. Update with concrete routes when framework is chosen.}}

| Method | Endpoint | Purpose |
|--------|----------|---------|
| {{method}} | {{endpoint}} | {{purpose}} |

---

## UI Components

| File | Change |
|------|--------|
| {{file}} | {{change}} |

### UI Architecture _(for UI-heavy features -- skip for data-only)_

**Entry points:** {{How the user reaches this feature}}

**State management:** {{Where state lives -- DOM, JS module, URL params, localStorage}}

**Component structure:**
```
{{component tree}}
```

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
