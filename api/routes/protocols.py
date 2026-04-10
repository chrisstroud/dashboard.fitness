from __future__ import annotations

from datetime import date, time

from flask import Blueprint, jsonify, request

from api.models import db
from api.models.protocol import (
    DailyInstance, DailyTask, Protocol, ProtocolGroup, ProtocolSection,
)
from api.services.daily import get_or_create_daily_instance, refresh_today

protocols_bp = Blueprint("protocols", __name__)

TEMP_USER_ID = "chris"


def _commit_and_refresh():
    """Commit DB changes and refresh today's daily instance to match master."""
    db.session.commit()
    refresh_today(TEMP_USER_ID)


# ── Sections CRUD ────────────────────────────────────────────────────

@protocols_bp.route("/sections", methods=["GET"])
def list_sections():
    sections = (
        ProtocolSection.query
        .filter_by(user_id=TEMP_USER_ID)
        .order_by(ProtocolSection.position)
        .all()
    )
    return jsonify([_serialize_section(s) for s in sections])


@protocols_bp.route("/sections", methods=["POST"])
def create_section():
    data = request.get_json()
    count = ProtocolSection.query.filter_by(user_id=TEMP_USER_ID).count()
    section = ProtocolSection(
        user_id=TEMP_USER_ID,
        name=data["name"],
        position=data.get("position", count),
    )
    db.session.add(section)
    _commit_and_refresh()
    return jsonify({"id": section.id, "name": section.name}), 201


@protocols_bp.route("/sections/<section_id>", methods=["PUT"])
def update_section(section_id: str):
    section = db.get_or_404(ProtocolSection, section_id)
    data = request.get_json()
    if "name" in data:
        section.name = data["name"]
    if "position" in data:
        section.position = data["position"]
    _commit_and_refresh()
    return jsonify({"id": section.id, "name": section.name})


@protocols_bp.route("/sections/<section_id>", methods=["DELETE"])
def delete_section(section_id: str):
    section = db.get_or_404(ProtocolSection, section_id)
    db.session.delete(section)
    _commit_and_refresh()
    return jsonify({"deleted": True})


@protocols_bp.route("/sections/reorder", methods=["PUT"])
def reorder_sections():
    data = request.get_json()
    for item in data.get("order", []):
        section = ProtocolSection.query.get(item["id"])
        if section:
            section.position = item["position"]
    _commit_and_refresh()
    return jsonify({"reordered": True})


# ── Groups CRUD ──────────────────────────────────────────────────────

@protocols_bp.route("/sections/<section_id>/groups", methods=["POST"])
def create_group(section_id: str):
    db.get_or_404(ProtocolSection, section_id)
    data = request.get_json()
    group = ProtocolGroup(
        section_id=section_id,
        name=data["name"],
        position=data.get("position", 0),
    )
    db.session.add(group)

    for i, proto_data in enumerate(data.get("protocols", [])):
        scheduled = _parse_time(proto_data.get("scheduled_time"))
        proto = Protocol(
            group=group, label=proto_data["label"],
            subtitle=proto_data.get("subtitle"), position=i,
            scheduled_time=scheduled, document_id=proto_data.get("document_id"),
        )
        db.session.add(proto)

    _commit_and_refresh()
    return jsonify({"id": group.id, "name": group.name}), 201


@protocols_bp.route("/groups/<group_id>", methods=["PUT"])
def update_group(group_id: str):
    group = db.get_or_404(ProtocolGroup, group_id)
    data = request.get_json()
    if "name" in data:
        group.name = data["name"]
    if "position" in data:
        group.position = data["position"]
    if "section_id" in data:
        group.section_id = data["section_id"]
    _commit_and_refresh()
    return jsonify({"id": group.id, "name": group.name})


@protocols_bp.route("/groups/<group_id>", methods=["DELETE"])
def delete_group(group_id: str):
    group = db.get_or_404(ProtocolGroup, group_id)
    db.session.delete(group)
    _commit_and_refresh()
    return jsonify({"deleted": True})


@protocols_bp.route("/groups/reorder", methods=["PUT"])
def reorder_groups():
    data = request.get_json()
    for item in data.get("order", []):
        group = ProtocolGroup.query.get(item["id"])
        if group:
            group.position = item["position"]
            if "section_id" in item:
                group.section_id = item["section_id"]
    _commit_and_refresh()
    return jsonify({"reordered": True})


# ── Protocols CRUD ───────────────────────────────────────────────────

@protocols_bp.route("/groups/<group_id>/protocols", methods=["POST"])
def add_protocol(group_id: str):
    db.get_or_404(ProtocolGroup, group_id)
    data = request.get_json()
    proto = Protocol(
        group_id=group_id, label=data["label"],
        subtitle=data.get("subtitle"),
        position=data.get("position", 0),
        scheduled_time=_parse_time(data.get("scheduled_time")),
        document_id=data.get("document_id"),
    )
    db.session.add(proto)
    _commit_and_refresh()
    return jsonify({"id": proto.id, "label": proto.label}), 201


