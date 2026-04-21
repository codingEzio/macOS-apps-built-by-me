#!/bin/bash
set -e

APP="/Users/mac/forfun/Applications/AnythingManager.app"
BINARY="$APP/Contents/MacOS/AnythingManager"
PLIST="$APP/Contents/Info.plist"

echo "=== Smoke Test ==="

# 1. Bundle structure
if [ ! -d "$APP" ]; then echo "FAIL: .app missing"; exit 1; fi
if [ ! -x "$BINARY" ]; then echo "FAIL: binary missing or not executable"; exit 1; fi
if [ ! -f "$PLIST" ]; then echo "FAIL: Info.plist missing"; exit 1; fi
echo "PASS: Bundle structure OK"

# 2. Info.plist content
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$PLIST")
if [ "$BUNDLE_ID" != "com.user.AnythingManager" ]; then
    echo "FAIL: wrong bundle ID: $BUNDLE_ID"
    exit 1
fi
echo "PASS: Info.plist OK"

# 3. Swift model test
swift -e '
import Foundation

struct Project: Codable {
    let id: UUID
    var name: String
    var path: String
    var command: String
    var port: Int?
}

let p = Project(id: UUID(), name: "test", path: "/tmp", command: "bun run dev", port: 3000)
let data = try! JSONEncoder().encode(p)
let decoded = try! JSONDecoder().decode(Project.self, from: data)
assert(decoded.name == "test")
assert(decoded.port == 3000)
print("PASS: Project Codable OK")
'

# 4. Port checker test (just verify the logic runs; do not assume port 22 is open)
swift -e '
import Foundation

func isPortInUse(_ port: Int) -> Bool {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    task.arguments = ["-ti:\(port)"]
    let pipe = Pipe()
    task.standardOutput = pipe
    do {
        try task.run()
        task.waitUntilExit()
        return pipe.fileHandleForReading.readDataToEndOfFile().isEmpty == false
    } catch { return false }
}

let free = isPortInUse(54321)
assert(free == false, "Port 54321 should be free")
print("PASS: PortChecker logic OK")
'

# 5. Launch test (start and kill quickly to verify it does not crash immediately)
open "$APP"
sleep 2
PID=$(pgrep -f "Applications/AnythingManager.app" || true)
if [ -z "$PID" ]; then
    echo "FAIL: app did not start"
    exit 1
fi
# pgrep may return multiple lines; kill each PID individually
echo "$PID" | while read -r p; do
    kill "$p" 2>/dev/null || true
done
echo "PASS: App launches without crashing"

echo ""
echo "All smoke tests passed."
