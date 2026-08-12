skywars.cleanup_timer = 2700

local S = core.get_translator(core.get_current_modname())

local nodes = {}

for _, nodename in ipairs(skywars.whitelist) do
    table.insert(nodes, core.get_content_id(nodename))
end

-- Helper: batch process a list with a function, n per step
local function batch_process(list, batch_size, fn, done)
    local i = 1
    local function step()
        for j = 1, batch_size do
            if i > #list then
                if done then done() end
                return
            end
            fn(list[i])
            i = i + 1
        end
        core.after(0.1, step)
    end
    step()
end

local function cleanup()
    local objs = {}
    for _, obj in ipairs(core.get_objects_inside_radius(skywars.map_center, skywars.radius)) do
        local entity = obj:get_luaentity()
        if entity and entity.name == "__builtin:item" then
            table.insert(objs, obj)
        end
    end
    batch_process(objs, 20, function(obj)
        if obj and obj:get_luaentity() then obj:remove() end
    end)

    for _, player in ipairs(core.get_connected_players()) do
        if player and not core.check_player_privs(player, {creative=true}) then
            skywars.teleport_player(player)
            core.chat_send_player(player:get_player_name(),
                S("@1 You have been tped!", core.colorize("red", S("[Cleanup]"))))
            hud_api.show_front(player, S("Cleaning the area").." ...", 0xFF0000, 1)
            core.after(3, hud_api.remove, player, "front")
        end
    end

    local minp = {
        x = skywars.map_center.x - skywars.radius,
        y = skywars.map_center.y - skywars.radius,
        z = skywars.map_center.z - skywars.radius
    }
    local maxp = {
        x = skywars.map_center.x + skywars.radius,
        y = skywars.map_center.y + skywars.radius,
        z = skywars.map_center.z + skywars.radius
    }

    local function after_emerge(blockpos, action, calls_remaining, param)
        if calls_remaining == 0 then
            local vm = core.get_voxel_manip()
            local emin, emax = vm:read_from_map(minp, maxp)
            local data = vm:get_data()
            local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
            local to_clear = {}
            for z = emin.z, emax.z do
                for y = emin.y, emax.y do
                    for x = emin.x, emax.x do
                        local vi = area:index(x, y, z)
                        for _, id in ipairs(nodes) do
                            if data[vi] == id then
                                table.insert(to_clear, vi)
                                break
                            end
                        end
                    end
                end
            end
            batch_process(to_clear, 2000, function(vi)
                data[vi] = core.get_content_id("air")
            end, function()
                vm:set_data(data)
                vm:write_to_map()
                vm:update_map()
            end)
        end
    end
    core.emerge_area(minp, maxp, after_emerge)
end

core.register_chatcommand("cleanup", {
    description = "",
    privs = {ffa_manager=true},
    func = function(name)
        cleanup()
        skywars.cleanup_timer = 2700
        return true, S("Cleaning area...")
    end
})

local function update_timer()
    if skywars.cleanup_timer == 0 then
        cleanup()
        skywars.cleanup_timer = 2700
    end

    core.after(1, update_timer)
    skywars.cleanup_timer = skywars.cleanup_timer - 1
end

core.after(0.1, update_timer)

for _, cmd in pairs({"clean_timer", "ct"}) do
    core.register_chatcommand(cmd, {
        description = S("Print the remaining time of the next cleaning"),
        privs = {interact=true},
        func = function(name)
            local timer = skywars.cleanup_timer or 0
            local mins = math.floor(timer / 60)
            local secs = timer % 60
            local time_str = ""
            if mins > 0 then
                time_str = mins .. "m:"
            end
            return true, core.colorize("red", S("[Cleanup] ")) .. S("@1@2s left!", time_str, secs)
        end
    })
end