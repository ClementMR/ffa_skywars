local H = ffa_halloween

local to_theme, to_original, tracked, names = {}, {}, {}, {}
local scan_index = 0
local restoring = false
local waiting_for_cleanup = false
local saved = core.deserialize(H.storage:get_string("themed_chests"))
if type(saved) == "table" then
	for key, pos in pairs(saved) do
		if type(key) == "string" and type(pos) == "table" and type(pos.x) == "number"
				and type(pos.y) == "number" and type(pos.z) == "number" then tracked[key] = pos end
	end
end

local function remember(key, pos)
	if (tracked[key] == nil) == (pos == nil) then return end
	tracked[key] = pos
	H.storage:set_string("themed_chests", core.serialize(tracked))
end

function H.pending_restores()
	local count = 0
	for _, pos in pairs(tracked) do
		if not H.active then count = count + 1 end
	end
	return count
end

function H.skin_chest(pos)
	-- SkyWars writes a whole VoxelManip snapshot at the end of cleanup. A
	-- concurrent swap could be overwritten after its undo journal was cleared.
	if skywars.cleanup_in_progress then return end
	local node = core.get_node_or_nil(pos)
	if not node or node.name == "ignore" then return end
	local key = core.pos_to_string(pos)
	local original = to_original[node.name] or node.name
	if not to_theme[original] then remember(key, nil); return end
	local themed = H.active
	local desired = themed and to_theme[original] or original
	-- Persist the position before swapping so a restart can finish restoration.
	if themed then remember(key, vector.copy(pos)) end
	if node.name ~= desired then
		node.name = desired
		core.swap_node(pos, node) -- preserve inventory, timer and orientation
	end
	if not themed then remember(key, nil) end
	for _, open in pairs(default.chest.open_chests) do
		if vector.equals(open.pos, pos) then
			local base = to_original[open.swap] or open.swap
			open.swap = themed and (to_theme[base] or base) or base
		end
	end
	if not themed then H.clean_inventory(core.get_meta(pos):get_inventory()) end
end

function H.restore_chests()
	if H.active then return end
	if skywars.cleanup_in_progress then
		if not waiting_for_cleanup then
			waiting_for_cleanup = true
			core.after(0.5, function()
				waiting_for_cleanup = false
				H.restore_chests()
			end)
		end
		return
	end
	local positions = {}
	for _, pos in pairs(tracked) do positions[#positions + 1] = pos end
	for _, pos in ipairs(positions) do H.skin_chest(pos) end
	if restoring then return end
	local queue = {}
	for _, pos in pairs(tracked) do
		queue[#queue + 1] = pos
	end
	if #queue == 0 then return end
	restoring = true
	local blocked_by_cleanup = false
	local index = 0
	local function step()
		index = index + 1
		local pos = queue[index]
		if not pos then
			restoring = false
			if blocked_by_cleanup and not H.active then
				core.after(0, H.restore_chests)
			end
			return
		end
		-- Emerge only the recorded chest block, never a complete 200x200 map.
		core.emerge_area(pos, pos, function(_, _, remaining)
			if remaining ~= 0 then return end
			if skywars.cleanup_in_progress then blocked_by_cleanup = true end
			H.skin_chest(pos)
			core.after(0.1, step)
		end)
	end
	step()
end

for _, tier in ipairs({"regular", "mese", "diamond"}) do
	for _, suffix in ipairs({"", "_open"}) do
		local original = "ffa_loot:" .. tier .. "_chest" .. suffix
		local themed = "ffa_halloween:" .. tier .. "_chest" .. suffix
		to_theme[original], to_original[themed] = themed, original
		names[#names + 1], names[#names + 2] = original, themed
		local def = table.copy(core.registered_nodes[original])
		def.name, def.mod_origin = nil, nil
		def.description = "Haunted " .. tier:gsub("^%l", string.upper) .. " Chest"
		def.groups = table.copy(def.groups)
		def.groups.not_in_creative_inventory = 1
		def.drop = ""
		def.tiles = {}
		local old = core.registered_nodes[original]
		for index, tile in ipairs(old.tiles) do
			local texture = type(tile) == "string" and tile or tile.name
			-- Prefixing the existing atlas preserves the opened chest mesh UVs.
			local name = "(" .. texture .. ")^[colorize:#6A3159:100"
			if (suffix == "_open" and index == 5) or (suffix == "" and index == 6) then
				name = name .. "^ffa_halloween_chest_face.png"
			end
			def.tiles[index] = {name = name, backface_culling = true}
		end
		def.light_source = tier == "diamond" and 5 or 3
		def.on_rightclick = function(pos, node, player, stack, pointed)
			local result = old.on_rightclick(pos, {name = original, param1 = node.param1, param2 = node.param2},
				player, stack, pointed)
			H.skin_chest(pos)
			if H.active then H.sound("chest", {to_player = player:get_player_name(), gain = 0.2}) end
			return result
		end
		def.on_timer = function(pos, elapsed)
			local result = old.on_timer and old.on_timer(pos, elapsed)
			H.skin_chest(pos)
			return result
		end
		-- Retain the base chest's access logging and inventory callbacks.
		core.register_node(themed, def)
	end
end

core.register_lbm({
	name = "ffa_halloween:restore_or_theme_chests", 
	label = "Restore or theme haunted chests",
	nodenames = names,
	run_at_every_load = true,
	action = function(pos, node)
		local original = to_original[node.name]
		if original and original:sub(-5) == "_open" and not original:find("diamond", 1, true) then
			node.name = original:sub(1, -6)
			core.swap_node(pos, node)
		end
		H.skin_chest(pos)
	end,
})

core.register_on_mods_loaded(function()
	core.after(0, H.restore_chests)
end)

function H.scan_environment(players)
	if #players == 0 or skywars.cleanup_in_progress then return end
	scan_index = scan_index % #players + 1
	local player = players[scan_index]
	local pos = vector.round(player:get_pos())
	-- One bounded, loaded-area scan per two seconds, independent of map volume.
	local found = core.find_nodes_in_area(vector.offset(pos, -14, -6, -14),
		vector.offset(pos, 14, 6, 14), names)
	for _, chest in ipairs(found) do
		H.skin_chest(chest)
		if math.random() < 0.2 then
			H.spawn_decoration(vector.offset(chest, 0, 1.1, 0), "lantern")
		end
	end
end
