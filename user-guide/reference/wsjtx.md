# WSJT-X settings

These names are explicitly registered as aliases in the 5.0.22 settings model. Use the [setup guide](../station/wsjtx.md) to connect the programs.

| Setting | Purpose |
| --- | --- |
| `WSJT-X ENABLED` | Enable the WSJT-X listener. |
| `WSJT-X BROADCAST PORT` | UDP port on which TR4W receives messages; must match the sending application. |
| `WSJT-X MULTICAST GROUP` | Multicast group to join; an empty value selects ordinary unicast. |
| `WSJT-X SEND HIGHLIGHTS` | Send callsign highlight information back to WSJT-X. |
| `WSJT-X RADIO CONTROL ENABLED` | Allow frequency changes from WSJT-X to move the radio. |

The model documents an enabled listener and port `2237` as defaults. The port type restricts values to `1–65535`.

!!! note "Names, not a file-editing recipe"
    This table documents supported command names. It does not imply that a particular settings file uses this text as its on-disk format. Use the settings UI for the current build.

Source: `tr4w/src/uSettingsModel.pas`, class `TWsjtxSettings` and the five `Alias('WSJT-X ...')` registrations. Source snapshot and review limits are recorded in [Evidence and review](../about/sources.md).
