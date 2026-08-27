-- Shared, short-lived kill feed shown to every connected player.
local MAX_ENTRIES = 3
local ENTRY_LIFETIME = 60
local HUD_KEY = "skywars:kill_history:"

local entries = {}
local refresh_token = 0

local function item_texture(item_name)
	local definition = core.registered_items[item_name or ""]
	local texture = definition and definition.inventory_image or ""
	if texture == "" and definition then
		texture = definition.wield_image or ""
	end
	if texture == "" then
		texture = "unknown_item.png"
	end
	return texture .. "^[resize:30x30"
end

local function prune_entries()
	local now = core.get_gametime()
	for index = #entries, 1, -1 do
		if entries[index].expires_at <= now then
			table.remove(entries, index)
		end
	end
end

local function entry_key(index, part)
	return HUD_KEY .. index .. ":" .. part
end

local function clear_feed(player)
	hud_api.remove(player, "skywars:kill_history")
	for index = 1, MAX_ENTRIES do
		hud_api.remove(player, entry_key(index, "killer"))
		hud_api.remove(player, entry_key(index, "item"))
		hud_api.remove(player, entry_key(index, "victim"))
	end
end

local function refresh_player(player)
	clear_feed(player)
	if #entries == 0 then
		return
	end

	for index, entry in ipairs(entries) do
		local offset_y = -176 - (index - 1) * 52
		local killer_width = math.max(52, #entry.killer * 8)
		local item_x = 24 + killer_width + 36

		hud_api.show(player, entry_key(index, "killer"), {
			type = "text",
			text = core.colorize("#6EE7B7", entry.killer .. "  →"),
			number = 0xFFFFFF,
			position = {x = 0, y = 1},
			alignment = {x = 1, y = -1},
			offset = {x = 24, y = offset_y},
			style = 1,
			z_index = 30,
		})

		hud_api.show(player, entry_key(index, "item"), {
			type = "image",
			text = item_texture(entry.item),
			position = {x = 0, y = 1},
			alignment = {x = 1, y = -1},
			offset = {x = item_x, y = offset_y - 8},
			scale = {x = 1, y = 1},
			z_index = 30,
		})

		hud_api.show(player, entry_key(index, "victim"), {
			type = "text",
			text = core.colorize("#FCA5A5", entry.victim),
			number = 0xFFFFFF,
			position = {x = 0, y = 1},
			alignment = {x = 1, y = -1},
			offset = {x = item_x + 42, y = offset_y},
			style = 1,
			z_index = 30,
		})
	end
end

local function refresh_all()
	prune_entries()
	for _, player in ipairs(core.get_connected_players()) do
		refresh_player(player)
	end
end

local function schedule_refresh()
	if #entries == 0 then
		return
	end

	refresh_token = refresh_token + 1
	local token = refresh_token
	local now = core.get_gametime()
	local next_expiry = entries[#entries].expires_at
	for _, entry in ipairs(entries) do
		next_expiry = math.min(next_expiry, entry.expires_at)
	end
	core.after(math.max(0.1, next_expiry - now), function()
		if token ~= refresh_token then
			return
		end
		refresh_all()
		schedule_refresh()
	end)
end

function skywars.record_kill(killer_name, item_name, victim_name)
	if type(killer_name) ~= "string" or killer_name == ""
		or type(victim_name) ~= "string" or victim_name == "" then
		return false
	end

	prune_entries()
	table.insert(entries, 1, {
		killer = killer_name,
		item = type(item_name) == "string" and item_name or "",
		victim = victim_name,
		expires_at = core.get_gametime() + ENTRY_LIFETIME,
	})
	while #entries > MAX_ENTRIES do
		table.remove(entries)
	end

	refresh_all()
	schedule_refresh()
	return true
end

core.register_on_joinplayer(function(player)
	core.after(0, function()
		if core.get_player_by_name(player:get_player_name()) then
			prune_entries()
			refresh_player(player)
		end
	end)
end)
