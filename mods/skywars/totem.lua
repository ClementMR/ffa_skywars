local S = core.get_translator(core.get_current_modname())

core.register_craftitem("skywars:totem_of_undying", {
    description = core.colorize("#b1b10e", S("Totem of Undying")),
    inventory_image = "skywars_totem_of_undying.png",
    stack_max = 1,
})

local function show_totem_hud(player)
    hud_api.show(player, "skywars:totem", {
        type = "image",
        position = {x = 0.5, y = 0.37},
        text = "totem_of_undying.png",
        scale = {x = 8, y = 8},
        alignment = {x = 0, y = 0},
    }, {duration = 2})
end

local function revive_player(player)
    local hp = player:get_hp()
    local pos = player:get_pos()
    local player_name = player:get_player_name()

    if hp <= 0 then
        player:set_hp(5)
        core.log("action", "[Undying-Totem] Player: " .. player_name ..
            " used of skywars:totem_of_undying and brought back to life with 3 hp")
    end

    show_totem_hud(player)

    core.add_particlespawner({
        amount = 40,
        time = 0.1,
        minpos = {x = pos.x - 0.3, y = pos.y + 1, z = pos.z - 0.3},
        maxpos = {x = pos.x + 0.3, y = pos.y + 1.2, z = pos.z + 0.3},
        minvel = {x = -4, y = -1, z = -4},
        maxvel = {x = 4, y = 6, z = 4},
        minacc = {x = 0, y = -9.81, z = 0},
        maxacc = {x = 0, y = -9.81, z = 0},
        minexptime = 1.5,
        maxexptime = 3.0,
        minsize = 2,
        maxsize = 6,
        texture = "totem_of_undying.png",
        glow = 14,
    })

    if core.sound_play then
        core.sound_play("default_place_node_metal", {
            pos = pos,
            gain = 1.0,
            pitch = 1.5,
        })
    end
end

core.register_playerevent(function(player, eventname)
    if eventname == "health_changed" then
        local inv = player:get_inventory()
        local hp = player:get_hp()
        if hp <= 0 then
            local totem = inv:get_stack("totem", 1)
            if totem:get_name() == "skywars:totem_of_undying" then
                revive_player(player)
                inv:set_stack("totem", 1, ItemStack())
                local inventory_api = rawget(_G, "ffa_inventory")
                if inventory_api and inventory_api.refresh_totem_visual then
                    inventory_api.refresh_totem_visual(player)
                end
            end
        end
    end
end)
