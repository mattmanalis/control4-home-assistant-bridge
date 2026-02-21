"""Config flow for Control4 Bridge."""

from __future__ import annotations

import voluptuous as vol

from homeassistant import config_entries
from homeassistant.core import callback

from .const import CONF_BRIDGE_ID, CONF_SHARED_SECRET, DEFAULT_BRIDGE_ID, DEFAULT_NAME, DOMAIN


class Control4BridgeConfigFlow(config_entries.ConfigFlow, domain=DOMAIN):
    """Handle a config flow for Control4 Bridge."""

    VERSION = 1

    @staticmethod
    @callback
    def async_get_options_flow(config_entry: config_entries.ConfigEntry):
        return Control4BridgeOptionsFlow(config_entry)

    async def async_step_user(self, user_input=None):
        if user_input is not None:
            await self.async_set_unique_id(user_input[CONF_BRIDGE_ID])
            self._abort_if_unique_id_configured()

            return self.async_create_entry(
                title=user_input.get("name", DEFAULT_NAME),
                data={
                    CONF_BRIDGE_ID: user_input[CONF_BRIDGE_ID],
                    CONF_SHARED_SECRET: user_input[CONF_SHARED_SECRET],
                },
            )

        schema = vol.Schema(
            {
                vol.Required("name", default=DEFAULT_NAME): str,
                vol.Required(CONF_BRIDGE_ID, default=DEFAULT_BRIDGE_ID): str,
                vol.Required(CONF_SHARED_SECRET): str,
            }
        )
        return self.async_show_form(step_id="user", data_schema=schema)


class Control4BridgeOptionsFlow(config_entries.OptionsFlow):
    """Handle options for Control4 Bridge."""

    def __init__(self, config_entry: config_entries.ConfigEntry) -> None:
        self.config_entry = config_entry

    async def async_step_init(self, user_input=None):
        if user_input is not None:
            return self.async_create_entry(title="", data=user_input)

        schema = vol.Schema({
            vol.Optional("command_batch_size", default=self.config_entry.options.get("command_batch_size", 25)): int,
        })
        return self.async_show_form(step_id="init", data_schema=schema)
