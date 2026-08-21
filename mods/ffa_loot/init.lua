-- Each entry is rolled once whenever a chest refills.  Keeping the odds on
-- the entries themselves (instead of rolling the whole table several times)
-- makes a refill predictable to balance: `chance = 0.25` means a 25% chance
-- for that stack to be present in this chest.
local regular_loot = {
    -- Building and survival
    {name = "skywars:leaves", chance = 1.00, min = 12, max = 20},
    {name = "skywars:wool_blue", chance = 0.45, min = 4, max = 10},
    {name = "xdecor:baricade", chance = 0.20, min = 1, max = 3},
    {name = "xdecor:cobweb", chance = 0.10, min = 1, max = 3},
    {name = "default:apple", chance = 0.25, min = 2, max = 4},
    {name = "farming:bread", chance = 0.05, min = 1, max = 3},

    -- Early combat
    {name = "default:sword_steel", chance = 0.40, max = 1},
    {name = "default:sword_bronze", chance = 0.25, max = 1},
    {name = "default:axe_steel", chance = 0.12, max = 1},
    {name = "ctf_ranged:pistol", chance = 0.25, max = 1},
    {name = "shooter_crossbow:crossbow", chance = 0.14, max = 1},
    {name = "shooter_crossbow:arrow_white", chance = 0.30, min = 4, max = 10},
    {name = "ctf_ranged:ammo", chance = 0.35, min = 2, max = 5},
    {name = "skywars:fireball", chance = 0.20, min = 1, max = 2},

    -- Armors
    {name = "3d_armor:helmet_steel", chance = 0.16, max = 1},
    {name = "3d_armor:chestplate_steel", chance = 0.10, max = 1},
    {name = "3d_armor:leggings_steel", chance = 0.10, max = 1},
    {name = "3d_armor:boots_steel", chance = 0.16, max = 1},
    {name = "shields:shield_steel", chance = 0.18, max = 1},
}

local mese_loot = {
    {name = "skywars:acacia_leaves", chance = 1.00, min = 12, max = 20},
    {name = "skywars:wool_blue", chance = 0.60, min = 6, max = 14},
    {name = "xdecor:cobweb", chance = 0.30, min = 2, max = 5},
    {name = "xdecor:baricade", chance = 0.22, min = 1, max = 3},
    {name = "default:apple", chance = 0.35, min = 3, max = 6},
    {name = "farming:bread", chance = 0.20, min = 2, max = 5},

    {name = "default:sword_mese", chance = 0.25, max = 1},
    {name = "default:axe_mese", chance = 0.13, max = 1},
    {name = "ctf_ranged:rifle_loaded", chance = 0.18, max = 1},
    {name = "ctf_ranged:ammo", chance = 0.48, min = 5, max = 10},
    {name = "fire:flint_and_steel", chance = 0.15, max = 1},
    {name = "skywars:fireball", chance = 0.30, min = 1, max = 3},
    {name = "tnt:tnt", chance = 0.25, min = 1, max = 3},

    {name = "3d_armor:helmet_bronze", chance = 0.22, max = 1},
    {name = "3d_armor:chestplate_bronze", chance = 0.15, max = 1},
    {name = "3d_armor:leggings_bronze", chance = 0.15, max = 1},
    {name = "3d_armor:boots_bronze", chance = 0.22, max = 1},
    {name = "shields:shield_bronze", chance = 0.25, max = 1},
    {name = "3d_armor:helmet_gold", chance = 0.16, max = 1},
    {name = "3d_armor:chestplate_gold", chance = 0.09, max = 1},
    {name = "3d_armor:leggings_gold", chance = 0.09, max = 1},
    {name = "3d_armor:boots_gold", chance = 0.16, max = 1},
    {name = "shields:shield_gold", chance = 0.13, max = 1},

    -- Mobility and keys
    {name = "wind_pearl:wind_pearl", chance = 0.25, min = 1, max = 2},
    {name = "enderpearl:ender_pearl", chance = 0.10, min = 1, max = 2},
    {name = "ffa_loot:diamond_key", chance = 0.05, max = 1},
}

