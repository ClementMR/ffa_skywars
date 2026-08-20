-- Named, layered HUD manager.
--
-- A HUD is owned by a player and a caller-provided key. Reusing the same key
-- updates it in place, which prevents duplicate HUD elements during timers or
-- repeated announcements.

hud_api = rawget(_G, "hud_api") or {}

local api = hud_api

-- Keep this public table for compatibility with the first version of the mod.
-- New code should use get_id()/get_ids() instead of reading it directly.
api.huds = api.huds or {}
api._entries = api._entries or {}

api.layouts = api.layouts or {}
api.layouts.front = api.layouts.front or {
	position = {x = 0.5, y = 0.3},
	background_scale = {x = 5, y = 3},
	text_size = {x = 2, y = 2},
}
api.layouts.actionbar = api.layouts.actionbar or {
	position = {x = 0.5, y = 0.8},
	background_scale = {x = 1.4, y = 1.4},
	text_size = {x = 1.1, y = 1.1},
}
api.layouts.top_right = api.layouts.top_right or {
	position = {x = 1, y = 0},
	offset = {x = -24, y = 24},
	-- In Luanti, -1 moves an element left/up and 1 moves it right/down.
	alignment = {x = -1, y = 1},
	background_scale = {x = 1.55, y = 1.45},
	text_size = {x = 1.15, y = 1.15},
	color = 0xFFCC4D,
	style = 1,
}

local function copy(value)
	if type(value) ~= "table" then
		return value
	end

	local result = {}
	for key, child in pairs(value) do
		result[key] = copy(child)
	end
	return result
end

local function merge(defaults, overrides)
	local result = copy(defaults or {})
	for key, value in pairs(overrides or {}) do
		result[key] = copy(value)
	end
	return result
end

local function same_value(first, second)
	if type(first) ~= type(second) then
		return false
	end
	if type(first) ~= "table" then
		return first == second
	end
	for key, value in pairs(first) do
		if not same_value(value, second[key]) then
			return false
		end
	end
	for key in pairs(second) do
		if first[key] == nil then
			return false
		end
	end
	return true
end

-- Returns the connected player when available, together with a stable key for
-- internal storage. String player names are useful for cleanup callbacks.
local function player_info(player_or_name)
	if type(player_or_name) == "string" then
		return core.get_player_by_name(player_or_name), string.lower(player_or_name), player_or_name
	end

	if not player_or_name then
		return nil
	end
	if type(player_or_name) ~= "table" and type(player_or_name) ~= "userdata" then
		return nil
	end

	local ok, name = pcall(player_or_name.get_player_name, player_or_name)
	if not ok or type(name) ~= "string" or name == "" then
		return nil
	end
	return player_or_name, string.lower(name), name
end

local function normalise_key(key)
	if type(key) ~= "string" or key == "" then
		return nil
	end
	return key
end

local function legacy_base(player_key, key)
	return "hud_api:" .. player_key .. "_" .. key
end

local function normalise_definition(definition)
	local result = copy(definition)

	-- Friendlier aliases for the two properties most often used by text HUDs.
	if result.color ~= nil and result.number == nil then
		result.number = result.color
	end
	result.color = nil
	if result.anchor ~= nil and result.alignment == nil then
		result.alignment = result.anchor
	end
	result.anchor = nil

	return result
end

-- A definition can either be one normal HUD definition or a table of named
-- layers. Named layers allow a background and text to be managed as one HUD.
local function normalise_layers(definition)
	if type(definition) ~= "table" then
		return nil, "HUD definition must be a table"
	end

	if definition.type then
		return {main = normalise_definition(definition)}, "main"
	end

	local source = definition.layers or definition
	local layers = {}
	for layer, hud_definition in pairs(source) do
		local layer_name = type(layer) == "number" and tostring(layer) or layer
		if type(layer_name) ~= "string" or layer_name == "" then
			return nil, "HUD layer names must be non-empty strings"
		end
		if type(hud_definition) ~= "table" or not hud_definition.type then
			return nil, "HUD layer '" .. layer_name .. "' has no type"
		end
		layers[layer_name] = normalise_definition(hud_definition)
	end

	if not next(layers) then
		return nil, "HUD needs at least one layer"
	end

	return layers, layers.main and "main" or next(layers)
