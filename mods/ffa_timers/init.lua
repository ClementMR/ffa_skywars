local players_timer = {}

local combat_timer = core.settings:get("combat_timer") or 8
local immunity_timer = core.settings:get("immunity_timer") or 14

local S = core.get_translator(core.get_current_modname())

local function is_immune(name)
    return players_timer[name] and players_timer[name].active == "immune"
end

local function is_fighting(name)
    return players_timer[name] and players_timer[name].active == "combat"
end

local function update_timer(player, timer, text, color, timer_name)
    if not player then
        return
    end

    local name = player:get_player_name()

    text = text or ""
    color = color or 0xFFFFFF
    timer_name = timer_name or ""

    hud_api.show(player, "ffa_timers:status", {
        type = "text",
        text = text.." ("..timer.."s)",
        number = color,
        position = {x = 0.5, y = 0.8},
        alignment = {x = 0, y = 0},
        size = {x = 1.1, y = 1.1},
        style = 1,
        z_index = 10,
    }, {background = true})

    if timer == 0 or player:get_hp() == 0 then
        players_timer[name] = nil
        hud_api.remove(player, "ffa_timers:status")

        return
    end

    players_timer[name] = core.after(1, update_timer, player, timer-1, text, color, timer_name)
    players_timer[name].active = timer_name
end

core.register_on_joinplayer(function(player)
    if core.is_creative_enabled(player:get_player_name()) then
        return
    end

    update_timer(player, immunity_timer, S("You are immune"), 0x42D3F2, "immune")
end)

core.register_on_respawnplayer(function(player)
    local name = player:get_player_name()
    if players_timer[name] ~= nil then
        players_timer[name]:cancel()
        update_timer(player, 0)
    end

    update_timer(player, immunity_timer, S("You are immune"), 0x42D3F2, "immune")
end)

core.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
    local name = hitter:get_player_name()

    if core.is_creative_enabled(name) then
        return false
    end

    local target_name = player:get_player_name()
    if is_immune(name) then
        players_timer[name]:cancel()
        update_timer(hitter, 0)
        core.chat_send_player(name, core.colorize("blue", S("[Immunity] ")).. S("Your immunity has been lifted!"))

        return false
    elseif is_immune(target_name) then
        core.chat_send_player(name, core.colorize("blue", S("[Immunity] ")).. S("Player @1 is immune!", target_name))
        --hitter:set_hp(hitter:get_hp()-0.5)

        return true
    end
end)

core.register_on_player_hpchange(function(player, hp_change, reason)
    local name = player:get_player_name()

    if core.is_creative_enabled(name) then
        return hp_change
    end

    if is_immune(name) and 
        (reason.type == "punch" or 
        reason.type == "fall" or 
        reason.type == "node_damage" or 
        reason.type == "set_hp") 
    then
        return 0
    end

    if reason.type == "punch"
        and reason.object
        and reason.object:is_player()
        and reason.object:get_player_name() ~= name
        and not players_timer[name]
    then
        update_timer(
            player,
            combat_timer,
            S("You are in combat"),
            0xFB2C36,
            "combat"
        )
    end

    return hp_change
end, true)

local function drop_armor(player)
    local name, armor_inv = armor:get_valid_player(player, "[on_leaveplayer]")
    if not name then return end

	local drop = {}
	for i=1, armor_inv:get_size("armor") do
		local stack = armor_inv:get_stack("armor", i)
		if stack:get_count() > 0 then
			table.insert(drop, stack)
			armor:run_callbacks("on_unequip", player, i, stack)
			armor_inv:set_stack("armor", i, nil)
		end
	end

    armor:remove_all(player)
	armor:save_armor_inventory(player)
	armor:set_player_armor(player)

	local pos = player:get_pos()
	if pos then
		for _,stack in ipairs(drop) do
			armor.drop_armor(pos, stack)
		end
	end
end

core.register_on_leaveplayer(function(player, timed_out)
    local name = player:get_player_name()

    local timer = players_timer[name]
    if timer then
        timer:cancel()
    end

    if is_fighting(name) then
        local inv = player:get_inventory()

        drop_armor(player)

        for _, list in ipairs({"main", "craft", "totem"}) do
            for _, stack in ipairs(inv:get_list(list) or {}) do
                if not stack:is_empty() then
                    core.add_item(player:get_pos(), stack)
                    inv:remove_item(list, stack)
                end
            end
        end
    end

    players_timer[name] = nil
end)

core.register_chatcommand("active", {
    params = "<player>",
    privs = {ffa_manager=true},
    func = function(name, param)
        if param ~= "" and core.get_player_by_name(param) then
            if players_timer[param] then
                local active = players_timer[param].active
                if active and active ~= "" then
                    return true, "Active timers for "..param..":\n- " .. active .. "\n"
                end
            end
        else
            local output = "Active timers:\n"
            for _, player in pairs(core.get_connected_players()) do
                local name = player:get_player_name()
                local active = players_timer[name] and players_timer[name].active
                if active then
                    output = output .. "[" .. name.. "]" .. " - " .. active .. "\n"
                end
            end

            return true, output
        end
    end
})

core.register_chatcommand("set_immunity", {
    params = "<player>",
    description = "",
    privs = {ffa_manager=true},
    func = function(name, param)
        local target_name = param
        local target_player = core.get_player_by_name(target_name)
        if target_name ~= "" and target_player then
            if players_timer[target_name] ~= nil then
                players_timer[target_name]:cancel()
                update_timer(target_player, 0)
            end

            update_timer(target_player, immunity_timer, S("You are immune"), 0x42D3F2, "immune")
        else
            return false, "Unable to find : " .. target_name
        end
    end
})

core.register_chatcommand("clear_immunity", {
    params = "<player>",
    description = "",
    privs = {ffa_manager=true},
    func = function(name, param)
        local target_name = param
        local target_player = core.get_player_by_name(target_name)
        if target_name ~= "" and target_player then
            if players_timer[target_name] ~= nil then
                players_timer[target_name]:cancel()
                update_timer(target_player, 0)
            end
        else
            return false, "Unable to find : " .. target_name
        end
    end
})