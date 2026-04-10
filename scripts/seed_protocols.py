"""Seed folders, docs, sections, groups, and protocols.

Usage:
    cd ~/Developer/dashboard.fitness
    source api/.venv/bin/activate
    PYTHONPATH=. python scripts/seed_protocols.py
"""
from __future__ import annotations

import requests

BASE = "http://localhost:5001/api"

folder_ids: dict[str, str] = {}
doc_ids: dict[str, str] = {}
section_ids: dict[str, str] = {}

# Ensure user exists
requests.get(f"{BASE}/users/me")

FOLDERS = [
    {"name": "Routines", "position": 0},
    {"name": "Supplements", "position": 1},
    {"name": "Workouts", "position": 2},
    {"name": "Research", "position": 3},
]

DOCS = [
    {"title": "Morning Routine", "folder": "Routines",
     "content": "# Morning Routine\n\nWake at 5 AM. Bathroom first, then teeth before coffee to protect enamel from acid.\n\nCoffee delayed 60-90 min after waking to preserve natural cortisol curve.\n\n## Skincare\n\nVitamin C serum → mineral sunscreen (SPF 30-50 if UV index 3+) → moisturize.\n\n## Breakfast\n\n- Shake: water + 50g whey + 10g creatine + 2 tbsp chia seeds\n- 1 cup oats + cinnamon + raw honey"},
    {"title": "Evening Routine", "folder": "Routines",
     "content": "# Evening Routine\n\n## Timeline\n\n- **6 PM** — Dinner (3 hrs before bed)\n- **7 PM** — Stop eating\n- **8 PM** — No more liquids, no blue light (Kindle only)\n\n## Wind Down\n\nCyclic sighing: 5 min double inhale nose, long slow exhale mouth.\n\n## Skincare\n\nRetinol + moisturize."},
    {"title": "Daily Habits", "folder": "Routines",
     "content": "# Daily Habits\n\n## TM Meditation\n\n2x/day, 20 min each. Morning and evening.\n\n## Dog Walk\n\nDaily. Light exposure + movement + mental reset."},
    {"title": "Morning Supplements", "folder": "Supplements",
     "content": "# Morning Supplements\n\n| Supplement | Dose | Why |\n|---|---|---|\n| Fish Oil (EPA/DHA) | 3-5g | Anti-inflammatory, cardiovascular, cognitive |\n| Vitamin D3 + K2 | 5,000 IU / 200mcg | Target 40-60 ng/mL |\n| Zinc Picolinate | 15-20mg | Testosterone support, immune |\n| Boron | 10mg | May support free T |\n| Creatine | 10g | Muscle + bone + cognitive |\n| Multivitamin | 1x | Methylated B vitamins |"},
    {"title": "Evening Supplements", "folder": "Supplements",
     "content": "# Evening Supplements\n\n| Supplement | Dose | Why |\n|---|---|---|\n| Magnesium Glycinate | 400mg | Sleep quality, recovery |\n| L-Theanine | 200mg | Synergistic with mag |\n| Ashwagandha KSM-66 | 600mg | Cortisol reduction. Cycle 4on/1off |\n| Glycine | 3-5g | Lowers core temp, collagen |"},
    {"title": "Bench Day", "folder": "Workouts",
     "content": "# Bench Day\n\n*~75-85 min*\n\n## DNS Stability (5 min)\n- Dead bugs: 2x8\n- Bird dogs: 2x8\n- Crocodile breathing: 5 breaths\n\n## ATG Warm-Up\n- External rotations 3x12\n- Powell raises 3x12\n\n## Strength\n- Bench\n- Incline DB\n- BB Row\n\n## Shoulders\n- Lateral raises: 3x12\n- Face pulls: 3x15\n\n## Arms (superset)\n- Triceps\n- Curls\n\n## Core Finisher\n- Hanging leg raises: 25 reps\n\n---\n\n## Log\n\n"},
    {"title": "Squat Day", "folder": "Workouts",
     "content": "# Squat Day\n\n*~75-85 min*\n\n## DNS Stability (5 min)\n- Dead bugs: 2x8\n- Bird dogs: 2x8\n- Crocodile breathing: 5 breaths\n\n## ATG Warm-Up\n- Tib raises: 4x25\n- Calf raises (weighted)\n- Elevated ATG split squats: 3x8\n\n## Explosive\n- Box jumps: 5x3\n\n## Strength\n- Back Squat\n- Bulgarian Split Squat\n\n## Upper Pull\n- Weighted Chins\n\n## Core Finisher\n- Ab rollouts: 3x10\n\n---\n\n## Log\n\n"},
    {"title": "Press Day", "folder": "Workouts",
     "content": "# Press Day\n\n*~75-85 min*\n\n## DNS Stability (5 min)\n- Dead bugs: 2x8\n- Bird dogs: 2x8\n- Crocodile breathing: 5 breaths\n\n## ATG Warm-Up\n- External rotations 3x12\n- Powell raises 3x12\n\n## Strength\n- OHP\n- DB Pullover\n\n## Shoulders\n- ATG press: 3x10\n- Lateral raises: 3x12\n- Face pulls: 3x15\n\n## Arms (superset)\n- Triceps\n- Curls\n\n## Back\n- Back extensions: 100 reps\n- Max hangs: 3x\n\n## Core Finisher\n- Farmer's carry: 3x heavy\n\n---\n\n## Log\n\n"},
    {"title": "Hinge Day", "folder": "Workouts",
     "content": "# Hinge Day\n\n*~65-75 min*\n\n## DNS Stability (5 min)\n- Dead bugs: 2x8\n- Bird dogs: 2x8\n- Crocodile breathing: 5 breaths\n\n## ATG Warm-Up\n- Tib raises: 4x25\n- Nordics: 5x5\n- Sissy squats: 3x\n\n## Explosive\n- Box jumps: 5x3\n\n## Strength\n- Deadlift or RDL\n- Glute work\n- Leg curls\n\n## Upper Pull\n- BB Rows or DB Rows\n\n## Core Finisher\n- Hanging leg raises: 25 reps\n\n---\n\n## Log\n\n"},
    {"title": "Zone 2 Ride", "folder": "Workouts",
     "content": "# Zone 2 Bike Ride\n\n*45-60 min, easy pace*\n\nConversational pace. Talk test: can converse but not sing.\n\n**Target:** 180 min/week total Zone 2\n\n---\n\n## Log\n\n"},
    {"title": "HIIT Hills", "folder": "Workouts",
     "content": "# HIIT Hill Ride\n\n*~45 min with warm-up/cooldown*\n\nNorwegian 4x4:\n- 4 min hard (85-95% HRmax)\n- 3 min easy (~70% HRmax)\n- Repeat x4\n\n---\n\n## Log\n\n"},
]

