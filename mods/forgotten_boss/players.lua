local boss = forgotten_boss

local function message(player, text)
    core.chat_send_player(player:get_player_name(), core.colorize("#C4B5FD", "[Forgotten] ") .. text)
end

function boss.is_member(name)
    return boss.state.members[name] == true
end

function boss.join_player(player)
    if not player or not player:is_player() then
        return false, "Only online players can join the fight."
    end
    if not boss.state.active or boss.state.loot_phase or not boss.get_boss() then
        return false, "The Forgotten is not fighting right now."
    end

    local name = player:get_player_name()
    if boss.is_member(name) then
        return false, "You are already in the boss fight."
    end
    if boss.member_count() >= boss.settings.max_players then
        return false, "The boss fight already has 10 players."
    end

    boss.state.members[name] = true
    player:set_pos(boss.get_position("player_spawn"))
    message(player, "You joined the fight against The Forgotten.")
    return true
end

function boss.return_all()
    local names = {}
    for name in pairs(boss.state.members) do
        table.insert(names, name)
    end

    for _, name in ipairs(names) do
        boss.state.members[name] = nil
        local player = core.get_player_by_name(name)
        if player and skywars and skywars.teleport_player then
            skywars.teleport_player(player)
            message(player, "The Forgotten event is over.")
        end
    end
end

core.register_on_leaveplayer(function(player)
    boss.state.members[player:get_player_name()] = nil
end)
