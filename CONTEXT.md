# Walakage

Walakage is a macOS menu-bar utility for controlling whether the Mac may sleep during long-running work.

## Language

**Awake Session**:
A period where Walakage prevents system sleep until a stop condition happens.
_Avoid_: Mode, wake state

**Keep Awake**:
The user-facing control for starting or ending an Awake Session.
_Avoid_: Start session, enable mode

**Keep Display Awake**:
An Awake Session setting that also prevents the display from sleeping.
_Avoid_: Display mode, screen session

**Protective Stop**:
A stop condition that ends an Awake Session to protect battery life or honor the charging requirement.
_Avoid_: Safety override, forced off

**Battery Protection Threshold**:
The configurable battery percentage at or below which Walakage ends an Awake Session while the Mac is discharging. It defaults to 20% and can be set from 5% to 80%.
_Avoid_: Low battery mode, battery saver

**Only While Charging**:
An Awake Session setting that requires external power and ends the session when external power is disconnected.
_Avoid_: Charging mode, plugged-in mode

**Battery Mac**:
A Mac with an internal battery. Battery protection and charging-only controls are only shown on Battery Macs.
_Avoid_: Laptop mode, mobile Mac

**Session Defaults**:
The remembered settings used when starting a new Awake Session.
_Avoid_: Saved session, profile

**Session Timer**:
An optional countdown after which an Awake Session ends. It can be chosen from quick durations or set as custom hours and minutes up to 24 hours, but it is not a calendar schedule. Changing it during an Awake Session starts a new countdown; zero means no timer.
_Avoid_: Schedule, alarm

**Session State**:
Whether Walakage currently has an active Awake Session. The menu-bar icon is always a coffee icon and is dimmed when inactive.
_Avoid_: Detailed mode, status level

**Clamshell Pause**:
A temporary suspension of sleep prevention while macOS handles closed-lid external-display behavior. The Awake Session remains active and the menu can show that Walakage is paused for clamshell.
_Avoid_: Stale session, clamshell mode
