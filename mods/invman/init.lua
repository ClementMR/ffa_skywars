local W = core.settings:get("invman.width") or 8
if core.get_modpath("mcl_core") and W == 8 then
	W = 9
end
local tab = {}
local target = {}
local grab_mode = {}
local F = core.formspec_escape

local function genlist(lists)
	local ilist = {}
	for lname,_ in pairs(lists) do
		if lname ~= "main" and lname ~= "craftpreview" and lname ~= "craftresult" then
			table.insert(ilist,lname)
		end
	end
	table.sort(ilist)
	table.insert(ilist, 1, "main")
	return ilist
end

local function im_fs(name)
	if not target[name] then return end
	local y = 0.7
	local x = 0
	local inv = core.get_inventory({type="player", name=target[name]})
	if not inv then return end
	local lists = inv:get_lists()
	local ilist = genlist(lists)
	local size = #inv:get_list(ilist[(tab[name] or 1)])
	local fsh = math.ceil(size/W)+0.7
	if fsh < 1 then
		fsh = 1
	end
	local formspec = "size["..W..","..fsh..
	"]tabheader[0,0;tabs;"..table.concat(ilist,",")..";"..(tab[name] or "1")..";false;false]" ..
	"label[0,0;"..target[name].."]"..
	"checkbox["..(W-2)..",-0.2;grab_mode;Grab item;"..(grab_mode[name] and grab_mode[name] or "false").."]"
	for number,stack in pairs(inv:get_list(ilist[(tab[name] or 1)])) do
		if not stack then
			stack = ItemStack("")
		end
		local name = stack:get_name()
		local count = stack:get_count()
		local descr = stack:get_short_description()
		if descr == name then
			descr = stack:get_name()
		else
			descr = descr.." ["..name.."]"
		end
		formspec = formspec .. ("item_image_button[%f,%f;1,1;%s;item:%i;\n\n\b\b\b%s]tooltip[item:%i;%s]"):format(
				x, y,
				name,
				number,
				count > 0 and tostring(count) or "",
				number,
				F(descr)
			)
		x = x + 1
		if x >= W then
			y = y + 1
			x = 0
		end
	end
	core.show_formspec(name,"invman",formspec)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "invman" then return end
	local name = player and player:get_player_name()
	if not name then return end
	if fields.tabs then
		tab[name] = tonumber(fields.tabs) or 1
		im_fs(name)
	end
	if fields.grab_mode then
		grab_mode[name] = fields.grab_mode
	end
	if not (fields.quit or fields.tabs or fields.grab_mode) then
		local number = 1
		for key,val in pairs(fields) do
			number = key:gsub("item:","")
		end
		local inv = core.get_inventory({type="player", name=target[name]})
		if not inv then return end
		local lists = inv:get_lists()
		local ilist = genlist(lists)
		local stack = inv:get_list(ilist[(tab[name] or 1)])[tonumber(number)]
		if grab_mode[name] == "true" then
			inv:remove_item(ilist[(tab[name] or 1)], stack)
		end
		local oinv = player:get_inventory()
		oinv:add_item("main",stack)
		im_fs(name)
	end
end)
core.register_privilege("invman",{description="Allows to use /invman",give_to_singleplayer=false})
core.register_chatcommand("invman",{
  description = "Open InvMan formspec",
  privs={invman=true},
  params = "<playername>",
  func = function(name,param)
	local user = core.get_player_by_name(name)
	if not user then
		return false, "You can't use /invman from IRC/Discord!"
	end
	local player = core.get_player_by_name(param)
	if not player then
		return false, "Target player is not online"
	end
	target[name] = param
	tab[name] = 1
	im_fs(name)
end})
