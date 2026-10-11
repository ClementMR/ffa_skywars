local H = ffa_halloween

function H.clear_objects()
	for object in pairs(H.objects) do
		if object:get_pos() then object:remove() end
	end
	H.objects = {}
end

local function collect(self, player)
	if self.kind ~= "ghost" or self.collected or not H.active
			or not player or not player:is_player()
			or vector.distance(self.object:get_pos(), player:get_pos()) > 4 then return end
	local item = "ffa_halloween:candy"
	local inventory = player:get_inventory()
	if not inventory:room_for_item("main", item) then return end
	inventory:add_item("main", item)
	self.collected = true
	H.burst(self.object:get_pos(), "ffa_halloween_spark.png", 14)
	self.object:remove()
end

core.register_entity("ffa_halloween:spirit", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		visual = "sprite",
		visual_size = {x = 0.9, y = 0.9},
		textures = {"ffa_halloween_ghost.png"},
		glow = 10,
		pointable = true,
		static_save = false,
		hp_max = 1,
		selectionbox = {-0.45, -0.45, -0.45, 0.45, 0.45, 0.45},
	},
	on_activate = function(self, kind)
		if not H.active or (kind ~= "ghost" and kind ~= "lantern") then
			self.object:remove()
			return
		end
		self.kind, self.age = kind, 0
		self.anchor = self.object:get_pos()
		self.object:set_armor_groups({immortal = 1})

		if kind == "lantern" then
			self.object:set_properties({textures = {"ffa_halloween_lantern.png"},
				pointable = false, visual_size = {x = 0.65, y = 0.65}})
		end

		H.objects[self.object] = kind
	end,
	on_step = function(self, dt)
		self.age = self.age + dt
		if not H.active or self.age >= 35 then self.object:remove(); return end
		self.object:set_pos(vector.offset(self.anchor, 0, math.sin(self.age * 2) * 0.15, 0))
	end,
	on_punch = function(self, player) collect(self, player); return true end,
	on_rightclick = collect,
	on_deactivate = function(self) H.objects[self.object] = nil end,
})

function H.spawn_decoration(pos, kind)
	if not H.active then return false end
	local count, lanterns = 0, 0
	for object, existing_kind in pairs(H.objects) do
		count = count + 1
		if existing_kind == "lantern" then lanterns = lanterns + 1 end
		local here = object:get_pos()
		if here and vector.distance(pos, here) < 2 then return false end
	end
	if count >= H.max_objects or (kind == "lantern" and lanterns >= H.max_objects / 2) then return false end
	local node = core.get_node_or_nil(pos)
	if not node or node.name ~= "air" then return false end
	return core.add_entity(pos, "ffa_halloween:spirit", kind) ~= nil
end

function H.spawn_spirits(players)
	for _, player in ipairs(players) do
		local pos = vector.round(player:get_pos())
		local x, z = math.random(-9, 9), math.random(-9, 9)
		for y = 2, -3, -1 do
			local target = vector.offset(pos, x, y, z)
			local below = core.get_node_or_nil(vector.offset(target, 0, -1, 0))
			local def = below and core.registered_nodes[below.name]
			if def and def.walkable and below.name ~= "ignore" and (def.damage_per_second or 0) == 0 then
				if H.spawn_decoration(vector.offset(target, 0, 0.6, 0), "ghost") then break end
			end
		end
		H.burst(vector.offset(pos, 0, 4, 0), "ffa_halloween_bat.png", 4, player:get_player_name())
	end
end
