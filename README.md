# StayAwake

A menu bar toggle that keeps your Mac awake. Click once to stay awake, click again to sleep normally.

## Build and install

```bash
./build.sh
cp -R StayAwake.app /Applications/
open /Applications/StayAwake.app
```

The icon is a coffee cup in the menu bar (top-right). It starts **off**, meaning your Mac sleeps as usual.

## Use it

Click the icon:

| Menu item | What it does |
|---|---|
| **Stay Awake** | Main toggle. On = Mac won't sleep. Off = normal sleep. |
| **Allow Screen to Sleep** | Only active while Stay Awake is on. Lets a long download run without keeping a bright screen on all night. |
| **Launch at Login** | Start it automatically on boot. |
| **Quit StayAwake** | Quit the app. |

The text under the toggles shows the current state, so the menu is never ambiguous.

The icon changes to show the state: a filled moon means awake, a plain cup means sleeping.

## Why it works this way

It uses the same power-assertion API that Omarchy's "stay awake" and the `caffeinate` command use. Nothing is written to System Settings, no `sudo` is needed, and no permanent settings change is made.

Two safety properties:

- **It cannot leave your Mac stuck awake.** The assertion belongs to the app process. Quit StayAwake, force quit it, or have it crash, and macOS drops the assertion and normal sleep resumes. There is no stale setting left behind.
- **Screen lock is unaffected.** This only controls idle sleep, so your login and password still behave normally.

`./verify` is a self-check that proves the mechanism on this machine: it takes an assertion, confirms macOS reports `PreventUserIdleSystemSleep` as `1`, releases it, and confirms the assertion is gone.

## Rebuild after editing

```bash
./build.sh
# then replace the installed copy
cp -R StayAwake.app /Applications/
```

Requires Xcode or the Command Line Tools (`xcode-select --install`). Ad-hoc signed, so no developer account needed. Only Apple Silicon (`arm64`); change `-target` in `build.sh` for Intel.