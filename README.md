# StayAwake

A macOS menu bar toggle that keeps your Mac awake. Click once to stay awake,
click again to sleep normally.

You use this instead of walking into System Settings every time. Omarchy has a
built-in stay-awake toggle; this is the same idea for a stock Mac.

## Install

```bash
git clone https://github.com/Kamal-Nayan-Kumar/stayawake.git
cd stayawake
./build.sh
cp -R StayAwake.app /Applications/
open /Applications/StayAwake.app
```

A coffee cup appears in your menu bar (top right). It starts **off**, meaning
your Mac sleeps as usual.

Building needs Xcode or the Command Line Tools:

```bash
xcode-select --install
```

## Use it

Click the cup:

| Menu item | What it does |
|---|---|
| **Stay Awake** | Main toggle. On = Mac won't sleep. Off = normal sleep. |
| **Allow Screen to Sleep** | Only active while Stay Awake is on. Lets a long job run overnight without a bright screen all night. |
| **Launch at Login** | Start it automatically on boot. |
| **Quit StayAwake** | Quit the app. |

A line of text under the toggles shows the current state, so the menu is never
ambiguous. The icon also changes: a filled moon when awake, a plain cup when
sleeping.

## Why it is built this way

It uses the same power-assertion API that `caffeinate` and Linux's stay-awake
tools use. That means:

- **No `sudo`.** Nothing is written to System Settings, and no permanent
  setting is changed.
- **It cannot leave your Mac stuck awake.** The assertion belongs to the app
  process. Quit StayAwake, force quit it, or let it crash, and macOS drops the
  assertion and resumes normal sleep. There is no stale setting to clean up
  later.
- **Screen lock is unaffected.** It only controls *idle* sleep, so your login
  and password behave normally.

### Turning the display off too

If you want it to behave like a standard sleep-preventing tool rather than
holding the display on, macOS offers a matching command:

```bash
caffeinate -dimsu
```

`-d` display, `-i` idle, `-m` disk, `-s` system sleep on AC power, `-u` declares
the user active. StayAwake does the same job through a clickable icon.

## Running agents overnight

StayAwake solves one problem, and it is the easy one. The thing that actually
kills long-running jobs is the **process dying**, which sleep prevention cannot
help with. A closed terminal, a dropped SSH session, or a logout will end an
agent mid-task.

Run agents in a detached session so they survive that:

```bash
screen -S agents     # start a named session
# run your agent inside it
# detach with Ctrl-A, then D

screen -r agents     # reattach later
```

`screen` ships with macOS; `tmux` does not.

### Power outages

This is the part that catches people out. If the power goes out, your Mac will
**not** come back by itself unless this is on:

```bash
sudo pmset autorestartatconnect 1
```

Check your current setting with `pmset -g | grep autorestart`. If it is `0`,
nothing comes back after an outage and any overnight job stays dead until
someone presses the power button.

For genuinely unattended operation, combine all three:

1. StayAwake on, with **Launch at Login** enabled
2. Agents running in `screen`
3. `autorestartatconnect 1`, plus a **UPS**

The UPS is the highest-value piece. Without one, a brief flicker can still kill
a run, and a UPS also lets macOS ride out short dips without shutting down at
all.

### Lid close

Closing the lid overrides sleep prevention. On a Mac mini there is no lid, so
this only matters if you put a MacBook to sleep on the same Keep Awake setup.

## Verify it works

`verify.swift` checks the mechanism on your machine. It takes an assertion,
confirms macOS reports `PreventUserIdleSystemSleep` as `1`, releases it, and
confirms it is gone:

```bash
swiftc -O -o verify verify.swift && ./verify
```

Expected output ends with:

```
RESULT: PASS — mechanism works
```

You can also watch it live while using the app:

```bash
pmset -g assertions
```

Look for `StayAwake` listed under the owning process.

## Build after editing

```bash
./build.sh
cp -R StayAwake.app /Applications/
```

Ad-hoc signed, so no developer account is needed. If macOS still blocks it,
right-click the app and choose **Open** once.

The build targets Apple Silicon (`arm64`). For Intel, change the `-target` flag
in `build.sh`.

## Uninstall

```bash
rm -R /Applications/StayAwake.app
```

No settings to undo, which is the point.

## How it works

Two files:

- `StayAwakeApp.swift` — a `MenuBarExtra` SwiftUI app. It calls
  `IOPMAssertionCreateWithName` to hold a
  `kIOPMAssertionTypePreventUserIdleSystemSleep` assertion, and
  `kIOPMAssertionTypePreventUserIdleDisplaySleep` for the display, then
  releases them when you switch it off.
- `build.sh` — compiles it with `swiftc` and assembles the `.app` bundle.

No dependencies, no network access, no background service.

## License

MIT
