local H = ffa_halloween

function H.clean_inventory(inventory)
	for listname, list in pairs(inventory:get_lists()) do
		for index, stack in ipairs(list) do
			if stack:get_name():sub(1, 14) == "ffa_halloween:" then
				inventory:set_stack(listname, index, "")
			end
		end
	end
end

core.register_on_item_pickup(function(stack)
	if not H.active and stack:get_name():sub(1, 14) == "ffa_halloween:" then
		return ItemStack()
	end
end)

core.register_craftitem("ffa_halloween:candy", {
	description = "Soul Candy\nHeals 2 HP",
	inventory_image = "ffa_halloween_candy.png",
	stack_max = 32,
	on_use = function(stack, user, pointed_thing)
		H.sound("candy", {to_player = user:get_player_name(), gain = 0.4})
		H.burst(user:get_pos(), "ffa_halloween_spark.png", 8)

		return core.do_item_eat(2, nil, stack, user, pointed_thing)
	end,
})

core.register_craftitem("ffa_halloween:broom", {
	description = "Magic Broom\nDashes forward",
	inventory_image = "ffa_halloween_broom.png",
	stack_max = 1,
	_cooldown = 2,
	on_use = function(stack, user)
		local direction = user:get_look_dir()
		direction = vector.normalize({x = direction.x, y = 0, z = direction.z})
		user:add_velocity({x = direction.x * 20, y = 10, z = direction.z * 20})
		H.start_broom_flight(user)

		H.sound("dash", {to_player = user:get_player_name(), gain = 0.45})
		H.burst(user:get_pos(), "ffa_halloween_ghost.png", 10)
		stack:take_item()

		return stack
	end,
})

throwables.register_projectile("ffa_halloween:thrown_pumpkin", {
	speed = 17, gravity = 12, lifetime = 5,
	hit_objects = false,
	texture = "ffa_halloween_pumpkin.png", glow = 8,
	impact_amount = 0,
	particles = {throwables.particle("ffa_halloween_spark.png", "#FF9C38")},
	on_hit = function(self, hit)
		if hit.type ~= "node" or not throwables.valid_player(self.owner) then return end
		local node = core.registered_nodes[core.get_node(hit.pos).name]
		tnt.boom(hit.pos, {
			radius = 1,
			strength = 200,
			explode_center = true,
			boom_sound = H.sounds and {name = "tnt_explode", def = {gain = 0.8, max_hear_distance = 64}},
		}, self.player_name, node and node.liquidtype ~= "none")
	end,
})

local throw_pumpkin = throwables.use("ffa_halloween:thrown_pumpkin", H.sounds and "ffa_halloween_laugh" or "")
core.register_craftitem("ffa_halloween:cursed_pumpkin", {
	description = "Cursed Pumpkin",
	inventory_image = "ffa_halloween_pumpkin.png",
	stack_max = 8,
	_cooldown = 5,
	on_use = function(stack, user)
		if not user or not user:is_player() then return stack end
		local count = stack:get_count()
		throw_pumpkin(stack, user)
		if stack:get_count() < count and ffa_timers.is_immune(user:get_player_name()) then
			ffa_timers.clear(user)
		end
		return stack
	end,
})

ffa_loot.register_loot_provider("ffa_halloween", function(pos, tier)
	if not H.active then return {} end
	H.skin_chest(pos)
	local chance = tier == "diamond" and 1 or tier == "mese" and 0.7 or 0.35
	return {
		{name = "ffa_halloween:candy", chance = 0.85, min = 1, max = 2},
		{name = "ffa_halloween:cursed_pumpkin", chance = chance * 0.65, max = 1},
		{name = "ffa_halloween:broom", chance = chance * 0.4, max = 1},
	}
end)
