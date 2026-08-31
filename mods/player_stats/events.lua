-- Session time, deaths and kill attribution.
return function(stats)

	local last_attackers = {}

	local function is_competitive_player(player)
		return player and player:is_player() and not core.is_creative_enabled(player:get_player_name())
	end

	core.register_on_joinplayer(function(player)
		stats.start_session(player:get_player_name())
	end)

	core.register_on_leaveplayer(function(player)
		local name = player:get_player_name()
		stats.finish_session(name)
		last_attackers[name] = nil
		if stats.close_form then
			stats.close_form(name)
		end
	end)

	function stats.api.record_hit(player, hitter)
		if not is_competitive_player(player) or not is_competitive_player(hitter) then
			return
		end
		if player == hitter then
			return
		end

		last_attackers[player:get_player_name()] = {
			name = hitter:get_player_name(),
			time = core.get_gametime(),
		}
	end

	core.register_on_player_hpchange(function(player, change, reason)
		if change < 0 and reason.type == "punch" then
			stats.api.record_hit(player, reason.object)
		end
	end)

	core.register_on_dieplayer(function(player)
		local victim_name = player:get_player_name()
		local attacker = last_attackers[victim_name]
		last_attackers[victim_name] = nil

		if not is_competitive_player(player) then
			return
		end

		stats.add(victim_name, "deaths", 1)
		if attacker and attacker.name ~= victim_name
			and core.get_gametime() - attacker.time <= stats.kill_credit_window then
			stats.add(attacker.name, "kills", 1)
		end
	end)
end