end

local function get_bucket(player_key, create)
	local bucket = api._entries[player_key]
	if not bucket and create then
		bucket = {}
		api._entries[player_key] = bucket
	end
	return bucket
end

local function clear_legacy_aliases(entry)
	for alias in pairs(entry.legacy_aliases or {}) do
		api.huds[alias] = nil
	end
	entry.legacy_aliases = {}
end

local function refresh_legacy_aliases(entry)
	clear_legacy_aliases(entry)

	local base = legacy_base(entry.player_key, entry.key)
	local aliases = entry.legacy_layers
	if aliases then
		for suffix, layer in pairs(aliases) do
			local element = entry.elements[layer]
			if element then
				local alias = base .. suffix
				api.huds[alias] = element.id
				entry.legacy_aliases[alias] = true
			end
		end
		return
	end

	local primary = entry.elements[entry.primary]
	if primary then
		api.huds[base] = primary.id
		entry.legacy_aliases[base] = true
	end
	for layer, element in pairs(entry.elements) do
		local alias = base .. "_" .. layer
		api.huds[alias] = element.id
		entry.legacy_aliases[alias] = true
	end
end

local function remove_hud(player, id)
	if player and id ~= nil then
		pcall(player.hud_remove, player, id)
	end
end

local function add_hud(player, definition)
	local ok, id = pcall(player.hud_add, player, definition)
	if not ok or id == nil then
		local reason = ok and "hud_add returned no id" or tostring(id)
		core.log("warning", "[hud_api] Unable to add HUD: " .. reason)
		return nil, reason
	end
	return id
end

local function can_change(old_definition, new_definition)
	if old_definition.type ~= new_definition.type then
		return false
	end
	for property in pairs(old_definition) do
		-- hud_change cannot reset a missing property to its engine default.
		if property ~= "type" and new_definition[property] == nil then
			return false
		end
	end
	return true
end

local function update_element(player, element, definition)
	if not can_change(element.definition, definition) then
		remove_hud(player, element.id)
		local id, reason = add_hud(player, definition)
		if not id then
			return nil, reason
		end
		element.id = id
		element.definition = copy(definition)
		return element
	end

	for property, value in pairs(definition) do
		if property ~= "type" and not same_value(element.definition[property], value) then
			local ok, changed = pcall(player.hud_change, player, element.id, property, copy(value))
			if not ok or changed == false then
				-- Recreating is safer than keeping a partly-updated HUD when a
				-- property is not supported by this engine version.
				remove_hud(player, element.id)
				local id, reason = add_hud(player, definition)
				if not id then
					return nil, reason
				end
				element.id = id
				break
			end
		end
	end

	element.definition = copy(definition)
	return element
end

local function remove_entry(player, bucket, key)
	local entry = bucket and bucket[key]
	if not entry then
		return false
	end

	entry.expiry_token = (entry.expiry_token or 0) + 1
	clear_legacy_aliases(entry)
	for _, element in pairs(entry.elements) do
		remove_hud(player, element.id)
	end
	bucket[key] = nil
	if not next(bucket) then
		api._entries[entry.player_key] = nil
	end
	return true
end

local function arm_expiry(entry, duration, on_expire)
	entry.expiry_token = (entry.expiry_token or 0) + 1
	if type(duration) ~= "number" or duration <= 0 then
		return true
	end

	local token = entry.expiry_token
	core.after(duration, function()
		local bucket = get_bucket(entry.player_key)
		local current = bucket and bucket[entry.key]
		if current ~= entry or entry.expiry_token ~= token then
			return
		end

		local player = core.get_player_by_name(entry.player_name)
		remove_entry(player, bucket, entry.key)
		if type(on_expire) == "function" then
			local ok, err = pcall(on_expire, player, entry.key)
			if not ok then
				core.log("warning", "[hud_api] HUD expiry callback failed: " .. tostring(err))
			end
		end
	end)
	return true
end

