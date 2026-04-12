# dashboard.fitness -- Claude Code Reference

**Owner:** Chris Stroud
**Location:** `~/Developer/dashboard.fitness` (symlinked to iCloud Drive)

---

## Purpose

Personal fitness app evolving into a multi-user product. Distributed via TestFlight. Native iOS app backed by a Flask API on Railway.

---

## Current State

| Layer | What Exists | Status |
|-------|-------------|--------|
| **iOS App** | Swift + SwiftUI + SwiftData | Planned |
| **Backend API** | Flask + SQLAlchemy + PostgreSQL on Railway | Planned |
| **Auth** | Sign in with Apple -> JWT | Planned |
| **Distribution** | TestFlight | Planned |
| **Data Pipeline** | YAML/JSON in `data/`, GitHub Actions, Python scripts | Existing |
| **Docs** | Markdown knowledge base (training, nutrition, research, health) | Existing |
| **Legacy PWA** | Static `index.html` served via GitHub Pages | Existing (will be superseded by iOS app) |

---

## Directory Map

```
dashboard.fitness/
  CLAUDE.md                         <- You are here
  README.md
  Ethos.md                          <- Training philosophy, macrocycle, big rocks
  index.html                        <- PWA dashboard (GitHub Pages)
  manifest.json                     <- PWA manifest
  version.txt                       <- Build version
  .nojekyll                         <- GitHub Pages bypass
  .github/workflows/
    daily.yml                       <- Daily generation workflow
  Volume Daddy/                     <- Workout logs (daily use, phone-first)
    Training Program.md             <- Weekly plan with links to workouts
    Bench Day.md                    <- Upper A
    Press Day.md                    <- Upper B
    Leg Day.md
    Arms & Core.md
    Cardio.md                       <- Zone 2/5 log
  data/                             <- Machine-generated / API pulls (don't hand-edit)
    whoop/
    weight/
    bloodwork/
    schedule.yaml
  scripts/                          <- Automation (API sync, data parsing)
    schedule.py
    sync.sh
  days/                             <- Daily log files
  weeks/                            <- Weekly rollup files
  docs/                             <- Reference material
    CLAUDE.md                       <- Docs index
    Daily Routine.md
    Ethos.md
    Program Archive.md
    Supplements.md
    Weekly Architecture.md
    health/
      template-bloodwork.md
    research/                       <- Things being evaluated for addition
  docs/product/                     <- BMAD product planning
    CLAUDE.md                       <- Product planning index
    BMAD.md                         <- Planning framework
    backlog.md                      <- Flat backlog (ideas + deferred)
    strategy/
      roadmap.md                    <- Product roadmap
    templates/                      <- Document templates
    briefs/                         <- Product briefs
    prd/                            <- Product requirements documents
    architecture/                   <- Architecture documents
    epics/                          <- Active epics
      done/                         <- Completed epics
    stories/                        <- Active stories
      done/                         <- Completed stories
  .claude/skills/                   <- Claude Code skills
    pm/SKILL.md                     <- Product Manager
    architect/SKILL.md              <- Technical Architect
    designer/SKILL.md               <- Designer (SwiftUI previews)
    sm/SKILL.md                     <- Scrum Master
    dev/SKILL.md                    <- Developer
    idea/SKILL.md                   <- Quick Idea Capture
    ship/SKILL.md                   <- Ship (PR pipeline)
```

---

## BMAD Decision Tree

**Use BMAD (Full Planning)** when:
- New feature or capability
- Spans 2+ files
- Needs data model changes
- UI/UX decisions required

**Skip BMAD (Quick Fix)** when:
- Bug fix with clear cause
- Single-file change
- CSS/copy/config tweak
- Data file update

**Decision:** `Is it a bug? -> Quick Fix` | `New data models? -> BMAD` | `2+ files? -> BMAD`

### Lightweight Pipeline

```
/pm brief [idea]             -> Create product brief
/pm prd [feature]            -> Write PRD
/architect design [feature]  -> Design architecture
/designer preview [feature]  -> SwiftUI preview mockups (UI-heavy features)
/sm epics                    -> Create epics from PRD
/sm story [epic-id]          -> Create detailed story
/dev implement [story-id]    -> Build the feature
/ship                        -> Push and create PR
```

No theme/initiative layer. No sprint infrastructure. Just brief -> prd -> architecture -> design -> epics -> stories -> dev -> ship.

---

## Conventions

### Code Style

