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

### Code style: centralize shared logic, avoid copy-paste.

When the same logic appears in two or more places, extract it into a single
**global** helper and call it from each site. This keeps bug fixes centralized:
a change made in one place applies everywhere, instead of being missed in a
forgotten copy.

- Prefer shared helpers for repeated patterns: facing/direction math, hostile
  entity scanning, cone (90° frontal) checks, etc.
- Place cross-file helpers in the earliest-loaded file that fits the domain
  (e.g. `common.lua` for combat/shared, `movement.lua` for movement/turning).
- Remember the File split notes rule: cross-file helpers MUST be global (no
  `local`), since load order is common → movement → ... → commands.

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
| Laser | 10 | 10 blocks, 90° cone | 4s | Instant beam, particles |
| Shot | 40 | 30 blocks, 90° cone | 6s | Snowball projectile (gravity=-22, speed=25, y-comp=+9) |
| bug_check | — | 5 blocks | — | skip=1 if hostile found |
| damaged_check | — | — | — | skip=1 if attacked in last 3s |
| turn_danger | — | 30 blocks (sphere, ×N multiplier, stacked up to ×49) | — | turn to attacker/LoS target; only visible threats (air/passable in between); no turn if no target |

- Zombie HP = 20. Laser = 2-shot kill, Shot = 1-shot kill.
- `is_hostile_entity(ent)`: checks `ent.type == "monster"` OR `ent.hostile` OR `ent._is_hostile` OR `ent._attack` OR `ent.passive == false`, then falls back to definition check.
- **Do NOT** include `ent.type == "animal"` — animals are passive.

### File split notes

- All cross-file functions must be global (no `local`): `facebot`, `facedirs`, `move_bot`, `bot_parsecommand`, etc.
- Cross-file tables/variables also need global: `facedirs`, `vbots2.bot_info`, etc.
- Load order in init.lua: common→movement→dig_build→pathfinding→commands→timer→nodes→register_commands.
- `luac -p` only catches syntax errors — test in-game for runtime errors.

### Save/load selection must use one shared list

- `vbots2.load` (init.lua) builds the save textlist, and `formspec_handler.lua` resolves
  the clicked row index back to a storage key. Both MUST use the SAME list.
