for k, v in pairs(armor.materials) do
	core.register_alias("helmet_"..k, "3d_armor:helmet_"..k)
	core.register_alias("chestplate_"..k, "3d_armor:chestplate_"..k)
	core.register_alias("leggings_"..k, "3d_armor:leggings_"..k)
	core.register_alias("boots_"..k, "3d_armor:boots_"..k)
	core.register_alias("shield_"..k, "shields:shield_"..k)
end

core.register_alias("helmet_admin", "3d_armor:helmet_admin")
core.register_alias("chestplate_admin", "3d_armor:chestplate_admin")
core.register_alias("leggings_admin", "3d_armor:leggings_admin")
core.register_alias("boots_admin", "3d_armor:boots_admin")
core.register_alias("shield_admin", "shields:shield_admin")