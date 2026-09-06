local api = {}
rawset(_G, "ctf_ranged", api)

local files = {
	"bullet.lua",
	"ammo.lua",
	"automatic.lua"
}

for _, file in ipairs(files) do
	dofile(core.get_modpath("ctf_ranged").."/"..file)
end

local S = core.get_translator(core.get_current_modname())
local RANGED_DAMAGE_GROUP = "ranged"

-- Ranged damage is reduced by ctf_ranged itself, not a second time by the
-- engine. 3d_armor rebuilds player armor groups whenever equipment changes,
-- so this group has to be registered with it rather than set on the player.
if core.global_exists("armor") and armor.register_armor_group then
	armor:register_armor_group(RANGED_DAMAGE_GROUP, 100)
end

core.register_craftitem("ctf_ranged:ammo", {
	description = S("Ammo"),
	inventory_image = "ctf_ranged_ammo.png",
})

local function record_hit(hits, target, damage)
	local key
	if target:is_player() then
		key = "player:" .. target:get_player_name()
	else
		key = "object:" .. tostring(target)
	end

	local hit = hits[key]
	if not hit then
		hit = {
			target = target,
			damage = 0,
			projectiles = 0,
		}
		hits[key] = hit
	end

	hit.damage = hit.damage + damage
	hit.projectiles = hit.projectiles + 1
end

local function ranged_damage_multiplier(fleshy)
	-- fleshy is Luanti's percentage of normal damage that passes through the
	-- armor (100 when unarmored, lower for stronger armor). This curve keeps
	-- armor meaningful without allowing it to make guns harmless.
	if fleshy <= 0 then
		return 0 -- preserve admin / explicitly invulnerable armor
	end

	local protection = math.min(fleshy, 100) / 100
	return 0.20 + 0.80 * math.pow(protection, 1.25)
end

local function apply_ranged_damage(hit, user, look_dir, def)
	local target = hit.target
	if not target or target:get_hp() <= 0 then
		return
	end

	if not target:is_player() then
		-- Mobs do not receive the 3d_armor damage group. Let their ordinary
		-- fleshy armor group handle the projectile damage.
		target:punch(user, def.fire_interval or 0.1, {
			full_punch_interval = def.fire_interval or 0.1,
			damage_groups = {fleshy = hit.damage},
		}, look_dir)
		return
	end

	local armor_groups = target:get_armor_groups()
	if armor_groups.immortal and armor_groups.immortal ~= 0 then
		return
	end

	local fleshy = armor_groups.fleshy
	if type(fleshy) ~= "number" then
		fleshy = 100
	end

	local multiplier = ranged_damage_multiplier(fleshy)
	if multiplier <= 0 then
		return
	end

	-- Damage is combined once per target and per shot. This preserves the
	-- fractional contribution of every pellet and prevents a shotgun from
	-- applying its full pellet count once for every ray.
	local final_damage = math.max(1, math.floor(hit.damage * multiplier + 0.5))

	-- Bullets wear armor more than a single projectile, but with diminishing
	-- returns: 1 hit = 0.70x normal wear, 7 hits = 1.11x, 14 hits = 1.39x.
	local armor_wear_multiplier = 0.45 + 0.25 * math.sqrt(hit.projectiles)

	target:punch(user, def.fire_interval or 0.1, {
		full_punch_interval = def.fire_interval or 0.1,
		armor_wear_multiplier = armor_wear_multiplier,
		damage_groups = {
			[RANGED_DAMAGE_GROUP] = final_damage,
		},
	}, look_dir)
end

