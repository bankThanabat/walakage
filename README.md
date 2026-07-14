# Walakage

Walakage is a small, native macOS menu-bar utility that keeps your Mac awake during long-running work, including when a MacBook lid is closed. The display is still allowed to sleep unless you explicitly enable **Keep Display Awake**.

## Current features

- Menu-bar-only app with no Dock icon
- One-click **Keep Awake** control
- Optional **Keep Display Awake** control
- Restores normal lid-sleep behavior when the session ends or the app quits
- Reuses administrator approval for the lifetime of the app
- Fully local operation with no accounts, analytics, or network access

The broader MVP—including timers, battery protection, charging rules, launch at login, and release packaging—is described in [PRD.md](PRD.md).

## Requirements

- macOS
- Xcode with the macOS SDK required by the project
- An administrator account, because changing lid-sleep behavior requires macOS approval

## Build and run

1. Open `walakage.xcodeproj` in Xcode.
2. Select the `walakage` scheme and **My Mac** as the destination.
3. Run the app with **Product > Run** (`⌘R`).
4. Find the coffee-cup icon in the menu bar.

You can also build from Terminal:

```sh
xcodebuild build \
  -project walakage.xcodeproj \
  -scheme walakage \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

## Usage

Open the coffee-cup menu-bar item and turn on **Keep Awake**. On first use, Walakage explains why approval is needed before macOS asks for an administrator password.

- **Keep Awake** prevents system and lid sleep.
- **Keep Display Awake** additionally prevents the display from sleeping.
- Turning **Keep Awake** off restores normal lid-sleep behavior.
- **Quit Walakage** ends the active session before closing the app.

Use the app's Quit command before force-quitting or terminating the process so it can restore the changed power setting cleanly.

## Tests

Run the test suite with:

```sh
xcodebuild test \
  -project walakage.xcodeproj \
  -scheme walakage \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

## Project layout

- `walakage/` — SwiftUI app and sleep-prevention implementation
- `walakageTests/` — controller and power-management tests
- `PRD.md` — product requirements and planned MVP behavior
- `CONTEXT.md` — shared product terminology
- `docs/adr/` — architectural decisions

## License

Walakage is available under the [MIT License](LICENSE).
