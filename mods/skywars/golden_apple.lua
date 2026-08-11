local GOLDEN_APPLE_ABSORPTION = 4
local absorption_huds = {}

local function get_absorption(player)
	return math.max(0, player:get_meta():get_int("skywars:golden_apple_absorption"))
end

local function set_absorption(player, amount)
	player:get_meta():set_int("skywars:golden_apple_absorption", math.max(0, math.min(GOLDEN_APPLE_ABSORPTION, amount)))
end

local function remove_absorption_hud(player)
	local name = player:get_player_name()
	local hud_id = absorption_huds[name]
	if hud_id then
		player:hud_remove(hud_id)
		absorption_huds[name] = nil
	end
end

local function update_absorption_hud(player)
	local amount = get_absorption(player)
	if amount <= 0 then
		remove_absorption_hud(player)
		return
	end

	local name = player:get_player_name()
	local hud_id = absorption_huds[name]
	if not hud_id then
		hud_id = player:hud_add({
			type = "statbar",
			position = {x = 0.5, y = 1},
			text = "heart.png^[colorize:#F3F22D:190",
			number = amount,
			item = GOLDEN_APPLE_ABSORPTION,
			direction = 0,
			size = {x = 24, y = 24},
			offset = {x = -262, y = -112},
			z_index = 10,
		})
		absorption_huds[name] = hud_id
	else
		player:hud_change(hud_id, "number", amount)
		player:hud_change(hud_id, "item", GOLDEN_APPLE_ABSORPTION)
	end
end

local function clear_golden_apple(player)
	set_absorption(player, 0)
	update_absorption_hud(player)
end

local function apply_golden_apple(player)
	set_absorption(player, GOLDEN_APPLE_ABSORPTION)

	local props = player:get_properties() or {}
	local hp_max = props.hp_max or 20
	player:set_hp(hp_max, {type = "set_hp", cause = "skywars:golden_apple"})

	update_absorption_hud(player)
end

core.register_craftitem("skywars:golden_apple", {
	description = "Golden Apple",
	inventory_image = "skywars_golden_apple.png",
	stack_max = 8,
	on_use = function(itemstack, user)
		if not user or not user:is_player() then
			return itemstack
		end
		apply_golden_apple(user)
		local name = user:get_player_name()
		if not core.is_creative_enabled(name) then
			itemstack:take_item()
		end
		return itemstack
	end,
})

core.register_on_player_hpchange(function(player, hp_change)
	if hp_change >= 0 then
		return hp_change
	end

	local absorption = get_absorption(player)
	if absorption <= 0 then
		return hp_change
	end

	local damage = -hp_change
	local absorbed = math.min(absorption, damage)
	set_absorption(player, absorption - absorbed)
	update_absorption_hud(player)
	core.sound_play("player_damage", {to_player = player:get_player_name(), gain = 0.5})
	return hp_change + absorbed
end, true)

core.register_on_dieplayer(function(player)
	clear_golden_apple(player)
end)

core.register_on_joinplayer(function(player)
	core.after(0, function()
		if player and player:is_player() then
			update_absorption_hud(player)
		end
	end)
end)

core.register_on_leaveplayer(function(player)
	absorption_huds[player:get_player_name()] = nil
end)
