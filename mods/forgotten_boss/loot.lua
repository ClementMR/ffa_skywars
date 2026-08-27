local boss = forgotten_boss

core.register_node("forgotten_boss:rift_block", {
    description = "Rift Block",
    tiles = {"default_obsidian.png^[colorize:#6D28D9:170"},
    light_source = 7,
    walkable = true,
    pointable = false,
    diggable = false,
    buildable_to = false,
    drop = "",
    groups = {not_in_creative_inventory = 1},
    on_blast = function()
        return {}
    end,
})

local function remove_rift_block(pos)
    if core.get_node(pos).name == "forgotten_boss:rift_block" then
        core.set_node(pos, {name = "air"})
    end
end

function boss.place_rift_blocks(center)
    local offsets = {
        {x = 1, z = 0},
        {x = -1, z = 0},
        {x = 0, z = 1},
        {x = 0, z = -1},
    }
    local base = vector.round(center)

    for _, offset in ipairs(offsets) do
        for y = 0, 1 do
            local pos = {
                x = base.x + offset.x,
                y = base.y + y,
                z = base.z + offset.z,
            }
            local node = core.get_node_or_nil(pos)
            local definition = node and core.registered_nodes[node.name]
            if definition and definition.buildable_to then
                core.set_node(pos, {name = "forgotten_boss:rift_block"})
                core.after(7, remove_rift_block, vector.new(pos))
            end
        end
    end
end

local rewards = {
    {name = "skywars:totem_of_undying", min = 1, max = 1, weight = 1},
    {name = "skywars:golden_apple", min = 1, max = 2, weight = 3},
    {name = "skywars:fireball", min = 2, max = 4, weight = 4},
    {name = "ctf_ranged:shotgun_loaded", min = 1, max = 1, weight = 2},
    {name = "ctf_ranged:rifle_loaded", min = 1, max = 1, weight = 2},
    {name = "default:mese_crystal", min = 2, max = 5, weight = 4},
    {name = "default:diamond", min = 1, max = 3, weight = 3},
}

local function reward_pool()
    local pool = {}
    for _, reward in ipairs(rewards) do
        if core.registered_items[reward.name] then
            for _ = 1, reward.weight do
                table.insert(pool, reward)
            end
        end
    end
    return pool
end

function boss.drop_rewards(pos)
    local pool = reward_pool()
    if #pool == 0 then
        return
    end

    for _ = 1, math.random(12, 16) do
        local reward = pool[math.random(#pool)]
        local drop_pos = vector.add(pos, {
            x = math.random(-7, 7),
            y = math.random(1, 3),
            z = math.random(-7, 7),
        })
        local item = core.add_item(drop_pos, ItemStack(reward.name .. " " .. math.random(reward.min, reward.max)))
        if item then
            item:set_velocity({
                x = math.random(-3, 3),
                y = math.random(3, 6),
                z = math.random(-3, 3),
            })
        end
    end
end
