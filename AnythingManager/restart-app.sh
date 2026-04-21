#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="AnythingManager"
APP_BUNDLE="$SCRIPT_DIR/../Applications/$APP_NAME.app"

echo "Building fresh app..."
cd "$SCRIPT_DIR"
./build-app.sh

echo "Stopping old $APP_NAME (menu-bar app only)..."
# Try graceful quit first; fallback to killall if frozen
osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
sleep 0.5
killall "$APP_NAME" 2>/dev/null || true
sleep 0.3

echo "Starting new version..."
open "$APP_BUNDLE"

echo ""
echo "Done."
echo "Note: any dev servers you started through the old app keep running"
echo "because they are separate OS processes. The new app will show them"
echo "as 'Stopped' until you click Start (it will reconnect to the port)."
