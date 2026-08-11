
--[[

Copyright (C) 2017 - Auke Kok <sofar@foo-projects.org>

"skybox" is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as
published by the Free Software Foundation; either version 2.1
of the license, or (at your option) any later version.

]]--

--
-- Builtin sky box textures and color/shadings, clouds
--

local skies = {
    {"DarkStormy", "#1f2226", 0.5, {density = 0.5, color = "#aaaaaae0", ambient = "#000000", height = 64, thickness = 32, speed = {x = 6, y = -6}}},
    {"CloudyLightRays", "#5f5f5e", 0.9, {density = 0.4, color = "#efe3d5d0", ambient = "#000000", height = 96, thickness = 24, speed = {x = 4, y = 0}}},
    {"FullMoon", "#24292c", 0.2, {density = 0.25, color = "#ffffff80", ambient = "#404040", height = 140, thickness = 8, speed = {x = -2, y = 2}}},
    {"SunSet", "#72624d", 0.4, {density = 0.2, color = "#f8d8e8e0", ambient = "#000000", height = 120, thickness = 16, speed = {x = 0, y = -2}}},
    {"ThickCloudsWater", "#a57850", 0.8, {density = 0.35, color = "#ebe4ddfb", ambient = "#000000", height = 80, thickness = 32, speed = {x = 4, y = 3}}},
    {"TropicalSunnyDay", "#f1f4ee", 1.0, {density = 0.25, color = "#fffffffb", ambient = "#000000", height = 120, thickness = 8, speed = {x = -2, y = 0}}},
}

skybox = {}

local storage = core.get_mod_storage()
local DEFAULT_INTERVAL = 3600
local rotation_enabled = storage:get_int("rotation_enabled") == 1
local rotation_interval = storage:get_int("rotation_interval")
local rotation_timer

if rotation_interval <= 0 then
    rotation_interval = DEFAULT_INTERVAL
end

local function apply_skybox(player, sky)
    if not player or not player:is_player() then
        return
    end

    player:override_day_night_ratio(sky[3])

    local textures = {
        sky[1] .. "Up.jpg",
        sky[1] .. "Down.jpg",
        sky[1] .. "Front.jpg",
        sky[1] .. "Back.jpg",
        sky[1] .. "Left.jpg",
        sky[1] .. "Right.jpg",
    }

    if player.get_sky_color ~= nil then
        player:set_sky({
            base_color = sky[2],
            type = "skybox",
            textures = textures,
            clouds = true
        })
        player:set_sun({visible = true, sunrise_visible = false, texture = "blank.png"})
        player:set_moon({visible = true, texture = "blank.png"})
        player:set_stars({visible = false})
    else
        player:set_sky(sky[2], "skybox", textures, true)
    end

    player:set_clouds(sky[4])
end

local function clear_skybox(player)
    if not player or not player:is_player() then
        return
    end

    player:override_day_night_ratio(nil)

    if player.get_sky_color ~= nil then
        player:set_sky({base_color = "white", type = "regular"})
    else
        player:set_sky("white", "regular")
    end

    player:set_clouds({
        density = 0.4,
        color = "#fff0f0e5",
        ambient = "#000000",
        height = 120,
        thickness = 16,
        speed = {x = 0, y = -2},
    })
    player:set_sun({visible = true, sunrise_visible = true, texture = ""})
    player:set_moon({visible = true, texture = ""})
    player:set_stars({visible = true})
end

local function get_global_skybox()
    local name = storage:get_string("skybox")

    if name == "" then
        return nil
    end

    for k, sky in ipairs(skies) do
        if sky[1] == name then
            return k, sky
        end
    end

    return nil
end

local function apply_to_all_players()
    local _, sky = get_global_skybox()

    for _, player in ipairs(core.get_connected_players()) do
        if sky then
            apply_skybox(player, sky)
        else
            clear_skybox(player)
        end
    end
end

