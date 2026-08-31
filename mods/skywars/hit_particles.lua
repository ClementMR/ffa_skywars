core.register_on_player_hpchange(function(player, hp_change, reason)
    if hp_change >= 0 then
        return hp_change
    end

    local pos = player:get_pos()
    if not pos then
        return hp_change
    end

    pos.y = pos.y + 1

    core.add_particlespawner({
        amount = 30,
        time = 0.05,

        minpos = vector.subtract(pos, 0.3),
        maxpos = vector.add(pos, 0.3),

        minvel = {x = -2, y = 0.5, z = -2},
        maxvel = {x = 2, y = 2, z = 2},

        minacc = {x = 0, y = -5, z = 0},
        maxacc = {x = 0, y = -8, z = 0},

        minexptime = 0.3,
        maxexptime = 0.6,

        minsize = 0.5,
        maxsize = 1,

        texture = "heart.png",
    })

    return hp_change
end, true)