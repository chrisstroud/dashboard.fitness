"""Seed folders, docs, and protocol groups.

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


# ── Folders ──────────────────────────────────────────────────────────

FOLDERS = [
    {"name": "Routines", "position": 0},
    {"name": "Supplements", "position": 1},
    {"name": "Research", "position": 2},
]


def seed_folders():
    for f in FOLDERS:
        resp = requests.post(f"{BASE}/documents/folders", json=f)
        if resp.status_code == 201:
            data = resp.json()
            folder_ids[f["name"]] = data["id"]
            print(f"  Folder: {data['name']} ({data['id']})")
        else:
            print(f"  Folder failed: {f['name']} — {resp.status_code}")


# ── Documents ────────────────────────────────────────────────────────

DOCS = [
    {
        "title": "Morning Routine",
        "folder": "Routines",
        "content": "# Morning Routine\n\nWake at 5 AM. Bathroom first, then teeth before coffee to protect enamel from acid.\n\nCoffee delayed 60-90 min after waking to preserve natural cortisol curve.\n\n## Skincare\n\nVitamin C serum → mineral sunscreen (SPF 30-50 if UV index 3+) → moisturize.\n\n## Breakfast\n\n- Shake: water + 50g whey + 10g creatine + 2 tbsp chia seeds\n- 1 cup oats + cinnamon + raw honey",
    },
    {
        "title": "Evening Routine",
        "folder": "Routines",
        "content": "# Evening Routine\n\n## Timeline\n\n- **6 PM** — Dinner (3 hrs before bed)\n- **7 PM** — Stop eating\n- **8 PM** — No more liquids, no blue light (Kindle only)\n\n## Wind Down\n\nCyclic sighing: 5 min double inhale nose, long slow exhale mouth. Shown to reduce stress more effectively than meditation.\n\n## Skincare\n\nRetinol + moisturize.",
    },
    {
        "title": "Daily Habits",
        "folder": "Routines",
        "content": "# Daily Habits\n\n## TM Meditation\n\n2x/day, 20 min each. Morning and evening. Non-negotiable foundation.\n\n## Dog Walk\n\nDaily. Light exposure + movement + mental reset.",
    },
    {
        "title": "Morning Supplements",
        "folder": "Supplements",
        "content": "# Morning Supplements\n\n| Supplement | Dose | Why |\n|---|---|---|\n| Fish Oil (EPA/DHA) | 3-5g | Anti-inflammatory, cardiovascular, cognitive |\n| Vitamin D3 + K2 | 5,000 IU / 200mcg | Target 40-60 ng/mL. K2 directs calcium to bones |\n| Zinc Picolinate | 15-20mg | Testosterone support, immune function |\n| Boron | 10mg | Weakest evidence but cheap. May support free T |\n| Creatine | 10g | Muscle + bone + cognitive at higher dose |\n| Multivitamin | 1x | Methylated B vitamins, chelated minerals |\n\n## Products\n\n- **Fish Oil:** Nordic Naturals Ultimate Omega (IFOS certified)\n- **D3+K2:** Sports Research\n- **Zinc:** Thorne Zinc Picolinate 15mg (NSF Certified)\n- **Creatine:** Nutricost or Thorne (NSF Certified)",
    },
    {
        "title": "Evening Supplements",
        "folder": "Supplements",
        "content": "# Evening Supplements\n\n| Supplement | Dose | Why |\n|---|---|---|\n| Magnesium Glycinate | 400mg | Sleep quality, muscle recovery |\n| L-Theanine | 200mg | Synergistic with mag for sleep |\n| Ashwagandha KSM-66 | 600mg | Cortisol reduction. Cycle 4on/1off |\n| Glycine | 3-5g | Lowers core body temp, collagen synthesis |\n\n## Notes\n\n- Many \"glycinate\" products sneak in magnesium oxide — Double Wood and Thorne are legit\n- Ashwagandha takes ~4 weeks for full efficacy\n- L-Theanine noticed improved sleep on first night",
    },
]


def seed_docs():
    for doc in DOCS:
        payload = {"title": doc["title"], "content": doc["content"]}
        folder_name = doc.get("folder")
        if folder_name and folder_name in folder_ids:
            payload["folder_id"] = folder_ids[folder_name]
        resp = requests.post(f"{BASE}/documents/", json=payload)
        if resp.status_code == 201:
            data = resp.json()
            doc_ids[doc["title"]] = data["id"]
            print(f"  Doc: {data['title']} ({data['id']})")
        else:
            print(f"  Doc failed: {doc['title']} — {resp.status_code}")


# ── Protocol Groups ──────────────────────────────────────────────────

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
                {"label": "Exercise + morning light", "doc": "Morning Routine"},
                {"label": "Coffee", "subtitle": "Delay 60-90 min after waking", "doc": "Morning Routine"},
                {"label": "Shower"},
                {"label": "Skincare", "subtitle": "Vitamin C → sunscreen → moisturize", "doc": "Morning Routine"},
                {"label": "Breakfast", "subtitle": "Shake + oats + creatine", "doc": "Morning Routine"},
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
                {"label": "Dinner", "subtitle": "6 PM — 3 hrs before bed", "doc": "Evening Routine"},
                {"label": "Stop eating", "subtitle": "7 PM", "doc": "Evening Routine"},
                {"label": "No liquids / no blue light", "subtitle": "8 PM — Kindle only", "doc": "Evening Routine"},
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
                {"label": "Retinol + moisturize", "doc": "Evening Routine"},
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
        for proto in group_data.get("protocols", []):
            doc_title = proto.pop("doc", None)
            if doc_title and doc_title in doc_ids:
                proto["document_id"] = doc_ids[doc_title]

        resp = requests.post(f"{BASE}/protocols/", json=group_data)
        if resp.status_code == 201:
            data = resp.json()
            print(f"  Group: {data['name']} ({data['id']})")
        else:
            print(f"  Group failed: {group_data['name']} — {resp.status_code} {resp.text}")


def main() -> None:
    print("=== Folders ===")
    seed_folders()
    print("\n=== Documents ===")
    seed_docs()
    print("\n=== Protocol Groups ===")
    seed_groups()
    print("\nDone.")


if __name__ == "__main__":
    main()
