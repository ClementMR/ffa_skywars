throwables = {}

local path = core.get_modpath(core.get_current_modname())
for _, file in ipairs({"effects", "projectiles", "ender_pearl", "wind_pearl", "snowball"}) do
	dofile(path .. "/" .. file .. ".lua")(throwables)
end