@protocols_bp.route("/protocol/<protocol_id>", methods=["PUT"])
def update_protocol(protocol_id: str):
    proto = db.get_or_404(Protocol, protocol_id)
    data = request.get_json()
    if "label" in data:
        proto.label = data["label"]
    if "subtitle" in data:
        proto.subtitle = data["subtitle"]
    if "position" in data:
        proto.position = data["position"]
    if "document_id" in data:
        proto.document_id = data["document_id"]
    if "scheduled_time" in data:
        proto.scheduled_time = _parse_time(data.get("scheduled_time"))
    if "group_id" in data:
        proto.group_id = data["group_id"]
    _commit_and_refresh()
    return jsonify({"id": proto.id, "label": proto.label})


@protocols_bp.route("/protocol/<protocol_id>", methods=["DELETE"])
def delete_protocol(protocol_id: str):
    proto = db.get_or_404(Protocol, protocol_id)
    db.session.delete(proto)
    _commit_and_refresh()
    return jsonify({"deleted": True})


@protocols_bp.route("/by-document/<document_id>", methods=["GET"])
def protocols_by_document(document_id: str):
    protocols = Protocol.query.filter_by(document_id=document_id).all()
    return jsonify([
        {
            "id": p.id, "label": p.label, "subtitle": p.subtitle,
            "group_name": p.group.name if p.group else None,
        }
        for p in protocols
    ])


# ── Legacy compat: flat list (used by sync) ──────────────────────────

@protocols_bp.route("/", methods=["GET"])
def list_all():
    """Return full hierarchy: sections → groups → protocols."""
    sections = (
        ProtocolSection.query
        .filter_by(user_id=TEMP_USER_ID)
        .order_by(ProtocolSection.position)
        .all()
    )
    return jsonify([_serialize_section(s) for s in sections])


# ── Daily Instance ───────────────────────────────────────────────────

@protocols_bp.route("/today", methods=["GET"])
def today_view():
    instance = get_or_create_daily_instance(TEMP_USER_ID, date.today())
    return jsonify(_serialize_instance(instance))


@protocols_bp.route("/daily/<date_str>", methods=["GET"])
def daily_view(date_str: str):
    target_date = date.fromisoformat(date_str)
    instance = DailyInstance.query.filter_by(user_id=TEMP_USER_ID, date=target_date).first()
    if not instance:
        return jsonify({"error": "No daily instance"}), 404
    return jsonify(_serialize_instance(instance))


@protocols_bp.route("/daily/task/<task_id>", methods=["PUT"])
def update_task(task_id: str):
    task = db.get_or_404(DailyTask, task_id)
    data = request.get_json()
    if "status" in data:
        task.status = data["status"]
        from datetime import datetime, timezone as tz
        task.completed_at = datetime.now(tz.utc) if data["status"] != "pending" else None
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


@protocols_bp.route("/history", methods=["GET"])
def history():
    instances = (
        DailyInstance.query.filter_by(user_id=TEMP_USER_ID)
        .order_by(DailyInstance.date.desc()).limit(90).all()
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


# ── Helpers ──────────────────────────────────────────────────────────

def _parse_time(val: str | None) -> time | None:
    if not val:
        return None
    parts = val.split(":")
    return time(int(parts[0]), int(parts[1]))


def _serialize_section(s: ProtocolSection) -> dict:
    return {
        "id": s.id,
        "name": s.name,
        "position": s.position,
        "groups": [
            {
                "id": g.id,
                "name": g.name,
                "position": g.position,
                "protocols": [
                    {
                        "id": p.id, "label": p.label, "subtitle": p.subtitle,
                        "position": p.position, "document_id": p.document_id,
                        "scheduled_time": p.scheduled_time.strftime("%H:%M") if p.scheduled_time else None,
                    }
                    for p in g.protocols
                ],
            }
            for g in s.groups
        ],
    }


def _serialize_instance(instance: DailyInstance) -> dict:
    tasks = sorted(instance.tasks, key=lambda t: (t.section_position, t.group_position, t.position))

    sections: dict[str, dict] = {}
    for task in tasks:
        skey = task.section_name
        if skey not in sections:
            sections[skey] = {"name": skey, "position": task.section_position, "groups": {}}
        gkey = task.group_name
        if gkey not in sections[skey]["groups"]:
            sections[skey]["groups"][gkey] = {
                "group_name": gkey, "group_position": task.group_position, "tasks": [],
            }
        sections[skey]["groups"][gkey]["tasks"].append({
            "id": task.id, "source_protocol_id": task.source_protocol_id,
            "label": task.label, "subtitle": task.subtitle, "position": task.position,
            "scheduled_time": task.scheduled_time.strftime("%H:%M") if task.scheduled_time else None,
            "document_id": task.document_id, "status": task.status,
            "completed_at": task.completed_at.isoformat() if task.completed_at else None,
        })

    result_sections = []
    for s in sorted(sections.values(), key=lambda x: x["position"]):
        result_sections.append({
            "name": s["name"],
            "position": s["position"],
            "groups": sorted(s["groups"].values(), key=lambda g: g["group_position"]),
        })

    total = len(tasks)
    completed = sum(1 for t in tasks if t.status == "completed")

    return {
        "id": instance.id,
        "date": instance.date.isoformat(),
        "sections": result_sections,
        "total_tasks": total,
        "completed_tasks": completed,
    }
