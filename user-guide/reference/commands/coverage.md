# Reference coverage and review

Generated counts describe extraction coverage, not completed operator validation.

| Measure | Count |
| --- | --- |
| settings | 288 |
| accepted setting names | 298 |
| retired | 88 |
| store owned | 39 |
| actions | 4 |
| old manual names | 335 |
| editorially reviewed | 12 |
| literal initial values | 256 |
| missing descriptions | 27 |
| unclassified old names | 21 |

## Source precedence

1. Current settings inventory, checked against the frozen command vocabulary, supplies names, aliases, scopes, and types.
2. Current model declarations verify every inventory property/type and supply literal initial values and numeric subranges.
3. Current uCFG dispatch lists distinguish withdrawn names, store-owned names, and actions.
4. Reviewed editorial descriptions override inherited English help. Unreviewed help stays visibly labeled.
5. The old manual supplies historical names and the migration lookup; its extracted PDF layout is too inconsistent to safely promote whole definition blocks automatically.

The older CTRLJ_INVENTORY, CFG_COMMAND_TABLE, and HELP_TEXT_GAPS documents explain the migration but contain historical counts and architecture. They are not the current command list.

## Missing explanations

- [ALERT COLOR](a-d.md#alert-color)
- [AUTO-CQ DELAY TIME](a-d.md#auto-cq-delay-time)
- [CALL WINDOW SHOW ALL SPOTS](a-d.md#call-window-show-all-spots)
- [COUNTRY INFORMATION FILE](a-d.md#country-information-file)
- [CW SPEED INCREMENT](a-d.md#cw-speed-increment)
- [DISPLAY LANGUAGE](a-d.md#display-language)
- [DVK PATH](a-d.md#dvk-path)
- [DVK RECORDER](a-d.md#dvk-recorder)
- [HAND LOG MODE](e-l.md#hand-log-mode)
- [INCLUDE F-KEY NUMBER](e-l.md#include-f-key-number)
- [MAIN CALLSIGN](m-p.md#main-callsign)
- [MISSINGCALLSIGNS FILE ENABLE](m-p.md#missingcallsigns-file-enable)
- [MMTTY ENGINE](m-p.md#mmtty-engine)
- [NET STATUS UPDATE INTERVAL](m-p.md#net-status-update-interval)
- [NO BORDER](m-p.md#no-border)
- [NO COLUMN HEADER](m-p.md#no-column-header)
- [OPERATING STANDARD EDIT KEYS](m-p.md#operating-standard-edit-keys)
- [QSO POINT METHOD](q-s.md#qso-point-method)
- [QZB RANDOM OFFSET ENABLE](q-s.md#qzb-random-offset-enable)
- [RADIO TCP SERVER PORT](q-s.md#radio-tcp-server-port)
- [SHOW ALL SERIAL PORTS](q-s.md#show-all-serial-ports)
- [SHOW DOMESTIC MULTIPLIER NAME](q-s.md#show-domestic-multiplier-name)
- [SHOW GRIDLINES](q-s.md#show-gridlines)
- [STATIONS CALLSIGNS MASK](q-s.md#stations-callsigns-mask)
- [TELNET CONSOLE LINES](t-z.md#telnet-console-lines)
- [TUNE WITH DITS](t-z.md#tune-with-dits)
- [USE RECORDED SIGNS](t-z.md#use-recorded-signs)

## Reproduce

Run `python tools/build_command_reference.py`, then `python -m mkdocs build --strict`. The generator reads only this worktree and refuses to publish when the inventory differs from the frozen settings vocabulary. It does not execute the application or prove end-to-end behavior.

Source revision: `24f06a30081b607dbca5020fe583d97944be97d8`. Reviewed prose is maintained in `tools/command_reference_notes.json`; generated pages should not be edited directly.

Historical manual credit: TR4W Reference Manual v4.01, Tod Olson, K0TO. Inherited English help retains its provenance in the project help catalogue.
