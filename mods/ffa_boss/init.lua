ffa_boss = {
    storage = core.get_mod_storage(),
    state = {
        members = {},
        active = false,
        starting = false,
        loot_phase = false,
        boss_object = nil,
    }
}

for _, file in ipairs({
    "config",
    "players",
    "loot",
    "boss",
    "commands",
    "golden_ticket"
}) do
    dofile(core.get_modpath(core.get_current_modname()) .. "/" .. file .. ".lua")
end
