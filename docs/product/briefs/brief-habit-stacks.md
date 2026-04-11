# Product Brief: Habit Stacks — Atomic Habits-Driven Protocol Hierarchy

**Date:** 2026-04-11
**Status:** Approved
**Builds on:** [Protocols v2 Brief](brief-protocols-v2.md)

---

## Problem Statement

The protocol hierarchy was recently flattened from Section → Group → Protocol down to Section → Protocol to reduce UX friction. But flat sections lose the ability to express *sequenced chains of behaviors* — the core mechanism behind habit formation. A morning routine isn't a bag of tasks; it's an ordered stack where completing one item cues the next. Without that structure, the app is a checklist, not a habit system.

## User Impact

Chris's morning routine currently shows as a flat list: Bathroom, Supplements, Weigh-In, Meditation, Journaling. But in practice these are two distinct chains — a "Wake Up" stack (bathroom → weigh-in → supplements) and a "Mindset" stack (meditation → journaling). The flat list obscures these natural groupings, making it harder to build automaticity. There's no visual cue that finishing supplements should trigger the next item. The app feels like a to-do list rather than an identity-reinforcing system.

**Current workaround:** Mental sequencing. Chris knows the order — the app doesn't.

## Proposed Solution

Re-introduce a second grouping level using the **Habit Stack** concept from James Clear's Atomic Habits. The hierarchy becomes **Section → Habit Stack → Protocol**, where:

- **Sections** are time-of-day containers (Morning Routine, Evening Routine, Workouts, Anytime)
- **Habit Stacks** are ordered sequences of protocols anchored to a cue or trigger ("After I wake up, I do [Wake Up Stack]")
- **Protocols** remain the atomic unit — individual tasks or workouts with type, analytics, and completion tracking

This maps directly to the existing `ProtocolSection → ProtocolGroup → UserProtocol` data model. `ProtocolGroup` is renamed conceptually to "Habit Stack" in the UI — no schema change needed.

### Atomic Habits Principles Applied

| Principle | How It Manifests |
|---|---|
| **Habit Stacking** (Ch. 5) | Stacks ARE the grouping layer. Formula: "After [previous protocol], I will [next protocol]." Sequential ordering within a stack means completing one item visually cues the next. |
| **Four Laws of Behavior Change** | **Obvious:** Stacks surface what's next, not just what's remaining. **Attractive:** Stack completion rings show progress toward full-stack completion. **Easy:** Default stacks pre-loaded; adding protocols drops into existing stacks without hierarchy management. **Satisfying:** Stack-level completion animation when all items in a stack are done. |
| **Identity-Based Habits** (Ch. 2) | Sections map to identity roles. "Morning Routine" = "I am someone who has a morning practice." Stack names reinforce sub-identities: "Wake Up Protocol" = "I am someone who starts the day with intention." |
| **Environment Design** (Ch. 6, 12) | The app itself is the environmental cue. Stack ordering decides what the user sees first. Decisive moments (the 2-3 highest-leverage choices per day) map to the first protocol in each stack. |
| **Two-Minute Rule** (Ch. 13) | Protocol-level metadata: optional `minimum_version` field. On low-energy days, the stack shows the minimum viable action for each item, keeping the streak alive. (Future enhancement — flag for brief.) |
| **Don't Break the Chain** (Ch. 16) | Per-stack streak tracking alongside per-protocol streaks. "You've completed your Wake Up Stack 14 days in a row." Stack-level analytics compound the satisfaction of individual protocol streaks. |
| **Decisive Moments** (Ch. 14) | The first protocol in each stack is the decisive moment. If you start the stack, you'll likely finish it. Notification design (future) targets stack-start triggers, not individual items. |

### UX Rules

1. **Both pages identical.** My Protocols and Daily Today show the same layout: Section header → Habit Stack cards → Protocol rows inside each card.
2. **Stacks are visually distinct cards.** Each stack is a rounded-rect card with a header (stack name, completion count) and protocol rows inside. This is the missing visual grouping that makes sections readable.
3. **Default stacks auto-created.** When a section is created, it gets one default stack with the same name. Users see one level unless they explicitly add more stacks.
4. **Adding protocols is still low-friction.** "Add Protocol" opens the sheet with section and stack pickers. If a section has only one stack, the stack picker is hidden — feels like adding directly to a section.
5. **Stack ordering is drag-reorderable.** Both stacks within a section and protocols within a stack can be reordered.

## Success Criteria

- Both My Protocols and Daily Today render Section → Habit Stack → Protocol with identical visual hierarchy
- Each stack shows its own completion progress (e.g., "3/5") and optional completion ring
- Adding a protocol to a section with one stack requires zero extra taps vs. current flow
- Stack names are editable and default to the section name
- Completing the last protocol in a stack triggers a distinct visual acknowledgment

## Effort Estimate

- **Complexity:** Medium
- **Files affected:** ~10 (HomeTab, MasterTemplateEditor, DailySectionView, CreateProtocolSheet, models, sync)
- **New data models:** No — `ProtocolGroup` already exists in the schema. This is a UI/UX restructure with possible field additions (stack description, ordering)
- **Migration required:** No schema migration. Possible data cleanup to ensure every section has at least one group.

## Recommendation

**Go** — The data model already supports this (Section → Group → Protocol exists in both SwiftData and the API). The previous session flattened the UI to one level to fix hierarchy bugs, but the user has confirmed two levels is the desired end state. This brief reframes "Group" as "Habit Stack" and applies Atomic Habits principles to drive UX decisions. The effort is primarily UI — re-introducing the stack card between section headers and protocol rows on both pages.

**Risk:** Low. The schema already exists. Main risk is UX complexity creep — mitigated by the "one default stack" rule that keeps simple cases simple.

## Future Enhancements (Out of Scope)

- **Sequential completion flow:** Completing a protocol auto-scrolls/highlights the next one in the stack
- **Stack-level streaks and analytics:** Per-stack completion history (requires API changes)
- **Two-Minute Rule mode:** Toggle to show minimum-viable versions of protocols on low-energy days
- **Decisive moment notifications:** Smart notifications targeting the first protocol in high-leverage stacks
- **Cue/trigger metadata:** "After [trigger], I will [stack]" — explicit anchoring for each stack
- **Temptation bundling:** Pair less appealing protocols with appealing ones within a stack

## Next Steps

- [ ] PRD required — detailed requirements for stack UI, both pages, creation flow
- [ ] Architecture review needed — confirm ProtocolGroup reuse, identify any field additions
- [ ] Design exploration needed — stack card design, completion animations, both-page layout
