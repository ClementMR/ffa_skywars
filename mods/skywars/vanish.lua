local STR = "skywars:vanished"
local armor_available = core.global_exists("armor")
local playertag_available = core.global_exists("playertag")

local S = core.get_translator(core.get_current_modname())

local function is_vanished(player)
	return player:get_meta():get_string(STR) == "true"
end

local function set_vanish(player, value)
	player:get_meta():set_string(STR, value and "true" or "false")
end

local function unvanish_player(player)
	if not is_vanished(player) then
		return false
	end

	player:set_properties({
		pointable = true,
		visual_size = {x = 1, y = 1},
		is_visible = true,
		makes_footstep_sound = true,
		show_on_minimap = true,
	})

	if playertag_available then
		playertag.update(player)
	else
		player:set_nametag_attributes({
			text = player:get_player_name(),
			color = {a = 255, r = 255, g = 255, b = 255},
		})
	end

	set_vanish(player, false)
	core.chat_send_player(player:get_player_name(), S("You are now unvanished."))

	return true
end

local function clear_properties(player)
	player:set_properties({
		pointable = false,
		visual_size = {x = 0, y = 0},
		is_visible = false,
		makes_footstep_sound = false,
		show_on_minimap = false,
	})

	if playertag_available then
		playertag.remove(player)
	else
		player:set_nametag_attributes({
			text = " ",
			color = {a = 0, r = 0, g = 0, b = 0},
		})
	end
end

local function vanish_player(player)
	if is_vanished(player) then
		return false
	end

	clear_properties(player)
	set_vanish(player, true)
	core.chat_send_player(player:get_player_name(), S("You are now vanished."))

	return true
end

if armor_available then
	armor:register_on_update(function(player)
		if is_vanished(player) then
			clear_properties(player)
		end
	end)
end

core.register_chatcommand("vanish", {
	description = "",
	params = "<player>",
	privs = {ffa_manager = true},
	func = function(name, param)
		if param ~= "" then
			local target_player = core.get_player_by_name(param)
			if target_player then
				vanish_player(target_player)
			end

			return false, S("The player @1 does not exist or is not online.", param)
		end

		local player = core.get_player_by_name(name)
		if player then
			vanish_player(player)
		end
	end,
})

core.register_chatcommand("unvanish", {
	description = "",
	privs = {ffa_manager = true},
	params = "<player>",
	func = function(name, param)
		if param ~= "" then
			local target_player = core.get_player_by_name(param)
			if target_player then
				unvanish_player(target_player)
			end

			return false, S("The player @1 does not exist or is not online.", param)
		end

		local player = core.get_player_by_name(name)
		if player then
			unvanish_player(player)
		end
	end,
})

core.register_on_joinplayer(function(player)
    if is_vanished(player) then
        clear_properties(player)

		core.after(0.5, function()
			if playertag_available then
				playertag.remove(player)
			end
		end)
	end
end)

core.register_on_respawnplayer(function(player)
	if is_vanished(player) then
		clear_properties(player)
	end
end)