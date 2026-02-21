# MVP Checklist

## Phase 1: Protocol and Connectivity

- Implement HA integration endpoints (`sync`, `commands`, `ack`)
- Configure bridge_id and shared secret
- Validate driver can POST sync and GET empty command queue
- Add logging and auth failure diagnostics

## Phase 2: Device Export and Entity Creation

- Build Composer allowlist properties in driver
- Export selected Light/Switch/BinarySensor devices
- Create HA entities dynamically from incoming device type/state
- Verify entity unique_id stability across restarts

## Phase 3: Bidirectional Commands

- Map HA service calls -> queued bridge commands
- Driver polls and executes command mapping
- Driver acks command result
- Add retry + dedupe behavior

## Phase 4: Hardening

- Backoff and reconnect strategy
- Command timeout and stale cleanup
- Schema validation + protocol version checks
- Add unit tests for queue/state mapping

## Phase 5: Expansion

- Add Lock/Cover/Thermostat/Media types
- Add options flow for advanced tuning
- Add diagnostics endpoint/export
