# EdWorldEdit (edwe)

A wooden axe region-fill tool for Luanti 5.14.0+ (Minetest Game and VoxeLibre).

## How to use

1. **Craft** a `edwe:wooden_axe` (3 wood + 2 sticks, wooden axe shape) or take it from Creative.
2. **LMB** on a block → marks position 1 — the space *adjacent* to the clicked face (top face → space above, side face → space next to).
3. **RMB** on a block → marks position 2 — same rule.
4. **RMB** on a third block → fills the cuboid between positions 1 and 2 with that block.

**Mark position rule:** clicking the *top* face marks the block **above** the clicked one (e.g. click floor → mark air above it). Clicking a *side* face marks the **adjacent** space (e.g. click wall from inside → mark the air block next to wall). This lets you naturally outline floors, walls, and ceilings. Example: click floor top + wall side → fill creates a new floor layer up to the wall.

## Fill rules

| Node | Action |
|---|---|
| `air` | replaced with fill block |
| Water (any node with "water" in name) | replaced |
| Grass (any node with "grass" in name) | replaced |
| Other occupied blocks | skipped (left as-is) |
| `ignore` (unloaded chunk) | skipped |
| Protected nodes (`areas` / protection mod) | skipped |

### Block consumption

| Mode | Behavior |
|---|---|
| Creative | Free — no blocks consumed from inventory |
| Survival | Blocks taken from player's main inventory (1 per filled position) |
| Fill with `air` | Always free (clearing doesn't consume items) |

## Chat messages (literal)

| Event | Message |
|---|---|
| First point marked | `EdWorldEdit :  first point set.` |
| Second point marked | `EdWorldEdit: second point set. Choose item to copy.` |
| Fill done | `EdWorldEdit : copy done` |
| Tool changed | `EdWorldEdit : cancel` |
| Region too big | `EdWorldEdit : region too big (N nodes, max M)` |
| Not enough blocks | `EdWorldEdit : not enough <nodename> (need N)` |
| No inventory access | `EdWorldEdit : cannot access inventory` |

## Settings

- `edwe.max_nodes` — maximum nodes per fill (default: 10000). Set in `All Settings` or `settingtypes.txt`.

## Compatibility

- Minetest Game (MTG)
- VoxeLibre / MineClone 2 (MCL)
- Uses `group:wood` / `group:stick` for crafting and `"water"`/`"grass"` name patterns for fill rules — works across both game systems.

## License

MIT — see `license.txt`.