SECTIONS = [
    {"name": "Morning", "position": 0, "groups": [
        {"name": "Bathroom", "position": 0, "protocols": [
            {"label": "Splash water on face"},
            {"label": "Brush teeth + tongue scrape"},
        ]},
        {"name": "Morning Routine", "position": 1, "protocols": [
            {"label": "Exercise + morning light", "doc": "Morning Routine"},
            {"label": "Coffee", "subtitle": "Delay 60-90 min after waking", "doc": "Morning Routine"},
            {"label": "Shower"},
            {"label": "Skincare", "subtitle": "Vitamin C → sunscreen → moisturize", "doc": "Morning Routine"},
            {"label": "Breakfast", "subtitle": "Shake + oats + creatine", "doc": "Morning Routine"},
        ]},
        {"name": "Morning Supplements", "position": 2, "protocols": [
            {"label": "Fish Oil (EPA/DHA)", "subtitle": "3-5g combined", "doc": "Morning Supplements"},
            {"label": "Vitamin D3 + K2", "subtitle": "5,000 IU / 200mcg", "doc": "Morning Supplements"},
            {"label": "Zinc Picolinate", "subtitle": "15-20mg", "doc": "Morning Supplements"},
            {"label": "Boron", "subtitle": "10mg", "doc": "Morning Supplements"},
            {"label": "Creatine Monohydrate", "subtitle": "10g in shake", "doc": "Morning Supplements"},
            {"label": "Multivitamin", "subtitle": "1x", "doc": "Morning Supplements"},
        ]},
    ]},
    {"name": "Evening", "position": 1, "groups": [
        {"name": "Wind Down", "position": 0, "protocols": [
            {"label": "Dinner", "subtitle": "6 PM — 3 hrs before bed", "doc": "Evening Routine"},
            {"label": "Stop eating", "subtitle": "7 PM", "doc": "Evening Routine"},
            {"label": "No liquids / no blue light", "subtitle": "8 PM — Kindle only", "doc": "Evening Routine"},
        ]},
        {"name": "Evening Routine", "position": 1, "protocols": [
            {"label": "Cyclic sighing", "subtitle": "5 min breathing", "doc": "Evening Routine"},
            {"label": "Face wash"},
            {"label": "Floss + brush", "subtitle": "Deep floss, 2-minute brush"},
            {"label": "Retinol + moisturize", "doc": "Evening Routine"},
            {"label": "Lock up + open window"},
            {"label": "Phone in other room"},
        ]},
        {"name": "Evening Supplements", "position": 2, "protocols": [
            {"label": "Magnesium Glycinate", "subtitle": "400mg", "doc": "Evening Supplements"},
            {"label": "L-Theanine", "subtitle": "200mg", "doc": "Evening Supplements"},
            {"label": "Ashwagandha KSM-66", "subtitle": "600mg — cycle 4on/1off", "doc": "Evening Supplements"},
            {"label": "Glycine", "subtitle": "3-5g", "doc": "Evening Supplements"},
        ]},
    ]},
    {"name": "Anytime", "position": 2, "groups": [
        {"name": "Daily Habits", "position": 0, "protocols": [
            {"label": "TM meditation — AM", "subtitle": "20 min", "doc": "Daily Habits"},
            {"label": "TM meditation — PM", "subtitle": "20 min", "doc": "Daily Habits"},
            {"label": "Dog walk", "doc": "Daily Habits"},
        ]},
    ]},
]


