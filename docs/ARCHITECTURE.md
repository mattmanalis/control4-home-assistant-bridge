# Architecture

## Components

1. Control4 Driver (DriverWorks Lua)
2. Home Assistant Custom Integration (`control4_bridge`)
3. Home Assistant Automations/UI for exposed entities

## Direction of Traffic

- Control4 -> Home Assistant
  - Driver sends periodic state snapshots and immediate change events
  - Payload includes only allowlisted devices

- Home Assistant -> Control4
  - HA integration enqueues commands when user controls entities
  - Driver polls command queue and executes commands in Control4
  - Driver sends command acknowledgements

## Security Model

- Shared secret configured in both driver and HA integration
- Secret is required for sync, command polling, and acknowledgements
- Integration rejects requests with invalid credentials

## Device Selection

- Driver owns selection (Composer-level allowlist)
- Only selected devices are serialized into sync payload
- HA only creates entities for selected device records

## Entity Identity

- Stable key: `bridge_id + c4_device_id`
- HA unique_id format: `control4_bridge_<bridge_id>_<device_id>`
- Entity id uses a slug from room/name/type where possible

## Reliability

- Driver caches last known state and retries on transient HTTP failures
- Command queue uses IDs and ack flow for at-least-once delivery
- Driver de-duplicates command IDs after successful ack

## Initial Device Classes (MVP)

- Light
- Switch/Relay
- Binary sensor (motion/contact)

Planned next:

- Lock
- Cover/garage/gate
- Thermostat
- Media scenes / watch-listen virtual switches
