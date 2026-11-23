# What's new in TR4W 5.1.0

TR4W 5.1.0 adds new contests and rover tools, gives you more control over the operating window, and makes logging and multi-op reconnects more reliable. [See what changed since TR4W 4.x](features-since-4.md).

!!! warning "Before you upgrade"
    Multi-op stations need 5.1.0 clients and a protocol 5 server. Keep the old server log and the log from each station. TR4W also verifies a backup before upgrading an older 5.x contest database. [Multi-op upgrade](station/network.md) · [Contest log upgrade](start/migration.md#upgrade-an-existing-5x-database)

## Keep logging when a save fails

TR4W keeps unsaved entries on screen so you can retry. If the disk fills, free space and press **Enter**. Automatic backups run in the background. Use **Tools → Correct Station Facts** to fix a sent value, such as your zone, across eligible contacts. [Backups](log/backup.md) · [Log recovery and corrections](log/restore.md)

## See the exchange, spots, and multipliers

Resize the main window in both directions. The sent exchange appears above the call field. The remaining-multiplier windows distinguish worked multipliers from those that still need a backup contact and show repeat counts. The band map follows the radio's band and mode and has its own text size and colors. [Window appearance](operating/appearance.md) · [Multiplier windows](operating/multipliers.md) · [Band map](operating/bandmap.md)

Send a self-spot from **Control → Self-spot** or enable automatic self-spotting where the contest allows it. For supported contests, TR4W can also use a section or state in a spot comment to mark a needed multiplier. [Self-spotting](operating/dxcluster.md#self-spot-from-the-run-frequency) · [Spot-comment setting](reference/commands/a-d.md#cluster-spot-comment-multiplier)

## Run commands and program messages

Open **Tools → Commands** for actions you can also type in the call field. Function-key messages use braces for commands, including rover details and another station's frequency. Use a leading `$` inside the braces to direct a radio command to the inactive radio. [Call-window commands](operating/keyboard.md#run-a-call-window-command) · [Function-key messages](station/cw-messages.md#message-commands)

## Work the new contests and rover locations

5.1.0 adds the **Russian WW Digital Contest** (`RUS-WW-DIGI`) and the **Weekly RTTY Test** (`WRT`). It also updates Winter Field Day for 2027, RU3AX Memorial, and many QSO parties. Use **ROVER** to select operating locations and log contacts from a county line together. [Contest updates](operating/contests.md) · [Rover operation](operating/contests.md#operate-as-a-rover)

## Connect radios, stations, and loggers

Use the native FLRig driver, improved Flex reconnection, optional N1MM-style contact input, and FT2 support. Multi-op stations catch up on missing contacts after reconnecting. External loggers can resend QSOs, and you can create a World Radio League logbook from its logger row. [Radio setup](station/radio.md#network-radios-and-software-interfaces) · [N1MM-style input](station/wsjtx.md#receive-n1mm-style-log-messages) · [Multi-op catch-up](station/network.md#catch-up-after-a-disconnect) · [External loggers](station/external-loggers.md)

## Refresh data and set up your station

TRMASTER and call history reload without restarting. More contests have downloadable call history. [Update reference data](start/data-updates.md)

On Windows, Program Files installations keep writable files under `%APPDATA%\TR4W`, and the Start menu links to the release notes. More controls have tooltips, the main callsign field in Preferences works with screen readers, and additional help translations are available as drafts. [File locations](start/files.md) · [Language and translations](station/language.md)
