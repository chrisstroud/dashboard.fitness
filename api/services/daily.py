"""Service to create daily instances from master protocol templates."""
from __future__ import annotations

import uuid
from datetime import date

from api.models import db
from api.models.protocol import DailyInstance, DailyTask, ProtocolGroup


def get_or_create_daily_instance(user_id: str, target_date: date) -> DailyInstance:
    """Get today's daily instance, or create one from the master template."""
    existing = DailyInstance.query.filter_by(user_id=user_id, date=target_date).first()
    if existing:
        return existing

    # Create new instance from master protocols
    instance = DailyInstance(id=str(uuid.uuid4()), user_id=user_id, date=target_date)
    db.session.add(instance)

    groups = (
        ProtocolGroup.query
        .filter_by(user_id=user_id)
        .order_by(ProtocolGroup.position)
        .all()
    )

    for group in groups:
        for proto in group.protocols:
            task = DailyTask(
                id=str(uuid.uuid4()),
                instance=instance,
                source_protocol_id=proto.id,
                group_name=group.name,
                section=group.section,
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
