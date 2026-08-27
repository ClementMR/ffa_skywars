local boss = forgotten_boss

local function is_manager(name)
    return core.check_player_privs(name, {ffa_manager = true})
end

local function status()
    local state = boss.state.loot_phase and "loot" or boss.state.active and "active" or "idle"
    return ("Event: %s | Players: %d / %d | Boss spawn: %s | Player spawn: %s")
        :format(
            state,
            boss.member_count(),
            boss.settings.max_players,
            boss.get_position("boss_spawn") and "set" or "missing",
            boss.get_position("player_spawn") and "set" or "missing"
        )
end

core.register_chatcommand("boss", {
    params = "boss_spawn | player_spawn | start | join | status",
    description = "Manage The Forgotten boss event",
    func = function(name, param)
        local player = core.get_player_by_name(name)
        if not player then
            return false, "You need to be online."
        end

        local action = (param:match("^%S+") or ""):lower()
        if action == "join" then
            return boss.join_player(player)
        end
        if action == "status" then
            return true, status()
        end
        if not is_manager(name) then
            return false, "You need the ffa_manager privilege."
        end
        if action == "boss_spawn" or action == "player_spawn" then
            boss.set_position(action, player:get_pos())
            return true, ("%s set to %s."):format(action, boss.position_text(boss.get_position(action)))
        end
        if action == "start" then
            return boss.start_event()
        end
        return false, "/boss boss_spawn | player_spawn | start | join | status"
    end,
})
