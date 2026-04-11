"""Dev server runner — used by .claude/launch.json."""
import os
import sys

# Ensure api/ is the working directory so Flask can find app, config, models
os.chdir(os.path.dirname(os.path.abspath(__file__)))

from app import create_app

app = create_app()
app.run(host="127.0.0.1", port=int(sys.argv[1]) if len(sys.argv) > 1 else 5001, debug=True, use_reloader=False)
