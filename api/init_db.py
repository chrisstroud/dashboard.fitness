"""One-off script to initialize database tables directly."""
import os
import sys

db_url = os.environ.get("DATABASE_URL", "NOT SET")
print(f"DATABASE_URL: {db_url[:50]}...", flush=True)

# Quick connection test first
print("Testing raw connection...", flush=True)
try:
    import psycopg2
    # Parse the URL for psycopg2
    conn = psycopg2.connect(db_url, connect_timeout=15)
    print("Connected to Postgres!", flush=True)
    cur = conn.cursor()
    cur.execute("SELECT version()")
    print(f"Postgres version: {cur.fetchone()[0][:50]}", flush=True)
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}", flush=True)
    sys.exit(1)

# Now do the actual initialization
from app import create_app
from models import db

app = create_app()
with app.app_context():
    from sqlalchemy import inspect, text
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

    tables_after = inspector.get_table_names()
    print(f"Created tables: {tables_after}", flush=True)
    print("Done!", flush=True)
