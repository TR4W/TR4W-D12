# Program CW function keys

TR4W retains the manual's separate message banks for running and search-and-pounce operation. The same function key can send a different message in each operating context.

1. Select CW and open **Tools → Program message**.
2. Choose **C** for a CQ function key, **E** for an exchange/search-and-pounce function key, or **O** for other messages.
3. Select the message to edit. Enter the transmitted content in **Message** and a useful button description in **Caption**.
4. Use **List of commands** to insert a supported command rather than guessing its spelling or control-character encoding.
5. Choose **OK** to apply the message. Test the key in the intended CQ or exchange context with the correct radio and [CW sending backend](cw.md). Function-key memories are captured in the contest database when the log closes; exit normally and reopen the practice log to check persistence. Do not edit the `.db` as though it were an old `.cfg` text file.

## Start with simple messages

| Message text | Meaning |
| --- | --- |
| `CQ TEST \ \` | CQ followed by your configured callsign twice. |
| `@ 5NN #` | The entered callsign, a CW signal report, and the serial number selected by TR4W's serial-number logic. Use only for a contest whose exchange fits. |
| `TU \` | Thanks followed by your own callsign. |

`\` expands your configured callsign; `@` expands the call being worked; `#` uses the serial-number logic, including configured leading zeros and abbreviated digits. These are executable message characters, so punctuation is not necessarily transmitted literally. A fixed-zone or section contest needs its actual exchange instead of the serial-number example.

Test each bank separately, including the exchange sent by the normal Enter workflow. **Esc** stops CW/automatic-CQ activity through the active sending path. Check the selected radio before testing a message that changes radio focus.

The old SO2R tips include messages that send on the inactive radio or swap focus. Those actions can change which radio supplies the band and mode for the contact being entered. Introduce them only after the basic [SO2R workflow](so2r.md) works, and insert the commands from the current command list.

??? info "Source check"
    Earlier wiki SO2R tips and reference manual message concepts. Current chooser/editor: `uProgramMessageForm`, `uEditMessageForm` (`SaveToConfig`), and `uMessagesListForm`; expansions: `trdos/logsend.pas`; stopping: `MainUnit.Escape_proc`. These examples have been checked against code, not transmitted on a radio.
