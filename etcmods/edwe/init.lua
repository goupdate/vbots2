-- edwe/init.lua -- EdWorldEdit wooden axe region fill tool

edwe = {}
edwe.max_nodes = tonumber(minetest.settings:get("edwe.max_nodes")) or 10000
edwe.player = {}

dofile(minetest.get_modpath("edwe") .. "/fill.lua")

-- Get mark position from a click: always use the adjacent space (above),
-- i.e. the position touching the pointed face.
-- Top face → space above the block, side face → space next to the block.
-- This way: click floor top + wall side → fill = floor layer up to wall.
function edwe_get_mark_pos(pointed_thing)
    return pointed_thing.above
end -- function edwe_get_mark_pos

-- Left-click handler: mark first position (pos1)
function edwe_handle_lmb(itemstack, user, pointed_thing)
    if pointed_thing.type ~= "node" then
        return itemstack
    end -- if type
    local name = user:get_player_name()
    local st = edwe.player[name]
    if st == nil then
        st = {}
        edwe.player[name] = st
    end -- if st nil
    st.pos1 = edwe_get_mark_pos(pointed_thing)
    minetest.chat_send_player(name, "EdWorldEdit :  first point set.")
    return itemstack
end -- function edwe_handle_lmb

-- Right-click handler: mark second position (pos2) or fill
function edwe_handle_rmb(itemstack, user, pointed_thing)
    if pointed_thing.type ~= "node" then
        return itemstack
    end -- if type
    local name = user:get_player_name()
    local st = edwe.player[name]
    if st == nil then
        return itemstack  -- no pos1 yet, ignore RMB
    end -- if st nil
    if st.pos2 == nil then
        st.pos2 = edwe_get_mark_pos(pointed_thing)
        minetest.chat_send_player(name, "EdWorldEdit: second point set. Choose item to copy.")
    else  -- if pos2
        local fill = minetest.get_node(edwe_get_mark_pos(pointed_thing))
        local ok = edwe_fill_cuboid(name, st.pos1, st.pos2, fill)
        if ok then
            edwe.player[name] = nil
            minetest.chat_send_player(name, "EdWorldEdit : copy done")
        end -- if ok
    end -- if pos2
    return itemstack
end -- function edwe_handle_rmb

-- Register the tool (no tool_capabilities: axe never digs)
minetest.register_tool("edwe:wooden_axe", {
    description = "EdWorldEdit Wooden Axe",
    inventory_image = "edwe_wooden_axe.png",
    groups = {},
    on_use = edwe_handle_lmb,
    on_place = edwe_handle_rmb,
})

-- Craft recipe: standard wooden axe shape, group-based for MTG + VoxeLibre compat
minetest.register_craft({
    output = "edwe:wooden_axe",
    recipe = {
        {"group:wood", "group:wood"},
        {"group:wood", "group:stick"},
        {"", "group:stick"},
    },
})

-- Detect tool change: reset state when player switches away from wooden_axe
minetest.register_globalstep(function(dtime)
    for name, st in pairs(edwe.player) do
        local player = minetest.get_player_by_name(name)
        if player == nil then
            edwe.player[name] = nil
        elseif player:get_wielded_item():get_name() ~= "edwe:wooden_axe" then  -- if player nil
            edwe.player[name] = nil
            minetest.chat_send_player(name, "EdWorldEdit : cancel")
        end -- if player nil / switched
    end -- loop over players with state
end)

-- Cleanup on player leave
minetest.register_on_leaveplayer(function(player)
    edwe.player[player:get_player_name()] = nil
end)