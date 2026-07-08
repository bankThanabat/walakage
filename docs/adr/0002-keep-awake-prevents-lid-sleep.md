# Keep Awake prevents lid sleep

Walakage's core product behavior is that the first `Keep Awake` ON action prevents lid sleep, including closed-lid MacBook behavior. We will not model `Keep Awake` as a normal IOPM idle-sleep assertion with a Clamshell Pause fallback; any IOPM assertion is only an internal supporting detail, not a separate product mode.

## Consequences

- `Keep Awake` ON must start lid-sleep prevention immediately.
- OFF and Quit must restore normal lid sleep.
- If lid-sleep prevention needs administrator approval, that approval is requested on first toggle ON.
