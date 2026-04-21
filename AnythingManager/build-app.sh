#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/Applications"
APP_NAME="AnythingManager.app"
BUILD_DIR="$REPO_ROOT/AnythingManager/.build/release"

echo "Building AnythingManager..."
cd "$REPO_ROOT/AnythingManager"
swift build -c release

echo "Packaging $APP_NAME..."
rm -rf "$OUTPUT_DIR/$APP_NAME"
mkdir -p "$OUTPUT_DIR/$APP_NAME/Contents/MacOS"

cp "$BUILD_DIR/AnythingManager" "$OUTPUT_DIR/$APP_NAME/Contents/MacOS/"

cat > "$OUTPUT_DIR/$APP_NAME/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.user.AnythingManager</string>
    <key>CFBundleName</key>
    <string>AnythingManager</string>
    <key>CFBundleDisplayName</key>
    <string>Anything Manager</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Done: $OUTPUT_DIR/$APP_NAME"
echo ""
echo "Next steps:"
echo "  1. Double-click $OUTPUT_DIR/$APP_NAME to run"
echo "  2. Check 'Launch at login' in Settings"
echo "  3. Future apps will also live in $OUTPUT_DIR"
