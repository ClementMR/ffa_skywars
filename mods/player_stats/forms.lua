-- Forms and leaderboards.
return function(stats)

	local open_forms = {}
	local LEADERBOARD_VIEW_HEIGHT = 5.15
	local LEADERBOARD_ROW_HEIGHT = 0.8
	local LEADERBOARD_SCROLL_FACTOR = 0.2

	local function form_escape(value)
		return core.formspec_escape(tostring(value))
	end

	local function append_profile_tab(formspec, target_name)
		local kills = stats.get_value(target_name, "kills")
		local deaths = stats.get_value(target_name, "deaths")
		local playtime = stats.get_value(target_name, "playtime")
		local ratio = stats.format_value("kd", stats.get_kd(target_name))

		table.insert(formspec, "label[0.65,1.46;Profile of " .. form_escape(target_name) .. "]")
		table.insert(formspec, "box[0.6,2.05;3.25,2.05;#243147]")
		table.insert(formspec, "box[4.17,2.05;3.25,2.05;#243147]")
		table.insert(formspec, "box[7.75,2.05;3.25,2.05;#243147]")
		table.insert(formspec, "label[0.9,2.38;PLAYTIME]")
		table.insert(formspec, "label[0.9,3.05;" .. form_escape(stats.format_value("playtime", playtime)) .. "]")
		table.insert(formspec, "label[4.47,2.38;KILLS]")
		table.insert(formspec, "label[4.47,3.05;" .. form_escape(kills) .. "]")
		table.insert(formspec, "label[8.05,2.38;DEATHS]")
		table.insert(formspec, "label[8.05,3.05;" .. form_escape(deaths) .. "]")
		table.insert(formspec, "box[0.6,4.55;10.4,1.55;#172033]")
		table.insert(formspec, "label[0.9,4.88;K/D Ratio: " .. form_escape(ratio) .. "]")
		table.insert(formspec, "label[0.9,5.42;Rank — Playtime: #" .. (stats.get_rank(target_name, "playtime") or "-")
			.. "   Kills : #" .. (stats.get_rank(target_name, "kills") or "-")
			.. "   Deaths: #" .. (stats.get_rank(target_name, "deaths") or "-")
			.. "   K/D: #" .. (stats.get_rank(target_name, "kd") or "-") .. "]")
	end

	local function append_leaderboard_tab(formspec, field, scroll_value)
		local board = stats.get_leaderboard(field)
		table.insert(formspec, "label[0.65,1.46;Leaderboard — " .. stats.leaderboard_fields[field] .. "]")
		table.insert(formspec, "label[0.95,1.98;RANK]")
		table.insert(formspec, "label[2.15,1.98;PLAYER]")
		table.insert(formspec, "label[8.7,1.98;VALUE]")

		if #board == 0 then
			table.insert(formspec, "box[0.6,2.4;10.4,1.2;#172033]")
			table.insert(formspec, "label[0.95,2.84;No statistics have been recorded yet.]")
			return
		end

		local entry_count = math.min(stats.leaderboard_size, #board)
		local content_height = entry_count * LEADERBOARD_ROW_HEIGHT
		local max_scroll = math.max(0, math.ceil((content_height - LEADERBOARD_VIEW_HEIGHT) / LEADERBOARD_SCROLL_FACTOR))
		scroll_value = math.max(0, math.min(max_scroll, math.floor(tonumber(scroll_value) or 0)))

		if max_scroll > 0 then
			local thumb_size = math.max(1, math.floor(max_scroll * LEADERBOARD_VIEW_HEIGHT / content_height))
			table.insert(formspec, "scrollbaroptions[min=0;max=" .. max_scroll
				.. ";smallstep=4;largestep=20;thumbsize=" .. thumb_size .. "]")
			table.insert(formspec, "scrollbar[10.75,2.38;0.28," .. LEADERBOARD_VIEW_HEIGHT
				.. ";vertical;leaderboard_scroll;" .. scroll_value .. "]")
			table.insert(formspec, "scroll_container[0.6,2.38;10.05," .. LEADERBOARD_VIEW_HEIGHT
				.. ";leaderboard_scroll;vertical;" .. LEADERBOARD_SCROLL_FACTOR .. "]")
		end

		local in_scroll_container = max_scroll > 0
		local box_x = in_scroll_container and 0 or 0.6
		local box_width = in_scroll_container and 10.05 or 10.4
		local rank_x = in_scroll_container and 0.35 or 0.95
		local player_x = in_scroll_container and 1.55 or 2.15
		local value_x = in_scroll_container and 8.1 or 8.7
		for rank = 1, entry_count do
			local entry = board[rank]
			local y = (rank - 1) * LEADERBOARD_ROW_HEIGHT
			if max_scroll == 0 then
				y = y + 2.38
			end
			table.insert(formspec, "box[" .. box_x .. "," .. y .. ";" .. box_width .. ",0.46;#1b2639]")
			table.insert(formspec, "label[" .. rank_x .. "," .. (y + 0.2) .. ";" .. form_escape("#" .. rank) .. "]")
			table.insert(formspec, "label[" .. player_x .. "," .. (y + 0.2) .. ";" .. form_escape(entry.name) .. "]")
			table.insert(formspec, "label[" .. value_x .. "," .. (y + 0.2) .. ";" .. form_escape(stats.format_value(field, entry.value)) .. "]")
		end

		if max_scroll > 0 then
			table.insert(formspec, "scroll_container_end[]")
		end
	end

	function stats.show_form(player_name, tab, target_name, scroll_value)
		if not core.get_player_by_name(player_name) then
			return
		end

		tab = math.max(1, math.min(5, tonumber(tab) or 1))
		target_name = stats.get_profile(target_name, false) and target_name or player_name
		scroll_value = math.max(0, math.floor(tonumber(scroll_value) or 0))
		open_forms[player_name] = {tab = tab, target_name = target_name, scroll_value = scroll_value}

		local formspec = {
			"formspec_version[4]size[11.6,8.4]no_prepend[]",
			"bgcolor[#101522;both]",
			"box[0.25,0.2;11.1,0.84;#1d2a40]",
			"tabheader[0.45,1.02;10.7,0.65;stats_tabs;Profile,Playtime,Kills,Deaths,K/D;" .. tab .. ";false;true]",
			"box[0.25,1.62;11.1,6.15;#131c2d]",
			"button[0.55,7.86;2.45,0.42;stats_refresh;Refresh]",
			"button_exit[8.85,7.86;2.15,0.42;stats_close;Close]",
		}

		if tab == 1 then
			append_profile_tab(formspec, target_name)
		else
			append_leaderboard_tab(formspec, ({"playtime", "kills", "deaths", "kd"})[tab - 1], scroll_value)
		end

		core.show_formspec(player_name, "player_stats:main", table.concat(formspec))
	end

	function stats.close_form(name)
		open_forms[name] = nil
	end

	core.register_on_player_receive_fields(function(player, formname, fields)
		if formname ~= "player_stats:main" then
			return
		end

		local name = player:get_player_name()
		if fields.quit or fields.stats_close then
			stats.close_form(name)
			return
		end

		local state = open_forms[name] or {tab = 1, target_name = name, scroll_value = 0}
		if fields.leaderboard_scroll then
			local event = core.explode_scrollbar_event(fields.leaderboard_scroll)
			if event and event.value then
				state.scroll_value = event.value
			end

			-- Scrolling is handled by the client. Rebuilding the formspec for every
			-- cursor movement makes dragging the scrollbar noticeably sluggish.
			if not fields.stats_tabs and not fields.stats_refresh then
				return
			end
		end

		local tab = tonumber(fields.stats_tabs) or state.tab
		local scroll_value = tab == state.tab and state.scroll_value or 0
		stats.show_form(name, tab, state.target_name, scroll_value)
	end)
end
