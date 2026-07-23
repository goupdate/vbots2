-------------------------------------
-- Cute 'unique' bot name generator
-------------------------------------

local function push_state(pos,a,b,c)
    local meta = minetest.get_meta(pos)
    local stack = meta:get_string("stack")
    local push = a..","..b..","..c..","
    meta:set_string("stack", push..stack)
end

local function pull_state(pos)
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
local function interact(player,pos,isempty)
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
local function clean_bot_table()
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
local function facebot(facing,pos)
    local node = minetest.get_node(pos)
    minetest.swap_node(pos,{name=node.name, param2=facing})
end

local function get_front_node(pos)
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

local function node_matches(got, expected)
    -- treat dirt variants as equal
    if dirt_aliases[got] and dirt_aliases[expected] then
        return true
    end
    return got == expected
end

local function bot_add_items(inv, listname, stack)
    inv:add_item(listname, stack)
end

local function resolve_value(stack, meta)
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

local function bot_turn_clockwise(pos)
    local node = minetest.get_node(pos)
    local newface = (node.param2+1)%4
    facebot(newface,pos)
end

local function bot_turn_anticlockwise(pos)
    local node = minetest.get_node(pos)
    local newface = (node.param2-1)%4
    facebot(newface,pos)
end

local function bot_turn_random(pos)
    if math.random(2)==1 then
        bot_turn_clockwise(pos)
    else
        bot_turn_anticlockwise(pos)
    end
end

local function position_bot(pos,newpos)
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
        local moveto_node = minetest.get_node(newpos)
        -- cut plants on the way
        local is_plant = false
        local ndef = minetest.registered_nodes[moveto_node.name]
        if ndef and ndef.groups then
            is_plant = ndef.groups.flora or ndef.groups.grass or ndef.groups.plant or
                       ndef.groups.flower or ndef.groups.sapling or ndef.groups.leaves
        end
        local is_door = ndef and ndef.groups and ndef.groups.door
        if moveto_node.name == "air" or is_plant or is_door then
            -- handle door: right-click toggle, then swap bot/door positions
            if is_door and player then
                local door_pos = newpos
                local door_node = moveto_node
                local door_def = minetest.registered_nodes[door_node.name]
                if door_def and door_def.on_rightclick then
                    door_def.on_rightclick(door_pos, door_node, player)
                end
                -- swap: bot to door position, door to bot position
                local bot_node = minetest.get_node(pos)
                local hold = meta:to_table()
                meta:set_string("moving", "1")
                -- place bot at door position
                minetest.swap_node(pos, {name = door_node.name, param2 = door_node.param2})
                minetest.swap_node(door_pos, {name = bot_node.name, param2 = bot_node.param2})
                minetest.get_node_timer(door_pos):set(1/R, 0)
                if hold then
                    minetest.get_meta(door_pos):from_table(hold)
                end
                -- close door behind bot
                local behind_node = minetest.get_node(pos)
                local behind_def = minetest.registered_nodes[behind_node.name]
                if behind_def and behind_def.on_rightclick then
                    behind_def.on_rightclick(pos, behind_node, player)
                end
                local dd = minetest.get_node(door_pos)
                return
            end
        if moveto_node.name == "air" or is_plant then
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
            minetest.after(0.06, function()
                minetest.set_node(pos,{name="air"})
            end)
        else
            minetest.sound_play("error",{pos = newpos, gain = 10})
        end
        minetest.check_for_falling(newpos)
    else
        minetest.sound_play("system-fault",{pos = newpos, gain = 10})
    end
end


local function move_bot(pos,direction)
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

local function bot_dig(pos,digy)
    local meta = minetest.get_meta(pos)
    local bot_owner = meta:get_string("owner")
    local node = minetest.get_node(pos)
    local dir = minetest.facedir_to_dir(node.param2)
    local digpos
    if digy == 0 then
        digpos = {x = pos.x-dir.x, y = pos.y, z = pos.z-dir.z}
    else
        digpos = {x = pos.x, y = pos.y+digy, z = pos.z}
    end
