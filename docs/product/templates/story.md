# Story {{epic}}.{{story}}: {{Title}}

**Epic:** [Epic {{epic}}: {{epic_title}}](../epics/epic-{{epic}}-{{slug}}.md)
**Status:** Not Started | In Progress | Complete
**Points:** {{1-5}}
**GitHub Issue:** #{{number}}

---

## User Story

**As a** dashboard user
**I want to** {{action}}
**So that** {{benefit}}

---

## Acceptance Criteria

- [ ] **AC1:** {{Specific, testable criterion}}
- [ ] **AC2:** {{Specific, testable criterion}}
- [ ] **AC3:** {{Specific, testable criterion}}

---

## Technical Context

### Architecture Reference
{{Relevant excerpt from architecture doc}}

### Files to Modify
| File | Purpose | Changes |
|------|---------|---------|
| `{{path/file}}` | {{what it does}} | {{what to change}} |

### New Files to Create
| File | Purpose |
|------|---------|
| `{{path/new_file}}` | {{what it does}} |

---

## Implementation Guidance

### Approach
{{High-level approach in 2-3 sentences}}

### Layer Sequence
{{Which layers this story touches and in what order:}}
1. {{Data layer (SwiftData models / SQLAlchemy models / Alembic migrations)}}
2. {{API layer (Flask routes / services)}}
3. {{UI layer (SwiftUI views / view models)}}

### Step-by-Step
1. {{First step with details}}
2. {{Second step with details}}
3. {{Third step with details}}

### Code Patterns to Follow
```swift
// Reference an existing Swift pattern:
// From ios/DashboardFitness/Views/ExampleView.swift
```
```python
# Reference an existing Python pattern:
# From api/routes/example.py
```

### Gotchas / Watch Out For
- {{Gotcha 1 -- specific issue to avoid}}
- {{Gotcha 2 -- edge case to handle}}

---

## Dev Notes

Architecture constraints, coding patterns, and prior learnings for this story.

### Architecture Constraints
- {{Constraint -- e.g., "SwiftData model must mirror PostgreSQL schema"}}
- {{Constraint -- e.g., "Must work offline with local SwiftData cache"}}

### Patterns to Follow
- {{Pattern -- e.g., "Follow APIClient pattern in ios/DashboardFitness/Services/APIClient.swift"}}

### Previous Learnings
- {{Learning from prior work relevant to this story}}

### References
- {{Source: docs/product/architecture/feature.md#Section}}

---

## Dependencies

### Blocked By
- [ ] Story {{X.Y}}: {{why it must be done first}}

### Blocks
- Story {{X.Y}}: {{why this must be done first}}

### Can Parallel With
- Story {{X.Y}} (no shared files)

---

## Testing Notes

### Test Scenarios
1. {{Happy path test}}
2. {{Edge case test}}

### Edge Cases
- {{Edge case 1}}
- {{Edge case 2}}

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Swift code follows conventions (SwiftUI patterns, type safety)
- [ ] Python code follows conventions (PEP 8, type hints)
- [ ] File size limits respected (300-500 lines target, 2,000 max)
- [ ] SwiftUI previews render correctly with hardcoded data
- [ ] No obvious bugs
- [ ] Self-reviewed before PR
