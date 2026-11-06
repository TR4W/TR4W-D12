# What NY4I still has to check in BENCH_QUEUE.md

Generated 2026-11-01 from `docs/BENCH_QUEUE.md` (423 open items at the time), for the 5.x
release gates in `docs/RELEASE_ROADMAP_5X.md`. Line numbers are lines in
`BENCH_QUEUE.md` as it stands after the 2026-11-01 edit, so open the queue at that line for the full
steps. Tick the item **in the queue** when you confirm it (the queue's rule: an item leaves only
when NY4I confirms it); this file is a view, not a second record.

**How the items were sorted.** Each open item was read and assigned a release gate and a kind:
**you** (you can do it at the keyboard with a build you have) or **hw** (it needs particular hardware
or a second machine; the note names it). The notes were written in bulk per section by read-only
agents, so treat a note as a pointer, not a verdict. Where a gate says *Windows*, the Linux and
macOS builds do not need to be touched.

| Gate | Items | |
|---|---|---|
| G9 | 12 | Linux and macOS: the tests under way now |
| G2 | 44 | A contest logged start to finish on the SQLite path |
| G1 | 27 | Upgrade from 4.x: old ini, old contest .cfg, real .TRW log |
| G3 | 2 | Clean machine: install, first run, uninstall |
| G6 | 2 | Destructive defaults: Yes/No prompts, Escape, Cancel |
| G5 | 68 | Scoring and contest rules |
| G4 | 9 | Second operator and two-radio (SO2R) operator |
| G7 | 77 | Multi-op network |
| G8 | 1 | Release mechanics |
| D, L | 177 | Disclose-only or can follow after release (appendix) |

**Withdrawn as stale (4):** queue lines 2748, 2874, 3185, 4190. Nothing to check.

---

## G9. Linux and macOS: the tests under way now

**Added 2026-10-29 -- EVERY CATEGORY-* MAY BE BLANK (NY4I)**

