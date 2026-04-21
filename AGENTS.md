# Agent Guidelines

## Commit Convention

All commits MUST be written in English and follow the Conventional Commits specification.

### Format

```
<type>(<scope>): <description>
```

### Types

- `feat` — A new feature or capability
- `fix` — A bug fix
- `refactor` — Code change that neither fixes a bug nor adds a feature
- `chore` — Build process, tooling, or auxiliary changes
- `docs` — Documentation only changes
- `style` — Formatting, missing semi-colons, etc; no code change
- `test` — Adding or correcting tests

### Rules

1. **Granular commits** — Each commit should represent a single logical change. Do not bundle unrelated changes into one commit.
2. **English only** — Commit messages, descriptions, and bodies must be in English.
3. **Lowercase type** — Use `feat:` not `Feat:`.
4. **Imperative mood** — "add button" not "added button".
5. **No trailing period** in the subject line.

### Examples

```
feat(ui): add project start/stop buttons to menubar panel
fix(launch): use LaunchAgent plist instead of SMAppService
chore(git): ignore build artifacts and generated apps
refactor(settings): split port field into optional string binding
```

## Project Structure

- Each macOS app lives in its own top-level directory (e.g. `AnythingManager/`).
- Built `.app` bundles are output to `Applications/` at the repository root.
- `Applications/` and any `.build/` directories are ignored by Git.
