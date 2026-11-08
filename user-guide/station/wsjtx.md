# Connect WSJT-X

WSJT-X performs the digital-mode work. TR4W receives its UDP messages to support contest logging and callsign highlighting.

## Match the UDP connection

1. Open a practice contest in TR4W.
2. In TR4W's settings, confirm **WSJT-X ENABLED** is true and note **WSJT-X BROADCAST PORT**. Its source default is `2237`.
3. In WSJT-X's **Settings → Reporting**, configure its UDP server destination and port to match your setup. On one computer with ordinary unicast, the destination is the local computer, typically `127.0.0.1`; leave TR4W's multicast group empty.
4. For a shared multicast setup, use the same multicast group and port in both applications and select the appropriate outgoing interface in WSJT-X. The wiki illustrates `224.0.0.1`.
5. Enable **Accept UDP requests** in WSJT-X if you want to receive TR4W's highlighting requests. Enable **WSJT-X SEND HIGHLIGHTS** in TR4W.

## Verify both directions

Confirm that decoded calls receive the expected highlighting. Then, when you complete and confirm a QSO in WSJT-X, check that it appears once in TR4W with the expected call, band, mode, and exchange.

| If you see this | Check this |
| --- | --- |
| No received activity | Matching port, destination/group, selected network interface, and local firewall rules. |
| Contacts arrive but no highlights | Accept UDP requests in WSJT-X and Send Highlights in TR4W. |
| Duplicate logged contacts | Whether both WSJT-X and another forwarding application are sending the same QSO to TR4W. |

## Radio control is a separate connection

Receiving a QSO over UDP does not establish CAT control. First verify [TR4W's radio connection](radio.md). The wiki also describes using TR4W's DXLab Commander-compatible TCP server from WSJT-X; a current 5.x end-to-end setup for that path is outside this prototype.

[WSJT-X setting names and defaults](../reference/wsjtx.md)

The [full command reference](../reference/commands/t-z.md#wsjt-x-enabled) includes scope, value constraints, and source initial values. [TCI connections](tci.md) explains the separate radio-control path; [external loggers](external-loggers.md) explains forwarding contacts beyond TR4W.

??? info "Evidence and review status"
    Adapted from the [WSJT-X integration wiki page](https://github.com/TR4W/TR4W/wiki/WSJT-X-Integration), with setting names and defaults checked against `uSettingsModel.pas`. UDP and highlighting behavior still need an operator test with the intended WSJT-X version. The wiki's older instruction to edit `tr4w.ini` has deliberately not been carried forward.
