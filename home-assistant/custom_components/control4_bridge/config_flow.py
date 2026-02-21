"""Config flow for Control4 Bridge."""

from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant import config_entries
from homeassistant.helpers import selector

from .const import CONF_BRIDGE_ID, CONF_SHARED_SECRET, DEFAULT_BRIDGE_ID, DEFAULT_NAME, DOMAIN


class Control4BridgeConfigFlow(config_entries.ConfigFlow, domain=DOMAIN):
    """Handle a config flow for Control4 Bridge."""

    VERSION = 1

    @staticmethod
    def async_get_options_flow(config_entry: config_entries.ConfigEntry) -> config_entries.OptionsFlow:
        """Return the options flow handler."""
        return Control4BridgeOptionsFlow(config_entry)

    async def async_step_user(self, user_input: dict[str, Any] | None = None):
        """Handle the initial step."""
        if user_input is not None:
            bridge_id = str(user_input[CONF_BRIDGE_ID]).strip()
            await self.async_set_unique_id(bridge_id)
            self._abort_if_unique_id_configured()

            return self.async_create_entry(
                title=str(user_input.get("name", DEFAULT_NAME)).strip() or DEFAULT_NAME,
                data={
                    CONF_BRIDGE_ID: bridge_id,
                    CONF_SHARED_SECRET: str(user_input[CONF_SHARED_SECRET]).strip(),
                },
            )

        return self.async_show_form(
            step_id="user",
            data_schema=vol.Schema(
                {
                    vol.Required("name", default=DEFAULT_NAME): selector.TextSelector(),
                    vol.Required(CONF_BRIDGE_ID, default=DEFAULT_BRIDGE_ID): selector.TextSelector(),
                    vol.Required(CONF_SHARED_SECRET): selector.TextSelector(
                        selector.TextSelectorConfig(type=selector.TextSelectorType.PASSWORD)
                    ),
                }
            ),
        )


class Control4BridgeOptionsFlow(config_entries.OptionsFlowWithConfigEntry):
    """Handle options for Control4 Bridge."""

    async def async_step_init(self, user_input: dict[str, Any] | None = None):
        """Manage options."""
        if user_input is not None:
            return self.async_create_entry(title="", data=user_input)

        return self.async_show_form(
            step_id="init",
            data_schema=vol.Schema(
                {
                    vol.Optional(
                        "command_batch_size",
                        default=int(self.config_entry.options.get("command_batch_size", 25)),
                    ): vol.All(vol.Coerce(int), vol.Range(min=1, max=100)),
                }
            ),
        )
