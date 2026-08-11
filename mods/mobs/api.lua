
-- translation & mod checks

local S = core.get_translator("mobs")
local FS = function(...) return core.formspec_escape(S(...)) end
local use_cmi = false
local use_mc2 = false
local use_vh1 = false
local use_tr = false
local use_invisibility = false

-- node check helper

local function has(nodename)
	return core.registered_nodes[nodename] and nodename
end

-- global table

mobs = {
	mod = "redo", version = "20250603",
	spawning_mobs = {}, translate = S,
	node_snow = has(core.registered_aliases["mapgen_snow"])
			or has("mcl_core:snow") or has("default:snow") or "air",
	node_dirt = has(core.registered_aliases["mapgen_dirt"])
			or has("mcl_core:dirt") or has("default:dirt")
}
mobs.fallback_node = mobs.node_dirt

-- load compatibility check function

dofile(core.get_modpath("mobs") .. "/compatibility.lua")

-- localize common functions

local pi, abs, min, max = math.pi, math.abs, math.min, math.max
local square, random = math.sqrt, math.random
local sin, cos, rad, deg = math.sin, math.cos, math.rad, math.deg
local floor, ceil, vdirection = math.floor, math.ceil, vector.direction
local vmultiply, vsubtract = vector.multiply, vector.subtract
local settings, atann = core.settings, math.atan
local function atan(x)
	if not x or x ~= x then return 0 else return atann(x) end
end
local table_copy, table_remove = table.copy, table.remove

-- creative check

local creative_cache = core.settings:get_bool("creative_mode")
function mobs.is_creative(name)
	return creative_cache or core.check_player_privs(name, {creative = true})
end

-- load settings

local damage_enabled = settings:get_bool("enable_damage")
local mob_hit_effect = false
local remove_far = true
local difficulty = 1.0
local active_limit = 0
local mob_smooth_rotate = true
local mob_height_fix = settings:get_bool("mob_height_fix")
local active_mobs = 0
local mob_infotext = true

-- loop interval timers

local node_timer_interval = 0.25
local main_timer_interval = 1.0

-- pathfind settings

local pathfinding_enable = true
local pathfinding_stuck_timeout = 3.0
local pathfinding_stuck_path_timeout = 5.0
local pathfinding_algorithm = "Dijkstra"

if pathfinding_algorithm == "AStar_noprefetch" then
	pathfinding_algorithm = "A*_noprefetch"
elseif pathfinding_algorithm == "AStar" then
	pathfinding_algorithm = "A*"
end

local pathfinding_max_jump = 4
local pathfinding_max_drop = 6
local pathfinding_searchdistance = 16

-- can we attack Creatura mobs ?

local creatura = core.get_modpath("creatura")

-- default mob settings

mobs.mob_class = {
	state = "stand",
	fly_in = "air",
	owner = "",
	order = "",
	jump_height = 4,
	lifetimer = 180, -- 3 minutes
	texture_mods = "",
	view_range = 5,
	walk_velocity = 1, run_velocity = 2,
	light_damage = 0, light_damage_min = 14, light_damage_max = 15,
	water_damage = 0, lava_damage = 4, fire_damage = 4, air_damage = 0,
	node_damage = true,
	suffocation = 2,
	fall_damage = true,
	fall_speed = -10, -- must be lower than -2
	armor = 100,
	sounds = {},
	knock_back = true,
	walk_chance = 50,
	stand_chance = 30,
	attack_chance = 5,
	attack_patience = 11,
	passive = false,
	shoot_offset = 0,
	floats = true, -- floats in water
	timer = 0,
	env_damage_timer = 0,
	tamed = false,
	pause_timer = 0,
	child = false,
	gotten = false,
	health = 0,
	reach = 3,
	docile_by_day = false,
	time_of_day = 0.5,
	fear_height = 0,
	runaway_timer = 0,
	immune_to = {},
	explosion_timer = 3,
	allow_fuse_reset = true,
	stop_to_explode = true,
	dogshoot_count = 0, dogshoot_count_max = 5, dogshoot_count2_max = 5,
	group_attack = false,
	attack_monsters = false,
	attack_animals = false,
	attack_players = true,
	attack_npcs = true,
	attack_ignore = nil,
	friendly_fire = true,
	facing_fence = false,
	_cmi_is_mob = true
}

local mob_class = mobs.mob_class -- compatibility
local mob_class_meta = {__index = mob_class}

-- return True if mob limit reached

local function at_limit()

	if active_limit and active_limit > 0
	and active_mobs and active_mobs >= active_limit then return true end
end

-- play sound

function mob_class:mob_sound(sound)

	if not sound then return end

	local pitch = self.child and 1.5 or 1.0 -- higher pitch for a child

	pitch = pitch + random(-10, 10) * 0.005 -- random pitch difference

	core.sound_play(sound, {
		object = self.object, gain = 1.0, pitch = pitch,
		max_hear_distance = (self.sounds and self.sounds.distance) or 10
	}, true)
end

-- set attack

function mob_class:do_attack(player, force)

	if self.state == "attack" and not force then return end

	self.attack = player ; self.state = "attack"

	if random(100) < 90 then self:mob_sound(self.sounds.war_cry) end
end

-- calculate distance

local function get_distance(a, b)

	if not a or not b then return 50 end -- nil check and default distance

	local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z

	return square(x * x + y * y + z * z)
end

-- are we a real player?

local function is_player(player)

	if player and type(player) == "userdata" and core.is_player(player) then
		return true
	end
end

-- collision function based on jordan4ibanez' open_ai mod

function mob_class:collision()

	local pos = self.object:get_pos() ; if not pos then return 0, 0 end
	local x, z = 0, 0
	local prop = self.object:get_properties()
	local width = -prop.collisionbox[1] + prop.collisionbox[4] + 0.5

	for _,object in pairs(core.get_objects_inside_radius(pos, width)) do

		if object:is_player() then

			local pos2 = object:get_pos()
			local vx, vz  = pos.x - pos2.x, pos.z - pos2.z
			local force = width - (vx * vx + vz * vz) ^ 0.5

			if force > 0 then
				force = force * 2 ; x = x + vx * force ; z = z + vz * force
			end
		end
	end

	return x, z
end

-- check for string inside table or string

local function check_for(look_for, look_inside)

	if look_inside == look_for then return true

	elseif type(look_inside) == "table" then

		for _, str in pairs(look_inside) do

			if str == look_for then return true end

			if str and str:find("group:") then

				local group = str:split(":")[2] or ""

				if core.get_item_group(look_for, group) ~= 0 then return true end
			end
		end
	end
end

-- move mob in facing direction

function mob_class:set_velocity(v)

	v = v or 0.01

	-- halt mob if ordered to stay
	if self.order == "stand" then

		local vel = self.object:get_velocity() or {y = 0}

		self.object:set_velocity({x = 0, y = vel.y, z = 0})

		return
	end

	local c_x, c_y = 0, 0

	-- calculate direction if mob can be pushed
	if self.pushable then c_x, c_y = self:collision() end

	local yaw = (self.object:get_yaw() or 0) + self.rotate

	-- is mob standing in liquid?
	local visc = min(core.registered_nodes[self.standing_in].liquid_viscosity, 7)

	-- only slow moving mobs when inside a viscous fluid they cannot swim in
	-- e.g. fish in water, spiders in cobweb
	if v > 0 and visc and visc > 0 and not check_for(self.standing_in, self.fly_in) then
		v = v / (visc + 1)
	end

	local vel = self.object:get_velocity() or {y = 0}

	self.object:set_velocity({
			x = (sin(yaw) * -v) + c_x, y = vel.y, z = (cos(yaw) * v) + c_y})
end

-- return velocity

function mob_class:get_velocity()

	local v = self.object:get_velocity() ; if not v then return 0 end

	return (v.x * v.x + v.z * v.z) ^ 0.5
end

-- set and return valid yaw

function mob_class:set_yaw(yaw, delay)

	if not yaw or yaw ~= yaw then yaw = 0 end

	delay = mob_smooth_rotate and delay or 0

	-- simplified yaw clamp
	if yaw > 6.283185 then	yaw = yaw - 6.283185
	elseif yaw < 0 then		yaw = 6.283185 + yaw
	end

	if delay == 0 then self.object:set_yaw(yaw) ; return yaw ; end

	self.target_yaw = yaw
	self.delay = delay

	return self.target_yaw
end

-- set defined animation

function mob_class:set_animation(anim, force)

	if not self.animation or not anim then return end

	self.animation.current = self.animation.current or ""

	-- only use different animation for attacks when using same set
	if force ~= true and anim ~= "punch" and anim ~= "shoot"
	and string.find(self.animation.current, anim) then return end

	local num = 0

	-- check for more than one animation (max 4)
	for n = 1, 4 do

		if self.animation[anim .. n .. "_start"]
		and self.animation[anim .. n .. "_end"] then num = n end
	end

	-- choose random animation from set
	if num > 0 then
		num = random(0, num)
		anim = anim .. (num ~= 0 and num or "")
	end

	if (anim == self.animation.current and force ~= true)
	or not self.animation[anim .. "_start"]
	or not self.animation[anim .. "_end"] then return end

	self.animation.current = anim

	self.object:set_animation({
		x = self.animation[anim .. "_start"],
		y = self.animation[anim .. "_end"]},
		self.animation[anim .. "_speed"] or self.animation.speed_normal or 15,
		0, self.animation[anim .. "_loop"] ~= false)
end

-- check line of sight using raycasting (thx Astrobe)

function mob_class:line_of_sight(pos1, pos2)

	local ray = core.raycast(pos1, pos2, true, false) -- ignore entities
	local thing = ray:next()
	local name, nodedef

	while thing do

		if thing.type == "node" then

			name = core.get_node(thing.under).name
			nodedef = core.registered_items[name]

			if nodedef and nodedef.walkable then return false end
		end

		thing = ray:next()
	end

	return true
end

-- if not flying in set medium, find some nearby to move to

