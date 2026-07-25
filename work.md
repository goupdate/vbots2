# vbots2 Work Plan & State

**Always update this file with: current state, what works/broken, fix ideas, conclusions.**

## Current State (2026-07-25 ~06:00)

### ✅ Working
- **Laser**: fires at zombies, 90° cone (-facing_dir·target≥0.707), direct HP damage (set_hp, bypasses MCL punch), 2s cooldown, range=10, damage=fleshy=10. Shoots through walls (no LOS check).
- **is_hostile_entity**: checks ent.type=="monster" + VL definition fallback. Works for zombies.
- **is_valid_target**: filters __builtin:item, vbots2:*, mcl_burning:, mcl_wieldview:, player. Works.
- **turn_danger**: uses is_valid_target + is_hostile_entity. Fallback to nearest hostile in 20 blocks.

### ❌ Broken
- **Shot** (snowball): handler reaches SHOT SCAN + finds candidates (zombie dist=4 fdot=0.81) but NEVER fires. No projectile spawns. Possible causes: cooldown check at line 439 area, or player==nil, or firing code not reached.
- **Zombie attacking bot**: not verified. specific_attack hook runs unconditionally with 1s delay but may not work for VL mobs (they use custom AI, not Mobs Redo).

### 🟡 Unknown
- **Spectator/creative**: does creative mode prevent mob AI?

## File Map

### commands.lua — Main handler (bot_parsecommand)
- Line 344: Laser handler. Scan (radius=10) → filter (is_valid_target+is_hostile_entity+cone) → damage (set_hp).
- Line 438: Shot handler. Scan → filter → spawn projectile.
- Line 476: turn_danger. Damage check → turn or nearest hostile scan.
- Line 339-342: goto_pos LOS fallback loops.

### common.lua — Shared utilities
- Line 45: is_valid_target — filters entities for laser/shot/turn_danger.
- Line 119: is_walkable — node walkability (includes grass/plants/doors).
- Line 135: is_hostile_entity — runtime type check + definition fallback.

### nodes.lua — Entities + bot node
- Line 172: bot_body entity — type="animal", hp_max=20.
- Line 223: specific_attack hook — adds bot_body to all VL entity attack tables.
- Line 241: projectile_snowball entity — gravity, collision, 5s timeout.

### init.lua — Bot lifecycle
- Line 88: bot_init — creates bot, sets all meta fields.
- Line 248: bot_togglestate — restart resets nav/goto/home vars.

### timer.lua — Tick loop
- Line 29: bot_handletimer — pickup, sync entities, hasarg, command dispatch.
- Line 78: hasarg — no_repeat list for conditional/variable/func commands.

## Current Task: Fix shot firing

### Investigation
- Log shows SHOT SCAN + SHOT ENTITY but no SHOT FIRING or projectile
- SHOT FIRING is the FIRST log in the handler (line 439)
- But current log shows SHOT SCAN WITHOUT SHOT FIRING
- This means either: the file on disk differs from code, or the handler path is different

### Plan
1. Verify commands.lua on disk matches — re-read shot handler start
2. If cooldown exists before SHOT FIRING log, move log before cooldown
3. Add SHOT FIRING log immediately after `elseif item == "vbots2:shot" then`
4. Add SHOT COOLDOWN log if cooldown active

### Things tried (and result)
- not obj:get_player_name() bug → FIXED (Lua empty string is truthy)
- LOS wall check → REMOVED (blocked by grass/plants)
- nil hitter punch → FIXED (direct set_hp bypass)
- is_hostile_entity nested in is_walkable → FIXED (missing end)
- f1-f6 no_repeat exclusion → FIXED (hasarg consumed repeat numbers)
- specific_attack mod check → REMOVED (vl_mobs doesn't exist, unconditional now)
- cone direction facing_dir → FIXED (-facing_dir, bot faces opposite of facedir)
- shot trajectory Y velocity → FIXED (vel.y+=9 for 20-block range)
- collision radius → INCREASED to 1.5

### Ideas
- Remove cooldown for testing, add back later
- Add raw HP damage for shot too (bypass MCL punch)
- Check if player==nil in shot handler (silent return)
