# Changelog

All notable changes to StayAwake are recorded here.

## 1.1.0

### Added

- Menu state is remembered across restarts. Quit the app, reboot, or crash, and
  it comes back the way you left it. This is the difference between "my agent
  kept running overnight" and "my agent died when the app restarted".
- An app icon, drawn from code in `Tools/make-icon.swift` so it stays
  reviewable in a diff.
- `Package.swift`, so the project opens in Xcode and builds with `swift build`.
- `./test.sh`, which builds the app, checks the bundle, and verifies that macOS
  really accepts and releases the power assertion.
- Continuous integration on every push, and prebuilt zips for Apple Silicon
  and Intel attached to each tagged release.

### Changed

- The menu bar icon now says what the Mac is doing: a sleeping moon when it
  sleeps, a sun when everything is held on, a coffee cup when the Mac is
  running but the screen is free to rest.
- Login item failures now say what to do about them instead of surfacing an
  opaque macOS error.
- A failed display assertion no longer gets overwritten by a successful system
  assertion, so the error you see is the real one.

### Fixed

- The app no longer loses the "Allow Screen to Sleep" choice when the main
  toggle is flipped off and on again.

## 1.0.0

- First release. A menu bar toggle that keeps the Mac awake, with an optional
  display assertion and a launch at login option.
