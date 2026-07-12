# Build Walakage MVP

## Problem Statement

Mac users need a tiny native way to keep their Mac awake during long-running work without unnecessarily keeping the display awake. Existing approaches are either too technical, too heavy, or too blunt: they often keep the screen on, require Terminal commands, expose too many settings, or do not behave clearly around battery, charging, and closed-lid external-display workflows.

Walakage should solve this as a small macOS menu-bar utility. The user should be able to turn `Keep Awake` ON, trust that the Mac stays awake even if the lid is closed, and still let the display sleep by default.

## Solution

Build a native macOS menu-bar-only app with a simple coffee status icon and one primary `Keep Awake` toggle.

When `Keep Awake` is ON, Walakage starts an Awake Session: lid sleep is prevented, the display is allowed to sleep by default, and the run continues until manual OFF, timer end, or a Protective Stop. `Keep Display Awake` is an optional setting that also prevents display sleep.

The app stays safe by default. Battery protection stops an Awake Session while discharging at or below the configured Battery Protection Threshold. `Only While Charging` stops an Awake Session when external power is disconnected. `Keep Awake` means preventing lid sleep; Clamshell Pause is superseded by ADR-0002.

The MVP ships as a signed and notarized DMG outside the Mac App Store, with no helper daemon, no Dock icon, no notifications, no analytics, no update checker, and no automation surfaces.

## User Stories

