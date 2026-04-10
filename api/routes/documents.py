from __future__ import annotations

from flask import Blueprint, jsonify, request

from api.models import db
from api.models.document import Document

documents_bp = Blueprint("documents", __name__)

TEMP_USER_ID = "chris"


@documents_bp.route("/", methods=["GET"])
def list_documents():
    category = request.args.get("category")
    query = Document.query.filter_by(user_id=TEMP_USER_ID)
    if category:
        query = query.filter_by(category=category)
    docs = query.order_by(Document.updated_at.desc()).all()
    return jsonify([
        {
            "id": d.id,
            "title": d.title,
            "category": d.category,
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
        "category": d.category,
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
        category=data.get("category"),
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
    if "category" in data:
        doc.category = data["category"]
    db.session.commit()
    return jsonify({"id": doc.id, "title": doc.title})


@documents_bp.route("/<doc_id>", methods=["DELETE"])
def delete_document(doc_id: str):
    doc = db.get_or_404(Document, doc_id)
    db.session.delete(doc)
    db.session.commit()
    return jsonify({"deleted": True})
