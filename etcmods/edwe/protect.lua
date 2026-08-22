-- edwe/protect.lua — Protection Totem: zone-based building/digging protection
-- One golden block + tablet label entity per totem. Limit 10 per player.
-- Zone: ±20 X/Z (41×41 column), full Y height.

-------------------------------------
-- In-memory totem index
--------------------------------------
if not edwe._totems then
    edwe._totems = {}                           -- {[player] = {count=N, zones={[hash]=true}}}
end                                             -- if not edwe._totems

-- Hash: collapse (x,z) into single key for fast lookup
local function totem_hash(x, z)
    return x * 65536 + z
end                                             -- function totem_hash

-- Check if a position is inside any totem zone of another player
function edwe.is_totem_protected(pos, player_name)
    local px, pz = pos.x, pos.z
    for owner, data in pairs(edwe._totems) do
        if owner ~= player_name then
            for hx, hz in pairs(data.zones) do
                if math.abs(px - hx) <= 20 and math.abs(pz - hz) <= 20 then
                    return true
                end                                         -- if in zone
            end                                             -- loop over zones
        end                                                 -- if not owner
    end                                                     -- loop over owners
    return false
end                                                         -- function edwe.is_totem_protected

-------------------------------------
-- Register / unregister totem zones
--------------------------------------
local function register_totem_zone(player_name, x, z)
    if not edwe._totems[player_name] then
        edwe._totems[player_name] = {count = 0, zones = {}}
    end                                                     -- if new player
    local data = edwe._totems[player_name]
    data.count = data.count + 1
    local h = totem_hash(x, z)
    data.zones[{x = x, z = z}] = true                       -- key = table, value = true
end                                                         -- function register_totem_zone

local function unregister_totem_zone(player_name, x, z)
    local data = edwe._totems[player_name]
    if not data then return end
    data.count = data.count - 1
    for key, _ in pairs(data.zones) do
        if key.x == x and key.z == z then
            data.zones[key] = nil; break
        end                                                 -- if match
    end                                                     -- loop over zones
    if data.count <= 0 then edwe._totems[player_name] = nil end
end                                                         -- function unregister_totem_zone

-------------------------------------
-- Protection handler: fires for every node punch/dig/place
--------------------------------------
if minetest.register_protection_handler then
    minetest.register_protection_handler(function(pos, name)
        return edwe.is_totem_protected(pos, name)
    end)                                                    -- protection_handler
end                                                         -- if API available (Luanti 5.15+)

-------------------------------------
-- Totem label entity: floating gold tablet above totem
--------------------------------------
minetest.register_entity("edwe:totem_label", {
    initial_properties = {
        physical = false,
        collide_with_objects = false,
        pointable = false,
        visual = "cube",
        visual_size = {x = 0.01, y = 0.01},
        textures = {
            "edwe_totem_tablet.png", "edwe_totem_tablet.png",
            "edwe_totem_tablet.png", "edwe_totem_tablet.png",
            "edwe_totem_tablet.png", "edwe_totem_tablet.png",
        },
        static_save = false,
        glow = 0,
        nametag = "",
        nametag_color = "#FFD700",
    },
    on_activate = function(self, staticdata)
    end,                                                    -- on_activate
    on_step = function(self, dtime)
    end,                                                    -- on_step
})

-------------------------------------
-- Spawn label entity above totem
--------------------------------------
local function spawn_totem_label(pos, owner, n)
    local lp = {x = pos.x + 0.5, y = pos.y + 1.2, z = pos.z + 0.5}
    local obj = minetest.add_entity(lp, "edwe:totem_label")
    if obj then
        local tag = owner .. " : totem " .. n
        obj:set_properties({nametag = tag})
    end                                                     -- if obj
end                                                         -- function spawn_totem_label

-------------------------------------
-- Remove label entity at totem position
--------------------------------------
local function remove_totem_label(pos)
    for _, obj in ipairs(minetest.get_objects_inside_radius(
        {x = pos.x + 0.5, y = pos.y + 1.2, z = pos.z + 0.5}, 0.5)) do
        local ent = obj:get_luaentity()
        if ent and ent.name == "edwe:totem_label" then
            obj:remove(); break
        end                                                 -- if label entity
    end                                                     -- loop over objects
end                                                         -- function remove_totem_label

-------------------------------------
-- Protection Totem node
--------------------------------------
minetest.register_node("edwe:protect_totem", {
    description = "Protection Totem (zone ±20, max 10 per player)",
    tiles = {"edwe_totem_block.png"},
    groups = {cracky = 1},
    paramtype = "light",
    drawtype = "normal",
    sunlight_propagates = true,

    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then return itemstack end
        local pos = pointed_thing.above
        local name = placer:get_player_name()
        local data = edwe._totems[name]
        if data and data.count >= 10 then
            minetest.chat_send_player(name,
                "EdWorldEdit : totem limit reached (max 10)")
            return itemstack
        end                                                 -- if limit reached
        local n = (data and data.count + 1) or 1
        local meta = minetest.get_meta(pos)
        meta:set_string("owner", name)
        meta:set_int("totem_n", n)
        meta:set_string("edwe_totem", "1")
        register_totem_zone(name, pos.x, pos.z)
        spawn_totem_label(pos, name, n)
        minetest.chat_send_player(name,
            "EdWorldEdit : totem " .. n .. " placed (zone ±20)")
        return minetest.item_place(itemstack, placer, pointed_thing)
    end,                                                    -- on_place

    can_dig = function(pos, player)
        local meta = minetest.get_meta(pos)
        local owner = meta:get_string("owner")
        if player and player:get_player_name() ~= owner then
            return false
        end                                                 -- if not owner
        return true
    end,                                                    -- can_dig

    after_dig_node = function(pos, oldnode, oldmetadata, digger)
        local meta = oldmetadata and oldmetadata.fields and oldmetadata.fields
        if meta and meta.owner then
            unregister_totem_zone(meta.owner, pos.x, pos.z)
        end                                                 -- if meta owner
        remove_totem_label(pos)
    end,                                                    -- after_dig_node
})

-------------------------------------
-- LBM: restore totem index on chunk load
--------------------------------------
minetest.register_lbm({
    name = "edwe:restore_totems",
    nodenames = {"edwe:protect_totem"},
    run_at_every_load = true,
    action = function(pos, node)
        local meta = minetest.get_meta(pos)
        local owner = meta:get_string("owner")
        local n = meta:get_int("totem_n")
        if owner == "" then return end
        register_totem_zone(owner, pos.x, pos.z)
        -- re-spawn label (safe: spawn_totem_label overwrites old)
        spawn_totem_label(pos, owner, n)
    end,                                                    -- LBM action
})