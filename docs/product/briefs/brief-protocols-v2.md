# Product Brief: Protocols v2 — First-Class Atomic Protocols

**Date:** 2026-04-11
**Status:** Approved

---

## Problem Statement

Protocols are currently a settings-level configuration detail, not a core experience. They exist as a flat Section → Group → Protocol hierarchy used only to generate daily task snapshots. Meanwhile, documents (notes, workout plans) live in a completely separate system with no meaningful connection to the protocols they support. There's no concept of protocol *types*, no per-protocol analytics, and no integration with iOS system capabilities like HealthKit.

## User Impact

Today's experience: protocols are a static checklist. You check "Take Boron" and "Bench Day" with the same UI — no awareness that one is a 60-minute HealthKit workout and the other is a 5-second task. There's no tracking history per protocol, no streaks, no way to see "I've done Morning Meditation 23 of the last 30 days." Documents exist in a separate tab that requires manual mental linking ("which doc goes with which protocol?"). The system can't grow into notifications, habit stacking, or intelligent scheduling because protocols lack the metadata to support it.

## Proposed Solution

Elevate Protocol to a first-class, typed atomic unit — the core primitive of the entire app. Each protocol has a `type` (initially `workout` or `task`), its own completion history, streak tracking, attached documents, and type-specific behavior. Workout protocols integrate with HealthKit. Task protocols track binary completion with streak analytics. The separate Docs tab merges into protocols — every document belongs to a protocol. Grouping uses a habit-stacking model: protocols are organized into Stacks (ordered sequences with temporal anchoring) within Sections (time-of-day containers like Morning/Evening).

## Key Concepts

### Protocol Types (Discriminated Union)
- **Workout** — HealthKit integrated, tracks duration/calories/heart rate, has exercise structure, weekly frequency targets
- **Task** — Binary completion (done/skipped), streak tracking, optional duration estimate. Future: notifications, location triggers

### Atomic Unit Properties (All Types)
- Completion history with per-day status
- Current streak + longest streak
- Rolling analytics (7d/30d completion rate)
- Multiple attached documents (notes, plans, references)
- Estimated duration
- Schedule/recurrence metadata

### Habit Stacking
Groups become **Stacks** — ordered sequences of protocols anchored to a time or trigger. "After I [wake up], I do [Stack: Bathroom → Supplements → Meditation]." Completing one protocol in a stack surfaces the next. This maps directly to the existing Group concept but adds intentional ordering and the habit-stacking mental model.

### Docs Folded In
The standalone Docs tab is removed. Documents attach to protocols (many-to-one: a protocol can have multiple docs). Orphan documents (not attached to any protocol) are accessible from a "Notes" section within the protocols view. The folder system is preserved for organization within protocols that have many documents.

## Success Criteria

- Every protocol has a type, completion history, and at least basic analytics (streak, completion rate)
- Workout protocols can start/complete HealthKit workout sessions
- Documents are accessible from their parent protocol — no separate Docs tab needed
- The daily Today view renders protocol cards appropriate to their type (workout card vs task checkbox)
- Data model supports future types (medication, journaling, etc.) without schema changes
- Existing user data migrates cleanly (current protocols become `task` type, workout docs become `workout` type protocols)

## Effort Estimate

- **Complexity:** High
- **Files affected:** 25-35 (models, API routes, services, iOS views, sync)
- **New data models:** Yes — Protocol type system, ProtocolDocument join, ProtocolCompletion refactor, HealthKit session tracking
- **Migration required:** Yes — Alembic migration for backend, SwiftData migration for iOS

## Recommendation

**Go** — This is the architectural foundation the app needs. The current flat-checklist model has hit its ceiling. Every future feature (notifications, Apple Watch, intelligent scheduling, social) depends on protocols being typed, trackable atomic units. The existing Section → Group → Protocol hierarchy maps cleanly to Section → Stack → Protocol, minimizing conceptual churn. Documents merging in simplifies the app's mental model from "protocols + docs" to just "protocols (with notes)."

**Risk:** This is a large change touching every layer. Mitigate by phasing: Phase 1 delivers the type system + per-protocol analytics + doc attachment. Phase 2 delivers HealthKit integration. Phase 3 delivers habit-stacking UX (sequential completion flow).

## Next Steps

- [x] Research best practices (task management, atomic habits, HealthKit patterns)
- [ ] PRD required — detailed requirements for each phase
- [ ] Architecture review needed — data model redesign, migration strategy
- [ ] Design exploration needed — protocol detail view, type-specific cards, analytics views
