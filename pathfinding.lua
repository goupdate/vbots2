-- pathfinding.lua — A* pathfinding to target position (player or coords). Actions: forward, jump, down, turn cw/ccw. Heuristic: max(|dx|+|dz|, |dy|).
 
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
