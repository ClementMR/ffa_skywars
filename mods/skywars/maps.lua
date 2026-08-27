-- Persistent map registry. A map owns its playable cuboid and its spawn list;
-- rotation and cleanup use this data instead of a global center/radius pair.

local storage = core.get_mod_storage()
local STORAGE_KEY = "MAPS"

skywars.maps = skywars.maps or {}

local function copy_pos(pos)
	if type(pos) ~= "table" or type(pos.x) ~= "number"
			or type(pos.y) ~= "number" or type(pos.z) ~= "number" then
		return nil
	end
	return {x = pos.x, y = pos.y, z = pos.z}
end

local function valid_id(map_id)
	return type(map_id) == "string" and map_id:match("^[a-z0-9_-]+$")
		and #map_id >= 3 and #map_id <= 32
end

local function normalize_id(name)
	if type(name) ~= "string" then
		return nil
	end
	local map_id = name:lower():gsub("%s+", "_"):gsub("[^a-z0-9_-]", "")
	return valid_id(map_id) and map_id or nil
end

local function normalize_map(map_id, map)
	if not valid_id(map_id) or type(map) ~= "table" then
		return nil
	end

	local result = {
		id = map_id,
		pos1 = copy_pos(map.pos1),
		pos2 = copy_pos(map.pos2),
		spawns = {},
		enabled = map.enabled ~= false,
		-- During mod initialization Luanti disallows get_gametime(), so old
		-- records without timestamps are represented by zero and receive real
		-- timestamps on their next edit.
		created_at = tonumber(map.created_at) or 0,
		updated_at = tonumber(map.updated_at) or 0,
	}

	for _, spawn in ipairs(map.spawns or {}) do
		local pos = copy_pos(spawn)
		if pos then
			table.insert(result.spawns, pos)
		end
	end

	return result
end

local function has_bounds(map)
	return map and copy_pos(map.pos1) and copy_pos(map.pos2)
end

function skywars.map_bounds(map_or_id)
	local map = type(map_or_id) == "table" and map_or_id
		or skywars.maps[map_or_id]
	if not has_bounds(map) then
		return nil
	end

	return {
		min = {
			x = math.min(map.pos1.x, map.pos2.x),
			y = math.min(map.pos1.y, map.pos2.y),
			z = math.min(map.pos1.z, map.pos2.z),
		},
		max = {
			x = math.max(map.pos1.x, map.pos2.x),
			y = math.max(map.pos1.y, map.pos2.y),
			z = math.max(map.pos1.z, map.pos2.z),
		},
	}
end

function skywars.is_position_in_map(pos, map_or_id)
	if not copy_pos(pos) then
		return false
	end
	-- Most gameplay callers operate on the active map.  Keep explicit map
	-- IDs/tables supported for the editor and rotation code.
	if map_or_id == nil then
		map_or_id = skywars.current_map
	end
	local bounds = skywars.map_bounds(map_or_id)
	return bounds and pos.x >= bounds.min.x and pos.x <= bounds.max.x
		and pos.y >= bounds.min.y and pos.y <= bounds.max.y
		and pos.z >= bounds.min.z and pos.z <= bounds.max.z or false
end

function skywars.is_map_ready(map_or_id)
	local map = type(map_or_id) == "table" and map_or_id
		or skywars.maps[map_or_id]
	if not has_bounds(map) then
		return false
	end
	for _, spawn in ipairs(map.spawns) do
		if skywars.is_position_in_map(spawn, map) then
			return true
		end
	end
	return false
end

function skywars.get_map(map_id)
	return skywars.maps[map_id]
end

function skywars.get_map_ids(ready_only)
	local ids = {}
	for map_id, map in pairs(skywars.maps) do
		if not ready_only or (map.enabled ~= false and skywars.is_map_ready(map)) then
			table.insert(ids, map_id)
		end
	end
	table.sort(ids)
	return ids
end

function skywars.save_maps()
	local serializable = {
		version = 2,
		current_map = skywars.current_map,
		rotation_paused = skywars.rotation_paused == true,
		maps = skywars.maps,
	}
	storage:set_string(STORAGE_KEY, core.serialize(serializable))
end

local function load_maps()
	local stored = core.deserialize(storage:get_string(STORAGE_KEY))
	if type(stored) ~= "table" then
		stored = {maps = {}}
	end

	for map_id, map in pairs(stored.maps or {}) do
		local normalized = normalize_map(map_id, map)
		if normalized then
			skywars.maps[map_id] = normalized
		end
	end

	if valid_id(stored.current_map) and skywars.is_map_ready(stored.current_map) then
		local current = skywars.maps[stored.current_map]
		skywars.current_map = current and current.enabled ~= false and stored.current_map or nil
	else
		skywars.current_map = nil
	end
	if not skywars.current_map then
		local ready_maps = skywars.get_map_ids(true)
		skywars.current_map = ready_maps[1]
	end
	skywars.rotation_paused = stored.rotation_paused == true

	skywars.save_maps()
end

function skywars.get_current_map_id()
	return skywars.current_map
