"""HTTP API for Control4 Bridge."""

from __future__ import annotations

from http import HTTPStatus
from typing import Any

from homeassistant.components.http import HomeAssistantView
from homeassistant.core import HomeAssistant
from homeassistant.helpers import device_registry as dr
from homeassistant.helpers.dispatcher import async_dispatcher_send

from .const import (
    API_ACK_PATH,
    API_COMMANDS_PATH,
    API_SYNC_PATH,
    ATTR_PROTOCOL_VERSION,
    DOMAIN,
    PROTO_VERSION,
    SIGNAL_DEVICE_UPDATE,
)
from .store import BridgeStore


class _BridgeBaseView(HomeAssistantView):
    """Shared behavior for bridge views."""

    requires_auth = False

    def _get_store(self, hass: HomeAssistant) -> BridgeStore:
        return hass.data[DOMAIN]["store"]

    def _is_authorized(self, hass: HomeAssistant, headers: dict[str, str]) -> bool:
        expected = hass.data[DOMAIN]["shared_secret"]
        provided = headers.get("X-C4-Bridge-Secret", "")
        return bool(provided) and provided == expected


class Control4SyncView(_BridgeBaseView):
    """Accepts state syncs from the Control4 driver."""

    url = API_SYNC_PATH
    name = "api:control4_bridge:sync"

    async def post(self, request):
        hass = request.app["hass"]
        if not self._is_authorized(hass, request.headers):
            return self.json({"ok": False, "error": "unauthorized"}, status_code=HTTPStatus.UNAUTHORIZED)

        body: dict[str, Any] = await request.json()
        store = self._get_store(hass)

        if body.get("bridge_id") != store.bridge_id:
            return self.json({"ok": False, "error": "unknown_bridge"}, status_code=HTTPStatus.NOT_FOUND)

        if body.get(ATTR_PROTOCOL_VERSION) != PROTO_VERSION:
            return self.json({"ok": False, "error": "unsupported_protocol"}, status_code=HTTPStatus.BAD_REQUEST)

        devices = body.get("devices", [])
        if not isinstance(devices, list):
            return self.json({"ok": False, "error": "invalid_devices"}, status_code=HTTPStatus.BAD_REQUEST)

        accepted = store.upsert_devices(devices)

        # Keep HA device registry in sync for discovery clarity.
        device_registry = dr.async_get(hass)
        for device in store.devices.values():
            device_registry.async_get_or_create(
                config_entry_id=hass.data[DOMAIN]["entry_id"],
                identifiers={(DOMAIN, f"{store.bridge_id}:{device.device_id}")},
                manufacturer="Control4",
                model="Bridge Device",
                name=device.name,
                suggested_area=device.room or None,
            )

        async_dispatcher_send(hass, SIGNAL_DEVICE_UPDATE)
        return self.json({"ok": True, "accepted_devices": accepted})


class Control4CommandsView(_BridgeBaseView):
    """Returns queued commands for driver polling."""

    url = API_COMMANDS_PATH
    name = "api:control4_bridge:commands"

    async def get(self, request):
        hass = request.app["hass"]
        if not self._is_authorized(hass, request.headers):
            return self.json({"ok": False, "error": "unauthorized"}, status_code=HTTPStatus.UNAUTHORIZED)

        store = self._get_store(hass)
        bridge_id = request.query.get("bridge_id", "")
        if bridge_id != store.bridge_id:
            return self.json({"ok": False, "error": "unknown_bridge"}, status_code=HTTPStatus.NOT_FOUND)

        try:
            limit = max(1, min(100, int(request.query.get("limit", 25))))
        except ValueError:
            limit = 25

        commands = store.pop_commands(limit)

        return self.json(
            {
                "ok": True,
                "commands": [
                    {
                        "command_id": cmd.command_id,
                        "device_id": cmd.device_id,
                        "action": cmd.action,
                        "params": cmd.params,
                        "created_at": cmd.created_at,
                    }
                    for cmd in commands
                ],
            }
        )


class Control4AckView(_BridgeBaseView):
    """Accepts command execution acknowledgements."""

    url = API_ACK_PATH
    name = "api:control4_bridge:ack"

    async def post(self, request):
        hass = request.app["hass"]
        if not self._is_authorized(hass, request.headers):
            return self.json({"ok": False, "error": "unauthorized"}, status_code=HTTPStatus.UNAUTHORIZED)

        body: dict[str, Any] = await request.json()
        store = self._get_store(hass)

        if body.get("bridge_id") != store.bridge_id:
            return self.json({"ok": False, "error": "unknown_bridge"}, status_code=HTTPStatus.NOT_FOUND)

        acks = body.get("acks", [])
        if not isinstance(acks, list):
            return self.json({"ok": False, "error": "invalid_acks"}, status_code=HTTPStatus.BAD_REQUEST)
        command_ids = [
            str(ack.get("command_id", "")).strip()
            for ack in acks
            if isinstance(ack, dict) and ack.get("command_id")
        ]
        acked = store.ack_commands(command_ids)
        return self.json({"ok": True, "acked": acked})


def async_register_views(hass: HomeAssistant) -> None:
    """Register all HTTP views."""

    hass.http.register_view(Control4SyncView())
    hass.http.register_view(Control4CommandsView())
    hass.http.register_view(Control4AckView())
