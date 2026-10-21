# StayAwake

A macOS menu bar toggle that keeps your Mac awake. Click once to stay awake, click again to sleep normally.

You use this instead of walking into System Settings every time. Omarchy has a built-in stay-awake toggle, this is the same idea for a stock Mac.

It is built for people who leave long jobs running on their Mac, especially coding agents that have to survive the night.

- No `sudo`, no System Settings changes, no background service, no network access.
- No dependencies. Two files of Swift and a build script.
- Quit the app and your Mac goes back to normal sleep. There is no stale setting to clean up.

## What the menu does

Click the cup in the menu bar (top right) to open the menu.

| Menu item | What it does |
|---|---|
| **Stay Awake** | The main switch. On means the Mac will not go to sleep on its own. Off means it sleeps as usual. |
| **Allow Screen to Sleep** | Only usable while Stay Awake is on. Lets the screen go dark on the normal timer while the Mac stays up. |
| **Launch at Login** | Starts StayAwake when you log in, so it is already holding the Mac awake by the time your agent starts. |
| **Quit StayAwake** | Quits the app. |

Underneath the toggles there is a line of text saying what the Mac is doing right now, so the menu is never ambiguous. The icon in the menu bar changes to match: a sleeping moon when the Mac sleeps, a sun when everything is held on, a coffee cup when the Mac is running but the screen is free to rest.

## Keep the Mac awake, screen off

Yes, this is what you want for overnight agent runs, and it is a supported mode.

Turn on **Stay Awake**, then turn on **Allow Screen to Sleep**.

| Mode | Mac stays awake | Screen stays on | Good for |
|---|---|---|---|
| Stay Awake off | no | no | Normal use. |
| Stay Awake on | yes | yes | Working at the desk, long downloads, a build you are watching. |
| Stay Awake on, Allow Screen to Sleep on | yes | no | Overnight agent runs. The screen goes dark on its own, the machine keeps working. |

How it works under the hood: the Mac is held awake with `kIOPMAssertionTypePreventUserIdleSystemSleep`, and the screen is held on with a second assertion, `kIOPMAssertionTypePreventUserIdleDisplaySleep`. "Allow Screen to Sleep" simply drops that second one. The machine keeps running, the display is free to sleep.

A few things worth knowing about that mode:

- The screen still wakes up when you move the mouse or press a key. "Allow Screen to Sleep" means the display is not held on forever, not that the display is off.
- The screen goes dark on your normal display timer (System Settings › Displays › Advanced › Turn display off on power adapter when inactive, usually 5 minutes).
- Locking the screen is separate and does not stop the Mac. `Ctrl Cmd Q` locks it, the Mac keeps running, and command line agents keep going.
- Closing the lid still forces the Mac to sleep. That overrides everything here. It only matters on a MacBook.

## Install

### Download a build

