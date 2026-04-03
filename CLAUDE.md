# dashboard.fitness -- Claude Code Reference

**Owner:** Chris Stroud
**Location:** `~/Developer/dashboard.fitness` (symlinked to iCloud Drive)

---

## Purpose

Personal fitness dashboard. Solving my own problem first -- maybe a product one day. Synced via iCloud Drive, edited on iPhone (1Writer), managed on Mac (Obsidian + Claude Code). The dashboard is a GitHub Pages PWA generated daily by GitHub Actions from structured data files.

---

## Current State

| Layer | What Exists |
|-------|-------------|
| **Frontend** | Static PWA (`index.html`) served via GitHub Pages |
| **Generation** | GitHub Actions daily workflow (`.github/workflows/daily.yml`) |
| **Data** | YAML/JSON in `data/` (Whoop, weight, bloodwork, schedule) |
| **Scripts** | Python automation for data sync and schedule generation |
| **Docs** | Markdown knowledge base (training, nutrition, research, health) |
| **Framework** | TBD -- no server framework chosen yet |

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
/sm epics                    -> Create epics from PRD
/sm story [epic-id]          -> Create detailed story
/dev implement [story-id]    -> Build the feature
/ship                        -> Push and create PR
```

No theme/initiative layer. No sprint infrastructure. Just brief -> prd -> architecture -> epics -> stories -> dev -> ship.

---

## Conventions

### Code Style
- Python: PEP 8, 4-space indent
- Type hints required on all new functions (`from __future__ import annotations`)
- YAML: 2-space indent, ISO 8601 dates
- Git: Imperative commit messages

### File Size
- Target 300-500 lines per module
- Never exceed 2,000 lines
- Decompose before adding new code to large files

### Bisectable Commit Convention

When a change spans multiple layers, commit in this order so `git bisect` works:

1. **Data layer** (models, schemas, data files) -- commit if tests pass
2. **API layer** (routes, endpoints) -- commit if tests pass
3. **UI layer** (templates, JS, CSS) -- commit if tests pass
4. **Config/infra** (settings, workflows) -- commit if tests pass
5. **Tests** (new test files only -- test updates go with their layer) -- commit
6. **Docs** (story status, archive, planning docs) -- separate commit

Each commit must be independently valid. Small changes (single layer, <10 files) = one commit is fine.

### Documentation
- Markdown only (`.md`) -- never `.docx`, `.doc`, or other formats
- Screenshots go in `_screenshots/` (gitignored), never project root

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
# Current (static PWA)
open index.html                       # Preview dashboard locally
python scripts/schedule.py            # Regenerate schedule data
./scripts/sync.sh                     # Sync data from APIs
git status --short

# Future (framework TBD)
# python app.py                       # Start dev server
# python -m pytest tests/ -v          # Run tests
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
