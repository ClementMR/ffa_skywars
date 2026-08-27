-- Thin entry point: the implementation is split by responsibility.
local modpath = core.get_modpath(core.get_current_modname())
local api = rawget(_G, "player_stats") or {}
local stats = {
	storage = core.get_mod_storage(),
	api = api,
}

rawset(_G, "player_stats", api)

for _, module in ipairs({"storage", "events", "forms", "commands"}) do
	dofile(modpath .. "/" .. module .. ".lua")(stats)
end
