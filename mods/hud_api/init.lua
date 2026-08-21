-- Small named HUD registry.
-- Each caller owns a stable key such as "skywars:cleanup". Showing the same
-- key updates its existing Luanti HUD instead of stacking another one.

hud_api = {}

local api = hud_api
local entries = {}

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

local function same(first, second)
	if type(first) ~= type(second) then
		return false
	end
	if type(first) ~= "table" then
		return first == second
	end
	for key, value in pairs(first) do
		if not same(value, second[key]) then
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

local function get_player_name(player)
	if not player then
		return nil
	end
	local ok, name = pcall(player.get_player_name, player)
	if not ok or type(name) ~= "string" or name == "" then
		return nil
	end
	return name
end

local function get_bucket(name, create)
	local bucket = entries[name]
	if not bucket and create then
		bucket = {}
		entries[name] = bucket
	end
	return bucket
end

local function remove_entry(player, name, key)
	local bucket = get_bucket(name)
	local entry = bucket and bucket[key]
	if not entry then
		return false
	end

	entry.token = entry.token + 1
	if player and entry.background_id ~= nil then
		pcall(player.hud_remove, player, entry.background_id)
	end
	if player and entry.id ~= nil then
		pcall(player.hud_remove, player, entry.id)
	end
	bucket[key] = nil
	if not next(bucket) then
		entries[name] = nil
	end
	return true
end

local function add_hud(player, definition)
	local ok, id = pcall(player.hud_add, player, definition)
	if not ok or id == nil then
		return nil, ok and "hud_add returned no id" or tostring(id)
	end
	return id
end

local function update_entry(player, entry, definition)
	if entry.definition.type ~= definition.type then
		return false
	end
	for property in pairs(entry.definition) do
		if property ~= "type" and definition[property] == nil then
			return false
		end
	end

	for property, value in pairs(definition) do
		if property ~= "type" and not same(entry.definition[property], value) then
			local ok, changed = pcall(player.hud_change, player, entry.id, property, copy(value))
			if not ok or changed == false then
				return false
			end
		end
	end
	entry.definition = copy(definition)
	return true
end

local function set_background(player, entry, definition, enabled)
	if not enabled then
		if entry.background_id ~= nil then
			pcall(player.hud_remove, player, entry.background_id)
			entry.background_id = nil
			entry.background_definition = nil
		end
		entry.has_background = false
		return true
	end

	local wanted = {
		type = "image",
		text = "hud_api_hud_bg.png",
		scale = {x = 1, y = 1.2},
		position = copy(definition.position or {x = 0.5, y = 0.5}),
		z_index = math.max(0, (definition.z_index or 1) - 1),
	}
	if definition.alignment then
		wanted.alignment = copy(definition.alignment)
	end
	if definition.offset then
		wanted.offset = copy(definition.offset)
	end

	if entry.background_id ~= nil then
		local background = {
			id = entry.background_id,
			definition = entry.background_definition,
		}
		if update_entry(player, background, wanted) then
			entry.background_definition = background.definition
			entry.has_background = true
			return true
		end
		pcall(player.hud_remove, player, entry.background_id)
	end

	local id, error = add_hud(player, wanted)
	if not id then
		return nil, error
	end
	entry.background_id = id
	entry.background_definition = wanted
	entry.has_background = true
	return true
end

local function set_expiry(entry, duration)
	entry.token = entry.token + 1
	if type(duration) ~= "number" or duration <= 0 then
		return
	end

	local token = entry.token
	core.after(duration, function()
		local bucket = get_bucket(entry.player_name)
		local current = bucket and bucket[entry.key]
		if current ~= entry or current.token ~= token then
			return
		end
		remove_entry(core.get_player_by_name(entry.player_name), entry.player_name, entry.key)
	end)
end

--- Show or replace one named Luanti HUD.
-- `definition` uses the native Luanti fields (`type`, `number`, `alignment`,
-- `offset`, ...). Options supports `{duration = seconds, background = true}`.
function api.show(player, key, definition, options)
	local name = get_player_name(player)
	if not name then
		return nil, "HUD requires a connected player"
	end
	if type(key) ~= "string" or key == "" then
		return nil, "HUD key must be a non-empty string"
	end
	if type(definition) ~= "table" or type(definition.type) ~= "string" then
		return nil, "HUD definition needs a type"
	end
	options = options or {}
	definition = copy(definition)
	if options.background == true and definition.z_index == nil then
		definition.z_index = 1
	end

	local bucket = get_bucket(name, true)
	local entry = bucket[key]
	if entry and not update_entry(player, entry, definition) then
		remove_entry(player, name, key)
		entry = nil
		bucket = get_bucket(name, true)
	end

	if not entry then
		local id, error = add_hud(player, definition)
		if not id then
			return nil, error
		end
		entry = {
			id = id,
			definition = copy(definition),
			key = key,
			player_name = name,
			token = 0,
		}
		bucket[key] = entry
	end

	local background, error = set_background(player, entry, definition, options.background == true)
	if not background then
		return nil, error
	end
	set_expiry(entry, options.duration)
	return entry.id
end

--- Update selected native HUD properties without changing its expiry.
function api.update(player, key, changes)
	local name = get_player_name(player)
	if not name or type(key) ~= "string" or type(changes) ~= "table" then
		return nil, "HUD update requires a player, key and changes"
	end
	local entry = get_bucket(name) and get_bucket(name)[key]
	if not entry then
		return nil, "HUD does not exist"
	end

	local definition = copy(entry.definition)
	for property, value in pairs(changes) do
		definition[property] = copy(value)
	end
	if not update_entry(player, entry, definition) then
		local id, error = add_hud(player, definition)
		if not id then
			return nil, error
		end
		pcall(player.hud_remove, player, entry.id)
		entry.id = id
		entry.definition = definition
	end
	local background, error = set_background(player, entry, definition, entry.has_background)
	if not background then
		return nil, error
	end
	return entry.id
end

function api.remove(player, key)
	local name = get_player_name(player)
	if not name or type(key) ~= "string" then
		return false
	end
	return remove_entry(player, name, key)
end

core.register_on_leaveplayer(function(player)
	entries[player:get_player_name()] = nil
end)
