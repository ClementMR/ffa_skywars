local storage = core.get_mod_storage()
local H = {
	storage = storage,
	active = storage:get_int("enabled") == 1,
	objects = {},
	max_objects = math.max(0, math.min(128, tonumber(core.settings:get("ffa_halloween_max_objects")) or 16)),
}
rawset(_G, "ffa_halloween", H)

local path = core.get_modpath(core.get_current_modname())
for _, file in ipairs({"ambience", "broom", "items", "chests", "spirits", "pumpkin_helmet"}) do
	dofile(path .. "/" .. file .. ".lua")
end

function H.set_active(active)
	H.active = active
	storage:set_int("enabled", H.active and 1 or 0)
	if not H.active then
		H.clear_objects()
		H.restore_chests()
	end
end

core.register_chatcommand("halloween", {
	params = "on | off",
	description = "Enable or disable Halloween for everyone.",
	privs = {ffa_manager = true},
	func = function(_, param)
		if param ~= "on" and param ~= "off" then
			return false, "Usage: /halloween on | off. Currently " .. (H.active and "on." or "off.")
		end
		H.set_active(param == "on")
		return true, "Halloween " .. (H.active and "enabled." or "disabled.")
	end,
})

ffa_loot.register_loot_provider("ffa_halloween", function(pos, tier)
	if not H.active then return {} end
	H.skin_chest(pos)
	local chance = tier == "diamond" and 1 or tier == "mese" and 0.7 or 0.35
	return {
		{name = "ffa_halloween:cursed_pumpkin", chance = 0.40, max = 1},
		{name = "ffa_halloween:broom", chance = 0.15, max = 2},
		{name = "ffa_halloween:helmet_pumpkin", chance = 0.50, max = 1},
	}
end)

local environment_timer, spirit_timer = 0, 0
core.register_globalstep(function(dt)
	if not H.active then return end
	environment_timer, spirit_timer = environment_timer + dt, spirit_timer + dt
	local players = core.get_connected_players()
	if environment_timer >= 2 then
		environment_timer = 0
		H.scan_environment(players)
	end
	if spirit_timer >= 10 then
		spirit_timer = 0
		H.spawn_spirits(players)
	end
end)

core.register_on_shutdown(function()
	for _, player in ipairs(core.get_connected_players()) do
		H.stop_broom_flight(player)
	end
end)