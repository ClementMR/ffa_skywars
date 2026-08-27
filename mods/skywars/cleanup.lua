local S = core.get_translator(core.get_current_modname())

local cleanup_interval = math.max(60,
	tonumber(core.settings:get("skywars_cleanup_interval")) or 2700)
local transition_delay = math.max(0,
	tonumber(core.settings:get("skywars_map_rotation_delay")) or 15)
local max_cleanup_volume = math.max(1,
	tonumber(core.settings:get("skywars_max_cleanup_volume")) or 20000000)
local air = core.get_content_id("air")

local nodes_to_clear = {}
for _, nodename in ipairs(skywars.whitelist or {}) do
	nodes_to_clear[core.get_content_id(nodename)] = true
end

skywars.cleanup_timer = cleanup_interval
skywars.cleanup_in_progress = false
skywars.rotation_in_progress = false
local rotation_token = 0

local function integer_bounds(map_or_id)
	local bounds = skywars.map_bounds(map_or_id)
	if not bounds then
		return nil
	end
	local result = {
		min = {
			x = math.floor(bounds.min.x),
			y = math.floor(bounds.min.y),
			z = math.floor(bounds.min.z),
		},
		max = {
			x = math.ceil(bounds.max.x),
			y = math.ceil(bounds.max.y),
			z = math.ceil(bounds.max.z),
		},
	}
	local volume = (result.max.x - result.min.x + 1)
		* (result.max.y - result.min.y + 1)
		* (result.max.z - result.min.z + 1)
	if volume > max_cleanup_volume then
		return nil, ("The map cuboid contains %d nodes; the configured cleanup limit is %d.")
			:format(volume, max_cleanup_volume)
	end
	return result
end

local function is_in_bounds(pos, bounds)
	return pos and pos.x >= bounds.min.x and pos.x <= bounds.max.x
		and pos.y >= bounds.min.y and pos.y <= bounds.max.y
		and pos.z >= bounds.min.z and pos.z <= bounds.max.z
end

local function batch_process(list, batch_size, callback, done)
	local index = 1
	local function step()
		for _ = 1, batch_size do
			if index > #list then
				if done then
					done()
				end
				return
			end
			callback(list[index])
			index = index + 1
		end
		core.after(0, step)
	end
	step()
end

local function remove_dynamic_objects(bounds, done)
	local center = {
		x = (bounds.min.x + bounds.max.x) / 2,
		y = (bounds.min.y + bounds.max.y) / 2,
		z = (bounds.min.z + bounds.max.z) / 2,
	}
	local half_diagonal = vector.distance(bounds.min, center) + 1
	local objects = {}

	for _, object in ipairs(core.get_objects_inside_radius(center, half_diagonal)) do
		local pos = object:get_pos()
		if pos and not object:is_player() and is_in_bounds(pos, bounds) and object:get_luaentity().name == "__builtin:item" then
			table.insert(objects, object)
		end
	end

	batch_process(objects, 25, function(object)
		if object and object:get_luaentity() then
			object:remove()
		end
	end, done)
end

local function clear_nodes(bounds, done)
	local emerged = false
	core.emerge_area(bounds.min, bounds.max, function(_, _, calls_remaining)
		if calls_remaining ~= 0 or emerged then
			return
		end
		emerged = true

		local vm = core.get_voxel_manip()
		local emin, emax = vm:read_from_map(bounds.min, bounds.max)
		local data = vm:get_data()
		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		local x, y, z = bounds.min.x, bounds.min.y, bounds.min.z
		local has_changes = false

		local function scan_step()
			for _ = 1, 50000 do
				if z > bounds.max.z then
					if has_changes then
						vm:set_data(data)
						vm:write_to_map()
						vm:update_map()
					end
					done()
					return
				end

				local index = area:index(x, y, z)
				if nodes_to_clear[data[index]] then
					data[index] = air
					has_changes = true
				end

				x = x + 1
				if x > bounds.max.x then
					x = bounds.min.x
					y = y + 1
					if y > bounds.max.y then
						y = bounds.min.y
						z = z + 1
					end
				end
			end
			core.after(0, scan_step)
		end

		scan_step()
	end)
