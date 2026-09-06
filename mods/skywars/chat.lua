local S = core.get_translator(core.get_current_modname())
local pending_joins = {}

local function format_uptime(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local days = math.floor(seconds / 86400)
	local hours = math.floor(seconds % 86400 / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	if days > 0 then
		return S("@1d @2h", days, hours)
	end
	if hours > 0 then
		return S("@1h @2m", hours, minutes)
	end
	return S("@1m", minutes)
end

core.get_server_status = function(name, joined)
	local player_count = #core.get_connected_players()
	local max_players = math.max(0, tonumber(core.settings:get("max_users")) or 0)
	local count = max_players > 0 and (player_count .. " / " .. max_players)
		or tostring(player_count)
	local lines = {}

	if joined and name and name ~= "" then
		lines[#lines + 1] = core.colorize("#A78BFA", S("Welcome, @1!", name))
	end
	lines[#lines + 1] = core.colorize("#6D28D9", "✦ " .. S("FFA Skywars"))
	lines[#lines + 1] = core.colorize("#A1A1AA", S("Players:") .. " ")
		.. core.colorize("#22C55E", count)
		.. core.colorize("#52525B", "  •  ")
		.. core.colorize("#A1A1AA", S("Uptime:") .. " ")
		.. core.colorize("#38BDF8", format_uptime(core.get_server_uptime()))
	return table.concat(lines, "\n")
end

local function valid_language(code)
	return type(code) == "string" and #code <= 16
		and code:match("^[%a][%w_-]*$") ~= nil
end

local function rtt_details(info)
	local rtt = info and tonumber(info.avg_rtt)
	if not rtt or rtt ~= rtt or rtt < 0 or rtt > 60 then
		return nil
	end

	local milliseconds = math.floor(rtt * 1000 + 0.5)
	local color = milliseconds <= 80 and "#22C55E"
		or milliseconds <= 160 and "#F59E0B" or "#EF4444"
	return core.colorize("#A1A1AA", S("RTT:") .. " ")
		.. core.colorize(color, milliseconds .. " ms")
end

core.send_join_message = function(name)
	local token = {}
	pending_joins[name] = token
	core.after(1, function()
		if pending_joins[name] ~= token or not core.get_player_by_name(name) then
			return
		end
		pending_joins[name] = nil

		local info = core.get_player_information(name) or {}
		local details = {}
		local rtt = rtt_details(info)
		if rtt then
			details[#details + 1] = rtt
		end
		if valid_language(info.lang_code) then
			details[#details + 1] = core.colorize("#A1A1AA", S("Language:") .. " ")
				.. core.colorize("#38BDF8", info.lang_code:upper())
		end

		local message = core.colorize("#22C55E", "◆ ")
			.. S("@1 joined the game.", core.colorize("#F4F4F5", name))
		if #details > 0 then
			message = message .. core.colorize("#52525B", "  •  ")
				.. table.concat(details, core.colorize("#52525B", "  •  "))
		end
		core.chat_send_all(message)
	end)
end

core.send_leave_message = function(name, timed_out)
	pending_joins[name] = nil
	local timers = rawget(_G, "ffa_timers")
	local in_combat = timers and timers.is_in_combat
		and timers.is_in_combat(name) or false
	local text = in_combat and S("@1 left the game during combat!",
		core.colorize("#F4F4F5", name))
		or S("@1 left the game.", core.colorize("#F4F4F5", name))
	local color = in_combat and "#EF4444" or "#F59E0B"
	if timed_out then
		text = text .. " " .. core.colorize("#A1A1AA", S("(timed out)"))
	end
	core.chat_send_all(core.colorize(color, in_combat and "✕ " or "◇ ") .. text)
end
