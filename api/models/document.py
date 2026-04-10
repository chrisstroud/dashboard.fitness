from __future__ import annotations

import uuid
from datetime import date, datetime, timezone

from api.models import db


class Folder(db.Model):
    """A folder for organizing documents. Can be nested."""

    __tablename__ = "folders"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: str = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False)
    name: str = db.Column(db.String(100), nullable=False)
    parent_id: str = db.Column(db.String(36), db.ForeignKey("folders.id"), nullable=True)
    position: int = db.Column(db.Integer, nullable=False, default=0)
    created_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    parent = db.relationship("Folder", remote_side=[id], backref="children")
    documents = db.relationship("Document", back_populates="folder")
    user = db.relationship("User", backref="folders")


class Document(db.Model):
    """A user-owned markdown document, optionally inside a folder."""

    __tablename__ = "documents"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: str = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False)
    folder_id: str = db.Column(db.String(36), db.ForeignKey("folders.id"), nullable=True)
    title: str = db.Column(db.String(200), nullable=False)
    content: str = db.Column(db.Text, nullable=False, default="")
    weekly_target: int = db.Column(db.Integer, nullable=True)  # e.g. 1 = once/week, 4 = 4x/week
    created_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: datetime = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    folder = db.relationship("Folder", back_populates="documents")
    user = db.relationship("User", backref="documents")
    completions = db.relationship("WorkoutCompletion", back_populates="document", cascade="all, delete-orphan")


class WorkoutCompletion(db.Model):
    """Tracks when a workout doc was completed on a given date."""

    __tablename__ = "workout_completions"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: str = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False)
    document_id: str = db.Column(db.String(36), db.ForeignKey("documents.id"), nullable=False)
    date: date = db.Column(db.Date, nullable=False)
    completed_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    document = db.relationship("Document", back_populates="completions")

    __table_args__ = (
        db.UniqueConstraint("user_id", "document_id", "date", name="uq_workout_completion_per_day"),
    )