end

-- Cleans a snapshot of one map. It does not read skywars.current_map after
-- starting, so a concurrent map change cannot redirect cleanup to a new map.
function skywars.cleanup_map(map_or_id, done)
	if skywars.cleanup_in_progress then
		return false, "A cleanup is already in progress."
	end

	local bounds, bounds_error = integer_bounds(map_or_id)
	if not bounds then
		return false, bounds_error or "This map has no complete cuboid."
	end

	skywars.cleanup_in_progress = true
	remove_dynamic_objects(bounds, function()
		clear_nodes(bounds, function()
			skywars.cleanup_in_progress = false
			if done then
				done()
			end
		end)
	end)
	return true
end

local function cleanup_hud(player, text, duration)
	hud_api.show(player, "skywars:cleanup", {
		type = "text",
		text = text,
		number = 0xFFB020,
		position = {x = 1, y = 0},
		alignment = {x = -1, y = 1},
		offset = {x = -24, y = 24},
		size = {x = 1.15, y = 1.15},
		style = 1,
		z_index = 10,
	}, {duration = duration, background = false})
end

local function announce_warning(seconds, next_map_id)
	for _, player in ipairs(core.get_connected_players()) do
		cleanup_hud(player, S("Map cleanup in @1s", seconds),
			math.max(1, math.min(seconds, 8)))
	end
end

local function snapshot_map(map)
	local bounds = skywars.map_bounds(map)
	if not bounds then
		return nil
	end
	return {
		-- Copy the points instead of retaining the persistent map table: an
		-- administrator can still edit a map while its rotation warning is up.
		pos1 = {
			x = bounds.min.x,
			y = bounds.min.y,
			z = bounds.min.z,
		},
		pos2 = {
			x = bounds.max.x,
			y = bounds.max.y,
			z = bounds.max.z,
		},
	}
end

local function schedule_final_warnings(delay, next_id, token)
	for _, seconds in ipairs({30, 10, 5}) do
		if seconds < delay then
			core.after(delay - seconds, function()
				if skywars.rotation_in_progress and rotation_token == token then
					announce_warning(seconds, next_id)
				end
			end)
		end
	end
end

local function transition_players(map_id)
	for _, player in ipairs(core.get_connected_players()) do
		if not core.check_player_privs(player:get_player_name(), {creative = true}) then
			skywars.teleport_player(player, map_id)
		end
	end
end

-- Announces, moves players to a different ready map where possible, and then
-- clears the previous cuboid. With one usable map, it cleans and reuses it.
function skywars.start_map_rotation(delay, automatic)
	if automatic and skywars.is_rotation_paused and skywars.is_rotation_paused() then
		return false, "Automatic map rotation is paused."
	end
	if skywars.rotation_in_progress or skywars.cleanup_in_progress then
		return false, "A map rotation or cleanup is already running."
	end

	local current_map = skywars.get_current_map()
	if not skywars.is_map_ready(current_map) then
		return false, "The active map is incomplete. Define its two positions and a spawn."
	end
	local current_snapshot = snapshot_map(current_map)
	if not current_snapshot then
		return false, "The active map has no complete cuboid."
	end

	local next_id = skywars.pick_next_map()
	if not next_id then
		return false, "No ready map is available."
	end

	skywars.rotation_in_progress = true
	rotation_token = rotation_token + 1
	local token = rotation_token
	delay = delay == nil and transition_delay or math.max(0, delay)
	announce_warning(delay, next_id)
	schedule_final_warnings(delay, next_id, token)

	core.after(delay, function()
		if automatic and skywars.is_rotation_paused and skywars.is_rotation_paused() then
			skywars.rotation_in_progress = false
			return
		end
		-- An admin may have deleted or invalidated the selected map during the
		-- warning. Pick a safe candidate again at the last possible moment.
		if not skywars.is_map_ready(next_id) then
			next_id = skywars.pick_next_map()
		end
		if not next_id or not skywars.is_map_ready(next_id) then
			skywars.rotation_in_progress = false
			skywars.cleanup_timer = cleanup_interval
			core.chat_send_all(core.colorize("#FF5252", S("[Map] Rotation cancelled: no ready map.")))
			return
		end

		local activated, error = skywars.set_current_map(next_id)
		if not activated then
			skywars.rotation_in_progress = false
			skywars.cleanup_timer = cleanup_interval
			core.log("warning", "[skywars] map rotation failed: " .. tostring(error))
			return
		end

		transition_players(next_id)
		core.chat_send_all(core.colorize("#6EE7B7", S("[Map] Now playing: @1.", next_id)))
		for _, player in ipairs(core.get_connected_players()) do
			cleanup_hud(player, S("Now playing: @1", next_id), 5)
		end

		local started = skywars.cleanup_map(current_snapshot, function()
			skywars.rotation_in_progress = false
			skywars.cleanup_timer = cleanup_interval
			core.chat_send_all(core.colorize("#93C5FD", S("[Map] Cleanup complete.")))
		end)
		if not started then
			skywars.rotation_in_progress = false
			skywars.cleanup_timer = cleanup_interval
		end
	end)
	return true
