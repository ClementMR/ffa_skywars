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

core.send_join_message = function(name)
	local token = {}
	pending_joins[name] = token
	core.after(1, function()
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
		core.chat_send_all("*** " .. text)
	end)
end

core.send_leave_message = function(name, timed_out)
	pending_joins[name] = nil
	local in_combat = ffa_timers and ffa_timers.is_in_combat(name) or false
	local text = in_combat and S("@1 left the game during combat!",
		core.colorize("#F4F4F5", name))
		or S("@1 left the game.", name)
	if timed_out then
		text = text .. " " .. S("(timed out)")
	end
	core.chat_send_all("*** " .. text)
end
