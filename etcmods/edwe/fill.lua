-- edwe/fill.lua -- cuboid fill helpers

-- Local references for CPU/memory optimization (avoid global table lookups in hot loops)
local minetest_get_node = minetest.get_node
local minetest_is_protected = minetest.is_protected
local minetest_bulk_set_node = minetest.bulk_set_node
local minetest_chat_send = minetest.chat_send_player
local minetest_is_creative = minetest.is_creative_enabled
local table_insert = table.insert

-- Check if node name contains "water" (catches default:water_* and mcl_core:water_* / river_water_*)
function edwe_is_water(name)
    return name:find("water") ~= nil
end -- function edwe_is_water

-- Check if node name contains "grass" (catches default:grass_*, dirt_with_grass*, mcl_core:grass_block, short_grass)
function edwe_is_grass(name)
    return name:find("grass") ~= nil
end -- function edwe_is_grass

-- Fill cuboid between pos1 and pos2 with the node 'fill'
-- Returns true on success, false + chat message if region too big or not enough items
function edwe_fill_cuboid(player_name, pos1, pos2, fill)
    local minp = {
        x = math.min(pos1.x, pos2.x),
        y = math.min(pos1.y, pos2.y),
        z = math.min(pos1.z, pos2.z),
    }
    local maxp = {
        x = math.max(pos1.x, pos2.x),
        y = math.max(pos1.y, pos2.y),
        z = math.max(pos1.z, pos2.z),
    }
    local count = (maxp.x - minp.x + 1) * (maxp.y - minp.y + 1) * (maxp.z - minp.z + 1)
    if count > edwe.max_nodes then
        minetest_chat_send(player_name,
            "EdWorldEdit : region too big (" .. count .. " nodes, max " .. edwe.max_nodes .. ")")
        return false
    end -- if count > max
    local list = {}
    for x = minp.x, maxp.x do
        for y = minp.y, maxp.y do
            for z = minp.z, maxp.z do
                local p = {x = x, y = y, z = z}
                local node = minetest_get_node(p)
                if node.name ~= "ignore"
                and (node.name == "air" or edwe_is_water(node.name) or edwe_is_grass(node.name))
                and not minetest_is_protected(p, player_name) then
                    table_insert(list, p)
                end -- if fillable
            end -- loop over z
        end -- loop over y
    end -- loop over x
    local to_fill = #list
    if to_fill == 0 then
        return true
    end -- if to_fill zero

    -- Inventory consumption: creative = free, survival = take from player inventory
    -- Air fill is always free (clearing blocks doesn't consume items)
    if fill.name ~= "air" and not minetest_is_creative(player_name) then
        local inv = minetest.get_inventory({type = "player", name = player_name})
        if inv == nil then
            minetest_chat_send(player_name, "EdWorldEdit : cannot access inventory")
            return false
        end -- if inv nil
        local needed = fill.name .. " " .. to_fill
        if not inv:contains_item("main", needed) then
            minetest_chat_send(player_name,
                "EdWorldEdit : not enough " .. fill.name .. " (need " .. to_fill .. ")")
            return false
        end -- if not enough
        inv:remove_item("main", needed)
    end -- if survival and not air

    minetest_bulk_set_node(list, fill)
    return true
end -- function edwe_fill_cuboid