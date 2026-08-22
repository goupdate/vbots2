-- nodes.lua � Bot node definitions (on/off), minimap marker entity, combat body entity, crafting recipes
 
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
            local ok = vbots2.bot_init(pos, placer)
            if not ok then
                minetest.set_node(pos, {name = "air"})       -- cancel placement
                return
            end                                             -- if limit reached
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
            -- during movement (position_bot sets moving flag) the bot continues
            -- at newpos: keep inventory, entities and bot_info entry intact
            if meta:get_string("moving") == "1" then
                return
            end
            local inv = meta:get_inventory()
            for i = 1, inv:get_size("main") do      -- loop over slots
                local stack = inv:get_stack("main", i)
                if not stack:is_empty() then        -- if slot non-empty
                    local drop_pos = {x = pos.x, y = pos.y + 0.5, z = pos.z}
                    minetest.add_item(drop_pos, stack)
                end                                 -- if slot non-empty
            end                                     -- loop over slots
            local bot_key = meta:get_string("key")
            local bi = vbots2.bot_info[bot_key]
            -- drop the mod_storage program mirror of this bot
            mod_storage:set_string("botprog_" .. bot_key, "")
            -- remove all vbots2 entities at this position
            for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 1.5)) do  -- loop over objects
                if obj and obj:get_luaentity() then -- if object entity
                    local ename = obj:get_luaentity().name
                    if ename and ename:find("^vbots2:") then  -- if vbots2 entity
                        obj:remove()
                    end                             -- if vbots2 entity
                end                                 -- if object entity
            end                                     -- loop over objects
            vbots2.bot_info[bot_key] = nil
            clean_bot_table()
        end
})
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
        visual_size = {x = 0, y = 0, z = 0},
        textures = {"blank.png"},
        glow = 0,
        physical = false,
        collide_with_objects = false,
        pointable = false,
        static_save = false,
    },
    on_activate = function(self)
        self.object:set_armor_groups({immortal = 1})
    end,
})

-------------------------------------
-- Bot body entity (mob combat)
-------------------------------------
minetest.register_entity("vbots2:bot_body", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.3, -0.5, -0.3, 0.3, 1.5, 0.3},
        pointable = false,
        visual = "cube",
        visual_size = {x = 0, y = 0, z = 0},
        textures = {"blank.png"},
        hp_max = 27,
    },
    type = "npc",                                             -- mcl_mobs: match attack_npcs check for hostile mob targeting
    _attack = 1,
    hostile = true,
    on_activate = function(self, staticdata)
        self.object:set_armor_groups({fleshy = 100})
        local epos = self.object:get_pos()
        if epos then                                          -- if entity has position
            local bpos = {x = math.floor(epos.x + 0.5), y = math.floor(epos.y), z = math.floor(epos.z + 0.5)}
            local meta = minetest.get_meta(bpos)
            local mhp = meta:get_float("max_hp")
            if mhp <= 0 then mhp = 1.0 end
            self.object:set_hp(mhp)
            vbots2.update_bot_label(bpos)                       -- spawn label entity above bot
        else                                                  -- if entity has position
            self.object:set_hp(1)
        end                                                   -- if entity has position
    end,
    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
        -- show floating damage number above bot
        local pos = self.object:get_pos()
        if pos then
            local dmg = damage or 0
            if dmg <= 0 then
                bot_show_damage_number(pos, "-0")
            else
                bot_show_damage_number(pos, "-" .. string.format("%.1f", dmg))
            end
        end
        local hp = self.object:get_hp() - (damage or 0)
        -- track damage for damaged_check / turn_danger commands
        local epos = self.object:get_pos()
        if epos then
            local bpos = {x = math.floor(epos.x + 0.5), y = math.floor(epos.y), z = math.floor(epos.z + 0.5)}
            local meta = minetest.get_meta(bpos)
            meta:set_float("damage_time", minetest.get_gametime())
            if puncher and puncher.get_pos then
                meta:set_string("damage_pos", minetest.serialize(puncher:get_pos()))
            end
        end
        if hp <= 0 then
            -- bot destroyed — destroy the node
            local pos = self.object:get_pos()
            if pos then
                pos = {x = math.floor(pos.x + 0.5), y = math.floor(pos.y), z = math.floor(pos.z + 0.5)}
                local node = minetest.get_node(pos)
                if node.name:find("^vbots2:") then
                    -- remove label entity before destroying bot node
                    local bm = minetest.get_meta(pos)
                    local bk = bm:get_string("key")
                    if vbots2._bot_labels and vbots2._bot_labels[bk] then
                        vbots2._bot_labels[bk]:remove()
                        vbots2._bot_labels[bk] = nil
                    end                                   -- if label exists
                    minetest.set_node(pos, {name = "air"})
                end
            end
            self.object:remove()
        else
            self.object:set_hp(hp)
        end
    end,
    on_death = function(self)
        -- handled by on_punch
    end,
})