if not minetest.is_protected(digpos, bot_owner) then
        local drop = minetest.get_node(digpos)
        if drop.name ~= "air" then
            local ndef = minetest.registered_nodes[drop.name]
            local is_container = ndef and ndef.groups and ndef.groups.container
            if is_container then
                local chest_inv = minetest.get_inventory({type="node", pos=digpos})
                if chest_inv and chest_inv:is_empty("main") then
                    -- empty chest: dig it as a block
                    local drops = minetest.get_node_drops(drop.name, "default:pick_diamond")
                    local inv=minetest.get_inventory({type="node", pos=pos})
                    for _, itemname in ipairs(drops) do
                        bot_add_items(inv, "main", ItemStack(itemname))
                    end
                    minetest.set_node(digpos,{name="air"})
                else
                    -- non-empty chest: take items
                    local inv=minetest.get_inventory({type="node", pos=pos})
                    -- read optional filter from next program slot
                    local PC = meta:get_int("PC")
                    local PR = meta:get_int("PR")
                    local filter = inv:get_stack("p"..PR, PC):get_name()
                    local taken = false
                    local chest_list = chest_inv:get_list("main")
                    for i = 1, #chest_list do
                        local stack = chest_list[i]
                        if not stack:is_empty() then
                            if filter == "" or stack:get_name() == filter then
                                bot_add_items(inv, "main", stack)
                                chest_inv:set_stack("main", i, ItemStack(nil))
                                taken = true
                                break
                            end
                        end
                    end
                    if not taken then
                        minetest.sound_play("system-fault",{pos = digpos, gain = 10})
                    end
                end
            else
                -- normal dig
                local drops = minetest.get_node_drops(drop.name, "default:pick_diamond")
                local inv=minetest.get_inventory({type="node", pos=pos})
                for _, itemname in ipairs(drops) do
                    bot_add_items(inv, "main", ItemStack(itemname))
                end
                minetest.set_node(digpos,{name="air"})
            end
        end
    else
        minetest.sound_play("system-fault",{pos = newpos, gain = 10})
    end
end

local function bot_build(pos, buildy, filter)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local bot_owner = meta:get_string("owner")
    local node = minetest.get_node(pos)
    local dir = minetest.facedir_to_dir(node.param2)
    local front_pos = {x = pos.x - dir.x, y = pos.y, z = pos.z - dir.z}
    local front_node = minetest.get_node(front_pos)

    -- check ahead for chest transfer first
    local ndef = minetest.registered_nodes[front_node.name]
    if ndef and ndef.groups and ndef.groups.container then
        if not minetest.is_protected(front_pos, bot_owner) then
            local chest_inv = minetest.get_inventory({type="node", pos=front_pos})
            if chest_inv then
                local main = inv:get_list("main")
                for i = 1, #main do
                    local stack = main[i]
                    if stack and not stack:is_empty() then
                        if filter == "" or stack:get_name() == filter then
                            local leftover = chest_inv:add_item("main", stack)
                            inv:set_stack("main", i, leftover)
                            return
                        end
                    end
                end
            end
        end
        return
    end

    -- no chest ahead: normal build behind
    local buildpos
    if buildy == 0 then
        buildpos = {x = pos.x+dir.x, y = pos.y, z = pos.z+dir.z}
    else
        buildpos = {x = pos.x, y = pos.y+buildy, z = pos.z}
    end
    local buildnode = minetest.get_node(buildpos)

    if not minetest.is_protected(buildpos, bot_owner) then
        if buildnode.name == "air" then
            local content = inv:get_list("main")
            local a = 1
            local found = nil
            if content then
                while( a<33 and not found) do
                    if content[a] and not content[a]:is_empty() then
                        found = content[a]:get_name()
                    end
                    a=a+1
                end
                if found then
                    local got = inv:remove_item("main",ItemStack(found))
                    if got:get_count() == 1 then
                        minetest.set_node(buildpos,{name=found})
                    end
                end
            end
        else
            minetest.sound_play("system-fault",{pos = buildpos, gain = 10})
        end
    else
        minetest.sound_play("system-fault",{pos = buildpos, gain = 10})
    end
end

-------------------------------------
-- Minimap marker color update
-------------------------------------
local function update_marker(pos, state)
    local meta = minetest.get_meta(pos)
    local bot_key = meta:get_string("key")
    local bi = vbots2.bot_info[bot_key]
    if bi and bi.marker then
        local tex = (state == "waiting") and "vbots_marker_wait.png" or "vbots_marker_on.png"
        bi.marker:set_properties({textures = {tex}})
    end
end

-------------------------------------
-- A* pathfinding to player
-------------------------------------
local facedirs = {
    {x=0, z=1},   -- 0: south
    {x=1, z=0},   -- 1: east
    {x=0, z=-1},  -- 2: north
    {x=-1, z=0},  -- 3: west
}

local function is_walkable(p)
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
    return false
end

