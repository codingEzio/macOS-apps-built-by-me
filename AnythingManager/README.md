# AnythingManager

[中文 README](README.zh-CN.md)

A macOS menu-bar app that starts, stops, and monitors your local dev servers
(`bun run dev`, `next dev`, `python -m http.server`, etc.) without keeping a
terminal window open.

```
    Menu Bar
       │
       ▼
┌──┬──┬──┬──┬──┬──⚡──┬──┬──┬──┐
│  │  │  │  │  │     │  │  │  │
└──┴──┴──┴──┴──┴─────┴──┴──┴──┘
       │
   click to open
       │
       ▼
┌──────────────────────────────────────┐
│  📡  Anything Manager                │
│  ─────────────────────────────────   │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ ● my-website         [Take Over]│  │
│  │   External            :3000     │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ ● my-api           [Restart][Stop]│ │
│  │   Running             :3001   [📄]│  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ ● static-site          [Start] │  │
│  │   Stopped             :3002     │  │
│  └────────────────────────────────┘  │
│                                      │
│  [Settings]              [Quit]      │
└──────────────────────────────────────┘
```

## What it does, in plain English

**The problem it solves:**

You work on a Next.js site and a Node API. Every morning you open two terminal
windows, `cd` into each project, and run `bun run dev`. Those terminals sit there
taking up space. You accidentally close one. You forget which port is which. You
start a second copy and get "EADDRINUSE". You hunt down the old process with
`lsof` and `kill`. It's annoying.

**What this app does:**

1. You configure your projects once (name, folder path, command, port).
2. The app lives in your menu bar. Click it, hit **Start**, close it.
3. Your server runs in the background. No terminal window needed.
4. The icon turns **green** when servers are running, **gray** when stopped.
5. If a port is occupied — even by a stray terminal session you forgot about —
   the app detects it, kills the old process, and starts yours.

## Features

| Feature | What it means |
|---------|---------------|
| **One-click Start/Stop/Restart** | No terminal needed. |
| **Smart port takeover** | Port occupied? The app kills the old listener and claims it. |
| **External process detection** | Started a server in a terminal yesterday? The app sees it, shows "External", and lets you **Take Over**. |
| **Survives app restarts** | Rebuild and relaunch via `./restart-app.sh`. Your servers keep running. The new app instance detects them automatically. |
| **Per-project logs** | View the last 10K chars of output. Clear them anytime. |
| **Config hot-reload** | Edit `config.json` in any editor. Changes appear in the app within 1 second. |
| **Launch at login** | Optional. The app starts when you log in. |
| **Click outside to dismiss** | Click the desktop or another app — the panel closes, just like native macOS menu-bar apps. |

## How to use it

### First time

```bash
cd AnythingManager
./build-app.sh
open ../Applications/AnythingManager.app
```

### While developing (rebuild + relaunch)

```bash
cd AnythingManager
./restart-app.sh
```

Your dev servers keep running because they are independent OS processes.
The new app detects them and shows **"Take Over"** so you can reclaim control.

### Configure your projects

Open the app → click **Settings** → add your projects:

| Field | Example |
|-------|---------|
| Name | `my-website` |
| Path | `~/projects/my-website` |
| Command | `bun run dev` |
| Port | `3000` |

Or edit `config.json` directly. A `config.sample.json` is provided as a template.

## Project Structure

| File | Purpose |
|------|---------|
| `Sources/AppDelegate.swift` | Menu-bar icon, panel setup, click-outside-dismiss |
| `Sources/ContentView.swift` | Main UI — project cards, port banner, log viewer |
| `Sources/SettingsView.swift` | Settings — edit projects, launch-at-login toggle |
| `Sources/ProcessManager.swift` | Spawns/kills processes, port health-checks, config hot-reload |
| `Sources/PortChecker.swift` | `lsof`-based port detection with safety whitelist |
| `Sources/Project.swift` | Codable project model |

## Security Notes

- **Only dev-server processes are killed.** `killPort()` checks the process name
  against a whitelist (`node`, `next`, `bun`, `npm`, `python`, `vite`, etc.).
  It will never kill Chrome, system services, or unknown processes.
- **Parent processes are only killed if they're also dev servers.** Your shell
  and Terminal are never touched.
- **No shell injection.** The working directory is set via `Process.currentDirectoryURL`,
  not by embedding paths in shell command strings.

## Requirements

- macOS 13+
- Swift 5.9+ (Xcode or Command Line Tools)

## Troubleshooting

**"The app doesn't appear in the menu bar"**
→ Make sure you opened the `.app` bundle, not the raw binary from `.build/debug/`.

**"Start shows an error"**
→ Check that the **Path** exists and the **Command** works when run manually:
  `zsh -l -c "cd <path> && <command>"`

**"It says Running but localhost doesn't respond"**
→ Make sure the **Port** in Settings matches the port your dev server actually binds to.

## License

Do whatever you want. It's a tool for my own workflow, shared in case it's useful.
