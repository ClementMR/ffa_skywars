local S = core.get_translator(core.get_current_modname())

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
})

if core.get_modpath("visible_wielditem") then
	visible_wielditem.item_tweaks["groups"]["sword_shadow"] = {
		scale = 1.25
	}
end

local weapons = {
    "skywars:sword_shadow",
    "default:sword_diamond",
    "default:sword_mese",
    "default:sword_bronze",
    "default:sword_steel",
    "default:sword_stone",
    "default:sword_wood",
    "default:axe_diamond",
    "default:axe_mese",
    "default:axe_bronze",
    "default:axe_steel",
    "default:axe_stone",
    "default:axe_wood",
}

for _, item in pairs(weapons) do
    local def = core.registered_tools[item]
    local tc = def.tool_capabilities
    local dmg = tc.damage_groups.fleshy or 0
    local fpi = tc.full_punch_interval or 0
    local new_desc = def.description .. "\n" ..
        core.colorize("#808080",
            S("Damage @1@2Cooldown @3", dmg, "\n", string.format("%.2f", fpi))
        )

    core.override_item(item, {description = new_desc})
end

if core.get_modpath("3d_armor") then
    local pieces = {
        "3d_armor:helmet_",
        "3d_armor:chestplate_",
        "3d_armor:leggings_",
        "3d_armor:boots_",
        "shields:shield_"
    }

    for k, _ in pairs(armor.materials) do
        for _, piece in pairs(pieces) do
            local item = piece..k
            local def = core.registered_tools[item]
            if def then
                local protection = def.armor_groups.fleshy or 0
                local healing = def.groups.armor_heal or 0
                local new_desc = def.description ..
                    core.colorize("#808080",
                        S("@1Armor Protection @2@3Armor Healing @4", "\n", protection, "\n", healing)
                    )

                core.override_item(item, {description = new_desc})
            end
        end
    end
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