from __future__ import annotations

import uuid
from datetime import datetime, timezone

from models import db


class Exercise(db.Model):
    """Canonical exercise catalog (e.g. "Bench Press", "Back Squat")."""

    __tablename__ = "exercises"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name: str = db.Column(db.String(100), nullable=False)
    category: str = db.Column(db.String(50), nullable=True)  # strength, cardio, mobility, etc.
    equipment: str = db.Column(db.String(50), nullable=True)  # barbell, dumbbell, bodyweight, etc.
    created_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class WorkoutTemplate(db.Model):
    """A reusable workout plan (e.g. "Bench Day", "Squat Day")."""

    __tablename__ = "workout_templates"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name: str = db.Column(db.String(100), nullable=False)
    description: str = db.Column(db.Text, nullable=True)
    duration_minutes: int = db.Column(db.Integer, nullable=True)
    created_at: datetime = db.Column(
        db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # Relationships
    exercises = db.relationship(
        "WorkoutTemplateExercise", back_populates="template", order_by="WorkoutTemplateExercise.position"
    )


class WorkoutTemplateExercise(db.Model):
    """An exercise slot within a workout template, with prescribed sets/reps."""

    __tablename__ = "workout_template_exercises"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    template_id: str = db.Column(db.String(36), db.ForeignKey("workout_templates.id"), nullable=False)
    exercise_id: str = db.Column(db.String(36), db.ForeignKey("exercises.id"), nullable=False)
    position: int = db.Column(db.Integer, nullable=False, default=0)
    section: str = db.Column(db.String(50), nullable=True)  # "warm_up", "strength", "arms", "core"
    target_sets: int = db.Column(db.Integer, nullable=True)
    target_reps: str = db.Column(db.String(50), nullable=True)  # "3x5", "25 reps", "3x12"
    notes: str = db.Column(db.Text, nullable=True)

    # Relationships
    template = db.relationship("WorkoutTemplate", back_populates="exercises")
    exercise = db.relationship("Exercise")


class ExerciseSet(db.Model):
    """Prescribed set detail within a template exercise (optional — for structured programs)."""

    __tablename__ = "exercise_sets"

    id: str = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    template_exercise_id: str = db.Column(
        db.String(36), db.ForeignKey("workout_template_exercises.id"), nullable=False
    )
    set_number: int = db.Column(db.Integer, nullable=False)
    target_reps: int = db.Column(db.Integer, nullable=True)
    target_weight: float = db.Column(db.Float, nullable=True)
    target_rpe: float = db.Column(db.Float, nullable=True)
