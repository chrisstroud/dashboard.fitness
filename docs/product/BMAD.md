# BMAD Method -- dashboard.fitness

**Breakthrough Method for Agile AI-Driven Development**

Lightweight BMAD adapted for a solo personal project. No themes, initiatives, sprints, or multi-tenant concerns. Just a clean pipeline from idea to shipped code.

---

## Quick Start

### Full Planning (New Features)
```
/pm brief [idea]             -> Create product brief
/pm prd [feature]            -> Write PRD
/architect design [feature]  -> Design architecture
/sm epics                    -> Create epics from PRD
/sm story [epic-id]          -> Create detailed story
/dev implement [story-id]    -> Build the feature
/ship                        -> Push and create PR
```

### Quick Development (Bug Fixes, Small Changes)
```
/dev implement [story-id]    -> Make the change (or fix directly)
/ship                        -> Push and create PR
```

### Quick Capture
```
/idea [description]          -> Append to backlog
```

---

## Decision Tree

```
Is it a bug fix with a clear cause?
  YES -> Quick Fix (skip BMAD, go straight to /dev or direct fix)
  NO  ->
    Does it need new data models or API endpoints?
      YES -> Full Planning (brief -> prd -> architecture -> epics -> stories)
      NO  ->
        Does it span 2+ files?
          YES -> Full Planning
          NO  -> Quick Fix
```

---

## Artifact Flow

```
Brief                    PRD                     Architecture
docs/product/briefs/  -> docs/product/prd/    -> docs/product/architecture/
                                                       |
                                                       v
                                               Epics (docs/product/epics/)
                                                       |
                                                       v
                                               Stories (docs/product/stories/)
                                                       |
                                                       v
                                               Implementation (/dev implement)
                                                       |
                                                       v
                                               Ship (/ship -> PR)
```

---

## Folder Structure

```
.claude/skills/              <- Claude Code skills
  pm/SKILL.md                <- Product Manager
  architect/SKILL.md         <- Technical Architect
  sm/SKILL.md                <- Scrum Master
  dev/SKILL.md               <- Developer
  idea/SKILL.md              <- Quick Idea Capture
  ship/SKILL.md              <- Ship pipeline

docs/product/
  BMAD.md                    <- You are here
  CLAUDE.md                  <- Product planning index
  backlog.md                 <- Flat backlog (ideas + deferred)
  strategy/
    roadmap.md               <- Product roadmap
  templates/                 <- Document templates
    brief.md
    prd.md
    architecture.md
    epic.md
    story.md
  briefs/                    <- Product briefs
  prd/                       <- PRDs
  architecture/              <- Architecture docs
  epics/                     <- Active epics
    done/                    <- Completed epics
  stories/                   <- Active stories
    done/                    <- Completed stories
```

---

## Artifacts Location

| Artifact | Location |
|----------|----------|
| Product Briefs | `docs/product/briefs/` |
| PRDs | `docs/product/prd/` |
| Architecture | `docs/product/architecture/` |
| Epics | `docs/product/epics/` |
| Stories | `docs/product/stories/` |
| Roadmap | `docs/product/strategy/roadmap.md` |
| Backlog | `docs/product/backlog.md` |
| Templates | `docs/product/templates/` |

---

## Workflow Selection

| Situation | Workflow | Typical Time |
|-----------|----------|--------------|
| New feature (2+ files) | Full Planning | Hours to 1 day planning |
| New data model | Full Planning | Hours to 1 day planning |
| Bug fix | Quick Fix | 30 min - 2 hours |
| Small improvement (1 file) | Quick Fix | 1-2 hours |
| Config/data tweak | Direct edit | Minutes |

---

## Skill Commands

| Skill | Command | Purpose |
|-------|---------|---------|
| PM | `/pm brief [idea]` | Create product brief |
| PM | `/pm prd [feature]` | Write PRD |
| PM | `/pm roadmap` | Update roadmap |
| PM | `/pm prioritize` | Review and prioritize backlog |
| Architect | `/architect design [feature]` | Create architecture |
| Architect | `/architect adr [decision]` | Document architecture decision |
| Architect | `/architect feasibility [idea]` | Assess feasibility |
| SM | `/sm epics` | Create epics from PRD |
| SM | `/sm story [epic-id]` | Create next story |
| SM | `/sm status` | Get development status |
| Dev | `/dev implement [story-id]` | Build story |
| Idea | `/idea [description]` | Quick capture to backlog |
| Ship | `/ship` | Push and create PR |

---

## Commit Policy

**Principle: Every skill commits its own output. Commits are checkpoints, not just records.**

Uncommitted work is lost if a session crashes or hits a context limit. Commits serve as recovery points.

### Planning Phase (briefs, PRDs, architecture, epics, stories)

**One commit per skill invocation.** When `/pm prd`, `/architect design`, or `/sm story` produces artifacts, commit them before the session ends or the next skill is invoked.

- **Message format:** `docs: [artifact type] -- [name]` (e.g., `docs: PRD -- data model v2`)
- **Batch OK:** Multiple related artifacts from one invocation can share a commit

### Implementation Phase (`/dev implement`)

**Checkpoint commits per stable layer.** Commit after each layer passes verification:

1. Data layer (models, schemas, data files) -> commit
2. API layer (routes, endpoints) -> commit
3. UI layer (templates, JS, CSS) -> commit
4. Story completion (status -> Complete, archive to `done/`) -> separate commit

**Message format:** `feat: [Story X.Y] [layer description]` (or `fix:` for bug fix stories)

For small stories touching a single layer, one code commit + one archive commit is sufficient.

---

## Context Management

Context limits are the biggest operational risk for AI-driven development. Follow these rules:

1. **Compact between artifacts.** After writing a brief, compact before starting the PRD. After writing stories, compact before implementing.
2. **Compact before skills.** Always run `/compact` before invoking a skill. Skill prompts are large and can spike per-minute token limits.
3. **Compact after ~20 turns.** Proactively compact when a conversation gets long, even if you haven't finished the current task.
4. **Checkpoint commits are recovery points.** If context dies mid-work, the next session resumes from the last commit.

---

## Quality Gates

1. **Brief Approval** -- Before PRD (confirm the problem is worth solving)
2. **PRD Approval** -- Before architecture (confirm scope and requirements)
3. **Architecture Approval** -- Before stories (confirm technical approach)
4. **Code Review** -- Before merge (self-review or PR review)

For a solo project, "approval" means Chris reads the artifact and says "go." No formal sign-off ceremony needed.

---

## Completion Convention

When a story is finished:
1. Set `**Status:** Complete`
2. Set `**Completed:**` to today's date (ISO 8601: `YYYY-MM-DD`)
3. Archive: `git mv docs/product/stories/[file].md docs/product/stories/done/`
4. **Cascade check:** If this was the last story in its epic, archive the epic too: `git mv docs/product/epics/[file].md docs/product/epics/done/`

When an epic is fully archived, check if its linked brief, PRD, and architecture doc have no other active epics referencing them. If so, those docs are effectively "done" -- leave them in place (they serve as reference) but note completion in the artifact header.

**Status vocabulary:** Use only **Not Started**, **In Progress**, or **Complete**. Do not use "Done", "Completed", "Ready", or "Implemented".
