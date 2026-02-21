# Control4 -> Home Assistant Bridge (MVP)

This repository contains a starter architecture to build a **dealer-managed Control4 driver** that selectively shares devices into Home Assistant.

## Goals

- Select devices from Composer Pro (allowlist in the driver)
- Push state from Control4 to Home Assistant
- Pull command queue from Home Assistant so HA can control selected Control4 devices
- Keep protocol explicit and versioned for long-term maintenance

## Repository Layout

- `docs/ARCHITECTURE.md` - end-to-end architecture and data flow
- `docs/PROTOCOL.md` - JSON protocol between driver and HA integration
- `docs/MVP_CHECKLIST.md` - phased implementation plan
- `docs/SETUP.md` - installation and first lab validation steps
- `control4-driver/lua/c4_home_assistant_bridge.lua` - DriverWorks Lua starter
- `control4-driver/home_assistant_bridge_control4_v0.1.0.c4z` - initial Control4 test package
- `control4-driver/home_assistant_bridge_control4_v0.1.1.c4z` - improved HTTP diagnostics and transport handling
- `home-assistant/custom_components/control4_bridge/` - HA custom integration starter
- `custom_components/control4_bridge/` - HACS-compatible integration path (repo root)
- `hacs.json` - HACS metadata

## Current Status

This is an MVP scaffold, not a production-complete driver package yet. It is designed so you can:

1. Implement driver properties, bindings, and programming actions in Composer
2. Install the HA custom component and verify bridge connectivity
3. Expand supported device classes incrementally

## Next Step

Start with `docs/SETUP.md`, then use `docs/MVP_CHECKLIST.md` for phased hardening.

## Upload Targets

- Control4 Composer import file: `control4-driver/home_assistant_bridge_control4_v0.1.1.c4z`
- HACS repository content root: `custom_components/control4_bridge`
