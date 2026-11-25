# WSJT-X settings

The 5.1.0 settings model registers these names. Use the [setup guide](../station/wsjtx.md) to connect the programs.

| Setting | Purpose |
| --- | --- |
| `WSJT-X ENABLED` | Enable the WSJT-X listener. |
| `WSJT-X BROADCAST PORT` | UDP port on which TR4W receives messages; must match the sending application. |
| `WSJT-X MULTICAST GROUP` | Multicast group to join; an empty value selects ordinary unicast. |
| `WSJT-X SEND HIGHLIGHTS` | Send callsign highlight information back to WSJT-X. |
| `WSJT-X RADIO CONTROL ENABLED` | Allow frequency changes from WSJT-X to move the radio. |

Every WSJT-X option is off by default: the listener, callsign highlights and radio control. The port defaults to `2237`. A settings file that already states a value keeps it. The port type restricts values to `1–65535`.

The separate [N1MM-style log listener](../station/wsjtx.md#receive-n1mm-style-log-messages) uses `ENABLE N1MM LOG LISTENER` and `N1MM LISTEN ADDRESS`. Its default is off, with a loopback address of `127.0.0.1`.

!!! note "Names, not a file-editing recipe"
    This table documents supported command names. It does not imply that a particular settings file uses this text as its on-disk format. Use the settings UI for the current build.

Source: `tr4w/src/uSettingsModel.pas`, class `TWsjtxSettings` and the five `Alias('WSJT-X ...')` registrations. Source snapshot and review limits are recorded in [Evidence and review](../about/sources.md).
