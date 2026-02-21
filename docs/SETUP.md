# Setup Guide (MVP)

## 1) Install the HA custom component

1. Copy `home-assistant/custom_components/control4_bridge` to your HA config directory under `custom_components/control4_bridge`.
2. Restart Home Assistant.
3. Add integration: **Settings -> Devices & Services -> Add Integration -> Control4 Bridge**.
4. Enter:
   - `Bridge ID` (example: `main_house`)
   - `Shared Secret` (long random string)

## 2) Prepare the Control4 driver project

Use `control4-driver/lua/c4_home_assistant_bridge.lua` as your logic base and wire it in DriverWorks.

Create driver properties in Composer/Driver XML that match:

- `Bridge ID`
- `Shared Secret`
- `Home Assistant Base URL` (example: `http://192.168.1.10:8123`)
- `Light Device IDs` (comma-separated Control4 light IDs, example: `1234,5678`)
- `Default Room Name` (optional room label shown in HA)

## 3) First connectivity test

1. Set properties in Composer.
2. Confirm Director can reach HA over network.
3. Watch HA logs for `control4_bridge` requests.
4. Verify entities appear after sync.

## 4) Command loop test

1. Toggle a bridged light/switch entity in HA.
2. Confirm command appears in driver poll response.
3. Confirm driver executes action and sends ack.

## 5) Expand mappings

- Replace placeholder static device payload in Lua with real allowlisted device discovery.
- Map `turn_on`, `turn_off`, and brightness to actual proxy commands.
- Add thermostat/lock/cover types once core loop is stable.
