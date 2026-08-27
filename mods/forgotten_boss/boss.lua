local boss = forgotten_boss
local entity_name = "skywars:forgotten_player"

local function broadcast(text)
    core.chat_send_all(core.colorize("#C4B5FD", "[Forgotten] ") .. text)
end

local function effect(pos, amount)
    mobs:effect(pos, amount, "default_mese_crystal_fragment.png^[colorize:#8B5CF6:180",
        1, 1.5, 3, 10, 1, true)
end

local function valid_boss(object)
    local entity = object and object:get_luaentity()
    return entity and entity.name == entity_name
end

function boss.get_boss()
    if valid_boss(boss.state.boss_object) then
        return boss.state.boss_object
    end
    boss.state.boss_object = nil
    return nil
end

local function update_nameplate(self)
    self.object:set_properties({
        nametag = ("THE FORGOTTEN\n%d / %d HP"):format(math.max(0, self.health), boss.settings.max_hp),
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
        damage_groups = {fleshy = 11},
    })
    local velocity = vector.multiply(vector.direction(boss_pos, target_pos), 10)
    velocity.y = 5
    target:add_velocity(velocity)
    effect(target_pos, 28)
end

local function rift_prison(self, target)
    local pos = target:get_pos()
    if not pos then
        return
    end

    boss.place_rift_blocks(pos)
    target:punch(self.object, 1, {
        full_punch_interval = 1,
        damage_groups = {fleshy = 6},
    })
    effect(pos, 20)
end

local function custom_step(self, dtime)
    local now = core.get_gametime()
    self.name_timer = (self.name_timer or 0) + dtime
    if self.name_timer >= 0.5 then
        self.name_timer = 0
        update_nameplate(self)
    end

    if now - (self.last_hit or now) >= boss.settings.idle_regen_delay then
        self.regen_timer = (self.regen_timer or 0) + dtime
        if self.regen_timer >= 1 then
            self.regen_timer = self.regen_timer - 1
            self.health = math.min(boss.settings.max_hp, self.health + boss.settings.idle_regen_per_second)
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
    self.next_power = math.random(10, 15)

    local power = math.random(1, 3)
    if power == 1 then
        teleport_near(self, target)
    elseif power == 2 then
        rift_prison(self, target)
    else
        void_burst(self, target)
    end
end

local function custom_punch(self, hitter)
    if not hitter or not hitter:is_player() then
        return
    end

    self.last_hit = core.get_gametime()
    self.last_hitter = hitter:get_player_name()
    if self.state == "attack" and math.random(1, 4) == 1 then
        teleport_near(self, hitter)
    end
end

local function boss_death(self, killer)
    if boss.state.loot_phase then
        return
    end

    boss.state.boss_object = nil
    boss.state.loot_phase = true
    boss.drop_rewards(self.object:get_pos())
    local winner = killer and killer:get_player_name() or self.last_hitter or "the arena"
    broadcast(("The Forgotten was defeated by %s. Loot is available for %d seconds.")
        :format(winner, boss.settings.reward_time))

    local event_id = boss.state.event_id
    core.after(boss.settings.reward_time, function()
        if boss.state.event_id ~= event_id or not boss.state.loot_phase then
            return
        end
        boss.return_all()
        boss.state.active = false
        boss.state.loot_phase = false
        broadcast("The Forgotten event is over.")
    end)
end

mobs:register_mob(entity_name, {
    type = "monster",
    hp_min = boss.settings.max_hp,
    hp_max = boss.settings.max_hp,
    armor = 12,
    walk_velocity = 3.2,
    run_velocity = 4.2,
    randomly_turn = true,
    jump_height = 1.4,
    view_range = 28,
    damage = 13,
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
        "skywars_forgotten_player.png",
        "blank.png",
        "skywars_shadow_sword.png",
    },
    sounds = {
        random = "skywars_forgotten_player",
        war_cry = "skywars_forgotten_player",
        attack = "skywars_forgotten_player",
        damage = "skywars_forgotten_player",
        death = "skywars_forgotten_player",
        distance = 28,
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
        self.next_power = 8
        boss.state.boss_object = self.object
        boss.state.active = true
        update_nameplate(self)
    end,
    do_custom = custom_step,
    do_punch = custom_punch,
    on_death = boss_death,
})

function boss.start_event()
    if boss.state.active then
        return false, "The Forgotten event is already running."
    end
    if not boss.is_ready() then
        return false, "Set the boss spawn and player spawn before starting the event."
    end

    boss.state.event_id = boss.state.event_id + 1
    boss.state.members = {}
    boss.state.loot_phase = false
    local object = core.add_entity(boss.get_position("boss_spawn"), entity_name)
    if not valid_boss(object) then
        return false, "The Forgotten could not be spawned."
    end

    boss.state.active = true
    boss.state.boss_object = object
    broadcast("The Forgotten has appeared. Use /boss join to fight it.")
    return true
end