def seed_folders():
    for f in FOLDERS:
        resp = requests.post(f"{BASE}/documents/folders", json=f)
        if resp.status_code == 201:
            data = resp.json()
            folder_ids[f["name"]] = data["id"]
            print(f"  Folder: {data['name']}")
        else:
            print(f"  FAIL: {f['name']} — {resp.status_code}")


def seed_docs():
    for doc in DOCS:
        payload = {"title": doc["title"], "content": doc["content"]}
        if doc.get("folder") in folder_ids:
            payload["folder_id"] = folder_ids[doc["folder"]]
        resp = requests.post(f"{BASE}/documents/", json=payload)
        if resp.status_code == 201:
            data = resp.json()
            doc_ids[doc["title"]] = data["id"]
            print(f"  Doc: {data['title']}")
        else:
            print(f"  FAIL: {doc['title']} — {resp.status_code}")


def seed_sections():
    for sec in SECTIONS:
        resp = requests.post(f"{BASE}/protocols/sections", json={"name": sec["name"], "position": sec["position"]})
        if resp.status_code != 201:
            print(f"  FAIL section: {sec['name']} — {resp.status_code} {resp.text}")
            continue
        sec_data = resp.json()
        section_ids[sec["name"]] = sec_data["id"]
        print(f"  Section: {sec_data['name']}")

        for grp in sec["groups"]:
            for proto in grp.get("protocols", []):
                doc_title = proto.pop("doc", None)
                if doc_title and doc_title in doc_ids:
                    proto["document_id"] = doc_ids[doc_title]

            resp2 = requests.post(f"{BASE}/protocols/sections/{sec_data['id']}/groups", json=grp)
            if resp2.status_code == 201:
                print(f"    Group: {resp2.json()['name']}")
            else:
                print(f"    FAIL group: {grp['name']} — {resp2.status_code} {resp2.text}")


def main():
    print("=== Folders ===")
    seed_folders()
    print("\n=== Documents ===")
    seed_docs()
    print("\n=== Sections + Groups + Protocols ===")
    seed_sections()
    print("\nDone.")


if __name__ == "__main__":
    main()