local function find_path_to_player(bot_pos, bot_facing, player_pos)
    local max_steps = 500
    local max_visited = 50000
    local visited_count = 0
    local visited = {}
    local function key(pos, facing)
        return pos.x .. "," .. pos.y .. "," .. pos.z .. "," .. facing
    end

    -- heuristic: max(horizontal, vertical)
    local function h(pos)
        return math.max(
            math.abs(pos.x - player_pos.x) + math.abs(pos.z - player_pos.z),
            math.abs(pos.y - player_pos.y)
        )
    end

    -- priority queue sorted by f = g + h, lowest first
    local open = {}
    local function push(state)
        state.f = state.g + state.h
        -- insert sorted by f
        local i = 1
        while i <= #open and open[i].f <= state.f do
            i = i + 1
        end
        table.insert(open, i, state)
    end

    push({pos = bot_pos, facing = bot_facing, g = 0, h = h(bot_pos), actions = {}})
    visited[key(bot_pos, bot_facing)] = true
    visited_count = 1

    while #open > 0 do
        if visited_count >= max_visited then
            return nil
        end
        local cur = table.remove(open, 1)
        --------------------------------------------------------------------------

        if cur.g >= max_steps then
            goto continue_astar
        end

        -- goal: within 1 block of target (any direction), not same block
        local dx = math.abs(cur.pos.x - player_pos.x)
        local dy = math.abs(cur.pos.y - player_pos.y)
        local dz = math.abs(cur.pos.z - player_pos.z)
        if dx <= 1 and dy <= 1 and dz <= 1 and (dx + dy + dz) > 0 then
            if #cur.actions == 0 then return "done" end
            return table.concat(cur.actions, ",")
        end

        local dir = facedirs[cur.facing + 1]

        -- move forward
        local fwd = {x = cur.pos.x - dir.x, y = cur.pos.y, z = cur.pos.z - dir.z}
        local fk = key(fwd, cur.facing)
        if is_walkable(fwd) and not visited[fk] then
            visited_count = visited_count + 1
            visited[fk] = true
            local a = {}
            for _, v in ipairs(cur.actions) do table.insert(a, v) end
            table.insert(a, "f")
            push({pos = fwd, facing = cur.facing, g = cur.g + 1, h = h(fwd), actions = a})
        end

        -- jump forward (up + forward)
        local jmp = {x = cur.pos.x - dir.x, y = cur.pos.y + 1, z = cur.pos.z - dir.z}
        local jk = key(jmp, cur.facing)
        if is_walkable(jmp) and not visited[jk] then
            visited_count = visited_count + 1
            visited[jk] = true
            local a = {}
            for _, v in ipairs(cur.actions) do table.insert(a, v) end
            table.insert(a, "j")
            push({pos = jmp, facing = cur.facing, g = cur.g + 1, h = h(jmp), actions = a})
        end

        -- move down (fall)
        local dn = {x = cur.pos.x, y = cur.pos.y - 1, z = cur.pos.z}
        local dk = key(dn, cur.facing)
        if is_walkable(dn) and not visited[dk] then
            visited_count = visited_count + 1
            visited[dk] = true
            local a = {}
            for _, v in ipairs(cur.actions) do table.insert(a, v) end
            table.insert(a, "d")
            push({pos = dn, facing = cur.facing, g = cur.g + 1, h = h(dn), actions = a})
        end

        -- turn clockwise
        local cwf = (cur.facing + 1) % 4
        local cwk = key(cur.pos, cwf)
        if not visited[cwk] then
            visited_count = visited_count + 1
            visited[cwk] = true
            local a = {}
            for _, v in ipairs(cur.actions) do table.insert(a, v) end
            table.insert(a, "cw")
            push({pos = cur.pos, facing = cwf, g = cur.g + 1, h = h(cur.pos), actions = a})
        end

        -- turn anticlockwise
        local ccwf = (cur.facing - 1) % 4
        local ccwk = key(cur.pos, ccwf)
        if not visited[ccwk] then
            visited_count = visited_count + 1
            visited[ccwk] = true
            local a = {}
            for _, v in ipairs(cur.actions) do table.insert(a, v) end
            table.insert(a, "ccw")
            push({pos = cur.pos, facing = ccwf, g = cur.g + 1, h = h(cur.pos), actions = a})
        end

        ::continue_astar::
    end

    return nil -- no path found
end

