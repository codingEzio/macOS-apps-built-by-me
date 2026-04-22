# Development Spec (Sample)

## Language
- All source code, comments, commit messages, and documentation in English only.

## Configuration-First Principle
- No hardcoded paths, ports, or commands in source code.
- All per-machine settings live in `config.json`.

## Config File Convention
- `config.json` — local-only, ignored by git.
- `config.sample.json` — tracked, contains placeholder values for reference.

## Multi-App Repo Structure
Each app lives in its own top-level directory:
```
repo-root/
├── AppOne/
│   ├── config.json
│   ├── config.sample.json
│   ├── build-app.sh
│   └── restart-app.sh
├── AppTwo/
│   ├── config.json
│   ├── config.sample.json
│   ├── build-app.sh
│   └── restart-app.sh
```

## New App Checklist
1. Dedicated directory under repo root.
2. `config.sample.json` with placeholder values.
3. `build-app.sh` and `restart-app.sh` scripts.
4. Config resolution relative to binary or via user selection.
5. Zero hardcoded personal values in source.

## Task Tracking vs Release Notes

### TODO.md (local-only, ignored)
- Tracks development tasks, subtasks, and progress before a feature ships.
- Audience: you and your local AI agents.
- Must never contain paths, ports, passwords, or personal identifiers.

### CHANGELOG.md (tracked, public)
- Summarizes shipped features and fixes for external readers.
- Must be fully de-sensitized: no personal paths, no machine-specific values.
- Updated only when a feature or fix is fully done and tested.

## Multi-Language Documentation

### README Structure
- Every app directory and the repo root must have an English `README.md` as the canonical source.
- A Chinese translation `README.zh-CN.md` must be kept in sync with the English version.
- When the English README is updated (features, structure, ASCII art, build instructions), the Chinese README must be updated to match.

### Sync Rules
- **Translate** explanations, descriptions, and plain-English sections.
- **Keep in English**: code blocks, shell commands, file paths, UI labels (Start/Stop/Restart/etc.), and brand/tool names.
- **Keep in sync**: ASCII art mockups must reflect the same UI layout; if the app UI changes, update art in both languages.
- **Add cross-links**: Each README must link to its translation counterpart at the top.

### ASCII Art Standards
- Use box-drawing characters (`│` `─` `┌` `┐` `└` `┘`) for clean lines.
- Keep width ≤ 80 columns so it renders well on mobile and in terminal.
- Art must reflect the actual UI: status dots, button positions, panel layout.

### Responsibility Split
- TODO holds the **process**; CHANGELOG holds the **outcome**.
- A TODO item must be checked off before its CHANGELOG entry is written.
- If a CHANGELOG entry would expose sensitive info, rephrase it generically or omit it.
