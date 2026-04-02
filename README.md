# dashboard.fitness

**Personal fitness dashboard. Train every day. Track sessions, not minutes.**

Everything counts — lifting, running, yoga, sauna, cold plunge, dog walks. No optimization theater. Volume is volume.

## How It Works

- **`docs/`** — Training logs, programs, health records. Written and edited on iPhone, synced via iCloud.
- **`data/`** — Structured data pulled from APIs (Whoop, scale, bloodwork). Machine-generated, don't hand-edit.
- **`scripts/`** — Python automation that syncs external data into `data/`.

Claude Code reads everything, generates weekly log files, tracks progressions, and flags gaps.

## Quick Start

1. Open `docs/training/logs/` — find or create this week's file
2. Log sessions under the day heading — exercises, weights, notes
3. Ask Claude to update progressions or generate next week's file

## Data Sources

| Source | Status | Data |
|--------|--------|------|
| Manual logs | Active | Training sessions, exercises, weights |
| Whoop | Planned | Recovery, HRV, strain, sleep |
| Scale | Planned | Daily weight |
| Bloodwork | Planned | Biomarkers (Whoop Labs or independent) |
