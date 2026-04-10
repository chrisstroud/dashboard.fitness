from __future__ import annotations

from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

from api.models.user import User  # noqa: E402, F401
from api.models.workout import (  # noqa: E402, F401
    Exercise,
    ExerciseSet,
    WorkoutTemplate,
    WorkoutTemplateExercise,
)
from api.models.session import (  # noqa: E402, F401
    ExerciseLog,
    SetLog,
    WorkoutSession,
)
from api.models.metric import BodyWeight  # noqa: E402, F401
from api.models.protocol import (  # noqa: E402, F401
    DailyInstance,
    DailyTask,
    Protocol,
    ProtocolChangeLog,
    ProtocolGroup,
    ProtocolSection,
)
from api.models.document import Document, Folder, WorkoutCompletion  # noqa: E402, F401