local hit_sent = {}
local rico_sent = nil
local function process_ray(ray, user, look_dir, def, hits)
	local hitpoint = ray:hit_object_or_node({
		node = function(ndef)
			return (ndef.walkable == true and ndef.pointable == true) or ndef.groups.liquid
		end,
		object = function(obj)
			return (obj:is_player() and obj ~= user) or not obj:is_player() and obj:get_luaentity().name ~= "__builtin:item"
		end
	})

	if hitpoint then
		if hitpoint.type == "node" then
			local node = core.get_node(hitpoint.under)
			local nodedef = core.registered_nodes[node.name]

			if nodedef.on_ranged_shoot or nodedef.groups.leaves then
				if not core.is_protected(hitpoint.under, user:get_player_name()) then
					if nodedef.on_ranged_shoot then
						nodedef.on_ranged_shoot(hitpoint.under, node, user, def.type)
					else
						core.dig_node(hitpoint.under)
					end
				end
				if def.type ~= "shotgun" then
					core.add_particlespawner({
						amount = 10,
						time = 0.03,
						minpos = hitpoint.intersection_point,
						maxpos = hitpoint.intersection_point,
						minvel = {x=-4, y=2, z=-4},
						maxvel = {x=4, y=3, z=4},
						minacc = {x=0, y=-15, z=0},
						maxacc = {x=0, y=-15, z=0},
						minexptime = 0.1,
						maxexptime = 0.3,
						minsize = 1,
						maxsize = 2,
						node = {name = nodedef.name},
						collisiondetection = true,
						collision_removal = false,
						glow = 3
					})
				end
			else
				if nodedef.walkable and nodedef.pointable then
					if nodedef.groups.tnt and core.get_modpath("tnt") then
						tnt.burn(hitpoint.under)
					end

					core.add_particle({
						pos = vector.subtract(hitpoint.intersection_point, vector.multiply(look_dir, 0.04)),
						velocity = vector.new(),
						acceleration = {x=0, y=0, z=0},
						expirationtime = def.bullethole_lifetime or 3,
						size = 1,
						collisiondetection = false,
						texture = "ctf_ranged_bullethole.png",
					})
					if def.type ~= "shotgun" then
						core.add_particlespawner({
							amount = 10,
							time = 0.03,
							minpos = hitpoint.intersection_point,
							maxpos = hitpoint.intersection_point,
							minvel = {x=-4, y=2, z=-4},
							maxvel = {x=4, y=3, z=4},
							minacc = {x=0, y=-15, z=0},
							maxacc = {x=0, y=-15, z=0},
							minexptime = 0.2,
							maxexptime = 0.4,
							minsize = 1,
							maxsize = 1,
							node = {name = nodedef.name},
							collisiondetection = true,
							collision_removal = false,
							glow = 14
						})
					end

					if not rico_sent or vector.distance(rico_sent, hitpoint.intersection_point) > 10 then
						if not rico_sent then
							core.after(0.2, function() rico_sent = nil end)
						end
						rico_sent = hitpoint.intersection_point

						core.sound_play("ctf_ranged_ricochet", {gain = 2.4, pos = hitpoint.intersection_point})
					end
				elseif nodedef.groups.liquid then
					if def.type ~= "shotgun" then
						core.add_particlespawner({
							amount = 10,
							time = 0.1,
							minpos = hitpoint.intersection_point,
							maxpos = hitpoint.intersection_point,
							minvel = {x=look_dir.x * 3, y=4, z=-look_dir.z * 3},
							maxvel = {x=look_dir.x * 4, y=6, z= look_dir.z * 4},
							minacc = {x=0, y=-10, z=0},
							maxacc = {x=0, y=-13, z=0},
							minexptime = 1,
							maxexptime = 1,
							minsize = 0,
							maxsize = 0,
							node = {name = nodedef.name},
							collisiondetection = false,
							glow = 3,
						})
					end
					if def.liquid_travel_dist then
						process_ray(api.bulletcast(
							def.bullet, hitpoint.intersection_point,
							vector.add(hitpoint.intersection_point, vector.multiply(look_dir, def.liquid_travel_dist)), true, false
						), user, look_dir, def)
					end
				end
			end
		elseif hitpoint.type == "object" then
			record_hit(hits, hitpoint.ref, def.damage)

			local name = user:get_player_name()
			if not hit_sent[name] then
				hit_sent[name] = true
				core.after(0.2, function() hit_sent[name] = nil end)
				core.sound_play("ctf_ranged_hit", {
					to_player = name,
					gain = 0.5
				})
			end
		end
	end
end

-- Can be overridden for custom behaviour
function api.can_use_gun(player, name)
	return true
end

--- Play ephemeral sound on the spot of a player.
-- @param user ObjectRef: The player object.
-- @param sound_name str: The name of the sound to be played.
-- @param spec? table: The SimpleSoundSpec of the sound. Some fields are overriden.
local function play_player_positional_sound(user, sound_name, spec)
	-- This function handles positional sounds that are
	-- supposed to be heared equally on both left and right channel
	-- by the user, while being heared at the position of the player
	-- by other players.
	-- Such a mechanism is mainly used on gunshot sounds,
	-- so the ephemeral flag is set.

	-- The spec table is copied as a base for the SimpleSoundSpec.
	-- If not supplied, one is created without any customizations.

	local user_name = user:get_player_name()

	-- Two copies of SimpleSoundSpec

	local non_user_spec = spec and table.copy(spec) or {}
	non_user_spec.pos = user:get_pos()
	non_user_spec.exclude_player = user_name

	local user_spec = spec and table.copy(spec) or {}
	user_spec.to_player = user_name

	core.sound_play(sound_name, non_user_spec, true)
	core.sound_play(sound_name, user_spec, true)
end

