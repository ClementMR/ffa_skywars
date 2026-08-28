ffa_boss.settings = {
    max_hp = 1000,
    max_players = 10,
    reward_time = 30,
    idle_regen_delay = 30,
    idle_regen_per_second = 1,
    arena_radius = 40,
    arena_height = 40
}

local position_keys = {
    "boss_spawn",
    "player_spawn",
}

local function is_position_key(key)
    for _, valid_key in ipairs(position_keys) do
        if valid_key == key then
            return true
        end
    end
    return false
end

local function clean_position(pos)
    if type(pos) ~= "table" then
        return nil
    end

    local x = tonumber(pos.x)
    local y = tonumber(pos.y)
    local z = tonumber(pos.z)
    if not x or not y or not z then
        return nil
    end

    return vector.round({x = x, y = y, z = z})
end

local function load_config()
    local saved = core.deserialize(ffa_boss.storage:get_string("config"))
    local config = {}

    if type(saved) == "table" then
        for _, key in ipairs(position_keys) do
            config[key] = clean_position(saved[key])
        end
    end

    return config
end

ffa_boss.config = load_config()

function ffa_boss.save_config()
    ffa_boss.storage:set_string("config", core.serialize(ffa_boss.config))
end

function ffa_boss.set_position(key, pos)
    if not is_position_key(key) then
        return false
    end

    ffa_boss.config[key] = clean_position(pos)
    ffa_boss.save_config()
    return true
end

function ffa_boss.get_position(key)
    local pos = ffa_boss.config[key]
    return pos and vector.new(pos) or nil
end

function ffa_boss.is_inside_arena(pos)
    local spawn = ffa_boss.get_position("boss_spawn")
    if not spawn or not pos then
        return false
    end

    local x = pos.x - spawn.x
    local z = pos.z - spawn.z
    return x * x + z * z <= ffa_boss.settings.arena_radius ^ 2
        and math.abs(pos.y - spawn.y) <= ffa_boss.settings.arena_height
end

function ffa_boss.is_ready()
    return ffa_boss.config.boss_spawn and ffa_boss.config.player_spawn
end

function ffa_boss.position_text(pos)
    return ("(%d, %d, %d)"):format(pos.x, pos.y, pos.z)
end

function ffa_boss.member_count()
    local count = 0
    for _ in pairs(ffa_boss.state.members) do
        count = count + 1
    end
    return count
end
