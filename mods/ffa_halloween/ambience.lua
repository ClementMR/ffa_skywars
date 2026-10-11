local H = ffa_halloween

function H.sound(name, params)
	if H.sounds then core.sound_play("ffa_halloween_" .. name, params, true) end
end

function H.burst(pos, texture, amount, playername)
	if not H.particles then return end
	core.add_particlespawner({
		amount = amount or 12, time = 0.2,
		minpos = vector.offset(pos, -0.3, 0, -0.3), maxpos = vector.offset(pos, 0.3, 1, 0.3),
		minvel = {x = -1.8, y = 0.5, z = -1.8}, maxvel = {x = 1.8, y = 3, z = 1.8},
		minacc = {x = 0, y = -1, z = 0}, maxacc = {x = 0, y = -1, z = 0},
		minexptime = 0.4, maxexptime = 1.2, minsize = 1, maxsize = 3,
		texture = texture, glow = 8, playername = playername,
	})
end

function H.apply_ambience(player)
	local name = player:get_player_name()
	if not H.ambience[name] then
		H.ambience[name] = {
			sky = player:get_sky(true), sun = player:get_sun(), moon = player:get_moon(),
			stars = player:get_stars(), clouds = player:get_clouds(),
			ratio = player:get_day_night_ratio(), lighting = player:get_lighting(),
		}
	end
	local saved = H.ambience[name]
	local sky = table.copy(saved.sky)
	sky.type, sky.textures, sky.clouds = "regular", {}, true
	sky.sky_color = {
		day_sky = "#4B365E", day_horizon = "#B77B54", dawn_sky = "#593866",
		dawn_horizon = "#C77C48", night_sky = "#302840", night_horizon = "#664365",
		indoors = "#68516F", fog_sun_tint = "#AD724B", fog_moon_tint = "#8660AB",
		fog_tint_type = "custom",
	}
	sky.fog = {fog_distance = H.fog_distance, fog_start = 0.3, fog_color = "#766180"}
	player:set_sky(sky)
	player:override_day_night_ratio(0.48)
	player:set_sun({visible = false, sunrise_visible = false})
	player:set_moon({visible = true, texture = "ffa_halloween_moon.png", scale = 1.7})
	player:set_stars({visible = true, count = 1800, star_color = "#E7C8FFAC", day_opacity = 0.45})
	player:set_clouds({density = 0.55, color = "#796385B0", ambient = "#302B40",
		thickness = 12, speed = {x = 1, z = -2}})
	local lighting = table.copy(saved.lighting)
	lighting.saturation = 0.88
	lighting.bloom = {intensity = 0.12, strength_factor = 1.1, radius = 1.2}
	player:set_lighting(lighting)
end

function H.restore_ambience(player)
	local name = player:get_player_name()
	local saved = H.ambience[name]
	if not saved then return end
	player:set_sky(saved.sky)
	player:set_sun(saved.sun)
	player:set_moon(saved.moon)
	player:set_stars(saved.stars)
	player:set_clouds(saved.clouds)
	player:override_day_night_ratio(saved.ratio)
	player:set_lighting(saved.lighting)
	local skies = rawget(_G, "skybox")
	if skies and skies.restore then skies.restore(player) end
	H.ambience[name] = nil
end
