local visible_bars = {}

local function get_player_settings(p_name)
    return {
        background_opacity = 55,
        length = 60,
        thickness = 1
    }
end

local function show_indicator(p_name, duration)
    local player = core.get_player_by_name(p_name)
    local s = get_player_settings(p_name)

    if visible_bars[p_name] then
        local v = visible_bars[p_name]
        player:hud_remove(v.fg_hud)
        player:hud_remove(v.bg_hud)
        visible_bars[p_name] = nil
    end

    visible_bars[p_name] = {
        start_time = core.get_us_time() / 1000000,
        duration = duration
    }

    visible_bars[p_name].bg_hud = player:hud_add({
        type = "image",
        position = {x = 0.5, y = 0.5},
        offset = {x = 0, y = 19 + s.thickness},
        text = "pii_black.png^[opacity:" .. s.background_opacity / 100 * 255,
        scale = {x = s.length - 1, y = s.thickness}, -- a pixel shorter to prevent visual glitches
    })

    visible_bars[p_name].fg_hud = player:hud_add({
        type = "image",
        position = {x = 0.5, y = 0.5},
        offset = {x = 0, y = 19 + s.thickness},
        text = "pii_white.png",
        scale = {x = 0, y = 0},
    })
end

core.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
    if not hitter or not hitter:is_player() then
        return
    end

    show_indicator(hitter:get_player_name(), tool_capabilities.full_punch_interval)
end)

core.register_globalstep(function(dtime)
    for p_name, v in pairs(visible_bars) do        
        local player = core.get_player_by_name(p_name)
        local current_time = core.get_us_time() / 1000000
    
        if not player then
            visible_bars[p_name] = nil
        elseif current_time >= v.start_time + v.duration then
            player:hud_remove(v.fg_hud)
            player:hud_remove(v.bg_hud)
            visible_bars[p_name] = nil
        else
            local s = get_player_settings(p_name)
            local length = (current_time - v.start_time) / v.duration * s.length
            player:hud_change(v.fg_hud, "offset", {x = (length - s.length) * 0.5, y = 19 + s.thickness})
            player:hud_change(v.fg_hud, "scale", {x = length, y = s.thickness})    
        end
    end
end)