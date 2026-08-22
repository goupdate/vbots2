-- Visual Bots v0.3
-- (c)2019 Nigel Garnett.
--
-- see licence.txt
--

vbots2={}
vbots2.modpath = minetest.get_modpath("vbots2")
vbots2.bot_info = {}
-- per-player global stop-all flag (bomb button): [owner] = true means no bot of
-- this owner may run; every running bot checks it on its own tick and self-stops
vbots2.stop_all = {}
vbots2.pickup_ticks = {}

local trashInv = minetest.create_detached_inventory(
                    "bottrash",
                    {
                       on_put = function(inv, toList, toIndex, stack, player)
                          inv:set_stack(toList, toIndex, ItemStack(nil))
                       end
                    })
trashInv:set_size("main", 1)
mod_storage = minetest.get_mod_storage()
-- world-unique prefix for save isolation
local world_name = minetest.get_worldpath():match("([^\\/]+)$") or "unknown"

-- logging: writes to debug.txt (via minetest.log), toggle with vbots2.enable_log
vbots2.enable_log = true

function vbots2.log(bot_name, msg)
    if not vbots2.enable_log then return end
    minetest.log("action", "[vbots2] " .. tostring(bot_name) .. ": " .. tostring(msg))
end

-------------------------------------
-- Program inventory helpers: bot programs (p0..p6) live in detached inventory
-- botprog_<bot_key> mirrored to mod_storage["botprog_<bot_key>"]. Detached
-- inventories die on server restart -> always (re)create from the mirror
-- before use. See AGENTS.md "Inventory storage" rule.
-------------------------------------
vbots2.save_prog_inv = function(bot_key)
    if bot_key == "" then return end
    local inv = minetest.get_inventory({type="detached", name="botprog_" .. bot_key})
    if not inv then return end
    local lists = {}
    for i = 0, 6 do                  -- loop over program lists
        local listname = "p" .. i
        local arr = {}
        local size = inv:get_size(listname)
        for a = 1, size do           -- loop over slots
            arr[a] = inv:get_stack(listname, a):to_string()
        end                          -- loop over slots
        lists[listname] = arr
    end                              -- loop over program lists
    mod_storage:set_string("botprog_" .. bot_key, minetest.serialize(lists))
end

