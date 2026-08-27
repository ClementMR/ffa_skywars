local boss = forgotten_boss
boss.huds = {}

local function remove_huds(player)
    local huds = boss.huds[player:get_player_name()]
    if not huds then
        return
    end

    for _, id in pairs(huds) do
        player:hud_remove(id)
    end
    boss.huds[player:get_player_name()] = nil
end

function boss.show_hud(player)
    local name = player:get_player_name()
    if boss.huds[name] then
        return
    end

    boss.huds[name] = {
        label = player:hud_add({
            hud_elem_type = "text",
            position = {x = 0.5, y = 0.075},
            offset = {x = 0, y = 0},
            alignment = {x = 0, y = 0},
            text = core.colorize("#C084FC", "THE FORGOTTEN"),
            number = 0xFFFFFF,
            z_index = 100,
        }),
        bar = player:hud_add({
            hud_elem_type = "statbar",
            position = {x = 0.5, y = 0.075},
            offset = {x = -220, y = 22},
            alignment = {x = 0, y = 0},
            text = "default_obsidian.png^[colorize:#7C3AED:180",
            number = 20,
            item = 20,
            direction = 0,
            size = {x = 22, y = 18},
            z_index = 100,
        }),
    }
end

function boss.hide_hud(player)
    remove_huds(player)
end

function boss.update_hud(player, hp, max_hp)
    boss.show_hud(player)
    local huds = boss.huds[player:get_player_name()]
    if not huds then
        return
    end

    local amount = math.max(0, math.min(20, math.ceil(hp / max_hp * 20)))
    player:hud_change(huds.label, "text", core.colorize("#C084FC", ("THE FORGOTTEN  %d / %d HP"):format(hp, max_hp)))
    player:hud_change(huds.bar, "number", amount)
end

function boss.update_all_huds(hp, max_hp)
    for name in pairs(boss.state.members) do
        local player = core.get_player_by_name(name)
        if player then
            boss.update_hud(player, hp, max_hp)
        end
    end
end

core.register_on_leaveplayer(remove_huds)