end

function skywars.get_current_map()
	return skywars.maps[skywars.current_map]
end

function skywars.set_current_map(map_id)
	local map = skywars.maps[map_id]
	if map and map.enabled == false then
		return false, "This map is disabled."
	end
	if not skywars.is_map_ready(map_id) then
		return false, "This map needs two positions and at least one spawn."
	end
	skywars.current_map = map_id
	skywars.save_maps()
	return true
end

function skywars.is_map_enabled(map_id)
	local map = skywars.maps[map_id]
	return map and map.enabled ~= false or false
end

function skywars.set_map_enabled(map_id, enabled)
	local map = skywars.maps[map_id]
	if not map then
		return false, "This map does not exist."
	end
	if enabled == false and map_id == skywars.current_map then
		return false, "Activate another map before disabling the current map."
	end
	map.enabled = enabled ~= false
	map.updated_at = core.get_gametime()
	skywars.save_maps()
	return true
end

function skywars.is_rotation_paused()
	return skywars.rotation_paused == true
end

function skywars.set_rotation_paused(paused)
	skywars.rotation_paused = paused == true
	skywars.save_maps()
	return skywars.rotation_paused
end

function skywars.play_map(map_id)
	if skywars.rotation_in_progress or skywars.cleanup_in_progress then
		return false, "A map rotation or cleanup is already running."
	end
	local activated, error = skywars.set_current_map(map_id)
	if not activated then
		return false, error
	end
	for _, player in ipairs(core.get_connected_players()) do
		if not core.check_player_privs(player:get_player_name(), {creative = true}) then
			skywars.teleport_player(player, map_id)
		end
	end
	return true
end

function skywars.create_map(name)
	local map_id = normalize_id(name)
	if not map_id then
		return nil, "Use 3 to 32 letters, digits, underscores or hyphens."
	end
	if skywars.maps[map_id] then
		return nil, "A map with this name already exists."
	end

	skywars.maps[map_id] = {
		id = map_id,
		spawns = {},
		enabled = true,
		created_at = core.get_gametime(),
		updated_at = core.get_gametime(),
	}
	skywars.save_maps()
	return skywars.maps[map_id]
end

function skywars.delete_map(map_id)
	if not skywars.maps[map_id] then
		return false, "This map does not exist."
	end
	if map_id == skywars.current_map then
		return false, "Activate another ready map before deleting the current one."
	end
	skywars.maps[map_id] = nil
	skywars.save_maps()
	return true
end

function skywars.set_map_position(map_id, position_name, pos)
	local map = skywars.maps[map_id]
	local position = copy_pos(pos)
	if not map or (position_name ~= "pos1" and position_name ~= "pos2") or not position then
		return false
	end
	map[position_name] = position
	map.updated_at = core.get_gametime()
	skywars.save_maps()
	return true
end

function skywars.clear_map_position(map_id, position_name)
	local map = skywars.maps[map_id]
	if not map or (position_name ~= "pos1" and position_name ~= "pos2") then
		return false
	end
	map[position_name] = nil
	map.updated_at = core.get_gametime()
	skywars.save_maps()
	return true
end

function skywars.add_spawn(map_id, pos)
	local map = skywars.maps[map_id]
	local spawn = copy_pos(pos)
	if not map or not spawn then
		return false
	end
	table.insert(map.spawns, spawn)
	map.updated_at = core.get_gametime()
	skywars.save_maps()
	return #map.spawns
end

function skywars.set_spawn(map_id, index, pos)
	local map = skywars.maps[map_id]
	local spawn = copy_pos(pos)
	if not map or not map.spawns[index] or not spawn then
		return false
	end
	map.spawns[index] = spawn
	map.updated_at = core.get_gametime()
	skywars.save_maps()
	return true
end

function skywars.delete_spawn(map_id, index)
	local map = skywars.maps[map_id]
	if not map or not map.spawns[index] then
		return false
	end
	table.remove(map.spawns, index)
	map.updated_at = core.get_gametime()
	skywars.save_maps()
	return true
end

function skywars.get_random_spawn(map_or_id)
	local map = type(map_or_id) == "table" and map_or_id
		or skywars.maps[map_or_id or skywars.current_map]
	if not map or #map.spawns == 0 then
		return nil
	end

	local spawns = {}
	for _, spawn in ipairs(map.spawns) do
		if skywars.is_position_in_map(spawn, map) then
			table.insert(spawns, spawn)
		end
	end
	if #spawns == 0 then
		return nil
	end
	return copy_pos(spawns[math.random(#spawns)])
end

-- Returns a random ready map different from the current map whenever possible.
function skywars.pick_next_map()
	local candidates = {}
	for _, map_id in ipairs(skywars.get_map_ids(true)) do
		if map_id ~= skywars.current_map then
			table.insert(candidates, map_id)
		end
	end
	if #candidates > 0 then
		return candidates[math.random(#candidates)]
	end
	return skywars.is_map_ready(skywars.current_map) and skywars.current_map or nil
end

load_maps()
