# Connect a DX cluster

The cluster console shows the node's messages and lets you send commands. Parsed DX spots feed the [band map](bandmap.md), where contest and display rules determine what you see.

## Connect and check reception

1. Open the **Telnet** window from the Windows menu.
2. Use **Configure...** to review the cluster connection, then select the intended node.
3. Choose **Connect** and follow any login prompts from that node.
4. Confirm that node messages arrive. Use the command-entry field and **Send** for a command appropriate to the node.
5. Compare a received spot with the band map. If the console receives it but the map does not show it, review the map filters and spot age.

The form also provides **Disconnect**, **Freeze**, **Clear**, **Commands**, and **SH/50**. Command support and response syntax depend on the cluster node; a button's presence does not make every server understand that command.

## Freeze, clear, and history

**Freeze** lets you hold the console view for reading; it is not the Disconnect command. **Clear** concerns console content, not the contest's QSO database. Use the controls for their displayed purpose rather than using console visibility as a connection-status test.

The current code separates the visible console-line budget from the session trace. [TELNET CONSOLE LINES](../reference/commands/t-z.md#telnet-console-lines) bounds the displayed history; it is not a promise that the session archive is limited to the same number of lines.

## Troubleshooting

| Symptom | First check |
| --- | --- |
| No connection | Selected host/port, reachability, and the node's availability. |
| Connected but no useful spots | Login, node-side filters, and the node's supported commands. |
| Console has spots but the map appears empty | Band, mode, mult-only, dupe, and age filters. |
| Old console lines are no longer visible | Console-line budget; consult the session trace when diagnosing history. |

A spot is information from another source. It can contain an incorrect call, stale frequency, or misleading comment. Verify it while operating.

??? info "Evidence and review status"
    UI: `ui/lcl/uTelnetForm.lfm` and `.pas`. Transport: `uDXClusterClient.pas`. Spot ingestion: `uTelnet.pas`, `uDXSpotParse.pas`, and `uSpots.pas`. Session logging: `uTelnetTrace.pas`. This page has not connected to a live cluster for validation.