local function bot_parsecommand(pos,item)
    local meta = minetest.get_meta(pos)
    local bot_owner = meta:get_string("owner")
    if item == "vbots2:move_forward" then
        move_bot(pos,"f")
    elseif item == "vbots2:move_backward" then
        move_bot(pos,"b")
    elseif item == "vbots2:move_down" then
        move_bot(pos,"d")
    elseif item == "vbots2:move_home" then
        local newpos = minetest.deserialize(meta:get_string("home"))
        if newpos then
            position_bot(pos,newpos,bot_owner)
        end
    elseif item == "vbots2:turn_clockwise" then
        bot_turn_clockwise(pos)
    elseif item == "vbots2:turn_anticlockwise" then
        bot_turn_anticlockwise(pos)
    elseif item == "vbots2:turn_random" then
        bot_turn_random(pos)
    elseif item == "vbots2:mode_speed" then
        local R = meta:get_int("repeat")
        if R > 1 then
            meta:set_int("repeat",0)
            meta:set_int("steptime",R+1)
        else
            meta:set_int("steptime",1)
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
        if not front_node.name:find("sign") then
            if not minetest.is_protected(front_pos, meta:get_string("owner")) then
                local sign_name = minetest.registered_nodes["mcl_signs:wall_sign_bamboo"]
                    and "mcl_signs:wall_sign_bamboo"
                    or minetest.registered_nodes["default:sign_wall_wood"]
                    and "default:sign_wall_wood"
                    or nil
                if sign_name then
                    minetest.set_node(front_pos, {name = sign_name})
                end
            end
        end
        local sign_meta = minetest.get_meta(front_pos)
        local text = sign_meta:get_string("text")
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
        local front_node, front_pos = get_front_node(pos)
        if not front_node.name:find("sign") then
            if not minetest.is_protected(front_pos, meta:get_string("owner")) then
                local sign_name = minetest.registered_nodes["mcl_signs:wall_sign_bamboo"]
                    and "mcl_signs:wall_sign_bamboo"
                    or minetest.registered_nodes["default:sign_wall_wood"]
                    and "default:sign_wall_wood"
                    or nil
                if sign_name then
                    minetest.set_node(front_pos, {name = sign_name})
                end
            end
        end
        if var_name then
            local val = meta:get_int("var_" .. var_name)
            local sign_meta = minetest.get_meta(front_pos)
            sign_meta:set_string("text", tostring(val))
            if mcl_signs and mcl_signs.update_sign then
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
            -- player offline: skip command
            return
        end

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
            -- at goal: set retry timer, wait 5s before recalculating
            local retry_time = meta:get_float("nav_retry")
            local now = minetest.get_gametime()
            if retry_time == 0 then
                meta:set_float("nav_retry", now)
            elseif now - retry_time >= 5 then
                meta:set_float("nav_retry", 0)
            end
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

                -- stay on this command for next step
                meta:set_int("PC", PC - 1)
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

                meta:set_int("PC", PC - 1)
            end
        else
            -- no path: wait 5s and retry
            local retry_time = meta:get_float("nav_retry")
            local now = minetest.get_gametime()
            if retry_time == 0 then
                meta:set_float("nav_retry", now)
            elseif now - retry_time >= 5 then
                meta:set_float("nav_retry", 0)
                meta:set_string("nav_path", "")
            end
            meta:set_int("PC", PC - 1)
            return
        end
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

local function punch_bot(pos,player)
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

local function bot_handletimer(pos)
    bot_pickup_items(pos)
    local meta = minetest.get_meta(pos)

    -- gravity: fall if no block below
    local below = {x = pos.x, y = pos.y - 1, z = pos.z}
    if minetest.get_node(below).name == "air" then
        move_bot(pos, "d")
        meta:set_string("nav_path", "")  -- invalidate cached path
        return true
    end

    -- sync minimap marker position + color
    local bot_key = meta:get_string("key")
    local bi = vbots2.bot_info[bot_key]
    if bi and bi.marker then
        bi.marker:set_pos({x = pos.x, y = pos.y + 0.5, z = pos.z})
        local tex = (meta:get_float("nav_retry") > 0) and "vbots_marker_wait.png" or "vbots_marker_on.png"
        bi.marker:set_properties({textures = {tex}})
    end

    local inv = meta:get_inventory()
    local PC = meta:get_int("PC")
    local PR = meta:get_int("PR")
    local invname = "p"..PR
    local stack = meta:get_string("stack")

    local taken = inv:get_stack(invname, PC)
    local command = taken:get_name()

    local todo = meta:get_int("repeat")
    if todo == 0 then
        PC=PC+1
        while(command == "" and PC<57) do
            taken = inv:get_stack(invname, PC)
            command = taken:get_name()
            PC=PC+1
        end
        local hasarg = string.split(inv:get_stack(invname, PC):get_name(),"_")
        -- print( PC.." "..dump(hasarg))
        if hasarg[1] == "vbots2:number" then
            if tonumber(hasarg[2])>1 then
                meta:set_int("repeat", hasarg[2]-1)
            end
            PC=PC+1
        elseif hasarg[1] == "vbots2:var" then
            local val = meta:get_int("var_" .. hasarg[2])
            if val > 1 then
                meta:set_int("repeat", val - 1)
            end
            PC=PC+1
        end
    else
        command = inv:get_stack(invname, PC-2):get_name()
        meta:set_int("repeat", todo-1)
    end
    meta:set_int("PC",PC)
    meta:set_int("PR",PR)
    meta:set_string("stack",stack)
    if PC<56 then
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