local diamond_loot = {
    {name = "skywars:wool_blue", chance = 1.00, min = 10, max = 20},
    {name = "farming:bread", chance = 0.85, min = 4, max = 6},
    {name = "default:apple", chance = 0.30, min = 2, max = 5},

    {name = "default:sword_diamond", chance = 0.35, max = 1},
    {name = "default:axe_diamond", chance = 0.14, max = 1},
    {name = "ctf_ranged:smg_loaded", chance = 0.30, max = 1},
    {name = "ctf_ranged:shotgun_loaded", chance = 0.30, max = 1},
    {name = "ctf_ranged:rifle_loaded", chance = 0.14, max = 1},
    {name = "ctf_ranged:ammo", chance = 0.65, min = 6, max = 12},
    {name = "skywars:fireball", chance = 0.25, min = 1, max = 3},

    {name = "enderpearl:ender_pearl", chance = 0.30, min = 1, max = 3},
    {name = "wind_pearl:wind_pearl", chance = 0.35, min = 1, max = 3},

    {name = "3d_armor:helmet_diamond", chance = 0.20, max = 1},
    {name = "3d_armor:chestplate_diamond", chance = 0.12, max = 1},
    {name = "3d_armor:leggings_diamond", chance = 0.12, max = 1},
    {name = "3d_armor:boots_diamond", chance = 0.20, max = 1},
    {name = "shields:shield_diamond", chance = 0.20, max = 1},

    -- Lifesavers
    {name = "skywars:golden_apple", chance = 0.05, max = 1},
    {name = "skywars:totem_of_undying", chance = 0.025, max = 1},
    {name = "skywars:sword_shadow", chance = 0.025, max = 1},
}

local REGULAR_CHEST = 30
local MESE_CHEST = 60
local DIAMOND_CHEST = 15

local function fill_chest_random(pos, loot)
    local meta = core.get_meta(pos)
    local inv = meta:get_inventory()
    local size = inv:get_size("main")
    inv:set_list("main", {})

    -- Pick an unused inventory slot for every successful roll. The previous
    -- implementation selected a slot independently and could overwrite an
    -- earlier reward, which made both the real drop count and the advertised
    -- probabilities unreliable.
    local empty_slots = {}
    for slot = 1, size do
        empty_slots[slot] = slot
    end

    local available_slots = size
    for _, item in ipairs(loot) do
        if available_slots == 0 then
            break
        end

        if core.registered_items[item.name] and math.random() <= item.chance then
            local index = math.random(1, available_slots)
            local slot = empty_slots[index]
            empty_slots[index] = empty_slots[available_slots]
            empty_slots[available_slots] = nil
            available_slots = available_slots - 1

            local minimum = item.min or 1
            local maximum = math.max(minimum, item.max or minimum)
            local amount = math.random(minimum, maximum)
            inv:set_stack("main", slot, ItemStack(item.name .. " " .. amount))
        end
    end
end

local function construct_node(pos, infotext)
    local meta = core.get_meta(pos)
    meta:set_string("infotext", infotext)
    local inv = meta:get_inventory()
    inv:set_size("main", 8*4)
    core.get_node_timer(pos):start(1)
end

local function update_node(pos, refill_time, loot)
    local meta = core.get_meta(pos)
    local timer = meta:get_int("timer")
    local time_left = (refill_time - timer)
    local infotext = meta:get_string("infotext")

    meta:set_int("timer", timer + 1)
    meta:set_string("infotext", ("%s, Filling in %ds"):format(infotext:split(",")[1], time_left))

    if time_left <= 0 then
        fill_chest_random(pos, loot)
    end

    -- Reset node timer
    if timer >= refill_time then
        meta:set_int("timer", 0)
    end
end

