local mod_name = core.get_current_modname()
local mod_path = core.get_modpath(mod_name)

local http_api = core.request_http_api()

if http_api == nil then
    core.log("error", "[anti-vpn] core.request_http_api() failed. Add " .. mod_name .. " to secure.http_mods.")
    return
end

local API_KEY = core.settings:get("anti_vpn_api_key") or ""
local API_URL = "https://vpnapi.io/api/"

local function clean_ip(ip)
    if not ip then
        return nil
    end

    if ip:match("^::ffff:") then
        ip = ip:gsub("^::ffff:", "")
    end

    if ip == "127.0.0.1" or ip == "::1" or ip:match("^192%.168%.") or
       ip:match("^10%.") or ip:match("^172%.1[6-9]%.") or ip:match("^172%.2[0-9]%.") or
       ip:match("^172%.3[0-1]%.") then
        return nil
    end

    return ip
end

local function format_security_status(security)
    local threats = {}

    if security.vpn then
        table.insert(threats, "VPN")
    end

    if security.proxy then
        table.insert(threats, "Proxy")
    end

    if security.tor then
        table.insert(threats, "Tor")
    end

    if security.relay then
        table.insert(threats, "Relay")
    end

    if #threats > 0 then
        return "THREAT DETECTED: " .. table.concat(threats, ", ")
    else
        return "Clean"
    end

end

local function format_vpn_result(data)
    local result = {}

    table.insert(result, "IP: " .. data.ip)

    if data.security then
        table.insert(result, "Security: " .. format_security_status(data.security))
    end

    if data.location then
        local location_parts = {}

        if data.location.city and data.location.city ~= "" then
            table.insert(location_parts, data.location.city)
        end

        if data.location.region and data.location.region ~= "" then
            table.insert(location_parts, data.location.region)
        end

        if data.location.country then
            table.insert(location_parts, data.location.country)
        end

        if #location_parts > 0 then
            table.insert(result, "Location: " .. table.concat(location_parts, ", "))
        end
    end

    if data.network then

        if data.network.autonomous_system_organization then
            table.insert(result, "ISP: " .. data.network.autonomous_system_organization)
        end

        if data.network.autonomous_system_number then
            table.insert(result, "ASN: " .. data.network.autonomous_system_number)
        end

    end

    return table.concat(result, "\n")
end

local storage = core.get_mod_storage()

local function is_threat_ip(ip)
    local threat_data = storage:get_string("threat_" .. ip)

    if threat_data and threat_data ~= "" then
        return true, threat_data
    end

    return false, nil
end

local function add_threat_ip(ip, threat_type)
    storage:set_string("threat_" .. ip, threat_type)

    core.log("action", "[VPN] Added " .. ip .. " to threat list as: " .. threat_type)
end

local function remove_threat_ip(ip)
    storage:set_string("threat_" .. ip, "")

    core.log("action", "[VPN] Removed " .. ip .. " from threat list")
end

local function check_vpn_api(ip, callback)
    if not http_api then
        callback(false, "HTTP API not available")
        return
    end

    if API_KEY == "" then
        callback(false, "API key not configured properly")
        return
    end

    local url = API_URL .. ip .. "?key=" .. API_KEY

    core.log("action", "[anti-vpn] Making request to: " .. url)

    http_api.fetch({
        url = url,
        method = "GET",
        timeout = 15,
        user_agent = "core VPN Checker"
    }, function(result)
        core.log("action", "[anti-vpn] Response received")
        core.log("action", "[anti-vpn] Success: " .. tostring(result.succeeded))
        core.log("action", "[anti-vpn] Status code: " .. tostring(result.code or "none"))

        if result.data then
            core.log("action", "[anti-vpn] Response data length: " .. string.len(result.data))
            core.log("action", "[anti-vpn] Response data: " .. string.sub(result.data, 1, 500))
        else
            core.log("action", "[anti-vpn] No response data")
        end

        if not result.succeeded or result.code ~= 200 then
            local error_msg = "API request failed"

            if result.reason then
                error_msg = error_msg .. ": " .. tostring(result.reason)
            end
            if result.code then
                error_msg = error_msg .. " (Code: " .. tostring(result.code) .. ")"
            end

            if result.code == 429 or result.code == 403 or not result.succeeded then
                core.log("warning", "[anti-vpn] API failed (" .. error_msg .. ")")
                return
            end

            callback(false, error_msg)
            return
        end

        if not result.data or result.data == "" then
            core.log("warning", "[anti-vpn] Empty response...")
            return
        end

        local data = core.parse_json(result.data)
        if not data then
            core.log("warning", "[anti-vpn] Invalid JSON...")
            return
        end

        if type(data) ~= "table" then
            callback(false, "Response is not a JSON object")
            return
        end

        if data.message then
            if data.message:match("private IP address") then
                core.log("action", "[anti-vpn] Private IP detected, considering as clean: " .. ip)
                callback(false, "Private IP address (considered safe)")
                return
            elseif data.message:match("quota") or data.message:match("limit") or data.message:match("exceeded") then
                core.log("warning", "[anti-vpn] Quota/limit error with the key, " .. tostring(data.message))
                return
            else
                callback(false, "API Error: " .. tostring(data.message))
                return
            end
        end

        if not data.ip then
            local available_fields = {}
            for key, _ in pairs(data) do
                table.insert(available_fields, tostring(key))
            end
            callback(false, "Missing 'ip' field. Available fields: " .. table.concat(available_fields, ", "))
            return
        end

        if not data.security and not data.location and not data.network then
            core.log("warning", "[anti-vpn] API response missing expected fields")
            return
        end
        
        callback(true, data)
    end)
