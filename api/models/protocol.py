from __future__ import annotations

import uuid
from datetime import date, datetime, timezone

from api.models import db


class ProtocolGroup(db.Model):
    """A named group of protocols within a day section (e.g. 'Bathroom', 'Supplements')."""

    __tablename__ = "protocol_groups"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: str = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False)
    name: str = db.Column(db.String(100), nullable=False)
    section: str = db.Column(db.String(20), nullable=False, default="anytime")  # morning, evening, anytime
    position: int = db.Column(db.Integer, nullable=False, default=0)
    created_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    protocols = db.relationship(
        "Protocol", back_populates="group", cascade="all, delete-orphan",
        order_by="Protocol.position",
    )
    user = db.relationship("User", backref="protocol_groups")


class Protocol(db.Model):
    """The atomic unit: a single habit/task (e.g. 'Take Boron 10mg')."""

    __tablename__ = "protocols"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    group_id: str = db.Column(db.String(36), db.ForeignKey("protocol_groups.id"), nullable=False)
    label: str = db.Column(db.String(200), nullable=False)
    subtitle: str = db.Column(db.String(500), nullable=True)
    position: int = db.Column(db.Integer, nullable=False, default=0)
    document_id: str = db.Column(db.String(36), db.ForeignKey("documents.id"), nullable=True)
    created_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    group = db.relationship("ProtocolGroup", back_populates="protocols")
    document = db.relationship("Document")


class ProtocolCompletion(db.Model):
    """Tracks completion/skip of a protocol on a specific date."""

    __tablename__ = "protocol_completions"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: str = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False)
    protocol_id: str = db.Column(db.String(36), db.ForeignKey("protocols.id"), nullable=False)
    date: date = db.Column(db.Date, nullable=False)
    status: str = db.Column(db.String(20), nullable=False, default="completed")  # completed, skipped
    completed_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    protocol = db.relationship("Protocol")

    __table_args__ = (
        db.UniqueConstraint("user_id", "protocol_id", "date", name="uq_completion_per_day"),
    )
