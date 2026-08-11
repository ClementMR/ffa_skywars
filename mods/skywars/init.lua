skywars = {}

skywars.map_center = core.settings:get_pos("static_spawnpoint") or {x=9959, y=300, z=4867}
skywars.radius = 100

local modpath = core.get_modpath(core.get_current_modname())

local files = {
    "cooldown",
    "player",
    "y_min",
    "nodes",
    "golden_apple",
    "items",
    "fireball",
    "totem",
    "cleanup",
    "entities",
    "vanish",
    "commands"
}

for _, file in ipairs(files) do
    dofile(modpath.."/"..file..".lua")
end

core.hud_replace_builtin("breath", {
	type = "statbar",
	position = {x = 0.5, y = 1},
	text = "bubble.png",
	text2 = "bubble_gone.png",
	number = core.PLAYER_MAX_BREATH_DEFAULT * 2,
	item = core.PLAYER_MAX_BREATH_DEFAULT * 2,
	direction = 0,
	size = {x = 24, y = 24},
	offset = {x = 25, y= -120},
})

core.register_privilege("ffa_manager", {
    description = "Manage FFA",
    give_to_singleplayer = true,
    give_to_admin = true,
})