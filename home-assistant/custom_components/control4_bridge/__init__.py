"""Control4 Bridge integration."""

from __future__ import annotations

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant

from .api import async_register_views
from .const import CONF_BRIDGE_ID, CONF_SHARED_SECRET, DOMAIN, PLATFORMS
from .store import BridgeStore


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Set up Control4 Bridge from a config entry."""

    hass.data.setdefault(DOMAIN, {})
    hass.data[DOMAIN]["entry_id"] = entry.entry_id
    hass.data[DOMAIN]["shared_secret"] = entry.data[CONF_SHARED_SECRET]
    hass.data[DOMAIN]["store"] = BridgeStore(entry.data[CONF_BRIDGE_ID])

    async_register_views(hass)
    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    return True


async def async_unload_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Unload a config entry."""

    unload_ok = await hass.config_entries.async_unload_platforms(entry, PLATFORMS)
    if unload_ok:
        hass.data.pop(DOMAIN, None)
    return unload_ok
