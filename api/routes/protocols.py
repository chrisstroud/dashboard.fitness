from __future__ import annotations

from datetime import date, datetime, time, timezone as tz

from flask import Blueprint, g, jsonify, request

from models import db
from models.document import Document
from models.protocol import (
    DailyInstance, DailyTask, Protocol, ProtocolChangeLog,
    ProtocolCompletion, ProtocolDocument, ProtocolGroup, ProtocolSection,
)
from services.analytics import compute_analytics
from services.auth import decode_token
from services.daily import get_or_create_daily_instance, refresh_today

protocols_bp = Blueprint("protocols", __name__)


@protocols_bp.before_request
def _require_authentication():
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return jsonify({"error": "Authentication required"}), 401
    try:
        payload = decode_token(auth_header[7:])
        g.user_id = payload["sub"]
    except Exception:
        return jsonify({"error": "Invalid or expired token"}), 401


def _commit_and_refresh():
    """Commit DB changes and refresh today's daily instance to match master."""
    db.session.commit()
    refresh_today(g.user_id)


# ── Sections CRUD ────────────────────────────────────────────────────

@protocols_bp.route("/sections", methods=["GET"])
def list_sections():
    sections = (
        ProtocolSection.query
        .filter_by(user_id=g.user_id)
        .order_by(ProtocolSection.position)
        .all()
    )
    return jsonify([_serialize_section(s) for s in sections])


@protocols_bp.route("/sections", methods=["POST"])
def create_section():
    data = request.get_json()
    # Idempotent: if client provides an id and it already exists, return it
    client_id = data.get("id")
    if client_id:
        existing = db.session.get(ProtocolSection, client_id)
        if existing:
            return jsonify({"id": existing.id, "name": existing.name}), 200
    count = ProtocolSection.query.filter_by(user_id=g.user_id).count()
    section = ProtocolSection(
        user_id=g.user_id,
        name=data["name"],
        position=data.get("position", count),
    )
    if client_id:
        section.id = client_id
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
    # Idempotent: if client provides an id and it already exists, return it
    client_id = data.get("id")
    if client_id:
        existing = db.session.get(ProtocolGroup, client_id)
        if existing:
            return jsonify({"id": existing.id, "name": existing.name}), 200
    group = ProtocolGroup(
        section_id=section_id,
        name=data["name"],
        position=data.get("position", 0),
    )
    if client_id:
        group.id = client_id
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
        type=data.get("type", "task"),
        activity_type=data.get("activity_type"),
        duration_minutes=data.get("duration_minutes"),
        weekly_target=data.get("weekly_target"),
        reminder_time=_parse_time(data.get("reminder_time")),
        icon=data.get("icon"),
        color=data.get("color"),
    )
    db.session.add(proto)
    _commit_and_refresh()
    return jsonify({"id": proto.id, "label": proto.label}), 201


@protocols_bp.route("/protocol/<protocol_id>", methods=["PUT"])
def update_protocol(protocol_id: str):
    proto = db.get_or_404(Protocol, protocol_id)
    data = request.get_json()

    # Reject type changes after creation
    if "type" in data and data["type"] != proto.type:
        return jsonify({"error": "Cannot change protocol type after creation"}), 400

    tracked_fields = {
        "label": ("label", str),
        "subtitle": ("subtitle", str),
        "scheduled_time": ("scheduled_time", lambda v: v.strftime("%H:%M") if v else None),
        "document_id": ("document_id", str),
    }

    for field, (attr, fmt) in tracked_fields.items():
        if field in data:
            old_val = getattr(proto, attr)
            new_val = data[field]
            old_str = fmt(old_val) if callable(fmt) and old_val is not None else str(old_val) if old_val else None
            new_str = str(new_val) if new_val else None
            if old_str != new_str:
                log = ProtocolChangeLog(
                    protocol_id=proto.id,
                    field=field,
                    old_value=old_str,
                    new_value=new_str,
                )
                db.session.add(log)

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
    if "activity_type" in data:
        proto.activity_type = data["activity_type"]
    if "duration_minutes" in data:
        proto.duration_minutes = data["duration_minutes"]
    if "weekly_target" in data:
        proto.weekly_target = data["weekly_target"]
    if "reminder_time" in data:
        proto.reminder_time = _parse_time(data.get("reminder_time"))
    if "icon" in data:
        proto.icon = data["icon"]
    if "color" in data:
        proto.color = data["color"]
    _commit_and_refresh()
    return jsonify({"id": proto.id, "label": proto.label})


