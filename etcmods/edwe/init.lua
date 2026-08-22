-- edwe/init.lua -- EdWorldEdit: fill axe + delete axe, shared state-machine helpers
-- Less copy-paste: one mark_first, one mark_second_or_act, per-tool action functions.

edwe = {}
edwe.max_nodes = tonumber(minetest.settings:get("edwe.max_nodes")) or 10000
edwe.player = {}       -- fill tool state: {pos1 = vector, pos2 = vector}
edwe.player_del = {}   -- delete tool state: {pos1 = vector, pos2 = vector}

dofile(minetest.get_modpath("edwe") .. "/fill.lua")
dofile(minetest.get_modpath("edwe") .. "/protect.lua")

-- ── helpers ──────────────────────────────────────────────────────────────────

-- Get mark position from a click: always use the adjacent space (above),
-- i.e. the position touching the pointed face.
-- Top face → space above the block, side face → space next to the block.
function edwe_get_mark_pos(pointed_thing)
    return pointed_thing.above
end -- function edwe_get_mark_pos

-- Shared LMB: mark pos1. state_tab is edwe.player or edwe.player_del.
function edwe_mark_first(itemstack, user, pointed_thing, state_tab)
    if pointed_thing.type ~= "node" then
        return itemstack
    end -- if type
    local name = user:get_player_name()
    local st = state_tab[name]
    if st == nil then
        st = {}
        state_tab[name] = st
    end -- if st nil
    st.pos1 = edwe_get_mark_pos(pointed_thing)
    minetest.chat_send_player(name, "EdWorldEdit :  first point set.")
    return itemstack
end -- function edwe_mark_first

-- Shared RMB: mark pos2 or execute action.
--   msg2         — chat message when pos2 is set
--   action_fn    — called on 3rd click: fn(name, pos1, pos2, pointed_thing) → bool ok
function edwe_mark_second_or_act(itemstack, user, pointed_thing,
                                 state_tab, action_fn, msg2)
    if pointed_thing.type ~= "node" then
        return itemstack
    end -- if type
    local name = user:get_player_name()
    local st = state_tab[name]
    if st == nil then
        return itemstack  -- no pos1 yet, ignore RMB
    end -- if st nil
    if st.pos2 == nil then
        st.pos2 = edwe_get_mark_pos(pointed_thing)
        minetest.chat_send_player(name, msg2)
    else  -- if pos2 nil
        local ok = action_fn(name, st.pos1, st.pos2, pointed_thing)
        if ok then
            state_tab[name] = nil
        end -- if ok
    end -- if pos2 nil
    return itemstack
end -- function edwe_mark_second_or_act

-- ── action functions ─────────────────────────────────────────────────────────

-- Fill: use the clicked block (under) as material, call fill_cuboid.
function edwe_action_fill(name, pos1, pos2, pointed_thing)
    local fill = minetest.get_node(pointed_thing.under)
    local ok = edwe_fill_cuboid(name, pos1, pos2, fill)
    if ok then
        minetest.chat_send_player(name, "EdWorldEdit : copy done")
    end -- if ok
    return ok
end -- function edwe_action_fill

-- Delete: remove all fillable nodes in cuboid, set to air.
function edwe_action_delete(name, pos1, pos2, pointed_thing)
    local ok = edwe_delete_cuboid(name, pos1, pos2)
    if ok then
        minetest.chat_send_player(name, "EdWorldEdit : delete done")
    end -- if ok
    return ok
end -- function edwe_action_delete

-- ── thin tool wrappers ───────────────────────────────────────────────────────

function edwe_lmb_fill(itemstack, user, pointed_thing)
    return edwe_mark_first(itemstack, user, pointed_thing, edwe.player)
end -- function edwe_lmb_fill

function edwe_rmb_fill(itemstack, user, pointed_thing)
    return edwe_mark_second_or_act(itemstack, user, pointed_thing,
        edwe.player, edwe_action_fill,
        "EdWorldEdit: second point set. Choose item to copy.")
end -- function edwe_rmb_fill

function edwe_lmb_del(itemstack, user, pointed_thing)
    return edwe_mark_first(itemstack, user, pointed_thing, edwe.player_del)
end -- function edwe_lmb_del

function edwe_rmb_del(itemstack, user, pointed_thing)
    return edwe_mark_second_or_act(itemstack, user, pointed_thing,
        edwe.player_del, edwe_action_delete,
        "EdWorldEdit: second point set. Delete region.")
end -- function edwe_rmb_del

-- ── register tools ───────────────────────────────────────────────────────────

-- Fill axe: wooden axe, standard texture
minetest.register_tool("edwe:wooden_axe", {
    description = "EdWorldEdit Wooden Axe",
    inventory_image = "edwe_wooden_axe.png",
    groups = {},
    on_use = edwe_lmb_fill,
    on_place = edwe_rmb_fill,
})

-- Delete axe: inverted wooden axe texture
minetest.register_tool("edwe:wooden_axe_delete", {
    description = "EdWorldEdit Delete Axe",
    inventory_image = "edwe_wooden_axe_delete.png",
    groups = {},
    on_use = edwe_lmb_del,
    on_place = edwe_rmb_del,
})

-- Crafts: both tools use standard wooden axe shape, group-based for MTG + VoxeLibre
minetest.register_craft({
    output = "edwe:wooden_axe",
    recipe = {
        {"group:wood", "group:wood"},
        {"group:wood", "group:stick"},
        {"", "group:stick"},
    },
})

minetest.register_craft({
    output = "edwe:wooden_axe_delete",
    recipe = {
        {"group:wood", "group:wood"},
        {"group:wood", "group:stick"},
        {"", "group:stick"},
    },
})

-- ── state reset ──────────────────────────────────────────────────────────────

-- Check one state entry: reset + "cancel" when player switches away or leaves.
local function edwe_check_tool(name, state_tab, tool_name)
    local player = minetest.get_player_by_name(name)
    if player == nil then
        state_tab[name] = nil
        return
    end -- if player nil
    if player:get_wielded_item():get_name() ~= tool_name then
        state_tab[name] = nil
        minetest.chat_send_player(name, "EdWorldEdit : cancel")
    end -- if switched
end -- function edwe_check_tool

minetest.register_globalstep(function(dtime)
    for name in pairs(edwe.player) do
        edwe_check_tool(name, edwe.player, "edwe:wooden_axe")
    end -- loop over fill state
    for name in pairs(edwe.player_del) do
        edwe_check_tool(name, edwe.player_del, "edwe:wooden_axe_delete")
    end -- loop over delete state
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    edwe.player[name] = nil
    edwe.player_del[name] = nil
end)