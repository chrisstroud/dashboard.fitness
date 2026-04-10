"""One-off script to initialize database tables directly."""
import sys
from app import create_app
from models import db

app = create_app()
with app.app_context():
    # Check if tables already exist
    from sqlalchemy import inspect
    inspector = inspect(db.engine)
    existing = inspector.get_table_names()
    print(f"Existing tables: {existing}", flush=True)

    if 'users' in existing:
        print("Tables already exist. Nothing to do.", flush=True)
        sys.exit(0)

    print("Creating all tables...", flush=True)
    db.create_all()

    # Stamp alembic version so future migrations work
    from alembic.config import Config as AlembicConfig
    from alembic import command
    alembic_cfg = AlembicConfig("migrations/alembic.ini")
    alembic_cfg.set_main_option("script_location", "migrations")
    alembic_cfg.set_main_option("sqlalchemy.url", str(db.engine.url))
    command.stamp(alembic_cfg, "head")

    # Verify
    tables_after = inspector.get_table_names()
    print(f"Created tables: {tables_after}", flush=True)
    print("Done!", flush=True)
