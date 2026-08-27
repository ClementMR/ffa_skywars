-- In-memory profile cache and durable ModStorage persistence.
return function(stats)
	local storage = stats.storage
	local profiles = {}
	local dirty_profiles = {}
	local sessions = {}
	local save_timer = 0

	stats.storage_prefix = "player:"
	stats.save_interval = math.max(30, math.floor(tonumber(core.settings:get("player_stats_save_interval")) or 60))
	stats.kill_credit_window = math.max(1, math.floor(tonumber(core.settings:get("player_stats_kill_credit_window")) or 8))
	stats.max_value = 2147483647
	stats.leaderboard_size = 20
	stats.profiles = profiles
	stats.dirty_profiles = dirty_profiles
	stats.sessions = sessions
	stats.stat_fields = {
		playtime = "Playtime",
		kills = "Kills",
		deaths = "Deaths",
	}
	stats.leaderboard_fields = {
		playtime = "Playtime",
		kills = "Kills",
		deaths = "Deaths",
		kd = "K/D",
	}
	stats.stat_aliases = {
		time = "playtime",
		playtime = "playtime",
		kill = "kills",
		kills = "kills",
		death = "deaths",
		deaths = "deaths",
		kd = "kd",
		kdr = "kd",
		kdratio = "kd",
	}

	function stats.integer(value)
		value = tonumber(value)
		if not value or value ~= value or value == math.huge or value == -math.huge then
			return 0
		end
		return math.max(0, math.min(stats.max_value, math.floor(value)))
	end

	function stats.valid_player_name(name)
		return type(name) == "string" and #name > 0 and #name <= 64
			and name:match("^[%w_%-]+$") ~= nil
	end

	function stats.resolve_field(value)
		return type(value) == "string" and stats.stat_aliases[value:lower()] or nil
	end

	local function normalize_profile(profile)
		profile = type(profile) == "table" and profile or {}
		return {
			version = 1,
			playtime = stats.integer(profile.playtime),
			kills = stats.integer(profile.kills),
			deaths = stats.integer(profile.deaths),
		}
	end

	function stats.get_profile(name, create)
		if not stats.valid_player_name(name) then
			return nil
		end

		local profile = profiles[name]
		if not profile and create then
			profile = normalize_profile()
			profiles[name] = profile
			dirty_profiles[name] = true
		end
		return profile
	end

	function stats.save_profile(name)
		local profile = profiles[name]
		if not profile then
			return
		end
		storage:set_string(stats.storage_prefix .. name, core.serialize(profile))
		dirty_profiles[name] = nil
	end

	function stats.commit_session(name, now)
		local session = sessions[name]
		local profile = profiles[name]
		if not session or not profile then
			return
		end

		now = now or core.get_gametime()
		local elapsed = math.max(0, math.floor(now - session.started_at))
		if elapsed > 0 then
			profile.playtime = math.min(stats.max_value, profile.playtime + elapsed)
			session.started_at = session.started_at + elapsed
			dirty_profiles[name] = true
		end
	end

	function stats.commit_all_sessions()
		local now = core.get_gametime()
		for name in pairs(sessions) do
			stats.commit_session(name, now)
		end
	end

	function stats.save_dirty_profiles()
		local names = {}
		for name in pairs(dirty_profiles) do
			table.insert(names, name)
		end
		for _, name in ipairs(names) do
			stats.save_profile(name)
		end
	end

	function stats.start_session(name)
		stats.get_profile(name, true)
		sessions[name] = {started_at = core.get_gametime()}
	end

	function stats.finish_session(name)
		stats.commit_session(name)
		stats.save_profile(name)
		sessions[name] = nil
	end

	function stats.reset_session_clock(name)
		if sessions[name] then
			sessions[name].started_at = core.get_gametime()
		end
	end

	function stats.get_kd(name)
		return stats.get_value(name, "kills") / math.max(stats.get_value(name, "deaths"), 1)
	end

	function stats.get_value(name, field)
		local profile = profiles[name]
		if not profile then
			return 0
		end

		if field == "kd" then
			return stats.get_kd(name)
		end
		if field == "playtime" and sessions[name] then
			local elapsed = math.max(0, math.floor(core.get_gametime() - sessions[name].started_at))
			return math.min(stats.max_value, profile.playtime + elapsed)
		end
		return profile[field] or 0
	end

	function stats.set_value(name, field, value)
		local profile = stats.get_profile(name, true)
		if not profile or not stats.stat_fields[field] then
			return false
		end
		profile[field] = stats.integer(value)
		dirty_profiles[name] = true
		return true
	end

	function stats.add(name, field, amount)
		local profile = stats.get_profile(name, true)
		if not profile or not stats.stat_fields[field] then
			return false
		end
		profile[field] = math.min(stats.max_value, profile[field] + stats.integer(amount))
		dirty_profiles[name] = true
		return true
	end

	function stats.format_duration(seconds)
		seconds = stats.integer(seconds)
		local days = math.floor(seconds / 86400)
		local hours = math.floor((seconds % 86400) / 3600)
		local minutes = math.floor((seconds % 3600) / 60)
		if days > 0 then
			return string.format("%dd %02dh %02dm", days, hours, minutes)
		end
		return string.format("%dh %02dm", hours, minutes)
	end

	function stats.format_value(field, value)
		if field == "playtime" then
			return stats.format_duration(value)
		end
		if field == "kd" then
			return string.format("%.2f", tonumber(value) or 0)
		end
		return tostring(stats.integer(value))
	end

	function stats.get_leaderboard(field)
		local board = {}
		for name in pairs(profiles) do
			local value = stats.get_value(name, field)
			if value > 0 then
				table.insert(board, {name = name, value = value})
			end
		end

		table.sort(board, function(a, b)
			if a.value == b.value then
				return a.name:lower() < b.name:lower()
			end
			return a.value > b.value
		end)
		return board
	end

	function stats.get_rank(name, field)
		for rank, entry in ipairs(stats.get_leaderboard(field)) do
			if entry.name == name then
				return rank
			end
		end
	end

	function stats.summary(name)
		if not stats.get_profile(name, false) then
			return nil
		end
		return string.format("%s — Playtime : %s | Kills : %d | Deaths : %d", name,
			stats.format_duration(stats.get_value(name, "playtime")),
			stats.get_value(name, "kills"), stats.get_value(name, "deaths"))
	end

	for key, serialized in pairs(storage:to_table().fields) do
		local name = key:match("^" .. stats.storage_prefix .. "(.+)$")
		if name and stats.valid_player_name(name) then
			local profile = core.deserialize(serialized)
			if type(profile) == "table" then
				profiles[name] = normalize_profile(profile)
			end
		end
	end

	stats.api.get = function(name)
		if not stats.get_profile(name, false) then
			return nil
		end
		return {
			playtime = stats.get_value(name, "playtime"),
			kills = stats.get_value(name, "kills"),
			deaths = stats.get_value(name, "deaths"),
			kd = stats.get_kd(name),
		}
	end

	stats.api.add = function(name, field, amount)
		field = stats.resolve_field(field)
		return field and stats.add(name, field, amount) or false
	end

	stats.api.save = function()
		stats.commit_all_sessions()
		stats.save_dirty_profiles()
	end

	core.register_globalstep(function(dtime)
		save_timer = save_timer + dtime
		if save_timer >= stats.save_interval then
			save_timer = 0
			stats.api.save()
		end
	end)

	core.register_on_shutdown(stats.api.save)
end
