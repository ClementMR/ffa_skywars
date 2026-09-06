local S = core.get_translator(core.get_current_modname())

local food_healing = {
	["default:apple"] = 2,
	["default:blueberries"] = 2,
	["farming:bread"] = 5,
	["flowers:mushroom_brown"] = 1,
	["flowers:mushroom_red"] = -5,
	["maptools:superapple"] = 20,
	["xdecor:bowl_soup"] = 30,
	["xdecor:honey"] = 2,
}

local special = {
	["ctf_ranged:ammo"] = {usage = S("Reloads ranged weapons")},
	["ffa_boss:golden_ticket"] = {usage = S("Starts The Forgotten boss event")},
	["screwdriver:screwdriver"] = {usage = S("Left-click: rotate face; right-click: rotate axis")},
	["skywars:golden_apple"] = {full_heal = true, absorption = 4},
	["skywars:totem_of_undying"] = {usage = S("Prevents death and restores 5 HP")},
}

local function format_number(value)
	value = tonumber(value) or 0
	if value == math.floor(value) then
		return tostring(math.floor(value))
	end
	return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
end

local function add_stat(lines, label, value, color)
	lines[#lines + 1] = core.colorize("#A1A1AA", label .. ": ")
		.. core.colorize(color or "#E4E4E7", tostring(value))
end

local function armor_slot(groups)
	if groups.armor_head then
		return S("Head")
	elseif groups.armor_torso then
		return S("Torso")
	elseif groups.armor_legs then
		return S("Legs")
	elseif groups.armor_feet then
		return S("Feet")
	elseif groups.armor_shield then
		return S("Shield")
	end
end

local function tool_uses(tool_capabilities)
	local uses = 0
	for _, capability in pairs(tool_capabilities.groupcaps or {}) do
		uses = math.max(uses, tonumber(capability.uses) or 0)
	end
	return uses
end

local function item_info(name, def)
	local info = {}
	for key, value in pairs(special[name] or {}) do
		info[key] = value
	end
	if type(def._item_info) == "table" then
		for key, value in pairs(def._item_info) do
			info[key] = value
		end
	end
	return info
end

local function build_details(name, def)
	local lines = {}
	local groups = def.groups or {}
	local info = item_info(name, def)
	local tool_capabilities = def.tool_capabilities or {}
	local damage_groups = tool_capabilities.damage_groups or {}
	local damage = info.ranged_damage or damage_groups.fleshy

	if damage and damage > 0 then
		add_stat(lines, S("Damage"), format_number(damage), "#EF4444")
	end
	if info.fire_rate then
		add_stat(lines, S("Fire rate"), S("@1 shots/s", format_number(info.fire_rate)), "#F97316")
	end
	if info.magazine then
		add_stat(lines, S("Magazine"), format_number(info.magazine), "#FACC15")
	end
	if info.loaded ~= nil then
		add_stat(lines, S("Loaded"), info.loaded and S("Yes") or S("No"),
			info.loaded and "#22C55E" or "#EF4444")
	end
	if info.range or def.range then
		add_stat(lines, S("Range"), S("@1 nodes", format_number(info.range or def.range)), "#38BDF8")
	end
	if tool_capabilities.full_punch_interval then
		add_stat(lines, S("Attack cooldown"),
			S("@1 s", format_number(tool_capabilities.full_punch_interval)), "#F59E0B")
	end
	if def._cooldown and not info.fire_rate then
		add_stat(lines, S("Cooldown"), S("@1 s", format_number(def._cooldown)), "#F59E0B")
	end

	local healing = food_healing[name]
	if healing then
		add_stat(lines, S("Food"), S("@1 HP", format_number(healing)),
			healing > 0 and "#22C55E" or "#EF4444")
	elseif info.full_heal then
		add_stat(lines, S("Healing"), S("Full health"), "#22C55E")
	end
	if info.absorption then
		add_stat(lines, S("Absorption"), S("@1 HP", format_number(info.absorption)), "#FACC15")
	end

	local slot = armor_slot(groups)
	if slot then
		add_stat(lines, S("Armor slot"), slot, "#A78BFA")
		local protection = def.armor_groups and def.armor_groups.fleshy
		if protection then
			add_stat(lines, S("Armor protection"), format_number(protection) .. "%", "#60A5FA")
		end
		if groups.armor_heal and groups.armor_heal > 0 then
			add_stat(lines, S("Armor healing chance"), format_number(groups.armor_heal) .. "%", "#22C55E")
		end
		if groups.armor_use and groups.armor_use > 0 then
			add_stat(lines, S("Durability"),
				S("~@1 hits", math.floor(65535 / groups.armor_use)), "#C4B5FD")
		end
	else
		local uses = tool_uses(tool_capabilities)
		if uses > 0 then
			add_stat(lines, S("Durability"), S("~@1 uses", uses), "#C4B5FD")
		end
	end

	if info.ability then
		add_stat(lines, S("Ability"), info.ability, "#A78BFA")
	end
	if info.ability_cooldown then
		add_stat(lines, S("Ability cooldown"),
			S("@1 s", format_number(info.ability_cooldown)), "#8B5CF6")
	end
	if info.usage then
		add_stat(lines, S("Usage"), info.usage, "#67E8F9")
	end

	add_stat(lines, S("Max stack"), def.stack_max or 99, "#D4D4D8")
	return lines
end

core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_items) do
		local consumable_node = food_healing[name] ~= nil
		local inventory_item = def.type == "tool" or def.type == "craft" or consumable_node
		if inventory_item and def.description and def.description ~= "" then
			local details = build_details(name, def)
			if #details > 0 then
				core.override_item(name, {
					description = def.description .. "\n" .. table.concat(details, "\n"),
				})
			end
		end
	end
end)
