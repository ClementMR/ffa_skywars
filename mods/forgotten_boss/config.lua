local boss = forgotten_boss

boss.settings = {
    max_hp = 850,
    max_players = 10,
    reward_time = 60,
    idle_regen_delay = 12,
    idle_regen_per_second = 1,
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
    local saved = core.deserialize(boss.storage:get_string("config"))
    local config = {}

    if type(saved) == "table" then
        for _, key in ipairs(position_keys) do
            config[key] = clean_position(saved[key])
        end
    end

    return config
end

boss.config = load_config()

function boss.save_config()
    boss.storage:set_string("config", core.serialize(boss.config))
end

function boss.set_position(key, pos)
    if not is_position_key(key) then
        return false
    end

    boss.config[key] = clean_position(pos)
    boss.save_config()
    return true
end

function boss.get_position(key)
    local pos = boss.config[key]
    return pos and vector.new(pos) or nil
end

function boss.is_ready()
    return boss.config.boss_spawn and boss.config.player_spawn
end

function boss.position_text(pos)
    return ("(%d, %d, %d)"):format(pos.x, pos.y, pos.z)
end

function boss.member_count()
    local count = 0
    for _ in pairs(boss.state.members) do
        count = count + 1
    end
    return count
end