1. As a MacBook user, I want to turn `Keep Awake` ON from the menu bar, so that my Mac does not sleep during long work.
2. As a MacBook user, I want the display to be allowed to sleep by default, so that I do not waste screen power.
3. As a developer, I want my Mac to stay awake during builds, so that a long build does not stop midway.
4. As a user downloading files, I want my Mac to stay awake during downloads, so that transfers can finish unattended.
5. As a user uploading files, I want my Mac to stay awake during uploads, so that uploads do not fail because the Mac slept.
6. As a student, I want one obvious ON/OFF control, so that I do not need to understand macOS power settings.
7. As a designer, I want a native-feeling menu-bar app, so that it feels lightweight and unobtrusive.
8. As a user, I want no Dock icon, so that Walakage stays out of my app switcher and Dock.
9. As a user, I want a simple outline coffee cup menu-bar icon, so that the app is easy to recognize.
10. As a user, I want the coffee icon dimmed when inactive, so that I can see the state without opening the panel.
11. As a user, I want the same coffee concept for the app bundle icon, so that the app identity is consistent.
12. As a user, I want `Keep Display Awake` as an optional toggle, so that I can keep the screen on only when needed.
13. As a user, I want `Keep Display Awake` visible while inactive, so that I can configure the next Awake Session before starting it.
14. As a presenter, I want to keep the display awake, so that the screen does not sleep during presentation-like work.
15. As a user, I want a timer, so that `Keep Awake` can stop automatically.
16. As a user, I want timer quick choices of `15m`, `30m`, `1h`, `2h`, and `4h`, so that common durations are fast to pick.
17. As a user, I want an explicit timer `Off` option, so that I can run untimed.
18. As a user, I want custom timer hours and minutes, so that I can choose a duration not in the quick choices.
19. As a user, I want custom timer input capped at 24 hours, so that stale multi-day runs are avoided.
20. As a user, I want invalid timer input clamped instead of erroring, so that the UI stays low-friction.
21. As a user, I want timer changes during an Awake Session to restart the countdown, so that the new value starts from now.
22. As a user, I want selecting timer `Off` while active to keep `Keep Awake` ON, so that removing the timer does not stop the run.
23. As a user, I want countdown text only while active and timed, so that inactive UI stays quiet.
24. As a user, I want countdown text like `1h 05m left` or `12m left`, so that remaining time is readable.
25. As a user, I want the countdown display rounded up while expiration remains exact, so that the UI does not show `0m left` before stopping.
26. As a user, I want timer behavior to use wall-clock deadlines, so that sleep/wake does not stretch a timer.
27. As a user, I want the countdown UI to update only while the panel is open, so that hidden UI does not waste work.
28. As a user, I want closing the panel to leave sleep prevention and timer expiration active, so that the menu panel is not required to stay open.
29. As a Battery Mac user, I want battery protection, so that Walakage does not drain my Mac too far.
30. As a Battery Mac user, I want the Battery Protection Threshold to default to 20%, so that the app is safe by default.
31. As a Battery Mac user, I want the Battery Protection Threshold configurable from 5% to 80%, so that I can choose my own safety level.
32. As a desktop Mac user, I do not want battery controls, so that irrelevant controls are hidden.
33. As a Battery Mac user, I want `Only While Charging`, so that `Keep Awake` stops when power is unplugged.
34. As a Battery Mac user, I want `Only While Charging` hidden on non-battery Macs, so that the UI does not show meaningless controls.
35. As a user, I want `Power disconnected.` to win when `Only While Charging` is enabled, so that the explicit charging rule is clear.
36. As a user, I want `Battery low.` only while discharging at or below threshold, so that plugging in removes that blocker.
37. As a user, I want clearing a blocking condition not to auto-start `Keep Awake`, so that the app does not act without a fresh user command.
38. As a user, I want Protective Stops to turn `Keep Awake` OFF, so that battery and charging safety end the run.
39. As a MacBook user, I want closing the lid not to sleep the Mac while `Keep Awake` is ON, so that long-running work continues.
40. As a user, I want the first `Keep Awake` ON action to request any needed administrator approval, so that setup happens only when I use the core feature.
46. As a user, I want `Time up.` when a timer stops an Awake Session, so that I know why it ended.
47. As a user, I want `Battery low.` when battery protection blocks or stops a run, so that I know why it ended.
48. As a user, I want `Power disconnected.` when `Only While Charging` blocks or stops a run, so that I know why it ended.
49. As a user, I want `Unable to keep awake.` if macOS refuses sleep prevention, so that the UI does not lie about being active.
50. As a user, I want one shared message area, so that stop and failure messages do not clutter the panel.
51. As a user, I want the message area hidden when empty, so that the panel stays compact.
52. As a user, I want messages to clear when I start `Keep Awake`, turn it OFF, or change settings, so that old messages do not linger after acknowledgement.
53. As a user, I want blocking messages to clear when the blocking condition is fixed, so that stale blockers disappear.
54. As a user, I want stop/failure messages not to clear just because the panel closes or time passes, so that I can reopen the panel and see what happened.
60. As a user, I want Quit to release sleep prevention immediately, so that quitting stops Walakage completely.
61. As a user, I want dismissing the panel to leave Walakage running, so that closing UI does not stop `Keep Awake`.
62. As a user, I want Quit separated at the bottom, so that I do not hit it accidentally.
63. As a user, I want Quit text-only and not alarming red, so that the panel stays calm.
64. As a user, I do not want confirmation before Quit, so that utility actions stay fast.
65. As a user, I do not want confirmation before turning `Keep Awake` OFF, so that the toggle is instant.
66. As a user, I want settings remembered across app restarts, so that I do not reconfigure basics every launch.
67. As a user, I want active runs not to resume after restart, so that Walakage does not silently keep the Mac awake.
68. As a user, I want no run history, so that the utility stays local and simple.
69. As a privacy-conscious user, I want no analytics or usage tracking, so that the app does not collect my behavior.
70. As a privacy-conscious user, I want no internet access required, so that Walakage works fully locally.
71. As a user, I want no notifications in MVP, so that the app does not ask for notification permission or annoy me.
72. As a user, I want no sound effects, so that the utility stays quiet.
73. As a user, I want no About screen or footer in MVP, so that the panel stays minimal.
74. As a user, I want system light/dark appearance automatically, so that Walakage matches macOS.
75. As a user, I want English-only UI in MVP, so that wording can settle before localization.
76. As a VoiceOver user, I want the status item labeled `Walakage`, so that I can identify the menu-bar item.
77. As a VoiceOver user, I want interactive controls labeled with their visible copy, so that controls are understandable.
78. As a VoiceOver user, I want the shared message exposed as status text, so that I can hear stop or pause reasons.
79. As a VoiceOver user, I want countdown text accessible but not announced every minute, so that updates are not noisy.
80. As a keyboard user, I want native Tab and Space behavior, so that I can use the panel without custom shortcuts.
81. As a user installing the app, I want a signed and notarized DMG, so that macOS can verify it.
82. As a user installing the app, I want a drag-to-Applications DMG, so that installation is simple.
83. As a user, I do not want the app to auto-start after installation, so that I choose when to run it.
84. As a maintainer, I want no Sparkle or update checker in MVP, so that the release process stays small.
85. As a maintainer, I want no helper daemon or background service, so that there is only one process to build and debug.
86. As a maintainer, I want native logging with no custom log files, so that diagnostics use platform tools.
87. As a maintainer, I want a small testable core model, so that sleep/timer decisions can be verified without UI automation.