function api.simple_register_gun(name, def)
	local item_info = {
		ranged_damage = def.damage * (def.bullet and def.bullet.amount or 1),
		fire_rate = 1 / def.fire_interval,
		magazine = def.rounds,
		range = def.range,
		loaded = false,
	}
	core.register_tool(api.also_register_loaded_tool(name, {
		description = def.description,
		inventory_image = def.texture .. "^[colorize:#F44:42",
		ammo = def.ammo or "ctf_ranged:ammo",
		rounds = def.rounds,
		_item_info = item_info,
		_g_category = def.type,
		groups = {ranged = 1, [def.type] = 1, tier = def.tier or 1, not_in_creative_inventory = 1},
		on_use = function(itemstack, user)
			if not api.can_use_gun(user, name) then
				play_player_positional_sound(user, "ctf_ranged_click")
				return
			end

			local result = api.load_weapon(itemstack, user:get_inventory())

			local sound_name
			if result:get_name() == itemstack:get_name() then
				sound_name = "ctf_ranged_click"
			else
				sound_name = "ctf_ranged_reload"
			end

			play_player_positional_sound(user, sound_name)

			return result
		end,
	},
	function(loaded_def)
		loaded_def.description = def.description
		loaded_def._item_info = table.copy(item_info)
		loaded_def._item_info.loaded = true
		loaded_def.inventory_image = def.texture
		loaded_def.inventory_overlay = def.texture_overlay
		loaded_def.wield_image = def.wield_texture or def.texture
		loaded_def.groups.not_in_creative_inventory = nil
		loaded_def.on_secondary_use = def.on_secondary_use
		loaded_def._cooldown = def.fire_interval
		loaded_def.on_use = function(itemstack, user)
			if not api.can_use_gun(user, name) then
				play_player_positional_sound(user, "ctf_ranged_click")
				return
			end

			if def.automatic then
				if not api.enable_automatic(def.fire_interval, itemstack, user) then
					return
				end
			end

			local spawnpos, look_dir = api.get_bullet_start_data(user)
			local endpos = vector.add(spawnpos, vector.multiply(look_dir, def.range))
			local rays

			if type(def.bullet) == "table" then
				def.bullet.texture = "ctf_ranged_bullet.png^[colorize:#FFDB4C:255"
				def.bullet.glow = 14
			else
				def.bullet = {
					texture = "ctf_ranged_bullet.png^[colorize:#FFDB4C:255",
					glow = 14
				}
			end

			if not def.bullet.spread then
				rays = {api.bulletcast(
					def.bullet,
					spawnpos, endpos, true, true
				)}
			else
				rays = api.spread_bulletcast(def.bullet, spawnpos, endpos, true, true)
			end

			play_player_positional_sound(user, def.fire_sound)

			local hits = {}
			for _, ray in pairs(rays) do
				process_ray(ray, user, look_dir, def, hits)
			end

			for _, hit in pairs(hits) do
				apply_ranged_damage(hit, user, look_dir, def)
			end

			if def.rounds > 0 then
				return api.unload_weapon(itemstack)
			end
		end

		if def.rightclick_func then
			loaded_def.on_place = function(itemstack, user, pointed, ...)
				local pointed_def = false
				local node

				if pointed and pointed.under then
					node = core.get_node(pointed.under)
					pointed_def = core.registered_nodes[node.name]
				end

				if pointed_def and pointed_def.on_rightclick then
					return core.item_place(itemstack, user, pointed)
				else
					return def.rightclick_func(itemstack, user, pointed, ...)
				end
			end

			loaded_def.on_secondary_use = def.rightclick_func
		end
	end))
end

api.simple_register_gun("ctf_ranged:pistol", {
	type = "pistol",
	description = S("Pistol"),
	texture = "ctf_ranged_pistol.png",
	fire_sound = "ctf_ranged_pistol",
	rounds = 75,
	range = 75,
	damage = 2,
	liquid_travel_dist = 2,
	automatic = false,
	fire_interval = 0.6
})

api.simple_register_gun("ctf_ranged:rifle", {
	type = "rifle",
	description = S("Rifle"),
	texture = "ctf_ranged_rifle.png",
	fire_sound = "ctf_ranged_rifle",
	rounds = 40,
	range = 150,
	damage = 4,
	liquid_travel_dist = 4,
	automatic = false,
	fire_interval = 0.8
})

api.simple_register_gun("ctf_ranged:shotgun", {
	type = "shotgun",
	description = S("Shotgun"),
	texture = "ctf_ranged_shotgun.png",
	fire_sound = "ctf_ranged_shotgun",
	bullet = {
		amount = 14,
		spread = 5,
	},
	rounds = 10,
	range = 24,
	damage = 2,
	automatic = false,
	fire_interval = 2
})

api.simple_register_gun("ctf_ranged:smg", {
	type = "smg",
	description = S("Submachinegun"),
	texture = "ctf_ranged_smgun.png",
	fire_sound = "ctf_ranged_pistol",
	bullet = {
		spread = 1.5,
	},
	rounds = 36,
	range = 75,
	damage = 1,
	liquid_travel_dist = 2,
	automatic = true,
	fire_interval = 0.1
})
