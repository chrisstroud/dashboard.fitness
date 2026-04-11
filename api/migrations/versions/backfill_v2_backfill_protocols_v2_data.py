"""backfill protocols v2 data

Revision ID: backfill_v2
Revises: 61c43df49a56
Create Date: 2026-04-11 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from uuid import uuid4
from datetime import datetime, timezone


# revision identifiers, used by Alembic.
revision = 'backfill_v2'
down_revision = '61c43df49a56'
branch_labels = None
depends_on = None


def upgrade():
    conn = op.get_bind()

    # 1. Ensure all existing protocols have type='task'
    conn.execute(sa.text(
        "UPDATE protocols SET type = 'task' WHERE type IS NULL OR type = ''"
    ))

    # 2. Find workout documents (documents in folders named 'workouts')
    workout_docs = conn.execute(sa.text("""
        SELECT d.id, d.user_id, d.title, d.weekly_target, d.duration_minutes,
               d.activity_type, d.folder_id
        FROM documents d
        JOIN folders f ON d.folder_id = f.id
        WHERE LOWER(f.name) = 'workouts'
    """)).fetchall()

    for doc in workout_docs:
        user_id = doc.user_id

        # Find or create a "Training" section for this user
        training_section = conn.execute(sa.text(
            "SELECT id FROM protocol_sections"
            " WHERE user_id = :uid AND LOWER(name) = 'training'"
        ), {"uid": user_id}).fetchone()

        if not training_section:
            section_id = str(uuid4())
            max_pos = conn.execute(sa.text(
                "SELECT COALESCE(MAX(position), -1) FROM protocol_sections WHERE user_id = :uid"
            ), {"uid": user_id}).scalar()
            conn.execute(sa.text("""
                INSERT INTO protocol_sections (id, user_id, name, position, created_at)
                VALUES (:id, :uid, 'Training', :pos, :now)
            """), {
                "id": section_id, "uid": user_id,
                "pos": max_pos + 1, "now": datetime.now(timezone.utc),
            })
        else:
            section_id = training_section[0]

        # Find or create a "Workouts" group in that section
        workouts_group = conn.execute(sa.text(
            "SELECT id FROM protocol_groups"
            " WHERE section_id = :sid AND LOWER(name) = 'workouts'"
        ), {"sid": section_id}).fetchone()

        if not workouts_group:
            group_id = str(uuid4())
            max_pos = conn.execute(sa.text(
                "SELECT COALESCE(MAX(position), -1) FROM protocol_groups WHERE section_id = :sid"
            ), {"sid": section_id}).scalar()
            conn.execute(sa.text("""
                INSERT INTO protocol_groups (id, section_id, name, position, created_at)
                VALUES (:id, :sid, 'Workouts', :pos, :now)
            """), {
                "id": group_id, "sid": section_id,
                "pos": max_pos + 1, "now": datetime.now(timezone.utc),
            })
        else:
            group_id = workouts_group[0]

        # Check if protocol already exists for this doc (idempotency)
        existing = conn.execute(sa.text(
            "SELECT id FROM protocols WHERE group_id = :gid AND label = :label"
        ), {"gid": group_id, "label": doc.title}).fetchone()

        if existing:
            protocol_id = existing[0]
        else:
            protocol_id = str(uuid4())
            max_pos = conn.execute(sa.text(
                "SELECT COALESCE(MAX(position), -1) FROM protocols WHERE group_id = :gid"
            ), {"gid": group_id}).scalar()
            conn.execute(sa.text("""
                INSERT INTO protocols
                    (id, group_id, label, type, activity_type, duration_minutes,
                     weekly_target, position, document_id, created_at)
                VALUES
                    (:id, :gid, :label, 'workout', :at, :dur, :wt, :pos, :did, :now)
            """), {
                "id": protocol_id,
                "gid": group_id,
                "label": doc.title,
                "at": doc.activity_type or "strength",
                "dur": doc.duration_minutes,
                "wt": doc.weekly_target,
                "pos": max_pos + 1,
                "did": doc.id,
                "now": datetime.now(timezone.utc),
            })

        # Link document to protocol via protocol_documents (idempotent)
        existing_link = conn.execute(sa.text(
            "SELECT id FROM protocol_documents"
            " WHERE protocol_id = :pid AND document_id = :did"
        ), {"pid": protocol_id, "did": doc.id}).fetchone()

        if not existing_link:
            conn.execute(sa.text("""
                INSERT INTO protocol_documents (id, protocol_id, document_id, position, created_at)
                VALUES (:id, :pid, :did, 0, :now)
            """), {
                "id": str(uuid4()), "pid": protocol_id, "did": doc.id,
                "now": datetime.now(timezone.utc),
            })

        # Copy workout_completions to protocol_completions (idempotent)
        completions = conn.execute(sa.text("""
            SELECT id, user_id, date, duration_minutes, notes, completed_at
            FROM workout_completions
            WHERE document_id = :did
        """), {"did": doc.id}).fetchall()

        for comp in completions:
            existing_comp = conn.execute(sa.text(
                "SELECT id FROM protocol_completions"
                " WHERE protocol_id = :pid AND user_id = :uid AND date = :d"
            ), {"pid": protocol_id, "uid": comp.user_id, "d": comp.date}).fetchone()

            if not existing_comp:
                conn.execute(sa.text("""
                    INSERT INTO protocol_completions
                        (id, protocol_id, user_id, date, status, completed_at,
                         duration_minutes, notes, created_at)
                    VALUES
                        (:id, :pid, :uid, :d, 'completed', :ca, :dur, :notes, :now)
                """), {
                    "id": str(uuid4()),
                    "pid": protocol_id,
                    "uid": comp.user_id,
                    "d": comp.date,
                    "ca": comp.completed_at,
                    "dur": comp.duration_minutes,
                    "notes": comp.notes,
                    "now": datetime.now(timezone.utc),
                })


def downgrade():
    conn = op.get_bind()
    # Remove all data written by this backfill.
    # Sections and groups are left in place — they may have been created
    # manually after the migration ran.
    conn.execute(sa.text("DELETE FROM protocol_completions"))
    conn.execute(sa.text("DELETE FROM protocol_documents"))
    conn.execute(sa.text("DELETE FROM protocols WHERE type = 'workout'"))
