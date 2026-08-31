return function(throwables)

local damage, knockback, lift = 1, 3, 1.2

throwables.register_projectile("ffa_throwables:snowball", {
	speed = 28,
	gravity = 20,
	lifetime = 5,
	texture = "default_snowball.png",
	impact_amount = 28,
	trail = {
		rate = 120,
		backward = 0.4,
		offset = 0.018,
		size = {min = 2.4, max = 4.2},
		exptime = {min = 0.28, max = 0.55},
		glow = 7,
	},
	particles = throwables.rainbow("default_snowball.png"),
	on_hit = function(self, hit)
		local target = hit.ref
		if hit.type ~= "object" or not throwables.can_hit(self.owner, target) then
			return
		end
		local hp = target:get_hp()
		local amount = damage
		target:punch(self.owner, 1, {
			full_punch_interval = 1,
			damage_groups = {["fleshy"] = amount},
		}, {x = 0, y = 0, z = 0})
		if target:get_hp() < hp then
			local direction = vector.normalize({x = self.last_velocity.x, y = 0, z = self.last_velocity.z})
			target:add_velocity(vector.offset(vector.multiply(direction, knockback), 0, lift, 0))
			if target:get_hp() > 0 then
				throwables.record_hit(self.owner, target)
			end
		end
	end,
})

core.register_craftitem("throwables:snowball", {
	description = "Snowball" .. core.colorize("#808080", "\nCooldown 0.4s"),
	inventory_image = "default_snowball.png",
	stack_max = 16,
	_cooldown = 0.4,
	on_use = throwables.use("ffa_throwables:snowball", "throwables_throw"),
})

end
