# Connect WSJT-X

WSJT-X performs the digital-mode work. TR4W receives its UDP messages to support contest logging and callsign highlighting.

You can set up WSJT-X in **Tools → Setup Wizard**. The page offers the enable switch, UDP port, callsign highlighting, radio control, and the advanced multicast group. The wizard saves only changed settings, and a Tools-menu run tells you when a restart is needed.

## Match the UDP connection

1. Open a practice contest in TR4W.
2. In TR4W's settings, confirm **WSJT-X ENABLED** is true and note **WSJT-X BROADCAST PORT**. Its source default is `2237`.
3. In WSJT-X's **Settings → Reporting**, configure its UDP server destination and port to match your setup. On one computer with ordinary unicast, the destination is the local computer, typically `127.0.0.1`; leave TR4W's multicast group empty.
4. For a shared multicast setup, use the same multicast group and port in both applications and select the appropriate outgoing interface in WSJT-X. The wiki illustrates `224.0.0.1`.
5. Enable **Accept UDP requests** in WSJT-X if you want to receive TR4W's highlighting requests. Enable **WSJT-X SEND HIGHLIGHTS** in TR4W.

## Verify both directions

Confirm that decoded calls receive the expected highlighting. Then, when you complete and confirm a QSO in WSJT-X, check that it appears once in TR4W with the expected call, band, mode, and exchange.

TR4W can fill a missing state from the received grid when the lookup gives a unique answer. If the grid spans more than one state, it shows the candidates for you to check. Live WSJT-X records use the open TR4W contest.

| If you see this | Check this |
| --- | --- |
| No received activity | Matching port, destination/group, selected network interface, and local firewall rules. |
| Contacts arrive but no highlights | Accept UDP requests in WSJT-X and Send Highlights in TR4W. |
| Duplicate logged contacts | Whether both WSJT-X and another forwarding application are sending the same QSO to TR4W. |

## Radio control is a separate connection

First verify [TR4W's radio connection](radio.md). To let WSJT-X use that radio, enable **WSJT-X RADIO CONTROL ENABLED** in Preferences or the wizard, restart if prompted, and select **DX Lab Suite Commander** as the rig in WSJT-X. Point it at TR4W's Commander-compatible TCP service, default port `52002`. Test frequency and mode changes with the intended rig. The UDP logging port is separate.

## Receive N1MM-style log messages

For a program configured to send N1MM Logger+ Log messages, enable **ENABLE N1MM LOG LISTENER** in TR4W Preferences. It is off by default. TR4W listens on UDP `2333` and TCP `52001`. **N1MM LISTEN ADDRESS** defaults to `127.0.0.1`, for senders on the same computer. To receive from another computer, set the listener to this station's LAN address and allow only trusted senders to reach it. Both settings apply when saved. Any sender that can reach the listener can add records to the open contest log.

Choose one forwarding path per sender. A resent contact can be logged and flagged as a dupe. This listener receives contact records and does not provide WSJT-X highlighting or CAT control.

[WSJT-X setting names and defaults](../reference/wsjtx.md)

The [full command reference](../reference/commands/t-z.md#wsjt-x-enabled) includes scope, value constraints, and source initial values. [TCI connections](tci.md) explains the separate radio-control path; [external loggers](external-loggers.md) explains forwarding contacts beyond TR4W.

??? info "Evidence and review status"
    Adapted from the [WSJT-X integration wiki page](https://github.com/TR4W/TR4W/wiki/WSJT-X-Integration), with setting names and defaults checked against `uSettingsModel.pas`. UDP and highlighting behavior still need an operator test with the intended WSJT-X version. The wiki's older instruction to edit `tr4w.ini` has deliberately not been carried forward.
