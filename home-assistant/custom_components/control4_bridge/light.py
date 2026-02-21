"""Light platform for Control4 Bridge."""

from __future__ import annotations

from homeassistant.components.light import ATTR_BRIGHTNESS, ColorMode, LightEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from .const import DOMAIN, SIGNAL_DEVICE_UPDATE
from .entity import Control4BridgeEntity
from .store import BridgeStore


class Control4BridgeLight(Control4BridgeEntity, LightEntity):
    """Bridge-backed light entity."""

    _attr_color_mode = ColorMode.BRIGHTNESS
    _attr_supported_color_modes = {ColorMode.ONOFF, ColorMode.BRIGHTNESS}

    @property
    def is_on(self) -> bool:
        return bool(self._device.state.get("on", False))

    @property
    def brightness(self):
        level = self._device.state.get("brightness")
        if level is None:
            return None
        return int(max(0, min(255, round(float(level) * 2.55))))

    async def async_turn_on(self, **kwargs):
        params = {}
        if ATTR_BRIGHTNESS in kwargs:
            params["brightness"] = int(round(kwargs[ATTR_BRIGHTNESS] / 2.55))
        self._store.enqueue_command(self._device_id, "turn_on", params)

    async def async_turn_off(self, **kwargs):
        self._store.enqueue_command(self._device_id, "turn_off", {})


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry, async_add_entities: AddEntitiesCallback) -> None:
    store: BridgeStore = hass.data[DOMAIN]["store"]
    entities: dict[str, Control4BridgeLight] = {}

    def _sync_entities() -> None:
        new_entities = []
        for device_id, device in store.devices.items():
            if device.device_type != "light" or device_id in entities:
                continue
            entity = Control4BridgeLight(store, device_id)
            entities[device_id] = entity
            new_entities.append(entity)

        if new_entities:
            async_add_entities(new_entities)

        for entity in entities.values():
            entity.async_write_ha_state()

    _sync_entities()
    entry.async_on_unload(async_dispatcher_connect(hass, SIGNAL_DEVICE_UPDATE, _sync_entities))