local function set_random_skybox()
    if #skies == 0 then
        return
    end

    local number = math.random(1, #skies)
    local sky = skies[number]

    storage:set_string("skybox", sky[1])
    apply_to_all_players()

    core.log("action", "[skybox] Random skybox: " .. sky[1])
end

local function start_rotation_timer()
    if not rotation_enabled then
        return
    end

    if rotation_timer then
        rotation_timer:cancel()
        rotation_timer = nil
    end

    rotation_timer = core.after(rotation_interval, function()
        rotation_timer = nil

        if not rotation_enabled then
            return
        end

        set_random_skybox()
        start_rotation_timer()
    end)
end

local function start_rotation()
    rotation_enabled = true
    storage:set_int("rotation_enabled", 1)
    storage:set_int("rotation_interval", rotation_interval)

    set_random_skybox()
    start_rotation_timer()
end

local function stop_rotation()
    rotation_enabled = false
    storage:set_int("rotation_enabled", 0)

    if rotation_timer then
        rotation_timer:cancel()
        rotation_timer = nil
    end

    storage:set_string("skybox", "")
    apply_to_all_players()
end

skybox.set = function(player, number)
    local sky = skies[number]

    if not sky then
        return false
    end

    storage:set_string("skybox", sky[1])
    apply_to_all_players()

    return true
end

skybox.clear = function(player)
    stop_rotation()
    return true
end

skybox.add = function(def)
    table.insert(skies, def)
end

skybox.get_skies = function()
    return table.copy(skies)
end

skybox.restore = function(player)
    local _, sky = get_global_skybox()

    if sky then
        apply_skybox(player, sky)
    else
        clear_skybox(player)
    end
end

core.register_on_joinplayer(function(player)
    core.after(0, function()
        if player and player:is_player() then
            skybox.restore(player)
        end
    end)
end)

core.register_on_mods_loaded(function()
    math.randomseed(os.time())

    if rotation_enabled then
        start_rotation_timer()
    end
end)

core.register_privilege("skybox", {
    description = "Change the server sky box",
})

core.register_chatcommand("skybox", {
    params = "[number|name|random [seconds]|off]",
    description = "Change the server sky box",
    privs = {skybox = true},

    func = function(name, param)
        param = param:trim()

        if param == "" then
            core.chat_send_player(name, "Available sky boxes:")

            for k, v in ipairs(skies) do
                core.chat_send_player(name, k .. " - " .. v[1])
            end

            if rotation_enabled then
                core.chat_send_player(name, "Automatic rotation: ON (" .. rotation_interval .. " seconds)")
            else
                core.chat_send_player(name, "Automatic rotation: OFF")
            end

            return true
        end

        if param == "off" or param == "0" then
            stop_rotation()
            core.chat_send_all("[Skybox] Automatic rotation disabled. Skybox reset to default.")
            return true
        end

        local command, interval = param:match("^(%S+)%s*(%d*)$")

        if command == "random" then
            if interval ~= "" then
                interval = tonumber(interval)

                if not interval or interval < 1 then
                    core.chat_send_player(name, "Invalid interval.")
                    return false
                end

                rotation_interval = math.floor(interval)
                storage:set_int("rotation_interval", rotation_interval)
            end

            start_rotation()

            core.chat_send_all(
                "[Skybox] Automatic rotation enabled. Interval: "
                .. rotation_interval .. " seconds."
            )

            return true
        end

        local number = tonumber(param)

        if number then
            number = math.floor(number)

            if number >= 1 and number <= #skies then
                storage:set_string("skybox", skies[number][1])
                apply_to_all_players()

                core.chat_send_all("[Skybox] Changed to " .. skies[number][1] .. ".")
                return true
            end
        end

        for k, sky in ipairs(skies) do
            if sky[1] == param then
                storage:set_string("skybox", sky[1])
                apply_to_all_players()

                core.chat_send_all("[Skybox] Changed to " .. sky[1] .. ".")
                return true
            end
        end

        core.chat_send_player(name, "Could not find that sky box.")
        return false
    end,
})