**Swift (iOS App):**
- SwiftUI declarative patterns
- `@Observable` for view models, `@Model` for SwiftData
- `async/await` for networking
- One View per file, target 100-300 lines per view
- SwiftUI previews with hardcoded data for every view

**Python (Flask API):**
- PEP 8, 4-space indent
- Type hints required on all new functions (`from __future__ import annotations`)
- SQLAlchemy models + Alembic migrations (never `db.create_all()`)

**Shared:**
- YAML: 2-space indent, ISO 8601 dates
- Git: Imperative commit messages

### File Size
- Target 300-500 lines per module
- Never exceed 2,000 lines
- Decompose before adding new code to large files

### Bisectable Commit Convention

When a change spans multiple layers, commit in this order so `git bisect` works:

1. **Data layer** (SwiftData models, SQLAlchemy models, Alembic migrations) -- commit if tests pass
2. **API layer** (Flask routes, services, endpoints) -- commit if tests pass
3. **UI layer** (SwiftUI views, view models) -- commit if tests pass
4. **Config/infra** (Xcode project, Railway config, scripts, workflows) -- commit if tests pass
5. **Tests** (new test files only -- test updates go with their layer) -- commit
6. **Docs** (story status, archive, planning docs) -- separate commit

Each commit must be independently valid. Small changes (single layer, <10 files) = one commit is fine.

### Documentation
- Markdown only (`.md`) -- never `.docx`, `.doc`, or other formats
- Screenshots go in `_screenshots/` (gitignored), never project root

### Design Parity: Today Page ↔ My Protocols
The **Today** page and **My Protocols** page must always look and behave identically in structure:
- Both use SwiftUI `List` with `Section` containers (white card styling)
- Both use `HabitStackHeader` for stack headers with the same parameters
- Both support collapsible sections (chevron + tap) and collapsible stacks
- Section headers share the same font/layout: chevron → name → status → spacer
- Any structural/UX change to one page **must** be mirrored to the other

Key differences (by design):
- Today shows completion counts (`3/5`) and rings; My Protocols shows protocol counts
- Today has "mark all complete" ring button; My Protocols has context menus for CRUD
- Today auto-collapses completed sections/stacks; My Protocols does not

---

## Subagent Model Routing

**Always pass a `model` parameter when using the Task tool.** Never let subagents inherit Opus by default.

| Subagent type | Model | Rationale |
|---|---|---|
| **Explore** | `haiku` | File search, codebase navigation |
| **Bash** | `haiku` | Command execution |
| **Plan** | `sonnet` | Design exploration, option analysis |
| **general-purpose** (research, reading) | `sonnet` | Synthesis without code generation |
| **general-purpose** (simple code, 1-2 files) | `sonnet` | Single-file stories, small fixes |
| **general-purpose** (complex code, 3+ files) | `opus` | Multi-file reasoning, architecture |

**Rule of thumb:** Reading/searching -> Haiku. Synthesizing/drafting -> Sonnet. Writing code across 3+ files -> Opus.

**Context management:** Run `/compact` after finishing a major task or when conversation exceeds ~20 turns. Always run `/compact` before invoking a skill -- skill prompts are large and can spike per-minute token limits.

---

## Quick Commands

```bash
# iOS App
open ios/DashboardFitness.xcodeproj   # Open in Xcode
xcodebuild -scheme DashboardFitness   # Build from CLI

# Flask API
cd api && python app.py               # Start Flask dev server
cd api && flask db upgrade             # Run migrations
cd api && flask db migrate -m "desc"   # Create migration
cd api && python -m pytest tests/ -v   # Run API tests

# Data Pipeline (existing)
python scripts/schedule.py            # Regenerate schedule data
./scripts/sync.sh                     # Sync data from APIs
git status --short
```

---

## Reference Docs

| Doc | Path |
|-----|------|
| Product planning index | `docs/product/CLAUDE.md` |
| BMAD framework | `docs/product/BMAD.md` |
| Product roadmap | `docs/product/strategy/roadmap.md` |
| Backlog | `docs/product/backlog.md` |
| Docs reference | `docs/CLAUDE.md` |
| Training philosophy | `Ethos.md` |
| Daily routine | `docs/Daily Routine.md` |
| Program archive | `docs/Program Archive.md` |

---

## GitHub

| Item | Value |
|------|-------|
| Repo | `chrisstroud/dashboard.fitness` |
| Pages | GitHub Pages (root, `main` branch) |
| Actions | Daily generation via `.github/workflows/daily.yml` |
