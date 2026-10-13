local H = ffa_halloween
local poisoned = {}

local function clear_poison(player)
	local name = player:get_player_name()
	local poison = poisoned[name]
	if not poison then return end
	poisoned[name] = nil
	player:hud_remove(poison.hud)
end

local function poison_player(player, owner)
	clear_poison(player)
	local name = player:get_player_name()
	local poison = {ticks = 5, hud = player:hud_add({
		type = "image",
		position = {x = 0.5, y = 0.5},
		scale = {x = -100, y = -100},
		text = "[fill:1x1:#648C2840",
		z_index = -400,
	})}
	poisoned[name] = poison
	local function tick()
		if poisoned[name] ~= poison then return end
		if poison.ticks == 0 or core.get_player_by_name(name) ~= player
				or not throwables.can_hit(owner, player) then
			clear_poison(player)
			return
		end
		player:set_hp(player:get_hp() - 1, {type = "set_hp", object = owner})
		poison.ticks = poison.ticks - 1
		core.after(1, tick)
	end
	tick()
end

core.register_on_dieplayer(clear_poison)
core.register_on_leaveplayer(clear_poison)
core.register_on_respawnplayer(clear_poison)

core.register_craftitem("ffa_halloween:candy", {
	description = "Soul Candy\nHeals 2 HP",
	inventory_image = "ffa_halloween_candy.png",
	on_use = core.item_eat(2)
})

core.register_craftitem("ffa_halloween:broom", {
	description = "Magic Broom\nDashes forward",
	inventory_image = "ffa_halloween_broom.png",
	stack_max = 4,
	_cooldown = 2,
	on_use = function(stack, user)
		local direction = user:get_look_dir()
		direction = vector.normalize({x = direction.x, y = 0, z = direction.z})
		user:add_velocity({x = direction.x * 20, y = 10, z = direction.z * 20})
		H.start_broom_flight(user)

		core.sound_play("ffa_halloween_dash", {to_player = user:get_player_name(), gain = 0.45}, true)
		H.burst(user:get_pos(), "ffa_halloween_ghost.png", 10)
		stack:take_item()

		return stack
	end,
})

throwables.register_projectile("ffa_halloween:thrown_pumpkin", {
	speed = 17,
	gravity = 12,
	lifetime = 5,
	texture = "ffa_halloween_pumpkin.png",
	glow = 8,
	impact_amount = 0,
	particles = {throwables.particle("ffa_halloween_spark.png", "#FF9C38")},
	on_hit = function(self, hit)
		local target = hit.ref
		if hit.type ~= "object" or not throwables.can_hit(self.owner, target) then
			return
		end

		poison_player(target, self.owner)
	end
})

core.register_craftitem("ffa_halloween:cursed_pumpkin", {
	description = "Cursed Pumpkin",
	inventory_image = "ffa_halloween_pumpkin.png",
	stack_max = 8,
	_cooldown = 4,
	on_use = throwables.use("ffa_halloween:thrown_pumpkin", "ffa_halloween_laugh"),
})