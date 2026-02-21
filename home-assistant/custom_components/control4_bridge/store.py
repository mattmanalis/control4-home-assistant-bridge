"""Runtime store for Control4 Bridge."""

from __future__ import annotations

from collections import deque
from secrets import token_hex
from typing import Any

from .models import BridgeCommand, BridgeDevice


def _normalize_maybe_array(value: Any) -> list[Any]:
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        return [value[key] for key in sorted(value.keys(), key=lambda k: int(k) if str(k).isdigit() else str(k))]
    return []


class BridgeStore:
    """In-memory bridge state and command queue."""

    def __init__(self, bridge_id: str) -> None:
        self.bridge_id = bridge_id
        self.devices: dict[str, BridgeDevice] = {}
        self._commands: deque[BridgeCommand] = deque()
        self._inflight: dict[str, BridgeCommand] = {}

    def upsert_devices(self, raw_devices: list[dict[str, Any]]) -> int:
        accepted = 0
        for raw in raw_devices:
            device_id = str(raw.get("device_id", "")).strip()
            device_type = str(raw.get("type", "")).strip()
            if not device_id or not device_type:
                continue

            self.devices[device_id] = BridgeDevice(
                device_id=device_id,
                name=str(raw.get("name", device_id)),
                room=str(raw.get("room", "")),
                device_type=device_type,
                capabilities=_normalize_maybe_array(raw.get("capabilities", [])),
                state=raw.get("state", {}) if isinstance(raw.get("state", {}), dict) else {},
            )
            accepted += 1

        return accepted

    def enqueue_command(self, device_id: str, action: str, params: dict[str, Any] | None = None) -> str:
        command_id = f"cmd_{token_hex(6)}"
        self._commands.append(
            BridgeCommand(
                command_id=command_id,
                device_id=device_id,
                action=action,
                params=params or {},
            )
        )
        return command_id

    def pop_commands(self, limit: int) -> list[BridgeCommand]:
        commands: list[BridgeCommand] = []
        while self._commands and len(commands) < limit:
            command = self._commands.popleft()
            self._inflight[command.command_id] = command
            commands.append(command)
        return commands

    def ack_commands(self, command_ids: list[str]) -> int:
        acked = 0
        for command_id in command_ids:
            if self._inflight.pop(command_id, None) is not None:
                acked += 1
        return acked
