#!/bin/bash
set -e

# 这个脚本会把 AnythingManager 打包成 .app，放到项目根目录的 Applications/ 文件夹里
# 这样你以后所有的 app 都输出到同一个地方，方便管理和设置开机启动

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/Applications"
APP_NAME="AnythingManager.app"
BUILD_DIR="$REPO_ROOT/AnythingManager/.build/release"

echo "🛠️  正在编译 AnythingManager..."
cd "$REPO_ROOT/AnythingManager"
swift build -c release

echo "📦 正在打包 $APP_NAME..."
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

echo "✅ 搞定！输出位置: $OUTPUT_DIR/$APP_NAME"
echo ""
echo "接下来你可以："
echo "  1. 直接双击打开 $OUTPUT_DIR/$APP_NAME"
echo "  2. 在 App 的设置里勾选『开机自动启动』"
echo "  3. 以后所有 App 都会统一放在 $OUTPUT_DIR，想删想改都来这儿"