-------------------------------------
-- Bot definitions
-------------------------------------
local function register_bot(node_name,node_desc,node_tiles,node_groups)
    minetest.register_node(node_name, {
        description = node_desc,
        tiles = node_tiles,
        stack_max = 1,
        is_ground_content = false,
        paramtype2 = "facedir",
        legacy_facedir_simple = true,
        groups = node_groups,
        --light_source = 14,
        on_blast = function() end,
        after_place_node = function(pos, placer, itemstack, pointed_thing)
            vbots2.bot_init(pos, placer)
            local facing = minetest.dir_to_facedir(placer:get_look_dir())
            facing = (facing+2)%4
            facebot(facing,pos)
        end,
        on_punch = function(pos, node, player, pointed_thing)
            punch_bot(pos,player)
        end,
        on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
            local name = clicker:get_player_name()
            if name == "" then
                return 0
            end
            if interact(clicker,pos) then
                vbots2.bot_restore(pos)
                minetest.after(0, vbots2.show_formspec, clicker, pos)
            end
        end,
        on_timer = function(pos, elapsed)
            return bot_handletimer(pos)
        end,
        can_dig = function(pos,player)
            return interact(player,pos)
        end,
        on_destruct = function(pos)
            local meta = minetest.get_meta(pos)
            -- skip inventory drop during bot movement (position_bot sets moving flag)
            if meta:get_string("moving") ~= "1" then
                local inv = meta:get_inventory()
                for i = 1, inv:get_size("main") do
                    local stack = inv:get_stack("main", i)
                    if not stack:is_empty() then
                        local drop_pos = {x = pos.x, y = pos.y + 0.5, z = pos.z}
                        minetest.add_item(drop_pos, stack)
                    end
                end
            end
            local bot_key = meta:get_string("key")
            local bi = vbots2.bot_info[bot_key]
            if bi and bi.marker then
                bi.marker:remove()
            end
            vbots2.bot_info[bot_key] = nil
            clean_bot_table()
        end
})

-------------------------------------
-- Mesecon integration: turn bot on by redstone
-------------------------------------
if minetest.get_modpath("mesecons") then
    mesecon.register_effector("vbots2:off", "vbots2:on", {
        action_on = function(pos)
            vbots2.bot_togglestate(pos, "on")
        end,
    })
end
end

register_bot("vbots2:off", "Inactive Vbot", {
            "vbots_turtle_top.png",
            "vbots_turtle_bottom.png",
            "vbots_turtle_right.png",
            "vbots_turtle_left.png",
            "vbots_turtle_tail.png",
            "vbots_turtle_face.png",
            },
            {cracky = 1,
             snappy = 1,
             crumbly = 1,
             oddly_breakable_by_hand = 1,
             }
)
register_bot("vbots2:on", "Live Vbot", {
            "vbots_turtle_top4.png",
            "vbots_turtle_bottom.png",
            "vbots_turtle_right.png",
            "vbots_turtle_left.png",
            "vbots_turtle_tail.png",
            "vbots_turtle_face.png",
            },
            {cracky = 1,
             snappy = 1,
             crumbly = 1,
             oddly_breakable_by_hand = 1,
not_in_creative_inventory = 1,
              }
)

-------------------------------------
-- Minimap marker entity
-------------------------------------
minetest.register_entity("vbots2:minimap_marker", {
    initial_properties = {
        visual = "sprite",
        visual_size = {x = 0.4, y = 0.4},
        textures = {"vbots_marker_on.png"},
        glow = 14,
        physical = false,
        collide_with_objects = false,
        pointable = false,
        static_save = false,
    },
    on_activate = function(self)
        self.object:set_armor_groups({immortal = 1})
    end,
})
