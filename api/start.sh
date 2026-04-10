#!/bin/bash
set -e

echo "DATABASE_URL is set: $([ -n "$DATABASE_URL" ] && echo 'yes' || echo 'no')"
echo "DATABASE_URL host: $(echo $DATABASE_URL | sed 's|.*@\(.*\)/.*|\1|')"

echo "Running database migrations..."
python -c "
import sys
print('Python starting...', flush=True)
try:
    from app import create_app
    print('App imported.', flush=True)
    from flask_migrate import upgrade
    print('Flask-Migrate imported.', flush=True)
    app = create_app()
    print(f'App created. DB URI prefix: {app.config[\"SQLALCHEMY_DATABASE_URI\"][:30]}...', flush=True)
    with app.app_context():
        print('Running upgrade...', flush=True)
        upgrade(directory='migrations')
    print('Migrations complete.', flush=True)
except Exception as e:
    print(f'Migration error: {e}', flush=True)
    sys.exit(1)
"

echo "Starting gunicorn..."
exec gunicorn --bind 0.0.0.0:$PORT wsgi:app
