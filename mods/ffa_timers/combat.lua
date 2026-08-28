local timers = ffa_timers
local S = timers.S

function timers.start_combat(player)
    timers.set_status(player, timers.combat_duration, S("You are in combat"), 0xFB2C36, "combat")
end

core.register_on_player_hpchange(function(player, hp_change, reason)
    if hp_change >= 0 or reason.type ~= "punch" or not reason.object
            or not reason.object:is_player() then
        return hp_change
    end

    local name = player:get_player_name()
    if reason.object:get_player_name() ~= name and not core.is_creative_enabled(name) then
        timers.start_combat(player)
    end
    return hp_change
end, true)

local function drop_armor(player)
    local name, inventory = armor:get_valid_player(player, "[on_leaveplayer]")
    if not name then
        return
    end

    local drops = {}
    for index = 1, inventory:get_size("armor") do
        local stack = inventory:get_stack("armor", index)
        if not stack:is_empty() then
            table.insert(drops, stack)
            armor:run_callbacks("on_unequip", player, index, stack)
            inventory:set_stack("armor", index, nil)
        end
    end

    armor:remove_all(player)
    armor:save_armor_inventory(player)
    armor:set_player_armor(player)

    local pos = player:get_pos()
    if pos then
        for _, stack in ipairs(drops) do
            armor.drop_armor(pos, stack)
        end
    end
end

core.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    local was_in_combat = timers.is_in_combat(name)
    timers.clear(player)
    if not was_in_combat then
        return
    end

    local inventory = player:get_inventory()
    drop_armor(player)
    for _, list in ipairs({"main", "craft", "totem"}) do
        for _, stack in ipairs(inventory:get_list(list) or {}) do
            if not stack:is_empty() then
                core.add_item(player:get_pos(), stack)
                inventory:remove_item(list, stack)
            end
        end
    end
end)

core.register_chatcommand("active", {
    params = "<player>",
    privs = {ffa_manager = true},
    func = function(_, param)
        if param ~= "" then
            local state = timers.get_state(param)
            return true, state and ("Active timer for " .. param .. ": " .. state) or "No active timer."
        end

        local lines = {}
        for _, player in ipairs(core.get_connected_players()) do
            local name = player:get_player_name()
            local state = timers.get_state(name)
            if state then
                table.insert(lines, name .. " - " .. state)
            end
        end
        return true, #lines > 0 and table.concat(lines, "\n") or "No active timers."
    end,
})
