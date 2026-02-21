"""Constants for Control4 Bridge."""

from homeassistant.const import Platform

DOMAIN = "control4_bridge"
PLATFORMS = [Platform.LIGHT, Platform.SWITCH, Platform.BINARY_SENSOR]

CONF_BRIDGE_ID = "bridge_id"
CONF_SHARED_SECRET = "shared_secret"

DEFAULT_NAME = "Control4 Bridge"
DEFAULT_BRIDGE_ID = "main_house"

API_SYNC_PATH = "/api/control4_bridge/sync"
API_COMMANDS_PATH = "/api/control4_bridge/commands"
API_ACK_PATH = "/api/control4_bridge/ack"

SIGNAL_DEVICE_UPDATE = "control4_bridge_device_update"

ATTR_PROTOCOL_VERSION = "protocol_version"
ATTR_TIMESTAMP = "timestamp"

PROTO_VERSION = 1
