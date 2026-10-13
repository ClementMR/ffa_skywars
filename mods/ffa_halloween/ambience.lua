local H = ffa_halloween

function H.burst(pos, texture, amount, playername)
	core.add_particlespawner({
		amount = amount or 12, time = 0.2,
		minpos = vector.offset(pos, -0.3, 0, -0.3), maxpos = vector.offset(pos, 0.3, 1, 0.3),
		minvel = {x = -1.8, y = 0.5, z = -1.8}, maxvel = {x = 1.8, y = 3, z = 1.8},
		minacc = {x = 0, y = -1, z = 0}, maxacc = {x = 0, y = -1, z = 0},
		minexptime = 0.4, maxexptime = 1.2, minsize = 1, maxsize = 3,
		texture = texture, glow = 8, playername = playername,
	})
end