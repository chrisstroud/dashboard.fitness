from __future__ import annotations

from datetime import date

from flask import Blueprint, jsonify, request

from models import db
from models.session import ExerciseLog, SetLog, WorkoutSession

sessions_bp = Blueprint("sessions", __name__)

# TODO: Replace hardcoded user_id with auth-derived user once Sign in with Apple is wired up.
TEMP_USER_ID = "chris"


@sessions_bp.route("/", methods=["GET"])
def list_sessions():
    sessions = (
        WorkoutSession.query
        .filter_by(user_id=TEMP_USER_ID)
        .order_by(WorkoutSession.date.desc())
        .limit(50)
        .all()
    )
    return jsonify([
        {
            "id": s.id,
            "date": s.date.isoformat(),
            "template_id": s.template_id,
            "duration_minutes": s.duration_minutes,
            "rating": s.rating,
            "notes": s.notes,
        }
        for s in sessions
    ])


@sessions_bp.route("/", methods=["POST"])
def create_session():
    data = request.get_json()
    session = WorkoutSession(
        user_id=TEMP_USER_ID,
        template_id=data.get("template_id"),
        date=date.fromisoformat(data["date"]),
        duration_minutes=data.get("duration_minutes"),
        notes=data.get("notes"),
        rating=data.get("rating"),
    )
    db.session.add(session)

    for i, ex_data in enumerate(data.get("exercises", [])):
        ex_log = ExerciseLog(
            session=session,
            exercise_id=ex_data["exercise_id"],
            position=i,
            notes=ex_data.get("notes"),
        )
        db.session.add(ex_log)

        for j, set_data in enumerate(ex_data.get("sets", [])):
            set_log = SetLog(
                exercise_log=ex_log,
                set_number=j + 1,
                weight=set_data.get("weight"),
                reps=set_data.get("reps"),
                rpe=set_data.get("rpe"),
                is_warmup=set_data.get("is_warmup", False),
                notes=set_data.get("notes"),
            )
            db.session.add(set_log)

    db.session.commit()
    return jsonify({"id": session.id, "date": session.date.isoformat()}), 201


@sessions_bp.route("/<session_id>", methods=["GET"])
def get_session(session_id: str):
    s = db.get_or_404(WorkoutSession, session_id)
    return jsonify({
        "id": s.id,
        "date": s.date.isoformat(),
        "template_id": s.template_id,
        "duration_minutes": s.duration_minutes,
        "rating": s.rating,
        "notes": s.notes,
        "exercises": [
            {
                "id": el.id,
                "exercise_id": el.exercise_id,
                "exercise_name": el.exercise.name,
                "position": el.position,
                "notes": el.notes,
                "sets": [
                    {
                        "set_number": sl.set_number,
                        "weight": sl.weight,
                        "reps": sl.reps,
                        "rpe": sl.rpe,
                        "is_warmup": sl.is_warmup,
                    }
                    for sl in el.sets
                ],
            }
            for el in s.exercise_logs
        ],
    })
