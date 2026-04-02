# dashboard.fitness — Claude Code Reference

**Owner:** Chris Stroud
**Location:** `~/Developer/dashboard.fitness` → symlinked to iCloud Drive

---

## Purpose

Personal fitness dashboard. Solving my own problem first — maybe a product one day. Synced via iCloud Drive, edited on iPhone (1Writer), managed on Mac (Obsidian + Claude Code).

## Structure

```
dashboard.fitness/
  CLAUDE.md
  README.md
  Ethos.md                       ← training philosophy, macrocycle, big rocks, lifestyle
  Volume Daddy/                  ← workout logs (daily use, phone-first)
    Training Program.md          ← weekly plan with links to workouts
    Bench Day.md                 ← Upper A — current numbers + log
    Press Day.md                 ← Upper B — current numbers + log
    Leg Day.md                   ← current numbers + log
    Arms & Core.md               ← current numbers + log
    Cardio.md                    ← Zone 2/5 log
  docs/                          ← reference material
    Daily Routine.md             ← morning/evening architecture, nutrition, supplements
    Program Archive.md           ← all past & dormant programs, progression history
    health/
      template-bloodwork.md
    research/                    ← things being considered for addition
      Testosterone Protocol.md   ← 6-week protocol (Mar 20 – Apr 29)
      Testosterone Research.md   ← evidence-based research companion
  data/                          ← machine-generated / API pulls (don't hand-edit)
    whoop/
    weight/
    bloodwork/
  scripts/                       ← automation (API sync, data parsing)
```

## Conventions

- `Ethos.md` = the "why" — read when motivation dips, not daily
- `Volume Daddy/` = daily-use workout files, one per workout type, flat text logging
- `docs/` = reference material (routines, archives, health records)
- `docs/research/` = things being evaluated for addition to the program
- `data/` = structured data from APIs and devices — don't hand-edit
- `scripts/` = Python automation that populates `data/`
- Claude Code reads all, writes to all, keeps them in sync
