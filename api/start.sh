#!/bin/bash
set -e

echo "Running database migrations (with 30s timeout)..."
timeout 30 python -c "
import sys
print('Starting migration...', flush=True)
from app import create_app
from flask_migrate import upgrade
app = create_app()
with app.app_context():
    upgrade(directory='migrations')
print('Migrations complete.', flush=True)
" || echo "Migration timed out or failed — starting server anyway"

echo "Starting gunicorn..."
exec gunicorn --bind 0.0.0.0:$PORT wsgi:app
