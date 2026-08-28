local timers = ffa_timers
local S = timers.S

function timers.get_state(name)
    local entry = timers.players[name]
    return entry and entry.active or nil
end

function timers.is_immune(name)
    return timers.get_state(name) == "immune"
end

function timers.is_in_combat(name)
    return timers.get_state(name) == "combat"
end

function timers.clear(player)
    if not player then
        return
    end

    local name = player:get_player_name()
    timers.players[name] = nil
    hud_api.remove(player, "ffa_timers:status")
end

function timers.set_status(player, seconds, text, color, active)
    if not player then
        return
    end

    if seconds <= 0 or player:get_hp() <= 0 then
        timers.clear(player)
        return
    end

    local name = player:get_player_name()
    hud_api.show(player, "ffa_timers:status", {
        type = "text",
        text = text .. " (" .. seconds .. "s)",
        number = color,
        position = {x = 0.5, y = 0.8},
        alignment = {x = 0, y = 0},
        size = {x = 1.1, y = 1.1},
        style = 1,
        z_index = 10,
    }, {background = true})

    local entry = {active = active}
    timers.players[name] = entry
    core.after(1, function()
        if timers.players[name] == entry then
            timers.set_status(player, seconds - 1, text, color, active)
        end
    end)
end

function timers.start_immunity(player)
    timers.set_status(player, timers.immunity_duration, S("You are immune"), 0x42D3F2, "immune")
end

core.register_on_joinplayer(function(player)
    if not core.is_creative_enabled(player:get_player_name()) then
        timers.start_immunity(player)
    end
end)

core.register_on_respawnplayer(function(player)
    timers.clear(player)
    if not core.is_creative_enabled(player:get_player_name()) then
        timers.start_immunity(player)
    end
end)

core.register_on_punchplayer(function(player, hitter)
    if not hitter or not hitter:is_player() then
        return
    end

    local hitter_name = hitter:get_player_name()
    local target_name = player:get_player_name()
    if core.is_creative_enabled(hitter_name) then
        return false
    end
    if timers.is_immune(hitter_name) then
        timers.clear(hitter)
        core.chat_send_player(hitter_name, core.colorize("blue", S("[Immunity] ")) .. S("Your immunity has been lifted!"))
        return false
    end
    if timers.is_immune(target_name) then
        core.chat_send_player(hitter_name, core.colorize("blue", S("[Immunity] ")) .. S("Player @1 is immune!", target_name))
        return true
    end
end)

core.register_on_player_hpchange(function(player, hp_change, reason)
    local name = player:get_player_name()
    if core.is_creative_enabled(name) then
        return hp_change
    end

    if timers.is_immune(name) and (reason.type == "punch" or reason.type == "fall"
            or reason.type == "node_damage" or reason.type == "set_hp") then
        return 0
    end
    return hp_change
end, true)

core.register_chatcommand("set_immunity", {
    params = "<player>",
    privs = {ffa_manager = true},
    func = function(_, param)
        local player = core.get_player_by_name(param)
        if not player then
            return false, "Unable to find: " .. param
        end
        timers.clear(player)
        timers.start_immunity(player)
        return true
    end,
})

core.register_chatcommand("clear_immunity", {
    params = "<player>",
    privs = {ffa_manager = true},
    func = function(_, param)
        local player = core.get_player_by_name(param)
        if not player then
            return false, "Unable to find: " .. param
        end
        timers.clear(player)
        return true
    end,
})
