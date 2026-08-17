# Ctrl-J inventory — every remaining row, and the panel it goes on

**Generated 2026-08-16** from `uCFG.pas`, with NY4I's panel assignments applied.
The working list for **deprecating Ctrl-J**.

**173 live rows** are visible in Ctrl-J today (`crS` not in `[csRem, csOwned, csJSON]`,
`uOption.pas:362`; 17 further rows are commented out in CFGCA and do not count).

## The rule

> "There is no difference between contest settings and general settings. Put all contest related
> settings into the contest panel. We will organise them as needed once the contest factory is
> done. But this will let me get the Ctrl-J thing deprecated." — NY4I, 2026-08-16

Every row gets a home **now**. Grouping inside the Contest panel is deliberately deferred.

## Three findings that shrink the work

**1. 59 of 173 rows are already READ-ONLY in Ctrl-J** — `crJ` of 2 or 3, in CFGCA's own
encoding (`0-edit, 1-edit+restart, 2-readonly, 3-message(ro)`). Ctrl-J *displays* them; it does not
edit them. So most of the Contest panel is a read-only reflection of what the contest set, not
editors to be designed.

**2. The 21 `crJ: 3` rows already have an editor.** NY4I: *"they are referred to when we set
Ctrl-P, so these were in Ctrl-J redundantly."* CFGCA agrees in its own type comment — `3` means
literally `message(ro)`. The CQ/S&P/QSL/QSO-BEFORE message set is owned by the message editor, so
these need **no new UI at all**: mark them `csOwned` and they leave Ctrl-J. (The `crJ: 3` encoding
is verified; the exact keystroke is NY4I's, not something this pass confirmed.)

**3. `crA` marks commands.** It is CFGCA's "additional proc" — a row that *does something* when
written. Nine rows have one; where it pairs with read-only, the row is a command, not a setting:
`CONTEST` / `CONTEST NAME` switch the loaded contest, `DX MULTIPLIER` / `ZONE MULTIPLIER`
recompute multipliers.

### `CLEAR DUPE SHEET` must be a button, not a checkbox

`crA: 4`, `crJ: 2`, `crNetwork: 1`, and its global is literally `ClearDupeSheetCommandGiven`. The
help text is *"CLEARDUPESHEET to clear all dupesheets in network"*. A stored `TRUE` would re-clear
every dupe sheet in the network on every start — silent data loss dressed as a restored preference.
It goes on Operating as an action with a confirm, and is **never persisted**.

## Summary

| destination | rows |
| --- | ---: |
| Prefs -> Contest | 68 |
| Prefs -> Operating | 34 |
| Message editor owns it -- no new UI | 21 |
| Prefs -> Appearance | 14 |
| Prefs -> CW | 12 |
| Prefs -> Files/Updates | 7 |
| Prefs -> Band Map | 5 |
| Prefs -> Hardware | 5 |
| Prefs -> Network | 2 |
| Prefs -> Voice/DVK | 2 |
| Prefs -> Advanced | 2 |
| Prefs -> DX Cluster | 1 |
| **TOTAL** | **173** |

## Acceptance: every one of these must be FINDABLE in Preferences search

NY4I, 2026-08-16: *"Make sure I can search and find every one of these please."*

That is a hard requirement, and **it is not satisfied today** — not even for the settings already
migrated. `BuildSearchIndex` (`ui/lcl/uPrefsForm.pas:2199`) walks `FBindings` only, and says so in
its own comment: *"the hand-wired panels call ApplyAndStoreCommand directly and are invisible
here."* So `MY GRID` and `MY CALL` cannot be found by search right now.

Two things make the requirement true, and both are cheap because the machinery exists:

**1. Register every row.** A `RegisterStoredSetting` line sets `LegacyCommand`, and the index
already stores it beside the caption (`uPrefsForm.pas:2299`). The registry comment states exactly
why that matters:

> *"Every migrated setting is a row that LEFT Ctrl-J, where an operator could type this exact name
> to find it; dropping the name from the index would make the migration silently cost fifteen years
> of muscle memory."*

So an operator who types `QSO POINTS DX CW` still lands on it after Ctrl-J is gone. **Searchability
is the thing that makes deprecating Ctrl-J safe rather than merely tidy.**

**2. Extend `BuildSearchIndex` to cover the hand-wired panels.** Otherwise Station, SCP, backup,
band map, WSJT-X, external logger, MMTTY and cluster stay invisible — a search that covers part of
the settings is worse than none, because an empty result reads as "TR4W cannot do that" and the
operator stops looking. That sentence is already in `BuildSearchIndex`; it is time to act on it.

### The guard

A unit test that asserts **every command in this document resolves in the search index**. It needs
no UI: build the index, assert each legacy command is present and maps to a control on a panel.
Deterministic, and it fails the moment a row is migrated without being made findable — which is the
only way this requirement stays true after the migration stops being anyone's focus.

Pair it with the reverse: no indexed entry may name a command that no longer exists in `CFGCA`.

## Before any row is flipped

1. **The export rule.** A setting read by `PostUnit`, `uCbrSum`, `uADIF` or `uCabrillo*` may become
   `csOwned` but never `csJSON` — that is what `COMPUTER ID` broke, costing 2632 wrong QSO lines.
2. **Read the row's `crAddress`; never derive the global from the command name.** `HF BAND ENABLE`
   is `HFBandEnable` but `VHF BAND ENABLE` is `VHFBandsEnabled` — a name-derived sweep reported a
   false clean on 2026-08-16.

`net` is `crNetwork`; `1` propagates between multi-op positions. `ApplyPeerCommand` routes on the
row's own state, so there is no per-row work — but it is why a wrong flip is not local.

## Prefs -> Contest  (68)

| command | crS | type | net | nature |
| --- | --- | --- | ---: | --- |
| `AUTO QSL INTERVAL` | csOld | ctInteger | 1 | editable, runs proc 6 |
| `AUTO-CQ DELAY TIME` | csNew | ctInteger | 1 | editable |
| `BEEP EVERY 10 QSOS` | csOld | ctBoolean | 1 | editable |
| `CATEGORY-ASSISTED` | csNew | ctOther | 1 | editable |
| `CATEGORY-BAND` | csNew | ctOther | 1 | editable |
| `CATEGORY-MODE` | csNew | ctOther | 1 | editable |
| `CATEGORY-OPERATOR` | csNew | ctOther | 1 | editable |
| `CATEGORY-OVERLAY` | csNew | ctOther | 1 | editable |
| `CATEGORY-POWER` | csNew | ctOther | 1 | editable |
| `CATEGORY-TRANSMITTER` | csNew | ctOther | 1 | editable |
| `COLUMN DUPESHEET ENABLE` | csOld | ctBoolean | 1 | editable |
| `CONTEST` | csOld | ctOther | 1 | COMMAND (read-only + proc 1) |
| `CONTEST NAME` | csOld | ctString | 1 | COMMAND (read-only + proc 7) |
| `CONTEST TITLE` | csOld | ctString | 1 | read-only (contest sets it) |
| `COUNT DOMESTIC COUNTRIES` | csOld | ctBoolean | 1 | editable |
| `CUSTOM INITIAL EXCHANGE STRING` | csOld | ctString | 1 | editable |
| `DOMESTIC MULTIPLIER` | csOld | ctMultiplier | 1 | read-only (contest sets it) |
| `DX MULTIPLIER` | csOld | ctMultiplier | 1 | COMMAND (read-only + proc 20) |
| `EXCHANGE MEMORY ENABLE` | csOld | ctBoolean | 1 | editable |
| `EXCHANGE RECEIVED` | csOld | ctOther | 1 | read-only (contest sets it) |
| `GRID MAP CENTER` | csOld | ctString | 1 | editable |
| `INITIAL EXCHANGE` | csOld | ctOther | 1 | editable |
| `INITIAL EXCHANGE CURSOR POS` | csOld | ctOther | 1 | editable |
| `INITIAL EXCHANGE OVERWRITE` | csOld | ctBoolean | 1 | editable |
| `LITERAL DOMESTIC QTH` | csOld | ctBoolean | 1 | editable |
| `LOG RS SENT` | csOld | ctWord | 1 | editable |
| `LOG RST SENT` | csOld | ctWord | 1 | editable |
| `LOOK FOR RST SENT` | csOld | ctBoolean | 1 | editable |
| `MESSAGE ENABLE` | csOld | ctBoolean | 1 | editable |
| `MINITOUR DURATION` | csNew | ctInteger | 1 | read-only (contest sets it) |
| `MULT BY BAND` | csOld | ctBoolean | 1 | read-only (contest sets it) |
| `MULT BY MODE` | csOld | ctBoolean | 1 | read-only (contest sets it) |
| `MULT REPORT MINIMUM BANDS` | csOld | ctInteger | 1 | editable |
| `MULT SHEET AUTO RESET` | csNew | ctBoolean | 1 | read-only (contest sets it) |
| `MULTIPLE BANDS` | csOld | ctBoolean | 1 | editable |
| `MULTIPLE MODES` | csOld | ctBoolean | 1 | editable |
| `PREFIX MULTIPLIER` | csOld | ctMultiplier | 1 | read-only (contest sets it) |
| `QSL MODE` | csOld | ctOther | 1 | editable |
| `QSO BY BAND` | csOld | ctBoolean | 1 | read-only (contest sets it) |
| `QSO BY MODE` | csOld | ctBoolean | 1 | read-only (contest sets it) |
| `QSO NUMBER BY BAND` | csOld | ctBoolean | 1 | editable |
| `QSO POINT METHOD` | csOld | ctOther | 1 | read-only (contest sets it) |
| `QSO POINTS DOMESTIC CW` | csOld | ctInteger | 1 | read-only (contest sets it) |
| `QSO POINTS DOMESTIC PHONE` | csOld | ctInteger | 1 | read-only (contest sets it) |
| `QSO POINTS DX CW` | csOld | ctInteger | 1 | read-only (contest sets it) |
| `QSO POINTS DX PHONE` | csOld | ctInteger | 1 | read-only (contest sets it) |
| `QTC ENABLE` | csOld | ctBoolean | 1 | editable |
| `QTC EXTRA SPACE` | csOld | ctBoolean | 1 | editable |
| `QTC MINUTES` | csOld | ctBoolean | 1 | editable |
| `QTC QRS` | csOld | ctBoolean | 1 | editable |
| `QUICK QSL CW MESSAGE` | csOld | ctMessage | 1 | read-only (contest sets it) |
| `QUICK QSL CW MESSAGE1` | csOld | ctMessage | 1 | read-only (contest sets it) |
| `QUICK QSL KEY 1` | csOld | ctChar | 1 | editable |
| `QUICK QSL KEY 2` | csOld | ctChar | 1 | editable |
| `QUICK QSL MESSAGE 1` | csOld | ctMessage | 1 | read-only (contest sets it) |
| `QUICK QSL MESSAGE 2` | csOld | ctMessage | 1 | read-only (contest sets it) |
| `QUICK QSL SSB MESSAGE` | csOld | ctMessage | 1 | read-only (contest sets it) |
| `R150S MODE` | csNew | ctBoolean | 1 | read-only (contest sets it) |
| `RANDOM CQ MODE` | csOld | ctBoolean | 1 | editable |
| `REMAINING MULT DISPLAY MODE` | csOld | ctOther | 1 | editable |
| `REVERSE INITIAL EX` | csOld | ctBoolean | 1 | editable |
| `RFOBL MODE` | csNew | ctBoolean | 1 | read-only (contest sets it) |
| `SHOW ALL SERIAL PORTS` | csNew | ctBoolean | 1 | editable |
| `SHOW DOMESTIC MULTIPLIER NAME` | csNew | ctBoolean | 1 | editable |
| `SINGLE BAND SCORE` | csOld | ctBand | 1 | read-only (contest sets it) |
| `SPRINT QSY RULE` | csOld | ctBoolean | 1 | editable |
| `TEN MINUTE RULE` | csOld | ctOther | 1 | editable |
| `ZONE MULTIPLIER` | csOld | ctMultiplier | 0 | COMMAND (read-only + proc 2) |

## Prefs -> Operating  (34)

| command | crS | type | net | nature |
| --- | --- | --- | ---: | --- |
| `IE SWITCH` | csOld | ctBoolean | 1 | editable |
| `ASK FOR FREQUENCIES` | csOld | ctBoolean | 1 | editable |
| `AUTO DISPLAY DUPE QSO` | csOld | ctBoolean | 1 | editable |
| `AUTO DUPE ENABLE CQ` | csOld | ctBoolean | 1 | editable |
| `AUTO DUPE ENABLE S AND P` | csOld | ctBoolean | 1 | editable |
| `AUTO S&P ENABLE` | csOld | ctBoolean | 1 | editable |
| `AUTO S&P ENABLE SENSITIVITY` | csOld | ctInteger | 1 | editable |
| `AUTO TIME INCREMENT` | csOld | ctInteger | 1 | editable |
| `BAND` | csOld | ctBand | 1 | read-only (contest sets it) |
| `CLEAR DUPE SHEET` | csOld | ctBoolean | 1 | **COMMAND -- button, never persisted** |
| `CUSTOM USER STRING` | csOld | ctString | 1 | editable |
| `DE ENABLE` | csOld | ctBoolean | 1 | editable |
| `DIGITAL MODE ENABLE` | csOld | ctBoolean | 1 | editable |
| `DISTANCE MODE` | csOld | ctOther | 1 | editable |
| `DUPE CHECK SOUND` | csOld | ctOther | 1 | editable |
| `DUPE SHEET AUTO RESET` | csNew | ctBoolean | 1 | editable |
| `FREQUENCY MEMORY` | csOld | ctFreqList | 1 | editable, runs proc 18 |
| `FREQUENCY MEMORY ENABLE` | csOld | ctBoolean | 1 | editable |
| `FREQUENCY POLL RATE` | csOld | ctInteger | 1 | editable |
| `INCREMENT TIME ENABLE` | csOld | ctBoolean | 1 | editable |
| `LOG FREQUENCY ENABLE` | csOld | ctBoolean | 1 | editable |
| `LOG SUB TITLE` | csOld | ctString | 0 | editable |
| `MAIN CALLSIGN` | csNew | ctString | 1 | editable |
| `MODE` | csOld | ctOther | 1 | editable |
| `POSSIBLE CALL ACCEPT KEY` | csOld | ctChar | 1 | editable |
| `POSSIBLE CALL LEFT KEY` | csOld | ctChar | 1 | editable |
| `POSSIBLE CALL MODE` | csOld | ctOther | 1 | editable |
| `POSSIBLE CALL RIGHT KEY` | csOld | ctChar | 1 | editable |
| `QSX ENABLE` | csOld | ctBoolean | 1 | editable |
| `QZB RANDOM OFFSET ENABLE` | csNew | ctBoolean | 1 | editable |
| `RADIUS OF EARTH` | csOld | ctReal | 1 | editable |
| `SHIFT KEY ENABLE` | csNew | ctBoolean | 1 | editable |
| `STATIONS CALLSIGNS MASK` | csNew | ctString | 1 | editable |
| `WAKE UP TIME OUT` | csOld | ctInteger | 1 | editable |

## Message editor owns it -- no new UI  (21)

| command | crS | type | net | nature |
| --- | --- | --- | ---: | --- |
| `CALL OK NOW CW MESSAGE` | csOld | ctMessage | 1 | message (read-only in Ctrl-J) |
| `CALL OK NOW MESSAGE` | csOld | ctMessage | 1 | message (read-only in Ctrl-J) |
| `CALL OK NOW SSB MESSAGE` | csOld | ctMessage | 1 | message (read-only in Ctrl-J) |
| `CQ CW EXCHANGE` | csOld | ctMessage | 0 | message (read-only in Ctrl-J) |
| `CQ CW EXCHANGE NAME KNOWN` | csOld | ctMessage | 0 | message (read-only in Ctrl-J) |
| `CQ EXCHANGE` | csOld | ctMessage | 0 | message (read-only in Ctrl-J) |
| `CQ EXCHANGE NAME KNOWN` | csOld | ctMessage | 0 | message (read-only in Ctrl-J) |
| `CQ SSB EXCHANGE` | csOld | ctMessage | 0 | message (read-only in Ctrl-J) |
| `CQ SSB EXCHANGE NAME KNOWN` | csOld | ctMessage | 0 | message (read-only in Ctrl-J) |
| `QSL CW MESSAGE` | csOld | ctMessage | 1 | message (read-only in Ctrl-J) |
| `QSL MESSAGE` | csOld | ctMessage | 1 | message (read-only in Ctrl-J) |
| `QSL SSB MESSAGE` | csOld | ctMessage | 1 | message (read-only in Ctrl-J) |
| `QSO BEFORE CW MESSAGE` | csOld | ctMessage | 1 | message (read-only in Ctrl-J) |
| `QSO BEFORE MESSAGE` | csOld | ctMessage | 1 | message (read-only in Ctrl-J) |
| `QSO BEFORE SSB MESSAGE` | csOld | ctMessage | 1 | message (read-only in Ctrl-J) |
| `REPEAT S&P CW EXCHANGE` | csOld | ctMessage | 0 | message (read-only in Ctrl-J) |
| `REPEAT S&P EXCHANGE` | csOld | ctMessage | 0 | message (read-only in Ctrl-J) |
| `REPEAT S&P SSB EXCHANGE` | csOld | ctMessage | 0 | message (read-only in Ctrl-J) |
| `S&P CW EXCHANGE` | csOld | ctMessage | 0 | message (read-only in Ctrl-J) |
| `S&P EXCHANGE` | csOld | ctMessage | 0 | message (read-only in Ctrl-J) |
| `S&P SSB EXCHANGE` | csOld | ctMessage | 0 | message (read-only in Ctrl-J) |

## Prefs -> Appearance  (14)

| command | crS | type | net | nature |
| --- | --- | --- | ---: | --- |
| `BEEP ENABLE` | csOld | ctBoolean | 1 | editable |
| `COLUMN AUTOSIZE` | csNew | ctBoolean | 1 | editable |
| `COMPLETE CALLSIGN MASK` | csNew | ctString | 1 | editable |
| `CONTACTS PER PAGE` | csOld | ctInteger | 1 | editable |
| `CUSTOM CARET` | csNew | ctBoolean | 1 | editable |
| `HOUR DISPLAY` | csOld | ctOther | 1 | editable |
| `INSERT MODE` | csOld | ctBoolean | 1 | editable |
| `RATE DISPLAY` | csOld | ctOther | 1 | editable |
| `REMINDER` | csOld | ctOther | 1 | read-only (contest sets it) |
| `ROW COUNT` | csNew | ctInteger | 1 | editable |
| `SHOW FREQUENCY IN LOG` | csNew | ctBoolean | 1 | editable |
| `SHOW TYPED CALLSIGN` | csNew | ctBoolean | 1 | editable |
| `USER INFO SHOWN` | csOld | ctOther | 1 | editable |
| `WINDOW SIZE` | csNew | ctInteger | 1 | editable |

## Prefs -> CW  (12)

| command | crS | type | net | nature |
| --- | --- | --- | ---: | --- |
| `AUTO SEND CHARACTER COUNT` | csOld | ctInteger | 1 | editable |
| `CODE SPEED` | csOld | ctInteger | 1 | editable |
| `PADDLE PORT` | csOld | ctPortLPT | 1 | editable |
| `QUESTION MARK CHAR` | csOld | ctChar | 1 | editable |
| `SHORT 0` | csOld | ctChar | 1 | read-only (contest sets it) |
| `SHORT 1` | csOld | ctChar | 1 | read-only (contest sets it) |
| `SHORT 2` | csOld | ctChar | 1 | read-only (contest sets it) |
| `SHORT 9` | csOld | ctChar | 1 | read-only (contest sets it) |
| `SHORT INTEGERS` | csOld | ctBoolean | 1 | editable |
| `SLASH MARK CHAR` | csOld | ctChar | 1 | editable |
| `START SENDING NOW KEY` | csOld | ctChar | 1 | editable, runs proc 19 |
| `TUNE ALT-D ENABLE` | csOld | ctBoolean | 1 | editable |

## Prefs -> Files/Updates  (7)

| command | crS | type | net | nature |
| --- | --- | --- | ---: | --- |
| `ALLOW AUTO UPDATE` | csNew | ctBoolean | 1 | editable |
| `CALLSIGN UPDATE ENABLE` | csOld | ctBoolean | 1 | editable |
| `COUNTRY INFORMATION FILE` | csOld | ctString | 1 | editable |
| `CTY UPDATE CHECK ON STARTUP` | csNew | ctBoolean | 0 | editable |
| `DOMESTIC FILENAME` | csOld | ctFileName | 1 | read-only (contest sets it) |
| `MISSINGCALLSIGNS FILE ENABLE` | csNew | ctBoolean | 1 | editable |
| `UNKNOWN COUNTRY FILE NAME` | csOld | ctString | 1 | editable |

## Prefs -> Band Map  (5)

| command | crS | type | net | nature |
| --- | --- | --- | ---: | --- |
| `BAND MAP CUTOFF FREQUENCY` | csOld | ctFreqList | 1 | editable, runs proc 17 |
| `BAND MAP ITEM HEIGHT` | csOld | ctInteger | 1 | editable |
| `BAND MAP ITEM WIDTH` | csNew | ctInteger | 1 | editable |
| `BAND MAP SIZE` | csOld | ctInteger | 1 | editable |
| `BAND MAP SPLIT MODE` | csOld | ctOther | 1 | editable |

## Prefs -> Hardware  (5)

| command | crS | type | net | nature |
| --- | --- | --- | ---: | --- |
| `LPT1 BASE ADDRESS` | csNew | ctInteger | 0 | read-only (contest sets it) |
| `LPT2 BASE ADDRESS` | csNew | ctInteger | 0 | read-only (contest sets it) |
| `LPT3 BASE ADDRESS` | csNew | ctInteger | 0 | read-only (contest sets it) |
| `STEREO PIN HIGH` | csOld | ctBoolean | 0 | editable |
| `USE CONTROL PORT` | csNew | ctBoolean | 1 | editable |

## Prefs -> Network  (2)

| command | crS | type | net | nature |
| --- | --- | --- | ---: | --- |
| `COMPUTER NAME` | csNew | ctString | 0 | editable |
| `NET STATUS UPDATE INTERVAL` | csNew | ctInteger | 1 | editable |

## Prefs -> Voice/DVK  (2)

| command | crS | type | net | nature |
| --- | --- | --- | ---: | --- |
| `MP3 RECORDER BITRATE` | csNew | ctInteger | 1 | editable |
| `MP3 RECORDER DURATION` | csNew | ctOther | 1 | editable |

## Prefs -> Advanced  (2)

| command | crS | type | net | nature |
| --- | --- | --- | ---: | --- |
| `HAND LOG MODE` | csNew | ctBoolean | 0 | editable |
| `NO LOG` | csOld | ctBoolean | 1 | editable |

## Prefs -> DX Cluster  (1)

| command | crS | type | net | nature |
| --- | --- | --- | ---: | --- |
| `BROADCAST ALL PACKET DATA` | csOld | ctBoolean | 1 | editable |

