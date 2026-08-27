local boss = forgotten_boss
local pending_key = "forgotten_boss:return_pending"

local function message(player, text)
    core.chat_send_player(player:get_player_name(), core.colorize("#C4B5FD", "[Forgotten] ") .. text)
end

function boss.is_member(name)
    return boss.state.members[name] == true
end

function boss.enter_player(player, take_ticket)
    if not player or not player:is_player() then
        return false, "Only online players can enter the arena."
    end

    if not boss.is_ready() then
        return false, "The arena has not been configured yet."
    end

    if not boss.state.event_open and not boss.state.event_active then
        return false, "The arena is closed. Wait for the next announcement."
    end

    local name = player:get_player_name()
    if boss.is_member(name) then
        return false, "You are already in the arena."
    end

    if take_ticket then
        local inventory = player:get_inventory()
        local ticket = ItemStack("forgotten_boss:golden_ticket")
        if not inventory:contains_item("main", ticket) then
            return false, "You need a Golden Ticket to enter."
        end
        inventory:remove_item("main", ticket)
    end

    boss.state.members[name] = true
    player:get_meta():set_string(pending_key, "")
    player:set_pos(boss.get_position("entry"))
    boss.show_hud(player)
    message(player, "You entered the arena. Use /boss leave to leave at any time.")
    return true
end

function boss.leave_player(player, reason)
    if not player or not player:is_player() then
        return false
    end

    local name = player:get_player_name()
    local was_member = boss.is_member(name)
    boss.state.members[name] = nil
    player:get_meta():set_string(pending_key, "")
    boss.hide_hud(player)

    local exit = boss.get_position("exit")
    if exit and was_member then
        player:set_pos(exit)
    end

    if was_member and reason then
        message(player, reason)
    end
    return was_member
end

function boss.return_all(reason)
    local names = {}
    for name in pairs(boss.state.members) do
        table.insert(names, name)
    end

    for _, name in ipairs(names) do
        local player = core.get_player_by_name(name)
        if player then
            boss.leave_player(player, reason)
        else
            boss.state.members[name] = nil
        end
    end
end

core.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if boss.is_member(name) then
        player:get_meta():set_string(pending_key, "1")
        boss.state.members[name] = nil
        boss.hide_hud(player)
    end
end)

core.register_on_joinplayer(function(player)
    core.after(0.2, function()
        if not player:is_player() then
            return
        end

        if player:get_meta():get_string(pending_key) ~= "1" then
            return
        end

        player:get_meta():set_string(pending_key, "")
        local exit = boss.get_position("exit")
        if exit then
            player:set_pos(exit)
        end
        message(player, "You left the Forgotten arena while disconnected.")
    end)
end)
