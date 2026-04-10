from __future__ import annotations

from flask import Blueprint, jsonify, request

from api.models import db
from api.models.workout import Exercise, WorkoutTemplate, WorkoutTemplateExercise

workouts_bp = Blueprint("workouts", __name__)


@workouts_bp.route("/templates", methods=["GET"])
def list_templates():
    templates = WorkoutTemplate.query.all()
    return jsonify([
        {
            "id": t.id,
            "name": t.name,
            "description": t.description,
            "duration_minutes": t.duration_minutes,
        }
        for t in templates
    ])


@workouts_bp.route("/templates/<template_id>", methods=["GET"])
def get_template(template_id: str):
    t = db.get_or_404(WorkoutTemplate, template_id)
    return jsonify({
        "id": t.id,
        "name": t.name,
        "description": t.description,
        "duration_minutes": t.duration_minutes,
        "exercises": [
            {
                "id": te.id,
                "exercise": {"id": te.exercise.id, "name": te.exercise.name, "category": te.exercise.category},
                "position": te.position,
                "section": te.section,
                "target_sets": te.target_sets,
                "target_reps": te.target_reps,
                "notes": te.notes,
            }
            for te in t.exercises
        ],
    })


@workouts_bp.route("/exercises", methods=["GET"])
def list_exercises():
    exercises = Exercise.query.order_by(Exercise.name).all()
    return jsonify([
        {"id": e.id, "name": e.name, "category": e.category, "equipment": e.equipment}
        for e in exercises
    ])


@workouts_bp.route("/exercises", methods=["POST"])
def create_exercise():
    data = request.get_json()
    exercise = Exercise(
        name=data["name"],
        category=data.get("category"),
        equipment=data.get("equipment"),
    )
    db.session.add(exercise)
    db.session.commit()
    return jsonify({"id": exercise.id, "name": exercise.name}), 201
