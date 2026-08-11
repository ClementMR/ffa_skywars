
local S = minetest.get_translator(minetest.get_current_modname())

if armor.materials.steel then

	armor:register_armor(":3d_armor:helmet_steel", {
		description = S("Steel Helmet"),
		inventory_image = "3d_armor_inv_helmet_steel.png",
		groups = {armor_head=1, armor_heal=1, armor_use=950},
		armor_groups = {fleshy=10},
		damage_groups = {cracky=2, snappy=3, choppy=2, crumbly=1, level=2},
	})

	armor:register_armor(":3d_armor:chestplate_steel", {
		description = S("Steel Chestplate"),
		inventory_image = "3d_armor_inv_chestplate_steel.png",
		groups = {armor_torso=1, armor_heal=0, armor_use=950,
			physics_speed=-0.04, physics_gravity=0.04},
		armor_groups = {fleshy=11},
		damage_groups = {cracky=2, snappy=3, choppy=2, crumbly=1, level=2},
	})

	armor:register_armor(":3d_armor:leggings_steel", {
		description = S("Steel Leggings"),
		inventory_image = "3d_armor_inv_leggings_steel.png",
		groups = {armor_legs=1, armor_heal=1, armor_use=950},
		armor_groups = {fleshy=11},
		damage_groups = {cracky=2, snappy=3, choppy=2, crumbly=1, level=2},
	})

	armor:register_armor(":3d_armor:boots_steel", {
		description = S("Steel Boots"),
		inventory_image = "3d_armor_inv_boots_steel.png",
		groups = {armor_feet=1, armor_heal=1, armor_use=950},
		armor_groups = {fleshy=10},
		damage_groups = {cracky=2, snappy=3, choppy=2, crumbly=1, level=2},
	})
end
