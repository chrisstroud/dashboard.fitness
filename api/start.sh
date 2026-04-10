#!/bin/bash
set -e

echo "Initializing database..."
timeout 30 python init_db.py || echo "DB init timed out or failed — starting server anyway"

echo "Starting gunicorn..."
exec gunicorn --bind 0.0.0.0:$PORT wsgi:app
