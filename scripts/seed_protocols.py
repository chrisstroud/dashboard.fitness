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
        "name": "Morning Routine",
        "section": "morning",
        "position": 0,
        "items": [
            {"label": "Bathroom — splash water on face"},
            {"label": "Brush teeth + tongue scrape"},
            {"label": "Exercise + morning light exposure"},
            {"label": "Coffee", "subtitle": "Delay 60-90 min after waking"},
            {"label": "Shower"},
            {"label": "Skincare", "subtitle": "Vitamin C serum → sunscreen → moisturize"},
            {"label": "Breakfast", "subtitle": "Shake + oats + creatine"},
        ],
    },
    {
        "name": "Morning Supplements",
        "section": "morning",
        "position": 1,
        "items": [
            {"label": "Fish Oil (EPA/DHA)", "subtitle": "3-5g combined"},
            {"label": "Vitamin D3 + K2", "subtitle": "5,000 IU / 200mcg"},
            {"label": "Zinc Picolinate", "subtitle": "15-20mg"},
            {"label": "Boron", "subtitle": "10mg"},
            {"label": "Creatine Monohydrate", "subtitle": "10g in shake"},
            {"label": "Multivitamin", "subtitle": "1x"},
        ],
    },
    {
        "name": "Evening Routine",
        "section": "evening",
        "position": 2,
        "items": [
            {"label": "Dinner", "subtitle": "6PM — 3 hrs before bed"},
            {"label": "Stop eating", "subtitle": "7PM — 2 hrs before bed"},
            {"label": "Wind down", "subtitle": "No liquids, no blue light, Kindle only"},
            {"label": "Face wash + cyclic sighing", "subtitle": "5 min breathing"},
            {"label": "Floss + brush", "subtitle": "Deep floss, 2-minute brush"},
            {"label": "Retinol + moisturize"},
            {"label": "Lock up + open window"},
            {"label": "Phone in other room"},
        ],
    },
    {
        "name": "Evening Supplements",
        "section": "evening",
        "position": 3,
        "items": [
            {"label": "Magnesium Glycinate", "subtitle": "400mg"},
            {"label": "L-Theanine", "subtitle": "200mg"},
            {"label": "Ashwagandha KSM-66", "subtitle": "600mg — cycle 4on/1off"},
            {"label": "Glycine", "subtitle": "3-5g"},
        ],
    },
    {
        "name": "Daily Habits",
        "section": "anytime",
        "position": 4,
        "items": [
            {"label": "TM meditation — AM", "subtitle": "20 min"},
            {"label": "TM meditation — PM", "subtitle": "20 min"},
            {"label": "Dog walk"},
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