## Implementation Decisions

- Build a native Swift and SwiftUI macOS app targeting macOS 13 Ventura or newer.
- Use a menu-bar-only app shape with SwiftUI `MenuBarExtra` and no Dock icon.
- Use a small SwiftUI popover-style panel rather than a plain menu list.
- Use one primary `Keep Awake` toggle at the top of the panel.
- Use `Awake Session` as the domain concept for the current active run where Walakage prevents lid sleep until a stop condition happens.
- Use `Keep Awake` as the user-facing control copy for starting and ending an Awake Session.
- Use `Keep Display Awake` as an Awake Session setting, not a separate session type.
- Let `Keep Display Awake` remain visible and editable while inactive.
- Start lid-sleep prevention on the first `Keep Awake` ON action.
- Request administrator approval on first use if lid-sleep prevention requires it.
- Restore normal lid sleep when `Keep Awake` turns OFF or Walakage quits.
- Treat IOPM assertions as internal support only; do not model a separate normal Keep Awake mode.
- If lid-sleep prevention fails, restore anything already changed, return `Keep Awake` to OFF, and show `Unable to keep awake.`
- Ignore restore failures in UI and log them during development.
- Use native `Logger` from Apple's `os` framework.
- Do not write custom log files and do not build a log viewer.
- Store Session Defaults in `UserDefaults`.
- Remember timer duration/source, Battery Protection Threshold, and `Only While Charging`.
- Keep `Keep Display Awake` session-local and default it to OFF on every launch.
- Do not silently resume an Awake Session after app restart.
- After quit and reopen, show inactive with saved settings and no old countdown.
- Do not store run history or persist the last stop reason across restart.
- Use a segmented timer control with `Off`, `15m`, `30m`, `1h`, `2h`, and `4h`.
- Support a custom timer using typed hours and minutes fields.
- Allow custom timer hours from `0` to `24` and minutes from `0` to `59`; total duration cannot exceed 24 hours.
- Clamp invalid timer input on blur instead of showing an error.
- Commit typed fields after valid/clamped blur or Enter, not on every keystroke.
- Clicking a quick timer choice replaces the custom timer and restarts the countdown if active.
- Editing the custom timer switches the timer source to custom and restarts the countdown if active.
- Selecting timer `Off` while active removes the countdown and keeps `Keep Awake` ON.
- Use a one-shot deadline timer for exact timer expiration.
- Use wall-clock deadlines for timer behavior.
- Refresh countdown UI once per minute only while the panel is open.
- Show countdown as `1h 05m left` for one hour or more and `12m left` under one hour.
- Round countdown display up to the next minute while keeping exact expiration.
- Use Battery Mac as the domain concept for a Mac with an internal battery.
- Show battery protection and `Only While Charging` controls only on Battery Macs.
- Ignore `Only While Charging` on non-battery Macs even if a saved setting exists.
- Use a numeric percentage field only for Battery Protection Threshold.
- Default Battery Protection Threshold to 20%.
- Clamp Battery Protection Threshold to 5% through 80% on blur.
- Treat Protective Stops as run-ending conditions that turn `Keep Awake` OFF.
- Give `Power disconnected.` priority when `Only While Charging` is enabled; otherwise use `Battery low.` if battery protection applies.
- Check blocking stop conditions before starting `Keep Awake`; refuse to start instead of flickering ON then OFF.
- Do not auto-start `Keep Awake` when a blocking condition clears.
- Use native macOS power-source change notifications and wake notifications; do not use a polling loop.
- Re-check stop conditions immediately when the Mac wakes.
- Use one shared message area for stop and failure messages.
- Hide the shared message area when empty.
- Clear transient messages when the user starts `Keep Awake`, manually turns it OFF, or changes any setting.
- Do not clear transient messages just because the panel closes or time passes.
- Clear blocking messages when their blocking condition is no longer true.
- Use these exact messages: `Time up.`, `Battery low.`, `Power disconnected.`, `Unable to keep awake.`, and `Administrator approval failed.`
- Keep UI copy non-technical; do not show terms like `assertion`, `IOKit`, `pmset`, or `clamshell state`.
- Use a compact vertical panel layout: primary toggle, timer controls, `Keep Display Awake`, battery controls, then Quit.
- Place `Quit Walakage` at the bottom, separated from settings.
- Style Quit as text-only, not as a red destructive button.
- Use a static monochrome template menu-bar icon with opacity dimming for inactive state.
- Create original icon assets from one vector source; reference images guide style only.
- Put app icon sizes in the Xcode asset catalog.
- Use a separate monochrome template PDF/vector status icon in the asset catalog.
- Set the status item accessibility label to `Walakage`.
- Enable App Sandbox unless native API testing proves it cannot work.
- Ship first as a signed and notarized DMG outside the Mac App Store.
- Make the DMG contain only the app bundle; no installer package.
- Do not auto-start after installation.
- Use a plain Xcode SwiftUI app project with one app target for MVP.
- Do not split into Swift packages until needed.
- Start implementation with the app shell and core model.
- Add DMG/notarization scripts after manual run verification.
- Defer CI setup until the app builds locally.

