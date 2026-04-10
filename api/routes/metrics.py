from __future__ import annotations

from datetime import date

from flask import Blueprint, jsonify, request

from models import db
from models.metric import BodyWeight

metrics_bp = Blueprint("metrics", __name__)

TEMP_USER_ID = "chris"


@metrics_bp.route("/weight", methods=["GET"])
def list_weights():
    weights = (
        BodyWeight.query
        .filter_by(user_id=TEMP_USER_ID)
        .order_by(BodyWeight.date.desc())
        .limit(90)
        .all()
    )
    return jsonify([
        {"date": w.date.isoformat(), "weight": w.weight}
        for w in weights
    ])


@metrics_bp.route("/weight", methods=["POST"])
def log_weight():
    data = request.get_json()
    d = date.fromisoformat(data["date"])

    existing = BodyWeight.query.filter_by(user_id=TEMP_USER_ID, date=d).first()
    if existing:
        existing.weight = data["weight"]
    else:
        existing = BodyWeight(user_id=TEMP_USER_ID, date=d, weight=data["weight"])
        db.session.add(existing)

    db.session.commit()
    return jsonify({"date": existing.date.isoformat(), "weight": existing.weight}), 201
