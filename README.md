# Vibe Check

Vibe Check is a native macOS menu bar app for watching Vercel deployments. It polls the Vercel REST API, shows a compact deployment indicator in the menu bar, and displays a top-center notch island toast whenever a deployment reaches `READY`.

The menu bar panel includes manual refresh, settings, launch-at-login preferences, and Sparkle-powered automatic updates.

## Build

```sh
swift build
```

To create a launchable `.app` bundle:

```sh
chmod +x scripts/build_app.sh
scripts/build_app.sh
open ".build/Vibe Check.app"
```

## Configure

Open the menu bar item, choose Settings, then paste a Vercel access token. Team ID and Project ID are optional. When Team ID is blank, Vibe Check lists personal deployments plus deployments from every team returned by `GET /v2/teams`. If Team ID is filled, it only watches that team.

The app uses `GET https://api.vercel.com/v6/deployments` with `Authorization: Bearer <token>`. Vercel documents team scoping with the `teamId` query parameter in the REST API reference: https://vercel.com/docs/rest-api

The Vercel token is stored in the macOS Keychain. Developer builds that used ad-hoc signing may create a legacy keychain entry; notarized releases avoid interactive keychain prompts for that legacy item.
