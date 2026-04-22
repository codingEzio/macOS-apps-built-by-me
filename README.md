# macOS Menu-Bar Lab

[中文 README](README.zh-CN.md)

Small macOS menu-bar apps. One job each. No dock icon. No bloat.

```
  [⚡]  →  ┌─────────────────────┐
           │  📡 Anything Manager│
           │  🟢 api    :3001 [■]│
           │  ⚪ web    :3000 [▶]│
           │  [Settings]  [Quit] │
           └─────────────────────┘
```

### AnythingManager

**The problem:** You open a terminal, run `bun run dev`, and now you can't close that window because it holds your server. You forget it's there. You open another terminal. Now two servers fight for the same port.

**The fix:** Click the bolt icon in your menu bar → see your projects → hit **Start**. The server runs in the background. Close the panel. Forget about it.

- Start / Stop / Restart any project with one click
- Takes over stray servers — port occupied? It kills the old process and starts yours
- Detects external processes — started a server in a terminal earlier? Shows "External", lets you reclaim it
- Survives app restarts — rebuild and relaunch; your servers keep running
- Shows logs — view the last 10K of output without opening a terminal

```bash
cd AnythingManager
./restart-app.sh
```

## What's coming

More single-purpose menu-bar tools. Each app gets its own folder with a `config.sample.json` and a `restart-app.sh`.

```
.
├── AnythingManager/
│   ├── config.sample.json
│   ├── build-app.sh
│   └── restart-app.sh
├── NextApp/          (clipboard manager?)
└── AnotherApp/       (quick notes?)
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
