# Changelog

## v0.5.0 — Lockdown

### Security
- **Process-kill whitelist** — `killPort()` now verifies the listener's process name against a whitelist of known dev-server names (`node`, `next`, `bun`, `npm`, `python`, `vite`, etc.) before sending `SIGKILL`. Unknown processes are logged and skipped.
- **Parent-kill guard** — The parent PID is only killed if the parent's name also matches the dev-server whitelist. Previously the parent was killed unconditionally, which could destroy the user's interactive shell or Terminal.
- **Chrome no longer murdered** — `pidsUsingPort()` now uses `lsof -ti :PORT -sTCP:LISTEN` so it returns only the actual listener, not every process with an open client connection (e.g. a browser tab pointing at `localhost:3000`).
- **Shell injection fixed** — `start()` now sets the working directory via `Process.currentDirectoryURL` instead of embedding the path in a shell command string (`cd <path> && ...`). A malicious `project.path` can no longer inject arbitrary commands.

### Added
- **Click outside to dismiss** — Clicking anywhere outside the panel (desktop, another app, another menu-bar item) automatically closes it, matching native macOS menu-bar app behavior.
- **Port occupancy cache** — Port scan results are cached in `ProcessManager` and refreshed every 3s. Views read from the cache instead of spawning `lsof`/`ps` during SwiftUI body evaluation, eliminating AttributeGraph cycles and UI freezes.
- **`isStarting` state** — Projects show a "Starting" spinner while the dev server boots, preventing accidental double-clicks.

### Fixed
- **Invisible panel** — Switched from `.borderless` to `.titled` + `.fullSizeContentView` with a transparent title bar. Borderless windows cannot become key, so `makeKeyAndOrderFront` failed and the panel was invisible/unclickable.
- **Dead Settings button** — Removed `withAnimation` wrappers around `screen` state changes inside the `NSPanel`. These deadlocked SwiftUI's render server in a non-activating panel.
- **Invisible idle icon** — Changed idle color from `.secondaryLabelColor` (invisible on dark menu bars) to `.labelColor`.
- **Duplicate headers** — Settings no longer renders nested under a redundant "Anything Manager" header; it replaces the entire content area.
- **Blank title-bar space** — Removed wasted padding above the header by using `.fullSizeContentView` instead of a visible title bar.
- **Data-loss on file select** — `setConfigURL()` no longer overwrites an existing user-selected file with placeholder JSON when the file isn't valid project config.
- **Process memory leak** — `terminationHandler` now removes exited processes from the `processes` dictionary and nils out the `readabilityHandler`, preventing leaked `Process` + `Pipe` objects.
- **Log dictionary leak** — System messages now use a fixed UUID instead of `UUID()` random keys, stopping unbounded growth of the `logs` dictionary.
- **Main-thread blocking** — `scanExternalProcesses()` now runs `lsof`/`ps` on `DispatchQueue.global(.utility)` and updates `@Published` state back on the main queue. No more UI stutter every 3 seconds.

---

## v0.4.0 — Immortal Process

### Fixed
- **Removed destructive health-check** — The previous auto-kill logic murdered dev servers that needed more than 5s to compile (e.g. `bun run dev`). Now the app **never kills a running process** during startup. It shows a "Starting" spinner, waits patiently, and logs status without violence.
- **Reliable port detection** — Switched `lsof` to `lsof -P -i :PORT -sTCP:LISTEN` so it correctly detects listeners on both IPv4 and IPv6, avoiding false negatives that triggered the auto-kill.

### Changed
- **Startup UX** — Clicking Start now shows an animated **"Starting"** state with a spinner. The button is disabled during startup so you can't accidentally double-click.
- **Log window auto-scroll** — The log view now automatically scrolls to the bottom as new output arrives, so you always see the latest lines.
- **Card design** — Added subtle shadow and increased corner radius for a more modern, elevated look.
- **Status badges** — Replaced plain text badges with icon+label combos (checkmark for Running, globe for External, etc.).
- **Empty state** — When no projects exist, a friendly icon and centered message replaces the blank void.

---

## v0.3.0 — Ghost Protocol

### Added
- **Smart port takeover** — Clicking **Start** on a project whose port is occupied automatically kills the old occupant and waits up to 3 seconds for the port to be fully freed before launching a fresh tracked process.
- **External process detection** — On launch the app scans configured ports. If a project is already running from a previous app instance (or a stray terminal session), it shows an orange **"Running (external)"** badge and a **"Take Over"** button.
- **Launch health-check** — After starting a project, the app checks the configured port at 2s and 5s. If the port never comes up (e.g. bun silently fails with EADDRINUSE), the process is automatically stopped and a clear error is shown. No more false "Running" states.
- **Menu-bar icon state** — The bolt icon glows **green** while projects are running and turns **gray** when everything is stopped, so you can tell the state at a glance without opening the panel. Uses `labelColor` so it remains visible in both dark and light menu bars.
- **Onboarding hints** — Stopped projects with no logs show a gentle "Click Start to run …" caption so first-time users know what to do.
- `restart-app.sh` — One-command rebuild-and-relaunch. Builds a fresh `.app`, kills the old menu-bar instance, and opens the new one. Dev servers keep running because they are independent OS processes.

### Fixed
- `LaunchAtLogin` now derives the `.app` path dynamically via `Bundle.main.bundlePath` instead of hard-coding `/path/to/repo`.
- Default project port changed from `nil` to `3000` so port scanning and takeover work out of the box for typical dev servers.

---

## v0.2.0 — Solid Ground

### Added
- **Error banners** — When a project fails to start, a red error message appears directly under the project card instead of being hidden in logs.
- **Delete confirmation** — Deleting a project in Settings now shows an alert asking for confirmation.
- **Screen transitions** — Switching between Projects and Settings views now has a subtle fade animation.
- `Scripts/validate.sh` — Smoke-test script that verifies bundle structure, Info.plist, model round-trip, PortChecker logic, and that the app launches without crashing.

### Changed
- **Architecture overhaul** — Replaced SwiftUI `MenuBarExtra` (which had a critical bug causing the window to close on every state change) with the industry-standard `NSStatusBar` + `NSPanel` combo.
- **UI redesign** — Start/Stop/Restart buttons are now normal size instead of tiny `.small`. Each project shows a clear **"Running"** (green) or **"Stopped"** (grey) badge.
- **Settings navigation** — Settings is no longer a confusing sheet; it is a full sub-page with a **"Back"** button.
- **Stop behavior** — The UI updates immediately when you click Stop; the force-kill happens in the background after a graceful terminate attempt.
- **Build script** — `build-app.sh` now outputs plain ASCII to avoid terminal encoding issues.

### Fixed
- **Login items** — Replaced the unreliable `SMAppService.mainApp` API with a robust `LaunchAgent` plist written to `~/Library/LaunchAgents/`.
- **Port input** — The port field in Settings now binds to a `String` instead of an optional `Int`, fixing empty/nil input UX issues.
- **Save feedback** — Clicking Save in Settings shows a green **"Saved"** toast for 1.5 seconds.

---

## v0.1.0 — Genesis

### Added
- Initial macOS menu-bar app scaffolding using Swift Package Manager.
- `ProcessManager` to spawn and monitor child processes via `zsh -l`.
- `PortChecker` using `lsof` to detect port conflicts and kill occupant PIDs.
- `Project` model (Codable) with default `/path/to/project` + `bun run dev` preset.
- `ContentView` / `SettingsView` SwiftUI layouts.
- `build-app.sh` to compile and package a minimal `.app` bundle into `../Applications/`.
