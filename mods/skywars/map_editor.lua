local S = core.get_translator(core.get_current_modname())
local editor_state = {}
local list_state = {}

local function F(value)
	return core.formspec_escape(tostring(value or ""))
end

local function pos_text(pos)
	if not pos then
		return S("Not defined")
	end
	return ("%0.1f, %0.1f, %0.1f"):format(pos.x, pos.y, pos.z)
end

local function cube_text(map)
	local bounds = skywars.map_bounds(map)
	if not bounds then
		return S("Cube: define both positions")
	end
	return S("Cube: @1 × @2 × @3", math.floor(bounds.max.x - bounds.min.x + 1),
		math.floor(bounds.max.y - bounds.min.y + 1), math.floor(bounds.max.z - bounds.min.z + 1))
end

local function map_status(map_id, map)
	if map.enabled == false then
		return S("Disabled")
	end
	if map_id == skywars.get_current_map_id() then
		return S("Active")
	end
	return skywars.is_map_ready(map) and S("Ready") or S("Incomplete")
end

local function show_list(player, requested_page)
	local name = player:get_player_name()
	local ids = skywars.get_map_ids(false)
	local current = skywars.get_current_map_id() or S("None")
	local page_count = math.max(1, math.ceil(#ids / 8))
	local page = math.max(1, math.min(requested_page or (list_state[name] and list_state[name].page) or 1, page_count))
	list_state[name] = {page = page}
	local rotation = skywars.is_rotation_paused() and S("Paused") or S("Running")
	local formspec = {
		"formspec_version[6]size[15,11.4]",
		"bgcolor[#10131CEE;true]",
		"style_type[button;bgcolor=#284B63;bgcolor_hovered=#3C6E71;border=false]",
		"style_type[button_exit;bgcolor=#A23B3B;bgcolor_hovered=#C8553D;border=false]",
		"box[0.35,0.25;14.3,1.45;#1D2A40]",
		"label[0.65,0.48;" .. F(S("Skywars map manager")) .. "]",
		"label[0.65,0.92;" .. F(S("Active map: @1", current)) .. "]",
		"label[5.25,0.92;" .. F(S("Automatic rotation: @1", rotation)) .. "]",
		"button[9.7,0.66;2.45,0.58;rotation_toggle;"
			.. F(skywars.is_rotation_paused() and S("Resume rotation") or S("Pause rotation")) .. "]",
		"button_exit[12.35,0.66;1.85,0.58;close;" .. F(S("Close")) .. "]",
		"field[0.65,2.15;5.2,0.7;new_map;" .. F(S("New map name")) .. ";]",
		"button[5.95,1.88;2.0,0.7;create;" .. F(S("Create")) .. "]",
		"label[0.65,2.8;" .. F(S("MAP")) .. "]",
		"label[4.3,2.8;" .. F(S("STATUS")) .. "]",
		"label[7.1,2.8;" .. F(S("ACTIONS")) .. "]",
		"box[0.45,3.12;14.1,6.75;#18212C99]",
	}

	if #ids == 0 then
		table.insert(formspec, "label[0.75,3.6;" .. F(S("No maps yet. Create one to get started.")) .. "]")
	else
		local first_index = (page - 1) * 8 + 1
		local last_index = math.min(#ids, first_index + 7)
		for index = first_index, last_index do
			local map_id = ids[index]
			local map = skywars.get_map(map_id)
			local y = 3.32 + (index - first_index) * 0.78
			table.insert(formspec, "box[0.62," .. y .. ";13.75,0.58;#243147]")
			table.insert(formspec, "label[0.85," .. (y + 0.15) .. ";" .. F(map_id) .. "]")
			table.insert(formspec, "label[4.3," .. (y + 0.15) .. ";" .. F(map_status(map_id, map)) .. "]")
			table.insert(formspec, "button[7.0," .. (y + 0.03) .. ";1.75,0.48;play_" .. map_id
				.. ";" .. F(S("Play now")) .. "]")
			table.insert(formspec, "button[8.95," .. (y + 0.03) .. ";2.1,0.48;toggle_" .. map_id
				.. ";" .. F(map.enabled == false and S("Enable") or S("Disable")) .. "]")
			table.insert(formspec, "button[11.25," .. (y + 0.03) .. ";2.45,0.48;edit_" .. map_id
				.. ";" .. F(S("Edit")) .. "]")
		end
		if page_count > 1 then
			table.insert(formspec, "label[0.7,10.05;" .. F(S("Page @1/@2", page, page_count)) .. "]")
			table.insert(formspec, "button[6.85,9.88;2,0.58;previous_maps;" .. F(S("Previous")) .. "]")
			table.insert(formspec, "button[9.05,9.88;2,0.58;next_maps;" .. F(S("Next")) .. "]")
		end
	end

	core.show_formspec(name, "skywars:maps", table.concat(formspec))
end

local function show_editor(player, map_id, requested_page)
	local map = skywars.get_map(map_id)
	if not map then
		show_list(player)
		return
	end

	local page_count = math.max(1, math.ceil(#map.spawns / 6))
	local page = math.max(1, math.min(requested_page or 1, page_count))
	editor_state[player:get_player_name()] = {map_id = map_id, page = page}
	local ready = skywars.is_map_ready(map) and S("Ready for rotation") or S("Incomplete")
	local formspec = {
		"formspec_version[6]size[15,11.4]",
		"bgcolor[#10131CEE;true]",
		"style_type[button;bgcolor=#284B63;bgcolor_hovered=#3C6E71;border=false]",
		"style_type[button_exit;bgcolor=#A23B3B;bgcolor_hovered=#C8553D;border=false]",
		"label[0.55,0.35;" .. F(S("Edit map: @1", map_id)) .. "]",
		"label[6.8,0.35;" .. F(ready) .. "]",
		"button[12.1,0.2;2.2,0.6;back;" .. F(S("Maps")) .. "]",
		"field[5.6,10.5;3.3,0.7;rename_map;" .. F(S("New map name")) .. ";" .. F(map_id) .. "]",
		"button[9.0,10.23;1.9,0.65;rename;" .. F(S("Rename")) .. "]",
		"box[0.4,1.05;14.2,2.25;#18212C99]",
		"label[0.65,1.02;" .. F(cube_text(map)) .. "]",
		"label[0.65,1.35;" .. F(S("Position 1")) .. "]",
		"label[3.1,1.35;" .. F(pos_text(map.pos1)) .. "]",
		"button[8.5,1.15;1.6,0.6;set_pos1;" .. F(S("Set")) .. "]",
		"button[10.25,1.15;1.6,0.6;go_pos1;" .. F(S("Go")) .. "]",
		"button[12,1.15;1.8,0.6;clear_pos1;" .. F(S("Delete")) .. "]",
		"label[0.65,2.35;" .. F(S("Position 2")) .. "]",
		"label[3.1,2.35;" .. F(pos_text(map.pos2)) .. "]",
		"button[8.5,2.15;1.6,0.6;set_pos2;" .. F(S("Set")) .. "]",
		"button[10.25,2.15;1.6,0.6;go_pos2;" .. F(S("Go")) .. "]",
		"button[12,2.15;1.8,0.6;clear_pos2;" .. F(S("Delete")) .. "]",
		"box[0.4,3.55;14.2,6.75;#18212C99]",
		"label[0.65,3.8;" .. F(S("Spawns (@1) · Page @2/@3", #map.spawns, page, page_count)) .. "]",
		"button[11.4,3.6;2.4,0.6;add_spawn;" .. F(S("Add current position")) .. "]",
	}
	if page_count > 1 then
		table.insert(formspec, "button[7.6,3.6;1.6,0.6;previous_spawns;" .. F(S("Previous")) .. "]")
		table.insert(formspec, "button[9.4,3.6;1.6,0.6;next_spawns;" .. F(S("Next")) .. "]")
	end

	if #map.spawns == 0 then
		table.insert(formspec, "label[0.65,4.35;" .. F(S("No spawn defined yet.")) .. "]")
	else
		local first_index = (page - 1) * 6 + 1
		local last_index = math.min(#map.spawns, first_index + 5)
		for index = first_index, last_index do
			local spawn = map.spawns[index]
			local y = 4.15 + (index - first_index) * 0.85
			local outside = not skywars.is_position_in_map(spawn, map)
			local suffix = outside and S(" (outside cube)") or ""
			table.insert(formspec, "label[0.75," .. y .. ";"
				.. F(S("Spawn @1: @2", index, pos_text(spawn)) .. suffix) .. "]")
			table.insert(formspec, "button[8.5," .. (y - 0.16) .. ";1.6,0.55;set_spawn_" .. index
				.. ";" .. F(S("Set")) .. "]")
			table.insert(formspec, "button[10.25," .. (y - 0.16) .. ";1.6,0.55;go_spawn_" .. index
				.. ";" .. F(S("Go")) .. "]")
			table.insert(formspec, "button[12," .. (y - 0.16) .. ";1.8,0.55;delete_spawn_" .. index
				.. ";" .. F(S("Delete")) .. "]")
		end
	end

	table.insert(formspec, "button[0.5,10.1;2.3,0.65;activate;" .. F(S("Set active")) .. "]")
	table.insert(formspec, "button[3,10.1;2.3,0.65;save;" .. F(S("Save")) .. "]")
	table.insert(formspec, "button_exit[11.5,10.1;2.3,0.65;delete_map;" .. F(S("Delete map")) .. "]")
	core.show_formspec(player:get_player_name(), "skywars:map_editor", table.concat(formspec))
end

skywars.show_maps = show_list
skywars.show_map_editor = show_editor

local function editor_message(player, message)
	core.chat_send_player(player:get_player_name(), core.colorize("#64B5F6", "[Maps] ") .. message)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if (formname == "skywars:maps" or formname == "skywars:map_editor")
			and not core.check_player_privs(player, {ffa_manager = true}) then
		return
	end
	if formname == "skywars:maps" then
		if fields.quit or fields.close then
			return
		end
		local page = (list_state[player:get_player_name()] and list_state[player:get_player_name()].page) or 1
		if fields.previous_maps then
			show_list(player, page - 1)
			return
		elseif fields.next_maps then
			show_list(player, page + 1)
			return
		elseif fields.rotation_toggle then
			local paused = skywars.set_rotation_paused(not skywars.is_rotation_paused())
			editor_message(player, paused and S("Automatic map rotation paused.")
				or S("Automatic map rotation resumed."))
			show_list(player, page)
			return
		end
		if fields.create then
			local map, error = skywars.create_map(fields.new_map)
			if map then
				editor_message(player, S("Map @1 created.", map.id))
				show_editor(player, map.id)
			else
				editor_message(player, error)
				show_list(player)
			end
			return
		end
		for _, map_id in ipairs(skywars.get_map_ids(false)) do
			if fields["play_" .. map_id] then
				local ok, error = skywars.play_map(map_id)
				editor_message(player, ok and S("Now playing: @1", map_id) or error)
				show_list(player, page)
				return
			elseif fields["toggle_" .. map_id] then
				local ok, error = skywars.set_map_enabled(map_id, not skywars.is_map_enabled(map_id))
				editor_message(player, ok and S("Map @1 updated.", map_id) or error)
				show_list(player, page)
				return
			elseif fields["edit_" .. map_id] then
				show_editor(player, map_id)
				return
			end
		end
	elseif formname == "skywars:map_editor" then
		local state = editor_state[player:get_player_name()] or {}
		local map_id = state.map_id
		local page = state.page or 1
		local map = skywars.get_map(map_id)
		if not map then
			show_list(player)
			return
		end
		if fields.quit and not fields.delete_map then
			return
		end
		if fields.back then
			show_list(player)
			return
		end
		if fields.previous_spawns then
			page = page - 1
		elseif fields.next_spawns then
			page = page + 1
		elseif fields.rename then
			local ok, result = skywars.rename_map(map_id, fields.rename_map)
			if ok then
				editor_message(player, S("Map renamed to @1.", result.id))
				show_editor(player, result.id, page)
				return
			end
			editor_message(player, result)
		elseif fields.save then
			skywars.save_maps()
			editor_message(player, S("Map saved."))
		elseif fields.activate then
			local ok, error = skywars.set_current_map(map_id)
			editor_message(player, ok and S("@1 is now active.", map_id) or error)
		elseif fields.delete_map then
			local ok, error = skywars.delete_map(map_id)
			if ok then
				editor_message(player, S("Map deleted."))
				show_list(player)
				return
			end
			editor_message(player, error)
		elseif fields.add_spawn then
			skywars.add_spawn(map_id, player:get_pos())
			page = math.ceil(#map.spawns / 6)
			editor_message(player, S("Spawn added."))
		else
			for _, key in ipairs({"pos1", "pos2"}) do
				if fields["set_" .. key] then
					skywars.set_map_position(map_id, key, player:get_pos())
					editor_message(player, S("@1 saved.", key))
				elseif fields["go_" .. key] then
					local pos = map[key]
					if pos then
						player:set_pos(pos)
					end
				elseif fields["clear_" .. key] then
					skywars.clear_map_position(map_id, key)
					editor_message(player, S("@1 removed.", key))
				end
			end
			for index, spawn in ipairs(map.spawns) do
				if fields["set_spawn_" .. index] then
					skywars.set_spawn(map_id, index, player:get_pos())
					editor_message(player, S("Spawn @1 saved.", index))
				elseif fields["go_spawn_" .. index] then
					player:set_pos(spawn)
				elseif fields["delete_spawn_" .. index] then
					skywars.delete_spawn(map_id, index)
					editor_message(player, S("Spawn @1 removed.", index))
					break
				end
			end
		end
		show_editor(player, map_id, page)
	end
end)

core.register_chatcommand("maps", {
	description = "Open the map manager.",
	params = "list | edit <name> | create <name> | delete <name>",
	privs = {ffa_manager = true},
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "You must be online to manage maps."
		end
		local action, value = param:match("^(%S+)%s*(.-)%s*$")
		if not action or action == "" then
			show_list(player)
			return true
		end
		if action == "list" then
			return true, table.concat(skywars.get_map_ids(false), ", ")
		elseif action == "edit" then
			if skywars.get_map(value) then
				show_editor(player, value)
				return true
			end
			return false, "Unknown map."
		elseif action == "create" then
			local map, error = skywars.create_map(value)
			if not map then
				return false, error
			end
			show_editor(player, map.id)
			return true, "Map created."
		elseif action == "delete" or action == "del" then
			return skywars.delete_map(value)
		end
		return false, "Usage: /maps [list|edit <name>|create <name>|delete <name>]"
	end,
})

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	editor_state[name] = nil
	list_state[name] = nil
end)