--- Show or replace a named HUD.
-- @param player Player ObjectRef or a connected player's name
-- @param key Stable caller-owned name, e.g. "cleanup_warning"
-- @param definition One HUD definition, or named layers such as
--   {background = {...}, text = {...}}
-- @param options Optional {duration = seconds, on_expire = function}
-- @return The primary HUD id, or nil and an error message
function api.show(player, key, definition, options)
	local object, player_key, player_name = player_info(player)
	key = normalise_key(key)
	if not object then
		return nil, "HUD requires a connected player"
	end
	if not key then
		return nil, "HUD key must be a non-empty string"
	end

	local layers, primary_or_error = normalise_layers(definition)
	if not layers then
		return nil, primary_or_error
	end
	local primary = primary_or_error
	options = options or {}

	local bucket = get_bucket(player_key, true)
	local entry = bucket[key]
	if not entry then
		entry = {
			player_key = player_key,
			player_name = player_name,
			key = key,
			elements = {},
			legacy_aliases = {},
			expiry_token = 0,
		}
		bucket[key] = entry
	else
		entry.player_name = player_name
	end

	entry.legacy_layers = options.legacy_layers
	entry.primary = primary

	for layer, element in pairs(entry.elements) do
		if not layers[layer] then
			remove_hud(object, element.id)
			entry.elements[layer] = nil
		end
	end

	for layer, hud_definition in pairs(layers) do
		local element = entry.elements[layer]
		if element then
			local updated, reason = update_element(object, element, hud_definition)
			if not updated then
				remove_entry(object, bucket, key)
				return nil, reason
			end
		else
			local id, reason = add_hud(object, hud_definition)
			if not id then
				remove_entry(object, bucket, key)
				return nil, reason
			end
			entry.elements[layer] = {
				id = id,
				definition = copy(hud_definition),
			}
		end
	end

	refresh_legacy_aliases(entry)
	arm_expiry(entry, options.duration, options.on_expire)

	return entry.elements[entry.primary].id
end

-- `add` and `set` are readable aliases for code that treats the HUD as a
-- component rather than an announcement.
api.add = api.show
api.set = api.show

--- Change properties on one layer without changing the other layers.
-- The default layer is the primary layer ("main" for a one-element HUD).
function api.update(player, key, changes, layer)
	local object, player_key = player_info(player)
	key = normalise_key(key)
	if not object or not key then
		return nil, "HUD requires a connected player and a non-empty key"
	end
	if type(changes) ~= "table" then
		return nil, "HUD changes must be a table"
	end

	local bucket = get_bucket(player_key)
	local entry = bucket and bucket[key]
	if not entry then
		return nil, "HUD does not exist"
	end
	layer = layer or entry.primary
	local element = entry.elements[layer]
	if not element then
		return nil, "HUD layer does not exist"
	end

	local definition = copy(element.definition)
	for property, value in pairs(normalise_definition(changes)) do
		definition[property] = value
	end
	local updated, reason = update_element(object, element, definition)
	if not updated then
		return nil, reason
	end
	refresh_legacy_aliases(entry)
	return updated.id
end

api.change = api.update

function api.set_text(player, key, text, layer)
	return api.update(player, key, {text = text or ""}, layer)
end

function api.get_id(player, key, layer)
	local _, player_key = player_info(player)
	key = normalise_key(key)
	if not player_key or not key then
		return nil
	end
	local bucket = get_bucket(player_key)
	local entry = bucket and bucket[key]
	if not entry then
		return nil
	end
	local element = entry.elements[layer or entry.primary]
	return element and element.id or nil
end

function api.get_ids(player, key)
	local _, player_key = player_info(player)
	key = normalise_key(key)
	if not player_key or not key then
		return nil
	end
	local bucket = get_bucket(player_key)
	local entry = bucket and bucket[key]
	if not entry then
		return nil
	end
	local ids = {}
	for layer, element in pairs(entry.elements) do
		ids[layer] = element.id
	end
	return ids
end

function api.exists(player, key)
	return api.get_id(player, key) ~= nil
end

-- Compatibility: the original API returned a boolean and assumed "front".
function api.get(player, hud_type)
	return api.exists(player, hud_type or "front")
