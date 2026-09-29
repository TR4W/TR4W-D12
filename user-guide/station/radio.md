# Connect a radio

Check the [radio support table](../reference/radios.md) for the driver's registered serial/network connections, discovery support, and setup defaults. For a TCI connection, also read [TCI connections](tci.md).

Open the radio configuration dialog for the radio you want to configure. Confirm **Name** and **Radio type** before entering connection details. Exact menu navigation still needs a walkthrough in the preview build.

=== "Serial CAT"

    1. Select the appropriate **Radio type** and open **Serial**.
    2. Choose the **Port** used by your radio's CAT interface.
    3. Match **Baud rate**, **Data bits**, **Parity**, and **Stop bits** to the radio's CAT settings.
    4. Set **CAT RTS** and **CAT DTR** according to the interface requirements.
    5. For an Icom radio, verify **CI-V address (hex)** against the radio's configuration.

=== "Network CAT"

    1. Select the appropriate **Radio type** and open **Network**.
    2. Enter **IP address** and **IP port** for the radio's control service.
    3. If discovery is available for that model, use **Discover** and select the radio in **Found**.
    4. Supply **User name** and **Password** if required by the radio's network service.
    5. Check the radio's own network-control configuration if the connection fails.

Choose **Save and close** to keep the configuration, or **Cancel** to discard the dialog changes.

## Verify the connection

Tune the radio and check that TR4W follows its frequency. Then check a mode change. If either fails, confirm the selected model and transport settings before investigating other integrations.

| Symptom | First checks |
| --- | --- |
| Serial radio does not respond | Correct CAT port, matching serial parameters, and whether another application owns the port. |
| Network radio does not respond | Radio address, control-service port, credentials where required, and network reachability. |
| Discovery finds nothing | Discovery support for this model and whether the radio is reachable on the local network; try its known address. |
| Frequency works but CW does not | Keying configuration. CAT frequency control and CW output are separate checks. |

The form has separate **Keyer output port**, **Keyer RTS line**, and **Keyer DTR line** controls. Configure these for your keying interface; do not assume the CAT connection selects a keying method automatically.

??? info "Source check"
    Control names: `tr4w/src/ui/lcl/uRadioEditForm.lfm`. This page documents the configuration surface; it does not certify a particular radio/OS combination. The older [TCP/IP wiki guide](https://github.com/TR4W/TR4W/wiki/Connecting-TR4W-to-Radios-via-TCP-IP) has additional model context.
## Reset Radio Ports

Use **Reset Radio Ports** when CAT frequency/mode updates have stopped after a USB interruption, a radio restart, or a lost network connection and the connection has not recovered. First check the radio power, cable or network, and configured device/address. A reset cannot fix a wrong serial device, baud rate, network address, or credentials.

Stop transmitting before resetting. The action reinitializes **both the active and inactive radio interfaces**: it stops old polling, disconnects, frees and recreates the radio objects, and reconnects using their configuration. It is not limited to serial ports despite its name.

Afterward, turn each radio's tuning knob and check that its panel follows; verify band, mode, and CW/PTT operation before resuming. If it still fails, inspect the [diagnostic log](../log/diagnostics.md) rather than repeatedly resetting. This action does not restore a log, reset the contest, or replace the separate WinKey configuration/reopen action.

Source: `MainUnit.ResetRadioPorts` calls `CheckAndInitializePorts_ForThisRadio` for both radios; `SetUpRadioInterface` owns interface teardown and recreation.
