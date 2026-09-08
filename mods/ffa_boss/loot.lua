local rewards = {
    {name = "default:apple", min = 6, max = 14, weight = 10},
    {name = "tnt:tnt", min = 1, max = 4, weight = 5},
    {name = "ctf_ranged:shotgun_loaded", min = 1, max = 1, weight = 3},
    {name = "ctf_ranged:smg_loaded", min = 1, max = 1, weight = 3},
    {name = "throwables:ender_pearl", min = 1, max = 3, weight = 4},
    {name = "throwables:wind_pearl", min = 1, max = 3, weight = 4},
    {name = "skywars:golden_apple", min = 1, max = 2, weight = 3},
    {name = "ffa_loot:diamond_key", min = 1, max = 1, weight = 3},
    {name = "skywars:totem_of_undying", min = 1, max = 1, weight = 2},
    {name = "skywars:sword_shadow", min = 1, max = 1, weight = 1},
    {name = "3d_armor:helmet_shadow", min = 1, max = 1, weight = 1},
    {name = "3d_armor:chestplate_diamond", min = 1, max = 1, weight = 1},
    {name = "3d_armor:leggings_diamond", min = 1, max = 1, weight = 1},
    {name = "shields:shield_diamond", min = 1, max = 1, weight = 1},
    {name = "3d_armor:boots_shadow", min = 1, max = 1, weight = 1},
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

function ffa_boss.drop_rewards(pos)
    local pool = reward_pool()
    if #pool == 0 then
        return
    end

    for _ = 1, math.random(15, 20) do
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
