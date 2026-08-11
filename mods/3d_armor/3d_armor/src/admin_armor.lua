--- Registered armors.
--
--  @topic armor


local S = core.get_translator(core.get_current_modname())

--- Admin Helmet
--
--  @helmet 3d_armor:helmet_admin
--  @img 3d_armor_inv_helmet_admin.png
--  @grp armor_head 1
--  @grp armor_heal 100
--  @grp armor_use 0
--  @grp armor_water 1
--  @grp not_in_creative_inventory 1
--  @armorgrp fleshy 100
armor:register_armor("3d_armor:helmet_admin", {
	description = S("Admin Helmet"),
	inventory_image = "3d_armor_inv_helmet_admin.png",
	armor_groups = {fleshy=100},
	groups = {armor_head=1, armor_heal=100, armor_use=0, armor_water=1},
	on_drop = function(itemstack, dropper, pos)
		return
	end,
})

--- Admin Chestplate
--
--  @chestplate 3d_armor:chestplate_admin
--  @img 3d_armor_inv_chestplate_admin.png
--  @grp armor_torso 1
--  @grp armor_heal 100
--  @grp armor_use 0
--  @grp armor_water 1
--  @grp not_in_creative_inventory 1
--  @armorgrp fleshy 100
armor:register_armor("3d_armor:chestplate_admin", {
	description = S("Admin Chestplate"),
	inventory_image = "3d_armor_inv_chestplate_admin.png",
	armor_groups = {fleshy=100},
	groups = {armor_torso=1, armor_heal=100, armor_use=0, armor_water=1},
	on_drop = function(itemstack, dropper, pos)
		return
	end,
})

--- Admin Leggings
--
--  @leggings 3d_armor:leggings_admin
--  @img 3d_armor_inv_leggings_admin.png
--  @grp armor_legs 1
--  @grp armor_heal 100
--  @grp armor_use 0
--  @grp armor_water 1
--  @grp not_in_creative_inventory 1
--  @armorgrp fleshy 100
armor:register_armor("3d_armor:leggings_admin", {
	description = S("Admin Leggings"),
	inventory_image = "3d_armor_inv_leggings_admin.png",
	armor_groups = {fleshy=100},
	groups = {armor_legs=1, armor_heal=100, armor_use=0, armor_water=1},
	on_drop = function(itemstack, dropper, pos)
		return
	end,
})

--- Admin Boots
--
--  @boots 3d_armor:boots_admin
--  @img 3d_armor_inv_boots_admin.png
--  @grp armor_feet 1
--  @grp armor_heal 100
--  @grp armor_use 0
--  @grp armor_water 1
--  @grp not_in_creative_inventory 1
--  @armorgrp fleshy 100
armor:register_armor("3d_armor:boots_admin", {
	description = S("Admin Boots"),
	inventory_image = "3d_armor_inv_boots_admin.png",
	armor_groups = {fleshy=100},
	groups = {armor_feet=1, armor_heal=100, armor_use=0, physics_speed=1, armor_water=1},
	on_drop = function(itemstack, dropper, pos)
		return
	end,
})

--- Admin Shield
--
--  @shield shields:shield_admin
--  @img shields_inv_shield_admin.png
--  @grp armor_shield 1
--  @grp armor_heal 100
--  @grp armor_use 0
--  @grp armor_water 1
--  @grp not_in_creative_inventory 1
--  @armorgrp fleshy 100
armor:register_armor(":shields:shield_admin", {
	description = S("Admin Shield"),
	inventory_image = "shields_inv_shield_admin.png",
	armor_groups = {fleshy=100},
	groups = {armor_shield=1, armor_heal=100, armor_use=0, armor_water=1},
	on_drop = function(itemstack, dropper, pos) return end
})