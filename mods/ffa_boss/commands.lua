local function status()
    local state = ffa_boss.state.loot_phase and "loot"
        or ffa_boss.get_boss() and "active"
        or "idle"
    return ffa_boss.S("Event: @1 | Players: @2 / @3", 
            state,
            ffa_boss.member_count(),
            ffa_boss.settings.max_players
        )
end

core.register_chatcommand("boss", {
    params = "start | stop | join | leave | status | boss_spawn | player_spawn",
    description = "",
    func = function(name, param)
        local player = core.get_player_by_name(name)
        local action = (param:match("^%S+") or ""):lower()

        if player and action == "join" then
            return ffa_boss.join_player(player)
        end

        if player and action == "leave" then
            return ffa_boss.leave_player(player)
        end

        if action == "status" then
            return true, status()
        end

        if not core.check_player_privs(name, {ffa_manager = true}) then
            return false, ffa_boss.S("You need the ffa_manager privilege.")
        end

        if player and action == "boss_spawn" or action == "player_spawn" then
            if ffa_boss.is_running() then
                return false, ffa_boss.S("Stop the event before changing its positions.")
            end
            ffa_boss.set_position(action, player:get_pos())
            return true, ffa_boss.S("@1 set to @2.", action, ffa_boss.position_text(ffa_boss.get_position(action)))
        end

        if action == "start" then
            return ffa_boss.start_event()
        end

        if action == "stop" then
            ffa_boss.stop_event()
            ffa_boss.broadcast(ffa_boss.S("The Forgotten event is over."))
            return true
        end

        return false, "/boss start | stop | join | leave | status | boss_spawn | player_spawn"
    end,
})
