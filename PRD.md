# Walakage PRD

## Product Summary

Walakage is a native macOS menu-bar utility that keeps a Mac awake during long-running tasks while allowing the display to sleep by default.

The app should feel small, clean, and native: one main toggle, clear status, minimal settings, no dashboard.

## Product Goal

Help users keep their Mac awake for downloads, uploads, builds, servers, transfers, presentations, and external-display workflows without forcing the screen to stay on unnecessarily.

## Primary Users

- MacBook users
- Developers
- Designers
- Students
- People running downloads or uploads
- People using external monitors
- People who leave long tasks running

## Product Principles

- Safe by default
- Native-feeling
- Tiny and fast
- Clear about what it is doing
- Not overly technical

## Core Behavior

When `Keep Awake` is ON:

- The Mac stays awake.
- The display is allowed to sleep by default.
- The run continues until manual OFF, timer end, or a protective stop.

When `Keep Display Awake` is ON:

- The Mac stays awake.
- The display also stays awake.

When `Keep Display Awake` changes during an active run, Walakage releases and recreates the native sleep-prevention request.

Protective stops win over the timer and manual ON intent:

- Battery protection stops the run while discharging at or below the configured threshold.
- `Only While Charging` stops the run when external power is disconnected.
- Protective stops turn `Keep Awake` OFF; only clamshell behavior pauses an active run.
- Clearing a blocking condition does not auto-start `Keep Awake`.

## MVP Scope

- Menu-bar-only app with a small SwiftUI popover-style panel
- No Dock icon
- Main toggle copy: `Keep Awake` ON/OFF
- Menu-bar icon: simple outline coffee cup with steam, dimmed when inactive
- Menu-bar icon uses template rendering, has no animation, and inactive state uses opacity dimming rather than a separate asset
- App bundle icon: same outline coffee cup concept, adapted for app icon sizes
- Icon assets are original, generated from one vector source; reference images guide style only
- App icon sizes live in the Xcode asset catalog
- Menu-bar status icon is a separate monochrome template PDF/vector asset in the asset catalog
- Status item accessibility label: `Walakage`
- No custom icon themes or color themes in MVP
- Optional `Keep Display Awake` toggle, visible even when inactive
- Optional timer with `Off`, quick durations (`15m`, `30m`, `1h`, `2h`, `4h`), and custom hours/minutes up to 24 hours
- Countdown shown only while active and timer is set
- Countdown format: `1h 05m left` for one hour or more, `12m left` under one hour
- Countdown rounds up to the next minute for display, but expiration uses the exact wall-clock deadline
- Countdown UI updates once per minute
- Active timer uses a one-shot deadline timer for exact expiration
- Countdown UI refresh runs only while the panel is open
- Closing the panel does not affect sleep prevention or timer expiration
- Battery protection on Battery Macs only
- Battery threshold defaults to 20%, configurable from 5% to 80%
- `Only While Charging` on Battery Macs only
- Binary active/inactive status, with one shared message area for stop, pause, or failure messages when relevant
- Shared message area is hidden when empty.
- Current pause message overrides old stop or failure messages while paused, and clears when pause ends.
- UI does not show raw technical terms like `assertion`, `IOKit`, or `clamshell state`
- Timer stop reason copy: `Time up.`
- Battery stop reason copy: `Battery low.`
- Charging stop reason copy: `Power disconnected.`
- Sleep-prevention failure copy: `Unable to keep awake.`
- Stop reason priority: `Power disconnected.` wins when `Only While Charging` is enabled; otherwise `Battery low.` applies.
- Login item failure copy: `Unable to launch at login.`
- If any requested sleep-prevention assertion fails, Walakage releases already-created assertions, returns `Keep Awake` to OFF, and shows `Unable to keep awake.`
- Assertion release failures are ignored in UI and only logged during development.
- Transient messages clear when the user starts `Keep Awake`, manually turns it OFF, or changes any setting.
- Transient messages do not clear just because the panel closes or time passes.
- Blocking messages such as `Battery low.` or `Power disconnected.` clear when the blocking condition is no longer true.
- `Battery low.` clears when the Mac is plugged in, and returns if unplugged below the threshold.
- Launch at login opens Walakage only; it does not start Keep Awake
- `Launch at Login` changes apply immediately to macOS login items.
- If changing `Launch at Login` fails, the toggle reverts to the actual registered state and shows `Unable to launch at login.`
- Quit releases any active sleep prevention immediately
- Closing or dismissing the menu leaves Walakage running
- No notifications in MVP
- No global keyboard shortcuts in MVP
- No AppleScript, Shortcuts app actions, or CLI automation in MVP
- No helper daemon or background service in MVP
- No named presets in MVP
- No custom reason labels in MVP
- No clamshell settings toggle in MVP
- No analytics or usage tracking in MVP
- No internet access required
- No update checker in MVP
- No Sparkle or auto-update framework in MVP
- No About screen in MVP
- No app/version footer in MVP
- No crash reporting in MVP
- Keyboard navigation and VoiceOver labels included from the first build
- Interactive controls have explicit VoiceOver labels matching visible copy
- Shared message area is exposed as VoiceOver status text
- Countdown is accessible as normal text but is not announced automatically every minute
- Keyboard navigation relies on native control behavior; no custom shortcuts or focus management unless testing finds a gap
- English-only UI in MVP
- Uses system light/dark appearance automatically
- No sound effects in MVP
- No confirmation before Quit
- No confirmation before turning `Keep Awake` OFF
- No administrator permissions required
- App Sandbox enabled unless native API testing proves it cannot work
- First distribution target is a signed and notarized `.dmg`, outside the Mac App Store
- DMG contains the app bundle only; no installer package
- App does not auto-start after installation