- Use `vbots2.get_savelist(player)` (owner-filtered + name-sorted) for BOTH the display
  string and the `index -> full_storage_key` lookup. Never rebuild an unfiltered
  `mod_storage` list in the handler — its order differs and it includes other players'
  saves, so the clicked index resolves to the wrong (often another player's) save.

### Inventory storage: detached inventory + mod_storage mirror

Bot **programs** (lists `p0`..`p6`, 7×56 slots) MUST live in a **detached inventory**
`botprog_<bot_key>` mirrored to `mod_storage["botprog_<bot_key>"]`. The node meta holds
only small fields + the `key` string — the bot's "pointer" to its data. `main` (32 slots)
stays in the node meta inventory because it changes on every step.

**Why:** `position_bot` moves the node via `set_node` + `meta:to_table()/from_table()`,
which copies the ENTIRE node metadata — copying 425 inventory slots on every step is
wasteful. With programs detached, a move copies only ~15 small fields + `main` (32 slots):
~10× cheaper. Additionally, mapblock saves shrink (node meta ~1KB vs tens of KB).

**Rules:**
- NEVER store program lists in node meta (`list[nodemeta:...;pN...]` is forbidden). Use
  detached: `list[detached:botprog_<key>;pN...]`.
- Detached inventories DIE on server restart → always (re)create from the `mod_storage`
  mirror before use. Use the shared helpers in `init.lua` (`ensure_prog_inv` /
  `prog_inv` / `save_prog_inv`) — they restore-from-storage idempotently.
- `main`/`trash` handling stays as-is: `main` in node meta, `trash` in
  `detached:bottrash`.
- One-time lazy migration of old bots happens in `bot_restore` (reads node p-lists →
  `mod_storage` → clears node p-lists). Saves (`inv_list` format) need NO conversion.
- Every new site that reads/writes program slots MUST go through `prog_inv`, never
  `minetest.get_inventory({type="node", pos=...})` for `p*` lists.

### Luanti 5.14.0 — bundled tools

- `luac\luac54.exe` — Lua compiler syntax check.
- Use `.\luac\luac54.exe -p <file>` before every commit.

## VoxeLibre MTG-compat reference (local install)

Context: a Luanti 5.14.0 install lives at `L:\games\luanti-5.14.0-win64\` running the
**VoxeLibre** game (a MineClone2 fork; uses `mcl_*` namespaces, NOT Minetest Game). MTG
mods (multidecor, etc.) hard-depend on MTG mods (`default`, `wool`, `dye`, `xpanes`,
`beds`, `flowers`, `bucket`) which do not exist there. A compat shim mod
`mods/mtg_compat_vl/` bridges them: `provides = default wool dye xpanes beds flowers bucket`
+ registers node aliases (`default:*`→`mcl_core:*`, `dye:`→`mcl_dye:`, `wool:`→`mcl_wool:`,
flower names→`mcl_flowers:`, `dye:cyan`→`mcl_dye:blue`) and API globals/bridges.

### How to make an MTG mod load against the shim
- `provides` on the shim is NOT enough when an MTG mod hard-`depends` on virtual MTG names.
  Force correct load order by editing the MTG mod's `mod.conf` so its `depends` names the
  REAL shim mod, not the virtual MTG names:
  - `decor_api`:          `depends = mtg_compat_vl`
  - `craft_ingredients`:  `depends = decor_api, mtg_compat_vl`
  - `modern`:             `depends = mtg_compat_vl, decor_api, craft_ingredients, stairs`
  (Keep `stairs` as the real mod — it ships its own `optional_depends = default`.)
- This install's `world.mt` uses the modern `load_mod_<name> = true` form. The decisive fix
  was the `depends`→`mtg_compat_vl` edit above; do not rely on legacy `load_mod_X = mods/path`
  (that format DISABLES unlisted mods). If the shim's "bridges registered" log line is absent
  from `debug.txt`, the shim did not load — check enablement + the `depends` edits.

### Bridges the shim provides (verified at runtime via runserver.bat, see below)
- **Node aliases**: `default:*`→`mcl_core:*` (steel_ingot→iron_ingot, copper_ingot→mcl_copper:copper_ingot, desert_stone→stone, tin_ingot→moreores:tin_ingot), `dye:`→`mcl_dye:`, `wool:`→`mcl_wool:`, 8 multidecor flower names→`mcl_flowers:*`, `dye:cyan`→`mcl_dye:blue`.
- **`beds` global** → `mcl_beds` (`bed_position`, `on_rightclick`→`mcl_beds.on_rightclick`, `remove_spawns_at`→`mcl_beds.remove_bed`, `can_dig`→true). `beds:bed_bottom` alias skipped — `mcl_beds` already defines it.
- **`dye` global stub** (`get_name`, `is_empty`, `take_item`) + `xpanes:pane_flat` alias to a `mtg_compat_vl:` stub node.
- **`bucket` global** + `bucket.register_liquid` adapter → `mcl_buckets.register_liquid` (MTG positional args → MCL table form, pcall + fallback alias to `mcl_buckets:bucket_empty`). `mcl_buckets` already aliases `bucket:bucket_empty/water/lava`, but does NOT `provide` the `bucket` mod name.
- **`player_api` global** → `mcl_player`. MTG `get_animation` returns nested `{model={model=name}}`; MCL returns flat `{model=name}`. Bridge returns nested form and tracks per-player model so sit/standup restore works. `registered_models` stored locally + `pcall(mcl_player.player_register_model)`.
- **`default` Lua global** (sound helpers only): `node_sound_stone_defaults/wood_defaults/glass_defaults/metal_defaults` → `mcl_sounds` (pcall-safe, fallback `{}`). Separate namespace from `default:` node aliases.
- **Fractional dig-group rounding**: VoxeLibre's `_mcl_autogroup` (`on_mods_loaded`, loads last) assumes integer dig-group indices (`pickaxey` has levels 1..5; `cracky=1.5`→`pickaxey=1.5` crashes `gdef.levels[1.5]`). The shim runs its own `register_on_mods_loaded` FIRST and rounds every fractional dig-group value (cracky/choppy/snappy/crumbly/oddly_breakable_by_hand/pickaxey/axey/shearsy/shovely/handy/...) to the nearest integer via `minetest.override_item`. This generically fixes MTG mods that use fractional values.

### Lessons learned (how the *working* MTG mods in this install survive VoxeLibre)
- Mods like `stairs`, `drawers`, `unified_inventory`, `moreblocks` use
  `optional_depends = default` + conditional registration, so they need NO shim.
- Only mods with **hard** `depends` on MTG mods require the shim + the `depends`→`mtg_compat_vl` edit above (multidecor: `decor_api`→default, `craft_ingredients`→decor_api+bucket, `modern`→beds+decor_api+craft_ingredients+flowers+stairs).

### Gotchas
- **`register_node` under a foreign mod prefix is forbidden** (`Name xpanes:pane_flat does not follow naming conventions`). Register the stub under `mtg_compat_vl:` and `register_alias('xpanes:pane_flat', 'mtg_compat_vl:...')` instead.
- `mcl_dye` has no `cyan` → aliased to `mcl_dye:blue`. VoxeLibre has no panes mod → `xpanes:pane_flat` is a stub node.
- No `provides` conflicts: only `mtg_compat_vl` provides the MTG mod names.
- `xcompat` does post-load node sound/material compat (wraps `register_node`), NOT a
  node-alias bridge — do not rely on it for `default` etc.
- `luac54 -p` only checks syntax; **runtime MUST be verified by running the server** (see
  below). Best-effort layer, not a full MTG reimplementation.

### Verifying changes without a GUI
- Run the headless server: `bin\luanti.exe --server --world worlds/2` (== `runserver.bat`).
  It runs until killed if mods load; on a mod/runtime error it exits fast and writes
  `ServerError`/`ModError` to `L:\games\luanti-5.14.0-win64\debug.txt` (NOT stdout — stdout
  is a 0-byte log). Tail `debug.txt` for the first error and fix from there. Keep the run
  short or stop it cleanly (don't rely on manual kill for timing-sensitive checks).
- The shim logs `MTG->VoxeLibre bridges registered` once — if that line is absent, the shim
  did not load (check its enablement + the `depends` edits above).

### Remaining non-fatal warnings (expected, harmless)
- `wallpaper_sbox` undeclared at `multidecor/modern/covering.lua:50` (multidecor expects a
  mod absent in VoxeLibre — warning only, server runs).
- `Multidecor has missing recipes` for zinc/silver items (no zinc ore in VoxeLibre).