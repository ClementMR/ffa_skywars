-- Run as a worldmod's init.lua, depending on ffa_inventory, in a disposable world.
core.after(0, function()
	local name = "armor_formspec_test"
	local inventory_name = name .. "_armor"
	assert(not core.get_inventory({type = "detached", name = inventory_name}))
	local player = {
		get_player_name = function() return name end,
		set_inventory_formspec = function(self, formspec) self.formspec = formspec end,
	}
	local page = sfinv.pages["sfinv:crafting"]
	local context = {nav_titles = {}, nav_idx = 1}
	local original_validator = armor.get_valid_player
	local original_skin = armor.get_player_skin
	armor.get_player_skin = function() return "character.png" end
	armor.get_valid_player = function()
		error("Rendering must not call the warning-producing player validator")
	end

	assert(armor:get_armor_formspec(name) == "", "Armor must wait for its inventory")
	local initial = page:get(player, context)
	assert(initial:find("list[current_player;craft;", 1, true))
	assert(initial:find("list[current_player;totem;", 1, true))
	assert(not initial:find("list[detached:", 1, true), "Do not reference a missing inventory")

	local inv = core.create_detached_inventory(inventory_name, {})
	inv:set_size("armor", #armor.elements)
	local ready = page:get(player, context)
	assert(ready:find("list[detached:" .. inventory_name .. ";armor;", 1, true))
	assert(ready:find("listring[detached:" .. inventory_name .. ";armor]", 1, true))
	assert(ready:find("3d_armor_stand_head.png", 1, true), "Empty slots must show their background")

	inv:set_stack("armor", 1, "3d_armor:helmet_steel")
	local equipped = page:get(player, context)
	assert(not equipped:find("3d_armor_stand_head.png", 1, true))
	assert(equipped:find("3d_armor_stand_torso.png", 1, true))

	-- Refresh through sfinv, as the armor on_update callback does.
	player.formspec = initial
	sfinv.set_page(player, "sfinv:crafting")
	assert(player.formspec:find("list[detached:" .. inventory_name .. ";armor;", 1, true))

	core.remove_detached_inventory(inventory_name)
	assert(armor:get_armor_formspec(name) == "")
	armor.get_valid_player = original_validator
	armor.get_player_skin = original_skin
	sfinv.contexts[name] = nil
	core.log("action", "[armor_formspec] All regression checks passed")
	core.request_shutdown("Regression checks passed", false, 0)
end)
