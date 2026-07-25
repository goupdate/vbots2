-- commands.lua � Main command dispatcher. Parses program items and executes bot actions. Includes all command handlers (move, turn, dig, build, conditions, variables, nav, redstone).
 
local function resolve_goto_target(target)
    -- if target is a solid block, stand on top of it
    local tnode = minetest.get_node(target)
    local tdef = minetest.registered_nodes[tnode.name]
    if tdef and tdef.walkable then
        local above = {x = target.x, y = target.y + 1, z = target.z}
        local an = minetest.get_node(above)
        local adef = minetest.registered_nodes[an.name]
        if not adef or not adef.walkable then
            return above
        end
    end
    return target
end

function bot_parsecommand(pos,item)
    local meta = minetest.get_meta(pos)
    local bot_owner = meta:get_string("owner")
    if item == "vbots2:move_forward" then
        move_bot(pos,"f")
    elseif item == "vbots2:move_backward" then
        move_bot(pos,"b")
    elseif item == "vbots2:move_down" then
        move_bot(pos,"d")
    elseif item == "vbots2:move_up" then
        move_bot(pos, "u")
    elseif item == "vbots2:move_home" then
        local home_pos = minetest.deserialize(meta:get_string("home"))
        if home_pos then
            -- find empty spot near home
            local target = home_pos
            if minetest.get_node(target).name ~= "air" then
                for dy = 0, 3 do
                    local check = {x = target.x, y = target.y + dy, z = target.z}
                    if minetest.get_node(check).name == "air" then
                        target = check; break
                    end
                end
            end
            position_bot(pos, target)
        end
    elseif item == "vbots2:turn_clockwise" then
        bot_turn_clockwise(pos)
    elseif item == "vbots2:turn_anticlockwise" then
        bot_turn_anticlockwise(pos)
    elseif item == "vbots2:turn_random" then
        bot_turn_random(pos)
    elseif item == "vbots2:mode_speed" then
        local R = meta:get_int("repeat")
        if R > 0 then
            meta:set_int("repeat",0)
            meta:set_int("steptime",R+1)
        else
            meta:set_int("steptime",2)
        end
    elseif item == "vbots2:mode_dig" then
        bot_dig(pos,0)
        -- skip move if front is container (chest/bot): bot already took items
        local fn, fp = get_front_node(pos)
        local fndef = minetest.registered_nodes[fn.name]
        local is_container = fndef and fndef.groups and fndef.groups.container
        local is_bot = fn.name:find("^vbots2:")
        if not is_container and not is_bot then
            move_bot(pos,"f")
        end
    elseif item == "vbots2:mode_dig_down" then
        bot_dig(pos,-1)
        move_bot(pos,"d")
    elseif item == "vbots2:mode_dig_up" then
        bot_dig(pos,1)
        -- dig only, no move (bot must not fly)
    elseif item == "vbots2:mode_build" then
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local filter = inv:get_stack("p"..PR, PC):get_name()
        bot_build(pos, 0, filter)
    elseif item == "vbots2:build_behind" then
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local filter = inv:get_stack("p"..PR, PC):get_name()
        bot_build(pos, 0, filter, true)
    elseif item == "vbots2:mode_build_down" then
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local filter = inv:get_stack("p"..PR, PC):get_name()
        bot_build(pos, -1, filter)
    elseif item == "vbots2:mode_build_up" then
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local filter = inv:get_stack("p"..PR, PC):get_name()
        bot_build(pos, 1, filter)
    elseif item == "vbots2:eq_check" then
        local front_node = get_front_node(pos)
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local expected = inv:get_stack("p"..PR, PC):get_name()
        if expected == "" then expected = "air" end
        if node_matches(front_node.name, expected) then
            meta:set_int("skip", 1)
        else
            meta:set_int("skip", 2)
        end
    elseif item == "vbots2:neq_check" then
        local front_node = get_front_node(pos)
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local expected = inv:get_stack("p"..PR, PC):get_name()
        if expected == "" then expected = "air" end
        if not node_matches(front_node.name, expected) then
            meta:set_int("skip", 1)
        else
            meta:set_int("skip", 2)
        end
    elseif item == "vbots2:dig_check" then
        local front_node, front_pos = get_front_node(pos)
        local ndef = minetest.registered_nodes[front_node.name]
        if ndef and ndef.groups and ndef.groups.container then
            local chest_inv = minetest.get_inventory({type="node", pos=front_pos})
            if chest_inv then
                local inv = meta:get_inventory()
                local PR = meta:get_int("PR")
                local PC = meta:get_int("PC")
                local filter = inv:get_stack("p"..PR, PC):get_name()
                if filter == "" then filter = "air" end
                local found = false
                local chest_list = chest_inv:get_list("main")
                for i = 1, #chest_list do
                    local stack = chest_list[i]
                    if not stack:is_empty() and stack:get_name() == filter then
                        found = true
                        break
                    end
                end
                if found then
                    meta:set_int("skip", 1)
                else
                    meta:set_int("skip", 2)
                end
            else
                meta:set_int("skip", 2)
            end
        else
            meta:set_int("skip", 2)
        end
    elseif item == "vbots2:gt_check" or item == "vbots2:lt_check" or
             item == "vbots2:gte_check" or item == "vbots2:lte_check" then
        -- left operand from active variable, right from arg slot
        local active = meta:get_string("active_var")
        local a_val = 0
        if active ~= "" then
            a_val = meta:get_int("var_" .. active)
        end
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local b_val = resolve_value(inv:get_stack("p"..PR, PC), meta)
        local result = false
        if item == "vbots2:gt_check" then result = a_val > b_val
        elseif item == "vbots2:lt_check" then result = a_val < b_val
        elseif item == "vbots2:gte_check" then result = a_val >= b_val
        elseif item == "vbots2:lte_check" then result = a_val <= b_val
        end
        if result then
            meta:set_int("skip", 1)
        else
            meta:set_int("skip", 2)
        end
    elseif item == "vbots2:end_program" then
        local PR = meta:get_int("PR")
        if PR ~= 0 then
            pull_state(pos)
        else
            -- find current bot position (may have moved during this tick)
            local cur_pos = pos
            local cn = minetest.get_node(pos)
            if cn.name ~= "vbots2:on" and cn.name ~= "vbots2:off" then
                local key = meta:get_string("key")
                local bi = vbots2.bot_info[key]
                if bi then cur_pos = bi.pos end
            end
            vbots2.bot_togglestate(cur_pos, "off")
        end
    elseif item == "vbots2:var_a" then
        meta:set_string("active_var", "a")
    elseif item == "vbots2:var_b" then
        meta:set_string("active_var", "b")
    elseif item == "vbots2:var_c" then
        meta:set_string("active_var", "c")
    elseif item == "vbots2:var_d" then
        meta:set_string("active_var", "d")
    elseif item == "vbots2:sign_read" then
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local var_item = inv:get_stack("p"..PR, PC):get_name()
        local var_name = var_item:match("var_(.)$")
        if not var_name then
            var_name = meta:get_string("active_var")
        end
        if var_name == "" then var_name = nil end
        local front_node, front_pos = get_front_node(pos)
        local sign_meta = minetest.get_meta(front_pos)
        local text = sign_meta:get_string("text")
        if text == "" and mcl_signs then
            local utext = minetest.deserialize(sign_meta:get_string("utext"), true)
            if utext then text = mcl_signs.ustring_to_string(utext) end
        end
        local num = tonumber(text)
        if num and var_name then
            meta:set_int("var_" .. var_name, num)
        end
    elseif item == "vbots2:sign_print" then
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local var_item = inv:get_stack("p"..PR, PC):get_name()
        local var_name = var_item:match("var_(.)$")
        if not var_name then
            var_name = meta:get_string("active_var")
        end
        local val = 0
        if var_name ~= "" then
            val = meta:get_int("var_" .. var_name)
        end
        local front_node, front_pos = get_front_node(pos)
        local has_sign = front_node.name:find("sign")
        if not has_sign then
            local fdef = minetest.registered_nodes[front_node.name]
            local can_place = (front_node.name == "air" or (fdef and fdef.buildable_to))
            if can_place and not minetest.is_protected(front_pos, meta:get_string("owner")) then
                local sign_name = minetest.registered_nodes["mcl_signs:standing_sign_bamboo"]
                    and "mcl_signs:standing_sign_bamboo"
                    or minetest.registered_nodes["default:sign_wall_wood"]
                    and "default:sign_wall_wood"
                    or nil
                if sign_name then
                    -- standing sign: degrotate, param2 = degrees / 1.5 (from mcl_signs on_place)
                    local wall_dir = minetest.facedir_to_dir(minetest.get_node(pos).param2)
                    local yaw = math.atan2(wall_dir.x, -wall_dir.z)
                    if yaw < 0 then yaw = yaw + 2 * math.pi end
                    local rot = yaw * 180 / math.pi / 1.5
                    local sign_p2 = math.floor(0.5 + rot / 15) * 15
                    minetest.set_node(front_pos, {name = sign_name, param2 = sign_p2})
                    has_sign = true
                end
            end
        end
        if has_sign then
            local sign_meta = minetest.get_meta(front_pos)
            local txt = tostring(val)
            sign_meta:set_string("text", txt)
        sign_meta:set_string("infotext", txt)
        sign_meta:set_string("formspec", "field[text;;${text}]")
        -- VoxeLibre/MCL: set utext + update entity texture
        if mcl_signs then
            sign_meta:set_string("utext", minetest.serialize(mcl_signs.string_to_ustring(txt)))
            if mcl_signs.update_sign then
                mcl_signs.update_sign(front_pos)
            end
        end -- if mcl_signs
        end -- if has_sign
    elseif item == "vbots2:count" then
        -- count items matching the block in the argument slot, store in active_var
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local filter = inv:get_stack("p"..PR, PC):get_name()
        local count = 0
        if filter ~= "" then
            local main = inv:get_list("main")
            for i = 1, #main do
                local s = main[i]
                if not s:is_empty() and s:get_name() == filter then
                    count = count + s:get_count()
                end
            end
        end
        local active = meta:get_string("active_var")
        if active ~= "" then
            meta:set_int("var_" .. active, count)
        end
    elseif item == "vbots2:go_player" then
        local owner = meta:get_string("owner")
        local player = minetest.get_player_by_name(owner)
        if not player then return end
        local pp = player:get_pos()
        local px, py, pz = math.floor(pp.x + 0.5), math.floor(pp.y), math.floor(pp.z + 0.5)
        -- search for empty spot near player
        local found = false
        for dy = 0, 3 do
            for dx = -2, 2 do
                for dz = -2, 2 do
                    local check = {x = px + dx, y = py + dy, z = pz + dz}
                    if minetest.get_node(check).name == "air" and
                       minetest.get_node({x = check.x, y = check.y - 1, z = check.z}).name ~= "air" then
                        position_bot(pos, check)
                        found = true
                        break
                    end
                end
                if found then break end
            end
            if found then break end
        end
    elseif item == "vbots2:goto_pos" then
        local PC = meta:get_int("PC")
        local PR = meta:get_int("PR")
        local inv = meta:get_inventory()
        local smeta = inv:get_stack("p"..PR, PC):get_meta()
        local tx = smeta:get_int("pos_x")
        local ty = smeta:get_int("pos_y")
        local tz = smeta:get_int("pos_z")
        if tx == 0 and ty == 0 and tz == 0 then return end
        local target = {x = tx, y = ty, z = tz}
        -- first try target directly
        if minetest.get_node(target).name == "air" then
            position_bot(pos, target)
        else
            -- search ±1 horizontal circle, then +1y circle
            local found = false
            for dy = 0, 3 do
                for dx = -1, 1 do
                    for dz = -1, 1 do
                        local check = {x = tx + dx, y = ty + dy, z = tz + dz}
                        if check.x == tx and check.y == ty and check.z == tz then
                            -- skip the target itself (already checked)
                        elseif minetest.get_node(check).name == "air" then
                            position_bot(pos, check)
                            found = true
                            break
                    end -- if check is air
                end -- for dz
            end -- for dx
            end -- for dy
        end -- if air
    elseif item == "vbots2:laser" then
        vbots2.log(meta:get_string("name"), "LASER FIRING at " .. pos.x .. "," .. pos.y .. "," .. pos.z)
        local now = minetest.get_gametime()
        local last = meta:get_float("laser_last")
        if now - last < 2.0 then
            -- cooldown: show recharge sparks
            vbots2.log(meta:get_string("name"), "LASER COOLDOWN")
            minetest.add_particlespawner({amount = 3, time = 0.2,
                minpos = {x = pos.x - 0.2, y = pos.y + 0.4, z = pos.z - 0.2},
                maxpos = {x = pos.x + 0.2, y = pos.y + 0.8, z = pos.z + 0.2},
                minvel = {x = -0.5, y = 1, z = -0.5}, maxvel = {x = 0.5, y = 3, z = 0.5},
                minacc = {x = 0, y = -2, z = 0}, maxacc = {x = 0, y = -5, z = 0},
                minexptime = 0.3, maxexptime = 0.6, minsize = 0.5, maxsize = 1,
                collisiondetection = false, texture = "vbots_laser_spark.png", glow = 14})
            return
        end
        meta:set_float("laser_last", now)
        local owner = meta:get_string("owner")
        local player = minetest.get_player_by_name(owner)
        if not player then return end
        local facing_dir = minetest.facedir_to_dir(minetest.get_node(pos).param2)
        -- find nearest hostile in 5 blocks, within 90° cone
        local nearest, nearest_dist = nil, 999
        local total_nearby = 0
        local all_ents = minetest.get_objects_inside_radius(pos, 10)
        vbots2.log(meta:get_string("name"), "LASER SCAN radius=10 found=" .. #all_ents)
        for _, obj in ipairs(all_ents) do
            local ename = "?"
            local ent = nil
            if obj and obj:get_luaentity() then
                ent = obj:get_luaentity()
                ename = ent.name or "?"
            elseif obj and obj:get_player_name() then
                ename = "player:" .. obj:get_player_name()
            end
            vbots2.log(meta:get_string("name"), "LASER ENTITY: " .. ename)
            if ent then
                vbots2.log(meta:get_string("name"), "LASER CHECK name=" .. (ent.name or "nil") .. " isplayer=" .. tostring(obj:get_player_name() or "no"))
                if is_valid_target(ent, obj, player) then
                    total_nearby = total_nearby + 1
                    if is_hostile_entity(ent) then
                        local epos = obj:get_pos()
                        if epos then
                            local to_target = {x = epos.x - pos.x, y = epos.y - pos.y, z = epos.z - pos.z}
                            local d = vector.length(to_target)
                            if d > 0 then
                                to_target = vector.normalize(to_target)
                                local dot = -(facing_dir.x * to_target.x + facing_dir.y * to_target.y + facing_dir.z * to_target.z)
                                if dot >= 0.707 then -- 90° cone (cos 45°)
                                    if d < nearest_dist then nearest, nearest_dist = obj, d end
                                end
                            end
                        end
                    else
                        vbots2.log(meta:get_string("name"), "LASER IGNORE " .. ent.name .. " not hostile")
                    end
                end
            end
        end
        if not nearest then
            vbots2.log(meta:get_string("name"), "LASER NO TARGET nearby=" .. total_nearby)
            return end
        local tpos = nearest:get_pos()
        local aim_pos = {x = tpos.x, y = (tpos.y or 0) + 1, z = tpos.z}
        vbots2.log(meta:get_string("name"), "LASER target at " .. aim_pos.x .. "," .. aim_pos.y .. "," .. aim_pos.z .. " entity=" .. nearest:get_luaentity().name)
        -- beam particles toward center of target (from bot eye level)
        local eye = {x = pos.x, y = pos.y + 0.6, z = pos.z}
        local beam = vector.subtract(aim_pos, eye); local blen = vector.length(beam)
        local bdir = vector.normalize(beam)
        -- LOS check FIRST: step-through at 0.2 block intervals
        -- beam particles
        for i = 0, math.floor(blen * 8) do
            local p = vector.add(pos, vector.multiply(bdir, i * 0.125))
            minetest.add_particle({pos = p, velocity = {x=0,y=0,z=0},
                acceleration = {x=0,y=0,z=0}, expirationtime = 1.0,
                size = 0.7 + math.random() * 0.3, collisiondetection = false,
                texture = "vbots_laser_spark.png", glow = 14})
        end
        -- LOS check: block laser through walls (pass through plants/grass/air)
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
                        blocked = true
                        break
                    end
                end
            end
        end
        if blocked then
            vbots2.log(meta:get_string("name"), "LASER BLOCKED")
            -- wall sparks
            minetest.add_particlespawner({amount = 5, time = 0.3,
                minpos = {x = pos.x - 0.2, y = pos.y + 0.4, z = pos.z - 0.2},
                maxpos = {x = pos.x + 0.2, y = pos.y + 0.8, z = pos.z + 0.2},
                minvel = {x = -0.5, y = 1, z = -0.5}, maxvel = {x = 0.5, y = 3, z = 0.5},
                minacc = {x = 0, y = -2, z = 0}, maxacc = {x = 0, y = -5, z = 0},
                minexptime = 0.3, maxexptime = 0.6, minsize = 0.5, maxsize = 1,
                collisiondetection = false, texture = "vbots_laser_spark.png", glow = 14})
            return
        end
        -- impact sparks
        for i = 1, 12 do
            minetest.add_particle({pos = aim_pos,
                velocity = {x=math.random()-0.5, y=math.random()*2+1, z=math.random()-0.5},
                acceleration = {x=0, y=-6, z=0}, expirationtime = 0.5 + math.random(),
                size = 0.2 + math.random()*0.15, collisiondetection = true,
                texture = "vbots_laser_spark.png", glow = 10})
        end
        -- direct damage (skip MCL punch system which crashes on nil hitter)
        local ent = nearest:get_luaentity()
        if ent and ent.object then
            local hp_before = ent.object:get_hp()
            local hp_after = math.max(0, hp_before - 10)
            ent.object:set_hp(hp_after)
            vbots2.log(meta:get_string("name"), string.format("LASER DMG %s aim=%.1f,%.1f,%.1f hp:%d→%d", tostring(ent.name), aim_pos.x, aim_pos.y, aim_pos.z, hp_before, hp_after))
        end
        meta:set_float("laser_last", now)
    elseif item == "vbots2:shot" then
        vbots2.log(meta:get_string("name"), "SHOT FIRING at " .. pos.x .. "," .. pos.y .. "," .. pos.z)
        local owner = meta:get_string("owner")
        local player = minetest.get_player_by_name(owner)
        if not player then return end
        local facing_dir = minetest.facedir_to_dir(minetest.get_node(pos).param2)
        -- find nearest hostile in 20 blocks, within 90° cone
        local nearest, nearest_dist = nil, 999
        local all_ents = minetest.get_objects_inside_radius(pos, 20)
        vbots2.log(meta:get_string("name"), "SHOT SCAN radius=20 found=" .. #all_ents)
        for _, obj in ipairs(all_ents) do
            if obj and obj:get_luaentity() then
                local ent = obj:get_luaentity()
                vbots2.log(meta:get_string("name"), "SHOT ENTITY: " .. (ent.name or "?"))
                 if ent.name ~= "__builtin:item"
                     and is_valid_target(ent, obj, player)
                     and is_hostile_entity(ent) then
                        local epos = obj:get_pos()
                        if epos then
                            local to_target = {x = epos.x - pos.x, y = epos.y - pos.y, z = epos.z - pos.z}
                            local d = vector.length(to_target)
                            if d > 0 then
                                to_target = vector.normalize(to_target)
                                local fdot = -(facing_dir.x * to_target.x + facing_dir.y * to_target.y + facing_dir.z * to_target.z)
                                vbots2.log(meta:get_string("name"), "SHOT CANDIDATE " .. (ent.name or "?") .. " dist=" .. math.floor(d) .. " fdot=" .. string.format("%.2f", fdot))
                                if fdot >= 0.707 then -- 90° cone (cos 45°)
                                    if d < nearest_dist then nearest, nearest_dist = obj, d end
                                end
                        end
                    end
                end
            end
        end
        if not nearest then
            -- no target: sparks from bot
            vbots2.log(meta:get_string("name"), "SHOT NO TARGET in cone")
            minetest.add_particlespawner({amount = 5, time = 0.3,
                minpos = {x = pos.x - 0.2, y = pos.y + 0.4, z = pos.z - 0.2},
                maxpos = {x = pos.x + 0.2, y = pos.y + 0.8, z = pos.z + 0.2},
                minvel = {x = -0.5, y = 1, z = -0.5}, maxvel = {x = 0.5, y = 3, z = 0.5},
                minacc = {x = 0, y = -2, z = 0}, maxacc = {x = 0, y = -5, z = 0},
                minexptime = 0.3, maxexptime = 0.6, minsize = 0.5, maxsize = 1,
                collisiondetection = false, texture = "vbots_laser_spark.png", glow = 14})
            return
        end
        -- throw dark snowball: 5x slower than arrow (arrow speed ~20, so 4 m/s)
        local tpos = nearest:get_pos()
        local tent2 = nearest:get_luaentity()
        vbots2.log(meta:get_string("name"), "SHOT TARGET " .. (tent2 and tent2.name or "?") .. " at " .. string.format("%.1f,%.1f,%.1f", tpos.x, tpos.y, tpos.z))
        local dir = vector.subtract(tpos, pos)
        local dlen = vector.length(dir)
        if dlen == 0 then return end
        dir = vector.normalize(dir)
        -- spawn dark snowball entity at bot midpoint heading toward target
        local spawn_pos = {x = pos.x, y = pos.y + 0.6, z = pos.z}
        -- parabolic: 1 block drop per 10 blocks forward at speed=25, gravity~-22
        local speed = 25
        local vel = {x = dir.x * speed, y = dir.y * speed + 9, z = dir.z * speed}
        local obj = minetest.add_entity(spawn_pos, "vbots2:projectile_snowball")
        if obj then
            vbots2.log(meta:get_string("name"), "SHOT SPAWNED vel=" .. string.format("%.0f,%.0f,%.0f", vel.x, vel.y, vel.z))
            obj:set_velocity(vel)
            local tent = obj:get_luaentity()
            if tent then
                tent._damage = 12
                tent._shooter = player
            end
        else
            vbots2.log(meta:get_string("name"), "SHOT FAILED to spawn projectile")
        end
    elseif item == "vbots2:damaged_check" then
        local now = minetest.get_gametime()
        local dt = meta:get_float("damage_time")
        if dt > 0 and now - dt < 3.0 then
            meta:set_int("skip", 1)
        else
            meta:set_int("skip", 2)
        end
    elseif item == "vbots2:turn_danger" then
        local now = minetest.get_gametime()
        local dt = meta:get_float("damage_time")
        if dt > 0 and now - dt < 3.0 then
            local dps = meta:get_string("damage_pos")
            if dps ~= "" then
                local ap = minetest.deserialize(dps)
                if ap then
                    local dx = ap.x - pos.x; local dz = ap.z - pos.z
                    if math.abs(dx) > math.abs(dz) then
                        if dx > 0 then bot_turn_clockwise(pos); bot_turn_clockwise(pos);
                        else bot_turn_anticlockwise(pos); bot_turn_anticlockwise(pos); end
                    else
                        if dz > 0 then bot_turn_clockwise(pos); bot_turn_clockwise(pos);
                        else bot_turn_anticlockwise(pos); bot_turn_anticlockwise(pos); end
                    end
                    return
                end
            end
        end
        -- no recent attack: find nearest hostile in 20 blocks instead
        local owner = meta:get_string("owner")
        local player = minetest.get_player_by_name(owner)
        local nearest, nearest_dist = nil, 999
        if player then
            for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 20)) do
                if obj and obj:get_luaentity() then
                    local ent = obj:get_luaentity()
                if ent.name ~= "__builtin:item"
                    and is_valid_target(ent, obj, player) then
                        local epos = obj:get_pos()
                        if epos then
                            local d = vector.distance(pos, epos)
                            if d < nearest_dist then nearest, nearest_dist = obj, d end
                        end
                    end
                end
            end
        end
        if nearest then
            local ep = nearest:get_pos()
            if ep then
                local dx = ep.x - pos.x; local dz = ep.z - pos.z
                if math.abs(dx) > math.abs(dz) then
                    if dx > 0 then bot_turn_clockwise(pos); bot_turn_clockwise(pos);
                    else bot_turn_anticlockwise(pos); bot_turn_anticlockwise(pos); end
                else
                    if dz > 0 then bot_turn_clockwise(pos); bot_turn_clockwise(pos);
                    else bot_turn_anticlockwise(pos); bot_turn_anticlockwise(pos); end
                end
                return
            end
        end
        -- no target: sparks
        minetest.add_particlespawner({amount = 5, time = 0.3,
            minpos = {x = pos.x - 0.2, y = pos.y + 0.4, z = pos.z - 0.2},
            maxpos = {x = pos.x + 0.2, y = pos.y + 0.8, z = pos.z + 0.2},
            minvel = {x = -0.5, y = 1, z = -0.5}, maxvel = {x = 0.5, y = 3, z = 0.5},
            minacc = {x = 0, y = -2, z = 0}, maxacc = {x = 0, y = -5, z = 0},
            minexptime = 0.3, maxexptime = 0.6, minsize = 0.5, maxsize = 1,
            collisiondetection = false, texture = "vbots_laser_spark.png", glow = 14})
    elseif item == "vbots2:redstone_toggle" then
        local owner = meta:get_string("owner")
        local player = minetest.get_player_by_name(owner)
        if player then
            local front_node, front_pos = get_front_node(pos)
            local ndef = minetest.registered_nodes[front_node.name]
            if ndef and ndef.on_rightclick then
                ndef.on_rightclick(front_pos, front_node, player)
            end
        end
    end
    local fnum = item:match("^vbots2:f(%d)$")
    if fnum then
        local PC = meta:get_int("PC")
        local PR = meta:get_int("PR")
        local R = meta:get_int("repeat")
        push_state(pos,PC,PR,R)
        meta:set_int("PR", tonumber(fnum))
        meta:set_int("PC", 0)
        meta:set_int("repeat", 0)
    end
end