Grab it from the [releases page](https://github.com/Kamal-Nayan-Kumar/stayawake/releases):

| Your Mac | Download |
|---|---|
| Apple Silicon (M1, M2, M3, M4...) | `StayAwake-arm64.zip` |
| Intel | `StayAwake-x86_64.zip` |

Unzip it, then drag `StayAwake.app` into your Applications folder.

macOS will not open an app that was not notarized, so the first time, right-click `StayAwake.app` in Applications and choose **Open**. After that it opens normally like any other app.

### Build it yourself

You need Xcode or the Command Line Tools:

```bash
xcode-select --install
```

Then:

```bash
git clone https://github.com/Kamal-Nayan-Kumar/stayawake.git
cd stayawake
./build.sh
cp -R StayAwake.app /Applications/
open /Applications/StayAwake.app
```

The build signs the app with an ad-hoc signature, so no developer account is needed.

If you have Xcode, you can also open `Package.swift` and run it from there.

### Uninstall

```bash
rm -R /Applications/StayAwake.app
```

There are no settings to undo, which is the point.

## Use it

Turn on **Launch at Login** first. After that, StayAwake is already holding the Mac awake the next time you log in, which is what you want if a long job is waiting to start.

Then turn on **Stay Awake**.

The app remembers how you left it. Quit it, reopen it, reboot, and it comes back the way you set it up.

To check that the Mac really is being held awake while the app is open:

```bash
pmset -g assertions
```

Look for `StayAwake` listed under the owning process.

## Running agents overnight

StayAwake solves one problem, and it is the easy one. The thing that actually kills long-running jobs is the **process dying**, which sleep prevention cannot help with. A closed terminal, a dropped SSH session, or a logout will end an agent mid-task.

Run agents in a detached session so they survive that:

```bash
screen -S agents     # start a named session
# run your agent inside it
# detach with Ctrl-A, then D

screen -r agents     # reattach later
```

`screen` ships with macOS. `tmux` does not.

For a full overnight setup, use all three:

1. StayAwake on, with **Launch at Login** enabled, and **Allow Screen to Sleep** on if you do not want a bright screen all night
2. Agents running in `screen`
3. `autorestartatconnect 1`, plus a UPS

### Power outages

This is the part that catches people out. If the power goes out, your Mac will **not** come back by itself unless this is on:

```bash
sudo pmset autorestartatconnect 1
```

Check your current setting with `pmset -g | grep autorestart`. If it is `0`, nothing comes back after an outage and any overnight job stays dead until someone presses the power button.

The UPS is the highest value piece. Without one, a brief flicker can still kill a run, and a UPS also lets macOS ride out short dips without shutting down at all.

## How it works

Two power assertions, held by the app process:

- `kIOPMAssertionTypePreventUserIdleSystemSleep` keeps the machine running.
- `kIOPMAssertionTypePreventUserIdleDisplaySleep` keeps the screen lit.

They are the same API that `caffeinate` and the Linux stay-awake tools use. That means:

- **No `sudo`.** Nothing is written to System Settings, and no permanent setting is changed.
- **It cannot leave your Mac stuck awake.** The assertion belongs to the app process. Quit StayAwake, force quit it, or let it crash, and macOS drops the assertion and resumes normal sleep. There is no stale setting to clean up later.
- **Screen lock is unaffected.** It only controls *idle* sleep, so your login and password behave normally.

If you would rather use a command line tool, `caffeinate -dimsu` does the same job:

- `-d` display, `-i` idle, `-m` disk, `-s` system sleep on AC power, `-u` declares the user active.

## Verify it works

`Tools/verify.swift` checks the mechanism on your machine. It takes an assertion, confirms macOS reports it by name, releases it, and confirms it is gone:

```bash
swiftc -O -o verify Tools/verify.swift && ./verify
```

Expected output ends with:

```
RESULT: PASS - mechanism works
```

## Development

```bash
git clone https://github.com/Kamal-Nayan-Kumar/stayawake.git
cd stayawake
./test.sh
```

`./test.sh` builds the app, checks the bundle it produced, verifies that macOS accepts and releases the assertion, then launches the app and checks that it really holds the assertion and gives it up when it quits.

Layout:

```
Sources/
  StayAwakeApp.swift   the app and its menu bar scene
  PowerKeeper.swift    the power assertions
  LaunchAtLogin.swift  the login item
  MenuBarContent.swift the menu
  Settings.swift       the state the app remembers
Tools/
  make-icon.swift      draws the app icon
  verify.swift         checks the assertion mechanism
build.sh               builds StayAwake.app
test.sh                builds and checks everything
```

The app icon is drawn in code rather than checked in as binary art, so it stays reviewable in a diff:

```bash
swift Tools/make-icon.swift
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the ground rules. They are short: no dependencies, no network access, no `sudo`.

## Troubleshooting

**The menu bar icon is not there.** Open Applications › StayAwake to launch it. It has no window and no dock icon, so it can look like it did not start. Check with `pgrep -fl StayAwake`.

**macOS says the app is damaged.** It is not notarized. Right-click it in Applications and choose **Open** once.

**Launch at Login does nothing.** macOS may be blocking it. Look under System Settings › General › Login Items. If it is listed there but disabled, turn it on. If it is not there at all, move StayAwake to Applications and toggle it again.

**A red line in the menu.** The app could not take the power assertion. Check Privacy & Security permissions.

**The Mac still sleeps.** Check that Stay Awake is on and that the line under the toggles says the Mac is awake. Then run `pmset -g assertions` and look for StayAwake. If it is not listed, the app could not take the assertion and the menu will be showing you why.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT. See [LICENSE](LICENSE).
