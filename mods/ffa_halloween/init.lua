local storage = core.get_mod_storage()
local H = {
	storage = storage,
	active = storage:get_int("enabled") == 1,
	ambience = {},
	objects = {},
	sounds = core.settings:get_bool("ffa_halloween_sounds", true),
	particles = core.settings:get_bool("ffa_halloween_particles", true),
	fog_distance = math.max(16, math.min(300, tonumber(core.settings:get("ffa_halloween_fog_distance")) or 75)),
	max_objects = math.max(0, math.min(128, tonumber(core.settings:get("ffa_halloween_max_objects")) or 32)),
}
rawset(_G, "ffa_halloween", H)

local path = core.get_modpath(core.get_current_modname())
for _, file in ipairs({"ambience", "broom", "items", "chests", "spirits"}) do
	dofile(path .. "/" .. file .. ".lua")
end

function H.set_active(active)
	H.active = active
	storage:set_int("enabled", active and 1 or 0)
	for _, player in ipairs(core.get_connected_players()) do
		if active then
			H.apply_ambience(player)
		else
			H.stop_broom_flight(player)
			H.restore_ambience(player)
			H.clean_inventory(player:get_inventory())
		end
	end
	if not active then
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

local environment_timer, spirit_timer = 0, 0
core.register_globalstep(function(dt)
	if not H.active then return end
	environment_timer, spirit_timer = environment_timer + dt, spirit_timer + dt
	local players = core.get_connected_players()
	if environment_timer >= 2 then
		environment_timer = 0
		for _, player in ipairs(players) do
			-- Reapply if skybox rotation changed the sky during Halloween.
			if not H.ambience[player:get_player_name()] or player:get_moon().texture ~= "ffa_halloween_moon.png" then
				H.apply_ambience(player)
			end
		end
		H.scan_environment(players)
	end
	if spirit_timer >= 10 then
		spirit_timer = 0
		H.spawn_spirits(players)
		for _, player in ipairs(players) do
			H.sound("ambience", {to_player = player:get_player_name(), gain = 0.13})
		end
	end
end)

core.register_on_joinplayer(function(player)
	core.after(0.6, function()
		if core.get_player_by_name(player:get_player_name()) ~= player then return end
		if H.active then H.apply_ambience(player)
		else H.clean_inventory(player:get_inventory()) end
	end)
end)

core.register_on_leaveplayer(function(player)
	H.restore_ambience(player)
end)

core.register_on_shutdown(function()
	for _, player in ipairs(core.get_connected_players()) do
		H.stop_broom_flight(player)
		H.restore_ambience(player)
	end
end)
