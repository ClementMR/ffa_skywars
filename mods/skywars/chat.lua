local S = core.get_translator(core.get_current_modname())
local pending_joins = {}

local function rtt_details(info)
	local rtt = info and tonumber(info.avg_rtt)
	if not rtt or rtt ~= rtt or rtt < 0 or rtt > 60 then
		return nil
	end

	local milliseconds = math.floor(rtt * 1000 + 0.5)
	local color = milliseconds <= 80 and "#22C55E"
		or milliseconds <= 160 and "#F59E0B" or "#EF4444"
	return " " .. core.colorize("#A1A1AA", S("RTT:") .. " ")
		.. core.colorize(color, milliseconds .. " ms")
end

local function is_admin(name)
	return core.get_player_privs(name).creative or
		core.get_player_privs(name).server or
		core.get_player_privs(name).protection_bypass
end

local function is_manager(name)
	return core.get_player_privs(name).ffa_manager
end

local admin_color = core.colorize("#D10000", "[Admin] ")
local manager_color = core.colorize("#D100D1", "[Manager] ")
local player_color = core.colorize("#00D100", "[Player] ")

core.send_join_message = function(name)
	local token = {}
	pending_joins[name] = token
	core.after(0.1, function()
		if pending_joins[name] ~= token or not core.get_player_by_name(name) then
			return
		end
		pending_joins[name] = nil

		local details = ""
		local rtt = rtt_details(core.get_player_information(name))
		if rtt then
			details = rtt
		end

		local text = S("@1 joined the game.", name)
		if #details > 0 then
			text = text .. details
		end

		if is_admin(name) then
			text = admin_color .. text
		elseif is_manager(name) then
			text = manager_color .. text
		end

		core.chat_send_all("*** " .. text)
	end)
end

core.send_leave_message = function(name, timed_out)
	pending_joins[name] = nil
	local text = S("@1 left the game.", name)
	if timed_out then
		text = text .. " " .. S("(timed out)")
	end

	if is_admin(name) then
		text = admin_color .. text
	elseif is_manager(name) then
		text = manager_color .. text
	end

	core.chat_send_all("*** " .. text)
end

core.register_on_chat_message(function(name, message)
	if is_admin(name) then
		core.chat_send_all(admin_color .. core.format_chat_message(name, message))
		return true
	elseif is_manager(name) then
		core.chat_send_all(manager_color .. core.format_chat_message(name, message))
		return true
	end

	core.chat_send_all(player_color .. core.format_chat_message(name, message))
	return true
end)