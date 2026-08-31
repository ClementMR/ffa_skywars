return function(throwables)

local callbacks, blocks = {}, {}

local function clear_destination(player, pos)
	local box = player:get_properties().collisionbox or {-0.3, 0, -0.3, 0.3, 1.75, 0.3}
	for x = math.floor(pos.x + box[1] + 0.501), math.floor(pos.x + box[4] + 0.499) do
		for y = math.floor(pos.y + box[2] + 0.501), math.floor(pos.y + box[5] + 0.499) do
			for z = math.floor(pos.z + box[3] + 0.501), math.floor(pos.z + box[6] + 0.499) do
				local node = core.get_node_or_nil({x = x, y = y, z = z})
				local def = node and core.registered_nodes[node.name]
				if not def or node.name == "ignore" or def.walkable or (def.damage_per_second or 0) > 0 then
					return false
				end
			end
		end
	end
	return true
end

local function destination(player, hit)
	local box = player:get_properties().collisionbox or {-0.3, 0, -0.3, 0.3, 1.75, 0.3}
	local distance = math.max(math.abs(box[1]), box[4], math.abs(box[3]), box[6]) + 0.1
	if hit.normal.y > 0.5 then
		distance = math.max(0, -box[2]) + 0.1
	elseif hit.normal.y < -0.5 then
		distance = box[5] + 0.1
	end
	local pos = vector.add(hit.pos, vector.multiply(hit.normal, distance))
	if clear_destination(player, pos) then
		return pos
	end
end

throwables.register_projectile("enderpearl:thrown_ender_pearl", {
	speed = 30,
	gravity = 16,
	lifetime = 6,
	texture = "enderpearl.png",
	glow = 5,
	particles = {
		throwables.particle("enderpearl.png", "#B476FF"),
		throwables.particle("enderpearl.png", "#40E5CE"),
	},
	on_hit = function(self, hit)
		local player = self.owner
		if player:get_meta():get_string("ep_can_teleport") == "false" then
			return
		end
		local pos = destination(player, hit)
		if not pos then
			return
		end
		player:add_velocity(vector.multiply(player:get_velocity(), -1))
		player:set_pos(pos)
		core.sound_play("enderpearl_teleport", {pos = pos, max_hear_distance = 16}, true)
		if hit.type == "node" then
			throwables.notify(callbacks, core.get_node(hit.under))
		end
	end,
})

core.register_craftitem(":enderpearl:ender_pearl", {
	description = core.colorize("#1DAEB3", "Ender Pearl") .. core.colorize("#808080", "\nCooldown 2s"),
	inventory_image = "enderpearl.png",
	stack_max = 16,
	_cooldown = 2,
	on_use = throwables.use("enderpearl:thrown_ender_pearl", "throwables_throw"),
})

function throwables.on_teleport(callback)
	assert(type(callback) == "function")
	table.insert(callbacks, callback)
end

function throwables.block_teleport(player, duration)
	if not throwables.valid_player(player) then
		return false
	end
	local name, token = player:get_player_name(), {}
	blocks[name] = token
	player:get_meta():set_string("ep_can_teleport", duration == 0 and "" or "false")
	if duration and duration > 0 then
		core.after(duration, function()
			local current = core.get_player_by_name(name)
			if blocks[name] == token and current then
				current:get_meta():set_string("ep_can_teleport", "")
				blocks[name] = nil
			end
		end)
	end
	return true
end

end
