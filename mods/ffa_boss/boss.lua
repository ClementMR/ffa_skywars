local function broadcast(text)
    core.chat_send_all(core.colorize("#d66823", "[Boss] ") .. text)
end

local function effect(pos, amount)
    mobs:effect(pos, amount, "default_mese_crystal_fragment.png^[colorize:#8B5CF6:180",
        1, 1.5, 3, 10, 1, true)
end

local function valid_boss(object)
    local entity = object and object:get_luaentity()
    return entity and entity.name == "ffa_boss:forgotten_player"
end

function ffa_boss.get_boss()
    if valid_boss(ffa_boss.state.boss_object) then
        return ffa_boss.state.boss_object
    end

    local spawn = ffa_boss.get_position("boss_spawn")
    if spawn then
        for _, object in ipairs(core.get_objects_inside_radius(spawn, ffa_boss.settings.boss_radius)) do
            if valid_boss(object) then
                ffa_boss.state.boss_object = object
                return object
            end
        end
    end

    ffa_boss.state.boss_object = nil
    return nil
end

function ffa_boss.is_running()
    return ffa_boss.state.loot_phase
        or ffa_boss.get_boss() ~= nil
end

local function keep_spawn_loaded()
    if ffa_boss.state.spawn_forced then
        return true
    end

    local spawn = ffa_boss.get_position("boss_spawn")
    if not spawn or not core.forceload_block(spawn, false, -1) then
        return false
    end

    ffa_boss.state.spawn_forced = true
    ffa_boss.storage:set_string("spawn_forced", "true")
    return true
end

local function release_spawn()
    if not ffa_boss.state.spawn_forced then
        return
    end

    local spawn = ffa_boss.get_position("boss_spawn")
    if spawn then
        core.forceload_free_block(spawn)
    end
    ffa_boss.state.spawn_forced = false
    ffa_boss.storage:set_string("spawn_forced", "")
end

local function update_nameplate(self)
    self.object:set_properties({
        nametag = ("THE FORGOTTEN\n%d / %d HP"):format(math.max(0, self.health), ffa_boss.settings.max_hp),
        nametag_color = "#C084FC",
    })
end

local function return_home(self)
    local spawn = ffa_boss.get_position("boss_spawn")
    local pos = self.object:get_pos()
    if spawn then
        if not pos or vector.distance(pos, spawn) > 1 then
            self.object:set_pos(spawn)
            self.object:set_velocity({x = 0, y = 0, z = 0})
        end
    end
end

local function open_positions(pos)
    local positions = {}
    local center = vector.round(pos)

    for x = -3, 3 do
        for z = -3, 3 do
            local target = {x = center.x + x, y = center.y, z = center.z + z}
            local here = core.get_node_or_nil(target)
            local above = core.get_node_or_nil(vector.offset(target, 0, 1, 0))
            local here_def = here and core.registered_nodes[here.name]
            local above_def = above and core.registered_nodes[above.name]
            if here_def and above_def and here_def.buildable_to and above_def.buildable_to
                and ffa_boss.is_in_zone(target)
            then
                table.insert(positions, target)
            end
        end
    end

    return positions
end

