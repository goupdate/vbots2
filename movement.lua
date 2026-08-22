-- movement.lua � Bot movement: position swap (smooth node transfer), directional moves, turns
 
function bot_turn_clockwise(pos)
    local node = minetest.get_node(pos)
    local newface = (node.param2+1)%4
    facebot(newface,pos)
end

function bot_turn_anticlockwise(pos)
    local node = minetest.get_node(pos)
    local newface = (node.param2-1)%4
    facebot(newface,pos)
end

function bot_turn_random(pos)
    if math.random(2)==1 then
        bot_turn_clockwise(pos)
    else
        bot_turn_anticlockwise(pos)
    end
end

-- Turn the bot to face a target position (minimal rotation: 0/90/180 deg).
function bot_face_toward(pos, target_pos)
    local dx = target_pos.x - pos.x; local dz = target_pos.z - pos.z
    -- dominant axis sets target param2 (see AGENTS.md Bot facedir direction)
    local target
    if math.abs(dx) > math.abs(dz) then      -- if east/west dominates
        target = dx > 0 and 3 or 1          -- face +X (param2=3, visual front +X) / -X (param2=1, visual front -X)
    else                                    -- if east/west dominates
        target = dz > 0 and 2 or 0          -- face +Z / -Z
    end                                     -- if east/west dominates
    local cur = minetest.get_node(pos).param2 % 4
    local delta = (target - cur) % 4
    if delta == 1 then bot_turn_clockwise(pos)
    elseif delta == 2 then bot_turn_clockwise(pos); bot_turn_clockwise(pos)  -- if delta
    elseif delta == 3 then bot_turn_anticlockwise(pos) end  -- if delta
end

-- Find nearest hostile entity within radius. If in_front_only, only consider
-- targets inside the bot's 90deg frontal cone (fdot >= 0.707).
-- In P2P mode (meta pvp=1) any other player is a hostile target too.
function find_nearest_hostile(pos, radius, player, in_front_only)
    local nearest, nearest_dist = nil, 999
    local meta = minetest.get_meta(pos)
    local pvp = meta:get_int("pvp") == 1
    local owner = meta:get_string("owner")
    local facing_dir
    if in_front_only then
        facing_dir = minetest.facedir_to_dir(minetest.get_node(pos).param2)
    end
    for _, obj in ipairs(minetest.get_objects_inside_radius(pos, radius)) do  -- loop over objects
        local hostile = false
        if obj and obj:is_player() then                     -- if player object
            local pname = obj:get_player_name()
            hostile = pvp and pname ~= "" and pname ~= owner
        elseif obj and obj:get_luaentity() then             -- if object has luaentity
            local ent = obj:get_luaentity()
            -- In PvP mode, enemy bots (vbots2:bot_body owned by other players) are hostile too
            if pvp and ent.name == "vbots2:bot_body" then -- if enemy bot
                local bot_owner = vbots2._bot_body_owner and vbots2._bot_body_owner[obj]
                hostile = bot_owner ~= nil and bot_owner ~= "" and bot_owner ~= owner
            else                                          -- if enemy bot
                hostile = is_valid_target(ent, obj, player) and is_hostile_entity(ent)
            end                                           -- if enemy bot
        end                                                 -- if player object
        if hostile then                                     -- if hostile target
            local epos = obj:get_pos()
            if epos then                        -- if position present
                local d = vector.distance(pos, epos)
                local consider = true
                if in_front_only and d > 0 then  -- if cone filter
                    local to_target = vector.normalize({x = epos.x - pos.x, y = epos.y - pos.y, z = epos.z - pos.z})
                    local fdot = -(facing_dir.x * to_target.x + facing_dir.y * to_target.y + facing_dir.z * to_target.z)
                    consider = fdot >= 0.5                      -- 120° cone (cos 60°)
                elseif in_front_only then       -- if cone filter
                    consider = false
                end                             -- if cone filter
                if consider and d < nearest_dist then  -- if best so far
                    nearest, nearest_dist = obj, d
                end                             -- if best so far
            end                                 -- if position present
        end                                     -- if hostile target
    end                                             -- loop over objects
    return nearest
end

