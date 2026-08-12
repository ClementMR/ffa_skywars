local ran = math.random

local S = core.get_translator(core.get_current_modname())

local function valid_positions(pos)
    local valid_pos = {}
    local min, max = -1, 1
    for x=min, max do
        for z=min, max do
            local node_pos = {x=pos.x + x, y=pos.y,z=pos.z + z}
            local nodedef = core.registered_nodes[core.get_node(node_pos).name]
            if not nodedef.groups.walkable then
                table.insert(valid_pos, node_pos)
            end
        end
    end

    return valid_pos
end

mobs:register_mob("skywars:forgotten_player", {
    type = "monster",
    hp_min = 200,
    hp_max = 200,
    armor = 25,
    walk_velocity = 2.2,
    run_velocity = 2.9,
    randomly_turn = true,
    jump_height = 1.2,
    view_range = 10,
    damage = 8,
    knock_back = false,
    lava_damage = 4,
    fire_damage = 1,
    suffocation = 1,
    floats = false,
    reach = 4,
    fear_height = 0,
    attack_chance = 0,
    attack_monsters = true,
    attack_animals = true,
    attack_players = true,
    attack_type = "dogfight",
    pathfinding = 1,
    makes_footstep_sound = true,
    visual = "mesh",
    mesh = "3d_armor_character.b3d",
    collisionbox = {-0.3,0,-0.3, 0.3,1.7,0.3},
    textures = {
        "skywars_forgotten_player.png",
        "blank.png",
        "skywars_shadow_sword.png"
    },
    drops = {
        {name = "skywars:golden_apple", chance = 4, min = 1, max = 1},
        {name = "ctf_ranged:shotgun_loaded", chance = 1, min = 1, max = 1},
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
    do_punch = function(self, hitter, time_from_last_punch, tool_capabilities, direction, damage)
        local ent = self.object
        local ent_pos = vector.round(ent:get_pos())
        local hitter_pos = hitter:get_pos()

        if self.state == "walk" then
            return
        end

        if hitter:get_wielded_item():get_name() == "ctf_ranged:shotgun_loaded" then return end
        if ent:get_hp() < 5 then return end

        if self.state == "attack" then
            local valid_pos = {}
            for _, pos in ipairs(valid_positions(hitter_pos)) do
                local lower_node = core.get_node(pos)
                local lower_nodedef = core.registered_nodes[lower_node.name]
                local upper_node = core.get_node({x=pos.x, y=pos.y + 1, z=pos.z})
                local upper_nodedef = core.registered_nodes[upper_node.name]

                if not lower_nodedef.groups.walkable and not upper_nodedef.groups.walkable then
                    table.insert(valid_pos, pos)
                end
            end

            if ran(0, 4) == 1 and #valid_pos > 0 then
                mobs:effect(ent_pos, 10, "default_obsidian_shard.png",
                    1, 1.5, 3, 10, 1, true)

                core.sound_play("skywars_forgotten_player", {
                    pos = ent_pos,
                    gain = 0.5,
                    max_hear_distance = 16
                })

                ent:set_pos(valid_pos[ran(1, #valid_pos)])
                mobs:effect(hitter_pos, 10, "default_mese_crystal_fragment.png",
                    1, 1.5, 3, 10, 1, true)
            end
        end
    end,
    on_death = function(self, killer)
        local killer_name = killer and killer:get_player_name() or "..."
        core.chat_send_all(S("The @1 was beaten by @2!", core.colorize("#31C950", S("Forgotten Player")), killer_name))
    end
})

function skywars.spawn_fp(pos)
    for _, obj in ipairs(core.get_objects_inside_radius(pos, 30)) do
        if obj:get_luaentity() and obj:get_luaentity().name == "skywars:forgotten_player" then
            obj:remove()
        end
    end

    core.add_entity(vector.new(pos), "skywars:forgotten_player")
end

mobs:register_egg("skywars:forgotten_player", "Forgotten Player", "default_cactus_side.png", 1, 1)