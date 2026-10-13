local H = ffa_halloween
local flights = {}
local landings = {}
local pose = {
	Body = {x = -math.pi / 2, y = math.pi, z = 0},
	Head = {x = math.pi / 2, y = 0, z = 0},
	Arm_Left = {x = 0, y = 0, z = 0},
	Arm_Right = {x = 0, y = 0, z = 0},
	Leg_Left = {x = math.pi, y = 0, z = 0},
	Leg_Right = {x = math.pi, y = 0, z = 0},
	Cape = {x = math.pi, y = 0, z = 0},
}

function H.stop_broom_flight(player)
	local name = player:get_player_name()
	local flight = flights[name]
	if not flight then return end
	flights[name] = nil
	-- Fall reports may arrive just after the server detects the landing.
	landings[name] = core.get_us_time() / 1000000 + 1
	if flight.overrides then
		for bone in pairs(pose) do
			player:set_bone_override(bone, flight.overrides[bone])
		end
	end
end

function H.start_broom_flight(player)
	-- Bone overrides keep skins, armor, collision and camera settings intact.
	if player:get_attach() then return end
	local name = player:get_player_name()
	if flights[name] then return end
	landings[name] = nil
	flights[name] = {
		player = player, mesh = player:get_properties().mesh,
		started = core.get_us_time() / 1000000,
	}
end

local timer = 0
core.register_globalstep(function(dt)
	timer = timer + dt
	if timer < 0.1 then return end
	timer = 0
	for name, flight in pairs(flights) do
		local player = flight.player
		local pos, properties = player:get_pos(), player:get_properties()
		local node = pos and core.get_node_or_nil(pos)
		local def = node and core.registered_nodes[node.name]
		if core.get_player_by_name(name) ~= player or player:get_hp() <= 0
				or player:get_attach() or properties.mesh ~= flight.mesh
				or not def or node.name == "ignore" or def.climbable or def.liquidtype ~= "none" then
			H.stop_broom_flight(player)
		else
			local feet = vector.offset(pos, 0, (properties.collisionbox or {})[2] or 0, 0)
			local grounded = not throwables.clear_path(vector.offset(feet, 0, 0.1, 0), vector.offset(feet, 0, -0.15, 0))
			if not grounded and not flight.overrides then
				flight.overrides = player:get_bone_overrides()
				for bone, rotation in pairs(pose) do
					local override = table.copy(flight.overrides[bone] or {})
					override.rotation = {vec = rotation, absolute = true, interpolation = 0.15}
					player:set_bone_override(bone, override)
				end
			elseif grounded and ((flight.overrides and player:get_velocity().y <= 0.1)
					or (not flight.overrides and core.get_us_time() / 1000000 - flight.started > 1)) then
				H.stop_broom_flight(player)
			end
		end
	end
end)

core.register_on_player_hpchange(function(player, change, reason)
	local name = player:get_player_name()
	if change < 0 and reason.type == "fall" and (flights[name]
			or (landings[name] or 0) > core.get_us_time() / 1000000) then
		return 0, true
	end
	return change
end, true)

local function clear_flight(player)
	H.stop_broom_flight(player)
	landings[player:get_player_name()] = nil
end

core.register_on_dieplayer(clear_flight)
core.register_on_leaveplayer(clear_flight)
