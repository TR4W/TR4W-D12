# Windows bench results — November 11–12, 2026

This is a scoped result record for [the UI bench plan](GUI_BENCH_TEST_PLAN.md), not acceptance of every item in BENCH_QUEUE. Python drove the real application on tr4w-gui-test; the linked screenshots were reviewed here. [Source item identities and exact original requirements](gui-test/bench-20261111/queue-items.json) preserve the seven relevant checkbox IDs and queue snapshot hash before annotations.

## Exact application tested

- Original executable: `C:\tr4w-d12\build-out\app-i386-win32\tr4w_fpc.exe`, selected by NY4I.
- Tested snapshot SHA256: `98db42069823905e263b1313d68dbb0d43d0e388ed685d77557082998ae3acb1`.
- Matching debug-link CRC: `51ADCB58`; debug SHA256: `5bc8496fe67d3e52d352363850e08dcca92e16e3ab1fcac081a82a17d3640a3b`.
- Build-time source revision: **unknown**, not inferred from the live checkout. Executable/symbol pair and runtime assets were copied and archived before execution.
- Windows GUI-TEST interactive desktop, 1280×800, 100%/96 DPI, English; Python 3.15.2 x86. No radio, keyer or external delivery definitions in this fixture.
- Fixture: `C:\TR4W-Test\bench-main-98db42069823\runs\bench-new-002`; three new test contacts entered with Ctrl+Enter. The application was closed through its normal confirmation.
- [Build evidence](gui-test/bench-20261111/build-evidence.json), [task result](gui-test/bench-20261111/result.json), [menu states](gui-test/bench-20261111/menus.json). Full flushed action journal and diagnostic artifacts: `build-out/bench-ui/results-98db-run002/bench-basic`.

An earlier label-only attempt used main-executable SHA256 `1ee7a69d9c09991ea4067a73832e906a5217283ec3ed3e2039a5f7f14d6b5927`. Main was updated during this work, so the completed batch used the newer snapshot above. No tests used the separate source-build trial. Future updates require a new snapshot/result; these results do not silently carry forward to a different executable.

## Results tied to the queue

| Queue heading / item | Status | Evidence and remaining scope |
| --- | --- | --- |
| CW OPEN COUNTS NO ZONES — No Zones row | **PARTIAL: Windows PASS** | [Empty totals](gui-test/bench-20261111/cwo-empty.png) and populated totals show QSOs and Calls, no Zones. Linux/gtk2 remains untested. |
| CW OPEN COUNTS NO ZONES — Two QSOs, the score | **PASS on Windows** | [Two contacts](gui-test/bench-20261111/cwo-two.png): K6RB and W7SP on 20 m CW, QSOs 2 / Calls 2 / 4 Pts. [Third contact](gui-test/bench-20261111/cwo-three.png): K6RB on 40 m CW, QSOs 3 / Calls 2 / 6 Pts. The 20/40 band headings and all three records are visible. This standalone behavior checkbox is checked in the worktree queue. |
| LICENCE-YEAR ROW IS LABELLED — European HF Championship | **PARTIAL: Windows label/input PASS** | [EUHFC setup](gui-test/bench-20261111/euhfc.png): MY LICENSE YEAR is readable, no MY ZONE, 64 entered. Saving/reopening that contest's year and Linux fit remain untested. |
| LICENCE-YEAR ROW IS LABELLED — KVP | **PARTIAL: Windows label/input PASS** | [KVP setup](gui-test/bench-20261111/kvp.png): MY LICENSE YEAR and 64, readable. The visible contest name is **KV PRVENSTVO ZRS**; searching the internal abbreviation KVP finds no result. Saved-year round trip and Linux remain untested. |
| LICENCE-YEAR ROW IS LABELLED — Another contest unchanged | **Windows PASS** | [NAQP CW](gui-test/bench-20261111/naqp.png): MY STATE and MY NAME, values FL and TOM. Other-platform behavior is not claimed. |
| CWT QTH-OR-MEMBER ROW — CWT row label | **PARTIAL: Windows label/input PASS** | [CWT setup](gui-test/bench-20261111/cwt.png): MY NAME and MY QTH OR MEMBER NO, readable at design size, TOM and 1234 entered. Saving/reopening MY STATE and Linux remain untested. |
| CWT QTH-OR-MEMBER ROW — Locust / NCCC unchanged | **PARTIAL: NCCC Windows PASS** | [NCCC](gui-test/bench-20261111/nccc.png) shows MY NAME / MY STATE. [Locust](gui-test/bench-20261111/locust-inactive.png) is explicitly inactive and displays no exchange inputs even with Show inactive contests checked. Its New Contest field comparison is not runnable as written; clarify whether a legacy log is intended. No application defect is inferred from an intentionally inactive entry. |
| CWT / ARRL Submit menu | **NOT RUN for the named contests** | Menu enumeration incidentally confirms Submit ARRL Log is disabled for CW Open. That does not close the CWT or ARRL contest items. No portal was opened. |
| Other UI batches, DPI, translations, Linux/macOS | **NOT RUN in this batch** | See the plan; the inventory's requirement signals are candidates, not passes. |

