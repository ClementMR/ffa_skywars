skywars = {}

core.register_privilege("ffa_manager", {
    description = "Manage FFA",
    give_to_singleplayer = true,
    give_to_admin = true,
})

local modpath = core.get_modpath(core.get_current_modname())

local files = {
    "maps",
    "map_editor",
    "player",
	"inventory_cleanup",
	"chat",
    "death_bound",
    "nodes",
    "items",
    "fireball",
    "totem",
    "cleanup",
    "vanish",
    "commands",
	"tips",
    "shadow_sword",
    "golden_apple",
    "hit_particles"
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

core.register_alias_force("wind_pearl:wind_pearl", "throwables:wind_pearl")
core.register_alias_force("enderpearl:ender_pearl", "throwables:ender_pearl")
