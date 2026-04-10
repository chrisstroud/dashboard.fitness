from __future__ import annotations

from flask import Blueprint, jsonify, request

from api.models import db
from datetime import date, timedelta

from api.models.document import Document, Folder, WorkoutCompletion

documents_bp = Blueprint("documents", __name__)

TEMP_USER_ID = "chris"


# MARK: - Folders

@documents_bp.route("/folders", methods=["GET"])
def list_folders():
    parent_id = request.args.get("parent_id")
    query = Folder.query.filter_by(user_id=TEMP_USER_ID)
    if parent_id:
        query = query.filter_by(parent_id=parent_id)
    else:
        query = query.filter(Folder.parent_id.is_(None))
    folders = query.order_by(Folder.position).all()
    return jsonify([
        {
            "id": f.id,
            "name": f.name,
            "parent_id": f.parent_id,
            "position": f.position,
        }
        for f in folders
    ])


@documents_bp.route("/folders", methods=["POST"])
def create_folder():
    data = request.get_json()
    folder = Folder(
        user_id=TEMP_USER_ID,
        name=data["name"],
        parent_id=data.get("parent_id"),
        position=data.get("position", 0),
    )
    db.session.add(folder)
    db.session.commit()
    return jsonify({"id": folder.id, "name": folder.name}), 201


@documents_bp.route("/folders/<folder_id>", methods=["PUT"])
def update_folder(folder_id: str):
    folder = db.get_or_404(Folder, folder_id)
    data = request.get_json()
    if "name" in data:
        folder.name = data["name"]
    if "parent_id" in data:
        folder.parent_id = data["parent_id"]
    if "position" in data:
        folder.position = data["position"]
    db.session.commit()
    return jsonify({"id": folder.id, "name": folder.name})


@documents_bp.route("/folders/<folder_id>", methods=["DELETE"])
def delete_folder(folder_id: str):
    folder = db.get_or_404(Folder, folder_id)
    db.session.delete(folder)
    db.session.commit()
    return jsonify({"deleted": True})


@documents_bp.route("/folders/<folder_id>/contents", methods=["GET"])
def folder_contents(folder_id: str):
    subfolders = (
        Folder.query
        .filter_by(user_id=TEMP_USER_ID, parent_id=folder_id)
        .order_by(Folder.position)
        .all()
    )
    docs = (
        Document.query
        .filter_by(user_id=TEMP_USER_ID, folder_id=folder_id)
        .order_by(Document.title)
        .all()
    )
    return jsonify({
        "folders": [
            {"id": f.id, "name": f.name, "position": f.position}
            for f in subfolders
        ],
        "documents": [
            {
                "id": d.id, "title": d.title,
                "created_at": d.created_at.isoformat() if d.created_at else None,
                "updated_at": d.updated_at.isoformat() if d.updated_at else None,
            }
            for d in docs
        ],
    })


# MARK: - Documents

@documents_bp.route("/", methods=["GET"])
def list_documents():
    """List documents. Use ?folder_id= to filter, or ?root=true for unfiled docs."""
    folder_id = request.args.get("folder_id")
    root_only = request.args.get("root")

    query = Document.query.filter_by(user_id=TEMP_USER_ID)
    if folder_id:
        query = query.filter_by(folder_id=folder_id)
    elif root_only:
        query = query.filter(Document.folder_id.is_(None))

    docs = query.order_by(Document.updated_at.desc()).all()
    return jsonify([
        {
            "id": d.id,
            "title": d.title,
            "folder_id": d.folder_id,
            "created_at": d.created_at.isoformat() if d.created_at else None,
            "updated_at": d.updated_at.isoformat() if d.updated_at else None,
        }
        for d in docs
    ])


@documents_bp.route("/<doc_id>", methods=["GET"])
def get_document(doc_id: str):
    d = db.get_or_404(Document, doc_id)
    return jsonify({
        "id": d.id,
        "title": d.title,
        "content": d.content,
        "folder_id": d.folder_id,
        "created_at": d.created_at.isoformat() if d.created_at else None,
        "updated_at": d.updated_at.isoformat() if d.updated_at else None,
    })


@documents_bp.route("/", methods=["POST"])
def create_document():
    data = request.get_json()
    doc = Document(
        user_id=TEMP_USER_ID,
        title=data["title"],
        content=data.get("content", ""),
        folder_id=data.get("folder_id"),
        weekly_target=data.get("weekly_target"),
        duration_minutes=data.get("duration_minutes"),
        activity_type=data.get("activity_type"),
    )
    db.session.add(doc)
    db.session.commit()
    return jsonify({"id": doc.id, "title": doc.title}), 201


@documents_bp.route("/<doc_id>", methods=["PUT"])
def update_document(doc_id: str):
    doc = db.get_or_404(Document, doc_id)
    data = request.get_json()
    if "title" in data:
        doc.title = data["title"]
    if "content" in data:
        doc.content = data["content"]
    if "folder_id" in data:
        doc.folder_id = data["folder_id"]
    if "weekly_target" in data:
        doc.weekly_target = data["weekly_target"]
    if "duration_minutes" in data:
        doc.duration_minutes = data["duration_minutes"]
    if "activity_type" in data:
        doc.activity_type = data["activity_type"]
    db.session.commit()
    return jsonify({"id": doc.id, "title": doc.title})


@documents_bp.route("/<doc_id>", methods=["DELETE"])
def delete_document(doc_id: str):
    doc = db.get_or_404(Document, doc_id)
    db.session.delete(doc)
    db.session.commit()
    return jsonify({"deleted": True})


# ── Workout Completions ──────────────────────────────────────────────

@documents_bp.route("/workouts/status", methods=["GET"])
def workout_status():
    """Get all workout docs with weekly completion counts."""
    # Find the Workouts folder
    folder = Folder.query.filter_by(user_id=TEMP_USER_ID, name="Workouts").first()
    if not folder:
        return jsonify([])

    docs = Document.query.filter_by(folder_id=folder.id).order_by(Document.title).all()

    # Current week boundaries (Monday-Sunday)
    today = date.today()
    week_start = today - timedelta(days=today.weekday())

    result = []
    for doc in docs:
        week_completions = WorkoutCompletion.query.filter(
            WorkoutCompletion.document_id == doc.id,
            WorkoutCompletion.user_id == TEMP_USER_ID,
            WorkoutCompletion.date >= week_start,
        ).count()

        today_done = WorkoutCompletion.query.filter_by(
            document_id=doc.id, user_id=TEMP_USER_ID, date=today,
        ).first() is not None

        result.append({
            "id": doc.id,
            "title": doc.title,
            "weekly_target": doc.weekly_target,
            "week_completions": week_completions,
            "completed_today": today_done,
        })

    return jsonify(result)


@documents_bp.route("/workouts/<doc_id>/toggle", methods=["POST"])
def toggle_workout(doc_id: str):
    """Toggle workout completion for today."""
    today = date.today()
    existing = WorkoutCompletion.query.filter_by(
        user_id=TEMP_USER_ID, document_id=doc_id, date=today,
    ).first()

    if existing:
        db.session.delete(existing)
        db.session.commit()
        return jsonify({"completed_today": False})
    else:
        completion = WorkoutCompletion(user_id=TEMP_USER_ID, document_id=doc_id, date=today)
        db.session.add(completion)
        db.session.commit()
        return jsonify({"completed_today": True}), 201
