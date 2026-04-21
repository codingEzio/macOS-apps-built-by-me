#!/bin/bash
set -e

echo "Building AnythingManager..."
swift build -c release

APP_NAME="AnythingManager.app"
BUILD_DIR=".build/release"

echo "Creating app bundle..."
rm -rf "$APP_NAME"
mkdir -p "$APP_NAME/Contents/MacOS"

cp "$BUILD_DIR/AnythingManager" "$APP_NAME/Contents/MacOS/"

cat > "$APP_NAME/Contents/Info.plist" << 'EOF'
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

echo "Done: $APP_NAME"
echo ""
echo "You can now:"
echo "  1. cp -r $APP_NAME /Applications/"
echo "  2. Open it from Launchpad or Finder"
echo "  3. Enable 'Login Items' in the app settings"
