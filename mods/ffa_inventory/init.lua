local has_sfinv     = core.get_modpath("sfinv") ~= nil
local has_3d_armor  = core.get_modpath("3d_armor") ~= nil

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
end)

if has_sfinv then
	sfinv.override_page("sfinv:crafting", {
		get = function(self, player, context)
			return sfinv.make_formspec(player, context, generate_sfinv_formspec(player), true)
		end,
	})
end
