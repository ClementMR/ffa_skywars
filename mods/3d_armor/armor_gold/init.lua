
local S = minetest.get_translator(minetest.get_current_modname())

if armor.materials.gold then
	armor:register_armor(":3d_armor:helmet_gold", {
		description = S("Gold Helmet"),
		inventory_image = "3d_armor_inv_helmet_gold.png",
		groups = {armor_head=1, armor_heal=6, armor_use=1500},
		armor_groups = {fleshy=11},
		damage_groups = {cracky=1, snappy=2, choppy=2, crumbly=3, level=2},
	})

	armor:register_armor(":3d_armor:chestplate_gold", {
		description = S("Gold Chestplate"),
		inventory_image = "3d_armor_inv_chestplate_gold.png",
		groups = {armor_torso=1, armor_heal=6, armor_use=1500},
		armor_groups = {fleshy=12.5},
		damage_groups = {cracky=1, snappy=2, choppy=2, crumbly=3, level=2},
	})

	armor:register_armor(":3d_armor:leggings_gold", {
		description = S("Gold Leggings"),
		inventory_image = "3d_armor_inv_leggings_gold.png",
		groups = {armor_legs=1, armor_heal=6, armor_use=1500},
		armor_groups = {fleshy=12.5},
		damage_groups = {cracky=1, snappy=2, choppy=2, crumbly=3, level=2},
	})

	armor:register_armor(":3d_armor:boots_gold", {
		description = S("Gold Boots"),
		inventory_image = "3d_armor_inv_boots_gold.png",
		groups = {armor_feet=1, armor_heal=6, armor_use=1500},
		armor_groups = {fleshy=11},
		damage_groups = {cracky=1, snappy=2, choppy=2, crumbly=3, level=2},
	})

end