end

function api.remove(player, key)
	local object, player_key = player_info(player)
	key = normalise_key(key or "front")
	if not player_key or not key then
		return false
	end
	return remove_entry(object, get_bucket(player_key), key)
end

api.hide = api.remove

function api.remove_all(player)
	local object, player_key = player_info(player)
	if not player_key then
		return 0
	end
	local bucket = get_bucket(player_key)
	if not bucket then
		return 0
	end

	local keys = {}
	for key in pairs(bucket) do
		table.insert(keys, key)
	end
	for _, key in ipairs(keys) do
		remove_entry(object, bucket, key)
	end
	return #keys
end

api.clear = api.remove_all

--- Set or replace an automatic expiry on an existing HUD.
function api.remove_after(player, key, duration, on_expire)
	local _, player_key = player_info(player)
	key = normalise_key(key)
	if not player_key or not key then
		return false
	end
	local bucket = get_bucket(player_key)
	local entry = bucket and bucket[key]
	if not entry then
		return false
	end
	arm_expiry(entry, duration, on_expire)
	return true
end

api.set_timeout = api.remove_after

--- Convenience helper for a text HUD with an optional image background.
-- Options may contain any normal layout fields plus duration and on_expire.
function api.show_panel(player, key, text, options)
	options = options or {}
	local layout = merge(api.layouts[options.layout] or {}, options)
	local position = layout.position or {x = 0.5, y = 0.5}
	local offset = layout.offset
	-- `anchor` is the friendlier public alias.  Read it from options first so
	-- it can override a preset that already defines Luanti's `alignment`.
	local alignment = options.anchor or options.alignment or layout.alignment or layout.anchor

	local text_definition = {
		type = "text",
		text = text or "",
		number = layout.color or 0xFFFFFF,
		size = layout.text_size or {x = 1, y = 1},
		position = copy(position),
		z_index = layout.text_z_index or 100,
		style = layout.style or 0,
	}
	if offset then
		text_definition.offset = copy(offset)
	end
	if alignment then
		text_definition.alignment = copy(alignment)
	end

	local layers = {text = text_definition}
	if layout.background ~= false then
		local background = {
			type = "image",
			text = layout.background_texture or "hud_api_hud_bg.png",
			scale = layout.background_scale or {x = 1, y = 1},
			position = copy(layout.background_position or position),
			z_index = layout.background_z_index or 0,
		}
		if layout.background_offset or offset then
			background.offset = copy(layout.background_offset or offset)
		end
		if layout.background_alignment or alignment then
			background.alignment = copy(layout.background_alignment or alignment)
		end
		layers.background = background
	end

	return api.show(player, key, layers, {
		duration = layout.duration,
		on_expire = layout.on_expire,
		legacy_layers = layout.legacy_layers,
	})
end

-- Existing helpers retain their old placement and parameters.
function api.show_front(player, text, color, style)
	return api.show_panel(player, "front", text, {
		layout = "front",
		color = color or 0xFFFFFF,
		style = style or 0,
		legacy_layers = { [""] = "text", ["_bg"] = "background" },
	})
end

function api.show_actionbar(player, text, color, style)
	return api.show_panel(player, "actionbar", text, {
		layout = "actionbar",
		color = color or 0xFFFFFF,
		style = style or 0,
		legacy_layers = { [""] = "text", ["_bg"] = "background" },
	})
end

-- A compact warning designed for temporary notices such as map cleanup.
function api.show_alert(player, key, text, options)
	options = merge({layout = "top_right"}, options)
	return api.show_panel(player, key, text, options)
end

api.notify = api.show_alert

core.register_on_leaveplayer(function(player)
	local _, player_key = player_info(player)
	local bucket = player_key and get_bucket(player_key)
	if not bucket then
		return
	end

	-- The engine removes a leaving player's HUD itself. Dropping the records
	-- here also invalidates all pending expiry callbacks for that player.
	for key, entry in pairs(bucket) do
		entry.expiry_token = (entry.expiry_token or 0) + 1
		clear_legacy_aliases(entry)
		bucket[key] = nil
	end
	api._entries[player_key] = nil
end)
