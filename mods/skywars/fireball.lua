local fireball_deaccel = 4

local S = core.get_translator(core.get_current_modname())

local function check_hit(pos1, pos2, obj)
	local ray = core.raycast(pos1, pos2, true, false)
	local hit = ray:next()

	-- Skip over non-normal nodes like ladders, water, doors, glass, leaves, etc
	-- Also skip over all objects that aren't the target
	-- Any collisions within a 1 node distance from the target don't stop the fireball
	while hit and (
		(
		 hit.type == "node"
		 and
		 (
			hit.intersection_point:distance(pos2) <= 1
			or
			not core.registered_nodes[core.get_node(hit.under).name].walkable
		 )
		)
		or
		(
		 hit.type == "object" and hit.ref ~= obj
		)
	) do
		hit = ray:next()
	end

	if hit and hit.type == "object" and hit.ref == obj then
		return true
	end
end

local function on_explode(obj, pos, name)
    if not name or not pos then return end

    local player = core.get_player_by_name(name)
    if not player then return end

    local radius = 3

    for x = -radius/2, radius/2 do
        for y = 0, 2 do
            for z = -radius/2, radius/2 do
                local pos = vector.add(pos, vector.new(x, y, z))
                local ran = math.random(1, 3)
                if core.get_node(pos).name == "air" and ran == 1 then
                    core.set_node(pos, {name = "fire:basic_flame"})
                end

                if core.get_modpath("tnt") and core.get_node(pos).name == "tnt:tnt" then
                    tnt.burn(pos)
                end
            end
        end
    end

    core.sound_play("grenades_explode", {
        pos = pos,
        gain = 0.6,
        max_hear_distance = 32,
    })

    for _, v in pairs(core.get_objects_inside_radius(pos, radius)) do
        if v:is_player() and v:get_hp() > 0 and v:get_properties().pointable then
            local footpos = vector.offset(v:get_pos(), 0, 0.1, 0)
            local headpos = vector.offset(v:get_pos(), 0, v:get_properties().eye_height, 0)
            local footdist = vector.distance(pos, footpos)
            local headdist = vector.distance(pos, headpos)
            local target_head = false

            if footdist >= headdist then
                target_head = true
            end

            local hit_pos1 = check_hit(pos, target_head and headpos or footpos, v)

			-- Check the closest distance, but if that fails try targeting the farther one
			if hit_pos1 or check_hit(pos, target_head and footpos or headpos, v) then
				local stats_api = rawget(_G, "player_stats")
				if stats_api and stats_api.record_attack then
					stats_api.record_attack(v, player, "skywars:fireball")
				end
				v:punch(player, 1, {
                    punch_interval = 1,
                    damage_groups = {
                        fleshy = 15 - ( (radius/2) * (target_head and headdist or footdist) )
                    }
                }, nil)
            end
        end
    end
end

core.register_entity("skywars:fireball", {
    initial_properties = {
        physical = true,
        collide_with_objects = false,
        visual = "sprite",
        visual_size = {x = 0.5, y = 0.5, z = 0.5},
        textures = {"skywars_fireball.png"},
        collisionbox = {-0.05, -0.05, -0.05, 0.05, 0.05, 0.05},
        pointable = false,
        static_save = false,
    },
    timer = 0,
    on_step = function(self, dtime, moveresult)
        local obj = self.object
        local vel = obj:get_velocity()
        local pos = obj:get_pos()
        local norm_vel -- Normalized velocity

        self.timer = self.timer + dtime

        -- Check for a collision on the x/y/z axis

        if moveresult.collides and moveresult.collisions then
            if self.thrower_name then
                core.log("action", "A fireball thrown by " .. self.thrower_name ..
                        " explodes at " .. core.pos_to_string(vector.round(pos)))
                on_explode(obj, pos, self.thrower_name)
            end
            obj:remove()
            obj:set_velocity(vel)
        end

        norm_vel = vector.normalize(vel)

        if not vector.equals(vel, vector.new()) then
            obj:set_acceleration({
                x = -norm_vel.x * fireball_deaccel * (moveresult.touching_ground and 2 or 1),
                y = -9.81,
                z = -norm_vel.z * fireball_deaccel * (moveresult.touching_ground and 2 or 1),
            })
        end

        if moveresult.touching_ground then
            -- If fireball is barely moving, make sure it stays that way
            if vector.distance(vector.new(), vel) <= 2 and not vector.equals(vel, vector.new()) then
                obj:set_velocity(vector.new())
                obj:set_acceleration(vector.new(0, -9.81, 0))
            end
        end

        if self.timer > 4 or not self.thrower_name then
            if self.thrower_name then
                core.log("action", "A fireball thrown by " .. self.thrower_name ..
                " explodes at " .. core.pos_to_string(vector.round(pos)))
                on_explode(obj, pos, self.thrower_name)
            end

            obj:remove()
        end
    end
})

local function throw_fireball(name, startspeed, player)
	local dir = player:get_look_dir()
	local pos = vector.offset(player:get_pos(), 0, player:get_properties().eye_height, 0)

	local obj = core.add_entity(pos, name)
	if not obj then return end

	core.sound_play("skywars_fireball_thrown", {
		pos = pos,
		gain = 0.5,
		max_hear_distance = 32,
	})

	obj:set_velocity(vector.add(vector.multiply(dir, startspeed), player:get_velocity()))
	obj:set_acceleration({x = 0, y = -9.81, z = 0})

	local data = obj:get_luaentity()
	data.thrower_name = player:get_player_name()

	return data
end

local cooldown = skywars.cooldown()
core.register_craftitem("skywars:fireball", {
    description = S("Fireball"),
	inventory_image = "skywars_fireball.png",
    range = 2.0,
	stack_max = 4,
    on_use = function(itemstack, user, pointed_thing)
        if cooldown:get(user) then
            return
        else
            cooldown:set(user, 1.0)
        end

		if pointed_thing.type ~= "node" then
			throw_fireball("skywars:fireball", 17, user)
            itemstack:take_item(1)
		end

		return itemstack
	end
})

core.register_alias_force("ranged:fireball", "skywars:fireball")
