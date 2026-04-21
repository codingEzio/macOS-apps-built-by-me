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
