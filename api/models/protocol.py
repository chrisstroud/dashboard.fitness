from __future__ import annotations

import uuid
from datetime import date, datetime, timezone

from api.models import db


class Protocol(db.Model):
    """A section of the daily dashboard (e.g. 'Morning', 'Evening', 'Anytime')."""

    __tablename__ = "protocols"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: str = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False)
    name: str = db.Column(db.String(100), nullable=False)
    section: str = db.Column(db.String(20), nullable=False, default="anytime")  # morning, evening, anytime
    position: int = db.Column(db.Integer, nullable=False, default=0)
    created_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    items = db.relationship(
        "ProtocolItem", back_populates="protocol", cascade="all, delete-orphan",
        order_by="ProtocolItem.position",
    )
    user = db.relationship("User", backref="protocols")


class ProtocolItem(db.Model):
    """A single task within a protocol, optionally linked to a document."""

    __tablename__ = "protocol_items"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    protocol_id: str = db.Column(db.String(36), db.ForeignKey("protocols.id"), nullable=False)
    label: str = db.Column(db.String(200), nullable=False)
    subtitle: str = db.Column(db.String(500), nullable=True)  # inline detail (e.g. supplement list)
    position: int = db.Column(db.Integer, nullable=False, default=0)
    notes: str = db.Column(db.Text, nullable=True)
    document_id: str = db.Column(db.String(36), db.ForeignKey("documents.id"), nullable=True)

    protocol = db.relationship("Protocol", back_populates="items")
    document = db.relationship("Document")


class ProtocolCompletion(db.Model):
    """Tracks task status for a specific date: completed or skipped."""

    __tablename__ = "protocol_completions"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: str = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False)
    item_id: str = db.Column(db.String(36), db.ForeignKey("protocol_items.id"), nullable=False)
    date: date = db.Column(db.Date, nullable=False)
    status: str = db.Column(db.String(20), nullable=False, default="completed")  # completed, skipped
    completed_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    item = db.relationship("ProtocolItem")

    __table_args__ = (
        db.UniqueConstraint("user_id", "item_id", "date", name="uq_completion_per_day"),
    )