function mob_class:attempt_flight_correction(override)

	if self:flight_check() and override ~= true then return true end

	local pos = self.object:get_pos() ; if not pos then return true end
	local flyable_nodes = core.find_nodes_in_area(
			{x = pos.x - 1, y = pos.y - 1, z = pos.z - 1},
			{x = pos.x + 1, y = pos.y + 1, z = pos.z + 1}, self.fly_in)

	if #flyable_nodes == 0 then return false end

	local escape_target = flyable_nodes[random(#flyable_nodes)]

	-- stop swimming mobs moving above water surface
	if escape_target.y > pos.y and #core.find_nodes_in_area(
		{x = escape_target.x, y = escape_target.y + 1, z = escape_target.z},
		{x = escape_target.x, y = escape_target.y + 1, z = escape_target.z},
		self.fly_in) == 0 then
		escape_target.y = pos.y
	end

	local escape_direction = vdirection(pos, escape_target)

	self.object:set_velocity(vmultiply(escape_direction, 1))

	return true
end

-- are we flying in what we are suppose to? (taikedz)

function mob_class:flight_check()

	local def = core.registered_nodes[self.standing_in]

	if not def then return false end

	-- are we standing inside what we should be to fly/swim ?
	if check_for(self.standing_in, self.fly_in) then return true end

	-- stops mobs getting stuck inside stairs or plantlike nodes
	if def.drawtype ~= "airlike" and def.drawtype ~= "liquid"
	and def.drawtype ~= "flowingliquid" then
		return true
	end
end

-- turn to face position

function mob_class:yaw_to_pos(target, rot)

	rot = rot or 0

	local pos = self.object:get_pos()
	local vec = {x = target.x - pos.x, z = target.z - pos.z}
	local yaw = (atan(vec.z / vec.x) + rot + pi / 2) - self.rotate

	if target.x > pos.x then yaw = yaw + pi end

	return self:set_yaw(yaw, rot)
end

-- look for stay_near nodes and move towards them

function mob_class:do_stay_near()

	if not self.stay_near then return false end

	local pos = self.object:get_pos()
	local chance = self.stay_near[2] or 10

	if not pos or random(chance) > 1 then return false end

	local r = self.view_range
	local nearby_nodes = core.find_nodes_in_area(
			{x = pos.x - r, y = pos.y - 1, z = pos.z - r},
			{x = pos.x + r, y = pos.y + 1, z = pos.z + r}, self.stay_near[1])

	if #nearby_nodes == 0 then return false end

	self:yaw_to_pos(nearby_nodes[random(#nearby_nodes)])
	self:set_animation("walk")
	self:set_velocity(self.walk_velocity)

	return true
end

-- particle effects

local function effect(pos, amount, texture, min_size, max_size, radius, grav, glow, fall)

	radius = radius or 2
	grav = grav or -10
	fall = fall == true and 0 or fall == false and radius or -radius

	core.add_particlespawner({
		amount = amount,
		time = 0.25,
		minpos = pos, maxpos = pos,
		minvel = {x = -radius, y = fall, z = -radius},
		maxvel = {x = radius, y = radius, z = radius},
		minacc = {x = 0, y = grav, z = 0},
		maxacc = {x = 0, y = grav, z = 0},
		minexptime = 0.1, maxexptime = 1,
		minsize = min_size or 0.5, maxsize = max_size or 1,
		texture = texture,
		glow = glow or 0
	})
end

function mobs:effect(pos, amount, texture, min_size, max_size, radius, grav, glow, fall)
	effect(pos, amount, texture, min_size, max_size, radius, grav, glow, fall)
end

-- update infotext

function mob_class:update_tag(newname)
	local prop = self.object:get_properties()

	self.infotext = self.health .. " ❤︎"

	-- apply infotext changes
	if mob_infotext and self.infotext ~= prop.infotext then
		self.object:set_properties({infotext = self.infotext})
	end
end

-- remove mob and descrease counter

local function remove_mob(self, decrease)

	self.object:remove()

	if decrease and active_limit and active_limit > 1 then
		active_mobs = active_mobs - 1
--print("-- active mobs: " .. active_mobs .. " / " .. active_limit)
	end
end

function mobs:remove(self, decrease)
	remove_mob(self, decrease)
end

-- check if dead

function mob_class:check_for_death(cmi_cause)

	if self.state == "die" then return true end -- already dead

	-- has health changed?
	if self.health == self.old_health and self.health > 0 then return false end

	local damaged = self.health < self.old_health
	local prop = self.object:get_properties()

	self.old_health = self.health

	if use_vh1 then VH1.update_bar(self.object, self.health) end

	if self.health > 0 then

		-- play hurt sound if damaged
		if damaged then self:mob_sound(self.sounds.damage) end

		-- make sure health isn't higher than max
		if self.health > prop.hp_max then self.health = prop.hp_max end

		self:update_tag() ; return false
	end

	self.cause_of_death = cmi_cause
	self:mob_sound(self.sounds.death) -- play death sound

	local pos = self.object:get_pos()

	-- execute official engine on_death function if found
	if self.on_death then

		-- only return killer if punched by player
		if cmi_cause.type == "punch" and is_player(cmi_cause.puncher) then
			cmi_cause = cmi_cause.puncher
		else
			cmi_cause = nil
		end

		self:on_death(cmi_cause)

		remove_mob(self, true) ; return true
	end

	-- execute mob api custom death function
	if pos and self.on_die then

		self:on_die(pos)

		if use_cmi then cmi.notify_die(self.object, cmi_cause) end

		remove_mob(self, true) ; return true
	end

	-- reset vars
	self.attack = nil
	self.following = nil
	self.v_start = false ; self.timer = 0 ; self.blinktimer = 0
	self.passive = true
	self.state = "die"
	self.fly = false

	-- check for die animation
	if self.animation and self.animation.die_start and self.animation.die_end then

		local frames = self.animation.die_end - self.animation.die_start
		local speed = self.animation.die_speed or 15
		local length = max((frames / speed), 0)
		local rot = self.animation.die_rotate and 5

		self.object:set_properties({
			pointable = false, collide_with_objects = false,
			automatic_rotate = rot, static_save = false
		})

		self:set_velocity(0)
		self:set_animation("die")

		core.after(length, function(self)

			if self.object:get_luaentity() then

				if use_cmi then cmi.notify_die(self.object, cmi_cause) end

				remove_mob(self, true)
			end
		end, self)

		return true

	elseif pos then -- otherwise remove mob and show particle effect

		if use_cmi then cmi.notify_die(self.object, cmi_cause) end

		remove_mob(self, true)

		effect(pos, 20, "mobs_tnt_smoke.png")
	end

	return true
end

-- get node, use fallback for nil or unknown

local function node_ok(pos, fallback)

	local node = core.get_node_or_nil(pos)

	if node and core.registered_nodes[node.name] then return node end

	return core.registered_nodes[(fallback or mobs.fallback_node)]
end

function mobs:node_ok(pos, fallback)
	return node_ok(pos, fallback)
end

-- return true if node can deal damage

local function is_node_dangerous(self, nodename)

	local def = core.registered_nodes[nodename]

	if (self.water_damage and self.water_damage > 0 and def.groups.water)
	or (self.lava_damage and self.lava_damage > 0 and def.groups.lava)
	or (self.fire_damage and self.fire_damage > 0 and def.groups.fire) then return true end

	if self.node_damage and def.damage_per_second > 0 then

		local damage = def.damage_per_second

		for n = 1, #self.immune_to do

			if self.immune_to[n][1] == nodename then
				damage = self.immune_to[n][2] or 0 ; break
			end
		end

		if damage > 0 then return true end
	end
end

function mobs:is_node_dangerous(mob_object, nodename)
	return is_node_dangerous(mob_object, nodename)
end

-- are we facing a cliff?

function mob_class:is_at_cliff()

	if self.driver or self.fear_height == 0 then -- 0 for no fear of heights
		return false
	end

	local yaw = self.object:get_yaw() ; if not yaw then return false end
	local prop = self.object:get_properties()
	local dir_x = -sin(yaw) * (prop.collisionbox[4] + 0.5)
	local dir_z = cos(yaw) * (prop.collisionbox[4] + 0.5)
	local pos = self.object:get_pos()
	local ypos = pos.y + prop.collisionbox[2] -- just above floor

	local free_fall, blocker = core.line_of_sight(
			{x = pos.x + dir_x, y = ypos, z = pos.z + dir_z},
			{x = pos.x + dir_x, y = ypos - self.fear_height, z = pos.z + dir_z})

	if free_fall then return true end -- check for straight drop

	local bnode = node_ok(blocker, "air")

	-- will we drop onto dangerous node?
	if is_node_dangerous(self, bnode.name) then return true end

	local def = core.registered_nodes[bnode.name]

	return (not def and def.walkable)
end

-- check for nodes or groups inside mob collision area

function mob_class:is_inside(itemtable)

	local cb = self.object:get_properties().collisionbox
	local pos = self.object:get_pos()
	local nn = core.find_nodes_in_area(
			vector.offset(pos, cb[1], cb[2], cb[3]),
			vector.offset(pos, cb[4], cb[5], cb[6]), itemtable)

	if nn and #nn > 0 then return true end
end

-- environmental damage

function mob_class:do_env_damage()

	local pos = self.object:get_pos() ; if not pos then return end

	self:update_tag()

	self.time_of_day = core.get_timeofday()

	-- halt mob when standing in ignore node
	if self.standing_in == "ignore" then
		self.object:set_velocity({x = 0, y = 0, z = 0}) ; return true
	end

	local prop = self.object:get_properties()
	local py = {x = pos.x, y = pos.y + prop.collisionbox[5], z = pos.z}
	local nodef = core.registered_nodes[self.standing_in]

	-- water damage
	if self.water_damage ~= 0 and nodef.groups.water then

		self.health = self.health - self.water_damage

		effect(py, 5, "mobs_bubble_particle.png", nil, nil, 1, nil)

		if self:check_for_death({type = "environment",
				pos = pos, node = self.standing_in}) then return true end
	end

	-- lava damage
	if self.lava_damage ~= 0 and nodef.groups.lava then

		self.health = self.health - self.lava_damage

		effect(py, 15, "mobs_fire_particle.png", 1, 5, 1, 0.2, 15, true)

		if self:check_for_death({type = "environment", pos = pos,
				node = self.standing_in, hot = true}) then return true end
	end

	-- fire damage
	if self.fire_damage ~= 0 and nodef.groups.fire then

		self.health = self.health - self.fire_damage

		effect(py, 15, "mobs_fire_particle.png", 1, 5, 1, 0.2, 15, true)

		if self:check_for_death({type = "environment", pos = pos,
				node = self.standing_in, hot = true}) then return true end
	end

	-- damage_per_second node check
	if self.node_damage and nodef.damage_per_second and nodef.damage_per_second ~= 0
	and nodef.groups.lava == nil and nodef.groups.fire == nil then

		local damage = nodef.damage_per_second

		-- check for node immunity or special damage
		for n = 1, #self.immune_to do

			if self.immune_to[n][1] == self.standing_in then
				damage = self.immune_to[n][2] or 0 ; break
			end
		end

		self.health = self.health - damage

		if damage > 0 then effect(py, 5, "mobs_tnt_smoke.png") end

		if self:check_for_death({type = "environment",
				pos = pos, node = self.standing_in}) then return true end
	end

	-- air damage
	if self.air_damage ~= 0 and self.standing_in == "air" then

		self.health = self.health - self.air_damage

		effect(py, 3, "mobs_bubble_particle.png", 1, 1, 1, 0.2)

		if self:check_for_death({type = "environment",
				pos = pos, node = self.standing_in}) then return true end
	end

	-- is mob light sensitive, or scared of the dark :P
	if self.light_damage ~= 0 then

		local light

		-- if max set to 16 then only natural sunlight can kill mob
		if self.light_damage_max == 16 then
			light = core.get_natural_light(pos) or 0
		else
			light = core.get_node_light(pos) or 0
		end

		if light >= self.light_damage_min and light <= self.light_damage_max then

			self.health = self.health - self.light_damage

			effect(py, 5, "mobs_tnt_smoke.png")

			if self:check_for_death({type = "light"}) then return true end
		end
	end

	--- suffocation
	if (self.suffocation and self.suffocation ~= 0)
	and (nodef.walkable == nil or nodef.walkable)
	and (nodef.collision_box == nil or nodef.collision_box.type == "regular")
	and (nodef.node_box == nil or nodef.node_box.type == "regular")
	and (nodef.groups.disable_suffocation ~= 1) then

		local damage

		if type(self.suffocation) == "boolean" and self.suffocation then
			damage = 2
		else
			damage = self.suffocation
		end

		self.health = self.health - damage

		if self:check_for_death({type = "suffocation",
				pos = pos, node = self.standing_in}) then return true end

		-- try to jump out of block
		self.object:set_velocity({x = 0, y = self.jump_height, z = 0})
	end

	return self:check_for_death({type = "unknown"})
end

-- jumping

function mob_class:do_jump()

	local vel = self.object:get_velocity() ; if not vel then return false end

	-- don't jump if ordered to stand, are already in mid-air, can fly or are a child
	if self.state == "stand" or self.order == "stand" or vel.y ~= 0
	or self.fly or self.child then return false end

	-- only jump if standing on solid node that allows it
	local ndef = core.registered_nodes[self.standing_on]

	if ndef.walkable == false or (ndef.groups and ndef.groups.disable_jump == 1) then
		return false
	end

	-- is there anything stopping us from jumping up onto a block?
	local blocked = core.registered_nodes[self.looking_above].walkable

	-- if mob can leap then remove blockages and let them try
	if self.can_leap then blocked = false ; self.facing_fence = false end

	-- what node are we looking at?
	ndef = core.registered_nodes[self.looking_at]

	-- jump if possible
	if self.jump_height > 0
	and (self.walk_chance == 0 or (ndef.walkable and ndef.drawtype == "normal"))
	and not blocked	and not self.facing_fence then

		vel.y = self.jump_height

		self:set_animation("jump")

		self.object:set_velocity(vel)

		core.after(0.3, function(self, vel) -- move forward when in air

			if self.object:get_luaentity() then

				self.object:set_acceleration({x = vel.x * 2, y = 0, z = vel.z * 2})
			end
		end, self, vel)

		if self:get_velocity() > 0 then
			self:mob_sound(self.sounds.jump)
		end

		self.jump_count = 0 ; return true
	end

	-- if blocked for 3 jump counts, turn
	if not self.following and (self.facing_fence or blocked) then

		self.jump_count = (self.jump_count or 0) + 1

		if self.jump_count > 2 then

			local yaw = self.object:get_yaw() or 0
			local turn = random(0, 2) + 1.35

			self:set_yaw(yaw + turn, 12)

			self.jump_count = 0
		end
	end
end

-- blast damage to nearby entities

local function entity_physics(pos, radius)

	radius = radius * 2

	local objs = core.get_objects_inside_radius(pos, radius)
	local obj_pos, dist

	for n = 1, #objs do

		obj_pos = objs[n]:get_pos()

		dist = max(1, get_distance(pos, obj_pos))

		local damage = floor((4 / dist) * radius)

		objs[n]:punch(objs[n], 1.0,
				{full_punch_interval = 1.0, damage_groups = {fleshy = damage}}, pos)
	end
end

-- can mob see player

local function is_invisible(self, player_name)

	if use_invisibility and not self.ignore_invisibility
	and invisibility.is_visible and not invisibility.is_visible(player_name) then
		return true
	end
end

function mobs:is_invisible(self, player_name)
	return is_invisible(self, player_name)
end

-- are we docile during daylight hours?

function mob_class:day_docile()

	if self.docile_by_day
	and self.time_of_day > 0.2 and self.time_of_day < 0.8 then return true end
end

-- pathfinder mod check and settings

local pathfinder_mod = core.get_modpath("pathfinder")
local los_switcher = false
local height_switcher = false

-- path finding and smart mob routine by rnd, line_of_sight and other edits by Elkien3

function mob_class:smart_mobs(s, p, dist, dtime)

	local s1 = self.path.lastpos
	local target_pos = p

	-- are we stuck?
	if abs(s1.x - s.x) + abs(s1.z - s.z) < .5 then
		self.path.stuck_timer = self.path.stuck_timer + dtime
	else
		self.path.stuck_timer = 0
	end

	self.path.lastpos = {x = s.x, y = s.y, z = s.z}

	local use_pathfind = false
	local has_lineofsight = core.line_of_sight(
		{x = s.x, y = (s.y) + .5, z = s.z},
		{x = target_pos.x, y = (target_pos.y) + 1.5, z = target_pos.z}, .2)

	-- im stuck, search for path
	if not has_lineofsight then

		if los_switcher then
			use_pathfind = true ; los_switcher = false
		end -- cannot see target!
	else
		if not los_switcher then

			los_switcher = true ; use_pathfind = false

			core.after(1, function(self)

				if not self.object:get_luaentity() then return end

				if has_lineofsight then self.path.following = false end
			end, self)
		end -- can see target!
	end

	if self.path.stuck_timer > pathfinding_stuck_timeout and not self.path.following then

		use_pathfind = true
		self.path.stuck_timer = 0

		core.after(1, function(self)

			if not self.object:get_luaentity() then return end

			if has_lineofsight then self.path.following = false end
		end, self)
	end

	if self.path.stuck_timer > pathfinding_stuck_path_timeout and self.path.following then

		use_pathfind = true
		self.path.stuck_timer = 0

		core.after(1, function(self)

			if not self.object:get_luaentity() then return end

			if has_lineofsight then self.path.following = false end
		end, self)
	end

	local prop = self.object:get_properties()

	if abs(s.y - target_pos.y) > prop.stepheight then

		if height_switcher then use_pathfind = true ; height_switcher = false end
	else
		if not height_switcher then use_pathfind = false ; height_switcher = true end
	end

	-- try to find a path
	if use_pathfind then

		-- round position to avoid getting stuck in walls
		s.x = floor(s.x + 0.5) ; s.z = floor(s.z + 0.5)

		local ssight, sground = core.line_of_sight(s,
				{x = s.x, y = s.y - 4, z = s.z}, 1)

		-- determine node above ground (adjust height for player models)
		if not ssight then s.y = sground.y + 1 end

		local p1 = self.attack and self.attack:get_pos()

		if not p1 then return end

		p1.x = floor(p1.x + 0.5) ; p1.y = floor(p1.y + 0.5) ; p1.z = floor(p1.z + 0.5)

		local dropheight = pathfinding_max_drop

		if self.fear_height ~= 0 then dropheight = self.fear_height end

		local jumpheight = 0

		if self.jump_height >= pathfinding_max_jump then

			jumpheight = min(ceil(
					self.jump_height / pathfinding_max_jump), pathfinding_max_jump)

		elseif prop.stepheight > 0.5 then jumpheight = 1 end

		if pathfinder_mod then
			self.path.way = pathfinder.find_path(s, p1, self, dtime)
		else
			self.path.way = core.find_path(s, p1, pathfinding_searchdistance,
					jumpheight, dropheight, pathfinding_algorithm)
		end
		--[[
		-- show path using particles
		if self.path.way and #self.path.way > 0 then

			print("-- path length:" .. tonumber(#self.path.way))

			for _,pos in pairs(self.path.way) do

				core.add_particle({
					pos = pos,
					velocity = {x = 0, y = 0, z = 0},
					acceleration = {x = 0, y = 0, z = 0},
					expirationtime = 1,
					size = 4,
					collisiondetection = false,
					vertical = false,
					texture = "mobs_heart_particle.png",
				})
			end
		end
		]]

		self.state = ""

		if self.attack then self:do_attack(self.attack) end

		-- no path found
		if not self.path.way then
			self.path.following = false

			-- will try again in 2 second
			self.path.stuck_timer = pathfinding_stuck_timeout - 2

		elseif s.y < p1.y and (not self.fly) then
			self:do_jump() --add jump to pathfinding
			self.path.following = true
		else
			-- yay i found path
			if self.attack then
				self:mob_sound(self.sounds.war_cry)
			else
				self:mob_sound(self.sounds.random)
			end

			self:set_velocity(self.walk_velocity)

			-- now follow path
			self.path.following = true
		end
	end
end

-- temporary entity for go_to() function

core.register_entity("mobs:_pos", {
	initial_properties = {
		visual = "sprite", texture = "", hp_max = 1, physical = false,
		static_save = false, pointable = false, is_visible = false
	}, health = 1, _cmi_is_mob = true,

	on_step = function(self, dtime)

		self.counter = (self.counter or 0) + dtime

		if self.counter > 20 then self.object:remove() end
	end
})

-- add temp entity and make mob go to that entity position

function mob_class:go_to(pos)

	local obj = core.add_entity(pos, "mobs:_pos")

	if obj and obj:get_luaentity() then self:do_attack(obj, true) end
end

-- general attack function

function mob_class:general_attack()

	-- return if already attacking, passive or docile during day
	if self.passive or self.state == "runaway" or self.state == "attack"
	or self:day_docile() then
		return
	end

	local s = self.object:get_pos() ; if not s then return end
	local objs = core.get_objects_inside_radius(s, self.view_range)

	-- remove entities we aren't interested in
	for n = 1, #objs do

		local ent = objs[n]:get_luaentity()

		if is_player(objs[n]) then -- are we a player?

			-- remove from list if invisible or unable to attack
			if not damage_enabled or self.attack_players == false
			or self.owner == objs[n]:get_player_name()
			-- npcs and animals that are tamed will not attack players unless provoked
			or (self.type ~= "monster" and self.tamed)
			or is_invisible(self, objs[n]:get_player_name())
			or (self.specific_attack and not check_for("player", self.specific_attack)) then
				objs[n] = nil
--print("- pla", n)
			end

		-- are we a creatura mob?
		elseif creatura and ent and ent._cmi_is_mob ~= true
		and ent.hitbox and ent.stand_node then

		-- monsters attack all creatura mobs, npc and animals will only attack
		-- if the animal owner is currently being attacked by creatura mob
		if self.name == ent.name
		or (self.type ~= "monster"
			and self.owner ~= (ent._target and ent._target:get_player_name() or "."))
		or (self.specific_attack and not check_for(ent.name, self.specific_attack)) then

			objs[n] = nil
--print("-- creatura", ent.name)
		end

		-- or are we a mob?
		elseif ent and ent._cmi_is_mob then

			-- remove mobs to not attack
			if self.name == ent.name
			or check_for(ent.name, self.attack_ignore)
			or (not self.attack_animals and ent.type == "animal")
			or (not self.attack_monsters and ent.type == "monster")
			or (not self.attack_npcs and ent.type == "npc")
			or (self.specific_attack and not check_for(ent.name, self.specific_attack)) then
				objs[n] = nil
--print("- mob", n, self.name, ent.name)
			end

		-- remove all other entities
		else
--print(" -obj", n)
			objs[n] = nil
		end
	end

	local p, sp, dist, min_player
	local min_dist = self.view_range + 1

	-- go through remaining entities and select closest
	for _,player in pairs(objs) do

		p = player:get_pos() ; sp = s

		dist = get_distance(p, s)

		-- aim higher to make looking up hills more realistic
		p.y = p.y + 1 ; sp.y = sp.y + 1

		-- choose closest player to attack
		if dist ~= 0 and dist < min_dist
		and self:line_of_sight(sp, p) then
			min_dist = dist
			min_player = player
		end
	end

	if min_player and random(100) > self.attack_chance then -- attack!
		self:do_attack(min_player)
	end
end

-- find someone to runaway from

function mob_class:do_runaway_from()

	if not self.runaway_from then return end

	local s = self.object:get_pos() ; if not s then return end
	local p, sp, dist, pname, player, obj, min_player, name
	local min_dist = self.view_range + 1
	local objs = core.get_objects_inside_radius(s, self.view_range)

	for n = 1, #objs do -- loop through entities surrounding mob

		if is_player(objs[n]) then

			pname = objs[n]:get_player_name()

			if is_invisible(self, pname) or self.owner == pname then
				name = ""
			else
				player = objs[n] ; name = "player"
			end
		else
			obj = objs[n]:get_luaentity()

			if obj then
				player = obj.object ; name = obj.name or ""
			end
		end

		-- find specific mob to runaway from
		if name ~= "" and name ~= self.name
		and (self.runaway_from and check_for(name, self.runaway_from)) then

			sp = s
			p = player and player:get_pos() or s

			-- aim higher to make looking up hills more realistic
			p.y = p.y + 1 ; sp.y = sp.y + 1

			dist = get_distance(p, s)

			-- choose closest entity to runaway from
			if dist < min_dist and self:line_of_sight(sp, p) then
				min_dist = dist
				min_player = player
			end
		end
	end

	if min_player then

		self:yaw_to_pos(min_player:get_pos(), 3)

		self.state = "runaway"
		self.runaway_timer = 3
		self.following = nil

		return
	end

	-- check for nodes to runaway from
	objs = core.find_node_near(s, self.view_range, self.runaway_from, true)

	if objs then

		self:yaw_to_pos(objs, 3)
		self.state = "runaway"
		self.runaway_timer = 3
		self.following = nil
	end
end

-- follow player if owner or holding item, if fish outta water then flop

function mob_class:follow_flop()

	-- find player to follow
	if (self.follow ~= "" or self.order == "follow") and not self.following
	and self.state ~= "attack" and self.state ~= "runaway" then

		local s = self.object:get_pos() ; if not s then return end
		local players = core.get_connected_players()

		for n = 1, #players do

			if players[n] and not is_invisible(self, players[n]:get_player_name())
			and get_distance(players[n]:get_pos(), s) < self.view_range then

				self.following = players[n] ; break
			end
		end
	end

	if self.type == "npc" and self.order == "follow"
	and self.state ~= "attack" and self.owner ~= "" then

		-- npc stop following player if not owner
		if self.following
		and self.owner and self.owner ~= self.following:get_player_name() then
			self.following = nil
		end
	end

	if self.following then -- follow that thing

		local s = self.object:get_pos()
		local p

		if is_player(self.following) then p = self.following:get_pos()
		elseif self.following.object then p = self.following.object:get_pos() end

		if p then

			local dist = get_distance(p, s)

			-- dont follow if out of range
			if dist > self.view_range then self.following = nil
			else
				self:yaw_to_pos(p)

				-- anyone but standing npc's can move along
				if dist >= self.reach and self.order ~= "stand" then

					self:set_velocity(self.walk_velocity)

					if self.walk_chance ~= 0 then self:set_animation("walk") end
				else
					self:set_velocity(0)
					self:set_animation("stand")
				end

				return
			end
		end
	end

	-- swimmers flop when out of their element, and swim again when back in
	if self.fly then

		if not self:attempt_flight_correction() then

			self.state = "flop"

			-- do we have a custom on_flop function?
			if self.on_flop and self:on_flop(self) then return end

			self.object:set_velocity({x = 0, y = -5, z = 0})

			self:set_animation("stand")

			return

		elseif self.state == "flop" then self.state = "stand" end
	end
end

-- dogshoot attack switch & counter function

function mob_class:dogswitch(dtime)

	if not self.dogshoot_switch or not dtime then return 0 end -- not activated

	self.dogshoot_count = self.dogshoot_count + dtime

	if (self.dogshoot_switch == 1 and self.dogshoot_count > self.dogshoot_count_max)
	or (self.dogshoot_switch == 2 and self.dogshoot_count > self.dogshoot_count2_max) then

		self.dogshoot_count = 0

		if self.dogshoot_switch == 1 then
			self.dogshoot_switch = 2
		else
			self.dogshoot_switch = 1
		end
	end

	return self.dogshoot_switch
end

-- stop attack & reset vars

function mob_class:stop_attack()

	self.attack = nil
	self.following = nil
	self.v_start = false ; self.timer = 0 ; self.blinktimer = 0
	self.path.way = nil
	self:set_velocity(0)
	self.state = "stand"
	self:set_animation("stand", true)
end

-- execute current state (stand, walk, run, attack)

function mob_class:do_states(dtime)

	local yaw = self.object:get_yaw() ; if not yaw then return end

	-- are we standing in something that hurts?  Try to get out
	if is_node_dangerous(self, self.standing_in) then

		local s = self.object:get_pos()

		local lp = core.find_nodes_in_area_under_air(
				{x = s.x - 7, y = s.y - 1.0, z = s.z - 7},
				{x = s.x + 7, y = s.y + 1.0, z = s.z + 7},
				{"group:cracky", "group:crumbly", "group:choppy", "group:solid"})

		if #lp > 0 then -- if we found land try to climb out

			yaw = self:yaw_to_pos( lp[random(#lp)] )
		
			self.pause_timer = 3
			self.following = nil
			self:set_velocity(self.run_velocity)
			self:set_animation("walk")

			return
		end
	end

	if self.state == "stand" then

		if self.randomly_turn and random(4) == 1 then

			local lp
			local s = self.object:get_pos()

			for _,player in pairs(core.get_connected_players()) do

				local player_pos = player:get_pos()

				if get_distance(player_pos, s) <= 3 then
					lp = player_pos ; break
				end
			end

			if lp then -- lok at any players nearby, otherwise turn randomly
				yaw = self:yaw_to_pos(lp)
			else
				yaw = yaw + random() - 0.5
			end

			self:set_yaw(yaw, 8)
		end

		self:set_velocity(0)
		self:set_animation("stand")

		-- mobs ordered to stand stay standing
		if self.order ~= "stand" and self.walk_chance ~= 0
		and self.facing_fence ~= true
		and self.at_cliff == false
		and random(100) <= self.walk_chance then

			self:set_velocity(self.walk_velocity)
			self.state = "walk"
			self:set_animation("walk")
		end

	elseif self.state == "walk" then

		if self.randomly_turn and random(100) <= 30 then

			yaw = yaw + random() - 0.5

			self:set_yaw(yaw, 8)

			-- for flying/swimming mobs randomly move up and down also
			if self.fly_in and not self.following then
				self:attempt_flight_correction(true)
			end
		end

		-- stand depending on situation
		if self.facing_fence or self.at_cliff or random(100) <= self.stand_chance then

			-- don't stand if mob flies and keep_flying set
			if (self.fly and not self.keep_flying) or not self.fly then

				self:set_velocity(0)
				self.state = "stand"
				self:set_animation("stand", true)
			end
		else
			self:set_velocity(self.walk_velocity)

			-- figure out which animation to use while in motion
			if self:flight_check() and self.animation
			and self.animation.fly_start and self.animation.fly_end then

				local on_ground = core.registered_nodes[self.standing_on].walkable
				local in_water = core.registered_nodes[self.standing_in].groups.water

				if on_ground and in_water then
					self:set_animation("fly")
				elseif on_ground then
					self:set_animation("walk")
				else
					self:set_animation("fly")
				end
			else
				self:set_animation("walk")
			end
		end

	elseif self.state == "runaway" then

		self.runaway_timer = self.runaway_timer - 1

		-- stand when timer runs out, or at cliff
		if self.runaway_timer <= 0 or self.at_cliff or self.order == "stand" then

			self:set_velocity(0)
			self.state = "stand"
			self:set_animation("stand")

			yaw = yaw + random(-1, 1) * 1.5 -- try to turn so we are not stuck
			yaw = self:set_yaw(yaw, 4)
		else
			self:set_velocity(self.run_velocity)
			self:set_animation("walk")
		end

	-- attack routines (explode, dogfight, shoot, dogshoot)
	elseif self.state == "attack" then

		-- get mob and enemy positions and distance between
		local s = self.object:get_pos()
		local p = self.attack and self.attack:get_pos()
		local dist = p and get_distance(p, s) or 500

		-- stop attacking if player out of range or invisible
		if dist > self.view_range
		or not self.attack or not self.attack:get_pos() or self.attack:get_hp() <= 0
		or (is_player(self.attack)
		and is_invisible(self, self.attack:get_player_name())) then

--print(" ** stop attacking **", self.name, self.health, dist, self.view_range)

			self:stop_attack() ; return
		end

		-- check enemy is in sight
		local in_sight = self:line_of_sight(
				{x = s.x, y = s.y + 0.5, z = s.z}, {x = p.x, y = p.y + 0.5, z = p.z})

		-- stop attacking when enemy not seen for 11 seconds
		if not in_sight then

			self.target_time_lost = (self.target_time_lost or 0) + dtime

			if self.target_time_lost > self.attack_patience then self:stop_attack() end
		else
			self.target_time_lost = 0
		end

		if self.attack_type == "explode" then

			self:yaw_to_pos(p)

			local node_break_radius = self.explosion_radius or 1
			local entity_damage_radius = self.explosion_damage_radius
					or (node_break_radius * 2)

			-- look a little higher to fix raycast
			s.y = s.y + 0.5 ; p.y = p.y + 0.5

			-- start timer when in reach and line of sight
			if not self.v_start and dist <= self.reach and in_sight then

				self.v_start = true
				self.timer = 0
				self.blinktimer = 0
				self:mob_sound(self.sounds.fuse)

--print("=== explosion timer started", self.explosion_timer)

			-- stop timer if out of reach or direct line of sight
			elseif self.allow_fuse_reset and self.v_start
			and (dist > self.reach or not in_sight) then

--print("=== explosion timer stopped")

				self.v_start = false
				self.timer = 0
				self.blinktimer = 0
				self.blinkstatus = false
				self.object:set_texture_mod("")
				self.object:set_properties({glow = self.glow})
			end

			-- walk right up to player unless the timer is active
			if self.v_start and (self.stop_to_explode or dist < 1.5) then
				self:set_velocity(0)
			else
				self:set_velocity(self.run_velocity)
			end

			if self.animation and self.animation.run_start then
				self:set_animation("run")
			else
				self:set_animation("walk")
			end

			if self.v_start then

				self.timer = self.timer + dtime
				self.blinktimer = (self.blinktimer or 0) + dtime

				if self.blinktimer > 0.2 then

					self.blinktimer = 0

					if self.blinkstatus then
						self.object:set_texture_mod(self.texture_mods)
						self.object:set_properties({glow = (self.glow or 0)})
					else
						self.object:set_texture_mod(self.texture_mods .. "^[brighten")
						self.object:set_properties({glow = (self.glow or 0) + 3})
					end

					self.blinkstatus = not self.blinkstatus
				end

--print("=== explosion timer", self.timer)

				if self.timer > self.explosion_timer then

					local pos = self.object:get_pos()

					-- dont damage anything if area protected or near water
					if core.find_node_near(pos, 1, {"group:water"})
					or core.is_protected(pos, "") then
						node_break_radius = 1
					end

					remove_mob(self, true)

					mobs:boom(self, pos, node_break_radius, entity_damage_radius)

					return true
				end
			end

		elseif self.attack_type == "dogfight"
		or (self.attack_type == "dogshoot" and self:dogswitch(dtime) == 2)
		or (self.attack_type == "dogshoot" and dist <= self.reach
		and self:dogswitch() == 0) then

			-- make sure flying mobs are inside proper medium
			if self.fly and dist > self.reach and self:flight_check() then

				local s_y, p_y = floor(s.y), floor(p.y + 1) -- self, attacker
				local v = self.object:get_velocity()

				-- fly/swim up towards attacker
				if s_y < p_y then

					-- if correct medium above then move up
					if #core.find_nodes_in_area(
							{x = s.x, y = s.y + 1, z = s.z},
							{x = s.x, y = s.y + 1, z = s.z}, self.fly_in) > 0 then

						self.object:set_velocity({
								x = v.x, y = self.walk_velocity, z = v.z})
					else
						self.object:set_velocity({x = v.x, y = 0, z = v.z}) -- stop
					end

				-- fly/swim down towards attacker
				elseif s_y > p_y then

					-- if correct medium below then move down
					if #core.find_nodes_in_area(
							{x = s.x, y = s.y - 1, z = s.z},
							{x = s.x, y = s.y - 1, z = s.z}, self.fly_in) > 0 then

						self.object:set_velocity({
								x = v.x, y = -self.walk_velocity, z = v.z})
					else
						self.object:set_velocity({x = v.x, y = 0, z = v.z}) -- stop
					end
				end
			end

			-- rnd: new movement direction
			if self.path.following and self.path.way
			and self.attack_type ~= "dogshoot" then

				-- no paths longer than 60
				if #self.path.way > 60 or dist < self.reach then
					self.path.following = false ; return
				end

				local p1 = self.path.way[1]

				if not p1 then
					self.path.following = false ; return
				end

				if abs(p1.x - s.x) + abs(p1.z - s.z) < 0.6 then
					table_remove(self.path.way, 1) -- remove waypoint once reached
				end

				p = {x = p1.x, y = p1.y, z = p1.z} -- set new temp target
			end

			self:yaw_to_pos(p)

			-- move towards enemy if beyond mob reach
			if dist > (self.reach + (self.reach_ext or 0)) then

				-- path finding by rnd (only when enabled in setting and mob)
				if self.pathfinding and pathfinding_enable then
					self:smart_mobs(s, p, dist, dtime)
				end

				-- distance padding to stop mob spinning
				local pad = abs(p.x - s.x) + abs(p.z - s.z)

				self.reach_ext = 0 -- extended ready off by default

				if self.at_cliff or pad < 0.2 then

					-- extend reach slightly when on top of player
					self.reach_ext = 0.8
					self:set_velocity(0)
					self:set_animation("stand")
				else

					if self.path.stuck then
						self:set_velocity(self.walk_velocity)
					else
						self:set_velocity(self.run_velocity)
					end

					if self.animation and self.animation.run_start then
						self:set_animation("run")
					else
						self:set_animation("walk")
					end
				end
			else -- rnd: if inside reach range

				self.path.stuck = false
				self.path.stuck_timer = 0
				self.path.following = false -- not stuck anymore

				self:set_velocity(0)

				if self.timer > 1 then

					self.timer = 0

					-- no custom attack or custom attack returns true to continue
					if not self.custom_attack or self:custom_attack(self, p) then

						self:set_animation("punch")

						local p2, s2 = p, s

						p2.y = p2.y + .5 ; s2.y = s2.y + .5

						if self:line_of_sight(p2, s2) then

							self:mob_sound(self.sounds.attack) -- attack sound

							-- punch player (or what player is attached to)
							local attached = self.attack:get_attach()

							if attached then
								self.attack = attached
							end

							local dgroup = self.damage_group or "fleshy"

							self.attack:punch(self.object, 1.0, {
								full_punch_interval = 1.0,
								damage_groups = {[dgroup] = self.damage}
							}, nil)
						end
					end
				end
			end

		elseif self.attack_type == "shoot"
		or (self.attack_type == "dogshoot" and self:dogswitch(dtime) == 1)
		or (self.attack_type == "dogshoot" and dist > self.reach and
		self:dogswitch() == 0) then

			p.y = p.y - .5 ; s.y = s.y + .5

			local vec = {x = p.x - s.x, y = p.y - s.y, z = p.z - s.z}

			self:yaw_to_pos(p) ; self:set_velocity(0)

			if self.shoot_interval and self.timer > self.shoot_interval
			and random(100) <= 60 then

				self.timer = 0
				self:set_animation("shoot")
				self:mob_sound(self.sounds.shoot_attack) -- attack sound

				local p = self.object:get_pos()
				local prop = self.object:get_properties()

				p.y = p.y + (prop.collisionbox[2] + prop.collisionbox[5]) / 2

				if core.registered_entities[self.arrow] then

					local obj = core.add_entity(p, self.arrow)
					local ent = obj:get_luaentity()
					local amount = (vec.x * vec.x + vec.y * vec.y + vec.z * vec.z) ^ 0.5

					-- check for arrow custom override
					if self.arrow_override then self.arrow_override(ent) end

					local v = ent.velocity or 1 -- or set to default

					if self.homing then -- setup homing arrow and target
						ent._homing_target = self.attack
					end

					 -- offset makes shoot aim accurate
					vec.y = vec.y + self.shoot_offset
					vec.x = vec.x * (v / amount)
					vec.y = vec.y * (v / amount)
					vec.z = vec.z * (v / amount)

					obj:set_velocity(vec)
				end
			end
		end
	end
end

-- falling & fall damage

function mob_class:falling(pos)

	if self.fly or self.disable_falling then return end

	local v = self.object:get_velocity() ; if not v then return end
	local fall_speed = self.fall_speed

	-- use liquid viscosity for float/sink speed when in water
	if self.floats and self.standing_in
	and core.registered_nodes[self.standing_in].groups.liquid then

		local visc = min(core.registered_nodes[self.standing_in].liquid_viscosity, 7) + 1

		self.object:set_velocity({x = v.x, y = 0.6, z = v.z})

		fall_speed = -1.2 / visc
	else

		-- fall damage onto solid ground
		if self.fall_damage and self.object:get_velocity().y == 0 then

			local d = (self.old_y or self.object:get_pos().y) - self.object:get_pos().y

			if d > 5 then

				local damage = d - 5
				local add = core.get_item_group(
						self.standing_on, "fall_damage_add_percent")

				if add ~= 0 then
					damage = damage + damage * (add / 100)
				end

				self.health = self.health - floor(damage)

				effect(pos, 5, "mobs_tnt_smoke.png", 1, 2, 2, nil)

				if self:check_for_death({type = "fall"}) then return true end
			end

			self.old_y = self.object:get_pos().y
		end
	end

	self.object:set_acceleration({x = 0, y = fall_speed, z = 0}) -- fall at set speed
end

-- deal damage & effects when mob punched

local dis_damage_kb = settings:get_bool("mobs_disable_damage_kb")

function mob_class:on_punch(hitter, tflp, tool_capabilities, dir, damage)

	-- mob health and nil check
	if self.health <= 0 or not hitter then return true end

	-- error checking when mod profiling is enabled
	if not tool_capabilities then
		core.log("warning",	"[mobs] Mod profiling enabled, damage not enabled")
		return true
	end

	local weapon = hitter:get_wielded_item()
	local weapon_def = weapon:get_definition() or {}

	-- calculate mob damage
	local damage = 0
	local armor = self.object:get_armor_groups() or {}
	local tmp

	-- quick error check incase it ends up 0
	if tflp == 0 then tflp = 0.2 end

	if use_cmi then
		damage = cmi.calculate_damage(self.object, hitter, tflp, tool_capabilities, dir)
	else

		for group,_ in pairs( (tool_capabilities.damage_groups or {}) ) do

			tmp = tflp / (tool_capabilities.full_punch_interval or 1.4)

			if tmp < 0 then tmp = 0.0 elseif tmp > 1 then tmp = 1.0 end

			damage = damage + (tool_capabilities.damage_groups[group] or 0)
					* tmp * ((armor[group] or 0) / 100.0)
		end
	end

	-- check if hit by player item or entity
	local hit_item = weapon_def.name

	if not is_player(hitter) then
		hit_item = hitter:get_luaentity().name
	end

	for n = 1, #self.immune_to do -- check for toll immunity or special damage

		if self.immune_to[n][1] == hit_item then

			damage = self.immune_to[n][2] or 0 ; break

		-- if "all" then no tools deal damage unless it's specified in list
		elseif self.immune_to[n][1] == "all" then
			damage = self.immune_to[n][2] or 0
		end
	end

	local enchants = {}

	if use_mc2 then

		-- get enchants from mineclonia or voxelibre
		enchants = core.deserialize(
				weapon:get_meta():get_string("mcl_enchanting:enchantments")) or {}

		-- check for damage increasing enchantments
		if enchants.sharpness then
			damage = damage + (0.5 * enchants.sharpness) + 0.5
		end
	end

	-- custom punch function (if false returned, do not continue and return true)
	if self.do_punch and self:do_punch(
			hitter, tflp, tool_capabilities, dir, damage) == false then
		return true
	end

--print("Mob Damage is", damage)

	if damage <= -1 then -- healing

		self.health = self.health - floor(damage)

		if use_vh1 then VH1.update_bar(self.object, self.health) end

		return true
	end

	if use_cmi
	and cmi.notify_punch(self.object, hitter, tflp, tool_capabilities, dir, damage) then
		return true
	end

	-- add weapon wear
	local punch_interval = tool_capabilities.full_punch_interval or 1.4

	-- toolrank support
	local wear = floor((punch_interval / 75) * 9000)

	-- check for punch_attack_uses being 0 to negate wear
	if tool_capabilities.punch_attack_uses == 0 then
		wear = 0
	end

	if mobs.is_creative(hitter:get_player_name()) then
		wear = use_tr and 1 or 0
	end

	if use_tr and weapon_def.original_description then
		toolranks.new_afteruse(weapon, hitter, nil, {wear = wear})
	else
		weapon:add_wear(wear)
	end

	hitter:set_wielded_item(weapon)

	-- only play hit sound if damage is 1 or over
	if damage >= 1 then

		-- select tool use sound if found, or fallback to default
		local snd = weapon_def.sound and weapon_def.sound.use or "mobs_punch"

		core.sound_play(snd, {object = self.object, max_hear_distance = 8}, true)

		local prop = self.object:get_properties()

		-- add healthy afterglow when hit (can cause lag with larger textures)
		if mob_hit_effect then

			self.old_texture_mods = self.texture_mods

			self.object:set_texture_mod(self.texture_mods .. prop.damage_texture_modifier)

			core.after(0.3, function()

				if self and self.object and self.object:get_pos() then

					self.texture_mods = self.old_texture_mods
					self.old_texture_mods = nil
					self.object:set_texture_mod(self.texture_mods)
				end
			end)
		end

		-- check for friendly fire (arrows from same mob)
		if self.friendly_fire then
			self.health = self.health - floor(damage) -- do damage regardless
		else
			local entity = hitter and hitter:get_luaentity()

			-- check if arrow from same mob, if so then do no damage
			if (entity and entity.name ~= self.arrow) or is_player(hitter) then
				self.health = self.health - floor(damage)
			end
		end

		-- exit here if dead, check for tools with fire damage
		local hot = tool_capabilities and tool_capabilities.damage_groups
				and tool_capabilities.damage_groups.fire

		-- check for any fire enchants also
		if use_mc2 and (enchants.flame or enchants.fire_aspect) then
			hot = true
		end

		if self:check_for_death({type = "punch", puncher = hitter, hot = hot}) then
			return true
		end
	end

	-- knock back effect (only on full punch)
	if self.knock_back and tflp >= punch_interval then

		local v = self.object:get_velocity() ; if not v then return true end
		local kb = dis_damage_kb and 1 or (damage or 1)
		local up = 2

		-- if already in air then dont go up anymore when hit
		if v.y > 0 or self.fly then up = 0 end

		dir = dir or {x = 0, y = 0, z = 0} -- nil check

		-- use tool knockback value or default
		kb = tool_capabilities.damage_groups["knockback"] or kb

		-- check for knockback enchantment
		if use_mc2 and enchants.knockback then
			kb = kb + (3 * enchants.knockback)
		end

		self.object:set_velocity({x = dir.x * kb, y = up, z = dir.z * kb})

		-- turn mob on knockback
		self:set_yaw((random(0, 360) - 180) / 180 * pi, 12)

		if self.animation and self.animation.injured_end and damage >= 1 then
			self:set_animation("injured")
		else
			self:set_animation("walk")
		end

		self.pause_timer = 0.25
	end

	-- if skittish then run away
	if self.runaway and self.order ~= "stand" then

		local lp = hitter:get_pos()

		self:yaw_to_pos(lp, 3)

		self.state = "runaway"
		self.runaway_timer = 3
		self.following = nil
	end

	local hitter_name = hitter:get_player_name() or ""

	-- call for help and attack puncher
	if self.passive == false and self.state ~= "flop"
	and not self.child --and self.attack_players
	and not (is_player(hitter) and hitter_name == self.owner)
	and not is_invisible(self, hitter_name)
	and self.object ~= hitter then

		self.state = ""
		self:do_attack(hitter) -- attack whoever punched mob

		-- alert others to the attack
		local objs = core.get_objects_inside_radius(hitter:get_pos(), self.view_range)
		local ent

		for n = 1, #objs do

			ent = objs[n] and objs[n]:get_luaentity()

			if ent and ent._cmi_is_mob then

				-- only alert members of same mob and assigned helper
				if ent.group_attack and ent.state ~= "attack"
				and not (is_player(hitter) and ent.owner == hitter_name)
				and (ent.name == self.name or ent.name == self.group_helper) then
					ent:do_attack(hitter)
				end

				-- have owned mobs attack player threat
				if is_player(hitter) and ent.owner == hitter_name and ent.owner_loyal then
					ent:do_attack(self.object)
				end
			end
		end
	end

	return true
end

-- helper to clean mob staticdata

local function clean_staticdata(self)

	local tmp, t = {}

	for _,stat in pairs(self) do

		t = type(stat)

		if  t ~= "function" and t ~= "nil" and t ~= "userdata"
		and _ ~= "object" and _ ~= "_cmi_components" then tmp[_] = self[_] end
	end

	return tmp
end

-- get entity staticdata

function mob_class:mob_staticdata()

	-- this handles mob count for mobs activated, unloaded, reloaded
	if active_limit > 0 and self.active_toggle then
		active_mobs = active_mobs + self.active_toggle
		self.active_toggle = -self.active_toggle
--print("-- staticdata", active_mobs, active_limit, self.active_toggle)
	end

	-- remove mob when out of range unless tamed
	if remove_far and self.remove_ok
	and self.type ~= "npc" and self.state ~= "attack"
	and not self.tamed and self.lifetimer < 20000 then

--print("REMOVED " .. self.name)

		remove_mob(self, true)

		return core.serialize({remove_ok = true, static_save = true})
	end

	self.remove_ok = true
	self.attack = nil
	self.following = nil
	self.state = "stand"

	if use_cmi then
		self.serialized_cmi_components = cmi.serialize_components(self._cmi_components)
	end

	return core.serialize(clean_staticdata(self))
end

-- list of items used in initial_properties

local is_property_name = {
	hp_max = true, physical = true, collide_with_objects = true, collisionbox = true,
	selectionbox = true, pointable = true, visual_size = true, textures = true,
	is_visible = true, stepheight = true, glow = true, show_on_minimap = true
}

-- activate mob and reload settings

function mob_class:mob_activate(staticdata, def, dtime)

	-- if dtime == 0 then entity has just been created
	-- anything higher means it is respawning (thx SorceryKid)
	if dtime == 0 and active_limit > 0 then self.active_toggle = 1 end

	-- remove mob if not tamed and mob total reached
	if at_limit() and not self.tamed then

		remove_mob(self)
--print("-- mob limit reached, removing " .. self.name)
		return
	end

	-- load entity variables from staticdata into self.*
	local tmp = core.deserialize(staticdata)

	if tmp then

		local t ; for _,stat in pairs(tmp) do

			t = type(stat)

			if t ~= "function" and t ~= "nil" and t ~= "userdata" then

				if is_property_name[_] then

					self.object:set_properties({[_] = stat})
				else
					self[_] = stat
				end
			end
		end
	end

	local prop = self.object:get_properties()

	-- select random texture
	if not self.base_texture then

		-- compatiblity with old simple mobs textures
		if def.textures and type(def.textures[1]) == "string" then
			def.textures = {def.textures}
		end

		-- backup a few base settings
		self.base_texture = def.textures and def.textures[random(#def.textures)]
	end

	-- get texture, model and size
	local textures = self.base_texture
	local mesh, vis_size  = self.base_mesh, self.base_size
	local colbox, selbox = self.base_colbox, self.base_selbox

	-- is there a specific texture if gotten
	if self.gotten and def.gotten_texture then textures = def.gotten_texture end

	-- specific mesh if gotten
	if self.gotten and def.gotten_mesh then mesh = def.gotten_mesh end

	-- set child objects to half size
	if self.child then

		vis_size = {x = self.base_size.x * .5, y = self.base_size.y * .5}

		if def.child_texture then textures = def.child_texture[1] end

		colbox = {
			self.base_colbox[1] * .5, self.base_colbox[2] * .5,
			self.base_colbox[3] * .5, self.base_colbox[4] * .5,
			self.base_colbox[5] * .5, self.base_colbox[6] * .5}

		selbox = {
			self.base_selbox[1] * .5, self.base_selbox[2] * .5,
			self.base_selbox[3] * .5, self.base_selbox[4] * .5,
			self.base_selbox[5] * .5, self.base_selbox[6] * .5}
	end

	-- set mob size and textures
	self.object:set_properties({textures = textures, visual_size = vis_size,
			collisionbox = colbox, selectionbox = selbox})

	if self.health == 0 then self.health = random(self.hp_min, prop.hp_max) end

	-- pathfinding init
	self.path = {}
	self.path.way = {} -- path to follow, table of positions
	self.path.lastpos = {x = 0, y = 0, z = 0}
	self.path.stuck = false
	self.path.following = false -- currently following path?
	self.path.stuck_timer = 0 -- if stuck for too long search for path

	-- Armor groups (immortal = 1 for custom damage handling)
	local armor

	if type(self.armor) == "table" then
		armor = table_copy(self.armor)
	else
		armor = {fleshy = self.armor, immortal = 1}
	end

	self.object:set_armor_groups(armor)

	-- var defaults
	self.old_y = self.object:get_pos().y
	self.old_health = self.health
	self.textures = textures
	self.standing_in = "air"
	self.standing_on = "air"
	self.state = self.state or "stand"

	-- set random yaw and stand
	self:set_yaw((random(0, 360) - 180) / 180 * pi, 6)
	self:set_animation("stand")

	-- apply texture mods
	self.object:set_texture_mod(self.texture_mods)

	-- set 5.x flag to remove monsters when map area unloaded
	if remove_far and self.type == "monster" and not self.tamed then
		self.object:set_properties({static_save = false})
	end

	-- run on_spawn function
	if self.on_spawn and not self.on_spawn_run and self.on_spawn(self) then
		self.on_spawn_run = true -- if true, set flag to run once only
	end

	-- run after_activate
	if def.after_activate then
		def.after_activate(self, staticdata, def, dtime)
	end

	if use_cmi then
		self._cmi_components = cmi.activate_components(self.serialized_cmi_components)
		cmi.notify_activate(self.object, dtime)
	end

	if use_vh1 then VH1.update_bar(self.object, self.health) end
end

-- handle mob lifetimer & expiration

function mob_class:mob_expire(pos, dtime)

	-- when lifetimer expires remove mob (except npc and tamed)
	if self.type ~= "npc" and not self.tamed and self.state ~= "attack"
	and remove_far ~= true and self.lifetimer < 20000 then

		self.lifetimer = self.lifetimer - dtime

		if self.lifetimer <= 0 then

			-- only despawn away from player
			for _,player in pairs(core.get_connected_players()) do

				if get_distance(player:get_pos(), pos) <= 15 then
					self.lifetimer = 20
					return
				end
			end

--			core.log("action", "lifetimer expired, removed " .. self.name)

			effect(pos, 15, "mobs_tnt_smoke.png", 2, 4, 2, 0)

			remove_mob(self, true) ; return true
		end
	end
end

-- get nodes mob is standing on, in, facing, facing above

function mob_class:get_nodes()

	local pos = self.object:get_pos()
	local yaw = self.object:get_yaw()
	local prop = self.object:get_properties()

	-- child mobs have a lower y_level
	local y_level = self.child and prop.collisionbox[2] * 0.5 or prop.collisionbox[2]

	self.standing_in = node_ok(
			{x = pos.x, y = pos.y + y_level + 0.25, z = pos.z}, "air").name

	self.standing_on = node_ok(
			{x = pos.x, y = pos.y + y_level - 0.25, z = pos.z}, "air").name

	-- find front position
	local dir_x = -sin(yaw) * (prop.collisionbox[4] + 0.5)
	local dir_z = cos(yaw) * (prop.collisionbox[4] + 0.5)

	-- nodes in front of mob and front/above
	self.looking_at = node_ok(
			{x = pos.x + dir_x, y = pos.y + y_level + 0.25, z = pos.z + dir_z}).name

	self.looking_above = node_ok(
			{x = pos.x + dir_x, y = pos.y + y_level + 1.25, z = pos.z + dir_z}).name

	-- are we facing a fence or wall
	if self.looking_at:find("fence") or self.looking_at:find("gate")
	or self.looking_at:find("wall") then
		self.facing_fence = true
	else
		self.facing_fence = nil
	end
--[[
print("on: " .. self.standing_on
	.. ", front: " .. self.looking_at
	.. ", front above: " .. self.looking_above
	.. ", fence: " .. (self.facing_fence and "yes" or "no"))
]]
end

-- main mob function

function mob_class:on_step(dtime, moveresult)

	if self.state == "die" then return end

	if use_cmi then cmi.notify_step(self.object, dtime) end

	local pos = self.object:get_pos()
	local yaw = self.object:get_yaw() ; if not yaw then return end

	self.node_timer = (self.node_timer or 0) + dtime

	-- get nodes (every 1/4 second by default)
	if self.node_timer > node_timer_interval then

		self:get_nodes() -- get nodes above, below, in front and front-above

		self.node_timer = 0

		-- stop when facing cliff or for fear of heights
		self.at_cliff = self:is_at_cliff()

		if self.pause_timer <= 0 and self.at_cliff then self:set_velocity(0) end

		-- has mob expired (0.25 instead of dtime since were in a timer)
		if self:mob_expire(pos, node_timer_interval) then return end

		self:do_jump() -- jump if not blocked
	end

	-- falling check, return if dead
	if self:falling(pos) then return end

	-- smooth rotation by ThomasMonroe314
	if self.delay and self.delay > 0 then

		if self.delay == 1 then yaw = self.target_yaw
		else
			local dif = abs(yaw - self.target_yaw)

			if yaw > self.target_yaw then

				if dif > pi then
					dif = 2 * pi - dif
					yaw = yaw + dif / self.delay -- add
				else
					yaw = yaw - dif / self.delay -- subtract
				end

			elseif yaw < self.target_yaw then

				if dif > pi then
					dif = 2 * pi - dif
					yaw = yaw - dif / self.delay -- subtract
				else
					yaw = yaw + dif / self.delay -- add
				end
			end

			if yaw > (pi * 2) then yaw = yaw - (pi * 2) end
			if yaw < 0 then yaw = yaw + (pi * 2) end
		end

		self.delay = self.delay - 1
		self.object:set_yaw(yaw)
	end

	-- environmental damage timer (every 1 second)
	self.env_damage_timer = self.env_damage_timer + dtime

	if self.env_damage_timer > 1 then

		self.env_damage_timer = 0

		if self:do_env_damage() then return end -- check for damage
	end

	if self.pause_timer > 0 then -- knockback timer

		self.pause_timer = self.pause_timer - dtime

		if self.pause_timer <= 0 and (self.order == "stand" or self.state == "stand") then

			self.pause_timer = 0
			self:set_velocity(0)
			self:set_animation("stand", true)
		end

		return
	end

	-- run custom function (defined in mob lua file) - when false skip going any further
	if self.do_custom and self:do_custom(dtime, moveresult) == false then
		return
	end

	self.timer = self.timer + dtime

	if self.timer > 100 then self.timer = 1 end -- never go over 100

	-- when attacking call do_states live (return if dead)
	if self.state == "attack" and self:do_states(dtime) then return end

	-- one second timed calls
	self.timer1 = (self.timer1 or 0) + dtime

	if self.timer1 >= main_timer_interval then

		-- random mob sound
		if random(100) == 1 then self:mob_sound(self.sounds.random) end

		self:general_attack()
		self:follow_flop()

		-- when not attacking call do_states every second (return if dead)
		if self.state ~= "attack" then
			if self:do_states(main_timer_interval) then return end
		end

		self:do_runaway_from(self)
		self:do_stay_near()

		self.timer1 = 0
	end
end

-- default function when mobs are blown up with TNT

function mob_class:on_blast(damage)

--print("-- blast damage", damage)

	self.object:punch(self.object, 1.0,
			{full_punch_interval = 1.0, damage_groups = {fleshy = damage}}, nil)

	-- return no damage, no knockback, no item drops, mob api handles all
	return false, false, {}
end

-- register mob entity

function mobs:register_mob(name, def)

	mobs.spawning_mobs[name] = {}

	local collisionbox = def.collisionbox or {-0.25, -0.25, -0.25, 0.25, 0.25, 0.25}

	-- quick fix to stop mobs glitching through nodes if too small
	if mob_height_fix and -collisionbox[2] + collisionbox[5] < 1.01 then
		collisionbox[5] = collisionbox[2] + 0.99
	end

	core.register_entity(":" .. name, setmetatable({

		initial_properties = {
			hp_max = max(1, (def.hp_max or 10) * difficulty),
			physical = true,
			collisionbox = collisionbox,
			selectionbox = def.selectionbox or collisionbox,
			visual = def.visual,
			visual_size = def.visual_size or {x = 1, y = 1},
			mesh = def.mesh,
			textures = "",
			makes_footstep_sound = def.makes_footstep_sound,
			stepheight = def.stepheight or 1.1,
			glow = def.glow,
			damage_texture_modifier = def.damage_texture_modifier or "^[colorize:#c9900070",
		},

		name = name,
		type = def.type,
		_nametag = def.nametag,
		attack_type = def.attack_type,
		fly = def.fly,
		fly_in = def.fly_in,
		keep_flying = def.keep_flying,
		owner = def.owner,
		order = def.order,
		jump_height = def.jump_height,
		can_leap = def.can_leap,
		drawtype = def.drawtype, -- DEPRECATED, use rotate
		rotate = rad(def.rotate or 0), -- 0=front 90=side 180=back 270=side2
		lifetimer = def.lifetimer,
		hp_min = max(1, (def.hp_min or 5) * difficulty),

		base_mesh = def.mesh, -- backup entity model and size
		base_colbox = collisionbox,
		base_selbox = def.selectionbox or collisionbox,
		base_size = def.visual_size or {x = 1, y = 1},

		view_range = def.view_range,
		walk_velocity = def.walk_velocity,
		run_velocity = def.run_velocity,
		damage = max(0, (def.damage or 0) * difficulty),
		damage_group = def.damage_group,
		light_damage = def.light_damage,
		light_damage_min = def.light_damage_min,
		light_damage_max = def.light_damage_max,
		water_damage = def.water_damage,
		lava_damage = def.lava_damage,
		fire_damage = def.fire_damage,
		air_damage = def.air_damage,
		node_damage = def.node_damage,
		suffocation = def.suffocation,
		fall_damage = def.fall_damage,
		fall_speed = def.fall_speed,
		armor = def.armor,
		arrow = def.arrow,
		arrow_override = def.arrow_override,
		shoot_interval = def.shoot_interval,
		homing = def.homing,
		sounds = def.sounds,
		animation = def.animation,
		follow = def.follow,
		walk_chance = def.walk_chance,
		stand_chance = def.stand_chance,
		attack_chance = def.attack_chance,
		attack_patience = def.attack_patience,
		passive = def.passive,
		knock_back = def.knock_back,
		shoot_offset = def.shoot_offset,
		floats = def.floats,
		reach = def.reach,
		texture_list = def.textures,
		texture_mods = def.texture_mods or "",
		child_texture = def.child_texture,
		docile_by_day = def.docile_by_day,
		fear_height = def.fear_height or def.fly and 0 or 2,
		runaway = def.runaway,
		pathfinding = def.pathfinding,
		immune_to = def.immune_to,
		explosion_radius = def.explosion_radius,
		explosion_damage_radius = def.explosion_damage_radius,
		explosion_timer = def.explosion_timer,
		allow_fuse_reset = def.allow_fuse_reset,
		stop_to_explode = def.stop_to_explode,
		dogshoot_switch = def.dogshoot_switch,
		dogshoot_count_max = def.dogshoot_count_max,
		dogshoot_count2_max = def.dogshoot_count2_max or def.dogshoot_count_max,
		group_attack = def.group_attack,
		group_helper = def.group_helper,
		attack_monsters = def.attacks_monsters or def.attack_monsters,
		attack_animals = def.attack_animals,
		attack_players = def.attack_players,
		attack_npcs = def.attack_npcs,
		attack_ignore = def.attack_ignore,
		specific_attack = def.specific_attack,
		friendly_fire = def.friendly_fire,
		runaway_from = def.runaway_from,
		owner_loyal = def.owner_loyal,
		pushable = def.pushable,
		stay_near = def.stay_near,
		randomly_turn = def.randomly_turn ~= false,
		ignore_invisibility = def.ignore_invisibility,
		messages = def.messages,

		on_rightclick = def.on_rightclick,
		on_die = def.on_die,
		on_death = def.on_death, -- engine function for entity death
		on_flop = def.on_flop,
		do_custom = def.do_custom,
		custom_attack = def.custom_attack,
		on_spawn = def.on_spawn,
		on_blast = def.on_blast,
		do_punch = def.do_punch,
		on_grown = def.on_grown,
		on_sound = def.on_sound,

--		is_mob = true, _hittable_by_projectile = true, -- mineclone thing

		on_activate = function(self, staticdata, dtime)
			return self:mob_activate(staticdata, def, dtime)
		end,

		get_staticdata = function(self)
			return self:mob_staticdata(self)
		end

	}, mob_class_meta))

	local self = core.registered_entities[name]
	mobs.compatibility_check(self) -- older setting check for compatibility
end

-- register arrow for shoot attack

function mobs:register_arrow(name, def)

	if not name or not def then return end

	core.register_entity(":" .. name, {

		initial_properties = {
			physical = def.physical,
			collide_with_objects = def.collide_with_objects or false,
			static_save = false,
			visual = def.visual,
			visual_size = def.visual_size,
			mesh = def.mesh,
			textures = def.textures,
			collisionbox = def.collisionbox or {-.1, -.1, -.1, .1, .1, .1},
			glow = def.glow,
			automatic_face_movement_dir = def.rotate
					and (def.rotate - (pi / 180)) or false,
		},

		velocity = def.velocity,
		hit_player = def.hit_player,
		hit_node = def.hit_node,
		hit_mob = def.hit_mob,
		hit_object = def.hit_object,
		drop = def.drop, -- chance of dropping arrow as registered item
		timer = 0,
		lifetime = def.lifetime or 4.5,
		owner_id = def.owner_id,
		rotate = def.rotate,

		on_activate = def.on_activate,

		on_punch = def.on_punch or function(self, hitter, tflp, tool_capabilities, dir)
		end,

		on_step = def.on_step or function(self, dtime)

			self.timer = self.timer + dtime

			local pos = self.object:get_pos()

			if self.timer > self.lifetime then

				self.object:remove() ; -- print("removed arrow")

				return
			end

			-- does arrow have a tail?
			if def.tail and def.tail == 1 and def.tail_texture then

				core.add_particle({
					pos = pos,
					velocity = {x = 0, y = 0, z = 0},
					acceleration = {x = 0, y = 0, z = 0},
					expirationtime = def.expire or 0.25,
					collisiondetection = false,
					texture = def.tail_texture,
					size = def.tail_size or 5,
					glow = def.glow or 0
				})
			end

			-- make homing arrows follow target when in view
			if self._homing_target then

				local p = self._homing_target:get_pos()

				if p then

					if core.line_of_sight(self.object:get_pos(), p) then

						self.object:set_velocity(
							vector.direction(self.object:get_pos(), p) * self.velocity)
					end
				else
					self._homing_target = nil
				end
			end

			self.lastpos = self.lastpos or pos

			local cast = core.raycast(self.lastpos, pos, true, true)
			local thing = cast:next()

			while thing do -- loop through things

				-- if inside object that isn't arrow
				if thing.type == "object" and thing.ref ~= self.object
				and tostring(thing.ref) ~= self.owner_id then

					if self.hit_player and is_player(thing.ref) then

						self:hit_player(thing.ref)

--print("hit player", thing.ref:get_player_name())

						self.object:remove() ; return

					end

					local entity = thing.ref:get_luaentity()

					if entity and self.hit_mob and entity._cmi_is_mob then

						self:hit_mob(thing.ref)

--print("hit mob", entity.name)

						self.object:remove() ; return
					end

					if entity and self.hit_object and (not entity._cmi_is_mob) then

						self:hit_object(thing.ref)

--print("hit object", entity.name)

						self.object:remove() ; return
					end

				end

				-- if inside node
				if thing.type == "node" and self.hit_node then

					local node = core.get_node(pos)
					local def = core.registered_nodes[node.name]

					if def and def.walkable then

						self:hit_node(pos, node)

						if (type(self.drop) == "boolean" and self.drop)
						or (type(self.drop) == "number" and random(self.drop) == 1) then

							pos.y = pos.y + 1

							core.add_item(self.lastpos,
									self.object:get_luaentity().name)
						end

--print("hit node", node.name)

						self.object:remove() ; return
					end
				end

				thing = cast:next()

			end -- end thing loop

			self.lastpos = pos
		end
	})
end

-- explosion with no node damage

function mobs:safe_boom(self, pos, radius, texture)

	core.sound_play(self and self.sounds and self.sounds.explode or "tnt_explode", {
		pos = pos,
		gain = 1.0,
		max_hear_distance = (self.sounds and self.sounds.distance) or 32
	}, true)

	entity_physics(pos, radius)

	effect(pos, 32, texture, radius * 3, radius * 5, radius, 1, 0)
end

-- explosion with tnt mod checks

function mobs:boom(self, pos, node_damage_radius, entity_radius, texture)

	texture = texture or "mobs_tnt_smoke.png"

	mobs:safe_boom(self, pos, node_damage_radius, texture)
end

-- Register spawn eggs - This also introduces the “spawn_egg” group:
-- * spawn_egg=1: generic mob, no metadata
-- * spawn_egg=2: captured/tamed mob, metadata

function mobs:register_egg(mob, desc, background, addegg, no_creative)

	local grp = {spawn_egg = 1}

	-- do NOT add this egg to creative inventory (e.g. dungeon master)
	if no_creative then grp.not_in_creative_inventory = 1 end

	local invimg = background

	if addegg == 1 then
		invimg = "mobs_chicken_egg.png^(" .. invimg .. "^[mask:mobs_chicken_egg_overlay.png)"
	end

	-- does mob/entity exist
	local is_mob = core.registered_entities[mob]

	if not is_mob then
		print("[Mobs Redo] Spawn Egg cannot be created for " .. mob) ; return
	end

	-- get mob collisionbox and determine y_offset when spawning
	local _prop = is_mob and is_mob.initial_properties or {}
	local _y = _prop.collisionbox and -_prop.collisionbox[2] or 1

	-- register new spawn egg containing mob information (cannot be stacked)
	-- these are only created for animals and npc's, not monsters
	if is_mob.type ~= "monster" then

		core.register_craftitem(":" .. mob .. "_set", {

			description = S("@1 (Tamed)", desc),
			inventory_image = invimg,
			groups = {spawn_egg = 2, not_in_creative_inventory = 1},
			stack_max = 1,

			on_place = function(itemstack, placer, pointed_thing)

				local pos = pointed_thing.above

				-- does existing on_rightclick function exist?
				local under = core.get_node(pointed_thing.under)
				local def = core.registered_nodes[under.name]

				if def and def.on_rightclick then

					return def.on_rightclick(
							pointed_thing.under, under, placer, itemstack, pointed_thing)
				end

				if pos and not core.is_protected(pos, placer:get_player_name()) then

					if at_limit() then -- have we reached active mob limit

						core.chat_send_player(placer:get_player_name(),
								S("Active Mob Limit Reached!")
								.. "  (" .. active_mobs
								.. " / " .. active_limit .. ")")
						return
					end

					pos.y = pos.y + _y

					local data = itemstack:get_metadata()
					local smob = core.add_entity(pos, mob, data)
					local ent = smob and smob:get_luaentity()

					if not ent then return end -- sanity check

					if ent.type ~= "monster" then -- set owner if not a monster
						ent.owner = placer:get_player_name()
						ent.tamed = true
					end

					itemstack:take_item() -- since mob is unique, remove egg on spawn
				end

				return itemstack
			end
		})
	end

	-- register old stackable mob egg
	core.register_craftitem(":" .. mob, {

		description = desc,
		inventory_image = invimg,
		groups = grp,

		on_place = function(itemstack, placer, pointed_thing)

			local pos = pointed_thing.above

			-- does existing on_rightclick function exist?
			local under = core.get_node(pointed_thing.under)
			local def = core.registered_nodes[under.name]

			if def and def.on_rightclick then

				return def.on_rightclick(
						pointed_thing.under, under, placer, itemstack, pointed_thing)
			end

			if pos and not core.is_protected(pos, placer:get_player_name()) then

				if at_limit() then -- have we reached active mob limit

					core.chat_send_player(placer:get_player_name(),
							S("Active Mob Limit Reached!")
							.. "  (" .. active_mobs
							.. " / " .. active_limit .. ")")
					return
				end

				pos.y = pos.y + _y

				local smob = core.add_entity(pos, mob)
				local ent = smob and smob:get_luaentity()

				if not ent then return end -- sanity check

				-- don't set owner if monster or sneak pressed
				if ent.type ~= "monster" and not placer:get_player_control().sneak then
					ent.owner = placer:get_player_name()
					ent.tamed = true
				end

				-- if not in creative then take item
				if not mobs.is_creative(placer:get_player_name()) then
					itemstack:take_item()
				end
			end

			return itemstack
		end
	})
end

function mobs:alias_mob(old_name, new_name)

	-- check old_name entity doesnt already exist
	if core.registered_entities[old_name] then return end

	core.register_alias(old_name, new_name) -- spawn egg

	core.register_entity(":" .. old_name, { -- entity

		initial_properties = {physical = false, static_save = false},

		on_activate = function(self, staticdata)

			if core.registered_entities[new_name] then
				core.add_entity(self.object:get_pos(), new_name, staticdata)
			end

			remove_mob(self)
		end,

		get_staticdata = function(self)
			return core.serialize(clean_staticdata(self))
		end
	})
end

-- Is mob hearing enabled, if so override core.sound_play with custom function

if settings:get_bool("mobs_can_hear") ~= false then

	local node_hear = settings:get_bool("mobs_can_hear_node")
	local old_sound_play = core.sound_play

	core.sound_play = function(spec, param, eph)

		if type(spec) == "table" then return old_sound_play(spec, param, eph) end

		local def = {} ; param = param or {}

		-- store sound position (ignore player and object positioning as background)
		if param.pos then
			def.pos = param.pos
--		elseif param.object then
--			def.pos = param.object:get_pos()
--			def.object = param.object
--		elseif param.to_player then
--			local player = core.get_player_by_name(param.to_player)
--			def.pos = player and player:get_pos()
--			def.player = param.to_player
		end

		-- if no position found use default function
		if not def.pos then
			return old_sound_play(spec, param, eph)
		end

		-- store sound name and gain
		if type(spec) == "string" then
			def.sound = spec
			def.gain = param.gain or 1.0
		elseif type(spec) == "table" then
			def.sound = spec.name
			def.gain = spec.gain or param.gain or 1.0
		end

--print("==", def.sound)

		def.gain = def.gain or 1.0
		def.max_hear_distance = param.max_hear_distance or 32

		-- find mobs within sounds hearing range
		local objs = core.get_objects_inside_radius(def.pos, def.max_hear_distance)
		local bit = def.gain / def.max_hear_distance

		for n = 1, #objs do

			local obj = objs[n]

			if not obj:is_player() then

				local ent = obj:get_luaentity()

				if ent and ent._cmi_is_mob and ent.on_sound then

					-- calculate loudness of sound to mob
					def.distance = get_distance(def.pos, obj:get_pos())
					def.loudness = def.gain - (bit * def.distance)

					-- run custom on_sound function if heard
					if def.loudness > 0 then ent.on_sound(ent, def) end
				end
			end
		end

		-- find nodes that can hear up to 8 blocks away
		if node_hear then

			local dist = min(def.max_hear_distance, 8)
			local ps = core.find_nodes_in_area(
					vector.subtract(def.pos, dist),
					vector.add(def.pos, dist), {"group:on_sound"})

			if #ps > 0 then

				for n = 1, #ps do

					local ndef = core.registered_nodes[core.get_node(ps[n]).name]

					def.distance = get_distance(def.pos, ps[n])
					def.loudness = def.gain - (bit * def.distance)

					if def.loudness > 0 and ndef and ndef.on_sound then
						ndef.on_sound(ps[n], def)
					end
				end
			end
		end

		return old_sound_play(spec, param, eph)
	end
end