from __future__ import annotations

import uuid
from datetime import date, datetime, time, timezone

from api.models import db


class ProtocolSection(db.Model):
    """A top-level section (e.g. 'Morning', 'Evening', 'Anytime'). User can rename/reorder."""

    __tablename__ = "protocol_sections"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: str = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False)
    name: str = db.Column(db.String(100), nullable=False)
    position: int = db.Column(db.Integer, nullable=False, default=0)
    created_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    groups = db.relationship(
        "ProtocolGroup", back_populates="section", cascade="all, delete-orphan",
        order_by="ProtocolGroup.position",
    )
    user = db.relationship("User", backref="protocol_sections")


class ProtocolGroup(db.Model):
    """A named group of protocols within a section (e.g. 'Bathroom', 'Supplements')."""

    __tablename__ = "protocol_groups"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    section_id: str = db.Column(db.String(36), db.ForeignKey("protocol_sections.id"), nullable=False)
    name: str = db.Column(db.String(100), nullable=False)
    position: int = db.Column(db.Integer, nullable=False, default=0)
    created_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    section = db.relationship("ProtocolSection", back_populates="groups")
    protocols = db.relationship(
        "Protocol", back_populates="group", cascade="all, delete-orphan",
        order_by="Protocol.position",
    )


class Protocol(db.Model):
    """Atomic habit/task (e.g. 'Take Boron 10mg')."""

    __tablename__ = "protocols"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    group_id: str = db.Column(db.String(36), db.ForeignKey("protocol_groups.id"), nullable=False)
    label: str = db.Column(db.String(200), nullable=False)
    subtitle: str = db.Column(db.String(500), nullable=True)
    position: int = db.Column(db.Integer, nullable=False, default=0)
    scheduled_time: time = db.Column(db.Time, nullable=True)
    document_id: str = db.Column(db.String(36), db.ForeignKey("documents.id"), nullable=True)
    created_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    group = db.relationship("ProtocolGroup", back_populates="protocols")
    document = db.relationship("Document")


# ── Daily Instance ───────────────────────────────────────────────────


class DailyInstance(db.Model):
    """A day's snapshot created from the master template."""

    __tablename__ = "daily_instances"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: str = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False)
    date: date = db.Column(db.Date, nullable=False)
    created_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    tasks = db.relationship(
        "DailyTask", back_populates="instance", cascade="all, delete-orphan",
        order_by="DailyTask.position",
    )
    user = db.relationship("User", backref="daily_instances")

    __table_args__ = (
        db.UniqueConstraint("user_id", "date", name="uq_daily_instance_per_day"),
    )


class DailyTask(db.Model):
    """A task within a daily instance — frozen snapshot."""

    __tablename__ = "daily_tasks"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    instance_id: str = db.Column(db.String(36), db.ForeignKey("daily_instances.id"), nullable=False)
    source_protocol_id: str = db.Column(db.String(36), nullable=True)
    section_name: str = db.Column(db.String(100), nullable=False)
    section_position: int = db.Column(db.Integer, nullable=False, default=0)
    group_name: str = db.Column(db.String(100), nullable=False)
    group_position: int = db.Column(db.Integer, nullable=False, default=0)
    label: str = db.Column(db.String(200), nullable=False)
    subtitle: str = db.Column(db.String(500), nullable=True)
    position: int = db.Column(db.Integer, nullable=False, default=0)
    scheduled_time: time = db.Column(db.Time, nullable=True)
    document_id: str = db.Column(db.String(36), nullable=True)
    status: str = db.Column(db.String(20), nullable=False, default="pending")
    completed_at: datetime = db.Column(db.DateTime(timezone=True), nullable=True)

    instance = db.relationship("DailyInstance", back_populates="tasks")
