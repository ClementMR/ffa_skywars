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