@protocols_bp.route("/protocol/<protocol_id>", methods=["DELETE"])
def delete_protocol(protocol_id: str):
    proto = db.get_or_404(Protocol, protocol_id)
    db.session.delete(proto)
    _commit_and_refresh()
    return jsonify({"deleted": True})


@protocols_bp.route("/protocol/<protocol_id>/detail", methods=["GET"])
def protocol_detail(protocol_id: str):
    """Full detail view for a single protocol: history, stats, changes, docs."""
    proto = db.get_or_404(Protocol, protocol_id)

    # Completion stats from daily tasks
    tasks = DailyTask.query.filter_by(source_protocol_id=protocol_id).all()
    total_days = len(tasks)
    completed_days = sum(1 for t in tasks if t.status == "completed")
    skipped_days = sum(1 for t in tasks if t.status == "skipped")

    # First appearance (oldest daily task with this source)
    first_task = (
        DailyTask.query
        .filter_by(source_protocol_id=protocol_id)
        .join(DailyInstance)
        .order_by(DailyInstance.date.asc())
        .first()
    )
    first_date = first_task.instance.date.isoformat() if first_task and first_task.instance else None

    # Current streak
    streak = 0
    if tasks:
        sorted_tasks = sorted(tasks, key=lambda t: t.instance.date if t.instance else date.min, reverse=True)
        for t in sorted_tasks:
            if t.status == "completed":
                streak += 1
            else:
                break

    # Change log
    changes = [
        {
            "field": c.field,
            "old_value": c.old_value,
            "new_value": c.new_value,
            "changed_at": c.changed_at.isoformat() if c.changed_at else None,
        }
        for c in proto.change_logs
    ]

    # Linked document
    doc_info = None
    if proto.document and proto.document_id:
        doc_info = {
            "id": proto.document.id,
            "title": proto.document.title,
        }

    return jsonify({
        "id": proto.id,
        "label": proto.label,
        "subtitle": proto.subtitle,
        "type": proto.type,
        "activity_type": proto.activity_type,
        "duration_minutes": proto.duration_minutes,
        "weekly_target": proto.weekly_target,
        "reminder_time": proto.reminder_time.strftime("%H:%M") if proto.reminder_time else None,
        "icon": proto.icon,
        "color": proto.color,
        "scheduled_time": proto.scheduled_time.strftime("%H:%M") if proto.scheduled_time else None,
        "group_name": proto.group.name if proto.group else None,
        "section_name": proto.group.section.name if proto.group and proto.group.section else None,
        "created_at": proto.created_at.isoformat() if proto.created_at else None,
        "first_tracked": first_date,
        "stats": {
            "total_days": total_days,
            "completed_days": completed_days,
            "skipped_days": skipped_days,
            "completion_rate": round(completed_days / total_days, 2) if total_days > 0 else 0,
            "current_streak": streak,
        },
        "changes": changes,
        "document": doc_info,
    })


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
        .filter_by(user_id=g.user_id)
        .order_by(ProtocolSection.position)
        .all()
    )
    return jsonify([_serialize_section(s) for s in sections])


# ── Daily Instance ───────────────────────────────────────────────────

@protocols_bp.route("/today", methods=["GET"])
def today_view():
    # Accept client date to avoid timezone mismatch (server is UTC)
    date_str = request.args.get("date")
    if date_str:
        target_date = date.fromisoformat(date_str)
    else:
        target_date = date.today()
    instance = get_or_create_daily_instance(g.user_id, target_date)
    return jsonify(_serialize_instance(instance))


@protocols_bp.route("/daily/<date_str>", methods=["GET"])
def daily_view(date_str: str):
    target_date = date.fromisoformat(date_str)
    instance = DailyInstance.query.filter_by(user_id=g.user_id, date=target_date).first()
    if not instance:
        return jsonify({"error": "No daily instance"}), 404
    return jsonify(_serialize_instance(instance))


