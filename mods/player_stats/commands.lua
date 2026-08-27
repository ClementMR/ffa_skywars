-- Player and administrator commands.
return function(stats)

	core.register_chatcommand("stats", {
		description = "Show your statistics or another player's statistics",
		params = "<playerName>",
		privs = {interact = true},
		func = function(name, param)
			local target_name = param:match("^%s*(.-)%s*$")
			if target_name == "" then
				target_name = name
			end
			if not stats.get_profile(target_name, false) then
				return false, "No statistics are known for " .. target_name .. "."
			end
			stats.show_form(name, 1, target_name)
			return true
		end,
	})

	core.register_chatcommand("top", {
		description = "Show a statistics leaderboard",
		params = "<playtime|kills|deaths|kd>",
		privs = {interact = true},
		func = function(name, param)
			local field = stats.resolve_field(param)
			if not field then
				return false, "Usage: /top <playtime|kills|deaths|kd>"
			end
			local tabs = {playtime = 2, kills = 3, deaths = 4, kd = 5}
			stats.show_form(name, tabs[field], name)
			return true
		end,
	})

	core.register_chatcommand("statsadmin", {
		description = "Manage player statistics",
		params = "get <playerName> | set <playerName> <playtime|kills|deaths> <value> | add <playerName> <stat> <value> | reset <playerName> [stat|all] | save",
		privs = {ffa_manager = true},
		func = function(_, param)
			local args = {}
			for value in param:gmatch("%S+") do
				table.insert(args, value)
			end
			local action = (args[1] or ""):lower()

			if action == "save" and #args == 1 then
				stats.api.save()
				return true, "Statistics saved."
			end

			local target_name = args[2]
			if not stats.valid_player_name(target_name) then
				return false, "Invalid player name."
			end

			if action == "get" and #args == 2 then
				local summary = stats.summary(target_name)
				return summary ~= nil, summary or "No statistics are known for " .. target_name .. "."
			end

			if action == "set" or action == "add" then
				local field = stats.resolve_field(args[3])
				local value = args[4]
				if not field or not stats.stat_fields[field] or not value or #args ~= 4 or not value:match("^%d+$") then
					return false, "Usage: /statsadmin " .. action .. " <player> <playtime|kills|deaths> <value>"
				end
				value = tonumber(value)
				if not value or value > stats.max_value then
					return false, "Invalid value (0 to " .. stats.max_value .. ")."
				end

				stats.commit_session(target_name)
				if action == "set" then
					stats.set_value(target_name, field, value)
				else
					stats.add(target_name, field, value)
				end
				if field == "playtime" then
					stats.reset_session_clock(target_name)
				end
				stats.save_profile(target_name)
				return true, stats.stat_fields[field] .. " for " .. target_name .. ": "
					.. stats.format_value(field, stats.get_value(target_name, field)) .. "."
			end

			if action == "reset" and (#args == 2 or #args == 3) then
				local field_name = (args[3] or "all"):lower()
				local field = stats.resolve_field(field_name)
				if field_name ~= "all" and (not field or not stats.stat_fields[field]) then
					return false, "Unknown statistic. Use playtime, kills, deaths or all."
				end

				stats.commit_session(target_name)
				if field then
					stats.set_value(target_name, field, 0)
				else
					stats.set_value(target_name, "playtime", 0)
					stats.set_value(target_name, "kills", 0)
					stats.set_value(target_name, "deaths", 0)
				end
				if not field or field == "playtime" then
					stats.reset_session_clock(target_name)
				end
				stats.save_profile(target_name)
				return true, "Statistics reset for " .. target_name .. "."
			end

			return false, "Usage: /help statsadmin"
		end,
	})
end
