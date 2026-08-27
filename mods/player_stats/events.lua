-- Session time, deaths and kill attribution.
return function(stats)

	local last_attackers = {}

	local function is_competitive_player(player)
		return player and player:is_player() and not core.is_creative_enabled(player:get_player_name())
	end

	local function get_player(reference)
		if type(reference) == "string" then
			return core.get_player_by_name(reference)
		end
		return reference
	end

	local function wielded_item_name(player)
		local stack = player and player:get_wielded_item()
		return stack and stack:get_name() or ""
	end

	local function record_attack(victim, attacker, item_name)
		victim = get_player(victim)
		attacker = get_player(attacker)
		if not is_competitive_player(victim) or not is_competitive_player(attacker)
			or victim == attacker then
			return false
		end

		local victim_name = victim:get_player_name()
		local attacker_name = attacker:get_player_name()
		local previous = last_attackers[victim_name]
		local now = core.get_gametime()
		if not item_name and previous and previous.name == attacker_name
				and now - previous.time <= 1 then
			item_name = previous.item
		end

		last_attackers[victim_name] = {
			name = attacker_name,
			item = item_name or wielded_item_name(attacker),
			time = now,
		}
		return true
	end

	-- Lets weapons that use set_hp() or knockback instead of punch() preserve
	-- their owner for kill credit.
	stats.api.record_attack = record_attack

	local function award_kill(victim_name, attacker, is_combat_log)
		stats.add(victim_name, "deaths", 1)
		if not attacker or attacker.name == victim_name then
			return false
		end

		if not is_combat_log and core.get_gametime() - attacker.time > stats.kill_credit_window then
			return false
		end

		stats.add(attacker.name, "kills", 1)
		if skywars and skywars.record_kill then
			skywars.record_kill(attacker.name, attacker.item, victim_name)
		end
		return true
	end

	function stats.api.record_combat_log(victim, attacker, item_name)
		victim = get_player(victim)
		if not is_competitive_player(victim) or type(attacker) ~= "string" or attacker == "" then
			return false
		end

		local victim_name = victim:get_player_name()
		last_attackers[victim_name] = nil
		return award_kill(victim_name, {name = attacker, item = item_name}, true)
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

	core.register_on_punchplayer(function(player, hitter, _, _, _, damage)
		if tonumber(damage) == nil or damage <= 0 then
			return
		end
		record_attack(player, hitter)
	end)

	core.register_on_dieplayer(function(player)
		local victim_name = player:get_player_name()
		local attacker = last_attackers[victim_name]
		last_attackers[victim_name] = nil

		if not is_competitive_player(player) then
			return
		end

		award_kill(victim_name, attacker, false)
	end)
end
