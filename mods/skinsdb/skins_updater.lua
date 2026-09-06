-- Skins update script

local S = minetest.get_translator("skinsdb")
local _ID_ = "Lua Skins Updater"

local internal = {}
internal.errors = {}

-- Binary downloads are required
if not core.features.httpfetch_binary_data then
	internal.errors[#internal.errors + 1] =
		"Feature 'httpfetch_binary_data' is missing. Update Minetest."
end

-- Insecure environment for saving textures and meta
local ie, http = skins.ie, skins.http
if not ie or not http then
	internal.errors[#internal.errors + 1] = "Insecure environment is required. " ..
		"Please add skinsdb to `secure.trusted_mods` in minetest.conf"
end

minetest.register_chatcommand("skinsdb_download_skins", {
	params = "<skindb start page> <amount of pages>",
	description = S("Downloads the specified range of skins and shuts down the server"),
	privs = {server=true},
	func = function(name, param)
		if #internal.errors > 0 then
			return false, "Cannot run " .. _ID_ .. ":\n\t" ..
				table.concat(internal.errors, "\n\t")
		end

		local parts = string.split(param, " ")
		local start = tonumber(parts[1])
		local len = tonumber(parts[2])
		if not start or not len or start < 1 or len < 1 or len > 1000
				or start ~= math.floor(start) or len ~= math.floor(len) then
			return false, "Invalid page number or amount of pages"
		end

		internal.get_pages_count(internal.fetch_function, start, len)
		return true, "Started downloading..."
	end,
})


if #internal.errors > 0 then
	return -- Nonsense to load something that's not working
end

local root_url = "https://skinsdb.terraqueststudios.net"
local page_url = root_url .. "/api/v1/content?client=mod&page=%i" -- [1] = Page#

local mod_path = skins.modpath
local meta_path = mod_path .. "/meta/"
local skins_path = mod_path .. "/textures/"

-- Fancy debug wrapper to download an URL
local function fetch_url(url, callback)
	http.fetch({
		url = url,
		user_agent = _ID_
	}, function(result)
		if result.succeeded and result.code == 200
				and type(result.data) == "string" and #result.data <= 16777216 then
			return callback(result.data)
		end
		core.log("warning", ("%s: Failed to download URL=%s STATUS=%s"):format(
			_ID_, url, tostring(result.code)))
	end)
end

-- Insecure workaround since meta/ and textures/ cannot be written to
local function unsafe_file_write(path, contents)
	local file, error_message = ie.io.open(path, "wb")
	if not file then
		core.log("error", ("%s: Cannot write %s: %s"):format(
			_ID_, path, tostring(error_message)))
		return false
	end
	local written, write_error = file:write(contents)
	file:close()
	if not written then
		core.log("error", ("%s: Cannot write %s: %s"):format(
			_ID_, path, tostring(write_error)))
		return false
	end
	return true
end

-- Takes a valid skin table from the Skins Database and saves it
local function safe_single_skin(skin)
	if type(skin) ~= "table" or skin.type ~= "image/png" then
		return false
	end

	local raw_id = tostring(skin.id or "")
	if not raw_id:match("^%d+$") then
		core.log("warning", _ID_ .. ": Rejected invalid skin ID")
		return false
	end
	local id = tonumber(raw_id)
	if not id or id <= 1 or id > 1000000000 then
		return false
	end

	local encoded_image = type(skin.img) == "string" and skin.img or ""
	if #encoded_image > 1398208 then
		return false
	end
	local image = core.decode_base64(encoded_image)
	if type(image) ~= "string" or #image < 24 or #image > 1048576
			or image:sub(1, 8) ~= "\137PNG\r\n\26\n" then
		core.log("warning", ("%s: Rejected invalid PNG for skin %d"):format(_ID_, id))
		return false
	end

	local function metadata(value)
		local cleaned = tostring(value or ""):gsub("[\r\n]", " ")
		return cleaned:sub(1, 256)
	end
	local meta = {
		metadata(skin.name),
		metadata(skin.author),
		metadata(skin.license)
	}

	local name = "character" .. skins.fsep .. id

	local meta_written = unsafe_file_write(
		meta_path .. name .. ".txt",
		table.concat(meta, "\n")
	)

	local image_written = unsafe_file_write(
		skins_path .. name .. ".png",
		image
	)
	if not meta_written or not image_written then
		return false
	end
	core.log("action", ("%s: Completed skin %s"):format(_ID_, name))
	return true
end

-- Get total pages since it'll just return the last page all over again
internal.get_pages_count = function(callback, ...)
	local vars = {...}
	fetch_url(page_url:format(1) .. "&per_page=1", function(data)
		local list = core.parse_json(data)
		local pages = type(list) == "table" and tonumber(list.pages)
		if not pages or pages < 0 then
			core.log("warning", _ID_ .. ": Invalid page-count response")
			return
		end
		callback(math.ceil(pages / 20), unpack(vars))
	end)
end

-- Function to fetch a range of pages
internal.fetch_function = function(pages_total, start_page, len)
	start_page = math.max(start_page, 1)
	local end_page = math.min(start_page + len - 1, pages_total)

	for page_n = start_page, end_page do
		local page_cpy = page_n
		fetch_url(page_url:format(page_n), function(data)
			core.log("action", ("%s: Page %i"):format(_ID_, page_cpy))

			local list = core.parse_json(data)
			if type(list) ~= "table" or type(list.skins) ~= "table" then
				core.log("warning", _ID_ .. ": Invalid skins response")
				return
			end
			for _, skin in pairs(list.skins) do
				safe_single_skin(skin)
			end

			if page_cpy == end_page then
				local log = _ID_ .. " finished downloading all skins. " ..
					"Shutting down server to reload media cache"
				core.log("action", log)
				core.request_shutdown(log, true, 3 --[[give some time for pending requests]])
			end
		end)
	end
end
