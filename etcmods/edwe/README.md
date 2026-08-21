# EdWorldEdit (edwe)

Two wooden axe tools for Luanti 5.14.0+ (Minetest Game and VoxeLibre):
- **Fill Axe** — fills a cuboid with a chosen block.
- **Delete Axe** (inverted texture) — clears a cuboid, setting all non-air non-protected nodes to air.

## How to use

### Fill Axe (`edwe:wooden_axe`)

1. **Craft** a `edwe:wooden_axe` (3 wood + 2 sticks, wooden axe shape) or take it from Creative.
2. **LMB** on a block → marks position 1 — the space *adjacent* to the clicked face (top face → space above, side face → space next).
3. **RMB** on a block → marks position 2 — same rule.
4. **RMB** on a third block → fills the cuboid between positions 1 and 2 with that block.

### Delete Axe (`edwe:wooden_axe_delete`)

1. **Craft** a `edwe:wooden_axe_delete` (same recipe) or take it from Creative.
2. **LMB** on a block → marks position 1 (same marking rule: adjacent space).
3. **RMB** on a block → marks position 2.
4. **RMB** a third time → clears the cuboid: all non-air, non-ignore, non-protected nodes are set to `air`. Always free (no blocks returned), works in both creative and survival.

**Mark position rule:** clicking the *top* face marks the block **above** the clicked one (e.g. click floor → mark air above it). Clicking a *side* face marks the **adjacent** space (e.g. click wall from inside → mark the air block next to wall).

## Fill rules (Fill Axe)

| Node | Action |
|---|---|
| `air` | replaced with fill block |
| Water (any node with "water" in name) | replaced |
| Grass (any node with "grass" in name) | replaced |
| Other occupied blocks | skipped (left as-is) |
| `ignore` (unloaded chunk) | skipped |
| Protected nodes (`areas` / protection mod) | skipped |

## Delete rules (Delete Axe)

| Node | Action |
|---|---|
| Any non-air, non-ignore, non-protected node | set to `air` |
| `air` | skipped |
| `ignore` (unloaded chunk) | skipped |
| Protected nodes | skipped |

### Block consumption

| Mode | Fill Axe | Delete Axe |
|---|---|---|
| Creative | Free | Free |
| Survival | Blocks taken from inventory (1 per position) | Free |
| Fill/Del with `air` | Free | N/A |

## Chat messages (literal)

| Event | Fill Axe | Delete Axe |
|---|---|---|
| First point | `EdWorldEdit :  first point set.` | `EdWorldEdit :  first point set.` |
| Second point | `EdWorldEdit: second point set. Choose item to copy.` | `EdWorldEdit: second point set. Delete region.` |
| Done | `EdWorldEdit : copy done` | `EdWorldEdit : delete done` |
| Tool changed | `EdWorldEdit : cancel` | `EdWorldEdit : cancel` |
| Region too big | `EdWorldEdit : region too big (N nodes, max M)` | `EdWorldEdit : region too big (N nodes, max M)` |
| Not enough blocks | `EdWorldEdit : not enough <nodename> (need N)` | — |
| No inventory | `EdWorldEdit : cannot access inventory` | — |

## Settings

- `edwe.max_nodes` — maximum nodes per operation (default: 10000). Set in `All Settings` or `settingtypes.txt`.

## Files

| File | Purpose |
|---|---|
| `init.lua` | Shared state-machine helpers, tool registration, crafts, globalstep, leaveplayer |
| `fill.lua` | `edwe_fill_cuboid()`, `edwe_delete_cuboid()`, `edwe_is_water()`, `edwe_is_grass()` |
| `textures/edwe_wooden_axe.png` | Fill axe texture (standard wooden axe) |
| `textures/edwe_wooden_axe_delete.png` | Delete axe texture (inverted 180°) |

## Compatibility

- Minetest Game (MTG)
- VoxeLibre / MineClone 2 (MCL)
- Uses `group:wood` / `group:stick` for crafting and `"water"`/`"grass"` name patterns — works across both game systems.

## License

MIT — see `license.txt`.