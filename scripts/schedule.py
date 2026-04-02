#!/usr/bin/env python3
"""Parse @tags from markdown files and generate a weekly schedule view.

Walks all .md files under the dashboard.fitness root, extracts lines with @tags,
and produces:
  - data/schedule.yaml  (structured intermediate)
  - Week View.md        (human-readable weekly calendar)

Tag syntax:
  @daily @2x/day @4x/week @1x/week     — frequency
  @5am @8pm @morning @evening           — time of day
  @20min @75min                         — duration
  @calendar @reminder @checklist        — integration type
  @cycle(4on/1off)                      — on/off cycling
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from datetime import date, timedelta
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
SCAN_DIRS = [ROOT / "Volume Daddy", ROOT / "docs"]
DAYS_DIR = ROOT / "days"
SCHEDULE_YAML_PATH = DATA_DIR / "schedule.yaml"

# Files to skip — contain @ in non-tag contexts (e.g. "3x15 @ 145")
SKIP_FILES = {"Program Archive.md"}

# --- Tag parsing ---

TAG_RE = re.compile(r"@(\S+)")
FREQ_RE = re.compile(r"^(\d+)x/(day|week)$")
CYCLE_RE = re.compile(r"^cycle\((\d+)on/(\d+)off\)$")
TIME_RE = re.compile(r"^(\d{1,2})(am|pm)$", re.IGNORECASE)
DURATION_RE = re.compile(r"^(\d+)min$")
TIME_WORDS = {"morning": "06:00", "evening": "20:00"}
FREQ_WORDS = {"daily": "1x/day"}
TYPE_WORDS = {"calendar", "reminder", "checklist"}


@dataclass
class ActionItem:
    name: str
    source: str
    frequency: str | None = None
    time: str | None = None
    duration: str | None = None
    item_type: str | None = None
    cycle: str | None = None
    children: list[str] = field(default_factory=list)
    heading_context: str = ""


def classify_tag(raw: str) -> tuple[str, str] | None:
    """Classify a single @tag token. Returns (key, value) or None if unrecognized."""
    lower = raw.lower()

    if lower in FREQ_WORDS:
        return ("frequency", FREQ_WORDS[lower])

    fm = FREQ_RE.match(raw)
    if fm:
        return ("frequency", f"{fm.group(1)}x/{fm.group(2)}")

    cm = CYCLE_RE.match(raw)
    if cm:
        return ("cycle", f"{cm.group(1)}on/{cm.group(2)}off")

    if lower in TIME_WORDS:
        return ("time", TIME_WORDS[lower])

    tm = TIME_RE.match(raw)
    if tm:
        hour, period = int(tm.group(1)), tm.group(2).lower()
        if period == "pm" and hour != 12:
            hour += 12
        if period == "am" and hour == 12:
            hour = 0
        return ("time", f"{hour:02d}:00")

    dm = DURATION_RE.match(raw)
    if dm:
        return ("duration", f"{dm.group(1)}min")

    if lower in TYPE_WORDS:
        return ("item_type", lower)

    return None


def parse_tags(text: str) -> tuple[str, dict]:
    """Extract recognized @tags from a line. Returns (cleaned text, tag dict).

    Only tags that match known patterns are extracted. Unknown @tokens
    (like '@ 145' in exercise notation) are left in the text.
    """
    tags: dict = {}
    recognized_spans: list[tuple[int, int]] = []

    for m in TAG_RE.finditer(text):
        result = classify_tag(m.group(1))
        if result:
            tags[result[0]] = result[1]
            recognized_spans.append((m.start(), m.end()))

    # Remove recognized tags from text (in reverse to preserve positions)
    cleaned = list(text)
    for start, end in reversed(recognized_spans):
        cleaned[start:end] = []
    cleaned_str = "".join(cleaned).strip().rstrip("|").strip()

    return cleaned_str, tags


def has_recognized_tags(text: str) -> bool:
    """Check if a line contains at least one recognized @tag."""
    for m in TAG_RE.finditer(text):
        if classify_tag(m.group(1)) is not None:
            return True
    return False


def parse_table_supplement(row: str) -> str | None:
    """Extract 'Name (Dose)' from a markdown table row."""
    cells = [c.strip() for c in row.split("|")]
    # Filter empties from leading/trailing pipes
    cells = [c for c in cells if c]
    if not cells or cells[0].startswith("--") or cells[0] == "Supplement":
        return None
    name = cells[0]
    dose = cells[1] if len(cells) > 1 else ""
    # Strip any @tags from name and dose
    name = TAG_RE.sub("", name).strip()
    dose = TAG_RE.sub("", dose).strip()
    return f"{name} ({dose})" if dose else name


def parse_file(filepath: Path) -> list[ActionItem]:
    """Parse a single markdown file for @tagged lines."""
    items: list[ActionItem] = []
    rel_path = filepath.relative_to(ROOT)
    lines = filepath.read_text().splitlines()

    current_heading = ""
    checklist_target: ActionItem | None = None

    for i, line in enumerate(lines, 1):
        stripped = line.strip()

        # Skip horizontal rules and empty lines
        if stripped in ("---", ""):
            continue

        # Track headings
        if stripped.startswith("#"):
            heading_text = stripped.lstrip("#").strip()

            if has_recognized_tags(heading_text):
                cleaned, htags = parse_tags(heading_text)
                current_heading = cleaned

                if htags.get("item_type") == "checklist":
                    item = ActionItem(
                        name=cleaned,
                        source=f"{rel_path}:{i}",
                        heading_context=current_heading,
                        **htags,
                    )
                    items.append(item)
                    checklist_target = item
                else:
                    # Heading with non-checklist tags (e.g. "## Strength @4x/week")
                    item = ActionItem(
                        name=cleaned,
                        source=f"{rel_path}:{i}",
                        heading_context=current_heading,
                        **htags,
                    )
                    items.append(item)
                    checklist_target = None
            else:
                current_heading = heading_text.split("—")[0].strip()
                checklist_target = None
            continue

        # Lines with recognized @tags
        if has_recognized_tags(stripped):
            cleaned, tags = parse_tags(stripped)
            # Strip leading list marker
            name = re.sub(r"^[-*]\s*", "", cleaned)
            # Strip markdown links: [text](url) → text
            name = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", name)
            name = name.strip(" -—·")

            # Table row with @tags (e.g. Ashwagandha row)
            if stripped.startswith("|"):
                supp = parse_table_supplement(stripped)
                if supp and checklist_target:
                    checklist_target.children.append(supp)
                    # Also record the cycle as a standalone item
                    if tags.get("cycle"):
                        cycle_name = supp.split("(")[0].strip()
                        items.append(ActionItem(
                            name=cycle_name,
                            source=f"{rel_path}:{i}",
                            cycle=tags["cycle"],
                        ))
                continue

            if not name:
                continue

            item = ActionItem(
                name=name,
                source=f"{rel_path}:{i}",
                heading_context=current_heading,
                **tags,
            )
            items.append(item)
            continue

        # Collect checklist children (non-tagged list items under a tagged heading)
        if checklist_target and stripped.startswith(("-", "*")):
            child = re.sub(r"^[-*]\s*", "", stripped).strip()
            if child and child != "--":
                checklist_target.children.append(child)
            continue

        # Table rows under a checklist heading
        if checklist_target and stripped.startswith("|"):
            supp = parse_table_supplement(stripped)
            if supp:
                checklist_target.children.append(supp)

    return items


def parse_all() -> list[ActionItem]:
    """Walk all markdown files and extract tagged items."""
    items: list[ActionItem] = []
    for scan_dir in SCAN_DIRS:
        if not scan_dir.exists():
            continue
        for md in sorted(scan_dir.rglob("*.md")):
            if md.name in SKIP_FILES:
                continue
            items.extend(parse_file(md))
    return items


# --- YAML output ---

def items_to_yaml(items: list[ActionItem]) -> str:
    records = []
    for item in items:
        rec: dict = {"name": item.name, "source": item.source}
        if item.frequency:
            rec["frequency"] = item.frequency
        if item.time:
            rec["time"] = item.time
        if item.duration:
            rec["duration"] = item.duration
        if item.item_type:
            rec["type"] = item.item_type
        if item.cycle:
            rec["cycle"] = item.cycle
        if item.children:
            rec["items"] = item.children
        records.append(rec)
    return yaml.dump(records, default_flow_style=False, sort_keys=False, allow_unicode=True)


# --- Weekly spine ---

WEEKS_DIR = ROOT / "weeks"

# Workout definitions — strength and cardio
STRENGTH_WORKOUTS = [
    {"name": "Bench Day", "duration": "75min"},
    {"name": "Squat Day", "duration": "80min"},
    {"name": "Press Day", "duration": "80min"},
    {"name": "Hinge Day", "duration": "70min"},
]
CARDIO_WORKOUTS = [
    {"name": "Zone 2", "duration": "50min"},
    {"name": "HIIT", "duration": "45min"},
]


def iso_week_file(d: date) -> Path:
    iso = d.isocalendar()
    return WEEKS_DIR / f"{iso.year}-W{iso.week:02d}.yaml"


def monday_of_week(d: date) -> date:
    return d - timedelta(days=d.weekday())


def read_week_spine(d: date) -> dict:
    """Read or initialize the weekly spine for the ISO week containing d."""
    path = iso_week_file(d)
    if path.exists():
        return yaml.safe_load(path.read_text()) or {}
    # Initialize empty spine
    mon = monday_of_week(d)
    return {
        "week": f"{d.isocalendar().year}-W{d.isocalendar().week:02d}",
        "start": mon.isoformat(),
        "strength": {"target": 4, "done": []},
        "cardio": {"target": 5, "done": []},
    }


def scan_week_completions(d: date) -> dict:
    """Scan day files for the ISO week containing d and build the weekly spine."""
    spine = read_week_spine(d)
    mon = monday_of_week(d)
    strength_done: list[dict] = []
    cardio_done: list[dict] = []

    strength_names = {w["name"] for w in STRENGTH_WORKOUTS}
    cardio_names = {w["name"] for w in CARDIO_WORKOUTS}

    for offset in range(7):
        day = mon + timedelta(days=offset)
        day_file = DAYS_DIR / f"{day.isoformat()}.md"
        if not day_file.exists():
            continue
        content = day_file.read_text()
        for line in content.splitlines():
            if not line.startswith("- [x]"):
                continue
            text = line[6:].strip()
            for name in strength_names:
                if text.startswith(name):
                    strength_done.append({"day": day.isoformat(), "workout": name})
            for name in cardio_names:
                if text.startswith(name):
                    cardio_done.append({"day": day.isoformat(), "workout": name})

    spine["strength"]["done"] = strength_done
    spine["cardio"]["done"] = cardio_done
    return spine


def write_week_spine(d: date, spine: dict) -> None:
    WEEKS_DIR.mkdir(parents=True, exist_ok=True)
    path = iso_week_file(d)
    path.write_text(yaml.dump(spine, default_flow_style=False, sort_keys=False))


# --- Day view ---

def compact_checklist(item: ActionItem) -> str:
    names = []
    for child in item.children:
        short = child.split("(")[0].strip().replace("**", "")
        if short:
            names.append(short)
    return " · ".join(names)


def generate_day(items: list[ActionItem], d: date, spine: dict) -> str:
    d = d or date.today()
    day_name = d.strftime("%A")

    # Classify items
    morning_items: list[ActionItem] = []
    evening_items: list[ActionItem] = []
    anytime_items: list[ActionItem] = []
    checklists: dict[str, ActionItem] = {}

    for item in items:
        freq = item.frequency or ""
        t = item.time or ""

        if item.item_type == "checklist":
            checklists[item.name.lower()] = item
            continue
        if "/week" in freq:
            continue  # handled by workout section
        if "2x/day" in freq:
            morning_items.append(item)
            evening_items.append(item)
            continue
        if "/day" in freq:
            if t and t < "12:00":
                morning_items.append(item)
            elif t and t >= "12:00":
                evening_items.append(item)
            else:
                anytime_items.append(item)

    # What's been done this week
    strength_done_names = {e["workout"] for e in spine.get("strength", {}).get("done", [])}
    cardio_done_workouts = spine.get("cardio", {}).get("done", [])
    cardio_done_count = len(cardio_done_workouts)
    hiit_done = any(e["workout"] == "HIIT" for e in cardio_done_workouts)
    zone2_done_count = sum(1 for e in cardio_done_workouts if e["workout"] == "Zone 2")

    # --- Build output ---
    lines: list[str] = []

    # Header — clean, just the day
    lines.append(f"# {day_name}, {d.strftime('%B %-d')}")
    lines.append("")

    # --- Morning ---
    lines.append("## Morning")
    lines.append("")
    for item in morning_items:
        dur = f" ({item.duration})" if item.duration else ""
        lines.append(f"- [ ] {item.name}{dur}")
    am_supps = checklists.get("morning supplements")
    if am_supps:
        lines.append(f"- [ ] Supplements: {compact_checklist(am_supps)}")
    lines.append("")

    # --- Workout ---
    lines.append("## Workout")
    lines.append("")

    # Strength
    for w in STRENGTH_WORKOUTS:
        if w["name"] in strength_done_names:
            # Find which day it was done
            day_label = ""
            for e in spine["strength"]["done"]:
                if e["workout"] == w["name"]:
                    done_date = date.fromisoformat(e["day"])
                    day_label = f" — {done_date.strftime('%a')}"
                    break
            lines.append(f"- [x] {w['name']} ({w['duration']}){day_label}")
        else:
            lines.append(f"- [ ] {w['name']} ({w['duration']})")

    # Cardio — 4x Zone 2 + 1x HIIT
    for i in range(4):
        if i < zone2_done_count:
            lines.append("- [x] Zone 2 (50min)")
        else:
            lines.append("- [ ] Zone 2 (50min)")
    if hiit_done:
        lines.append("- [x] HIIT (45min)")
    else:
        lines.append("- [ ] HIIT (45min)")

    lines.append("")

    # --- Evening ---
    lines.append("## Evening")
    lines.append("")
    for item in evening_items:
        dur = f" ({item.duration})" if item.duration else ""
        lines.append(f"- [ ] {item.name}{dur}")
    pm_supps = checklists.get("evening supplements")
    if pm_supps:
        lines.append(f"- [ ] Supplements: {compact_checklist(pm_supps)}")

    # --- Other ---
    if anytime_items:
        lines.append("")
        lines.append("## Other")
        lines.append("")
        for item in anytime_items:
            dur = f" ({item.duration})" if item.duration else ""
            lines.append(f"- [ ] {item.name}{dur}")
    lines.append("")

    return "\n".join(lines)


# --- Main ---

ROLLING_DAYS = 7


def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    DAYS_DIR.mkdir(parents=True, exist_ok=True)
    WEEKS_DIR.mkdir(parents=True, exist_ok=True)

    items = parse_all()
    if not items:
        print("No @tagged items found.")
        sys.exit(1)

    # Write schedule.yaml
    yaml_content = items_to_yaml(items)
    SCHEDULE_YAML_PATH.write_text(yaml_content)
    print(f"Wrote {len(items)} items → {SCHEDULE_YAML_PATH.relative_to(ROOT)}")

    # Scan and write weekly spine
    today = date.today()
    spine = scan_week_completions(today)
    write_week_spine(today, spine)
    s_done = len(spine["strength"]["done"])
    c_done = len(spine["cardio"]["done"])
    print(f"Week spine: strength {s_done}/4, cardio {c_done}/5")

    # Generate rolling 7 days (only if file doesn't exist — preserve checkmarks)
    generated = 0
    for offset in range(ROLLING_DAYS):
        d = today + timedelta(days=offset)
        day_file = DAYS_DIR / f"{d.isoformat()}.md"
        if not day_file.exists():
            # Use spine for current week, empty spine for next week
            if d.isocalendar().week == today.isocalendar().week:
                day_spine = spine
            else:
                day_spine = scan_week_completions(d)
                write_week_spine(d, day_spine)
            day_file.write_text(generate_day(items, d, day_spine))
            generated += 1

    print(f"Generated {generated} new day files ({ROLLING_DAYS - generated} already existed)")


if __name__ == "__main__":
    main()
