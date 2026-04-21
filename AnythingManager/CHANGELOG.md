# Changelog

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