- [ ] `106` (hw) Windows, Linux (gtk2) and macOS: open each drop-down. Is the blank item at the END of the list visible and selectable (not a zero-height... -- needs: Needs gtk2 Linux and macOS widget sets to judge the blank drop-down item; Windows part is OWNER.

**Added 2026-10-31 -- THE OS VAULT ON macOS AND LINUX (WRL key, HamScore and server passwords)**

- [ ] `4933` (hw) Store, restart, read. Enter a WRL API key, save, quit. The startup line says libsecret1 (available). Restart: the WRL logger editor shows th... -- needs: Linux Mint libsecret store/restart/read.
- [ ] `4937` (hw) Change and clear. Change the key and restart: the new one is read. Clear it and save: the entry is gone from Seahorse. -- needs: Linux change and clear key in Seahorse.
- [ ] `4939` (hw) A locked collection. Lock the Login keyring in Seahorse, then save a changed key. The desktop asks to unlock. Unlock: it stores. Dismiss:... -- needs: Linux locked keyring dismissed prompt; record exact log.
- [ ] `4946` (hw) Autologin (keyring locked at start). With a key stored, log in through autologin so the Login keyring stays locked, and start TR4W. The s... -- needs: Linux autologin locked keyring; relies on 2026-11-01 uKeychain fix (commit 21ff8392).
- [ ] `4958` (hw) Headless / no Secret Service. Run from an ssh session with no DBUS_SESSION_BUS_ADDRESS (or with gnome-keyring stopped). TR4W must start,... -- needs: Linux headless, no Secret Service; time first save.
- [ ] `4963` (hw) No libsecret at all (a VM without libsecret-1-0): one warning naming libsecret-1.so.0, the startup line says UNAVAILABLE, and nothing els... -- needs: Linux VM without libsecret-1-0.
- [ ] `4966` (hw) The AppImage and the tarball both. The AppImage bundles glib; check that the HOST's libsecret loads beside it (the startup line says avai... -- needs: AppImage and tarball host libsecret loading on Linux.
- [ ] `4973` (hw) Store, restart, read as above. Keychain Access -> login -> Passwords lists TR4W/<path>. No prompt from the signed build. -- needs: macOS signed bundle keychain store/restart/read.
- [ ] `4975` (hw) Update to the next signed release and read. Store with release N, install N+1, start: the key is read with NO "wants to use your confiden... -- needs: macOS update to next signed release, no prompt; needs two signed releases.
- [ ] `4979` (hw) A locked keychain. Lock the login keychain (Keychain Access -> File -> Lock Keychain "login"), then save a changed key. macOS asks to unl... -- needs: macOS locked login keychain.
- [ ] `4983` (hw) Clear removes it from Keychain Access. -- needs: macOS clear removes entry in Keychain Access.

## G2. A contest logged start to finish on the SQLite path

**Added 2026-10-29 -- EVERY CATEGORY-* MAY BE BLANK (NY4I)**

- [ ] `110` (you) Edit Cabrillo Summary: choose blank for OVERLAY, TIME and STATION, close, reopen. Each still shows blank (it used to keep the previous va...
- [ ] `112` (you) Same window: choose blank for POWER with QSOs logged. The log rescores (blank power scores as HIGH in every power-multiplier contest), an...
- [ ] `115` (you) New Contest: choose blank for CATEGORY-POWER and CATEGORY-ASSISTED, create the contest, export Cabrillo: CATEGORY-POWER: and CATEGORY-ASS...
- [ ] `121` (you) Note: a station that never stored STATION, TIME, TRANSMITTER or OVERLAY in the summary window now gets bare lines for them. Absent and "n...

**Added 2026-10-26 -- THE CABRILLO IS NAMED AFTER THE LOG (NY4I)**

- [ ] `711` (you) The three names sort together. Open a real contest log, e.g. CQ-WW-SSB 2026-10-19 NY4I.db. File > Export ADIF, then Create Cabrillo. EXPE...
- [ ] `716` (you) SCP uploads the new file. Answer Yes to the upload prompt after Create Cabrillo. EXPECT the log line ...NY4I.log file uploaded to SCP nam...

**Added 2026-10-26 -- THE NEEDS STRIPS AFTER A QSO IS LOGGED (issue #100)**

- [ ] `807` (you) A new multiplier drops its band from both strips. CQ WW, S&P: type a station in a country not yet worked, press Enter, log it on 20 m. EX...
- [ ] `811` (you) Tail-ending keeps the NEXT call. In a run, tail-end: with the next station's call already in the strips, let the previous QSO log. EXPECT...

**Added 2026-10-25 -- THE PERIODIC BACKUP AND BACKUP DESTINATION (issue #98 step 2)**

- [ ] `863` (you) The local backup moved. With BACKUP LOG FREQUENCY = 5, log five QSOs. EXPECT settings\backup\<log> periodic.db (beside tr4w.json), the st...
- [ ] `874` (you) A copy arrives. Five more QSOs. EXPECT <log> periodic.db in the share, and no .partial left there; then .bak beside it after the next.
- [ ] `876` (you) The status line says where it went (2026-10-25, after NY4I read the local file's name as "the destination was ignored"). With the destina...
- [ ] `884` (you) The share goes away. Unplug or unshare it, log five QSOs. EXPECT ONE status-line message and a beep ("Backups are NOT reaching ..."), one...
- [ ] `889` (you) A hung share at exit. With a copy in progress to a slow or hanging share, close TR4W. EXPECT it to close within about two seconds, with [...
- [ ] `892` (you) Caught up at start. Make the share unreachable, log five QSOs, close, restore the share, start TR4W. EXPECT the periodic backup copied at...

**Added 2026-10-18 -- AN ADIF IMPORT GIVES QSOs THIS CONTEST'S STATION, AND ASKS WHEN THE FILE NAMES ITS OWN (lo**

- [ ] `1172` (you) Import the file with no MY_ tags. EXPECT: no question; the final report ends "N QSO(s) named no station of ours and were given this conte...
- [ ] `1176` (you) Import the JO65 file. EXPECT: before anything is written, a Yes/No naming "MY_GRIDSQUARE", the record count, and a line MY_GRIDSQUARE: N...
- [ ] `1180` (you) Answer Yes. EXPECT: Edit QSO shows JO65, and the score is the one JO65 gives (measured headless: 522 against 231 for ARRL Digi's reference).
- [ ] `1183` (you) Answer No (on a fresh log). EXPECT: Edit QSO shows EL88.
- [ ] `1184` (you) A file whose MY_ values match the contest's. EXPECT: no question, only "...the same as this contest's." in the report.

**Added 2026-10-14 -- THE ADIF IMPORT IS ALL OR NOTHING, AND SAYS SO**

- [ ] `1575` (you) Import the bad file into a log that already has QSOs. A warning dialog says NOTHING was imported, names the record (record N of M (no CAL...
- [ ] `1581` (you) Then log a QSO by hand. It logs: a rolled-back import no longer stops the log (only a rollback that itself fails does -- see docs/SQLITE_...
- [ ] `1585` (you) Import a good file. The quick-command line shows N Qs imported. as before, the log window fills once, and on a large file (a few thousand...
- [ ] `1589` (you) Import a file with a stray non-record line after the header (any text with no <EOR>). It imports, and a warning names how many lines were...

**Added 2026-10-13 -- A STATION FACT CHOSEN AT NEW CONTEST IS THAT CONTEST'S ONLY (design 7.12)**

- [ ] `1752` (you) Log one QSO, close, and reopen the European HFC log. Export Cabrillo. The sent column carries 3, because the log carries the override. Al...

**A. New Contest dialog is now an LCL form (16ffc284)**

- [ ] `2724` (you) Resize the window -- list and fields follow, buttons stay bottom-right.

**Added 2026-08-26 (overnight) -- UNRUN**

- [ ] `2761` (you) The Windows menu and its accelerator now CLOSE a converted window. Previously the second press did nothing: the toggle called CloseTR4WWi...

**9. Edit QSO (uEditQSOForm) -- THE ONE THAT WRITES TO THE LOG**

- [ ] `2954` (you) A LONG CALLSIGN SURVIVES. Cannot be tested by TYPING (NY4I, 2026-08-20: "It is not possible to enter a callsign greater than 12 character...

**27. Band map step 1: the model, before any form exists**

- [ ] `3400` (you) A logged QSO still turns its spot into a dupe, and clearing the dupe sheet still un-dupes them.

**30. Application.Run -- THE PIVOT. Test this harder than anything before it**

- [ ] `3513` (you) Shutdown. HamScoreShutdown moved into tr4w_ShutDown. It was a finally below the message loop, which could never have run: TR4W exits thro...

**31. The dupe sheet is a form and a TDrawGrid (uDupeSheetForm)**

- [ ] `3535` (you) The title, on a REOPEN. Open a dupe sheet, close it, open it again. Both times it must read Radio 1 Dupesheet - 10m-CW. The first open wa...

**37. THE MAIN WINDOW'S FORTY-TWO ELEMENTS ARE LCL CONTROLS — test this like section 30**

- [ ] `3670` (you) The exchange field CLEARS when the operating mode changes (Ctrl-Enter between CQ and S&P with something typed in it).

**42. Accelerators no longer reach past a modal dialog**

- [ ] `3826` (you) ESC closes a dialog and the main window does NOT react. Try several: Preferences, Edit QSO, Send Spot, the message editor.
- [ ] `3828` (you) TAB moves between controls inside a dialog and does NOT put the main window into search-and-pounce.
- [ ] `3830` (you) ACCELERATORS STILL WORK FROM A MODELESS TOOL WINDOW. This is the half that must not have been broken by the fix: with focus in the band m...
- [ ] `3836` (you) And they still work from the main window itself.

**BENCH RUNS -- no automated gate reaches any of this**

- [ ] `4337` (you) Log a contest, properly. Work a run of QSOs, watch the editable log fill, check the totals and the dupe sheet. The whole write path chang...
- [ ] `4342` (you) Alt-Y, twice. Delete the last contact and restore it. It reads the newest QSO through the seam instead of seeking back one record, and wr...
- [ ] `4346` (you) Edit a QSO in a log LONGER than the editable-log window. This is the one I would run first. The editable-log selection arithmetic was bro...
- [ ] `4354` (you) Open the log window twice in one session. A reload used to append to the list instead of rebuilding it -- caught by Lint-Win32Dialogs cou...
- [ ] `4358` (you) Search the log, then edit a result. Search results carry a record INDEX now, not a byte offset.
- [ ] `4365` (you) CREATE A NEW CONTEST. The highest-risk item in this batch, because contest creation has NO automated coverage of any kind -- the corpus i...

**Contest factory -- state QSO parties (added 2026-09-29)**

- [ ] `4748` (you) An edited memory survives a restart (Q113, 5.0.29). Open a contest, edit a CQ memory, an EX memory and an Alt-key memory (Alt-P), change...

**Issue #1 -- tool windows are no longer owned by the main window (2026-10-29)**

- [ ] `4794` (you) Click the main window and it rises. Overlap the band map, Telnet and a radio panel with the main window, then click the main window. It c...
- [ ] `4797` (you) Click a tool window and it rises above the main window and above the other tool windows.

## G1. Upgrade from 4.x: old ini, old contest .cfg, real .TRW log

**Added 2026-10-29 -- EVERY CATEGORY-* MAY BE BLANK (NY4I)**

- [ ] `119` (you) A contest whose header stated CATEGORY-OVERLAY: CLASSIC before this build still writes it.

**Added 2026-10-25 -- THE PERIODIC BACKUP AND BACKUP DESTINATION (issue #98 step 2)**

- [ ] `868` (you) Your setting carried over. Your tr4w.json says BackupFileName: "logback.db". EXPECT Preferences' "Copy to:" EMPTY (a bare name meant besi...

**Added 2026-10-23 -- RTC 2026 RULES AND THE CLEARER IMPROPER-QTH MESSAGE**

- [ ] `945` (you) Opening a log uses ITS OWN MY STATE. With the station's MY STATE FL, open a QSO party log made at a host county (the Michigan corpus log,...

**Added 2026-10-23 -- HAMSCORE RE-EMITS A STORED QSO FROM ITS RECORD (issue 95, review R6, Q13)**

- [ ] `981` (you) A log from before this build (a QSO row that never recorded its station -- a log written before schema 3, or migrated from a .TRW): resyn...

**Added 2026-10-14 -- SEVEN CONTEST SETTINGS RETIRED (M10 S2, NY4I's Q4)**

- [ ] `1671` (you) Open a contest log written before 2026-10-01 (any corpus log.db copied somewhere writable will do). tr4w.log carries ONE line [LogStore]...
- [ ] `1677` (you) A contest .cfg that still says QSO POINT METHOD = ... (or any of the seven) loads with no dialog and one [Config] QSO POINT METHOD = ......

**This one needs a release note, not just a bench run**

- [ ] `2507` (you) This one needs a release note, not just a bench run

**Stable ids -- three stores changed, NONE bench-verified**

- [ ] `2651` (you) Open an existing station and confirm nothing moved: the migration runs once, silently, on the first load with this build.

**18. Upgrading a 4.x station -- its settings arrive from tr4w.ini, once**

- [ ] `3154` (you) Accept the conversion, then restart. Settings you had are in force and survive the restart -- try a drop-down (ROW COUNT), an integer (AU...
- [ ] `3158` (you) HOUR DISPLAY, RATE DISPLAY, DUPE CHECK SOUND: set each in Preferences, confirm it takes effect and survives a restart. [AGENT (NY4I, earl...
- [ ] `3163` (you) The band plan. tr4w.log reads [BandPlan] seeded N band(s) from tr4w.ini, and the seeded values land on the RIGHT bands -- the seed re-der...
- [ ] `3171` (you) A contest wins over the station. A contest .cfg carrying FREQUENCY MEMORY lines, or naming a Cabrillo category such as CATEGORY-POWER, is...
- [ ] `3175` (you) Load a few real old contest .cfg files: no "Invalid statement in config file" dialog, and no new [Config] ... was REFUSED lines.
- [ ] `3181` (you) tr4w.log should be quiet. [ApplyStoredCommands] CFGCA refused "X" = "Y" names a stored value TR4W would not accept. Worth one grep after...

**23. TR4W offers to remove tr4w.ini -- once -- and the first resourcestring**

- [ ] `3269` (you) On a station WITH a tr4w.ini: start TR4W. The prompt should appear once, after the window is up -- and only when the first-run conversion...
- [ ] `3276` (you) Then flip that back to false by hand, restart, and say Yes. The file should be gone and a confirmation shown. No .bak is made -- that is...
- [ ] `3279` (you) Restart again with everything you had set -- radios, colors, band plan, DE ENABLE, auto-send count. All of it must survive the ini being...

**24. WinKeyer -- the menu now lands on it, and an upgrading station gets its keyer back**

- [ ] `3326` (you) On a station that had a WinKeyer configured before today: start TR4W and look for [Keyers] seeded "WinKeyer" from the legacy WinKeyer set...
- [ ] `3329` (you) Open it and check every value against what you had -- port, keyer mode, sidetone frequency, weight, dit/dah ratio, lead-in, tail, first e...
- [ ] `3332` (you) It seeds ONCE, into an EMPTY library only. Restart again: there must still be exactly one keyer, not two.
- [ ] `3334` (you) A station that never enabled a WinKeyer must get an empty list -- not a phantom device it has to work out how to delete.
- [ ] `3336` (hw) Then key some CW. The seed writes the device; ApplyKeyerToWinKey reads it back on the next start, so this is the round trip that matters. -- needs: Key CW through seeded WinKeyer: needs a WinKeyer device.

**31. The dupe sheet is a form and a TDrawGrid (uDupeSheetForm)**

- [ ] `3552` (you) Retirement of COLUMN DUPESHEET ENABLE. Setting it in a .cfg or tr4w.ini must still LOAD WITHOUT AN ERROR (it is a retired command, uCFG.R...

**DECISIONS FIRST -- these are yours, not bench runs**

- [ ] `4200` (you) THE LOG NOW OVERRIDES settings\tr4w.json FOR CONTEST SETTINGS. csJSON means the JSON store owns a row, which is right for a STATION setti...

**BENCH RUNS -- no automated gate reaches any of this**

- [ ] `4290` (you) The two file choosers are TOpenDialog now. Open a contest configuration (Commands -> Execute configuration file) and import an ADIF. Chec...
- [ ] `4361` (you) Migrate a real 4.x log. Point this build at a contest whose .TRW you care about and confirm every QSO arrives. It happens ONCE, silently,...
- [ ] `4395` (you) OPEN AN EXISTING .cfg CONTEST AND CONFIRM IT MIGRATES. The dialog lists .db files, plus any .cfg that has no .db beside it -- which is ho...

## G3. Clean machine: install, first run, uninstall

**23. TR4W offers to remove tr4w.ini -- once -- and the first resourcestring**

- [ ] `3285` (you) A station with no tr4w.ini must never see the prompt.

**37. THE MAIN WINDOW'S FORTY-TWO ELEMENTS ARE LCL CONTROLS — test this like section 30**

- [ ] `3631` (you) Everything is there, in the right place, at the right size. Compare against a screenshot of the previous build if you have one. The posit...

## G6. Destructive defaults: Yes/No prompts, Escape, Cancel

**B. YesOrNo lost its HWND at 16 call sites (384d1895)**

- [ ] `2733` (you) Every Yes/No prompt still defaults to No. Press Enter on "do you really want to clear the log" and it must NOT clear. This is the one to...

**Added 2026-10-29 -- HAMSCORE "RE-SEND LOG" ASKS BEFORE IT DELETES (NY4I, RTC test)**

- [ ] `4849` (you) Enter and Escape both Cancel. Open the dialog, press Enter: nothing is queued and the status line does not say "queueing". Same for Escap...

## G5. Scoring and contest rules

**Added 2026-10-27 -- THE QUEBEC QSO PARTY (issue #128)**

- [ ] `564` (you) The New Contest dialog. Choose the Quebec QSO Party: EXPECT the MY STATE comment asks for the administrative region code (e.g. MTL), not...
- [ ] `569` (you) In Quebec (MY STATE MTL). 599 QUE is Capitale-Nationale (a region), not Quebec; 599 QC and 599 VE2 are refused. 599 NF then 599 LB: TWO m...
- [ ] `575` (you) Out of Quebec (MY STATE NY). 599 MTL takes; 599 NY and a DX station's 599 DX are refused with "work QC stations only". W2ABC/VE2 599 GIM...
- [ ] `579` (you) A region line. 599 MTL/LVL logs two QSOs; 599 MTL/LVL/LNS is refused (two regions -- the French rules' "deux zones"; the English says "2...
- [ ] `582` (you) No 160 m. A 160 m QSO is logged as an X-QSO (X-QSO: in the Cabrillo), scoring nothing.
- [ ] `584` (you) The Cabrillo file. CONTEST: QC-QSO-PARTY; a DX entrant (no MY STATE) sends 599 DX (not its prefix); FM is FM. The ADIF carries STATE QC f...
- [ ] `587` (you) File > Reports > 3830 Score from a real log: one Mults column (no 3830 form was found for this contest).

**Added 2026-10-26 -- THE ONTARIO QSO PARTY (issue #127)**

- [ ] `600` (you) The New Contest dialog. Choose the Ontario QSO Party: EXPECT the MY STATE comment asks for the Ontario county code (e.g. TOR), not "if yo...
- [ ] `605` (you) In Ontario (MY STATE TOR). Type 599 MAN for VE3xxx: EXPECT the multiplier is Manitoulin (MAN), not Manitoba; 599 MB is Manitoba, a second...
- [ ] `611` (you) The club stations. VE3CCO, VA3CCO, VE3ODX, VA3RAC, VE3RHQ score 10, also as VE3CCO/TOR (the rover strip); VE3CCO/M scores 2.
- [ ] `613` (you) A county-line junction. 599 TOR/YRK/PEL/DUR/HTN logs five QSOs, one per county; nothing is refused (no maximum).
- [ ] `615` (you) The Cabrillo file. EXPECT the writer refuses to start without LOCATION (the sponsor scores in/out of province from ARRL-SECTION: ONN, ONS...
- [ ] `620` (you) File > Reports > 3830 Score from a real log: one Mults column (no 3830 form was read for this contest).

**Added 2026-10-26 -- THE NEW MEXICO QSO PARTY (issue #125)**

- [ ] `631` (you) In New Mexico (New Contest, MY STATE BER). Type 599 DC for W3DC: EXPECT the multiplier shown is MD; 599 NM: a new multiplier (NM is one o...
- [ ] `636` (you) The Cabrillo file (summary window: CATEGORY-POWER, LOCATION NM). EXPECT the writer refuses to start without LOCATION; LY2ZZ's line ends 5...
- [ ] `641` (you) A DX entrant (MY CALL LY2xxx, no MY STATE): EXPECT the CQ exchange is 5NN LY (what goes on the air), the ADIF STX_STRING carries LY, and...
- [ ] `644` (you) W1AW/5. Work W1AW/5 from two counties on one band and mode: two QSOs, the bonus 250 once. Logged as W1AW/5/BER it is NOT paid today -- th...
- [ ] `647` (you) A county line of two. 599 SOC/SIE logs two QSOs; three counties are refused.

**Added 2026-10-26 -- THE OKLAHOMA QSO PARTY (issue #126)**

- [ ] `658` (you) In Oklahoma (New Contest, MY STATE MUS). Type 599 DC for W3DC: EXPECT it is taken and the multiplier shown is MD ("DC counts as Maryland"...
- [ ] `664` (you) A mobile on a four-county line. In Oklahoma, enter 599 PIT/LAT/HAS/LEF for one call: EXPECT FOUR QSOs in the log, one per county, each sc...
- [ ] `668` (you) A DX entrant (MY CALL DL1xxx, no MY STATE): EXPECT the CQ exchange is 5NN DL, and the Cabrillo QSO lines and the ADIF STX_STRING carry DL...
- [ ] `672` (you) Digital. A JS8 or PSK QSO scores 3; an FT8 or FT4 QSO is a greyed X-QSO. CW and PSK with the same station on one band are two QSOs.
- [ ] `674` (you) The Cabrillo header. The rules ask for one custom CATEGORY: OKLAHOMA MOBILE ... line; TR4W writes CATEGORY-* tags. Check okqp.contesting....
- [ ] `677` (you) File > Reports > 3830 Score from a real log: one Mults column, as the 3830 form has (checked against the 2026 breakdown page).

**Added 2026-10-23 -- RTC 2026 RULES AND THE CLEARER IMPROPER-QTH MESSAGE**

- [ ] `918` (you) RTC, same station twice on one band. Work DL1xxx on 20 m CW, then on 20 m SSB. EXPECT the SSB QSO is NOT a dupe and earns its distance po...
- [ ] `923` (you) Georgia, as an out-of-state entrant (MY STATE outside GA), type 599 CT for W1AW. EXPECT the message reads Improper domestic QTH!! (CT: wo...
- [ ] `928` (you) A stated MY COUNTRY no longer shows on screen in a refusal (it did as (MY COUNTRY = K) in several QSO parties); it is still in tr4w.log....
- [ ] `931` (you) ARRL Field Day, a bad section. Type 2A WSX for W1AW. EXPECT Invalid ARRL Section (WSX not in arrlsect.dom) (46 characters), the caret aft...
- [ ] `935` (you) RTC, serial 0 is refused everywhere. Type 0 FN31: EXPECT QSO number 0 is not valid in this contest., the caret after 0, and nothing logge...
- [ ] `941` (you) Q119, an out-of-area QSO that reaches the log is an X-QSO. With MY STATE outside Georgia, import (or receive from a peer) a GA QSO Party...

**Added 2026-10-22 -- THE AUTOMATIC X-QSO (Q98 S1) AND CQ WW'S BANDS AND MODES**

- [ ] `1021` (you) A CW QSO in CQ WW SSB (switch the radio or mode to CW, log a DX station on 20 m). EXPECT: it is logged; its row in the log window is GREY...
- [ ] `1029` (you) An off-band QSO (log a phone QSO on 17 m, 12 m or 6 m). EXPECT the same: greyed, 0 points, no multiplier, not a dupe of anything, no "new...
- [ ] `1032` (you) Edit the band of that QSO to 20 m (Edit QSO). EXPECT the row turns ordinary and the score includes it after the rescore -- nothing was st...
- [ ] `1037` (you) Export: the Cabrillo writes X-QSO: for those lines and the CLAIMED-SCORE leaves them out; the ADIF carries <APP_TR4W_CLAIMEDQSO:1>0 on th...
- [ ] `1040` (you) Summary sheet (post-contest): QSO totals and points leave them out.
- [ ] `1041` (you) Reopen the log: totals, multipliers and the greyed rows are the same as before closing.

**Added 2026-10-18 -- A STATE QSO PARTY: A NEW COUNTY FROM THE SAME PLAIN CALL IS A NEW QSO (Q118, 91d6bc34)**

- [ ] `1201` (you) Log plain W2TZ sending KIN. It logs and scores.
- [ ] `1202` (you) Type W2TZ again, same band and mode. EXPECT: the call window shows DUPE -- that is the ruling, not a defect.
- [ ] `1204` (you) Enter STE as the exchange and log it. EXPECT: it is accepted, is not marked a dupe, and scores (2 points on CW).
- [ ] `1206` (you) W2TZ with KIN again. EXPECT: a dupe, scoring 0.
- [ ] `1207` (you) Rescore (Tools > Rescore). EXPECT: the same marks -- KIN and STE counted once each, the second KIN a dupe -- and the same score.
- [ ] `1209` (you) On 40 m, W2TZ is not a dupe in the call window at all.

**Added 2026-10-18 -- AN FM QSO NO LONGER CORRUPTS ITS CALL ON RESCORE (pointer audit P8 part A, 433c047f)**

- [ ] `1224` (you) Rescore (Tools > Rescore).
- [ ] `1225` (you) Open the dupe sheet (Alt-D) on the band and mode the FM QSOs were made on, and on phone. EXPECT: every call reads exactly as logged -- no...
- [ ] `1228` (you) Open the remaining-multiplier windows. EXPECT: the multipliers worked and needed are what they were before the rescore.
- [ ] `1230` (you) EXPECT: the score and multiplier counts are unchanged, and working an FM-logged station again on phone, same band, is a dupe.
- [ ] `1232` (you) Exit TR4W: nothing in tr4w.log at Error level from the rescore.

**Added 2026-10-17 -- BATCH C RULINGS (Q9, Q32, Q37, Q73, Q81)**

- [ ] `1326` (you) Missouri's peak-hour bonus survives reopening (Q32). In a Missouri log, log a few 40 or 80 m QSOs with a logged time between 1400 and 195...
- [ ] `1331` (you) A malformed grid has no distance (Q37). In WWL or the Stew Perry, a logged QSO whose grid is not a grid (import one, or edit one to FN3)...
- [ ] `1336` (you) A county rover is its own station (Q73). In the Florida QSO Party, work NY4I/PIN, then type NY4I/HIL: the call window does NOT say dupe,...
- [ ] `1340` (you) New England's county spellings (Q81). Out of New England, the New England QSO Party accepts MEAND, CTCAP and the old ANDME; of the eight...

**Added 2026-10-17 -- BATCH B SCORING RULINGS (Q38, Q45, Q49, Q71, Q84, Q85, Q104)**

- [ ] `1357` (you) IN7QPNE is refused at New Contest for an in-area station (Q104). Pick IN7QPNE and type each of IN, UT, ME, DE (and one county, e.g. INADA...
- [ ] `1370` (you) A 160 m contest scores nothing off 160 m (Q71). In RSGB 1.8 MHz, ARRL 160 or CQ 160, log one QSO on 80 m: it is logged, scores 0, earns n...
- [ ] `1374` (you) Winter Field Day shows no DXCC multipliers (Q38). The remaining-DX window and the multiplier totals show none; the score is unchanged.
- [ ] `1376` (you) EUDX from outside the EU (Q45). A W station working a European who sends a ZONE scores 5 (3 on our continent, 2 for our own country), not...

**Added 2026-10-14 -- THE EXCHANGE RULES ASK THE CONTEST (M11 S7)**

- [ ] `1550` (you) Rover call, Michigan QSO Party (out of state): type KG1S/MON and Enter with the exchange empty. The county MON is copied into the exchang...
- [ ] `1553` (you) Rover call, ARRL DX CW from a non-W/VE call (e.g. MY CALL DL1xx): the same /county strip happens; from a W or VE call it does NOT (the ex...

**Added 2026-10-14 -- COUNTY-LINE IMPORT ASKS THE CLASS (M10 S7)**

- [ ] `1653` (you) Import a real Michigan QSO Party ADIF holding a repeat (same call, band and mode, a DIFFERENT county). Since Q118 (4c5c0a6b, kept in 91d6...
- [ ] `1658` (you) Import a county-line ADIF for one of Arizona, BC, Virginia, the Salmon Run or New York (same call/band/mode, two counties). The second co...

**36. All five remaining-multiplier windows are forms (uRemMultsForm)**

- [ ] `3598` (you) Worked multipliers fade, needed ones are plain. In HILIGHT mode all multipliers are listed and worked ones are gradiented to white with w...

**DECISIONS FIRST -- these are yours, not bench runs**

- [ ] `4211` (you) DOES TR4W REFUSE A QSO ITS CONTEST DOES NOT ALLOW, OR LOG IT AT ZERO? A contest-factory decision, surfaced by comparing against TR4QT. TR...

**Contest factory -- state QSO parties (added 2026-09-29)**

- [ ] `4692` (you) Florida QSO Party now refuses a three-county exchange. Type 599 PIN/HIL/CIT into the exchange window in FQP. Expected: the exchange is re...
- [ ] `4701` (you) Michigan QSO Party now refuses ANY county-line exchange. 599 WAYN/OAK must be refused; 599 WAYN must log normally. Michigan's rules: "No...
- [ ] `4707` (you) California QSO Party now refuses a FIVE-county exchange. NY4I set the maximum at four -- "4 since that is the intersection of 4 counties...
- [ ] `4714` (you) Indiana QSO Party now refuses a THREE-county exchange. Maximum two, per NY4I. Two must still log two QSOs sharing one serial.
- [ ] `4724` (you) Every QSO party WITHOUT an established maximum must be UNCHANGED. Spot-check one of the eight above with four counties; it must log four,...
- [ ] `4732` (you) A contest that is NOT a QSO party must not be asked at all. Arktika Spring, ARRL Digital and ARRL Field Day each have a class now and non...
- [ ] `4739` (you) ADIF STATE is the WORKED station's, decided per QSO by the contest class (Q76/Q89, 35986731): a party county gives its state, a state or...

## G4. Second operator and two-radio (SO2R) operator

**Added 2026-10-26 -- K4 TX TEST MODE IS SHOWN ON A KEY-UP (issue #97 phase 2)**

- [ ] `762` (hw) SO2R, keyers swapped (issue #97 review). Two radios on CW-by-CAT, radio 2 in test mode, send to the inactive radio (Ctrl-A or a dueling C... -- needs: Two radios on CW-by-CAT, SO2R keyers swapped; K4 TX test.

**Stable ids -- three stores changed, NONE bench-verified**

- [ ] `2646` (you) Rename a radio in Preferences and confirm the active profile keeps it. This is the case that failed and started all of it.

**31. The dupe sheet is a form and a TDrawGrid (uDupeSheetForm)**

- [ ] `3548` (hw) Two dupe sheets at once, both correct. This is the first converted window with more than one instance. Open both, work a station on each... -- needs: Two dupe sheets need two radios (or a simulator) for SO2R.

**44. The radio panels are LCL forms -- and colour used to mean state**

- [ ] `3845` (hw) Both VFO rows track the rig, on Radio 1 and Radio 2, and the RIT figure and both mode labels with them. These five writes were raw cross-... -- needs: Needs a rig on Radio 1 and Radio 2 (two radios for full check).
- [ ] `3849` (hw) The INACTIVE VFO row is greyed. 102/104 really do mean enabled/disabled, and a TLabel greys natively. -- needs: Needs a rig; inactive VFO row greying.
- [ ] `3851` (hw) RIT / XIT / SPLIT go YELLOW when the rig has them on. THIS IS THE ONE TO WATCH. The dialog got the colour by returning a yellow brush fro... -- needs: Needs a rig with RIT/XIT/split on; no-radio grey case already confirmed 2026-08-20 (F7).
- [ ] `3858` (hw) The ACTIVE radio's panel is tinted light blue, and the tint MOVES when the active radio changes. That was two InvalidateRect calls in LOG... -- needs: Needs two radios to see the tint move with the active radio.
- [ ] `3864` (you) Both panels remember their position across a close and reopen, and across a restart (the BoundsRect fix, section 43).
- [ ] `3866` (you) Escape closes each panel, which a DialogBox gave away free.

## G7. Multi-op network

**MULTI-OP PHASE 1: ONE BENCH SESSION, IN THIS ORDER (2026-10-27)**

- [ ] `88` (hw) Intercom and spot form. Net > Send message from A (EXPECT it at B), and the Send Spot form with no cluster connected at A (EXPECT B's cluster command gets the text). (The time-sync row was removed 2026-11-03; an older station's time sync being skipped is its own item in BENCH_QUEUE.) -- needs: Needs a second station B receiving the intercom and spot form.
- [ ] `92` (you) Nothing refused. tr4w.log at either station has no REFUSED to send a malformed packet line. If one appears it names the id and size of a...

**Added 2026-10-29 -- SHARE DX SPOTS AROUND THE NETWORK (NETWORK SHARE SPOTS)**

- [ ] `147` (hw) Gateway ON, peer ON: a spot from the gateway's cluster appears in the peer's band map within a second; the peer does not post it back (th... -- needs: Needs gateway with cluster plus a second peer station on one server.
- [ ] `150` (hw) Turn the PEER's box off while connected, no restart: the next gateway spot does not reach the peer's band map; tr4w.log at Debug has spot... -- needs: Needs gateway with cluster plus a second peer station on one server.
- [ ] `154` (hw) Turn it back on: the next spot arrives. -- needs: Needs gateway with cluster plus a second peer station on one server.
- [ ] `155` (hw) Gateway OFF, peer ON: spots from the gateway's cluster do not reach the peer; the gateway's own band map still shows them. -- needs: Needs gateway with cluster plus a second peer station on one server.
- [ ] `157` (hw) Both stations on their own cluster, both ON: each spot arrives twice at each station (its own and the other's). Expected, not a bug: the... -- needs: Needs gateway with cluster plus a second peer station on one server.
- [ ] `160` (you) The Preferences > Network page: the new checkbox sits under "Connect to the multi-op server when TR4W starts", the grey hint and the "Rad...

**Added 2026-10-28 -- A SERVER THAT LOST ITS LOG (the restock; Phase 1 gap found on the bench)**

- [ ] `221` (hw) The question, one only (setting OFF). Repeat the first item with the setting off. EXPECT: ONE question, "The server lacks 83 QSO(s) of yo... -- needs: Multi-op restock/sync; needs stations A and B (Windows plus Mint) and a restartable server.
- [ ] `230` (hw) The server's log is cleared while the stations keep theirs. With A and B connected and holding the same 20 QSOs, clear ONLY the server's... -- needs: Multi-op restock/sync; needs stations A and B (Windows plus Mint) and a restartable server.
- [ ] `242` (hw) A mid-send drop repairs itself. With 1,000+ QSOs at A and a fresh empty server, Connect and pull the cable (or stop the server) while it... -- needs: Multi-op restock/sync; needs stations A and B (Windows plus Mint) and a restartable server.
- [ ] `247` (hw) The server keeps them across a restart. After the first item stop S2 and start it again in the same directory (both servers). EXPECT the... -- needs: Multi-op restock/sync; needs stations A and B (Windows plus Mint) and a restartable server.
- [ ] `250` (hw) Imports and owed rows are left alone. Import an ADIF of 5 QSOs at A (no network identity), log 2 QSOs with the link down, then connect to... -- needs: Multi-op restock/sync; needs stations A and B (Windows plus Mint) and a restartable server.
- [ ] `256` (hw) Mint. Repeat the first, third and sixth items with the Mint build as the station holding the QSOs (B in that item), against tr4wserver an... -- needs: Needs Linux Mint station; also gtk2 button clipping.
- [ ] `261` (hw) The in-tree server stays up under a large restock. One of five in-tree runs on 2026-10-28 lost the server process about 7 s into a 5,000-... -- needs: 5,000-QSO restock against in-tree tr4wserver; issue 149; needs two machines to observe.

**Added 2026-10-27 -- A STATION THAT COMES UP LATE CATCHES UP FROM THE SERVER (Phase 1, C6)**

- [ ] `301` (hw) The reboot (the NY4I scenario). Connect A and B; log 2 QSOs at A so both have them. QUIT TR4W at B. Log 20 QSOs at A. Start B, open the s... -- needs: Late catch-up needs stations A and B and server; some items need Mint or firewall.
- [ ] `312` (hw) Nothing owed afterwards. tr4w.log at B (DEBUG): still owed to the server: 0 QSO(s), 0 edit(s) -- the 20 arrived marked sent and clean, so... -- needs: Late catch-up needs stations A and B and server; some items need Mint or firewall.
- [ ] `316` (hw) The question (setting OFF). Repeat the reboot with the setting off. EXPECT: B is ASKED "The server holds 20 QSO(s) that this log does not... -- needs: Late catch-up needs stations A and B and server; some items need Mint or firewall.
- [ ] `322` (hw) Net > Add missing QSOs from the server (the window). At B, Net > Add missing QSOs from the server. EXPECT: a window titled Server log; Ge... -- needs: Late catch-up needs stations A and B and server; some items need Mint or firewall.
- [ ] `331` (hw) The backup, and that nothing is replaced. After a catch-up, the backup folder holds a NEW file <log> before catch-up <date time>Z.db (one... -- needs: Late catch-up needs stations A and B and server; some items need Mint or firewall.
- [ ] `341` (hw) A server log that was not cleared. Run CQ WW CW on A and B, log 5 QSOs at A. Without clearing the server, both stations change the contes... -- needs: Late catch-up needs stations A and B and server; some items need Mint or firewall.
- [ ] `356` (hw) A long outage. Log 200+ QSOs at A while B is down, start B. EXPECT: B's window does not freeze during the download (3.76 MB for 10,000 QS... -- needs: Late catch-up needs stations A and B and server; some items need Mint or firewall.
- [ ] `360` (hw) An edit made while B was away. At A, edit the exchange of a QSO B also holds while B is down; restart B and catch up. EXPECT (by design):... -- needs: Late catch-up needs stations A and B and server; some items need Mint or firewall.
- [ ] `365` (hw) The server is reachable but the sync port is not. Block port+1 at the server (firewall), connect B. EXPECT: the link stays up; a notice "... -- needs: Late catch-up needs stations A and B and server; some items need Mint or firewall.
- [ ] `370` (hw) TR4WServerPy and Mint. Repeat the first item against python tr4wserver.py --display, and with B on Linux Mint (its backup folder is under... -- needs: Late catch-up needs stations A and B and server; some items need Mint or firewall.

**Added 2026-10-27 -- A STATION THAT LOST THE LINK CATCHES UP (Phase 1, C5)**

- [ ] `395` (hw) Drop the link, log 5 QSOs, edit 1, reconnect. Connect A and B (Net > Connect). At A: Net > Disconnect. Log FIVE QSOs at A, then edit one... -- needs: Offline resend needs two stations and a server; network cable pull on some.
- [ ] `406` (hw) Nothing is owed afterwards. tr4w.log at A (DEBUG) ends the catch-up with [Net] still owed to the server: 0 QSO(s), 0 edit(s) (no window s... -- needs: Offline resend needs two stations and a server; network cable pull on some.
- [ ] `411` (hw) Reboot variant. With A connected log nothing; Net > Disconnect at A; log 3 QSOs and edit one; QUIT TR4W at A; start TR4W at A, open the s... -- needs: Offline resend needs two stations and a server; network cable pull on some.
- [ ] `417` (hw) A QSO is not "sent" until it is written. With both connected, log a QSO at A and at once pull A's network cable (or kill the server) so t... -- needs: Offline resend needs two stations and a server; network cable pull on some.
- [ ] `424` (hw) An import is never sent. Open a contest log that has imported QSOs (ADIF or an old .TRW), Net > Connect. EXPECT: NO resend notice, nothin... -- needs: Import-never-sent needs a connected server; second station to confirm absence.
- [ ] `427` (hw) A refused station does not push. Start A with COMPUTER ID the same as B's (B connected). EXPECT: A is refused (8320), A's QSOs logged whi... -- needs: Offline resend needs two stations and a server; network cable pull on some.
- [ ] `431` (hw) A long outage. Disconnect A and log a few hundred QSOs at A with the link down (only QSOs LOGGED at A count; an ADIF import does not trav... -- needs: Offline resend needs two stations and a server; network cable pull on some.
- [ ] `436` (hw) Python server. Repeat the first item against TR4WServerPy (python tr4wserver.py --display). EXPECT the same, and the server log says QSOI... -- needs: Offline resend needs two stations and a server; network cable pull on some.

**Added 2026-10-27 -- THE MULTI-OP LINK BELONGS TO THE PROGRAM, NOT THE NETWORK WINDOW**

- [ ] `495` (you) Nothing connects by itself. Start A. EXPECT: no connection attempt in tr4w.log ([Net] not connecting at startup (NETWORK AUTO CONNECT is...
- [ ] `500` (hw) Connect with the Network window CLOSED. Net > Connect at A and at B, never opening the window. EXPECT: the strip reads "Connected to Netw... -- needs: Connect with window closed, QSOs crossing; needs second station B.
- [ ] `503` (hw) QSOs cross with the window closed. Log at A, then at B, then the same call on the same band and mode at both. EXPECT: each arrives at the... -- needs: Connect with window closed, QSOs crossing; needs second station B.
- [ ] `506` (hw) Open the window mid-session. Net > Show Network window (and again from Windows > Network). EXPECT: BOTH stations are in the list at once... -- needs: Connect with window closed, QSOs crossing; needs second station B.
- [ ] `511` (hw) Closing the window drops nothing. Close it (Escape and the close box). EXPECT: still connected, QSOs still cross, the strip still says co... -- needs: Connect with window closed, QSOs crossing; needs second station B.
- [ ] `515` (hw) Disconnect. Net > Disconnect at B. EXPECT: B's strip reads " DISCONNECTED from Network", B's list is empty, A's row for B clears, and B d... -- needs: Connect with window closed, QSOs crossing; needs second station B.
- [ ] `520` (hw) Reconnect. Net > Reconnect at B while connected. EXPECT: a clean drop and a new link, both rows back, no dialog. -- needs: Connect with window closed, QSOs crossing; needs second station B.
- [ ] `522` (you) Auto-reconnect without the window. With the window closed and B connected, stop the server, wait ten seconds, start it again. EXPECT: B r...
- [ ] `528` (you) A server that is not there. Net > Connect with the server stopped. EXPECT: the Disconnect item is lit while it retries (it stops the retr...
- [ ] `531` (hw) The refusal latch is re-armed by Connect. Point B at an old server (before protocol 2) or give B a computer id already in use. EXPECT: th... -- needs: Needs an old server or duplicate computer id from a second station.
- [ ] `537` (you) NETWORK AUTO CONNECT. Turn it on in Preferences > Network, restart B with the server up. EXPECT: connected a moment after the main window...
- [ ] `543` (you) Restore. Leave the Network window open, quit, relaunch with AUTO CONNECT off. EXPECT: the window comes back showing the disconnected titl...
- [ ] `546` (you) Preferences > Network layout. The new checkbox ("Connect to the multi-op server when TR4W starts") sits above the grey hint text without...
- [ ] `550` (you) Quit while connected and while retrying. Exit from each: no hang, no error. Exit now disconnects first (NetLinkShutdown from ExitProgram)...

**Added 2026-10-19 -- SMALL PUNS AND TERMINATORS (pointer audit P10: 3.3, 3.4, 3.6, 6.14)**

- [ ] `1096` (hw) Server password handshake (3.4, multi-op-network; automated only for the slicing). With tr4wserver running with a password, connect a cli... -- needs: Needs tr4wserver with password plus a client on a second machine or browser.

**Added 2026-10-18 -- UNTYPED BYTE BUFFERS ARE OPEN ARRAYS (pointer audit P12)**

- [ ] `1143` (hw) Connect two clients and log a QSO on one. EXPECT: it reaches the other; neither tr4w.log nor tr4wserver.log reports an unrecognised id or... -- needs: Two clients and tr4wserver; wire bytes unchanged.
- [ ] `1146` (hw) Server at TRACE. EXPECT [Net] rx <ip>: and [Net] tx <ip>: lines in the same shape as before: two upper-case hex digits and a space per by... -- needs: Two clients and tr4wserver; wire bytes unchanged.

**Added 2026-10-27 -- NETWORK PROTOCOL 2: HELLO, AND EVERY CONTEST TRAVELS**

- [ ] `1393` (hw) Connect, both stations, a by-id contest. Select the same QSO party on both, choose Net > Connect on each (the link no longer needs the Ne... -- needs: Two machines (Windows + Mint) and a tr4wserver/TR4WServerPy. Memory: protocol-2 items still to bench (next-...
- [ ] `1399` (hw) A QSO crosses and is logged. Log one at A. EXPECT at B: it appears in B's log, scores, and the dupe sheet knows it -- ON A BY-ID CONTEST.... -- needs: Two stations, QSO/edit/Alt-Y cross the link. Only restock/catch-up confirmed 2026-10-29, not this.
- [ ] `1403` (hw) The two builds do not agree on the handle byte, and it does not matter. If the two stations' by-id handles differ (compare handle in a de... -- needs: Two builds with different by-id handle sets; two stations needed.
- [ ] `1407` (hw) A contest change is announced. With both connected on contest X, change A to contest Y (Preferences, or New Contest). EXPECT at A: [Net]... -- needs: Two connected stations, change contest at A, watch B.
- [ ] `1411` (hw) A peer on another contest is refused and reported, once (this is Q110, now by announcement). EXPECT at B: the QSO is NOT logged; one pane... -- needs: Two stations on different contests; refusal notice once.
- [ ] `1416` (hw) A server from before protocol 2. Point the station at an old tr4wserver.exe (any build before this change) or the Python server at tag d7... -- needs: Needs an old pre-protocol-2 tr4wserver build or Python d7-protocol tag.
- [ ] `1422` (hw) A station from before protocol 2 (or the probe's --case hello) against the NEW server: refused, the server log says first message was not... -- needs: Needs 4.x-style client or netprobe --case hello against new server.
- [ ] `1425` (hw) A mismatched protocol number (hand edit, or run netprobe against a patched server): the dialog says which end is behind and what to update. -- needs: Needs netprobe or hand-patched server; second endpoint.
- [ ] `1427` (hw) Duplicate computer id, as before: the second station gets the "Computer ID is already in use" dialog; the first is undisturbed. Then stop... -- needs: Two stations with the same computer id against a server.
- [ ] `1430` (hw) A station that leaves is forgotten. Net > Disconnect at B; at A the row clears (this was broken against the Python server), and a QSO for... -- needs: Two stations; Disconnect at B, row clears at A, forged QSO refused.

**Added 2026-10-18 -- Q110: PEERS ON DIFFERENT CONTESTS**

- [ ] `1448` (hw) A QSO from a peer on another contest is refused and reported. Station A on contest X, station B on contest Y, both connected; log a QSO a... -- needs: Q110: two stations on different contests, one server.
- [ ] `1456` (hw) Same contest on both is unchanged, and a reconnect re-arms the notice. -- needs: Q110 follow-up: same contest both; reconnect re-arms notice. Two stations.

**15. Launching other programs now goes through one unit (07c55fa4)**

- [ ] `3099` (you) Run server starts tr4wserver.exe; Ping server pings it. [ AGENT: Confirm how you are pinging the server. When I did it, it tried ::1 so i...

**40. Two multi-op message-loop defects fixed, and the silent drop now reports**

- [ ] `3794` (hw) A spot announced by another operator still reaches the cluster, and the QSO behind it in the same segment still arrives. The spot arm adv... -- needs: Needs two stations; memory next-multi-op-network-revival: a DX spot Mint->server->Windows band map confirme...
- [ ] `3799` (hw) When one station drops off the network, the others' QSOs still arrive. The disconnect arm overwrote the recv byte count with a client ind... -- needs: Needs a second station dropping off; uNet revived since, not confirmed for this case.
- [ ] `3802` (you) Watch tr4w.log for [Net] Unrecognised message id. New. If it never appears, the framing is holding. If it does, capture the log -- it nam...

**45. The multi-op link runs on Indy -- NEEDS A SECOND STATION**

- [ ] `3880` (hw) Connect to TR4WServer, with the right password. The handshake moved into TNetClient.Connect: ten bytes of password, then a four-byte ackn... -- needs: Second station/server; memory: Windows+Mint connected to TR4WServerPy 2026-10-29 (protocol 2), correct-pass...
- [ ] `3884` (you) A WRONG password still says so. The server answers 'PASS' and the operator gets TC_CONNECTTOTR4WSERVERFAILED, as before.
- [ ] `3886` (hw) Two stations logging at once: QSOs, mults, serial numbers, the station status list, intercom messages and spot forwarding. Every message... -- needs: Two stations logging at once; Windows+Mint rig exists (memory bench-rig-mint-and-pi400).
- [ ] `3890` (hw) Pull the network cable. The link drop now arrives as an EVENT from the reader thread rather than as a zero-length recv, and auto-reconnec... -- needs: Cable pull with a server; memory lists long outage/cable pull as still to bench.
- [ ] `3893` (you) Close the network WINDOW while connected, and keep logging. This is the whole point of the change: the window used to BE the socket's eve...
- [ ] `3897` (you) Watch tr4w.log for [Net] stream desynchronised. It should never appear. If it does, the buffer was discarded to resynchronise and somethi...

**BENCH RUNS -- no automated gate reaches any of this**

- [ ] `4271` (hw) The server-log SYNCHRONIZE window -- NEEDS A SECOND STATION. Its QSO list was the last hand-built Win32 window in the program and is a TL... -- needs: Needs server + second station; uServerLogForm still exists; Create a new log vs SQLite unproven.

**2026-09-08 -- THE MULTI-OP LOG SYNC MOVED TO INDY. NOBODY HAS RUN IT.**

- [ ] `4431` (hw) The byte count on the progress display climbs and finishes. If it sticks at 0, the password write or the size header is wrong. -- needs: Get server log needs server+station; FetchServerLog still in uGetServerLog.pas:306.
- [ ] `4433` (hw) The record and QSO counts match what the server reports. The size check is LogSize <> TotalBytes; a mismatch shows *"failed to receive se... -- needs: Needs server holding a log.
- [ ] `4436` (hw) A log LARGER than 4096 bytes -- that is one old recv buffer, so a single-chunk transfer would prove almost nothing about the loop. -- needs: Needs server log over 4096 bytes.
- [ ] `4438` (you) The window does not hang for a station that is off. Connect failures are now REPORTED ([SyncLog] connect to <host>:<port> failed) where t...

## G8. Release mechanics

**Added 2026-10-18 -- UNTYPED BYTE BUFFERS ARE OPEN ARRAYS (pointer audit P12)**

- [ ] `1155` (you) Start the PREVIOUS release's exe, then this build's, from the SAME directory. EXPECT: the second is refused as a second instance. That pr...

---

## Appendix: items that are not release gates (D and L)

D = disclose in the release notes as a limitation; L = can follow after release. They stay in the
queue. Counted here by section so nothing is hidden; the first line number is where to start.

| Section (queue) | First line | D | L |
|---|---|---|---|
| Added 2026-10-29 -- SHARE DX SPOTS AROUND THE NETWORK (NETWORK SHARE SPOTS) | `163` | 0 | 1 |
| Added 2026-10-28 -- A SERVER THAT LOST ITS LOG (the restock; Phase 1 gap found on the benc | `274` | 0 | 1 |
| Added 2026-10-27 -- THE QUEBEC QSO PARTY (issue #128) | `589` | 1 | 0 |
| Added 2026-10-26 -- THE ONTARIO QSO PARTY (issue #127) | `622` | 1 | 0 |
| Added 2026-10-26 -- THE RADIO POLLER WRITES NO CONTROL (issue #108) | `686` | 0 | 5 |
| Added 2026-10-26 -- K4 TX TEST MODE IS SHOWN ON A KEY-UP (issue #97 phase 2) | `735` | 0 | 8 |
| Added 2026-10-26 -- K4 TX TEST MODE REACHES THE STATUS (issue #97 phase 1) | `779` | 0 | 3 |
| Added 2026-10-26 -- EXIT AND THE ICOM SPAN AT LINK-UP (issues #106, #107) | `821` | 0 | 4 |
| Added 2026-10-26 -- K4 STARTUP SENDS AND RADIO REBUILD (issues #99, #104) | `842` | 0 | 3 |
| Added 2026-10-23 -- MODE NAMES SENT TO OTHER PROGRAMS (UDP, RADIOINFO, DXKEEPER) | `900` | 0 | 3 |
| Added 2026-10-23 -- HAMSCORE RE-EMITS A STORED QSO FROM ITS RECORD (issue 95, review R6, Q | `965` | 0 | 6 |
| Added 2026-10-22 -- THE AUTOMATIC X-QSO (Q98 S1) AND CQ WW'S BANDS AND MODES | `1043` | 0 | 2 |
| Added 2026-10-19 -- SMALL PUNS AND TERMINATORS (pointer audit P10: 3.3, 3.4, 3.6, 6.14) | `1077` | 0 | 4 |
| Added 2026-10-18 -- UNTYPED BYTE BUFFERS ARE OPEN ARRAYS (pointer audit P12) | `1123` | 0 | 4 |
| Added 2026-10-17 -- THE CPU KEYER'S ELEMENT RING IS A FIELD (pointer audit P6, defect D4) | `1248` | 0 | 6 |
| Added 2026-10-17 -- THE SPOT STORE IS A CLASS OVER A GENERIC LIST (pointer audit P8, part  | `1290` | 0 | 3 |
| Added 2026-10-17 -- BATCH C RULINGS (Q9, Q32, Q37, Q73, Q81) | `1317` | 0 | 1 |
| Added 2026-10-17 -- BATCH B SCORING RULINGS (Q38, Q45, Q49, Q71, Q84, Q85, Q104) | `1366` | 0 | 1 |
| Added 2026-10-27 -- NETWORK PROTOCOL 2: HELLO, AND EVERY CONTEST TRAVELS | `1433` | 0 | 1 |
| Added 2026-10-15 -- THE MINIMUM OFF TIME IS THE CONTEST'S (Q60) | `1534` | 0 | 3 |
| Added 2026-10-14 -- THE EXCHANGE RULES ASK THE CONTEST (M11 S7) | `1556` | 0 | 4 |
| Added 2026-10-14 -- WSJT-X MESSAGES ARE EVALUATED ON THE MAIN THREAD | `1604` | 0 | 9 |
| Added 2026-10-14 -- SEVEN CONTEST SETTINGS RETIRED (M10 S2, NY4I's Q4) | `1681` | 0 | 1 |
| Added 2026-10-13 -- A STATION FACT CHOSEN AT NEW CONTEST IS THAT CONTEST'S ONLY (design 7. | `1745` | 0 | 5 |
| Added 2026-10-13 -- POTA IS A CONTEST CLASS. LOG AN ACTIVATION. | `1779` | 0 | 7 |
| Hand docs/QTC_BENCH_HANDOFF.md to N4AF | `2472` | 1 | 0 |
| Icom IC-7110 -- a clone, not a driver | `2532` | 1 | 0 |
| Send the Chinese catalogue to BA4WI, and ask for his original file | `2545` | 0 | 1 |
| DISTRUST: does Invoke-MenuSmoke really fail when a window does not open? | `2557` | 0 | 1 |
| Stable ids -- three stores changed, NONE bench-verified | `2648` | 0 | 2 |
| Still open from his notes | `2656` | 1 | 2 |
| A. New Contest dialog is now an LCL form (16ffc284) | `2726` | 0 | 1 |
| D. Decisions waiting on NY4I, not bench items | `2742` | 0 | 1 |
| Added 2026-08-26 (overnight) -- UNRUN | `2769` | 0 | 1 |
| 1. Program message editor — Alt-P, pick a memory, Edit (d036b949, feb180f0, bede4637) | `2822` | 1 | 0 |
| 3. Window control dialog — Ctrl+Alt+M (f11a1093) | `2852` | 0 | 1 |
| 4. Band plan editor — Preferences, More settings, the Edit... button (uBandPlanForm) | `2885` | 0 | 2 |
| 10. Radio panel updates now go through a posted message (uPanelUpdate) | `3015` | 0 | 1 |
| 11. Window positions now live in settings/tr4w.json, not settings/tr4w.pos | `3065` | 1 | 0 |
| 15. Launching other programs now goes through one unit (07c55fa4) | `3091` | 1 | 0 |
| 16. One callsign validator: IsAGoodCall (d3d4d5b3) | `3130` | 0 | 1 |
| 17. The YCCC box -- the LPT half of this item is gone | `3144` | 1 | 0 |
| 18. Upgrading a 4.x station -- its settings arrive from tr4w.ini, once | `3178` | 0 | 1 |
| 22. Colors moved to JSON, and Ctrl-J is GONE | `3239` | 0 | 1 |
| 23. TR4W offers to remove tr4w.ini -- once -- and the first resourcestring | `3283` | 0 | 1 |
| 24. WinKeyer -- the menu now lands on it, and an upgrading station gets its keyer back | `3313` | 0 | 2 |
| 26. The function-keys window is an LCL form -- TEST THIS ONE PROPERLY | `3355` | 0 | 1 |
| 27. Band map step 1: the model, before any form exists | `3433` | 0 | 2 |
| 30. Application.Run -- THE PIVOT. Test this harder than anything before it | `3486` | 0 | 6 |
| 31. The dupe sheet is a form and a TDrawGrid (uDupeSheetForm) | `3542` | 0 | 2 |
| 35. Super Check Partial is a form, and the dupe sheet moved under it (uMasterForm, uCallGr | `3575` | 0 | 4 |
| 36. All five remaining-multiplier windows are forms (uRemMultsForm) | `3602` | 0 | 4 |
| 37. THE MAIN WINDOW'S FORTY-TWO ELEMENTS ARE LCL CONTROLS — test this like section 30 | `3636` | 0 | 3 |
| 38. Injected keystrokes are deferred calls now | `3684` | 1 | 1 |
| 39. The WSJT-X indicator is driven by domain state (uWSJTXState, uStateBridge) | `3728` | 0 | 1 |
| 44. The radio panels are LCL forms -- and colour used to mean state | `3862` | 1 | 0 |
| F7 — RIT, XIT and SPLIT show yellow with no radio attached | `4176` | 0 | 1 |
| DECISIONS FIRST -- these are yours, not bench runs | `4206` | 0 | 1 |
| BENCH RUNS -- no automated gate reaches any of this | `4227` | 2 | 1 |
| 2026-09-08 -- THE WARNING BEEPS SHOULD BE AUDIBLE AGAIN. LISTEN. | `4524` | 0 | 5 |
| 2026-09-08 -- peeling MainUnit for a Linux compile: DECISIONS OWED | `4556` | 3 | 1 |
| Issue #1 -- tool windows are no longer owned by the main window (2026-10-29) | `4799` | 1 | 4 |
| Added 2026-10-29 -- HAMSCORE "RE-SEND LOG" ASKS BEFORE IT DELETES (NY4I, RTC test) | `4845` | 0 | 5 |
| Added 2026-10-31 -- EDIT QSO SHOWS WHERE AN EXTERNAL LOGGER STANDS (WRL) | `4871` | 0 | 4 |
| Added 2026-10-31 -- A LOCKED CONTEST LOG: THE STARTUP DIALOG, READ-ONLY, AND THE WATCHDOG | `4890` | 1 | 9 |

## Not counted

Many sections (for example M5b, M6, M8, M9a/b, Idaho, Delaware, IN7QPNE, the 2026-09-03 and
2026-09-05 batches, the New Contest dialog items near the Russian-contest entry, and the `.local`
mDNS checks) use plain bullets or numbered steps with no checkbox. They are real checks but were
not part of the 423. Decide for each whether it gates; the classifiers could not tell from the text.
