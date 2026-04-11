"""Authentication routes — Sign in with Apple."""
from __future__ import annotations

from flask import Blueprint, jsonify, request

from models import db
from models.user import User
from services.auth import validate_apple_token, create_token

auth_bp = Blueprint("auth", __name__)


@auth_bp.route("/apple", methods=["POST"])
def apple_sign_in():
    """Exchange an Apple identity token for a session JWT."""
    data = request.get_json()
    identity_token = data.get("identity_token")
    if not identity_token:
        return jsonify({"error": "Missing identity_token"}), 400

    try:
        claims = validate_apple_token(identity_token)
    except Exception as e:
        return jsonify({"error": f"Invalid Apple token: {e}"}), 401

    apple_user_id = claims["sub"]
    email = claims.get("email")

    # Find existing user by Apple ID
    user = User.query.filter_by(apple_user_id=apple_user_id).first()

    if not user:
        # First sign-in: adopt the seed user if it exists, otherwise create new
        seed_user = User.query.filter_by(id="chris").first()
        if seed_user and not seed_user.apple_user_id:
            seed_user.apple_user_id = apple_user_id
            if email:
                seed_user.email = email
            first_name = data.get("first_name")
            last_name = data.get("last_name")
            if first_name:
                name = first_name
                if last_name:
                    name += f" {last_name}"
                seed_user.display_name = name
            user = seed_user
        else:
            first_name = data.get("first_name", "")
            last_name = data.get("last_name", "")
            display_name = f"{first_name} {last_name}".strip() or None
            user = User(
                apple_user_id=apple_user_id,
                email=email,
                display_name=display_name,
            )
            db.session.add(user)

    db.session.commit()

    token = create_token(user.id)
    return jsonify({
        "token": token,
        "user": {
            "id": user.id,
            "display_name": user.display_name,
            "email": user.email,
            "timezone": user.timezone,
        },
    })
