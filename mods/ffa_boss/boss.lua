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
    ffa_boss.state.boss_object = nil
    return nil
end

local function update_nameplate(self)
    self.object:set_properties({
        nametag = ("THE FORGOTTEN\n%d / %d HP"):format(math.max(0, self.health), ffa_boss.settings.max_hp),
        nametag_color = "#C084FC",
    })
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
            if here_def and above_def and here_def.buildable_to and above_def.buildable_to then
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
    if not target or not target:is_player() or target:get_hp() <= 0 then
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
        ffa_boss.state.active = false
        ffa_boss.state.loot_phase = false
        broadcast("The Forgotten event is over.")
    end)
end

mobs:register_mob("ffa_boss:forgotten_player", {
    type = "monster",
    hp_min = ffa_boss.settings.max_hp,
    hp_max = ffa_boss.settings.max_hp,
    armor = 30,
    walk_velocity = 3.2,
    run_velocity = 4.2,
    randomly_turn = true,
    jump_height = 1.4,
    view_range = 28,
    damage = 22,
    knock_back = false,
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
    pathfinding = 1,
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
        self.last_hit = core.get_gametime()
        self.next_power = 10
        ffa_boss.state.boss_object = self.object
        ffa_boss.state.active = true
        update_nameplate(self)
    end,
    do_custom = custom_step,
    do_punch = custom_punch,
    on_death = boss_death,
})

function ffa_boss.start_event()
    if ffa_boss.state.active then
        return false, "The Forgotten event is already running."
    end
    if not ffa_boss.is_ready() then
        return false, "The zone isn't completely defined."
    end

    ffa_boss.state.members = {}
    ffa_boss.state.loot_phase = false
    local object = core.add_entity(ffa_boss.get_position("boss_spawn"), "ffa_boss:forgotten_player")
    if not valid_boss(object) then
        return false, "The Forgotten could not be spawned."
    end

    ffa_boss.state.active = true
    ffa_boss.state.boss_object = object
    broadcast(("The Forgotten has appeared. Use %s to fight it."):format(core.colorize("cyan", "/boss join")))
    return true
end
