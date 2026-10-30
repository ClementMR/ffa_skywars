return function(throwables)

local radius = 3

local function check_hit(pos1, pos2, obj)
	local ray = core.raycast(pos1, pos2, true, false)
	local hit = ray:next()

	-- Skip over non-normal nodes like ladders, water, doors, glass, leaves, etc
	-- Also skip over all objects that aren't the target
	-- Any collisions within a 1 node distance from the target don't stop the fireball
	while hit and ((hit.type == "node" and (hit.intersection_point:distance(pos2) <= 1 or not core.registered_nodes[core.get_node(hit.under).name].walkable))
		or (hit.type == "object" and hit.ref ~= obj)) do
		hit = ray:next()
	end

	if hit and hit.type == "object" and hit.ref == obj then
		return true
	end
end

local function on_explode(obj, pos, name)
	core.sound_play("tnt_explode", {
		pos = pos,
		gain = 1.0,
		max_hear_distance = 32,
	})

    for _, obj in pairs(core.get_objects_inside_radius(pos, radius)) do
        if obj:is_player() and obj:get_hp() > 0 and obj:get_properties().pointable then
            local footpos = vector.offset(obj:get_pos(), 0, 0.1, 0)
            local headpos = vector.offset(obj:get_pos(), 0, obj:get_properties().eye_height, 0)
            local footdist = vector.distance(pos, footpos)
            local headdist = vector.distance(pos, headpos)
            local target_head = false

            if footdist >= headdist then
                target_head = true
            end

            local hit_pos1 = check_hit(pos, target_head and headpos or footpos, obj)

			-- Check the closest distance, but if that fails try targeting the farther one
			if hit_pos1 or check_hit(pos, target_head and footpos or headpos, obj) then
				obj:punch(core.get_player_by_name(name), 1, {
                    punch_interval = 1,
                    damage_groups = { fleshy = 12 - ((radius/2) * (target_head and headdist or footdist)) }
                }, nil)
            end
        end
    end

	if core.get_node(pos).name == "air" then
		core.set_node(pos, {name = "fire:blue_flame"})
	end
end

throwables.register_projectile("throwables:thrown_fireball", {
	speed = 17,
    gravity = 12,
    lifetime = 5,
	hit_objects = false,
	texture = "skywars_fireball.png",
    glow = 8,
	impact_amount = 0,
	on_hit = function(self, hit)		
		on_explode(self.object, hit.pos, self.player_name)
	end,
})

core.register_craftitem(":skywars:fireball", {
    description = throwables.S("Fireball"),
	inventory_image = "skywars_fireball.png",
	stack_max = 16,
    _cooldown = 0.5,
    on_use = throwables.use("throwables:thrown_fireball", "skywars_fireball_thrown"),
})

end