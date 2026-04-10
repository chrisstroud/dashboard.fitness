from __future__ import annotations

from datetime import date, time

from flask import Blueprint, jsonify, request

from api.models import db
from api.models.protocol import DailyInstance, DailyTask, Protocol, ProtocolGroup
from api.services.daily import get_or_create_daily_instance

protocols_bp = Blueprint("protocols", __name__)

TEMP_USER_ID = "chris"


# ── Master Template CRUD ─────────────────────────────────────────────

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
        scheduled = None
        if "scheduled_time" in proto_data and proto_data["scheduled_time"]:
            parts = proto_data["scheduled_time"].split(":")
            scheduled = time(int(parts[0]), int(parts[1]))

        proto = Protocol(
            group=group,
            label=proto_data["label"],
            subtitle=proto_data.get("subtitle"),
            position=i,
            scheduled_time=scheduled,
            document_id=proto_data.get("document_id"),
        )
        db.session.add(proto)

    db.session.commit()
    return jsonify({"id": group.id, "name": group.name}), 201


def _serialize_group(g: ProtocolGroup) -> dict:
    return {
        "id": g.id,
        "name": g.name,
        "section": g.section,
        "position": g.position,
        "protocols": [
            {
                "id": p.id,
                "label": p.label,
                "subtitle": p.subtitle,
                "position": p.position,
                "scheduled_time": p.scheduled_time.strftime("%H:%M") if p.scheduled_time else None,
                "document_id": p.document_id,
            }
            for p in g.protocols
        ],
    }


# ── Daily Instance (Today view) ──────────────────────────────────────

@protocols_bp.route("/today", methods=["GET"])
def today_view():
    today = date.today()
    instance = get_or_create_daily_instance(TEMP_USER_ID, today)
    return jsonify(_serialize_instance(instance))


@protocols_bp.route("/daily/<date_str>", methods=["GET"])
def daily_view(date_str: str):
    target_date = date.fromisoformat(date_str)
    instance = DailyInstance.query.filter_by(user_id=TEMP_USER_ID, date=target_date).first()
    if not instance:
        return jsonify({"error": "No daily instance for this date"}), 404
    return jsonify(_serialize_instance(instance))


@protocols_bp.route("/daily/task/<task_id>", methods=["PUT"])
def update_task(task_id: str):
    task = db.get_or_404(DailyTask, task_id)
    data = request.get_json()
    if "status" in data:
        task.status = data["status"]
        if data["status"] in ("completed", "skipped"):
            from datetime import datetime, timezone as tz
            task.completed_at = datetime.now(tz.utc)
        elif data["status"] == "pending":
            task.completed_at = None
    db.session.commit()
    return jsonify({"id": task.id, "status": task.status})


@protocols_bp.route("/daily/bulk", methods=["PUT"])
def bulk_update_tasks():
    data = request.get_json()
    task_ids = data.get("task_ids", [])
    status = data.get("status", "completed")

    from datetime import datetime, timezone as tz
    now = datetime.now(tz.utc) if status != "pending" else None

    for tid in task_ids:
        task = DailyTask.query.get(tid)
        if task:
            task.status = status
            task.completed_at = now
    db.session.commit()
    return jsonify({"updated": len(task_ids), "status": status})


def _serialize_instance(instance: DailyInstance) -> dict:
    tasks = sorted(instance.tasks, key=lambda t: (t.group_position, t.position))

    # Group tasks by group_name + section
    groups: dict[str, dict] = {}
    for task in tasks:
        key = f"{task.section}:{task.group_name}"
        if key not in groups:
            groups[key] = {
                "group_name": task.group_name,
                "section": task.section,
                "group_position": task.group_position,
                "tasks": [],
            }
        groups[key]["tasks"].append({
            "id": task.id,
            "source_protocol_id": task.source_protocol_id,
            "label": task.label,
            "subtitle": task.subtitle,
            "position": task.position,
            "scheduled_time": task.scheduled_time.strftime("%H:%M") if task.scheduled_time else None,
            "document_id": task.document_id,
            "status": task.status,
            "completed_at": task.completed_at.isoformat() if task.completed_at else None,
        })

    grouped_list = sorted(groups.values(), key=lambda g: g["group_position"])

    sections: dict[str, list] = {}
    for g in grouped_list:
        s = g["section"]
        if s not in sections:
            sections[s] = []
        sections[s].append(g)

    return {
        "id": instance.id,
        "date": instance.date.isoformat(),
        "morning": sections.get("morning", []),
        "evening": sections.get("evening", []),
        "anytime": sections.get("anytime", []),
        "total_tasks": len(tasks),
        "completed_tasks": sum(1 for t in tasks if t.status == "completed"),
        "skipped_tasks": sum(1 for t in tasks if t.status == "skipped"),
    }


# ── History (for heat map) ───────────────────────────────────────────

@protocols_bp.route("/history", methods=["GET"])
def history():
    """Return completion rates per day for the heat map."""
    instances = (
        DailyInstance.query
        .filter_by(user_id=TEMP_USER_ID)
        .order_by(DailyInstance.date.desc())
        .limit(90)
        .all()
    )
    return jsonify([
        {
            "date": inst.date.isoformat(),
            "total": len(inst.tasks),
            "completed": sum(1 for t in inst.tasks if t.status == "completed"),
            "skipped": sum(1 for t in inst.tasks if t.status == "skipped"),
        }
        for inst in instances
    ])
