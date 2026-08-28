local storage = core.get_mod_storage()
local saved_block = core.deserialize(storage:get_string("boss_block"))
local boss_block

if type(saved_block) == "table"
    and type(saved_block.x) == "number"
    and type(saved_block.y) == "number"
    and type(saved_block.z) == "number" then
    boss_block = vector.new(saved_block)
end

ffa_boss = {
    storage = storage,
    state = {
        members = {},
        starting = false,
        loot_phase = false,
        boss_object = nil,
        boss_block = boss_block,
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
