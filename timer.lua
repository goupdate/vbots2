-- timer.lua � Bot tick loop: gravity check, command dispatch, skip handling, magnet pickup, punch toggle
 
function punch_bot(pos,player)
    local meta = minetest.get_meta(pos)
    local bot_owner = meta:get_string("owner")
    if bot_owner == player:get_player_name() then
        local item = player:get_wielded_item():get_name()
        if item == "" then
            vbots2.bot_togglestate(pos)
        end
    end
end

local function bot_pickup_items(pos)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local objects = minetest.get_objects_inside_radius(pos, 1.8)
    for _, obj in ipairs(objects) do
        if obj and obj:get_luaentity() and obj:get_luaentity().name == "__builtin:item" then
            local stack = ItemStack(obj:get_luaentity().itemstring)
            if not stack:is_empty() then
                bot_add_items(inv, "main", stack)
                obj:remove()
            end
        end
    end
end

function bot_handletimer(pos)
    local meta = minetest.get_meta(pos)

    -- global stop-all (bomb button): owner flagged -> bot stops itself
    if vbots2.stop_all[meta:get_string("owner")] then
        vbots2.bot_togglestate(pos, "off")
        return false
    end

    -- magnet pickup: scan for dropped items only every 5th tick (~2.5s at 0.5s steps)
    local pt = vbots2.pickup_ticks
    local pkey = meta:get_string("key")
    local pc = (pt[pkey] or 0) + 1
    if pc >= 5 then
        pt[pkey] = 0
        bot_pickup_items(pos)
    else
        pt[pkey] = pc
    end

    -- sync minimap marker position + color
    local bot_key = meta:get_string("key")
    local bi = vbots2.bot_info[bot_key]
    if not bi and bot_key ~= "" then
        -- re-register after server restart: bot_info is memory-only, so a
        -- running bot must restore its own entry (owner, pos, marker, body)
        vbots2.bot_restore(pos)
        bi = vbots2.bot_info[bot_key]
    end
    if bi and bi.marker then
        bi.marker:set_pos({x = pos.x, y = pos.y + 0.5, z = pos.z})
        local tex = (meta:get_float("nav_retry") > 0) and "vbots_marker_wait.png" or "vbots_marker_on.png"
        bi.marker:set_properties({textures = {tex}})
    end
    if bi and bi.body then
        bi.body:set_pos({x = pos.x, y = pos.y + 0.5, z = pos.z})
    end

    -- program slots live in detached inventory botprog_<key> (mirrored to mod_storage)
    local inv = vbots2.prog_inv(bot_key)
    local PC = meta:get_int("PC")
    local PR = meta:get_int("PR")
    local invname = "p"..PR
    local stack = meta:get_string("stack")

    -- stay on nav command if bot is pathfinding
    if meta:get_int("nav_active") == 1 then
        PR = meta:get_int("nav_pr")
    end

    local taken = inv:get_stack(invname, PC)
    local command = taken:get_name()

    local command_slot = PC            -- remember where the command lives (for repeat loop)
    local todo = meta:get_int("repeat")
    if todo == 0 then
        -- only advance PC if not navigating
        if meta:get_int("nav_active") ~= 1 then
            PC = PC + 1
        end
        while(command == "" and PC<=56) do            -- skip empty slots
            taken = inv:get_stack(invname, PC)
            command = taken:get_name()
            PC=PC+1
        end                                        -- skip empty slots
        -- accumulate consecutive number/var multipliers (e.g. x5 x2 = 10)
        -- skip arg consumption for commands that read their own slot args
        local no_repeat = (command == "vbots2:gt_check"
            or command == "vbots2:lt_check" or command == "vbots2:gte_check"
            or command == "vbots2:lte_check" or command == "vbots2:eq_check"
            or command == "vbots2:neq_check" or command == "vbots2:dig_check"
            or command == "vbots2:sign_read" or command == "vbots2:sign_print"
            or command == "vbots2:count")
        local accumulate = 1
        while not no_repeat and PC <= 56 do           -- loop over consecutive multipliers
            local ns = inv:get_stack(invname, PC)
            local nname = ns:get_name()
            local parts = string.split(nname, "_")
            if parts[1] == "vbots2:number" then
                accumulate = accumulate * tonumber(parts[2])
                if accumulate > 49 then accumulate = 49; break end  -- cap
                PC = PC + 1
            elseif parts[1] == "vbots2:var" then
                local val = meta:get_int("var_" .. parts[2])
                if val > 1 then
                    accumulate = accumulate * val
                    if accumulate > 49 then accumulate = 49; break end  -- cap
                end
                PC = PC + 1
            else
                break                                    -- not a multiplier
            end                                         -- if number or var
        end                                             -- loop over consecutive multipliers
        if accumulate > 1 then                          -- if any multiplier found
            meta:set_int("repeat", accumulate - 1)
        end                                             -- if any multiplier found
        meta:set_int("repeat_mult", accumulate)
        meta:set_int("cmd_slot", command_slot)
    else
        command = inv:get_stack(invname, meta:get_int("cmd_slot")):get_name()
        meta:set_int("repeat", todo-1)
    end
    meta:set_int("PC",PC)
    meta:set_int("PR",PR)
    meta:set_string("stack",stack)
    if PC<=56 then
        -- print("mainloop PR:"..meta:get_int("PR")..
        --   " PC:"..meta:get_int("PC")..
        --   " R:"..meta:get_int("repeat")..
        --   " : "..command)
        bot_parsecommand(pos, command)
        local skip = meta:get_int("skip")
        if skip > 0 then
            PC = meta:get_int("PC") + skip
            meta:set_int("PC", PC)
            meta:set_int("skip", 0)
        end
        return true
    else
        -- print("Program "..PR.." ending.")
        if PR ~=0 then
            pull_state(pos)
            return true
        else
            vbots2.bot_togglestate(pos)
            return false
        end
    end
end
