return function(throwables)

local callbacks, blocks = {}, {}
local radius, strength, lift = 7, 10, 4

throwables.register_projectile("throwables:thrown_wind_pearl", {
	speed = 14,
	gravity = 20,
	lifetime = 6,
	texture = "wind_pearl.png",
	glow = 3,
	impact_amount = 24,
	particles = {
		throwables.particle("wind_pearl.png", "#B9EEFF"),
		throwables.particle("wind_pearl.png", "#FFFFFF"),
	},
	on_hit = function(self, hit)
		local center = vector.add(hit.pos, vector.multiply(hit.normal, 0.15))
		for _, object in ipairs(core.get_objects_inside_radius(center, radius)) do
			local pos = object:get_pos()
			local properties = object:get_properties()
			local entity = object:get_luaentity()
			local player = object:is_player()
			local allowed = player and (object == self.owner or throwables.can_hit(self.owner, object))
				or (not player and entity and not entity._throwable and entity.name ~= "__builtin:item"
					and properties and properties.physical)
			if player and object:get_meta():get_string("wind_pearl_can_knockback") == "false" then
				allowed = false
			end
			if allowed and pos and object:get_hp() > 0 then
				local target = vector.offset(pos, 0, player and 0.8 or 0, 0)
				local distance = vector.distance(center, target)
				if distance <= radius and throwables.clear_path(center, target) then
					local direction = vector.normalize(vector.subtract(target, center))
					local velocity = vector.multiply(direction, strength * (1 - distance / radius))
					velocity.y = math.max(0, velocity.y) + lift
					object:add_velocity(velocity)
					if player and object ~= self.owner then
						throwables.record_hit(self.owner, object)
					end
				end
			end
		end
		if hit.type == "node" then
			throwables.notify(callbacks, core.get_node(hit.under))
		end
	end,
})

core.register_craftitem("throwables:wind_pearl", {
	description = throwables.S("Wind Pearl") .. core.colorize("#808080", "\nCooldown 1s"),
	inventory_image = "wind_pearl.png",
	stack_max = 16,
	_cooldown = 1,
	on_use = throwables.use("throwables:thrown_wind_pearl", "throwables_throw"),
})

function throwables.on_knockback(callback)
	assert(type(callback) == "function")
	table.insert(callbacks, callback)
end

function throwables.block_knockback(player, duration)
	if not throwables.valid_player(player) then
		return false
	end
	local name, token = player:get_player_name(), {}
	blocks[name] = token
	player:get_meta():set_string("wind_pearl_can_knockback", duration == 0 and "" or "false")
	if duration and duration > 0 then
		core.after(duration, function()
			local current = core.get_player_by_name(name)
			if blocks[name] == token and current then
				current:get_meta():set_string("wind_pearl_can_knockback", "")
				blocks[name] = nil
			end
		end)
	end
	return true
end

end
