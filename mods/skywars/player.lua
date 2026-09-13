local starter_list = {
    "default:sword_steel",
    "skywars:leaves 8",
}

function skywars.teleport_player(player)
    if not player then
        return false
    end

    local spawn = skywars.get_random_spawn(skywars.get_current_map_id())
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
    core.after(0.1, skywars.teleport_player, player)

    -- Override the hotbar
    player:hud_set_hotbar_itemcount(9)
    player:hud_set_hotbar_image("gui_hotbar_9_slots.png")

    if core.is_creative_enabled(player:get_player_name()) then
        return
    end

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
    for _, list in ipairs({"main", "craft", "totem"}) do
        for _, stack in ipairs(player_inv:get_list(list) or {}) do
            if not stack:is_empty() then
                core.add_item(player:get_pos(), stack)
                player_inv:remove_item(list, stack)
            end
        end
    end
end)

core.register_on_respawnplayer(function(player)
    core.after(0.1, skywars.teleport_player, player)
end)

local old_is_protected = core.is_protected

core.is_protected = function(pos, name)
    if core.is_creative_enabled(name) then
        return false
    end

    if not skywars.is_position_in_map(pos) then
        return true
    end

    return old_is_protected(pos, name)
end