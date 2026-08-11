
local S = minetest.get_translator(minetest.get_current_modname())

if armor.materials.bronze then

	armor:register_armor(":3d_armor:helmet_bronze", {
		description = S("Bronze Helmet"),
		inventory_image = "3d_armor_inv_helmet_bronze.png",
		groups = {armor_head=1, armor_heal=3, armor_use=1100},
		armor_groups = {fleshy=10.5},
		damage_groups = {cracky=3, snappy=2, choppy=2, crumbly=1, level=2},
	})

	armor:register_armor(":3d_armor:chestplate_bronze", {
		description = S("Bronze Chestplate"),
		inventory_image = "3d_armor_inv_chestplate_bronze.png",
		groups = {armor_torso=1, armor_heal=3, armor_use=1100},
		armor_groups = {fleshy=12},
		damage_groups = {cracky=3, snappy=2, choppy=2, crumbly=1, level=2},
	})

	armor:register_armor(":3d_armor:leggings_bronze", {
		description = S("Bronze Leggings"),
		inventory_image = "3d_armor_inv_leggings_bronze.png",
		groups = {armor_legs=1, armor_heal=3, armor_use=1100},
		armor_groups = {fleshy=12},
		damage_groups = {cracky=3, snappy=2, choppy=2, crumbly=1, level=2},
	})

	armor:register_armor(":3d_armor:boots_bronze", {
		description = S("Bronze Boots"),
		inventory_image = "3d_armor_inv_boots_bronze.png",
		groups = {armor_feet=1, armor_heal=3, armor_use=1100},
		armor_groups = {fleshy=10.5},
		damage_groups = {cracky=3, snappy=2, choppy=2, crumbly=1, level=2},
	})
end
