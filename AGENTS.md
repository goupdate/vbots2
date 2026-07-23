# AGENTS.md — vbots2

## Rules

### ALWAYS update README.md and README.ru.md after any feature, command, or behavior change.

- New commands → add to command tables in both READMEs
- New behaviors → add to "New Behaviors" / "Новые Возможности" sections
- New examples → add to Examples / Примеры sections
- Keep English and Russian versions in sync

### ALWAYS commit after completing a set of related changes.

```bash
git add -A
git commit -m "Brief description in English"
```

- One commit per logical group of changes
- Message in English, short (≤72 chars), imperative mood (e.g. "add go_player command with A* pathfinding")

### ALWAYS run a linter agent BEFORE committing.

- Launch `task(category="quick", description="Lint check", prompt="Read all changed Lua files, check for: syntax errors, unbalanced if/end blocks, undefined variables, logic bugs. Check READMEs for consistency with code. Report: OK or list of issues.")`
- Fix any blocking issues before commit
- Only commit after linter passes