local function regular_chest_on_rightclick(pos, node, clicker)
    local cn = clicker:get_player_name()

    if default.chest.open_chests[cn] then
        default.chest.chest_lid_close(cn)
    end
    core.sound_play("default_chest_open", {gain = 0.3, pos = pos, max_hear_distance = 10}, true)
    if not default.chest.chest_lid_obstructed(pos) then
        core.swap_node(pos, {name = "ffa_loot:regular_chest_open", param2 = node.param2 })
    end
    core.after(0.2, core.show_formspec, cn, "ffa_loot:regular_chest", default.chest.get_chest_formspec(pos))
    default.chest.open_chests[cn] = { pos = pos, sound = "default_chest_close", swap = "ffa_loot:regular_chest" }
end

local function mese_chest_on_rightclick(pos, node, clicker)
    local cn = clicker:get_player_name()

    if default.chest.open_chests[cn] then
        default.chest.chest_lid_close(cn)
    end
    core.sound_play("default_chest_open", {gain = 0.3, pos = pos, max_hear_distance = 10}, true)
    if not default.chest.chest_lid_obstructed(pos) then
        core.swap_node(pos, {name = "ffa_loot:mese_chest_open", param2 = node.param2 })
    end
    core.after(0.2, core.show_formspec, cn, "ffa_loot:mese_chest", default.chest.get_chest_formspec(pos))
    default.chest.open_chests[cn] = { pos = pos, sound = "default_chest_close", swap = "ffa_loot:mese_chest" }
end

--
--- REGULAR CHEST
--

core.register_node("ffa_loot:regular_chest", {
	description = "Regular Chest",
	tiles = {
		"default_chest_top.png",
		"default_chest_top.png",
		"default_chest_side.png",
		"default_chest_side.png",
        "default_chest_side.png",
		"default_chest_front.png",
	},
	paramtype = "light",
    paramtype2 = "facedir",
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	groups = {unbreakable=1},
    on_construct = function(pos) construct_node(pos, "Regular Chest") end,
    on_rightclick = function(pos, node, clicker) regular_chest_on_rightclick(pos, node, clicker) end,
    on_timer = function(pos, elapsed)
        update_node(pos, REGULAR_CHEST, regular_loot)
        return true
    end,
    on_blast = function() end,
})

core.register_node("ffa_loot:regular_chest_open", {
	description = "Regular Chest Opened",
	tiles = {
        {name = "default_chest_top.png", backface_culling = true},
        {name = "default_chest_top.png", backface_culling = true},
        {name = "default_chest_side.png", backface_culling = true},
        {name = "default_chest_side.png", backface_culling = true},
        {name = "default_chest_front.png", backface_culling = true},
        {name = "default_chest_inside.png", backface_culling = true},
	},
    selection_box = {
		type = "fixed",
		fixed = { -1/2, -1/2, -1/2, 1/2, 3/16, 1/2 },
	},
    drawtype = "mesh",
    mesh = "chest_open.obj",
	paramtype = "light",
    paramtype2 = "facedir",
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	groups = {unbreakable=1, not_in_creative_inventory=1},
    on_construct = function(pos) construct_node(pos, "Regular Chest") end,
    on_rightclick = function(pos, node, clicker) regular_chest_on_rightclick(pos, node, clicker) end,
    on_timer = function(pos, elapsed)
        update_node(pos, REGULAR_CHEST, regular_loot)
        return true
    end,
    on_blast = function() end,
    drop = "ffa_loot:regular_chest"
})

--
--- MESE CHEST
--

