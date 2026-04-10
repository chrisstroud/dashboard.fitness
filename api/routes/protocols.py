from __future__ import annotations

from datetime import date

from flask import Blueprint, jsonify, request

from api.models import db
from api.models.protocol import Protocol, ProtocolCompletion, ProtocolGroup

protocols_bp = Blueprint("protocols", __name__)

TEMP_USER_ID = "chris"


def _serialize_protocol(p: Protocol, completions: dict | None = None) -> dict:
    result = {
        "id": p.id,
        "label": p.label,
        "subtitle": p.subtitle,
        "position": p.position,
        "document_id": p.document_id,
    }
    if completions is not None:
        result["status"] = completions.get(p.id, "pending")
    return result


def _serialize_group(g: ProtocolGroup, completions: dict | None = None) -> dict:
    return {
        "id": g.id,
        "name": g.name,
        "section": g.section,
        "position": g.position,
        "protocols": [_serialize_protocol(p, completions) for p in g.protocols],
    }


@protocols_bp.route("/", methods=["GET"])
def list_groups():
    groups = (
        ProtocolGroup.query
        .filter_by(user_id=TEMP_USER_ID)
        .order_by(ProtocolGroup.position)
        .all()
    )
    return jsonify([_serialize_group(g) for g in groups])


@protocols_bp.route("/", methods=["POST"])
def create_group():
    data = request.get_json()
    group = ProtocolGroup(
        user_id=TEMP_USER_ID,
        name=data["name"],
        section=data.get("section", "anytime"),
        position=data.get("position", 0),
    )
    db.session.add(group)

    for i, proto_data in enumerate(data.get("protocols", [])):
        proto = Protocol(
            group=group,
            label=proto_data["label"],
            subtitle=proto_data.get("subtitle"),
            position=i,
            document_id=proto_data.get("document_id"),
        )
        db.session.add(proto)

    db.session.commit()
    return jsonify({"id": group.id, "name": group.name}), 201


@protocols_bp.route("/today", methods=["GET"])
def today_view():
    today = date.today()
    groups = (
        ProtocolGroup.query
        .filter_by(user_id=TEMP_USER_ID)
        .order_by(ProtocolGroup.position)
        .all()
    )

    completions_raw = ProtocolCompletion.query.filter_by(
        user_id=TEMP_USER_ID, date=today,
    ).all()
    completions = {c.protocol_id: c.status for c in completions_raw}

    sections = {}
    for g in groups:
        s = g.section
        if s not in sections:
            sections[s] = []
        sections[s].append(_serialize_group(g, completions))

    return jsonify({
        "date": today.isoformat(),
        "morning": sections.get("morning", []),
        "evening": sections.get("evening", []),
        "anytime": sections.get("anytime", []),
    })


@protocols_bp.route("/completions", methods=["POST"])
def set_completion():
    data = request.get_json()
    status = data.get("status", "completed")  # completed, skipped, or pending (to clear)
    target_date = date.fromisoformat(data.get("date", date.today().isoformat()))

    # Accept single protocol_id or list of protocol_ids (for bulk)
    protocol_ids = data.get("protocol_ids", [])
    if "protocol_id" in data:
        protocol_ids.append(data["protocol_id"])

    results = []
    for pid in protocol_ids:
        existing = ProtocolCompletion.query.filter_by(
            user_id=TEMP_USER_ID, protocol_id=pid, date=target_date,
        ).first()

        if status == "pending":
            if existing:
                db.session.delete(existing)
            results.append({"protocol_id": pid, "status": "pending"})
        else:
            if existing:
                existing.status = status
                existing.completed_at = db.func.now()
            else:
                existing = ProtocolCompletion(
                    user_id=TEMP_USER_ID, protocol_id=pid, date=target_date, status=status,
                )
                db.session.add(existing)
            results.append({"protocol_id": pid, "status": status})

    db.session.commit()
    return jsonify({"results": results}), 201


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
                "protocol_id": c.protocol_id,
                "protocol_label": c.protocol.label if c.protocol else None,
                "group_name": c.protocol.group.name if c.protocol and c.protocol.group else None,
                "status": c.status,
                "completed_at": c.completed_at.isoformat() if c.completed_at else None,
            }
            for c in completions
        ],
    })
