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

## Nuances & Debugging

### Lua truthiness traps

- `""` (empty string) is **truthy** in Lua. `not ""` = `false`.
- `0` is **truthy** in Lua. `not 0` = `false`.
- Only `nil` and `false` are falsy.
- **Never** use `not obj:get_player_name()` to check "is not a player" — use `obj:get_player_name() == ""` instead.

### Bot facedir direction

- `minetest.facedir_to_dir(param2)` returns a vector that points OPPOSITE to the bot's actual front.
- `get_front_node(pos)` calculates `pos - dir` (where dir = facedir_to_dir).
- **Cone checks**: use `-(facing_dir·to_target)` not `facing_dir·to_target`.
- For param2=0: facing_dir={0,0,1} (+Z), but bot's visual front is at -Z.

### VoxeLibre/MCL mob targeting

- Mobs use `specific_attack` table on entity **definition** (not instance) to choose attack targets.
- `vbots2:bot_body` is registered as vanilla entity (`minetest.register_entity`), not via Mobs Redo API.
- Must add `"vbots2:bot_body"` to every mob's `def.specific_attack` table.
- Use `minetest.after(1, ...)` delay — mobs may be registered after vbots2.
- **Do NOT** guard with `minetest.get_modpath("vl_mobs")` — VoxeLibre uses `mcl_mobs` internally.

### Combat system

| Command | Damage (fleshy) | Range | Cooldown | Effect |
|---------|----------------|-------|----------|--------|
| Laser | 20 | 5 blocks, 90° cone | 2s | Instant beam, particles |
| Shot | 40 | 20 blocks, 90° cone | 8s | Snowball projectile (gravity=-22, speed=25, y-comp=+9) |
| bug_check | — | 5 blocks | — | skip=1 if hostile found |
| damaged_check | — | — | — | skip=1 if attacked in last 3s |
| turn_danger | — | 20 blocks | — | turn toward attacker or nearest hostile |

- Zombie HP = 20. Laser = 2-shot kill, Shot = 1-shot kill.
- `is_hostile_entity(ent)`: checks `ent.type == "monster"` OR `ent.hostile` OR `ent._is_hostile` OR `ent._attack` OR `ent.passive == false`, then falls back to definition check.
- **Do NOT** include `ent.type == "animal"` — animals are passive.

### File split notes

- All cross-file functions must be global (no `local`): `facebot`, `facedirs`, `move_bot`, `bot_parsecommand`, etc.
- Cross-file tables/variables also need global: `facedirs`, `vbots2.bot_info`, etc.
- Load order in init.lua: common→movement→dig_build→pathfinding→commands→timer→nodes→register_commands.
- `luac -p` only catches syntax errors — test in-game for runtime errors.

### Luanti 5.14.0 — bundled tools

- `luac\luac54.exe` — Lua compiler syntax check.
- Use `.\luac\luac54.exe -p <file>` before every commit.