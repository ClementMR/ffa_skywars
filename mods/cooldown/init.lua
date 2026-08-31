cooldown = {}

local players = {}

function cooldown.set(player, itemname, time)
	local name = player:get_player_name()

	players[name] = players[name] or {}
	players[name][itemname] = core.get_us_time() + (time * 1000000)
end

function cooldown.get(player, itemname)
	local name = player:get_player_name()

	if not players[name] or not players[name][itemname] then
		return 0
	end

	local remaining = (players[name][itemname] - core.get_us_time()) / 1000000

	if remaining <= 0 then
		players[name][itemname] = nil
		return 0
	end

	return remaining
end

function cooldown.is_active(player, itemname)
	return cooldown.get(player, itemname) > 0
end


core.register_on_mods_loaded(function()
	for itemname, def in pairs(core.registered_items) do
		if def._cooldown and def.on_use then
			local original_on_use = def.on_use
			local duration = def._cooldown

			core.override_item(itemname, {
				on_use = function(itemstack, user, pointed_thing)
					if cooldown.is_active(user, itemname) then
						return itemstack
					end

					local result = original_on_use(
						itemstack,
						user,
						pointed_thing
					)

					cooldown.set(user, itemname, duration)

					return result
				end
			})
		end
	end
end)


core.register_on_leaveplayer(function(player)
	players[player:get_player_name()] = nil
end)