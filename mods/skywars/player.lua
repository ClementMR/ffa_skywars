local positions = {
    -- North
    {x = 9959, y = 307, z = 4889},
    {x = 9966, y = 307, z = 4889},
    {x = 9952, y = 307, z = 4889},
    {x = 9959, y = 307, z = 4882},
    -- East
    {x = 9981, y = 307, z = 4867},
    {x = 9981, y = 307, z = 4860},
    {x = 9981, y = 307, z = 4874},
    {x = 9974, y = 307, z = 4867},
    -- South
    {x = 9959, y = 307, z = 4845},
    {x = 9952, y = 307, z = 4845},
    {x = 9966, y = 307, z = 4845},
    {x = 9959, y = 307, z = 4852},
    -- West
    {x = 9937, y = 307, z = 4867},
    {x = 9937, y = 307, z = 4874},
    {x = 9937, y = 307, z = 4860},
    {x = 9944, y = 307, z = 4867},
}

local starter_list = {
    "default:sword_steel",
    "skywars:leaves 8"
}

function skywars.teleport_player(player)
    player:set_pos(positions[math.random(#positions)])
end

core.register_on_newplayer(function(player)
    for _, item in ipairs(starter_list) do
        player:get_inventory():add_item("main", item)
    end
end)

core.register_on_joinplayer(function(player)
    if core.is_creative_enabled(player:get_player_name()) then
        return
    end

    skywars.teleport_player(player)

    player:hud_set_flags({
        minimap = false,
        minimap_radar = false
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
    -- Override static spawnpoint
    core.after(0.1, skywars.teleport_player, player)

    local name = player:get_player_name()
    if core.check_player_privs(name, {creative=true}) then
        return
    end

    for _, item in ipairs(starter_list) do
        player:get_inventory():add_item("main", item)
    end
end)

core.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if core.is_creative_enabled(placer:get_player_name()) then
        return
    end

    for _, obj in ipairs(core.get_objects_inside_radius(skywars.map_center, skywars.radius-5)) do
        if placer == obj then
            return false
        end
    end

    core.remove_node(pos)
    return true
end)

local timer
core.register_globalstep(function(dtime)
    timer = (timer or 0) + dtime
    if timer > 2 then
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
    end
end)
