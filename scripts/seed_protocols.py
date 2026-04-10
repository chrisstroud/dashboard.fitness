"""Seed Chris's protocols from Daily Routine markdown into the database.

Usage:
    cd ~/Developer/dashboard.fitness
    source api/.venv/bin/activate
    PYTHONPATH=. python scripts/seed_protocols.py
"""
from __future__ import annotations

import requests

BASE_URL = "http://localhost:5001/api/protocols"

PROTOCOLS = [
    {
        "name": "Morning",
        "position": 0,
        "items": [
            {"label": "Bathroom — splash water on face"},
            {"label": "Brush teeth + tongue scrape"},
            {"label": "Exercise + morning light exposure"},
            {"label": "Coffee (delay 60-90 min after waking)"},
            {"label": "Shower"},
            {"label": "Skincare — Vitamin C serum → sunscreen → moisturize"},
            {"label": "Breakfast — shake + oats"},
        ],
    },
    {
        "name": "Morning Supplements",
        "position": 1,
        "items": [
            {"label": "Fish Oil (EPA/DHA) — 3-5g"},
            {"label": "Vitamin D3 + K2 — 5,000 IU / 200mcg"},
            {"label": "Zinc Picolinate — 15-20mg"},
            {"label": "Boron — 10mg"},
            {"label": "Creatine Monohydrate — 10g (in shake)"},
            {"label": "Multivitamin — 1x"},
        ],
    },
    {
        "name": "Evening",
        "position": 2,
        "items": [
            {"label": "6PM — dinner"},
            {"label": "7PM — stop eating"},
            {"label": "8PM — no more liquids, no blue light"},
            {"label": "Foam face wash + cyclic sighing (5 min)"},
            {"label": "Deep floss + 2-minute brush"},
            {"label": "Retinol + moisturize"},
            {"label": "Lock front door, open window"},
            {"label": "Charge phone in other room"},
        ],
    },
    {
        "name": "Evening Supplements",
        "position": 3,
        "items": [
            {"label": "Magnesium Glycinate — 400mg"},
            {"label": "L-Theanine — 200mg"},
            {"label": "Ashwagandha KSM-66 — 600mg"},
            {"label": "Glycine — 3-5g"},
        ],
    },
    {
        "name": "Daily",
        "position": 4,
        "items": [
            {"label": "TM meditation — morning (20 min)"},
            {"label": "TM meditation — evening (20 min)"},
            {"label": "Dog walk"},
            {"label": "Cyclic sighing (5 min)"},
        ],
    },
]


def main() -> None:
    for protocol in PROTOCOLS:
        resp = requests.post(BASE_URL + "/", json=protocol)
        if resp.status_code == 201:
            data = resp.json()
            print(f"Created: {data['name']} ({data['id']})")
        else:
            print(f"Failed: {protocol['name']} — {resp.status_code} {resp.text}")


if __name__ == "__main__":
    main()
