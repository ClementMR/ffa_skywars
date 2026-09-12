local function is_legacy_crossbow_item(name)
	return name:find("^shooter_crossbow:") ~= nil
		or name == "shooter:crossbow"
		or name:find("^shooter:crossbow_loaded_") ~= nil
		or name:find("^shooter:arrow_") ~= nil
end

local function clean_inventory(inventory)
	if not inventory then
		return 0
	end

	local removed = 0
	for listname, list in pairs(inventory:get_lists()) do
		for index, stack in ipairs(list) do
			if is_legacy_crossbow_item(stack:get_name()) then
				removed = removed + stack:get_count()
				inventory:set_stack(listname, index, ItemStack())
			end
		end
	end
	return removed
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	core.after(0, function()
		local current = core.get_player_by_name(name)
		if not current then
			return
		end

		local removed = clean_inventory(current:get_inventory())
		if removed > 0 then
			core.log("action", "[skywars] Removed " .. removed
				.. " legacy crossbow item(s) from " .. name)
		end
	end)
end)
