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


# --- Day view ---

def source_link(item: ActionItem) -> str:
    """Build a relative markdown link to the source file."""
    path = item.source.split(":")[0]
    # URL-encode spaces for markdown links
    encoded = path.replace(" ", "%20")
    return f"[↗]({encoded})"


def compact_checklist(item: ActionItem) -> str:
    """Render a checklist as a single compact line: Name — item · item · item [↗]"""
    names = []
    for child in item.children:
        # Strip dose parens for compactness: "Fish Oil (EPA/DHA) (3–5g)" → "Fish Oil"
        # Keep first word group before any parenthetical
        short = child.split("(")[0].strip()
        # Drop markdown bold markers
        short = short.replace("**", "")
        if short:
            names.append(short)
    return " · ".join(names)


def generate_today(items: list[ActionItem], d: date | None = None) -> str:
    d = d or date.today()
    day_name = d.strftime("%A")

    # Buckets
    weekly: list[str] = []
    cycle_notes: list[str] = []
    morning_items: list[ActionItem] = []
    evening_items: list[ActionItem] = []
    anytime_items: list[ActionItem] = []
    checklists: dict[str, ActionItem] = {}  # keyed by name for smart grouping

    for item in items:
        if item.cycle and not item.item_type:
            cycle_notes.append(f"{item.name} ({item.cycle})")

        freq = item.frequency or ""
        t = item.time or ""

        if item.item_type == "checklist":
            checklists[item.name.lower()] = item
            continue

        if "/week" in freq:
            weekly.append(item)
            continue

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

    # --- Build output ---
    lines: list[str] = []

    # Header
    lines.append(f"# {day_name}, {d.strftime('%B %-d')}")
    lines.append("")
    if cycle_notes:
        lines.append(f"> {' · '.join(cycle_notes)}")
        lines.append("")

    # Weekly targets — compact single block
    if weekly:
        targets = []
        for w in weekly:
            dur = f" ({w.duration})" if w.duration else ""
            targets.append(f"{w.name}{dur}")
        lines.append(f"**This week:** {' · '.join(targets)}")
        lines.append("")

    # --- Morning ---
    lines.append("## Morning")
    lines.append("")
    for item in morning_items:
        dur = f" ({item.duration})" if item.duration else ""
        lines.append(f"- [ ] {item.name}{dur} {source_link(item)}")

    # Morning supplements — compact
    am_supps = checklists.get("morning supplements")
    if am_supps:
        summary = compact_checklist(am_supps)
        lines.append(f"- [ ] Supplements: {summary} {source_link(am_supps)}")

    lines.append("")

    # --- Workout ---
    lines.append("## Workout")
    lines.append("")
    lines.append("- [ ] _____ *(Bench · Squat · Press · Hinge · Zone 2 · HIIT)*")
    for item in anytime_items:
        dur = f" ({item.duration})" if item.duration else ""
        lines.append(f"- [ ] {item.name}{dur} {source_link(item)}")
    lines.append("")

    # --- Evening ---
    lines.append("## Evening")
    lines.append("")
    for item in evening_items:
        dur = f" ({item.duration})" if item.duration else ""
        lines.append(f"- [ ] {item.name}{dur} {source_link(item)}")

    # Evening supplements — compact
    pm_supps = checklists.get("evening supplements")
    if pm_supps:
        summary = compact_checklist(pm_supps)
        lines.append(f"- [ ] Supplements: {summary} {source_link(pm_supps)}")

    lines.append("")

    # --- Reference links ---
    lines.append("---")
    lines.append("")
    refs = [
        "[Morning routine](docs/Daily%20Routine.md#morning)",
        "[Evening routine](docs/Daily%20Routine.md#evening)",
        "[Training program](Volume%20Daddy/Training%20Program.md)",
    ]
    lines.append(" · ".join(refs))
    lines.append("")

    return "\n".join(lines)


# --- Main ---

ROLLING_DAYS = 7


def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    DAYS_DIR.mkdir(parents=True, exist_ok=True)

    items = parse_all()
    if not items:
        print("No @tagged items found.")
        sys.exit(1)

    # Write schedule.yaml
    yaml_content = items_to_yaml(items)
    SCHEDULE_YAML_PATH.write_text(yaml_content)
    print(f"Wrote {len(items)} items → {SCHEDULE_YAML_PATH.relative_to(ROOT)}")

    # Generate rolling 7 days (only if file doesn't exist — preserve checkmarks)
    today = date.today()
    generated = 0
    for offset in range(ROLLING_DAYS):
        d = today + timedelta(days=offset)
        day_file = DAYS_DIR / f"{d.isoformat()}.md"
        if not day_file.exists():
            day_file.write_text(generate_today(items, d))
            generated += 1

    print(f"Generated {generated} new day files ({ROLLING_DAYS - generated} already existed)")


if __name__ == "__main__":
    main()
