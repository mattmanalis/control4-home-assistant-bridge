--[[=============================================================================
  Control4 Home Assistant Bridge (Lights MVP)
===============================================================================]]

local VERSION = "0.2.0"
local POLL_INTERVAL_SECONDS = 2
local SYNC_INTERVAL_SECONDS = 15

local BRIDGE_ID = "main_house"
local SHARED_SECRET = ""
local HA_BASE_URL = "http://homeassistant.local:8123"
local DEBUG_ENABLED = false
local DEFAULT_ROOM_NAME = "Control4"

local LIGHT_DEVICE_IDS = {}
local LIGHT_STATE = {}

local sync_timer = nil
local poll_timer = nil
local command_ack_buffer = {}
local HTTP_OPTIONS = {
  cookies_enable = false,
  fail_on_error = false,
}

local function debug_log(msg)
  if DEBUG_ENABLED then
    C4:DebugLog("[C4-HA Bridge] " .. tostring(msg))
  end
end

local function info_log(msg)
  print("[C4-HA Bridge] " .. tostring(msg))
end

local function trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parse_id_list(raw)
  local ids = {}
  local seen = {}
  for token in string.gmatch(tostring(raw or ""), "[^,]+") do
    local cleaned = trim(token)
    local numeric = tonumber(cleaned)
    if numeric ~= nil then
      cleaned = tostring(math.floor(numeric))
      if not seen[cleaned] then
        table.insert(ids, cleaned)
        seen[cleaned] = true
      end
    end
  end
  return ids
end

local function parse_ids_from_selector(raw)
  local ids = {}
  local seen = {}
  for token in string.gmatch(tostring(raw or ""), "%d+") do
    local id = tostring(tonumber(token))
    if id and not seen[id] then
      table.insert(ids, id)
      seen[id] = true
    end
  end
  return ids
end

local function update_runtime_properties()
  local v = VERSION
  if C4.GetDriverConfigInfo then
    local ok, configured = pcall(function() return C4:GetDriverConfigInfo("version") end)
    if ok and configured then
      v = configured
    end
  end

  C4:UpdateProperty("Driver Version", tostring(v))
  C4:UpdateProperty("Bridge Status", "Running")
end

