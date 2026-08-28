local function status()
    local state = ffa_boss.state.loot_phase and "loot"
        or ffa_boss.state.starting and "preparing"
        or ffa_boss.get_boss() and "active"
        or ffa_boss.has_boss_block() and "loading"
        or "idle"
    return ("Event: %s | Players: %d / %d")
        :format(
            state,
            ffa_boss.member_count(),
            ffa_boss.settings.max_players
        )
end

core.register_chatcommand("boss", {
    params = "start | stop | join | leave | status",
    description = "",
    func = function(name, param)
        local player = core.get_player_by_name(name)
        if not player then
            return false, "You need to be online."
        end

        local action = (param:match("^%S+") or ""):lower()
        if action == "join" then
            return ffa_boss.join_player(player)
        end
        if action == "leave" then
            return ffa_boss.leave_player(player)
        end
        if action == "status" then
            return true, status()
        end
        if not core.check_player_privs(name, {ffa_manager = true}) then
            return false, "You need the ffa_manager privilege."
        end
        if action == "boss_spawn" or action == "player_spawn" then
            if ffa_boss.is_running() then
                return false, "Stop the event before changing its positions."
            end
            ffa_boss.set_position(action, player:get_pos())
            return true, ("%s set to %s."):format(action, ffa_boss.position_text(ffa_boss.get_position(action)))
        end
        if action == "start" then
            return ffa_boss.start_event()
        end
        if action == "stop" then
            ffa_boss.stop_event()
            core.chat_send_all(core.colorize("#d66823", "[Boss] ") .. "The Forgotten event is over.")
            return true
        end
        return false, "/boss start | stop | join | leave | status"
    end,
})
