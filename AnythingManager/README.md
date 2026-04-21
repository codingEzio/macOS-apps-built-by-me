# AnythingManager

A dead-simple macOS menu-bar app to start, stop, and monitor local dev projects (like `bun run dev`) without keeping a terminal window open.

## What it does

- Lives in your menu bar — click the icon to see your projects.
- **Start / Stop / Restart** any project with one click.
- Shows a **Running / Stopped** badge so you always know the state.
- **Port conflict detection** — if another process is using the project's port, you can force-start to kill the occupant and take over.
- **Survives app restarts** — if you rebuild and relaunch the menu-bar app, it detects projects that are still running from the previous instance and offers a **"Take Over"** button to reclaim them without dropping traffic.
- **Launch at login** — enable in Settings and the app starts automatically.
- **Per-project logs** — view the last 10K characters of output in a built-in log window.

## Requirements

- macOS 13+
- Swift 5.9+ (included with Xcode or Command Line Tools)

## Build & Run

### First time
```bash
cd AnythingManager
./build-app.sh
open ../Applications/AnythingManager.app
```

### Rebuild while developing
```bash
cd AnythingManager
./restart-app.sh
```

`restart-app.sh` builds a fresh `.app`, kills the old menu-bar instance, and launches the new one. Any dev servers you started through the old app **keep running** because they are independent OS processes; the new app detects them and shows a **"Take Over"** button so you can reclaim control instantly.

The `.app` is placed in `../Applications/` so all your menu-bar apps live in one predictable place.

## Project Structure

| File | Purpose |
|------|---------|
| `Sources/AnythingManager/AppDelegate.swift` | `NSStatusBar` + `NSPanel` setup |
| `Sources/AnythingManager/ContentView.swift` | Main UI — project cards, start/stop |
| `Sources/AnythingManager/SettingsView.swift` | Settings — edit projects, toggle login item |
| `Sources/AnythingManager/ProcessManager.swift` | Spawns and kills child processes |
| `Sources/AnythingManager/PortChecker.swift` | Uses `lsof` to check/kill ports |
| `Sources/AnythingManager/Project.swift` | Codable project model |
| `Scripts/validate.sh` | Smoke tests — bundle sanity, model round-trip, launch check |
| `Tests/AnythingManagerTests/` | XCTest unit tests |

## Troubleshooting

**App doesn't appear in the menu bar**
- Make sure you opened the `.app`, not the raw binary.
- Check Activity Monitor for a process named `AnythingManager`.

**"Launch at login" doesn't work**
- The app must be a bundled `.app` (not run via `swift run`) so macOS knows its bundle path.
- The toggle writes a plist to `~/Library/LaunchAgents/com.user.AnythingManager.plist`.

**Start button shows an error**
- Verify the **Path** exists on disk.
- Verify the **Command** works when you run it manually in a shell (`zsh -l -c "cd <path> && <command>"`).

**"Take Over" is shown but I didn't restart the app**
- Another app or terminal window is using that port. Click **Take Over** (or **Force Start**) to replace it.

## Notes

- Processes run via `zsh -l` so your `.zshrc` (and therefore `bun`, `node`, etc.) is loaded.
- Build artifacts (`.build/`) and generated apps (`../Applications/`) are git-ignored.
