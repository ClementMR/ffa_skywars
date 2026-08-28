local ffa_timers = rawget(_G, "ffa_timers") or {}
rawset(_G, "ffa_timers", ffa_timers)

ffa_timers.players = ffa_timers.players or {}
ffa_timers.combat_duration = tonumber(core.settings:get("combat_timer")) or 8
ffa_timers.immunity_duration = tonumber(core.settings:get("immunity_timer")) or 14
ffa_timers.S = core.get_translator(core.get_current_modname())

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/immunity.lua")
dofile(modpath .. "/combat.lua")
