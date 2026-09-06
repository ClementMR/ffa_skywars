local S = core.get_translator(core.get_current_modname())

local SHADOW_BURST_COOLDOWN = 12
local SHADOW_BURST_RADIUS = 5
local SHADOW_BURST_DAMAGE = 4

local function shadow_burst(itemstack, user)
    if not user or not user:is_player() then
        return itemstack
    end

    local name = user:get_player_name()
    local creative = core.is_creative_enabled(name)
    local origin = user:get_pos()
    if not origin or (not creative and not skywars.is_position_in_map(origin)) then
        core.chat_send_player(name, S("Void Burst can only be used in the active arena."))
        return itemstack
    end

    local cooldown_name = "skywars:shadow_void_burst"
    local remaining = cooldown.get(user, cooldown_name)
    if remaining > 0 then
        core.chat_send_player(name, S("Void Burst recharges in @1s.", math.ceil(remaining)))
        return itemstack
    end
    cooldown.set(user, cooldown_name, SHADOW_BURST_COOLDOWN)

    local eye = vector.offset(origin, 0, 1.5, 0)
    for _, target in ipairs(core.get_objects_inside_radius(origin, SHADOW_BURST_RADIUS)) do
        if target ~= user and target:is_player() and target:get_hp() > 0 then
            local target_pos = target:get_pos()
            local target_eye = target_pos and vector.offset(target_pos, 0, 1, 0)
            local in_arena = creative or (target_pos and skywars.is_position_in_map(target_pos))
            if target_eye and in_arena and core.line_of_sight(eye, target_eye) then
                local direction = vector.direction(origin, target_pos)
                target:punch(user, 1, {
                    full_punch_interval = 1,
                    damage_groups = {fleshy = SHADOW_BURST_DAMAGE},
                }, direction)
                target:add_velocity({
                    x = direction.x * 8,
                    y = 5,
                    z = direction.z * 8,
                })
            end
        end
    end

    core.add_particlespawner({
        amount = 48,
        time = 0.15,
        minpos = vector.subtract(origin, 1),
        maxpos = vector.add(origin, 1),
        minvel = {x = -5, y = 1, z = -5},
        maxvel = {x = 5, y = 6, z = 5},
        minexptime = 0.3,
        maxexptime = 0.8,
        minsize = 1,
        maxsize = 3,
        texture = "default_obsidian.png^[resize:8x8^[colorize:#7C3AED:170",
        glow = 5,
    })
    core.sound_play("grenades_explode", {
        pos = origin,
        gain = 0.35,
        max_hear_distance = 24,
    }, true)
    return itemstack
end

core.register_tool("skywars:sword_shadow", {
    description = core.colorize("#27272A", S("Shadow Sword")),
    inventory_image = "skywars_shadow_sword.png",
    wield_scale = {x = 1.2, y = 1, z = 1},
    range = 5.0,
    tool_capabilities = {
        full_punch_interval = 0.7,
        groupcaps = {
            snappy={times={[1]=1.90, [2]=0.90, [3]=0.30}, uses = 100, maxlevel = 3}
        },
        damage_groups = {fleshy = 12},
    },
	sound = {breaks = "default_tool_breaks"},
	groups = {sword = 1, sword_shadow = 1},
	_item_info = {
		ability = S("Void Burst (4 damage, 5-node radius)"),
		ability_cooldown = SHADOW_BURST_COOLDOWN,
	},
	on_secondary_use = shadow_burst,
	on_place = shadow_burst,
})

if core.get_modpath("visible_wielditem") then
	visible_wielditem.item_tweaks["groups"]["sword_shadow"] = {
		scale = 1.25
	}
end

core.register_on_mods_loaded(function()
    for name, def in pairs(core.registered_items) do
        if def and def.type == "node" then
            local recipes = core.get_all_craft_recipes(name)
            if recipes and #recipes > 0 then -- Check s'il y a bien des recettes
                core.clear_craft({output = name})
            end
        end
    end
end)
