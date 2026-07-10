# Manual Verification

## Automated baseline

- App target builds with `MACOSX_DEPLOYMENT_TARGET=13.0`.
- The complete Swift Testing suite passes on macOS.
- The asset catalog compiles all app-icon sizes and the template status icon without warnings.
- The app target is menu-bar-only through `LSUIElement` and uses the system light or dark appearance.
- Hardened Runtime is enabled. App Sandbox remains disabled because the current core behavior invokes privileged `/usr/bin/pmset disablesleep`; sandbox runtime validation must exercise that path before the setting can change.

## Panel interaction checklist

Run these checks from an installed, signed build:

- [ ] The menu-bar item is announced as `Walakage` and uses the coffee template icon.
- [ ] Controls appear in order: `Keep Awake`, timer, `Keep Display Awake`, Battery Mac controls, `Launch at Login`, `Quit Walakage`.
- [ ] VoiceOver reads visible control labels and the shared `Status` value.
- [ ] Countdown text is readable but is not announced automatically each minute.
- [ ] Tab moves through native controls and Space changes the focused toggle.
- [ ] Timer hours and minutes commit on Enter or focus loss, clamp to 24 hours, and do not commit on each keystroke.
- [ ] Battery Protection Threshold commits on Enter or focus loss and clamps to 5% through 80%.
- [ ] Closing the panel leaves an Awake Session, deadline, and shared message intact.
- [ ] `Quit Walakage` is separated, text-only, and immediately releases sleep prevention.
- [ ] Light and dark appearances remain legible without a custom theme.

## Hardware and distribution checks

- [ ] Disconnecting power with `Only While Charging` enabled stops the run with `Power disconnected.`.
- [ ] Discharging at or below the threshold stops the run with `Battery low.`.
- [ ] Enabling and disabling `Launch at Login` from an installed signed app updates Login Items and never starts `Keep Awake`.
- [ ] A Developer ID Application identity signs the Release app and DMG.
- [ ] `notarytool` accepts the DMG, `stapler` validates it, and Gatekeeper assesses the app successfully.

The current development Mac has no Developer ID Application identity or notarization credentials, so signed/notarized DMG verification is pending those release credentials.
