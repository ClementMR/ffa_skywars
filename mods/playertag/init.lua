local players = {}

local ATTACH_POSITION = core.rgba and {x = 0, y = 20, z = 0} or {x = 0, y = 10, z = 0}

playertag = {}

local function is_connected_player(player)
    if not player or not player:is_player() then
        return false
    end
    local name = player:get_player_name()
    return name ~= "" and core.get_player_by_name(name) == player
end

local function is_tag_entity(entity)
    if not entity then
        return false
    end
    local ok, luaentity = pcall(entity.get_luaentity, entity)
    return ok and luaentity and luaentity.name == "playertag:tag"
end

local function add_entity_tag(player, attempts)
    if not is_connected_player(player) then
        return
    end

    local name = player:get_player_name()

    players[name] = players[name] or {}

    if is_tag_entity(players[name].entity) then
        return
    end
    players[name].entity = nil

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
    local luaentity = ent:get_luaentity()
    if luaentity then
        luaentity.owner_name = name
    end
end

function playertag.get(player)
    local tag = players[player:get_player_name()]
    if tag and is_tag_entity(tag.entity) then
        return tag.entity
    end
    if tag then
        players[player:get_player_name()] = nil
    end
    return nil
end

function playertag.get_all()
    return players
end

function playertag.remove(player)
    local name = player:get_player_name()
    local tag = players[name]

    if tag and is_tag_entity(tag.entity) then
        tag.entity:remove()
    end
    players[name] = nil
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
    },
    owner_name = "",
    on_activate = function(self)
        self.object:set_armor_groups({immortal = 1})
    end,
    on_blast = function()
        return false, false, {}
    end,
    on_step = function(self)
        local parent = self.object:get_attach()
        if not parent or not parent:is_player() then
            self.object:remove()
            return
        end

        local name = parent:get_player_name()
        if name == "" or core.get_player_by_name(name) ~= parent
                or (self.owner_name ~= "" and self.owner_name ~= name) then
            self.object:remove()
            return
        end

        local entry = players[name]
        if entry and entry.entity and entry.entity ~= self.object then
            self.object:remove()
            return
        end

        players[name] = players[name] or {}
        players[name].entity = self.object
        self.owner_name = name
    end,
})

if core.global_exists("armor") then
	armor:register_on_update(function(player, index, stack)
		add_entity_tag(player)
	end)
end

core.register_on_joinplayer(function(player)
    players[player:get_player_name()] = {}

    core.after(0.1, function()
        local current_player = core.get_player_by_name(player:get_player_name())
        if current_player then
            add_entity_tag(current_player)
        end
    end)
end)

core.register_on_leaveplayer(function(player)
    playertag.remove(player)
end)