The CWO remaining-multipliers window, ADIF CQZ absence, existing-log rescore, invalid-entry notices and safe numbered-log dialog remain open. This batch does not establish them through inference from the correct score.

## Harness findings, kept separate from application defects

- Contest search uses visible names. The initial KVP abbreviation query found no result; the catalog supplied KV PRVENSTVO ZRS. Locust needs the inactive filter and still has no creation inputs. The catalog was read from the running list, not taken from source.
- The call and exchange inputs have the same left coordinate and different top coordinates. An initial driver sorted by left and reversed them. The screenshot exposed the mistake; entry now uses their observed vertical order and explicit focus. NAQP's state/name order differs from CWT's name/member order; its fixture values were corrected accordingly.
- The no-CW contact sequence is now shared with the existing practice-contact scenario. Actions and field-clear assertions passed before screenshot review. The final score and label verdicts above come from the reviewed images, not only from a successful task exit.
- No application access violation occurred in this batch. No hardware or external logger test was passed. No application-source changes were made.

## Queue synchronization

The initial triage read source SHA256 `be55e8fc19acaa74da54fffe9c8dae5a9c80915fb07f5e6b8c78a183c184f19d`. Main then gained the Preferences > Station information License year/CQ zone label item. That fresh main file was copied again before evidence annotations; it was not overwritten in the non-worktree checkout. The worktree queue adds scope-specific evidence and leaves untested requirements open. The other agent may merge these annotations with subsequent queue edits.

## Follow-up 2026-11-12

These additional Python-driven tests used the same pinned `98db42069823…` main executable and isolated settings, with no hardware connections or CW output. Reviewed screenshots and structured results are retained under [bench-20261112](gui-test/bench-20261112/). The worktree queue is updated; the non-worktree queue is untouched. Windows-only success does not close requirements that also demand Linux or other untested routes.

