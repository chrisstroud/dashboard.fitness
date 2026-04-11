"""Analytics service for protocol completion streaks and rates."""
from __future__ import annotations

from datetime import date, timedelta

from models.protocol import Protocol, ProtocolCompletion


def compute_analytics(protocol_id: str, user_id: str) -> dict:
    """Compute streak, completion rates, and totals for a protocol."""
    completions = (
        ProtocolCompletion.query
        .filter_by(protocol_id=protocol_id, user_id=user_id)
        .order_by(ProtocolCompletion.date.desc())
        .limit(365)
        .all()
    )

    completed_dates = sorted(
        {c.date for c in completions if c.status == "completed"},
        reverse=True,
    )

    today = date.today()

    # Current streak: consecutive days ending today or yesterday
    current_streak = 0
    if completed_dates:
        check = today
        if check not in completed_dates:
            check = today - timedelta(days=1)
            if check not in completed_dates:
                check = None
        if check:
            while check in completed_dates:
                current_streak += 1
                check -= timedelta(days=1)

    # Longest streak
    longest_streak = 0
    if completed_dates:
        streak = 1
        sorted_asc = sorted(completed_dates)
        for i in range(1, len(sorted_asc)):
            if (sorted_asc[i] - sorted_asc[i - 1]).days == 1:
                streak += 1
            else:
                longest_streak = max(longest_streak, streak)
                streak = 1
        longest_streak = max(longest_streak, streak)

    # Rates
    protocol = Protocol.query.get(protocol_id)
    weekly_target = protocol.weekly_target if protocol else None

    if weekly_target:
        expected_7d = weekly_target
        expected_30d = weekly_target * 4
    else:
        expected_7d = 7
        expected_30d = 30

    completed_7d = len([d for d in completed_dates if d >= today - timedelta(days=7)])
    completed_30d = len([d for d in completed_dates if d >= today - timedelta(days=30)])

    return {
        "current_streak": current_streak,
        "longest_streak": longest_streak,
        "rate_7d": round(min(completed_7d / max(expected_7d, 1), 1.0), 2),
        "rate_30d": round(min(completed_30d / max(expected_30d, 1), 1.0), 2),
        "total_completions": len(completed_dates),
        "last_completed": completed_dates[0].isoformat() if completed_dates else None,
    }