## Testing Decisions

- Test external behavior at the highest practical seam: a small core decision model/controller that owns Awake Session state transitions, timer deadlines, stop-condition priority, lid-sleep prevention, and settings bounds.
- Keep SwiftUI thin enough that most product behavior can be tested without UI automation.
- Use tiny test seams only where needed for power state, timer/deadline behavior, lid-sleep prevention, and display-awake assertions.
- Avoid a broad abstraction layer; fake only the platform behaviors needed to test decisions.
- Add focused unit tests for timer math:
  - quick durations map to correct deadlines
  - custom hours/minutes clamp correctly
  - zero duration means timer off
  - timer display rounds up while expiration stays exact
  - changing timer during an active Awake Session restarts the countdown
  - selecting timer `Off` keeps `Keep Awake` ON
- Add focused unit tests for stop condition priority:
  - `Power disconnected.` wins when `Only While Charging` is enabled
  - `Battery low.` applies while discharging at or below threshold
  - plugging in clears the battery blocker
  - clearing a blocker does not auto-start `Keep Awake`
  - Protective Stops turn `Keep Awake` OFF
- Add focused unit tests for lid-sleep prevention:
  - first `Keep Awake` ON starts lid-sleep prevention
  - OFF restores normal lid sleep
  - Quit restores normal lid sleep
  - failed start leaves `Keep Awake` OFF
- Add focused unit tests for settings bounds:
  - Battery Protection Threshold clamps to 5% through 80%
  - custom timer clamps to 24 hours max
  - typed fields commit on blur or Enter, not every keystroke
- Add focused tests for sleep-prevention behavior:
  - lid-sleep prevention starts for `Keep Awake`
  - display-awake assertion is added only when requested
  - partial display-assertion failure restores lid sleep and returns OFF
  - quit restores lid sleep and releases active assertions
- Add focused tests for transient message behavior:
  - stop/failure messages persist while the app stays open
  - messages clear on start, manual OFF, or setting changes
  - administrator-approval failure uses the specific shared message
- Add accessibility verification for the panel:
  - status item has `Walakage` label
  - interactive controls expose labels matching visible copy
  - shared message area is exposed as status text
  - countdown is accessible text and not auto-announced every minute
  - native keyboard navigation works before adding custom focus handling
- Keep one focused Swift Testing target alongside the app; avoid UI-test machinery unless native interaction testing finds a real gap.

## Out of Scope

- Dock icon
- Main dashboard or main window
- Notifications
- Global keyboard shortcuts
- AppleScript support
- Shortcuts app actions
- CLI automation
- Helper daemon or background service
- Named presets
- Custom reason labels
- Clamshell settings toggle
- Analytics or usage tracking
- Internet access requirement
- Update checker
- Sparkle or any auto-update framework
- About screen
- App/version footer
- Crash reporting
- Custom icon themes or color themes
- Sound effects
- Quit confirmation
- `Keep Awake` OFF confirmation
- Launch at Login
- Mac App Store release for MVP
- Installer package
- Auto-start after installation
- CI before local build works
- DMG/notarization scripts before manual run verification
- Swift Package split before the one-target app needs it

## Further Notes

- The domain glossary is single-context and defines Awake Session, Keep Awake, Keep Display Awake, Protective Stop, Battery Protection Threshold, Only While Charging, Battery Mac, Session Defaults, Session Timer, and Session State.
- ADR 0002 records the decision that `Keep Awake` means preventing lid sleep. ADR 0001 is superseded.
- The issue should be ready for an implementation agent to start with the app shell and core model before packaging work.