core.register_node("ffa_loot:mese_chest", {
	description = "Mese Chest",
	tiles = {
        "(default_chest_top.png^default_mese_crystal.png)^[colorize:#FFDF20:100",
        "default_chest_top.png^[colorize:#FFDF20:100",
        "default_chest_side.png^[colorize:#FFDF20:100",
        "default_chest_side.png^[colorize:#FFDF20:100",
        "default_chest_side.png^[colorize:#FFDF20:100",
        "default_chest_front.png^[colorize:#FFDF20:100"
	},
	paramtype = "light",
    paramtype2 = "facedir",
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	groups = {unbreakable=1},
    on_construct = function(pos) construct_node(pos, "Mese Chest") end,
    on_rightclick = function(pos, node, clicker) mese_chest_on_rightclick(pos, node, clicker) end,
    on_timer = function(pos, elapsed)
        update_node(pos, MESE_CHEST, mese_loot)
        return true
    end,
    on_blast = function() end,
})

core.register_node("ffa_loot:mese_chest_open", {
	description = "Mese Chest Opened",
	tiles = {
        "(default_chest_top.png^default_mese_crystal.png)^[colorize:#FFDF20:100",
        "default_chest_top.png^[colorize:#FFDF20:100",
        "default_chest_side.png^[colorize:#FFDF20:100",
        "default_chest_side.png^[colorize:#FFDF20:100",
        "default_chest_front.png^[colorize:#FFDF20:100",
        "default_chest_inside.png"
	},
    selection_box = {
		type = "fixed",
		fixed = { -1/2, -1/2, -1/2, 1/2, 3/16, 1/2 },
	},
    drawtype = "mesh",
    mesh = "chest_open.obj",
	paramtype = "light",
    paramtype2 = "facedir",
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	groups = {unbreakable=1, not_in_creative_inventory=1},
    on_construct = function(pos) construct_node(pos, "Mese Chest") end,
    on_rightclick = function(pos, node, clicker) mese_chest_on_rightclick(pos, node, clicker) end,
    on_timer = function(pos, elapsed)
        update_node(pos, MESE_CHEST, mese_loot)
        return true
    end,
    on_blast = function() end,
    drop = "ffa_loot:mese_chest"
})

--
--- DIAMOND CHEST
--

local diamond_chest_opened = {}

core.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if diamond_chest_opened[name] ~= nil then
        diamond_chest_opened[name] = nil
    end
end)

local function chest_opened(pos)
    local meta = core.get_meta(pos)
    return meta:get_int("timer") ~= 0
end

local function has_key(clicker, pos)
    local stack = ItemStack("ffa_loot:diamond_key")
    local name = clicker:get_player_name()
    local wielded_item = clicker:get_wielded_item()
    if wielded_item == stack then
        return true
    end

    if not chest_opened(pos) then
        core.chat_send_player(name,
        ("You need a %s to open this chest."):format(core.colorize("#12e8ec", stack:get_description())))
    end

    return false
end

local function remove_key(clicker)
    clicker:set_wielded_item("")
end

local function update_diamond_chest(pos, closing_time)
    local meta = core.get_meta(pos)
    local timer = meta:get_int("timer")
    local infotext = meta:get_string("infotext")

    meta:set_int("timer", timer - 1)
    meta:set_string("infotext", ("%s, Closing in %ds"):format(infotext:split(",")[1], timer - 1))

    if (timer -1) == 0 then
        meta:set_string("infotext", ("%s"):format(infotext:split(",")[1]))
        core.swap_node(pos, {name = "ffa_loot:diamond_chest", param2 = core.get_node(pos).param2 })

        for name, opened_pos in pairs(diamond_chest_opened) do
            if vector.equals(opened_pos, pos) then
                core.close_formspec(name, "ffa_loot:diamond_chest")
                diamond_chest_opened[name] = nil
            end
        end
    end
end

