# Reference coverage and review

Generated counts describe extraction coverage, not completed operator validation.

| Measure | Count |
| --- | --- |
| settings | 310 |
| accepted setting names | 321 |
| retired | 111 |
| store owned | 40 |
| actions | 4 |
| old manual names | 335 |
| editorially reviewed | 20 |
| literal initial values | 272 |
| missing descriptions | 0 |
| unclassified old names | 11 |

## Source precedence

1. Current settings inventory, checked against the frozen command vocabulary, supplies names, aliases, scopes, and types.
2. Current model declarations verify every inventory property/type and supply literal initial values and numeric subranges.
3. Current uCFG dispatch lists distinguish withdrawn names, store-owned names, and actions.
4. Reviewed descriptions override the English settings help in `i18n/help_en.po`. Historical INI defaults appear separately.
5. The old manual supplies historical names and the migration lookup; its extracted PDF layout is too inconsistent to safely promote whole definition blocks automatically.

The older CTRLJ_INVENTORY, CFG_COMMAND_TABLE, and HELP_TEXT_GAPS documents explain the migration but contain historical counts and architecture. They are not the current command list.

## Missing explanations

Every setting has an English help entry or a reviewed description.

## Reproduce

Run `python tools/build_command_reference.py`, then `python -m mkdocs build --strict`. The generator reads only this worktree and refuses to publish when the inventory differs from the frozen settings vocabulary. It does not execute the application or prove end-to-end behavior.

Source revision: `4a0707be141d12c48327358c23deeddd2f0af0b7`. Reviewed prose is maintained in `tools/command_reference_notes.json`; generated pages should not be edited directly.

Historical manual credit: TR4W Reference Manual v4.01, Tod Olson, K0TO. Inherited English help retains its provenance in the project help catalogue.
