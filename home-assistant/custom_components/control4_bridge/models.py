"""Data models for Control4 Bridge."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, UTC
from typing import Any


@dataclass(slots=True)
class BridgeDevice:
    """Represents a single Control4 device mirrored into HA."""

    device_id: str
    name: str
    room: str
    device_type: str
    capabilities: list[str] = field(default_factory=list)
    state: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class BridgeCommand:
    """Represents one queued command from HA to Control4."""

    command_id: str
    device_id: str
    action: str
    params: dict[str, Any] = field(default_factory=dict)
    created_at: str = field(default_factory=lambda: datetime.now(UTC).isoformat())
