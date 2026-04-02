#!/bin/bash
# Auto-sync iCloud ↔ GitHub
# Runs periodically via launchd to keep both in sync.
#
# Flow:
#   1. Pull latest from GitHub (picks up PWA checkbox commits + Action-generated files)
#   2. Stage any local changes (picks up 1Writer edits via iCloud)
#   3. Commit and push if there are changes

set -euo pipefail

REPO_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/dashboard.fitness"
cd "$REPO_DIR"

# Skip if no git repo
if [ ! -d .git ]; then
  echo "Not a git repo: $REPO_DIR"
  exit 1
fi

# Pull remote changes (GitHub → local/iCloud)
git pull --rebase --autostash 2>/dev/null || git pull --no-rebase 2>/dev/null || true

# Check for local changes (iCloud/1Writer → GitHub)
if [ -n "$(git status --porcelain)" ]; then
  git add days/ weeks/ docs/ "Volume Daddy/" data/

  # Only commit if there are staged changes
  if ! git diff --cached --quiet; then
    git commit -m "sync: iCloud changes $(date +%Y-%m-%dT%H:%M)"
    git push || true
  fi
fi
