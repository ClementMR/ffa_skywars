local boss = forgotten_boss
local entity_name = "forgotten_boss:the_forgotten"

local function broadcast(text)
    core.chat_send_all(core.colorize("#C4B5FD", "[Forgotten] ") .. text)
end

local function valid_boss(object)
    if not object then
        return false
    end
    local entity = object:get_luaentity()
    return entity and entity.name == entity_name
end

function boss.get_boss()
    if valid_boss(boss.state.boss_object) then
        return boss.state.boss_object
    end
    boss.state.boss_object = nil
    return nil
end

local function player_target(position)
    local target
    local nearest

    for name in pairs(boss.state.members) do
        local player = core.get_player_by_name(name)
        local player_pos = player and player:get_pos()
        if player_pos and player:get_hp() > 0 and boss.in_zone(player_pos) then
            local distance = vector.distance(position, player_pos)
            if not nearest or distance < nearest then
                target = player
                nearest = distance
            end
        end
    end

    return target, nearest
end

local function damage_player(entity, player, amount)
    if not player or player:get_hp() <= 0 then
        return
    end

    player:punch(entity.object, 1, {
        full_punch_interval = 1,
        damage_groups = {fleshy = amount},
    })
end

local function hit_particles(pos)
    core.add_particlespawner({
        amount = 25,
        time = 0.15,
        minpos = vector.subtract(pos, 0.5),
        maxpos = vector.add(pos, 0.5),
        minvel = {x = -2, y = 1, z = -2},
        maxvel = {x = 2, y = 4, z = 2},
        minacc = {x = 0, y = -5, z = 0},
        maxacc = {x = 0, y = -5, z = 0},
        minexptime = 0.4,
        maxexptime = 1.2,
        minsize = 2,
        maxsize = 5,
        texture = "default_mese_crystal_fragment.png^[colorize:#8B5CF6:180",
        glow = 8,
    })
end

local function teleport_near_target(entity, target)
    local target_pos = target:get_pos()
    if not target_pos then
        return
    end

    for _ = 1, 10 do
        local angle = math.random() * math.pi * 2
        local distance = math.random(4, 7)
        local pos = {
            x = target_pos.x + math.cos(angle) * distance,
            y = target_pos.y + 1,
            z = target_pos.z + math.sin(angle) * distance,
        }
        local below = core.get_node_or_nil(vector.offset(pos, 0, -1, 0))
        local here = core.get_node_or_nil(pos)
        local above = core.get_node_or_nil(vector.offset(pos, 0, 1, 0))
        local here_def = here and core.registered_nodes[here.name]
        local above_def = above and core.registered_nodes[above.name]

        if boss.in_zone(pos)
            and below
            and here_def and here_def.buildable_to
            and above_def and above_def.buildable_to then
            entity.object:set_pos(pos)
            entity.object:set_velocity(vector.zero())
            hit_particles(pos)
            return
        end
    end
end

local function rift_cage(entity, target)
    local pos = target:get_pos()
    if not pos then
        return
    end

    boss.place_rift_blocks(pos)
    damage_player(entity, target, 5)
    hit_particles(pos)
    core.sound_play("default_dig_metal", {pos = pos, gain = 0.7, max_hear_distance = 24})
end

local function soul_bolt(entity, target)
    local from = entity.object:get_pos()
    local pos = target:get_pos()
    if not from or not pos then
        return
    end

    damage_player(entity, target, 9)
    target:add_velocity(vector.multiply(vector.direction(from, pos), 7))
    hit_particles(pos)
    core.sound_play("default_mese_crystal_fragment", {pos = pos, gain = 0.8, max_hear_distance = 24})
end

local function shockwave(entity, position)
    for name in pairs(boss.state.members) do
        local player = core.get_player_by_name(name)
        local player_pos = player and player:get_pos()
        if player_pos then
            local distance = vector.distance(position, player_pos)
            if distance <= 12 then
                local velocity = vector.multiply(vector.direction(position, player_pos), 11)
                velocity.y = 5
                player:add_velocity(velocity)
                damage_player(entity, player, 6)
            end
        end
    end
    hit_particles(position)
    core.sound_play("tnt_explode", {pos = position, gain = 0.45, max_hear_distance = 32})
end

local function set_nameplate(entity)
    local hp = math.max(0, entity.object:get_hp())
    entity.object:set_properties({
        nametag = core.colorize("#C084FC", ("THE FORGOTTEN\n%d / %d HP"):format(hp, boss.settings.max_hp)),
        nametag_color = "#C084FC",
    })
    boss.update_all_huds(hp, boss.settings.max_hp)
end

function boss.finish_event(reason)
    boss.state.event_id = boss.state.event_id + 1
    boss.state.event_open = false
    boss.state.event_active = false
    boss.state.boss_object = nil
    boss.return_all(reason)
end

local function defeat(entity)
    if entity.dead then
        return
    end
    entity.dead = true
    local pos = entity.object:get_pos() or boss.get_position("spawn")
    local winner = entity.last_hitter or "the arena"

    boss.state.event_open = false
    boss.state.event_active = false
    boss.state.boss_object = nil
    boss.drop_rewards(pos)
    broadcast(("The Forgotten was defeated by %s. Collect the scattered rewards; the arena closes in %d seconds.")
        :format(winner, boss.settings.reward_time))

    entity.object:set_velocity(vector.zero())
    entity.object:set_properties({pointable = false, nametag = ""})
    core.after(5, function(object)
        if valid_boss(object) then
            object:remove()
        end
    end, entity.object)
    core.after(boss.settings.reward_time, function()
        boss.return_all("The Forgotten event is over.")
    end)
