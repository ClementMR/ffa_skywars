local storage = core.get_mod_storage()

ffa_boss = {
    storage = storage,
    S = core.get_translator("ffa_boss"),
    state = {
        members = {},
        loot_phase = false,
        boss_object = nil
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
