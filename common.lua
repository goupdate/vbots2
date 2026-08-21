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
        vbots2.log(meta:get_string("name"), P .. " miss")
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
        vbots2.log(meta:get_string("name"), P .. " miss")
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
                tent._bot_pos = pos        -- for kill detection in on_step
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
        local bot_name = meta:get_string("name")
        local ld = meta:get_float("laser_damage")
        local sd = meta:get_float("shot_damage")
        local mh = meta:get_float("max_hp")
        if nearest:is_player() then
            -- P2P: damage player target directly
            local hp_before = nearest:get_hp()
            local hp_after = math.max(0, hp_before - cfg.damage)
            nearest:set_hp(hp_after)
            local tname = nearest:get_player_name()
            vbots2.log(bot_name, string.format("LASER hit %s dmg=%.1f left=%d ★%.2f ❄%.2f ♥%.2f", tname, cfg.damage, hp_after, ld, sd, mh))
            if hp_after == 0 and hp_before > 0 then
                update_bot_kill_stats(meta, pos, true, "player")        -- laser kill
                local nld = meta:get_float("laser_damage")
                local nmh = meta:get_float("max_hp")
                local upd = ""
                if nld ~= ld then upd = upd .. string.format("★%.2f→%.2f", ld, nld) end
                if nmh ~= mh then upd = upd .. (upd ~= "" and " " or "") .. string.format("♥%.2f→%.2f", mh, nmh) end
                vbots2.log(bot_name, "LASER kill " .. tname .. " upd " .. upd)
            end                                                         -- if killed
        elseif ent and ent.object then
            local hp_before = ent.object:get_hp()
            local hp_after = math.max(0, hp_before - cfg.damage)
            ent.object:set_hp(hp_after)
            local target_pos = nearest:get_pos()
            if target_pos then
                local lost = hp_before - hp_after
                if lost <= 0 then
                    bot_show_damage_number(target_pos, "-0")
                else
                    bot_show_damage_number(target_pos, "-" .. string.format("%.1f", lost))
                end                                                         -- if lost > 0
            end                                                             -- if target_pos
            local tname = tostring(ent.name)
            vbots2.log(bot_name, string.format("LASER hit %s dmg=%.1f left=%d ★%.2f ❄%.2f ♥%.2f", tname, cfg.damage, hp_after, ld, sd, mh))
            if hp_after == 0 and hp_before > 0 then
                update_bot_kill_stats(meta, pos, true, tname)          -- laser kill
                local nld = meta:get_float("laser_damage")
                local nmh = meta:get_float("max_hp")
                local upd = ""
                if nld ~= ld then upd = upd .. string.format("★%.2f→%.2f", ld, nld) end
                if nmh ~= mh then upd = upd .. (upd ~= "" and " " or "") .. string.format("♥%.2f→%.2f", mh, nmh) end
                vbots2.log(bot_name, "LASER kill " .. tname .. " upd " .. upd)
            end                                                         -- if killed
        end
    end
end

-------------------------------------
-- Line-of-sight: check if bot has a clear view to a target point.
-- Only air, liquids, and passable-through nodes (flora, grass, plant,
-- flower, torch, attached_node, leaves) are transparent — any other
-- walkable node blocks the view.
-- Used by laser, shot, and turn_danger.
-------------------------------------
function has_clear_los(pos, tpos)
    local eye = {x = pos.x, y = pos.y + 0.6, z = pos.z}
    local aim_pos = {x = tpos.x, y = (tpos.y or 0) + 1, z = tpos.z}
    local beam_vec = vector.subtract(aim_pos, eye)
    local beam_len = vector.length(beam_vec)
    if beam_len == 0 then return true end
    local beam_dir = vector.normalize(beam_vec)
    for s = 1, math.floor(beam_len * 2) do                 -- loop along beam
        local p = vector.add(eye, vector.multiply(beam_dir, s * 0.5))
        local pnode = minetest.get_node({x=math.floor(p.x+0.5), y=math.floor(p.y+0.5), z=math.floor(p.z+0.5)})
        local pndef = minetest.registered_nodes[pnode.name]
        if pndef and pndef.walkable then                    -- if walkable
            local g = pndef.groups or {}
            if not g.flora and not g.grass and not g.plant and not g.flower and not g.torch and not g.attached_node and not g.leaves then
                return false                                -- blocked by solid wall
            end                                             -- if non-passable walkable
        end                                                 -- if walkable
    end                                                     -- loop along beam
    return true
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

-------------------------------------
-- Show floating damage number above an entity position (RPG-style).
-- New numbers appear above old ones (Y-offset stacks), fade after 1s.
-------------------------------------
local _dmg_stack = {} -- Y-offset per position-key (x..","..z)
function bot_show_damage_number(near_pos, text)
    local key = math.floor(near_pos.x + 0.5) .. "," .. math.floor(near_pos.z + 0.5)
    _dmg_stack[key] = (_dmg_stack[key] or 0) + 0.25
    if _dmg_stack[key] > 3.0 then _dmg_stack[key] = 0.25 end
    local y_off = _dmg_stack[key]
    local spawn_y = near_pos.y + 2.0 + y_off
    local obj = minetest.add_entity({x=near_pos.x, y=spawn_y, z=near_pos.z}, "vbots2:damage_text")
    if obj then
        obj:set_properties({nametag = text, nametag_color = "#FF3333"})
    end                                                                 -- if obj spawned
