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
    elseif item == "vbots2:move_home" then
        local PC = meta:get_int("PC")
        local PR = meta:get_int("PR")
        local hx = meta:get_int("home_tx")
        local hy = meta:get_int("home_ty")
        local hz = meta:get_int("home_tz")
        if hx == 0 and hy == 0 and hz == 0 then
            -- first call: read home pos from meta
            local home_pos = minetest.deserialize(meta:get_string("home"))
            if not home_pos then return end -- if no home set
            hx = home_pos.x; hy = home_pos.y; hz = home_pos.z
            meta:set_int("home_tx", hx)
            meta:set_int("home_ty", hy)
            meta:set_int("home_tz", hz)
            meta:set_int("nav_active", 1)
            meta:set_int("nav_pr", PR)
        end -- if hx == 0
        local target = {x = hx, y = hy, z = hz}
        local node = minetest.get_node(pos)
        local facing = node.param2

        local dx = math.abs(pos.x - target.x)
        local dy = math.abs(pos.y - target.y)
        local dz = math.abs(pos.z - target.z)
        if dy <= 1 and ((dx == 0 and dz <= 1) or (dz == 0 and dx <= 1)) then
            meta:set_int("nav_active", 0)
            meta:set_int("home_tx", 0)
            meta:set_int("home_ty", 0)
            meta:set_int("home_tz", 0)
            meta:set_string("nav_path", "")
            meta:set_int("PC", PC - 1)
            return
        end -- if at goal

        local nav = meta:get_string("nav_path")
        if nav ~= "" then
            local actions = string.split(nav, ",")
            if #actions > 0 then
                local act = actions[1]
                table.remove(actions, 1)
                meta:set_string("nav_path", table.concat(actions, ","))
                if act == "f" then move_bot(pos, "f")
                elseif act == "j" then
                    local jn = minetest.get_node(pos)
                    local jd = minetest.facedir_to_dir(jn.param2)
                    position_bot(pos, {x = pos.x - jd.x, y = pos.y + 1, z = pos.z - jd.z})
                elseif act == "d" then move_bot(pos, "d")
                elseif act == "cw" then bot_turn_clockwise(pos)
                elseif act == "ccw" then bot_turn_anticlockwise(pos)
                end -- if act
                local np = pos
                if act == "f" then local nd = minetest.get_node(pos); local ndir = minetest.facedir_to_dir(nd.param2); np = {x = pos.x - ndir.x, y = pos.y, z = pos.z - ndir.z}
                elseif act == "d" then np = {x = pos.x, y = pos.y - 1, z = pos.z}
                elseif act == "j" then local nd = minetest.get_node(pos); local ndir = minetest.facedir_to_dir(nd.param2); np = {x = pos.x - ndir.x, y = pos.y + 1, z = pos.z - ndir.z}
                end -- if act
                minetest.get_meta(np):set_int("PC", PC - 1)
                minetest.get_meta(np):set_int("nav_active", 1)
                return
            end -- if #actions > 0
        end -- if nav ~= ""

        local path = find_path_to_player(pos, facing, target)
        if path == "done" then
            meta:set_int("nav_active", 0)
            meta:set_int("home_tx", 0)
            meta:set_int("home_ty", 0)
            meta:set_int("home_tz", 0)
            meta:set_string("nav_path", "")
            return
        end -- if path == "done"
        if path then
            local actions = string.split(path, ",")
            if #actions > 0 then
                local act = actions[1]
                table.remove(actions, 1)
                meta:set_string("nav_path", table.concat(actions, ","))
                if act == "f" then move_bot(pos, "f")
                elseif act == "j" then
                    local jn = minetest.get_node(pos)
                    local jd = minetest.facedir_to_dir(jn.param2)
                    position_bot(pos, {x = pos.x - jd.x, y = pos.y + 1, z = pos.z - jd.z})
                elseif act == "d" then move_bot(pos, "d")
                elseif act == "cw" then bot_turn_clockwise(pos)
                elseif act == "ccw" then bot_turn_anticlockwise(pos)
                end -- if act
                local np2 = pos
                if act == "f" then local nd = minetest.get_node(pos); local ndir = minetest.facedir_to_dir(nd.param2); np2 = {x = pos.x - ndir.x, y = pos.y, z = pos.z - ndir.z}
                elseif act == "d" then np2 = {x = pos.x, y = pos.y - 1, z = pos.z}
                elseif act == "j" then local nd = minetest.get_node(pos); local ndir = minetest.facedir_to_dir(nd.param2); np2 = {x = pos.x - ndir.x, y = pos.y + 1, z = pos.z - ndir.z}
                end -- if act
                minetest.get_meta(np2):set_int("PC", PC - 1)
                minetest.get_meta(np2):set_int("nav_active", 1)
            end -- if #actions > 0
        else
            meta:set_float("nav_retry", minetest.get_gametime())
        end -- if path
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
        move_bot(pos,"f")
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
            vbots2.bot_togglestate(pos, "off")
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
        if not front_node.name:find("sign") then
            if not minetest.is_protected(front_pos, meta:get_string("owner")) then
                local sign_name = minetest.registered_nodes["mcl_signs:wall_sign_bamboo"]
                    and "mcl_signs:wall_sign_bamboo"
                    or minetest.registered_nodes["default:sign_wall_wood"]
                    and "default:sign_wall_wood"
                    or nil
                if sign_name then
                    local wdir = minetest.facedir_to_dir(minetest.get_node(pos).param2)
                    local wm
                    if wdir.z == 1 then wm = 5
                    elseif wdir.z == -1 then wm = 4
                    elseif wdir.x == 1 then wm = 3
                    elseif wdir.x == -1 then wm = 2
                    else wm = 2 end
                    minetest.set_node(front_pos, {name = sign_name, param2 = wm})
                end
            end
        end
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
        end
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
        local node = minetest.get_node(pos)
        local facing = node.param2
        local PC = meta:get_int("PC")

        if not player then
            return
        end
        -- mark navigation active so handletimer stays on this command
        meta:set_int("nav_active", 1)
        meta:set_int("nav_pc", PC)
        meta:set_int("nav_pr", meta:get_int("PR"))
        vbots2.log(meta:get_string("name"), "go_player: start")

        local player_pos = player:get_pos()
        if not player_pos then
            return
        end

        -- if player is flying, trace down to solid ground
        local round_pos = {x = math.floor(player_pos.x + 0.5), y = math.floor(player_pos.y + 0.5), z = math.floor(player_pos.z + 0.5)}
        local below_n = minetest.get_node({x = round_pos.x, y = round_pos.y - 1, z = round_pos.z}).name
        if below_n == "air" then
            local gy = round_pos.y - 2
            while gy > -31000 do
                local nn = minetest.get_node({x = round_pos.x, y = gy, z = round_pos.z}).name
                if nn ~= "air" then break end
                gy = gy - 1
            end
            round_pos.y = gy + 1
        end

        -- check if at goal (within 1 block, not same block)
        local dx = math.abs(pos.x - round_pos.x)
        local dy = math.abs(pos.y - round_pos.y)
        local dz = math.abs(pos.z - round_pos.z)
        if dx <= 1 and dy <= 1 and dz <= 1 and (dx + dy + dz) > 0 then
            local retry_time = meta:get_float("nav_retry")
            local now = minetest.get_gametime()
            if retry_time == 0 then
                meta:set_float("nav_retry", now)
                meta:set_int("nav_active", 0)
                meta:set_int("PC", PC - 1)
                return
            elseif now - retry_time >= 5 then
                meta:set_float("nav_retry", 0)
                meta:set_int("nav_active", 0)
                return -- done waiting, advance to next command
            end
            meta:set_int("nav_active", 0)
            meta:set_int("PC", PC - 1)
            return
        end

        -- try stored path first
        local nav = meta:get_string("nav_path")
        if nav ~= "" then
            local actions = string.split(nav, ",")
            if #actions > 0 then
                local act = actions[1]
                table.remove(actions, 1)
                meta:set_string("nav_path", table.concat(actions, ","))

                if act == "f" then
                    move_bot(pos, "f")
                elseif act == "j" then
                    local jnode = minetest.get_node(pos)
                    local jdir = minetest.facedir_to_dir(jnode.param2)
                    position_bot(pos, {x = pos.x - jdir.x, y = pos.y + 1, z = pos.z - jdir.z})
                elseif act == "d" then
                    move_bot(pos, "d")
                elseif act == "cw" then
                    bot_turn_clockwise(pos)
                elseif act == "ccw" then
                    bot_turn_anticlockwise(pos)
                end
                -- update PC + nav_active on new meta after move
                local np_cache = pos
                if act == "f" then local nd = minetest.get_node(pos); local ndir = minetest.facedir_to_dir(nd.param2); np_cache = {x = pos.x - ndir.x, y = pos.y, z = pos.z - ndir.z}
                elseif act == "d" then np_cache = {x = pos.x, y = pos.y - 1, z = pos.z}
                elseif act == "j" then local nd = minetest.get_node(pos); local ndir = minetest.facedir_to_dir(nd.param2); np_cache = {x = pos.x - ndir.x, y = pos.y + 1, z = pos.z - ndir.z}
                end
                local nm_cache = minetest.get_meta(np_cache)
                nm_cache:set_int("PC", PC - 1)
                nm_cache:set_int("nav_active", 1)
                return
            end
        end

        -- no more path: recalculate
        local path = find_path_to_player(pos, facing, round_pos)
        if path == "done" then
            return
        end
        if path then
            local actions = string.split(path, ",")
            if #actions > 0 then
                local act = actions[1]
                table.remove(actions, 1)
                meta:set_string("nav_path", table.concat(actions, ","))

                if act == "f" then
                    move_bot(pos, "f")
                elseif act == "j" then
                    local jnode = minetest.get_node(pos)
                    local jdir = minetest.facedir_to_dir(jnode.param2)
                    position_bot(pos, {x = pos.x - jdir.x, y = pos.y + 1, z = pos.z - jdir.z})
                elseif act == "d" then
                    move_bot(pos, "d")
                elseif act == "cw" then
                    bot_turn_clockwise(pos)
                elseif act == "ccw" then
                    bot_turn_anticlockwise(pos)
                end
                -- update PC + nav_active on new meta after move
                local np_fresh = pos
                if act == "f" then local nd = minetest.get_node(pos); local ndir = minetest.facedir_to_dir(nd.param2); np_fresh = {x = pos.x - ndir.x, y = pos.y, z = pos.z - ndir.z}
                elseif act == "d" then np_fresh = {x = pos.x, y = pos.y - 1, z = pos.z}
                elseif act == "j" then local nd = minetest.get_node(pos); local ndir = minetest.facedir_to_dir(nd.param2); np_fresh = {x = pos.x - ndir.x, y = pos.y + 1, z = pos.z - ndir.z}
                end
                local nm_fresh = minetest.get_meta(np_fresh)
                nm_fresh:set_int("PC", PC - 1)
                nm_fresh:set_int("nav_active", 1)
            end
        else
            -- no path: retry next tick
            vbots2.log(meta:get_string("name"), "no path: retrying")
            meta:set_int("PC", PC - 1)
            return
        end
    elseif item == "vbots2:goto_pos" then
        local PC = meta:get_int("PC")
        local PR = meta:get_int("PR")
        -- read target from meta (stored on first call) or from item stack
        local tx = meta:get_int("goto_tx")
        local ty = meta:get_int("goto_ty")
        local tz = meta:get_int("goto_tz")
        if tx == 0 and ty == 0 and tz == 0 then
            -- first call: read coords from item stack at PC-1
            local inv = meta:get_inventory()
            local smeta = inv:get_stack("p"..PR, PC-1):get_meta()
            tx = smeta:get_int("pos_x")
            ty = smeta:get_int("pos_y")
            tz = smeta:get_int("pos_z")
            if tx == 0 and ty == 0 and tz == 0 then
                return -- no coords set, skip
            end -- if tx
            meta:set_int("goto_tx", tx)
            meta:set_int("goto_ty", ty)
            meta:set_int("goto_tz", tz)
            meta:set_int("nav_active", 1)
            meta:set_int("nav_pr", PR)
        end -- if tx == 0
        local target = resolve_goto_target({x = tx, y = ty, z = tz})
        local node = minetest.get_node(pos)
        local facing = node.param2

        -- check if at goal (Chebyshev ≤1)
        local dx = math.abs(pos.x - target.x)
        local dy = math.abs(pos.y - target.y)
        local dz = math.abs(pos.z - target.z)
        if dy <= 1 and ((dx == 0 and dz <= 1) or (dz == 0 and dx <= 1)) then
            meta:set_int("nav_active", 0)
            meta:set_int("goto_tx", 0)
            meta:set_int("goto_ty", 0)
            meta:set_int("goto_tz", 0)
            meta:set_string("nav_path", "")
            meta:set_int("PC", PC - 1)
            return -- done
        end -- if at goal

        -- cached path
        local nav = meta:get_string("nav_path")
        if nav ~= "" then
            local actions = string.split(nav, ",")
            if #actions > 0 then
                local act = actions[1]
                table.remove(actions, 1)
                meta:set_string("nav_path", table.concat(actions, ","))
                if act == "f" then move_bot(pos, "f")
                elseif act == "j" then
                    local jn = minetest.get_node(pos)
                    local jd = minetest.facedir_to_dir(jn.param2)
                    position_bot(pos, {x = pos.x - jd.x, y = pos.y + 1, z = pos.z - jd.z})
                elseif act == "d" then move_bot(pos, "d")
                elseif act == "cw" then bot_turn_clockwise(pos)
                elseif act == "ccw" then bot_turn_anticlockwise(pos)
                end -- if act
                local np = pos
                if act == "f" then local nd = minetest.get_node(pos); local ndir = minetest.facedir_to_dir(nd.param2); np = {x = pos.x - ndir.x, y = pos.y, z = pos.z - ndir.z}
                elseif act == "d" then np = {x = pos.x, y = pos.y - 1, z = pos.z}
                elseif act == "j" then local nd = minetest.get_node(pos); local ndir = minetest.facedir_to_dir(nd.param2); np = {x = pos.x - ndir.x, y = pos.y + 1, z = pos.z - ndir.z}
                end -- if act
                minetest.get_meta(np):set_int("PC", PC - 1)
                return
            end -- if #actions > 0
        end -- if nav ~= ""

        -- recalculate path
        local path = find_path_to_player(pos, facing, target)
        if path == "done" then
            meta:set_int("nav_active", 0)
            meta:set_int("goto_tx", 0)
            meta:set_int("goto_ty", 0)
            meta:set_int("goto_tz", 0)
            meta:set_string("nav_path", "")
            return
        end -- if path == "done"
        if path then
            local actions = string.split(path, ",")
            if #actions > 0 then
                local act = actions[1]
                table.remove(actions, 1)
                meta:set_string("nav_path", table.concat(actions, ","))
                if act == "f" then move_bot(pos, "f")
                elseif act == "j" then
                    local jn = minetest.get_node(pos)
                    local jd = minetest.facedir_to_dir(jn.param2)
                    position_bot(pos, {x = pos.x - jd.x, y = pos.y + 1, z = pos.z - jd.z})
                elseif act == "d" then move_bot(pos, "d")
                elseif act == "cw" then bot_turn_clockwise(pos)
                elseif act == "ccw" then bot_turn_anticlockwise(pos)
                end -- if act
                local np2 = pos
                if act == "f" then local nd = minetest.get_node(pos); local ndir = minetest.facedir_to_dir(nd.param2); np2 = {x = pos.x - ndir.x, y = pos.y, z = pos.z - ndir.z}
                elseif act == "d" then np2 = {x = pos.x, y = pos.y - 1, z = pos.z}
                elseif act == "j" then local nd = minetest.get_node(pos); local ndir = minetest.facedir_to_dir(nd.param2); np2 = {x = pos.x - ndir.x, y = pos.y + 1, z = pos.z - ndir.z}
                end -- if act
                minetest.get_meta(np2):set_int("PC", PC - 1)
            end -- if #actions > 0
        else
            -- no path: retry next tick
            meta:set_float("nav_retry", minetest.get_gametime())
        end -- if path
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
