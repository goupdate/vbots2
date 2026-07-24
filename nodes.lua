-- nodes.lua — Bot node definitions (on/off), minimap marker entity, combat body entity, crafting recipes
 
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
            -- remove all vbots2 entities at this position
            for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 1.5)) do
                if obj and obj:get_luaentity() then
                    local ename = obj:get_luaentity().name
                    if ename and ename:find("^vbots2:") then
                        obj:remove()
                    end
                end
            end
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
        hp_max = 20,
        -- Mobs target entities with type="npc" (monsters don't attack other monsters)
    },
    type = "npc",
    on_activate = function(self, staticdata)
        self.object:set_armor_groups({fleshy = 100})
        self.object:set_hp(20)
    end,
    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
        if not damage then return end
        local hp = self.object:get_hp() - damage
        if hp <= 0 then
            -- bot destroyed â€” destroy the node
            local pos = self.object:get_pos()
            if pos then
                pos = {x = math.floor(pos.x + 0.5), y = math.floor(pos.y), z = math.floor(pos.z + 0.5)}
                local node = minetest.get_node(pos)
                if node.name:find("^vbots2:") then
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