| Check | Result and evidence |
| --- | --- |
| Preferences search and focus | PASS for QTC MINUTES, CATEGORY-POWER, SPRINT QSY RULE and CALL HISTORY FILENAME. Actual visible search hits opened the corresponding leaves and focused their controls. [Observations](gui-test/bench-20261112/contest-save/search-results.json). Help/deep-link routes remain open. |
| Three contest leaves: Cancel, Save, restart | PASS. QTC MINUTES, CATEGORY-POWER and SPRINT QSY RULE cancel without change; Save persists TRUE / LOW / TRUE under their original SQLite command names. Restart restores the saved controls; original values then restored. [Saved rows](gui-test/bench-20261112/contest-save/stored-config.json), [restart result](gui-test/bench-20261112/contest-reopen/result.json). |
| Three station pages: Cancel and Save | PASS for unchanged Cancel and typed JSON persistence: DE ENABLE, SCP MINIMUM LETTERS and RADIUS OF EARTH. DE and SCP reload correctly; Radius does not. [Saved settings](gui-test/bench-20261112/station-save/stored-settings.json). Original fixture settings restored and verified in [cleanup result](gui-test/bench-20261112/station-restored/result.json). |
| Radius Of Earth last row and reload | Layout PASS: last on Advanced. Reload FAIL: saved 6371.0 is blank after restarting. [Screenshot](gui-test/bench-20261112/station-reopen/radius-of-earth.png), [issue #295](https://github.com/TR4W/TR4W-D12/issues/295). Current-source diagnosis: shared typed-settings getter lacks the float case supported by its setter; no application source changed. |
| Preferences placement errors | PASS: inspected runtime log contains no `editor(s) in Preferences` Error or `placement ... refused` line. Full runtime logs remain in `build-out/bench-ui/prefs-radius6371/bench-prefs-station-verify`. |
| Taken log: Create new | PASS: default Enter creates empty numbered 2.db and 3.db, serial 1. Original three-contact database hash unchanged after both creations. [Result](gui-test/bench-20261112/log-names/naming-result.json), [numbered log](gui-test/bench-20261112/log-names/numbered-3.png). |
| Taken log: Open existing | PASS: original three contacts / 6 points open, no additional file created. [Screenshot](gui-test/bench-20261112/log-names/opened-original.png). |
| Taken log: Cancel | PASS for Escape, Cancel button and physical title-bar X: form values retained and no file created. Choosing CWT afterward succeeds. [Physical X result](gui-test/bench-20261112/log-close/result.json), [retained form](gui-test/bench-20261112/log-names/cancel-retained.png). In-session File > Open Log routes remain untested. |
| CWT member field and ARRL menu | Windows PASS: creation saves member number 1234 as MY STATE; Submit to ARRL is disabled. [CWT screenshot](gui-test/bench-20261112/log-names/cwt-after-cancel.png), [structured assertions](gui-test/bench-20261112/log-names/naming-result.json). Other platforms and enabled ARRL-contest routes remain open. |
| CW Open missing serial/name | Behavior PASS with Ctrl+Enter: exact notices, no contact logged, focus retained. [Serial missing](gui-test/bench-20261112/exchanges/missing-serial.png), [name missing](gui-test/bench-20261112/exchanges/missing-name.png). Visual mismatch: notices are black, whereas queue specifies red; [issue #296](https://github.com/TR4W/TR4W-D12/issues/296) asks to resolve UI versus requirement. |
| CW Open corrected and empty exchange | PASS: correcting to 234 WOODY logs exactly one contact and clears the notice; empty Ctrl+Enter leaves count at one and fields empty. [Corrected](gui-test/bench-20261112/exchanges/valid-after-errors.png), [empty](gui-test/bench-20261112/exchanges/empty-enter.png), [counts/focus](gui-test/bench-20261112/exchanges/entry-result.json). Empty submission's silent behavior is confirmed as the queue's known gap, not fixed. |

External Software overview: Tab reaches all four buttons and all four mouse clicks open the corresponding leaf. Enter fails on all four, even with a five-second transition wait: [issue #297](https://github.com/TR4W/TR4W-D12/issues/297), [per-button results](gui-test/bench-20261112/overview/overview-result.json). Returning to the overview does not duplicate buttons. The Operating-page script selected DX Cluster instead; screenshot review rejected that assertion, so Operating remains untested. The parent checkbox remains open.

Harness corrections were validated separately: search needs selection of its visible popup hit; numeric-looking settings can be checkboxes or combos; the collision fixture must use the guest's current local date (a first attempt crossed midnight). These are not application defects. UI transition waits are required after rebuilding Preferences pages. Nine portable harness tests pass; these validate evidence guards and queue indexing, not application behavior.

After this batch, the live main executable changed to SHA256 A6285C3F56DC46C23E01C355061DD3AEAC7E27D4917F481178F2A2E82A5FE315. The results above apply to the archived 98db snapshot only; the newer executable requires a fresh paired snapshot and test run.


## Current main repeat: e1e4f880d914

Resumed on the freshly copied main executable, SHA256 e1e4f880d91449f932ba7869985c17e07fe3c3071a9036cec1baa684a0853237, matching symbols CRC 4F73F3E0. The External Software overview repeat confirms all four Tab targets and all four mouse navigations; Enter still fails on all four after five-second waits. Issue #297 remains reproducible. No application crash occurred; the owned application closed normally. [Per-button result](gui-test/bench-20261112/current-overview-e1e4/overview-result.json), [focused button after Enter](gui-test/bench-20261112/current-overview-e1e4/wsjt-x-enter.png). Operating-page behavior remains untested.


## Licence-year creation and reopen: e1e4 build

Both European HF Championship and KV PRVENSTVO ZRS were created with year 64, closed normally, and reopened. Their closed-log config MY ZONE is 64, but the focused Preferences License year field displays 8, the station CQ zone. This is a failed round trip, recorded as [issue #300](https://github.com/TR4W/TR4W-D12/issues/300); transmitted exchange behavior is not established. [KVP saved row](gui-test/bench-20261112/bench-year-kvp/saved-year.json), [reopened control](gui-test/bench-20261112/bench-year-kvp/reopened-year.json), [screen](gui-test/bench-20261112/bench-year-kvp/my-zone.png). Each creation used a fresh settings/log fixture and the exact e1e4f880d914 snapshot above.


## Preferences persistence repeat: e1e4 build

All three contest leaves passed Cancel, Save, restart and restoration on the current pinned build. Station Cancel and JSON persistence passed; DE ENABLE and SCP MINIMUM LETTERS reloaded correctly, while RADIUS OF EARTH was blank rather than saved 6371, reproducing #295. Cleanup restored the baseline and verified the JSON. [Contest restart](gui-test/bench-20261112/current-preferences-e1e4/bench-prefs-verify/result.json), [station failure](gui-test/bench-20261112/current-preferences-e1e4/bench-prefs-station-verify/result.json), [verified cleanup](gui-test/bench-20261112/current-preferences-e1e4/bench-prefs-station-restore/stored-settings.json). Full journals/logs remain in build-out/bench-ui/current-preferences.


## QSO-party forms: e1e4 build

Python drove the actual New Contest controls in fresh isolated fixtures; no hardware connected. The accepted final runs use the pinned e1e4f880d914 main snapshot. [Florida/7QP result](gui-test/bench-20261112/county-florida/county-result.json), [Texas result](gui-test/bench-20261112/county-texas/county-result.json).

- Florida out of state PASS: GA, DX and ON enable OK; XX is rejected with its invalid-state notice; ALC and FL require the in-state checkbox. Screenshots were reviewed for the actual notices and enabled state.
- Florida in state PARTIAL PASS: blank county disables OK; a physical click on ALC enables it; created log stores MY STATE=ALC and title says in state. Sent exchange remains untested. [Selected county](gui-test/bench-20261112/county-florida/florida-alc-selected.png), [created session](gui-test/bench-20261112/county-florida/florida-created.png).
- Colorado name retention PASS: TOM survives ticking and unticking the county checkbox. [Retained name](gui-test/bench-20261112/county-florida/colorado-name-retained.png).
- Texas named county PASS: 254 entries include ANDE - Anderson. A physical click selects it; after creation and normal exit, MY STATE is ANDE alone. [Selection](gui-test/bench-20261112/county-texas/texas-county-selected.png). Full list scrolling and another language remain open under the separate layout item.
- 7QP PASS: checkbox says I am in 7th area; AZ is refused with the tick-box notice, CA accepted, and county list includes AZAPH. [AZ](gui-test/bench-20261112/county-florida/7qp-AZ.png), [CA](gui-test/bench-20261112/county-florida/7qp-CA.png).
- British Columbia, Ontario, Quebec and combined IN7QPNE have no in-state checkbox and retain free-entry rows. Ontario's multiline instruction clips at the top: [issue #301](https://github.com/TR4W/TR4W-D12/issues/301), [screen](gui-test/bench-20261112/county-florida/ontario-unchanged.png). Presentation item stays open.

Harness findings: ComboBox.texts includes the displayed value before the item list, so using it as a list index selected BAK instead of ALC. The script now uses item_texts and asserts the displayed code before creation. A checkbox also raced with rebuilding the selected contest form; the script now waits for the expected area caption and verifies the checked state. These were test-driver defects; no application issue was filed for them. Earlier failed evidence remains in build-out/bench-ui/county and county-corrected, separate from the accepted final runs. Nine portable harness tests pass.


## Open Log cancellation: e1e4 build

File > Open Log opens the expected switch dialog with existing-log grid, Browse and New Contest area. Last Contest is hidden. Cancel and physical title-bar X both return to the same process/session; log lines confirm the hidden-last-contest decision and both cancellations. [Dialog](gui-test/bench-20261112/switch-cancel/cancel-dialog.png), [outcomes](gui-test/bench-20261112/switch-cancel/switch-cancel-result.json). Full runtime log is in build-out/bench-ui/switch-cancel-exact/bench-switch-cancel. Restarting into a different log and hardware reconnection are not accepted by this cancellation test.


## Already-open name: e1e4 build

File > Open Log > New Contest with the current CW Open name shows only Create new log and Cancel. Wording explicitly identifies the log already open; Cancel returns the unchanged inputs and preserves the original session. [Question](gui-test/bench-20261112/switch-taken/already-open-question.png), [result](gui-test/bench-20261112/switch-taken/switch-cancel-result.json). Gtk2, Escape on this particular question and actually creating/restarting into the numbered log remain open.


The latest main BENCH_QUEUE was merged into the annotated worktree queue using the previous refreshed snapshot as the common base. It merged without conflicts; source SHA256 daa2030668caef0477aecc1ec4fc5d7d3089b8023970f446474d979d7aedd37a. New export/year checks remain pending; previous evidence annotations were preserved.


## Preferences focus audit: e1e4 build

Python completed actual Tab and Shift+Tab focus walks on 47 Preferences pages. Every cycle completed before the cap, reverse order exactly matched forward order, and no focused stop was hidden or disabled. [Full focus records](gui-test/bench-20261112/tab-audit-e1e4/preferences-audit.json), [task result](gui-test/bench-20261112/tab-audit-e1e4/result.json). This is mechanical coverage, not full semantic acceptance of every page or proof of hover-tooltip coverage.

Reviewed specific sequences:

- Station goes down the left column, then the right, then Main Callsign and footer. [Station](gui-test/bench-20261112/tab-audit-e1e4/preferences-1.png). NY4I's choice between column and row order remains pending.
- Appearance traverses Font, Size, Bold, Language, four window/grid checkboxes, Row Count, Window Size, then footer. The Layout block follows Draw gridlines as specified. [Appearance](gui-test/bench-20261112/tab-audit-e1e4/preferences-7.png).
- Operating has its own page, no overview navigation buttons or removed Stop sending checkbox, a two-line introduction, and seven checkboxes in downward order. [Operating](gui-test/bench-20261112/tab-audit-e1e4/preferences-21.png). This replaces the earlier rejected Operating assertion.
- Each cycle includes the search field immediately before the navigation tree; from there Tab enters the page, then the enabled footer buttons. Shift+Tab reverses the sequence. Disabled Save is correctly skipped in this unchanged fixture; its current caption replaces the queue's old Apply wording.

Screenshot review also found a clipped long label in Band Map > Window and tuning: [issue #304](https://github.com/TR4W/TR4W-D12/issues/304), [screen](gui-test/bench-20261112/tab-audit-e1e4/preferences-38.png). Selected reviewed pages additionally include DX Cluster, SCP, Logging, Backup and Band Map. Remaining page images are preserved for semantic review; empty UIA HelpText is not classified as a missing tooltip.


## CW Open exports and remaining multipliers: e1e4 build

File > Export > ADIF generated three records with no received CQZ tag. MY_CQ_ZONE/MY_ITU_ZONE are still present as station metadata. [Actual ADIF](gui-test/bench-20261112/cwopen-adif/cwopen.adi), [result](gui-test/bench-20261112/cwopen-adif/result.json).

Cabrillo generated three QSO lines sending 1 TOM, 2 TOM and 3 TOM. The station summary was confirmed locally; after closing the generated-file viewer, the Super Check Partial upload question was explicitly answered No. [Actual Cabrillo](gui-test/bench-20261112/cwopen-cabrillo/cwopen.cbr), [result including upload declined](gui-test/bench-20261112/cwopen-cabrillo/result.json). No sponsor or external upload was performed.

Windows > Mults is a submenu. Selecting its Default entry opens a window titled Default containing K6RB and W7SP, with no zone list. [Reviewed capture](gui-test/bench-20261112/cwopen-multipliers/remaining-multipliers.png), [actual submenu](gui-test/bench-20261112/cwopen-multipliers/multiplier-menu.json). The early menu driver selected the submenu heading without its Default command and then searched for a window containing Mult in its title; both assumptions were corrected from the actual menu and window inventory. No application issue was filed for those driver mistakes.

The ADIF command opens an internal text viewer rather than a save dialog. Cabrillo opens the summary, then its internal viewer, then asks about uploading after that viewer closes. Earlier unclassified prompts stopped the owned process without accepting an upload. Final runs closed normally and preserved the generated files as evidence.


## License-year exports and Preferences edit: e1e4 build

Fresh SQLite-backed copies of the EUHFC and KVP logs created with year 64 each received one W7SP / 599 85 test contact through normal fields using Ctrl+Enter, without CW or hardware. Both exported STX_STRING=599 64 in ADIF and sent 599 64 in Cabrillo. ITU station metadata remains 8 in ADIF. MY_CQ_ZONE is absent in these fixtures; full captured-zone metadata acceptance remains open. The Edit QSO view shows our-station CQ zone 64 and ITU zone 8; that is an observation, not a source-level explanation for the missing ADIF tag.

- EUHFC: [ADIF](gui-test/bench-20261112/year-euhfc/bench-export-year-adif/year.adi), [Cabrillo](gui-test/bench-20261112/year-euhfc/bench-export-year-cabrillo/year.cbr).
- KVP: [ADIF](gui-test/bench-20261112/year-kvp/bench-export-year-adif/year.adi), [Cabrillo](gui-test/bench-20261112/year-kvp/bench-export-year-cabrillo/year.cbr).

Separate disposable copies test Preferences editing. Search MY ZONE opens the visibly labelled License year control showing 8. Entering 05 and choosing Save and close leaves the log's MY ZONE command at 64. Subsequent ADIF still sends 599 64 in both contests. This is a verified failure of the requested edit/export behavior; [#300 was updated](https://github.com/TR4W/TR4W-D12/issues/300#issuecomment-6817167958).

- EUHFC: [before/after configuration](gui-test/bench-20261112/year-change-euhfc/year-change.json), [05 entered](gui-test/bench-20261112/year-change-euhfc/license-year-05-entered.png), [actual export](gui-test/bench-20261112/year-change-euhfc/year.adi).
- KVP: [before/after configuration](gui-test/bench-20261112/year-change-kvp/year-change.json), [actual export](gui-test/bench-20261112/year-change-kvp/year.adi).

Successful export runs closed the application normally and explicitly declined the optional external upload. The deliberately failing 05 checks preserved the generated evidence and stopped only their owned process; their fixture copies are disposable, separate from baseline test logs and operator data. No application source changed.


## Captured ITU-zone edits: e1e4 build

The contact editor was opened by a physical double-click on the single test record. Changing its bottom-right, visibly labelled ITU zone field from 8 to 42 and cancelling/answering No preserved 8 on reopen. Repeating the edit, Save/answering Yes, then reopening preserved 42. Both the EUHFC and IARU cases passed this actual edit/reopen sequence. [EUHFC assertions](gui-test/bench-20261112/year-itu42/adif/itu-edit-result.json), [IARU assertions](gui-test/bench-20261112/iaru-itu42/adif/itu-edit-result.json).

- EUHFC after ITU=42: [ADIF](gui-test/bench-20261112/year-itu42/adif/year.adi) retains MY_ITU_ZONE=42 and sends STX_STRING=599 64; [Cabrillo](gui-test/bench-20261112/year-itu42/cabrillo/year.cbr) still sends 599 64. [Reopened editor](gui-test/bench-20261112/year-itu42/adif/itu-after-save.png).
- IARU after ITU=42: [ADIF](gui-test/bench-20261112/iaru-itu42/adif/zone.adi) retains MY_CQ_ZONE=5 and MY_ITU_ZONE=42 and sends STX_STRING=599 42; [Cabrillo](gui-test/bench-20261112/iaru-itu42/cabrillo/zone.cbr) also sends 599 42. Thus the real-zone contest still follows the per-contact captured-zone edit.

The new IARU fixture is a regular station with its HQ/member checkbox unticked; its actual New Contest form has no exchange input, so no license-year input was assumed. On contact entry the program suggested an exchange; the driver was corrected to replace that suggestion when supplying a complete exchange rather than append another exchange to it. No application defect was filed for this setup correction.

The EUHFC editor also displays CQ zone 64, while the same W1AW station in IARU captures CQ zone 5. EUHFC ADIF omits MY_CQ_ZONE. This observed metadata discrepancy is [issue #305](https://github.com/TR4W/TR4W-D12/issues/305), separate from #300's Preferences editing failure. The complete ADIF captured-CQ requirement remains open.

Both failed Preferences-05 fixture databases were reread after their application processes had stopped: [closed database results](gui-test/bench-20261112/closed-year-configs.json) confirm MY ZONE stayed 64 in EUHFC and KVP.

Export evidence now records file modification timestamps and SHA256 and refuses a file that the tested export command did not rewrite. This guard was exercised in the IARU runs. Two portable regression checks reject stale exports without replacing evidence and preserve rewritten output with the correct digest; the portable suite now has 11 passing checks. These guards do not substitute for the GUI/file-content results above.


## Fresh CW Open replay after exchange-driver correction

A new cwopen-replay-001 fixture repeated New Contest labels, then entered three contacts with the shared driver replacing any suggested exchange. Reviewed screenshots again show 2 QSOs / 2 Calls / 4 points and then 3 QSOs / 2 Calls / 6 points. [Two contacts](gui-test/bench-20261112/cwopen-current-replay/bench-basic/cwo-two.png), [three contacts](gui-test/bench-20261112/cwopen-current-replay/bench-basic/cwo-three.png). The fresh log also passed [ADIF export](gui-test/bench-20261112/cwopen-current-replay/bench-export-discover/cwopen.adi) and [Cabrillo export](gui-test/bench-20261112/cwopen-current-replay/bench-export-cabrillo/cwopen.cbr), including rewritten-file timestamp/digest guards and explicit No to the upload question. The application closed normally after each phase. These results supersede the older fixture raw-exchange artifact that appended a suggestion to the third contact.

Application source was consulted only to understand the multiplier menu routing and the configured editor confirmation while diagnosing driver failures. Acceptance above is based on the real UI, reopen checks, stored configuration and generated files. No application source changed. Eleven portable harness checks pass; full hover-tooltip coverage and semantic review of the remaining Preferences pages are still pending.


## New main build: 4d244c6f3d26

Main changed during final validation. A new immutable executable/symbol snapshot was staged: SHA256 4d244c6f3d26f682f250e8a7cc00b84afbddf86630f9caaf03776ab44bfeaffa, debug CRC F964CC0E, VM root C:/TR4W-Test/bench-main-4d244c6f3d26. Build-time source revision is unknown. Only the EUHFC creation/reopen probe was rerun: MY ZONE saves 64, but the Preferences License year control still reopens at 8. [Saved value](gui-test/bench-20261112/year-roundtrip-4d24/saved-year.json), [reopened control](gui-test/bench-20261112/year-roundtrip-4d24/reopened-year.json), [result](gui-test/bench-20261112/year-roundtrip-4d24/result.json). Issue #300 was updated. All broader export, contact-edit and IARU passes above remain scoped to e1e4; they have not silently carried forward to this build.


## First x64 attempt, 2026-11-12: BLOCKED by the guest Python, no verdict

Build under test: `build-out\app-x86_64-win64\tr4w_fpc.exe` from main `87cd9ff9`, copied before staging; SHA256 `e5fcd70dddba696760c6e0f22c2ad6dfb26b488fcf229db0b21e7a1ead60a214`, staged to `C:\TR4W-Test\bench-main-e5fcd70dddba`. Portable harness tests: 11 passed. VM preflight: GUI-TEST console session 1 active, 1280x800, 96 DPI, no TR4W process, no scenario task.

`run_suite.py --case import` never reached the application. The seed worker (`pythonw.exe` from `C:\TR4W-Test\.venv`, started 19:19:54 guest time) stayed alive with no artifacts directory, no TR4W process, and `readiness\scenario-runner.log` not even reopened. Cause, read from the guest: the x64 venv's `pyvenv.cfg` has `home = C:\Users\toms\AppData\Local\Programs\Python\Python315`, and that folder's ACL grants only SYSTEM, Administrators and toms. The interactive worker runs as gui-test, so the venv launcher cannot reach its base interpreter. This is the failure the README already describes for a venv built from a private profile; the x86 venv works because its base is the shared `C:\TR4W-Test\runtimes\python315-x86`. No shared x64 runtime exists under `runtimes`. The x86 venv cannot be substituted: `evidence.require_matching_bitness` refuses it against an x64 exe, as it should.

Required before any x64 GUI verdict: a shared x64 Python 3.15.2 runtime gui-test can execute (for example `C:\TR4W-Test\runtimes\python315-x64`), `.venv` recreated from it with pywinauto 0.6.9, Pillow, pywin32 and comtypes, and the `import` case run alone first. Consequently every suite case, every fix verification (#295, #297, #300, #301, #304, #305, #306) and every BENCH_QUEUE item for this build is **NOT RUN**. Host evidence: `build-out/gui-regression/20261113T001934-27bf77` (its `summary.json` still says RUNNING because the host runner was killed by a tool timeout, not by a verdict). The hung worker and the registered `TR4W-GuiScenario` task were left on the guest; the next `vm_run.py` will refuse to start ("Scenario task already exists") until they are removed.


## Second x64 attempt, 2026-11-12 21:13 EST: BLOCKED again by the guest Python, no verdict

**Superseded the same evening:** the working environment was a separate `C:\TR4W-Test\.venv-x64`, which already existed, not a repaired `.venv`. No administrator action was needed; see "First x64 results" below.

Build under test: `build-out\app-x86_64-win64\tr4w_fpc.exe` (built 19:44, after 7f231e18 and 2c755fa6), SHA256 `af52e1445acb4cc8b6bd1c096f67de1aa763f48c19c8d5615484eb6fe555e266`, debug CRC `99C94B0C`, staged to `C:\TR4W-Test\bench-main-af52e1445acb`. Portable harness tests: 11 passed. Preflight: the stale `TR4W-GuiScenario` task had been removed by the user; no TR4W or Python process on the guest.

`run_suite.py --case import` exited 2: the seed worker returned task result 103 with no artifacts, the same signature as the first attempt. Read from the guest afterwards: `C:\TR4W-Test\runtimes` holds only `python315-x86`; `C:\TR4W-Test\.venv` was last written 2026-11-10 and its `pyvenv.cfg` still has `home = C:\Users\toms\AppData\Local\Programs\Python\Python315`, whose ACL still grants only SYSTEM, Administrators and toms. The shared x64 runtime and rebuilt venv described as done are not present. Installing them needs administrator rights and was not attempted.

Every suite case, the fix verifications (#280, #295, #297, #301, #304, #306) and the BENCH_QUEUE items for this build are **NOT RUN**. Host evidence: `build-out/gui-regression/20261113T021319-3ef71f` (`summary.json` status ERROR, `seed/runner.log`). The harness removed its task; the guest was left with no scenario task and no test process.


## First x64 results, 2026-11-12 21:23-21:45 EST: af52e1445acb

The guest Python was repaired as `C:\TR4W-Test\.venv-x64` (GUI-TEST's own Python 3.15.2 x64; proof `C:\TR4W-Test\readiness\gui-python-preflight.json`), and `stage_main_build.GUEST_PYTHON` now names it. Every run below drove x64 exe `build-out\app-x86_64-win64\tr4w_fpc.exe`, SHA256 `af52e1445acb4cc8b6bd1c096f67de1aa763f48c19c8d5615484eb6fe555e266`, debug CRC `99C94B0C`, VM root `C:\TR4W-Test\bench-main-af52e1445acb`. It was built at 19:44, after 7f231e18 and 2c755fa6; the working tree held other uncommitted source changes, so the build-time source revision is **unknown**. Windows 1280x800, 96 DPI, fresh disposable fixtures, no radio, keyer, cluster or external delivery. Portable harness tests: 11 passed after the driver edits below.

| Case / item | Result | Evidence under `build-out/gui-regression/` |
| --- | --- | --- |
| import alone (harness proof) | PASS (seed PASS) | `20261113T022346-7e86bc` |
| Full suite: seed, hints, focus, online, loggers, radio, locked, import, messages | PASS (9) | `20261113T022504-c9da52` |
| search | FAIL, **driver error, not an app result**: K3GUI was logged on 20 m (`Band = 20` in tr4w.log), not the intended 10 m. This is the known 40 m-start assumption; the driver is not fixed yet | `20261113T022504-c9da52/search` |
| #306 switch: Open Log refuses a text file named .db | **PASS** after a driver correction. The app logs `[OpenLog] ... not-a-log.db is not a contest TR4W can open -- not switching`, closes the dialog, shows "Not a TR4W contest log, so it was not opened: ..." on the status line, keeps the same PID and the three contacts/6 points. The numbered-new-log/back round trip passes. In the full suite the old driver timed out waiting for the dialog to stay open (ERROR, not FAIL) | `20261113T023624-d9c56d/switch` (`invalid-file-refused.png`, `invalid-file-refusal.json`) |
| #297 Enter on a focused overview button | **PASS**: Enter and click both navigate for WSJT-X, External Logger, DXLab and MMTTY; Tab reaches all four; no duplicate buttons | `20261113T023739-x2ce34/overview` |
| #301 Ontario QSO Party notice | **PASS** (reviewed screenshot): the four-line notice is fully visible, its box has grown and MY STATE sits below it. The rest of the county case also passes | `20261113T023739-x2ce34/county/bench-county-check/ontario-unchanged.png` |
| #304 long Preferences captions | **PASS** (reviewed screenshot): Band Map > Window and tuning wraps "Color of the M on a spot whose multiplier wants a backup" onto two lines and its row grows. Nothing is clipped on the Network page | `20261113T022504-c9da52/focus/bench-prefs-focus/preferences-38.png`, `preferences-6.png` |
| #295 Radius Of Earth reads back | **PASS**: 6371 saved, read back as 6371 after restart; Cancel restores; baseline restored. Driver correction: an unsaved key is absent from the fresh `tr4w.json` | `20261113T024045-xbf9a4/station-verify` |
| #280 Grid square tooltip | **PASS**: searching MY GRID lands on Grid square (FN31). A HintWindow shows "Values: Four- or six-character grid identifier. ..." inside the screen, wrapped at 70 columns or fewer, and it dismisses. This was added to the hints case | `20261113T022504-c9da52/hints/bench-prefs-hints/hint-observations.json` |
| EUHFC / KVP licence year (issue 298) | **PASS** for storage: New Contest row reads MY LICENSE YEAR, `64` is stored as contest-scoped `MY LICENSE YEAR` and survives a reopen, `MY ZONE` stays the station's 8. Preferences search lands on the License year box, which shows the station default (empty), as the queue says. The CQ zone box keeps its label in EUHFC | `20261113T023739-x2ce34/year-euhfc`, `year-kvp` |

BENCH_QUEUE items established on Windows x64 by the runs above (NY4I ticks; none were ticked here):

- 2026-11-12 "Enter on an empty exchange": **Preferences > Station Grid square tooltip** PASS; **Preferences > Web Server** reads "There are no settings on this page yet." PASS (`focus/.../preferences-12.png`). The two Enter-on-empty-exchange items are NOT RUN; the harness logs with Ctrl+Enter to avoid CW.
- 2026-11-12 "MY LICENSE YEAR": the Station page has a License year box under Park in the Contest exchange column (`focus/.../preferences-1.png`, CW Open log). The CQ zone label is unchanged in EUHFC; CQ WW was not opened. The EUHFC/KVP New Contest row reads MY LICENSE YEAR. The sent `85` in the default CQ message, Cabrillo and ADIF is NOT RUN, and so are the pre-298 log migration and the empty-year startup warning.
- 2026-11-12 "64-bit build": it starts and opens a log with no error box; Preferences walks all 47 pages forward and back, and a change survives a restart (station pair above). Each is a Windows PASS. ADIF re-export (import case) passes; Cabrillo, QSO edit/delete, radios, CW, cluster, WSJT-X, external loggers, multi-op, SO2R and the installer are not covered.

Driver corrections made in this session (harness defects, not application defects): `bench_switch.py` compares the seed log name against the UTC date (issue 284 names new logs by UTC) and accepts the 306 refusal path where the dialog closes; `bench_years.py` asserts `MY LICENSE YEAR` (issue 298) instead of the year under `MY ZONE`; `bench_remaining.inspect_hints` adds MY GRID and matches help text with line breaks folded; `bench_preferences.station_values` reads an absent key as None. No application source changed. The guest was left with no scenario task and no test process.


### Follow-up runs on the same exe (af52e1445acb), 21:46-21:50 EST

All five earlier evidence directories and the two below record the same SHA256 `af52e144...`. The non-suite phases (`overview`, `station-save`/`-verify`, `county`, `year-*`, `captions`, `prompts`, `export-*`) were run through `run_suite`'s own `stage`/`install`/`prepare`/`run_case` helpers, with `CASES` extended by those phase names. Each step got a fresh disposable fixture; the station pair and each year-then-export chain share one. The full suite (`20261113T022504-c9da52`) exited **2**: switch ERROR (driver) and search FAIL (driver). Switch passed only on a rerun with the corrected driver (`20261113T023624-d9c56d`).

| Item | Result | Evidence under `build-out/gui-regression/` |
| --- | --- | --- |
| #305 / 298 ADIF and Cabrillo, EUHFC and KVP | **PASS**: ADIF `STX_STRING` `599 64`, `SRX_STRING` `599 85`, `MY_CQ_ZONE` `5` (W1AW's CQ zone, not the year), `MY_ITU_ZONE` 8. Cabrillo sends `599 64` and receives `599 85`. The export driver now asserts `MY_CQ_ZONE` is present and differs from the year | `20261113T024626-x7b241/export-*` (EUHFC), `20261113T024847-xfe20b/export-*` (KVP) |
| 287 Jock White branch row | **PASS on Windows**: the row reads MY BRANCH NUMBER (reviewed `jockwhite.png`); `27` is stored as contest `MY ZONE` 27. Linux not run | `20261113T024626-x7b241/prompts/bench-prompts-check` |
| 290 NCCC / CWT prompts | **PASS on Windows** (reviewed screenshots): NCCC Sprint reads "Enter your name and QTH (US state, Canadian Province or DX country):" with no member number, beside MY STATE; CWT keeps "... or member number:" beside MY QTH OR MEMBER NO. UIA did not expose the prompt text, so the wording was judged from the images | same, `nccc.png`, `cwt.png` |
| 290 Locust | **NOT RUNNABLE as written**: with Show inactive contests ticked, "Locust QSO Party (inactive)" shows an empty prompt box and no rows (as on 2026-11-11) | same, `locust.png` |
| 284 new log named by UTC date | **PASS on Windows**: every seed log created after 19:00 EST on 2026-11-12 is named `CWOPEN 2026-11-13 W1AW.db` (for example `20261113T022504-c9da52/switch`, created 21:32 EST), the UTC date | the suite run directories |
| 282 RSGB IOTA / UK-EI parser | NOT RUN: `logstuff.pas` changed at 21:43, after this exe was built (19:44) | n/a |
| #304 Network page caption | **NOT VERIFIED**: searching NETWORK HTTP TRANSPORT and ALLOW AUTO UPDATE focused the controls (screen y 747 and 687), but the page did not scroll, so neither row is in the capture. Whether search should scroll its target into view is an open question, not a filed defect | `20261113T024626-x7b241/captions` |

Two more driver corrections: `bench_switch.py` accepts either the visible status-line refusal or the logged refusal and records both (both were seen); a new `bench-prompts-check` phase was added to `bench_years.py`, and a `bench-prefs-captions` capture phase to `bench_preferences.py`.
