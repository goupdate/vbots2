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

### Code style: comment every block closer.

Every `end`, `elseif`, `else` must have a trailing comment identifying what it closes or continues. This makes debugging block structure trivial.

```lua
if item == "vbots2:move_forward" then
    move_bot(pos, "f")
elseif item == "vbots2:move_backward" then  -- if item
    move_bot(pos, "b")
elseif item == "vbots2:mode_dig" then       -- if item
    local filter = ...
    for i = 1, #list do                     -- loop over slots
        if not stack:is_empty() then        -- if stack non-empty
            ...
        end                                 -- if stack non-empty
    end                                     -- loop over slots
    if R > 0 then                           -- if repeat
        ...
    end                                     -- if repeat
end                                         -- if item
```

Format:
- `-- if <condition_short>` for if/elseif chains
- `-- loop over <what>` for for-loops
- `-- while <condition>` for while-loops
- `-- function <name>` for function ends

### Code style: never write code that doesn't compile.

Run `.\luac\luac54.exe -p` after every change.

`luac54.exe` is bundled in `luac\` directory. Run with:

```bash
.\luac\luac54.exe -p common.lua && .\luac\luac54.exe -p movement.lua && .\luac\luac54.exe -p dig_build.lua && .\luac\luac54.exe -p pathfinding.lua && .\luac\luac54.exe -p commands.lua && .\luac\luac54.exe -p timer.lua && .\luac\luac54.exe -p nodes.lua && .\luac\luac54.exe -p init.lua
```

- All must pass with exit code 0 (no output = OK)
- Fix any syntax errors before commit — never commit code that doesn't compile
- Only commit after ALL files pass luac

### ALWAYS compress context after completing a task.

- After each logical unit of work (bug fix, feature, README update), run `compress` to collapse the finished section
- Keeps context window lean for the next task
- One compress per logical group of changes