end                                                                     -- function bot_show_damage_number

-------------------------------------
-- Update bot kill stats: level-based progression with victim-dependent growth.
--  Level = floor(sqrt(total_kills)) + 1
--  Growth rates:  player=1.0,  creeper=0.4,  spider=0.3,  skeleton=0.25,  default=0.15
--  Stats from level:
--    laser = min(36, 3 + (lv-1)*1.5)
--    shot  = min(21, 2 + (lv-1)*0.9)
--    HP    = min(27, 10 + (lv-1)*0.8)   -- bot_body uses floor of this value
--    armor = min(5, floor((lv-1)/4))
--  victim_name: "player" for player kills, or entity name (e.g. "mobs_mc:creeper")
--  is_laser: true for laser kill, false for shot kill (increments specific counter + log)
-------------------------------------
function update_bot_kill_stats(meta, bot_pos, is_laser, victim_name)
    -- determine growth rate from victim type
    local rate = 0.15                                              -- default: zombie, misc
    if victim_name == "player" then
        rate = 1.0
    elseif victim_name then
        if victim_name:find("creeper") then rate = 0.4
        elseif victim_name:find("spider") then rate = 0.3
        elseif victim_name:find("skeleton") then rate = 0.25
        end                                                        -- if creeper/spider/skeleton
    end                                                            -- if victim_name not player

    local kills = (meta:get_float("total_kills") or 0) + rate
    meta:set_float("total_kills", kills)

    local level = math.floor(math.sqrt(kills + 0.01)) + 1
    if level < 1 then level = 1 end                                -- if level underflow

    -- recalculate all stats from level (deterministic, not incremental)
    local laser_dmg = math.min(36, 3 + (level - 1) * 1.5)
    local shot_dmg  = math.min(21, 2 + (level - 1) * 0.9)
    local max_hp    = math.min(27, 10 + (level - 1) * 0.8)
    local armor     = math.min(5, math.floor((level - 1) / 4))

    meta:set_float("laser_damage", laser_dmg)
    meta:set_float("shot_damage", shot_dmg)
    meta:set_float("max_hp", max_hp)
    meta:set_int("armor", armor)

    -- increment specific kill counter (for log display)
    local kill_field = is_laser and "laser_kills" or "shot_kills" -- which kill counter
    meta:set_int(kill_field, (meta:get_int(kill_field) or 0) + 1)

    -- Update bot_body entity HP in the world (use floor for integer HP)
    local bot_key = meta:get_string("key")
    for _, obj in ipairs(minetest.get_objects_inside_radius(bot_pos, 0.5)) do
        local ent = obj:get_luaentity()
        if ent and ent.name == "vbots2:bot_body" and ent._key == bot_key then
            obj:set_hp(math.floor(max_hp))
            -- update label entity above bot after stat change
            vbots2.update_bot_label(bot_pos)
            break
        end -- if bot_body match
    end -- loop over objects at bot_pos
end -- function update_bot_kill_stats

-------------------------------------
-- Derive level-based combat ranges from kill stats.
-- Laser: 3 + 0.5/level (min 3); Shot: 5 + 0.5/level (min 5);
-- Danger detection: max(shot_range, 10).
--------------------------------------
function vbots2.compute_bot_stats(meta)
    local kills = meta:get_float("total_kills") or 0
    local level = math.floor(math.sqrt(kills + 0.01)) + 1
    local laser_range = 3 + 0.5 * (level - 1)
    local shot_range = 5 + 1.0 * (level - 1)
    local danger_range = math.max(shot_range, 10)
    return level, laser_range, shot_range, danger_range
end -- function vbots2.compute_bot_stats

-------------------------------------
-- Bot label visibility: show only to owner, within 5 blocks radius.
-- Runs every 0.5s to keep overhead minimal.
--------------------------------------
local label_timer = 0
minetest.register_globalstep(function(dtime)
    label_timer = label_timer + dtime
    if label_timer < 0.5 then return end; label_timer = 0
    if not vbots2._bot_labels then return end
    for key, obj in pairs(vbots2._bot_labels) do
        if not obj or not obj:get_pos() then
            vbots2._bot_labels[key] = nil                    -- dead entity
        else
            local pos = obj:get_pos()
            local ent = obj:get_luaentity()
            if ent then
                local owner = ent._owner
                local visible = false
                if owner then
                    for _, player in ipairs(minetest.get_connected_players()) do
                        local pname = player:get_player_name()
                        if pname == owner and vector.distance(player:get_pos(), pos) <= 5 then
                            visible = true; break
                        end                                                 -- if owner nearby
                    end                                                     -- loop over players
                end                                                         -- if owner set
                if visible then
                    obj:set_properties({nametag = ent._tag})
                else
                    obj:set_properties({nametag = ""})
                end                                                         -- if visible
            end                                                             -- if ent exists
        end                                                             -- if obj alive
    end                                                                 -- loop over labels
end)                                                                    -- globalstep
