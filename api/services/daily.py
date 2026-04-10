"""Service to create and refresh daily instances from master protocol templates."""
from __future__ import annotations

import uuid
from datetime import date

from models import db
from models.protocol import DailyInstance, DailyTask, ProtocolSection


def get_or_create_daily_instance(user_id: str, target_date: date) -> DailyInstance:
    """Get today's daily instance, or create one from the master template."""
    existing = DailyInstance.query.filter_by(user_id=user_id, date=target_date).first()
    if existing:
        return existing
    return _stamp_instance(user_id, target_date)


def refresh_today(user_id: str) -> DailyInstance:
    """Re-sync today's daily instance with the current master template.

    - New protocols in master → added as pending tasks
    - Removed protocols → tasks deleted (even if completed)
    - Existing protocols → updated labels/subtitles/positions, status preserved
    """
    today = date.today()
    instance = DailyInstance.query.filter_by(user_id=user_id, date=today).first()
    if not instance:
        return _stamp_instance(user_id, today)

    sections = (
        ProtocolSection.query
        .filter_by(user_id=user_id)
        .order_by(ProtocolSection.position)
        .all()
    )

    # Build lookup of existing tasks by source_protocol_id
    existing_by_source = {}
    for task in instance.tasks:
        if task.source_protocol_id:
            existing_by_source[task.source_protocol_id] = task

    seen_protocol_ids = set()

    for section in sections:
        for group in section.groups:
            for proto in group.protocols:
                seen_protocol_ids.add(proto.id)

                if proto.id in existing_by_source:
                    # Update existing task but preserve status
                    task = existing_by_source[proto.id]
                    task.section_name = section.name
                    task.section_position = section.position
                    task.group_name = group.name
                    task.group_position = group.position
                    task.label = proto.label
                    task.subtitle = proto.subtitle
                    task.position = proto.position
                    task.scheduled_time = proto.scheduled_time
                    task.document_id = proto.document_id
                    # status and completed_at are NOT changed
                else:
                    # New protocol → add as pending
                    task = DailyTask(
                        id=str(uuid.uuid4()),
                        instance=instance,
                        source_protocol_id=proto.id,
                        section_name=section.name,
                        section_position=section.position,
                        group_name=group.name,
                        group_position=group.position,
                        label=proto.label,
                        subtitle=proto.subtitle,
                        position=proto.position,
                        scheduled_time=proto.scheduled_time,
                        document_id=proto.document_id,
                        status="pending",
                    )
                    db.session.add(task)

    # Remove tasks whose source protocol no longer exists in master
    for task in list(instance.tasks):
        if task.source_protocol_id and task.source_protocol_id not in seen_protocol_ids:
            db.session.delete(task)

    db.session.commit()
    return instance


def _stamp_instance(user_id: str, target_date: date) -> DailyInstance:
    """Create a new daily instance from the master template."""
    instance = DailyInstance(id=str(uuid.uuid4()), user_id=user_id, date=target_date)
    db.session.add(instance)

    sections = (
        ProtocolSection.query
        .filter_by(user_id=user_id)
        .order_by(ProtocolSection.position)
        .all()
    )

    for section in sections:
        for group in section.groups:
            for proto in group.protocols:
                task = DailyTask(
                    id=str(uuid.uuid4()),
                    instance=instance,
                    source_protocol_id=proto.id,
                    section_name=section.name,
                    section_position=section.position,
                    group_name=group.name,
                    group_position=group.position,
                    label=proto.label,
                    subtitle=proto.subtitle,
                    position=proto.position,
                    scheduled_time=proto.scheduled_time,
                    document_id=proto.document_id,
                    status="pending",
                )
                db.session.add(task)

    db.session.commit()
    return instance
