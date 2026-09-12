local S = core.get_translator(core.get_current_modname())
local C = core.colorize

local last_logins = {}

local function rtt_details(info)
	local rtt = info and tonumber(info.avg_rtt)
	if not rtt or rtt ~= rtt or rtt < 0 or rtt > 60 then
		return nil
	end

	local milliseconds = math.floor(rtt * 1000 + 0.5)
	local color = milliseconds <= 80 and "#22C55E"
		or milliseconds <= 160 and "#F59E0B" or "#EF4444"
	return " - " .. C("#A1A1AA", "RTT: ")
		.. C(color, milliseconds .. " ms")
end

local function last_login(name)
	local timestamp = last_logins[name]
	if not timestamp then
		return nil
	end

	local diff = os.time() - timestamp

	local time
	if diff < 60 then
		time = diff .. "s ago"
	elseif diff < 3600 then
		time = math.floor(diff / 60) .. "m ago"
	elseif diff < 86400 then
		time = math.floor(diff / 3600) .. "h ago"
	else
		time = math.floor(diff / 86400) .. "d ago"
	end

	return " - " .. C("#A1A1AA", "Last seen: ")
		.. C("#38BDF8", time)
end

core.register_on_joinplayer(function(player, last_login)
	last_logins[player:get_player_name()] = last_login
end)

core.register_on_leaveplayer(function(player, last_login)
	last_logins[player:get_player_name()] = last_login
end)

local function is_admin(name)
	return core.get_player_privs(name).creative or
		core.get_player_privs(name).protection_bypass
end

local function is_manager(name)
	return core.get_player_privs(name).ffa_manager
end

local admin_color = "#D10000"
local manager_color = "#D100D1"
local player_color = "#00D100"

core.send_join_message = function(name)
	core.after(0.1, function()
		if not core.get_player_by_name(name) then
			return
		end

		local details = ""

		local rtt = rtt_details(core.get_player_information(name))
		if rtt then
			details = rtt
		end

		local seen = last_login(name)
		if seen then
			details = details .. seen
		end

		local color = player_color
		if is_admin(name) then
			color = admin_color
		elseif is_manager(name) then
			color = manager_color
		end

		local text = S("@1 joined the game.", C(color, name))
		core.chat_send_all("*** " .. text .. details)
	end)
end

core.register_on_chat_message(function(name, message)
	if is_admin(name) then
		core.chat_send_all(C(admin_color, "[Admin] ") .. core.format_chat_message(name, message))
		return true
	elseif is_manager(name) then
		core.chat_send_all(C(manager_color, "[Manager] ") .. core.format_chat_message(name, message))
		return true
	end

	core.chat_send_all(C(player_color, "[Player] ") .. core.format_chat_message(name, message))
	return true
end)