## Panel Layout

- Compact vertical stack
- Primary `Keep Awake` toggle at the top
- Timer controls below the primary toggle
- Timer quick choices use a segmented control: `Off`, `15m`, `30m`, `1h`, `2h`, `4h`
- Custom timer uses typed hours and minutes fields; hours allow `0` to `24`, minutes allow `0` to `59`, and total duration cannot exceed 24 hours
- Invalid timer input is clamped on blur instead of showing an error
- Clicking a quick timer choice replaces the custom timer and restarts the countdown if active
- Editing the custom timer switches the timer source to custom and restarts the countdown if active
- Selecting `Off` while active removes the countdown and keeps `Keep Awake` ON
- `Keep Display Awake` below timer controls
- Battery controls below timer and display controls, only on Battery Macs
- Battery threshold uses a numeric percentage field only
- Invalid battery threshold input is clamped to `5%` to `80%` on blur
- Toggles update immediately with no Apply or Save button
- Typed fields save after valid/clamped blur or Enter, not on every keystroke
- `Launch at Login` near the bottom above Quit
- `Quit Walakage` at the bottom, separated from settings
- Quit is text-only, not styled as a red destructive button

## Clamshell Behavior

Walakage does not fight macOS clamshell behavior.

When macOS enters closed-lid external-display behavior, Walakage pauses its sleep-prevention behavior while keeping the user intent active. The menu-bar icon still appears active, and the opened menu can show `Paused for clamshell.` When the Mac leaves clamshell behavior, Walakage resumes applying the active run.

Walakage detects clamshell pause with IOKit: `AppleClamshellState == true` and `AppleClamshellCausesSleep == false`. CoreGraphics display topology is not the main product rule.

If Walakage cannot read IOKit clamshell state, it assumes not paused and continues applying sleep prevention.

Settings remain editable during clamshell pause. Changes apply when pause ends; Walakage does not create sleep-prevention assertions while paused.

Timers and protective stops still apply during clamshell pause. If they end the run, `Paused for clamshell.` is replaced by the stop reason.

## Settings Persistence

Walakage stores settings in `UserDefaults`.

Walakage remembers the last settings for:

- `Keep Display Awake`
- Timer duration
- Battery threshold
- `Only While Charging`

Walakage does not silently resume an active run after restart.

After quit and reopen, Walakage shows inactive with saved settings, not an old countdown.

Walakage does not store run history or persist the last stop reason across restart.

## Tech Stack

- Swift
- SwiftUI
- Minimum macOS 13 Ventura
- SwiftUI `MenuBarExtra`
- Native macOS sleep-prevention APIs
- `IOPMAssertionCreateWithName` for sleep prevention
- Assertion name: `Walakage Keep Awake`
- System-awake assertion type: `kIOPMAssertionTypeNoIdleSleep`
- Display-awake assertion type: `kIOPMAssertionTypeNoDisplaySleep`, added only when `Keep Display Awake` is ON
- Native macOS login item APIs
- Native macOS power-source change notifications
- Native macOS wake notifications
- Native IOKit clamshell state
- Native `Logger` from Apple's `os` framework
- No custom log files or log viewer

## Project Shape

- Plain Xcode SwiftUI app project
- One app target for MVP
- No Swift Package split until needed
- Focused unit tests for timer math, stop condition priority, and settings bounds
- Core sleep/timer decision logic isolated from SwiftUI enough to unit test
- Tiny test seams for power state, timer, and sleep-prevention behavior only where needed
- Implementation starts with app shell and core model
- DMG/notarization scripts come after manual run verification
- CI setup waits until the app builds locally
