from __future__ import annotations

import uuid
from datetime import datetime, timezone

from models import db


class User(db.Model):
    __tablename__ = "users"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    apple_user_id: str = db.Column(db.String(255), unique=True, nullable=True)
    email: str = db.Column(db.String(255), unique=True, nullable=True)
    display_name: str = db.Column(db.String(100), nullable=True)
    timezone: str = db.Column(db.String(50), nullable=False, default="America/Los_Angeles")
    created_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: datetime = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relationships
    workout_sessions = db.relationship("WorkoutSession", back_populates="user")
    body_weights = db.relationship("BodyWeight", back_populates="user")