local function teleport_near(self, target)
    local target_pos = target:get_pos()
    if not target_pos then
        return
    end

    local positions = open_positions(target_pos)
    if #positions == 0 then
        return
    end

    local from = self.object:get_pos()
    local destination = positions[math.random(#positions)]
    effect(from, 18)
    self.object:set_pos(destination)
    effect(destination, 18)
    self:mob_sound("skywars_forgotten_player")
end

local function void_burst(self, target)
    local boss_pos = self.object:get_pos()
    local target_pos = target:get_pos()
    if not boss_pos or not target_pos then
        return
    end

    target:punch(self.object, 1, {
        full_punch_interval = 1,
        damage_groups = {fleshy = 24},
    })
    local velocity = vector.multiply(vector.direction(boss_pos, target_pos), 18)
    velocity.y = 8
    target:add_velocity(velocity)
    effect(target_pos, 28)
end

local function custom_step(self, dtime)
    local pos = self.object:get_pos()
    if not pos or not ffa_boss.is_in_zone(pos) then
        return_home(self)
        return false
    end

    local now = core.get_gametime()
    self.name_timer = (self.name_timer or 0) + dtime
    if self.name_timer >= 0.5 then
        self.name_timer = 0
        update_nameplate(self)
    end

    if now - (self.last_hit or now) >= ffa_boss.settings.idle_regen_delay then
        self.regen_timer = (self.regen_timer or 0) + dtime
        if self.regen_timer >= 1 then
            self.regen_timer = self.regen_timer - 1
            self.health = math.min(ffa_boss.settings.max_hp, self.health + ffa_boss.settings.idle_regen_per_second)
        end
    else
        self.regen_timer = 0
    end

    local target = self.attack
    if not target
        or not target:is_player()
        or target:get_hp() <= 0
        or not ffa_boss.is_member(target:get_player_name())
        or not ffa_boss.is_in_zone(target:get_pos()) then
        self.attack = nil
        self.state = "stand"
        return_home(self)
        return
    end

    self.power_timer = (self.power_timer or 0) + dtime
    if self.power_timer < (self.next_power or 10) then
        return
    end
    self.power_timer = 0
    self.next_power = math.random(5, 10)

    void_burst(self, target)
end

local function custom_punch(self, hitter)
    if not hitter or not hitter:is_player() then
        return
    end

    if not ffa_boss.is_member(hitter:get_player_name()) then
        return false
    end

    self.last_hit = core.get_gametime()
    self.last_hitter = hitter:get_player_name()
    if self.state == "attack" and math.random(1, 5) == 1 then
        teleport_near(self, hitter)
    end
end

local function boss_death(self, killer)
    if ffa_boss.state.loot_phase then
        return
    end
    ffa_boss.state.boss_object = nil
    ffa_boss.state.loot_phase = true
    release_spawn()
    ffa_boss.drop_rewards(ffa_boss.get_position("boss_spawn") or self.object:get_pos())
    local winner = killer and killer:get_player_name() or self.last_hitter or "the arena"
    broadcast(("The Forgotten was defeated by %s."):format(winner))

    for name in pairs(ffa_boss.state.members) do
        core.chat_send_player(name, core.colorize("#d66823", "[Boss] ") .. 
            ("Teleporting in %d seconds ..."):format(ffa_boss.settings.reward_time))
    end

    core.after(ffa_boss.settings.reward_time, function()
        if not ffa_boss.state.loot_phase then
            return
        end
        ffa_boss.return_all()
        ffa_boss.state.loot_phase = false
        broadcast("The Forgotten event is over.")
    end)
end

mobs:register_mob("ffa_boss:forgotten_player", {
    type = "monster",
    lifetimer = 20000,
    hp_min = ffa_boss.settings.max_hp,
    hp_max = ffa_boss.settings.max_hp,
    armor = 30,
    walk_velocity = 3.2,
    run_velocity = 4.2,
    randomly_turn = false,
    jump_height = 1.4,
    view_range = 28,
    damage = 22,
    knock_back = true,
    fall_damage = false,
    node_damage = false,
    water_damage = 0,
    lava_damage = 0,
    fire_damage = 0,
    suffocation = 0,
    floats = false,
    reach = 5,
    fear_height = 0,
    attack_chance = 0,
    attack_monsters = true,
    attack_animals = true,
    attack_players = true,
    attack_type = "dogfight",
    pathfinding = 0,
    makes_footstep_sound = true,
    visual = "mesh",
    visual_size = {x = 1.35, y = 1.35},
    mesh = "3d_armor_character.b3d",
    collisionbox = {-0.45, 0, -0.45, 0.45, 2.1, 0.45},
    selectionbox = {-0.7, 0, -0.7, 0.7, 2.4, 0.7},
    glow = 3,
    textures = {
        "ffa_boss_forgotten.png",
        "blank.png",
        "skywars_shadow_sword.png",
    },
    animation = {
        stand_start = 0,
        stand_end = 79,
        walk_start = 168,
        walk_end = 187,
        run_start = 168,
        run_end = 187,
        punch_start = 190,
        punch_end = 198,
    },
    after_activate = function(self)
        self.lifetimer = 20000
        self.object:set_properties({ static_save = true })
        self.last_hit = core.get_gametime()
        self.next_power = 10
        ffa_boss.state.boss_object = self.object
        update_nameplate(self)
    end,
    do_custom = custom_step,
    do_punch = custom_punch,
    on_death = boss_death,
})

function ffa_boss.start_event()
    if not ffa_boss.is_ready() then
        return false, "The zone isn't completely defined."
    end

    local boss_spawn = ffa_boss.get_position("boss_spawn")
    core.load_area(boss_spawn)
    if ffa_boss.is_running() then
        return false, "The Forgotten event is already running."
    end
    if not keep_spawn_loaded() then
        return false, "The boss spawn could not be kept loaded."
    end

    ffa_boss.state.members = {}
    ffa_boss.state.loot_phase = false
    local object = core.add_entity(boss_spawn, "ffa_boss:forgotten_player")
    if not valid_boss(object) then
        release_spawn()
        return false, "The Forgotten could not be spawned."
    end

    broadcast(("The Forgotten has appeared. Use %s to fight it."):format(core.colorize("cyan", "/boss join")))
    return true, "The Forgotten is ready to fight."
end

function ffa_boss.stop_event()
    local boss = ffa_boss.get_boss()
    if boss then
        boss:remove()
    end

    ffa_boss.return_all()
    ffa_boss.state.loot_phase = false
    ffa_boss.state.boss_object = nil
    release_spawn()
end
