from __future__ import annotations

from flask import Blueprint, jsonify, request

from api.models import db
from api.models.user import User

users_bp = Blueprint("users", __name__)

TEMP_USER_ID = "chris"


@users_bp.route("/me", methods=["GET"])
def get_profile():
    user = User.query.get(TEMP_USER_ID)
    if not user:
        # Auto-create for dev
        user = User(id=TEMP_USER_ID, display_name="Chris", timezone="America/Los_Angeles")
        db.session.add(user)
        db.session.commit()

    return jsonify({
        "id": user.id,
        "display_name": user.display_name,
        "email": user.email,
        "timezone": user.timezone,
        "created_at": user.created_at.isoformat() if user.created_at else None,
    })


@users_bp.route("/me", methods=["PUT"])
def update_profile():
    user = User.query.get(TEMP_USER_ID)
    if not user:
        user = User(id=TEMP_USER_ID)
        db.session.add(user)

    data = request.get_json()
    if "display_name" in data:
        user.display_name = data["display_name"]
    if "email" in data:
        user.email = data["email"]
    if "timezone" in data:
        user.timezone = data["timezone"]

    db.session.commit()
    return jsonify({
        "id": user.id,
        "display_name": user.display_name,
        "timezone": user.timezone,
    })
