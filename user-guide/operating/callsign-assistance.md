# Possible calls and Super Check Partial

Call assistance offers candidates when you copy an incomplete or uncertain callsign. It does not establish what the station actually sent. Confirm the call on the air before logging it.

The older manual distinguishes three related tools:

| Tool | Purpose and data |
| --- | --- |
| Partial calls | Matches partial input against calls available from the contest's dupe/initial-exchange information. `PARTIAL CALL ENABLE` controls this feature; `WILDCARD PARTIALS` controls whether the fragment must start the call. |
| Possible calls | Suggests similar calls. `POSSIBLE CALLS` enables the candidate strip; `POSSIBLE CALL MODE` controls the candidate source/filter. |
| Super Check Partial (SCP) | Searches the master callsign data for a fragment. `SCP MINIMUM LETTERS` controls automatic activation; `SCP COUNTRY STRING` restricts the countries included. |

Open preferences with **Ctrl+J** and search for those command names. Use the [current command reference](../reference/commands/index.md) for their current storage and accepted settings. In particular, do not assume the old manual's `NAMES` default is the current default: the current settings constructor selects **ALL**.

## Use the possible-call strip

Enter the call or uncertain fragment. **Ctrl+P** requests possible-call processing (and the associated short-path rotor action if configured). With the default keys, **comma** selects left, **period** selects right, and **semicolon** copies the selected call into the callsign entry field. The three keys are configurable. Selection alone does not log a contact.

The current strip uses bold selection and red/white dupe cells rather than relying on the old manual's angle-bracket cursor illustration. It clears when there are no candidates, so a previous result should not be mistaken for the current search.

## Maintain the master data

Use [Download TRMASTER.DTA](../start/data-updates.md) and restart as described there. SCP needs the master data available at the current [data-file location](../start/files.md). An empty result can mean no match, a country filter, a minimum-character threshold, or missing master data; it does not prove the callsign is invalid.

??? info "Source check"
    Earlier reference manual and wiki configuration statements for partial/possible calls and SCP. Current: `trdos/logedit.pas` (`DoPossibleCalls`, `SuperCheckPartial`), `trdos/logscp.pas`, `uSettingsModel`, and `MainUnit` candidate-key handlers. The current default keys are `,`, `.`, and `;`.
