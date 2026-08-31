return function(throwables)

local function range(center, spread)
	return {
		min = vector.subtract(center, spread),
		max = vector.add(center, spread),
	}
end

function throwables.start_trail(self, velocity)
	local def = self.def
	local trail = def.trail or {}
	local horizontal = math.sqrt(velocity.x ^ 2 + velocity.z ^ 2)
	local motion = {x = 0, y = velocity.y, z = horizontal}
	local final_motion = vector.offset(motion, 0, -def.gravity * def.lifetime, 0)
	local backward = trail.backward or 0.28
	local offset = trail.offset or 0.012
	self.trail = core.add_particlespawner({
		amount = math.floor(def.lifetime * (trail.rate or 72)),
		time = def.lifetime,
		attached = self.object,
		pos_tween = {
			range(vector.multiply(motion, -offset), 0.04),
			range(vector.multiply(final_motion, -offset), 0.04),
		},
		vel_tween = {
			range(vector.multiply(motion, -backward), 0.25),
			range(vector.multiply(final_motion, -backward), 0.25),
		},
		acc = {x = 0, y = 0, z = 0},
		exptime = trail.exptime or {min = 0.22, max = 0.45},
		size = trail.size or {min = 0.6, max = 1.4},
		texpool = def.particles,
		glow = trail.glow or def.glow or 0,
		collisiondetection = true,
		collision_removal = true,
		object_collision = true,
	})
end

function throwables.stop_trail(self)
	if self.trail and self.trail ~= -1 then
		core.delete_particlespawner(self.trail)
	end
	self.trail = nil
end

function throwables.impact_particles(self, hit)
	local trail = self.def.trail or {}
	local backward = vector.multiply(vector.normalize(self.last_velocity), -4.5)
	local pos = vector.add(hit.pos, vector.multiply(hit.normal, 0.12))
	core.add_particlespawner({
		amount = self.def.impact_amount or 12,
		time = 0.08,
		pos = range(pos, 0.08),
		vel = range(backward, 1.1),
		acc = {x = 0, y = -3, z = 0},
		exptime = {min = 0.15, max = 0.4},
		size = trail.size or {min = 0.8, max = 1.8},
		texpool = self.def.particles,
		glow = trail.glow or self.def.glow or 0,
		collisiondetection = true,
		collision_removal = true,
		object_collision = true,
	})
end

function throwables.particle(texture, color, strength)
	return {
		name = texture .. "^[colorize:" .. color .. ":" .. (strength or 180),
		alpha_tween = {1, 0},
		scale_tween = {{x = 1, y = 1}, {x = 0.25, y = 0.25}},
	}
end

function throwables.rainbow(texture)
	local particles = {}
	for _, color in ipairs({
		"#FF3B5C", "#FF912B", "#FFE44D", "#8DFF45", "#24E892",
		"#35DFFF", "#477DFF", "#955CFF", "#FF4CE1",
	}) do
		table.insert(particles, throwables.particle(texture, color, 230))
	end
	return particles
end

end
