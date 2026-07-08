---
status: superseded by ADR-0002
---

# Detect clamshell pause from IOKit power state

Walakage detects Clamshell Pause with IOKit root-domain clamshell state: `AppleClamshellState == true` and `AppleClamshellCausesSleep == false`. We chose this over CoreGraphics display-topology inference because it matches the actual closed-lid power behavior Walakage must respect, while display lists only show which displays are online and can mislead future code into managing hardware behavior instead of observing macOS.