function position_bot(pos,newpos)
    local meta = minetest.get_meta(pos)
    local R = meta:get_int("steptime")
    local bot_owner = meta:get_string("owner")
    local bot_key = meta:get_string("key")
    -- close formspec before moving to prevent engine crash
    -- (formspec references nodemeta:<pos> which becomes invalid after set_node)
    local player = minetest.get_player_by_name(bot_owner)
    if player and bot_key ~= "" then
        minetest.close_formspec(bot_owner, bot_key)
    end
    if not minetest.is_protected(newpos, bot_owner) then
        -- ram: deal max damage to mobs at destination (and players in P2P mode)
        local pvp = meta:get_int("pvp") == 1
        local mobs = minetest.get_objects_inside_radius(newpos, 0.8)
        for _, obj in ipairs(mobs) do
            local hit = false
            if obj and obj:is_player() then          -- if player object
                local pname = obj:get_player_name()
                hit = pvp and pname ~= "" and pname ~= bot_owner
            elseif obj and obj:get_luaentity() then  -- if mob entity
                local ent = obj:get_luaentity()
                -- punch mobs (skip items and this bot's own entities)
                if ent.name ~= "__builtin:item" and ent.name ~= "vbots2:minimap_marker"
                        and ent.name ~= "vbots2:bot_body"
                        and obj ~= player then
                    hit = true
                end
            end                                      -- if player object
            if hit then                              -- if hittable
                obj:punch(obj, 1.0, {full_punch_interval = 0.1, damage_groups = {fleshy = 100}}, nil)
            end                                      -- if hittable
        end                                          -- loop over objects
        local moveto_node = minetest.get_node(newpos)
        -- cut plants on the way
        local is_plant = false
        local ndef = minetest.registered_nodes[moveto_node.name]
        if ndef and ndef.groups then
            is_plant = ndef.groups.flora or ndef.groups.grass or ndef.groups.plant or
                       ndef.groups.flower or ndef.groups.sapling or ndef.groups.leaves
        end
        local is_door = ndef and ndef.groups and ndef.groups.door
        if moveto_node.name == "air" or is_plant or is_door or is_walkable(newpos) then
            -- dig through non-plant walkable nodes (leaves, foliage, etc.)
            if not is_plant and not is_door and moveto_node.name ~= "air" then
                minetest.set_node(newpos, {name = "air"})
            end
            -- handle door: open → move bot through → close behind
            if is_door and player then
                local door_def = minetest.registered_nodes[moveto_node.name]
                -- open door
                if door_def and door_def.on_rightclick then
                    door_def.on_rightclick(newpos, moveto_node, player)
                end
                -- save door state (both bottom + top parts)
                local door_top_pos = {x = newpos.x, y = newpos.y + 1, z = newpos.z}
                local door_bottom = minetest.get_node(newpos)
                local door_top = minetest.get_node(door_top_pos)
                -- move bot to door position
                local bot_node = minetest.get_node(pos)
                local hold = meta:to_table()
                meta:set_string("moving", "1")
                minetest.set_node(newpos, {name = bot_node.name, param2 = bot_node.param2})
                minetest.get_node_timer(newpos):set(1/R, 0)
                if hold then
                    minetest.get_meta(newpos):from_table(hold)
                end
                minetest.set_node(door_top_pos, {name = "air"})
                -- place door at old bot position
                minetest.set_node(pos, {name = door_bottom.name, param2 = door_bottom.param2})
                if door_top.name ~= "air" then
                    minetest.set_node({x = pos.x, y = pos.y + 1, z = pos.z}, {name = door_top.name, param2 = door_top.param2})
                end
                -- close door behind
                local behind_node = minetest.get_node(pos)
                local behind_def = minetest.registered_nodes[behind_node.name]
                if behind_def and behind_def.on_rightclick then
                    behind_def.on_rightclick(pos, behind_node, player)
                end
                -- keep bot_info position in sync so removeall/formspec find the bot
                if vbots2.bot_info[bot_key] then
                    vbots2.bot_info[bot_key].pos = newpos
                end
                minetest.check_for_falling(newpos)
                return
            end
            if is_plant then
                local drops = minetest.get_node_drops(moveto_node.name, "")
                local inv = minetest.get_inventory({type="node", pos=pos})
                for _, itemname in ipairs(drops) do
                    bot_add_items(inv, "main", ItemStack(itemname))
                end
                minetest.set_node(newpos, {name="air"})
            end
            local node = minetest.get_node(pos)
            local hold = meta:to_table()
            -- prevent on_destruct from dropping inventory during move
            meta:set_string("moving", "1")
            -- smooth: place new node first, then remove old after brief overlap
            minetest.set_node(newpos,{name=node.name, param2=node.param2})
            minetest.get_node_timer(newpos):set(1/R,0)
            if hold then
                minetest.get_meta(newpos):from_table(hold)
            end
            minetest.set_node(pos,{name="air"})
            -- keep bot_info position in sync so removeall/formspec find the bot
            if vbots2.bot_info[bot_key] then
                vbots2.bot_info[bot_key].pos = newpos
            end
        else
            minetest.sound_play("error",{pos = newpos, gain = 10})
        end
        minetest.check_for_falling(newpos)
    else
        minetest.sound_play("system-fault",{pos = newpos, gain = 10})
    end
end


function move_bot(pos,direction)
    local meta = minetest.get_meta(pos)
    local bot_owner = meta:get_string("owner")
    local player = minetest.get_player_by_name(bot_owner)
    -- print(bot_owner)
    local ppos
    if player then
        ppos = player:get_pos()
        -- print(dump(pos))
        -- print(dump(ppos))
    end
    local node = minetest.get_node(pos)
    local dir = minetest.facedir_to_dir(node.param2)
    local newpos
    if direction == "u" then
        newpos = {x = pos.x, y = pos.y+1, z = pos.z}
    elseif direction == "d" then
        newpos = {x = pos.x, y = pos.y-1, z = pos.z}
    elseif direction == "f" then
        newpos = {x = pos.x-dir.x, y = pos.y, z = pos.z-dir.z}
    elseif direction == "b" then
        newpos = {x = pos.x+dir.x, y = pos.y, z = pos.z+dir.z}
    end
    if newpos then
        position_bot(pos,newpos)
    end
    if ppos then
        if math.abs(ppos.x-pos.x)<1.1 and
                math.abs(ppos.z-pos.z)<1.1 and
                math.abs(ppos.y-pos.y)<2 and
                ppos.y>pos.y then
            player:setpos({x=newpos.x, y=newpos.y+1.1, z=newpos.z })
        end
    end
end
