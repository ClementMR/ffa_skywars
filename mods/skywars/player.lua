local starter_list = {
    "default:sword_steel",
    "skywars:leaves 8",
}

function skywars.teleport_player(player, map_or_id)
    if not player then
        return false
    end

    local spawn = skywars.get_random_spawn(map_or_id)
    if not spawn then
        return false
    end

    player:set_pos(spawn)
    player:set_velocity({x = 0, y = 0, z = 0})
    return true
end

local function give_starter_items(player)
    for _, item in ipairs(starter_list) do
        player:get_inventory():add_item("main", item)
    end
end

core.register_on_newplayer(give_starter_items)

core.register_on_joinplayer(function(player)
    if core.is_creative_enabled(player:get_player_name()) then
        return
    end

    core.after(0, skywars.teleport_player, player)

    player:hud_set_flags({
        minimap = false,
        minimap_radar = false,
    })
end)

core.register_on_dieplayer(function(player)
    if core.is_creative_enabled(player:get_player_name()) then
        return
    end

    local player_inv = player:get_inventory()
    for _, list in ipairs({"main", "craft"}) do
        for _, stack in ipairs(player_inv:get_list(list)) do
            if not stack:is_empty() then
                core.add_item(player:get_pos(), stack)
                player_inv:remove_item(list, stack)
            end
        end
    end
end)

core.register_on_respawnplayer(function(player)
    core.after(0.1, skywars.teleport_player, player)

    if core.check_player_privs(player:get_player_name(), {creative=true}) then
        return
    end

    give_starter_items(player)
end)

core.register_on_placenode(function(pos, newnode, placer)
    if not placer or core.is_creative_enabled(placer:get_player_name()) then
        return
    end

    -- Players may only place blocks while they and the node are in the active
    -- map cuboid. The cleanup can therefore safely erase the whitelist there.
    if not skywars.is_position_in_map(placer:get_pos())
            or not skywars.is_position_in_map(pos) then
        core.remove_node(pos)
        return true
    end
end)

local timer
core.register_globalstep(function(dtime)
    timer = (timer or 0) + dtime
    if timer <= 2 then
        return
    end
    timer = 0
    for _, player in ipairs(core.get_connected_players()) do
        local pos = player:get_pos()
        local node_head = core.get_node({x = pos.x, y = pos.y + 1.625, z = pos.z}).name
        local ndef = core.registered_nodes[node_head]

        if (ndef.walkable == nil or ndef.walkable == true)
        and (ndef.collision_box == nil or ndef.collision_box.type == "regular")
        and (ndef.node_box == nil or ndef.node_box.type == "regular")
        and (node_head ~= "ignore")
        and (not core.check_player_privs(player:get_player_name(), {noclip=true})) then
            local hp = player:get_hp()
            if hp > 0 then
                player:set_hp(hp - 4)
            end
        end
    end
end)
