from __future__ import annotations

from datetime import date

from flask import Blueprint, jsonify, request

from api.models import db
from api.models.protocol import Protocol, ProtocolCompletion, ProtocolItem

protocols_bp = Blueprint("protocols", __name__)

TEMP_USER_ID = "chris"


def _serialize_item(item: ProtocolItem, completions: dict | None = None) -> dict:
    result = {
        "id": item.id,
        "label": item.label,
        "subtitle": item.subtitle,
        "position": item.position,
        "notes": item.notes,
        "document_id": item.document_id,
    }
    if completions is not None:
        status = completions.get(item.id)
        result["status"] = status if status else "pending"
    return result


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
            "section": p.section,
            "position": p.position,
            "items": [_serialize_item(item) for item in p.items],
        }
        for p in protocols
    ])


@protocols_bp.route("/", methods=["POST"])
def create_protocol():
    data = request.get_json()
    protocol = Protocol(
        user_id=TEMP_USER_ID,
        name=data["name"],
        section=data.get("section", "anytime"),
        position=data.get("position", 0),
    )
    db.session.add(protocol)

    for i, item_data in enumerate(data.get("items", [])):
        item = ProtocolItem(
            protocol=protocol,
            label=item_data["label"],
            subtitle=item_data.get("subtitle"),
            position=i,
            notes=item_data.get("notes"),
            document_id=item_data.get("document_id"),
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

    completions_raw = ProtocolCompletion.query.filter_by(
        user_id=TEMP_USER_ID, date=today
    ).all()
    completions = {c.item_id: c.status for c in completions_raw}

    sections = {}
    for p in protocols:
        section = p.section
        if section not in sections:
            sections[section] = []
        sections[section].append({
            "id": p.id,
            "name": p.name,
            "section": p.section,
            "position": p.position,
            "items": [_serialize_item(item, completions) for item in p.items],
        })

    return jsonify({
        "date": today.isoformat(),
        "morning": sections.get("morning", []),
        "evening": sections.get("evening", []),
        "anytime": sections.get("anytime", []),
    })


@protocols_bp.route("/completions", methods=["POST"])
def set_completion():
    data = request.get_json()
    item_id = data["item_id"]
    status = data.get("status", "completed")  # completed, skipped, or pending (to clear)
    target_date = date.fromisoformat(data.get("date", date.today().isoformat()))

    existing = ProtocolCompletion.query.filter_by(
        user_id=TEMP_USER_ID, item_id=item_id, date=target_date,
    ).first()

    if status == "pending":
        if existing:
            db.session.delete(existing)
            db.session.commit()
        return jsonify({"status": "pending", "item_id": item_id})

    if existing:
        existing.status = status
        existing.completed_at = db.func.now()
    else:
        existing = ProtocolCompletion(
            user_id=TEMP_USER_ID, item_id=item_id, date=target_date, status=status,
        )
        db.session.add(existing)

    db.session.commit()
    return jsonify({"status": status, "item_id": item_id}), 201


@protocols_bp.route("/history/<date_str>", methods=["GET"])
def day_summary(date_str: str):
    target_date = date.fromisoformat(date_str)

    completions = ProtocolCompletion.query.filter_by(
        user_id=TEMP_USER_ID, date=target_date,
    ).all()

    return jsonify({
        "date": target_date.isoformat(),
        "completions": [
            {
                "item_id": c.item_id,
                "item_label": c.item.label if c.item else None,
                "protocol_name": c.item.protocol.name if c.item and c.item.protocol else None,
                "status": c.status,
                "completed_at": c.completed_at.isoformat() if c.completed_at else None,
            }
            for c in completions
        ],
    })
