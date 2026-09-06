local S = core.get_translator(core.get_current_modname())

armor:register_armor(":3d_armor:helmet_shadow", {
	description = core.colorize("#5B21B6", S("Shadow Helmet")),
	inventory_image = "3d_armor_inv_helmet_shadow.png",
	groups = {armor_head=1, armor_heal=12, armor_use=350},
	armor_groups = {fleshy=15},
	damage_groups = {cracky = 1, snappy = 1, choppy = 1, level = 3},
})

armor:register_armor(":3d_armor:chestplate_shadow", {
	description = core.colorize("#5B21B6", S("Shadow Chestplate")),
	inventory_image = "3d_armor_inv_chestplate_shadow.png",
	groups = {armor_torso=1, armor_heal=12, armor_use=350},
	armor_groups = {fleshy=17},
	damage_groups = {cracky = 1, snappy = 1, choppy = 1, level = 3},
})

armor:register_armor(":3d_armor:leggings_shadow", {
	description = core.colorize("#5B21B6", S("Shadow Leggings")),
	inventory_image = "3d_armor_inv_leggings_shadow.png",
	groups = {armor_legs=1, armor_heal=12, armor_use=350},
	armor_groups = {fleshy=17},
	damage_groups = {cracky = 1, snappy = 1, choppy = 1, level = 3},
})

armor:register_armor(":3d_armor:boots_shadow", {
	description = core.colorize("#5B21B6", S("Shadow Boots")),
	inventory_image = "3d_armor_inv_boots_shadow.png",
	groups = {armor_feet=1, armor_heal=12, armor_use=350},
	armor_groups = {fleshy=15},
	damage_groups = {cracky = 1, snappy = 1, choppy = 1, level = 3},
})
