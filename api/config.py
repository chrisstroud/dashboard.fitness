from __future__ import annotations

import os


class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev-secret-key")
    SQLALCHEMY_DATABASE_URI = os.environ.get(
        "DATABASE_URL", "sqlite:///dashboard_fitness.db"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Sign in with Apple
    APPLE_TEAM_ID = os.environ.get("APPLE_TEAM_ID", "")
    APPLE_KEY_ID = os.environ.get("APPLE_KEY_ID", "")
    APPLE_PRIVATE_KEY_PATH = os.environ.get("APPLE_PRIVATE_KEY_PATH", "")
