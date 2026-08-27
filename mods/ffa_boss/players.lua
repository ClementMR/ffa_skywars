function ffa_boss.is_member(name)
    return ffa_boss.state.members[name] == true
end

function ffa_boss.join_player(player)
    if not player or not player:is_player() then
        return false, "Only online players can join the fight."
    end

    if not ffa_boss.state.active or ffa_boss.state.loot_phase or not ffa_boss.get_boss() then
        return false, "The Forgotten is not fighting right now."
    end

    local name = player:get_player_name()
    if ffa_boss.is_member(name) then
        return false, "You are already in the boss fight."
    end

    local max = ffa_boss.settings.max_players
    if ffa_boss.member_count() >= max then
        return false, string.format("The boss fight already has %d players.", max)
    end

    ffa_boss.state.members[name] = true
    player:set_pos(ffa_boss.get_position("player_spawn"))
    core.chat_send_player(player:get_player_name(), "You joined the fight against The Forgotten.")
    return true
end

function ffa_boss.return_all()
    local names = {}
    for name in pairs(ffa_boss.state.members) do
        table.insert(names, name)
    end

    for _, name in ipairs(names) do
        ffa_boss.state.members[name] = nil
        local player = core.get_player_by_name(name)
        if player and skywars and skywars.teleport_player then
            skywars.teleport_player(player)
        end
    end
end

core.register_on_joinplayer(function(player)
    local members_count = ffa_boss.member_count()
    local max_players = ffa_boss.settings.max_players

    if ffa_boss.state.active and not 
        ffa_boss.state.loot_phase and 
        members_count ~= max_players
    then
        core.chat_send_player(player:get_player_name(), core.colorize("#d66823", "[Boss] ") .. 
            "The Forgotten has appeared. Use " .. core.colorize("cyan", "/boss join") .. 
            " to fight it. Place left : " .. (max_players - members_count))
    end
end)

core.register_on_leaveplayer(function(player)
    ffa_boss.state.members[player:get_player_name()] = nil
end)

core.register_on_dieplayer(function(player)
    ffa_boss.state.members[player:get_player_name()] = nil
end)