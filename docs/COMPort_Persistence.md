Question: from a useability standpoint and related to persisting the COM port for a serial device, is it recommended to persist the name of the COM port even though it may not be there when the program starts up again (someone may unplug a particular USB cable)? This is a balance between showing COM ports that are not defined versus letting the user chnage to a COM port that is enumerated

Answer provided by Perplexity


Yes—**persist the user’s last choice**, but do not pretend the port is currently available. The best UX is to remember the last selected device/port, show it as the preferred or last-used choice even when absent, and clearly distinguish that from the list of ports currently enumerated. Microsoft also notes that relying only on legacy COM names is fragile because COM names can collide and do not provide state-change notifications, which is one reason to combine persistence with live enumeration and device-change handling. [learn.microsoft](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/guid-devinterface-comport)

## Recommended behavior

Persist the last-used selection, but store more than just `COM5` when possible: keep `PortName`, `FriendlyName`, `InstanceID`, `HardwareID`, and optionally `DevicePath`. `SetupDiGetDeviceInterfaceDetail` returns a device path that Microsoft says can be reused across system starts, but for user-facing persistence the most practical key is usually a combination of hardware identity plus the last-known COM name, because the COM number can change when users move adapters or Windows reassigns ports. [learn.microsoft](https://learn.microsoft.com/en-us/windows/win32/api/setupapi/nf-setupapi-setupdigetdeviceinterfacedetaila)

A good startup rule is:
- If the remembered device is present, preselect it.
- If it is absent, show it as “Last used: COM5 — not currently connected”.
- Also show the currently available ports as normal selectable entries. [learn.microsoft](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/guid-devinterface-comport)

## What to persist

Persisting only the COM port name is acceptable for simple apps, but it is not the strongest identifier because `COM5` is really a current assignment, not a device identity. The more robust choice is to persist a small record such as `LastPortName`, `LastFriendlyName`, `LastInstanceID`, and `LastHardwareID`, then match in that order when the app starts again. [stackoverflow](https://stackoverflow.com/questions/304986/how-do-i-get-the-friendly-name-of-a-com-port-in-windows)

A practical matching strategy is:

1. Match by `InstanceID` if present.
2. Else match by `HardwareID` plus friendly-name pattern.
3. Else match by exact `PortName`.
4. Else keep the saved item as remembered-but-offline. [learn.microsoft](https://learn.microsoft.com/en-us/windows/win32/api/setupapi/nf-setupapi-setupdigetdeviceregistrypropertya)

## UI pattern

From a usability standpoint, a combo box that mixes missing and present ports without labeling is confusing. A better pattern is either a combo box with one disabled “last used but unavailable” entry at the top, or a small status line above the combo box that says “Last used device is not connected; choose another port.” [learn.microsoft](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/guid-devinterface-comport)

Example display:

| State    | What user sees                                                           |
| -------- | ------------------------------------------------------------------------ |
| Saved    | `COM5 — USB Serial Device (last used)`                                   |
| devic    | [                                                                        |
|          | stackoverflow](https://stackoverflow.com/questions/304986/how-do-i-get-t |
|          | he                                                                       |
| e is     | -friendly-name-of-a-com-port-in-windows)                                 |
| present  |                                                                          |
| Saved    | `Last used: COM5 — USB Serial Device (not connected)`                    |
| devic    | [                                                                        |
|          | learn.microsoft](https://learn.microsoft.com/en-us/windows-hardware/dri  |
|          | ver                                                                      |
| e is     | s/install/guid-devinterface-comport)                                     |
| absent   |                                                                          |
| Other    | `COM3 — Silicon Labs CP210x...` , `COM7 — USB Serial Device...`          |
| ports    | [                                                                        |
|          | stackoverflow](https://stackoverflow.com/questions/304986/how-do-i-get-t |
|          | he                                                                       |
| are      | -friendly-name-of-a-com-port-in-windows)                                 |
| present  |                                                                          |

That keeps the user oriented without lying about what is actually openable right now. Using `WM_DEVICECHANGE` to refresh the list also helps the UI recover naturally when the cable is plugged back in. [learn.microsoft](https://learn.microsoft.com/en-us/windows/win32/devio/dbt-devicearrival)

## Practical advice

Do not auto-open a missing remembered port at startup; instead, remember it and defer action until the user clicks Connect or until the exact device reappears. If your users often work with one known adapter, a checkbox like “Reconnect automatically when this device reappears” is useful, especially because Windows can notify you when a COM-port interface arrives. [learn.microsoft](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerdevicenotificationa)

For ham-radio or instrument-control style software, the best compromise is usually:
- Persist the last-used device.
- Show unavailable remembered ports separately from live ports.
- Prefer matching by device identity, not only COM number.
- Let the user override to any currently enumerated port. [learn.microsoft](https://learn.microsoft.com/en-us/windows/win32/api/setupapi/nf-setupapi-setupdigetdeviceinterfacedetaila)

Would you like a Delphi pattern for this, such as a `TRememberedComPort` record plus matching code for your enumerator class?