# Contributing

Thanks for taking a look. StayAwake is deliberately small, and the bar for a
change is that it makes the app more useful without making it heavier.

## Getting set up

You need the Xcode Command Line Tools:

```bash
xcode-select --install
```

Then:

```bash
git clone https://github.com/Kamal-Nayan-Kumar/stayawake.git
cd stayawake
./test.sh
```

`./test.sh` builds the app, checks the bundle it produced, and verifies that
macOS accepts and releases the power assertion on your machine.

Open the project in Xcode with `open Package.swift` if you prefer a GUI. The
app itself is assembled by `./build.sh`, which wraps the compiled binary in a
bundle with `Info.plist` and the app icon.

## Ground rules

- **No dependencies.** StayAwake has none and should keep it that way. A tool
  people install to keep their machine awake should not need a package
  manager.
- **No network access.** The app talks to nothing.
- **No `sudo`, ever.** The power assertion belongs to the app process, so
  quitting the app always puts the Mac back to normal sleep. Do not add code
  that writes permanent power settings.
- **Keep the macOS deployment target at 13.0** unless there is a good reason
  to move it, and say so in a pull request if you do.

## Changing the icon

The icon is drawn in code, not checked in as binary art:

```bash
swift Tools/make-icon.swift
```

This regenerates `Resources/AppIcon.iconset` and repacks it into
`Resources/AppIcon.icns`. Commit the `.icns`, leave the `.iconset` out.

## Pull requests

Keep them to one thing. Say what changed and why. If you changed how the
power assertion behaves, say what you verified.
