# macOS Menu-Bar Lab

A collection of small macOS apps that live in your menu bar and do one thing well.
No dock icons. No bloat. Just tools that stay out of your way until you need them.

## What's inside

```
┌─────────────────────────────────────────────┐
│  ⚡  AnythingManager                        │
│                                             │
│  Your dev servers, one click away.          │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ 🔴 my-app        [Start]            │   │
│  │    Stopped  :3000                   │   │
│  └─────────────────────────────────────┘   │
│  ┌─────────────────────────────────────┐   │
│  │ 🟢 my-api        [Restart] [Stop]   │   │
│  │    Running   :3001                  │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  [Settings]                    [Quit]       │
└─────────────────────────────────────────────┘
```

### AnythingManager

**The problem:** You open a terminal, run `bun run dev`, and now you have a terminal
window you can't close because it holds your server. You forget it's there. You open
another terminal. Now you have two servers fighting for the same port.

**The fix:** AnythingManager lives in your menu bar. Click it → see your projects →
hit Start. The server runs in the background. Close the panel. Forget about it.

- **Start / Stop / Restart** any project with one click
- **Takes over stray servers** — if a port is occupied, it kills the old process and
  starts yours
- **Detects external processes** — if you started a server in a terminal earlier, it
  shows "External" and lets you reclaim it
- **Survives app restarts** — rebuild and relaunch; your servers keep running
- **Shows logs** — view the last 10K characters of output without opening a terminal

```bash
cd AnythingManager
./restart-app.sh
```

## What's coming

More single-purpose menu-bar tools. Each app gets its own folder with a
`config.sample.json` and a `restart-app.sh`.

```
.
├── AnythingManager/
│   ├── config.sample.json
│   ├── build-app.sh
│   └── restart-app.sh
├── NextApp/          (maybe a clipboard manager?)
└── AnotherApp/       (maybe a quick notes app?)
```

## Build one yourself

Each app is a Swift Package Manager project. Build script included.

```bash
cd AnythingManager
./build-app.sh        # builds the .app
./restart-app.sh      # rebuild + kill old + launch new
```

## Requirements

- macOS 13+
- Swift 5.9+ (Command Line Tools)

---

*Built for my own workflow. Shared in case it's useful for yours.*
