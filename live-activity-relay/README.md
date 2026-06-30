# AirPosture Live Activity Relay

This service receives Live Activity token/state events from the app and forwards them to APNs as `liveactivity` pushes.

## 1) Configure

Copy `.env.example` and set values:

- `APNS_ENV`: `development` (sandbox) or `production`
- `APNS_TEAM_ID`: Apple Developer Team ID
- `APNS_KEY_ID`: APNs Auth Key ID
- `APNS_PRIVATE_KEY_PATH` or `APNS_PRIVATE_KEY`: `.p8` key material
- `APP_BUNDLE_ID`: iOS app bundle id (example: `com.allenleee.AirPosturePro`)
- `RELAY_API_KEY`: shared secret (optional but recommended)
- `REGISTRATION_STORE_PATH`: durable registration store path (default: `data/registrations.json`)
- `REGISTRATION_MAX_AGE_SECONDS`: stale registration pruning age (default: 12 hours)

## 2) Run

```bash
cd live-activity-relay
node server.mjs
```

Health check:

```bash
curl http://localhost:8787/healthz
```

## 3) App configuration

In app `Info.plist` set:

- `LIVE_ACTIVITY_RELAY_BASE_URL` build setting to your relay URL (example: `https://relay.yourdomain.com`)
- `LIVE_ACTIVITY_RELAY_API_KEY` build setting to match `RELAY_API_KEY` (if used)

The app will call:

- `POST /api/live-activity/register`
- `POST /api/live-activity/update`
- `POST /api/live-activity/end`

## 4) Notes

- This relay persists registrations to `data/registrations.json` by default and reloads them on restart.
- Registrations are pruned when their `updatedAtUnix` age exceeds `REGISTRATION_MAX_AGE_SECONDS`.
- Deploy behind TLS (HTTPS) for production.
- Keep APNs key material outside source control.
