from __future__ import annotations

from flask import Flask
from flask_cors import CORS
from flask_migrate import Migrate

from api.config import Config
from api.models import db


migrate = Migrate()


def create_app(config_class: type = Config) -> Flask:
    app = Flask(__name__)
    app.config.from_object(config_class)

    db.init_app(app)
    migrate.init_app(app, db)
    CORS(app)

    from api.routes.health import health_bp
    from api.routes.workouts import workouts_bp
    from api.routes.sessions import sessions_bp
    from api.routes.metrics import metrics_bp
    from api.routes.protocols import protocols_bp
    from api.routes.documents import documents_bp

    app.register_blueprint(health_bp)
    app.register_blueprint(workouts_bp, url_prefix="/api/workouts")
    app.register_blueprint(sessions_bp, url_prefix="/api/sessions")
    app.register_blueprint(metrics_bp, url_prefix="/api/metrics")
    app.register_blueprint(protocols_bp, url_prefix="/api/protocols")
    app.register_blueprint(documents_bp, url_prefix="/api/documents")

    return app
