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

function bot_shoot(pos, meta, cfg)
    local P = cfg.log_prefix or "COMBAT"
    vbots2.log(meta:get_string("name"), P .. " FIRING at " .. pos.x .. "," .. pos.y .. "," .. pos.z)
    local now = minetest.get_gametime()
    local last = meta:get_float(cfg.cooldown_key)
    if now - last < cfg.cooldown_time then
        vbots2.log(meta:get_string("name"), P .. " COOLDOWN")
        minetest.add_particlespawner({amount = 3, time = 0.2,
            minpos = {x = pos.x - 0.2, y = pos.y + 0.4, z = pos.z - 0.2},
            maxpos = {x = pos.x + 0.2, y = pos.y + 0.8, z = pos.z + 0.2},
            minvel = {x = -0.5, y = 1, z = -0.5}, maxvel = {x = 0.5, y = 3, z = 0.5},
            minacc = {x = 0, y = -2, z = 0}, maxacc = {x = 0, y = -5, z = 0},
            minexptime = 0.3, maxexptime = 0.6, minsize = 0.5, maxsize = 1,
            collisiondetection = false, texture = "vbots_laser_spark.png", glow = 14})
        return
    end
    meta:set_float(cfg.cooldown_key, now)
    local owner = meta:get_string("owner")
    local player = minetest.get_player_by_name(owner)
    if not player then return end
    local nearest = find_nearest_hostile(pos, cfg.radius, player, true)
    vbots2.log(meta:get_string("name"), P .. " SCAN radius=" .. cfg.radius)
    if not nearest then
        vbots2.log(meta:get_string("name"), P .. " NO TARGET")
        minetest.add_particlespawner({amount = 5, time = 0.3,
            minpos = {x = pos.x - 0.2, y = pos.y + 0.4, z = pos.z - 0.2},
            maxpos = {x = pos.x + 0.2, y = pos.y + 0.8, z = pos.z + 0.2},
            minvel = {x = -0.5, y = 1, z = -0.5}, maxvel = {x = 0.5, y = 3, z = 0.5},
            minacc = {x = 0, y = -2, z = 0}, maxacc = {x = 0, y = -5, z = 0},
            minexptime = 0.3, maxexptime = 0.6, minsize = 0.5, maxsize = 1,
            collisiondetection = false, texture = "vbots_laser_spark.png", glow = 14})
        return
    end
    local tpos = nearest:get_pos()
    local aim_pos = {x = tpos.x, y = (tpos.y or 0) + 1, z = tpos.z}
    -- LOS check
    local eye = {x = pos.x, y = pos.y + 0.6, z = pos.z}
    local beam_vec = vector.subtract(aim_pos, eye)
    local beam_len = vector.length(beam_vec)
    local blocked = false
    if beam_len > 0 then
        local beam_dir = vector.normalize(beam_vec)
        for s = 1, math.floor(beam_len * 2) do
            local p = vector.add(eye, vector.multiply(beam_dir, s * 0.5))
            local pnode = minetest.get_node({x=math.floor(p.x+0.5), y=math.floor(p.y+0.5), z=math.floor(p.z+0.5)})
            local pndef = minetest.registered_nodes[pnode.name]
            if pndef and pndef.walkable then
                local g = pndef.groups or {}
                if not g.flora and not g.grass and not g.plant and not g.flower and not g.torch and not g.attached_node and not g.leaves then
                    blocked = true; break
                end
            end
        end
    end
    if blocked then
        vbots2.log(meta:get_string("name"), P .. " BLOCKED by wall")
        local bp = vector.add(eye, vector.multiply(beam_vec, 0.5))
        for i = 1, 6 do
            minetest.add_particle({pos = bp, velocity = {x=math.random()-0.5, y=math.random()*2+1, z=math.random()-0.5},
                acceleration = {x=0, y=-6, z=0}, expirationtime = 0.5 + math.random(),
                size = 0.2 + math.random()*0.15, collisiondetection = true,
                texture = "vbots_laser_spark.png", glow = 10})
        end
        return
    end
    if cfg.is_shot then
        -- SHOT: spawn projectile
        local spawn_pos = {x = pos.x, y = pos.y + 0.6, z = pos.z}
        local dir = vector.subtract(aim_pos, spawn_pos)
        if vector.length(dir) == 0 then return end
        dir = vector.normalize(dir)
        local vel = {x = dir.x * 6.67, y = dir.y * 6.67, z = dir.z * 6.67}
        local obj = minetest.add_entity(spawn_pos, "vbots2:projectile_snowball")
        if obj then
            vbots2.log(meta:get_string("name"), P .. " SPAWNED vel=" .. string.format("%.0f,%.0f,%.0f", vel.x, vel.y, vel.z))
            obj:set_velocity(vel)
            local tent = obj:get_luaentity()
            if tent then tent._damage = cfg.damage; tent._shooter = player
                tent._pvp = meta:get_int("pvp") == 1
                tent._owner_name = meta:get_string("owner")
            end
            minetest.sound_play("mcl_bows_bow_shoot", {pos = pos, max_hear_distance = 16})
        else
            vbots2.log(meta:get_string("name"), P .. " FAILED to spawn")
        end
    else
        -- LASER: beam + impact + direct damage
        local beam_dir = vector.normalize(beam_vec)
        for i = 0, math.floor(beam_len * 8) do
            local p = vector.add(eye, vector.multiply(beam_dir, i * 0.125))
            minetest.add_particle({pos = p, velocity = {x=0,y=0,z=0},
                acceleration = {x=0,y=0,z=0}, expirationtime = 1.0,
                size = 0.7 + math.random() * 0.3, collisiondetection = false,
                texture = "vbots_laser_spark.png", glow = 14})
        end
        for i = 1, 12 do
            minetest.add_particle({pos = aim_pos, velocity = {x=math.random()-0.5, y=math.random()*2+1, z=math.random()-0.5},
                acceleration = {x=0, y=-6, z=0}, expirationtime = 0.5 + math.random(),
                size = 0.2 + math.random()*0.15, collisiondetection = true,
                texture = "vbots_laser_spark.png", glow = 10})
        end
        local ent = nearest:get_luaentity()
        if nearest:is_player() then
            -- P2P: damage player target directly
            local hp_before = nearest:get_hp()
            local hp_after = math.max(0, hp_before - cfg.damage)
            nearest:set_hp(hp_after)
            vbots2.log(meta:get_string("name"), string.format(P .. " DMG player=%s aim=%.1f,%.1f,%.1f hp:%d→%d", nearest:get_player_name(), aim_pos.x, aim_pos.y, aim_pos.z, hp_before, hp_after))
        elseif ent and ent.object then
            local hp_before = ent.object:get_hp()
            local hp_after = math.max(0, hp_before - cfg.damage)
            ent.object:set_hp(hp_after)
            vbots2.log(meta:get_string("name"), string.format(P .. " DMG %s aim=%.1f,%.1f,%.1f hp:%d→%d", tostring(ent.name), aim_pos.x, aim_pos.y, aim_pos.z, hp_before, hp_after))
        end
    end
end

function is_valid_target(ent, obj, player)
    if not ent or not ent.name then return false end
    if ent.name == "__builtin:item" then return false end
    if ent.name:find("^vbots2:") then return false end
    if ent.name:find("^mcl_burning:") then return false end
    if ent.name:find("^mcl_wieldview:") then return false end
    if obj == player then return false end
    if obj:get_player_name() ~= "" then return false end
    return true
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
    if ent.type == "monster" or ent.hostile or ent._is_hostile or ent._attack or ent.passive == false then
        return true
    end
    -- check entity definition (reliable for Mobs Redo/VoxeLibre)
    local def = minetest.registered_entities[ent.name]
    if def then
        if def.type == "monster" then return true end
        if def.hostile or def._attack or def.passive == false then return true end
    end
    vbots2.log("HOSTILE", "false for " .. tostring(ent.name) .. " type=" .. tostring(ent.type) .. " hostile=" .. tostring(ent.hostile) .. " def=" .. tostring(def ~= nil) .. " def.type=" .. tostring(def and def.type))
    return false
end
