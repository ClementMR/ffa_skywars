local mod_name = core.get_current_modname()

local http_api = core.request_http_api()

if http_api == nil then
    core.log("error", "[anti-vpn] core.request_http_api() failed. Add " .. mod_name .. " to secure.http_mods.")
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

local function get_threat_type(data)
    local security = data and data.security
    if type(security) ~= "table" then
        return nil
    end

    local threats = {}
    if security.vpn then table.insert(threats, "VPN") end
    if security.proxy then table.insert(threats, "Proxy") end
    if security.tor then table.insert(threats, "Tor") end
    if security.relay then table.insert(threats, "Relay") end

    if #threats > 0 then
        return table.concat(threats, "/")
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
local verification_cache = {}
local pending_checks = {}
local pending_count = 0
local request_times = {}

local function positive_setting(name, default, minimum)
    return math.max(minimum, math.floor(tonumber(core.settings:get(name)) or default))
end

local cache_ttl = positive_setting("anti_vpn_cache_ttl", 900, 60)
local failure_cache_ttl = positive_setting("anti_vpn_failure_cache_ttl", 30, 1)
local max_pending = positive_setting("anti_vpn_max_pending", 8, 1)
local max_requests_per_minute = positive_setting("anti_vpn_max_requests_per_minute", 20, 1)

local function get_time()
    return core.get_gametime()
end

local function get_cached_verification(ip)
    local cached = verification_cache[ip]
    if cached and cached.expires_at > get_time() then
        return cached
    end
    verification_cache[ip] = nil
end

local function allow_new_request()
    local now = get_time()
    while request_times[1] and request_times[1] <= now - 60 do
        table.remove(request_times, 1)
    end
    if #request_times >= max_requests_per_minute then
        return false
    end
    table.insert(request_times, now)
    return true
end

local function is_threat_ip(ip)
    local threat_data = storage:get_string("threat_" .. ip)

    if threat_data and threat_data ~= "" then
        return true, threat_data
    end

    return false, nil
end

local function add_threat_ip(ip, threat_type)
    storage:set_string("threat_" .. ip, threat_type)

    core.log("action", "[VPN] Added a threat to the block list as: " .. threat_type)
end

local function remove_threat_ip(ip)
    storage:set_string("threat_" .. ip, "")

    core.log("action", "[VPN] Removed a threat from the block list")
end

local function perform_vpn_api_check(ip, callback)
    if not http_api then
        callback(false, "HTTP API not available")
        return
    end

    if API_KEY == "" then
        callback(false, "API key not configured properly")
        return
    end

    local url = API_URL .. ip .. "?key=" .. API_KEY

    -- Never log the request URL: it contains the API key.
    core.log("action", "[anti-vpn] Sending a verification request")

    http_api.fetch({
        url = url,
        method = "GET",
        timeout = 15,
        user_agent = "core VPN Checker"
    }, function(result)
        if not result.succeeded or result.code ~= 200 then
            local error_msg = "API request failed"

            if result.reason then
                error_msg = error_msg .. ": " .. tostring(result.reason)
            end
            if result.code then
                error_msg = error_msg .. " (Code: " .. tostring(result.code) .. ")"
            end

            callback(false, error_msg)
            return
        end

        if not result.data or result.data == "" then
            callback(false, "Empty API response")
            return
        end

        local data = core.parse_json(result.data)
        if not data then
            callback(false, "Invalid API response")
            return
        end

        if type(data) ~= "table" then
            callback(false, "Response is not a JSON object")
            return
        end

        if data.message then
            if data.message:match("private IP address") then
                callback(true, {ip = ip, security = {}})
                return
            elseif data.message:match("quota") or data.message:match("limit") or data.message:match("exceeded") then
                core.log("warning", "[anti-vpn] The verification provider reported a quota error")
                callback(false, "Verification provider quota exceeded")
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

        if type(data.security) ~= "table" then
            callback(false, "API response missing security data")
            return
        end
        
        callback(true, data)
    end)
end

local function finish_check(ip, success, result)
    local callbacks = pending_checks[ip]
    if not callbacks then
        return
    end

    pending_checks[ip] = nil
    pending_count = math.max(0, pending_count - 1)
    verification_cache[ip] = {
        success = success,
        result = result,
        expires_at = get_time() + (success and cache_ttl or failure_cache_ttl),
    }

    for _, callback in ipairs(callbacks) do
        local ok, err = pcall(callback, success, result)
        if not ok then
            core.log("error", "[anti-vpn] Verification callback failed: " .. tostring(err))
        end
    end
end

-- Coalesce same-IP requests and bound both concurrent and per-minute work.
local function check_vpn_api(ip, callback)
    if not http_api then
        return false, "HTTP API is not available."
    end
    if API_KEY == "" then
        return false, "API key is not configured."
    end

    local cached = get_cached_verification(ip)
    if cached then
        callback(cached.success, cached.result)
        return true, "cached"
    end

    if pending_checks[ip] then
        table.insert(pending_checks[ip], callback)
        return true, "pending"
    end

    if pending_count >= max_pending then
        return false, "Verification service is busy. Please retry shortly."
    end
    if not allow_new_request() then
        return false, "Verification rate limit reached. Please retry shortly."
    end

    pending_checks[ip] = {callback}
    pending_count = pending_count + 1
    perform_vpn_api_check(ip, function(success, result)
        finish_check(ip, success, result)
    end)
    return true, "started"
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

        local started, message = check_vpn_api(ip, function(success, result)
            if not success then

                core.chat_send_player(name, "Error: " .. result)
                core.log("warning", "[VPN] A manual verification failed")

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
                    core.log("warning", "[VPN] Manual verification detected a threat")
                else
                    core.log("action", "[VPN] Manual verification completed without a threat")
                end
            end
        end)
        if not started then
            return false, message
        end
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
        core.log("action", "[VPN] Allowing a local/private connection")
        return
    end
    local is_threat, threat_type = is_threat_ip(cleaned_ip)
    if is_threat then
        core.log("warning", "[VPN] Blocked a known " .. threat_type .. " connection")
        return "Connection blocked: " .. threat_type .. " detected. VPNs and proxies are not allowed on this server."
    end
    if not http_api or API_KEY == "" then
        return "Connection verification is unavailable. Please contact a server administrator."
    end

    local cached = get_cached_verification(cleaned_ip)
    if cached then
        if not cached.success then
            return "Connection verification is temporarily unavailable. Please retry shortly."
        end
        local cached_threat = get_threat_type(cached.result)
        if cached_threat then
            add_threat_ip(cleaned_ip, cached_threat)
            return "Connection blocked: " .. cached_threat .. " detected. VPNs and proxies are not allowed on this server."
        end
        return
    end

    local started, message = check_vpn_api(cleaned_ip, function(success, result)
        if success then
            local detected_threat = get_threat_type(result)
            if detected_threat then
                add_threat_ip(cleaned_ip, detected_threat)
            end
        end
    end)
    if not started then
        return message
    end
    return "Connection verification started. Please reconnect in a moment."
end)
