from __future__ import annotations

import uuid
from datetime import date, datetime, timezone

from api.models import db


class BodyWeight(db.Model):
    """Daily body weight measurement."""

    __tablename__ = "body_weights"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: str = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False)
    date: date = db.Column(db.Date, nullable=False)
    weight: float = db.Column(db.Float, nullable=False)  # lbs
    created_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # Relationships
    user = db.relationship("User", back_populates="body_weights")

    __table_args__ = (db.UniqueConstraint("user_id", "date", name="uq_user_weight_date"),)