-------------------------------------
-- Bot label: standalone upright_sprite entity floating above the bot.
-- Shows combat stats as icons: Lv.N ★laser/36 ❄shot/21 ♥hp/27 🛡armor
-- Visibility: only the bot's owner sees it, and only within 5 blocks.
--------------------------------------
function vbots2.update_bot_label(bot_pos)
    local meta = minetest.get_meta(bot_pos)
    local bot_key = meta:get_string("key")
    if bot_key == "" then return end                          -- no key = not initialized
    local owner = meta:get_string("owner")
    if owner == "" then return end                            -- no owner = invalid
    local lk = tonumber(meta:get_string("laser_kills")) or 0
    local sk = tonumber(meta:get_string("shot_kills")) or 0
    local tk = tonumber(meta:get_string("total_kills")) or 0
    if lk > 19900 then lk = 19900 end                              -- cap at lv 200
    if sk > 19900 then sk = 19900 end                              -- cap at lv 200
    if tk > 4950 then tk = 4950 end                                -- cap at lv 100
    -- weapon-specific levels: laser/shot max 200, HP/armor from total_kills max 100
    local laser_lv = math.min(200, math.floor((1 + math.sqrt(1 + 8 * lk)) / 2))
    local shot_lv  = math.min(200, math.floor((1 + math.sqrt(1 + 8 * sk)) / 2))
    local shared_lv = math.min(100, math.floor((1 + math.sqrt(1 + 8 * tk)) / 2))
    if laser_lv < 1 then laser_lv = 1 end
    if shot_lv  < 1 then shot_lv  = 1 end
    if shared_lv < 1 then shared_lv = 1 end
    local laser = tonumber(meta:get_string("laser_damage")) or 3
    local shot  = tonumber(meta:get_string("shot_damage")) or 2
    local hp    = math.floor(tonumber(meta:get_string("max_hp")) or 10)
    local armor = tonumber(meta:get_string("armor")) or 0
    -- progress within shared level
    local kills_cur = shared_lv * (shared_lv - 1) / 2
    local kills_next = shared_lv * (shared_lv + 1) / 2
    local need = kills_next - kills_cur
    local have = tk - kills_cur
    local pct = need > 0 and math.floor((have / need) * 100) or 0
    if pct > 99 then pct = 99 end
    local tag = string.format("Lv.%d (%d%%)  ★%d %.1f/36  ❄%d %.1f/21  ♥ %d/27  A %d",
        shared_lv, pct, laser_lv, laser, shot_lv, shot, hp, armor)

    if not vbots2._bot_labels then vbots2._bot_labels = {} end
    -- remove old label if any
    local old = vbots2._bot_labels[bot_key]
    if old and old:get_pos() then old:remove() end
    -- spawn standalone entity above bot
    local label_pos = {x = bot_pos.x + 0.5, y = bot_pos.y - 0.5, z = bot_pos.z + 0.5}
    local obj = minetest.add_entity(label_pos, "vbots2:bot_label")
    if obj then
        local ent = obj:get_luaentity()
        ent._owner = owner
        ent._tag = tag
        obj:set_properties({nametag = tag})
        vbots2._bot_labels[bot_key] = obj
    end -- if obj spawned
end -- function vbots2.update_bot_label

-- Bot label entity: standalone upright_sprite above bot, shows combat stats with icons.
-- Visibility controlled by globalstep: owner-only, within 5 blocks radius.
minetest.register_entity("vbots2:bot_label", {
    initial_properties = {
        physical = false,
        collide_with_objects = false,
        pointable = false,
        visual = "upright_sprite",
        visual_size = {x = 0.01, y = 0.01},
        textures = {"vbots_damage_dot.png"},
        static_save = false,
        glow = 0,
        nametag = "",
        nametag_color = "#FFFF80",
    },
    on_activate = function(self, staticdata)
        self._check_timer = 0
    end, -- on_activate
    on_step = function(self, dtime)
        self._check_timer = (self._check_timer or 0) + dtime
        if self._check_timer < 0.5 then return end; self._check_timer = 0
        if not self._owner then return end                        -- not yet initialized
        local p = minetest.get_player_by_name(self._owner)
        if not p then
            self.object:set_properties({nametag = ""})            -- player offline → hide
            return
        end                                                       -- if player offline
        local ok = vector.distance(p:get_pos(), self.object:get_pos()) <= 20
        self.object:set_properties({nametag = ok and (self._tag or "") or ""})
    end, -- on_step
})

