return function(throwables)

local active = {}
local pointabilities = {nodes = {}}

function throwables.clear_path(from, to)
	for hit in core.raycast(from, to, false, false, pointabilities) do
		local node = core.get_node_or_nil(hit.under)
		local def = node and core.registered_nodes[node.name]
		if not def or def.walkable then
			return false
		end
	end
	return true
end

function throwables.notify(callbacks, node)
	for _, callback in ipairs(callbacks) do
		local ok, err = pcall(callback, node)
		if not ok then
			core.log("warning", "[ffa_throwables] Impact callback failed: " .. tostring(err))
		end
	end
end

core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_nodes) do
		if def.walkable and def.pointable == false then
			pointabilities.nodes[name] = true
		end
	end
end)

function throwables.valid_player(player)
	return player and player:is_player() and player:get_pos() and player:get_hp() > 0
end

function throwables.can_hit(owner, target)
	if not throwables.valid_player(owner) or not throwables.valid_player(target)
			or owner == target or not core.settings:get_bool("enable_pvp", true) then
		return false
	end
	local groups = target:get_armor_groups()
	if (groups.immortal or 0) ~= 0 or (groups.fleshy or 100) <= 0 then
		return false
	end
	return not (core.global_exists("ffa_timers")
		and ffa_timers.is_immune(target:get_player_name()))
end

function throwables.record_hit(owner, target)
	if core.global_exists("player_stats") then
		player_stats.record_hit(target, owner)
	end
	if core.global_exists("ffa_timers") then
		for _, player in ipairs({owner, target}) do
			if not core.is_creative_enabled(player:get_player_name()) then
				ffa_timers.start_combat(player)
			end
		end
	end
end

local function valid_target(self, object)
	if object == self.object or object == self.owner or not object:get_pos()
			or object:get_hp() <= 0 then
		return false
	end
	if object:is_player() then
		return true
	end
	local entity = object:get_luaentity()
	local properties = object:get_properties()
	return entity and not entity._throwable and entity.name ~= "__builtin:item"
		and properties and properties.physical and (object:get_armor_groups().fleshy or 0) > 0
end

local function trace(self, from, to)
	for hit in core.raycast(from, to, true, false, pointabilities) do
		local valid
		if hit.type == "node" then
			local node = core.get_node_or_nil(hit.under)
			local def = node and core.registered_nodes[node.name]
			valid = not def or def.walkable
		else
			valid = valid_target(self, hit.ref)
		end
		if valid then
			hit.pos = hit.intersection_point or to
			hit.normal = hit.intersection_normal or vector.multiply(vector.normalize(self.last_velocity), -1)
			return hit
		end
	end
end

local function finish(self, hit)
	if self.finished then
		return
	end
	self.finished = true
	throwables.stop_trail(self)
	self.object:remove()
	if hit then
		throwables.impact_particles(self, hit)
		self.def.on_hit(self, hit)
	end
end

local function on_step(self, dtime, moveresult)
	if self.finished then
		return
	end
	self.age = self.age + dtime
	local pos = self.object:get_pos()
	local node = pos and core.get_node_or_nil(pos)
	if self.age >= self.def.lifetime or not node or node.name == "ignore"
			or not throwables.valid_player(self.owner)
			or core.get_player_by_name(self.player_name) ~= self.owner then
		finish(self)
		return
	end

	local hit = trace(self, self.last_pos, pos)
	if not hit then
		for _, collision in ipairs(moveresult and moveresult.collisions or {}) do
			if collision.type == "node" then
				self.last_velocity = collision.old_velocity or self.last_velocity
				local normal = {x = 0, y = 0, z = 0}
				normal[collision.axis] = self.last_velocity[collision.axis] > 0 and -1 or 1
				hit = {type = "node", under = collision.node_pos,
					pos = collision.new_pos or pos, normal = normal}
				break
			end
		end
	end
	if hit then
		finish(self, hit)
		return
	end
	if moveresult and moveresult.collides then
		finish(self)
		return
	end
	self.last_pos = vector.copy(pos)
	self.last_velocity = self.object:get_velocity()
end

function throwables.register_projectile(name, def)
	core.register_entity(":" .. name, {
		_throwable = true,
		initial_properties = {
			physical = true,
			collide_with_objects = false,
			collisionbox = {-0.1, -0.1, -0.1, 0.1, 0.1, 0.1},
			visual = "sprite",
			visual_size = {x = 0.5, y = 0.5},
			textures = {def.texture},
			pointable = false,
			static_save = false,
			glow = def.glow or 0,
		},
		on_activate = function(self, name)
			local player = core.get_player_by_name(name)
			if not throwables.valid_player(player) then
				self.object:remove()
				return
			end
			self.def, self.owner, self.player_name = def, player, name
			self.age = 0
			self.last_pos = self.object:get_pos()
			local inherited = vector.multiply(player:get_velocity(), 0.35)
			self.last_velocity = vector.add(vector.multiply(player:get_look_dir(), def.speed), inherited)
			self.object:set_yaw(core.dir_to_yaw(self.last_velocity))
			self.object:set_velocity(self.last_velocity)
			self.object:set_acceleration({x = 0, y = -def.gravity, z = 0})
			active[self.object] = self
			throwables.start_trail(self, self.last_velocity)
		end,
		on_step = on_step,
		on_deactivate = function(self)
			throwables.stop_trail(self)
			active[self.object] = nil
		end,
	})
end

function throwables.use(entity_name, sound)
	return function(stack, player)
		if not throwables.valid_player(player) then
			return stack
		end
		local count = 0
		for _, projectile in pairs(active) do
			if projectile.owner == player then
				count = count + 1
			end
		end
		if count >= 8 then
			return stack
		end
		local pos = vector.offset(player:get_pos(), 0, player:get_properties().eye_height or 1.625, 0)
		local node = core.get_node_or_nil(pos)
		local def = node and core.registered_nodes[node.name]
		if not def or def.walkable then
			return stack
		end
		local object = core.add_entity(pos, entity_name, player:get_player_name())
		if object then
			stack:take_item(1)
			core.sound_play(sound, {pos = pos, gain = 0.55, max_hear_distance = 16}, true)
		end
		return stack
	end
end

core.register_on_leaveplayer(function(player)
	local remove = {}
	for _, projectile in pairs(active) do
		if projectile.owner == player then
			table.insert(remove, projectile)
		end
	end
	for _, projectile in ipairs(remove) do
		finish(projectile)
	end
end)

end