vbots2.ensure_prog_inv = function(bot_key)
    local name = "botprog_" .. bot_key
    local inv = minetest.get_inventory({type="detached", name=name})
    if inv then return inv end
    inv = minetest.create_detached_inventory(name, {
        -- duplicate non-vbots2 items (block filters) back to player's main
        on_put = function(inv2, listname, index, stack, player)
            vbots2.save_prog_inv(bot_key)
            if listname:match("^p%d$") and player and stack and not stack:is_empty() then
                local itemname = stack:get_name()
                if not itemname:match("^vbots2:") then  -- if non-command item
                    local pinv = player:get_inventory()
                    if pinv then
                        pinv:add_item("main", stack)
                    end
                end                                     -- if non-command item
            end
        end,
        on_take = function(inv2, listname, index, stack, player)
            vbots2.save_prog_inv(bot_key)
            if listname:match("^p%d$") and player and stack and not stack:is_empty() then
                local itemname = stack:get_name()
                if not itemname:match("^vbots2:") then  -- if non-command item
                    local pinv = player:get_inventory()
                    if pinv then
                        pinv:remove_item("main", stack)
                    end
                end                                     -- if non-command item
            end
        end,
        on_move = function(inv2, from_list, from_index, to_list, to_index, count, player)
            vbots2.save_prog_inv(bot_key)
        end,
    })
    for i = 0, 6 do                  -- loop over program lists
        inv:set_size("p" .. i, 56)
    end                              -- loop over program lists
    -- restore from mod_storage mirror (survives server restart)
    local data = mod_storage:get_string("botprog_" .. bot_key)
    if data ~= "" then
        local lists = minetest.deserialize(data)
        if lists and type(lists) == "table" then
            for i = 0, 6 do          -- loop over program lists
                local listname = "p" .. i
                local arr = lists[listname]
                if arr then
                    for a = 1, math.min(#arr, 56) do  -- loop over slots
                        inv:set_stack(listname, a, ItemStack(arr[a]))
                    end              -- loop over slots
                end
            end                      -- loop over program lists
        end
    end
    return inv
end

vbots2.prog_inv = function(bot_key)
    return vbots2.ensure_prog_inv(bot_key)
end

local function bot_namer()
    local first = {
        "A", "An", "Ba", "Bi", "Bo", "Bom", "Bon", "Da", "Dan",
        "Dar", "De", "Do", "Du", "Due", "Duer", "Dwa", "Fa", "Fal", "Fi",
        "Fre", "Fun", "Ga", "Gal", "Gar", "Gam", "Gim", "Glo", "Go", "Gom",
        "Gro", "Gwar", "Ib", "Jor", "Ka", "Ki", "Kil", "Lo", "Mar", "Na",
        "Nal", "O", "Ras", "Ren", "Ro", "Ta", "Tar", "Tel", "Thi", "Tho",
        "Thon", "Thra", "Tor", "Von", "We", "Wer", "Yen", "Yur"
    }
    local after = {
        "bil", "bin", "bur", "char", "den", "dir", "dur", "fri", "fur", "in",
        "li", "lin", "mil", "mur", "ni", "nur", "ran", "ri", "ril", "rimm", "rin",
        "thur", "tri", "ulf", "un", "ur", "vi", "vil", "vim", "vin", "vri"
    }
    return first[math.random(#first)] ..
           after[math.random(#after)] ..
           after[math.random(#after)]
end

-------------------------------------
-- Generate 32 bit key for formspec identification
-------------------------------------
function vbots2.get_key()
    math.randomseed(minetest.get_us_time())
    local w = math.random()
    local key = tostring( math.random(255) +
            math.random(255) * 256 +
            math.random(255) * 256*256 +
            math.random(255) * 256*256*256 )
    return key
end

-------------------------------------
-- callback from bot node on_rightclick
-------------------------------------
vbots2.bot_restore = function(pos)
    local meta = minetest.get_meta(pos)
    local bot_key = meta:get_string("key")
    local bot_owner = meta:get_string("owner")
    local bot_name = meta:get_string("name")
    -- one-time lazy migration: old bots keep programs in node meta p-lists
    local inv = meta:get_inventory()
    if inv:get_size("p0") > 0 then
        local lists = {}
        for i = 0, 6 do                  -- loop over program lists
            local listname = "p" .. i
            local arr = {}
            for a = 1, inv:get_size(listname) do  -- loop over slots
                arr[a] = inv:get_stack(listname, a):to_string()
            end                          -- loop over slots
            lists[listname] = arr
        end                              -- loop over program lists
        mod_storage:set_string("botprog_" .. bot_key, minetest.serialize(lists))
        for i = 0, 6 do                  -- loop over program lists
            inv:set_size("p" .. i, 0)
        end                              -- loop over program lists
    end                                  -- if migrating
    -- migrate missing stat keys for bots placed before progression system
    if meta:get_string("laser_damage") == "" then
meta:set_float("laser_damage", 8.0)
    meta:set_float("shot_damage", 32.0)
    meta:set_float("max_hp", 12.0)
        meta:set_float("total_kills", 0.0)
        meta:set_int("armor", 0)
        meta:set_float("laser_kills", 0)
        meta:set_float("shot_kills", 0)
    end                                                   -- if migrating stats
    vbots2.ensure_prog_inv(bot_key)
    if not vbots2.bot_info[bot_key] then
vbots2.bot_info[bot_key] = { owner = bot_owner, pos = pos, name = bot_name}
    -- minimap marker
    local marker_pos = {x = pos.x, y = pos.y + 0.5, z = pos.z}
    local marker = minetest.add_entity(marker_pos, "vbots2:minimap_marker")
    vbots2.bot_info[bot_key].marker = marker
    local body = minetest.add_entity(pos, "vbots2:bot_body")
    vbots2.bot_info[bot_key].body = body
        meta:set_string("infotext", bot_name .. " (" .. bot_owner .. ")")
        --print(dump(vbots2.bot_info))
    end
end


-------------------------------------
-- callback from bot node after_place_node
-------------------------------------
vbots2.bot_init = function(pos, placer)
    local bot_owner = placer:get_player_name()
    -- enforce per-player bot limit (max 64)
    local bot_count = 0
    for _, bi in pairs(vbots2.bot_info) do
        if bi.owner == bot_owner then bot_count = bot_count + 1 end
    end                                                 -- count player bots
    if bot_count >= 64 then
        minetest.chat_send_player(bot_owner,
            "Bot limit 64 is reached. Creation cancelled.")
        return false
    end                                                 -- if limit reached
    local bot_name = bot_namer()
    local bot_key = vbots2.get_key()
vbots2.bot_info[bot_key] = { owner = bot_owner, pos = pos, name = bot_name}
    local body = minetest.add_entity(pos, "vbots2:bot_body")
    vbots2.bot_info[bot_key].body = body
    local marker_pos = {x = pos.x, y = pos.y + 0.5, z = pos.z}
    local marker = minetest.add_entity(marker_pos, "vbots2:minimap_marker")
    vbots2.bot_info[bot_key].marker = marker
    local meta = minetest.get_meta(pos)
	meta:set_string("infotext", bot_name .. " (" .. bot_owner .. ")")
    local inv = meta:get_inventory()
    inv:set_size("main", 32)
    inv:set_size("trash", 1)
    -- programs live in detached inventory botprog_<key> (mirrored to mod_storage)
    vbots2.ensure_prog_inv(bot_key)

    meta:set_int("program",0)
    meta:mark_as_private("program")
    meta:set_string("home",minetest.serialize(pos))
    meta:mark_as_private("home")
    meta:set_int("panel",0)
    meta:mark_as_private("panel")
    meta:set_int("steptime",2)
    meta:mark_as_private("steptime")
    meta:set_string("key", bot_key)
    meta:mark_as_private("key")
	meta:set_string("owner", bot_owner)
    meta:mark_as_private("owner")
	meta:set_string("name", bot_name)
    meta:mark_as_private("name")
	meta:set_int("PC", 0)
    meta:mark_as_private("PC")
	meta:set_int("PR", 0)
    meta:mark_as_private("PR")
meta:set_int("repeat",0)
    meta:mark_as_private("repeat")
    meta:set_int("skip",0)
    meta:mark_as_private("skip")
    meta:set_string("stack","")
    meta:mark_as_private("stack")
    meta:set_int("var_a",0)
    meta:mark_as_private("var_a")
    meta:set_int("var_b",0)
    meta:mark_as_private("var_b")
    meta:set_int("var_c",0)
    meta:mark_as_private("var_c")
    meta:set_int("var_d",0)
    meta:mark_as_private("var_d")
    meta:set_string("active_var","")
    meta:mark_as_private("active_var")
    meta:set_int("goto_tx",0)
    meta:set_int("goto_ty",0)
    meta:set_int("goto_tz",0)
    meta:set_int("home_tx",0)
    meta:set_int("home_ty",0)
    meta:set_int("home_tz",0)
    meta:set_float("laser_last",0)
    meta:set_float("shot_last",0)
    meta:set_int("pvp",0)
    meta:mark_as_private("pvp")
    meta:set_float("damage_time",0)
    meta:set_string("damage_pos","")
    meta:set_float("laser_damage", 8.0)
    meta:set_float("shot_damage", 32.0)
    meta:set_float("max_hp", 12.0)
    meta:set_float("total_kills", 0.0)
    meta:set_int("armor", 0)
    meta:set_float("laser_kills", 0)
    meta:set_float("shot_kills", 0)
    -- spawn label entity above bot after activation
    minetest.after(0.1, function() vbots2.update_bot_label(pos) end)
    return true
end -- function vbots2.bot_init

vbots2.wipe_programs = function(pos)
    local meta = minetest.get_meta(pos)
    local bot_key = meta:get_string("key")
    local inv = vbots2.ensure_prog_inv(bot_key)
    for i = 0, 6 do                  -- loop over program lists
        local listname = "p" .. i
        for a = 1, inv:get_size(listname) do  -- loop over slots
            inv:set_stack(listname, a, "")
        end                          -- loop over slots
    end                              -- loop over program lists
    vbots2.save_prog_inv(bot_key)
end

vbots2.save = function(pos)
    vbots2.bot_restore(pos)
    local meta = minetest.get_meta(pos)
    local bot_key = meta:get_string("key")
    local botname = meta:get_string("name")
    local name = meta:get_string("owner")
    local inv = vbots2.ensure_prog_inv(bot_key)
    local inv_list = {}
    for i = 0, 6 do                  -- loop over program lists
        local listname = "p" .. i
        for a = 1, inv:get_size(listname) do  -- loop over slots
            local s = inv:get_stack(listname, a)
            local itemname = s:get_name()
            if s:get_count() > 0 and itemname:sub(1, 6) == "vbots2" then
                inv_list[#inv_list+1] = listname.." "..itemname.." "..s:get_count()
            end                      -- if vbots2 item
        end                          -- loop over slots
    end                              -- loop over program lists
    mod_storage:set_string(world_name..",vbotsep,"..name..",vbotsep,"..botname,minetest.serialize(inv_list))
end

-------------------------------------
-- Build owner's save list (sorted by name) for load/delete/rename
-- returns array of {name=botname, key=full_storage_key}
-------------------------------------
vbots2.get_savelist = function(pname)
    local fields = mod_storage:to_table().fields
    local list = {}
    for n,_ in pairs(fields) do              -- loop over storage fields
        local parts = string.split(n, ",vbotsep,")
        if #parts == 3 and parts[1] == world_name and parts[2] == pname then  -- if own save
            list[#list+1] = {name = parts[3], key = n}
        end                                 -- if own save
    end                                     -- loop over storage fields
    table.sort(list, function(a,b) return a.name < b.name end)  -- function sort
    return list
end                                         -- function get_savelist

vbots2.load = function(pos,player,mode)
    vbots2.bot_restore(pos)
    local meta = minetest.get_meta(pos)
    local key = meta:get_string("key")
    local saves = vbots2.get_savelist(player:get_player_name())
    local bot_list = ""
    for _,s in ipairs(saves) do             -- loop over saves
        bot_list = bot_list .. s.name .. ","
    end                                     -- loop over saves
    bot_list = bot_list:sub(1,#bot_list-1)
    local formspec
    local formname
    if not mode then
        formspec = "size[5,9]"..
                 "image_button_exit[4,8;1,1;vbots_gui_check.png;ok;]"..
                 "image_button_exit[4,0;1,1;vbots_gui_delete.png;delete;]"..
                 "tooltip[4,0;1,1;delete]"..
                 "image_button_exit[4,1;1,1;vbots_gui_rename.png;rename;]"..
                 "tooltip[4,1;1,1;rename]"..
                 "textlist[0,0;4,9;saved;"..bot_list.."]"
        formname = "loadbot,"..key
    elseif mode == "delete" then
        formspec = "size[5,9]no_prepend[]"..
                 "image_button_exit[4,8;1,1;vbots_gui_check.png;ok;]"..
                 "bgcolor[#F00]"..
                 "textlist[0,0;4,9;saved;"..bot_list.."]"
        formname = "delete,"..key
    elseif mode == "rename" then
        formspec = "size[5,9]no_prepend[]"..
                 "image_button_exit[4,8;1,1;vbots_gui_check.png;ok;]"..
                 "bgcolor[#0F0]"..
                 "textlist[0,0;4,9;saved;"..bot_list.."]"
        formname = "rename,"..key
    elseif mode:sub(1,10) == "renamefrom" then
        local fromname = mode:sub(12)
        formspec = "size[6,6]no_prepend[]"..
                 "image_button_exit[5,5;1,1;vbots_gui_check.png;ok;]"..
                 "bgcolor[#00F]"..
                 "field[0,0;5,2;oldname;Old Name;"..fromname.."]"..
                 "field[0,1;5,4;newname;New Name;]"
        formname = "renamefrom,"..key
    end
    minetest.after(0.2, minetest.show_formspec, player:get_player_name(), formname, formspec)
end




vbots2.bot_togglestate = function(pos,mode)
    local meta = minetest.get_meta(pos)
    local node = minetest.get_node(pos)
    local timer = minetest.get_node_timer(pos)
    local newname
    if not mode then
        if node.name == "vbots2:off" then
            mode = "on"
        elseif node.name == "vbots2:on" then
            mode = "off"
        end
    end
    if mode == "on" then
        newname = "vbots2:on"
        -- starting any bot lifts the owner's global stop-all flag
        vbots2.stop_all[meta:get_string("owner")] = nil
        timer:stop()                                      -- stop any running timer before restart
        timer:start(1/meta:get_int("steptime"))
        meta:set_int("PC",0)
        meta:set_int("PR",0)
        meta:set_int("repeat",0)
        meta:set_int("skip",0)
        meta:set_string("stack","")
        meta:set_string("home",minetest.serialize(pos))
    meta:set_int("nav_active", 0)
    meta:set_string("nav_path", "")
    meta:set_int("goto_tx", 0)
    meta:set_int("goto_ty", 0)
    meta:set_int("goto_tz", 0)
    meta:set_int("home_tx", 0)
    meta:set_int("home_ty", 0)
    meta:set_int("home_tz", 0)
    meta:set_float("nav_retry", 0)
        meta:set_float("state_stop_time", 0)
    elseif mode == "off" then
        newname = "vbots2:off"
        timer:stop()
        meta:set_int("PC",0)
        meta:set_int("PR",0)
        meta:set_string("stack","")
        meta:set_float("state_stop_time", minetest.get_gametime())
        meta:set_int("nav_active", 0)
        meta:set_string("nav_path", "")
    end
    -- update minimap marker texture
    if newname then
        vbots2.update_bot_label(pos)               -- ensure label stays visible
        local bot_key = meta:get_string("key")
        local bi = vbots2.bot_info[bot_key]
        if bi and bi.marker then
            local tex = (mode == "on") and "vbots_marker_on.png" or "vbots_marker_off.png"
            bi.marker:set_properties({textures = {tex}})
        end                                         -- if marker exists
    end                                             -- if newname
    --print(node.name.." "..newname)
    if newname then
        minetest.swap_node(pos,{name=newname, param2=node.param2})
    end
end


minetest.register_on_shutdown(function()
    for k, bi in pairs(vbots2.bot_info) do     -- loop over known bots
        if bi and bi.pos then
            vbots2.save_prog_inv(k)
        end
    end                                        -- loop over known bots
end)

dofile(vbots2.modpath.."/formspec.lua")
dofile(vbots2.modpath.."/formspec_handler.lua")
dofile(vbots2.modpath.."/common.lua")
dofile(vbots2.modpath.."/movement.lua")
dofile(vbots2.modpath.."/dig_build.lua")
dofile(vbots2.modpath.."/pathfinding.lua")
dofile(vbots2.modpath.."/commands.lua")
dofile(vbots2.modpath.."/timer.lua")
dofile(vbots2.modpath.."/nodes.lua")
dofile(vbots2.modpath.."/register_commands.lua")
dofile(vbots2.modpath.."/register_joinleave.lua")
