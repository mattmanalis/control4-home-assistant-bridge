-- Control4 Home Assistant Bridge (MVP skeleton)
-- Drop this logic into your DriverWorks driver project and map real bindings/proxies.

PROTOCOL_VERSION = 1
POLL_INTERVAL_SECONDS = 2
SYNC_INTERVAL_SECONDS = 15

local BRIDGE_ID = Properties["Bridge ID"] or "main_house"
local SHARED_SECRET = Properties["Shared Secret"] or ""
local HA_BASE_URL = Properties["Home Assistant Base URL"] or "http://homeassistant.local:8123"

local command_ack_buffer = {}

local function log(msg)
  print("[C4-HA Bridge] " .. tostring(msg))
end

local function auth_headers()
  return {
    ["Content-Type"] = "application/json",
    ["X-C4-Bridge-Secret"] = SHARED_SECRET,
  }
end

local function build_sync_payload()
  -- TODO: Replace this with dynamic allowlisted devices from Composer properties/bindings.
  local devices = {
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

  return {
    protocol_version = PROTOCOL_VERSION,
    bridge_id = BRIDGE_ID,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    devices = devices,
  }
end

local function post_json(url, body_table, on_done)
  local body = C4:JsonEncode(body_table)
  C4:url()
    :OnDone(function(ticketId, strData, responseCode, tHeaders)
      if on_done then
        on_done(ticketId, strData, responseCode, tHeaders)
      end
    end)
    :Post(url, body, auth_headers())
end

local function get_json(url, on_done)
  C4:url()
    :OnDone(function(ticketId, strData, responseCode, tHeaders)
      if on_done then
        on_done(ticketId, strData, responseCode, tHeaders)
      end
    end)
    :Get(url, auth_headers())
end

local function sync_to_ha()
  if SHARED_SECRET == "" then
    log("Shared Secret not configured")
    return
  end

  local payload = build_sync_payload()
  post_json(HA_BASE_URL .. "/api/control4_bridge/sync", payload, function(_, data, code)
    if code ~= 200 then
      log("Sync failed HTTP " .. tostring(code))
      return
    end
    log("Sync succeeded")
  end)
end

local function execute_command(command)
  -- TODO: Map command.action to real C4 proxy/device commands.
  -- command fields: command_id, device_id, action, params
  log("Executing command " .. tostring(command.command_id) .. " action=" .. tostring(command.action))
  table.insert(command_ack_buffer, {
    command_id = command.command_id,
    status = "success",
    message = "Executed",
  })
end

local function poll_commands()
  if SHARED_SECRET == "" then
    return
  end

  local url = HA_BASE_URL .. "/api/control4_bridge/commands?bridge_id=" .. BRIDGE_ID .. "&limit=25"
  get_json(url, function(_, data, code)
    if code ~= 200 then
      log("Command poll failed HTTP " .. tostring(code))
      return
    end

    local ok, decoded = pcall(function()
      return C4:JsonDecode(data)
    end)
    if not ok or type(decoded) ~= "table" then
      log("Failed to decode command payload")
      return
    end

    local commands = decoded.commands or {}
    for _, cmd in ipairs(commands) do
      execute_command(cmd)
    end

    if #command_ack_buffer > 0 then
      local ack_payload = {
        bridge_id = BRIDGE_ID,
        acks = command_ack_buffer,
      }

      post_json(HA_BASE_URL .. "/api/control4_bridge/ack", ack_payload, function(_, _, ack_code)
        if ack_code == 200 then
          command_ack_buffer = {}
        else
          log("Ack failed HTTP " .. tostring(ack_code))
        end
      end)
    end
  end)
end

function OnDriverInit()
  log("Driver init")
  C4:SetTimer(SYNC_INTERVAL_SECONDS * 1000, function()
    sync_to_ha()
  end, true)

  C4:SetTimer(POLL_INTERVAL_SECONDS * 1000, function()
    poll_commands()
  end, true)
end

function OnPropertyChanged(name)
  if name == "Bridge ID" then
    BRIDGE_ID = Properties["Bridge ID"]
  elseif name == "Shared Secret" then
    SHARED_SECRET = Properties["Shared Secret"]
  elseif name == "Home Assistant Base URL" then
    HA_BASE_URL = Properties["Home Assistant Base URL"]
  end
end
