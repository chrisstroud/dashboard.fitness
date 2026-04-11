from __future__ import annotations

from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

from models.user import User  # noqa: E402, F401
from models.workout import (  # noqa: E402, F401
    Exercise,
    ExerciseSet,
    WorkoutTemplate,
    WorkoutTemplateExercise,
)
from models.session import (  # noqa: E402, F401
    ExerciseLog,
    SetLog,
    WorkoutSession,
)
from models.metric import BodyWeight  # noqa: E402, F401
from models.protocol import (  # noqa: E402, F401
    DailyInstance,
    DailyTask,
    Protocol,
    ProtocolChangeLog,
    ProtocolCompletion,
    ProtocolDocument,
    ProtocolGroup,
    ProtocolSection,
)
from models.document import Document, Folder, WorkoutCompletion  # noqa: E402, F401
