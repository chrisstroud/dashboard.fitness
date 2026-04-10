#!/bin/bash
set -e
echo "Running database migrations..."
python -c "
from app import create_app
from flask_migrate import upgrade
app = create_app()
with app.app_context():
    upgrade(directory='migrations')
print('Migrations complete.')
"
echo "Starting gunicorn..."
exec gunicorn --bind 0.0.0.0:$PORT wsgi:app