core.register_node("ffa_loot:diamond_chest", {
	description = "Diamond Chest",
	tiles = {
        "(default_chest_top.png^default_diamond.png)^[colorize:#12e8ec:100",
        "default_chest_top.png^[colorize:#12e8ec:100",
        "default_chest_side.png^[colorize:#12e8ec:100",
        "default_chest_side.png^[colorize:#12e8ec:100",
        "default_chest_side.png^[colorize:#12e8ec:100",
        "default_chest_front.png^[colorize:#12e8ec:100"
	},
	paramtype = "light",
    paramtype2 = "facedir",
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	groups = {unbreakable=1},
    on_construct = function(pos) construct_node(pos, "Diamond Chest") end,
    on_rightclick = function(pos, node, clicker)
        local cn = clicker:get_player_name()
        local meta = core.get_meta(pos)
        local is_opened = chest_opened(pos)

        if not has_key(clicker, pos) and not is_opened then
            return
        end

        if not is_opened then
            core.after(0, remove_key, clicker)
            fill_chest_random(pos, diamond_loot)
            meta:set_int("timer", DIAMOND_CHEST)

            core.chat_send_all(("%s has opened a %s"):format(cn, core.colorize("#12e8ec", "Diamond Chest")))
        end

        --local p = vector.new(pos.x, pos.y+1, pos.z)
        --core.chat_send_player(cn, "<" .. core.colorize("#31C950", "Forgotten Player") .. "> I seee you")
        --skywars.spawn_fp(p)

        core.sound_play("ffa_loot_unlock", {gain = 0.3, pos = pos, max_hear_distance = 10}, true)
        core.swap_node(pos, {name = "ffa_loot:diamond_chest_open", param2 = node.param2 })
        core.after(0.2, core.show_formspec, cn, "ffa_loot:diamond_chest", default.chest.get_chest_formspec(pos))

        diamond_chest_opened[cn] = pos
    end,
    on_timer = function(pos, elapsed)
        local is_opened = chest_opened(pos)
        if is_opened then
            update_diamond_chest(pos, DIAMOND_CHEST)
        end

        return true
    end,
    on_blast = function() end,
})

core.register_node("ffa_loot:diamond_chest_open", {
	description = "Diamond Chest Opened",
	tiles = {
        {name = "(default_chest_top.png^default_diamond.png)^[colorize:#12e8ec:100", backface_culling = true},
        {name = "default_chest_top.png^[colorize:#12e8ec:100", backface_culling = true},
        {name = "default_chest_side.png^[colorize:#12e8ec:100", backface_culling = true},
        {name = "default_chest_side.png^[colorize:#12e8ec:100", backface_culling = true},
        {name = "default_chest_front.png^[colorize:#12e8ec:100", backface_culling = true},
        {name = "default_chest_inside.png", backface_culling = true},
	},
    selection_box = {
		type = "fixed",
		fixed = { -1/2, -1/2, -1/2, 1/2, 3/16, 1/2 },
	},
    drawtype = "mesh",
    mesh = "chest_open.obj",
	paramtype = "light",
    paramtype2 = "facedir",
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	groups = {unbreakable=1, not_in_creative_inventory=1},
    on_construct = function(pos) construct_node(pos, "Diamond Chest") end,
    on_rightclick = function(pos, node, clicker)
        local cn = clicker:get_player_name()
        core.show_formspec(cn, "ffa_loot:diamond_chest", default.chest.get_chest_formspec(pos))

        diamond_chest_opened[cn] = pos
    end,
    on_timer = function(pos, elapsed)
        local is_opened = chest_opened(pos)
        if is_opened then
            update_diamond_chest(pos, DIAMOND_CHEST)
        end

        return true
    end,
    on_blast = function() end,
    drop = "ffa_loot:diamond_chest"
})

core.register_craftitem("ffa_loot:diamond_key", {
    description = core.colorize("#12e8ec", "Diamond Key"),
    inventory_image = "ffa_loot_diamond_key.png",
    stack_max = 1
})

core.register_lbm({
    label = "Close opened chests on load",
    name = "ffa_loot:close_chest_open",
    nodenames = {
        "ffa_loot:regular_chest_open",
        "ffa_loot:mese_chest_open"
    },
    run_at_every_load = true,
    action = function(pos, node)
        node.name = (node.name):sub(1, (node.name):len() - 5)
        core.swap_node(pos, node)
    end
})
