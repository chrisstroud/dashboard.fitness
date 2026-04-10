from __future__ import annotations

from datetime import date

from flask import Blueprint, jsonify, request

from api.models import db
from api.models.protocol import Protocol, ProtocolCompletion, ProtocolItem

protocols_bp = Blueprint("protocols", __name__)

TEMP_USER_ID = "chris"


@protocols_bp.route("/", methods=["GET"])
def list_protocols():
    protocols = (
        Protocol.query
        .filter_by(user_id=TEMP_USER_ID)
        .order_by(Protocol.position)
        .all()
    )
    return jsonify([
        {
            "id": p.id,
            "name": p.name,
            "position": p.position,
            "items": [
                {"id": item.id, "label": item.label, "position": item.position, "notes": item.notes}
                for item in p.items
            ],
        }
        for p in protocols
    ])


@protocols_bp.route("/", methods=["POST"])
def create_protocol():
    data = request.get_json()
    protocol = Protocol(
        user_id=TEMP_USER_ID,
        name=data["name"],
        position=data.get("position", 0),
    )
    db.session.add(protocol)

    for i, item_data in enumerate(data.get("items", [])):
        item = ProtocolItem(
            protocol=protocol,
            label=item_data["label"],
            position=i,
            notes=item_data.get("notes"),
        )
        db.session.add(item)

    db.session.commit()
    return jsonify({"id": protocol.id, "name": protocol.name}), 201


@protocols_bp.route("/today", methods=["GET"])
def today_protocols():
    today = date.today()
    protocols = (
        Protocol.query
        .filter_by(user_id=TEMP_USER_ID)
        .order_by(Protocol.position)
        .all()
    )

    completions = {
        c.item_id
        for c in ProtocolCompletion.query.filter_by(
            user_id=TEMP_USER_ID, date=today
        ).all()
    }

    return jsonify([
        {
            "id": p.id,
            "name": p.name,
            "position": p.position,
            "items": [
                {
                    "id": item.id,
                    "label": item.label,
                    "position": item.position,
                    "notes": item.notes,
                    "completed": item.id in completions,
                }
                for item in p.items
            ],
        }
        for p in protocols
    ])


@protocols_bp.route("/completions", methods=["POST"])
def toggle_completion():
    data = request.get_json()
    item_id = data["item_id"]
    target_date = date.fromisoformat(data.get("date", date.today().isoformat()))

    existing = ProtocolCompletion.query.filter_by(
        user_id=TEMP_USER_ID, item_id=item_id, date=target_date,
    ).first()

    if existing:
        db.session.delete(existing)
        db.session.commit()
        return jsonify({"completed": False, "item_id": item_id})
    else:
        completion = ProtocolCompletion(
            user_id=TEMP_USER_ID, item_id=item_id, date=target_date,
        )
        db.session.add(completion)
        db.session.commit()
        return jsonify({"completed": True, "item_id": item_id}), 201
