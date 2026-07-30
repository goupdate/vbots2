-- dig_build.lua � Dig (break block + loot + chest handling) and Build (place block + chest transfer)
 
function bot_dig(pos,digy)
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
            local is_bot = drop.name:find("^vbots2:")
            if is_bot then
                -- take items from another bot
                local bot_inv = minetest.get_inventory({type="node", pos=digpos})
                if bot_inv then
                    local inv = minetest.get_inventory({type="node", pos=pos})
                    local PC = meta:get_int("PC")
                    local PR = meta:get_int("PR")
                    local filter = inv:get_stack("p"..PR, PC):get_name()
                    if filter:find("^vbots2:") then filter = "" end
                    local taken = false
                    local bot_list = bot_inv:get_list("main")
                    for i = 1, bot_inv:get_size("main") do
                        local stack = bot_list[i]
                        if not stack:is_empty() then
                            if filter == "" or stack:get_name() == filter then
                                bot_add_items(inv, "main", stack)
                                bot_inv:set_stack("main", i, ItemStack(nil))
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
            local is_container = ndef and ndef.groups and ndef.groups.container
            if is_container then
                local chest_inv = minetest.get_inventory({type="node", pos=digpos})
                vbots2.log(meta:get_string("name"), "dig: chest ahead, empty=" .. tostring(chest_inv and chest_inv:is_empty("main")))
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
                    if filter:find("^vbots2:") then filter = "" end
                    local taken = false
                    local chest_list = chest_inv:get_list("main")
                    for i = 1, chest_inv:get_size("main") do
                        local stack = chest_list[i]
                        if not stack:is_empty() then
                            if filter == "" or stack:get_name() == filter then
                                 bot_add_items(inv, "main", stack)
                                chest_inv:set_stack("main", i, ItemStack(nil))
                                taken = true
                                -- flag: prevent next build from putting it back
                                meta:set_int("chest_grab", 1)
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
    end
    else
        minetest.sound_play("system-fault",{pos = digpos, gain = 10})
    end
end

function bot_build(pos, buildy, filter, mode)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local bot_owner = meta:get_string("owner")
    local node = minetest.get_node(pos)
    local dir = minetest.facedir_to_dir(node.param2)
    local front_pos
    if mode == "behind" then
        front_pos = {x = pos.x + dir.x, y = pos.y, z = pos.z + dir.z}
    else
        front_pos = {x = pos.x - dir.x, y = pos.y, z = pos.z - dir.z}
    end
    local front_node = minetest.get_node(front_pos)

    -- check ahead for bot or chest transfer first
    local is_bot = front_node.name:find("^vbots2:")
    local ndef = minetest.registered_nodes[front_node.name]
    if meta:get_int("chest_grab") == 1 then
        -- just took from chest ahead: check chest behind instead
        meta:set_int("chest_grab", 0)
        local back_pos = {x = pos.x + dir.x, y = pos.y, z = pos.z + dir.z}
        local back_node = minetest.get_node(back_pos)
        local back_def = minetest.registered_nodes[back_node.name]
        if back_def and back_def.groups and back_def.groups.container then
            if not minetest.is_protected(back_pos, bot_owner) then
                local chest_inv = minetest.get_inventory({type="node", pos=back_pos})
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
        -- no chest behind: fall through to normal build
    elseif is_bot or (ndef and ndef.groups and ndef.groups.container) then
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

    -- no chest ahead: normal build ahead (front)
    local buildpos
    if mode == "behind" then
        buildpos = {x = pos.x + dir.x, y = pos.y, z = pos.z + dir.z}
    elseif buildy == 0 then
        buildpos = {x = pos.x - dir.x, y = pos.y, z = pos.z - dir.z}
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
                if found and minetest.registered_nodes[found] then
                    minetest.set_node(buildpos, {name = found})
                    -- creative: do not consume items
                end
            end
        else
            minetest.sound_play("system-fault",{pos = buildpos, gain = 10})
        end
    else
        minetest.sound_play("system-fault",{pos = buildpos, gain = 10})
    end
end
