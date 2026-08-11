local player_HUD = {}

local function display_FOV_Form(pname, fov_value)
	local player = core.get_player_by_name(pname)
	if not player then return end
	local formspec =
		"size[8,4]no_prepend[]bgcolor[black;neither]scrollbaroptions[min=45;max=160;smallstep=1;largestep=1;thumbsize=2]" ..
		"scrollbar[0,2;7.8,0.5;horizontal;sb_font_size;" .. fov_value .. "]"
	player_HUD[pname] = player:hud_add({
		hud_elem_type = "text",
		text = "FOV: " .. fov_value,
		position = {x = 0.5, y = 0.4},
		number = 0xFFFFFF,
	})
	core.show_formspec(pname, "fov:fov_fs", formspec)
end

local function update_FOV_Value(pname, value)
	local player = core.get_player_by_name(pname)
	if not player then return end
	local meta = player:get_meta()
	meta:set_int("fov", value)
	player:set_fov(value)
	local hudId = player_HUD[pname]
	if hudId then
		player:hud_change(hudId, "text", "FOV: " .. value)
	end
end

core.register_chatcommand("fov", {
	description = "Adjust your FOV",
	privs = {interact = true},
	func = function(pname)
		local player = core.get_player_by_name(pname)
		if not player then return end
		local meta = player:get_meta()
		display_FOV_Form(pname, meta:get_int("fov"))
	end
})

core.register_on_player_receive_fields(function(player, formName, fields)
	if formName ~= "fov:fov_fs" then return end
	local pname = player:get_player_name()
	if fields.quit then
		if player_HUD[pname] then
			player:hud_remove(player_HUD[pname])
			player_HUD[pname] = nil
		end
		return
	end
	local event = core.explode_scrollbar_event(fields.sb_font_size)
	if event and event.value then
		update_FOV_Value(pname, event.value)
	end
end)

core.register_on_joinplayer(function(player)
	local meta = player:get_meta()
	local current_fov = meta:get_int("fov")
	if current_fov == 0 then
		current_fov = player:get_fov() or 95
		meta:set_int("fov", current_fov)
	end
	player:set_fov(current_fov)
end)
