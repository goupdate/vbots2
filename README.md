# vbots2

An extended visual programming bot mod for [Luanti](https://www.luanti.org/) (formerly Minetest).

**Requires Luanti 5.14.0+.** Tested on 5.14.0.

Vbots are single-block "turtle" style bots, programmable in an entirely visual way — no text typing required.

## What's New in vbots2

vbots2 adds **conditional logic** and quality-of-life improvements on top of the original [visual-bots by Nigel Garnett](https://content.luanti.org/packages/Nigel/vbots/):

- Conditional commands: ![=?](textures/vbots_eq_check.png) ![<>?](textures/vbots_neq_check.png) ![dig?](textures/vbots_dig_check.png) — check blocks ahead, chest contents
- Value comparisons: ![>?](textures/vbots_gt_check.png) ![<?](textures/vbots_lt_check.png) ![>=?](textures/vbots_gte_check.png) ![<=?](textures/vbots_lte_check.png) — compare variables/numbers
- Variables A–D and ![#](textures/vbots_count.png) — memory cells via signs (auto-creates if none ahead), item counting
- ![END](textures/vbots_end_program.png) command — stops program in main, returns from sub-programs
- Chest interaction — build transfers one item **ahead** into chest (filter by item type); empty chests can be dug as blocks
- Magnet pickup — auto-collects dropped items in 1-block radius; excess vanishes
- Dirt equivalence — `dirt` and `dirt_with_grass` treated as same block in conditions
- Editable bot name, crash fixes (formspec no longer crashes on bot move), inventory drops on removal

---

## Basics

- **Punch** an idle bot with an **empty hand** to start its program (or click the run icon in the menu).
- **Punch** a running bot with an **empty hand** to stop it.
- **Right-click** (double-tap on Android) to open the menu.
- **Dig the bot** by hitting it with anything except an empty hand. Items in the bot's inventory will drop on the ground.

### Crafting

| | | |
|---|---|---|
| Iron | Iron | Iron |
| Iron | Redstone | Iron |
| Iron | Iron | Iron |

→ **1 Vbot (inactive)**

---

## The Main Menu

![Main Menu 1](images/doc_menu1.png)

The **commands** ![commands](textures/vbots_gui_commands.png) and **inventory** ![inventory](textures/vbots_location_inventory.png) icons switch between the two panels.

The **command panel** (left, shown above) contains all available commands. Click any command to add it to the current sub-program (the red area on the right).

The **inventory panel** shows the bot's inventory (top) and the player's inventory (bottom). Use this panel to give the bot building materials or take items it has collected.

![Main Menu 2](images/doc_menu2.png)

### Controls

| Icon | Action |
|------|--------|
| ![trash](textures/vbots_gui_trash.png) **Trash** | Deletes the last instruction on the current sub-program page |
| ![run](textures/vbots_gui_run.png) **Run** | Starts the program (same as punching with empty hand) |
| ![save](textures/vbots_gui_save.png) **Save** | Saves the current program and sub-programs under the bot's name |
| ![load](textures/vbots_gui_load.png) **Load** | Opens the load menu to choose, rename, or delete saved programs |
| ![removeall](textures/vbots_gui_nuke.png) **Remove All** | 1st press: stop all your bots. 2nd press (within 2s): destroy all your bots |
| ![reset](textures/vbots_gui_reset.png) **Reset** | Clears all programs (main + sub-programs) but keeps the inventory |
| ![exit](textures/vbots_gui_exit.png) **Exit** | Closes the menu |

### Sub-Programs

The red panel on the right has **7 pages**:

| Icon | Page |
|------|------|
| ![main](textures/vbots_fm.png) | **Main** program — execution starts here |
| ![sub1](textures/vbots_f1.png) | Sub-program 1 |
| ![sub2](textures/vbots_f2.png) | Sub-program 2 |
| ![sub3](textures/vbots_f3.png) | Sub-program 3 |
| ![sub4](textures/vbots_f4.png) | Sub-program 4 |
| ![sub5](textures/vbots_f5.png) | Sub-program 5 |
| ![sub6](textures/vbots_f6.png) | Sub-program 6 |

Call sub-programs using the function icons at the bottom of the command panel.

---

## Commands

### Movement

| Icon | Command | Description |
|------|---------|-------------|
| ![forward](textures/vbots_move_forward.png) | Move Forward | Move one step forward |
| ![backward](textures/vbots_move_backward.png) | Move Backward | Move one step backward |
| ![up](textures/vbots_move_up.png) | Move Up | Move one step up |
| ![down](textures/vbots_move_down.png) | Move Down | Move one step down |
| ![home](textures/vbots_move_home.png) | Go Home | Teleport to creation point |
| ![go_player](textures/vbots_go_player.png) | Go to Player | Teleport to player |
| ![goto_pos](textures/vbots_goto_pos.png) | Go to Position | Teleport to coordinates (searches empty spot nearby) |

> **GUI layout:** ![END](textures/vbots_end_program.png) END appears on the same row as ![goto_pos](textures/vbots_goto_pos.png) (right of Go to Position) in the command panel.

Movement fails if the destination is not empty. **Gravity removed:** the bot stays in place even if the block below is air — it can float in mid-air.

### Turning

| Icon | Command | Description |
|------|---------|-------------|
| ![cw](textures/vbots_turn_clockwise.png) | Turn Clockwise | Rotate 90° right |
| ![ccw](textures/vbots_turn_anticlockwise.png) | Turn Anti-Clockwise | Rotate 90° left |
| ![random](textures/vbots_turn_random.png) | Turn Random | Rotate in a random direction |

### Digging & Building

| Icon | Command | Description |
|------|---------|-------------|
| ![dig](textures/vbots_mode_dig.png) | Dig Forward | Dig the block in front, then move into that space |
| ![dig up](textures/vbots_mode_dig_up.png) | Dig Up | Dig the block above, then move up |
| ![dig down](textures/vbots_mode_dig_down.png) | Dig Down | Dig the block below, then move down |
| ![build up](textures/vbots_mode_build_up.png) | Build Up | Place a block above the position ahead |
| ![build](textures/vbots_mode_build.png) | Build Ahead | Place a block ahead (or transfer into chest ahead) |
| ![build behind](textures/vbots_build_behind.png) | Build Behind | Place a block behind (or transfer into chest behind) |
| ![build down](textures/vbots_mode_build_down.png) | Build Down | Place a block below the position ahead |

**Building behavior:**
- Build commands **never consume blocks** from the bot's inventory (creative mode — blocks are created out of thin air)
- If the target is **air** → places the selected block type
- If the target is a **chest/container** (any node with `container` group) → transfers the first item from inventory (or matching item if filter is placed in next slot)
- If no items in inventory → nothing happens

**Digging & Pickup behavior:**
- Collected items go into the bot's inventory
- **Magnet:** the bot automatically picks up any dropped items within 1-block radius on each tick
- If inventory is full, excess items **vanish** (no ground drops to avoid pickup/drop loops)
- **Chests:** empty chest → digs it as a block; non-empty chest → takes items (optional filter in next slot)

### Conditions

| Icon | Command | Description |
|------|---------|-------------|
| ![=?](textures/vbots_eq_check.png) | **Is block ahead?** | Execute next command **only if** the block ahead matches |
| ![<>?](textures/vbots_neq_check.png) | **Is NOT block ahead?** | Execute next command **only if** the block ahead does NOT match |
| ![dig?](textures/vbots_dig_check.png) | **Has item in chest?** | Execute next command **only if** the chest ahead contains the specified item |
| ![>?](textures/vbots_gt_check.png) | **Value > Value?** | Execute next if first value greater than second |
| ![<?](textures/vbots_lt_check.png) | **Value < Value?** | Execute next if first value less than second |
| ![>=?](textures/vbots_gte_check.png) | **Value >= Value?** | Execute next if first value greater or equal |
| ![<=?](textures/vbots_lte_check.png) | **Value <= Value?** | Execute next if first value less or equal |

**How conditions work:**

A condition uses 3 slots in the program:

```
[ =? ] [ block ] [ command ] [ next... ]
  (1)     (2)       (3)         (4)
```

1. **Slot 1** — the condition command (![=?](textures/vbots_eq_check.png) or ![<>?](textures/vbots_neq_check.png))
2. **Slot 2** — the **block to check for** (place any block item here, e.g. `Stone`, `Dirt`)
3. **Slot 3** — the **command to execute if the condition is true**
4. **Slot 4+** — always executed

If slot 2 is empty, it checks for **air** (nothing ahead).

**Special:** `dirt` and `dirt_with_grass` (and their `mcl_core:` variants) are treated as the same block.

**Value comparisons** use 3 slots with **active variable** as left operand:

```
[ >? ] [ arg ] [ true-cmd ] [ after... ]
```

- **Left operand** — the **active variable** (set by ![A](textures/vbots_var_a.png)–![D](textures/vbots_var_d.png) before the comparison)
- **Slot arg** — right operand: a number (![x2](textures/vbots_number_2.png)–![x7](textures/vbots_number_7.png)), a variable (A–D), or a block (= 1). Empty = 0.
- **Slot true-cmd** — executed if comparison is true
- If false, true-cmd is skipped, after executes

![A](textures/vbots_var_a.png) ![>?](textures/vbots_gt_check.png) ![x2](textures/vbots_number_2.png) ![forward](textures/vbots_move_forward.png) ![cw](textures/vbots_turn_clockwise.png)
→ If var_a > 2: move forward, then turn right. Otherwise: only turn right.

### Variables & Count

| Icon | Command | Description |
|------|---------|-------------|
| ![A](textures/vbots_var_a.png) | **Var A** | Select variable A as active |
| ![B](textures/vbots_var_b.png) | **Var B** | Select variable B as active |
| ![C](textures/vbots_var_c.png) | **Var C** | Select variable C as active |
| ![D](textures/vbots_var_d.png) | **Var D** | Select variable D as active |
| ![read](textures/vbots_sign_read.png) | **Load from sign** | Read number from sign ahead into specified variable (creates sign if none) |
| ![write](textures/vbots_sign_print.png) | **Write to sign** | Write specified variable value to sign ahead (creates sign if none) |
| ![count](textures/vbots_count.png) | **Count items** | Count items of a type in inventory, store in active variable |

**Variables as multipliers:** place a variable after any command to repeat it that many times. Variables stack with numbers — they multiply together (cap: 49):

![forward](textures/vbots_move_forward.png) ![A](textures/vbots_var_a.png)
→ If var_a = 5, moves forward 5 times.

![forward](textures/vbots_move_forward.png) ![x2](textures/vbots_number_2.png) ![A](textures/vbots_var_a.png)
→ With var_a = 3: 2×3 = 6 steps forward.

**Loading variables:**
- **Signs:** ![read](textures/vbots_sign_read.png) ![B](textures/vbots_var_b.png) → reads number from sign ahead into var_b
- **Count:** `[A]` `[count]` \+ [Stone] → counts all stone in inventory, stores in var_a
- **Writing:** ![write](textures/vbots_sign_print.png) ![C](textures/vbots_var_c.png) → writes var_c value onto sign ahead

### Program Flow

| Icon | Command | Description |
|------|---------|-------------|
| ![f1](textures/vbots_f1.png) | **F1** | Call sub-program 1 |
| ![f2](textures/vbots_f2.png) | **F2** | Call sub-program 2 |
| ![f3](textures/vbots_f3.png) | **F3** | Call sub-program 3 |
| ![f4](textures/vbots_f4.png) | **F4** | Call sub-program 4 |
| ![f5](textures/vbots_f5.png) | **F5** | Call sub-program 5 |
| ![f6](textures/vbots_f6.png) | **F6** | Call sub-program 6 |
| ![END](textures/vbots_end_program.png) | **End** | Stop execution (in main) or return (from sub-program) |
| ![speed](textures/vbots_mode_speed.png) | **Speed** | Set bot step rate (use with number or variable) |

**Speed:** use ![speed](textures/vbots_mode_speed.png) with a number (![x2](textures/vbots_number_2.png)–![x7](textures/vbots_number_7.png)) or variable to set the bot's step rate. Without a multiplier, resets to normal speed (1 step/tick).

### Number Multipliers

| ![speed](textures/vbots_mode_speed.png) | ![x2](textures/vbots_number_2.png) | ![x3](textures/vbots_number_3.png) | ![x4](textures/vbots_number_4.png) | ![x5](textures/vbots_number_5.png) | ![x6](textures/vbots_number_6.png) | ![x7](textures/vbots_number_7.png) |
|----------------------------------------|------|------|------|------|------|------|

Place a number **after** a command to repeat it (N−1) additional times. Works with all commands. ![speed](textures/vbots_mode_speed.png) sets the bot's step rate multiplier.

**Stacking multipliers:** you can place several numbers/variables in a row — they multiply together. Example: `[→]` ![x5](textures/vbots_number_5.png) ![x2](textures/vbots_number_2.png) = 5×2 = 10 steps. The total is capped at **49** (×7 ×7), any extra multipliers beyond the cap are ignored.

### Combat

| Icon | Command | Description |
|------|---------|-------------|
| ![laser](textures/vbots_laser.png) | **Laser** | Fire at nearest hostile (range: 3+0.5×lv blocks, 90° cone, damage based on level ★1→36, 4s cooldown with sparks). |
| ![shot](textures/vbots_shot.png) | **Shot** | Throw snowball at nearest hostile (range: 5+1.0×lv blocks, 90° cone, damage based on level ❄1→21, 6s cooldown, speed ~6.7). |
| ![bug_check](textures/vbots_bug_check.png) | **Bug?** | Skip next command if hostile mob within 5 blocks |
| ![damaged_check](textures/vbots_damaged_check.png) | **Damaged?** | Skip next command if bot was attacked in last 3 seconds |
| ![turn_danger](textures/vbots_turn_danger.png) | **Turn→** | Turn toward attacker (last 3s) or nearest hostile (max(shot_range, 10)-block sphere). Line-of-sight required: only air and passable-through nodes (flora, leaves, torches, etc.) between bot and target. Follow with **×N** (number button) to scale search radius by N — multipliers stack (×7×7 = ×49). Turns only when a target is found — otherwise sparks, no turn. |
| ![p2p_on](textures/vbots_p2p_on.png) | **P2P On** | Player-vs-player mode: any other player and bots owned by other players are treated as hostile. Active button is highlighted in the panel. |
| ![p2p_off](textures/vbots_p2p_off.png) | **P2P Off** | Default: fire only at mobs, never at players. |

**Laser & Shot** fire only within a 90° cone in the bot's facing direction. Both aim at the target's center (y+1) and perform a line-of-sight check (ignores flora, grass, plants, flowers, torches, leaves).
**Shot** spawns a projectile (`vbots2:projectile_snowball`) with snowball texture, direct flight path (no gravity), speed ~6.7 blocks/s (~3s per 20 blocks), 1.5-block hit radius, and 5s timeout.
**[Damaged?]** and **[Turn→]** track damage via the bot's combat entity (`vbots2:bot_body`) — works with any mob attack.
Bot uses `is_hostile_entity()`: checks `type=="monster"`, `hostile`, `_is_hostile`, `_attack`, `passive==false` flags on runtime entity + registered definition fallback.
`is_valid_target()` excludes dropped items, vbots2:* entities, mcl_burning:*, mcl_wieldview:*, and any player.
In **P2P On** mode any other player becomes a valid target for Laser, Shot, Bug?, Turn→ and the ram — the bot's owner is always excluded.

**Bot body** (`vbots2:bot_body`): type=npc, starting HP=10, invisible (`visual_size={0,0,0}`), has `hostile=true` and `_attack=1` flags. All hostile mobs (`type=="monster"`) get `attack_npcs=true` and `specific_attack` injection at mod load (1s delay), so zombies/spiders/creepers/skeletons naturally attack bots.

**Damage floating numbers** — each hit shows a red damage number (`-X.X`) above the target, floating upward for 1 second.

**Level progression** — each kill advances the bot based on victim weight:

| Victim | Weight |
|--------|--------|
| Player | 1.0 |
| Creeper | 0.4 |
| Spider | 0.3 |
| Skeleton | 0.25 |
| Other mob | 0.15 |

Level = `floor(sqrt(total_kills)) + 1`. Stats scale with level:

| Stat | Formula | Start (Lv.1) | Max (Lv.22) | Range |
|------|---------|--------------|-------------|-------|
| Laser ★ | `3 + (lv-1)*1.5` | 3.0 | 36.0 | `3+0.5×lv` |
| Shot ❄ | `2 + (lv-1)*0.9` | 2.0 | 21.0 | `5+1.0×lv` |
| HP ♥ | `10 + (lv-1)*0.8` | 10 | 27.0 | — |
| Armor 🛡 | `floor((lv-1)/4)` | 0 | 5 | — |

Bot HP uses `math.floor()` for integer HP. Danger detection radius = `max(shot_range, 10)`. The bot panel shows: **Name, Lv(%), Kills, ♥HP 🛡 ★ ❄**.

**Label indicator** — a standalone entity floats above each bot (+2.5Y): `Lv.N(%)  ★laser/36  ❄shot/21  ♥hp/27  🛡armor`. Visible only to the bot's owner, within 5 blocks.

Zombie HP = 20.

---

## New Behaviors

vbots2 introduces several behavioral changes:

- **Creative build mode** — build commands never consume blocks from the bot's inventory. Blocks are created out of thin air, so you don't need to stock the bot with materials.
- **No gravity** — the bot no longer falls when the block below is air. It can float in mid-air indefinitely, allowing aerial platforms and ceiling work.
- **Teleport navigation** — ![home](textures/vbots_move_home.png), ![go_player](textures/vbots_go_player.png), and ![goto_pos](textures/vbots_goto_pos.png) all teleport instantly instead of pathfinding. The bot vanishes and reappears at the target.
- **Move Up** — ![up](textures/vbots_move_up.png) lets the bot move one step upward, complementing the existing Move Down command.
- **P2P mode** — ![p2p_on](textures/vbots_p2p_on.png) makes the bot treat any other player and bots owned by other players as hostile targets (Laser, Shot, Bug?, Turn→ and the ram). ![p2p_off](textures/vbots_p2p_off.png) returns to mobs-only combat. The active mode button is highlighted in the panel.

---

## Examples

### Example 1: Walk and Turn

![forward](textures/vbots_move_forward.png)
![x4](textures/vbots_number_4.png)
![clockwise](textures/vbots_turn_clockwise.png)
![x2](textures/vbots_number_2.png)
![forward](textures/vbots_move_forward.png)
![x4](textures/vbots_number_4.png)
![clockwise](textures/vbots_turn_clockwise.png)
![x2](textures/vbots_number_2.png)

Moves 4 spaces forward, turns 180°, moves 4 back to start, turns 180° to face original direction.

### Example 2: Using a Sub-Program

In sub-program 1 (![f1](textures/vbots_f1.png)):

![forward](textures/vbots_move_forward.png)
![x4](textures/vbots_number_4.png)
![clockwise](textures/vbots_turn_clockwise.png)
![x2](textures/vbots_number_2.png)

In main (![fm](textures/vbots_fm.png)):

![f1](textures/vbots_f1.png)
![x2](textures/vbots_number_2.png)

Calls the sub-program twice.

### Example 3: Conditional Digging

Check if the block ahead is NOT dirt — dig only non-dirt blocks:

![<>?](textures/vbots_neq_check.png)
\+ [Dirt item]
![dig](textures/vbots_mode_dig.png)
![forward](textures/vbots_move_forward.png)

> Place a **Dirt** block (from your inventory) in the slot after ![<>?](textures/vbots_neq_check.png).  
> If the block ahead is NOT dirt → dig it and move forward.  
> If it IS dirt (or dirt_with_grass) → just move forward (skip digging).

### Example 4: Mine Until Stone, Then Stop

Mine forward in a loop, but stop when you hit stone:

![=?](textures/vbots_eq_check.png)
\+ [Stone item]
![END](textures/vbots_end_program.png)
![dig](textures/vbots_mode_dig.png)
![forward](textures/vbots_move_forward.png)
![home](textures/vbots_move_home.png)

> Place a **Stone** block in the arg slot after ![=?](textures/vbots_eq_check.png). With this looped program, the bot:
> - If ahead IS stone → hits END and stops forever
> - If ahead is NOT stone → **skips** END, digs, moves forward, goes home (loop continues)

### Example 5: Find Block, Then Dig

![=?](textures/vbots_eq_check.png) \+ [Stone] ![dig](textures/vbots_mode_dig.png) ![forward](textures/vbots_move_forward.png)
→ If stone ahead: dig it and move forward. Otherwise: just move forward.

### Example 6: Take From Chest

![dig?](textures/vbots_dig_check.png) \+ [Stone] ![dig](textures/vbots_mode_dig.png) ![forward](textures/vbots_move_forward.png)
→ If chest ahead has stone: take one stone (bot stays in place, chest blocks movement). Otherwise: just move forward.

### Example 7: Count & Compare

![A](textures/vbots_var_a.png) ![count](textures/vbots_count.png) \+ [Stone]
![>?](textures/vbots_gt_check.png) ![x3](textures/vbots_number_3.png) ![END](textures/vbots_end_program.png)
![forward](textures/vbots_move_forward.png)
→ Count stone in inventory → var_a. If var_a > 3: stop. Otherwise: move forward.

### Example 8: Read Sign, Multiply

![read](textures/vbots_sign_read.png) ![B](textures/vbots_var_b.png)
![forward](textures/vbots_move_forward.png) ![B](textures/vbots_var_b.png)
→ Read number from sign ahead into var_b. Move forward var_b times.

### Example 9: Inventory Dump

![build](textures/vbots_mode_build.png)
→ If chest is **ahead**: transfers first item from inventory.  
→ ![build](textures/vbots_mode_build.png) \+ [Stone]: transfers one stone to chest.  
→ If no chest ahead: places a block ahead.

---

## Based On

This mod is based on **[visual-bots](https://content.luanti.org/packages/Nigel/vbots/)** (© 2019 Nigel Garnett).  
Extended with conditional commands, chest interaction, variables, and various fixes.
