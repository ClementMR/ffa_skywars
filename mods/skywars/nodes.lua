local S = core.get_translator(core.get_current_modname())

local special_items = {}

skywars.whitelist = {
    "skywars:leaves",
    "skywars:acacia_leaves",
    "tnt:tnt",
    "fire:basic_flame",
    "xdecor:baricade",
    "xdecor:cobweb",
	"default:apple",
	"maptools:superapple",
	"skywars:wool_blue"
}

local protected_mods = {
	"bakedclay",
    "default",
    "doors",
	"farming",
	"flowers",
	"stainedglass",
    "stairs",
    "vessels",
	"walls",
	"wool",
    "xpanes",
	"xdecor"
}

local groups_to_keep = {
	"fence",
	"not_in_creative_inventory",
	"pane",
	"slab",
	"stair",
	"wall",
	"slippery",
	"fall_damage_add_percent",
	"bouncy",
	"water",
	"lava",
	"cools_lava"
}

local function item_exists(item_name)
    return core.registered_items[item_name] ~= nil
end

local function apply_special_items()
    for item_name, settings in pairs(special_items) do

        if item_exists(item_name) then
            core.override_item(item_name, settings)
        end

    end
end

local function add_groups(current_groups)
    local groups = {unbreakable=1}

    for _, group in pairs(groups_to_keep) do
		if current_groups[group] ~= nil and current_groups[group] ~= 0 then
			groups[group] = current_groups[group]
		end
    end

    return groups
end

local function is_whitelisted(node_name)
	for _, whitelisted_node in pairs(skywars.whitelist) do
		if node_name == whitelisted_node then
			return true
		end
	end

	return false
end

core.register_node("skywars:leaves", {
	description = core.registered_nodes["default:leaves"].description,
	drawtype = "allfaces_optional",
	tiles = {"default_leaves.png"},
	paramtype = "light",
	is_ground_content = false,
	groups = {snappy = 3, leafdecay = 3, flammable = 2, leaves = 1},
	sounds = default.node_sound_leaves_defaults(),
})

core.register_node("skywars:acacia_leaves", {
	description = core.registered_nodes["default:acacia_leaves"].description,
	drawtype = "allfaces_optional",
	tiles = {"default_acacia_leaves.png"},
	paramtype = "light",
	is_ground_content = false,
	groups = {snappy = 3, leafdecay = 3, flammable = 2, leaves = 1},
	sounds = default.node_sound_leaves_defaults(),
})

minetest.register_node("skywars:wool_blue", {
	description = core.registered_nodes["wool:blue"].description,
	tiles = {"wool_blue.png"},
	is_ground_content = false,
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 3, flammable = 3, wool = 1},
	sounds = default.node_sound_defaults(),
})


core.register_node("skywars:fake_stone", {
	description = "Fake Stone",
	tiles = {"default_stone.png"},
	light_source = 5,
	is_ground_content = false,
	groups = {unbreakable = 1},
	walkable = false,
	sounds = default.node_sound_stone_defaults(),
	on_blast = function() end,
	drop = "",
})

for _, node_prefix in pairs(protected_mods) do
	for node_name, def in pairs(core.registered_nodes) do
		if node_name:find(node_prefix) and not is_whitelisted(node_name) then
			core.override_item(node_name, {
				description =  def.description .. " " .. core.colorize("red", S("(Unbreakable)")),
				groups = add_groups(def.groups),
				drop = "",
				buildable_to = false,
				on_blast = function() return end
			})
		end
	end
end

apply_special_items()