@protocols_bp.route("/daily/task/<task_id>", methods=["PUT"])
def update_task(task_id: str):
    task = db.get_or_404(DailyTask, task_id)
    data = request.get_json()
    if "status" in data:
        old_status = task.status
        new_status = data["status"]
        task.status = new_status
        now = datetime.now(tz.utc)
        task.completed_at = now if new_status != "pending" else None

        # Dual-write: sync to protocol_completions when task has a source protocol
        if task.source_protocol_id:
            today = task.instance.date if task.instance else date.today()
            if new_status == "completed" and old_status != "completed":
                existing = ProtocolCompletion.query.filter_by(
                    protocol_id=task.source_protocol_id,
                    user_id=g.user_id,
                    date=today,
                ).first()
                if existing:
                    existing.status = "completed"
                    existing.completed_at = now
                else:
                    completion = ProtocolCompletion(
                        protocol_id=task.source_protocol_id,
                        user_id=g.user_id,
                        date=today,
                        status="completed",
                        completed_at=now,
                    )
                    db.session.add(completion)
            elif new_status != "completed" and old_status == "completed":
                ProtocolCompletion.query.filter_by(
                    protocol_id=task.source_protocol_id,
                    user_id=g.user_id,
                    date=today,
                ).delete()

    db.session.commit()
    return jsonify({"id": task.id, "status": task.status})


@protocols_bp.route("/daily/bulk", methods=["PUT"])
def bulk_update_tasks():
    data = request.get_json()
    task_ids = data.get("task_ids", [])
    status = data.get("status", "completed")
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
        DailyInstance.query.filter_by(user_id=g.user_id)
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


# ── Protocol Completions (Story 2.1) ────────────────────────────────

def _verify_protocol_ownership(protocol_id: str) -> Protocol | None:
    """Return the protocol if it belongs to the current user, else None."""
    proto = Protocol.query.get(protocol_id)
    if not proto or not proto.group or not proto.group.section:
        return None
    if proto.group.section.user_id != g.user_id:
        return None
    return proto


@protocols_bp.route("/protocol/<protocol_id>/complete", methods=["POST"])
def complete_protocol(protocol_id: str):
    """Mark a protocol complete for today (upsert)."""
    proto = _verify_protocol_ownership(protocol_id)
    if not proto:
        return jsonify({"error": "Protocol not found"}), 404

    data = request.get_json() or {}
    today = date.today()
    now = datetime.now(tz.utc)

    existing = ProtocolCompletion.query.filter_by(
        protocol_id=protocol_id, user_id=g.user_id, date=today,
    ).first()

    if existing:
        existing.status = data.get("status", "completed")
        existing.completed_at = now
        existing.duration_minutes = data.get("duration_minutes")
        existing.calories = data.get("calories")
        existing.avg_heart_rate = data.get("avg_heart_rate")
        existing.notes = data.get("notes")
        completion = existing
    else:
        completion = ProtocolCompletion(
            protocol_id=protocol_id,
            user_id=g.user_id,
            date=today,
            status=data.get("status", "completed"),
            completed_at=now,
            duration_minutes=data.get("duration_minutes"),
            calories=data.get("calories"),
            avg_heart_rate=data.get("avg_heart_rate"),
            notes=data.get("notes"),
        )
        db.session.add(completion)

    db.session.commit()
    return jsonify(_serialize_completion(completion)), 201


@protocols_bp.route("/protocol/<protocol_id>/complete", methods=["DELETE"])
def undo_completion(protocol_id: str):
    """Undo a protocol completion for a given date (defaults to today)."""
    proto = _verify_protocol_ownership(protocol_id)
    if not proto:
        return jsonify({"error": "Protocol not found"}), 404

    date_str = request.args.get("date")
    target_date = date.fromisoformat(date_str) if date_str else date.today()

    ProtocolCompletion.query.filter_by(
        protocol_id=protocol_id, user_id=g.user_id, date=target_date,
    ).delete()
    db.session.commit()
    return "", 204


@protocols_bp.route("/protocol/<protocol_id>/history", methods=["GET"])
def completion_history(protocol_id: str):
    """Completion history for a protocol."""
    proto = _verify_protocol_ownership(protocol_id)
    if not proto:
        return jsonify({"error": "Protocol not found"}), 404

    from_str = request.args.get("from")
    to_str = request.args.get("to")
    limit = int(request.args.get("limit", 90))

    query = ProtocolCompletion.query.filter_by(
        protocol_id=protocol_id, user_id=g.user_id,
    )
    if from_str:
        query = query.filter(ProtocolCompletion.date >= date.fromisoformat(from_str))
    if to_str:
        query = query.filter(ProtocolCompletion.date <= date.fromisoformat(to_str))

    completions = (
        query.order_by(ProtocolCompletion.date.desc())
        .limit(limit)
        .all()
    )
    return jsonify([_serialize_completion(c) for c in completions])


