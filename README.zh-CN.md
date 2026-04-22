# macOS 菜单栏工具实验室

[English README](README.md)

小而精的 macOS 菜单栏应用，每个只做一件事。
没有 Dock 图标，没有臃肿功能，需要时才冒出来。

```
  [⚡]  →  ┌─────────────────────┐
           │  📡 Anything Manager│
           │  🟢 api    :3001 [■]│
           │  ⚪ web    :3000 [▶]│
           │  [Settings]  [Quit] │
           └─────────────────────┘
```

### AnythingManager

**烦人的事儿：** 打开终端，跑 `bun run dev`，然后这窗口就不能关了，因为服务器在里面挂着。你忘了它的存在，又开一个终端。现在两个服务器在抢同一个端口，报错 EADDRINUSE。

**搞定方式：** 点菜单栏的闪电图标 → 看到项目列表 → 点 **Start**。服务器后台跑起来。关掉面板，忘了吧。

- 一键 Start / Stop / Restart，不用终端
- 端口被占了？它会干掉旧进程，启动你的
- 之前在终端里启动过服务器？它会显示 "External"，让你一键接管
- 重建应用后仍然能控制 —— `./restart-app.sh` 重新编译重启，你的服务器继续跑
- 看日志 —— 不用开终端就能看最近 1 万字的输出

```bash
cd AnythingManager
./restart-app.sh
```

## 接下来会有什么

更多单一用途的菜单栏工具。每个应用有自己的文件夹，里面有 `config.sample.json` 和 `restart.app.sh`。

```
.
├── AnythingManager/
│   ├── config.sample.json
│   ├── build-app.sh
│   └── restart-app.sh
├── NextApp/          （剪贴板管理器？）
└── AnotherApp/       （快速笔记？）
```

## 自己写一个

每个应用都是 Swift Package Manager 项目，自带编译脚本。

```bash
cd AnythingManager
./build-app.sh        # 编译成 .app
./restart-app.sh      # 重新编译 + 杀掉旧进程 + 启动新的
```

## 环境要求

- macOS 13+
- Swift 5.9+（命令行工具就行）

---

*我自己工作流用的工具。你觉得有用就拿去。*
