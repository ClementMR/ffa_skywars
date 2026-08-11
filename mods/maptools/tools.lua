--[[
Map Tools: tool definitions

Copyright © 2012-2019 Hugo Locurcio and contributors.
Licensed under the zlib license. See LICENSE.md for more information.
--]]

maptools.creative = maptools.config["hide_from_creative_inventory"]

local pick_admin_toolcaps = {
	full_punch_interval = 0.1,
	max_drop_level = 3,
	groupcaps = {
		unbreakable = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0, maxlevel = 3},
		fleshy = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0, maxlevel = 3},
		choppy = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0, maxlevel = 3},
		bendy = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0, maxlevel = 3},
		cracky = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0, maxlevel = 3},
		crumbly = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0, maxlevel = 3},
		snappy = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0, maxlevel = 3},
	},
	damage_groups = {fleshy = 1000},
}

core.register_tool("maptools:pick_admin", {
	description = S("Admin Pickaxe"),
	range = 20,
	inventory_image = "maptools_adminpick.png",
	tool_capabilities = pick_admin_toolcaps,
	on_drop = function() return end,
})