local boss = rawget(_G, "forgotten_boss") or {}
rawset(_G, "forgotten_boss", boss)

boss.modname = core.get_current_modname()
boss.modpath = core.get_modpath(boss.modname)
boss.storage = core.get_mod_storage()
boss.state = boss.state or {
    members = {},
    active = false,
    loot_phase = false,
    event_id = 0,
    boss_object = nil,
}

for _, file in ipairs({
    "config.lua",
    "players.lua",
    "loot.lua",
    "boss.lua",
    "commands.lua",
}) do
    dofile(boss.modpath .. "/" .. file)
end
