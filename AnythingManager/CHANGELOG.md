# Changelog

## Unreleased

### Added
- **External process detection** — On launch the app scans configured ports. If a project is already running from a previous app instance, it shows an orange **"Running (external)"** badge and a **"Take Over"** button that kills the old occupant and starts tracking a fresh Process.
- `restart-app.sh` — One-command script that builds a fresh `.app`, kills the old menu-bar instance, and launches the new one. Existing dev servers keep running because they are independent OS processes.

### Fixed
- `LaunchAtLogin` now derives the `.app` path dynamically via `Bundle.main.bundlePath` instead of hard-coding `/path/to/repo`.

## 2026-04-21

### Added
- **Error banners** — When a project fails to start, a red error message appears directly under the project card instead of being hidden in logs.
- **Delete confirmation** — Deleting a project in Settings now shows an alert asking for confirmation.
- **Screen transitions** — Switching between Projects and Settings views now has a subtle fade animation.
- `Scripts/validate.sh` — Smoke-test script that verifies bundle structure, Info.plist, model round-trip, PortChecker logic, and that the app launches without crashing.

### Changed
- **Architecture overhaul** — Replaced SwiftUI `MenuBarExtra` (which had a bug causing the window to close on every state change) with the industry-standard `NSStatusBar` + `NSPanel` combo.
- **UI redesign** — Start/Stop/Restart buttons are now normal size instead of tiny `.small`. Each project shows a clear **"Running"** (green) or **"Stopped"** (grey) badge.
- **Settings navigation** — Settings is no longer a confusing sheet; it is a full sub-page with a **"Back"** button.
- **Stop behavior** — The UI updates immediately when you click Stop; the force-kill happens in the background after a graceful terminate attempt.
- **Build script** — `build-app.sh` now outputs plain ASCII to avoid terminal encoding issues.

### Fixed
- **Login items** — Replaced the unreliable `SMAppService.mainApp` API with a robust `LaunchAgent` plist written to `~/Library/LaunchAgents/`.
- **Port input** — The port field in Settings now binds to a `String` instead of an optional `Int`, fixing empty/nil input UX issues.
- **Save feedback** — Clicking Save in Settings shows a green **"Saved"** toast for 1.5 seconds.

## 2026-04-21 (Initial)

### Added
- Initial macOS menu-bar app scaffolding using Swift Package Manager.
- `ProcessManager` to spawn and monitor child processes via `zsh -l`.
- `PortChecker` using `lsof` to detect port conflicts and kill occupant PIDs.
- `Project` model (Codable) with default `/path/to/project` + `bun run dev` preset.
- `ContentView` / `SettingsView` SwiftUI layouts.
- `build-app.sh` to compile and package a minimal `.app` bundle into `../Applications/`.
