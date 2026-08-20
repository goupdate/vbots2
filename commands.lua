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
    -- program slots live in detached inventory botprog_<key> (mirrored to mod_storage)
    local prog_inv = vbots2.prog_inv(meta:get_string("key"))
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
        move_bot(pos,"u")
    elseif item == "vbots2:mode_build" then
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local filter = prog_inv:get_stack("p"..PR, PC):get_name()
        bot_build(pos, 0, filter)
    elseif item == "vbots2:build_behind" then
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local filter = prog_inv:get_stack("p"..PR, PC):get_name()
        bot_build(pos, 0, filter, true)
    elseif item == "vbots2:mode_build_down" then
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local filter = prog_inv:get_stack("p"..PR, PC):get_name()
        bot_build(pos, -1, filter)
    elseif item == "vbots2:mode_build_up" then
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local filter = prog_inv:get_stack("p"..PR, PC):get_name()
        bot_build(pos, 1, filter)
    elseif item == "vbots2:eq_check" then
        local front_node = get_front_node(pos)
        local inv = meta:get_inventory()
        local PR = meta:get_int("PR")
        local PC = meta:get_int("PC")
        local expected = prog_inv:get_stack("p"..PR, PC):get_name()
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
        local expected = prog_inv:get_stack("p"..PR, PC):get_name()
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
                local filter = prog_inv:get_stack("p"..PR, PC):get_name()
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
        local b_val = resolve_value(prog_inv:get_stack("p"..PR, PC), meta)
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
        local var_item = prog_inv:get_stack("p"..PR, PC):get_name()
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
        local var_item = prog_inv:get_stack("p"..PR, PC):get_name()
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
        local filter = prog_inv:get_stack("p"..PR, PC):get_name()
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
        local smeta = prog_inv:get_stack("p"..PR, PC):get_meta()
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
        bot_shoot(pos, meta, {radius=10, damage=10, cooldown_key="laser_last", cooldown_time=4, log_prefix="LASER", is_shot=false})
    elseif item == "vbots2:shot" then
        bot_shoot(pos, meta, {radius=30, damage=40, cooldown_key="shot_last", cooldown_time=6, log_prefix="SHOT", is_shot=true})
    elseif item == "vbots2:damaged_check" then
        local now = minetest.get_gametime()
        local dt = meta:get_float("damage_time")
        if dt > 0 and now - dt < 3.0 then
            meta:set_int("skip", 1)
        else
            meta:set_int("skip", 2)
        end
    elseif item == "vbots2:bug_check" then
        local owner = meta:get_string("owner")
        local player = minetest.get_player_by_name(owner)
        local nearest = player and find_nearest_hostile(pos, 5, player, false)
        if nearest then
            meta:set_int("skip", 1)
        else
            meta:set_int("skip", 2)
        end
elseif item == "vbots2:turn_danger" then
        local now = minetest.get_gametime()
        local dt = meta:get_float("damage_time")
        local owner = meta:get_string("owner")
        local player = minetest.get_player_by_name(owner)
        local radius = 30
        -- multiplier: number item consumed as repeat sits one slot before PC
        local mult_name = prog_inv:get_stack("p" .. meta:get_int("PR"), meta:get_int("PC") - 1):get_name()
        local mult = mult_name:match("^vbots2:number_(%d)$")
        if mult then
            radius = radius * tonumber(mult)
        end
        local nearest = player and find_nearest_hostile(pos, radius, player, false)
        -- recently attacked: prefer the attacker, but only if it is still present
        if dt > 0 and now - dt < 3.0 then
            local dps = meta:get_string("damage_pos")
            if dps ~= "" then
                local ap = minetest.deserialize(dps)
                if ap then
                    local attacker = find_nearest_hostile(ap, 4, player, false)
                    if attacker then
                        bot_face_toward(pos, ap)
                        return
                    end
                end
            end
        end
        -- turn only when a target is actually found (no target = no turn)
        if nearest then
            local ep = nearest:get_pos()
            if ep then
                bot_face_toward(pos, ep)
                return
            end
        end
        -- no hostile nearby: sparks only, bot does NOT turn anywhere
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
