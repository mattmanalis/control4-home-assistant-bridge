"""Binary sensor platform for Control4 Bridge."""

from __future__ import annotations

from homeassistant.components.binary_sensor import BinarySensorEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from .const import DOMAIN, SIGNAL_DEVICE_UPDATE
from .entity import Control4BridgeEntity
from .store import BridgeStore


class Control4BridgeBinarySensor(Control4BridgeEntity, BinarySensorEntity):
    """Bridge-backed binary sensor."""

    @property
    def is_on(self) -> bool:
        return bool(self._device.state.get("on", False))


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry, async_add_entities: AddEntitiesCallback) -> None:
    store: BridgeStore = hass.data[DOMAIN]["store"]
    entities: dict[str, Control4BridgeBinarySensor] = {}

    def _sync_entities() -> None:
        new_entities = []
        for device_id, device in store.devices.items():
            if device.device_type not in {"binary_sensor", "motion", "contact"} or device_id in entities:
                continue
            entity = Control4BridgeBinarySensor(store, device_id)
            entities[device_id] = entity
            new_entities.append(entity)

        if new_entities:
            async_add_entities(new_entities)

        for entity in entities.values():
            entity.async_write_ha_state()

    _sync_entities()
    entry.async_on_unload(async_dispatcher_connect(hass, SIGNAL_DEVICE_UPDATE, _sync_entities))