-----------------------------------------
-- Recovery: every 30s ensure all bots in active mapblocks have labels.
-----------------------------------------
minetest.register_globalstep(function(dtime)
    if not vbots2._label_recovery_timer then vbots2._label_recovery_timer = 0 end
    vbots2._label_recovery_timer = vbots2._label_recovery_timer + dtime
    if vbots2._label_recovery_timer < 30 then return end
    vbots2._label_recovery_timer = 0
    if not vbots2.bot_info then return end
    for _, info in pairs(vbots2.bot_info) do
        local bpos = info.pos
        if bpos then                                           -- bot has position
            local meta = minetest.get_meta(bpos)
            local bk = meta:get_string("key")
            if bk ~= "" then                                   -- valid key
                local old = vbots2._bot_labels and vbots2._bot_labels[bk]
                if not old or not old:get_pos() then           -- no label or dead label
                    vbots2.update_bot_label(bpos)
                end                                            -- if label missing
            end                                                -- if valid key
        end                                                    -- if has pos
    end                                                        -- loop over bot_info
end)                                                           -- globalstep

-- Floating damage text entity: RPG-style numbers above bots/mobs
-- transparent 1×1 upright_sprite with nametag, lives 1 second
minetest.register_entity("vbots2:damage_text", {
    initial_properties = {
        physical = false,
        collide_with_objects = false,
        pointable = false,
        visual = "upright_sprite",
        visual_size = {x = 0.01, y = 0.01},
        textures = {"vbots_damage_dot.png"},
        static_save = false,
        glow = 0,
        nametag = "",
    },
    on_activate = function(self, staticdata)
        self._expire = minetest.get_gametime() + 1.0 -- 1 second lifetime
    end,                                                -- on_activate
    on_step = function(self, dtime)
        if minetest.get_gametime() >= self._expire then
            self.object:remove()
        end                                             -- if expired
    end,                                                -- on_step
})

-- Make MCL/VL hostile mobs target bot_body as a valid attack target
-- MCL combat.lua:342 requires: specific_attack(name) AND (type=="npc" AND attack_npcs)
-- bot_body now has type="npc", so we add attack_npcs=true + specific_attack to all monster-type mobs
minetest.after(1, function()
    for name, def in pairs(minetest.registered_entities) do
        if def.type == "monster" then                          -- only hostile monsters
            -- Add attack_npcs so npc-type entities (incl. bot_body) are valid targets
            if def.attack_npcs == nil then
                def.attack_npcs = true
            end                                               -- if attack_npcs nil
            -- Add specific_attack table if missing (nil returns true = attacks everything)
            if def.specific_attack == nil then
                def.specific_attack = {"vbots2:bot_body"}
            elseif type(def.specific_attack) == "table" then  -- if specific_attack nil
                local has_vbots = false
                for _, t in ipairs(def.specific_attack) do
                    if t == "vbots2:bot_body" then has_vbots = true; break end
                end                                           -- loop over specific_attack
                if not has_vbots then
                    table.insert(def.specific_attack, "vbots2:bot_body")
                end                                           -- if not has_vbots
            end                                               -- if specific_attack nil
        end                                                   -- if type monster
    end                                                       -- loop over registered_entities
end)

-- Bot projectile (snowball with gravity, damage on hit)
minetest.register_entity("vbots2:projectile_snowball", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.15, -0.15, -0.15, 0.15, 0.15, 0.15},
        visual = "sprite",
        visual_size = {x = 0.5, y = 0.5, z = 0.5},
        textures = {"vbots_snowball.png"},
        pointable = false,
        static_save = false,
    },
    _damage = 4,
    _shooter = nil,
    _pvp = false,
    _owner_name = "",
    on_activate = function(self, staticdata)
        self.object:set_acceleration({x = 0, y = 0, z = 0})
        self._timer = 0
        if staticdata and staticdata ~= "" then
            local data = minetest.deserialize(staticdata)
            if data then
                self._damage = data.damage or 4
                self._shooter = data.shooter
            end
        end
    end,