end

core.register_chatcommand("vpn", {
    params = "<player_name>",
    description = "Check if a player is using VPN/Proxy/Tor",
    privs = {ban = true},
    func = function(name, param)
        if not param or param == "" then
            return false, "Usage: /vpn <player_name>"
        end

        local target_player = param:trim()
        local raw_ip = core.get_player_ip(target_player)
        local ip = clean_ip(raw_ip)

        if not raw_ip then
            return false, "Player '" .. target_player .. "' not found or offline"
        end

        if not ip then
            return false, "Player '" .. target_player .. "' has a private/local IP address (" .. raw_ip .. ") - cannot check VPN status"
        end

        core.chat_send_player(name, "Checking IP " .. ip .. " for player " .. target_player .. "...")

        check_vpn_api(ip, function(success, result)
            if not success then

                core.chat_send_player(name, "Error: " .. result)
                core.log("error", "[VPN] Check failed: " .. result)

                return
            end

            local formatted_result = format_vpn_result(result)

            core.chat_send_player(name, "VPN Check Result for " .. target_player .. ":")

            for line in formatted_result:gmatch("[^\n]+") do
                core.chat_send_player(name, line)
            end

            if result.security then
                local is_threat = result.security.vpn or result.security.proxy or result.security.tor or result.security.relay
                if is_threat then
                    core.log("warning", "[VPN] Player " .. target_player .. " (" .. ip .. ") detected as threat")
                else
                    core.log("action", "[VPN] Player " .. target_player .. " (" .. ip .. ") is clean")
                end
            end
        end)
        return true, "VPN check initiated..."
    end
})

core.register_chatcommand("vpnlist", {
    params = "",
    description = "List all blocked threat IPs",
    privs = {ban = true},
    func = function(name, param)
        local threat_count = 0
        local threat_list = {}

        for key, value in pairs(storage:to_table().fields) do

            if key:match("^threat_") and value ~= "" then
                local ip = key:gsub("^threat_", "")

                table.insert(threat_list, ip .. " (" .. value .. ")")
                threat_count = threat_count + 1
            end

        end

        if threat_count == 0 then
            return true, "No threat IPs stored"
        end

        core.chat_send_player(name, "Blocked threat IPs (" .. threat_count .. " total):")

        for _, entry in ipairs(threat_list) do
            core.chat_send_player(name, "- " .. entry)
        end

        return true
    end
})

core.register_chatcommand("vpnremove", {
    params = "<ip>",
    description = "Remove an IP from the threat list",
    privs = {ban = true},
    func = function(name, param)
        if not param or param == "" then
            return false, "Usage: /vpnremove <ip>"
        end

        local ip = param:trim()
        local is_threat, threat_type = is_threat_ip(ip)

        if not is_threat then
            return false, "IP " .. ip .. " is not in the threat list"
        end

        remove_threat_ip(ip)

        return true, "Removed " .. ip .. " (" .. threat_type .. ") from threat list"
    end
})

core.register_chatcommand("vpnclear", {
    params = "",
    description = "Clear all threat IPs from storage",
    privs = {server = true},
    func = function(name, param)
        local cleared_count = 0

        for key, value in pairs(storage:to_table().fields) do

            if key:match("^threat_") and value ~= "" then
                storage:set_string(key, "")
                cleared_count = cleared_count + 1
            end

        end

        core.log("action", "[VPN] Cleared " .. cleared_count .. " threat IPs by " .. name)

        return true, "Cleared " .. cleared_count .. " threat IPs from storage"
    end
})

core.register_on_prejoinplayer(function(name, ip)
    local cleaned_ip = clean_ip(ip)
    if not cleaned_ip then
        core.log("action", "[VPN] Player " .. name .. " connecting from private IP: " .. ip)
        return
    end
    local is_threat, threat_type = is_threat_ip(cleaned_ip)
    if is_threat then
        core.log("warning", "[VPN] Blocked connection from " .. name .. " (" .. cleaned_ip .. ") - known threat: " .. threat_type)
        return "Connection blocked: " .. threat_type .. " detected. VPNs and proxies are not allowed on this server."
    end
    core.log("action", "[VPN] Player " .. name .. " connecting with clean/unknown IP: " .. cleaned_ip .. " - allowing connection, will verify in background")
    core.after(5, function()
        check_vpn_api(cleaned_ip, function(success, result)
            if success and result and result.security then
                local is_threat = result.security.vpn or result.security.proxy or result.security.tor or result.security.relay

                if is_threat then
                    local threat_types = {}
                    if result.security.vpn then table.insert(threat_types, "VPN") end
                    if result.security.proxy then table.insert(threat_types, "Proxy") end
                    if result.security.tor then table.insert(threat_types, "Tor") end
                    if result.security.relay then table.insert(threat_types, "Relay") end

                    local threat_string = table.concat(threat_types, "/")
                    add_threat_ip(cleaned_ip, threat_string)
                    core.log("warning", "[VPN] Background check: Player " .. name .. " (" .. cleaned_ip .. ") detected as threat: " .. threat_string)
                    local player = core.get_player_by_name(name)
                    if player then
                        core.kick_player(name, "Connection blocked: " .. threat_string .. " detected. VPNs and proxies are not allowed on this server.")
                    end
                else
                    core.log("action", "[VPN] Background check: Player " .. name .. " (" .. cleaned_ip .. ") verified as clean")
                end
            else
                core.log("warning", "[VPN] Background check failed for " .. name .. " (" .. cleaned_ip .. "): " .. (result or "unknown error"))
            end
        end)
    end)
end)