local S = core.get_translator(core.get_current_modname())

core.register_chatcommand("killme", {
	description = S("Kill yourself to respawn"),
	func = function(name)
		local player = core.get_player_by_name(name)
		if player then
			if core.settings:get_bool("enable_damage") then
				player:set_hp(0)
				return true
			else
				for _, callback in pairs(core.registered_on_respawnplayers) do
					if callback(player) then
						return true
					end
				end

				-- There doesn't seem to be a way to get a default spawn pos
				-- from the lua API
				return false, "No static_spawnpoint defined"
			end
		else
			-- Show error message if used when not logged in, eg: from IRC mod
			return false, "You need to be online to be killed!"
		end
	end
})

core.register_chatcommand("playerinfo", {
	description = S("Print informations of the specified player"),
	params = "<name>",
	privs = {ffa_manager=true},
	func = function(name, param)
		local player = core.get_player_by_name(param)
		if player then
			local player_info = core.get_player_information(param)
			local output = {}
			for key, value in pairs(player_info) do
				table.insert(output, key .. " = " .. value)
			end

			return true, S("@1's informations@n", core.colorize("cyan", param)) .. table.concat(output, "\n")
		end

		return false, S("The player @1 does not exist or is not online.", param)
	end
})

core.override_chatcommand("privs", {
	privs = {ffa_manager=true},
})