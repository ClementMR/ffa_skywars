local has_sfinv     = core.get_modpath("sfinv") ~= nil
local has_3d_armor  = core.get_modpath("3d_armor") ~= nil
local S = core.get_translator(core.get_current_modname())

local TOTEM_LIST = "totem"
local TOTEM_ENTITY = "ffa_inventory:equipped_totem"
local totem_entities = {}
local refresh_totem_visual

local function is_totem(stack)
	return stack and not stack:is_empty() and stack:get_name() == "skywars:totem_of_undying"
end

local function remove_totem_visual(name)
	local object = totem_entities[name]
	totem_entities[name] = nil

	if object and object:get_pos() then
		local entity = object:get_luaentity()
		if entity then
			entity.skip_refresh = true
		end
		object:remove()
	end
end

core.register_entity(TOTEM_ENTITY, {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "wielditem",
		wield_item = "",
		is_visible = false,
		backface_culling = false,
		use_texture_alpha = true,
		static_save = false,
		shaded = true,
	},

	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,

	on_deactivate = function(self)
		local name = self.player_name
		if not name then
			return
		end

		if totem_entities[name] == self.object then
			totem_entities[name] = nil
		end

		if self.skip_refresh then
			return
		end

		-- Map cleanup removes dynamic entities. Recreate the off-hand item when
		-- that happens, as long as its player is still connected and equipped.
		core.after(0, function()
			local player = core.get_player_by_name(name)
			if player then
				refresh_totem_visual(player)
			end
		end)
	end,
})

refresh_totem_visual = function(player)
	if not player then
		return
	end

	local name = player:get_player_name()
	local stack = player:get_inventory():get_stack(TOTEM_LIST, 1)
	if not is_totem(stack) then
		remove_totem_visual(name)
		return
	end

	local object = totem_entities[name]
	if object and object:get_pos() then
		return
	end

	local pos = player:get_pos()
	if not pos then
		return
	end

	object = core.add_entity(pos, TOTEM_ENTITY)
	if not object then
		return
	end

	local entity = object:get_luaentity()
	if entity then
		entity.player_name = name
	end

	object:set_properties({
		is_visible = true,
		wield_item = stack:to_string(),
		visual_size = {x = 0.16, y = 0.16},
		glow = stack:get_definition().light_source or 0,
	})
	object:set_attach(player, "Arm_Left", {x = 0, y = 5, z = 2},
		{x = 180, y = -120, z = 0}, true)
	totem_entities[name] = object
end

local inventory_api = rawget(_G, "ffa_inventory") or {}
rawset(_G, "ffa_inventory", inventory_api)
inventory_api.refresh_totem_visual = refresh_totem_visual

local function generate_sfinv_formspec(player)
	local player_name = player:get_player_name()

	local skin_texture  = "character.png"
	local armor_texture = "blank.png"
	local wield_texture = "blank.png"

	if _G.armor and _G.armor.textures and _G.armor.textures[player_name] then
		local textures = _G.armor.textures[player_name]
		skin_texture  = armor:get_player_skin(player_name) or skin_texture
		armor_texture = textures.armor    or armor_texture
		wield_texture = textures.wielditem or wield_texture
	end

	local formspec_parts = {
		"size[15,9]",

		"list[current_player;craft;3.77,0.75;2,2;]",
		"list[current_player;craftpreview;7.02,1.25;1,1;]",

		"image[5.92,1.25;1,1;sfinv_crafting_arrow.png]",

		"box[1.15,0;2.25,3.9;#030303]",
		"image[1.2,4.01;1,1;totem_of_undying.png^[opacity:40]",
		"list[current_player;" .. TOTEM_LIST .. ";1.2,4.01;1,1;]",

		"listring[current_player;craft]",
		"listring[current_player;main]",

		"model[1.05,0.1;3,4.5;model;3d_armor_character.b3d;" .. skin_texture .. "," .. armor_texture .. "," .. wield_texture .. ";-10,160;false;false;3,80;30]",
	}

	if has_3d_armor then
        table.insert(formspec_parts, armor:get_armor_formspec(player_name))
	end

	return table.concat(formspec_parts, "")
end

core.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	inv:set_size("craft", 4)
	inv:set_size(TOTEM_LIST, 1)
	core.after(0, refresh_totem_visual, player)
end)

core.register_on_respawnplayer(function(player)
	core.after(0, refresh_totem_visual, player)
end)

core.register_on_leaveplayer(function(player)
	remove_totem_visual(player:get_player_name())
end)

core.register_allow_player_inventory_action(function(player, action, inv, info)
	if action == "move" and info.to_list == TOTEM_LIST then
		if not is_totem(inv:get_stack(info.from_list, info.from_index)) then
			return 0
		end
	elseif action == "put" and info.listname == TOTEM_LIST then
		if not is_totem(info.stack) then
			return 0
		end
	end
end)

core.register_on_player_inventory_action(function(player, action, inv, info)
	if info.listname == TOTEM_LIST
		or info.from_list == TOTEM_LIST
		or info.to_list == TOTEM_LIST then
		core.after(0, refresh_totem_visual, player)
	end
end)

if has_sfinv then
	sfinv.override_page("sfinv:crafting", {
		get = function(self, player, context)
			return sfinv.make_formspec(player, context, generate_sfinv_formspec(player), true)
		end,
	})
end