end

core.register_entity(entity_name, {
    initial_properties = {
        hp_max = boss.settings.max_hp,
        physical = true,
        collide_with_objects = true,
        pointable = true,
        visual = "sprite",
        visual_size = {x = 5, y = 5},
        textures = {"forgotten_boss_wither.png"},
        use_texture_alpha = "blend",
        glow = 8,
        collisionbox = {-0.8, -0.2, -0.8, 0.8, 2.8, 0.8},
        selectionbox = {-1.2, -0.2, -1.2, 1.2, 3.2, 1.2},
        armor_groups = {fleshy = 100},
        nametag = "THE FORGOTTEN",
        nametag_color = "#C084FC",
        static_save = false,
    },

    on_activate = function(self)
        self.last_hit = core.get_gametime()
        self.next_power = core.get_gametime() + 8
        self.next_attack = 0
        self.next_hud = 0
        boss.state.boss_object = self.object
        boss.state.event_active = true
        set_nameplate(self)
    end,

    on_punch = function(self, puncher)
        if puncher and puncher:is_player() then
            self.last_hit = core.get_gametime()
            self.last_hitter = puncher:get_player_name()
            hit_particles(self.object:get_pos())
        end
    end,

    on_step = function(self, dtime)
        if self.dead then
            return
        end

        local position = self.object:get_pos()
        if not position then
            return
        end

        if self.object:get_hp() <= 0 then
            defeat(self)
            return
        end

        local now = core.get_gametime()
        if now >= self.next_hud then
            self.next_hud = now + 0.5
            set_nameplate(self)
        end

        if not boss.in_zone(position) then
            local spawn = boss.get_position("spawn")
            if spawn then
                self.object:set_pos(spawn)
                self.object:set_velocity(vector.zero())
                position = spawn
            end
        end

        local target, distance = player_target(position)
        if target then
            local target_pos = target:get_pos()
            local direction = vector.direction(position, vector.offset(target_pos, 0, 1, 0))
            if distance > 3 then
                self.object:set_velocity(vector.multiply(direction, 4.2))
            else
                self.object:set_velocity(vector.zero())
                if now >= self.next_attack then
                    self.next_attack = now + 1.4
                    damage_player(self, target, 8)
                    hit_particles(target_pos)
                end
            end
            self.object:set_yaw(core.dir_to_yaw(direction))

            if now >= self.next_power then
                self.next_power = now + math.random(10, 15)
                local power = math.random(1, 4)
                if power == 1 then
                    teleport_near_target(self, target)
                elseif power == 2 then
                    rift_cage(self, target)
                elseif power == 3 then
                    soul_bolt(self, target)
                else
                    shockwave(self, position)
                end
            end
        else
            self.object:set_velocity(vector.zero())
        end

        if now - self.last_hit >= boss.settings.idle_regen_delay then
            self.regen_time = (self.regen_time or 0) + dtime
            if self.regen_time >= 1 then
                self.regen_time = self.regen_time - 1
                local hp = self.object:get_hp()
                if hp < boss.settings.max_hp then
                    self.object:set_hp(math.min(boss.settings.max_hp, hp + boss.settings.idle_regen_per_second))
                end
            end
        else
            self.regen_time = 0
        end
    end,
})

function boss.start_event()
    if boss.state.event_active then
        return false, "The Forgotten is already in the arena."
    end
    if not boss.is_ready() then
        return false, "Set pos1, pos2, entry, exit and spawn before starting an event."
    end

    boss.state.event_id = boss.state.event_id + 1
    boss.state.event_open = false
    local object = core.add_entity(boss.get_position("spawn"), entity_name)
    if not valid_boss(object) then
        return false, "The Forgotten could not be spawned."
    end

    boss.state.event_active = true
    boss.state.boss_object = object
    broadcast("The Forgotten has appeared. Use a Golden Ticket or /boss enter to join the fight.")
    return true
end

function boss.open_event(delay)
    if boss.state.event_open or boss.state.event_active then
        return false, "An event is already open."
    end
    if not boss.is_ready() then
        return false, "Set pos1, pos2, entry, exit and spawn before opening an event."
    end

    delay = math.max(0, math.floor(tonumber(delay) or boss.settings.open_delay))
    boss.state.event_id = boss.state.event_id + 1
    local event_id = boss.state.event_id
    boss.state.event_open = true

    if delay == 0 then
        return boss.start_event()
    end

    broadcast(("The Forgotten awakens in %d seconds. Bring a Golden Ticket and use /boss enter."):format(delay))
    for _, warning in ipairs({60, 30, 10}) do
        if delay > warning then
            core.after(delay - warning, function()
                if boss.state.event_id == event_id and boss.state.event_open then
                    broadcast(("The Forgotten arrives in %d seconds."):format(warning))
                end
            end)
        end
    end
    core.after(delay, function()
        if boss.state.event_id == event_id and boss.state.event_open then
            boss.start_event()
        end
    end)
    return true
end

function boss.stop_event()
    boss.state.event_id = boss.state.event_id + 1
    boss.state.event_open = false
    local object = boss.get_boss()
    if object then
        object:remove()
    end
    boss.finish_event("The Forgotten event was closed by an administrator.")
end
