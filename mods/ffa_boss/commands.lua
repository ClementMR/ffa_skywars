local function status()
    local state = ffa_boss.state.loot_phase and "loot" or ffa_boss.state.active and "active" or "idle"
    return ("Event: %s | Players: %d / %d")
        :format(
            state,
            ffa_boss.member_count(),
            ffa_boss.settings.max_players
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
            return ffa_boss.join_player(player)
        end
        if action == "status" then
            return true, status()
        end
        if not core.check_player_privs(name, {ffa_manager = true}) then
            return false, "You need the ffa_manager privilege."
        end
        if action == "boss_spawn" or action == "player_spawn" then
            ffa_boss.set_position(action, player:get_pos())
            return true, ("%s set to %s."):format(action, ffa_boss.position_text(ffa_boss.get_position(action)))
        end
        if action == "start" then
            return ffa_boss.start_event()
        end
        return false, "/boss boss_spawn | player_spawn | start | join | status"
    end,
})
