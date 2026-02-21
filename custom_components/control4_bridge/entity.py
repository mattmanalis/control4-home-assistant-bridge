"""Base entity for Control4 Bridge devices."""

from __future__ import annotations

from typing import Any

from homeassistant.helpers.device_registry import DeviceInfo
from homeassistant.helpers.entity import Entity

from .const import DOMAIN
from .store import BridgeStore


class Control4BridgeEntity(Entity):
    """Base bridge entity."""

    _attr_should_poll = False

    def __init__(self, store: BridgeStore, device_id: str) -> None:
        self._store = store
        self._device_id = device_id

    @property
    def _device(self):
        return self._store.devices[self._device_id]

    @property
    def name(self) -> str:
        return self._device.name

    @property
    def unique_id(self) -> str:
        return f"control4_bridge_{self._store.bridge_id}_{self._device_id}"

    @property
    def available(self) -> bool:
        return self._device_id in self._store.devices

    @property
    def device_info(self) -> DeviceInfo:
        return DeviceInfo(
            identifiers={(DOMAIN, f"{self._store.bridge_id}:{self._device_id}")},
            manufacturer="Control4",
            model="Bridge Device",
            name=self._device.name,
            suggested_area=self._device.room or None,
        )

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        return {
            "control4_device_id": self._device_id,
            "control4_room": self._device.room,
            "control4_capabilities": self._device.capabilities,
        }
