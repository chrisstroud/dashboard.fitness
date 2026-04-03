# Epic {{epic_number}}: {{epic_title}}

**PRD Reference:** [{{prd_name}}](../prd/prd-slug.md)
**Architecture:** [{{arch_name}}](../architecture/arch-slug.md) _(if applicable)_
**Status:** Not Started | In Progress | Complete
**Owner:** Chris

---

## Overview

{{epic_description}}

### Value

{{Why this matters -- what burden does it reduce or what capability does it add?}}

### Success Criteria

- [ ] {{criterion_1}}
- [ ] {{criterion_2}}

---

## Scope

### In Scope
- {{in_scope_1}}
- {{in_scope_2}}

### Out of Scope
- {{out_scope_1}}

### Dependencies
- Epic {{dependency_epic}}: {{dependency_description}}

---

## Stories

| ID | Story | Points | Status |
|----|-------|--------|--------|
| {{epic_number}}.1 | {{story_1_title}} | {{points}} | Not Started |
| {{epic_number}}.2 | {{story_2_title}} | {{points}} | Not Started |
| {{epic_number}}.3 | {{story_3_title}} | {{points}} | Not Started |

---

## Technical Context

### Affected Components
- {{component_1}}
- {{component_2}}

### Key Files
- `{{file_1}}`
- `{{file_2}}`

### Architecture Notes
{{architecture_notes}}

---

## Context Digest

> Compressed from PRD and Architecture. Read these for full detail:
> - PRD: `docs/product/prd/{{feature}}.md`
> - Architecture: `docs/product/architecture/{{feature}}.md`

### Decisions Affecting This Epic
- {{Decision}}: {{Choice}} -- {{rationale}}

### Scope for This Epic
- In: {{what this epic covers}}
- Out: {{what other epics cover}}

### Data Model
{{Only models/fields this epic creates or modifies}}

### API Surface
{{Only endpoints this epic creates or modifies}}

### UI Changes
{{Only templates/JS this epic touches}}

### Patterns to Follow
{{Specific code patterns or existing implementations to reference}}

### Dependencies
- Requires: {{epics/systems that must exist first}}
- Provides: {{what downstream work needs from this epic}}

---

## Risks

| Risk | Mitigation |
|------|------------|
| {{risk_1}} | {{mitigation_1}} |

---

## Progress Log

| Date | Update |
|------|--------|
| {{date}} | Epic created |