on_step = function(self, dtime)
        self._timer = (self._timer or 0) + dtime
        if self._timer > 5 then
                local bmeta = self._bot_pos and minetest.get_meta(self._bot_pos)
                local bname = bmeta and bmeta:get_string("name") or "?"
                vbots2.log(bname, "SHOT miss")
                self.object:remove(); return
            end
        local pos = self.object:get_pos()
        if not pos then return end
        local node = minetest.get_node(pos)
        if node.name ~= "air" and node.name ~= "ignore" then
            local ndef = minetest.registered_nodes[node.name]
            if ndef and ndef.walkable then
                local bmeta = self._bot_pos and minetest.get_meta(self._bot_pos)
                    local bname = bmeta and bmeta:get_string("name") or "?"
                    vbots2.log(bname, "SHOT miss")
                    self.object:remove()
                    return
            end
        end
        for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 1.5)) do
            if obj ~= self.object then
                local hittable = false
                local hitname = "?"
                if obj:is_player() then
                    -- P2P: only hit other players when active and not the owner
                    local pname = obj:get_player_name()
                    hitname = pname
                    if self._pvp and pname ~= "" and pname ~= self._owner_name then
                        hittable = true
                    end
                elseif obj:get_luaentity() then
                    local ent = obj:get_luaentity()
                    hitname = ent and ent.name or "?"
                    if ent and ent.name ~= "__builtin:item" and not ent.name:match("^vbots2:") then
                        hittable = true
                    end
                end
                if hittable then
                    local hp = obj:get_hp()
                    local hp_after = math.max(0, hp - self._damage)
                    -- read bot stats for log
                    local bmeta = self._bot_pos and minetest.get_meta(self._bot_pos)
                    local bname = bmeta and bmeta:get_string("name") or "?"
                    local ld = bmeta and bmeta:get_float("laser_damage") or 0
                    local ss = bmeta and bmeta:get_float("shot_damage") or 0
                    local mh = bmeta and bmeta:get_float("max_hp") or 0
                    vbots2.log(bname, string.format("SHOT hit %s dmg=%.1f left=%d ★%.2f ❄%.2f ♥%.2f",
                        tostring(hitname), self._damage, hp_after, ld, ss, mh))
                    obj:set_hp(hp_after)
                    -- self-heal bot_body on hit (+0.02)
                    if self._bot_pos then
                        local skey = bmeta and bmeta:get_string("key")
                        if skey then
                            for _, bobj in ipairs(minetest.get_objects_inside_radius(self._bot_pos, 0.5)) do
                                local bent = bobj:get_luaentity()
                                if bent and bent.name == "vbots2:bot_body" and bent._key == skey then
                                    bobj:set_hp(math.min(mh, math.floor(bobj:get_hp() + 0.02)))
                                    break
                                end -- if bot_body match
                            end -- loop over bot pos objects
                        end -- if skey set
                    end -- if bot_pos set
                    -- floating damage number above hit entity
                    local mobpos = obj:get_pos()
                    if mobpos then
                        local lost = hp - hp_after
                        if lost <= 0 then
                            bot_show_damage_number(mobpos, "-0")
                        else
                            bot_show_damage_number(mobpos, "-" .. string.format("%.1f", lost))
                        end                                                     -- if lost > 0
                    end                                                         -- if mobpos
                    if hp_after == 0 and hp > 0 and self._bot_pos and bmeta then
                        local vt = obj:is_player() and "player" or hitname
                        update_bot_kill_stats(bmeta, self._bot_pos, false, vt, hp, 0)   -- shot kill
                        local nss = bmeta:get_float("shot_damage")
                        local nmh = bmeta:get_float("max_hp")
                        local upd = ""
                        if nss ~= ss then upd = upd .. string.format("❄%.2f→%.2f", ss, nss) end
                        if nmh ~= mh then upd = upd .. (upd ~= "" and " " or "") .. string.format("♥%.2f→%.2f", mh, nmh) end
                        vbots2.log(bname, "SHOT kill " .. tostring(hitname) .. " upd " .. upd)
                    end                                                      -- if shot kill
                    self.object:remove()
                    return
                end
            end
        end
    end,
})