end

core.register_chatcommand("cleanup", {
	description = "Start the cleanup.",
	privs = {ffa_manager = true},
	func = function(_, param)
		local current_map = skywars.get_current_map()
		if not skywars.is_map_ready(current_map) then
			return false, "The active map is incomplete. Define its two positions and a spawn."
		end
		local current_snapshot = snapshot_map(current_map)
		if not current_snapshot then
			return false, "The active map has no complete cuboid."
		end

		transition_players()

		skywars.cleanup_map(current_snapshot)
		core.chat_send_all(core.colorize("#93C5FD", S("[Map] Cleanup complete. Requested by server.")))
	end,
})

core.register_chatcommand("maprotate", {
	description = "Start a random map rotation without repeating the current map.",
	params = "[now]",
	privs = {ffa_manager = true},
	func = function(_, param)
		local delay = param:trim() == "now" and 0 or transition_delay
		local ok, message = skywars.start_map_rotation(delay)
		return ok, message or "Map rotation scheduled."
	end,
})

for _, command in ipairs({"clean_timer", "ct"}) do
	core.register_chatcommand(command, {
		description = S("Print the remaining time before the next map rotation."),
		privs = {interact = true},
		func = function()
			local seconds = math.max(0, skywars.cleanup_timer or 0)
			return true, core.colorize("#FFB020", S("[Map] Next cleanup in @1m @2s.",
				math.floor(seconds / 60), seconds % 60))
		end,
	})
end

local warning_thresholds = {
	[60] = true,
	[30] = true,
	[10] = true,
	[5] = true,
}

local function update_cleanup_timer()
	if skywars.is_rotation_paused and skywars.is_rotation_paused() then
		core.after(1, update_cleanup_timer)
		return
	end

	if not skywars.rotation_in_progress and not skywars.cleanup_in_progress then
		-- Start the transition at the beginning of its countdown.  Previously
		-- the timer reached zero and then started another full warning delay,
		-- so a "10 seconds" message could actually take 20 seconds.
		if skywars.cleanup_timer <= transition_delay then
			local delay = math.max(0, skywars.cleanup_timer)
			local ok, error = skywars.start_map_rotation(delay, true)
			if not ok then
				core.log("warning", "[skywars] automatic rotation failed: " .. tostring(error))
				skywars.cleanup_timer = cleanup_interval
			end
		elseif warning_thresholds[skywars.cleanup_timer] then
			announce_warning(skywars.cleanup_timer, skywars.pick_next_map())
		end

		if not skywars.rotation_in_progress then
			skywars.cleanup_timer = skywars.cleanup_timer - 1
		end
	end

	core.after(1, update_cleanup_timer)
end

core.after(1, update_cleanup_timer)
