--[[=============================================================================
  Control4 Home Assistant Bridge (MVP)
  Dealer test build for Composer upload.
===============================================================================]]

local VERSION = "0.1.0"
local POLL_INTERVAL_SECONDS = 2
local SYNC_INTERVAL_SECONDS = 15

local BRIDGE_ID = "main_house"
local SHARED_SECRET = ""
local HA_BASE_URL = "http://homeassistant.local:8123"
local DEBUG_ENABLED = false

local sync_timer = nil
local poll_timer = nil
local command_ack_buffer = {}
local HTTP_OPTIONS = {
  cookies_enable = false,
  fail_on_error = false,
}

local function bool_string(value)
  return value == true and "true" or "false"
end

local function debug_log(msg)
  if DEBUG_ENABLED then
    C4:DebugLog("[C4-HA Bridge] " .. tostring(msg))
  end
end

local function info_log(msg)
  print("[C4-HA Bridge] " .. tostring(msg))
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
end

local function auth_headers()
  return {
    ["Content-Type"] = "application/json",
    ["X-C4-Bridge-Secret"] = SHARED_SECRET,
  }
end

local function build_sync_payload()
  -- TODO: Replace placeholder payload with allowlisted devices selected in Composer.
  return {
    protocol_version = 1,
    bridge_id = BRIDGE_ID,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    devices = {
      {
        device_id = "1001",
        name = "Kitchen Pendants",
        room = "Kitchen",
        type = "light",
        capabilities = {"on_off", "brightness"},
        state = {
          on = true,
          brightness = 75,
        }
      }
    }
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

local function execute_command(command)
  -- TODO: Map these actions to real C4 proxy/device operations.
  local action = tostring(command.action or "")
  local command_id = tostring(command.command_id or "")
  local device_id = tostring(command.device_id or "")

  debug_log("Execute command_id=" .. command_id .. " device_id=" .. device_id .. " action=" .. action)

  table.insert(command_ack_buffer, {
    command_id = command_id,
    status = "success",
    message = "Executed in MVP bridge stub",
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
      info_log("Ack failed HTTP=" .. tostring(code) .. " err=" .. tostring(err))
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
  debug_log("Debug Mode=" .. bool_string(DEBUG_ENABLED))

  if name == "Bridge ID" or name == "Shared Secret" or name == "Home Assistant Base URL" then
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
