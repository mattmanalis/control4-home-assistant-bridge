# Control4 <-> Home Assistant Protocol (v1)

## Common

- Content-Type: `application/json`
- Authentication: `X-C4-Bridge-Secret: <shared_secret>`
- Bridge identifier: `bridge_id` string set in driver and integration

## 1) Sync State (Driver -> HA)

`POST /api/control4_bridge/sync`

Request:

```json
{
  "protocol_version": 1,
  "bridge_id": "main_house",
  "timestamp": "2026-02-21T20:30:00Z",
  "devices": [
    {
      "device_id": "1234",
      "name": "Kitchen Pendants",
      "room": "Kitchen",
      "type": "light",
      "capabilities": ["on_off", "brightness"],
      "state": {
        "on": true,
        "brightness": 78
      }
    }
  ]
}
```

Response:

```json
{
  "ok": true,
  "accepted_devices": 1
}
```

## 2) Poll Commands (Driver <- HA)

`GET /api/control4_bridge/commands?bridge_id=main_house&limit=25`

Response:

```json
{
  "ok": true,
  "commands": [
    {
      "command_id": "cmd_7f2f8cf7",
      "device_id": "1234",
      "action": "turn_on",
      "params": {
        "brightness": 90
      },
      "created_at": "2026-02-21T20:31:00Z"
    }
  ]
}
```

## 3) Ack Commands (Driver -> HA)

`POST /api/control4_bridge/ack`

Request:

```json
{
  "bridge_id": "main_house",
  "acks": [
    {
      "command_id": "cmd_7f2f8cf7",
      "status": "success",
      "message": "Executed"
    }
  ]
}
```

Response:

```json
{
  "ok": true,
  "acked": 1
}
```

## Errors

- `401` invalid/missing secret
- `400` malformed payload
- `404` unknown bridge
- `500` internal processing failure
