local boss = forgotten_boss

local function is_manager(name)
    return core.check_player_privs(name, {ffa_manager = true})
end

local function usage()
    return table.concat({
        "/boss enter | leave | status",
        "/boss pos1 | pos2 | entry | exit | spawn",
        "/boss open [seconds] | start | stop | ticket <player> [count] | players",
    }, "\n")
end

local function status_text()
    local state = boss.state.event_active and "active" or boss.state.event_open and "opening" or "closed"
    return ("Arena: %s | Event: %s | Players: %d\nConfigured: zone=%s entry=%s exit=%s spawn=%s")
        :format(
            boss.is_ready() and "ready" or "incomplete",
            state,
            boss.member_count(),
            boss.has_zone() and "yes" or "no",
            boss.get_position("entry") and "yes" or "no",
            boss.get_position("exit") and "yes" or "no",
            boss.get_position("spawn") and "yes" or "no"
        )
end

local function give_tickets(target, count)
    local stack = ItemStack("forgotten_boss:golden_ticket " .. count)
    local left = target:get_inventory():add_item("main", stack)
    if not left:is_empty() then
        core.add_item(target:get_pos(), left)
    end
end

core.register_chatcommand("boss", {
    params = "enter | leave | status | pos1 | pos2 | entry | exit | spawn | open [seconds] | start | stop | ticket <player> [count] | players",
    description = "Manage the Forgotten boss arena",
    func = function(name, param)
        local player = core.get_player_by_name(name)
        if not player then
            return false, "You need to be online."
        end

        local action, rest = param:match("^(%S*)%s*(.-)%s*$")
        action = action:lower()

        if action == "enter" then
            return boss.enter_player(player, true)
        end
        if action == "leave" then
            if boss.leave_player(player, "You left the Forgotten arena.") then
                return true, "You left the arena."
            end
            return false, "You are not in the arena."
        end
        if action == "status" then
            return true, status_text()
        end

        if not is_manager(name) then
            return false, "You need the ffa_manager privilege."
        end

        if action == "pos1" or action == "pos2" or action == "entry" or action == "exit" or action == "spawn" then
            boss.set_position(action, player:get_pos())
            return true, ("%s set to %s."):format(action, boss.position_text(boss.get_position(action)))
        end

        if action == "open" then
            local delay = tonumber(rest) or boss.settings.open_delay
            return boss.open_event(delay)
        end
        if action == "start" then
            return boss.start_event()
        end
        if action == "stop" then
            boss.stop_event()
            return true, "The Forgotten event was stopped."
        end
        if action == "ticket" then
            local target_name, count = rest:match("^(%S+)%s*(%d*)$")
            local target = target_name and core.get_player_by_name(target_name)
            count = tonumber(count) or 1
            if not target or count < 1 or count > 99 then
                return false, "Usage: /boss ticket <online player> [1-99]"
            end
            give_tickets(target, count)
            return true, ("Gave %d Golden Ticket(s) to %s."):format(count, target_name)
        end
        if action == "players" then
            local names = {}
            for member in pairs(boss.state.members) do
                table.insert(names, member)
            end
            table.sort(names)
            return true, #names > 0 and table.concat(names, ", ") or "No players are in the arena."
        end

        return false, usage()
    end,
})
