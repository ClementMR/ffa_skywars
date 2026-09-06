local S = core.get_translator(core.get_current_modname())
local name_color = "#5B21B6"

local pieces = {
	{
		name = "helmet",
		description = S("Shadow Helmet"),
		slot = "head",
		protection = 18,
	},
	{
		name = "chestplate",
		description = S("Shadow Chestplate"),
		slot = "torso",
		protection = 22,
	},
	{
		name = "leggings",
		description = S("Shadow Leggings"),
		slot = "legs",
		protection = 22,
	},
	{
		name = "boots",
		description = S("Shadow Boots"),
		slot = "feet",
		protection = 18,
	},
}

for _, piece in ipairs(pieces) do
	armor:register_armor(":3d_armor:" .. piece.name .. "_shadow", {
		description = core.colorize(name_color, piece.description),
		inventory_image = "3d_armor_inv_" .. piece.name .. "_shadow.png",
		groups = {
			["armor_" .. piece.slot] = 1,
			armor_heal = 12,
			armor_use = 350,
			not_in_creative_inventory = 1,
		},
		armor_groups = {fleshy = piece.protection},
		damage_groups = {cracky = 1, snappy = 1, choppy = 1, level = 3},
	})
end
