return function(throwables)

throwables.register_projectile("throwables:thrown_fireball", {
	speed = 17,
    gravity = 12,
    lifetime = 5,
	hit_objects = false,
	texture = "skywars_fireball.png",
    glow = 8,
	impact_amount = 0,
	on_hit = function(self, hit)
		if hit.type ~= "node" or not throwables.valid_player(self.owner) then return end
		local node = core.registered_nodes[core.get_node(hit.pos).name]
		tnt.boom(hit.pos, {
			radius = 2,
			strength = 1000,
			explode_center = true,
			boom_sound = {name = "tnt_explode", def = {gain = 1.0, max_hear_distance = 64}},
		}, self.player_name, node and node.liquidtype ~= "none")

        if core.get_node(hit.pos).name == "air" then
            core.set_node(hit.pos, {name = "fire:basic_flame"})
        end
	end,
})

core.register_craftitem(":skywars:fireball", {
    description = throwables.S("Fireball"),
	inventory_image = "skywars_fireball.png",
	stack_max = 16,
    _cooldown = 1,
    on_use = throwables.use("throwables:thrown_fireball", "skywars_fireball_thrown"),
})

end