local function load_properties()
  BRIDGE_ID = Properties["Bridge ID"] or "main_house"
  SHARED_SECRET = Properties["Shared Secret"] or ""
  HA_BASE_URL = Properties["Home Assistant Base URL"] or "http://homeassistant.local:8123"
  DEBUG_ENABLED = (Properties["Debug Mode"] == "On")
  DEFAULT_ROOM_NAME = trim(Properties["Default Room Name"] or "Control4")
  if DEFAULT_ROOM_NAME == "" then
    DEFAULT_ROOM_NAME = "Control4"
  end

  local selector_ids = parse_ids_from_selector(Properties["Light Devices"])
  if #selector_ids > 0 then
    LIGHT_DEVICE_IDS = selector_ids
  else
    LIGHT_DEVICE_IDS = parse_id_list(Properties["Light Device IDs"])
  end
  for _, id in ipairs(LIGHT_DEVICE_IDS) do
    if LIGHT_STATE[id] == nil then
      LIGHT_STATE[id] = { on = false, brightness = 0 }
    end
  end

  debug_log("Loaded " .. tostring(#LIGHT_DEVICE_IDS) .. " light device IDs")
end

local function auth_headers()
  return {
    ["Content-Type"] = "application/json",
    ["X-C4-Bridge-Secret"] = SHARED_SECRET,
  }
end

local function light_name_from_id(device_id)
  return "C4 Light " .. tostring(device_id)
end

local function build_sync_payload()
  local devices = {}

  for _, device_id in ipairs(LIGHT_DEVICE_IDS) do
    local state = LIGHT_STATE[device_id] or { on = false, brightness = 0 }
    table.insert(devices, {
      device_id = tostring(device_id),
      name = light_name_from_id(device_id),
      room = DEFAULT_ROOM_NAME,
      type = "light",
      capabilities = {"on_off", "brightness"},
      state = {
        on = state.on == true,
        brightness = tonumber(state.brightness) or 0,
      },
    })
  end

  return {
    protocol_version = 1,
    bridge_id = BRIDGE_ID,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    devices = devices,
  }
end

local function post_json(url, body_table, on_done)
  local body = C4:JsonEncode(body_table)
  local ticket_id = C4:urlPost(
    url,
    body,
    auth_headers(),
    false,
    function(tid, data, response_code, headers, err)
      if on_done then
        on_done(tid, data, response_code, headers, err)
      end
    end,
    HTTP_OPTIONS
  )

  debug_log("POST scheduled ticket=" .. tostring(ticket_id) .. " url=" .. tostring(url))
end

local function get_json(url, on_done)
  local ticket_id = C4:urlGet(
    url,
    auth_headers(),
    false,
    function(tid, data, response_code, headers, err)
      if on_done then
        on_done(tid, data, response_code, headers, err)
      end
    end,
    HTTP_OPTIONS
  )

  debug_log("GET scheduled ticket=" .. tostring(ticket_id) .. " url=" .. tostring(url))
end

local function sync_to_ha()
  if SHARED_SECRET == "" then
    C4:UpdateProperty("Bridge Status", "Missing Shared Secret")
    debug_log("Skipping sync: shared secret missing")
    return
  end

  post_json(HA_BASE_URL .. "/api/control4_bridge/sync", build_sync_payload(), function(_, data, code, _, err)
    if code == 200 then
      C4:UpdateProperty("Bridge Status", "Connected")
      debug_log("Sync succeeded")
    else
      C4:UpdateProperty("Bridge Status", "Sync Error " .. tostring(code))
      info_log("Sync failed code=" .. tostring(code) .. " err=" .. tostring(err))
      if data and tostring(data) ~= "" then
        info_log("Sync response body: " .. tostring(data))
      end
    end
  end)
end

local function send_to_device(device_id, command, params)
  if C4.SendToDevice == nil then
    return false, "C4:SendToDevice unavailable"
  end

  local numeric_id = tonumber(device_id)
  local target = numeric_id or device_id
  local ok, err = pcall(function()
    C4:SendToDevice(target, command, params or {})
  end)

  if not ok then
    return false, tostring(err)
  end
  return true, "sent"
end

local function clamp_percent(v)
  local n = tonumber(v) or 0
  if n < 0 then return 0 end
  if n > 100 then return 100 end
  return math.floor(n + 0.5)
end

local function handle_light_command(device_id, action, params)
  local state = LIGHT_STATE[device_id] or { on = false, brightness = 0 }
  LIGHT_STATE[device_id] = state

  if action == "turn_off" then
    local ok, err = send_to_device(device_id, "OFF", {})
    if ok then
      state.on = false
      state.brightness = 0
    end
    return ok, err
  end

  if action == "turn_on" then
    local brightness = nil
    if type(params) == "table" and params.brightness ~= nil then
      brightness = clamp_percent(params.brightness)
    end

    if brightness ~= nil then
      local ok_level = false
      local err_level = ""
      local tries = {
        { cmd = "RAMP_TO_LEVEL", args = { LEVEL = tostring(brightness), RATE = "0" } },
        { cmd = "SET_LEVEL", args = { LEVEL = tostring(brightness) } },
      }

      for _, attempt in ipairs(tries) do
        local ok, err = send_to_device(device_id, attempt.cmd, attempt.args)
        if ok then
          ok_level = true
          break
        end
        err_level = tostring(err)
      end

      if not ok_level then
        return false, "brightness command failed: " .. err_level
      end

      state.on = brightness > 0
      state.brightness = brightness
      return true, "brightness set"
    end

    local ok, err = send_to_device(device_id, "ON", {})
    if ok then
      state.on = true
      if (tonumber(state.brightness) or 0) == 0 then
        state.brightness = 100
      end
    end
    return ok, err
  end

  return false, "unsupported action for light"
end

local function execute_command(command)
  local action = tostring(command.action or "")
  local command_id = tostring(command.command_id or "")
  local device_id = tostring(command.device_id or "")
  local params = command.params

  debug_log("Execute command_id=" .. command_id .. " device_id=" .. device_id .. " action=" .. action)

  local ok = false
  local message = "unsupported device"

  if LIGHT_STATE[device_id] ~= nil then
    ok, message = handle_light_command(device_id, action, params)
  end

  table.insert(command_ack_buffer, {
    command_id = command_id,
    status = ok and "success" or "error",
    message = tostring(message),
  })
end

local function send_ack_batch()
  if #command_ack_buffer == 0 then
    return
  end

  local payload = {
    bridge_id = BRIDGE_ID,
    acks = command_ack_buffer,
  }

  post_json(HA_BASE_URL .. "/api/control4_bridge/ack", payload, function(_, _, code, _, err)
    if code == 200 then
      command_ack_buffer = {}
      debug_log("Command ack succeeded")
    else
      info_log("Ack failed code=" .. tostring(code) .. " err=" .. tostring(err))
    end
  end)
end

local function poll_commands()
  if SHARED_SECRET == "" then
    return
  end

  local url = HA_BASE_URL .. "/api/control4_bridge/commands?bridge_id=" .. BRIDGE_ID .. "&limit=25"
  get_json(url, function(_, data, code, _, err)
    if code ~= 200 then
      debug_log("Command poll failed code=" .. tostring(code) .. " err=" .. tostring(err))
      if data and tostring(data) ~= "" then
        debug_log("Command poll response body: " .. tostring(data))
      end
      return
    end

    local ok, decoded = pcall(function()
      return C4:JsonDecode(data)
    end)

    if not ok or type(decoded) ~= "table" then
      info_log("Failed to decode command payload")
      return
    end

    local commands = decoded.commands or {}
    if type(commands) ~= "table" then
      return
    end

    for _, cmd in ipairs(commands) do
      execute_command(cmd)
    end

    send_ack_batch()
  end)
end

local function schedule_timers()
  if sync_timer then
    sync_timer:Cancel()
  end
  if poll_timer then
    poll_timer:Cancel()
  end

  sync_timer = C4:SetTimer(SYNC_INTERVAL_SECONDS * 1000, function()
    sync_to_ha()
  end, true)

  poll_timer = C4:SetTimer(POLL_INTERVAL_SECONDS * 1000, function()
    poll_commands()
  end, true)

  debug_log("Timers started sync=" .. tostring(SYNC_INTERVAL_SECONDS) .. "s poll=" .. tostring(POLL_INTERVAL_SECONDS) .. "s")
end

local function force_sync_command()
  sync_to_ha()
end

local function force_poll_command()
  poll_commands()
end

function OnDriverLateInit()
  load_properties()
  update_runtime_properties()
  schedule_timers()
  info_log("Driver initialized")
end

function OnPropertyChanged(name)
  load_properties()
  debug_log("Property changed: " .. tostring(name))

  if name == "Bridge ID" or name == "Shared Secret" or name == "Home Assistant Base URL" or name == "Light Device IDs" or name == "Light Devices" or name == "Default Room Name" then
    sync_to_ha()
  end
end

function ExecuteCommand(strCommand, tParams)
  if strCommand == "ForceSync" then
    force_sync_command()
  elseif strCommand == "ForcePoll" then
    force_poll_command()
  end
end

function ReceivedFromProxy(idBinding, strCommand, tParams)
  debug_log("ReceivedFromProxy binding=" .. tostring(idBinding) .. " command=" .. tostring(strCommand))
end
