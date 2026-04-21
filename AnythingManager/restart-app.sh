#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BUNDLE="$SCRIPT_DIR/../Applications/AnythingManager.app"

echo "Building fresh app..."
cd "$SCRIPT_DIR"
./build-app.sh

echo "Stopping old AnythingManager..."
# NEVER use killall — it slaughters every process with the same name.
# We find the exact PID that belongs to the .app bundle.
OLD_PID=$(pgrep -f "Applications/AnythingManager.app" || true)
if [ -n "$OLD_PID" ]; then
    echo "Found old instance PID: $OLD_PID"
    kill "$OLD_PID" 2>/dev/null || true
    sleep 0.5
    if kill -0 "$OLD_PID" 2>/dev/null; then
        kill -9 "$OLD_PID" 2>/dev/null || true
    fi
else
    echo "No old instance running"
fi
sleep 0.3

echo "Starting new version..."
open "$APP_BUNDLE"

echo ""
echo "Done."
