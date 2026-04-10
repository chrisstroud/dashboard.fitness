from __future__ import annotations

import uuid
from datetime import date, datetime, timezone

from models import db


class WorkoutSession(db.Model):
    """A single logged workout (an instance of doing a workout template)."""

    __tablename__ = "workout_sessions"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: str = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False)
    template_id: str = db.Column(
        db.String(36), db.ForeignKey("workout_templates.id"), nullable=True
    )
    date: date = db.Column(db.Date, nullable=False)
    duration_minutes: int = db.Column(db.Integer, nullable=True)
    notes: str = db.Column(db.Text, nullable=True)
    rating: int = db.Column(db.Integer, nullable=True)  # 1-5 session quality
    created_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: datetime = db.Column(
        db.DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relationships
    user = db.relationship("User", back_populates="workout_sessions")
    template = db.relationship("WorkoutTemplate")
    exercise_logs = db.relationship(
        "ExerciseLog", back_populates="session", cascade="all, delete-orphan"
    )


class ExerciseLog(db.Model):
    """A logged exercise within a workout session."""

    __tablename__ = "exercise_logs"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id: str = db.Column(
        db.String(36), db.ForeignKey("workout_sessions.id"), nullable=False
    )
    exercise_id: str = db.Column(db.String(36), db.ForeignKey("exercises.id"), nullable=False)
    position: int = db.Column(db.Integer, nullable=False, default=0)
    notes: str = db.Column(db.Text, nullable=True)

    # Relationships
    session = db.relationship("WorkoutSession", back_populates="exercise_logs")
    exercise = db.relationship("Exercise")
    sets = db.relationship("SetLog", back_populates="exercise_log", cascade="all, delete-orphan")


class SetLog(db.Model):
    """A single logged set (the atomic unit of training data)."""

    __tablename__ = "set_logs"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    exercise_log_id: str = db.Column(
        db.String(36), db.ForeignKey("exercise_logs.id"), nullable=False
    )
    set_number: int = db.Column(db.Integer, nullable=False)
    weight: float = db.Column(db.Float, nullable=True)  # lbs
    reps: int = db.Column(db.Integer, nullable=True)
    rpe: float = db.Column(db.Float, nullable=True)  # rate of perceived exertion 1-10
    is_warmup: bool = db.Column(db.Boolean, default=False)
    notes: str = db.Column(db.String(200), nullable=True)

    # Relationships
    exercise_log = db.relationship("ExerciseLog", back_populates="sets")
