hud_api = {
    huds = {} -- Store HUDs
}

function hud_api.show_front(player, text, color, style)
    if not player then return end

    local name = string.lower(player:get_player_name())
    local id = "hud_api:" .. name .. "_front"

    text = text or ""

    if hud_api.huds[id] then
        player:hud_change(hud_api.huds[id], "text", text)
    else
        -- bg
        hud_api.huds[id .. "_bg"] = player:hud_add({
            type = "image",
            text = "hud_api_hud_bg.png",
            scale = {x = 5, y = 3},
            position = {x = 0.5, y = 0.3},
            z_index = 0
        })

        hud_api.huds[id] = player:hud_add({
            type = "text",
            text = text,
            number = color or 0xFFFFFF,
            size = {x = 2, y = 2},
            position = {x =  0.5, y = 0.3},
            z_index = 100,
            style = style or 0
        })
    end
end

function hud_api.show_actionbar(player, text, color, style)
    if not player then return end

    local name = string.lower(player:get_player_name())
    local id = "hud_api:" .. name .. "_actionbar"

    text = text or ""

    if hud_api.huds[id] then
        player:hud_change(hud_api.huds[id], "text", text)
    else
        -- bg
        hud_api.huds[id .. "_bg"] = player:hud_add({
            type = "image",
            text = "hud_api_hud_bg.png",
            scale = {x = 1.4, y = 1.4},
            position = {x = 0.5, y = 0.8},
            z_index = 0
        })

        hud_api.huds[id] = player:hud_add({
            type = "text",
            text = text,
            number = color or 0xFFFFFF,
            size = {x = 1.1, y = 1.1},
            position = {x =  0.5, y = 0.8},
            z_index = 100,
            style = style or 0
        })
    end
end

function hud_api.get(player, hud_type)
    local name = string.lower(player:get_player_name())
    if not hud_type then hud_type = "front" end
    local id = "hud_api:" .. name .. "_" .. hud_type

    for k, _ in pairs(hud_api.huds) do
        if string.find(k, id) then
            return true
        end
    end

    return false
end

function hud_api.remove(player, hud_type)
    local name = string.lower(player:get_player_name())
    if not hud_type then hud_type = "front" end
    local id = "hud_api:" .. name .. "_" .. hud_type

    for k, _ in pairs(hud_api.huds) do
        if string.find(k, id) then
            player:hud_remove(hud_api.huds[k])
            hud_api.huds[k] = nil
        end
    end
end

function hud_api.remove_all(player)
    local name = string.lower(player:get_player_name())
    for k, _ in pairs(hud_api.huds) do
        if string.find(k, "hud_api:" .. name) then
            player:hud_remove(hud_api.huds[k])
            hud_api.huds[k] = nil
        end
    end
end

core.register_on_leaveplayer(function(player)
    local name = string.lower(player:get_player_name())
    for k, _ in pairs(hud_api.huds) do
        if string.find(k, "hud_api:" .. name) then
            hud_api.huds[k] = nil
        end
    end
end)