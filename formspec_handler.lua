
-------------------------------------
-- generate new key & move data in table
-------------------------------------
local function bot_rekey(bot_key,meta)
    local new_key = vbots2.get_key()
    vbots2.bot_info[new_key] = vbots2.bot_info[bot_key]
    vbots2.bot_info[bot_key] = nil
    meta:set_string("key", new_key)
    return new_key
end

minetest.register_on_player_receive_fields(function(player, bot_key, fields)
    --print(dump( fields))
    local bot_data = vbots2.bot_info[bot_key]
    -- Bot main formspec
    if bot_data then
        -- print("Main Bot formspec received:")
        local inv=minetest.get_inventory({type="node", pos=bot_data.pos})
        local meta = minetest.get_meta(bot_data.pos)
        local meta_bot_key = meta:get_string("key")
        -- print(bot_key.." vs "..meta_bot_key)
        if bot_key == meta_bot_key then
            bot_key = bot_rekey(bot_key,meta)
            if fields.run then
                minetest.after(0, vbots2.bot_togglestate, bot_data.pos, "on")
            end
            if fields.save then
                vbots2.save(bot_data.pos)
            end
            if fields.load then
                vbots2.load(bot_data.pos,player)
            end
            if fields.reset then
                vbots2.wipe_programs(bot_data.pos)
            end
            if fields.removeall then
                local pname = player:get_player_name()
                local now = minetest.get_gametime()
                vbots2.removeall_last = vbots2.removeall_last or {}
                local last = vbots2.removeall_last[pname]
                if last and (now - last) <= 2 then
                    -- second press: destroy all player's bots
                    local to_remove = {}
                    for k, v in pairs(vbots2.bot_info) do
                        if v.owner == pname then
                            table.insert(to_remove, {key = k, pos = v.pos, name = v.name})
                        end
                    end
                    for _, bot in ipairs(to_remove) do
                        local bi = vbots2.bot_info[bot.key]
                        if bi and bi.marker then
                            bi.marker:remove()
                        end
                        if bi and bi.body then
                            bi.body:remove()
                        end
                        if bi and bi.state_marker then
                            bi.state_marker:remove()
                        end
                        vbots2.bot_info[bot.key] = nil
                        minetest.set_node(bot.pos, {name = "air"})
                    end
                    vbots2.removeall_last[pname] = nil
                    minetest.chat_send_player(pname,
                        "[vbots2] Removed " .. #to_remove .. " bot(s).")
                else
                    -- first press (or timer reset): stop all player's bots
                    local stopped = {}
                    for k, v in pairs(vbots2.bot_info) do
                        if v.owner == pname then
                            local node = minetest.get_node(v.pos)
                            if node.name == "vbots2:on" then
                                vbots2.bot_togglestate(v.pos, "off")
                                table.insert(stopped, v.name .. " (" ..
                                    v.pos.x .. "," .. v.pos.y .. "," .. v.pos.z .. ")")
                            end
                        end
                    end
                    minetest.chat_send_player(pname,
                        "[vbots2] All bots stopped. Press again within 2s to REMOVE.")
                    if #stopped > 0 then
                        minetest.log("action", "[vbots2] " .. pname .. " stopped: " ..
                            table.concat(stopped, ", "))
                    end
                    vbots2.removeall_last[pname] = now
                end
            end
            if fields.quit=="true" then
                return
            end
            if fields.commands then
                meta:set_int("panel", 0)
            end
            if fields.player_inv then
                meta:set_int("panel", 1)
            end
            if fields.bot_name then
                local newname = fields.bot_name:gsub("^%s+", ""):gsub("%s+$", "")
                if newname ~= "" and newname ~= meta:get_string("name") then
                    meta:set_string("name", newname)
                    meta:set_string("infotext", newname .. " (" .. meta:get_string("owner") .. ")")
                    bot_data.name = newname
                end
            end
            if fields.trash then
                local last = 0
                local content = inv:get_list("p"..meta:get_int("program"))
                for a = 1,56 do
                    if not content[a]:is_empty() then last=a end
                end
                if last>0 then
                    inv:set_stack("p"..meta:get_int("program"), last, ItemStack(nil))
                end
            end
            if fields.goto_pos then
                local formname = "gotocoords," .. bot_key
                local ppos = player:get_pos()
                local px, py, pz = math.floor(ppos.x + 0.5), math.floor(ppos.y), math.floor(ppos.z + 0.5)
                local fs = "size[5,4]" ..
                    "label[0.5,0.1;Your position: " .. px .. "," .. py .. "," .. pz .. "]" ..
                    "field[0.5,0.8;4,1;gotox;X;]" ..
                    "field[0.5,1.8;4,1;gotoy;Y;]" ..
                    "field[0.5,2.8;4,1;gotoz;Z;]" ..
                    "button_exit[1,3.8;3,1;okgo;Set & Insert]"
                minetest.after(0.1, minetest.show_formspec, player:get_player_name(), formname, fs)
            end
            if not fields.exit and not fields.run then
                for f,v in pairs(fields) do
                    -- f1-f6 are single-token (no underscore)
                    local nametable=string.split(f, "_")
                    if f == "f1" or f == "f2" or f == "f3" or f == "f4" or f == "f5" or f == "f6" then
                        local leftover = inv:add_item("p"..meta:get_int("program"), ItemStack("vbots2:"..f))
                    elseif #nametable>=2 then
                        if nametable[1]=="sub" then
                            meta:set_int("program", nametable[2])
                            -- print(dump(
                        end
                        if nametable[1]=="move" or
                                nametable[1]=="turn" or
                                nametable[1]=="number" or
                                nametable[1]=="mode" or
                                nametable[1]=="gt" or
                                nametable[1]=="lt" or
                                nametable[1]=="gte" or
                                nametable[1]=="lte" or
                                nametable[1]=="neq" or
                                nametable[1]=="dig" or
                                nametable[1]=="end" or
                                nametable[1]=="var" or
                                nametable[1]=="sign" or
                                nametable[1]=="go" or
                                nametable[1]=="redstone" or
                                nametable[1]=="goto" or
                                f == "count" then
                            --print("COMMAND!!!!!!!")
                            local leftover = inv:add_item("p"..meta:get_int("program"), ItemStack("vbots2:"..f))
                        end
                    end
                end
                minetest.after(0, vbots2.show_formspec, player, bot_data.pos)
            end
        end
    else
        local form_parts = string.split(bot_key,",")
        local data = mod_storage:to_table()
        local bot_list = {}
        for n,d in pairs(data.fields) do
            bot_list[#bot_list+1] = n
        end
        if #form_parts == 2 and form_parts[1] == "gotocoords" then
            -- Coordinate input for goto_pos
            local bot_data = vbots2.bot_info[form_parts[2]]
            if bot_data then
                local pos = bot_data.pos
                local meta = minetest.get_meta(pos)
                local inv = meta:get_inventory()
                minetest.close_formspec(player:get_player_name(), bot_key)
                if fields.okgo then
                    local x = tonumber(fields.gotox)
                    local y = tonumber(fields.gotoy)
                    local z = tonumber(fields.gotoz)
                    if x and y and z then
                        local stack = ItemStack("vbots2:goto_pos")
                        local smeta = stack:get_meta()
                        smeta:set_int("pos_x", x)
                        smeta:set_int("pos_y", y)
                        smeta:set_int("pos_z", z)
                        smeta:set_string("description", "Go to " .. x .. "," .. y .. "," .. z)
                        inv:add_item("p"..meta:get_int("program"), stack)
                    end
                end
                minetest.after(0.1, vbots2.show_formspec, player, pos)
            end
        elseif #form_parts == 2 and form_parts[1] == "loadbot" then
            -- print("Load Bot formspec received")
            local bot_data = vbots2.bot_info[form_parts[2]]
            local pos=bot_data.pos
            local meta = minetest.get_meta(pos)
            local inv = meta:get_inventory()

            minetest.close_formspec(player:get_player_name(), bot_key)
            if fields.delete then
                vbots2.load(pos,player,"delete")
            end
            if fields.rename then
                vbots2.load(pos,player,"rename")
            end
            if fields.saved then
                local bot_name = bot_list[tonumber(string.split(fields.saved,":")[2])]
                -- print('Loadbot '..bot_name)
                local inv_list = minetest.deserialize(data.fields[bot_name])
                local inv_involved = {}
                if inv_list then
                    for _,v in pairs(inv_list) do
                        local parts = string.split(v," ")
                        if #parts == 3 then
                            inv_involved[parts[1]]=true
                        end
                    end
                    -- print(dump(inv_involved))
                    local size
                    for i,_ in pairs(inv_involved) do
                        size = inv:get_size(i)
                        for a=1,size do
                            inv:set_stack(i,a, "")
                        end
                    end
                    for _,v in pairs(inv_list) do
                        local parts = string.split(v," ")
                        if #parts == 3 then
                            inv:add_item(parts[1],parts[2].." "..parts[3])
                        end
                    end
                end
            end
        elseif #form_parts == 2 and form_parts[1] == "delete" then
            -- print("Delete Bot formspec received")
            local bot_data = vbots2.bot_info[form_parts[2]]
            local pos=bot_data.pos
            minetest.close_formspec(player:get_player_name(), bot_key)
            if fields.saved then
                local bot_name = bot_list[tonumber(string.split(fields.saved,":")[2])]
                data.fields[bot_name]=nil
                mod_storage:from_table(data)
                --print(dump(mod_storage:to_table()))
            end
        elseif #form_parts == 2 and form_parts[1] == "rename" then
            -- print("Rename Bot formspec received")
            local bot_data = vbots2.bot_info[form_parts[2]]
            local pos=bot_data.pos
            minetest.close_formspec(player:get_player_name(), bot_key)
            if fields.saved then
                local bot_name = bot_list[tonumber(string.split(fields.saved,":")[2])]
                -- print("renamefrom_"..bot_name)
                local parts = string.split(bot_name,",vbotsep,")
                if #parts == 2 and parts[1] == player:get_player_name() then
                    bot_name = parts[2]
                    -- print("renamefrom_"..bot_name)

                    vbots2.load(pos,player,"renamefrom_"..bot_name)
                end

            end
        elseif #form_parts == 2 and form_parts[1] == "renamefrom" then
            -- print("Renameto formspec received")
            local bot_data = vbots2.bot_info[form_parts[2]]
            local pos=bot_data.pos
            local pname = player:get_player_name()
            minetest.close_formspec(pname, bot_key)
            local oldname = fields.oldname
            local newname = fields.newname
            if newname and oldname then
                local hold = data.fields[pname..",vbotsep,"..oldname]
                data.fields[pname..",vbotsep,"..oldname] = nil
                data.fields[pname..",vbotsep,"..newname] = hold
                mod_storage:from_table(data)
                -- print("renamed "..pname..",vbotsep,"..oldname.." to "..pname..",vbotsep,"..newname)
            end
        end
    end
end)
