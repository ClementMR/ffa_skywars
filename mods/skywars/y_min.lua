local function update()
    if core.is_singleplayer() then return end

    for _, player in ipairs(core.get_connected_players()) do
        local pos = player:get_pos()
        if player and pos.y <= -100 and not
                core.check_player_privs(player, {creative=true}) then
            player:set_hp(0)
        end
    end

    core.after(5, update)
end


core.after(0.1, update)