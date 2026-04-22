# AnythingManager

A dead-simple macOS menu-bar app to start, stop, and monitor local dev projects (like `bun run dev`) without keeping a terminal window open.

## What it does

- Lives in your menu bar — click the icon to see your projects.
- **Start / Stop / Restart** any project with one click.
- **Smart port takeover** — If a project's port is occupied (even by a stray terminal session), clicking **Start** automatically kills the old process, waits for the port to be fully released, and launches a fresh tracked one.
- **No more false "Running" states** — After starting, the app checks the configured port at 1s, 3s, 6s, and 10s. If the port never comes up (e.g. bun silently fails with `EADDRINUSE`), it stops the process and shows a clear error instead of pretending everything is fine.
- **Survives app restarts** — Rebuild and relaunch the menu-bar app via `./restart-app.sh`. Existing dev servers keep running, and the new app detects them with an orange **"External"** badge. Click **Take Over** to reclaim control instantly.
- **Click outside to dismiss** — Click anywhere outside the panel (desktop, another app, another menu-bar item) and it closes automatically, just like native macOS menu-bar apps.
- **Launch at login** — Enable in Settings and the app starts automatically.
- **Per-project logs** — View the last 10K characters of output in a built-in log window.
- **Menu-bar icon state** — The bolt icon glows green while your projects are running, and turns gray when everything is stopped. Works in both dark and light menu bars.

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
| `Sources/AnythingManager/AppDelegate.swift` | `NSStatusBar` + `NSPanel` setup, menu-bar icon state, click-outside dismissal |
| `Sources/AnythingManager/ContentView.swift` | Main UI — project cards, start/stop, port banner |
| `Sources/AnythingManager/SettingsView.swift` | Settings — edit projects, toggle login item |
| `Sources/AnythingManager/ProcessManager.swift` | Spawns and kills child processes, health-checks ports, config hot-reload |
| `Sources/AnythingManager/PortChecker.swift` | Uses `lsof` to check/kill ports safely |
| `Sources/AnythingManager/Project.swift` | Codable project model |
| `Scripts/validate.sh` | Smoke tests — bundle sanity, model round-trip, launch check |
| `Tests/AnythingManagerTests/` | XCTest unit tests |

## Security Notes

- **Port takeover only kills dev-server processes** — `killPort()` verifies the process name against a whitelist (`node`, `next`, `bun`, `npm`, `python`, `vite`, etc.) before sending `SIGKILL`. It will **never** kill browsers, shells, system services, or unknown processes.
- **Shell injection is prevented** — The project working directory is set via `Process.currentDirectoryURL` rather than embedding the path in a shell command string, so malicious path values cannot inject arbitrary commands.

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
- Another app or terminal window is using that port. Click **Take Over** (or just **Start**) to replace it.

**It says "Running" but localhost is not responding**
- The app performs a health-check after starting. If the configured port never comes up, it will automatically stop the process and show a red error. Make sure the **Port** in Settings matches the port your dev server actually binds to.

## Notes

- Processes run via `zsh -l` so your `.zshrc` (and therefore `bun`, `node`, etc.) is loaded.
- Build artifacts (`.build/`) and generated apps (`../Applications/`) are git-ignored.
