wind_pearl = {}

local S = core.get_translator(core.get_current_modname())
local cooldown = skywars.cooldown()

local config = {
	cooldown = 1,
	speed = 45,
	gravity = 30,
	knockback_base = 12,
	knockback_y = 4,
	knockback_radius = 7,
	lifetime = 10,
	stack_max = 16,
}

local knockback_callbacks = {}

local function valid_player(player)
	return player and player:is_player() and player:get_hp() > 0
end

local function valid_position(pos)
	return pos and pos.x and pos.y and pos.z
		and math.abs(pos.x) <= 31000
		and math.abs(pos.y) <= 31000
		and math.abs(pos.z) <= 31000
end

local function launch_pearl(player)
	local direction = player:get_look_dir()
	local start_pos = vector.add(player:get_pos(), {
		x = direction.x * 0.4,
		y = player:get_properties().eye_height + direction.y * 0.4,
		z = direction.z * 0.4,
	})

	local object = core.add_entity(start_pos, "wind_pearl:thrown_wind_pearl",
		player:get_player_name())
	if not object then
		return false
	end

	core.sound_play("wind_pearl_throw", {
		pos = start_pos,
		gain = 0.7,
		max_hear_distance = 16,
	})

	return true
end

core.register_craftitem("wind_pearl:wind_pearl", {
	description = S("Wind Pearl") .. core.colorize("#808080", "\nCooldown " .. config.cooldown .. "s"),
	inventory_image = "wind_pearl.png",
	stack_max = config.stack_max,

	on_use = function(itemstack, player)
		if not valid_player(player) or cooldown:get(player) then
			return itemstack
		end

		if launch_pearl(player) then
			cooldown:set(player, config.cooldown)
			itemstack:take_item(1)
		end

		return itemstack
	end,
})

local function apply_knockback(center)
	local objects = core.get_objects_inside_radius(center, config.knockback_radius)
	local processed = 0

	for _, object in ipairs(objects) do
		if processed >= 20 then
			break
		end

		local object_pos = object:get_pos()
		if object_pos and (object:is_player() or object:get_luaentity()) then
			local distance = vector.distance(center, object_pos)
			if distance > 0 and distance <= config.knockback_radius then
				local direction = vector.normalize(vector.subtract(object_pos, center))
				local strength = math.max(1,
					config.knockback_base * (1 - distance / config.knockback_radius))
				local velocity = vector.multiply(direction, strength)
				velocity.y = velocity.y + config.knockback_y

				local can_knockback = true
				if object:is_player() then
					can_knockback = object:get_meta():get_string(
						"wind_pearl_can_knockback") ~= "false"
				end

				if can_knockback then
					object:add_velocity(velocity)
					processed = processed + 1
				end
			end
		end
	end
end

core.register_entity("wind_pearl:thrown_wind_pearl", {
	initial_properties = {
		hp_max = 1,
		physical = true,
		collide_with_objects = false,
		collisionbox = {-0.15, -0.15, -0.15, 0.15, 0.15, 0.15},
		visual = "wielditem",
		visual_size = {x = 0.4, y = 0.4},
		textures = {"wind_pearl:wind_pearl"},
		pointable = false,
	},

	on_activate = function(self, staticdata)
		local player = core.get_player_by_name(staticdata or "")
		if not valid_player(player) then
			self.object:remove()
			return
		end

		self.player_name = player:get_player_name()
		self.age = 0

		local direction = player:get_look_dir()
		self.object:set_rotation({
			x = -player:get_look_vertical(),
			y = player:get_look_horizontal(),
			z = 0,
		})
		self.object:set_velocity(vector.multiply(direction, config.speed))
		self.object:set_acceleration({
			x = direction.x * -4,
			y = -config.gravity,
			z = direction.z * -4,
		})
	end,

	on_step = function(self, dtime, moveresult)
		self.age = (self.age or 0) + dtime
		if self.age >= config.lifetime then
			self.object:remove()
			return
		end

		local collision = moveresult and moveresult.collisions
			and moveresult.collisions[1]
		if not collision or collision.type ~= "node" then
			return
		end

		local pos = self.object:get_pos()
		if not valid_position(pos) then
			self.object:remove()
			return
		end

		apply_knockback(pos)
		core.sound_play("wind_pearl_throw", {
			pos = pos,
			gain = 0.8,
			max_hear_distance = 16,
			pitch = 0.8,
		})

		if collision.node_pos then
			local node = core.get_node_or_nil(collision.node_pos)
			if node then
				for _, callback in ipairs(knockback_callbacks) do
					local ok, err = pcall(callback, node)
					if not ok then
						core.log("warning", "[wind_pearl] knockback callback failed: "
							.. tostring(err))
					end
				end
			end
		end

		self.object:remove()
	end,
})

function wind_pearl.on_knockback(callback)
	if type(callback) == "function" then
		table.insert(knockback_callbacks, callback)
	end
end

function wind_pearl.block_knockback(player, duration)
	if not valid_player(player) then
		return false
	end

	player:get_meta():set_string("wind_pearl_can_knockback", "false")
	if duration and duration > 0 then
		local player_name = player:get_player_name()
		core.after(duration, function()
			local current_player = core.get_player_by_name(player_name)
			if current_player then
				current_player:get_meta():set_string("wind_pearl_can_knockback", "")
			end
		end)
	end

	return true
end