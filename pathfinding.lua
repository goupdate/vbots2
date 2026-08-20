-- pathfinding.lua � A* pathfinding to target position (player or coords). Actions: forward, jump, down, turn cw/ccw. Heuristic: max(|dx|+|dz|, |dy|).
 
function find_path_to_player(bot_pos, bot_facing, player_pos)
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

    -- binary min-heap priority queue sorted by f = g + h, lowest first
    local open = {}

    -- per-run walkability cache: world is frozen during this synchronous call,
    -- so caching node lookups for the whole search is always valid
    local walk_cache = {}
    local function walkable(p)
        local ck = p.x .. "," .. p.y .. "," .. p.z
        local c = walk_cache[ck]
        if c ~= nil then return c end   -- if cached
        c = is_walkable(p)
        walk_cache[ck] = c
        return c
    end                                 -- function walkable
    local function push(state)
        state.f = state.g + state.h
        local i = #open + 1
        open[i] = state
        while i > 1 do                       -- sift-up loop
            local p = math.floor(i / 2)
            if open[p].f <= state.f then break end
            open[i], open[p] = open[p], open[i]
            i = p
        end                                 -- sift-up loop
    end
    local function pop()
        local top = open[1]
        local last = table.remove(open)
        if #open > 0 then                   -- if heap non-empty
            open[1] = last
            local i = 1
            while true do                   -- sift-down loop
                local l = i * 2
                local r = l + 1
                local smallest = i
                if l <= #open and open[l].f < open[smallest].f then smallest = l end  -- if left child smaller
                if r <= #open and open[r].f < open[smallest].f then smallest = r end  -- if right child smaller
                if smallest == i then break end
                open[i], open[smallest] = open[smallest], open[i]
                i = smallest
            end                             -- sift-down loop
        end                                 -- if heap non-empty
        return top
    end

    push({pos = bot_pos, facing = bot_facing, g = 0, h = h(bot_pos), parent = nil, action = nil})
    visited[key(bot_pos, bot_facing)] = true
    visited_count = 1

    while #open > 0 do
        if visited_count >= max_visited then
            return nil
        end
        local cur = pop()

        -- goal: within 1 block of target (any direction), not same block
        local dx = math.abs(cur.pos.x - player_pos.x)
        local dy = math.abs(cur.pos.y - player_pos.y)
        local dz = math.abs(cur.pos.z - player_pos.z)
        if dx <= 1 and dy <= 1 and dz <= 1 and (dx + dy + dz) > 0 then
            if cur.action == nil then return "done" end
            -- reconstruct action list via parent pointers (collected backwards)
            local acts = {}
            while cur.action do             -- walk parents
                acts[#acts + 1] = cur.action
                cur = cur.parent
            end                             -- walk parents
            local n = #acts
            for i = 1, math.floor(n / 2) do -- reverse loop
                acts[i], acts[n - i + 1] = acts[n - i + 1], acts[i]
            end                             -- reverse loop
            return table.concat(acts, ",")
        end

        if cur.g < max_steps then
            local dir = facedirs[cur.facing + 1]

            -- move forward
            local fwd = {x = cur.pos.x - dir.x, y = cur.pos.y, z = cur.pos.z - dir.z}
            if walkable(fwd) then       -- if forward walkable
                local fk = key(fwd, cur.facing)
                if not visited[fk] then     -- if forward unvisited
                    visited_count = visited_count + 1
                    visited[fk] = true
                    push({pos = fwd, facing = cur.facing, g = cur.g + 1, h = h(fwd), parent = cur, action = "f"})
                end                         -- if forward unvisited
            end                             -- if forward walkable

            -- jump forward (up + forward)
            local jmp = {x = cur.pos.x - dir.x, y = cur.pos.y + 1, z = cur.pos.z - dir.z}
            if walkable(jmp) then       -- if jump walkable
                local jk = key(jmp, cur.facing)
                if not visited[jk] then     -- if jump unvisited
                    visited_count = visited_count + 1
                    visited[jk] = true
                    push({pos = jmp, facing = cur.facing, g = cur.g + 1, h = h(jmp), parent = cur, action = "j"})
                end                         -- if jump unvisited
            end                             -- if jump walkable

            -- move down (fall)
            local dn = {x = cur.pos.x, y = cur.pos.y - 1, z = cur.pos.z}
            if walkable(dn) then        -- if down walkable
                local dk = key(dn, cur.facing)
                if not visited[dk] then     -- if down unvisited
                    visited_count = visited_count + 1
                    visited[dk] = true
                    push({pos = dn, facing = cur.facing, g = cur.g + 1, h = h(dn), parent = cur, action = "d"})
                end                         -- if down unvisited
            end                             -- if down walkable

            -- turn clockwise
            local cwf = (cur.facing + 1) % 4
            local cwk = key(cur.pos, cwf)
            if not visited[cwk] then        -- if cw unvisited
                visited_count = visited_count + 1
                visited[cwk] = true
                push({pos = cur.pos, facing = cwf, g = cur.g + 1, h = h(cur.pos), parent = cur, action = "cw"})
            end                             -- if cw unvisited

            -- turn anticlockwise
            local ccwf = (cur.facing - 1) % 4
            local ccwk = key(cur.pos, ccwf)
            if not visited[ccwk] then       -- if ccw unvisited
                visited_count = visited_count + 1
                visited[ccwk] = true
                push({pos = cur.pos, facing = ccwf, g = cur.g + 1, h = h(cur.pos), parent = cur, action = "ccw"})
            end                             -- if ccw unvisited
        end                                 -- if cur.g < max_steps
    end

    return nil -- no path found
end
