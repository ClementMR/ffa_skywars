-- Shared, short-lived kill feed shown to every connected player.
local MAX_ENTRIES = 3
local ENTRY_LIFETIME = 60
local HUD_KEY = "skywars:kill_history"

local entries = {}

local function item_label(item_name)
	local definition = core.registered_items[item_name or ""]
	local description = definition and definition.description or ""
	description = description:match("^[^\n]+") or ""
	if description == "" then
		description = item_name ~= "" and item_name or "Unknown"
	end
	return description
end

local function prune_entries()
	local now = core.get_gametime()
	for index = #entries, 1, -1 do
		if entries[index].expires_at <= now then
			table.remove(entries, index)
		end
	end
end

local function feed_text()
	local lines = {}
	for _, entry in ipairs(entries) do
		local killer = core.colorize("#6EE7B7", entry.killer)
		local item = core.colorize("#FCD34D", "[" .. item_label(entry.item) .. "]")
		local victim = core.colorize("#FCA5A5", entry.victim)
		table.insert(lines, killer .. " " .. item .. " " .. victim)
	end
	return table.concat(lines, "\n")
end

local function refresh_player(player)
	if #entries == 0 then
		hud_api.remove(player, HUD_KEY)
		return
	end

	hud_api.show(player, HUD_KEY, {
		type = "text",
		text = feed_text(),
		number = 0xFFFFFF,
		position = {x = 1, y = 0},
		alignment = {x = -1, y = 1},
		offset = {x = -18, y = 22},
		style = 1,
		z_index = 30,
	}, {background = true})
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

	local now = core.get_gametime()
	local next_expiry = entries[#entries].expires_at
	for _, entry in ipairs(entries) do
		next_expiry = math.min(next_expiry, entry.expires_at)
	end
	core.after(math.max(0.1, next_expiry - now), refresh_all)
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
