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

core.register_chatcommand("info", {
	description = S("Print informations of the specified player"),
	params = "<playerName>",
	privs = {ffa_manager=true},
	func = function(name, param)
		local player = core.get_player_by_name(param)
		if player then
			local player_info = core.get_player_information(param)
			local output = {}
			for key, value in pairs(player_info) do
				table.insert(output, key .. " = " .. value)
			end

			return true, S("@1's informations @n", core.colorize("cyan", param)) .. table.concat(output, "\n")
		end

		return false, S("The player @1 does not exist or is not online.", param)
	end
})

core.register_chatcommand("hp", {
	description = "",
	params = "get <playerName> | set <playerName> <value>",
	privs = {ffa_manager=true},
	func = function(name, param)
		local args = param:split(" ")

		if args[1] == "get" and args[2] ~= nil then
			local player = core.get_player_by_name(args[2])
			if player then
				return true, string.format("Health points of %s : %d", args[2], player:get_hp())
			else
				return false, "This player is not online."
			end

		elseif args[1] == "set" and args[2] ~= nil and args[3] ~= nil then
			local player = core.get_player_by_name(args[2])
			if player then
				local value = tonumber(args[3])
				if value then
					player:set_hp(value)
					return true, string.format("Health points of %s set to ", args[2], value)
				else
					return false, "Invalid value."
				end
			else
				return false, "This player is not online."
			end
		end

		return false, string.format("Invalid parameters, see %s", core.colorize("cyan", "/help hp"))
	end
})

for _, kick_cmd in pairs({"kickme", "disconnect"}) do
	core.register_chatcommand(kick_cmd, {
		privs = {interact=true},
		func = function(name)
			core.disconnect_player(name, "[Self-Kick] You have been kicked from the server.")
		end
	})
end

core.register_chatcommand("notice", {
	params = "<playerName> <message>",
	description = "Send a direct message to a player",
	privs = {ffa_manager=true},
	func = function(name, param)
		local sendto, message = param:match("^(%S+)%s(.+)$")
		if not sendto then
			return false, S("Invalid usage, see /help notice.")
		end

		if not core.get_player_by_name(sendto) then
			return false, ("The player %s is not online."):format(sendto)
		end

		core.chat_send_player(sendto, core.colorize("#FF8904", "[ PRIVATE NOTICE ] ") .. message)

		core.log("action", "[ PRIVATE NOTICE ] to " .. sendto .. " : " .. message)

		return true, ("Message sent to %s."):format(sendto)
	end,
})

core.register_chatcommand("notice_all", {
	params = "<message>",
	description = "Send a message to all players",
	privs = {ffa_manager=true},
	func = function(name, param)
		if not param or param == "" then
			return false, "Invalid usage, see /help notice_all"
		end

		core.chat_send_all(core.colorize("#FF8904", "[ NOTICE ] ") .. param)

		core.log("action", ("[ PUBLIC NOTICE ] " .. param))
	end,
})

core.register_chatcommand("restart", {
	params = "[<message>]",
	description = "Restart the server",
	privs = {ffa_manager=true},
	func = function(name, param)
		local delay = 15
		core.chat_send_all(core.colorize("#FF8904", "[ NOTICE ] ") .. 
			("Server restarts in %d seconds. %s"):format(delay, param or ""))

		core.request_shutdown("Restart in 5 seconds...", true,  delay)
		return true
	end,
})

core.override_chatcommand("privs", {
	privs = {ffa_manager=true},
})