# ── Analytics (Story 2.2) ──────────────────────────────────────────

@protocols_bp.route("/protocol/<protocol_id>/analytics", methods=["GET"])
def protocol_analytics(protocol_id: str):
    """Return streak, completion rates, and totals for a protocol."""
    proto = _verify_protocol_ownership(protocol_id)
    if not proto:
        return jsonify({"error": "Protocol not found"}), 404
    return jsonify(compute_analytics(protocol_id, g.user_id))


# ── Protocol-Document Links (Story 2.3) ────────────────────────────

@protocols_bp.route("/protocol/<protocol_id>/documents", methods=["POST"])
def attach_document(protocol_id: str):
    """Attach a document to a protocol."""
    proto = _verify_protocol_ownership(protocol_id)
    if not proto:
        return jsonify({"error": "Protocol not found"}), 404

    data = request.get_json()
    document_id = data.get("document_id")
    if not document_id:
        return jsonify({"error": "document_id is required"}), 400

    # Verify document belongs to user
    doc = Document.query.get(document_id)
    if not doc or doc.user_id != g.user_id:
        return jsonify({"error": "Document not found"}), 404

    # Check for existing link
    existing = ProtocolDocument.query.filter_by(
        protocol_id=protocol_id, document_id=document_id,
    ).first()
    if existing:
        return jsonify({"error": "Document already attached"}), 409

    link = ProtocolDocument(
        protocol_id=protocol_id,
        document_id=document_id,
        position=data.get("position", 0),
    )
    db.session.add(link)
    db.session.commit()
    return jsonify({
        "id": link.id,
        "protocol_id": link.protocol_id,
        "document_id": link.document_id,
        "position": link.position,
    }), 201


@protocols_bp.route(
    "/protocol/<protocol_id>/documents/<document_id>", methods=["DELETE"],
)
def detach_document(protocol_id: str, document_id: str):
    """Detach a document from a protocol (does NOT delete the document)."""
    proto = _verify_protocol_ownership(protocol_id)
    if not proto:
        return jsonify({"error": "Protocol not found"}), 404

    ProtocolDocument.query.filter_by(
        protocol_id=protocol_id, document_id=document_id,
    ).delete()
    db.session.commit()
    return "", 204


@protocols_bp.route("/protocol/<protocol_id>/documents", methods=["GET"])
def list_attached_documents(protocol_id: str):
    """List documents attached to a protocol, ordered by position."""
    proto = _verify_protocol_ownership(protocol_id)
    if not proto:
        return jsonify({"error": "Protocol not found"}), 404

    links = (
        ProtocolDocument.query
        .filter_by(protocol_id=protocol_id)
        .order_by(ProtocolDocument.position)
        .all()
    )
    result = []
    for link in links:
        doc = link.document
        if doc:
            result.append({
                "id": doc.id,
                "title": doc.title,
                "content": doc.content,
                "position": link.position,
                "created_at": doc.created_at.isoformat() if doc.created_at else None,
                "updated_at": doc.updated_at.isoformat() if doc.updated_at else None,
            })
    return jsonify(result)


# ── Helpers ──────────────────────────────────────────────────────────

def _parse_time(val: str | None) -> time | None:
    if not val:
        return None
    parts = val.split(":")
    return time(int(parts[0]), int(parts[1]))


def _serialize_completion(c: ProtocolCompletion) -> dict:
    return {
        "id": c.id,
        "protocol_id": c.protocol_id,
        "user_id": c.user_id,
        "date": c.date.isoformat(),
        "status": c.status,
        "completed_at": c.completed_at.isoformat() if c.completed_at else None,
        "duration_minutes": c.duration_minutes,
        "calories": c.calories,
        "avg_heart_rate": c.avg_heart_rate,
        "notes": c.notes,
    }


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
                        "type": p.type,
                        "activity_type": p.activity_type,
                        "duration_minutes": p.duration_minutes,
                        "weekly_target": p.weekly_target,
                        "reminder_time": p.reminder_time.strftime("%H:%M") if p.reminder_time else None,
                        "icon": p.icon,
                        "color": p.color,
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
            "type": task.type,
            "activity_type": task.activity_type,
            "duration_minutes": task.duration_minutes,
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
