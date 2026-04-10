"""Seed Chris's protocol groups, protocols, and reference docs.

Usage:
    cd ~/Developer/dashboard.fitness
    source api/.venv/bin/activate
    PYTHONPATH=. python scripts/seed_protocols.py
"""
from __future__ import annotations

import requests

BASE = "http://localhost:5001/api"

# First, create reference documents
DOCS = [
    {
        "title": "Morning Routine",
        "category": "routine",
        "content": "# Morning Routine\n\nWake at 5 AM. Bathroom first, then teeth before coffee to protect enamel from acid.\n\nCoffee delayed 60-90 min after waking to preserve natural cortisol curve.\n\nSkincare: Vitamin C serum → mineral sunscreen (SPF 30-50 if UV index 3+) → moisturize.\n\nBreakfast: Shake (water + 50g whey + 10g creatine + 2 tbsp chia seeds) + 1 cup oats + cinnamon + raw honey.",
    },
    {
        "title": "Morning Supplements",
        "category": "supplements",
        "content": "# Morning Supplements\n\n| Supplement | Dose | Why |\n|---|---|---|\n| Fish Oil (EPA/DHA) | 3-5g | Anti-inflammatory, cardiovascular, cognitive |\n| Vitamin D3 + K2 | 5,000 IU / 200mcg | Target 40-60 ng/mL blood levels. K2 directs calcium to bones |\n| Zinc Picolinate | 15-20mg | Testosterone support, immune function |\n| Boron | 10mg | Weakest evidence but cheap. May support free T |\n| Creatine | 10g | Muscle + bone + cognitive benefits at higher dose |\n| Multivitamin | 1x | Must have methylated B vitamins and chelated minerals |",
    },
    {
        "title": "Evening Routine",
        "category": "routine",
        "content": "# Evening Routine\n\nDinner by 6 PM (3 hrs before bed). Stop eating by 7 PM.\n\n8 PM: No more liquids, no blue light in bedroom (Kindle only).\n\nCyclic sighing: 5 min double inhale nose, long slow exhale mouth. Shown to reduce stress more effectively than meditation.\n\nSkincare: Retinol + moisturize.",
    },
    {
        "title": "Evening Supplements",
        "category": "supplements",
        "content": "# Evening Supplements\n\n| Supplement | Dose | Why |\n|---|---|---|\n| Magnesium Glycinate | 400mg | Sleep quality, muscle recovery. True chelated form only |\n| L-Theanine | 200mg | Synergistic with magnesium for sleep onset |\n| Ashwagandha KSM-66 | 600mg | Cortisol reduction, takes 4 weeks for full effect. Cycle 4on/1off |\n| Glycine | 3-5g | Lowers core body temp, collagen synthesis |",
    },
    {
        "title": "Daily Habits",
        "category": "routine",
        "content": "# Daily Habits\n\nTM meditation 2x/day (20 min each). Morning and evening.\n\nDog walk — daily non-negotiable. Light exposure + movement.\n\nThese are the foundation. Everything else is built on top.",
    },
]

# Create docs and collect their IDs
doc_ids = {}


def seed_docs():
    for doc in DOCS:
        resp = requests.post(f"{BASE}/documents/", json=doc)
        if resp.status_code == 201:
            data = resp.json()
            doc_ids[doc["title"]] = data["id"]
            print(f"Doc: {data['title']} ({data['id']})")
        else:
            print(f"Doc failed: {doc['title']} — {resp.status_code}")


# Protocol groups with nested protocols
def get_groups():
    return [
        {
            "name": "Bathroom",
            "section": "morning",
            "position": 0,
            "protocols": [
                {"label": "Splash water on face"},
                {"label": "Brush teeth + tongue scrape"},
            ],
        },
        {
            "name": "Morning Routine",
            "section": "morning",
            "position": 1,
            "protocols": [
                {"label": "Exercise + morning light"},
                {"label": "Coffee", "subtitle": "Delay 60-90 min after waking"},
                {"label": "Shower"},
                {"label": "Skincare", "subtitle": "Vitamin C serum → sunscreen → moisturize"},
                {"label": "Breakfast", "subtitle": "Shake + oats + creatine"},
            ],
        },
        {
            "name": "Morning Supplements",
            "section": "morning",
            "position": 2,
            "protocols": [
                {"label": "Fish Oil (EPA/DHA)", "subtitle": "3-5g combined", "doc": "Morning Supplements"},
                {"label": "Vitamin D3 + K2", "subtitle": "5,000 IU / 200mcg", "doc": "Morning Supplements"},
                {"label": "Zinc Picolinate", "subtitle": "15-20mg", "doc": "Morning Supplements"},
                {"label": "Boron", "subtitle": "10mg", "doc": "Morning Supplements"},
                {"label": "Creatine Monohydrate", "subtitle": "10g in shake", "doc": "Morning Supplements"},
                {"label": "Multivitamin", "subtitle": "1x", "doc": "Morning Supplements"},
            ],
        },
        {
            "name": "Wind Down",
            "section": "evening",
            "position": 3,
            "protocols": [
                {"label": "Dinner", "subtitle": "6 PM — 3 hrs before bed"},
                {"label": "Stop eating", "subtitle": "7 PM"},
                {"label": "No liquids / no blue light", "subtitle": "8 PM — Kindle only"},
            ],
        },
        {
            "name": "Evening Routine",
            "section": "evening",
            "position": 4,
            "protocols": [
                {"label": "Cyclic sighing", "subtitle": "5 min breathing", "doc": "Evening Routine"},
                {"label": "Face wash"},
                {"label": "Floss + brush", "subtitle": "Deep floss, 2-minute brush"},
                {"label": "Retinol + moisturize"},
                {"label": "Lock up + open window"},
                {"label": "Phone in other room"},
            ],
        },
        {
            "name": "Evening Supplements",
            "section": "evening",
            "position": 5,
            "protocols": [
                {"label": "Magnesium Glycinate", "subtitle": "400mg", "doc": "Evening Supplements"},
                {"label": "L-Theanine", "subtitle": "200mg", "doc": "Evening Supplements"},
                {"label": "Ashwagandha KSM-66", "subtitle": "600mg — cycle 4on/1off", "doc": "Evening Supplements"},
                {"label": "Glycine", "subtitle": "3-5g", "doc": "Evening Supplements"},
            ],
        },
        {
            "name": "Daily Habits",
            "section": "anytime",
            "position": 6,
            "protocols": [
                {"label": "TM meditation — AM", "subtitle": "20 min", "doc": "Daily Habits"},
                {"label": "TM meditation — PM", "subtitle": "20 min", "doc": "Daily Habits"},
                {"label": "Dog walk", "doc": "Daily Habits"},
            ],
        },
    ]


def seed_groups():
    for group_data in get_groups():
        # Resolve doc links
        for proto in group_data.get("protocols", []):
            doc_title = proto.pop("doc", None)
            if doc_title and doc_title in doc_ids:
                proto["document_id"] = doc_ids[doc_title]

        resp = requests.post(f"{BASE}/protocols/", json=group_data)
        if resp.status_code == 201:
            data = resp.json()
            print(f"Group: {data['name']} ({data['id']})")
        else:
            print(f"Group failed: {group_data['name']} — {resp.status_code} {resp.text}")


def main() -> None:
    print("=== Seeding Documents ===")
    seed_docs()
    print("\n=== Seeding Protocol Groups ===")
    seed_groups()
    print("\nDone.")


if __name__ == "__main__":
    main()
