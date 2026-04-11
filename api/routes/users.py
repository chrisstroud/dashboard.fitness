from __future__ import annotations

from flask import Blueprint, g, jsonify, request

from models import db
from models.user import User
from services.auth import decode_token

users_bp = Blueprint("users", __name__)


@users_bp.before_request
def _require_authentication():
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return jsonify({"error": "Authentication required"}), 401
    try:
        payload = decode_token(auth_header[7:])
        g.user_id = payload["sub"]
    except Exception:
        return jsonify({"error": "Invalid or expired token"}), 401


@users_bp.route("/me", methods=["GET"])
def get_profile():
    user = db.session.get(User, g.user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    return jsonify({
        "id": user.id,
        "display_name": user.display_name,
        "email": user.email,
        "timezone": user.timezone,
        "created_at": user.created_at.isoformat() if user.created_at else None,
    })


@users_bp.route("/me", methods=["PUT"])
def update_profile():
    user = db.session.get(User, g.user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

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
