local players = {}

local ATTACH_POSITION = core.rgba and {x = 0, y = 20, z = 0} or {x = 0, y = 10, z = 0}

playertag = {}

local function add_entity_tag(player)
    if not player or not player:is_player() then
        return
    end

    local name = player:get_player_name()

    players[name] = players[name] or {}

	if players[name].entity then
        return
    end

    -- Hide fixed nametag
    player:set_nametag_attributes({color = {a = 0, r = 0, g = 0, b = 0}})

    local pos = player:get_pos()
    if not pos then
        return
    end

    local ent = core.add_entity(pos, "playertag:tag")

    if not ent then
        return
    end

    -- Build name from font texture
    local texture = "npcf_tag_bg.png"
    local x = math.floor(134 - ((#name * 11) / 2))
    local i = 0

    name:gsub(".", function(char)
        local n = "_"
        local byte = char:byte()

        if (byte > 96 and byte < 123)
            or (byte > 47 and byte < 58)
            or char == "-" then

            n = char

        elseif byte > 64 and byte < 91 then
            n = "U" .. char
        end

        texture = texture
            .. "^[combine:84x14:"
            .. (x + i)
            .. ",0=W_"
            .. n
            .. ".png"

        i = i + 11
    end)

    ent:set_properties({textures = {texture}})

    -- Attach to player
    ent:set_attach(player, "", ATTACH_POSITION, {x = 0, y = 0, z = 0})

    -- Store entity
    players[name].entity = ent
end

local function add_entity_tag_retry(player, attempts)
    if not player or not player:is_player() then
        return
    end

    local name = player:get_player_name()

    players[name] = players[name] or {}

    if players[name].entity then
        return
    end

    add_entity_tag(player)

    if not players[name].entity and attempts > 0 then
        core.after(0.5, function()
            add_entity_tag_retry(player, attempts - 1)
        end)
    end
end

function playertag.get(player)
    if not player then
        return nil
    end

    local name = player:get_player_name()
    local tag = players[name]

    return tag and tag.entity or nil
end

function playertag.get_all()
    return players
end

function playertag.remove(player)
    if not player then
        return
    end

    local name = player:get_player_name()
    local tag = players[name]

    if not tag or not tag.entity then
        return
    end

    local entity = tag.entity

    if entity then
        entity:remove()
    end

    tag.entity = nil
end

function playertag.update(player)
    if not player then
        return
    end

    playertag.remove(player)
    add_entity_tag(player)
end

core.register_entity("playertag:tag", {
    initial_properties = {
        visual = "sprite",
        visual_size = {
            x = 2.16,
            y = 0.18,
            z = 2.16
        },

        textures = {"blank.png"},

        physical = false,
        makes_footstep_sound = false,
        backface_culling = false,
        static_save = false,
        pointable = false,

        on_punch = function()
            return true
        end,
    }
})

if core.global_exists("armor") then
	armor:register_on_update(function(player, index, stack)
		add_entity_tag_retry(player, 0)
	end)
end

core.register_on_joinplayer(function(player)
    local name = player:get_player_name()

    players[name] = {}

    core.after(0.1, function()
        add_entity_tag_retry(player, 3)
    end)
end)

core.register_on_leaveplayer(function(player)
    local name = player:get_player_name()

    playertag.remove(player)

    players[name] = nil
end)