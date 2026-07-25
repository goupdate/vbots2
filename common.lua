-- common.lua -- Shared utilities for vbots2: state push/pull, node matching, value resolution, walkable checks, bot interaction callbacks


function push_state(pos,a,b,c)
    local meta = minetest.get_meta(pos)
    local stack = meta:get_string("stack")
    local push = a..","..b..","..c..","
    meta:set_string("stack", push..stack)
end

function pull_state(pos)
    local meta = minetest.get_meta(pos)
    local stack = meta:get_string("stack")
    local newstack = ""
    local heap = string.split(stack,",")
    if #heap>2 then
        meta:set_int("PC",heap[1])
        meta:set_int("PR",heap[2])
        meta:set_int("repeat",heap[3])
        if #heap>3 then
            for a = 4,#heap do
                newstack = newstack .. heap[a] .. ","
            end
            meta:set_string("stack",newstack)
        else
            meta:set_string("stack","")
        end
    end
end

-------------------------------------
-- callback from bot node can_dig
-------------------------------------
function interact(player,pos,isempty)
    local name = player:get_player_name()
    local meta = minetest.get_meta(pos)
    local player_is_owner = ( name == meta:get_string("owner") )
    local has_server_priv = minetest.check_player_privs(player, "server")
    if has_server_priv or player_is_owner then
        return true
    end
    return false
end


-------------------------------------
-- Clean up bot table and bot storage
-------------------------------------
function clean_bot_table()
    for bot_key,bot_data in pairs( vbots2.bot_info) do
        local meta = minetest.get_meta(bot_data.pos)
        local bot_name = meta:get_string("name")
        if bot_name=="" then
            vbots2.bot_info[bot_key] = nil
        end
    end
    --print("Cleaned")
    --print(dump(vbots2.bot_info))
end

-------------------------------------
-- Bot Action Handlers
-------------------------------------
function facebot(facing,pos)
    local node = minetest.get_node(pos)
    minetest.swap_node(pos,{name=node.name, param2=facing})
end

function get_front_node(pos)
    local node = minetest.get_node(pos)
    local dir = minetest.facedir_to_dir(node.param2)
    local front_pos = {x = pos.x - dir.x, y = pos.y, z = pos.z - dir.z}
    return minetest.get_node(front_pos), front_pos
end

local dirt_aliases = {
    ["default:dirt"] = true,
    ["default:dirt_with_grass"] = true,
    ["mcl_core:dirt"] = true,
    ["mcl_core:dirt_with_grass"] = true,
}

function node_matches(got, expected)
    -- treat dirt variants as equal
    if dirt_aliases[got] and dirt_aliases[expected] then
        return true
    end
    return got == expected
end

function bot_add_items(inv, listname, stack)
    -- skip signs: bot creates them via sign_print
    local name = stack:get_name()
    if name and name:find("sign") then return end
    inv:add_item(listname, stack)
end

function resolve_value(stack, meta)
    local name = stack:get_name()
    if name:match("^vbots2:var_") then
        local v = name:match("var_(.)$")
        return meta:get_int("var_" .. v)
    elseif name:match("^vbots2:number_") then
        local n = name:match("number_(%d)$")
        return tonumber(n)
    elseif name ~= "" then
        return 1
    else
        return 0
    end
end
facedirs = {
    {x=0, z=1},   -- 0: south
    {x=1, z=0},   -- 1: east
    {x=0, z=-1},  -- 2: north
    {x=-1, z=0},  -- 3: west
}

function is_walkable(p)
    local node = minetest.get_node(p)
    local n = node.name
    if n == "air" then return true end
    local ndef = minetest.registered_nodes[n]
    if not ndef then return false end
    -- walkable: plants, grass, flowers, saplings, doors, torch-like
    local g = ndef.groups or {}
    if g.flora or g.plant or g.grass or g.flower or g.sapling or g.attached_node or g.torch or g.door then
        return true
    end
    -- not walkable: liquids
    if g.water or g.lava or g.liquid then
        return false
    end
end

function is_hostile_entity(ent)
    if not ent or not ent.name then return false end
    -- check runtime entity fields first
    if ent.hostile or ent._is_hostile or ent._attack or ent.passive == false then
        return true
    end
    -- check entity definition (reliable for Mobs Redo/VoxeLibre)
    local def = minetest.registered_entities[ent.name]
    if def then
        if def.type == "monster" then return true end
        if def.hostile or def._attack or def.passive == false then return true end
    end
    return false
end
