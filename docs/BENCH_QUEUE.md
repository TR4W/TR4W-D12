# Bench queue — what is waiting for a real run

A **living list**, not a log. An item goes in when a change lands that no
automated gate can check, and comes **out** when NY4I confirms it. Items that
pass are deleted from here; if the result is interesting it goes into the
document that owns the area (`RADIO_BENCH_STATUS.md`, `D12_HARDWARE_TEST_PLAN.md`,
`CW_Keyer_Factory_Plan.md`) rather than accumulating here.

**Triage, 2026-11-01.** All 423 open items were classified against the tree and the
git history for the 5.x release (`RELEASE_ROADMAP_5X.md`). Nothing was ticked: no open
item has citable confirmation from NY4I. Four were found stale and are marked `[-]`
(withdrawn, with the reason on the line); delete them when you next edit this file.
The list of what NY4I still has to check, by release gate, is
`BENCH_CHECKLIST_NY4I.md`. Plain-bullet items were converted to `- [ ]` checkboxes afterwards (2026-11-01), so every item can be ticked.

**"Does it open" is meant to be covered by a gate.** `Invoke-MenuSmoke.ps1`
drives the converted dialogs and is meant to fail when one does not produce a
window -- but see the DISTRUST item below: on 2026-08-29 it reported success
for runs in which Preferences never opened. So nothing below is asking whether
a dialog appears; every item is about whether what appears is CORRECT, which is
the part no gate reaches.

**Why this exists.** Every defect NY4I found during the Phase 3/4 conversions was
invisible to the lints, the unit tests and the golden corpus: a
swallowed menu, invisible entry fields, a double caret, a window collapsed to
400×200, the "most recent configuration" button vanishing, `K3Sio 2` for a radio
named `K3S`, Escape not closing a dialog, a settings field accepting letters, and
a message key written with four bytes of garbage on the end. The gates are good
at what they cover; this is the list of what they cannot see.

---

## Added 2026-11-12 -- MY LICENSE YEAR: THE SENT YEAR HAS ITS OWN SETTING, BOX AND ROW (issue 298)

Unit-tested (`uTestLicenseYearSetting`, `uTestStationFactOverrides`); nothing
below has been seen on a screen. No schema change (still 7). The year you SEND
was the MY ZONE setting relabelled; it is now `MY LICENSE YEAR`.

- [ ] **Preferences > Station information has a License year box**, in the
      Contest exchange column under Park, with its own tooltip (it describes the
      year, four digits or two). The CQ zone box is still labelled CQ zone in
      EVERY contest -- open Preferences with an EUHFC log and with a CQ WW log
      and confirm the zone box never changes its words.
- [ ] **Type 1985 (or 85) in License year, Save, open a new EUHFC contest.** The
      New Contest row reads MY LICENSE YEAR and is pre-asked; the default CQ
      message and the Cabrillo/ADIF sent exchange carry `85`. KVP the same.
- [ ] **Your EUHFC log from before this build** (`EUROPEAN HFC 2026-11-11
      NY4I.log` -- copy it first, do not open the only copy): its year, which
      the log stored as MY ZONE, is moved to MY LICENSE YEAR when the contest
      opens, so the Cabrillo and ADIF sent exchange show the year you stated
      (not `08`/`8`, not your ITU zone). Preferences shows the STATION's
      License year (the default), not this contest's, so it may read empty
      there. If the sent year is missing, say what the log's MY ZONE held.
- [ ] **A zone contest is untouched**: CQ WW still sends its CQ zone, and the
      License year box being filled changes nothing in it.
- [ ] **An EUHFC contest with no License year** warns at startup ("MY LICENSE
      YEAR is empty ...") and sends no year, rather than your CQ zone.

## Added 2026-11-12 -- THE RECEIVED YEAR ON SCREEN AND IN EVERY EXPORT (issue 298, stage 3)

Unit-tested (`uTestReceivedYearDisplay`); nothing below has been seen on a
screen. No schema change (still 7).

- [ ] **The log grid shows the year as typed.** In an EUHFC or KVP log the
      column headed Year shows `05`, not `5` (a CQ WW log still shows its
      zone under `Zn`).
- [ ] **Edit QSO names the year.** Open an EUHFC QSO in Edit QSO: the box that
      said Zone is labelled Year and holds two digits. Then open a CQ WW QSO in
      the same session: it says Zone again (the form is reused). The "Our
      station for this QSO" CQ zone box on a NEW EUHFC QSO shows your CALL's
      CQ zone (e.g. 15 for an S5), not your licence year -- an EUHFC QSO logged
      before this build still shows the year it recorded (80 in NY4I's log);
      nothing rewrites it.
- [ ] **Edit the year, then export.** Change a QSO's year in Edit QSO and save:
      the ADIF `SRX_STRING` and the Cabrillo received column both carry the
      NEW year (the ADIF used to carry the typed one). A QSO typed `5` exports
      `SRX_STRING` `599 05` now.
- [ ] **ADIF MY_CQ_ZONE.** Export ADIF from a NEW EUHFC log: `MY_CQ_ZONE` is
      your call's CQ zone, never your licence year.
- [ ] **UDP.** With UDP broadcast on, an EUHFC QSO's contact carries the year
      in `<zone>` (5 for 05, as before) and `599 05` as its exchange.

## Added 2026-11-12 -- LOG SCHEMA 7: THE RECEIVED YEAR IS READ FROM ITS OWN FIELD (issue 298, stage 2)

Unit-tested (`uTestLogReceivedYear`: the kinds, the parser, Edit QSO's save
rule, the ADIF import through `ParseADIFRecord`, the v7 re-carry, a QSO
received live through the NET_QSOINFO arm); nothing below has been seen on a
screen. **Keep a copy of the log first: a log this build opens is refused by
5.0.37 and earlier.**

- [ ] **Edit QSO keeps the year and the zone together.** In an EUHFC log, open
      a QSO in Edit QSO: the zone box shows its year as two digits (`05`, not
      `5`). Change it (e.g. 85 to 84), save, then: the log grid's Year column
      shows 84, a Rescore counts 84 (not 85) on that band, and Cabrillo's
      received column reads `599 84`. Empty the box and save: the grid shows no
      year and the QSO earns no year multiplier. Type `1982` or `8A`: the save
      is refused with "Improper license year!!" and the form stays open.
- [ ] **An existing EUHFC/KVP log migrates.** Open an EUHFC log last saved by
      a stage-1 build (or 5.0.37): nothing visible changes -- years, score and
      export are what they were -- and the log is now schema 7.
- [ ] **ADIF import carries the year.** Export ADIF from an EUHFC log, start a
      new EUHFC log, import that file: every QSO keeps its year (grid Year
      column, Cabrillo received column, the score's multipliers). Before this
      change it came back with none. An ADIF from another logger whose year is
      only in `CQZ` imports that value as the year.
- [ ] **Multi-op.** Two stations on EUHFC (TR4WServerPy moved to protocol 3,
      see stage 1 below): a QSO logged on one shows the right year on the
      other, in the grid and in its Edit QSO.

## Added 2026-11-12 -- NETWORK PROTOCOL 3 AND LOG SCHEMA 6: THE RECEIVED YEAR (issue 298, stage 1)

The QSO record carries the received year in bytes that were reserved; packet and
record sizes are unchanged. What only a real run can judge:
- **TR4WServerPy must be moved to protocol 3** (it judges the version as equal),
  or every station of this build is refused with "protocol mismatch". The in-tree
  `tr4wserver` builds from this tree and is already 3. Then two stations: log an
  EUHFC QSO on one, check the other's log row has `rcvd_year` (and a catch-up
  after a restart keeps it).
- Opening an existing EUHFC or KVP log migrates it to schema 7 (6 was stage
  1's; stage 2's 7 re-copies the years) and copies each
  QSO's year out of the zone column; **5.0.37 cannot open it afterwards** --
  keep a copy before trying. A log of any other contest gets an empty column.

## Added 2026-11-12 -- THE 64-BIT (x64) WINDOWS BUILD (issue 299)

NY4I wants 32-bit Windows retired. Step 1 (rebuild, headless export identical to i386, GUI
starts) is recorded at the top of `docs/64_BIT_TASKLIST.md`. Nobody has used the x64 app for
anything real. **Run:** `C:\tr4w-d12\build-out\app-x86_64-win64\tr4w_fpc.exe` (rebuild first with
`.\tr4w\build\Build-App.ps1 -Cpu x86_64 -Os win64`; its 64-bit DLLs are staged beside it). Use a
copy of your station settings, not the live ones, for the first pass.

- [ ] It starts, opens your contest log, and shows the main window with no error box
- [ ] Preferences opens, every page loads, a change saves and is still there after a restart
- [ ] A new contest, a QSO logged, edited and deleted; the log grid and score update
- [ ] A SERIAL radio (an Icom CI-V and a Yaesu or Kenwood if you have them): connects, frequency and
      mode follow the dial, a band change from TR4W reaches the radio
- [ ] A LAN radio (K4 or an Icom LAN radio): connects, credentials are sent, reconnects after a drop
- [ ] A HamLib radio (this is the first time the 64-bit `libhamlib-4.dll` is actually loaded)
- [ ] CW from the function keys: CW-by-CAT, a WinKeyer, and DTR/RTS keying; speed changes; Esc stops it
- [ ] DX cluster login, spots in the band map, click-to-tune
- [ ] WSJT-X: decodes arrive, a logged QSO is accepted
- [ ] An external logger (WRL or Club Log), which exercises the 64-bit OpenSSL pair
- [ ] A multi-op station against `tr4wserver` (the 64-bit server now builds and is in the x64
      installer, but it has never been RUN; the old 32-bit one still works against an x64 client)
- [ ] SO2R with two radios; the intercom/voice (winmm) functions if you use them
- [ ] ADIF and Cabrillo export from the GUI; compare with what the 32-bit build gives for the same log
- [ ] **The 64-bit INSTALLER (nothing has ever run it).** Built by `FullBuild.ps1 -Cpu x86_64
      -BuildInstaller` into `tr4w\build\release\tr4w_setup_<version>-x64.exe`. On a TEST machine or VM
      that has a 32-bit TR4W in `C:\Program Files (x86)\TR4W` with real settings and contest logs
      (copy a station's folder there; do not use the live PC): close TR4W, run the x64 installer.
      Expected: a message names the old and new folders; TR4W lands in `C:\Program Files\TR4W`;
      `settings\tr4w.json`, every contest folder and loose `.db` (with `-wal`/`-shm`) are in the new
      folder and open with their QSOs; the old folder keeps its data and loses `tr4w.exe`, its DLLs
      and `tr4wconvert.exe`; the Desktop and Start Menu shortcuts start the 64-bit exe;
      `HKCU\Software\TR4W` names the new folder; a second run of the installer does NOT overwrite the
      new settings. Also: `setup /S` over the old install (no dialog, same result); the installer on a
      machine with a custom 32-bit folder such as `C:\TR4W` (upgrades in place, no stale
      `libgcc_s_dw2-1.dll`); a fresh machine (no old install); and a 32-bit Windows refuses it with a
      message. The installer manifest is `requireAdministrator` (measured), so a UAC prompt must
      appear; run it as an account that is also the operator's own, because HKCU, `$DESKTOP` and the
      Start Menu belong to whoever elevates (true of the 32-bit installer too).
- [ ] Start-up time: the first x64 start took 11.5 s to the main window against 2.7 s for i386, almost all of
      it a `DdeConnect` to DXLab Pathfinder -- is that repeatable on your PC?

## Added 2026-11-11 -- EUROPEAN HF CHAMPIONSHIP AND KVP SAY "YEAR", NOT "ZONE"

Unit-tested (`uTestLicenceYearEntry`, `uTestContestDisplay.Test_TotalsDisplay` / `Test_ZoneColumnHeading` / `Test_MyZoneLabel`); nothing below has been seen on a screen.

- [ ] **A lone report.** An EUHFC log on CW: type a call and `599` alone, Enter. The message reads `No license year found!!`, not `Improper zone number!!`. `599 1982` or `599 CT` reads `Improper license year!!`. `599 85` logs as before. Same in a KVP log.
- [ ] **The log column.** The main log's and Edit Log's column over the year reads `Year`, wide enough to read in full; in CQ WW (or any zone contest) it still reads `Zn`. A saved COLUMN WIDTH for that column still applies in both.
- [ ] **The totals rows.** EUHFC's totals grid shows a `Years` row where it showed `Zones`; KVP (multipliers by mode) shows `CW Years` / `Ph Years`. Every other zone contest still shows `Zones` / `CW Zone` / `Ph Zone`.
- [ ] **Preferences > Station information.** In an EUHFC (and a KVP) log the label beside the MY ZONE box reads `License year:`, not cut off; in CQ WW (or any other contest) it reads `CQ zone:`. Searching `MY ZONE` still lands on the box. Hovering the label or the box in EUHFC/KVP shows the year's help ("The last two digits of the year you were first licensed..."), not the CQ-zone help; in CQ WW both show the MY ZONE command's usual help (`Values: Integer. Normally, your zone is determined by your callsign...`).

## Added 2026-11-10 -- EUROPEAN HF CHAMPIONSHIP: A REMEMBERED YEAR MARKS A CALL OR SPOT AS A NEW MULTIPLIER (issue 70)

Unit-tested through the real parser and the sheets (`uTestStatusAndNotice.Test_EUHFCYearNeedFollowsTheRememberedExchange`); nothing below has been seen on a screen. The year comes only from what the program remembers for the call -- INITIAL.EX, a call history file, or a logged QSO -- never from the call itself.

- [ ] **INITIAL.EX with years marks spots.** An EUHFC log, INITIAL.EX holding `S51B 85` (and a line with the RST, `S52C 599 73`). With 85 not yet worked on 20 m, a spot of S51B on 20 m shows the band map's multiplier `M`; after a QSO with any station giving 85 on 20 m, the S51B spot on 20 m loses its `M` and a 40 m spot of it keeps one. A spot of a call INITIAL.EX does not know shows no `M`, as before.
- [ ] **The call window agrees.** Type S51B: the MULT flag and the "Mult needs for S51B" strip follow the same answer (20 empty once 85 is worked on 20, 40 still shown). Year 00 (`S54E 00`) behaves like any other year.

## Added 2026-11-09 -- THE PER-DESTINATION "VERIFY THE SERVER'S CERTIFICATE" BOX (issue 256)

Written with no screen and no network: unit tests pin the rule (global AND destination) for every destination through a fake transport, the definition and settings round trips, the editor's controls on an unshown form, and the Test button. What is below needs a screen, or a server whose certificate TR4W will not accept.

- [ ] **Preferences > Online scoring fits and reads right.** The page has two new check boxes, "Verify the server's certificate": one under the HamScore Service URL (below its Test result) and one under the score Posting URL. Nothing overlaps, nothing is clipped at the page's 572 px, and the Score board hint and the new red warning line at the bottom still fit (the Posting URL block moved up 8 px and the Reading URL block down 10 px; the test-result labels are 32 px high, were 34). Look at it at 100% and 150% scaling, and in a translated language.
- [ ] **Both boxes start ticked, and Save is armed by them.** A fresh settings file, and a settings file saved before this change, show both ticked. Untick one: Save un-greys. Cancel, reopen: ticked again.
- [ ] **Unticking shows the warning, ticking hides it.** HamScore: the sentence "The server's identity is not checked; anyone between you and it can read what you send." appears in the slot under the box (the same label that carries the plain-http note); the Posting URL row shows it as a red line at the bottom of the page. Over a plain `http://` URL the box is greyed (it keeps its value) and the HamScore slot shows the plain-http note instead; a plain http:// Posting URL shows no warning.
- [ ] **The Test button follows its row.** With the global `network.verifyServerCertificates` ON, a server with a self-signed certificate: Test with the box ticked answers `No answer: the server's certificate was not accepted ...`; untick the box, Test again: `Answered 200` (or what it answers), and `tr4w.log` has `server certificate checking is OFF for HamScore by its own setting` (or `score posting`) naming the URL and no password. Ticking the box blanks the old result. The Reading URL Test has no box and obeys the global setting only.
- [ ] **A real self-signed destination, end to end.** A Wavelog or Cloudlog on a LAN with a self-signed certificate: add it in Preferences > External Logger, untick the box in the editor, Save (the row says a restart is needed; restart). A QSO delivers; `tr4w.log` has the Warn naming the definition and its URL. The same box ticked fails closed with a certificate refusal and the delivery retries, it never goes unverified. Club Log and WRL, left ticked, are verified in the same session.
- [ ] **The external logger editor.** Open a Cloudlog, a Club Log and a WRL definition: a "Verify the server's certificate" box row sits last, the caption column beside it is empty, the box fits its caption, and unticking shows the red warning under the rows and lays the dialog out again (taller by one wrapped line, buttons still on screen). A plain `http://` Cloudlog address greys the box and hides the warning. WRL's logbook Refresh uses the box's current state. A DXKeeper or ACLog definition shows no such row.
- [ ] **Global OFF still wins.** With `network.verifyServerCertificates` false in `settings\tr4w.json`, a ticked destination is NOT verified (the log has the existing "OFF by setting" line, not the per-destination one).

---

## Added 2026-11-08 -- ACLOG EXTERNAL LOGGER (issue 33)

Needs a real AC Log (N3FJP) with "TCP API Enabled" ticked (default port 1100). The unit
tests only prove the bytes against a loopback server; nobody has run this against AC Log, and
no reply to `ADDADIFRECORD` is documented.

- [ ] Add an ACLog logger in Preferences > External Logger; the port starts at 1100 when you
      switch the provider from DXKeeper; host `127.0.0.1` (or the AC Log machine's address).
- [ ] Log a QSO: it appears in AC Log's log AND its recent-contacts list.
- [ ] The call, date, time (UTC), band spelling, mode and RST/exchange fields are right in
      AC Log; a phone QSO and a CW one; a QSO whose call or name has an accent (UTF-8).
- [ ] A QSO with `<`, `>` or `&` in a note/comment is stored whole and does not break AC Log.
- [ ] Close AC Log (or untick TCP API) and log QSOs: the row reads Retrying (ACLOG_NOT_REACHABLE),
      logging is not slowed; reopen AC Log and the waiting QSOs drain within about a minute.
- [ ] Log the same call twice in the same minute: note what AC Log does (duplicate row, refusal).
- [ ] Edit a delivered QSO and delete one: each shows Failed with `ACLOG_EDIT_UNSUPPORTED` /
      `ACLOG_DELETE_UNSUPPORTED`, AC Log is untouched, and later QSOs still deliver.
- [ ] An old settings file with `EXTERNAL LOGGER = ACLOG` becomes an ACLog definition on first
      start (host kept, port 1100 unless one was set).

## Added 2026-11-08 -- SPLIT BY '-' WITH VFO B RECEIVING ON A TS-890S (issue 38)

The transmit-frequency entry (the `-` key) always wrote the TX frequency to VFO B and the LAN Kenwood always sent `FT1;`. With VFO B receiving that made TX = RX = B: no split. The radio now names its split TX VFO (`SplitTransmitVFO`); only the TS-890S changes its answer, to the VFO it is NOT receiving on (tracked from `FR`), and the `-` entry splits through `SplitTransmittingOn` with that VFO. With A receiving the bytes are exactly as before (`FB<freq>;` then `FT1;`, off `FT0;`). With B receiving it sends `FA<freq>;` then `FT0;`, and off sends `FT1;`. Split OFF from ANY path now puts TX back on the receive VFO (with B receiving it used to send `FT0;`, which turned split ON). The band map's QSX, WSJT-X and the TCI server still write B and send `FT1;` -- unchanged on purpose, still A-centric for B receiving. Unit-pinned in `uTestKenwoodLANSplit`; what the radio does with it is not. Hamlib agrees with `FT0` for "on, B receiving"; the "off" spelling is reasoned from FT = "TX VFO" (Hamlib's own off arm sends `FT0` regardless, which would leave B-receiving in split). Also still open from before: does `FT` alone make a real TS-890 report `TB1` (the comment in `TKenwoodLAN.Split`)? Watch `tr4w.log` at TRACE for `ParseTBResponse`, `ParseFTResponse`, `ParseFRResponse`.

- [ ] **TS-890S over LAN, VFO A receiving.** Press `-`, enter a TX frequency. Split comes on (radio and TR4W's split indicator), RX stays on A at its frequency, VFO B shows the entered frequency and transmits there. Press `-` again: split off, TX back on A.
- [ ] **TS-890S over LAN, VFO B receiving** (press A/B on the radio first). Press `-`, enter a TX frequency. Split comes on, RX stays on B and B's frequency is NOT changed, VFO A shows the entered frequency and transmits there (key briefly into a dummy load, or watch the TX VFO indicator). Press `-` again: split OFF (not on), TX back on B, and the radio reports `TB0`.
- [ ] **Band-map click with B receiving does not split.** With B receiving and split off, double-click an ordinary (non-QSX) band-map spot: the radio must NOT go into split (it used to, because the tune's split-off sent `FT0;`). Known and unchanged: that tune writes VFO A, not the receive VFO.
- [ ] **Mode with B receiving.** After the B-receiving entry, say whether VFO A's mode changed. Known, not new: `OM` sets the mode of the receive VFO whatever VFO is named, so TR4W can only set the mode of the receive VFO.
- [ ] **FlexRadio: unchanged.** Flex was deliberately not touched (it never tracks an active slice). With slice A active, `-` behaves as before. With slice B active the old behaviour is expected: TX goes to slice 1 and RX is forced to slice 0. That is a separate fix, so report it but do not count it as a regression of this change.
- [ ] **TS-990S (if one is to hand): unchanged.** It shares the LAN base but keeps "B transmits" (`FT1;`/`FT0;`) whatever VFO receives, because its split works differently (Hamlib: TB, RX main / TX sub).

---

## Added 2026-11-08 -- DXLAB PATHFINDER CLEARS THE EXCHANGE (issue 48)

The DDE message from PathFinder used to put the call in the call field and leave whatever was in the exchange field. It now clears the exchange first (`tCleareExchangeWindow`, which hands the clear to the main thread when it is called from another one), as the band map's tune path does. Not unit-testable: it needs DXLab's DDE client and the live window.

- [ ] **Clear and prefill.** With DXLab PathFinder running and enabled, type some text in the exchange field, then send a call from PathFinder. The exchange field empties, the call appears in the call field with the caret at the end, and a call-history or remembered-exchange prefill follows for that call. No `entry-field guard` complaint in `tr4w.log`.

---

## Added 2026-11-08 -- PREFERENCES: THE CONTEST PAGE IS SPLIT INTO LEAVES; A HEADING WITH NO PAGE LISTS ITS PAGES

The Contest page was one long list. Its settings now sit on eight leaves under Contest, beside Printed log: **QSO settings, Modes, Initial exchange, Multiplier data, Quick QSL, QTC, Contest rules, Cabrillo headings**. Contest itself keeps the rest (Contest, Contest Name, Contest Title, Auto-CQ Delay Time, Grid Map Center, the RST and message rows, ...). Only where a control sits changed: keys, scope and stored values are untouched. `uTestPrefsPlacement` pins every key's leaf and builds the real window to prove each setting has exactly one control. Separately, a heading with no page of its own (today only **External Software**; Operating has its own page) now shows its sentence plus one button per page under it.

- [ ] **The Contest leaves.** Open Preferences with a contest log open. Contest has the eight children above plus Printed log. Each holds only its rows: **QSO settings** -- QSO By Band, QSO By Mode, QSO Number By Band, the four QSO Points rows (QSO By Band/Mode and the points greyed "(set by the contest)"); **Modes** -- Digital Mode Enable, Multiple Modes; **Initial exchange** -- Initial Exchange Filename (Browse...), Use Call History File, Call History Filename (Browse...), Custom Initial Exchange String, Initial Exchange Cursor Pos, Initial Exchange Overwrite, Reverse Initial Ex, Exchange Memory Enable; **Multiplier data** -- Domestic Filename and the three MULT BY / MULT SHEET rows greyed, Mult Report Minimum Bands, Remaining Mult Display Mode, Count Domestic Countries, Show Domestic Multiplier Name, Literal Domestic QTH; **Quick QSL** -- the five Quick QSL rows, QSL Mode, Auto QSL Interval; **QTC** -- QTC Enable, Extra Space, Minutes, QRS; **Contest rules** -- Minitour Duration (greyed), R150S Mode, RFOBL Mode, Sprint QSY Rule, Ten Minute Rule, Single Band Score, Multiple Bands; **Cabrillo headings** -- the seven CATEGORY rows. Nothing appears twice and the Contest page no longer shows any of them.
- [ ] **Search and Ctrl-J land on the leaf.** Search `QTC MINUTES`, `CATEGORY-POWER`, `SPRINT QSY RULE`, `CALL HISTORY FILENAME`: each hit names its new leaf and opens it with the control focused. The same for ShowPreferencesForCommand (any route that opens Preferences at a command, e.g. from a setting's help).
- [ ] **Save round trip.** Change one value on three leaves, Save, reopen the log: the values held, contest-scoped ones in the log, station ones in `settings\tr4w.json` under their OLD keys. `tr4w.log` has no `editor(s) in Preferences` Error.
- [ ] **German.** The five new leaf names (QSO settings, Quick QSL, QTC, Contest rules, Cabrillo headings) are English until translated (fuzzy, empty); nothing is clipped in the tree.
- [ ] **External Software overview.** Click External Software: under "Choose one of the pages listed under this heading." are buttons WSJT-X, External Logger, DXLab, MMTTY. Tab reaches them; Enter or a click opens that page and selects it in the tree. Click Operating: its own page shows as before, no buttons. Click a leaf, then External Software again: the buttons are there once (not doubled).

---

## Added 2026-11-08 -- CALL HISTORY DOWNLOAD (supercheckhistory.com)

Help > Download call history for this contest (SS CW and SS SSB only). Manual only: nothing downloads by itself. NO test touches the site; the one real fetch is yours, by hand, and the site blocks hammering, so do it ONCE and then once more for the 304 -- do not repeat it. (`uCallHistoryDownload`, `uHTTPDownload.DownloadFileConditional`; rules in the supercheckhistory-download-rules memory.)

- [ ] **First download (200).** Open an SS CW log (or SS SSB). Help > Download call history for this contest. The status line shows `Downloading call history...` and then `Call history updated (N entries, <date>); it takes effect the next time the contest is opened`. `target\settings\CallHistoryFiles\ARRL-SS-CW.txt` exists (the writable folder, NOT beside the program) next to `ARRL-SS-CW.txt.meta` (four lines: the ETag, Last-Modified, a UTC time, the file's size in bytes), and no `.tmp`. `tr4w.log` has `[CallHistory] GET https://supercheckhistory.com/downloads/N1MM/ARRL-SS-CW.txt (If-None-Match "", ...)` then `updated: <rows> rows, <usable> usable`, and the `[HTTP] request` DEBUG line shows `User-Agent: TR4W/<version>`. **If it says "the file has too few usable rows"** the 50 % yield threshold (rows that give BOTH check and section) is wrong for the site's real file: tell the agent the numbers on the `[CallHistory] the download was not kept` line; the thresholds are unattended guesses.
- [ ] **Second download (304).** Immediately again: `Call history already current`. `tr4w.log` shows `If-None-Match "<the ETag>"` and `is current (304)`. The file is unchanged (same size and time).
- [ ] **A hand-edited file is not answered 304.** Append a comment line to `ARRL-SS-CW.txt` and download again: the log shows `If-None-Match ""` (no condition: the size no longer matches the sidecar) and the file is replaced.
- [ ] **It takes effect at the next open, and only if it is the file in use.** Tick USE CALL HISTORY FILE with CALL HISTORY FILENAME blank, reopen the log: `[CallHistory]` names `ARRL-SS-CW.txt` and the prefill works (`N6TV`). With CALL HISTORY FILENAME set to another file, the download message adds that the downloaded file is not the one in use.
- [ ] **The legacy file still works.** With only `SSCW.txt` in `tr4w\target\CallHistoryFiles\` and no `ARRL-SS-CW.txt` anywhere, blank CALL HISTORY FILENAME: the log says `reading the legacy file`. Once the downloaded `ARRL-SS-CW.txt` exists it wins.
- [ ] **A contest with no site file.** In any other contest (CQ WW) the menu item says `This contest has no call history download` and nothing is requested.
- [ ] **No network / blocked.** With the network off: `Download failed (<reason>); the previous file was kept`, and the old file and `.meta` are unchanged. (Never provoke a 429 or a block on purpose.)
- [ ] **Replace while open.** Download while the SS log is open and reading the file is not needed (it is read at open only); confirm the replace succeeds on Windows with the file open in an editor or in Explorer's preview.
- [ ] **The Help menu caption and the five messages in another language** (German): the caption is an English fallback until the `.po` entries are translated (they are added as fuzzy, empty). Check nothing is clipped on the status line.

---

## Added 2026-11-07 -- CALL HISTORY FILE PREFILLS SWEEPSTAKES' CHECK AND SECTION

A call history file (N1MM format) is read at contest open into the initial-exchange store; Sweepstakes takes CK then Sect from each row (`uCallHistory`, `TContestBase.CallHistoryFields`). Off by default.

- [ ] **Load.** Put `SSCW.txt` in `tr4w\target\CallHistoryFiles\` (beside the program). With the SS log OPEN (the two settings are contest-scoped, so they are stored in that log), Preferences > Contest > Initial exchange: tick USE CALL HISTORY FILE and set CALL HISTORY FILENAME to `SSCW.txt`. Reopen the log. `tr4w.log` has a `[CallHistory]` Info line: rows, entries added, rows skipped for a missing field, and the time taken (expect well under a second), plus a line naming `!!`directives that are ignored, if any.
- [ ] **Browse picks the file.** Preferences > Contest > Initial exchange: the CALL HISTORY FILENAME row has a Browse... button at its right, inside the page (the edit box is shorter to make room; in German the button reads "Durchsuchen..." and must not be clipped). Blank, the box shows the contest's default greyed (`ARRL-SS-CW.txt` in an SS CW log, `ARRL-SS-SSB.txt` in an SS SSB log; changed 2026-11-08, the old `SSCW.txt` / `SSSSB.txt` are the fallback). Browse opens in the `CallHistoryFiles` folder; pick `SSCW.txt`: the box reads `SSCW.txt` (a BARE name, not a path). Pick a file in any other folder: the box holds its full path. Save, reopen the log: the `[CallHistory]` line names the picked file. INITIAL EXCHANGE FILENAME's Browse... stores the full path of the `.ex` picked. The DVK recorder and MMTTY Browse buttons still work (they now share the same picker).
- [ ] **The contest's default file.** Leave CALL HISTORY FILENAME blank with `SSCW.txt` in the `CallHistoryFiles` folder: SS CW reads it by itself through the LEGACY fallback (the default is now `ARRL-SS-CW.txt`; SS SSB falls back to `SSSSB.txt` -- N1MM's names, NY4I 2026-11-07), and `tr4w.log` says `reading the legacy file`. Then set CALL HISTORY FILENAME to supercheckhistory.com's `ARRL-SS-CW.txt` (its column order differs: `Call,Exch1,CK,Sect,UserText`): same prefill for a call in both files.
- [ ] **Prefill.** Type `N6TV` and move to the exchange: it holds `72 SCV`. `NY4I` gives `80 WCF`, `N4AF` gives `58 NC`. A station whose file row has a one-digit check (e.g. `AA1RB,VA,VA,8`) gives `08 VA`.
- [ ] **Mult needs strip.** Typing `N6TV` names SCV in the "Mult needs for" header, with no check in it.
- [ ] **A spot comment outranks the file.** With CLUSTER SPOT COMMENT MULTIPLIER on and a spot for N4AF whose comment says `WY`, type N4AF: the strip names WY, not the file's NC (the exchange window still offers `58 NC`). Log a QSO with N4AF as NC: the strip then shows NC whatever the spot says.
- [ ] **Nothing changes when off.** Untick USE CALL HISTORY FILE and reopen: no `[CallHistory]` line, no prefill for N6TV.
- [ ] **A missing file** (a misspelt name) gives one `[CallHistory]` Warning in `tr4w.log` and no dialog.
- [ ] **FLUSH INITIAL EX** does NOT write the history entries into INITIAL.EX (only what the log remembers).

---

## Added 2026-11-07 -- THE "MULT NEEDS FOR" STRIP TAKES A SPOT'S SECTION (issue 12 follow-up)

For a typed call the program remembers nothing about, the strip now uses the section/state/county a cluster spot for that call carries in its comment -- the same answer the band map gives that spot. Needs CLUSTER SPOT COMMENT MULTIPLIER on.

- [ ] **ARRL Sweepstakes.** With a spot on the band map for a call you have never worked, comment carrying a section (e.g. `CQ NTX`), type that call: the "Mult needs for" header names the section and the band cells show where it is needed, and it matches the spot's red `M`. Turn the setting off: the strip no longer names it (and the spot's `M` goes too).
- [ ] **What the program remembers wins.** Type a call the LOG or INITIAL.EX holds with a different section than its spot comment: the strip shows the remembered section. (A CALL HISTORY FILE's entry does NOT win: the comment outranks it -- see the call history item above.)
- [ ] **A QSO party** (a county or state in the comment) behaves the same.

---

## Added 2026-11-07 -- ALT-P AND STATIONS OPEN WITH THEIR ROW SELECTED, ON LINUX TOO

On gtk2 a list-view selection written before the list has its window is lost when the window is made (measured on the Linux CI runner; Windows and macOS keep it). Every TR4W list-view selection now goes through `uLCLFormHelpers.SelectListViewRow`, which makes the window first and then writes the row into it. `uTestListViewSelection` shows both real forms off screen and asks the WIDGET which row is selected, with no Linux exception. It passes on Windows; the Linux CI run is its first real test. A screen is still needed to see the highlight.

- [ ] **Linux (gtk2), Alt-P.** Open Alt-P: one row is highlighted, F1 (or the key you right-clicked on the function-key bar). Edit F6, close, open Alt-P again: F6 is highlighted. Change the bank: the first row of the new bank is highlighted. Enter / double-click edits THAT row.
- [ ] **Linux (gtk2), Stations.** With the Stations window open, log or enter a call: its row is highlighted and scrolled into view. Enter a second call: the highlight moves, and only one row is highlighted.
- [ ] **Windows and macOS.** The same two checks, to confirm nothing changed.

---

## Added 2026-11-07 -- THE NEEDS STRIPS AND THE TOTALS GRID SHOW ONLY THE CONTEST'S BANDS (NY4I, Florida QP)

"QSO needs for <call>" listed 160 and 80 in the Florida QSO Party, whose class uses 40/20/15/10 only (the Mult strip already left them blank). The QSO strip's mask now goes through `CreditedBands`, as the Mult strip's does; the totals grid's 160 and 80 headers are blank for such a contest. Columns do not move: an unused band is an empty cell / unnamed column in its usual place. Pinned by `uTestStatusAndNotice` (`Test_TheQSONeedsStripOffersOnlyTheContestsBands`, `Test_TheTotalsHeadersNameOnlyTheContestsBands`) on the streamed form; nothing has looked at a running window.

- [ ] **Florida QSO Party, a call typed.** Both QSO-needs rows (CW and SSB) show 40 20 15 10 and nothing under 160 or 80; the Mult-needs rows as before. The empty 160/80 cells are plain background, no stripes.
- [ ] **The totals grid (top left) in Florida.** The 160 and 80 columns have no header and no numbers; 40-10 and All are named where they always were, and the active band's header is still highlighted.
- [ ] **CQ WW (or any all-band contest).** All six bands still show in both strips and in the totals headers.

## Added 2026-11-07 -- CLOUDLOG / WAVELOG EXTERNAL LOGGER (issue 204)

New contacts go to a Cloudlog or Wavelog instance through `POST <address>/api/qso` (the key is in the JSON body). The unit tests (`uTestCloudlog`) run the real request path against a scripted transport; they cannot talk to a real server. Both programs' behaviour below was read from their source (Api.php, Logbook_model.php), never run. **Neither has an edit or delete call**, so editing or deleting a contact that was already delivered fails visibly instead (decision for NY4I, see `EXTERNAL_LOGGERS_DESIGN.md`).

- [ ] **A real Wavelog and a real Cloudlog.** Preferences > External Software > External Logger > Add > Cloudlog / Wavelog. Address is the site as the browser opens it (add `/index.php` if the site needs it), the API key (a READ AND WRITE key), the Station profile ID (the number in the station locations list). Log a QSO: it appears in the site's log, the row reads Idle, no failure counts.
- [ ] **The station callsign.** Cloudlog answers 401 (the worker halts, "Paused") when the ADIF's STATION_CALLSIGN does not match the station profile's callsign. TR4W only writes that tag when the operator differs from the station call. Log as a different operator and see what the server does.
- [ ] **A duplicate.** Log the same call, band and mode in the same minute twice (dupe logging on). The second is refused by the server: the row shows "Failed: CLOUDLOG_IMPORT_REJECTED", the destination keeps sending the next QSO. Cloudlog reports it as a 201 with imported_count 0; Wavelog as a 400.
- [ ] **A read-only key** (Wavelog): 403, Paused, the QSO stays queued, and fixing the key plus a restart sends it.
- [ ] **A wrong station profile id**: 401, Paused.
- [ ] **A self-hosted https site with a private certificate**: refused (certificates are checked; there is no per-destination "do not verify" yet, issue 224 question 13). An `http://` address is refused too (the key travels in the body; question 12). Confirm the Connection column says so rather than "Idle".
- [ ] **Edit a QSO that was delivered**: the row shows "Failed: CLOUDLOG_EDIT_UNSUPPORTED" and nothing is changed or duplicated on the server. **Delete one**: "Failed: CLOUDLOG_DELETE_UNSUPPORTED", the server keeps it. Neither halts later QSOs.
- [ ] **The log** (DEBUG LOG LEVEL = DEBUG): the `[HTTP] request POST` line shows `"key" : "********"` and the key appears nowhere in tr4w.log.
- [ ] **Rate limit** (Wavelog): if the server answers 429 the row says Retrying, and the QSO is sent after the Retry-After seconds. Needs a server with the limit turned low.

---

## Added 2026-11-07 -- THE SPOT'S M BY WORKED COUNT: RED, ORANGE, NONE (issue 12)

NY4I's ruling replaced the orange `B` built earlier the same day. A cluster spot's multiplier indicator now follows how many times its multiplier is WORKED (credited, non-dupe QSOs), against the new setting BAND MAP WORKED MULT LIMIT (N, 1..9, default 1): 0 worked is the red `M`; 1 up to N-1 is the same `M` in BAND MAP WORKED MULT COLOR (orange: a backup wanted), with orange text in the Telnet window; N or more shows no `M`. A dupe stays yellow `D`. **At the default N = 1 there is no orange state; set N = 2 for the items below.** Both settings are in Preferences > Band Map > Window and tuning. The unit tests pin the counting (Sweepstakes across bands, CQ WW per band, a dupe and an X-QSO not counted, a delete rebuilding the count); they cannot see the screen. For Sweepstakes the section reaches TR4W from the call history or the spot comment, so turn CLUSTER SPOT COMMENT MULTIPLIER on if the spots carry sections.

- [ ] **ARRL Sweepstakes (CW), N = 2.** Take a spot in a section you have not worked (e.g. `CQ WY`): red `M`. Work a station in that section (W7WYS): the spot's `M` turns orange, on every band (a section counts once). Work a second station in that section (K7OWY): the `M` disappears. Delete the second QSO (Alt-Y on the last entry, or delete it in the log): the orange `M` comes back. Delete the first too: the red `M` comes back.
- [ ] **Default N = 1.** The same first working removes the `M` altogether, as before issue 12.
- [ ] **MULTS ONLY keeps the orange M.** With N = 2, one station worked in a section, and BAND MAP MULTS ONLY on: the spot for that section stays on the band map with its orange `M` (as it does in the cluster window); a spot with no `M` is hidden; a CQ spot stays.
- [ ] **A dupe does not count.** With N = 2 and one station worked in the section, log a dupe of that station: the spot stays orange.
- [ ] **A spot with no section** (no comment, no call history) shows no `M`.
- [ ] **A per-band contest** (CQ WW, N = 2): a country worked once on 20 m is an orange `M` on 20 m and still the red `M` on 40 m.
- [ ] **Reopen the log.** With N = 2 and a section worked once, close and reopen the contest: the spot is still orange (the count is rebuilt from the log).
- [ ] **The colour.** Change BAND MAP WORKED MULT COLOR: the orange `M` and the Telnet lines change colour. Is orange readable on your band map background?
- [ ] **Multi-op.** Two stations sharing spots: each shows the state from ITS OWN log, not the sender's.

---

## Added 2026-11-06 -- A DROP-DOWN ROW CARRIES ITS OWN TAG (issue 216, stage A)

Every tagged drop-down and list in Preferences, the radio editor and the keyer editor kept its stored values (a radio id, a COM port, a profile name, a keyer kind) in a second list beside the control. Each row now carries its value in the control's own per-row slot (`Items.Objects[]`). `uTestComboTags` checks this on the Windows widget set, with and without a window. What it cannot check is the other widget sets, or the real dialogs end to end.

- [ ] **Radio editor.** Open the editor and pick a radio type, a CAT port and a keyer port. Click Discover if a radio is attached. Save, then reopen. Each choice is the one you saved, not its neighbour in the list.
- [ ] **Keyer editor.** Change Kind, WinKeyer mode and sidetone. Save and reopen: the same three values come back. Open the editor twice in a row: no list has doubled.
- [ ] **Preferences.** Switch the station profile, then add a new profile and select it. The profile list follows your choice. The same goes for the rotator port and the CW output list.
- [ ] **macOS and Linux (gtk2).** The same three checks. Those widget sets keep a row's value in their own lists, and no test reaches them.

---

## Added 2026-11-06 -- THE EXTERNAL LOGGER EDITOR LAYS ITSELF OUT FROM MEASUREMENT (issue 232)

The editor's rows used fixed 96-dpi pixels (captions 190 wide, boxes at 200, 42 px rows, Refresh 90 wide). `TExternalLoggersForm.FitLayout` now runs on every show and provider change. The caption column is as wide as the widest caption. Refresh is as wide as its caption needs. Every row is as tall as its tallest control, and the eye is square at its box's height. The status and note lines are as tall as their wrapped text, and the dialog grows (or shrinks back to its designed width) about its centre.

`uTestExternalLoggerEditorLayout` opens every registered provider off screen at the default font, at 14 pt, and on a form adjusted to 144 ppi. It checks for overlap, for controls outside their parent, and for clipped captions and buttons. That is on the Windows widget set only.

TR4W's Windows manifest declares no DPI awareness. At 150% Windows therefore stretches the window as a bitmap, and the layout is the 100% one, enlarged.

**The dialog is shorter at 100% by design.** It used to keep empty room for four provider rows, and it is now as tall as the rows the provider has. Every provider has two rows, so the dialog measures 710x358 where it was 710x510. The widths and the left edges are unchanged.

- [ ] **Windows at 150%.** Open the editor for WRL, Club Log and DXKeeper. Check that nothing is cut off and Refresh and the eye are inside the dialog. Also say whether the text is blurry: that comes from the manifest, not this change, but it is worth knowing.
- [ ] **macOS.** Open the editor for each provider and check these things:
  - no caption is cut off;
  - the Logbook drop-down shows its name clear of its arrows;
  - Refresh, Save to Preferences and Cancel show their whole captions;
  - the eye sits beside the key box at the box's height;
  - the note under the check box shows all its lines.
- [ ] **Linux (gtk2).** The same checks as macOS, on DejaVu Sans.
- [ ] **Provider change while open.** Switch DXKeeper -> WRL -> Club Log -> DXKeeper. The rows re-fit each time and the dialog does not walk across the screen.

---

## Added 2026-11-06 -- EDIT QSO LAYS ITSELF OUT FROM MEASURED WIDTHS (NY4I, macOS screenshot)

On the Mac, Band and Mode showed only `10` and `C`, with the up/down arrows over the text. The Date control's drop-down button covered the Zone label, so it read `ne`. `Frequency, Hz`, `Number Sent` and `Number Rcvd` were clipped.

The window now lays its fields out in `TfrmEditQSO.FitLayout`, which runs on every open:
- Each label column is as wide as its widest caption.
- Each field column is as wide as its widest need. For a drop-down that is its longest item plus a stated chrome allowance (`DROPDOWN_CHROME_96` = 40 px at 96 dpi), held as a `MinWidth`. For the date picker it is the picker's own measured width.
- The check-box column is as wide as its widest check box or button.
- Rows are as tall as their tallest control.
- The window may grow, and it keeps its centre.

`uTestEditQSOLayout` shows the real form off screen and checks it, **on Windows only**, at the default font and at 14 pt. It checks for overlap, for clipping and for the drop-down widths, and that a second layout moves nothing. **It cannot see cocoa.** Win32 reports no preferred width for a drop-down, so the test proves the width is set and held, not that an NSPopUpButton draws its text clear of its arrows. The 40 px allowance is a guess until the Mac answers. With `DEBUG LOG LEVEL = DEBUG` each open logs `[EditQSO] layout: columns a/b/c/d/e, form WxH (was WxH)`.

On the Mac, open Edit QSO from the log, once at the default window text size and once at a larger one. Not verified: whether macOS's own text-size setting reaches an LCL window at all. If it does not, say so; that is itself a finding.
- [ ] **Band and Mode**: the whole value is readable (`160`, `CW`, `DATA-FM`, `D-STAR`) and the arrows sit to the right of the text, not over it. Open each list; every item reads in full.
- [ ] **Date**: the date and time read in full. The drop-down button sits inside the field column and clear of the Zone label.
- [ ] **Labels**: `Frequency, Hz`, `Number Sent`, `Number Rcvd`, `RST received`, `Ten Ten Number`, `Computer ID`, and the our-station `CQ zone` / `ITU zone` / `Section` all read in full.
- [ ] **Check boxes**: `Domestic Mult`, `Inhibit Mults` and the others read in full in the right-hand column.
- [ ] **Save and Cancel** are visible and fully inside the window. So are the our-station group and, on a QSO with an external-logger row, the delivery line.
- [ ] **Position**: the first open is centred over the main window. Move it, close it, and reopen it in the same session: it is where you left it and has not jumped. Edit QSO saves no position across a restart, and it never did.
- [ ] **Windows at 150%**: the same look, nothing clipped or overlapping. Only a font change was simulated on Windows, never a real DPI change.

## Added 2026-11-06 -- PREFERENCES: "MORE SETTINGS" IS GONE; EVERY SETTING HAS A TASK PAGE (issue 235)

Every setting that was on **More settings** is now on a task page, and so is the band plan's Edit... button. More settings itself is removed. The Operating page's one CW-only box, AUTO CALL TERMINATE, moved with the CW settings. Stored keys and command names did not change, so an existing `settings\tr4w.json` loads unchanged. A placement table in `uPrefsForm` decides where each control goes. `uTestPrefsPlacement` builds the real window against an empty settings folder and checks three things: every one of those settings has exactly one control, no page carries the old tag, and the band plan button is on the Bands page. What no test sees is geometry, scaling, and whether a search lands on the control. Each time Preferences builds its pages, it logs an Error for a setting with no control or with two: `[Prefs] "<key>" has N editor(s) in Preferences; it must have exactly one`.

- [ ] **The tree.** There is no **More settings** entry; **Files and updates** is in its place.
  - Operating has **Entry and dupe checking** and **Messages**, and no **CW**.
  - Operating > Band Map has a child, **Window and tuning**.
  - CW Settings has **Paddle and PTT**, **While operating** (the page that was Operating > CW) and **Speed and characters**.
  - DX Cluster has **Spots and console**.
  - Appearance has **Log display**.
  - Contest has **Printed log**.
- [ ] **New pages, one look each** (headings, no overlap, every row reachable by scrolling):
  - **Entry and dupe checking**: Dupe checking / Search and pounce / Typing / What a QSO records / Entering a log by hand.
  - **Messages**: De Enable.
  - **Speed and characters**: the speed, cut-number, character and auto-send settings, including *Stop sending when the call window changes*.
  - **Window and tuning**: the band map size and split settings, plus the QZB offset.
  - **Spots and console**: Ask For Frequencies, QSX Enable, the spot-comment multiplier, packet broadcast, console lines.
  - **Log display**: Rate display / Log window / Information shown under the call window.
  - **Files and updates**: country file, CTY update check, unknown-country file name.
  - **Printed log**: Log Sub Title and Contacts Per Page, under a note that the log is not printed and they have no effect yet.
- [ ] **Blocks on designed pages.** Each sits below the page's last designed control, with nothing overlapping and nothing cut off at the bottom:
  - Station: your own callsign for New Contest.
  - SCP: the four suggested-call keys.
  - Network: computer name, status interval, stations mask, show typed callsign, allow auto update.
  - Audio: Alerts (dupe sound, wake-up time-out, beep) and Voice keyer (missing-callsigns file).
  - Two Radio Mode: Tune Alt-D Enable.
  - Band Map: Ie Switch.
  - Hardware: YCCC box (Stereo Pin High). ~~**Radio polling - one rate for every radio** (Frequency Poll Rate)~~ -- moved to each radio's definition (issue 235 step 3, 2026-11-06); Hardware no longer has a polling block. See the entry below.
  - Bands: band, mode, frequency memory, and the **band plan Edit... button**, which opens the same editor with its own save.
- [ ] ~~**Contest page**: after the contest's own rows come *Digital Mode Enable*, *Initial Exchange Filename*, and *Domestic Filename*, which is greyed with "(set by the contest)" and cannot be edited.~~ -- the Contest page was split into leaves on 2026-11-08; those three are on Contest > Modes, > Initial exchange and > Multiplier data. See the 2026-11-08 entry.
- [ ] **Advanced**: Radius Of Earth is at the end.
- [ ] **The Operating page** has no *Stop sending when the call window changes* box; the boxes below it moved up with no gap, and Tab still moves down in order. Its introduction says CW is under CW Settings and fits in two lines.
- [ ] **Search and deep link.** Search for a few old command names: `DE ENABLE`, `FREQUENCY POLL RATE`, `POSSIBLE CALL MODE`, `TELNET CONSOLE LINES`, `BAND MAP SIZE`, `DIGITAL MODE ENABLE`, `COUNTRY INFORMATION FILE`, `MAIN CALLSIGN`. Each hit names its NEW section and lands on its control. (Since issue 235 step 3 `FREQUENCY POLL RATE` is NOT a Preferences setting -- it is in the radio editor -- so it should find nothing in Preferences; drop it from this list once confirmed.)
- [ ] **Save and Cancel.** Change one moved value on each of three pages and press Cancel: nothing changes on disk. Change them again and Save: `settings\tr4w.json` holds them under their OLD keys (`operating.ctrlj.*`, `cw.ctrlj.*`, ...).
- [ ] **150% scaling.** The blocks still sit below their pages' last designed control. They are anchored to it, but their own rows are 96-dpi pixels, like every generated row.
- [ ] **tr4w.log after opening Preferences** has no `editor(s) in Preferences` Error and no `placement ... refused` line.

## Added 2026-11-06 -- FREQUENCY POLL RATE IS PER RADIO (issue 235 step 3)

The station-wide `FREQUENCY POLL RATE` (Preferences > Hardware, temporarily) is gone; each radio definition carries its own `frequencyPollRate` (10..1000 ms, default 10), edited on the radio editor's **Advanced** tab. For every native driver it is the polling loop's tick -- how often what the driver knows reaches the program -- and for a serial driver declaring `honorsFreqPollRate` (K4 over serial, Ten-Tec Orion, and the others that keep the base default) it is also the CAT poll interval; HamLib keeps its own 50 ms tick. The store, the copy/compare paths, the applied-radio comparison, the clamp, the old-value precedence and the one-time seed are unit-tested (`uTestRadioConfigStore`, `uTestSettingsModel`); what no test does is a real editor, a real radio and a real upgrade.

- [ ] **The editor control.** Open a radio in the radio editor, Advanced tab: a *Frequency Poll Rate* row under the transverter offset shows the radio's rate (10 on a new radio), its tooltip is the FREQUENCY POLL RATE help and says the rate is per radio, Tab reaches it last on that tab, and the row is not cut off. Tick *Drive through HamLib*: the row greys; untick: it comes back with its value. A HamLib-only type greys it too. Type 5 or 5000 and Save: an error names 10 and 1000 and nothing is saved; blank saves the default.
- [ ] **A changed rate reaches a LIVE radio after Save.** With a serial K4 (or K3) active at 10 ms, set its rate to 500, Save: `tr4w.log` shows the radio torn down and rebuilt, `[ApplyProfile] radio 1 frequency poll rate 500 ms`, and `[pFactoryRadio] Serial polling interval set to 500ms` after it reconnects; turning the VFO updates the display about twice a second rather than continuously. Set it back to 10 and Save: smooth again, without a restart.
- [ ] **An old station's value survives the move.** With a `settings\tr4w.json` from a build before this one whose `Operating.FrequencyPollRate` is NOT 10 (say 100), start this build once: `tr4w.log` has `[Radios] the station's FREQUENCY POLL RATE (100 ms) is now set on N radio definition(s)`, every radio in the file gains `"frequencyPollRate" : 100`, the `Operating` group no longer carries it after the next Preferences save, and a second start logs no seed line. With the old value at 10 nothing is written and every radio reads 10.
- [ ] **A contest `.cfg` naming FREQUENCY POLL RATE** loads with no "invalid statement" dialog and no radio's rate changes. Expect TWO log lines: "is read from the settings store, not from this file", and -- misleadingly, the same for every store-owned name such as the WK and UDP ones -- `LogCfg`'s "overrides the stored value for this contest", although nothing is overridden.

## Added 2026-11-06 -- A DRAGGED GRID COLUMN IS REMEMBERED -- PER USER, AND THE MAIN LOG PER CONTEST (issue 234)

Column widths an operator drags are kept in a new `columns` section of `settings\tr4w.json` (grid name -> column token -> width at 96 dpi), for the B4 list, View/Edit Log, Search, the Server log, the External logger grid and the Colours grid. **The main log is the exception (NY4I): its widths are kept per contest, in the contest database** -- `COLUMN WIDTH <token>` rows of its config table, the rows older builds wrote -- because the columns it shows depend on the contest. The store, the file section, the database round trip, the 96-dpi conversion, the clamp and a drag-then-restore on a fresh grid are unit-tested (`uTestColumnWidthStore`, `uTestExternalLoggerGrid`); what no test does is a real mouse, a real restart and a real translated header. A per-user drag is written when its window closes, at exit, and by the 5-second layout autosave; a main-log drag is written into the contest database when the log closes (exit, or File > Open Log), so a crash loses it, as it loses any contest setting changed in that session.

- [x] **Main log, per contest.** With a `.db` contest open, drag the Callsign column's divider wider, exit TR4W, restart into the same contest: the column comes back at the dragged width. `settings\tr4w.json` gains NO `"MainLog"` entry. Then open a different contest (File > Open Log): its main log has its own widths, not the first contest's. (A `"MainLog"` entry a build from earlier on 2026-11-06 wrote into `tr4w.json` is now ignored and carried through untouched.)
- [x] **The corpus-era rows are read now.** Open a contest whose database already holds `COLUMN WIDTH` rows (the ARRL FD 2026 and CQ WPX CW 2026 logs do): the main log opens at those widths, and `tr4w.log` no longer says `"COLUMN WIDTH CALLSIGN" is an action, not a setting -- ignored`. AGENT - I opened ARRL FD 2026 but no message so this passes.
- [x] **B4 list (previous dupes).** Bring the B4 list up (a dupe), drag a column, let it go away, exit, restart, bring it up again: the dragged width is back. It is kept apart from the main log's (`"PreviousDupes"`).
- [x] **View/Edit Log.** Open it, drag a column, close it, reopen: same width; restart TR4W and reopen: same width (`"ViewEditLog"`). AGENT - Not retained after restart.
- [x] **Search Log.** Same check (`"SearchLog"`).
- [ ] **Server log (Net > Synchronize with the server).** Open it, drag a column, close, reopen after a restart: same width (`"ServerLog"`).
- [x] **External logger grid.** In Preferences > External logger, drag the Logger, Provider and Enabled dividers, close Preferences (Save or Cancel -- a width is kept either way), restart, reopen: same widths, and the Connection column still fills to the right edge with no gap. Connection itself and the hidden columns are never saved (`"ExternalLoggers"` holds only `Logger`, `Provider`, `Enabled`).
- [x] **Colours grid.** Preferences > Colours: drag a column, close, restart, reopen: same width (`"Colors"`).
- [x] **Colours grid fills to its right edge.** Preferences > Appearance > Colors: Sample reaches the grid's right edge (against the vertical scrollbar) with no white band, at the designed size, after widening Preferences and after dragging Element/Text/Background; a narrowed window clips Sample at its measured width (no horizontal bar). `"Colors"` never gains a `Sample` entry. Measured on Win32 in `uTestExternalLoggerGrid` only.
- [ ] **A translated header wider than the saved width.** Drag a log column (say UTC) narrow, exit, switch the display language to one whose header for it is longer, restart: the column opens at least as wide as its header text, never cutting it off.
- [ ] **An old contest database with COLUMN WIDTH rows** (written by a much older build): the MAIN LOG opens with those widths (read as 96-dpi pixels -- those builds were not DPI-aware, so that is what they saw), a column you drag afterwards keeps the new width, and a row too narrow to read opens at its header's width. The other log grids no longer read those rows; they are the main log's.
- [ ] **150% scaling.** Drag at 100%, restart at 150%: the columns come back one and a half times as wide, not the same pixel count.
- [x] **Every log grid fills to its right edge, with no white band.** On the main log, B4 list, View/Edit Log, Search and Server log: the last column reaches the grid's right edge (in the main log that is Op), at startup, after dragging a divider narrower (the other columns widen at once), and after resizing the window. Measured on Win32 in `uTestColumnWidthStore` only (`LogGridFill`); not yet seen on screen or on gtk2.

## Added 2026-11-05 -- HTTP TRANSPORT SEAM, NOTHING SHOULD LOOK DIFFERENT (issue 224, S1a)

The FPC + OpenSSL client moved out of `uHTTPDownload` into `uHttpTransportGeneric` with no intended change. The unit suite (425,000+ checks, including a loopback contract suite) is green; what it cannot do is talk to a real server over TLS.

- [x] **A real Club Log (or WRL) send, and a real download.** With the real DLLs and `cacert.pem` beside the program, log a QSO to a throwaway Club Log account and see it confirmed; Alt-O (CTY) and Help > version check complete. `tr4w.log` shows one `[HTTP] transport: generic` line at the first request (it is an Info line: set `DEBUG LOG LEVEL` to INFO or lower to see it).
- [ ] **`test\integration\tls-verify-probe` still rejects the four bad certificates** (expired, wrong host, self-signed, untrusted root) and accepts a good host. It goes to badssl.com, so it is hand-run only.

## Added 2026-11-06 -- ITU-ZONE CONTESTS SEND THE ITU ZONE; BLACK SEA CUP SCORES IT (issue 225)

The default CW exchange messages FoundContest writes, and the default CQ exchange of IARU, both OZCHR and LZ DX, send the zone the export prints: the ITU zone (stated MY ITU ZONE, else CTY.DAT's for MY CALL), never a stated CQ MY ZONE. The Black Sea Cup's same-zone point is the QSO's ITU zone (as IARU's). Unit-tested (`uTestITUZoneContests`); nothing drives the message windows or keys a radio.

- [ ] **IARU, CQ zone stated.** From a K/W4 station state MY ZONE 5, leave MY ITU ZONE unset, open a new IARU HF log with no MY STATE. The CQ EXCHANGE and S&P EXCHANGE messages read `599 8`, not `599 5`; the CQ F3 memory and the exchange F4/F5 memories carry `8`. The Cabrillo sent column also says 8.
- [ ] **MY ITU ZONE stated.** Same, with MY ITU ZONE 7: the messages and the export both say 7.
- [ ] **CQ WW unchanged.** A CQ WW log at the same station still sends `599 5`.
- [ ] **Black Sea Cup.** With MY ZONE 5 stated, log W1AW `8`: 1 point; VE3 `4`: 3; F4HQ `27`: 5; LZ1AAA `28`: 10.

## Added 2026-11-05 -- IARU: THE SAME-ZONE POINT IS THE QSO'S OWN ITU ZONE (issue 222)

Scoring asks the QSO's recorded my_itu_zone, or for the QSO being typed now the session's ITU zone (stated MY ITU ZONE, else CTY.DAT's for MY CALL), and never the stated MY ZONE. Unit-tested (`uTestIARUScoring`) and checked headless (the iaru_hf fixture with `Zone: 5` rescores to 12). What no gate drives is typed live entry.

- [ ] **Typed, with a CQ zone stated.** In an IARU HF log from a K/W4 station, state MY ZONE 5 (leave MY ITU ZONE unset). Log W1AW with exchange `8`: the QSO scores 1 point (log window and Edit QSO). Log F4HQ `27`: 5 points. Log a VE3 `4`: 3 points. Log W1AW `ARRL`: 1 point.
- [ ] **Rescore agrees.** Run the rescore (or reopen the log): every point above is unchanged, and the total matches the claimed score in the Cabrillo.

## Added 2026-11-05 -- PREFERENCES > EXTERNAL LOGGER GRID EDITING (issue 220)

The External Logger grid is the editor now; the separate "Configure external loggers..." dialog is gone. The order/toggle/remove logic is unit-tested (`uTestExternalLoggerGrid`, the drag driven through the grid's own `MoveColRow`); what no test can do is a mouse and a popup.

- [x] **Add each provider.** Press Add..., choose DXKeeper, then World Radio League, then Club Log, fill the fields, "Save to Preferences". Each appears as a new row (inactive: Order "-", Send new QSOs "No"). The Club Log field captions work in the one-definition editor.
- [x] **Right-click edit / toggle.** Right-click a row (not the one already selected): the row under the pointer becomes selected and the menu offers Edit..., Send new QSOs (a tick when on), Move up, Move down, Remove.... Edit changes the name and the row follows. Send new QSOs ON gives it the next Order number; OFF moves the row below the active ones and its Order becomes "-". Double-click the Send new QSOs cell toggles; double-click elsewhere opens Edit. Switching ON a logger whose required field is blank is refused with the message.
- [x] **Drag to reorder.** Press on the ORDER cell (the grey left column) of an active row, drag it above/below another active row, release. Order numbers renumber, the moved row stays selected. Drop an inactive row among the active ones: it springs back to the inactive group and nothing else changes. Pressing on the Logger/Provider cells must NOT drag (that is expected; it only selects).
- [x] **Move up / Move down** in the popup do the same as the drag and are disabled at the edge of the group.
- [x] **Remove.** Remove... asks; Yes drops the row, No keeps it. The wording says pending deliveries stay in the contest log and are not redirected.
- [x] **Cancel discards.** Make several grid edits, press Cancel in Preferences: reopen and the grid is as it was. The page still says to Save and restart.
- [x] **Save, restart, order kept, delivery order honoured.** Make two loggers active, reverse them by dragging, Save, restart TR4W, reopen: same order. Log one QSO with a contest open and check the order the two destinations were handed it (tr4w.log; both loggers' first line for that QSO).
- [x] **First definition on a clean station.** On a settings file with no external-logger section, Add... on the legacy page creates the first definition and the page switches to the grid.
- [ ] **Layout.** The grid, Add... button and the hint line below do not overlap at 100% and 150% scaling. The Order column is visibly a fixed (header-coloured) column.

## Added 2026-11-06 -- NO WRL SETUP DIALOG, AND THE EYE SITS BESIDE ITS BOX (issue 231)

TR4W no longer creates WRL logbooks (NY4I: use the WRL website or app), so the "Set up World Radio League..." button and its dialog are gone. The eye was a fragment in the editor because the editor's rows were anchored to the right edge of a panel that is stretched after they are built; `uTestPasswordRevealLayout` now SHOWS the editor (and the generic input prompt) off screen and measures the eye, the Logbook drop-down and Refresh. What it cannot see is the drawing and the real DPI.

- [x] **WRL editor.** Edit a WRL logger: an API key row with a visible eye, a "Logbook" row with a drop-down showing a NAME and its arrow, a Refresh button to the right of it inside the dialog, and no "Setup" or "Set up World Radio League..." button anywhere. Refresh loads the names; Save to Preferences works.
- [x] **The eye, everywhere.** Type something in the WRL key box and in the Club Log token box: the eye is a complete eye (lids and pupil, not a bracket), sits right of the box at the box's height, and clicking it shows and hides the text. Same in Preferences (cluster password, network password, HamScore password), the radio editor's password and the generic password prompt.
- [ ] **150% scaling.** Open the External logger editor at 150%: the rows still fit inside the dialog (the row captions and heights are fixed pixel values and were not measured at 150%).
- [ ] **Preferences > External logger, legacy single-logger page.** On a settings file with no external-logger section, the type list no longer offers WRL (it is chosen through Add...); a station whose stored type is already WRL still shows it.

## Added 2026-11-06 -- THE EXTERNAL LOGGER EDITOR SHOWS WHAT EACH PROVIDER NEEDS (issue 227)

The one-definition editor builds its rows from the provider's own declaration (`uExternalLoggerRegistry`). The descriptors, the start-up check, the JSON and the editor's behaviour on a streamed form are unit-tested (`uTestExternalLoggerFields`); the real WRL drop-down, the look of the rows and the modal flow are not.

- [x] **WRL edit shows a key and a logbook NAME, no UUIDs.** Edit an existing WRL logger. There is an API key (masked, with the eye) and a "Logbook" drop-down showing a NAME. No "Email / account ID" box and no box holding an id appears anywhere. With a key present the drop-down fills by itself (the status line says Loading... then clears) without freezing the dialog.
- [x] **An old WRL definition opens and keeps working.** A WRL logger saved BEFORE this change (no name stored): the drop-down opens on "Saved choice (refresh to see its name)". Press Save to Preferences without touching it, restart, log a QSO: it still goes to the same logbook (`[WRL]` lines in tr4w.log, same account and logbook). After the list loads the name appears; saving again keeps the same logbook.
- [ ] **Offline.** Unplug the network and open a WRL logger: the saved logbook name is still in the drop-down, Refresh reports "The list could not be loaded: ... The saved choice is kept.", Save to Preferences still works.
- [ ] **Pick another logbook, replace the key.** Choose a different logbook, Save, reopen: the new name shows. Type a different API key: the drop-down empties; Save is refused for an ACTIVE logger until a logbook is chosen again (Refresh first).
- [ ] **Club Log.** The editor shows "Club Log callsign" (plain text) and "Club Log API token" (masked) and nothing else; Save/restart/log a QSO still reaches Club Log.
- [ ] **DXKeeper.** The editor shows Host / IP address and Port only. Change provider DXKeeper -> Club Log -> DXKeeper: the host and port you typed are still there.
- [ ] **Layout.** The rows, the Refresh button and the status lines do not overlap at 100% and 150% scaling.

## Added 2026-11-05 -- THE TNC PACKET OBJECT IS A CLASS (pointer audit 6.6, Issue 89)

`logpack.PacketObject` was an old-style `object` and is a `class` now, created and freed by the unit. The ring and line-buffer logic is unit-tested (`uTestLogPack`); a serial port is not.

**Bench: TNC packet over a serial port still connects, receives spots, sends commands.** Needs a TNC (or a null-modem loop with a spot generator). IMPORTANT, read before benching: in this tree the serial calls inside `PacketObject` (`SetUpPacketPortAndBuffer`, `SendPacketMessage`, the `CheckPacketBuffer` reader) are commented out and `CheckPacket` is empty, so this tree may never have driven a TNC; D7 fed telnet spots to `Packet.ProcessPacketSpot` directly. If the bench shows no TNC traffic at all, that is the existing state, not this change; compare against a build from the commit before it.

## Added 2026-11-05 -- A REMAINING MULTIPLIER IS A TYPE, NOT TWO PACKED HALVES (pointer audit P9, 5.1c)

Each cell of the remaining-multiplier windows (the generic one and the DX,
domestic, zone and prefix ones) was a (kind, index) pair packed into two 16-bit
halves of one integer in the flow grid's `Objects[]`, and unpacked with
`LoWord`/`HiWord` -- `WIN32_ARTIFACT_SWEEP.md`'s worked example. It is a
`TRemainingMult` the grid owns now. **Also changed in the same paint handler**: the
faded fill of a worked multiplier is `TCanvas.GradientFill` (as the band map's mult
flag already is) instead of `uGradient.GradientRect` on the canvas's HDC -- same two
colours, same left-to-right direction. `uTestFlowGridCells` pins the kind and index
of every cell; the text, the worked test and the colours are BENCH only.

- [ ] **A contest with DX and zone multipliers (CQ WW), a few multipliers worked.**
  Open Remaining Mults (DX) and (Zone). EXPECT: every country prefix and every
  zone number shows, as before. With `REMAINING MULT DISPLAY MODE = HILIGHT`, the
  worked ones are faded from their colour to white with white text, left to
  right, and the unworked ones plain black. With `ERASE`, worked ones are gone.
- [ ] **A domestic-multiplier contest (a state QSO party).** Open Remaining Mults
  (Domestic), with `SHOW DOMESTIC MULTIPLIER NAME` both off and on. EXPECT: the
  abbreviations, then the names. Work one; EXPECT it to fade or vanish on the
  next refresh. Change band; EXPECT the window to follow the band.
- [ ] **A prefix-multiplier contest (WPX).** Open Remaining Mults (Prefix), work a
  new prefix, change band. EXPECT the same prefixes, in the same colours, as a
  build before this change shows for the same log.
- [ ] **Clean sweep.** Where practical (a small domestic list), work them all.
  EXPECT the congratulations text at the top left, as before.

## Added 2026-11-05 -- AN SCP CELL CARRIES ITS DUPE FLAG AS A TYPED CELL (pointer audit P9, 5.1b)

Each cell of the Super Check Partial window knew whether its call is a dupe
through the flow grid's `Objects[]` as `Ord(isDupe)`. It is a `TMasterCell` the grid
owns now. `uTestFlowGridCells` pins the flag, the "show only what fits" refusal and
(under `-Checked`) that a refused cell is freed; what it cannot see is the paint.

- [ ] **SCP window open, a contest with some QSOs logged.** Type a partial call
  that matches both worked and unworked calls (e.g. `K1`). EXPECT: the worked ones
  in the dupe colour with white text, the rest plain, as before. Keep typing and
  deleting letters. EXPECT: the window refills on each keystroke with the right
  calls coloured.
- [ ] **A partial that matches more calls than fit (e.g. `W`), then shrink the
  window.** EXPECT: it shows as many as fit and no more, no error, and growing
  the window then typing again shows more.

## Added 2026-11-05 -- A DUPE SHEET CELL CARRIES ITS DISTRICT AS A TYPED CELL (pointer audit P9, 5.1a)

Each dupe-sheet cell knew its call district (the digit that picks its colour)
through the flow grid's `Objects[]` as `Ord(digit)`. It is a `TDupeSheetCell` the
grid owns now. `uTestFlowGridCells` pins the round trip and, under `-Checked`, that
a rebuild frees the cells it replaces; what it cannot see is the paint.

- [ ] **Dupe sheet 1 and 2, in a log with contacts in several call districts.**
  Open the dupe sheet (both radios if SO2R). EXPECT: each call's cell is filled
  with its district's colour, as before -- W1, K3, N6 and VE3 calls in their own
  colours. Change band, then mode. EXPECT: the sheet redraws with that band and
  mode's calls, colours still right. Log a new contact. EXPECT: it appears in its
  district's colour.
- [ ] **Leave the dupe sheet open through a session of band changes, then exit
  TR4W with it open.** EXPECT: no access violation and no crash record in
  `tr4w.log` at exit.

## Added 2026-11-05 -- A DX CLUSTER CONSOLE LINE CARRIES ITS KIND AS AN OBJECT (pointer audit P9, 5.3)

Each line of the DX cluster console knew its kind (sent, received, dupe, mult,
error, alert -- what colours it) through `Items.Objects[]` as `Ord(kind)`. It
points at one of seven `TConsoleLineKind` objects the form owns now.
`uTestTelnetConsoleKinds` pins the kinds through adds, the scrollback trim and
Clear on a streamed form; what it cannot see is the paint.

- [x] **DX cluster window, connected, a few minutes of traffic.** EXPECT the
  colours as before (`TelnetStringColor`): a command you send in blue,
  received lines and status lines black, a spot for a dupe light grey, a spot
  for a new multiplier red, errors red, an alert black on a yellow band.
- [ ] **Scrollback trim.** Set `TELNET CONSOLE LINES` to its minimum, 1000, and
  let it run past that (SH/DX 50 a few times, or a busy evening). EXPECT: the oldest lines leave from the top and every line
  that stays keeps its colour -- an alert keeps its yellow band after the lines above it
  are trimmed. Then Clear, and new lines take their own colours.
- [ ] **Close TR4W with the cluster window open and full.** EXPECT: no access
  violation and no crash record in `tr4w.log` at exit.

## Added 2026-11-05 -- THE SEARCH LOG FILTERS KNOW THEIR ROWS BY A TYPED ARRAY (pointer audit P9, 5.2)

Which band or mode a row of the Search Log's Band and Mode drop-downs means rode
in `Items.Objects[]` as `Ord(value) + 1`. It is a typed array the form builds in
the same pass as the rows now (`FBandRows`, `FModeRows`). `uTestLogSearchFilters`
pins the mapping on a streamed form; what it cannot see is the window in use.

- [ ] **Search Log, in a log with QSOs on at least three bands and two modes.**
  Clear the main call entry, then open Search. EXPECT (issue 230): the Band
  drop-down lists exactly the bands the LOG holds -- not the contest's bands --
  Mode exactly the log's modes (never `NON`), and Operator the log's operators;
  `tr4w.log` has `[LogSearch] the log holds N band(s), M mode(s) ...`. An empty
  box searches nothing, so the grid stays empty. Now type a partial call that
  was worked on several bands and pick each band in turn. EXPECT: the grid
  shows only that band's QSOs, and the Band column agrees with the drop-down.
  Do the same for Mode. Then type a partial call (e.g. `N6`) with 20 m chosen.
  EXPECT: 20 m stays chosen while the list of bands narrows to those the matches
  contain. Still on 20 m, change the call to one never worked on 20 m. EXPECT:
  Band falls back to All. Pick All on both. EXPECT: every QSO the call
  matches.
- [ ] **Log a QSO on a new band with Search open and its box empty.** EXPECT:
  the new band appears in the Band drop-down (the log is read again after a
  QSO, once, not on every keystroke).
- [ ] **The Callsign box's placeholder (issue 230).** Type `SEARCH` (or `CQ`, or
  a frequency such as `14025`) into the main call entry and open Search.
  EXPECT: the Callsign box is EMPTY and shows the grey hint `Call or part of
  one`; `tr4w.log` reads `seeded with "" (call entry "SEARCH", ...)`. The box
  is focused at once, so note whether the hint stays visible while the caret
  is in the empty box (the Win32 cue banner may hide on focus -- that is the
  LCL's behaviour, report it either way). Type a letter: the hint goes. Close
  it, put `N6` in the call entry, reopen. EXPECT: the box opens holding `N6`.

## Added 2026-11-05 -- AN ALT-P ROW CARRIES ITS KEY AS A TYPED FIELD (pointer audit P9, 5.4)

Each row of the Alt-P list knew its function key through `TListItem.Data`, as
`Pointer(key + 1)`. The list now makes its own rows as `TAltPItem` (the LCL's
`OnCreateItemClass`, wired in the `.lfm`) with a `Key` field. `uTestAltPRows` pins
the round trip on a streamed, never-shown form; what it cannot see is the window
the operator opens.

- [ ] **Alt-P, CQ messages, CW.** Select the Standard bank, double-click F3, change
  the text, save. Switch to the Control bank, double-click CONTROL-F3, change it,
  save. EXPECT: each edit lands on the key double-clicked (F3 and CONTROL-F3 are
  different memories). Close Alt-P and reopen it: it shows the Control bank
  again with CONTROL-F3 selected. Switch to the Standard bank: F1 is selected
  (the last key edited is not in that bank).
- [ ] **Alt-P, Exchange messages.** Double-click F1, then F2. EXPECT: neither
  opens the editor (they are derived from MY CALL and S&P EXCHANGE). Then switch
  to the Control bank and double-click CONTROL-F1. EXPECT: the editor opens --
  CONTROL-F1 is an ordinary memory.

## Added 2026-11-05 -- THE HAMLIB COMMAND QUEUE HOLDS VALUES (pointer audit P13, 2.8)

`THamLibDirect`'s urgent queue (frequency, mode, PTT, RIT/XIT, split, posted from
the main thread and run on the polling thread) was a `TList` of `New`'d records
and is a dynamic array of the record now. No test reaches it: every setter returns
at once without a live rig. HamLib as a family is unproven on the bench.

- [ ] **Any HamLib-driven radio (HAMLIB ANY, or FLRig), connected.** Click a band-map
  spot, change mode, key and unkey, toggle split, set RIT. EXPECT: each reaches the
  radio once, in the order made, and no access violation when TR4W exits or the
  radio is rebuilt (Reset Radio Ports) straight after a burst of changes.

## Added 2026-11-05 -- THE ICOM LAN TX HISTORY IS A LOCKED RING (pointer audit P13, 2.8)

The packets an Icom LAN link keeps for the radio's retransmit requests were a
`TList` of `New`'d records with no lock, written by the sending threads and read by
the socket listener; a threaded unit test crashed it. It is a fixed ring under its
own lock now (`TIcomTxHistory`, pinned by `uTestIcomTxHistory`). What no test
reaches is a real radio asking for a resend: the 2026-09-24 IC-7760 capture
records how rarely that happens.

- [ ] **An Icom LAN session (IC-7760 or IC-9700) on a lossy link, then a long
  soak.** Run the radio over Wi-Fi or a busy switch for an hour while tuning and
  keying. EXPECT: no access violation and no hang; with DEBUG logging,
  `Retransmitted seq N (single request)` / `(multi request)` lines whenever the
  radio asks, and the link stays up. A clean soak with no retransmit lines at all
  is also a pass for "nothing broke", but says nothing about the resend path.

## Added 2026-11-05 -- NETWORK RADIO DISCOVERY RETURNS A VALUE ARRAY (pointer audit P13, 2.7)

The K4, Flex and Icom discoveries returned a `TList` of `New`'d records that
`uCAT.DiscoverNetworkRadios` freed one cast at a time; each now returns a dynamic
array of its record and the caller frees nothing. Unit-pinned: the Flex datagram
parser (`uTestFlexDiscovery`, unchanged). Not driven by any test: the collecting
loops, which need a socket and a radio on the subnet.

- [ ] **The radio editor's Discover button, for a K4, a Flex and an Icom LAN radio**
  (each powered on, on the same subnet). EXPECT: each radio's IP address is offered
  once, as before; with two radios of a kind, both; with the radio off, nothing
  found and no access violation. `tr4w.log` (DEBUG) says
  `[RadioEdit] Discovery worker finished -- N address(es)` with the right N.

## Added 2026-11-05 -- THE WAE QTC COUNTS LIVE IN A PLAIN ARRAY (pointer audit P13 part 2, 2.5)

Unit-pinned: the per-station counting, lookup, decrement and the 500-station edge
(`uTestQTCCounts`). Not driven by any test: the two QTC windows and the reset of the
counts on a new log. The table used to be a heap pointer and is now a zeroed static
array, so nothing is expected to differ; the item below is the QTC windows' normal
run, which `QTC_BENCH_HANDOFF.md` scripts in full.

- [ ] **WAE QTC send and receive, and the per-station count** (WAE contest, with
  `QTC ENABLE` both on and off). Send a QTC book to a station and receive one. EXPECT:
  no access violation; the QTC count shown for the station rises by the book's size,
  answering No at the confirm steps it back, and a second station's count is its own.
  With `QTC ENABLE` on, start a new log or reset the dupe sheet: the counts return to
  zero. (With it off the dupe-sheet reset leaves the counts alone, as it always did --
  the reset is inside that setting's test -- so do not expect zero there.)

## Added 2026-11-05 -- THE LINE-FILE CALLBACK, THE EDIT-MESSAGE ROW AND THE PARK LIST ARE TYPED (pointer audit P16, 5.5, 5.6)

Unit-pinned: what `TF.EnumerateLinesInFile` hands its loaders (line breaks,
blank lines, the 255-byte cut, high bytes, in-place edits) and the HELLO.DAT
reader (`uTestEnumerateLines`); the park list handed over by the startup load
(`uTestContestPOTA`). `.dom` and `.cfg` loading are under the matrix and the
corpus. The compiler type-checks every change here, and nothing is expected to
differ on screen. These are the loaders and windows with no test:

- [ ] **DX cluster alert list and cluster commands** (`uTelnet`). With
  `DXCLUSTER_ALERT_LIST.TXT` and `CLUSTER_COMMANDS.TXT` beside the program,
  open the Telnet window. EXPECT: the command popup lists every
  non-`;` line of `CLUSTER_COMMANDS.TXT`, upper-cased as before, and a spot of a
  call on the alert list alerts as before.
- [ ] **Intercom** (`uIntercom`). With an `INTERCOM.TXT`, open the Intercom
  window. EXPECT: its lines are listed as written (case kept).
- [ ] **Stations** (`uStations`). With a `STATIONS.TXT`, open the Stations
  window. EXPECT: every non-`;` line is a column call, upper-cased.
- [ ] **Alt-P -> Edit Message** (5.5). Select a function-key memory in Alt-P
  and press Enter (or double-click). EXPECT: the editor opens on THAT row's
  key name and text, for a row near the top and one near the bottom of the
  list. OK saves it to that key.
- [ ] **POTA park list** (5.6). In a POTA log, start TR4W with a downloaded
  `pota_parks.csv`. EXPECT: park names resolve as before (the startup load's
  list is the one in use). Then Help -> download the park list: it loads and
  reports the count as before.

## Added 2026-11-05 -- A PRIOR CONTACT'S ZONE TRUMPS THE CALL'S (issue 213, NY4I bench)

The zone the "Mult needs for" strip, the call-window MULT flag and the spot
hint use for a call is now the zone it was most recently LOGGED with; the
call's CTY.DAT zone only when it has none. Every CQ/ITU zone-multiplier contest
(about 15: CQ WW CW/SSB/RTTY, IARU HF, JIDX x2, Croatian, LZ DX, CW Open ...).
A unit test reproduces NY4I's bench case and passes; nobody has looked at the
window.

- [ ] IARU HF: log W1AW on 160 m CW with zone 7 (CTY.DAT says 8). Retype W1AW
  on 80 m: the 160 cell of "Mult needs for W1AW" is EMPTY (zone 7 worked on
  160); it showed 160 needed before. The yellow MULT flag agrees.
- [ ] Same log: a call never worked (W2XYZ, zone 8): 160 shows needed.
- [ ] Log W1AW again on 40 m with zone 6, retype: the strip follows zone 6 (the
  most recently logged), so 160 shows needed.
- [ ] A cluster spot of W1AW on 160 is not coloured as a new multiplier.
- [ ] Reopen the log: the same answers (the loader feeds the same store).

## Added 2026-11-05 -- A ONE-CHARACTER MULTIPLIER SHOWS IN "MULT NEEDS FOR" (issue 209)

The header and needs strip refused any multiplier shorter than two characters
(D7, 2016, no reason given). The contest now says what is a multiplier
(`TContestBase.IsValidDomesticMultiplier`): anything non-empty, two characters
or more for a grid contest. Unit tests drive the header panel through the
remembered-exchange path for every one-letter key (SP DX, King of Spain, MWC's
file) and the routine itself for MWC; nobody has looked at the window.

**MWC (a second change, the same day, after NY4I's ruling that a multiplier
computed from the call is what the header and strip use, as CQ WW's zone
is):** MWC now answers `DomesticMultiplierFromCall` with the letter it scores.
The header names the CALL, as CQ WW's does; the strip shows whether the call's
letter is needed. Measured before: the strip was empty for every MWC call.

- [ ] MWC (OK1WC Memorial), MULT BY BAND on, 80 m: type `OK1W` -- the header
  reads `Mult needs for OK1W :` and the 80 m cell shows (W needed). Log it:
  the cell empties. Type `OK5W`: empty (W worked). Type `OK1Z`: shown (Z
  needed). Retype `OK1W`: empty.
- [ ] MWC: a spot or WSJT-X decode of a call with an unworked letter is
  coloured as a new multiplier, a worked letter is not (it never was before).
- [ ] SP DX, out of Poland: log an SP station sending a one-letter province
  (`B`): the header names `B`; retype the call later, still `B`.
- [ ] King of Spain (CW or SSB): an EA station sending a one-letter province
  (`M`): the header names `M`.
- [ ] A grid contest through WSJT-X (WW Digi): a decoded station with a grid
  shows its field as before (`FN`); one with no grid shows no header.
- [ ] IARU HF and WRTC (NY4I: the ITU zone comes from the call, as in CQ WW):
  log K1ABC sending zone 8 and no HQ on 40 m. Afterwards, and when the call is
  retyped, the header reads `Mult needs for K1ABC :` (it read `8`) and the
  40 m cell is empty (zone 8 worked); it showed every band needed. An HQ
  station (`ARRL`) or a state (`CT`) still heads with its HQ or state.
- [ ] Worth a look, NOT changed: in IARU HF the ARRL header's 40 m cell still
  showed needed after ARRL was logged on 40 m in the unit probe (WRTC showed it
  worked); it did before this change too.
- [ ] A FIELD THAT IS NOT A MULTIPLIER NO LONGER HEADS THE STRIP (option 1,
  NY4I): in a domestic-file contest, a station logged with no QTH heads with
  its CALL, not its zone, name or class. CQ WW RTTY / CQ 160: a DX station
  that sent only zone 6 -- `Mult needs for XE1ABC :` (was `6`). NAQP: a
  station logged with a name and no state -- the call (was `TOM`). Field Day
  with no section -- the call (was `2A`). 29 contests measured.
- [ ] YOTA unchanged: a station of age 9 still heads `Mult needs for 9 :`.
- [ ] Michigan QP out of state: a county typed `PRES` still heads `PRESQ`.
- [ ] Not changed: typing a lone `W` into the MWC exchange window shows
  nothing (`logsubs2`'s two-character gate before the typed lookup).

## Added 2026-11-04 -- SWEEPSTAKES: "MULT NEEDS FOR" NAMES THE SECTION, NOT THE CHECK (NY4I, bench)

The header read `Mult needs for 18 UT :` after W7ST (33M 18 UT) was logged. The
QSO and the Mults window were right; the header showed the remembered exchange
(check + section) whole. Unit tests drive the header panel; nobody has looked
at the window.

- [ ] ARRL SS (CW or SSB): log `W7ST` with `33M 18 UT`. Afterwards the header
  reads `Mult needs for UT :`, never `18 UT`.
- [ ] Type a call you have already worked (a station logged with check 32,
  section IN): the header reads `Mult needs for IN :`, not `32 IN`.
- [ ] ~~A section whose file spelling differs from what you typed (`WF`, filed
  as `WcF`): the header shows what you typed (`WF`), and its needs strip may
  show it as needed. Not changed by this fix -- issue 207.~~ Changed by issue
  207 (2026-11-05) -- see the next entry.

## Added 2026-11-05 -- "MULT NEEDS FOR" NAMES THE MULTIPLIER IN EVERY DOMESTIC-FILE CONTEST (issue 207)

The header was the remembered exchange whole (`TOM CA`, `2A CT`, `123 CT`) or
the alias as typed (`WF`, `VE7`, `KALA`), and the needs strip looked that text
up, never found, so every band read needed. It now shows the MULTIPLIER, upper
case (`CA`, `CT`, `WCF`, `BC`, `KZOO`). Measured on 58 contests through the
matrix; unit tests drive the header panel and the strip cells. Nobody has
looked at the window.

- [ ] NAQP (any mode): log a station with `TOM CA`. Afterwards the header reads
  `Mult needs for CA :`, never `TOM CA`; the strip cell for the band you
  worked goes empty.
- [ ] NAQP: type the same call again later: the header still reads `CA`.
  A name that is also a state (`DE CA`, Del in California): the header reads
  `CA`.
- [ ] A state QSO party, out of state (e.g. Michigan): log a county typed as an
  alias (`KALA`, filed as `Kzoo`): the header reads `KZOO`, and the cell for
  that band goes empty. Retype the call: still `KZOO`.
- [ ] Field Day: log `2A CT`: the header reads `CT`, not `2A CT`.
- [ ] ARRL SS: log a station with section `WF`: the header reads `WCF`, and the
  needs strip shows it WORKED afterwards (it showed it needed before).
- [ ] ARRL SS: type a call whose remembered exchange is a check alone (`18`):
  the header names the CALL, not the previous call's section.

## Added 2026-11-04 -- SWEEPSTAKES: A PRECEDENCE JOINED TO DIGITS IS ALWAYS THE SERIAL (NY4I)

NY4I: *"a check would NEVER be entered with the precedence next to it without
a space."* Unit tests drive `ParametersOkay`; nothing has looked at the window.

- [ ] ARRL SS (CW or SSB), call `W1AW`: type `U12 W1AW 80 CT`. It logs serial
  12, precedence U, check 80, section CT (it used to read check 12).
- [ ] **`A99CT` is always precedence A, serial 99, section CT** (NY4I: "a
  number next to a prec. was the serial"). With **CALLSIGN UPDATE ENABLE =
  TRUE** (the default) type `A99CT 32`: it does not log, and the notice reads
  `Ambiguous entry - A99CT may be a callsign or an exchange. For the
  exchange, enter 99A CT; for the call, type it in the call window`. Then
  type `99A CT 32`: it logs serial 99, check 32. `A99CT 32 W1AW` (the call
  typed last) logs serial 99, check 32 with no question.
- [ ] With **CALLSIGN UPDATE ENABLE = FALSE**: `A99CT 32` logs serial 99,
  check 32; `A99CT 123` does not log and the notice reads
  `Check must be two digits (123)`.
- [ ] Type `A 99CT 32`. It does not log; the notice reads
  `Ambiguous exchange - enter 99A or 32A to resolve`. With the number BEFORE
  the check and section it logs in the base order: `32 A 99CT` is serial 32,
  check 99, and `42 M W1AW 31CT` is serial 42, check 31 (as before `fce7be16`).
- [ ] **A missing section or check says so** (NY4I's bench: these were refused
  with no message). Type `A99 32`: it does not log, and the notice reads
  `Missing section`. With CALLSIGN UPDATE ENABLE = FALSE type `A99CT`, and
  with either setting `123 A CT`: neither logs, and the notice reads
  `Missing check (two digits)`. `A99CT 5` still reads
  `Check must be two digits (5)`. A missing serial (`M 31 CT`) is still
  refused with no message (not changed).

## Added 2026-11-04 -- OLD TR4W/TR4W ISSUES CLOSED AS FIXED, NEEDING A REAL RUN (NY4I)

Nine issues from the Delphi 7 repository were closed as fixed in this tree on
the strength of the code. Each is only proven by a run on the real thing. If
one fails, open a TR4W-D12 issue; the old number is given for the history.

- [ ] **Old #144, FTDX5000:** click a band-map spot that carries no split
  frequency. The radio must come out of split (and not go into split by itself).
- [ ] **Old #315, IC-9100:** switch the radio to a data mode (USB-D). TR4W shows
  the data mode, and a mode change from TR4W sets it.
- [ ] **Old #623, Ten-Tec Omni VI (model 564):** connect and read frequency and
  mode; change band from TR4W.
- [ ] **Old #703, Elecraft K4 over the network:** with the K4 in split, click a
  band-map spot that has no split. The K4 leaves split.
- [ ] **Old #680, radio setup:** with CW keying on a COM port also used by the
  radio, press Apply in Preferences twice. No "port already open" error, and
  the radio and keyer come back.
- [ ] **Old #602, scoreboard:** post a score with an overlay category chosen
  (for example Classic). The scoreboard accepts it and shows the overlay.
- [ ] **Old #730, ContestOnlineScore:** post a score in a contest with several
  modes. The band rows show every QSO of the band, not half.
- [ ] **Old #788, band map:** delete a spot, then press the next-band-map key.
  The deleted spot is not offered.
- [ ] **Old #434, WW Digi:** log grids in several fields (for example DM, FN,
  JO). Each new two-letter field counts as a multiplier; check against the WW
  Digi rules that the field, not the 4-character locator, is the multiplier.

## Added 2026-11-04 -- THE KEYING THREADS HAND THE END OF A MESSAGE TO THE MAIN THREAD (issue #132)

The CW thread, the WinKeyer reader and the DVK playback thread no longer arm the
auto-CQ timer, swap radios, return to CQ or draw the speed panel themselves; each
asks the main thread, in its old order. The unit tests run the shipped CW thread
and DVK body to their end; nothing here has keyed a rig. **Expect one visible
change:** on Windows a timer armed from those threads could never fire, so the
auto-CQ repeat after a CPU-keyed or WinKeyer-keyed CQ may now work where the
previous 5.x build stopped after one CQ. If it repeated before, say so -- that
would mean something else was re-arming it.

- [ ] **CPU keyer (DTR/RTS), AUTO-CQ.** Start auto-CQ on F1. EXPECT the CQ to
  repeat after AUTO-CQ DELAY TIME, every time, with PTT dropping between CQs as
  before, and the element timing unchanged by ear.
- [ ] **CPU keyer, AUTO CALL TERMINATE.** AUTO CALL TERMINATE on, auto-send on,
  CQ mode: type a call so auto-send keys it. EXPECT the exchange to follow the
  call WITHOUT PTT dropping in between, the cursor to land in the exchange
  window as before, and no gap you can hear beyond the usual one. Then press
  Esc the instant the call finishes: EXPECT sending to stop. (The exchange is
  now appended by the main thread a moment later, so an Esc caught in that
  moment is handled before the exchange exists -- say if the exchange still
  goes out.)
- [ ] **WinKeyer, AUTO-CQ and AUTO CALL TERMINATE.** The same two checks with a
  WinKeyer. EXPECT the same.
- [ ] **SO2R TR3 (either keyer).** A QSO that ends with the radios swapped back
  (`BackToInactiveRadioAfterQSO`): EXPECT the swap back and, with ALT-D CQ
  enabled, the CQ on the other radio, exactly as before.
- [ ] **DVK.** Phone, DVK enabled, AUTO-CQ on, a .WAV in F1. EXPECT the message
  to play, PTT to drop when it ends, the speed panel to read `DVK OFF` after
  playback, and the CQ to repeat after the delay.
- [ ] **Nothing in the log.** After the session, search `tr4w.log` for
  `NOT the main thread`. `app timer start` / `app timer stop` lines are NEW
  reports (uAppTimers checks now) and each names a caller still to move --
  report them.

## Added 2026-11-03 -- WINDOW TITLES CARRY NO "&"

Menu-row text is reused as a window title (`uCaptionText.DisplayedText` strips the markers). Only a screen can judge it.

- [ ] Open Windows > Beacons, Send spot, QTC, Radio 1 and Radio 2 (and a panadapter from the radio panel) in English and in `--lang sr` (Serbian carries `&` markers in its captions). No title shows a literal `&`, and `&&` shows as a single `&`.

## Added 2026-11-03 -- THE PANADAPTER FOLLOWS THE K4'S WATERFALL HEIGHT, COLOUR RANGE AND COLOUR MODE

The K4 radio object now reports to the panadapter what its LCD says about the
waterfall: `#WFH` (height), `#WBS` (colour range, WTR CLRS) and `#WFC` (colour
mode). The window follows them live
(`docs/PANADAPTER_LCL_DESIGN.md` section 10.5). It follows the **LCD values
only**. The external monitor's `#HWFH`, `#HWBS` and `#HWFC` must not move it.
The parse, the translation and the "unknown means today's look" rule are
pinned by `uTestK4DisplayReport` and `uTestSpectrumRadioState`. What no test
can see is whether the radio PUSHES these on a front-panel change, and what the
screen looks like. Use a network K4 with the panadapter open (pan A, then
pan B), and keep `tr4w.log` at TRACE.

- [ ] **Waterfall height.** Change it on the front panel (e.g. 50, 30, 70, then
  0 and 100). EXPECT the window's split to follow within a tick. At 0 the
  window shows the trace only. At 100 it shows the waterfall only, with the
  VFO markers and the cursor still drawn over it. The log should show
  `[K4] display report recorded: #WFH...`. If no line appears, the K4 does
  not push `#WFH`, and the window only learns it at the next connect.
- [ ] **The history survives a height change.** EXPECT the newest rows to stay
  when the split moves (they used to be cleared). The oldest rows are lost
  when it shrinks.
- [ ] **Colour range (WTR CLRS).** The floor is REF - TR4W's slider value x
  WBS / 40, and the slider now follows the rig's SCALE when it changes, so
  do not drag TR4W's slider during this check (if you have, turn SCALE at
  the rig once to bring it back). Then step WTR CLRS from 5 to 30. EXPECT the whole
  waterfall, history included, to get brighter as the number rises. With
  the slider at 80 dB, 5 should look exactly as TR4W always has. **Compare
  against the rig's own screen at 5, 14 and 30.** The mapping is QK4's
  photographic fit and is unverified away from 14. Say whether it looks
  right.
- [ ] **Colour mode.** Step it through gray, color, teal, blue and sepia. EXPECT
  the combo and the waterfall to follow: Grayscale, Heat Map, Blue-Green,
  **Blue**, Sepia. Fire-Ice is never selected by the rig (it is the
  operator's only).
- [ ] **The Blue palette against the K4's own blue tone** (added later
  2026-11-03). Blue is a NEW palette and **TR4W's own design**: QK4 draws
  one colour table whatever `#WFC` says, so there was nothing to copy. It is
  Sepia's tone curve moved to blue: black, then dark blue, rising to a pale
  blue-white. Put the rig on WTR BLUE and compare the two screens side by
  side, noise and strong signals both. Say what differs (the dark run, the
  hue, the top end).
- [ ] **The operator's choice still works.** Pick a palette in the combo. EXPECT
  it to stay until the colour mode is changed at the rig. A reconnect alone
  should not undo it.
- [ ] **REF is followed, AutoRef ON.** (Added later 2026-11-03.) With AutoRef
  on, the trace's bottom edge is now the rig's `#REF` exactly, with no 10 dB
  margin, as QK4 and the rig draw it. EXPECT the noise to sit on the bottom
  edge as on the LCD, and to stay put while AutoRef steps (a few `#REF`
  lines a second in the log at TRACE). EXPECT the waterfall NOT to flash or
  re-colour its history on a REF step: a new REF reaches new rows only.
  **Say whether losing the 10 dB margin under the floor looks worse** -- the
  margin used to keep the noise texture visible below the floor.
- [ ] **REF is followed, AutoRef OFF.** Turn AutoRef off and turn the REF knob
  (pan A, then pan B). EXPECT the trace to move up and down with REF, and
  the dB labels to follow. Pan B: TR4W does not ASK `#REF$;` at connect, so
  with AutoRef off pan B keeps the noise-floor scaling until the sub's REF
  is changed at the rig. Say whether pan B needs it asked.
- [ ] ~~**SCALE is NOT followed yet.**~~ **SCALE IS FOLLOWED, NEVER WRITTEN**
  (NY4I's option (b), later 2026-11-03; design doc 10.6). Change SCALE on
  the K4's front panel (e.g. 80, 50, 25, 120). EXPECT TR4W's scale slider
  and its caption to jump to the rig's value within a tick, and the trace
  height and the waterfall colours (history included) to follow, on pan A
  and pan B. The log should show `[K4] display report recorded: #SCL...`;
  if no line appears, the K4 does not push `#SCL` and TR4W learns it only
  at the next connect -- record which.
- [ ] **TR4W's slider sends nothing.** Drag TR4W's scale slider. EXPECT the
  picture to change, **nothing to be sent to the K4** (no `#SCL` in the
  log's outbound lines at TRACE) and **the K4's own SCALE not to change**.
  EXPECT TR4W to keep the dragged value until SCALE is changed at the rig
  again -- and a reconnect alone not to undo it. Also EXPECT no waterfall
  flash while the rig sits on one SCALE.
- [ ] **The Y mini-pan's slider is TR4W's alone.** With the Y source shown,
  change SCALE at the rig. EXPECT no change in TR4W.
- [ ] **A reconnect keeps the picture.** Set a split, WTR CLRS and colour mode
  that are NOT the defaults (e.g. 30 %, 20, sepia). Then **power-cycle the
  K4**, and separately **pull the network cable** and put it back. EXPECT
  the window to keep that split, colour range and palette throughout, never
  snapping to 0.5 / 10 dB / Heat Map, and to take any value changed while
  the link was down as soon as the radio answers. A PROFILE switch or Reset
  Radio Ports builds a new radio object and DOES start from the defaults
  until the radio answers: say whether that brief reset is acceptable.
- [ ] **The external monitor does not move it.** Change the EXTERNAL monitor's
  waterfall height, colour range and colour mode. EXPECT no change in the
  window.
- [ ] **Does the K4 answer `#WFC;` at connect?** The connect line is now
  `#REF;#SCL;#AR;#WFH;#WBS;#WFC;#AVG;`. EXPECT `#WFC<n>` in the log within a
  second of connecting.

## Added 2026-11-03 -- THE K4 MAIN PAN IS DRAWN AT #SPN, NOT AT THE FRAME WIDTH

The K4 radio object now cuts pan A down to the radio's own `#SPN`, centred,
before the panadapter sees it. The frames' ~40 pad bins per edge used to show
as a flat line at the bottom of the plot at both ends
(`docs/PANADAPTER_LCL_DESIGN.md` section 10.4). The arithmetic and both
captures are pinned by `uTestK4SpectrumCrop`. What no test can see is the
screen. Use a network K4 with the panadapter open, and set each span at the
rig or with the +/- buttons.

- [ ] **No flat line at either edge** at #SPN 5, 20, 40, 80, 150, 190 and 250
  kHz, **and at the 368 kHz maximum**. The trace should run edge to edge as
  ordinary noise.
- [ ] **At 368 kHz the axis spans about 365 kHz** (the edge guard) while the
  `Span` label still says 368. Is that acceptable, or should the label say
  what is drawn? Labelling the drawn span makes +/- look dead near the top
  (366, 367 and 368 all draw 365.25).
- [ ] **The axis, the label and a click agree.** At 20 kHz and at 150 kHz,
  click a carrier near each edge and one in the middle. The radio should
  tune onto it, and the axis frequency under the cursor should match the
  VFO. Elsewhere the label and the axis width should agree to within 375 Hz
  (e.g. 5 kHz draws 5.25).
- [ ] **The waterfall across a span change.** Step the span several times.
  Old rows are NOT cleared when the span changes, so for a while rows
  drawn at the old span sit under the new axis. Is that visible enough to
  fix? (Proposed: clear the history when the drawn span changes.) Also
  watch the 1-3 frames at the old width that the K4 sends just after a
  change upward: they pass through whole, pad included, for one or two
  rows.

## Added 2026-11-02 -- PREFERENCES CONTROLS SHOW THEIR COMMAND HELP ON HOVER

Every control bound through `TSettingBindings.Bind`, and every hand-wired one
listed in `AddHandWiredToSearchIndex`, now has a tooltip: the
setting's help text from `help\help_<code>.po` for the UI language, over
`help\help_en.po` (`src/uCommandHelp.pas`). Wrapped at 70 columns, capped at
600 characters with ` ...`. The catalogues are only in an INSTALLED tree (or a
tarball/.app) -- a developer run from `tr4w/target` has no `help\` folder and
shows no tooltips; the log line `[Prefs] Setting tooltips: ...` names the
files it loaded (`""` = none). To try it from a dev tree, copy
`i18n/help_*.po` into `tr4w/target/help/` by hand and do not commit them.

- [ ] Hover CW Tone and Say Hi Enable (bound) and Band Map Decay Time
  (hand-wired) on an installed build: each shows its description, wrapped,
  and the hint goes away normally.
- [ ] A long one (Always Call Blind CQ, bound) is cut with ` ...` and stays on
  screen.
- [ ] A bound control with no help (No Border, Show Gridlines on Appearance)
  shows no tooltip, not an empty box.
- [ ] `--lang es`: the same controls show the Spanish text; `--lang ja` falls
  back to English.
- [ ] macOS and Linux: the `.app` / tarball finds `help/` (Contents/Resources,
  beside the binary) -- read the log line.

## Added 2026-11-02 -- TAB MOVES IN READING ORDER ON EVERY PREFERENCES PAGE (NY4I)

Tab on almost every Preferences page followed the order the controls were
CREATED, not where they sit (Network went Server, This station, a checkbox,
Port). Only `TabOrder` values in `uPrefsForm.lfm` changed: down the page in
rows, left to right in a row. The Station page goes down the Station column,
then the Contest column. At the window level the order is search box, tree,
page, then OK / Cancel / Apply. `Lint-TabOrder` now fails a form whose order
disagrees (`tools/lfm_taborder.py`; columns and the ratchet for forms not yet
reviewed are in `tr4w/build/lint-taborder.txt`).

- [ ] **Windows.** Open each leaf page, click its first field and Tab to the
  end. Expect: the caret moves down the page in reading order, and stops
  only on what can be edited. Pages: Station, Radios, Rotators, DX
  Cluster, Operating, Band Map, Bands, CW, Online Scoring, Two Radio
  Mode, SCP, UDP Broadcast, Network, Appearance, Logging, Backup, Audio,
  CW Settings, Paddle and PTT, TCI Server, WSJT-X, External Logger,
  MMTTY.
- [ ] **Station** reads down the left column (Call ... Postal code), then the
  right one (Check ... Park). NY4I to judge whether that is right, or
  whether it should go row by row.
- [ ] From the search box: Tab goes to the tree, then into the page, then
  OK, Cancel, Apply. Shift-Tab reverses it.
- [ ] **Appearance**: the generated "Layout" block below the designed
  controls comes after Show gridlines.
- [ ] **Linux (gtk2)**: the same walk on two pages. gtk2 takes the order
  from the same `TabOrder`, but it has not been seen there.
- [ ] **The other forms** (same fix, `.lfm` only): Tab through the UDP
  destination editor (Address, Port, streams, Test, OK, Cancel), Server
  log (Close last), the Radio editor (all four tabs, OK before Cancel),
  the radio panel, and **Edit QSO** (field columns row by row, My Station,
  then the multiplier and flag checkboxes, then Save and Cancel -- NY4I
  accepted this order 2026-11-02).

---

## Added 2026-11-01 -- COMING BACK TO TR4W PUTS THE MAIN WINDOW ON TOP (NY4I, bench)

Clicking any TR4W window from another program used to bring the tool windows
forward as one group and leave the main window behind the tool window that
partly covered it. Cause: the main window is unowned (`stAlways`), and every
tool window is owned by the LCL's hidden application window, so Windows raises
the tool windows together and the main window keeps its old place. Now
`Application.OnActivate` (once per switch INTO TR4W, never between TR4W's own
windows) queues a raise: every showing tool window, bottom first in the LCL's
activation order, then the main window last (`uMainForm.TActivationRaiser`).
Every platform, not only Windows.

- [ ] **Windows.** Open three tool windows, one partly covering the main
  window. Click another program, then click the CORNER of that tool
  window. Expect: every TR4W window in front of the other program, the
  main window above all the tool windows, the caret in the call field.
- [ ] Same, but come back by clicking the MAIN window, and by Alt-Tab. Expect
  the same: no tool window is left behind the other program.
- [ ] **Click to type in a tool window from another program** (Telnet's command
  field, say). The main window comes up over it and takes the caret; a
  second click on the tool window brings it forward again. NY4I to judge
  whether that cost is acceptable.
- [ ] **A modal up** (Preferences, Edit QSO): switch away and back. The modal
  is in front and nothing else moves.
- [ ] **No flicker worth mentioning**: each tool window is raised in turn,
  so their title bars may flash active for an instant.
- [ ] **Linux (gtk2)** and **macOS**: the same first check. gtk2 gives each
  form its own taskbar entry and the window manager may raise them
  differently; this is a behaviour change there and has not been seen.

---

## MULTI-OP PHASE 1: ONE BENCH SESSION, IN THIS ORDER (2026-10-27)

The four multi-op sections below (C6, C5, the link, protocol 2) are one
piece of work and run best as one session. This block is only the ORDER;
the expectations live in the items, so nothing here can drift from them.
Tick items in their own sections.

**Build both stations from `main` at or after the catch-up commit
(`02fa68d9`).** A released 5.0.35 station cannot connect: it sends no
HELLO and both servers drop it. Windows: `build-out\app-i386-win32\tr4w_fpc.exe`.
Mint: the Linux artifact of a `release.yml` dispatch run on that commit.
Servers: `tr4wserver` built from the same commit (`Build-Server.ps1`; it can
also run on Mint, which has a display), and TR4WServerPy at `master`
(`python tr4wserver.py --display`). **One server at a time**; delete its
`SERVERLOG.TRW` between runs. Same password on both ends (the default
`TR4WSERVER`: a non-default one is lost on restart on Linux, issue #143).
Both stations: `DEBUG LOG LEVEL = DEBUG`, distinct COMPUTER IDs (A = Windows,
B = Mint), NETWORK AUTO CONNECT off, a throwaway log of the contest.

1. **The link** (section "THE MULTI-OP LINK BELONGS TO THE PROGRAM"): nothing
   connects by itself; Connect with the window closed; QSOs cross; open the
   window mid-session; close it; Disconnect; Reconnect; auto-reconnect.
2. **Protocol 2** (section "NETWORK PROTOCOL 2"): a by-id contest connects
   and a QSO crosses; a contest change; a peer on another contest; an old
   server (TR4WServerPy at tag `d7-protocol`); a duplicate id.
3. **Offline resend** (section C5): drop, log 5 and edit 1, reconnect; the
   reboot variant; nothing owed afterwards.
4. **Late catch-up** (section C6): the reboot scenario; the question with
   the setting off; Net > Add missing QSOs from the server; the backup file.
5. **Repeat 1-4 against TR4WServerPy**, then with `tr4wserver` on Mint.
6. **The long outage and the cable pull** (C5 and C6), last, because they
   leave the logs large.

Capture for any failure: `tr4w.log` from both stations (the `[Net]` lines),
the server's log (`tr4wserver.log` or the Python `--log-file`), and the time.

**Added 2026-10-27 after the first live link: DX SPOTS, TIME SYNC, INTERCOM AND
SPOT-VIA-NETWORK (a defect found on the bench, fixed in the tree, UNPROVEN
LIVE).** From 2026-08-25 until this fix the client sent all four with an id of
ZERO, so a server (Python: "unknown or zero-size message ID 0"; `tr4wserver`
since `429de246`) dropped the link on every one, and the reconnect, resend and
catch-up ran once per spot. The unit tests (`uTestNetClientPackets`) now read
the first Word and length of what the client's own senders write, but only a
real link says the server keeps the connection. Run this with BOTH servers, after
item 1:

- [x] **A spot crosses and the link stays up -- CONFIRMED 2026-10-29, NY4I**
  (Mint on the cluster, AF4O 14234: six `RX NETWORKDXSPOT (0x0406) 106B`
  lines in the server's output, the AF4O one 6 ms after the cluster line; no
  drop, no unknown id, `clients=2/26` throughout; and AF4O shows on the
  Windows band map). With a cluster connected at A
  (or a spot added at A), watch B's band map. EXPECT the spot on B, no
  `unknown or zero-size message ID` line in the server log, no
  `Disconnecting client` after the spot, and `tr4w.log` at A with no
  reconnect following it. 20 spots in a minute must not flap the link.
- [ ] **Intercom and spot form.** Net > Send message from A (EXPECT it
  at B), and the Send Spot form with no cluster connected at A (EXPECT B's
  cluster command gets the text). (The time-sync menu row that used to be here
  was REMOVED 2026-11-03; see the next item.)
- [ ] **AN OLDER STATION'S TIME SYNC IS SKIPPED (2026-11-03, needs an OLDER
  5.x build with the menu row as station A).** "Synchronize time on all
  computers" was removed -- a station may not set another's clock (NY4I). Every
  5.x build released before that still has the row, speaks protocol 2 and is
  admitted, so it can still send message id 1070. With the NEW build as B and
  the new tr4wserver (and, separately, TR4WServerPy, which relays 1070 blindly
  and is not changed here): on A choose Net > Synchronize time on all computers.
  EXPECT on B: still responsive, the link stays up, B's clock UNCHANGED, and at
  most ONE `[Net] time-sync packet from an older station ignored` Debug line
  per link in `tr4w.log` (no Warn or Error, no `Unrecognised message id`).
  EXPECT on the new server: one `[Net] time-sync packet from an older station
  skipped, not relayed` Debug line per packet, no `not one the server handles`
  warning, and A and B both still connected. The unit test
  (`uTestNetClientPackets`) and `tools/netprobe --case time` cover the parsing;
  only a real older build covers the rest.
- [ ] **Nothing refused.** `tr4w.log` at either station has no
  `REFUSED to send a malformed packet` line. If one appears it names the id
  and size of a record that would have broken the link; capture it.

---

## Added 2026-10-29 -- EVERY CATEGORY-* MAY BE BLANK (NY4I)

NY4I: none of the CATEGORY-* fields is required. Every category drop-down, in
the New Contest dialog (six rows) and the Edit Cabrillo Summary window (nine
rows), now ends in a BLANK item. Choosing it exports the bare tag, e.g.
`CATEGORY-OVERLAY:` with nothing after it. The blank item has an EMPTY caption;
no gate can judge whether that is visible enough on each widget set.

- [ ] Windows, Linux (gtk2) and macOS: open each drop-down. Is the blank item at
  the END of the list visible and selectable (not a zero-height row)? If it
  is not usable, the fallback is a visible `(none)` caption mapped back to
  `''` -- say so, that is a small change plus a translatable string.
- [ ] Edit Cabrillo Summary: choose blank for OVERLAY, TIME and STATION, close,
  reopen. Each still shows blank (it used to keep the previous value).
- [ ] Same window: choose blank for POWER with QSOs logged. The log rescores
  (blank power scores as HIGH in every power-multiplier contest), and the
  notice names an empty power -- does it read acceptably?
- [ ] New Contest: choose blank for CATEGORY-POWER and CATEGORY-ASSISTED,
  create the contest, export Cabrillo: `CATEGORY-POWER:` and
  `CATEGORY-ASSISTED:` lines, no trailing space. Close and reopen the
  contest, then export again: they are still blank.
- [ ] A contest whose header stated `CATEGORY-OVERLAY: CLASSIC` before this
  build still writes it.
- [ ] Note: a station that never stored STATION, TIME, TRANSMITTER or OVERLAY
  in the summary window now gets bare lines for them. Absent and "none"
  are the same thing in the header store. Acceptable to sponsors' robots?

---

## Added 2026-10-29 -- SHARE DX SPOTS AROUND THE NETWORK (NETWORK SHARE SPOTS)

NY4I: one computer on the internet gets the cluster, the rest sit on a private
network. New checkbox Preferences > Network, "Share DX spots around the network"
(`Settings.Network.ShareSpots`, command `NETWORK SHARE SPOTS`), default ON (what
every connected station already did). OFF = this station neither posts its
cluster spots to the network nor accepts the network's. Read at each spot: no
restart. It is NOT shared between stations (not in SHARED_WITH_PEERS).
Needs two or three stations on one server (Windows, Mint).

What the code gives, per station (post = own setting ON and own cluster
connected; accept = own setting ON):

| gateway (has the cluster) | peer (no cluster) | result                                                               |
| ------------------------- | ----------------- | -------------------------------------------------------------------- |
| ON                        | ON                | gateway posts, peer's band map gets the spots                        |
| ON                        | OFF               | gateway posts, peer drops them (one Debug line per link in tr4w.log) |
| OFF                       | ON                | gateway keeps its spots to itself, peer gets none                    |
| OFF                       | OFF               | both independent                                                     |

- [ ] Gateway ON, peer ON: a spot from the gateway's cluster appears in the
  peer's band map within a second; the peer does not post it back (the
  gateway's band map shows it once).
- [ ] Turn the PEER's box off while connected, no restart: the next gateway
  spot does not reach the peer's band map; `tr4w.log` at Debug has
  `spot from the network ignored: sharing is off` once for the link. The link
  stays up and QSOs still flow (the packet is consumed, not an error).
- [ ] Turn it back on: the next spot arrives.
- [ ] Gateway OFF, peer ON: spots from the gateway's cluster do not reach the
  peer; the gateway's own band map still shows them.
- [ ] Both stations on their own cluster, both ON: each spot arrives twice at
  each station (its own and the other's). Expected, not a bug: the spot store
  merges by frequency, so the band map shows one row.
- [ ] The Preferences > Network page: the new checkbox sits under "Connect to
  the multi-op server when TR4W starts", the grey hint and the "Radio
  sharing" heading moved down, nothing overlaps or clips.
- [ ] LEFT ALONE, decide: the spot form's "send this spot to a station with a
  cluster" (spot-via-network) is not governed by the checkbox. It is an
  explicit operator action; the server hands it to the FIRST other station
  whose status says it has a cluster, and that station posts it to its own
  cluster whatever its own checkbox says.

## Added 2026-10-28 -- A SERVER THAT LOST ITS LOG (the restock; Phase 1 gap found on the bench)

NY4I moved TR4WServerPy to another machine and it had NO log. His Windows TR4W held
83 QSOs, all already sent to the old server (`sent_to_server = 1`), and nothing
would ever send them again: the resend only sends rows still owed, and the late
catch-up only asked which of the SERVER'S QSOs this log lacks. The same state
follows the server's Clear-server-log or any restart that lost
`SERVERLOG.TRW`. **Now the catch-up is two-way.** The server log it already
downloads each link also says which of THIS log's QSOs the server lacks (a row
whose `(ceQSOID1, ceQSOID2)` is not in the image; imports and still-owed rows are
left out and counted), and they are sent as **OFFLINEQSO** -- both servers store
it and acknowledge it but do NOT relay it, so the stations that are connected are
not flooded; a station that lacks some catches up from the server's log on its
next connect. No flag is written (the rows were already sent). The menu row and
window are now **Net > Synchronize with the server...** (they were "Add missing
QSOs from the server..." and "Server log" in the two sections below -- read those
names as these). Unit tests: `uTestNetRestock` (the 83-row plan, idempotence, a
partial server, rows received from other stations, the one question, the posting
over a stub writer, the window's button following the link, its layout read from
the `.lfm`); `tools/netprobe --case restock` proves both real servers. They cannot
show the question, run two programs, or see a real server restart on a machine.
**WHAT YOU NEED:** as the sections below -- stations A (Windows) and B (Mint),
`DEBUG LOG LEVEL = DEBUG`, NETWORK AUTO CONNECT off, same LEGACY contest -- and a
server you can empty and restart; **delete `SERVERLOG.TRW` first** (or start the
Python server in a new directory) for the first item. Expect the in-tree
`tr4wserver` to take MINUTES to store a large restock (about 40-85 ms a QSO, so
5,000 is about 3.5 minutes; TR4WServerPy takes about 1 ms a QSO).

- [x] **NY4I's scenario -- OUTCOME CONFIRMED 2026-10-29, NY4I** (Windows A to an
  empty TR4WServerPy on a Raspberry Pi, then Mint B: "it worked, mint has the
  83 qsos"). Not reported, so still worth a look in `tr4w.log` on the next run:
  the notice wording, the two `[Net] restock:` lines, no Error or Warn, and
  NO notice on a second connect. At A alone, log 83 QSOs while connected to server S1 (so
  all are marked sent), then Disconnect. Start a FRESH EMPTY server S2 (no
  `SERVERLOG.TRW`), point A at it, **SERVER AUTO SYNCHRONIZE LOG ON CONNECT on**,
  Net > Connect. EXPECT: no question; a notice "Sent to the server: 83 QSO(s) it
  did not have."; `tr4w.log` at A has `[Net] restock: 83 to send; 0 imported
  (no network identity) skipped; 0 still owed (the resend sends them) skipped`
  and `[Net] restock: 83 QSO(s) the server did not have were posted (OFFLINEQSO:
  stored, acknowledged, not relayed)`, no Error and no Warn; the server's
  log shows 83 records (the display on the server window, or a download); A's log
  is unchanged (83 rows, none gained, none lost, **no `sent_to_server` change** --
  nothing to settle). Disconnect and Connect again: NO notice, `restock: 0 to
  send`.
- [x] **Then B joins and catches up all 83 -- CONFIRMED 2026-10-29, NY4I** (Mint,
  the Linux AppImage of CI run 40755408814, server `pi400.local`: it holds the
  83). Start B (Mint) on the same contest with
  an empty log, connect with the setting on. EXPECT: "Caught up from the server:
  83 QSO(s) added."; B's log holds the 83, once each, and its score equals A's.
  The restock did not push them to B live (B was not connected during it, and an
  OFFLINEQSO is never relayed) -- if B WAS connected during the restock, EXPECT B to
  show nothing then and to get the 83 on its next connect.
- [ ] **The question, one only (setting OFF).** Repeat the first item with the setting
  off. EXPECT: ONE question, "The server lacks 83 QSO(s) of yours. Send them to the
  server now? ..."; nothing is sent until Yes; No leaves everything alone, logs that
  the operator declined, and asks again on the next connect. Then make BOTH apply:
  with the server holding 10 QSOs A lacks (logged at B while A was away) and A
  holding 83 the server lacks, connect A. EXPECT ONE dialog covering both
  ("The server holds 10 QSO(s) this log lacks and lacks 83 of yours. ...");
  never two dialogs; Yes does both (check both logs afterwards), No does neither.
  When both sides are complete (a second connect): no dialog, no notice.
- [ ] **The server's log is cleared while the stations keep theirs.** With A and B
  connected and holding the same 20 QSOs, clear ONLY the server's log (the
  server's own Clear server log, or the Python server's clear; NOT the Clear all
  logs message, which clears every station's log too). Then at A, Net >
  Synchronize with the server, Get server log: the server holds 0 and the window's
  second button reads "Send 20 QSO(s) to the server". EXPECT the button enabled
  only while the link is up (drop the link with the window open: it greys; bring
  it back: it comes on), and clicking it sends at once (the window stays open,
  the button goes grey, the notice "Sent to the server: 20 QSO(s) it did not have."
  appears); Get server log again shows 20 and the button stays grey. B's log is
  unchanged and shows nothing (an OFFLINEQSO is not relayed). Then Net > Clear all
  logs and confirm every station still clears as before.
- [ ] **A mid-send drop repairs itself.** With 1,000+ QSOs at A and a fresh empty server,
  Connect and pull the cable (or stop the server) while it sends. EXPECT a Warn
  `restock: the link went down after N of M QSO(s)`; on the next link A sends only
  the rest (the plan is made again from the server's log): no duplicates, the server's
  log ends at exactly the 1,000.
- [ ] **The server keeps them across a restart.** After the first item stop S2 and start
  it again in the same directory (both servers). EXPECT the log still holds the 83
  and a station connecting now catches up all of them.
- [ ] **Imports and owed rows are left alone.** Import an ADIF of 5 QSOs at A (no
  network identity), log 2 QSOs with the link down, then connect to an EMPTY
  server. EXPECT `restock: <n> to send; 5 imported ... skipped; 2 still owed ...
  skipped` -- the 2 owed go as QSOINFO through the ordinary resend ("Resent to the
  server what was logged while disconnected: 2 QSO(s)") and a second station sees
  them live; the 5 imports are NOT on the server.
- [ ] **Mint.** Repeat the first, third and sixth items with the Mint build as the
  station holding the QSOs (B in that item), against `tr4wserver` and TR4WServerPy.
  LOOK AT THE WINDOW LAYOUT on gtk2 (the wider font, issue 142): the Send button's
  caption "Send 83 QSO(s) to the server" must not be clipped, and no two buttons
  may overlap.
- [ ] **The in-tree server stays up under a large restock.** One of five in-tree runs
  on 2026-10-28 lost the server process about 7 s into a 5,000-QSO restock (no
  crash line, no Windows error event; four later runs did not repeat it). Restock
  5,000 into `tr4wserver` and read whether it is still running afterwards; if it
  went, capture `tr4wserver.log` and the process exit code. ALSO EXPECT, and
  write down: (a) many `write took over 250 ms` Warns in `tr4w.log` at the
  restocking station (the real writer pushes the whole set into a server that
  stores one every 40-85 ms; the unit tests and netprobe used writers that never
  block); (b) that station's OWN live QSOs and status packets queue behind the
  backlog on the same stream, so other stations see them minutes late with
  `tr4wserver` and seconds late with TR4WServerPy; and (c) the operator is not
  frozen meanwhile (the writes are off the main thread). No prompt and no pacing
  for a large restock is deliberate (NY4I).
- [ ] **What the counts mean.** The log's `restock:` line counts only rows the
  server LACKS: a row the server already holds is never read, so an owed row the
  server has an older copy of (edited offline) is not in "still owed ... skipped";
  the resend sends its edit as before.

---

## Added 2026-10-27 -- A STATION THAT COMES UP LATE CATCHES UP FROM THE SERVER (Phase 1, C6)

NY4I: *"Late catch-up has to be supported as it was ... to handle a station that
comes up (reboots) in the middle of the contest."* D7 CRC32'd the `.TRW` at both
ends and REPLACED the local log with the server's file. This build keeps no
`.TRW`, so it does something different with the same operator-facing shape: once
per link, after the server's HELLO, it **downloads the server's log on the second
port and ADDS the QSOs it lacks -- insert only, after a verified backup, in one
transaction, then a rescore**. With `SERVER AUTO SYNCHRONIZE LOG ON CONNECT` on it
just does it; with it off the operator is asked, with the count. Net > Add missing QSOs from the server
opens the window that shows the server's log and adds the same way. The unit tests
drive the merge over a scratch SQLite log and the download against an in-process
socket; `tools/netprobe --case catchup` (`--burst 200 --timeout 12`) proves the
sync port of both real servers. They cannot run two programs, show the question,
or see the log change under an operator. **WHAT YOU NEED:** `tr4wserver` (then
TR4WServerPy, one at a time), stations A and B on the same LEGACY contest,
`DEBUG LOG LEVEL = DEBUG`, **NETWORK AUTO CONNECT off**, a throwaway `SERVERLOG.TRW`
deleted between runs, and a backup folder you can look in (the line
`[Net] catch-up: log backed up to ...` names it).

- [ ] **The reboot (the NY4I scenario).** Connect A and B; log 2 QSOs at A so both
  have them. QUIT TR4W at B. Log 20 QSOs at A. Start B, open the same
  contest, and at B log 2 QSOs with the link down (Net > Disconnect first if
  it connected by itself), then Net > Connect. With the setting ON at B.
  EXPECT: B's log holds 24 QSOs (2 + 20 + its 2), none twice, its QSO count and
  score are A's plus its own; a notice "Caught up from the server: 20 QSO(s)
  added."; B's own two reach A (the step-4 resend: "Resent to the server what
  was logged while disconnected: 2 QSO(s), 0 edit(s)." -- the two notices share
  one line, so read `tr4w.log`); `tr4w.log` at B has `[Net] catch-up: 20 to add`
  and `[Net] catch-up: 20 QSO(s) added from the server`, no Error line.
  A's log has B's two and 22+2 in all; the server's log has all of it once.
- [ ] **Nothing owed afterwards.** `tr4w.log` at B (DEBUG): `still owed to the
  server: 0 QSO(s), 0 edit(s)` -- the 20 arrived marked sent and clean, so
  the resend never sends them back. Net > Disconnect and Connect at B again:
  NO notice, `[Net] catch-up: 0 to add; 22 already in this log`, nothing sent.
- [ ] **The question (setting OFF).** Repeat the reboot with the setting off.
  EXPECT: B is ASKED "The server holds 20 QSO(s) that this log does not have.
  Add them to this log now? ..." and nothing is added until Yes. Answer No: the
  log is unchanged, `tr4w.log` says the operator declined, and the question
  comes again on the next connect. Net > Add missing QSOs from the server afterwards still works
  (next item).
- [ ] **Net > Add missing QSOs from the server (the window).** At B, Net > Add missing QSOs from the server. EXPECT: a window
  titled Server log; Get server log fills the Received bytes / records /
  QSOs counters and the grid with the server's QSOs (greyed if deleted); the
  second button reads "Add 20 missing QSOs" and is enabled; clicking it closes
  the window and the 20 appear in B's log with the notice. Get server log again
  with nothing missing: the button stays grey. LOOK AT THE LAYOUT on Windows,
  Mint and macOS: the window was widened to 860 and the buttons re-spaced; the
  "Add ... QSOs" caption must not be clipped (the Spanish/German/Russian
  catalogues have not been written for the two new captions yet).
- [ ] **The backup, and that nothing is replaced.** After a catch-up, the backup
  folder holds a NEW file `<log> before catch-up <date time>Z.db` (one per
  catch-up that added something; never rotated), and `<log> periodic.db` and its
  `.bak` are exactly as they were (check their times) -- also with BACKUP LOG
  FREQUENCY = 0. Open the new file (Open Contest, or any SQLite viewer on a COPY)
  and check it holds B's log as it was BEFORE the 20 were added. B's own two QSOs, logged offline, are still in B's
  log with their original times and exchanges. Make the backup folder
  unwritable (a file where the folder should be) and repeat: EXPECT a warning
  "Nothing was added to the log: the backup of the log taken first failed ..."
  and the log unchanged.
- [ ] **A server log that was not cleared.** Run CQ WW CW on A and B, log 5 QSOs at
  A. Without clearing the server, both stations change the contest to ARRL DX
  CW (both announce the new contest). Restart B, connect. EXPECT: the 5 CQ WW
  QSOs are NOT added; `tr4w.log` says `5 for another contest (first: <call>)`;
  NOTHING is shown on screen (a complete log is silent), and the
  notice "N QSO(s) on the server belong to another contest and were not added."
  follows the "Caught up" one only when something else WAS added.
  Then repeat with a by-id contest on both (a QSO party): with A connected its
  QSOs are added (A announced the contest); stop A, restart B, connect: the
  records of a departed author are added when their byte equals B's handle
  (same build) -- and report what happens with two DIFFERENT builds (Windows
  and Mint), where the byte differs and the QSOs are skipped as "contest not
  known". That last one is the documented limit, ACCEPTED FOR NOW (NY4I,
  2026-10-27); the fix is the contest's ADIF name in the shared record,
  issue #146.
- [ ] **A long outage.** Log 200+ QSOs at A while B is down, start B. EXPECT: B's
  window does not freeze during the download (3.76 MB for 10,000 QSOs, a
  fraction of a second on a LAN), the add and the rescore finish in a few
  seconds, the count is right. Note how long the rescore takes on a big log.
- [ ] **An edit made while B was away.** At A, edit the exchange of a QSO
  B also holds while B is down; restart B and catch up. EXPECT (by design): B's
  copy is NOT updated -- catch-up only adds. Live edits while B is up still
  arrive. D7 picked up such an edit because it replaced the whole file.
  DECIDED (NY4I, 2026-10-27): acceptable until the redesign, issue #146.
- [ ] **The server is reachable but the sync port is not.** Block port+1 at the
  server (firewall), connect B. EXPECT: the link stays up; a notice "Could not
  read the server's log to catch up: could not connect to host:port ..." and an
  Error line; Net > Add missing QSOs from the server shows a warning and the Get server log button
  comes back.
- [ ] **TR4WServerPy and Mint.** Repeat the first item against `python
  tr4wserver.py --display`, and with B on Linux Mint (its backup folder is under
  `~/.config/tr4w/backup`).

---

## Added 2026-10-27 -- A STATION THAT LOST THE LINK CATCHES UP (Phase 1, C5)

NY4I: a station that reboots or loses the link mid-contest must catch up --
required. The QSOs and edits made while it was down used to be sent by a loop
that read the binary `.TRW` this build no longer keeps, so they were never sent
and nothing said so. They are rows in the SQLite log now (`sent_to_server = 0`,
`server_dirty = 1`) and go to the server -- as QSOINFO, which both servers relay
-- once the server's own HELLO has arrived on the new link. A QSO is marked sent
when the writer thread has handed its bytes to the socket, not when it was
posted. Both servers and the receiving client ignore a QSO they already hold.
The unit tests drive all of this through the real queue and writer thread, to a
stub with no socket, on a scratch SQLite log; `tools/netprobe --case resend`
(`--burst 200 --timeout 10`) proves the duplicate rules against both real servers.
They cannot pull a cable, run two programs, or see the QSOs arrive in the other
station's log. **WHAT YOU NEED:** `tr4wserver` (then TR4WServerPy, one at a time),
stations A and B on a LEGACY or by-id contest (both work now), same contest, empty
logs of that contest, **NETWORK AUTO CONNECT off**, `DEBUG LOG LEVEL = DEBUG`.
Delete each server's `SERVERLOG.TRW` between runs.

- [ ] **Drop the link, log 5 QSOs, edit 1, reconnect.** Connect A and B (Net >
  Connect). At A: Net > Disconnect. Log FIVE QSOs at A, then edit one of
  them (change its exchange). A's Network status reads disconnected. Net >
  Connect at A. EXPECT: within a few seconds B's log holds ALL FIVE QSOs and the
  edited exchange on the one that was edited, nothing twice (B's QSO count and
  score moved by five); a notice at A reads "Resent to the server what was
  logged while disconnected: 5 QSO(s), 1 edit(s)." (the edited QSO was never
  sent either, so it travels as a QSO AND as an edit); B shows "Server log
  changed: 5". `tr4w.log` at A: `[Net] resending
  what was logged while disconnected: 5 QSO(s), 1 edit(s)`, no `[NetSend]`
  Warn or Error. The server log shows five `NET_QSOINFO` and one `NET_EDITEDQSO`.
- [ ] **Nothing is owed afterwards.** `tr4w.log` at A (DEBUG) ends the catch-up
  with `[Net] still owed to the server: 0 QSO(s), 0 edit(s)` (no window shows
  the two numbers any more). Net >
  Disconnect and Connect again at A. EXPECT: NO second notice, nothing resent
  (`tr4w.log` has no `resending` line for the second link).
- [ ] **Reboot variant.** With A connected log nothing; Net > Disconnect at A;
  log 3 QSOs and edit one; QUIT TR4W at A; start TR4W at A, open the same
  contest; Net > Connect. EXPECT: the same as above for three QSOs: B gets them
  all, once each, and the edit lands. (The flags are in the log file, so they
  survive the restart. Check that A did NOT resend anything it had sent before
  it was disconnected: `tr4w.log` counts only the three.)
- [ ] **A QSO is not "sent" until it is written.** With both connected, log a QSO
  at A and at once pull A's network cable (or kill the server) so the write
  cannot finish. EXPECT: after the link is reported lost the QSO is counted as
  unsent at A (`still owed ... 1 QSO(s)` in `tr4w.log`), and when the link is back it reaches B exactly once.
  If the cable was pulled just AFTER the write and B already had it, A may
  send it again: B must not log it twice (`[Net] QSO ... is already in the
  log; the copy that just arrived is ignored` at B).
- [ ] **An import is never sent.** Open a contest log that has imported QSOs
  (ADIF or an old `.TRW`), Net > Connect. EXPECT: NO resend notice, nothing
  reaches the server from the imported rows (`still owed ... 0 QSO(s)`).
- [ ] **A refused station does not push.** Start A with COMPUTER ID the same as
  B's (B connected). EXPECT: A is refused (8320), A's QSOs logged while
  disconnected stay UNSENT and no resend notice appears. Change A's id to
  another letter and Connect: now they go.
- [ ] **A long outage.** Disconnect A and log a few hundred QSOs at A with the
  link down (only QSOs LOGGED at A count; an ADIF import does not travel),
  then reconnect. EXPECT: the main window never freezes while they go, all
  arrive at B, and the notice names the count. In-tree `tr4wserver` relays
  about 34 QSOs a second (200 in about 6 s), so B's log fills in over that long.
- [ ] **Python server.** Repeat the first item against TR4WServerPy
  (`python tr4wserver.py --display`). EXPECT the same, and the server log says
  `QSOINFO already in the server log - not stored, not relayed` for anything
  sent twice.

---

## Added 2026-10-28 -- A .local (mDNS) HOST NAME RESOLVES THROUGH THE C LIBRARY (issue 148)

Every host name the operator types now goes through `uHostResolve`. On Linux
and macOS it asks the C library (`gethostbyname`: /etc/hosts, DNS, mDNS, the
machine's own configuration) and Indy is handed the IPv4 address; on Windows
the name is passed on untouched. Only a machine with avahi and a real `.local`
host can show the first two items.

1. **Linux Mint, multi-op.** Server address `pi400.local` (the Pi that answers
   `getent hosts pi400.local`), Net > Connect. The link comes up and the station
   list fills in, as it does with the IP.
2. **Linux Mint, a bad name.** Server address `nosuch.local`. `tr4w.log` shows
   one Error line `[Net] could not resolve 'nosuch.local': ...` naming the
   name, then only Debug lines on the retries; the Network window never says
   Connected. Net > Connect again logs it once more.
3. **Linux Mint, the other users of a name.** A DX cluster, a TCI radio, a K4 or
   Kenwood LAN radio and an Icom LAN radio addressed by a `.local` name each
   connect. A radio that will not resolve logs the name in its usual connect
   failure line (the Icom and K4 spectrum paths log it once per run of failures).
4. **Windows, unchanged.** The same server, cluster and radio entered by name
   or IP behave as before; the log shows no resolver lines.
5. **macOS, if a Mac is at hand.** `pi400.local` connects. This is the arm that
   declares `gethostbyname` itself (cnetdb is not built for Darwin) and was not
   compiled until the release workflow ran.
6. **UDP destinations (Preferences, UDP).** A destination entered as
   `pi400.local` delivers on Mint (the Test button says so, and a listener on
   the Pi sees the datagram). A dead name (`dead.local`) logs
   `[UDP] Send to dead.local:<port> failed: EHostResolveError - could not resolve
   'dead.local': ...` and the next destination is still sent to; the only
   stall is the lookup itself. Resolved at every send on purpose, never cached.
   The Test button with a dead name shows "Could not send to dead.local:<port>
   -- could not resolve 'dead.local': ...". On Windows the same destinations
   behave as before.
7. **A name with only an IPv6 address** (no A record) fails with "no IPv4
   address" in the log rather than connecting; nothing here dials IPv6.

---

## Added 2026-10-27 -- THE MULTI-OP LINK BELONGS TO THE PROGRAM, NOT THE NETWORK WINDOW

NY4I: *"I never liked the idea that we only connected when the Network window
was up."* Until now the link was connected by showing the Network window and
dropped by closing it. Now the program owns it: the **Net menu** has Connect,
Disconnect, Reconnect and Show Network window, `NETWORK AUTO CONNECT` (Preferences

> Network; default OFF) connects at startup, and the window is only a view.
> The unit tests reach the state table, the menu rows in every state, the refusal
> latch, the observer list and the window drawing the stations it was not open to
> see. They cannot connect. **WHAT YOU NEED:** `tr4wserver` (or the Python server)
> and TWO stations, A and B (Windows and Mint), both with a COMPUTER ID and the
> server address set, on the same contest. Start with NETWORK AUTO CONNECT off.

- [ ] **Nothing connects by itself.** Start A. EXPECT: no connection attempt in
  `tr4w.log` (`[Net] not connecting at startup (NETWORK AUTO CONNECT is off ...)`),
  the status strip's Network panel is empty or "Disconnected from Network",
  and the Net menu offers Connect and Show Network window only (Disconnect,
  Reconnect, Set time, Send message, Add missing QSOs and the clear rows are grey).
- [ ] **Connect with the Network window CLOSED.** Net > Connect at A and at B,
  never opening the window. EXPECT: the strip reads "Connected to Network";
  Connect greys, Disconnect and Reconnect and the sending rows light.
- [ ] **QSOs cross with the window closed.** Log at A, then at B, then the same
  call on the same band and mode at both. EXPECT: each arrives at the other, and
  the second is flagged a dupe. The Network window has not been opened once.
- [ ] **Open the window mid-session.** Net > Show Network window (and again from
  Windows > Network). EXPECT: BOTH stations are in the list at once with name,
  id, band and frequency, QSO count and call, the title reads
  `Network : Connected to <address>:<port>` -- without waiting for either
  station to do anything. Log a QSO at B: A's row count moves.
- [ ] **Closing the window drops nothing.** Close it (Escape and the close box).
  EXPECT: still connected, QSOs still cross, the strip still says connected.
  Reopen: the list is right again. Show Network window while it is open
  brings it forward and does not close it.
- [ ] **Disconnect.** Net > Disconnect at B. EXPECT: B's strip reads
  "** DISCONNECTED from Network", B's list is empty, A's row for B clears,
  and B does NOT reconnect by itself. Connect, Disconnect and the rest of the
  menu keep their greying right. Log at B while disconnected: nothing
  reaches A until B connects again, and then it is resent (C5, below).
- [ ] **Reconnect.** Net > Reconnect at B while connected. EXPECT: a clean drop
  and a new link, both rows back, no dialog.
- [ ] **Auto-reconnect without the window.** With the window closed and B
  connected, stop the server, wait ten seconds, start it again. EXPECT: B
  reconnects by itself within the retry interval (`NET STATUS UPDATE
  INTERVAL`, 5 s by default), the strip goes disconnected, "Connecting" and
  connected, with no dialog and no storm of log lines. Then Net > Disconnect
  during an outage: the retries stop.
- [ ] **A server that is not there.** Net > Connect with the server stopped.
  EXPECT: the Disconnect item is lit while it retries (it stops the
  retrying), one "Failed to connect" line in the log, not one per attempt.
- [ ] **The refusal latch is re-armed by Connect.** Point B at an old server
  (before protocol 2) or give B a computer id already in use. EXPECT: the
  dialog ONCE, then silence (no retry every five seconds), the Net menu
  offering Connect and Reconnect. Fix the cause and choose Net > Connect:
  it is tried again and works. (Before this change the way back was
  closing and reopening the Network window.)
- [ ] **NETWORK AUTO CONNECT.** Turn it on in Preferences > Network, restart
  B with the server up. EXPECT: connected a moment after the main window
  appears, with the Network window never opened. Restart with the server
  down: the retries run quietly and it connects when the server comes up.
  With COMPUTER ID blank: no attempt at startup; Net > Connect opens
  Preferences at COMPUTER ID instead of connecting.
- [ ] **Restore.** Leave the Network window open, quit, relaunch with AUTO
  CONNECT off. EXPECT: the window comes back showing the disconnected title and
  an empty list, and nothing connects until you ask.
- [ ] **Preferences > Network layout.** The new checkbox ("Connect to the
  multi-op server when TR4W starts") sits above the grey hint text without
  overlapping it or the "Radio sharing" heading below, and (issue #142) the
  Network panel in the status strip is not clipped.
- [ ] **Quit while connected and while retrying.** Exit from each: no hang, no
  error. Exit now disconnects first (`NetLinkShutdown` from `ExitProgram`):
  after a quit while connected, the server logs the departure and the other
  stations clear this station's row at once, not after a timeout.

---

## Added 2026-10-27 -- THE QUEBEC QSO PARTY (issue #128)

A new by-id contest (`QC-QSO-PARTY`), the third Canadian host on the party
base. Unit-tested (`uTestContestQuebecQP`, including a real-engine run for
both entrants); nothing sees the screen, the multiplier windows or a written
file.

- [ ] **The New Contest dialog.** Choose the Quebec QSO Party: EXPECT the
  MY STATE comment asks for the administrative region code (e.g. MTL),
  not "if you are in QC state". With MY STATE `MTL` the session is in
  province; with `QC` it is OUTSIDE Quebec (no guard refuses it -- the
  prompt is the only one).
- [ ] **In Quebec** (MY STATE `MTL`). `599 QUE` is Capitale-Nationale (a
  region), not Quebec; `599 QC` and `599 VE2` are refused. `599 NF` then
  `599 LB`: TWO multipliers; `599 NL`: refused. `599 NT` then `599 NWT`:
  one. `599 DC` then `599 MD`: two. DL1xxx `599 DX` then JA1xxx `599 DX`
  on 20 m: ONE new multiplier; DX again on 40 m: a new one. `599 DL` is
  refused ("must be logged as DX").
- [ ] **Out of Quebec** (MY STATE `NY`). `599 MTL` takes; `599 NY` and a DX
  station's `599 DX` are refused with "work QC stations only".
  `W2ABC/VE2 599 GIM` takes and is located as Canada; `VE2xxx/LVL` is
  VE2xxx in Laval.
- [ ] **A region line.** `599 MTL/LVL` logs two QSOs; `599 MTL/LVL/LNS` is
  refused (two regions -- the French rules' "deux zones"; the English
  says "2 or more", open on #128).
- [ ] **No 160 m.** A 160 m QSO is logged as an X-QSO (`X-QSO:` in the
  Cabrillo), scoring nothing.
- [ ] **The Cabrillo file.** CONTEST: `QC-QSO-PARTY`; a DX entrant (no MY
  STATE) sends `599 DX` (not its prefix); FM is `FM`. The ADIF carries
  STATE `QC` for a region, `NL` for NF and for LB, and no CNTY.
- [ ] **File > Reports > 3830 Score** from a real log: one `Mults` column (no
  3830 form was found for this contest).
- [ ] **NOT BUILT (#133)**: a mobile entrant's re-work from a new region is
  a dupe, its multipliers are one sheet, and there is no 300-point region
  bonus. Expect a mobile's claimed score low.

## Added 2026-10-26 -- THE ONTARIO QSO PARTY (issue #127)

A new by-id contest (`ON-QSO-PARTY`), the second Canadian host on the party
base. Unit-tested (`uTestContestOntarioQP`, including a real-engine run for
both entrants); nothing sees the screen, the multiplier windows or a written
file.

- [ ] **The New Contest dialog.** Choose the Ontario QSO Party: EXPECT the
  MY STATE comment asks for the Ontario county code (e.g. TOR), not "if
  you are in ON state". With MY STATE `TOR` the session is in province;
  with `ON` it is OUTSIDE Ontario (no guard refuses it -- the prompt is
  the only one).
- [ ] **In Ontario** (MY STATE `TOR`). Type `599 MAN` for VE3xxx: EXPECT the
  multiplier is Manitoulin (MAN), not Manitoba; `599 MB` is Manitoba, a
  second multiplier. `599 DC` then `599 MD`: TWO multipliers. `599 NF`
  then `599 LB`: one (NL). `599 ON`: refused. Work DL1xxx `599 DL` on 20
  and on 40 m: a new DX multiplier on EACH band; the remaining-countries
  window lists DXCC countries but not K, VE, KH6 or KL.
- [ ] **The club stations.** VE3CCO, VA3CCO, VE3ODX, VA3RAC, VE3RHQ score
  10, also as `VE3CCO/TOR` (the rover strip); `VE3CCO/M` scores 2.
- [ ] **A county-line junction.** `599 TOR/YRK/PEL/DUR/HTN` logs five QSOs,
  one per county; nothing is refused (no maximum).
- [ ] **The Cabrillo file.** EXPECT the writer refuses to start without
  LOCATION (the sponsor scores in/out of province from ARRL-SECTION:
  ONN, ONS, ONE or GH; DX outside North America); an FM QSO's mode is
  `FM`; a DX entrant (no MY STATE) sends its own prefix (`599 DL`); the
  ADIF carries STATE `ON` for a county and no CNTY.
- [ ] **File > Reports > 3830 Score** from a real log: one `Mults` column (no
  3830 form was read for this contest).
- [ ] **NOT BUILT (#133)**: a rover's claimed score is a fixed station's --
  one multiplier sheet, no 300-point area bonus. Expect it low.

## Added 2026-10-26 -- THE NEW MEXICO QSO PARTY (issue #125)

A new by-id contest (`NM-QSO-PARTY`). Unit-tested (`uTestContestNewMexicoQP`,
including a real-engine run for both entrants); nothing sees the screen, the
multiplier windows or a written file.

- [ ] **In New Mexico** (New Contest, MY STATE `BER`). Type `599 DC` for W3DC:
  EXPECT the multiplier shown is **MD**; `599 NM`: a new multiplier (NM is
  one of the 50 states). Work LY2ZZ `599 LY`: a new **DX** multiplier, and
  the remaining-countries window lists DXCC entities but not K, VE, KH6 or
  KL (KP4 is listed).
- [ ] **The Cabrillo file** (summary window: CATEGORY-POWER, LOCATION `NM`).
  EXPECT the writer refuses to start without LOCATION; LY2ZZ's line ends
  `599 DX`, not `599 LY` or blank; an FT8 QSO's mode column is `RY`; an FM
  QSO's is `PH`; `CLAIMED-SCORE` is points x multipliers x the power
  multiplier (QRP 5, LOW 2, HIGH 1), plus 250 if W1AW/5 was worked.
- [ ] **A DX entrant** (MY CALL LY2xxx, no MY STATE): EXPECT the CQ exchange
  is `5NN LY` (what goes on the air), the ADIF `STX_STRING` carries `LY`,
  and the Cabrillo sent column is `DX`.
- [ ] **W1AW/5.** Work `W1AW/5` from two counties on one band and mode: two
  QSOs, the bonus 250 once. Logged as `W1AW/5/BER` it is NOT paid today --
  the base matches the bare call only (South Carolina's #111 fixes it).
- [ ] **A county line of two.** `599 SOC/SIE` logs two QSOs; three counties
  are refused.

## Added 2026-10-26 -- THE OKLAHOMA QSO PARTY (issue #126)

A new by-id contest (`OK-QSO-PARTY`). Unit-tested (`uTestContestOklahomaQP`,
including a real-engine run for both entrants, and
`uTestContestStateQSOPartyBase` for the DX entrant's sent prefix, now shared
with North Dakota); nothing sees the screen, the multiplier windows or a
written file.

- [ ] **In Oklahoma** (New Contest, MY STATE `MUS`). Type `599 DC` for W3DC:
  EXPECT it is taken and the multiplier shown is **MD** ("DC counts as
  Maryland"); `599 MD` afterwards is no new multiplier. Type `599 OK`:
  a new multiplier (NY4I: OK stays a state). Work DL1xxx `599 DL`: a new
  **DX** multiplier, and the remaining-countries window lists DXCC
  countries but not K, VE, KH6 or KL.
- [ ] **A mobile on a four-county line.** In Oklahoma, enter
  `599 PIT/LAT/HAS/LEF` for one call: EXPECT FOUR QSOs in the log, one per
  county, each scored. `599 PIT/LAT/HAS/LEF/MCU` is refused
  ("too many counties", maximum 4) and nothing is logged.
- [ ] **A DX entrant** (MY CALL DL1xxx, no MY STATE): EXPECT the CQ exchange
  is `5NN DL`, and the Cabrillo QSO lines and the ADIF `STX_STRING` carry
  `DL`, not `DX` (North Dakota the same -- its code moved to the party
  base).
- [ ] **Digital.** A JS8 or PSK QSO scores 3; an FT8 or FT4 QSO is a greyed
  X-QSO. CW and PSK with the same station on one band are two QSOs.
- [ ] **The Cabrillo header.** The rules ask for one custom
  `CATEGORY: OKLAHOMA MOBILE ...` line; TR4W writes `CATEGORY-*` tags.
  Check okqp.contesting.com accepts the file as written (NY4I: bench).
- [ ] **File > Reports > 3830 Score** from a real log: one `Mults` column,
  as the 3830 form has (checked against the 2026 breakdown page).

## Added 2026-10-26 -- THE RADIO POLLER WRITES NO CONTROL (issue #108)

The poller now sets state and asks the main thread to draw it. The unit test
runs the real polling thread over a probe radio; a real rig, the CW-by-CAT end
of message and the band map's call-on-frequency have not been run.

- [ ] **A CW speed change at the rig updates the WPM panel.** K4 (or a network
  Icom), CW, CW SPEED SYNC on for that radio. Turn the rig's keyer speed knob.
  EXPECT the WPM panel to follow within a poll, and an F-key message to go out
  at the new speed. Then switch to radio 2 and back: the speed it remembers is
  the one you set at the rig.
- [ ] **The WinKeyer speed pot updates it too.** With a WinKeyer and its pot
  enabled, turn the pot. EXPECT the WPM panel to follow.
- [ ] **CW-by-CAT, end of message.** K4 CW-by-CAT, AUTO-CQ on: F1 CQ. EXPECT the
  CQ to repeat after the auto-CQ delay (the resume used to arm its timer from the
  poller). With AUTO CALL TERMINATE, type a call and send: EXPECT the return to
  CQ mode exactly as before.
- [ ] **The band map still fills the call window.** S&P with spots on the band
  map; tune the active radio onto a spot. EXPECT the spot's call in the call
  window, as before. SO2R with TUNE ALT-D: tune the inactive radio onto a spot,
  EXPECT the Alt-D dupe check as before.
- [ ] **Nothing in the log.** After the session, search `tr4w.log` for
  `NOT the main thread`. Any line is now an ERROR and names the caller; report
  it (the CW thread, the WinKeyer reader and DVK playback were moved by issue
  #132 -- see that section above).

## Added 2026-10-26 -- THE CABRILLO IS NAMED AFTER THE LOG (NY4I)

The name rule is unit-tested (`uTestLogDatabase`, `TestExportNames*`) and the
corpus checks the bytes; the menu route and the SCP upload have not been run.

- [ ] **The three names sort together.** Open a real contest log, e.g.
  `CQ-WW-SSB 2026-10-19 NY4I.db`. File > Export ADIF, then Create Cabrillo.
  EXPECT `CQ-WW-SSB 2026-10-19 NY4I.adi` and `CQ-WW-SSB 2026-10-19 NY4I.log`
  beside the `.db`, in the log's folder, and no `NY4I.LOG`. Export a second
  contest: it gets its own `.log`, the first is untouched.
- [ ] **SCP uploads the new file.** Answer Yes to the upload prompt after
  Create Cabrillo. EXPECT the log line `...NY4I.log file uploaded to SCP`
  naming the new file.

A sponsor that wants the call as the file name (Georgia QP, Russian DX) gets a
manual rename by the operator. NY4I, 2026-10-26: no export option for it.

## Added 2026-10-26 -- K4 TX TEST MODE IS SHOWN ON A KEY-UP (issue #97 phase 2)

Unit-tested: the decision (`uTestTXInhibitAlert`), a CW message through the
keying facade on an inhibited radio, SO2R and a down link included
(`uTestCWKeyer`), and the PTT indicator and status panel on the streamed main
window (`uTestStatusAndNotice`). What no test can see is a real K4 and a real
screen. Put the K4 in TX TEST mode (`TS1`) and keep tr4w.log open.

- [x] **The INH display -- CONFIRMED 2026-10-26, NY4I** ("INH works nicely",
  K4 in TX test mode, uncommitted phase 2 build). The split stands: `INH`
  in the three-cell PTT box, the sentence on the status panel. The items
  below that he did not report on stay open.
- [ ] **Does a K4 in TX TEST report TX at all while its icon flashes?** Watch a
  TRACE log during a long CQ (20 s or more) in test mode: does `TX;` (AI4
  and up), `IF` with the TX flag, or a `TQ` answer say TRANSMITTING? If it
  does NOT, a key-up TR4W started is never confirmed by the radio, and the
  alert DROPS 3 s after the CQ starts (the wait in uTXInhibitView) while
  the CQ is still going. Report which, network and serial.
- [ ] **F1 CQ turns the indicator red AT ONCE.** CW, F1. EXPECT the PTT box
  (between USER INFO and OP MODE) to read `INH` on the alert colour, and
  the radio's status panel (bottom strip, radio 1's quarter) to read
  `TX INHIBITED: TX test mode`, as the CQ starts -- not a poll later. One
  line in tr4w.log: `[TX inhibit] <radio> is keyed and reports TX
  inhibited (TX test mode) -- no RF is going out`. Repeat on SSB with a DVK
  message (F1 on a .WAV).
- [ ] **The footswitch does too.** Key from the K4's footswitch or mic PTT (TR4W
  did not start it). EXPECT the same box and panel within about a poll.
  Serial K4 at AI2: TX is learned from the poll, so note the delay.
- [ ] **It clears on unkey.** When the CQ ends, or the footswitch is released,
  EXPECT the box back to `OFF` on its normal colour and the status panel
  empty. Also take the K4 OUT of test mode mid-transmission: EXPECT it to
  clear at once.
- [ ] **One log line per key-up.** Send CQ three times (or AUTO-CQ). EXPECT
  exactly three `[TX inhibit]` lines -- not one per poll.
- [ ] **The beep, when enabled.** Preferences, PTT: tick *Beep when keying a
  radio that will not transmit* (`PTT TX INHIBIT BEEP`). BEEP ENABLE must
  also be on -- it is the master cue every beep obeys. EXPECT one warning
  beep per key-up and none with the box unticked.
- [ ] **No dialog, ever**, and nothing at all while receiving in test mode.
- [ ] **SO2R, keyers swapped (issue #97 review).** Two radios on CW-by-CAT,
  radio 2 in test mode, send to the inactive radio (Ctrl-A or a dueling
  CQ), then press SPACE in S&P with nothing in the call window (it sends
  MY CALL through SendStringAndStop). EXPECT radio 2 to key it -- it used
  to sit in radio 2's buffer unsent -- and the warning on radio 2's
  status panel, not radio 1's.
- [ ] **Out of test mode, nothing changes.** F1 CQ: `ON ` on radio 1's red, as
  before, no status text, no log line.

## Added 2026-10-26 -- K4 TX TEST MODE REACHES THE STATUS (issue #97 phase 1)

Unit-tested: the `TSn;` parse, a reply split across reads, the connect-time
`TS;` against a loopback server, the status change detection
(`uTestTXInhibit`, `uTestRadioSocketNoRead`). These items need no key-up, so
the evidence is the log (what a key-up SHOWS is the phase 2 entry above). Set DEBUG LOG LEVEL = DEBUG (TRACE for
the second item's raw lines).

- [ ] **Does the K4 PUSH `TS` when test mode is toggled at the front panel?**
  TR4W asks `TS;` at every link-up and then every 5 s, because whether the
  radio sends it unsolicited under auto-info is UNKNOWN. Network K4 (AI5),
  then serial K4 (AI2). Toggle TX TEST on and off at the rig several times,
  a few seconds apart. EXPECT `[TX inhibit] ON -- the radio reports: TX
  test mode` and `[TX inhibit] OFF` for each toggle. The QUESTION is the
  delay: if every line lands within a fraction of a second of the toggle,
  the K4 pushes it; if they land up to 5 s late, only the poll is finding
  it. At TRACE, a pushed one shows `Received from radio: (TS1)` with no
  `TS;` sent just before it. Report which, per transport -- if it is
  pushed, the 5 s poll can go.
- [ ] **How fast does the K4 report TX state?** Matters only for phase 2's
  second trigger (keying from a footswitch or mic PTT, which TR4W did not
  start). Key the K4 from the front panel / PTT, network and serial. At
  TRACE, measure from the key-down to the `TX` line in `tr4w.log`, and
  from key-up to `RX`. (Serial auto-info never reports a T/R transition
  on a K3S, so on serial expect it to arrive only with the next `IF;`
  poll -- note the delay you see.)
- [ ] **No change to the frequency poll.** Serial K4 at a fast FREQUENCY POLL
  RATE: EXPECT the VFO display to track the knob as before, and one `TS;`
  roughly every 5 s in a TRACE log -- not one per `IF;`.

## Added 2026-10-26 -- THE NEEDS STRIPS AFTER A QSO IS LOGGED (issue #100)

Unit-tested on the real form and sheets
(`uTestStatusAndNotice.Test_LoggingAQSOTakesItsBandOutOfTheNeedsStrips`); the
live LogContact path has not been run.

- [ ] **A new multiplier drops its band from both strips.** CQ WW, S&P: type a
  station in a country not yet worked, press Enter, log it on 20 m. EXPECT
  "QSO needs for <call>" and "Mult needs for <call>" both to lose 20 at once,
  before anything else is typed, and the other bands to stay.
- [ ] **Tail-ending keeps the NEXT call.** In a run, tail-end: with the next
  station's call already in the strips, let the previous QSO log. EXPECT both
  strips to keep naming the NEXT call, not the one just logged.

## Added 2026-10-26 -- EXIT AND THE ICOM SPAN AT LINK-UP (issues #106, #107)

Unit-tested with a blocking fake radio and a real IC-9700 whose wire is a list
(`uTestRadioDestructors.Test_Exit*`, `uTestIcomScopeSeam.Test_SpanIsAskedOnEveryLinkUp`);
not yet run against a radio.

- [ ] **Exit with a network radio switched off: no 3 s pause.** K4 (or any
  network radio) off, wait for its reconnect attempts in the log, then
  exit. EXPECT TR4W to close at once; in `tr4w.log` EXPECT
  `[ExitProgram] Shutting down` and `Freeing radio object` for that radio
  within a fraction of a second, and NO `did not stop within` ERROR.
  (NY4I's 2026-10-26 10:23:58 exit with the K4 off waited exactly 3 s.)
- [ ] **The panadapter still comes back after exit.** Panadapter open, exit,
  restart. EXPECT it to reopen: exit detaches it, it does not close it.
- [ ] **Icom panadapter span known after startup.** Network IC-9700 (or
  IC-7610/IC-705), panadapter open at shutdown. Start TR4W. EXPECT
  `radio reports scope span <n> Hz` (TRACE) after the CI-V stream opens,
  and the span buttons work at once, before the span is changed at the rig.
- [ ] **Again after a reconnect.** Pull the radio's network cable and restore
  it (or power-cycle). After it reconnects, EXPECT the span read again in
  the log, once.

## Added 2026-10-26 -- K4 STARTUP SENDS AND RADIO REBUILD (issues #99, #104)

Unit-tested against a loopback server and a blocking fake radio
(`uTestRadioSocketNoRead`, `uTestRadioDestructors`); not yet run against a K4.

- [ ] **The span is known without touching the rig.** Network K4, panadapter
  open at shutdown. Start TR4W. EXPECT no `Cannot send command (#SPN;)` and
  no `Cannot send command (KY ;RX;)` error in `tr4w.log`; EXPECT
  `radio reports spectrum span <n> Hz` (TRACE) shortly after
  `Network Radio connected`; and the span +/- buttons work at once, before
  the span is changed at the rig.
- [ ] **Again after a reconnect.** Power-cycle the K4 (or pull its network
  cable and restore it). After it reconnects, change the span AT THE RIG
  while TR4W is disconnected if you can, then press a span button: EXPECT it
  to step from the rig's current span.
- [ ] **Reset Radio Ports with the K4 switched off.** Turn the K4 off, wait for
  the reconnect attempts in the log, then Reset Radio Ports several times.
  EXPECT no crash and no `did not stop within` ERROR; each reset logs
  `Freeing radio object`. (The old 3 s wait was shorter than a 5 s connect
  attempt, so this freed the radio under its polling thread.)

## Added 2026-10-25 -- THE PERIODIC BACKUP AND BACKUP DESTINATION (issue #98 step 2)

Unit-tested with real files and a fault-injecting file layer (`uTestBackupCopier`,
`uTestLogStore`); nothing has run against a real share.

- [ ] **The local backup moved.** With BACKUP LOG FREQUENCY = 5, log five QSOs.
  EXPECT `settings\backup\<log> periodic.db` (beside `tr4w.json`), the status
  line saying so, and NOTHING new beside the logs -- the Open dialog must not
  list a backup. A second five gives `<log> periodic.db.bak`. Old
  `logback.db` files are left where they are.
- [ ] **Your setting carried over.** Your `tr4w.json` says `BackupFileName:
  "logback.db"`. EXPECT Preferences' "Copy to:" EMPTY (a bare name meant
  beside the logs, which is now the local folder). Put `\\NAS2\Backups` (or a
  Dropbox folder) there and press OK. EXPECT within a few seconds, on the
  status line: "Backup destination ... is reachable.", and `tr4w.log`
  `[BackupCopy] ... reachable`.
- [ ] **A copy arrives.** Five more QSOs. EXPECT `<log> periodic.db` in the
  share, and no `.partial` left there; then `.bak` beside it after the next.
- [ ] **The status line says where it went** (2026-10-25, after NY4I read the
  local file's name as "the destination was ignored"). With the destination
  set, press Backup Log (Alt-F). EXPECT first "Log backed up; copying to
  <the destination folder> ..." (the folder, not the local file), then within
  a few seconds "Backup copied to <the file in the share>.", with no beep,
  and `[BackupCopy] copied and verified:` at INFO in `tr4w.log`. The same two
  lines on a periodic backup. With "Copy to:" empty, EXPECT the old "Log
  backed up to ..." and nothing after it.
- [ ] **The share goes away.** Unplug or unshare it, log five QSOs. EXPECT ONE
  status-line message and a beep ("Backups are NOT reaching ..."), one Error
  line in `tr4w.log`, logging uninterrupted, and NO further message on later
  backups. Restore the share and wait up to a minute WITHOUT logging. EXPECT
  "Backups are reaching ... again".
- [ ] **A hung share at exit.** With a copy in progress to a slow or hanging
  share, close TR4W. EXPECT it to close within about two seconds, with
  `[BackupCopy] shutdown: still copying ...` in `tr4w.log` if the copy was cut.
- [ ] **Caught up at start.** Make the share unreachable, log five QSOs, close,
  restore the share, start TR4W. EXPECT the periodic backup copied at start
  with no new QSO.

## Added 2026-10-23 -- MODE NAMES SENT TO OTHER PROGRAMS (UDP, RADIOINFO, DXKEEPER)

Unit-tested (`uTestN1MMMode`, `uTestUDPContactXml`); nothing sees a listener.

- [ ] **UDP contact broadcast.** With a UDP listener (N1MM-format: Log4OM,
  GridTracker, a scoreboard) log an SSB QSO on 40 m and one on 20 m with
  the radio in plain SSB, and a QSO with the K4 in DATA A. EXPECT
  `<mode>LSB</mode>`, `<mode>USB</mode>` and `<mode>RTTY</mode>` -- never
  `SSB` or `DATA` -- and the listener logs each in the right mode.
- [ ] **N1MM RadioInfo.** Watch the RadioInfo packet while the radio is in
  CW-R, FM-N or DATA. EXPECT `CW`, `FM` and `RTTY` (it sent `CW-R`, `FM-N`,
  `DATA`, and `NoMode` for a radio with no extended mode).
- [ ] **DXKeeper external log.** Log an FT4 QSO and a DATA A QSO with the
  external logger on. EXPECT DXKeeper records MODE MFSK / SUBMODE FT4, and
  MODE RTTY; before, a DATA QSO went as MODE `DATA`.

## Added 2026-10-23 -- RTC 2026 RULES AND THE CLEARER IMPROPER-QTH MESSAGE

Unit-tested (`uTestContestRTC`, `uTestContestGeorgiaQP`,
`uTestContestReadiness`); the matrix sees the parse result and the error text,
nothing sees the window.

- [ ] **RTC, same station twice on one band.** Work DL1xxx on 20 m CW, then on
  20 m SSB. EXPECT the SSB QSO is NOT a dupe and earns its distance
  points, but its grid is NOT a new multiplier (grids count per band).
  Work it again on 20 m CW: a dupe. A QSO on 80 m, or in FM or a digital
  mode, is a greyed X-QSO.
- [ ] **Georgia, as an out-of-state entrant** (MY STATE outside GA), type
  `599 CT` for W1AW. EXPECT the message reads
  `Improper domestic QTH!! (CT: work GA stations only)` and **fits** the
  main-window element (52 characters; the old longest form was 45). Type
  `599 HARX`: `(HARX not in georgia_cty.dom)`.
- [ ] **A stated MY COUNTRY no longer shows on screen** in a refusal (it did as
  `(MY COUNTRY = K)` in several QSO parties); it is still in `tr4w.log`. An
  EMPTY MY COUNTRY in ARRL DX still shows `(MY COUNTRY is empty)`.
- [ ] **ARRL Field Day, a bad section.** Type `2A WSX` for W1AW. EXPECT
  `Invalid ARRL Section (WSX not in arrlsect.dom)` (46 characters), the
  caret after `WSX` as before (issue #1010). `2A` alone:
  `Invalid ARRL Section (no QTH)`. Winter Field Day the same.
- [ ] **RTC, serial 0 is refused everywhere.** Type `0 FN31`: EXPECT
  `QSO number 0 is not valid in this contest.`, the caret after `0`, and
  nothing logged. In Edit QSO, set a QSO's received (or sent) number to 0
  and save: the same warning, the window stays open, nothing changes.
  Import an ADIF with one RTC record whose SRX is 0: EXPECT the import
  stops, names that record, and imports NOTHING.
- [ ] **Q119, an out-of-area QSO that reaches the log is an X-QSO.** With
  MY STATE outside Georgia, import (or receive from a peer) a GA QSO Party
  QSO with W1AW `CT`. EXPECT it greyed as an X-QSO, scoring nothing, and
  `X-QSO:` in the Cabrillo. A Georgia county QSO stays a plain `QSO:`.
- [ ] **Opening a log uses ITS OWN MY STATE.** With the station's MY STATE
  FL, open a QSO party log made at a host county (the Michigan corpus log,
  MY STATE `WAYN`). EXPECT it opens IN STATE: QSOs with DC/MD/VA/OH are
  plain QSOs and score. Until this fix it opened out of state.

## Added 2026-10-23 -- HAMSCORE RE-EMITS A STORED QSO FROM ITS RECORD (issue 95, review R6, Q13)

Unit-tested only (`Test_HamScoreStoredQsoReadsItsRecord`,
`Test_HamScoreStoredQsoGridIsTheFinalExportsGrid`,
`TestTheSentExchangeReadsBackWithTheFacts`). The corpus never sees HamScore, and
nothing automated reaches the uploader. What changed: the one-QSO Cabrillo line
HamScore receives no longer reads today's MY CALL and CQ exchange when it
describes a QSO that is already in the log. Edit QSO, the Tools -> HamScore
resync and Alt-Y's undelete now pass the row's recorded station
(`my_call`, grid) and its `exchange_sent`; a QSO being logged right now passes
the session's values, which are the ones being recorded.

Needs a HamScore account (or the status window's queue count, if posting is
off) and a contest HamScore accepts (RTC, or any RTC-capable contest).

- [ ] **Just-logged is unchanged.** HAMSCORE ENABLE on. Log three QSOs as
  your call and grid. In the HamScore window the queue grows by three and
  the server shows each with your call and exchange, as before this change.
- [ ] **A changed session does not rewrite old QSOs.** Change MY CALL (or add
  a /P) and MY GRID, and edit the CQ exchange (`CQ EXCHANGE CW`, e.g. add a
  word). Log one more QSO: it carries the NEW call and exchange.
- [ ] **Edit one OLD QSO** (Edit QSO, change only its callsign or its RST,
  Save). HamScore shows that QSO still sent from the ORIGINAL call and grid
  -- not the new ones -- with your correction applied. If you
  change the "my station" fields in the editor and save, those corrections
  are what HamScore shows.
- [ ] **Tools -> HamScore resync** (it wipes the server log and re-sends all
  QSOs). Every QSO appears with the call and exchange it was logged with:
  the first three as the original station, the fourth as the new one.
- [ ] **Alt-Y twice** on the newest QSO (delete, then undelete). After the
  undelete it reappears with its own recorded station.
- [ ] **A log from before this build** (a QSO row that never recorded its
  station -- a log written before schema 3, or migrated from a `.TRW`): resync sends today's call and exchange for it, as before. That is
  the deliberate fallback, not a regression.
- [ ] **Edit a SENT serial** (Edit QSO, change the sent number of one QSO,
  Save). HamScore shows the NEW serial in that QSO's sent exchange (NY4I,
  2026-10-23), and a Tools resync afterwards still shows it. The sent
  exchange is rebuilt from the QSO's record and its recorded grid, as the
  Cabrillo file does; the CQ exchange template is today's. An IMPORTED QSO
  is the exception: it shows the sent text its file stated.

## Added 2026-10-22 -- RUSSIAN DX 2027 RULES AND THE POPOV YOUTH CUP (Q97, Q131-Q136)

Unit-tested and matrix-classified only; the corpus has no log of either
contest, and the matrix's call roster has no WAE-only, UA2, FJL, RI1AN or
/MM station, so nothing has scored one of these end to end.

- [ ] **RDXC, as a DL station:** log IT9xxx (a new multiplier, 3 points),
  4U1VIC (multiplier, 3), RI1ANx (10 points, Antarctica multiplier, exchange
  AN accepted), RI1FJx (10, FJL multiplier, FJ), UA2Fxx (10) and DL1xxx/MM
  (5 points, no multiplier). The CTY country list is now CQ's -- check the
  country display for IT9/TA1/JW/4U1V calls and that MY COUNTRY is right.
- [ ] **RDXC, as a UA3 station:** UA2Fxx and RI1ANx score 2; a call-window
  pre-fill of RI1ANx is AN and of RI1FJx is FJ; DO/HE/LU/ZP are accepted as
  oblasts (also now in the five other contests that share russian.dom).
- [ ] **RADIO-YOC:** MY STATE = the age; the CQ/S&P exchange sends it with the
  serial (check the function-key messages -- the class states none); typing
  `15001` logs age 15 serial 1; a station worked at 07:10 is a new QSO at
  07:40 on the same band (the call window still shows DUPE -- information,
  not a gate) and a dupe at 07:20; 80 m scores 0; a Russian call's
  multiplier is its subject (RFOBL MODE needs a restart after choosing the
  contest, as for SRR-JR). Check the Ermak/Cabrillo QSO line against
  ua9qcq's Ermak example: TR4W prints the SRR-JR layout.

## Added 2026-10-22 -- THE AUTOMATIC X-QSO (Q98 S1) AND CQ WW'S BANDS AND MODES

Unit-pinned (`uTestAutomaticXQSO`, the ratchet in `uTestContestStatesItsRules`)
and seen by the contest matrix (scoring, both exports, import, totals). What no
gate reaches is the live window, the log grids, the summary sheet and the far
end of HamScore. Design 8.2v "S1 as built". Run in a CQ WW SSB log:

- [ ] **A CW QSO in CQ WW SSB** (switch the radio or mode to CW, log a DX
  station on 20 m). EXPECT: it is logged; its row in the log window is
  GREYED as an X-QSO; 0 points; no multiplier is shown as new; the totals
  window does not count it (the per-minute rate still does -- it counts
  contacts); the NEXT QSO's sent serial is
  one higher (it advances). Then work the SAME station on 20 m SSB:
  EXPECT it is NOT called a dupe and DOES count as a new multiplier if
  the country/zone was new.
- [ ] **An off-band QSO** (log a phone QSO on 17 m, 12 m or 6 m). EXPECT the
  same: greyed, 0 points, no multiplier, not a dupe of anything, no "new
  multiplier" hint while on that band.
- [ ] **Edit the band of that QSO to 20 m** (Edit QSO). EXPECT the row turns
  ordinary and the score includes it after the rescore -- nothing was
  stored. Edit QSO's X-QSO checkbox stays UNCHECKED throughout: it is the
  operator's statement only (the read-only "X-QSO by rule" caption is NOT
  built -- 8.2v decision 8).
- [ ] **Export**: the Cabrillo writes `X-QSO:` for those lines and the
  CLAIMED-SCORE leaves them out; the ADIF carries
  `<APP_TR4W_CLAIMEDQSO:1>0` on them only.
- [ ] **Summary sheet** (post-contest): QSO totals and points leave them out.
- [ ] **Reopen the log**: totals, multipliers and the greyed rows are the
  same as before closing.
- [ ] **HamScore**: an X-QSO goes up as an `X-QSO:` line -- does hamscore.com
  leave it out of its counts? (design 8.2v question 7)
- [ ] **FM in CQ WW SSB is an X-QSO** (Q120(a) proposal, unanswered) -- say
  if that is wrong.

## Added 2026-10-19 -- THE NEW CONTEST DIALOG: LAST CONTEST BUTTON AND THE LOG GRID

No window is shown by any test; all of this is compiled and unit-tested only.

- [ ] **Last Contest button** shows the contest's display name and year on its
  second line and the call / file name on the third; hovering shows the full
  path. Check it at 100% and 150% scaling, with a long name (e.g. the
  IN7QPNE composite) -- the year must survive any shortening.
- [ ] **The existing-log list is a grid** (Contest, Year, Call, File), newest
  year first, undescribable files (old `.cfg`, damaged `.db`) last by file
  name. Check: layout at 100%/150%; header and row height and the sideways
  scroll bar on Windows, GTK and Cocoa; the full-path hint; a double-click on
  a HEADER opens nothing, on a row opens that log.
- [ ] **Enter on a log row opens it and does NOT also create a new contest**
  (the OK default button). With no logs listed, Enter still presses OK. Key
  routing differs by widget set -- check Windows, GTK and Cocoa.
- [ ] **Fill time on a real contest directory, cold disk** -- 100 warm logs take
  ~160 ms; antivirus scanning each `.db` may be slower.
- [ ] **The peek never touches a log:** opening the dialog while the same log is
  open in another TR4W leaves that log working, and no `-wal`/`-shm` files
  appear beside a closed log.

## Added 2026-10-19 -- SMALL PUNS AND TERMINATORS (pointer audit P10: 3.3, 3.4, 3.6, 6.14)

Unit-pinned: the CQ / NEW marker test (`uTestDXSpotParse`, `Test_Marker_*`),
the country prefix table's add, replace and growth (`uTestCTYDAT`), and the
two server handshake slices (`uTestUtilsText`). What no gate reaches is the
screen, the keyer and the multi-op handshake.

- [ ] **CQ and NEW markers in the band map** (3.3). With the band map open and
  a radio on a band: tune to a frequency and press the key that drops a CQ
  marker (or call CQ so `CQ/ <number>` is created). EXPECT: a `CQ/ n` row
  appears at that frequency, is NOT sent to the multi-op network
  (`uSpots.AddSpot`), and clicking it tunes the radio but does NOT fill the
  call window (`uBandmap`). A `NEW ` flag row behaves the same on click. A
  normal spot beside it still fills the call window and still sends. The
  Alt-D / VFO-spin call window ignores a CQ marker inside the guard band
  (`DisplayCallsignOnThisFreq`, `TuneDupeCheck`, on the polling thread) and
  shows the real spot next to it.
- [ ] **Multiplier refresh skips markers** (3.3). Change the multiplier mode
  (or log a QSO that makes a spotted station a dupe) with a CQ marker on
  the map: the marker row is untouched, ordinary spots change colour.
- [ ] **WinKeyer opens** (3.4, `cw-keying`). Plug in a WinKeyer, start TR4W
  with it enabled. EXPECT: the main window shows `WK2` / `WK3` and the
  keyer's firmware version exactly as before (the version byte is read
  into `wkREADBuffer[0]` after the buffer's first byte is cleared). A
  WinKeyer that does not answer the host-open must still end with the
  keyer reported closed, not a stale version.
- [ ] **Server password handshake** (3.4, `multi-op-network`; automated only
  for the slicing). With `tr4wserver` running with a password, connect a
  client with the right password: it joins. Connect with a wrong one: it
  is refused ("password" reply) and the server stays up. If a browser or
  a `GET xxPASS...` style client is in use, the 11-byte offset form still
  authenticates.
- [ ] **A command with an argument** (3.6, `uProcessCommand`). Put a command
  with an `=` argument in a CW memory (a ctrl-C ... ctrl-D command such as
  the `EXECUTE` one naming a config file, or one that sends text to the
  cluster) and play it. EXPECT: the argument reaches the command intact.
  The removed line wrote a NUL one byte past the argument; no live consumer
  read it (the one that did is commented out), so nothing should differ.

## Added 2026-10-18 -- UNTYPED BYTE BUFFERS ARE OPEN ARRAYS (pointer audit P12)

`GetCRC32`, `GetCRC16X25`, `SHA256Update`, `NextNetMessage`, the hex dumpers
and the WinKeyer writer take `const aData: array of Byte` now, not an untyped
buffer and a count (`docs/POINTER_AUDIT.md`, P12). Every hash and framing pin
was written first and passed unchanged after; what no test reaches is a real
keyer and a real two-station link. **The wire bytes are meant to be identical
-- anything that behaves differently is a defect, not a new behaviour.**

**WinKeyer** (cw-keying). `wkWriteRaw` takes an open array, the admin
commands are a two-byte type, and the 16-byte LOAD DEFAULTS value list is
built field by field by `wkValueListBytes` instead of being sent as the
record's memory (pinned by `uTestWinKeyWire`). Set `DEBUG LOG LEVEL = TRACE`.

- [ ] **Enable the WinKeyer and let it open.** EXPECT: `tr4w.log` shows
  `[wkSendAdminCommand] B1=$00 B2=$04` (ECHO TEST) and then
  `B1=$00 B2=$02` (HOST OPEN), and the main window names WK2/WK3 and its
  version. No answer to the echo test means an admin command's bytes
  changed.
- [ ] **The settings sent at open take effect before any change is made.**
  Send a message straight away. EXPECT: the TR4W speed, the configured
  sidetone pitch, and the configured paddle mode and swap. A wrong speed
  or pitch at open (and right after a manual change) is a value-list
  field out of order.
- [ ] **Send a message; change speed during it; PTT; Escape to clear.**
  EXPECT: all as before (`wkSendByte`, `wkSendTwoBytes`, `wkTurnPTT` and
  `wkClearBuffer` now pass `[b]` / `[B1, B2]`).
- [ ] **Disable and re-enable the keyer.** EXPECT: `B1=$00 B2=$03` (HOST
  CLOSE), then a clean re-open.

**Multi-op link** (multi-op-network). Two stations and `tr4wserver`. The
server's `SendToClient` turns the record into bytes once and both writes and
traces those; the wire format is unchanged (V1 is not being touched).

- [ ] **Connect two clients and log a QSO on one.** EXPECT: it reaches the
  other; neither `tr4w.log` nor `tr4wserver.log` reports an unrecognised
  id or a desync.
- [ ] **Server at TRACE.** EXPECT `[Net] rx <ip>:` and `[Net] tx <ip>:` lines
  in the same shape as before: two upper-case hex digits and a space per
  byte, at most 64 bytes, then `... (N more)`.

**Single-instance lock** (serial-port-io; no hardware). The mutex name is a
CRC of the install path's UTF-16 bytes, now taken with
`TEncoding.Unicode.GetBytes` instead of read out of the string (pinned by
`uTestCRC32.Test_UnicodeBytesAreTheCodeUnits`).

- [ ] **Start the PREVIOUS release's exe, then this build's, from the SAME
  directory.** EXPECT: the second is refused as a second instance. That
  proves the name did not change between builds, which a test cannot.

---

## Added 2026-10-18 -- AN ADIF IMPORT GIVES QSOs THIS CONTEST'S STATION, AND ASKS WHEN THE FILE NAMES ITS OWN (log schema 3)

NY4I's ruling: *"I start a contest, then import. Therefore you apply the set my
fields as if it were a new QSO. If the import has its own my fields, we should
report that and ask the user if they should override the contest."* A headless
`/IMPORT` keeps the file's values (the round trip pins that); the QUESTION only
appears in the GUI, so nothing automated has seen it.

Set up: an ARRL Digi log with MY GRID `EL88`. Two ADIF files: one with no MY_
tags, and one whose records carry `<MY_GRIDSQUARE:4>JO65`.

- [ ] **Import the file with no MY_ tags.** EXPECT: no question; the final
  report ends "N QSO(s) named no station of ours and were given this
  contest's." Edit QSO on one shows grid `EL88`; the claimed score is the
  one EL88 gives.
- [ ] **Import the JO65 file.** EXPECT: before anything is written, a Yes/No
  naming "MY_GRIDSQUARE", the record count, and a line
  `MY_GRIDSQUARE: N QSO(s), e.g. JO65 (this contest: EL88)`. The wording
  and line breaks must read right; it is new text.
- [ ] **Answer Yes.** EXPECT: Edit QSO shows `JO65`, and the score is the one
  JO65 gives (measured headless: 522 against 231 for ARRL Digi's
  reference).
- [ ] **Answer No (on a fresh log).** EXPECT: Edit QSO shows `EL88`.
- [ ] **A file whose MY_ values match the contest's.** EXPECT: no question,
  only "...the same as this contest's." in the report.

---

## Added 2026-10-18 -- A STATE QSO PARTY: A NEW COUNTY FROM THE SAME PLAIN CALL IS A NEW QSO (Q118, `91d6bc34`)

NY4I's ruling: in a state QSO party a logged QSO whose received county differs
is NOT a dupe, live and on rescore (`QSOIsADupe`, `AddQSOToDupeSheets`). The
call window, deliberately, still checks the CALL alone -- *"If we consider it a
dupe until that second contact with a new county comes in, that is a
reasonable compromise."* `uTestNYQPRover` pins the rule; nothing automated
types into the entry window or watches the call window say DUPE.

Set up: a New York QSO Party log, MY STATE out of state (e.g. `FL`), CW on
20 m. A station that does NOT sign `/county`.

- [ ] **Log plain `W2TZ` sending `KIN`.** It logs and scores.
- [ ] **Type `W2TZ` again, same band and mode.** EXPECT: the call window shows
  DUPE -- that is the ruling, not a defect.
- [ ] **Enter `STE` as the exchange and log it.** EXPECT: it is accepted, is
  not marked a dupe, and scores (2 points on CW).
- [ ] **`W2TZ` with `KIN` again.** EXPECT: a dupe, scoring 0.
- [ ] **Rescore** (Tools > Rescore). EXPECT: the same marks -- KIN and STE
  counted once each, the second KIN a dupe -- and the same score.
- [ ] On 40 m, `W2TZ` is not a dupe in the call window at all.

## Added 2026-10-18 -- AN FM QSO NO LONGER CORRUPTS ITS CALL ON RESCORE (pointer audit P8 part A, `433c047f`)

The sorted list, the multiplier object and the callsign list are classes now.
The defect found on the way: the RESCORE passed a QSO's stored mode, which can
be FM, and the dupe bits were indexed past their array into the entry's
callsign (K1AR on 20 m FM became garbage). One rule now, `DupeSlot`: FM counts
as Phone. The unit tests pin it; the commit itself asks for a real-contest
check.

Set up: a log that holds FM QSOs -- a VHF contest (e.g. ARRL VHF) with a few
FM contacts among SSB and CW ones. Note the score and the multiplier counts
before you start.

- [ ] **Rescore** (Tools > Rescore).
- [ ] **Open the dupe sheet (Alt-D)** on the band and mode the FM QSOs were
  made on, and on phone. EXPECT: every call reads exactly as logged -- no
  garbled or truncated callsigns -- and the FM QSOs are listed as PHONE.
- [ ] **Open the remaining-multiplier windows.** EXPECT: the multipliers
  worked and needed are what they were before the rescore.
- [ ] EXPECT: the score and multiplier counts are unchanged, and working an
  FM-logged station again on phone, same band, is a dupe.
- [ ] Exit TR4W: nothing in `tr4w.log` at Error level from the rescore.

## Added 2026-10-17 -- THE CPU KEYER'S ELEMENT RING IS A FIELD (pointer audit P6, defect D4)

`uTestCPUKeyerRing` pins every element the DTR/RTS keyer's text-to-element
translation writes, and it passed unchanged across the change -- so what
reaches the ring is the same. What the tests cannot see is the CW THREAD
keying it: `SendCWBufferStart` now reads `CPUKeyer.CWBuffer[...]` instead of
`CWBuffer^[...]`, including the Farnsworth arm that rewrites an element's
length in place, and the thread and Esc (`FlushCWBuffer`) step the ring
through `NextRingSlot` / `PreviousRingSlot` -- with one deliberate change,
the Esc wrap fix in the long-run item below. Set up: CW through the **CPU keyer** -- keyer port on a
serial adapter with DTR (or RTS) = CW, no WinKeyer, CW-by-CAT off, a radio
or a sidetone monitor you can hear. **A YCCC box's autosend characters go
this way too**, so the same checks cover it.

- [ ] **A message keys exactly as before.** F1 (CQ) and the exchange memory:
  every character correct by ear, letter spacing and word spacing
  unchanged, PTT drops at the end. Include a memory with `^` (half space)
  and one with a speed change (Ctrl-F / Ctrl-S inside the memory) if you
  use them.
- [ ] **Autosend, starting from a FRESH start of TR4W.** Before keying
  anything else, put the call window in autosend and type a call: it
  keys as you type. (The D4 crash needed the very first character into
  the keyer to be a space, `^`, a control character or an unmapped one,
  which the UI does not readily produce -- the unit test reached it and
  reproduced the access violation; this checks the ordinary path.)
- [ ] **Farnsworth** (if you use it: FARNSWORTH ENABLE with a code speed
  below FARNSWORTH SPEED): the character and word gaps stretch as before.
- [ ] **Backspace while autosending** retracts the last unsent character, as
  before -- and only that: it never brings back CW that was already sent
  or flushed. **FIXED in this packet (NY4I, 2026-10-17):** when the ring
  stood at slot 0, the retraction walk used to go round the whole OLD
  ring and could resume keying stale CW. Rare for the same reason as
  the Esc item below, so a clean run does not prove it -- the unit test
  does -- but stale CW after a Backspace is now a defect: note the time
  and send `tr4w.log`. **Esc** stops sending mid-message.
- [ ] **A long run, with Esc.** Send forty or more CQs/exchanges in one
  session -- the ring holds 2,047 elements and wraps, so this crosses the
  wrap several times -- and press **Esc mid-message on a good number of
  them**. Every message keys clean, and **every Esc stops sending
  cleanly**: at most the element in progress finishes, then silence and
  PTT off. **FIXED in this packet (NY4I, 2026-10-17):** `FlushCWBuffer`
  used to wrap to `CWBufferSize`, not `CWBufferSize - 1`, so an Esc at
  the moment the ring stood at slot 0 replayed up to 2,046 OLD elements
  instead of stopping. That moment is rare (once per 2,047 elements), so
  a clean run does not prove the fix -- the unit tests do -- but **a
  burst of old CW after an Esc is now a defect**: note the time and send
  `tr4w.log`.
- [ ] Exit TR4W: no `worker thread` exception line in `tr4w.log`.

## Added 2026-10-17 -- THE SPOT STORE IS A CLASS OVER A GENERIC LIST (pointer audit P8, part B)

`uTestSpotStore` pins the store itself (add, same-frequency replace, order,
find, delete, clear, 600-spot growth, ageing and the minutes-versus-seconds
decay, dupe and repaint bookkeeping). It cannot reach the band map window, the
cluster, or the radio polling thread, which now takes the store's lock.

- [ ] **Spots arrive, age and leave.** Connect to a cluster (Telnet window)
  with the band map open. EXPECT: spots appear, in frequency order, within
  a repaint tick of arriving; with `BAND MAP DECAY TIME` set to 2 they fall
  off one at a time about two minutes after THEY arrived, not all in one
  tick. The band map's delete removes the right row; its clear empties
  the map and new spots still arrive afterwards.
- [ ] **Click-to-tune.** Click a spot: the radio tunes to that spot's
  frequency and the call window fills (search-and-pounce). Spin the VFO
  across a spot's frequency with the band map open: the call window shows
  that spot's call inside the guard band and clears outside it. With
  the Tune Alt-D option on and a second radio, tuning the INACTIVE radio onto a
  spot fills the Alt-D call. These last two run on the radio polling
  thread and are the paths that gained the lock -- watch for a stall or an
  exception in `tr4w.log` while spots are arriving and being deleted.
- [ ] **Persistence.** Close and reopen TR4W with spots on the map: they come
  back (SaveBandMap / LoadBandMap), still ordered, with their ages kept.

---

## Added 2026-10-17 -- BATCH C RULINGS (Q9, Q32, Q37, Q73, Q81)

The unit tests reach each rule (`uTestOperatorCQMemory`, `uTestContestTotals.
Test_MissouriPeakHourBonus`, `uTestMalformedGrid`, `uTestRoverDupeKey`,
`uTestContestIN7QPNE` / `uTestContestExport` for the New England files) and the
contest matrix reaches the scoring; nothing reaches a live entry window or the
running program's contest re-selection, and the corpus is blind to points.

- [ ] **An edited CQ memory survives re-selecting the contest (Q9).** Open a
  CQ WPX (or any serial-number) log; Alt-P, edit CQ F3 to something of
  your own; then re-select the SAME contest the way an operator does
  (a peer's CONTEST line, or the CONTEST setting applied again). EXPECT:
  CQ F3 keeps your text, while the other memories set-up writes are
  written as before. Then open a log of a DIFFERENT contest: its own CQ F3
  default appears (your edit is not carried over). **Known, separate:** an
  edited memory is still lost when TR4W restarts -- the log's `message`
  table is written at close and never read back (reported with Q9).
- [ ] **Missouri's peak-hour bonus survives reopening (Q32).** In a Missouri
  log, log a few 40 or 80 m QSOs with a logged time between 1400 and 1959
  UTC (edit the time if it is not contest day), note the score, close and
  reopen the log: the score is the SAME (it used to drop by the tally).
  `/EXPORT`'s `CLAIMED-SCORE` matches the window.
- [ ] **A malformed grid has no distance (Q37).** In WWL or the Stew Perry, a
  logged QSO whose grid is not a grid (import one, or edit one to `FN3`)
  scores the no-distance points (1 in both) every time it is rescored, and
  the beam-heading display shows nothing for it. A real grid still shows
  its heading and distance.
- [ ] **A county rover is its own station (Q73).** In the Florida QSO Party,
  work `NY4I/PIN`, then type `NY4I/HIL`: the call window does NOT say
  dupe, and it logs. Type `NY4I/PIN` again on the same band and mode: it
  IS a dupe. The same with `K1AR/NHHIL` then `K1AR/NHMER` in New England.
- [ ] **New England's county spellings (Q81).** Out of New England, the
  New England QSO Party accepts `MEAND`, `CTCAP` and the old `ANDME`; of
  the eight old Connecticut counties only the three in7qpne_cty.dom maps
  onto a planning region are still typed (`HARCT` and `TOLCT` give
  Capital, `NHVCT` Naugatuck) and `FAICT`, `LITCT`, `MIDCT`, `NLNCT`,
  `WINCT` are refused; the remaining-multiplier window lists 68 counties
  under the state-first names. Inside New England (MY STATE `ME`),
  `MEAND` counts Maine.

---

## Added 2026-10-17 -- BATCH B SCORING RULINGS (Q38, Q45, Q49, Q71, Q84, Q85, Q104)

The unit tests reach every rule (`uTestContestRulings2026Oct`) and the contest
matrix reaches the scoring; NOTHING reaches the New Contest dialog's window or a
live entry window, and the corpus is blind to points.

- [ ] **IN7QPNE is refused at New Contest for an in-area station (Q104).** Pick
  IN7QPNE and type each of `IN`, `UT`, `ME`, `DE` (and one county, e.g.
  `INADA`) into MY STATE. EXPECT: OK stays DISABLED and the comment under the
  rows reads *"IN7QPNE is for stations outside Indiana, the 7th call area,
  New England and Delaware. From UT, choose the 7th Call Area QSO Party
  instead."* -- the 7QP for every 7th-area state, Indiana / New England /
  Delaware QSO Party for the others. Then type `KS`: the prompt text comes
  BACK in the comment and OK enables. Check the message fits the comment
  area without clipping (it is longer than the prompt).
- [ ] **The UA4W Championship's prompt (Q71).** Pick it: the comment is the
  translated `TC_ENTERYOURRDAIDORGRID` ("Enter your RDA ID (for UA1A
  stations) or four digit grid square:" in English); in Russian it should be
  the existing Russian text.
- [ ] **A 160 m contest scores nothing off 160 m (Q71).** In RSGB 1.8 MHz, ARRL
  160 or CQ 160, log one QSO on 80 m: it is logged, scores 0, earns no
  multiplier and is not a dupe on 160 m; the need-multiplier hint on 80 m
  says nothing is needed.
- [ ] **Winter Field Day shows no DXCC multipliers (Q38).** The remaining-DX
  window and the multiplier totals show none; the score is unchanged.
- [ ] **EUDX from outside the EU (Q45).** A W station working a European who
  sends a ZONE scores 5 (3 on our continent, 2 for our own country), not
  10; one who sends a region scores 10.

---

## Added 2026-10-27 -- NETWORK PROTOCOL 2: HELLO, AND EVERY CONTEST TRAVELS

Replaces the Q108 S4 items (a contest with no legacy number was REFUSED on
multi-op; it is not any more). Nothing automated drives a real client against a
real server: the unit tests reach the HELLO, the judgement and the receive arms,
and `tools/netprobe --case hello` speaks the protocol to `tr4wserver` and to
TR4WServerPy, but no gate has seen a TR4W station do it. **WHAT YOU NEED:** two
machines (Windows and Mint), one running `tr4wserver` or the Python server, both
stations on a contest registered BY ID (any QSO party, e.g. `GA-QSO-PARTY`) and
then on a legacy one.

- [ ] **Connect, both stations, a by-id contest.** Select the same QSO party on
  both, choose Net > Connect on each (the link no longer needs the Network
  window; see the section above). EXPECT: connected; each station's
  row on the other; `tr4w.log` has `[Net] server hello: network protocol 2`
  and `[Net] station B announced contest "GA-QSO-PARTY"` (the other letter on
  the other station). NO dialog.
- [ ] **A QSO crosses and is logged.** Log one at A. EXPECT at B: it appears in
  B's log, scores, and the dupe sheet knows it -- ON A BY-ID CONTEST. Edit it
  at A and Alt-Y delete another: both arrive. (`tr4w.log` at B: no
  `REFUSED`.) The same on a legacy contest.
- [ ] **The two builds do not agree on the handle byte, and it does not matter.**
  If the two stations' by-id handles differ (compare `handle` in a debug
  build, or just link a different set of contests on one), the QSO still
  arrives and carries B's own contest.
- [ ] **A contest change is announced.** With both connected on contest X, change
  A to contest Y (Preferences, or New Contest). EXPECT at A: `[Net] sent
  hello` with Y; at B: `station A announced contest "Y"`. Log a QSO at A:
  B refuses it (below). Change B to Y: the next QSO arrives.
- [ ] **A peer on another contest is refused and reported, once** (this is Q110,
  now by announcement). EXPECT at B: the QSO is NOT logged; one panel notice
  "Station A is on Y, this station is on X -- ..."; one `REFUSED` Error line
  per QSO; no second notice for the same station and contest until the link
  is re-established.
- [ ] **A server from before protocol 2.** Point the station at an old
  `tr4wserver.exe` (any build before this change) or the Python server at
  tag `d7-protocol`. EXPECT: the connection closes at once, and ONE dialog
  "The multi-op server closed the connection without answering. It is
  probably older than this TR4W ..." -- not repeated every five seconds.
  Net > Connect (or Reconnect) tries again; it is not retried by itself.
- [ ] **A station from before protocol 2** (or the probe's `--case hello`)
  against the NEW server: refused, the server log says `first message was not
  HELLO ... a 4.x client?`.
- [ ] **A mismatched protocol number** (hand edit, or run `netprobe` against a
  patched server): the dialog says which end is behind and what to update.
- [ ] **Duplicate computer id**, as before: the second station gets the
  "Computer ID is already in use" dialog; the first is undisturbed. Then
  stop the first and reconnect the second: accepted.
- [ ] **A station that leaves is forgotten.** Net > Disconnect at B; at A the
  row clears (this was broken against the Python server), and a QSO
  forged under B's id is refused ("has not announced a contest").
- [ ] **`<contestnr>` on the wire.** With a UDP listener (N1MM-format) on the
  contact stream and a by-id contest selected, log a QSO: the datagram
  carries a `<contestnr>` that is NOT a byte value (the id's derived number);
  a legacy contest still carries its legacy number (the `ContestType`
  ordinal -- compare with a capture from before this change).

---

## Added 2026-10-18 -- Q110: PEERS ON DIFFERENT CONTESTS

Two machines, one `tr4wserver`, two contests (e.g. ARRL DX CW and CQ WW CW). Since
2026-10-27 the judgement is by what the SENDER announced in its HELLO, not by the
record's contest byte (the first item above covers it for by-id contests too).
Unit tests feed the real receive arms but cannot log a QSO or show a panel.

- [ ] **A QSO from a peer on another contest is refused and reported.** Station
  A on contest X, station B on contest Y, both connected; log a QSO at B.
  EXPECT at A: the QSO is NOT in A's log or totals; the quick-command panel
  shows "Station B is on Y, this station is on X -- its QSOs are NOT being
  logged here. ..." ; `tr4w.log` has one `[Net] NET_QSOINFO from station B
  REFUSED` Error line naming both contests and the call. Log three more at
  B: three more log lines, NO second panel notice. Edit one at B: a
  `NET_EDITEDQSO ... REFUSED` line, still no second notice.
- [ ] **Same contest on both is unchanged**, and a reconnect re-arms the notice.

## Added 2026-10-16 -- 5.0.28 AND AFTER: WHAT THE GATES CANNOT SEE

Every item below passed every automated oracle; each is "same as before",
not "right". Check on a real run:

- [ ] **DX vs domestic in a domestic contest** (pointer audit P5): the domestic
  country list is a class now (`TDomesticCountryList`). Log a few in-country
  and DX contacts in a contest that uses it (e.g. a state QSO party from out
  of state, ARRL DX from W) and confirm each is DX or domestic as before.
- [ ] **County files** (`TDomQTHTable`, the logdom rewrite): a QSO party's county
  abbreviations still resolve, including an INCLUDE FILE (New York in-state:
  a Canadian province counts).
- [ ] **Nebraska QSO Party** (new): out of state, only NE counties score; in
  state, counties + states + provinces + countries, NE itself not a state;
  KA0BOJ bonus 100.
- [ ] **Out-of-area QSOs score 0** (Q107): as an out-of-state entrant, import an
  ADIF holding a contact with another out-of-state station; it should log
  but score 0 -- and Rescore from the menu keeps it 0.
- [ ] **Polish UI** shows "Polski", the About box credits SP2EWQ, M0GIM and
  G0DVJ; a machine-translated language credits LibreTranslate.
- [ ] **N1MM listener** receives `<mycall>` again (UDP contact broadcast).
- [ ] **The installer** (`dom\*.dom` wildcard): an installed copy has all 124
  files in `dom\`, including `prov12.dom`.
- [ ] **Every worker thread has a new signature** (pointer audit P1, defect D2).
  `tCreateThread` is typed now, and eleven thread bodies changed from
  parameterless procedures to `function(aParameter: Pointer): DWORD;
  stdcall`. Before, each of them, ON EXIT, wrote nil into its own SEH chain
  head and restored three registers from the wrong stack slots -- so a
  crash or hang AT THE END of one of these is what to watch for, not at the
  start. For each: use the feature, let the thread finish (or exit TR4W),
  and check `tr4w.log` holds no `worker thread ... ` exception line:
  - **The dupe / new-multiplier beep** (`tDoABeep`).
  - **The paddle/foot-switch thread** (`tPaddleFootSwitchThreadProc`).
    Its LPT reads are gone (2026-09-13), so all it has to do is start and
    exit cleanly.
  - **DVP voice playback** -- play a `.wav` memory to its end, and stop one
    mid-message (`tDVPPlayThreadproc`).
  - **WinKeyer** -- open at startup with WINKEYER ENABLE on, key a message,
    exit (`wkOpenThreadProc`, the new entry for `wkOpen`, and
    `wkReadThreadProc`).
  - **Any CAT radio** -- polling starts, frequency and mode follow, and
    Reset Radio Ports rebuilds it (`BeginPolling`, which now receives its
    RadioObject as the thread parameter).
  - **Multi-op** -- connect to `tr4wserver`, including a retry while the
    server is down (`ConnectThread`), and **Synchronize** the server log,
    both from the Network window and with SERVER AUTO SYNCHRONIZE LOG ON
    CONNECT (`RunSyncThread`).
  - **Post / Get Scores** upload (`CreateConnectionAndSendReportToGetScores`).
  - **The NTP check at startup** (`NTPStartupCheck`).
- [ ] **The CW-memory command table** (pointer audit P1): its handler column is a
  typed procedure now and every row names its routine bare. No row changed
  its target, and the compiler checked all 81; still, run two or three
  memory commands (e.g. `SWAPRADIOS`, `BANDUP`, `CQMODE` in a function-key
  message) and confirm each does what it did.
- [ ] **MMTTY RTTY text** (pointer audit P2, defect D3): with MMTTY running,
  received characters appear in the RTTY window in Lucida Console, in
  colour, and the callsign grab still works. Three `SendMessage` addresses
  are `LPARAM` instead of `integer` -- identical on i386; on x86_64 the
  `integer` form handed RichEdit half an address (the 64-bit image is based
  at `$100000000`).

---

## Added 2026-10-15 -- THE MINIMUM OFF TIME IS THE CONTEST'S (Q60)

NY4I's answer: a break is 60 minutes in CQ WW and 30 in every other contest,
IARU HF included. `TContestBase.MinimumOffTimeMinutes` states it and
`PostUnit.CalculateTotals` reads it; the summary sheet no longer reads it from
the contest NAME. The values and the gap rule are unit-pinned
(`uTestContestUI`); the summary sheet is in no oracle.

**The main window's on-screen times are NOT affected.** Its 60-for-IARU copy
wrote a variable nothing read (the reader was inside a comment in D7 too), and
is deleted. The on-air counter is wall time since the first entry, with no
break rule at all -- so there is nothing to see change there.

- [ ] **IARU HF**: log two QSOs 45 minutes apart (edit the second QSO's time)
  and write the summary sheet. `OPERATING TIME` does NOT include the 45
  minutes. Before this change it did not either, unless a stated `CONTEST
  NAME` held `CQ-WW`.
- [ ] **CQ WW CW**: the same two QSOs -- `OPERATING TIME` DOES include the
  45 minutes. The CT1BOH window's per-band times agree with it.
- [ ] **CQ WW CW with `CONTEST NAME = MY TEST`** in the `.cfg`: still 60
  minutes (before this change, 30).

## Added 2026-10-14 -- THE EXCHANGE RULES ASK THE CONTEST (M11 S7)

Five rules the engine decided by testing the session's exchange shape are now
each contest's own answer. The answers are unit-pinned for every contest at
six stations, but the sites that USE them are entry-window paths no gate runs.
Nothing should look different:

- [ ] **Rover call, Michigan QSO Party** (out of state): type `KG1S/MON` and
  Enter with the exchange empty. The county `MON` is copied into the exchange
  and the QSO logs as a USA contact (not country G).
- [ ] **Rover call, ARRL DX CW from a non-W/VE call** (e.g. `MY CALL` DL1xx):
  the same `/county` strip happens; from a W or VE call it does NOT (the
  exchange there is power).
- [ ] **Two QTHs in one S&P entry** (Michigan, out of state): `MON WAY` logs
  exactly as it did before this change (`ReturnInSAPOpMode`'s re-entry).
- [ ] **A blank exchange** logs in BWQP, General QSO and POTA, and is refused
  (nothing logged) in, say, CQ WW CW.
- [ ] **POTA**: typing a park reference in the exchange shows its name.
- [ ] **CQ WW RTTY** with `MY STATE` set: the F3 exchange memory is
  `599 <zone> <state>`; CQ WW CW's has no state.

## Added 2026-10-14 -- THE ADIF IMPORT IS ALL OR NOTHING, AND SAYS SO

NY4I's ruling: an ADIF import is one transaction -- one record that will not
go in, and none does -- "with ample notification". `File > Import ADIF`
(`MainUnit.ImportFromADIF`) now reads the whole file, then writes it in one
transaction (`uLogStore.LogStoreAppendQSOs`). Headless `/IMPORT` is proven
(exit 2 on failure, the `qso` rows unchanged, the report in
`tr4w-early.log`); what the OPERATOR sees is not. Make a bad file by adding a
line holding only `<EOR>` after a few records of any ADIF -- a record with no
CALL, which the log refuses (`callsign` is NOT NULL).

- [ ] **Import the bad file into a log that already has QSOs.** A warning
  dialog says NOTHING was imported, names the record (`record N of M (no CALL,
  no QSO_DATE)`), the reason (`NOT NULL constraint failed: qso.callsign`) and
  that the contest log is unchanged; the quick-command line reads `ADIF import
  FAILED -- nothing was imported` behind it. The log window, totals and score
  are exactly what they were. Is it unmissable, and is it clear?
- [ ] **Then log a QSO by hand.** It logs: a rolled-back import no longer stops
  the log (only a rollback that itself fails does -- see
  `docs/SQLITE_LOG_SCHEMA_PLAN.md` 9c). There is no second dialog saying THE
  CONTEST LOG IS NOT BEING SAVED.
- [ ] **Import a good file.** The quick-command line shows `N Qs imported.` as
  before, the log window fills once, and on a large file (a few thousand
  records) the wait is noticeably shorter than before -- the progress count
  every 100 records is GONE, because nothing is in the log until the end.
- [ ] **Import a file with a stray non-record line after the header** (any text
  with no `<EOR>`). It imports, and a warning names how many lines were
  skipped. Those lines were always dropped; now the operator is told.

---

## Added 2026-10-14 -- WSJT-X MESSAGES ARE EVALUATED ON THE MAIN THREAD

`uWSJTX` ran the dupe and new-multiplier test for a CQ decode on Indy's UDP
listener thread, racing the main thread's sheet and `ActiveContest`. The
evaluation and the `HighlightCall` reply now run on the main thread, queued by
the listener. The unit tests pin the hand-off; only a live WSJT-X proves the
colours still land. The server's destructor also runs now (it had been hidden
from `Free` for as long as the unit existed), so the shutdown path is new.

- [ ] **Run WSJT-X FT8 against TR4W in a digital contest with a few logged QSOs.**
  A CQ decode from a station already worked on that band is coloured as a dupe
  in the WSJT-X decode list; a new multiplier (call or grid) is coloured as a
  mult; an ordinary station is not coloured.
- [ ] **Log a QSO from WSJT-X while decodes are arriving** and confirm the next
  decode of that station turns dupe-red. (The sheet is read after the QSO is
  logged because both are now on the main thread's queue order.)
- [ ] **Turn WSJT-X off and on in Preferences, then exit TR4W** with WSJT-X
  still sending. No crash, nothing in `tr4w.log` from `[uWSJTX]` at Error level.
- [ ] **Look for `called off the main thread` from `[uWSJTX]` in `tr4w.log`.**
  It should never appear.

The STATUS, CLEAR and LOGGED-ADIF messages followed (same day), so a QSO WSJT-X
logs is now parsed, checked and LOGGED on the main thread, in arrival order with
everything else WSJT-X sent. The unit tests pin the marshalling for all four
kinds and cannot log a QSO (no booted contest):

- [ ] **Log a QSO in WSJT-X (FT8, a contest that accepts it).** TR4W logs it
  EXACTLY ONCE, with the right call, band, mode, and exchange (grid or state as
  the contest wants), and the log window, score and rate update.
- [ ] **Work two stations back to back while decodes are scrolling.** Each QSO
  is logged once and in order; the call window does not show the previous
  station's call or lose the next one (the clear after QSO 1 must land BEFORE
  QSO 2's call is placed).
- [ ] **While WSJT-X is calling a station,** that call appears in the call
  window and its grid in the station display; stepping the dial with no radio
  defined still follows the band.
- [ ] **Log a QSO from WSJT-X and, at the same moment, type one yourself.** Both
  are logged, neither is lost or doubled.
- [ ] **Disable WSJT-X in Preferences right after WSJT-X logs a QSO, and the QSO
  must be in the log.** Stop logs any QSO still queued, in order, before it lets
  go. Do the same by quitting TR4W immediately after a WSJT-X QSO (the exit path
  stops the server before the log store closes). A line in `tr4w.log` reading
  `LOST QSO` is a failure of this fix: report it with the ADIF text it carries.

NOT CHANGED, AND RECORDED: the WSJT-X TCP command handler
(`IdTCPServer1Execute`) still runs on Indy's TCP thread. It reads the radio
status record unsynchronised and writes `Settings.Ptt.ViaCommands`. It is
request/response against a roughly one-second WSJT-X deadline, and CmdTX / CmdRX
are PTT, so queuing it to the main thread is the wrong fix; the assessment is in
a comment above the procedure. It belongs with the radio-status snapshot work.

## Added 2026-10-14 -- COUNTY-LINE IMPORT ASKS THE CLASS (M10 S7)

`MainUnit`'s ADIF import clears the dupe flag on a repeat of (call, band, mode)
with a different QTH when the contest's CLASS allows a county line. That
changed for six parties, and `ceClearDupeSheet` is set inside the import
routine, which no unit test reaches:

- [ ] **Import a real Michigan QSO Party ADIF holding a repeat** (same call,
  band and mode, a DIFFERENT county). Since Q118 (`4c5c0a6b`, kept in
  `91d6bc34`) a state-party QSO whose received county differs is NOT a dupe --
  live and on the post-import rescore -- so the repeat is NOT flagged. A
  repeat from the SAME county IS flagged.
- [ ] **Import a county-line ADIF for one of Arizona, BC, Virginia, the Salmon
  Run or New York** (same call/band/mode, two counties). The second contact is
  now NOT flagged as a dupe; it used to be.

## Added 2026-10-14 -- SEVEN CONTEST SETTINGS RETIRED (M10 S2, NY4I's Q4)

`QSO POINT METHOD`, `EXCHANGE RECEIVED`, `INITIAL EXCHANGE`, `DOMESTIC
MULTIPLIER`, `DX MULTIPLIER`, `PREFIX MULTIPLIER` and `ZONE MULTIPLIER` are
names in `uCFG.RETIRED_COMMANDS` now: accepted, reported once per name per
session, no effect. They are gone from Preferences. Unit tests pin the read,
the capture and the no-modal path; the corpus never captures, so **an
interactive open and close of an old log is what no gate runs**:

- [ ] **Open a contest log written before 2026-10-01** (any corpus `log.db`
  copied somewhere writable will do). `tr4w.log` carries ONE line
  `[LogStore] 7 stored contest setting(s) are retired commands -- ...`
  naming each with its value, and **no** "invalid statement" dialog. Close
  it cleanly, reopen it: that line is gone, because the close deleted the
  seven rows.
- [ ] **A contest `.cfg` that still says `QSO POINT METHOD = ...`** (or any of
  the seven) loads with no dialog and one
  `[Config] QSO POINT METHOD = ... is a withdrawn command` line, once, however
  many times the file is read in the session. The contest scores by its class.
- [ ] **Preferences, Contest page:** the seven rows are gone, and nothing else
  on the page moved or lost its caption.

## Added 2026-10-14 -- IN7QPNE JUDGES EACH QSO BY ITS PARTY (design 7.14, 8.2r)

IN7QPNE is no longer one merged rule: `uContestIN7QPNE` hands each QSO to the
Indiana, 7QP, NEQP or Delaware class, by the worked station's county. Unit
tests pin the routing and each party's points; **no real IN7QPNE session has
been logged with it**, and the contest matrix record changes by design. To
exercise, log a short session from an IN7QPNE `.cfg`:

- [ ] **Outside all four areas** (`MY STATE` e.g. KS): an Indiana county scores
  2 on any mode; a 7QP county 3 CW / 2 phone; a New England county 2 CW /
  1 phone; a Delaware county 20 CW / 10 phone, and **0 on 30, 17 or 12 m**.
  A station sending a state or DX is refused with "Out of state: work IN,
  7th area, NE or DE stations only" (only if the exchange lets you type one).
- [ ] **Inside one** (`MY STATE` a county, e.g. `INADA` or `KDE`): a station in
  another party scores by THAT party's rules (a DE entrant working an
  Arizona county: 7QP's 3 on CW); a state, province or DX station scores by
  your own party's (a DE entrant: 2 CW, 1 phone).
- [ ] **Multipliers**: a Delaware county worked on 30 m earns none; an Indiana
  entrant's DX contact -- see Q84.
- [ ] **The score shown** is points x multipliers over the whole log: no
  sponsor's score (Q77). Check it is not mistaken for one party's.
- [ ] **Cabrillo**: `CONTEST: IN7QPNE-QSO-PARTY`, one file for all four sponsors.
- [ ] **No score posting**: Post Scores is greyed; with `HAMSCORE ENABLE` on, the
  HamScore window's status reads "Score posting is not permitted for this
  contest" and nothing is sent. (WRTC now behaves the same -- Q83.)

---

## Added 2026-10-14 -- THE DELAWARE QSO PARTY IS A NEW CONTEST

`DELAWAREQSOPARTY` is a new contest type with its own class
(`uContestDelawareQP`, design 8.2q). Unit tests pin the class; **nothing
automated types a Delaware exchange or loads its `.dom` files**, and the
contest matrix shows it unfrozen. To exercise, create it from the New Contest
dialog (the template `.cfg` was deleted 2026-10-15):

- [ ] **In-state** (`MY STATE` a county: NDE, KDE or SDE): states, provinces and
  DX countries are multipliers **per band**; working another DE county counts
  the ONE multiplier "Delaware". Points CW 2, digital 2, phone 1.
- [ ] **Out-of-state** (`MY STATE` e.g. PA): NDE, KDE and SDE are the only
  multipliers, per band; a non-DE station is refused with "Out of state: work
  DE stations only". Points CW 20, digital 20, phone 10.
- [ ] **Bands**: a QSO on 30, 17 or 12 m is logged and scores 0; 6 m and 2 m score.
- [ ] **Score**: CATEGORY-POWER LOW doubles, QRP triples, and 50 is added.
- [ ] **Cabrillo**: `CONTEST: DE-QSO-PARTY`, an FT8 QSO's mode is `RY`, and the
  file is refused until the summary window has a LOCATION.

---

## Added 2026-10-13 -- A STATION FACT CHOSEN AT NEW CONTEST IS THAT CONTEST'S ONLY (design 7.12)

What the New Contest dialog asks for, such as MY ZONE, MY STATE, MY SECTION
and MY FD CLASS, is now **this contest's override**. It is stored in the
log. It is **never** written into the station's settings. Before this
change, the next settings save carried it into `settings\tr4w.json`. A save
happens on any Preferences edit or on the insert-mode toggle. Unit tests pin
the rule; only a run shows the dialog and the windows agree.

Before you start, note the station's **MY ZONE** and **MY STATE** in
Preferences > Station (zone 5 and FL here).

- [ ] **New Contest > European HFC.** Its row is labelled `MY ZONE`, because
  that contest sends the year licensed in the zone's place. Enter `3`.
  OK. The CQ message (F1/F3) sends `599 3`.
- [ ] **During that contest, Preferences > Station > MY ZONE still shows the
  station's zone (5).** Change something harmless on another page and
  save, or toggle INSERT. Close TR4W. Open `settings\tr4w.json`:
  `"Zone"` is still `"5"`.
- [ ] **Log one QSO, close, and reopen the European HFC log.** Export
  Cabrillo. The sent column carries `3`, because the log carries the
  override. Also look at what F1/F3 send after the reopen. The contest
  is set up before the log's rows are applied (Q68), so a message built
  at set-up may show the station's 5. Note which one you see.
- [ ] **New Contest > CQ WW (any mode).** Its exchange sends the
  **station's** zone (5), not 3. That is NY4I's case: zone 3 was
  for that one contest.
- [ ] **New Contest > CQ WW RTTY.** Its row is MY STATE; enter `UT`. The CQ
  exchange is `599 5 UT`, the same text it always built. In Preferences,
  MY STATE is still `FL`.
- [ ] **During the European HFC contest, change MY ZONE in Preferences to
  4.** The contest still sends `599 3`, because its override wins for
  that contest. Preferences does not say so; that is Q66. A later new CQ
  WW contest sends 4.

---

## Added 2026-10-13 -- POTA IS A CONTEST CLASS. LOG AN ACTIVATION.

NY4I ruled design Q6; `TContestPOTA` now owns everything POTA did through
shared code (`CONTEST_OWNERSHIP_DESIGN.md` §8.2o). **Nothing below should look
different** except the one line marked. The contest matrix proved set-up,
scoring and export unchanged -- but its QSOs carry **no park**, so the park,
n-fer and state/grid branches are proven only by `uTestContestPOTA`, which
cannot press a key. One live activation covers all of it.

- [ ] **New Contest**: the drop-down line now reads *"Parks on the Air(r)
  Logging"* -- **a deliberate change** (it said *"POTA"*; design Q64). Choose
  it: the box reads *"Activator"*; tick it -- the MY PARK row with the
  comment *"Enter your POTA Park Reference Designator (WITH DASH e.g.
  K-1234)"*; enter `US-0663`, OK. The log opens as POTA.
- [ ] **Set-up**: CW F1 is `CQ^POTA \ \ `, F2 `CQ^POTA CQ^POTA \ \ FD`, the
  QSL message `73 \ EE`; WARC bands step; working the same call twice is
  allowed (no dupe warning). The **Download POTA Parks** and **Repeat POTA
  Parks (2nd Op)** menu rows are **visible**; open any other contest and
  both are **hidden**.
- [ ] **Park entry**: type a call and `57 US-1234`; the park's NAME shows as
  you type (with the park list loaded) and the QSO logs with QTH
  `US-1234`. Abbreviations still normalise -- `1274` becomes `US-1274`
  from MY PARK.
- [ ] **The n-fer**: `57 US-1234 US-5678 US-9012` logs **three** rows, one per
  park, as one contact (one QSO set, like a county line). Then **Repeat
  POTA Parks (2nd Op)** pre-fills the three parks for a new call.
- [ ] **A hunter not in a park**: `57 PA` logs with the state; `57 FN31` with
  the grid; a bare call with an empty exchange still logs.
- [ ] **ADIF export** (File > Export ADIF), **with the POTA park list
  loaded** (Download POTA Parks): every record has `<MY_SIG:4>POTA`,
  `MY_SIG_INFO` and `MY_POTA_REF` = MY PARK, `MY_DXCC` (and `MY_STATE`
  for a single-subdivision park) from MY PARK's row in the list -- a park
  not in the list writes neither and warns once -- and **no
  `CONTEST_ID`**. A park QSO: `SRX_STRING`, `SIG`, `SIG_INFO` and
  `POTA_REF` = the park, one record per park of an n-fer. **`DXCC` is the
  WORKED CALL's country** (Q62, `d6dd0208`), never the shape of what it
  sent: a W hunter sending `PA` writes `<DXCC:3>291` and `<STATE:2>PA`; a
  VE3 hunter writes `<DXCC:1>1`; `NY4I/VE7` is Canada. A grid QSO:
  `<GRIDSQUARE:4>FN31`. No exchange field the POTA class does not declare
  (`df4f028a`) -- no PRECEDENCE, CHECK, TEN_TEN, AGE or NAME.
- [ ] **ADIF import**: re-import that file into a new POTA log; the parks come
  back as each QSO's QTH, and a record carrying only `SIG=POTA` and
  `SIG_INFO` (as another logger writes it) reads its park from there.

---

## Added 2026-10-02 -- THE NEW CONTEST DROP-DOWN SHOWS DISPLAY NAMES, AND CATEGORY-POWER IS ONE VALUE (M9b)

The UI itself (`CONTEST_OWNERSHIP_DESIGN.md` §8.2n). `uTestContestUI` pins the
list the drop-down is built from and the power decision; **nothing sees the
windows**. The first two groups are DELIBERATE changes; the rest should look
exactly as before.

- [ ] **The New Contest drop-down** (`uNewContestForm.FillContests`,
  `uContestChoices`):
  - it lists **display names**, sorted by them -- *"ARRL Inter. DX Contest,
    CW"*, *"CQ Worldwide DX Contest, SSB"*, *"General QSO/DX Logging"* -- and
    a contest with no human name yet still shows its token (design Q53;
    Batch A, `fba681fa`, named more of them);
  - **WRTC** reads *"World Radiosport Team Championship"* and **IARU-HF**
    reads *"IARU HF World Championship"*, both bare -- no brackets on either,
    since WRTC took its own name (NY4I, 2026-10-16, design Q58);
  - the **last two lines** are *"Locust QSO Party (inactive)"* and
    *"SA-SPRINT (inactive)"*, after every active contest;
  - choose a contest and press OK: **the log's file name and the contest that
    opens are what they were** (the file is still named by the token, e.g.
    `CQ-WW-CW`, not the display name). Check one QSO party, Field Day and
    General QSO;
  - **type-ahead**: the list is a drop-down list -- typing a letter should jump
    to display names starting with it;
  - **long names**: a 30-plus-character name (*"RAEM Ernst Krenkel Memorial
    Contest"*) -- is it readable in the closed combo and the open list, or
    clipped? Widen the dialog: the combo is right-anchored and should grow;
  - the prompts per contest (M9a's list below) are unchanged.
- [ ] **CATEGORY-POWER is one value** (`uCabrilloSummaryForm.CommitCategoryPower`,
  design 7.6):
  - open a contest with a few QSOs, power HIGH. Start the **Cabrillo** export
    (its station-information window opens), choose **QRP**, OK: a Cabrillo
    file is written whose
    header says **CATEGORY-POWER: QRP** and whose **CLAIMED-SCORE** is the QRP
    score -- Winter Field Day (power factor), Idaho (QRP points) or Stew Perry
    show the difference; a plain contest's score does not move;
  - the main window's notice strip shows *"CATEGORY-POWER is now QRP -- the
    scoring category changed and the log was rescored."* and the score display
    updates **without** using Tools > Rescore;
  - reopen it (Tools > Edit Cabrillo Summary...): the row shows QRP. Choose
    LOW and OK -- no file is written (no export), but the notice shows and the
    score moves. Close it **without** changing it --
    no notice, no rescore (re-saving the same power does nothing);
  - **Cancel** and the window's close button save it too (every exit has always
    saved the summary);
  - a **brand-new contest** (no QSOs): choosing a power in the New Contest
    dialog, or later in the summary, shows **no** notice;
  - restart TR4W and reopen the log: the power is the one chosen last.
  - **headless /EXPORT**: a log whose `.cfg` says LOW now writes
    `CATEGORY-POWER: LOW` in the Cabrillo header (the golden corpus's
    `arrl_digi` and `winter_fd` sets did write HIGH, from the header store's
    copy; the corpus compares only QSO lines and CLAIMED-SCORE, so it cannot
    see this).
- [ ] **Call entry, General QSO** (`ShowsContestStatus`): in a General QSO log,
  typing a call shows **no** multiplier/QSO status, station information or
  possible calls, as before; in any contest they show as before.
- [ ] **Band up/down, General QSO** (`BandStepIncludesWARC`): steps onto 30, 17 and
  12 m (with WARC enabled); a contest skips them, as before.
- [ ] **The summary sheet's ten-date warning** (`MaximumContestDates`): a contest
  log spanning more than ten dates warns; General QSO never does -- as before.
- [ ] **The FOC Marathon log** (`PowerFieldIsFOCNumber`): the member number shows
  under **FOC#**, and there is no PWR column; any contest with a power exchange
  shows PWR as before.
- [ ] **WAG** (`CallEntryFrequencyWarning`): with the radio at 3.675 MHz, typing a
  call shows *"Warning: Out of WAG allowed frequency range"*; at 7.080 MHz
  exactly it does **not** (between two windows, as before); in any other
  contest no warning.

## Added 2026-10-02 -- THE DIALOG, THE TOTALS, THE REPORTS AND HAMSCORE ASK THE CONTEST (M9a)

What each contest shows and reports moved onto its class as data the UI renders
(`CONTEST_OWNERSHIP_DESIGN.md` §8.2m). **Every item below should look exactly
as it did before** -- the change is where the answer comes from, not the answer.
`uTestContestDisplay` pins the data; **nothing sees the windows or the files
below but the golden corpus's Cabrillo header** (Winter Field Day, General QSO).
One deliberate change is listed last.

- [ ] **The New Contest dialog** (`uNewContest` renders
  `TContestBase.DescribeNewContestPrompts`; its two 240-line `case`s are gone).
  Choose, and check the rows, their labels, the comment and the "I am in" box:
  - a state QSO party (Florida): one MY STATE row, comment *"Enter your county
    if you are in FL state ..."*; **7QP** says *"7th area"*; **Colorado** adds a
    MY NAME row after it; **British Columbia** shows only its VE7 district
    comment;
  - **NAQP CW**: MY STATE (comment *name and state*) then MY NAME; **CWops**:
    MY NAME first, then MY STATE -- the order is the point;
  - **Sweepstakes**: MY PREC (comment), MY CHECK, MY SECTION; **ARRL Field
    Day**: MY FD CLASS, MY SECTION;
  - **Russian DX**: the box reads *"I am in Russia"*; tick it -- MY STATE row,
    comment *"Enter your oblast ID:"*; untick -- the rows clear;
  - **IOTA**: the box reads *"Island station"* (its own caption, not "I am in");
    **WW PMC**: *"I am in PMC"*;
  - the three still named in the dialog: **POTA** (box *"Activator"*, tick for
    MY PARK -- its class's since 2026-10-13, checked in the POTA item above),
    **RSGB 1.8 MHz** (*"I am in UK"*, tick for the district), the
    **UA4W Championship** (MY QTH, the RDA/grid comment);
  - **IN7QPNE** (its composite class since 2026-10-14; the base's prompt): the county-or-state comment naming *IN7QPNE*.
    OK must still enable only when every offered row is filled.
- [ ] **The totals window** (`uTotal` reads `TotalsDisplay`): **IARU** labels the
  domestic row *HQ Mults* (by mode: *CW HQ* / *Ph HQ*); **Russian DX** and
  **RU3AX** *Oblasts*; **OZCHR teams** (QSO by mode, CW and phone both worked)
  shows *CW: nn%* / *PH: nn%* in place of the per-mode QSO rows. Every other
  contest *Dom Mults*, *CW Dom*, *Ph Dom* as before.
- [ ] **The summary sheet** (PostUnit reads `SummarySheet`): **Winter Field Day**'s
  multiplier columns show 1 per band/mode row and the row count on the total
  line; **ARRL Field Day**'s claimed score is the QSO point total, one column
  further in; every other contest states `Claimed Score = <score>`.
- [ ] **The hour-by-hour report** (`ReportsRunningScore`): no SCORE column for the
  Cup RF CW/SSB, Ural Cup, Ukraine Championship, RF Championship CW/SSB and
  RU3AX; every other contest keeps it.
- [ ] **The Cabrillo header**: ARRL 10 and Winter Field Day still refuse to start
  without a LOCATION (`TC_LOCATIONFIELDEMPTY`); Winter Field Day's
  `ARRL-SECTION:` and `X-EXCHANGE:` lines still precede `LOCATION:`; General
  QSO's `CONTEST:` is the title, else the contest name.
- [ ] **HamScore / the UDP contact broadcast / the log's `exchange_sent`**
  (`uExchangeBuilder` asks `CanonicalReceived/SentExchange`): with HamScore on,
  log one QSO each in **CQ WW** (`599 5`), **ARRL DX** from a W and from a DX
  station (`599 CT` / `599 100`), **NAQP** (`JOE CT`), **CW Open** (`123 JOE`),
  **RTC** (`123 EM17` received, `7 EM17` sent -- no RST either way) and **Field
  Day** (`2A CT`); every other contest sends the exchange as typed.
- [ ] **WRTC**: the master-file, Telnet and post-scores menu rows are greyed, the
  three windows do not open, and Super Check Partial shows nothing -- now from
  `PermittedOperatingAids`. The **WAE** runnings still offer the QTC menu; every
  other contest greys it.
- [ ] **Score posting XML** (UDP score broadcast, Q109, `a5afe844`; **rows
  changed 2026-11-02**): the local UDP `dynamicresults` carries the same rows as
  the HamScore post -- ONE row per band in the all-modes column (`mode="ALL"`)
  for the QSOs, the points and each multiplier, then ONE `total`/`ALL`
  summary; no per-mode rows and no total per mode (CW 5 on 20 m and PH 3 on
  15 m reads 20 ALL 5 / 15 ALL 3 / total ALL 8). A multiplier is typed by the
  contest: `state`, `country`, `zone`, `prefix`, and `gridsquare` for a grid
  contest (RTC, the VHF contests). **WRTC posts its HQ and country multipliers**
  on every band row and the total (Q55). Check with a real N1MM-format score
  listener, if you have one, that it reads the all-modes rows.
- [ ] **THE ONE DELIBERATE CHANGE -- design 7.11, MY STATE IS NEVER WRITTEN BY A
  CONTEST.** As a **K or DL station**, open **Canada Day** (or Canada Winter,
  Russian DX, RU3AX) or the **Cup RF**: the CW messages, the `&` macro, the
  Cabrillo and ADIF sent columns and HamScore send what they always did (no
  state; the grid for the Cup RF) -- **but Preferences' MY STATE still shows
  YOUR state**, and after exiting and opening another contest MY STATE is what
  you set, not blank or a grid. Before M9a the contest wrote its value into MY
  STATE and a save carried it out. A MY STATE edit made mid-session no longer
  reaches those contests' sent exchange (the contest's rule stands for the
  session; design Q56).

---

## Added 2026-10-02 -- OFF-BAND QSOs LEAVE THE DUPE SHEET AND THE NEED-MULT HINTS (M8)

Multipliers and dupes became contest-declared rules over the shared sheet
(`CONTEST_OWNERSHIP_DESIGN.md` §8.2l), and NY4I's off-band ruling (§7.4,
*"off-band should not impact need multiplier. It is really a one-off with no
impact on the contest at all"*) now reaches the dupe sheet and the hints.
**Only the Idaho QSO Party states its bands today**, so only Idaho can move;
every other contest credits every band and is unchanged by construction. The
unit tests pin the logic; **nothing sees the windows**. Open an Idaho log
(160/80/40/20/15/10 m only) and work one station on 20 m CW, then the same
station on 30 m CW:

- [ ] **Dupes**: the 30 m QSO is **not** shown or logged as a dupe, and a second
  30 m QSO with it is not either. A 20 m repeat still is.
- [ ] **Displays that read the dupe sheet** -- a deliberate consequence, Q51:
  the 30 m dupe sheet does not list the station, and the Stations window
  shows no `+` for an off-band band it shows (6 m and up, in its VHF view).
  The possible-calls strip does not mark it a dupe on 30 m.
- [ ] **Need-multiplier hints** on 30 m: typing a DX call that is a needed
  country on 20 m shows **no** "new multiplier" indicator, the mult-needs
  strip shows no off-band band as needed, and the band map does not flag a
  30 m spot as a multiplier.
- [ ] **A defect that went with it**: in Idaho (multipliers not counted per
  band) typing a county the log does not have now shows it **needed** while
  on an Idaho band -- before M8 the county strip said "not needed" for every
  county, always.
- [ ] **Everything else is as before** -- the score, the multiplier counts and
  the Cabrillo `CLAIMED-SCORE` (the golden corpus and the contest matrix
  hold those).

---

## Added 2026-10-02 -- EACH CONTEST OWNS ITS FINAL SCORE (M6), AND THREE BONUSES ARE NEW

The final score moved onto the contest classes (`TContestBase.FinalScore` =
`CombineScore` + `BonusPoints`), and `LogEdit.TotalScore` -- what the score
display, the summary sheet, Cabrillo `CLAIMED-SCORE`, the XML report and the
posting clients read -- asks it. The golden corpus and the matrix's `totals`
section prove the formulas did not move; **no gate sees the score ON SCREEN,
and none sees a bonus pay**: the matrix's synthetic QSOs trigger none of them,
so `uTestContestTotals` is their only proof. To exercise, watching the main
window's score after each QSO and the `CLAIMED-SCORE` of an exported Cabrillo:

- [ ] **North Carolina, the Rarest-of-NC sweep (NEW)**: log stations in four of
  CAB, GRM, VAN, MAC, DAV, CUR, PAM, ALL, PER, CAS -- no bonus; the fifth adds
  **500 once**, after the multiplication (the score is points x mults + 500).
  A sixth county adds nothing more.
- [ ] **Salmon Run, W7DX (NEW)**: CATEGORY-MODE MIXED -- a W7DX CW contact adds
  500, a W7DX phone contact another 500, a second CW band nothing. Set
  CATEGORY-MODE CW and the phone contact stops paying (the score drops 500).
  **An operator who never chose a CATEGORY-MODE is a CW entry** -- that is the
  setting's default and what the Cabrillo header says.
- [ ] **Idaho, the dormant county (NEW; one table per contest YEAR since Q35,
  `b6e7d19b`)**: the year comes from the LOG -- today its QSO dates -- and
  only 2026 has a table. In a log dated 2026, an in-state station with MY
  STATE `BUT` (Butte) -- nine valid QSOs, no bonus; the tenth adds **1000**.
  `ADM` pays 500; `ADA` and `WAS` are not in the 2026 table and pay nothing.
  A dupe or a 30 m QSO is not a valid QSO. A log dated another year pays no
  county bonus, and `tr4w.log` carries one error naming the year.
- [ ] **The moved formulas -- spot-check one each against a hand calculation**:
  WAE (weighted multipliers, QTCs as points), Winter Field Day (band-modes x
  points x 2 for LOW / 5 for QRP), RF Cup / ALRS / RF Championship / Ukraine
  Championship / OZHCR (points PLUS 100 / 300 / 50 / 10 / 1000 per
  multiplier), Ural Cup (prefixes are 10 points each, after the
  multiplication).
- [ ] **A score-posting client** (HamScore / getscores.org) posts the score the
  main window shows -- off the main thread it now reads the last score the
  window computed.

---

## Added 2026-10-02 -- EACH CONTEST PARSES ITS OWN EXCHANGE (M5b), AND TWO NEW REFUSALS

Exchange parsing moved onto the contest classes
(`TContestBase.ParseReceivedExchange`). The contest matrix types 66 exchanges
through `ParametersOkay` for every contest and proved nothing else moved; **no
gate types into the real window**, so nothing has seen a refusal's message on
screen or a valid exchange log from the entry fields. To exercise:

- [ ] **Sweepstakes, no precedence** (NY4I, design 7.10): type `123 99 CT` and
  Enter -- NOT logged, and the notice line says `Missing precedence (Q A B U M S)`.
  It used to refuse silently. `123 A 99 CT` logs as before.
- [ ] **A QSO party, out-of-state station** (NY4I, design 7.10) -- Florida, MY
  STATE `KS`: a DX station `DL1ABC` with `599 DL` is NOT logged and the notice
  says `Out of state: work FL stations only`; a Florida county logs. With MY
  STATE a Florida county (in state), the DX station logs.
- [ ] **NC QSO Party**: out of state, `599 GA` from `K4ABC` is now refused (an
  improper domestic QTH -- `nc_cty.dom` is the hundred counties); a county logs.
  A VE station with MY STATE `ON` is now OUT of state for NC. In state, states,
  provinces, DC and DX are still accepted.
- [ ] **Field Day DX**: log `DL1ABC` with `1D` (or `1D DX`), export ADIF -- the
  record carries `CLASS 1D`, `SRX_STRING 1D DX`, and no `ARRL_SECT`. Import that
  file back: the QSO's QTH is DX and it is NOT a section.
- [ ] **Unchanged, but moved -- spot-check one each**: RAC Canada Day `VE0ABC 599 123`
  logs a serial; PCC `599 GR` a QTH and `599 123` a serial; IARU `ARRL` alone
  logs with the station's zone filled; UK/EI `G3ABC` with only `123` is refused
  `Invalid Entry`; SAC with `UA3ABC` in the call window clears the entry; LABRE
  `PY2ABC 599 SP` logs SP as the state.
- [ ] **CQ WW RTTY `599 14` from a DX station** now answers the same every time --
  REFUSED, by the shape's own later test of a first word over two characters.
  The fields it left behind used to differ run to run (an uninitialised word
  handed to `ValidRST`, also in D7). Whether `RST zone` should log at all for
  CQ WW RTTY is a question, not a regression: it never did reliably.

---

## Added 2026-10-01 -- NIGHT-TIME RULES READ THE QSO'S TIME, NOT THE CLOCK

Croatian (23:00-04:59 UTC doubles) and UK/EI (01:00-04:59 UTC for a UK/EI
station) used to read the PC's clock at SCORING time, so a rescore at night
doubled daytime QSOs. Both now read `ContestExchange.tSysTime`, and live entry
(`MainUnit.ParametersOkay`) stamps the QSO's time BEFORE scoring it -- without
that, a fresh record scored as hour 00, inside both windows. Unit tests pin
the rules; nothing automated drives live entry. To exercise:

- [ ] Log a Croatian QSO by day and one at night (or with the clock set): day
  points by day, doubled at night.
- [ ] Rescore the log at the other time of day: points do NOT change.
- [ ] Same for UK/EI from a G station.

---

## Added 2026-10-01 -- THE IDAHO QSO PARTY HAS ITS OWN CONTEST

`IDAHOQSOPARTY` is a new contest type with its own class (`uContestIdahoQP`); the
template `Idaho QSO Party.cfg` no longer borrowed `CONTEST = NEQP` (and was deleted
2026-10-15; create the contest from the New Contest dialog). Unit tests pin
the class; **nothing automated types an Idaho exchange**, and the multiplier
lists come from `.dom` files no gate loads. To exercise:

- [ ] **In-state** (`MY STATE` an Idaho county, e.g. ADA): states, Canadian
  provinces and DX countries are multipliers, and every Idaho county counts as
  the ONE multiplier "Idaho". Before this change in-state got the 44 counties
  and no states or provinces at all -- `IDAHO.DOM` wrote `INCLUDE S50.DOM`
  without the word `FILE`, which `logdom` silently skips.
- [ ] **Out-of-state**: each of the 44 counties is its own multiplier; nothing else.
- [ ] **Points**: CW 2, phone 1, digital 2, FM 1 -- the old `.cfg` scored CW 4 and
  phone 2 through the rotated spelling table.
- [ ] **County line**: a third county in one exchange is refused; two are accepted.
- [ ] **Export**: Cabrillo `CONTEST: ID-QSO-PARTY`, ADIF `CONTEST_ID` `ID-QSO-PARTY`.

---

## Added 2026-09-11 -- WHAT NY4I'S "WERE THEY REFERENCED?" QUESTION FOUND

He asked whether each deleted `csRem` row had been checked for references. It
had not been, individually -- the argument was structural (a `csRem` row
returned True and exited BEFORE applying, so it could not affect what any code
read). That argument holds, and `uCFG.pas:2096` is the code that proves it.

**But the search he asked for found a real defect next to them, and a second
one underneath.** Doing the check was worth it; the reasoning was not a
substitute.

### FIXED -- Preferences read blank and then saved the blank

Seven hand-wired controls in `uPrefsForm` reach their setting by command NAME:
external logger address / enabled / port, MMTTY engine, radio TCP server port,
spot collector enabled, YCCC SO2R enable. They read through
`CFGCommandValueAsString` and write through `SetCFGCommandValue`.

All seven had moved to `uSettingsModel`. The WRITE path resolved the name; the
READ path did not, and returned `''`. So the panel showed unchecked or empty
whatever the setting actually was, and OK stored what the control was showing.

**Broken since 2026-09-10, not by the row deletions** -- those rows had been
stubs with `crAddress: nil` since then, so the read was already failing.

Fixed, with a test that was verified to FAIL without the fix. **Worth checking
on the bench anyway**: open Preferences, confirm the external logger and spot
collector checkboxes show the state the program is actually in, press OK, and
confirm they are unchanged afterwards.

### ALSO OBSERVED -- the external logger port is read once at startup

`uProgramMain:1682` copies `Settings.ExternalLogger.Port` into the logger
object when it is created. Changing the port in Preferences mid-session
updates the setting but not the running object. That predates this work (the
global was read once too) and is not a regression; it is worth knowing before
anyone reports "changing the port does nothing".

---

## Added 2026-09-11 (overnight) -- 122 CONFIG ROWS GONE, AND THE RULINGS THAT WERE OWED

Six commits moved 122 rows out of `CFGCA` (508 -> 386). Everything below is
green on this machine -- FullBuild, 24,787 unit tests, the corpus at
24/0/2 -- and **none of it proves a radio keys or a band map redraws**, which
is what this queue is for.

### To exercise on the bench

1. **The band map filters, from BOTH directions.** The eight display filters
   (all bands, all modes, dupes, CQ, mults-only, SO2R, call-window, GHz) are
   properties now and their SETTER asks for the repaint. Previously a config
   file repainted and a menu toggle only worked because the window remembered
   to ask.

   - toggle each from the band map's own context menu, and with B / M / D
   - then change one from Preferences and confirm the map redraws WITHOUT
     reopening it -- that half is the new behaviour
   - and from a second position over multi-op, which never repainted before

2. **HF / VHF / WARC band enables.** These are not display filters: they also
   refuse a band change. Confirm a WARC band is still refused with WARC off,
   and that selecting a contest still sets them (five contests in `fcontest`
   assign them).

3. **PTT, on real hardware, and this is the one that matters.** Five settings
   moved off the `Config` record: PTT ENABLE, PTT LOCKOUT, PTT TURN ON DELAY,
   PTT VIA COMMANDS, NO POLL DURING PTT. The defaults are pinned by a test,
   but **nothing here can prove the transmitter keys**. `PTT TURN ON DELAY`
   defaults to 15 ms and is what stops CW starting before an amplifier is
   keyed.

4. **The paddle**, through a WinKeyer or a YCCC box -- the LPT paddle input
   is gone (2026-09-13): SWAP PADDLES, PADDLE SPEED (0 = follow the keyboard
   speed), PADDLE PTT HOLD COUNT (13 dit counts -- a 0 here is hot switching
   on an amplifier), and PADDLE MONITOR TONE, the paddle sidetone -- KEPT by
   NY4I's ruling below.

5. **An OLD config file.** 98 `csRem` rows were deleted and 91 withdrawn
   command NAMES replace them. Open a `tr4w.ini` or contest `.cfg` from 4.x
   that names a withdrawn feature and confirm **no "invalid statement in
   config file" dialog** appears. That dialog is the entire reason those
   hollow rows existed.

6. **Band map item height / width / size** now refuse an out-of-range value
   rather than accepting it. They still say "restart required", which is real:
   the grid geometry is computed once.

### The ruling recorded

- [ ] **`PADDLE MONITOR TONE` -- RULED 2026-10-18 (NY4I): *"Keep it."*** The
  setting stays. Its check is bench item 4 above: the WinKeyer / YCCC paddle
  sidetone, now that the LPT paddle is gone.

### One thing NOT done on purpose

`Config.DVKPath` and `Config.DVKRecorder` are `FileNameType` buffers read
through `GetRealPath(Path, FileName, AddFolder: PAnsiChar): PAnsiChar`. Making
them `string` properties is right and is what took two `PChar`s out of the tree
when `MMTTY ENGINE` moved -- but it means converting `GetRealPath` and its
seven callers, which is the `PChar` audit, not a settings batch. Casting at the
call sites instead would ADD `PChar`s.

---

## Added 2026-09-10 (overnight) -- MULTI-OP: SETTINGS SYNC, AND THE LINUX PORT LIST

Four items. The first needs TWO POSITIONS AND A SERVER, which is the one shape
of test nothing here can stand in for.

### 1. A SETTING CHANGED AT ONE POSITION SHOULD NOW REACH THE OTHER

**This was BROKEN and nobody knew** (`41229eec`). Nothing in this build filled a
`TParameterToNetwork` or put one on the wire; the record was declared, never
used, and its message id was never set -- and `tr4wserver` discards a message
with the wrong id without a word.

**The RECEIVE side survived**, which is why it lasted: TR4W has been obeying its
peers while telling them nothing, so a two-position station drifts in ONE
DIRECTION ONLY and the operator who made the change sees it take effect.

It is a port regression, not a missing feature -- D7 has all three pieces
(`JCTRL2.PAS:1817`, `uOption.pas:919`, and `uNet.pas:217` setting the id inside
the network window's `WM_INITDIALOG`). All three went with the Win32 windows.

**What to try, with two positions connected to `tr4wserver`:**

1. Change a shared setting in Preferences at position A -- `CQ EXCHANGE` and any
   `MY ...` row are `crNetwork:1`, so those are the ones to use.
2. Position B should take the change without being touched.
3. Then the OTHER DIRECTION, because only one direction was ever broken.
4. With `DEBUG LOG LEVEL = DEBUG`, position A's log should carry
   `[Net] sent "<command>" = "<value>" to the other positions`, and B's should
   report the command it applied.

**A value that is REFUSED must not be announced.** Type something the row
rejects at A; B must not change, and A's log should say it was refused rather
than sent.

**Single-operator stations cannot be affected either way** -- the send is
guarded on `NetIsConnected` -- but it is worth one start with no server to
confirm nothing new appears in the log.

### 2. LINUX: THE PORT DROP-DOWN LISTS THE ADAPTER

`c67f582a`. `/dev/ttyUSB0` and its vendor string should appear in the radio,
keyer and rotator port lists on the Mint box, marked `(not selectable yet)` --
that caption is CORRECT for now and goes when the port work reaches step 5.

**Verified already**: the enumerator itself, run natively against the FTDI
adapter. What is NOT verified is that the LCL drop-downs show it.

**And add yourself to `dialout` first** (`sudo usermod -aG dialout toms`, then
log out and in), or the port will list and refuse to open.

### 3. LINUX: A NEW CONTEST LANDS IN `~/tr4w`

`969d8a2d`. The AppImage mounted itself read-only and the contest log was being
created beside the binary, so QSOs were NOT BEING SAVED.

- [ ] Create a contest on the Debian box. Its `.db` should be in `~/tr4w`, not
  under `/tmp/.mount_...` (a new contest writes no `.cfg`).
- [ ] Log a QSO, restart, and confirm it is still there.
- [ ] "Download latest cty.dat" should succeed rather than failing with
  *"Read-only file system"*.

**Existing contests are unaffected** -- they keep pointing wherever their `.cfg`
already lives. This changes where NEW ones are created.

### 4. WINDOWS: A SERIAL RADIO STILL OPENS

Nothing above is a Windows feature, and that is exactly why this is here. The
port work moved what the store holds from `SERIAL n` to the device name
(`269b99ea`), and a careless step there leaves a Windows station whose radio
silently stops opening.

- [ ] One serial rig, from an EXISTING configuration, so the `SERIAL n` a saved
  station already holds is exercised on the upgrade path.
- [ ] Then change the port in Preferences, restart, and confirm it sticks.

---

## 2026-09-05 overnight -- the main window has no Win32 children left

**Two commits plus follow-on work.** `839aeb1f` replaced the last sixty-seven raw
Win32 STATICs on the main form with designed LCL panels; `d568e5e3` made the
window resizeable. Everything below is a LOOK-AT-IT item -- lints 31/31, unit
tests 22513/0 and the corpus 24/0/2 were all green while the four regressions in
the second group were on screen.

### Already confirmed by NY4I, not waiting

- [ ] The form is correct again after the border-style fix (title bar, menu,
  close-quits, and the un-compressed bottom).

### KNOWN BAD, and NY4I is deciding how it should behave

1. **The log grid does not grow when the window is dragged taller.** The window
   resizes and the lower band follows the bottom edge, but the grid keeps its
   height. NY4I: *"it does not really make much sense to resize the form if the
   log grid is not resized"* -- and then *"hold on that as I need to think about
   how I want it to work."* **Do not 'fix' this before that decision.** The grid
   carries `Anchors = [akLeft, akTop, akRight, akBottom]`, so the anchor is not
   the whole story and the cause is still open.

### Waiting for a bench run

2. **The score totals grid (top left).** Eight columns by four rows under seven
   band headers, all designed panels now. Check: the numbers land in the right
   cells; the CURRENT BAND's header is highlighted and the others are not; the
   highlight MOVES with a band change and leaves nothing behind. That last part
   is a fixed defect worth confirming -- the Win32 version repainted headers 1
   to 6 of seven, so the "All" column's highlight could go stale.

3. **The QSO-need and mult-need strips (top right).** Type a callsign that is
   needed on some bands and not others. Check: only the needed bands appear;
   the CW/SSB rows appear only in a by-mode contest and read `CW:` / `SSB:`;
   a non-by-mode contest shows one row reading `Both:` for mults and a blank
   label for QSOs. The mult strip takes its colours from `mweNewMultStatus`
   (yellow-on-black by default) and the QSO strip from `mweWholeScreen`; if
   either is the wrong colour, `uMainGrids.ApplyElementColors` is where.

4. **A one-pixel column shift, top left.** The band columns used to start one
   pixel INSIDE the label column (label is `ws * 5` = 85, the columns began at
   `2 * round(ws * 2.5)` = 84). They now start after it. Nobody should be able
   to see this; it is here because it moved every totals column by a pixel and
   an operator comparing screenshots might notice.

5. **The Last-hour and Rate progress bars.** Now `TProgressBar`. They should
   fill as before. THEY WILL BE THE THEME COLOUR, not red and blue: the code
   asked for those with `PBM_SETBARCOLOR`, which comctl32 v6 ignores under
   visual styles, so they have not been red or blue for as long as the app has
   shipped a v6 manifest. Confirm you are happy with that before it is called
   done -- restoring the colours means owner-drawing the bar.

6. **Tour duration (needs `MINITOUR DURATION` non-zero).** The readout and its bar
   appear on the quick-command row, the bar tracks the minutes, and at the top
   of the tour it switches to MARQUEE and back. The marquee used to be driven by
   `SetWindowLong(GWL_STYLE)` rewriting the window style wholesale -- the same
   move that blanked the log grid for three sessions -- and is now
   `Style := pbstMarquee`.

7. **The window's height across a restart.** Drag it taller, quit, relaunch.
   The height should come back. EXPECT ONE ODDITY THE FIRST TIME: the saved rect
   was written by the old code as an OUTER rect and is now read as LCL bounds,
   so the first launch after this change may come up slightly shorter than you
   left it. It self-corrects on the next save. If it is still wrong on the
   SECOND restart, that is a real defect.

8. **The Network window title.** Connect to a TR4WServer. The title should read
   `Network : <operation> <address>:<port>`. It is `Format` + a `Caption`
   property now instead of a wsprintf shim writing through a cached HWND.

9. **Both radio panel titles.** Open Radio 1 and Radio 2. Each should read
   `Radio 1`/`Radio 2` plus the rig name when one is configured, and just
   `Radio 1`/`Radio 2` when none is. Same conversion as the item above.

---

## 2026-09-03 overnight -- Log Edit converted, and what it turned up

**Everything here needs a bench run; none of it is checkable from a script.**

### Confirmed by NY4I during the session, not waiting

- [ ] Logging works again after the CONTEST fix. The title bar shows the contest.
- [ ] The main editable log renders again after the column-width unit bug.
- [ ] Log Edit columns are measured and distributed, and the grid no longer
  visibly redraws -- the third attempt was the right one (a row cache; the
  cost was two database reads per row per paint, not the column arithmetic).

### Waiting for a bench run

1. **View / Edit Log, converted to an LCL virtual list.** Open it on a contest
   log and check: the columns are readable and fill the window; X-QSO rows are
   grey and deleted rows red -- *neither was ever true in this window*; a
   double click opens the QSO you clicked; Escape closes it; resizing
   redistributes without flicker. Then scroll a LONG log: past 512 rows the
   cache stops helping and `LogSourceReadAtIndex` does the work again.

2. **THE OWNER GAP IS NOT ONLY THIS WINDOW.** `ShowModalOverWin32Parent`
   disables the parent but never sets an owner, so switching to another program
   and back raises the MAIN window and leaves the modal behind it -- still
   modal, now invisible. NY4I hit it on Log Edit and it is fixed there with
   `PopupParent`. **Every other dialog shown through that helper has the same
   gap.** Fixing it inside the helper would fix all of them at once, but the
   helper takes an HWND and would have to find the form behind it. Worth doing;
   worth doing deliberately.

3. **Column widths now live in the log, not a `.cfg`.** Drag a divider, close
   the contest cleanly, reopen it, and confirm the width came back -- and that
   a column you did NOT drag still sizes itself. Only a width the operator set
   is captured, which is what the `.cfg` used to hold.

### Added later the same night -- Win32 removal, inside out

11. **The main window still draws everything.** `CreateMainElement` no longer
    returns a window handle, and the element loop no longer stores one in
    `wh[]`. That array was written for all 110 panels and READ BY NOTHING (its
    only live readers are the server log's list view), and storing a handle
    forced `TWinControl.Handle`, which CONSTRUCTS the window -- so 110 windows
    were being created at startup to fill a dead array. The LCL now builds each
    handle when the form is shown. **Check the main window looks unchanged and
    nothing is blank**; the headless corpus exercises form creation and passed,
    but it does not look at pixels.

12. **The multi-op station list.** Connect two stations. Rows should appear and
    fill as before. `AddNewClient` used to insert a row into `wh[mweNetwork]` --
    a handle never assigned since that list became a `TListView` -- so the
    insert did nothing; rows are created on demand by `SetCell`. Also gone: a
    `ListView_RedrawItems` against the same zero handle after a PTT change.
    **If a row is ever missing, or a PTT change does not repaint, this is why.**

13. **The DX-cluster callsign alert list.** Put a call in
    `DXCLUSTER_ALERT_LIST.TXT`, open Telnet, and let that call be spotted. It
    should still beep and show "New DX Cluster spot: ... ". The list was a
    HIDDEN Win32 LISTBOX created at 0,0,0,0 and searched with
    LB_FINDSTRINGEXACT -- a data structure built out of a window. It is a sorted
    TStringList now. **Also worth one deliberate negative test**: a call that is
    NOT in the file must not alert. The old lookup handed a ShortString where a
    NUL-terminated pointer was wanted and could match on trailing bytes from the
    rest of the spot record, so a false positive was possible; that is now
    unreachable rather than guarded.

---

14. **The time sent to the multi-op network was uninitialised stack.** Fixed
    in `8149ebb1`. `TF.GetTime` had its entire body commented out, so all four
    `var` parameters came back as whatever was on the stack -- and nothing could
    warn, because `var` parameters are assumed to be written by the callee. Two
    live callers in LOGEDIT (the *"send time to computers on the network?"*
    prompt) formatted those values with a correct date from `GetDate` and put
    them on the wire.

    **THE COMMIT MESSAGE OVERSTATES THE CONSEQUENCE, and this note is the
    correction.** It says receiving stations set their clocks from the message.
    They do not, for two independent reasons NY4I pointed out and the tree
    confirms:

    * `MultiTimeMessage` is declared in `logstuff.pas:86` as
      `{ TR6.75 - Reception only from CT Network }` -- TR4W SENDS it and has no
      handler that receives it. The garbage went onto the wire and nothing in
      TR4W consumed it.
    * The real clock sync is a DIFFERENT path -- `uNet.pas:418`,
      `Windows.SetSystemTime(NetTimeSyncPtr.tsTime)`, driven by the TR4WServer
      time-sync record and not by `GetTime` at all. NY4I: *"since we are not
      running as admin, changing it is not possible"* -- and that call already
      reports the failure (`ShowSysErrorMessage('SET SYSTEM TIME')`), so it is
      not a silent downgrade.

    So this was a real defect -- uninitialised memory formatted and transmitted
    -- with a much smaller blast radius than the commit claims. It is worth a
    check, not a panic.

    **TEST (revised):** two stations networked, answer Y to that prompt, and
    confirm the time in the transmitted message is the correct UTC time rather
    than nonsense. Do NOT expect the receiving station's clock to change; it
    will not, and that is correct.

15. **Radio configuration, after 468 lines came out of `uCAT.pas`.** The
    per-slot CAT dialog was deleted on 2026-08-29 but ~465 lines of its
    supporting machinery were left orphaned -- port combos, radio-type combo,
    default-network-port helpers -- with no callers. Deleted now. What SURVIVES
    and is used by Preferences: `DiscoverNetworkRadios`,
    `CloseCATAndKeyerForThisRadio`, `GroupRadioIniKeys`, `CATWTR`.
    **TEST:** open Preferences, add/edit a radio, check the COM-port drop-down
    still lists and greys ports correctly, that a network radio discovers, and
    that the settings survive a restart.

## Added 2026-09-01 -- BOTH WAE QTC WINDOWS, AND NOBODY HAS RUN THEM

### [ ] Hand `docs/QTC_BENCH_HANDOFF.md` to N4AF

Both QTC windows converted from raw Win32 to LCL on 2026-08-31/09-01 -- the
receive window had **thirty-two subclassed edit controls** and none of them
survive -- plus fixes on top: button captions that could not fit, a stray glyph
in the QRV caption, a minimum size that ratcheted down on every reopen, and an
access violation saving a completed book.

**Every one of those was found from a screenshot, and three of them took more
than one attempt.** NY4I, 2026-09-01: *"I have to look up how to operate QTCs
honestly. That is Howie's area."*

So this is the ONLY part of the conversion with neither an automated harness nor
an operator who can judge it. It cannot get a harness for a good reason: a QTC
window opens only in a DARC WAE contest with QSOs available to send, and there
is no WAE set in the golden corpus. Building one would prove the windows open,
which is not the part in doubt.

`docs/QTC_BENCH_HANDOFF.md` is the script -- what to do and what correct looks
like, taken from what the Win32 code did. Three items in it are DECISIONS rather
than checks and are marked as such:

- [ ] the per-line resend buttons (Alt+1..Alt+0) **now work**; in the Win32 version
  they never did, because they were created with the wrong control id. Wiring
  them was a judgement call and is one line to undo;
- [ ] the receive window's **OK button is gone** -- it did nothing, and its handler
  still carries an N4AF 04.32.3 note beside the commented-out save;
- [ ] the Cabrillo **transmitter id** diverges from the specification in two ways
  and has NOT been touched. See Part 4 of the handoff.

Nothing here blocks anything else. It is on this list so it does not quietly
become "converted, therefore done".

## Added 2026-08-28 (night) -- FOUR KENWOODS CHANGE DRIVER ON UPGRADE

### [ ] This one needs a release note, not just a bench run

`InterfacedRadioTypeSA` -- the table `RADIO ONE MODEL = ...` was matched against
-- had drifted one row from the enum in `VC.pas`. It was missing `TS140` and
carried a `TS530` the enum never had, so from that point on it was off by one:

| the config said | the operator actually got | after the fix                             |
| --------------- | ------------------------- | ----------------------------------------- |
| `TS440`         | TS-140 driver             | TS-440 driver                             |
| `TS450`         | TS-440 driver             | TS-450 driver                             |
| `TS480`         | TS-450 driver             | TS-480 driver                             |
| `TS530`         | TS-480 driver             | **no match** -- TR4W has no TS-530 driver |
| `TS140`         | no match at all           | TS-140 driver                             |

**Existing configs will behave differently after upgrading**, and for these four
that means correctly rather than as before. Two things follow:

- [ ] somebody with a TS-440/450/480 should confirm on hardware that the *correct*
  driver actually works -- they have been running the neighbouring one, possibly
  for years, and nobody has exercised the right one;
- [ ] `TS530` was never a real TR4W model. Anyone whose config says that was getting
  a TS-480 driver by accident and will now get no radio at all. If that spelling
  should keep working it needs a deliberate `MarkConfigToken` alias -- ask before
  adding one, because preserving it means preserving a bug.

### [ ] Icom IC-7110 -- a clone, not a driver

Added the same evening. It is the IC-705's driver with a different name and the
one fact available: CI-V `$BA`. The band plan, transceive menu address, scope
geometry, HamLib id (still the IC-705's, deliberately) and serial parameters are
all inherited and unverified -- the radio was announced days ago and has no CI-V
reference guide yet. It needs a real manual and a real radio before it is
offered to anyone as finished.

---

## Added 2026-08-28 (night) -- I18N: ONE THING TO SEND, ONE THING TO DISTRUST

### [ ] Send the Chinese catalogue to BA4WI, and ask for his original file

`i18n\tr4w_zh_CN.po` now exists. It holds 73 strings recovered from his
`tr4w_consts_chn.pas` plus 536 machine drafts, every one of them fuzzy.

**Ask him for the original file.** `tr4w_consts_chn.pas` is UTF-8 damaged at
the BIT level and only partly invertible -- 144 of his strings cannot be
recovered at all, and of the 73 that came back, roughly half have one character
wrong (`其闭` where it must be `关闭`). A wrong hanzi looks exactly like a right
one, so those are suggestions for him to confirm, never translations. If he
still has the file he wrote, all 254 come back cleanly instead.

### [ ] DISTRUST: does `Invoke-MenuSmoke` really fail when a window does not open?

The preamble to this document says it does -- "fails if any of them does not
produce a window". Evidence from 2026-08-28 says otherwise: in one sweep run the
Preferences window never opened (294 captions measured against another
language's 744, and no `PrefsForm` line in the log at all) and the runner
reported no failure. If `ExpectsWindow` can miss, then every "the conversion is
fine" result it has ever produced is weaker than it reads, which is worth
knowing before the next conversion leans on it.

Not yet chased -- flagged because the claim is load-bearing and is written into
this file. `Sweep-TextFit.ps1` now keeps the runner's own output per language in
`build-out\textfit-logs\<lang>-menusmoke.txt`, so the next occurrence is
diagnosable rather than gone.

**MEASURED 2026-08-29, and it is worse than "in one sweep run".** A full sweep of
21 languages was run after the machine-seed, and **9 of the 21 measured 59-72
captions against a best of 536** -- Preferences never opened, and
`Invoke-MenuSmoke` reported success for every one of them. Re-running the nine
fixed six; re-running the remaining two fixed one; the last needed a third run.

| pass | languages run | invalid |
| ---- | -------------:| -------:|
| 1    | 21            | 9       |
| 2    | 8             | 2       |
| 3    | 2             | 1       |
| 4    | 1             | 0       |

**So the first-pass failure rate is about 40%, it is load-dependent rather than
language-dependent** -- Spanish measured 59 in the bulk run and 523 alone, with
no change to its catalogue -- and `ExpectsWindow` did not catch a single one.
That confirms the DISTRUST above with numbers: the runner's window check is not
detecting a window that fails to appear.

The `SUSPECT` floor in `Sweep-TextFit` is what caught it, and it only works
because several languages run together and give it a yardstick. **A single-language
sweep has no floor and would silently report a partial measurement as a pass.**

Two things are owed, in this order:

1. Find out why `ExpectsWindow` misses. It compares visible top-level window
   counts before and after; the likely culprit is that Preferences is slow enough
   under load that the `AfterMs` window closes before it appears, so the count
   never rises and the check passes on a window that was merely late rather than
   absent.
2. Once that reports honestly, have `Sweep-TextFit` **re-run a language that
   lands under the floor** instead of printing SUSPECT and leaving it to a human.
   Today that took four passes by hand.

---

## Added 2026-08-28 (evening) -- FIXED FROM NY4I'S NOTES, UNRUN

Worked from the [AGENT ...] notes as instructions. Each of these is a change he
reported and has not re-tested, except where marked confirmed.

- [x] **Edit QSO wrote the operator as its first letter only** (`1e53f410`).
  CONFIRMED as a defect from his log; the fix itself wants a look: edit a QSO,
  change Operator to something longer than one character, save, reopen.

- [x] **Check for Updates is off the Help menu** (`2366f099`). Verified by
  dumping the live menu. **Still yours:** an endpoint that returns a version
  string, and a static link to the latest.

- [x] **Edit QSO tab order** (`9792b795`) -- RST received -> Operator ->
  Deleted -> X-QSO -> Save -> Cancel.

- [x] **Picking a window from the Windows menu always shows it** (`9792b795`).
  Was: an item shown UNCHECKED could still take the close branch. Applies to
  every tool window, so worth a pass over several.

- [x] **The call and exchange fields use the main font** (`9adffbeb`). They were
  still being handed an HFONT, which an LCL control ignores, so they kept the
  form default while everything beside them did not.

- [x] **One config log line per CHANGE, not two per save** (`53921ce2`), and it
  now says what the value was.

- [x] **Renaming a profile no longer empties the radio combos** (`ca1eb59a`).
  CONFIRMED by NY4I. Took four attempts; the first three fenced the capture
  side when the fault was on the display side.

### Stable ids -- three stores changed, NONE bench-verified

`875c71b6` radios, `aacf6571` keyers, `79cda4c5` rotators. Profiles and the
active-device references are ids now, not names. Migration from a file without
ids is covered by unit tests, including one built from the shape of his own
settings/tr4w.json.

- [ ] **Rename a radio** in Preferences and confirm the active profile keeps it.
  This is the case that failed and started all of it.
- [ ] **Rename a keyer** and confirm the profile's CW output still names it.
- [ ] **Rename the active rotator** -- type over its name a character at a time.
  It used to deactivate after the first letter.
- [ ] **Open an existing station** and confirm nothing moved: the migration runs
  once, silently, on the first load with this build.

### Still open from his notes

- [ ] **The beacon monitor tunes the radio just by opening.** "I should have to
  take an overt act to start changing the radio frequency."
- [ ] **The colours table could show a sample** of the text and background.
- [ ] **Escape closes the DX cluster with no confirmation.** Escape closes every
  converted window, so this is a decision about all of them, not one.

---

## What the agent can check without you  (audit, 2026-08-28)

NY4I asked: "confirm there are not any of the steps you added to this document
for me to check that you could have checked."

**The honest answer is that some of them were.** The harness in `test/ui` can
launch TR4W, enumerate every window and control, drive menu commands, type into
fields and read the log back. Anything in the list below should be run by the
agent BEFORE it reaches this file.

| Question                                  | Tool                                                       | Verified tonight                         |
| ----------------------------------------- | ---------------------------------------------------------- | ---------------------------------------- |
| Does a dialog open at all?                | `Invoke-MenuSmoke.ps1`                                     | 8 commands, 7 windows                    |
| Do Edit QSO's fields round-trip?          | `Invoke-FieldCheck.ps1`                                    | 69/69                                    |
| Is a menu caption, id or shortcut right?  | `Dump-Menu.ps1`                                            | caught About reading "Check for Updates" |
| Do accelerators collide?                  | `uTestAccelerators.Test_NoDuplicateKeystroke` (unit tests) | --                                       |
| Did a window lose a control, or its size? | `Dump-WindowTree.ps1` + `Compare-WindowTree.ps1`           | --                                       |
| Does a translated caption still fit?      | `Test-TextFit.ps1`                                         | --                                       |
| Does typing reach the right field?        | `Test-Typing.ps1`                                          | --                                       |
| Does Preferences show every section?      | `Test-PreferencesSections.ps1`                             | --                                       |
| Did the program write what it claims?     | read `target/tr4w.log`                                     | proved the Spanish menu is not ours      |

**What the agent still cannot do**, and what therefore belongs here: judge a
COLOUR or a layout by eye; confirm a caret is visible; see flicker or timing;
anything needing a radio (`tools/radiosim` or the TCI simulator can stand in for
some of it); anything needing a second station; and any question about whether
what appeared is CORRECT rather than merely present.

That distinction is the point. `Invoke-MenuSmoke` proves a window OPENS and says
so in its own output -- "Still NOT a check that any window is CORRECT" -- and
that gap is exactly what the rest of this file is for.

---

## Added 2026-08-28 (overnight) -- UNRUN

Everything below was built, linted, unit-tested and corpus-checked. None of it
has been on screen.

### A. New Contest dialog is now an LCL form  (`16ffc284`)

**This is the first thing the operator sees, and it changed shape** -- it
replaced 494 lines of `NewContestDlgProc`.

- [x] **The `.CFG` list** shows the TR4W directory, and **Browse...** opens the
  standard file picker and can reach a config somewhere else.

- [x] **Latest config file** still reopens the last one.

- [x] **OK stays disabled** until the callsign and every shown field are filled.
  Pick a contest and watch the prompt panel and any extra field appear.

- [x] **A contest that asks for a field** -- `NEWENGLANDQSO`, `WAG`, `POTA` --
  shows one row with the right label.

- [x] **The "I am in" box** on a QSO-party contest changes the prompts.

- [x] **The six `CATEGORY-*` drop-downs have labels.** They shipped unlabelled in
  the first pass; this is the fix.

- [ ] **Resize the window** -- list and fields follow, buttons stay bottom-right.

- [ ] **DECISION: should `ARRL10/160/DXCW/RTTY_ROUNDUP` pre-tick something?**
  Those four arms called `SendMessage(107, BM_SETCHECK, ...)`, and 107 is a
  control ID, not an HWND, so it addressed nothing and never worked. Dropped
  rather than reinvented: giving it a meaning now is a new decision, not a port.

### B. YesOrNo lost its HWND at 16 call sites  (`384d1895`)

- [ ] **Every Yes/No prompt still defaults to No.** Press Enter on "do you really
  want to clear the log" and it must NOT clear. This is the one to check
  because the failure is silent and one keystroke wide: `MessageDlg` focuses
  the FIRST button, so a naive port would have moved every destructive prompt's
  default to Yes. Confirmed once on the exit prompt; the other fifteen are
  unverified.

### D. Decisions waiting on NY4I, not bench items

- [ ] **The main window's start-up paint is still unexplained** -- grid lines,
  then data. The `WM_SETREDRAW` bracket was tried, made no visible difference,
  and was reverted when the lint showed it added three `wh[]` references to a
  surface being retired. Cause unknown; likely the control's own first paint
  before any rows exist, which redraw suppression cannot touch.

- [-] **15 unreferenced routines in `TF.pas` and `uDialogs.pas`** --  **[WITHDRAWN 2026-11-01: SelectColor/SelectFolder/SaveFileDlg/TR4W_OFNHookProc gone: rg finds none; uDialogs.pas:30-42 records removal.]**
  `SelectColor`, `SelectFolder`, `SaveFileDlg`, `TR4W_OFNHookProc` (referenced
  only from a commented-out `lpfnHook` assignment, so the hook is never
  installed) and others. Two automated attempts to remove them broke on a
  multi-line declaration and on an assembly block; they need a hand pass.

---

## Added 2026-08-26 (overnight) -- UNRUN

Five changes landed while NY4I was away. Three are visible and want an eye; two
are diagnostics that cost nothing to leave on.

- [ ] **The Windows menu and its accelerator now CLOSE a converted window.**
  Previously the second press did nothing: the toggle called
  `CloseTR4WWindow` directly, which destroys the handle behind the LCL's back
  on a form that is still Visible, so the widget set recreated it. Try it on
  **every** converted window, not just Stations -- the fix is shared
  (`RequestCloseTR4WWindow`). Also **Escape in the Stations window**, which had
  the same bug and appeared to do nothing.

- [ ] **Menu items no longer show their shortcut twice** -- File > Export >
  Cabrillo and Settings > Winkeyer. They read `Ctrl+Alt+B Ctrl+Alt+B` and so
  on. Check the keys still WORK as well as reading right.

- [x] **The WSJT-X indicator's font is smaller** so its text fits its cell --
  see the item in section 40. The layout is unchanged. [AGENT: But after that change, the font size of the call window is now smaller. That should be the same size as other items on the form like band, date, time, etc.]

- [x] **`DEBUG LOG LEVEL = DEBUG` now logs every configuration change**, both
  storage paths, and logs REJECTED values too. Change a few settings in
  Preferences and confirm the lines match what you did: [AGENT: Note this worked but I see two messages in the log as if we are going through this code twice: `28 Aug 2026 13:49:23.846 700244 [27180] debug TR4WDebugLog  - [Config] BAND MAP SIZE = 4 (stored in tr4w.json)`
  `28 Aug 2026 13:49:23.846 700244 [27180] debug TR4WDebugLog  - [Config] BAND MAP SIZE = 4 (stored in tr4w.json)`

        [Config] BAND MAP DECAY TIME = 20 (stored in tr4w.json)

- [x] **`DEBUG LOG LEVEL = TRACE` now logs every MODIFIED keystroke the
  accelerator hook sees.** This is the instrument for the Ctrl+Shift+0
  question in section 34 -- press it and look for
  `[InputHooks] key $30 ctrl=1 alt=0 shift=1`. **No line means Windows took the
  key before TR4W saw it.**

**Not in the bench queue because a gate now covers it:** the menu itself.
`test\ui\Dump-Menu.ps1` captures the live menu and `baselines\menu.json` is the
committed reference, so a menu row that changes caption, shortcut, position or
id shows up as a diff rather than needing to be noticed by eye.

---

## Waiting now (as of 2026-08-24)

**Sections 31-42 were added 2026-08-24 and are UNRUN.**  Section 37 is the
biggest of them: the entire main window display changed. NY4I confirmed
the dupe sheet window, the Stations window and the entry-field colours on the
bench that day, but was remote when the captions, the resize behaviours and
the band-change message landed -- so those are recorded here rather than
counted as tested.

**STILL UNRUN AND THE OLDEST ITEM HERE: the radio bench test (section 10).**
The 2026-08-20 commits were held for it and then pushed on 2026-08-21 without
it having happened, at NY4I's instruction. Nothing in the radio panel seam has
been exercised on hardware, and it had NEVER delivered an update before that
fix -- so section 10 is new behaviour, not a regression check.

**Bench run 2026-08-20 (NY4I).** Items 2 and 6 passed in full and are gone; the
numbering keeps its gaps on purpose, because commit messages cite these numbers.
Everything NY4I found is in **Findings** at the foot of this file -- seven of
them, F1 to F7, and F7 lands on a change from the same sitting.

### 1. Program message editor — Alt-P, pick a memory, Edit  (`d036b949`, `feb180f0`, `bede4637`)

Ctrl+P / Ctrl+A / Ctrl+C / Ctrl+D all insert their control characters, the saved
`.cfg` key is clean, and the Caption field greys for the "other messages" bank.
**Still open:**

- [ ] **&Edit** is enabled only in Phone mode, and only acts on a message naming
  a `.WAV`. [AGENT: Given the comment below, is this still a viable task to test. Also, you headline has test steps rather than a tasklist under the heading. This needs some more explanation.]
  **NEEDS REWRITE -- NY4I:** *"Given the comment below, is this still a
  viable task to test ... This needs some more explanation."*

~~An empty Caption REMOVES the key.~~ **Struck 2026-08-20 (NY4I):** "I see no
evidence of this nor would I want it to work that way." It was written from
reading the old code, not from behaviour, and it is not wanted -- so it is not a
defect and not a requirement. See finding F1, which is the real issue in this
area.

### 3. Window control dialog — Ctrl+Alt+M  (`f11a1093`)

It opens and lists the windows, and Cancel / Escape / the window button correctly
move nothing. The flash-on-selection check became **finding F2**, which is now
answered: the system menu NY4I saw is the accept path doing what it was always
meant to do, and it is the mechanism behind the item still open below. Still
open:

- [x] **OK** then lets you move the chosen window -- it pops the chosen window's
  SYSTEM MENU at its top-left corner (`WM_POPUPSYSTEMMENU`), and Move from that
  menu is how the repositioning happens. That is the design, in D7 too. ~~[AGENT - There is a weird artifact from Spanish. The move menu (or if I click on any TR4W top-left icon, shows me the choices in Spanish. I am NOT running in Spanish mode)]~~
  **RESOLVED 2026-08-28 -- not TR4W.** That is the WINDOWS system menu, and the
  log proves TR4W translated nothing on that run: `UI language: "en" from the
  operating system locale (en_US); that is the compiled-in language, so no
  catalogue is loaded`, then `UI language: none loaded`. With no catalogue
  applied the program cannot be the source of a Spanish word. Move / Size /
  Close come from Windows and follow the WINDOWS DISPLAY LANGUAGE, so the place
  to look is Settings > Language, not us.

- [ ] Moving the selection with the ARROW KEYS, without accepting, flashes the
  window and does nothing else. This is the half of F2 that is still a question. [AGENT: There is no way to move with arrow keys as when I press OK, the window control daughter menu appears and the arrow keys navigate in that menu (up and down).]
  **NEEDS REWRITE -- NY4I:** *"There is no way to move with arrow keys as
  when I press OK, the window control daughter menu appears and the arrow keys
  navigate in that menu (up and down)."*

### 4. Band plan editor — Preferences, More settings, the Edit... button  (`uBandPlanForm`)

**UNBLOCKED 2026-08-21.** The way in is an "Edit..." button on the two
band-plan rows in **Preferences -> More settings** -- captioned *Band Map Cutoff
Frequency* and *Frequency Memory*. Note it is NOT in Ctrl-J Settings, which is
where it used to be and where it was looked for; finding F3 records why.
Confirmed opening on the bench (NY4I).

**MOVED 2026-11-06 (issue 235):** More settings is gone. The button is now on
**Preferences -> Operating -> Bands**, below the band and mode rows, captioned
*Band plan (cutoff frequencies and memories)*. It opens the same editor, which
still saves its own whole section.

Converted from 33 generated edit boxes to a single `TStringGrid`.

**Confirmed 2026-08-21 (NY4I):** it opens from Preferences, it is resizable, the
headings are readable, the grid fills the window, and the position is remembered
across openings. **What is still unrun is everything that WRITES:**

- [x] It **opens** and shows one row per band with the three current values.

- [-] ~~Editing a cell and pressing **OK** writes `[BAND PLAN]` in `tr4w.ini` and  **[WITHDRAWN 2026-11-01: Struck-through; ANSWERED at 2870: band plan lives in tr4w.json, ini step out of date.]**
  the new values survive a restart.~~[AGENT: Nothing is suppose to write to the .ini so validate this is meant to be .json. You should also consider if this is something you can automatically test now that we figured out how you can run the program to test. IN fact, confirm there are not any  of the steps you added to this document for me to check that you could have checked.]~~

  **ANSWERED 2026-08-28 -- it is JSON, and this step is out of date.** The band
  plan lives in `uRadioConfigStore` (`settings/tr4w.json`); the ini's
  `[BAND PLAN]` section is READ once, by `uRadioConfigApply`, to migrate a
  station upgrading from an older build, and `uBandPlanForm` guards against
  falling back to writing it. So the check is: edit a cell, OK, and confirm the
  values land in **tr4w.json** and survive a restart -- nothing should appear in
  tr4w.ini.

- [ ] **Cancel changes nothing.**

- [ ] A cell left **empty or non-numeric is skipped** — that band keeps its old
  value rather than becoming 0.

**DECIDED 2026-08-19 (NY4I): the grid stays.** It cost **295 KB of binary**
(4734 -> 5029 KB, ~6%) because `Grids` is linked for the first time and nothing
else in TR4W uses it. Two standing rules pointed opposite ways — "limit
hand-coding of LCL components" against "assume every dependency has a cost" —
and the first wins here: one designed control instead of 33 generated ones, and a
dialog that keeps working when a band is added to `BandType`. Recorded so the
size is not re-litigated, and so the next unit that wants `Grids` knows it is
already paid for.

**Also worth knowing while testing:** the ROW does not decide the band — the
FREQUENCY does. Both loaders call `CalculateBandMode` on the value, so typing a
20m frequency into the 80m row updates 20m. That is pre-existing behaviour, not
new, and it surprised me enough while reading that it is worth surprising you
deliberately rather than accidentally.

### 8. Beacon monitor  (`uBeaconsForm`)

The NCDXF/IBP schedule window. **Opening it QSYs Radio 1 to 14100 kHz CW.**

The grid, the stepping diagonal, the ten mutually-exclusive buttons, the 14100
default and Escape all confirmed. **Still open -- both need a radio:** [AGENT - Simply the act of opening the beacons monitor window changes the radio frequency to the first monitor. That should not work that way--even though it may have in D7 too). I should have to take an overt act to start changing the radio frequency]

- [x] The highlighted beacon should agree with the schedule table at the foot of
  `src/uBeacons.pas` for the current UTC time.
- [x] **Pressing a button tunes Radio 1** to that frequency in CW.

### 9. Edit QSO  (`uEditQSOForm`) -- THE ONE THAT WRITES TO THE LOG

Double-click a QSO in the editable log, or reach it from Log Edit / Log Search.
**Work on a copy of a log.**

Confirmed 2026-08-20: it opens over its parent from all three routes, the date
field carries a full date and time, every field edits and lands, the four mult
flags / Name Sent / Inhibit Mults / Dupe are greyed, S&P / Deleted / X-QSO edit
and save, X-QSO still exports with its Cabrillo prefix, callsign typing updates
country / prefix / DX QTH, and note and skipped records behave.

~~[AGENT - Editing a QSO is changing the Operator field to just the first
character.]~~ **FIXED and verified by reading, 2026-09-03.** `uEditQSO` converts
through `WinAnsi`, zero-fills the array, bounds the copy and leaves room for the
terminator; the comment there records the original failure (`'NY4I'` stored as
`'N',#0,'Y',#0,...` and read back at the first `#0`). The commented-out
`GetDlgItemTextA` attempts left beside it are deleted -- NY4I: "I do not want
code that is commented so you trip on it and find it next time."

**THE SECOND HALF OF THAT NOTE IS STILL OPEN AND IS THE BIGGER ASK.** We have to
add a mechanism to check the fields in the qso record upon entry to the edit field is the exact same as when we leave except for the dirty field. In  the test log, I changed the contact for W1SSB and it updated operator to just N. The sanctity of a QSO is paramount] 
**FIXED 2026-08-28 (`1e53f410`).** `ceOperator` is `array[0..10] of AnsiChar`,
and the save did `Move(tempOperator[1], ..., length * sizeof(char))` with `char`
two bytes wide under `{$MODESWITCH UnicodeStrings}` -- so 'NY4I' was written as
`N`,#0,`Y`,#0,... and read back at the first #0 as `N`. Two more faults in the
same three lines: the zero-fill measured the value ALREADY in the record, so a
shorter name left the old tail behind, and nothing bounded the copy, so an
11-character operator wrote past the field. Worth knowing:
`Invoke-FieldCheck.ps1` reported 69/69 both before and after -- it proves a
value survives the CONTROL, and this was the write to the RECORD.

**Two defects came out of that pass -- F4 (the dialog is dirty before you touch
it) and F5 (a bad callsign is accepted). Still open:**

- [x] **Round-trip with no edits**: open a QSO, press Save, reopen. Every field
  should read back identically. Still the single most valuable check here, and
  **F4 has to be fixed before it means anything** -- a dialog that thinks it is
  dirty on open is not testing a clean round trip.
- [ ] **A LONG CALLSIGN SURVIVES.** **Cannot be tested by TYPING** (NY4I,
  2026-08-20: "It is not possible to enter a callsign greater than 12
  characters") -- and that is the design: `MaxLength` limits typing exactly as
  `EM_SETLIMITTEXT` did. The regression was on the LOAD path, so load one the
  dialog did not type: **import an ADIF holding a callsign longer than twelve
  characters** (e.g. `VP2E/W1ABCDE`), open the QSO, press Save, reopen, and
  confirm it is not shortened. Worth the trouble because it was silent log
  corruption.
- [x] **Deleted still sends a contactdelete** to UDP / the external logger.
- [x] **Cancel and Escape discard everything.** See F6 -- NY4I found Escape
  after a change does not prompt, and whether it SHOULD depends on the
  `CONFIRM EDIT CHANGES` question below, so treat these two as one item.
- [x] `CONFIRM EDIT CHANGES = TRUE` still prompts before saving.
- [x] ~~**Play** is enabled only when the QSO has an MP3 and the file exists;
  with no MP3 player configured it prompts to set one.~~ **WITHDRAWN
  2026-09-07: THE BUTTON IS GONE.** NY4I had already reported it could not be
  tested -- *"I do not even know where these would go or the name of one to
  test it"* -- and that turned out to be the answer rather than a gap: the
  built-in MP3 recorder is removed and recording moves to QSOCapture, so
  nothing writes the file this button expected. MakeMP3Filename built a path
  from the QSO's call, band and time -- a naming convention belonging to
  TR4W's own recorder, describing nothing an external recorder produces. See
  the commit that removed it for the future path (QSOCapture returning a
  filename for the contactinfo GUID).

**Not a defect, do not report:** the RST fields still refuse a minus sign. That
is deliberate and now has a written reason -- a negative "RST" is a WSJT-X dB
report, and the fix is separate received/sent SNR fields when the log moves to
contest.sqlite, not a wider RST. See the `uEditQSOForm.pas` header.

### 10. Radio panel updates now go through a posted message  (`uPanelUpdate`)

**NEEDS A RADIO.** No UI changed and no control moved -- what changed is HOW the
radio's reading thread reaches the Radio 1 / Radio 2 panels. It used to call
`SetDlgItemTextA` and `EnableWindow` directly across the thread boundary; it now
posts to the main thread, and identical consecutive values are dropped.

Everything below should look exactly as it did. The point of the list is that
"looks the same" is the pass condition, and any DIFFERENCE is the finding.

- [x] Open the Radio 1 panel (and Radio 2 on an SO2R setup). **VFO A and VFO B
  read the right frequencies and keep up while you tune.**
- [x] **RIT, XIT and SPLIT light up and go out as you toggle them on the rig**,
  with no lag you did not have before. These are the three that used to be
  written on every single poll; they are now only written when they change,
  so a stuck indicator is the thing to report.
- [x] **The active VFO highlight follows the radio** when you switch VFO A/B.
- [x] **Disconnect the radio** (pull the cable or stop the network rig): both VFO
  fields should clear.
- [x] **Close the panel and reopen it.** Everything should repopulate. This is
  the one genuinely new failure mode: the coalescing cache remembers what it
  last sent, and a panel that reopens BLANK and stays blank would mean the
  cache was not cleared with the window. It is cleared in `CloseTR4WWindow`.
- [x] Leave it open for a while with the rig idle. Nothing should flicker.
- [x] **THE PANEL'S TITLE NAMES THE RIG** -- "Radio 1 K4", not just "Radio 1"
  (NY4I, 2026-08-20). The label is `TC_RADIO1`/`TC_RADIO2` so it follows the
  UI language; the rig comes from `RadioName`, which the radio library sets
  when a definition is applied. **With NO radio configured it must read just
  "Radio 1"** -- `RadioName` is initialised to `TC_RADIO1` itself, so an
  unguarded concatenation would say "Radio 1 Radio 1", and that is the state
  the panel is most often opened in while setting a radio up. Check both.
- [ ] **Known limitation, not a defect:** the title is set when the panel OPENS.
  Changing the radio in the CAT dialog while the panel is up leaves the old
  caption until it is closed and reopened. Say so if that is worth fixing --
  There is no polling-thread restart -- a configuration change rebuilds the radio (`SetUpRadioInterface`), and that rebuild is where a refresh would go. [AGENT: While testing, I ran into an issue here... I changed the name of the K4Z to K40 in My radios. When I did that, the radio was removed from the active profile. I then selected the new name K4) from the drop-down for Radio 2, but received this error message - ![image-20260828141727836](C:\Users\toms\AppData\Roaming\Typora\typora-user-images\image-20260828141727836.png) So there are at least two issues. First, when I change the name of a radio in MY radios, that name should also be updated in the saved (and active profile). It would appear you are using the radio name as an id when it would make more sense to say use a GUID and reference it by index so these changes will just flow through once you just do an update on the profile drop-downs.  The second issue of course is the error dialog but the prior statement about a guid or some index besides the name could address that. On the subject of what this item discussed specifically, stale data is never good and should be updated as we change it so yes the name in the radio window and the main window should change.]
- [x] **The MODE labels beside each VFO still show the mode** (CW / USB / …).
  They moved house in the same sitting: they used to be created by the
  generic window opener in `MainUnit` with runtime geometry arithmetic, and
  are now built by `uRadio12` with the rest of the panel and found by
  control id. Verified structurally identical by `Dump-WindowTree` -- same
  197/36 and 197/61, same 55x23 -- so this is confirming they still get
  TEXT, which no dump can show.

**Worth knowing:** the radio thread no longer blocks waiting for the UI on these
writes -- `SetDlgItemTextA` across threads is a synchronous `SendMessage` and
held the poll thread until the main thread serviced it. It should if anything
poll more evenly now. That is a side effect of the change, not its purpose.

### 11. Window positions now live in `settings/tr4w.json`, not `settings/tr4w.pos`

**Why this needs a bench run at all:** the store itself is covered by unit
tests, but the part that reads and writes `tr4w_WindowsArray` is in `MainUnit`
and only runs in the real application. Nothing in the build exercises it.

**Do this in order -- the first step is the migration and it happens once.**

- [x] **Before starting, note where a few windows are** (Band Map, Telnet, the
  two radio panels) and confirm `settings tr4w.pos` exists and is 550 bytes.
- [x] Start TR4W. **Every window should come up exactly where it was.** This is
  the seed from the old binary file; if anything moved, the seed is wrong
  and nothing after this is worth testing.
- [x] **Move two windows somewhere obvious**, then exit TR4W normally.
- [x] **Open `settings  tr4w.json`.** There should be a `"windows"` section with
  one entry per window, keyed by NAME (`"BandMap"`, `"Telnet"`, `"Radio1"`
  ...), each with `left`/`top`/`right`/`bottom`/`visible`. The two you moved
  should show their new positions.
- [x] **The rest of the file must be intact** -- `radios`, `profiles`, `keyers`,
  `udpBroadcast`, the Cabrillo header sections. This is the one that would
  be expensive to get wrong: exit-save is the first caller in the program
  that saves ONE tenant, and the read-modify-write change exists to stop it
  wiping the others. Check the radio library is still there.
- [x] **`settings   tr4w.pos` should still exist, unchanged.** It is deliberately
  left in place and simply stops being read. Nothing writes it any more.
- [x] Start TR4W again. The two windows should be where you left them -- read
  from the JSON this time, not the `.pos`.
- [x] **Open Preferences, change something small, save.** Exit. The `windows`
  section must still be there afterwards: that is the same guarantee from
  the other direction.
- [x] **Minimise a window and exit.** Its saved rect should not become the
  `-32000` sentinel -- `FindAndSaveRectOfAllWindows` skips iconic windows
  and that logic is untouched, so this is confirming it still is.
- [ ] **Optional, if you have a second monitor:** put a window on it, exit,
  disconnect the monitor, start TR4W. Issue #739's recovery (clamp onto the
  nearest monitor, cascade) runs on the array after loading and is unchanged
  by this work, so it should behave exactly as before.

**Two things a failure here would look like.** A window at the top-left corner
means a rect read as (0,0,0,0) -- which is a LEGAL saved value, so nothing will
report it. A window back at its default position means its name did not match:
`WindowNames` in `VC.pas` is now the on-disk key, and a rename orphans a saved
entry silently.

### 15. Launching other programs now goes through one unit  (`07c55fa4`)

`WinExec`/`ShellExecute` were replaced by `uPlatformProcess` -- `RunProgram`
(TProcess, no guard) for programs the operator chose or we ship, and
`RunWindowsUtility` (the only WinExec left, inside a WINDOWS conditional) for
Windows programs. **Behaviour on Windows should be identical**; the point of the
list is that "identical" is the pass condition.

**THE THREE THAT CHANGED SHAPE, and so are worth trying with a path that has a
SPACE in it** -- they used to build `'"%s" "%s"'` by hand and now pass the file
as an argument, so quoting is no longer their problem:

- [x] ~~**Play** on a QSO in Edit QSO starts the configured **MP3 player**
  with the recording.~~ **WITHDRAWN 2026-09-07** -- same reason as the Edit QSO
  item above: the button no longer exists.
- [ ] The **DVK recorder** starts from the program-message editor with the file
  to record.
- [x] **Open in editor** (file preview, history.txt) opens the operator's
  `.txt`-associated program -- and still falls back to Notepad when there is no
  association.

**The rest should be unremarkable:**

- [ ] **Run server** starts `tr4wserver.exe`; **Ping server** pings it. [ AGENT: Confirm how you are pinging the server. When I did it, it tried ::1 so it grabbed the IPv6 address. We should ping the address set in the server address in the config.]
- [x] Calculator, Volume control, Recording control, Device manager, the
  date/time applet, a command prompt, and "show the log folder" all still open.
- [x] **MMTTY** starts with its `-t -s -u -r` switches. It stays Windows-only by
  decision (NY4I, 2026-08-21: not on macOS, and not on Linux either).
- [x] The **WINEXEC** function-key command still runs an operator command line,
  minimised as before.

**A FAILURE NOW SAYS SO.** WinExec's "less than 32 means it failed" was checked
at two of the seventeen old sites, so a mistyped path in the MP3 Player setting
used to do nothing at all with nothing in the log. Both routines log now -- so if
one of these does not start, `tr4w.log` should say why, and that line is worth
reporting.

**The decision that was here is DONE (NY4I, 2026-08-21):** `K6VVA_WK_DEBUG`
and the WinKeyer HTML debug facility are deleted -- *"we now have a wk_debug
extra flag"* -- and the program's last `wsprintf` went with them
(`fb26b49b`). Nothing to test: none of it had ever compiled.

### 16. One callsign validator: IsAGoodCall  (`d3d4d5b3`)

The three callsign REGEXES are gone -- `RX_CALLSIGN`, `RX_US_PREFIX`,
`RX_US_CALLSIGN` -- replaced by hand-written tests in `uCallSignRoutines`.
Measured over 234,467 real callsigns: four times faster than the pattern it
replaced and a strict SUPERSET of it (131 real calls it accepts that the regex
refused, none the other way). 254 of those callsigns are now a test fixture.

- [x] **Operator login** -- confirmed 2026-08-21 (NY4I). The only path whose
  behaviour genuinely changed: lower-case `w1aw` now takes the STRICT US check
  it used to skip, because the old `RX_US_PREFIX` had 'a' twice and no
  lower-case 'w'.
- [ ] **WSJT-X CQ decoding** (`uWSJTX.pas:557`) -- swapped from
  `IsValidCallsign` to `IsAGoodCall`. Marginal calls in the decode list are
  where a difference would show.

**If something looks wrong, the benchmark diagnoses it faster than a symptom
will:** `build\Build-Bench.ps1`, then run `test\bench\bench_callsign.exe` over
any list of callsigns -- it reports exactly which ones are accepted and refused,
rather than leaving us to infer it from behaviour.

### 17. The YCCC box -- the LPT half of this item is gone

The parallel port left TR4W on 2026-09-13 (`f2839f8c`). The YCCC SO2R+ box
(`uYCCCSO2R.pas`, a USB **HID** device) is a different transport and stays.

- [ ] **The YCCC SO2R+ box opens and switches.** HID, so a separate check.

### 18. Upgrading a 4.x station -- its settings arrive from `tr4w.ini`, once

Every setting lives in `settings\tr4w.json`. A 4.x `tr4w.ini` is read ONCE,
through the first-run conversion offer (`uLegacyIniPrompt`, which runs
`SeedMigratedCommandsFromIni` and `SeedBandPlanFromIni` in
`uRadioConfigApply`), and never consulted again. Run this on a machine with a
POPULATED 4.x `tr4w.ini` you can restore -- an empty ini proves nothing.

- [ ] **Accept the conversion, then restart.** Settings you had are in force
  and survive the restart -- try a drop-down (`ROW COUNT`), an integer
  (`AUTO-CQ DELAY TIME`), a check box and `DE ENABLE`.

- [ ] **`HOUR DISPLAY`, `RATE DISPLAY`, `DUPE CHECK SOUND`**: set each in
  Preferences, confirm it takes effect and survives a restart. [AGENT (NY4I,
  earlier): I am changing these but do not see any evidence of a change on the
  main window]

- [ ] **The band plan.** `tr4w.log` reads `[BandPlan] seeded N band(s) from
  tr4w.ini`, and the seeded values land on the RIGHT bands -- the seed
  re-derives each band from its frequency, the one thing that could put a
  memory on the wrong band. Then change one cutoff in the band plan editor, OK,
  restart: it sticks and shows under `bandPlan` in `tr4w.json`; a band with no
  values is ABSENT rather than three zeros. The band map still splits CW from
  phone on each band.

- [ ] **A contest wins over the station.** A contest `.cfg` carrying
  `FREQUENCY MEMORY` lines, or naming a Cabrillo category such as
  `CATEGORY-POWER`, is in force over the station's value.

- [ ] **Load a few real old contest `.cfg` files**: no "Invalid statement in
  config file" dialog, and no new `[Config] ... was REFUSED` lines.

- [ ] **Hand-edit one setting in `settings\tr4w.json`** and confirm TR4W
  honours it on the next start.

- [ ] **`tr4w.log` should be quiet.** `[ApplyStoredCommands] CFGCA refused "X"
  = "Y"` names a stored value TR4W would not accept. Worth one grep after a
  session.

- [-] **ACCENTED TEXT, IN A NON-ENGLISH CATALOGUE, AFTER TF.Format BECAME  **[WITHDRAWN 2026-11-01: TF C-sprintf facade/uCFormat gone 2026-09-14 (TF.pas:332 note); premise of WinAnsi->Format doubt removed. Spanish glance optional.]**
  PASCAL (2026-09-07). UNVERIFIED, AND I INTRODUCED THE DOUBT.**

  73 call sites in 27 units pass `PAnsiChar(WinAnsi(TC_SOMETHING))` as the
  FORMAT STRING to TF.Format. WinAnsi produces bytes in the machine ANSI code
  page, which was exactly right while TF.Format was Win32 wsprintfA.

  TF.Format is Pascal now, and uCFormat does `AnsiString(aFormat)` -- which
  tags those cp1252 bytes with DefaultSystemCodePage, i.e. UTF-8, before
  SysUtils.Format sees them. Whether the accented characters survive to the
  screen is NOT something the corpus or the unit tests can see: this is UI
  text, and the corpus compares ADIF and Cabrillo.

  **This is the exact bug class WinAnsi was written for** -- NY4I saw
  "Ultimo archivo de configuracion" with every accented letter doubled in
  Spanish on 2026-08-27.

  TO CHECK: run with a non-English catalogue (Spanish is the most complete)
  and look at any status line built with TF.Format -- the rate display, the
  QTC counter, the Telnet connect message. If they are mangled, the fix is
  probably that WinAnsi is now the WRONG call at those sites and they should
  pass the string straight through; that is a 73-site change and wants
  deciding, not guessing.

**Not a bench check, recorded so it is not lost:** serial-number padding is
DECIDED and NOT BUILT (NY4I, 2026-09-07) -- the width is the digit count of the
log's highest serial, so 142 QSOs export `001` to `142`. It changes exported
Cabrillo and ADIF and needs the corpus in front of it -- now issue #91.

### 22. Colors moved to JSON, and Ctrl-J is GONE

`uOption.pas` is deleted -- 960-odd lines, the last Win32 settings dialog. What
kept it alive was the Colors editor, which was never a Ctrl-J filter at all: it
was a different dialog wearing the same window, built from
`TWindows[TMainWindowElement]`, two rows per element, saved to `[COLORS]` in
`tr4w.ini`. Preferences now has a **Colors** page under Appearance.

**Why `[COLORS]` in the ini ever worked, which is worth knowing:** the config
loader is SECTION-BLIND. It reads every line of `tr4w.ini` in order regardless
of which `[SECTION]` heading it sits under. That is also what made the migration
exact -- the seed copies out of `TWindows` AFTER the load, so whatever the ini
said is already in force and there is no second parser to disagree with.

- [x] **Appearance -> Colors.** Fifty elements, each with a Text and a
  Background drop-down from the 18-color palette. Change one, OK, and check it
  repaints. Restart and check it stuck.
- [x] **Look at `settings\tr4w.json`** -- a `colors` object keyed by element
  name, values as SPELLINGS (`"YELLOW"`, not `15`).
- [x] **Your existing colors must survive.** On first run with an old
  `tr4w.ini`, the log should say `[Colors] seeded 50 element(s) from the loaded
  configuration` and the window should look exactly as it did.
- [x] **Ctrl-J.** Every menu route that used to open the old list -- Ctrl-J
  itself, Appearance, Colors, WinKeyer -- must open Preferences and nothing
  else. Nothing should open an empty list, and nothing should fail to open.
- [ ] **`QuickEditResponse` prompts still parent correctly.** They used to
  prefer `settingswindowhandle`, which only existed while the old dialog was
  open; that branch is gone and they parent to the main window. Trigger one
  (any prompt that asks for a value) and confirm it appears where it should.

**A stranding check that came out clean:** measured against comment-stripped
source there are ZERO live `csOld`/`csNew` rows -- every live row is `csOwned`,
`csJSON` or `csRem`. So no setting lost its only editor when Ctrl-J went. Six
rows LOOK like csOld in the raw file (`DISPLAY REFRESH`, `MULTIPLIER ITEM
WIDTH`, four `TAIL END *`), and all six are commented out.

**Counts that fell as a result:** ini writes 7 -> 6, ini reads 10 -> 8, Win32 UI
call sites 245 -> 236, non-UI platform 110 -> 107.

**What still touches `tr4w.ini`, and it is now only the seed path:** the
one-time readers that migrate an existing installation, plus three CFGCA rows --
`CLEAR DUPE SHEET` (an action trigger that must never persist) and `BAND` +
`SINGLE BAND SCORE` (contest-owned, going to the SQLite contest file).

### 23. TR4W offers to remove tr4w.ini -- once -- and the first resourcestring

Every station setting is in `settings\tr4w.json`. What remains of `tr4w.ini` is
a file read ONCE per installation to carry an existing configuration across, and
never again. So TR4W now asks, one time, whether to remove it.

**The wording states what has already happened before it asks for anything.** An
operator told "may I delete your configuration" reasonably says no; an operator
told "your settings have already been copied, this file is no longer read" can
answer the question actually being asked.

- [ ] **On a station WITH a `tr4w.ini`:** start TR4W. The prompt should appear
  once, after the window is up -- **and only when the first-run conversion
  offer was not declined in that run** (`FirstRunConversionDeclined`,
  `uProgramMain`): declining it leaves a `tr4w.json` of defaults, and offering
  to remove the ini then would offer to delete the only copy of the 4.x
  configuration. Say **No** -- it must not ask again on the next start, and
  `settings\tr4w.json` should carry `"keepLegacyIni": true`.
- [ ] **Then flip that back to `false` by hand, restart, and say Yes.** The file
  should be gone and a confirmation shown. **No `.bak` is made** -- that is
  deliberate ("There should not be any backups of the ini or anything else").
- [ ] **Restart again with everything you had set** -- radios, colors, band
  plan, DE ENABLE, auto-send count. All of it must survive the ini being gone.
  This is the real test of the whole migration and the reason to do it on a
  station you can restore.
- [ ] **Make the ini read-only and say Yes.** It should report that it could not
  remove it and carry on -- the file is ignored either way.
- [ ] **A station with no `tr4w.ini` must never see the prompt.**

**The corpus is the automated half of this.** The prompt sits AFTER the
`/EXPORT` Halt in `uProgramMain` for exactly that reason: a modal dialog in
headless mode would HANG every corpus run rather than fail it.

**First `resourcestring` in the program** (`src\uAppStrings.pas`). New dialogs
and message boxes declare their text there from now on, not as a `TC_` constant
in the nine per-language files. Nothing existing was converted -- that sweep
belongs with the translation work, not a feature commit.

### 24. WinKeyer -- the menu now lands on it, and an upgrading station gets its keyer back

**"Where did all those WinKeyer options go?" (NY4I, 2026-08-21).** Two separate
faults, and neither had lost a setting.

**1. The menu did not go anywhere in particular.** `RunOptionsDialog` has taken
a `CFGFunc` filter since Ctrl-J, and once every filter routed to Preferences the
parameter was ignored -- so Settings > WinKeyer opened Preferences wherever it
was last left. Every filter that names a page now maps to one:

| menu              | page                                         |
| ----------------- | -------------------------------------------- |
| Colors            | Appearance > Colors                          |
| Appearance        | Appearance                                   |
| WinKeyer          | **CW Settings** -- the keying-device library |
| Radio 1 / Radio 2 | Radios                                       |

- [ ] Settings > WinKeyer must land on **Hardware > CW keyers** (issue 264),
  with the keying devices list at the top. Pick the keyer, **Edit...**, and all
  seventeen options are there.
- [ ] Preferences search: type `winkey`. "WinKeyer and YCCC SO2R+ keyers" is
  listed with "CW keyers" at the right; choosing it opens Hardware > CW keyers
  with the list focused. Same for `WK`, `YCCC`, `keyer`, `switchpoint`.
- [ ] The nav tree shows Hardware > Radios, Rotators, CW keyers. CW Settings
  opens with the grey pointer line first, then Sending (Send CW ... key number)
  with no gap and nothing clipped. The CW keyers page shows its hint, then the
  pointer back to CW Settings.
- [ ] The Hardware page's longer introduction fits its 40 px label above the
  YCCC checkbox, including in a language where it wraps to three lines.
- [ ] Settings > Colors, Appearance, and the radio items likewise.

**2. The keyer LIBRARY was never seeded from the legacy settings, and this is
the real one.** The seventeen `WK` rows are `csJSON`, so an upgrading station's
WinKeyer settings were carried into the store and applied into `WinKeySettings`
-- the keyer KEYED correctly. But the editor does not read `WinKeySettings`; it
reads the device library, and nothing ever populated it. So every option was in
force and none could be seen or changed. Rotators already had this seed; keyers
did not.

- [ ] **On a station that had a WinKeyer configured before today:** start TR4W
  and look for `[Keyers] seeded "WinKeyer" from the legacy WinKeyer settings` in
  `tr4w.log`. CW Settings should then list one device.
- [ ] **Open it and check every value against what you had** -- port, keyer
  mode, sidetone frequency, weight, dit/dah ratio, lead-in, tail, first
  extension, key compensation, paddle switchpoint, and the six switches.
- [ ] **It seeds ONCE, into an EMPTY library only.** Restart again: there must
  still be exactly one keyer, not two.
- [ ] **A station that never enabled a WinKeyer must get an empty list** -- not
  a phantom device it has to work out how to delete.
- [ ] **Then key some CW.** The seed writes the device; `ApplyKeyerToWinKey`
  reads it back on the next start, so this is the round trip that matters.

**Note:** there is no "enabled" flag on a keyer DEVICE, deliberately -- whether
the WinKeyer is in use is a property of the PROFILE (`SetWinKeyerEnabled`). The
seed describes the device on the desk and nothing more.

### 26. The function-keys window is an LCL form -- TEST THIS ONE PROPERLY

**This window sends CW.** It is the first `tw_` tool window converted, two of the
three message-loop arms blocking `Application.Run` went with it, and none of it
is provable by build. Please give it a real session.

- [x] **F1 through F12 send.** Click each button and confirm the right message
  goes out -- this replaced `WM_COMMAND` / `BN_CLICKED` with `OnClick`, and the
  key code now comes from the panel's `Tag` rather than the control id.
- [x] **The CQ and S&P banks both show the right text.** Toggle mode and watch
  the captions change. `ShowFMessages` drives them now by setting `Caption`
  instead of invalidating an owner-draw.
- [ ] **AN AMPERSAND IN A CW MESSAGE.** Put `&` in an F-key message and check it
  shows as one `&`, not none and not two. `ShowFMessages` deliberately doubles
  it; a `TPanel` caption treats `&` the same way the owner-draw did, so the
  doubling had to stay. This is the single most likely thing to be wrong.
- [x] **Right-click a key** -> the one-item context menu, opening the editor on
  the RIGHT row. Do it while holding Ctrl and again holding Alt: the bank is read
  before the menu pops, precisely so releasing the modifier to click the menu
  does not change the answer (Issue #1001).
- [x] **Right-DOUBLE-click a key** -> the Alt-P editor straight to that row.
- [x] **The layout.** Twelve buttons across the width, with a wider gap after F4
  and after F8, resizing with the window. That arithmetic was copied unchanged
  from the Win32 `WM_SIZE` handler.
- [x] **Colours.** F1-F4 white, F5-F8 yellow, F9-F12 as before -- straight from
  the same `ButtonsColor` table the owner-draw read.
- [x] **The window still docks and remembers its place**, and closing it from the
  menu still works. It goes through the same `WndRect` / `WndVisible` /
  `CloseTR4WWindow` path as before; only the creation changed.
- [x] **Escape still belongs to the callsign field** while this window is open --
  it must NOT close the F-key row.

**What is left before `Application.Run` can replace the message loop:** the band
map's `WM_KEYUP` arm, and nothing else. That is the next piece of item 1.

### 27. Band map step 1: the model, before any form exists

**No UI change.** The band map is still the Win32 window; what changed is
underneath it. Design at `docs/BANDMAP_LCL_DESIGN.md` -- these are the three
defects that were provable by reading and did not need the new form.

- [x] **THE BIG ONE -- spots no longer vanish while the band map has focus.**
  Connect to a cluster, click INTO the band map list and leave it focused
  for a minute or two on a busy node, then click away (or into the callsign
  window). **Every spot that arrived while you were looking should now be
  there.** Before this change they were gone for good: `AddSpot` returned
  before inserting, and the buffer that was supposed to replay them was
  never filled by anything -- `InsertSpotBuffer` was declared, defined and
  never called. Cross-check against the telnet console, which always showed
  the lines.
- [x] **The rows still hold still while you have focus.** That half was
  deliberate and is kept -- the freeze now applies to the VIEW only. If the
  list starts re-sorting under the mouse, that is a regression.
- [x] **Ordinary spot flow is unchanged** -- new spots appear within about a
  quarter second, no more flashing than before, no less.
- [x] **The VFO cursor line still tracks the radio.** `uRadioPolling` used to
  set a global flag; it now calls `SpotsList.RequestRepaint`.
- [ ] **A logged QSO still turns its spot into a dupe**, and clearing the dupe
  sheet still un-dupes them.
- [x] **Deleting a spot** from the band map's context menu still works and the
  list is intact afterwards -- `Delete` had `try ... finally
  CriticalSection.Leave` with **no matching `Enter`**, so it released a lock
  it never took. Fixed here. This is the one item where a latent
  intermittent (two threads in the list at once) becomes less likely rather
  than visibly different, so there is nothing to see -- just confirm delete
  behaves.

**Added after the first bench attempt (NY4I, 2026-08-22 evening) -- the band map
showed nothing at all.** Three separate things, and the log settled all of them.

- [x] **BAND MAP ENABLE is RETIRED. Opening the window is what enables it.**
  `settings\tr4w.json` held `"BAND MAP ENABLE" : "FALSE"`, so
  `DisplayBandMap` refused every spot at the gate -- the log showed
  `BandMapEnable=0, BandMapWindowExists=1, FCount=49`: the spots were
  arriving and being thrown away. The cause is that one boolean was both the
  persisted setting AND the window's runtime flag, and `WM_DESTROY` wrote
  False to it -- so **closing the band map turned the feature off and the
  next settings save persisted that.** Opening Preferences to change the
  cluster re-applied the stored FALSE over the live TRUE.
  `BandMapEnable` is now a function returning
  `tWindowsExist(tw_BANDMAPWINDOW_INDEX)`, the command is `csRem`, and the
  Preferences checkbox is gone. **Test: open the band map -- spots should
  appear. Close it and reopen it, repeatedly, including with a trip through
  Preferences in between. It must never go dead again.** The stale FALSE
  still in your json is now ignored rather than obeyed.

- [x] **The Preferences band map page lost a row.** "Show the band map" is gone
  and everything below it moved up 38px. Check the page still reads
  properly and nothing is clipped or overlapping.

- [ ] **The log should be readable again.** 1,287 of the 9,810 lines in that
  run were `[DisplayBandMap]` trace, ~2,600 of them before the window even
  existed -- my regression: the repaint token stays raised until Display
  actually paints (deliberately, so spots that arrive while the window is
  shut are drawn when it opens), but with no window it never paints, so the
  250 ms timer called `DisplayBandMap` forever. The timer now returns early
  when there is no band map window, WITHOUT consuming the token. **Test:
  run for a few minutes with the band map CLOSED and confirm `tr4w.log` is
  not full of `[DisplayBandMap]` lines.**

- [x] **Minimise TR4W with the band map open and a busy cluster running.** The
  tool windows are owned popups, so Windows hides the band map with its
  owner -- and until now that hidden window still cost a full render four
  times a second. The refresh timer now skips a window that is not visible.
  **Restore TR4W and every spot that arrived while it was down should be
  there immediately**, because the skip does not consume the repaint token.
  Watch for a stale or empty list on restore; that would mean the token
  logic is wrong.

- [ ] **Leave it minimised over a decay boundary** (a minute or more). Spot ages
  must still advance -- `DecrementSpotsTimes` is model work and still runs;
  only its repaint waits. Restore and check the age colours are right, not
  a minute behind.

- [x] **DX cluster logging was never broken** -- 56 `[Telnet RX]` lines were in
  that log, buried under the flood above. Nothing to fix; noted so it is
  not re-reported.

**What did NOT change, deliberately.** `UpdateSpotsMultiplierStatus` still runs
on the paint path -- a CTY prefix resolution per spot per repaint. Moving it
needs the full list of places the LOG changes, and `UpdateWindows` demonstrably
covers QSO-logged, log-load, network QSO and WSJT-X but **not** an in-place log
edit. A stale multiplier flag shows up as WRONG SCORING, not as an error, so it
is carved out into its own change rather than guessed at here.

### 30. Application.Run -- THE PIVOT.  Test this harder than anything before it

**TR4W no longer owns its message loop.** `Application.Run` does. Nothing in
this section is provable by a build, a lint or the corpus -- the corpus runs
headless `/EXPORT`, which halts before any GUI init, so it says nothing at all
about this change. Branch `phase3c-application-run`.

**If something feels wrong that is not listed here, say so before rationalising
it.** Four things that used to be answered by one loop are now answered by four
different LCL mechanisms, and the failure mode of each is "a key does nothing"
rather than a crash.

- [x] **EVERY MENU SHORTCUT.** All 101 rows of `ACCELERATORS` are now matched in
  an `AddOnKeyDownBeforeHandler` instead of by `TranslateAccelerator`. Work
  down the menus and try the ones you actually use -- Alt+X, Ctrl+J,
  Ctrl+Alt+B, Ctrl+W, the Ctrl+Shift+digit window shortcuts. A shortcut that
  does nothing is the signature failure of this change.

- [ ] **The same shortcuts with a TOOL WINDOW focused.** The handler is
  application-wide by design, so Ctrl+Shift+1 should open the dupe sheet
  whether the callsign field or the band map has focus.

- [ ] **Ctrl-C / V / X / A / Z in the DX cluster command field** must still
  paste and copy, NOT fire Execute Config File or Clear Mult Sheet
  (issue #23). This is now a focus test rather than a message test. [AGENT - ESCAPE closes the dxcluster without confirmation - That is too drastic a step. We should confirm. Also note that after this, when I selected the now unchecked DX Cluster from the Windows menu, the window did not appear. But looking at the menu again, it was checked. I had to select a now-checked DX cluster option for it to appear. Selecting the unchecked DX cluster in the window should ALWAYS show the window - goes for all others too]

- [ ] **The numeric keypad as CW memories**, if you use them
  (`KEYPAD CW MEMORIES`). They fire whatever has focus.

- [ ] **F10 does nothing**, as before -- it must not open the menu bar.

- [ ] **QUICK QSL -- and a deliberate narrowing.** `\` and `=` still QSL while
  you are typing a callsign. They no longer fire while a TOOL WINDOW has
  focus: type a call, click into the band map, press `\` -- nothing happens,
  where it used to QSL. There is no application-wide KeyPress hook, and
  QuickQSL does nothing unless the call window has text, so it moved onto
  the entry fields. **If that edge case matters to you, say so** -- it can
  come back, at the cost of a `VkKeyScan` and a keyboard-layout assumption.

- [ ] **A fault must not take the session down.** The recovery wrapper is an
  `AddOnExceptionHandler` now, same 10-faults-in-a-minute limit. Hard to
  provoke deliberately; what to watch for is the OPPOSITE failure -- a
  dialog appearing for an exception that used to be swallowed and logged.
  `grep AppException tr4w.log`.

- [ ] **Shutdown.** `HamScoreShutdown` moved into `tr4w_ShutDown`. It was a
  `finally` below the message loop, which **could never have run**: TR4W
  exits through `ExitProcess`. So this is the first build in which the
  HamScore uploader is actually stopped cleanly -- watch for a hang or a
  delay on exit that was not there before.

- [x] **Long soak.** Leave it running for a session with a cluster connected.
  The loop had its own fault recovery for a reason.

**Still Win32, deliberately, and not blocked by any of this:** the main menu is
a raw `HMENU` of ~181 items attached with `SetMenu`, and it stays one. The
accelerator handler reads the same `ACCELERATORS` table the menu captions are
drawn from, so there is still ONE source of truth and the menu can convert on
its own schedule rather than being dragged into the pivot.

### 31. The dupe sheet is a form and a TDrawGrid  (`uDupeSheetForm`)

NY4I confirmed the window itself on 2026-08-24 -- both sheets open, refill on a
worked station, follow band and mode, resize and close on Escape. **What is
below was changed AFTER that sitting and he was remote when it landed, so none
of it has been seen.**

- [ ] **The title, on a REOPEN.** Open a dupe sheet, close it, open it again.
  Both times it must read `Radio 1 Dupesheet - 10m-CW`. The first open was
  always right; it was the second that showed the bare menu text (NY4I:
  "it just states Radio 1"), because `OpenTR4WWindow` wrote the native title
  with `SetWindowTextW` behind the LCL's back and left `Caption` stale, so
  the form's own later assignment of the SAME string was compared, found
  equal, and dropped.
- [ ] **The stations window title, on a reopen** -- same fix, same mechanism,
  and it had the identical latent bug: "Stations in CW mode" is likewise the
  same string every time it is set. Must not revert to the menu text.
- [ ] **Every other converted tool window still gets its caption.** The fix is
  in the GENERIC opener, so the band map and the function-keys window take
  the new path too. They must still be titled from the menu.
- [ ] **Two dupe sheets at once, both correct.** This is the first converted
  window with more than one instance. Open both, work a station on each
  radio's band, and check each sheet shows ITS radio's calls with ITS radio
  in the title.
- [ ] **Retirement of `COLUMN DUPESHEET ENABLE`.** Setting it in a `.cfg` or
  `tr4w.ini` must still LOAD WITHOUT AN ERROR (it is a retired command, `uCFG.RETIRED_COMMANDS`)
  and must have no effect. It must not appear in Preferences. `tr4w.json`
  may still hold the key from before the retirement; that is inert.

**Not asking whether it opens** -- see the note at the head of this file.

### 35. Super Check Partial is a form, and the dupe sheet moved under it  (`uMasterForm`, `uCallGrid`)

**Neither has been seen since this change.** The dupe sheet WAS confirmed on
2026-08-24 (section 31) and was then refactored onto the shared grid -- now
`TFlowGrid` (`uFlowGrid.pas`) -- so its confirmation no longer covers the code
that runs. Re-check both. The SCP cell buffer underneath was rebuilt on
2026-10-17 (pointer audit P7, `24f336c2`), which "SCP fills as you type" now
covers too.

- [x] **SCP fills as you type.** Type three or more characters of a callsign
  with the SCP window open; partial matches appear. Fewer than
  `SCP MINIMUM LETTERS` shows nothing, and the window hides itself when the
  callsign is too short, exactly as before.
- [x] **Dupes are painted and the text inverts.** A partial match already
  worked on this band and mode must show in `SCP DUPE COLOR` with white
  text; everything else plain on the window background.
- [ ] **IT STOPS AT WHAT FITS AND DOES NOT SCROLL.** That is the old behaviour
  (`MaxItemsInMasterListBox`), now `TFlowGrid.LimitToVisible`. Make the
  window small with a common partial like `K1` and confirm it fills and
  stops rather than growing a scrollbar. Then make it BIG and confirm more
  matches appear -- the capacity is asked for, not cached, so a resize must
  change how many the next keystroke shows.
- [ ] **Opening SCP with `SCP MINIMUM LETTERS` at 0 still sets it to 3.** A
  config write from a window-open; kept as it was, flagged as a shape not to
  copy.
- [ ] **The dupe sheet still behaves as it did in section 31** -- both sheets,
  refill on a worked station, follow band and mode, reflow on resize.
- [ ] **The two windows read the same way.** SCP, the dupe sheet and the band
  map all flow DOWN THEN ACROSS now. Confirm none of them reads across-then-
  down, which would be the one arithmetic slip this extraction could hide.

### 36. All five remaining-multiplier windows are forms  (`uRemMultsForm`)

One dialog procedure served `tw_REMMULTSWINDOW_INDEX` and the four fixed-type
windows; there are five instances of one form class now. **None seen.**

- [x] **Open all five.** Remaining mults, and the DX / zone / domestic / prefix
  windows. Each must show ITS OWN multiplier type, and the generic one must
  follow `RemainingMultDisplay` when you swap it (Alt-M or the menu).
- [ ] **Worked multipliers fade, needed ones are plain.** In `HILIGHT` mode all
  multipliers are listed and worked ones are gradiented to white with white
  text. In `ERASE` mode only NEEDED ones are listed at all. `NONE` empties
  the window.
- [ ] **THE FADE COLOUR IS A QUESTION FOR YOU.** The original picks it with
  `tr4wColorsArray[tr4wColors(Ord(rmt))]` -- the MULTIPLIER TYPE's ordinal
  used as a colour index, so a faded prefix and a faded zone differ for no
  stated reason. It is reproduced exactly rather than "fixed" unseen. Say
  whether the colours are meaningful to you or whether they should become
  one deliberate colour.
- [ ] **Clean sweep.** When every multiplier is worked, the congratulations
  message takes the window.
- [ ] **Column width follows SHOW DOMESTIC MULTIPLIER NAME** on the generic
  window (wider when names are shown or the contest does prefix mults).
  **It does NOT on the other four** -- they were given the base width once
  at creation and never followed the setting. That inconsistency is
  preserved; tell me if it should not be.
- [x] **Work a multiplier and watch it fade without reopening the window.** The
  text and the worked flag are resolved at PAINT time, not at rebuild, so
  this is the check that the resolution seam is wired.
- [ ] **The zone window numbers from 1, except EUHFC which numbers from 0.**

### 37. THE MAIN WINDOW'S FORTY-TWO ELEMENTS ARE LCL CONTROLS — test this like section 30

The single largest visible change of the conversion. Every static on the main
window -- band, mode, frequency, rate, totals, the status indicators, the radio
rows -- was a Win32 STATIC painted by TR4W's own WM_CTLCOLORSTATIC handler.
They are LCL TPanels now and they paint from their own properties. **Nothing
below has been seen.**

**If something on the main window is the wrong color, blank, mispositioned or
the wrong size, this is the change that did it.**

- [ ] **Everything is there, in the right place, at the right size.** Compare
  against a screenshot of the previous build if you have one. The positions
  come from the same TWindows[] table and the same `ws` arithmetic; the
  FONT is now built from the same three numbers instead of an HFONT, and a
  wrong sign on the height would show as visibly larger text.
- [ ] **The sunken borders.** defStyle carries SS_SUNKEN and that is
  `BevelOuter = bvLowered`. With `NO BORDER = TRUE` they should be flat, as
  before.
- [ ] **The QSO number's bigger font.** It is the one element with its own --
  Lucida Console, ws+3. FW_EXTRABOLD has no LCL counterpart and is now
  fsBold; say if it reads lighter.
- [x] **The auto-send arrow.** Down arrow, and it MOVES as the character count
  changes. Set `AUTO SEND CHARACTER COUNT` above 0 in CW.
- [x] **THE FIVE LIVE COLOURS.** These were re-evaluated on every repaint by
  DrawWindows and are now pushed when the state changes. Each needs
  exercising:
  - **PTT** goes red on radio 1, yellow on radio 2, while transmitting.
  - **WSJT-X** green when connected, red when not, and the element hides
    when WSJT-X goes away.
  - **Dupe info** takes its state colour when Alt-D reports a dupe, and
    clears.
  - **Radio 1 / radio 2 rows** turn the alert colour when that radio
    disconnects and back when it reconnects. **This one has no text write
    behind it** -- it rides on a new main-thread job (mtRadioAlertColors),
    so it is the most likely of the five to be missed.
- [x] **The frequency display tracks the radio.** It is written from the
  POLLING THREAD and now travels through uPanelUpdate's coalescing queue
  (puElement) rather than SetWindowTextW on a handle -- because an LCL
  control paints from a property and a handle write would leave it stale.
  Watch it follow the VFO continuously, and go blank on disconnect.
- [x] **Colour scheme changes still reach the main window** (Preferences ->
  colours). RefreshMainWindowColors pushes the elements now.
- [x] **THE INITIAL EXCHANGE FILLS.** With `INITIAL EXCHANGE` set to Zone, type
  a callsign and the zone must appear in the exchange field. Found broken on
  the bench 2026-08-24 (NY4I: "I enter AF4O, the zone in the exchange is
  not displayed... That was working earlier") and fixed the same evening:
  `SetMainWindowText(mweExchange, ...)` reached a nil panel, because the
  creation loop skips `mweiStyle <= 2` and the entry fields are TEdits, not
  panels. Two siblings were dead the same way and are worth checking too:
- [ ] **The exchange field CLEARS when the operating mode changes** (Ctrl-Enter
  between CQ and S&P with something typed in it).
- [ ] **WAE QTC puts the callsign into the call field** (`LOGWAE:177`), if you
  run WAE.
- [x] **Greying still works:** the inactive radio's row in two-radio mode, the
  WinKey indicator, and the quick-display FLASH (which is
  still an enable/disable toggle -- see LOGWIND).

### 38. Injected keystrokes are deferred calls now

Each was a PostMessage into an entry field, and the POST was doing real work --
deferring the action until the current message finished. That deferral is kept
through Application.QueueAsyncCall; what went away is the synthetic keystroke.

- [ ] **The trailing space in the exchange field** (space bar at the end of an
  exchange that does not already end in one).
- [ ] **MMTTY double-click pastes a callsign into the call field AND FOCUSES
  IT.** The focus half never worked: the old code posted WM_SETFOCUS, which
  tells a window it has gained focus rather than giving it focus. If the
  caret now lands in the call field where it did not before, that is the
  fix, not a regression.

### 39. The WSJT-X indicator is driven by domain state  (`uWSJTXState`, `uStateBridge`)

First slice of the domain layer -- one boolean, one writer, one indicator,
chosen because it proves the whole path with almost nothing to get wrong. The
listener thread no longer names a widget.

- [x] **Start WSJT-X: the indicator appears and goes green.**

- [x] **Stop WSJT-X and the box stays RED. FIXED 2026-08-26, wants a look.**
  It used to disappear entirely, which NY4I reported and which was the same
  defect as the box staying red while the link was up: the indicator tracked
  the LINK when it should track the SETTING.

  **The rule now: `WSJT-X ENABLED = TRUE` shows the box, always. Its COLOUR
  says whether the link is live -- green connected, red not.** Disabled
  hides it. NY4I settled it: *"the normal user is not in development mode --
  wouldn't the red indicator show that. We should put WSJTX in that box
  regardless if it is red or green."*

  That also closes the old open question of how long red shows before it
  hides: while enabled, it does not hide.

  **It earns its keep immediately.** A wrong multicast group in WSJT-X
  reaches TR4W as complete silence -- the join succeeds and nothing ever
  arrives (this is exactly what happened on 2026-08-26). Under the old
  behaviour the only sign was a box that was not there, which is
  indistinguishable from the feature being off. Red says it.

  **Check:** enabled with WSJT-X down -> red box; start WSJT-X -> green
  within a heartbeat (~15 s) with no radios needed; untick WSJT-X ENABLED
  in Preferences -> box goes immediately, not at the next heartbeat.

- [x] **Start TR4W with WSJT-X ALREADY RUNNING.** A heartbeat can arrive before
  the main form exists; InstallStateBridge brings the view into line once at
  install for exactly that case, and it is the half most likely to be wrong.

- [ ] **It does not flicker.** A heartbeat arrives every few seconds and setting
  the state to what it already holds must notify nobody.

- [x] **DISABLE WSJT-X IN PREFERENCES AND THE BOX GOES OUT. CONFIRMED
  2026-08-24 (NY4I): "restarted it, box goes out now."** First bench
  confirmation of the domain layer -- state object, notification, bridge and
  view, end to end.
  Original report and fix: Found on the bench
  2026-08-24 and fixed the same evening: `Stop` closed the sockets without
  telling `WSJTXState`, so the indicator stayed GREEN with nothing behind
  it. The state is cleared in `Stop` now, before the sockets close and
  outside the `started` guard. **Re-enable and confirm it comes back green
  when the first heartbeat arrives -- not the moment the server binds.**

- [x] **Saving Preferences with WSJT-X disabled no longer logs
  `JoinMulticastGroup called but UDP server not active`.** It fired on every
  Save. A warning that appears during correct operation is one people learn
  to ignore.

  - [x] **DONE 2026-08-26 -- config changes are logged at DEBUG.** NY4I:
    *"it would help if we are running DEBUG or higher to log when a command
    is changed."* Both storage paths report, which matters because they are
    not one path: `SetCFGCommandValue` covers the ini rows and
    `TStoredSetting.TrySetText` the 226 in `tr4w.json`. A line in only one
    would have answered the question for a fraction of the settings and
    said nothing about the rest.

        [Config] BAND MAP DECAY TIME = 20 (stored in tr4w.json)
        [Config] SCP MINIMUM LETTERS = 99 REJECTED -- not applied, not stored

    **The rejection line is the half worth having.** A value CheckCommand
    refuses was previously discarded with nothing anywhere to say why, so a
    setting the operator typed could simply vanish. DEBUG rather than INFO
    because one OK on a Preferences page can write dozens of rows.

- [x] **The WSJT-X indicator was too narrow for its own text. FIXED
  2026-08-26, WANTS A LOOK.** NY4I: *"The WSJTX letters are too big for the
  field."*

  Not the font -- the FIELD. `mweWSJTX` was declared `mweiWidth: 03` and the
  text written into it is the literal `'WSJTX'`, five characters
  (`uStateBridge.pas:106`). It never fitted.

  **SMALLER FONT, NOT A WIDER CELL** -- NY4I's call, 2026-08-26. Widening it
  (tried first, reverted) pushed `QSO B4` from x=11 to x=13, and moving a
  row of the main window that is otherwise exactly where it has always been
  is a bigger change than the defect. **The geometry is untouched.**

  The size is DERIVED, not picked: the same base every other element gets,
  scaled by cells-over-characters (3/5), with a floor of 8. So it tracks
  the operator's FONT SIZE setting and the window scale rather than being
  right at one size and wrong at every other.

  **Confirm by eye**: start with WSJT-X running so the indicator shows.
  Check it fits, that it is still readable, and that it still looks right
  at a different FONT SIZE. No automated gate covers main-window element
  geometry -- `Lint-FormOverlap` only sees designed `.lfm` forms, and these
  elements are a table in `VC.pas`.

### 40. Two multi-op message-loop defects fixed, and the silent drop now reports

`uNet.pas`. Multi-op only -- **not** the DX cluster; those are unrelated
subsystems and the only place they touch is the spot-forwarding call fixed
below. Needs a real multi-op session; nothing automated reaches any of it (there
is no `uNet` test at all).

- [ ] **A spot announced by another operator still reaches the cluster**, and
  **the QSO behind it in the same segment still arrives.** The spot arm
  advanced by 264 bytes for a 48-byte message -- an overshoot of 216 -- so
  one network-forwarded spot desynchronised the rest of that buffer. This is
  the fix most likely to be observable.
- [ ] **When one station drops off the network, the others' QSOs still arrive.**
  The disconnect arm overwrote the recv byte count with a client index, so
  the loop exited early and discarded whatever followed the notice.
- [ ] **Watch `tr4w.log` for `[Net] Unrecognised message id`.** New. If it never
  appears, the framing is holding. **If it does, capture the log** -- it
  names the id and the offset, and it is the first evidence this program has
  ever produced for a class of loss that was previously invisible.
  **Not a defect, do not re-report:** `NET_MESSAGESTATE_ID` is sent and received
  only under `{$IF OZCR2008}`, and that is `False` -- so no shipping TR4W emits it
  and the missing receive arm cannot fire. It was briefly reported as live during
  this session and that was wrong: the `SetTimer` that would arm it is inside the
  same conditional (`uCWKeyerCPU.pas:87`). The residual hazard is cross-build
  only -- `tr4wserver` relays the id ungated, so a client compiled WITH the switch
  would feed standard clients something they cannot advance past.

### 42. Accelerators no longer reach past a modal dialog

Found on the bench 2026-08-24 (NY4I): with a dialog open, ESC did not close it
and the main window reacted instead; TAB turned the exchange field green, which
is search-and-pounce.

ESC and TAB are both accelerators (`uAccelerators.pas:170` -> `menu_escape`,
`:174` -> `menu_spmode_ortab`), and `Application.NotifyKeyDownBeforeHandler`
fires for EVERY `TWinControl` in the application -- so the hook matched them on
a dialog's controls, posted `WM_COMMAND` to the main window, and swallowed the
key. Suppressed now while a modal form is active.

- [ ] **ESC closes a dialog** and the main window does NOT react. Try several:
  Preferences, Edit QSO, Send Spot, the message editor.
- [ ] **TAB moves between controls inside a dialog** and does NOT put the main
  window into search-and-pounce.
- [ ] **ACCELERATORS STILL WORK FROM A MODELESS TOOL WINDOW.** This is the half
  that must not have been broken by the fix: with focus in the band map,
  stations, a dupe sheet, SCP or a remaining-mults window, Alt-B / Alt-V and
  the other accelerators must still fire. The guard is on MODAL forms
  specifically, not on "any form that is not the main window", because tool
  windows are separate forms too.
- [ ] **And they still work from the main window itself.**

---

### 44. The radio panels are LCL forms -- and colour used to mean state

Converted 2026-08-25.  Everything here needs a rig on the bench; none of it is
provable by the unit tests, the lints or the corpus.

- [ ] **Both VFO rows track the rig**, on Radio 1 and Radio 2, and the
  **RIT figure** and **both mode labels** with them.  These five writes were
  raw cross-thread `SetDlgItemText` / `SetWindowText` until the commit
  before this one; they now travel through `uPanelUpdate`.
- [ ] **The INACTIVE VFO row is greyed.**  102/104 really do mean
  enabled/disabled, and a `TLabel` greys natively.
- [ ] **RIT / XIT / SPLIT go YELLOW when the rig has them on.**  THIS IS THE
  ONE TO WATCH.  The dialog got the colour by returning a yellow brush from
  `WM_CTLCOLORSTATIC` for an ENABLED control, so `EnableWindow` was doing
  two jobs at once -- recording the rig state AND colouring the label.  An
  LCL label has no such coupling, so the flag is explicit state now and the
  colour follows from it.  Behaviour-preserving, and no compiler can check
  that claim.
- [ ] **The ACTIVE radio's panel is tinted light blue**, and the tint MOVES when
  the active radio changes.  That was two `InvalidateRect` calls in
  `LOGSUBS1` making `WM_CTLCOLORDLG` run again; it is
  `RadioPanelsRefreshActive` now.
- [ ] **The status line still shows connection failures in red** -- the
  `AUTH FAILED` path in `uRadioPolling`.
- [ ] **Both panels remember their position** across a close and reopen, and
  across a restart (the `BoundsRect` fix, section 43).
- [ ] **Escape closes each panel**, which a `DialogBox` gave away free.

**Watch the poll cost.**  `PostPanelEnable` coalesces on (panel, control id) and
the RIT/XIT/SPLIT posts run on EVERY poll, at rates down to 10 ms.  A steady
state should cost nothing.  If the UI feels heavy with two rigs polling fast,
that is the first place to look.

---

### 45. The multi-op link runs on Indy -- NEEDS A SECOND STATION

Converted 2026-08-25.  **This is the one section in this file that cannot be
tested solo**, and the one where a regression costs somebody else's log.

- [ ] **Connect to TR4WServer**, with the right password.  The handshake moved
  into TNetClient.Connect: ten bytes of password, then a four-byte
  acknowledgement.  The `Sleep(200)` that used to sit between them is gone --
  a blocking read waits properly.
- [ ] **A WRONG password still says so.**  The server answers 'PASS' and the
  operator gets TC_CONNECTTOTR4WSERVERFAILED, as before.
- [ ] **Two stations logging at once**: QSOs, mults, serial numbers, the station
  status list, intercom messages and spot forwarding.  Every message arm is
  byte-for-byte the code that ran before; what changed underneath is only how
  the bytes arrive.
- [ ] **Pull the network cable.**  The link drop now arrives as an EVENT from the
  reader thread rather than as a zero-length recv, and auto-reconnect still
  runs off the window's WM_TIMER.  Confirm it reconnects.
- [ ] **Close the network WINDOW while connected, and keep logging.**  This is
  the whole point of the change: the window used to BE the socket's event
  sink (WSAAsyncSelect posted WM_SOCK_NET to it), so it could not be closed
  or converted.  The link must now be entirely independent of it.
- [ ] **Watch tr4w.log for `[Net] stream desynchronised`.**  It should never
  appear.  If it does, the buffer was discarded to resynchronise and
  something upstream sent an id this build does not know.

**What to watch hardest: partial records.**  A read can end mid-message, and the
tail is now KEPT and completed by the next read instead of being logged and
dropped (bench queue 40 asked for exactly this).  That is a fix, but it is the
kind of fix that shows up as a rare, weird QSO if it is wrong.

---

## Findings — bench run 2026-08-20 (NY4I)

Defects found while working the list above. **A finding is not a checklist item.** They
are written down here rather than in the checklists because a checklist item is
a question and these are answers.

### F1 — a stray character appears before a message with a blank caption — **ANSWERED: the command delimiters; PARKED behind the JSON/F-key rewrite**

**Seen:** F5 saved with the command `EXCHANGERADIOS` and **no caption**. The
function-key display shows *"a random character before the word
EXCHANGERADIOS"*. With a caption present the command is fine.

Screenshot: `C:\Users\toms\Pictures\Screenshots\Screenshot 2026-08-20 112902.png`

**ANSWERED 2026-08-21: it is the command delimiters, drawn raw. It is NOT the
length-byte bug, and it is NOT new.** The suspicion below was that "a random
character" is the signature of a length byte read as text, because this area had
produced exactly that once (`CQ CW MEMORY F5<A4><AE>6w=`, an unterminated
`ShortString` read past its length). It is not the same defect.

A message is STORED with its control characters in it. A command is bracketed by
`ControlC`/`ControlD` -- `<03>EXCHANGERADIOS<04>` is how `tr4w.ini` spells it,
and `CfgCmd.SniffOutControlCharacters` turns that spelling into the two real
bytes on load, which is what `uProcessCommand.FoundCommand` then parses.
`uFunctionKeys.ShowFMessages` puts the STORED string on the button
(`uFunctionKeys.pas:319`/`:323`), so both delimiters are drawn, each as a
missing-glyph box. The screenshot shows one before the word and one after.

A caption hides it because the caption is displayed INSTEAD of the message, so
the blank-caption path is not a length-zero read going wrong -- it is simply the
only path that shows the message itself. The D7 tree's `uFunctionKeys.pas` does
the identical thing, so this is original behaviour, not a port regression.
`uAltP`'s message column (`uAltP.pas:312`/`:316`) has it too.

**PARKED, deliberately, and not fixed (NY4I, 2026-08-21):** the function-key
messages are moving to JSON and the way commands are processed is being redone.
The control characters ARE the storage format, so a display-side strip written
now is thrown away by that work -- and worse, it would hide the question the
rewrite has to answer, which is how a command should be represented once the
message is no longer a byte string with markers in it. Park it there.

Note this also settles the struck checklist item in section 1 -- the question was
never whether a blank caption should REMOVE the key; the character it renders was
typed, just not by the operator.

### F2 — the window control dialog opens a system menu instead of flashing — **ANSWERED: that menu is the accept path, by design**

**Seen:** *"Selecting a window here activates the window but opens the menu with
maximize, minimize, close, etc."*

**ANSWERED 2026-08-21: the system menu is the ACCEPT path, and it is the
original design.** It does not come from the dialog and it is not the flash.
Once a window is chosen, `MainUnit.pas:4429` sends the chosen window `$313` --
`WM_POPUPSYSTEMMENU` -- at its own top-left corner. That IS the mechanism behind
section 3's remaining checklist item "OK then lets you move the chosen window":
the operator is meant to pick Move from that menu. The D7 tree has the same line
at `MainUnit.pas:3965`, so nothing about it came from the LCL conversion.

The selection-change handler is correct as written --
`uWinManagerForm.lstWindowsSelectionChange` calls `Windows.FlashWindow`, which
inverts the target's caption and does not activate anything. So there is no
defect proven here, and the reading is that the menu was seen after ACCEPTING a
row (double-click, OK or Enter) rather than after merely moving the selection.

**Not closed, because one half is still a bench question:** does moving the
selection with the arrow keys, without accepting, flash the window and nothing
else? If it does, F2 is a misreading of intended behaviour and can be deleted.
If a system menu appears on selection alone, the diagnosis above is wrong and
that is worth knowing.

**NEEDS REWRITE -- NY4I** (section 3): *"There is no way to move with arrow
keys as when I press OK, the window control daughter menu appears and the arrow
keys navigate in that menu (up and down)."*

### F4 — Edit QSO is dirty before you touch it — **FIXED, needs a bench pass**

**Seen:** *"I opened the edit dialog but made no changes. Save was already
enabled upon dialog open and I was prompted to save upon close even though I
changed nothing."*

**Cause, and it is one line.** `uEditQSOForm.pas` enabled Save unconditionally in
`OnShow`, directly contradicting the comment sitting above it:

```pascal
// Save starts disabled and every field's OnChange turns it on, exactly as
// the WM_COMMAND EN_CHANGE / CBN_SELCHANGE / BN_CLICKED arm did.
btnSave.Enabled := True;        // <-- said True
```

D7 enables it **only** from that message arm --
`EnableWindowTrue(hwnddlg, FLD_SAVE_BUTTON)`, `C:\TR4W\tr4w\src\uEditQSO.pas:439`.
So this was a port regression, not a design choice.

**It matters more than a spare button**, which is why it is written up rather
than just fixed: in D7's design the Save button's enabled state **is the dirty
flag**. The dialog keeps no other record of whether anything changed. Enabling it
on open did not merely offer a pointless Save -- it destroyed the only
change-tracking the dialog has, which is exactly why F6 could not work.

The second symptom had a second cause: the "Save changes?" prompt lived inside
`SaveQSOToEditableLog` and was never guarded by whether anything had changed. It
has moved to the UI layer -- see F6.

### F6 — Escape after a change does not prompt — **IMPLEMENTED as NEW behaviour**

**Seen:** *"Hitting ESC after a change does not prompt for saving"*, and then
*"I do have edit confirm enabled so when I change a field and hit esc, I should
be prompted."*

**Said plainly: D7 did not do this either.** Its `WM_CLOSE` was a bare
`EndDialog(hwnddlg, 0)` and discarded silently. So this is a REQUESTED FEATURE,
not a restored regression, and it is recorded that way so nobody later reads it
as a port defect.

**What the manual says, and it is right.** `CONFIRM EDIT CHANGES` is documented
against editing "one of your five most recent QSOs (i.e., the QSOs in the
editable log) using the alt-E command". The Edit QSO dialog **is** that editor
today -- `MainUnit.pas:6026` opens it from the editable log via
`IndexOfItemInLogForEdit`. The DOS-era in-place line editor that used to serve
Alt-E, `EditWindowEditor` in `help.pas`, has its whole body inside a 387-line
block comment (lines 1225-1612) and both of its callers are commented out too,
so `uEditQSO.pas` is the only live reader of the setting. (The manual's "five" is
the array bound `NumberEditableLines`, not the selectable row count; NY4I's note
that it should read "the number of most recent QSOs to show" applies to the
DISPLAY, and see the roadmap note about replacing that setting with a resizable
log window.)

**How it is wired.** The confirmation moved out of `SaveQSOToEditableLog` and
into the form: `ConfirmSave` is asked once by `btnSaveClick`, and
`HandleCloseQuery` covers Escape, Cancel and the window's X together (Escape
reaches it because `btnCancel` has `Cancel = True`). A routine that writes 340
lines of binary into the contest log should not also be deciding whether to ask a
question, and with two ways to reach a save it would otherwise have prompted
twice for one action.

Behaviour now, all gated on `CONFIRM EDIT CHANGES`:

| Action              | Nothing changed            | Something changed                                                |
| ------------------- | -------------------------- | ---------------------------------------------------------------- |
| Save button         | unreachable (disabled)     | "Save changes?" -> Yes writes, No returns to the dialog          |
| Escape / Cancel / X | closes silently, as before | "Save changes?" -> Yes writes and closes, No discards and closes |

A save that FAILS does not close -- the operator would otherwise lose the edit to
a validation refusal they never saw resolved.

**To verify on the bench:** all six cells of that table, plus
`CONFIRM EDIT CHANGES = FALSE` giving the old silent behaviour on every one.

### F7 — RIT, XIT and SPLIT show yellow with no radio attached

**Seen:** *"While testing and no radio attached, when the radio window is
opened, the RIT XIT and SPLIT panels are highlighted yellow as if they were
on."*

**This is the one that lands on a change from the same sitting, and I think it is
a regression from the marshalling seam (`9d3a9f79`) -- but I have not proved it
and it needs the bench to confirm.**

The mechanism, as far as the code shows: `uRadio12` creates controls 121-123 with
`CreateStatic`, and a STATIC is created **enabled**. `WM_CTLCOLORSTATIC` paints
ids 121-123 yellow *when the control is enabled* (`uRadio12.pas`, the
`IsWindowEnabled` test). What used to make them grey was
`DisplayCurrentStatus(Radio)`, called from `OpenTR4WWindow` immediately after the
panel is built, which called `EnableWindow(..., False)` **synchronously** -- so
the controls were already disabled before the panel first painted.

**THAT DIAGNOSIS WAS WRONG, and NY4I's test is what killed it.** The prediction
was that forcing a repaint would turn them grey, proving the disable had arrived
and only the paint was stale. Measured on the bench: *"No change when I forced a
repaint and the problem remains."* So they are not stale -- they are **genuinely
still enabled**, and the `EnableWindow(False)` never happened at all.

**THE REAL CAUSE, and it is provable by reading rather than inferred.**
`CloseTR4WWindow` calls `ForgetPanel` **BEFORE** `DestroyWindow`
(`MainUnit.pas:5341`), deliberately and with a comment saying so. But
`ForgetPanel` cleared child entries with `not IsWindow(Target)` -- and at that
moment the children are still perfectly good windows, so that test is false for
every one of them. Its own comment claimed the line *"is what actually clears the
RIT/XIT/SPLIT statics"*. It never did.

So the three `puEnable` entries SURVIVED the close, holding `Enabled = False`.
Windows reuses handles; a freshly created static landing on a remembered HWND
makes `PostControlEnable(h, False)` match the cache and **skip the post** -- while
the new control was created ENABLED. Hence yellow, and hence no repaint could fix
it: the control really is enabled.

It also explains why it shows up **with no radio attached**. With a rig
connected, polling eventually posts a different value and the panel self-heals;
with nothing polling, that one suppressed post is the only one there was.

NY4I confirmed the sequence: *"I closed the radio windows then reopened in same
session (no radio attached) and still RIT XIT and SPLIT are yellow."* On a
genuine first open the cache is empty and they come up grey, which is why this
survived the original bench pass.

**FIXED** in `uPanelUpdate.ForgetPanel` by asking `IsChild(aPanel, Target)` while
the panel still exists, instead of waiting for the children to stop being
windows. The `IsWindow` arm stays as a backstop.

**NOT fixed by moving the call after `DestroyWindow`**, which was the tempting
one-liner: a freed HWND can be reused immediately, so `IsWindow` can be true
again for an unrelated window and the stale entry survives anyway. `IsChild`
answers the question actually being asked, and only works BEFORE the destroy --
so the existing call order was right and only the test was wrong.

**THAT WAS ALSO WRONG.** NY4I rebuilt with the `ForgetPanel` fix and the panels
were still yellow (screenshot 2026-08-20 14:33, caption reading "Radio 1
K4D-278" so it was demonstrably the new binary). Two confident diagnoses, both
refuted by one bench run each. The third was found by stopping at the question
both had assumed away: **does the posted message arrive at all?**

**IT NEVER DID, AND IT NEVER HAD.** The main window is an LCL form subclassed by
`TR4WFormSubclassProc` (`uMainForm.pas`), which asks `IsTR4WsOwnMessage` whether
TR4W wants a message and chains everything else to the LCL. That was a
hand-written list of literal integers, with a comment noting this avoided
"depending on five more units for four integers". **`WM_PANEL_UPDATE`
(`WM_APP + 230`) was not in it.** Every panel update ever posted chained to the
LCL, which has never heard of it, and `RunQueuedPanelUpdate` was never called
once. The seam from `9d3a9f79` had not delivered a single update since the day
it was written -- which is also why bench item 10 has nothing to report yet.

**AND THREE MORE MESSAGES WERE BEING DROPPED THE SAME WAY**, two of them from
long before this work:

| Message                         | The list said  | Actually               | Consequence                                                                                                                |
| ------------------------------- | -------------- | ---------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `WM_CTY_VERSION_CHECKED`        | `WM_APP + 213` | `WM_APP + 210`         | CTY.DAT version-check result discarded                                                                                     |
| `WM_TRAYBALLON`                 | `WM_APP + 100` | `WM_SOCK + 3` = `$5F7` | tray icon clicks never handled                                                                                             |
| `WM_PANEL_UPDATE`               | absent         | `WM_APP + 230`         | the whole radio-panel seam                                                                                                 |
| `WM_USER_HEADLESS_SYNC_REPLACE` | absent         | `WM_USER + 200`        | **multi-op log replace never ran**, and it is `SendMessage`d, so the requesting thread blocked to be told nothing happened |

Four of eight. Not one of them produced an error, a log line or a compiler
diagnostic: the post SUCCEEDS, and the work simply does not happen.

**FIXED** by naming the constants instead of their values -- `uMainForm` now has
an implementation-section `uses` for the six units that declare them. A list of
integers that must agree with constants declared elsewhere cannot be checked by
anything; a list of the constants cannot be wrong about a value at all.

**GATED** by `Lint-AppMessages` (`build/Lint-AppMessages.ps1`, wired into
`Run-Lints`), which fails when a message `WindowProc` handles is not claimed by
`IsTR4WsOwnMessage`. It was tested by deleting `WM_PANEL_UPDATE` from the list
again and confirming it fails with that name and the line number.

The `ForgetPanel` fix above stays: it is a real bug on its own -- the entries
genuinely did survive a close -- it just was not this symptom, because nothing
was reaching the panel to be suppressed in the first place.

**To verify on the bench:**

- [x] Open Radio 1 with no radio attached. **RIT, XIT and SPLIT must be GREY.**
  **CONFIRMED 2026-08-20 (NY4I): "rit xit and split appear gray now."** That
  is the first update the marshalling seam has ever delivered.

- [x] Close and reopen it a few times. Still grey every time (that is the
  `ForgetPanel` half, a separate bug from the message routing).
  **CONFIRMED 2026-08-20 (NY4I): "closed and reopened the radio panel, still
  gray."** Both halves of F7 are now verified: the message reaches the panel
  at all, and the coalescing cache no longer suppresses the first update
  after a reopen.

- [x] **Taskbar button:** the main window has one again, and clicking it
  restores/minimises normally. **CONFIRMED 2026-08-20 (NY4I).** This is the
  `ShowInTaskBar := stAlways` fix, not a message-routing one: the window had
  had no taskbar button at all since it became an LCL form, because
  stDefault means "show if this is the application's MAIN form" and TR4W has
  none -- `Application.CreateForm` is never called.

- [ ] **CTY.DAT version check** should report a newer version when there is one.

---

## Added 2026-09-02 -- THE .TRW IS GONE. NOTHING BELOW HAS BEEN RUN BY AN OPERATOR.

**TR4W now logs a contest entirely to SQLite.** No `.TRW` is written, created, or
read except once, to migrate an existing log in. Every gate is green -- 28 lints,
22,624 unit tests, corpus 24/0/2, plus three new suites -- and **not one of them
puts a human in front of the program**. The corpus exports; it never logs a QSO,
edits one, deletes one, or opens a log window.

### DECISIONS FIRST -- these are yours, not bench runs

- [-] **MULTI-OP SYNCHRONISATION DOES NOT WORK, ON PURPOSE.** Log comparison  **[WITHDRAWN 2026-11-01: Question answered: no log comparison now, catch-up is insert-only from server log (CLAUDE.md sec 6; commit 02fa68d9; memory next-multi-op-network-revival).]**
  CRC32'd the raw bytes of the `.TRW` at both ends. There is no `.TRW` here, and
  **`tr4wserver` still keeps one**, so even a new digest computed at this end
  would have nothing to agree with. It now REPORTS, once per session, that
  nothing was compared -- explicitly not a claim the logs match. Reporting
  "identical" would skip a sync an operator needed; reporting "different" would
  resync on every connect against a log this build cannot read.
  **The question for you: does the server move to SQLite, or does the new
  protocol have to speak to a binary-log server?**

- [ ] **THE LOG NOW OVERRIDES `settings\tr4w.json` FOR CONTEST SETTINGS.**
  `csJSON` means the JSON store owns a row, which is right for a STATION
  setting. `CONTEST` and the `CATEGORY-*` tags are properties of a CONTEST, so
  the log applies them as a trusted caller. That is a precedence change and it
  is the one in this batch most likely to surprise you.

- [ ] **A CONFIG CHANGE MADE MID-CONTEST IS WRITTEN AT LOG CLOSE, NOT WHEN IT IS
  MADE.** Kill TR4W and the settings changed that session are not in the log --
  though every QSO is, because QSOs commit as they are made. Recording changes as
  they happen belongs with the settings work; say if it should come sooner.

- [ ] **DOES TR4W REFUSE A QSO ITS CONTEST DOES NOT ALLOW, OR LOG IT AT ZERO?**
  A contest-factory decision, surfaced by comparing against TR4QT. TR4QT's
  ARRLDXBase says "W/VE stations may ONLY work DX stations" and means it
  literally -- NY4I: *"when TR4QT says we do not work them... we will not allow
  it to be logged. But they would be zero points as TR4W does today."*

  TR4W logs the contact at zero points and sets `InhibitMults`. The factory
  preserves that exactly, and `test-contest-factory.sh` holds it there. Changing
  it alters what an operator can do at the keyboard, so it is a decision rather
  than a port detail -- and the kind that has to be right in a contest rather
  than discovered in one. TR4QT expresses the refusal through `isValidQSO`,
  which is on the list of virtuals `TContestBase` grows into, so there is
  somewhere for it to go.

### BENCH RUNS -- no automated gate reaches any of this

- [ ] **An Icom NETWORK radio -- IC-7610/IC-705/IC-9700 over LAN.** Connect,
  leave it connected for several minutes, work a few QSOs, then disconnect and
  reconnect. What is being checked is that the link STAYS up: the six protocol
  timers (are-you-there, ping, idle, token renewal, CI-V watchdog, login retry)
  are `TTimer`s now instead of `SetTimer` ids against a hidden window.

  **They already fired on the main thread**, which is why this is a swap rather
  than a redesign -- the transport has no message pump of its own, so `WM_TIMER`
  was only ever dispatched by `Application.Run`. NY4I, 2026-09-06: *"If the
  TTimer has to fire on the main thread, so be it. We can test to see if there
  is any consequence and if so, investigate some third party timers."* So the
  thing to watch for is a keepalive arriving LATE while the UI is busy --
  scrolling the band map or opening Preferences while connected is the way to
  provoke it. A disconnect after ~30 s of idle is what a missed token renewal
  looks like.

  **Icom LAN is on the unproven list already** (`docs/RADIO_BENCH_STATUS.md`),
  so this is the same run, with one more thing to watch.

- [ ] **CW BY CAT, on a radio that keys over the control link** (Elecraft,
  Kenwood, Icom, Flex). Send a few F-key messages at different speeds and check
  the busy window still ends when the message does -- particularly a message
  whose length is EXTENDED mid-send, which is `AddTimeToCWByCATTimer`.

  **What changed.** `tmrCWByCAT` was a `TWinTimer` -- a hand-rolled `SetTimer`
  wrapper written in August because linking VCL's `ExtCtrls` for one timer
  meant linking the VCL. The framework is the LCL now and is linked anyway, and
  `uWinTimer`'s own header said the swap was gated on the message loop moving,
  which it has. It is an `ExtCtrls.TTimer`.

  **The seven unit tests moved with it** (`uTestCWByCATTimer`) and one of them
  failed on the swap, which is why they were repointed rather than deleted:
  `TWinTimer` was born DISABLED and `TTimer` is born ENABLED with a 1000 ms
  interval. Harmless here -- all three LOGRADIO constructions disable it before
  assigning `OnTimer` -- but it is exactly the class of difference that shows
  up as CW timing being subtly wrong on the air and nowhere else.

  **And one thing NOT fixed, deliberately.** `uRadioPolling:935` sets
  `rig.tmrCWByCAT.Enabled := False` from the POLLING THREAD. `KillTimer` works
  from the thread that owns the timer, so that call was already reaching across
  threads under `TWinTimer` and still does. Not a regression and not made
  worse; it is a threading question about CW timing rather than a Win32 one,
  and it wants a decision, not a patch.

- [ ] **The server-log SYNCHRONIZE window -- NEEDS A SECOND STATION.** Its
  QSO list was the last hand-built Win32 window in the program and is a
  `TLogGrid` now (2026-09-06). Connect to a multi-op server, open it from the
  menu (**Ctrl+Alt+S**, get server log), tick "show server log content", and
  press Get Log. Check that rows appear AS THE DOWNLOAD RUNS rather than all at
  the end, that the columns match the main window's log, and that X-QSO and
  deleted rows are visually distinct. **"Create a new log" is UNPROVEN against
  the SQLite log** -- the server still sends its binary log -- so check whether
  it replaces the local log at all, and what the log holds afterwards.

  **What changed and why it needs an operator.** The rows used to be inserted
  one at a time by the download WORKER THREAD with `ListView_InsertItem` --
  safe by accident, as every raw Win32 call from a worker was. An LCL control
  cannot be touched off the main thread, so the worker now fills a
  preallocated array and the grid asks for the rows it is painting. The count
  the grid may read is published through `ReportSyncProgress`, which is
  already a `SendMessage`. **Nothing automated exercises this path** -- it
  needs a real server with a real log, which is why it sits with item 45.

- [ ] **The two file choosers are TOpenDialog now.** Open a contest
  configuration (Commands -> Execute configuration file) and import an ADIF.
  Check that the filter drop-down reads sensibly, that the chosen path comes
  back complete -- a long path is the case to try, since it is copied into a
  MAX_PATH `FileNameType` buffer -- and that Cancel still leaves everything
  alone.

  What changed: `OpenFileDlg` was a hand-rolled `GetOpenFileNameA` reached
  through `LoadLibrary('comdlg32.dll')`, taking `PAnsiChar` and a
  `#0`-separated filter. It is `TOpenDialog` now, and the filter is written
  `'Description|mask'` at both call sites. **No automated gate opens a file
  dialog**, so nothing here was proved by the build.

- [ ] **`NO CAPTION = TRUE`, on any tool window.**

  **THE PREFERENCES LABEL IS WRONG AND WILL MISLEAD THIS TEST (found
  2026-09-07).** It reads *"Main window has no title bar"*
  (`RS_APPEARANCE_NOCAPTION`), and the setting does NOT touch the main window:
  it is applied in `MainUnit.OpenTR4WWindow`, so it reaches the TOOL windows
  only. The main form's BorderStyle is `bsSizeable` in its `.lfm` and nothing
  overrides it at run time. Do not report "the main window still has its title
  bar" as a defect -- that is the label's fault, not the code's. Correcting the
  string is deferred because it is translated: changing the msgid drops the
  existing catalogue entries, so it wants doing with `po_merge`.

  Set it in Preferences
  (Appearance), open the band map and the function keys window, and check that
  the title bars are gone, that the windows still land where they were saved,
  and that they are still movable and closable. Then set it back to FALSE and
  check the captions come back on the next open.

  **This has almost certainly never worked.** Until 2026-09-06 the setting ran
  `SetWindowLong(h, GWL_STYLE, GetWindowLong(h, GWL_STYLE) - WS_POPUP)` --
  SUBTRACTION from a style word rather than `and not`, taking away a bit
  ($80000000) that an LCL top-level form does not have set, so the DWORD wrapped
  and the remaining style bits were whatever the borrow left. It also named the
  wrong bit: a caption is WS_CAPTION. A second block then shrank the outer
  height by `SM_CYSMCAPTION` to compensate for a caption that had not been
  removed.

  It is `lclForm.BorderStyle := bsNone` now, applied before the saved
  `BoundsRect`, with the handle re-read because changing BorderStyle recreates
  the window. The compensation block is gone. **The setting defaults to False
  and no automated gate touches it**, so this is the only way to find out
  whether the new behaviour is the one an operator wants -- and whether the
  windows are still usable without a title bar to drag.

- [ ] **Log a contest, properly.** Work a run of QSOs, watch the editable log
  fill, check the totals and the dupe sheet. The whole write path changed: the
  binary write is gone from `tAddQSOToLog` and `riTotalRecordsInLog` now follows
  the append rather than a byte count.

- [ ] **Alt-Y, twice.** Delete the last contact and restore it. It reads the
  newest QSO through the seam instead of seeking back one record, and writes
  through the repository.

- [ ] **Edit a QSO in a log LONGER than the editable-log window.** This is the
  one I would run first. The editable-log selection arithmetic was broken by B4
  and fixed in the same session, and *it needs a log longer than the window to
  reach* -- no fixture has one. Separately, an edit used to write to the QSO
  AFTER the one selected (a `div` that returned index+1 because the header and a
  record are both 376 bytes). Both are fixed and pinned by a unit test; neither
  has been seen by a person.

- [ ] **Open the log window twice in one session.** A reload used to append to
  the list instead of rebuilding it -- caught by `Lint-Win32Dialogs` counting
  `wh[]` uses, not by any test.

- [ ] **Search the log, then edit a result.** Search results carry a record
  INDEX now, not a byte offset.

- [ ] **Migrate a real 4.x log.** Point this build at a contest whose `.TRW` you
  care about and confirm every QSO arrives. It happens ONCE, silently, on first
  open. The corpus does this thirteen times, but with logs I chose.

- [ ] **CREATE A NEW CONTEST.** The highest-risk item in this batch, because
  contest creation has NO automated coverage of any kind -- the corpus is handed
  ready-made logs and never makes one, and no harness drives the new-contest
  dialog. What changed:

  **No folder.** A contest was `target\<year> <contest> <call>\` holding eight
  files; it is now one `.db` in one directory. NY4I: *"There is really no reason
  for a folder for each one anymore."*

  **The name follows TR4QT** -- `CONTEST YYYY-MM-DD CALL.db`, so a logs
  directory sorts by contest then date. TR4QT drops the callsign; TR4W keeps it,
  because an operator who runs one contest as two calls otherwise gets one name
  for two logs. `uLogNaming` is a pure function with six unit tests, including
  that a `/` in a callsign separates rather than vanishing (W1AW/4 must not
  become W1AW4, which is a different real station) and that `..\` in a typed
  contest name cannot climb out of the logs directory.

  **No `.cfg` is written.** The dialog's settings are applied straight into the
  config layer and captured into the log, which is the same journey with the
  file taken out. The ordering is preserved deliberately: `CONTEST` is applied
  LAST, as it was the last line of the file, because its hook builds the
  contest's state from the values set above it.

  **The POTA special case is gone** -- it existed to put the date in the folder
  name, and every log's name carries its date now.

  Worth checking specifically: that a created contest appears in the list next
  time, that the name reads well for a POTA activation, and that two contests
  created on the same day with different calls do not collide.

- [ ] **OPEN AN EXISTING .cfg CONTEST AND CONFIRM IT MIGRATES.** The dialog
  lists `.db` files, plus any `.cfg` that has no `.db` beside it -- which is how
  an upgrading operator still sees the contests they already have. Opening one
  builds the database from the `.TRW`, after which it is listed as a `.db` and
  the `.cfg` stops appearing, because the same contest must not show twice.

### AND ONE THING THE GATES DID CATCH, WORTH KNOWING

The corpus ran a **14-hour-old binary for an entire session**. It executes
`tr4w/target/tr4w.exe`, which is where `FullBuild.ps1` puts the app;
`Build-App.ps1` writes `build-out/` and does not touch `target/`. Every green
corpus result reported before that discovery measured code that never ran -- and
the run that finally used the new binary turned 22/0/4 into 24/0/2 on the spot.
**A regression would have hidden exactly as well.** The script now REFUSES to run
against a stale binary rather than warning, because a warning above a 30-line
pass list is a warning nobody reads.

---

## 2026-09-08 -- THE MULTI-OP LOG SYNC MOVED TO INDY. NOBODY HAS RUN IT.

**This one IS a bench test**, and it is the only change in today's sweep that
code review cannot settle: it needs a running `tr4wserver` and a second
station, which this machine does not have.

`uGetServerLog.RunSyncThread` downloaded the server's log through a raw
WinSock socket -- `utils_net.GetConnection`, `WSAEventSelect`,
`WSAWaitForMultipleEvents`, `recv`. It is `TIdTCPClient` now
(`FetchServerLog`), which was the last raw socket in TR4W and let
`utils_net.pas` be deleted outright.

**WHAT TO RUN:** on a multi-op setup, *Get server log* (the synchronize
window), against a server holding a log of a few hundred QSOs.

**WHAT TO WATCH, in the order it can go wrong:**

- [ ] **The byte count on the progress display climbs and finishes.** If it
  sticks at 0, the password write or the size header is wrong.
- [ ] **The record and QSO counts match what the server reports.** The size
  check is `LogSize <> TotalBytes`; a mismatch shows *"failed to receive
  server log"* and is the loudest symptom of a framing error.
- [ ] **A log LARGER than 4096 bytes** -- that is one old `recv` buffer, so a
  single-chunk transfer would prove almost nothing about the loop.
- [ ] **The window does not hang for a station that is off.** Connect failures
  are now REPORTED (`[SyncLog] connect to <host>:<port> failed`) where the
  old path returned a bare False, so a wrong address and a refused
  connection no longer look identical. Check `tr4w.log`.

**TWO CHANGES THAT ARE NOT TRANSLATIONS**, because if this misbehaves they are
the first places to look:

1. **The 4-byte size header is read as a header** (`ReadInt32(False)`) instead
      of being skipped off the front of whatever the first `recv` returned.
      The old form was correct only while that first segment carried at least
      four bytes, which TCP does not promise.
2. **`AConvert := False` is load-bearing.** Indy converts from NETWORK byte
      order by default and the old code read those bytes natively. Left at the
      default on a little-endian machine, a 25,000-byte log reads as
      3,347,644,416 and every size check fails.

The transfer still ends on **two seconds of silence or a close**, exactly as
the old 2000 ms wait did -- there is no framing past the size field.

## 2026-09-08 -- THE RADIO FACTORY TESTER DOES NOT COMPILE, AND HAS NOT FOR A WHILE

**Found by the Windows-dependency sweep, and it is a bench-work problem rather
than a portability one** -- which is why it is here and not in the sweep doc.

`tr4w/test/RadioFactoryTester.lpr` + `uTestMain.pas` + `uTestMain.dfm` is an
interactive harness for driving radio commands at real hardware. **NO BUILD
SCRIPT IN THIS TREE BUILDS IT** -- it is in no `.lpi`, no `.ps1`, and no CI
step -- so nothing has told anyone it stopped working.

**Compiled by hand on 2026-09-08 it fails with 11 errors**, and they are drift
against the factory it is supposed to test:

```
uTestMain.pas(378,8)  Wrong number of parameters for "CreateRadioNetwork"
uRadioFactory.pas(104) Found declaration:
                       CreateRadioNetwork(InterfacedRadioType; UnicodeString; LongInt)
uTestMain.pas(768,19) Identifier not found "rb20m"
uTestMain.pas(774,19) Identifier not found "rb40m"
```

So the signature it calls has changed and the band enum members it names no
longer exist. It is also a **DELPHI VCL FORM with a `.dfm`**, not an `.lfm`,
which is the other half of why it cannot come back cheaply.

**WHY THIS MATTERS MORE THAN AN UNCOMPILED FILE USUALLY WOULD:** it is a
RADIO test harness. The bench work is the one thing CI cannot buy (the runner
proves the tree builds, not that a radio keys), so an operator sitting down
with a rig is exactly the person who would reach for this -- and lose an hour
discovering it has rotted.

**THE DECISION IS NY4I'S, and there are three real options:**

1. **DELETE IT.** This is the same shape as the FMX twins, which CLAUDE.md
   records were deleted precisely because they were "units no build compiled,
   and they had already drifted". The precedent is established and the
   argument is the same one.
2. **FIX AND BUILD IT.** Three call-site errors is not much work, but the
   `.dfm` has to become an `.lfm` and it needs a build script, or it will rot
   again the same way -- which is the real cost, not the eleven errors.
3. **LEAVE IT AND SAY SO IN THE FILE.** Cheapest, and only acceptable if the
   header states plainly that it does not build, so the next person finds out
   in ten seconds instead of an hour.

**Nothing blocks on this** -- it is not in any build, so it cannot break one.
It stays out of the Windows-dependency sweep's count for the same reason: an
ungated `uses Windows, Messages` in a file no compiler reads is not a
portability problem yet.

## 2026-09-08 -- THE WARNING BEEPS SHOULD BE AUDIBLE AGAIN. LISTEN.

**One thing to check, and it takes ten seconds: WORK A DUPE AND LISTEN.**

`BeepUnit` drove `\Device\Beep` through a DOS device alias it defined for
itself (`QueryDosDeviceA` / `DefineDosDeviceA` / `CreateFileA` /
`DeviceIoControl`). **On most Windows 10/11 machines that did nothing at all**:
beep.sys is commonly disabled and there is no PC speaker, so `CreateFile`
failed, the handle stayed invalid, and every alert was silent WITH NOTHING
LOGGED. If you have not heard a dupe beep in years, that is why.

It is `uAudio.BeepAlert` now, which calls `Windows.Beep` -- synthesised
through the SOUND CARD, no driver and no speaker hardware involved.

**WHAT TO LISTEN FOR** -- each is a different call in `tDoABeep`, so hearing
one does not prove the rest:

- [ ] **a dupe** -- `Single`, 2000 Hz for 75 ms
- [ ] **a new multiplier / congratulations** -- `BeepCongrats`, a five-tone
  run from 500 Hz down to 300 and up to 800
- [ ] **a warning** -- `Warning`, 1500 Hz for 150 ms
- [ ] **a prompt** -- `PromptBeep`, three pulses at 2000 Hz
- [ ] **`QuickBeep`** -- 1000 Hz for 300 ms

**AND ONE THING TO WATCH RATHER THAN HEAR: TIMING.** `Windows.Beep` BLOCKS for
the duration, and so did the old path -- `ntBeep` returned immediately and
`SpeakerBeep` then called `Sleep(Duration)`. **That Sleep is removed**, because
keeping both would double every alert. If a beep now feels twice as long, or
the log window stutters on a run of dupes, that is the place to look.

**IF THEY ARE STILL SILENT**, the log will say why -- `uAudio` reports a
refused tone with its frequency and duration, which the old code never did.
`[Audio]` is the prefix.

**NOT A PORTABILITY ITEM.** This is a Windows behaviour change on Windows; the
cross-platform half (aplay/paplay/afplay, and no tone generator on macOS) is
in `uAudio`'s header and needs a Linux box rather than a bench.

## 2026-09-08 -- peeling MainUnit for a Linux compile: DECISIONS OWED

Compiling `MainUnit.pas` for x86_64-linux, unit by unit, to find what still
binds this program to Windows (`tools/Compile-Linux.ps1`). Most blockers were
dead `uses` entries or one-line RTL swaps and were simply fixed. **These are
the ones that are NY4I's call, not mine** -- each is legacy code that is
provably inert today, so deleting it is safe in the compiler's eyes and is
still a decision about what the program is.

Nothing here is a bench test. They need an answer, not a radio.

- [ ] **THE SIDETONE IS GONE. THREE THINGS WEARING THE SAME NAME ARE NOT --
  and two of them need your call.** NY4I, 2026-09-08: *"We do not need a
  sidetone generated by the program at all. It is notoriously unreliable on
  windows and the sidetone comes from the radio. You can remove any references
  to sidetone."*

  **DONE, and it was two lines.** The program's generated CW sidetone was
  exactly two `ntBeep` calls in `logk1ea` -- one for the CW buffer, one for the
  paddle monitor. Both are deleted. **CW element timing is untouched and that
  is checkable rather than asserted**: `ntBeep` issued a `DeviceIoControl` and
  returned immediately, so `tCWSleep` was always the only thing timing a dit.

  Searching for "sidetone" turns up two OTHER things, and deleting either would
  be me deciding something you did not:

  1. **THE WINKEYER'S OWN SIDETONE** -- `WK SIDETONE ENABLE`, `WK SIDETONE
     FREQUENCY`, `WK PADDLE ONLY SIDETONE`. This is the KEYER'S HARDWARE
     generating the tone, not the program, so your reason for removing the
     other one does not obviously apply: it is neither unreliable nor
     Windows-bound, it is a setting we send over the keyer link. **Kept.** Say
     if you want it gone too.
  2. **THE WARNING BEEPS** -- `tDoABeep` (dupe, new multiplier, prompt,
     congratulations), `QuickBeep`, and tree's note player. Not sidetones, but
     they share the same generator: `SpeakerBeep` calls `ntBeep`, so they go
     through `\Device\Beep` too, **and therefore have the same reliability
     problem you just described** -- beep.sys is disabled on most Windows 10/11
     machines, there is no PC speaker, `CreateFile` fails, and every beep
     silently does nothing. **Kept, because you asked about the sidetone.** If
     these go as well, `BeepUnit` is deleted outright and the
     `QueryDosDevice`/`DefineDosDevice`/`DeviceIoControl` block leaves the tree
     with it -- which is the whole reason the sweep listed audio as a blocker.

  **And one piece of cleanup that follows either way, listed so it is not
  forgotten:** `Config.CWTone` is no longer a tone. It is threaded through
  `AddStringToBuffer(Msg, Tone)` into the keyer factory as a dead parameter,
  and `logddx` and `MainUnit` now test it against 0 as a CW-ENABLED FLAG --
  which is also what `Alt-=` toggles. Removing it means separating the flag
  from the frequency across the keyer API, so it is a refactor with real reach,
  not a deletion. Not started.

- [ ] **BENCH: the Icom LAN transport is back on Indy -- find the deadlock.**
  NY4I, 2026-09-08: *"we have to switch back to indy and we will bench test to
  determine the issue. Using WinSock is no longer an option."* Done, and
  **instrumented on purpose** (*"instrument the code around the icom change so
  get us a leg up on detecting the issue"*).

  `SendRawPacket` had imported `sendto` from `ws2_32.dll` with a hand-built
  `sockaddr_in`, because of a REAL fix for a REAL hang:

      Use direct WinSock sendto() to avoid TIdUDPServer.SendBuffer deadlock
      when called from the main thread while Indy read threads are active.

  It now calls `Socket.SendBuffer`. **So the hang may come back** -- that is
  the point of the bench run, not a risk that slipped through.

  **What the log will show, and what to look for.** A deadlock never returns,
  so nothing logged after the send survives it. Every send therefore logs
  BEFORE it, carrying everything a diagnosis needs:

      SEND ENTER port=50001 -> 192.168.1.50:50001 len=16 thread=27312
                 mainthread=True inflight=1 active=True

  | what you see                                          | what it means                                                                                                                          |
  | ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
  | an `ENTER` with no matching `EXIT`, and the log stops | the deadlock. The line names the thread, whether it is the main one, and how many sends were already inside Indy                       |
  | `SEND OVERLAP`                                        | two or more threads inside the send at once -- the shape the original comment blamed                                                   |
  | `mainthread=True` on the stuck one                    | exactly the case that comment named                                                                                                    |
  | `SLOW SEND: N ms`                                     | Indy blocked but survived. The same contention, and far likelier to be caught than a full hang -- threshold is 20 ms, deliberately low |

  `FSendInFlight` is maintained with an interlocked increment and NOT under
  `FSendLock`, because the lock is what a deadlock would be waiting on: the
  counter has to be readable without taking it.

  **Also converted in the same pass, and also unproven:** `GetLocalIPForRoute`
  (the UDP-connect routing trick) now uses `TIdSocketHandle` instead of seven
  raw WinSock calls, and it REPORTS failure instead of swallowing it -- without
  a local IP the session id is wrong and the radio rejects the login, which
  looks like a password problem. Two `setsockopt(SO_RCVBUF)` calls became
  `TIdSocketHandle.SetSockOpt`.

  **Nothing here is checkable by any gate we have** -- Icom LAN is the one
  radio family `RADIO_BENCH_STATUS.md` lists as UNPROVEN. Build, tests and
  lints are green and prove only that it compiles.

- [ ] **CW speed sync over TCI: the detector's POSITIVE branch has never fired
  against a real server.** Restored 2026-09-18 with a behaviour detector in
  `TFactoryRadioBase` — TR4W remembers the speed it pushed, compares it with
  the speed the radio reports back, and stops sending after one log line if
  they differ. The refusing path is the one we have evidence for (AetherSDR,
  measured: ten pushes, ten replies carrying its own unchanged 30). **The
  "it worked" path is pinned by unit tests only.**

  **The run:** QK4 as the server, TR4W as the client, a K4 on the other end.
  Change speed with PgUp/PgDn and watch the wire for three things —

  1. Does QK4 accept a **one-argument** `cw_macros_speed:NN;` as a set, or
     does it require two? (AetherSDR's `isSet = (args.size() >= 2)` makes a
     global one-argument command unreachable as a set for *any* client; that
     is a limitation of that server, not of TCI.)
  2. Which name comes back — `cw_macros_speed` or `cw_keyer_speed` — and does
     it carry **our** number or the server's old one? Reading AetherSDR's
     source showed it replies under the **same name in both directions**, so
     the value is the discriminator and the name is worthless. Confirm that
     holds on a conforming server.
  3. That the radio's own keyer speed actually moves.

  Also settles the `[VERIFY]` at `uRadioTCI.pas` on whether speed
  notifications are receiver-addressed.

  **Do NOT probe at connect** — a set to the value already in force changes
  nothing, so a server may broadcast nothing and a working server would read
  as refused. Only a genuine operator speed change is a valid sample.

- [ ] **`cw_macros_stop;` on AetherSDR — and the hypothesis has changed.** It
  works on QK4 (confirmed on air 2026-09-17, cuts mid-message on a K4). The
  suspicion was that AetherSDR's argument-count parse swallowed a
  zero-argument command. **Reading its source says no:** line 463 dispatches
  `cmdCwMacrosStop()` with no args and no `isSet` at all, so it never reaches
  that logic. Its body is `if (!model->hasRadioSideCwKeyer()) return;
  sendCmdPublic("cwx clear")`.

  So the question to answer at the bench is narrower: on NY4I's AetherSDR,
  **does the attached radio report a radio-side CW keyer?** Key a long message,
  press Escape. If it does not cut, that test is why, and it is a capability
  question rather than a protocol one.

---

## Contest factory -- state QSO parties (added 2026-09-29)

**None of this is covered by any automated gate.** ADDING_A_CONTEST.md section 4
is explicit: the golden corpus is blind to scoring, `test-contest-factory.sh`
sees only the factory-versus-legacy A/B, and **nothing in this tree types an
exchange**. The unit tests added alongside this work pin the contest classes'
ANSWERS; they cannot press a key.

- [ ] **Florida QSO Party now refuses a three-county exchange.** Type
  `599 PIN/HIL/CIT` into the exchange window in FQP. Expected: the exchange
  is refused with "Too many counties for this contest (maximum 2)!!" and
  nothing is logged. Two counties (`599 PIN/HIL`) must still log TWO QSOs
  sharing one serial number. **This is NEW behaviour** -- TR4W has never
  enforced a county limit; NY4I chose it ("knowing and setting a limit makes
  our edit checking of the exchange more robust").

- [ ] **Michigan QSO Party now refuses ANY county-line exchange.** `599 WAYN/OAK`
  must be refused; `599 WAYN` must log normally. Michigan's rules: "No
  station may claim simultaneous operation in more than one county, state,
  or province." Also new behaviour.

- [ ] **California QSO Party now refuses a FIVE-county exchange.** NY4I set the
  maximum at four -- "4 since that is the intersection of 4 counties with
  common 90 degree angle borders". `599 SLUI/MONT/ALAM/STAN` must log FOUR
  QSOs sharing one serial; a fifth county must be refused. Also new
  behaviour.

- [ ] **Indiana QSO Party now refuses a THREE-county exchange.** Maximum two,
  per NY4I. Two must still log two QSOs sharing one serial.

  **California was this list's "unchanged" canary until 2026-09-29 and is
  no longer usable as one** -- it now has a limit of its own. Use a party
  that states NO maximum instead: Colorado, Minnesota, Missouri, Ohio,
  Wisconsin, Tennessee, Texas or Arizona. All eight inherit
  `CountyLineCountiesUnlimited`.

- [ ] **Every QSO party WITHOUT an established maximum must be UNCHANGED.**
  Spot-check one of the eight above with four counties; it must log four,
  exactly as before. If it is refused, the unlimited default has been lost
  -- which is the defect fixed on 2026-09-29, where a class of any kind
  made the base answer 0 from ContestsArray's boolean and refuse a second
  QTH.

- [ ] **A contest that is NOT a QSO party must not be asked at all.** Arktika
  Spring, ARRL Digital and ARRL Field Day each have a class now and none is
  a QSO party; a multi-QTH exchange in any of them must behave exactly as
  it did before they were moved. The unit tests assert they accept two;
  only the bench can say what the operator sees.

- [ ] **ADIF STATE is the WORKED station's, decided per QSO by the contest
  class** (Q76/Q89, `35986731`): a party county gives its state, a
  state or province code gives itself where ADIF allows it, DX gives
  none. Export from NYQP: an in-state county QSO carries `<STATE:2>NY`
  and its `<CNTY>`; an out-of-state W station that sent `PA` carries
  `<STATE:2>PA`; a DX QSO carries no STATE. **No corpus log covers
  NYQP.**

- [ ] **An edited memory survives a restart** (Q113, 5.0.29). Open a
  contest, edit a CQ memory, an EX memory and an Alt-key memory (Alt-P),
  change one button caption; close TR4W and reopen the same contest. All
  four edits are back; an unedited key shows the contest's default.
  Change MY STATE and reopen: the unedited defaults follow it, the edits
  do not. The log says `function-key memory(ies) the operator edited
  restored`. Then open the log in 5.0.28: it is refused (schema 4) --
  expected, keep a copy if an older build must read it.

---

## Decisions owed from NY4I -- contest factory

- [ ] **Eleven flagged parties have no established county limit** and are left
  unlimited (today's behaviour). 7QP is known to be 4 on NY4I's geometric
  argument -- four counties is the most that can meet at a point with
  right-angle borders. 7QP has a class now (`uContestSevenQP`), and it states
  no county-line limit of its own.

---

## Known and accepted — no action, listed so they are not re-reported

- [ ] **CW-by-CAT keys one character per `KY` command** when typing into the
  send-from-keyboard box (Ctrl+A) or during autosend. Staccato, inherent, and
  better than D7 (which sent nothing until Enter). Full explanation and three
  untried directions in `CW_Keyer_Factory_Plan.md`.
- [ ] **Preferences collapses the Hardware branch** after visiting another section.
  That is the one-branch-at-a-time rule working. The pane arithmetic behind it
  was recounted 2026-08-18 and two branches now overflow; NY4I is rearranging the
  sections first, then it gets revisited.

---

## Issue #1 -- tool windows are no longer owned by the main window (2026-10-29)

Every MODELESS tool window now calls `LeaveFormUnowned`
(`uLCLFormHelpers`) instead of `OwnFormByMainWindow`: Telnet, band map,
remaining mults, dupe sheet, stations, radio panel, panadapter, function
keys, network, intercom, MMTTY, master, HamScore, post scores,
Preferences and Log Search. Modal dialogs (Log Edit, About, the band
plan, every `ShowModalOverWin32Parent` caller) keep `OwnFormByMainWindow`.
Windows keeps an owned window above its owner at all times, which is why
clicking the main window could not bring it forward. Not built or run when
this was written.

- [ ] **Click the main window and it rises.** Overlap the band map,
  Telnet and a radio panel with the main window, then click the main
  window. It comes to the front, above all three.
- [ ] **Click a tool window and it rises** above the main window and
  above the other tool windows.
- [ ] **Minimize and restore the main window.** EXPECTED CHANGE: the
  tool windows no longer minimize with it. They stay where they are.
  Say whether that is acceptable on a contest desk.
- [ ] **THE TRADE: switch to another program and back** (Alt-Tab, and
  the taskbar button separately). Ownership was added to Preferences on
  2026-08-23 and to Log Search for exactly this: unowned, coming back
  raised only the main window and left the tool window buried behind it.
  EXPECTED, from the code: the taskbar button raises only the main window
  and the tool windows stay behind the other program. Confirm, and weigh
  it against the click-to-raise fix. If it needs fixing, the follow-up is
  an `Application.OnActivate` that brings the visible tool windows up
  beneath the main window. That is NY4I's call, not part of this change.
- [ ] **A modal stays above the main window.** Open the band plan from
  Preferences (and Edit QSO from Log Search), switch to another program
  and back. The modal is on top and not stranded behind the main window.
  Also check whether the MAIN window jumps in front of Preferences or
  Log Search when the modal opens. The modal is owned by the main window,
  and activating it may raise its owner too (not verified). If it does,
  the native follow-up is a modal owned by the form that opened it
  (`Screen.ActiveForm`, which is what `pmAuto` resolves to).
- [ ] **Panadapter auto-open does not take the caret.** Bring up the
  spectrum link. Typing still goes to the call field. NOTE:
  `ShowWithoutTakingFocus` brings the main window back to the front, so
  an unowned panadapter that overlaps it now opens BEHIND the main
  window. EXPECTED: it has no taskbar button and no Alt-Tab entry, so
  one wholly behind the main window is reached only by moving the main
  window or through TR4W's window list. Say whether that is acceptable.
- [ ] **One taskbar entry for TR4W, and what Alt-Tab lists.** From the
  LCL source, no extra buttons are expected on Windows. An unowned tool
  window's real owner is the hidden Application window
  (`win32wsforms.pp`, CreateHandle: stDefault with MainFormOnTaskBar
  False), and that window is never shown because TR4W has no
  `Application.MainForm`. So nothing sets `ShowInTaskBar`. Confirm there
  is one taskbar button, and record what Alt-Tab shows. **On Linux
  (gtk2)** every stDefault form already asks for a taskbar entry. Some
  panels hide windows that are transient-for another window, so dropping
  the transient-for may add entries there. Check on Mint.

## Added 2026-10-29 -- HAMSCORE "RE-SEND LOG" ASKS BEFORE IT DELETES (NY4I, RTC test)

The Tools item formerly "HamScore: Resync log from scratch" sent `<deletelog>`
with no warning. It is now **Tools -> Re-send Log to HamScore...** and opens a
three-button dialog; the status window's button (same caption) opens the same
dialog. Before this, that button queued ONLY the `<deletelog>` and never
re-uploaded. Needs a HamScore account (or the queue count with posting off).

- [ ] **Dialog look and buttons** on Windows, Mint (gtk2) and macOS: buttons
  "Re-send only", "Delete and re-send", Cancel; the body reads as two
  paragraphs and the long text wraps without clipping. GTK draws the buttons
  in the other order -- the answer must follow the caption, not the position.
- [ ] **Enter and Escape both Cancel.** Open the dialog, press Enter: nothing is
  queued and the status line does not say "queueing". Same for Escape and for
  closing the window.
- [ ] **Re-send only**: the queue grows by one per QSO and no `<deletelog>` goes
  out (tr4w.log / the HamScore mock `tr4w/test/hamscore_mock.py`). Against the
  REAL server: does a re-sent QSO replace the existing one or duplicate it?
  The code only shows the QSO carries its original `<ID>`; nothing in the repo
  says what the server does. Record the answer here and in the dialog text.
- [ ] **Delete and re-send**: `<deletelog>` first, then every QSO; the contest
  named in the dialog is the contest id in the `<deletelog>` body.
- [ ] **Delete a QSO locally, then "Re-send only"**: it stays on the server
  (the dialog says so); "Delete and re-send" removes it.
- [ ] **Button caption** in the status window reads "Re-send Log to HamScore..."
  and fits its button (width 250) in a non-English language.

## Added 2026-10-31 -- EDIT QSO SHOWS WHERE AN EXTERNAL LOGGER STANDS (WRL)

Edit QSO has a read-only line under "Our station for this QSO" when the QSO
has an `external_delivery` row, e.g. `External logger WRL: up to date. Last
sent 2026-10-31 14:05 UTC`. Hidden, and the window no taller, when it has
none. Needs a log with WRL delivery set up (or rows written by hand).

- [ ] **Edit QSO delivery line looks right on Windows, Mint (gtk2) and macOS**:
  one line, left-aligned with the group above it, not clipped at the bottom of
  the window, and the window has no empty band below the group for a QSO with
  no delivery row.
- [ ] **It follows the QSO.** Open a delivered QSO, close, open a QSO with no
  row: the line is gone. A failed delivery shows its code, e.g.
  `failed (BAD_CALL)`; a never-answered one says `Not sent yet`.
- [ ] **It does not dirty the dialog.** Open and Escape: no save prompt, and
  Save stays disabled.
- [ ] **The time is UTC** and matches when WRL last answered (`tr4w.log`).

## Added 2026-10-31 -- A LOCKED CONTEST LOG: THE STARTUP DIALOG, READ-ONLY, AND THE WATCHDOG

Both failures in tr4w.log of 2026-10-31 (the startup crash at 10:39:27 and
"the configuration could not be recorded on close" at 10:43:25) were a write
from a stale sqldb read snapshot after the WRL worker committed
(SQLITE_BUSY_SNAPSHOT, which no busy timeout cures). The unit tests pin that
(uTestLogLocking, uTestLogStore). What only a real run can judge:

- [ ] **No crash, no lost QSO with WRL enabled.** Start TR4W on a log with WRL
  delivery set up and log a dozen QSOs quickly. tr4w.log has no
  `database is locked`, no `THE LOG WAS LOCKED`, and the WRL worker starts AFTER
  the log is loaded (its first `[WRL]` line follows the `[EditableLog]` lines).
  Close: no `could not be recorded on close`.
- [ ] **The startup dialog on a really locked log.** Lock the log from outside
  (e.g. open the `sqlite3` shell on `<log>.db`, run `BEGIN IMMEDIATE;` and
  leave it open), then start TR4W. After about 2 s a warning box titled "Contest log is
  locked" names the file and the likely causes, with three buttons.
- [ ] **Retry** with the lock still held asks again; release the lock, Retry
  again: the log opens normally and QSOs log.
- [ ] **Open read-only (no logging)**: the log shows and can be exported; trying
  to log a QSO shows "QSO NOT LOGGED" with a beep, and ONE box saying the log
  is read-only (not one per QSO). The WRL worker does not start. Close: nothing
  is written (no `recorded on exit` line).
- [ ] **Quit TR4W** ends the program cleanly (exit code 1, `operator chose Quit`
  in tr4w.log). Escape and the window's close button also Quit.
- [ ] **The box on gtk2 (Mint) and Cocoa (macOS)**: the body wraps without
  clipping and the three captions fit. GTK draws the buttons in the other
  order -- the action must follow the caption, not the position.
- [ ] **Nothing ever offers to delete the -wal or -shm**, and after any of the
  above they are still beside the log until TR4W closes it.
- [ ] **Tools > Run Verification Checks** has "Contest log is not locked": it
  passes on an ordinary session and reports the -wal/-shm as expected; with
  the outside lock held it FAILS and says another program holds the write
  lock; the watchdog intervention count is 0 in a normal session.
- [ ] **The watchdog under real WRL traffic.** A normal session logs no
  `[LogWatchdog]` line at all. (A stalled worker cannot be provoked without a
  debugger; if one is ever seen, the lines go: asked to roll back, interrupted,
  stopping its owner, then "starting a new one" -- and logging carries on.)
- [ ] **The WRL editor loads logbooks on open and drops them with the key.** (The separate WRL setup form is gone, issue 231; this is the editor's own behaviour.) Open a WRL logger with a saved key: the Logbook list fills with no button press, the UI stays responsive, and the saved logbook is selected. Disconnect the network and open it: the saved name stays, the status line reports the failure. Close it immediately after opening (Cancel while loading): it closes once the request ends, no crash. Edit one character of the key: the list empties. Type a wrong key and press Refresh: the failure code shows and the list stays empty.

## Added 2026-10-31 -- THE OS VAULT ON macOS AND LINUX (WRL key, HamScore and server passwords)

`uKeychainMac` (Security.framework, login keychain) and `uKeychainLinux`
(libsecret, loaded at run time) are new. Nothing on Windows can compile them
for real, let alone run them, so everything here is unverified. Each entry is
service `TR4W/v1`, account the setting's path UPPER-CASED, label
`TR4W/<setting>`. Use `DEBUG LOG LEVEL = DEBUG`; the lines to read are
`[Convert]   secret store  :` (startup) and any `[Keychain]` warning.

**Mint (gtk2), GNOME Keyring or the desktop's own Secret Service**

- [ ] **Store, restart, read.** Enter a WRL API key, save, quit. The startup
  line says `libsecret1 (available)`. Restart: the WRL logger editor shows the
  key without asking, and `settings/tr4w.json` has `ApiKeyRef` and no `ApiKey`.
  Seahorse ("Passwords and Keys") lists `TR4W/<path>` under Login.
- [ ] **Change and clear.** Change the key and restart: the new one is read.
  Clear it and save: the entry is gone from Seahorse.
- [ ] **A locked collection.** Lock the Login keyring in Seahorse, then save a
  changed key. The desktop asks to unlock. Unlock: it stores. Dismiss: tr4w.log
  has `[Keychain] ... the secret store is locked`, nothing is in Seahorse, and
  the key is asked for again next session. **Record exactly what was logged**:
  the code assumes a dismissed prompt comes back as "failed, no error" or as
  G_IO_ERROR_CANCELLED. If it comes back as "not found" instead, a locked read
  cannot be told from a missing entry, and the unit header says so.
- [ ] **Autologin (keyring locked at start).** With a key stored, log in
  through autologin so the Login keyring stays locked, and start TR4W. The
  settings load reads the key BEFORE the main window, so an unlock prompt may
  appear with no TR4W window behind it -- note whether it does, on every
  start. Dismiss it, then change any setting (a save): **check Seahorse that
  the stored key is still there**, that `settings/tr4w.json` still has
  `ApiKeyRef`, and that tr4w.log has `[Keychain] ... was not removed: it
  could not be read this session`. Unlock and restart: the key is read.
  (Fixed 2026-11-01 in `uKeychain`: a name whose read failed is not deleted
  by an empty save. It relies on the dismissed prompt reading as locked or
  failed -- if the read came back as "not found", the key IS deleted, and
  that is the finding to record.)
- [ ] **Headless / no Secret Service.** Run from an ssh session with no
  `DBUS_SESSION_BUS_ADDRESS` (or with gnome-keyring stopped). TR4W must start,
  log one `[Keychain]` warning naming the Secret Service error, and say
  `unavailable` rather than crash or hang. **Time the first save**: a D-Bus
  activation timeout could block the UI for ~25 s, and that would need fixing.
- [ ] **No libsecret at all** (a VM without `libsecret-1-0`): one warning naming
  `libsecret-1.so.0`, the startup line says `UNAVAILABLE`, and nothing else
  changes.
- [ ] **The AppImage and the tarball both.** The AppImage bundles glib; check
  that the HOST's libsecret loads beside it (the startup line says
  `available`). If it says `lacks <symbol>` or `could not be loaded`, the
  bundling decision in the build-release report applies.

**macOS (Developer ID signed bundle, then an ad-hoc local build)**

- [ ] **Store, restart, read** as above. Keychain Access -> login ->
  Passwords lists `TR4W/<path>`. No prompt from the signed build.
- [ ] **Update to the next signed release and read.** Store with release N,
  install N+1, start: the key is read with NO "wants to use your confidential
  information" prompt (same Developer ID). An ad-hoc build DOES prompt; that is
  macOS asking and is expected.
- [ ] **A locked keychain.** Lock the login keychain (Keychain Access ->
  File -> Lock Keychain "login"), then save a changed key. macOS asks to
  unlock. Cancel: tr4w.log has `[Keychain] ... is locked` and
  `macOS keychain status -128` (or -25308); nothing is stored.
- [ ] **Clear removes it** from Keychain Access.

## Restart audit fixes (2026-11-01)

- [ ] **WSJT-X BROADCAST PORT.** Set it to something other than 2237 (say 2345), restart, enable WSJT-X, point WSJT-X at that port: decodes arrive. Default 2237 still works.
- [ ] **BAND MAP SIZE / ITEM HEIGHT / ITEM WIDTH apply on Save, no restart.** With the band map open, change each in Preferences and Save: the spot text size (Size 0..8 = 10+n pixel cells, main-window face and bold) and the row/column geometry change at once. Check the text still fits the default row height at Size 8 (raise ITEM HEIGHT if not).
- [ ] **Preferences > Appearance** no longer has "Color the dupe sheet columns" (retired; nothing read it); an old config line naming it is ignored quietly.
- [ ] **Restart notes read true.** HamLib, WSJT-X, External Logger, Online scoring and Appearance pages: the sentence under each names only what really waits for a restart.

## Added 2026-11-02 -- THE K4'S OWN DISPLAY SETTINGS ARE PARSED (stages 1-2, nothing drawn yet)

TR4W now decodes `#REF`, `#REF$`, `#SCL`, `#WFH`, `#HWFH`, `#WBS`, `#HWBS`, `#AVG`, `#FPS` and `#AR` from the K4 and stores them on the radio (`uK4DisplayReport`, `TK4Radio.SpectrumRadioState`). The panadapter does NOT use them yet. At every network link-up it asks `#REF;#SCL;#AR;#WFH;#WBS;#AVG;` (reads only). Before stage 3 makes the window follow the rig, these questions need a real K4. Network K4, TR4W connected, `DEBUG LOG LEVEL = TRACE` in Preferences (every inbound message is logged as `[ProcessMessage] Received from radio: (...)`, and an accepted one also as `[K4] display report recorded: ...`).

- [ ] **The link-up answers.** Right after connect, tr4w.log shows one `#REF<v>`, `#SCL<v>`, `#AR<8 chars>`, `#WFH<v>`, `#WBS<v>` and `#AVG<v>` reply, each followed by `display report recorded`. Note whether values carry leading zeros (`#AVG02` or `#AVG2`, `#WFH050` or `#WFH50`) -- the parser accepts both because nobody knows which.
- [ ] **AutoRef survives the bare `#REF;` read.** With AutoRef ON, connect TR4W, then watch for 30 s or more: `#REF` pushes keep arriving and keep moving as the noise changes. A client `#REF<value>` is known to freeze AutoRef silently (QK4 quirks section 13); a bare read should not, but nobody has shown it. If REF stops moving after TR4W connects, that is a defect -- report it at once.
- [ ] **Front-panel capture, in this order, noting the clock time of each step** (so the log lines can be matched to the action):
  1. change SCALE a few steps;
  2. AutoRef OFF, then change REF a few steps;
  3. AutoRef ON, then OFF, then ON;
  4. change the AutoRef OFFSET (menu, -8..+8);
  5. change the waterfall height;
  6. change the waterfall colours (WTR CLRS);
  7. change averaging;
  8. change FPS.
     For each, record whether the radio PUSHES a `#` report unprompted. The quirks doc says `#AR` is pushed on every change and `#REF`/`#HREF` are pushed under AutoRef; **whether `#SCL`, `#WFH`, `#WBS` and `#AVG` are pushed is unknown** and decides whether stage 3 can rely on pushes or must ask. Also note any `#` report the parser does not know (it is logged and ignored).
- [ ] **The `#AR` debounce field.** Read the two digits after the averaging in each `#AR` line (`#AR12dd+oom`). QK4's command table says 4..9; captures have shown `01` and `06`. Record the values seen, and whether a menu changes them.
- [ ] **The sub receiver.** With SUB RX on, does `#REF$` arrive at link-up without being asked (TR4W does not ask `#REF$;`), or only under AutoRef? If only then, stage 3 needs `#REF$;` in the link-up queries.
- [ ] **The same, from outside TR4W.** With TR4W disconnected: `python tools/k4catwatch.py --host <ip> --ai 5 --query --seconds 60`, repeat the front-panel steps above inside the 60 s, and keep the output. `--query` now also asks `#WBS`, `#HWBS` and `#HREF`; it sends only bare reads.
- [ ] **Does `#AVG` average the STREAM, or only the radio's screen?** With the panadapter open on a quiet band, set averaging to 1 at the rig and watch the trace's noise jitter in TR4W for 20 s, then set it to 20 and watch again (a screenshot of each helps). If TR4W's trace smooths when the rig's does, the stream is already averaged and TR4W must not average again on top; if it does not change, `#AVG` is the radio's screen only and following it would mean TR4W doing its own averaging.

## 2026-11-03: line breaks in the New Contest comment label

The `\r` escape in eleven TC_ messages was shipping as the letter "r" (LazUtils does not decode it). The build now rewrites it to `\n` in the shipped copy. Only a screen can judge it.

Start the test build in German: `cd tr4w\target`, then `..\..\build-out\app-i386-win32\tr4w_fpc.exe uitest.cfg --lang de`. Open New Contest and select each contest. The comment label above the field should sit on two lines (the old build ran the halves together with an "r").

1. NA Sprint CW: "Gib dein QTH ein, das du senden willst" / "und den Namen:" (old: "...willstrund den Namen:").
2. ARRL Sweepstakes: two lines, no stray "r" before "(die".
3. RAEM: "Gib deine geografischen Koordinaten ein" / "(z. B. 55N37O fuer Moskau):".
4. New England QP with the "I am in" box ticked: "...New England Staat ein" / "(ME, NH, VT, MA, CT, RI):".
5. Optional: `--lang ru` for steps 1 and 2. Russian sweepstakes is one of four reviewed translations written on one line, so it shows one line with no stray "r".

Check on Windows and on Linux (gtk2). Windows breaks these with CRLF where the English uses a bare CR; no doubled blank line is expected. Not benched: TC_INVALIDSTATEMENTIN (no reliable trigger found). (TC_FOLDERALREADYEXISTSOVERWRITE, also listed here, was retired with issue 276.)

**Periodic HamScore score tick (2026-11-04):** `HamScoreScoreTick` calls `CalculateTotals`, which walks the WHOLE log on the main thread (every 5 s after a change, 30 s heartbeat). Not measured. Needs a latency measurement on a large contest log (tens of thousands of QSOs); watch for operator-visible stalls on Enter. Also confirm that with the log source unreadable the last posted score is kept and one warning is logged.

## Added 2026-11-05 -- STARTUP WINDOW FLASHING (issue 219)

Two changes; neither can be judged without a screen. (1) The tool-window restore no longer hands the keyboard back to the main window after EACH window (`OpenTR4WWindow(i, False)`); it does so once, at the end. Each window still activates as it is shown: the LCL has no way to show a form without activating it. (2) The "raise every window when you switch back to TR4W" handler (b8f4125c) is armed only AFTER the restore, so it can no longer raise everything a second time at start-up.

Set `DEBUG LOG LEVEL = TRACE` (the per-window `[Startup] restored ...` lines are Trace; the new raiser lines are Debug). "The previous build" means v5.0.36 from the release page or a build of `b4b92ef4`: `build-out\app-i386-win32\tr4w_fpc.exe` is already this build. Use the same contest and the same `settings\tr4w.pos` with many tool windows left open (band map, function keys, master, radio 1, telnet, the remaining-mults windows, HamScore, a panadapter).

- [ ] **Compare with the previous build.** Start the previous build (or v5.0.36) three times, then this build three times. Watch for these and note them for each start:
  - title bars switching between active and inactive colour, back and forth;
  - windows popping up, and then popping up AGAIN after they are all on screen (a second wave is the raiser);
  - the taskbar buttons blinking or highlighting in turn.
    Expected: about half the title-bar switching while the windows open (one per window, not two), and no second wave. The windows still appear one after another.
- [ ] **The caret ends in the call window**, and the main window is in front of the tool windows when start-up finishes.
- [ ] **In `tr4w.log` after start-up**, find `[Windows] activation raise armed, after the tool-window restore`. It should come after the last `[Startup] restored ...` (or `restoring the ... window took`) line. A `[Windows] activation raise:` line during start-up means the raiser still fired then; send that log.
- [ ] **The raiser still works later.** Click another program, then click a TR4W tool window. Every TR4W window should come forward with the main window on top, and the log should show `[Windows] activation raise: ... raised N tool window(s)`.
- [ ] **Opening a window from the Windows menu** still returns the caret to the call window (that path keeps the hand-back).

## Added 2026-11-05 -- FILE > OPEN LOG... (issue 218 S0; the New Contest dialog since issue 228, 2026-11-06)

File > Open Log... (the first item on the File menu, no keystroke) switches to another contest by RESTARTING: TR4W exits the way File > Exit does (radios unkeyed and shut down, restart file saved, score to UDP, backup copier stopped, network left, log closed) and starts a new instance on the chosen contest. The new instance is given `--wait-for-instance=<pid>` and retries the single-instance lock for up to 10 s while the old one finishes. Nothing is reset in place; that is S1-S6. **Since issue 228 the choice is the startup New Contest dialog, not a file picker.** Use `build-out\app-i386-win32\tr4w_fpc.exe` with two contests' `.db` files in the contest folder, radios connected, `DEBUG LOG LEVEL = DEBUG`.

- [ ] **The dialog shows.** File > Open Log opens the same window as at startup (grid of logs, Browse, New Contest side), titled "TR4W ... - Switch to another contest (TR4W restarts on the one you choose)".
- [ ] **No Last Contest button mid-session.** The last contest is recorded at startup, so it is the one open; the button is hidden and `tr4w.log` has `[NewContest] the last contest is the one open, so its button is hidden`. (The recorded file IS the one this session was started on, so from the menu the button is always hidden; Last Contest still shows at startup as before.)
- [ ] **Cancel does nothing.** Cancel, or close the window: TR4W keeps running on the same contest, nothing restarts; `tr4w.log` has `[OpenLog] the dialog was cancelled`.
- [ ] **The same contest does nothing.** Double-click the open contest's row: the notice line says "That log is already open." and TR4W keeps running.
- [ ] **An existing contest restarts on it.** Double-click (or select and Enter) another row, or Browse to another `.db`: TR4W closes and comes back on that contest (checks below).
- [ ] **A New Contest restarts on it.** Fill in the New Contest side (a contest, your call, its rows) and OK. TR4W closes and comes back on a NEW log named as at startup, with the contest, call, exchange rows and categories you chose (check the title, the exchange prompt and Cabrillo categories). `tr4w.log`: the old session has `[OpenLog] the new contest is handed over in <settings>\open-log-new-contest-<pid>.txt`; the new one has `[OpenLog] the new contest handed over in ... is queued` and `[NewContest] applied N of N setting(s)`. The hand-off file is gone afterwards. A club call typed here wins over the station call, as at startup.
- [ ] **Not a contest TR4W can open is refused before anything closes.** Browse with "All files" to a `.png` or another program's `.db`: the notice line says "Not a TR4W contest log, so it was not opened: ..." and TR4W keeps running. A `.cfg` is now ACCEPTED (the grid lists an un-migrated `.cfg` itself): TR4W restarts and imports it as a first start would.
- [ ] **Another contest closes cleanly and comes back on it.** Pick the other `.db`. TR4W closes (no exit question) and reopens on that contest within a few seconds, with its own QSOs, score and title. In `tr4w-early.log` beside the binary: `startup: started by File > Open Log -- waiting up to 10000 ms for instance <pid> to exit`, then `startup: instance <pid> has exited (waited N ms)`. There should NOT be an "already running" dialog. `tr4w.log` shows the old session's `[ExitProgram] Step SaveRestartFile` and `[OpenLog] starting ... on <file>` before `Program shutdown`.
- [ ] **The previous contest's restart file was saved.** Open the first contest again with File > Open Log: its QSO count, mult totals and serial number continue where they were.
- [ ] **The radios reconnect** in the new instance (both slots, serial and network), and nothing stays keyed across the switch. A network radio (K4, IC-9700 LAN) must accept the new session without a power cycle.
- [ ] **The DX cluster, WSJT-X and TCI reconnect** in the new instance: the cluster logs in with your call without "already connected", and WSJT-X / a TCI client find their ports free. (The child is started with no inherited handles, so it holds none of the old instance's sockets.)
- [ ] **Refused while transmitting.** Key the radio (PTT, a voice message, or WSJT-X TX) and choose File > Open Log: the notice says "Open Log was not done: a radio is transmitting...", and the dialog does not open. With a long CW message playing: "...a CW message is still being sent...". Also key WSJT-X while the dialog is open and then choose a contest (or OK a New Contest): it should still refuse, and TR4W keeps running on the same contest.
- [ ] **Started with `--settings` or `--lang`**, the new instance uses the same settings file and language (both are carried forward).
- [ ] **Multi-op (if a server is up).** The old instance leaves the network normally and the new one reconnects and catches up as at an ordinary start. Not refused on purpose in S0.
- [ ] **Linux / macOS:** there is no single-instance lock off Windows, so the new instance does not wait. Check it starts and opens the log (the old one has closed the log before starting it). On Linux run it FROM THE APPIMAGE: the relaunch starts the `.AppImage` file (`$APPIMAGE`), not the binary inside the old instance's mount, which goes away when the old instance exits. macOS relaunches the binary inside the bundle and is untested.

## Added 2026-11-05 -- NEW CONTEST: QSO PARTY IN-STATE COUNTY (issue 217)

New Contest, for a US QSO party, now shows an "I am in <area>" box above the party's row. Ticked: the row reads MY COUNTY and is a drop-down of the party's county codes (Texas shows "ANDE - Anderson"; Florida shows the bare code). Unticked: the row reads MY STATE and takes a US state, a Canadian province or DX. Anything else is refused, with the reason shown in the notice line and OK greyed. The value saved is MY STATE either way, with the same text as before (ALC chosen = ALC typed). The unit tests drive this on a form that is never shown; only a screen can judge the layout. Use `build-out\app-i386-win32\tr4w_fpc.exe` from a full `.\build\Build-App.ps1`. That build reports BUILD FAILED on the narrowing ceiling (1207 vs 1201; HEAD `fc20d3c9` measures the same without this change), but it links the exe first. Check the exe's timestamp is from that run.

- [ ] **Florida QSO Party, in Florida.** Choose it. The box reads "I am in FL", unticked, and the row reads MY STATE. Tick it: the row becomes a list labelled MY COUNTY, the notice reads "You are in FL: choose your county from the list.", and OK stays grey until a county is chosen. OK must enable THE MOMENT a county is clicked in the list (the unit test raises the list's OnChange itself; whether a real click raises it is only visible here). Choose ALC, create the contest, and in the new log check that MY STATE is ALC and the session is "(in state)" (title bar or `tr4w.log` `[FCONTEST]`). A QSO's sent exchange is your county.
- [ ] **Florida, out of state.** Leave the box unticked and type GA: OK enables. Type XX: the notice says it is not a state, province or DX, and OK greys. Type ALC or FL: the notice says to tick the box. Type DX and ON: both accepted.
- [ ] **Another party with named counties (Texas QSO Party).** Tick the box: the list shows "CODE - Name". Choose one: the saved MY STATE is the code alone (ANDE, not "ANDE - Anderson").
- [ ] **A party that asks for a name too (Colorado or Minnesota).** Type MY NAME, then tick and untick the box. The name must still be there, and only the state/county row changes.
- [ ] **The 7QP.** The box reads "I am in 7th area" and the list is the 7th-area county codes (AZAPH ...). Typing AZ (or any of the eight 7th-area states) while unticked is refused with "tick the box"; CA is accepted.
- [ ] **Unchanged parties.** British Columbia, Ontario, Quebec and IN7QPNE show NO box: the same free-entry row and notice as before.
- [ ] **Layout.** The MY COUNTY drop-down sits exactly where the box does, the same width, and the label is not clipped. The drop-down list scrolls for Texas (254 entries). Check the box caption and notices in a second language (`--lang de`): the new strings are untranslated until the resourcestring harvest, so English is expected there today.
- [ ] **Linux (gtk2).** The same, once: the drop-down list is a real list (no typing into it).

## Added 2026-11-05 -- CA BUNDLE MISSING (issue 221)

`cacert.pem` is now looked for in the data directory (the working directory on Windows) and then in the folder the program is in. If it is in neither, Club Log and World Radio League uploads are held back (nothing is sent), retried every 5 minutes, and the operator gets ONE notice per service. The unit tests drive the lookup order, the classification and the once-only text; only a screen can judge the notice. Use `build-out\app-i386-win32\tr4w_fpc.exe` (it has the OpenSSL DLLs and no `cacert.pem`), a Club Log or WRL logger enabled with a valid key, and `DEBUG LOG LEVEL = DEBUG`.

- [ ] **Started from the build-out folder with no `cacert.pem` anywhere.** Log a QSO. A warning box appears within a few seconds: "<service>: The certificate file cacert.pem was not found (looked in: <two paths>); uploads to <service> are paused until it is available." It must name BOTH places and appear once, not on every retry or every QSO.
- [ ] **`tr4w.log`** has one `[TLS] The certificate file cacert.pem was not found ...` line and one `[HTTP] REFUSING ...` Error line per service/episode, not one per retry; no key or token anywhere. The delivery shows `CLUBLOG_CA_BUNDLE_MISSING` / `WRL_CA_BUNDLE_MISSING` and the QSO stays pending (not failed, not "needs review").
- [ ] **Copy `target\cacert.pem` beside `tr4w_fpc.exe`** (leave the working directory elsewhere). Within about 5 minutes the pending QSOs upload, and `tr4w.log` shows `[TLS] CA bundle: <path> (beside the program)`. Start from `target\` instead: the line says `(data directory)`.
- [ ] **A second service** (enable both Club Log and WRL with no bundle): each gets its own notice, once.
- [ ] **Linux AppImage / macOS bundle:** with the bundle present the log names the tier that answered; macOS reports the bundle's Resources folder as the data directory.
- [ ] **HamScore with no `cacert.pem`** (https URL, HamScore enabled): the HamScore status window reads "Not sent: cacert.pem not found (looked in: <places>) -- N QSO(s) retained", the pending count does not fall, and `tr4w.log` has one `[TLS]` warning for HamScore. Rename the file back: the next cycle (about 2 minutes) uploads them.
- [ ] **Rename `cacert.pem` away, then Alt-O (CTY download)**: the dialog names the missing certificate file and where it looked, and the existing `cty.dat` is untouched.

## Added 2026-11-06 -- EXTERNAL LOGGER GRID: ENABLED CHECKBOX AND CONNECTION STATE (issue 226)

Preferences > External Software > External Logger. The grid now has an Enabled checkbox column and a Connection column; Enabled is the same flag as Order (a dash = off) and the popup's Send new QSOs. A change applies after Save and restart; the Connection column is read from the running program and re-read every 5 seconds while the page shows. Colour repeats the text and is never the only signal; the selected row keeps the theme colours.

- [ ] **Toggle a row off, then on.** Click the Enabled box of an active logger: the box clears, Order becomes a dash, the row drops to the inactive group, the status line says Save Preferences and restart, Preferences shows as changed. Click it again: it returns to the end of the active order. A double-click on the box toggles ONCE (not three times) and does not open the editor. Space on the selected row toggles it. Cancel discards the change; Save keeps it across a restart.
- [ ] **Disabled.** A switched-off logger that was also off at start-up reads "Disabled" in grey.
- [ ] **Restart needed.** (Changed by issue 233: Enabled and Order now apply on Save with no restart, see the 2026-11-06 section below.) Tick a logger that was off at start-up, or untick one that was on: "Applies on Save" in violet until Save, then Idle or Disabled with no restart. "Restart TR4W to apply" in amber now means a logger ADDED since start-up, or one whose key/host was edited.
- [ ] **Idle.** With a log open and a working destination (Club Log, WRL or DXKeeper), the row reads "Idle" in green. A DXKeeper row has no last result, only a queue depth.
- [ ] **Sending.** Stop DXKeeper (or take the network down for WRL/Club Log), log two or three QSOs: the row reads "Sending (n pending)" in blue (DXKeeper) or "Retrying: <code>" in amber (WRL/Club Log, with the destination's own error code); the count falls to Idle when it recovers.
- [ ] **Paused with a notice.** Start with no `cacert.pem` (see the CA bundle item above): the row reads "Retrying: ..._CA_BUNDLE_MISSING" (a retry, not a pause). Give Club Log or WRL a refused credential (401/403) or an http:// URL: "Paused: <code>" in orange-brown; it stays paused until the log is reopened or TR4W restarts.
- [ ] **Old failures.** A log with earlier failed or uncertain deliveries but a healthy destination reads "Idle (n uncertain, m failed)", not Failed.
- [ ] **The click does not fight the drag.** Drag a row by its Order cell while the timer ticks (wait 5 s mid-drag); the row lands where dropped and the selection stays on it.
- [ ] **No loggers configured.** With an empty library the placeholder row shows "No loggers configured" and the LCL draws an indeterminate (grey) checkbox in the Enabled cell. Cosmetic; clicking it does nothing. Say if it should go.
- [ ] **Layout.** All five columns are readable at the page's width (the State text is not clipped for "Retrying: WRL_VERIFICATION_UNAVAILABLE"); the checkbox is centred; the hidden columns are not visible; Linux (gtk2) draws the same.
- [ ] **The columns fill the grid (follow-up).** No gap between the Connection column's right edge and the grid frame, at the page's designed width and after widening the Preferences window. The vertical scrollbar is ALWAYS there (disabled while the loggers fit) -- an automatic one left a 17 px gap or clipped Connection by 17 px when the logger count crossed what the grid holds, and failed the CI runner -- so adding loggers until it scrolls, and removing them again, must not move Connection's edge. Say if a permanent disabled bar looks wrong on this page. Only Connection changes width; Order, Logger, Provider and Enabled keep 60/190/110/70. Measured off screen on Windows: Connection 199 px beside the bar at the designed width. Below ~580 px of grid the Connection column stops at 150 px and the row is clipped (no horizontal scrollbar with AutoFillColumns) -- say if that ever happens at a real window size.
- [ ] **Header dividers drag (goColSizing).** Drag the dividers between Logger, Provider, Enabled and Connection headers: the column follows the pointer and Connection takes up or gives back the difference, leaving no gap. The Order divider does not drag. Drag Connection's right edge (the grid's edge) to the right: nothing changes, and no extra column or digits appear -- they may FLASH during the drag and must vanish on release (the LCL resizes the hidden ordinal column there; `OnHeaderSized` puts it back to 0). Widening Logger until Connection reaches 150 px clips the row with no horizontal scrollbar (AutoFillColumns). Dragged widths for Logger, Provider and Enabled are kept (issue 234); Connection is never saved. Measured off screen by a real LCL mouse drag in `Test_Grid_HeaderDragResizesAndHiddenColumnsStayHidden`; Linux (gtk2) unmeasured.

## Added 2026-11-06 -- EXTERNAL LOGGERS APPLY ENABLED AND ORDER ON SAVE, NO RESTART (issue 233)

Save in Preferences now switches each running logger on or off and sets the delivery order immediately. The rule, the composite and the durable worker park/restart are unit-tested (`uTestExternalLoggers`, `LiveApplyTests`, including a dispatcher held open mid-delivery); what no test can do is the real dialog, a real destination and a real log. Use Club Log or WRL in TEST mode (or DXKeeper) and a contest open. Watch `tr4w.log` for `[ExternalLoggers] Destination ... switched on/off without a restart` and the provider's own lines.

- [ ] **Enable live.** With two loggers configured and one Enabled, tick the other's Enabled box: its Connection cell reads "Applies on Save". Save (Save and close, or Apply). Without restarting, log a QSO: tr4w.log shows the delivery for BOTH loggers for that QSO, and the second one's Connection cell leaves "Applies on Save" (Idle, then Sending/Idle) within 5 s if Preferences is still open.
- [ ] **No backfill.** QSOs logged BEFORE the enable are not sent to the logger just enabled (nothing in its queue for them), only QSOs logged after Save.
- [ ] **Disable live.** Untick Enabled, Save, log a QSO: the disabled logger shows no delivery line for it, the other one does. Edit or delete one of the QSOs that logger already holds: that edit IS still sent to it (existing bindings keep following edits), as before.
- [ ] **Queued work survives a disable.** Take a logger offline (no network), log two QSOs so they sit pending, untick it, Save: the pending count in its Edit dialog is unchanged. Tick it again, Save, restore the network: the two QSOs are delivered once each (no duplicates at the destination).
- [ ] **Quick off/on while a request is out.** With a slow or blocked destination, untick, Save, tick, Save at once: no second worker (one `[ExternalDelivery]` worker per logger in the log), no freeze of the Preferences dialog.
- [ ] **Order.** Drag two active loggers into the reverse order, Save, log a QSO: the lines for the two loggers appear in the new order.
- [ ] **A changed key or host is NOT applied live.** Edit an active logger's API key (or the DXKeeper host), Save: the status line says N logger(s) apply after you restart, its Connection cell reads "Restart TR4W to apply", and the next QSO still goes with the OLD settings. Restart: the new settings are used. Untick a logger whose key was edited, Save: it stops at once.
- [ ] **Remove live.** Remove an active logger's definition, Save: it receives nothing new. Add a brand-new logger and tick it, Save: its row reads "Restart TR4W to apply" until restart.

## Added 2026-11-09 -- THE WINDOWS (WinHTTP) HTTP TRANSPORT, NETWORK HTTP TRANSPORT (issue 224, S2)

Needs a Windows 11 machine (Windows 10 may work and is unsupported). The transport is built and its plain-HTTP
loopback contract suite is green; the default stays `generic`. Everything below is what no loopback test can
prove (docs/HTTP_TRANSPORT_DESIGN.md, "S2, as built" and section 5). Set Preferences > Network > "How downloads
and uploads connect" to `auto`, Save, and read `tr4w.log`.

- [ ] **It is selected, and OpenSSL is not.** After the first request the log has `[HTTP] transport: winhttp (setting: auto)`. With `cacert.pem` deliberately absent from beside the exe (and from the data directory), no `[TLS] CA bundle` line and no OpenSSL load appear, and a version check, a CTY download and a TRMASTER download succeed. (This is the failure class of issue 221 gone.)
- [ ] **Switching live.** Change the setting to `generic`, Save, make a request: a second `[HTTP] transport: generic (setting: generic)` line; back to `auto`: `winhttp` again. No restart. Setting `platform` on this machine selects winhttp; there is no Warn.
- [ ] **A good host.** `https://tr4w.net/version.json` (the Help menu's version check) works; note the TLS version in a capture if one is handy.
- [ ] **Club Log and WRL.** A Club Log test-mode create and a WRL create against throwaway accounts each settle confirmed.
- [ ] **A bad certificate is refused, and nothing was sent.** badssl.com's expired, wrong.host, self-signed and untrusted-root hosts, through an external-logger style caller that does not follow redirects: each settles with a `*_NOT_SENT` retry code and the request is absent from the server's log. (A caller that follows redirects reports "may have been sent" for the same failure by design.)
- [ ] **Verify off.** With `network.verifyServerCertificates` false, the self-signed host proceeds and the Warn line says checking is OFF.
- [ ] **Timeouts.** A black-holed address (for example `http://10.255.255.1/`) with the callers' 5 s connect timeout: record the real return time and the failure kind. The IO timeout was measured to be rounded up to a multiple of about 4 s (so 5 s gives 8 s); the connect timeout was NOT measured and may do the same. A timeout is `hfIOTimedOut` ("may have been sent"), never a not-sent kind.
- [ ] **A proxy.** With a real system proxy configured (and, separately, a PAC file): the request goes through it. On a network with no WPAD server, a request does not stall (the loopback tests did not, but they bypass the proxy). Record what `WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY` honours: the user's Internet Options or the machine's WinHTTP setting.
- [ ] **An https to http redirect is refused.** A URL that answers 302 from https to http: the request fails, the log shows `ERROR_WINHTTP_REDIRECT_FAILED`, nothing is followed. (The plain-HTTP loopback suite cannot test this.)
- [ ] **A plain `http://` URL: what the transport does, and what the program says (HSTS).** Measured with `curl` on 2026-11-09, NY4I's two sites: `http://uparc.org` answers `200 OK` directly over plain http, with no redirect (the site sends `strict-transport-security: max-age=31536000; preload; includeSubDomains` only on https, so a browser upgrades the URL from its own preload list and a client without that list never does); `http://ny4i.com` answers `301 Moved Permanently` with `Location: https://ny4i.com/`. Neither WinHTTP nor FPC's client is believed to carry an HSTS cache or preload list (unverified), so request both URLs through the WinHTTP transport and through the generic one, with a caller that follows redirects and one that does not, and RECORD each result here: the status, the final URL, whether any request left as plain http, and the exact error text or log line when a request is refused (plain-http not allowed without `AllowInsecure`, or a refused redirect). Expected: `uparc.org` returns its plain 200 with no upgrade; `ny4i.com` is followed to https when redirects are followed and ends at the 301 (not an error) when they are not. A caller that sends Basic credentials must not send them in that first plain request. Whether to add an explicit upgrade-to-https for credentialed destinations is a decision after this record.
- [ ] **HamScore, contest score post, SCP upload.** HamScore over `https://` (the default since issue 250) and, deliberately, over plain `http://` with its Basic credentials; the contest score post; the SuperCheckPartial upload of a large Cabrillo body. Each completes, and the version check (main thread) does not freeze the window for longer than its timeouts.
- [ ] **The Preferences row.** On the Network page, "How downloads and uploads connect" under "Internet downloads and uploads": the caption fits, the drop-down offers generic, auto and platform, and the tooltip shows the help text (needs `help\` staged beside the exe).

## Added 2026-11-09 -- THE TEST BUTTON BESIDE EACH ONLINE SCORING URL (issue 251)

Written with no screen and no network: unit tests pin the wording, the request (a fake transport) and the worker; the layout, the real answers and the live control are below.

- [ ] **The page fits at its design size.** Preferences > Online scoring: a **Test** button right of each of Service URL, Posting URL and Reading URL (edit boxes are 380 wide now, were 420), a one-or-two-line result under each, the plain-http note under the HamScore result, and nothing overlapping or clipped (the form was re-laid by hand: everything below the HamScore row moved down 36 px, the score board rows by 72 px; the last hint ends near y 547 of 572). Check at 100% and at 150%, and that Tab goes URL, Test, next field.
- [ ] **Each button asks its own box, and only that.** Type an address that is not saved, click Test: the label shows `Asking...`, then the answer for the TYPED text; Save stays as it was (greyed if nothing else changed; a Test never arms Save). Editing the box clears the result. Closing Preferences while it is asking neither waits nor crashes.
- [ ] **Real answers, both transports** (Network > How downloads and uploads connect: generic, then platform). Record the exact label text for: `https://hamscore.com/postxml/` (a POST endpoint: expect a status, perhaps 405 or 200), `http://uparc.org` (plain 200), `http://ny4i.com` (a 301 followed: `Answered 200 from https://ny4i.com/`), a path that is 404, a host that does not exist, a closed port, a host that never answers (timeout 10 or 15 s, WinHTTP rounds up to about 4 s), `https://expired.badssl.com/` and `https://self-signed.badssl.com/` (certificate rejected), and with `cacert.pem` hidden (the trust sentence). Put the results in `docs/HTTP_TRANSPORT_DESIGN.md` section 11, which says which kinds each transport is expected to produce. `FinalURL` from WinHTTP (`WINHTTP_OPTION_URL`) has never run: confirm it shows the redirected address and nothing for a bare host.
- [ ] **No credentials leave.** With a packet capture or the HamScore server log: the test request carries no Authorization header, no username or password, and no body (the generic transport sends `Content-Length: 0` on the GET, as `THttpRequest.Send` always does).


## Added 2026-11-09 -- ARRL 10: THE NEEDS STRIPS AND TOTALS HEADERS SHOW 10 M ONLY (issue 56)

`TContestARRL10` now states `UsesBand` (10 m only). Unit tests drive the strips and headers on the streamed form; the screen and a real log are below.

- [ ] **Mult needs for a state.** ARRL 10 on 10 m CW, type a W/VE call, enter `AZ`: "Mult needs for AZ" shows 10 on the CW and SSB rows and nothing under 160-15. Log it on CW: the CW row clears and SSB still shows 10. Switch to SSB and repeat.
- [ ] **The totals grid.** The 160-15 column headers are blank, 10 and All are named, and the numbers sit under 10 and All.
- [ ] **An off-band QSO** (log one on 20 m by mistake): it scores 0, earns no multiplier, is not a dupe, and the Cabrillo writes it as `X-QSO:`. A rescore of an existing ARRL 10 log zeroes any such QSO.

### 2026-11-10 Band map: Hide digital spots (issue 73)

- [ ] Preferences > Band map: the **Hide digital spots** checkbox sits under "Show GHz"; the note and the last two checkboxes are not overlapped or clipped.
- [ ] Searching "filter out digital" in Preferences finds the checkbox.
- [ ] With a live cluster, turning it on makes FT8, FT4 and RTTY spots disappear from the band map at once, no restart; CW and SSB stay. Turning it off brings them back; the setting survives a restart.
- [ ] A bare spot at 14.074 to 14.077 MHz is hidden (frequency rule); a spot commented "CW" at 14.074 MHz stays visible; a CQ marker on an FT8 frequency stays visible.
- [ ] Ask NY4I whether a band map right-click toggle is wanted too (the issue asked only for the Preferences setting).

## Added 2026-11-10 -- THE VERMONT QSO PARTY (issue #130)

A new by-id contest (`VT-QSO-PARTY`), built from the sponsor's 2027 rules
(`docs/ContestRules/QSOParties/Vermont/`). Unit-tested
(`uTestContestVermontQP`, including a real-engine run for an out-of-state and
an in-state entrant); nothing sees the screen, the multiplier windows or a
written file.

- [ ] **In Vermont** (New Contest, tick "I am in VT", county `CHI`). Type
  `599 NY` on 20 m CW, then `59 NY` on 40 m SSB: EXPECT both are new
  multipliers (once PER MODE), and `599 NY` on 40 m CW is not. `599 DC` is
  multiplier **MD**. `599 CHI` for another Vermont station is the county
  multiplier.
- [ ] **A county does NOT also give VT** (NY4I's ruling is not built): after a
  `CHI` QSO, a station sending `599 VT` is still shown as a new multiplier.
  Confirm that is what the screen says, so the gap is visible.
- [ ] **A DX station sends RST only.** In Vermont, work DL1xxx and type just
  `599`: EXPECT it is taken, scores 3 on CW, is a new **DX** multiplier, and
  the Cabrillo received column reads `599 DL` (the DXCC prefix, not `DX`).
  With the exchange EMPTY it is refused today (pinned): the operator must
  type the RST. Ask NY4I whether a blank DX exchange should be taken.
- [ ] **FT8 and FT4.** A WSJT-X FT8 QSO logged from WSJT-X scores 2 and earns
  NO multiplier of any kind (county, state, DXCC); its grid multipliers are
  not built. Outside Vermont, a WSJT-X QSO whose exchange is a grid is
  refused / an X-QSO (the host-area table knows counties only) -- check what
  the log shows for a real WSJT-X-logged QSO.
- [ ] **WARC.** A 30, 17 or 12 m QSO in any mode, FT8 included, is a greyed
  X-QSO (the rules allow FT8/FT4 there; TR4W cannot say so yet).
- [ ] **A county line.** In Vermont, `599 LAM/ORL` logs two QSOs; `599
  LAM/ORL/FRA` is refused ("too many counties", maximum 2).
- [ ] **A DX entrant** (MY CALL DL1xxx; New Contest, MY STATE `DX`, and once
  more with MY STATE empty): EXPECT the CQ exchange is `5NN` alone, the ADIF
  `STX_STRING` is `599` alone, and the Cabrillo sent column is `599 DL` --
  never `DX`.
- [ ] **The power multiplier.** Set CATEGORY-POWER to LOW on a log whose points
  x multipliers is odd: EXPECT the CLAIMED-SCORE is x1.5 rounded half to
  EVEN (13.5 -> 14, 22.5 -> 22). QRP doubles; HIGH and unset are x1.
- [ ] **The Cabrillo header.** Export with LOCATION empty: EXPECT the
  "location field empty" warning (the rules reject a log without one). Check
  b4h.net/vtqp accepts the file as written, and that a log holding FT8 QSOs
  needs splitting by hand (the rules want those in a separate ADIF upload).
- [ ] **WA7BNM and 3830.** The class states WA7BNM 0 (not found). Look the
  contest up on the calendar and on 3830scores.com; if 3830's form breaks
  the multipliers out, the class needs a `Get3830Summary`.

## Added 2026-11-10 -- THE NEW HAMPSHIRE QSO PARTY (issue #112)

A new by-id contest (`NH-QSO-PARTY`), built from the sponsor's 2026 rules
(`docs/ContestRules/QSOParties/NewHampshire/`). Unit-tested
(`uTestContestNewHampshireQP`, including a real-engine run for an
out-of-state and an in-state entrant, each with its own MultByBand); nothing
sees the screen, the multiplier windows or a written file. NOT the New
England QSO Party.

- [ ] **Out of New Hampshire** (New Contest, MY STATE `NY`). Type `599 BEL` on
  20 m CW, then on 40 m CW, then `59 BEL` on 20 m SSB: EXPECT Belknap is a
  new multiplier on 20 and on 40 m (once PER BAND), and the SSB QSO is no
  dupe but no new multiplier (not per mode). The multiplier window and the
  summary count 2, not 1. `599 NY` is refused ("work NH stations only").
- [ ] **In New Hampshire** (New Contest, tick "I am in NH", county `HIL`).
  `599 NY` on 20 m CW is a new multiplier; on 40 m CW and on 20 m SSB it is
  NOT (every multiplier counts ONCE). Check the session really came up with
  multipliers not by band: the in-state answer comes from the class's
  `DescribeSession`, and nothing but the unit test has seen it applied.
- [ ] **`599 NH` in state** is taken and scores, but shows NO multiplier (an
  NH station sends its county). `599 DC` is multiplier **MD** (a question
  on #112).
- [ ] **A DX station sends DX.** In New Hampshire, work DL1xxx and type
  `599 DX`: EXPECT 2 points on CW, a new DX multiplier, and the Cabrillo
  received column `599 DX`. Work more than 10 DXCC countries: EXPECT the
  multiplier window and sheet keep counting them, but the CLAIMED-SCORE
  counts only 10 ("up to 10 DXCC country") -- decide whether the display
  should say so.
- [ ] **A DX entrant** (MY CALL DL1xxx; New Contest, MY STATE `DX`, and once
  more with MY STATE empty): EXPECT the CQ exchange is `5NN DX`, the ADIF
  `STX_STRING` is `599 DX` and the Cabrillo sent column is `599 DX` both
  times.
- [ ] **Bands and modes.** A 160 m, 6 m, WARC or RTTY/FT8 QSO is logged as a
  greyed X-QSO (0 points, no multiplier). FM on 10 m scores 1 and is the
  same dupe as SSB on 10 m.
- [ ] **A county line** (a question on #112: the rules are silent; built as
  two). `599 GRA/COO` logs two QSOs; `599 GRA/COO/CAR` is refused ("too many
  counties", maximum 2).
- [ ] **Between the sessions.** A QSO stamped 0400-1200 UTC Sunday still
  scores (the contest period is not built); confirm the operator sees no
  warning, so the gap is visible.
- [ ] **The Cabrillo file.** `CONTEST: NH-QSO-PARTY` (DXLog's name; the rules
  give none). Check https://w1wqm.org/submit-log.php accepts the file as
  written.
- [ ] **WA7BNM and 3830.** The class states WA7BNM 0 (not found). Look the
  contest up on the calendar and on 3830scores.com; if 3830's form breaks
  the multipliers out, the class needs a `Get3830Summary`.

## Added 2026-11-11 -- SECTION ALIASES ON IMPORT AND THE ERASE-MODE YEAR WINDOW (issues 265, 266, 267)

- [ ] **Import a D7 ADIF into Sweepstakes or Field Day.** The file carries ARRL_SECT EM (or QTH WF, SN, NY). EXPECT the log shows EMA (WCF, SNJ, NLI), the multiplier window counts it once beside a typed EMA, and a re-export writes the resolved ARRL_SECT. Work a real section contest's import before relying on it.
- [ ] **Field Day / Winter Field Day ADIF STATE.** Log a QSO with an alias section (WF, SN, ST, NY, LOS). EXPECT the exported ADIF has the STATE of the resolved section (WF is WCF, state FL; SN is SNJ, NJ; ST is STX, TX) and ARRL_SECT is the resolved section.
- [ ] **DXKeeper hand-off in a section contest.** Log EM or WF with DXKeeper connected. EXPECT DXKeeper receives EMA or WCF in ARRL_SECT, never the typed alias.
- [ ] **EUHFC or KVP, remaining multipliers in erase mode.** Work year 85, then look at the multiplier window. EXPECT 85 is gone and 84 and 86 remain (it used to hide 84 and keep 85). Year 00 is listed until worked.
- [ ] **A refused CQ zone.** In CQ WW CW type 599 45, then 599 55. EXPECT both refused with Improper zone number, and the zone field does not keep the typed value. CQ zones above 40 are no longer accepted (50-59 used to get through).

## Added 2026-11-11 -- THE CQ WW RTTY EXCHANGE PARSER (issue 274)

- [ ] **CQ WW RTTY, type the exchange the way an operator does.** On RTTY or CW: `599 5`, `599 14`, `599 5 CT` and `599 CT 14` are accepted with the zone and QTH read; `14 CT` (no RST) is accepted too. EXPECT the Exchange window shows the zone and the multiplier needs correctly and the Cabrillo line carries the typed exchange.
- [ ] **Refusals show a message.** Type `599 CT` (no zone), `599 45` (above 40), `599 14 ZZZ` and `JOE 10 CT`. EXPECT a message each time (Not enough info in exchange, Improper zone number, Improper domestic QTH naming the file, Invalid Entry) and no zone or QTH left in the entry fields. In QSL AND LOG mode a refused entry now logs no zone or QTH.
- [ ] **ARRL RTTY Roundup** uses the same parser without a zone: `599 CT` and `599 GA` are accepted with no zone needed.

## Added 2026-11-11 -- THE EUHFC AND KVP YEAR PARSER (issue 281)

- [ ] **EUHFC and KVP, type the licence year.** On CW: `599 85`, `85 599`, `599 5`, `599 00`; on Phone: `59 85`, `59 00`. EXPECT each is accepted with the year shown as the received exchange and counted once per band regardless of mode. `599 123`, `599 1982` and `599 CT` are refused with a message (it still says Improper zone number, which is awkward wording for a year). In the call window of a booted contest, also check `599 00` on Phone is refused WITH a message (the engine path returned an empty one in the unit test).

## Added 2026-11-11 -- A WORD BEFORE THE NUMBER IS NO LONGER TAKEN AS THE QTH (issue 263)

- [ ] **RSGB-IOTA.** Type `5NN 12 EU5`, then `EU5 12` and `599 12 EU5`. EXPECT the first refused with Improper domestic QTH (5NN not known) and nothing left in the entry; the other two accepted with island EU-005 and the multiplier needs header naming the call. Typing the canonical `EU-005` is still refused (3-5 characters, as in D7).
- [ ] **UBA-DX, RSGB-160, UK/EI, DARC 10 m.** `CT 123` or `JOE 123` (word first) is refused with a message naming the contest's domestic file where that file does not list the word; DARC 10 m still takes any word.

## Added 2026-11-11 -- AUTO-SEND NO LONGER KEYS THE POSSIBLE-CALL KEYS (issue 258)

A DEPARTURE FROM D7, which keyed them. `MainUnit.AutoSendKeysCallWindowKey`.

- [ ] **Each keyer: WinKeyer, CPU (DTR/RTS), and CW-by-CAT on a KY radio (K3/K4 or a Kenwood) and on an Icom.** In CQ mode on CW, with AUTO SEND CHARACTER COUNT 3, type `W1A`, then while it is keying press `,` `.` `;` (or the remapped POSSIBLE CALL keys), then finish the call. EXPECT none of the three is heard (no comma, period, AA or extra gap), the possible-call selection still moves and `;` still accepts, and letters typed after them are still keyed. On a KY radio, EXPECT no `?;` error reply from the radio after `;` (a keyed `;` used to end the `KY` command early).
- [ ] **Accept key mid-auto-send (NOT changed, ruling needed).** Press `;` to accept a possible call while auto-send is keying the partial call. Note what is keyed: the call in the window is replaced, but only the characters typed so far went out. Read from code (issue 29 trace), not observed: `ReturnInCQOpMode` does not resend the call while auto-send ran, so the accepted call may never be keyed in full.

## Added 2026-11-11 -- A TAKEN NEW-CONTEST LOG NAME ASKS THREE WAYS, NEVER "OVERWRITE" (issue 276)

The numbering is unit-tested (`uTestLogNaming`: free, taken, two taken, a gap, a sanitised call, the disk). The dialog and the re-shown New Contest window are not: nothing drives them. `uNewContest.AskAboutATakenLogName`, `SaveNewContest`, `RunNewContestDialog`.

- [ ] **The question.** Create CWOps CW Open as W1AW, log nothing, close. Start again, choose CW Open, same call, OK. Expect a box titled "This contest already has a log" naming `CWOPEN <date> W1AW.db` and `CWOPEN <date> W1AW 2.db`, with three buttons: **Create new log** (the default: Enter picks it), **Open existing log**, **Cancel** (Escape and the close box are Cancel). The word "Folder" and "Overwrite" appear nowhere. Windows and Linux (gtk2: the button order is the desktop's, which is expected).
- [ ] **Create new log.** A new empty log `CWOPEN <date> W1AW 2.db` opens, serials from 1; the first log is untouched (its QSO is still there when opened later). A third session gives ` 3.db`.
- [ ] **Open existing log.** The existing log opens with its QSOs; no new file appears in the logs folder.
- [ ] **Cancel.** The New Contest window comes back as it was left (contest, call and fields still filled in); choosing another contest and OK proceeds normally, and nothing from the cancelled pass is applied. No file is created.
- [ ] **File > Open Log, same three.** From a running contest, File > Open Log, New Contest for a name that is taken: Create new log relaunches on the numbered log; Open existing log relaunches on the existing one (or says it is already open, if it is the running log); Cancel returns to the dialog and the session continues if that is then cancelled.

## Added 2026-11-11 -- THE LICENCE-YEAR ROW IS LABELLED FOR WHAT IT HOLDS (European HF Championship, KVP)

The row beside "Enter the last two digits of the year of your first official amateur radio license:" read MY ZONE (a D7 artifact). The contest now names the row (`TNewContestPrompt.RowLabel`, `uAppStrings.SNewContestLicenseYearLabel`); the command queued is still MY ZONE. Unit-tested on a never-shown form (`uTestNewContestHostArea.Test_ALicenseYearRowQueuesMyZone`); not seen on a screen.

- [ ] **European HF Championship.** New Contest, choose European HF Championship. Expect the row beside the year prompt to read **MY LICENSE YEAR**, and no row to read MY ZONE. Type `64`, OK. Expect the new log's MY ZONE to be `64` (Preferences, or the sent exchange's year). Windows and Linux (gtk2): the label fits beside its field.
- [ ] **KVP.** The same with KVP.
- [ ] **Another contest is unchanged.** Choose NAQP CW: its rows still read MY STATE and MY NAME. (The Jock White Field Day still asks for a branch number on a row reading MY ZONE -- the same artifact, deliberately not changed here; it gets a label once NY4I says what to call it.)

## Added 2026-11-11 -- THE CWT'S QTH-OR-MEMBER ROW IS LABELLED FOR WHAT IT HOLDS; SUBMIT ARRL LOG IS GREYED OUTSIDE AN ARRL CONTEST

The CWT's row beside "Enter your name and QTH (US state, Canadian Province or DX country) or member number:" read MY STATE. The contest now names the row (`uAppStrings.SNewContestQTHOrMemberLabel`); the command queued is still MY STATE. Tools > Submit ARRL Log opens the ARRL's portal and was enabled for every contest; it is now greyed unless the contest says `SubmitsLogToARRL` (the ARRL DX, Sweepstakes, 160, 10 m, Digi, three VHF runnings, RTTY Roundup and Field Day). Unit-tested (`uTestNewContestHostArea.Test_ACWTMemberRowQueuesMyState` on a never-shown form, `uTestContestUI.Test_OnlyARRLContestsOfferTheARRLLogPortal`); neither seen on a screen.

- [ ] **CWT row label.** New Contest, choose CWops Test (CWT). Expect two rows: MY NAME, then **MY QTH OR MEMBER NO** beside the QTH/member prompt; no row reads MY STATE. Type a name and `1234`, OK. Expect the new log's MY STATE to be `1234`. Windows and Linux (gtk2): the 19-character label fits the 160-pixel label column (CATEGORY-TRANSMITTER, 20 characters, already does).
- [ ] **Locust QSO Party / NCCC Sprint unchanged.** Their rows still read MY NAME and MY STATE (they take a QTH, not a member number).
- [ ] **Submit ARRL Log greyed for the CWT.** Open a CWT log: Tools > Submit ARRL Log is greyed. Windows, Linux and macOS (one menu, built once).
- [ ] **Submit ARRL Log enabled for an ARRL contest.** Open an ARRL DX CW (or Sweepstakes, Field Day) log: the row is enabled and opens contest-log-submission.arrl.org.
- [ ] **NY4I's call: does Field Day belong on that portal?** The row is enabled for Field Day, but the agent that built it believes Field Day entries go through a separate Field Day web form, not contest-log-submission.arrl.org. Left unset (greyed) and unverified: IARU HF (probably the same ARRL portal) and ARRL Kids Day (probably an online form). Say which of the three should be on or off.

## Added 2026-11-11 -- A REFUSED CW OPEN EXCHANGE SAYS WHAT IS MISSING

Pressing Enter in CW Open with the serial or the name missing used to do nothing. `ProcessQSONumberAndNameExchange` now sets the message (CW Open, the four EU Sprints and MST share it): **No QSO number found!!**, **No name found!!** or **Not enough info in exchange!!**; an all-digit serial too large for the field gives the first. Unit-tested (`uTestQSONumberAndNameEntry`, including the engine path); the contest matrix moved only the `err=` field of 93 parse lines in each of those six contests (re-frozen with the reason recorded). 34 other parsers still refuse silently: not changed (issue to follow).

- [ ] **CW Open, serial missing.** Call W7SP, type only a name (`WOODY`), Enter: the red error line reads **No QSO number found!!** and the caret is left alone. Nothing is logged.
- [ ] **CW Open, name missing.** Type only `234`, Enter: **No name found!!**.
- [ ] **CW Open, a good exchange.** `234 WOODY`, Enter: logs as before, no error text left over from the earlier attempts.
- [ ] **Empty Enter still shows nothing in CW Open** (known gap: it exits before any parser runs; follow-up).

## Added 2026-11-11 -- "CONNECT RADIOS AT STARTUP" IS ON THE PROFILE, AND STARTUP OBEYS IT (issue 286)

The old station-wide box was read by nothing: every start connected the active profile's radios whatever it said. The setting is now the profile's (`connectAtStartup`, a missing key reads as on, so nothing changes on upgrade) and `LogCfg` skips the two radio connects when the active profile says off. The old `general.autoConnect` is not migrated (it never did anything) and is dropped on the next save. Note for the earlier report: deleting a RADIO does not change the box now; it follows the selected PROFILE.

- [ ] **Radios page layout.** The box sits inside the Station profile group beside "SO2R enabled", does not overlap it, follows the profile combo, and is greyed with no profiles. Tab order goes SO2R, Connect at startup, Activate. Windows and Linux (gtk2).
- [ ] **Off means no connect.** Untick it on the active profile, Save, restart: tr4w.log shows `[Startup] profile "..." does not connect its radios at startup` and `radios not connected`, and no `Created Radio ... thread` line. F1 (CW), clicking a band-map spot and typing a frequency must not crash with no radio.
- [ ] **Activate and Reset Radio Ports still connect** with the box off.
- [ ] **On connects as before** after ticking it again and restarting. An old `tr4w.json` with `general.autoConnect` loads with no ERROR line about an unknown key.
- [ ] **Caption question.** The box shows the profile selected in the combo, but startup uses the ACTIVE profile. Should the caption say "when this profile is active"? (New string if yes.)

## Added 2026-11-11 -- DX LAB PATHFINDER DDE TIMING LINES (issue 252, on hold)

`uDXLabPathfinder` now logs how long each DDE connect takes (debug level). One start with SpotCollector enabled showed 47 ms (Pathfinder probe) and 16 ms (SpotCollector). Issue 252 is on hold until a slow start recurs.

- [ ] **Collect the lines whenever a start feels slow** (DEBUG LOG LEVEL on, SpotCollector enabled): `rg -a --no-ignore -g "*.log*" "DdeConnect took"` from the repo root (cmd.exe: double quotes; `-a` because tr4w.log can hold a NUL byte). Seconds = the DDE call is the cause; near zero = machine load, close the issue.

## Added 2026-11-11 -- THE CW OPEN'S MULTIPLIER ROW SAYS CALLS (issue 277)

The totals grid's prefix-multiplier row is now the contest's label (`TTotalsDisplay.PrefixMultsCaption`, beside the domestic captions IARU and the Russian contests already state). The CW Open says **Calls**, because its multiplier is each different callsign worked (the sponsor: "each different call sign is a multiplier the first time it is worked in that session"). Every other contest still says **Prefixes**. A label only: no count or score changes. Unit-tested (`uTestContestDisplay.Test_TotalsDisplay`). The Zones row is NOT changed -- see the last item.

- [ ] **CW Open totals block.** Open (or create) a CWOps CW Open log. The left column reads QSOs, **Calls**, Zones; it no longer says Prefixes. Log one QSO (e.g. K6RB): the Calls row counts 1 on its band and in the All column. Windows and Linux (gtk2): "Calls" fits the left column.
- [ ] **Another contest unchanged.** Open a contest with a real prefix multiplier (CQ WPX CW): the row still reads **Prefixes**.
- [ ] **Wording.** Is "Calls" the word you want (the issue suggested "Callsign multipliers" or "Unique calls"; the grid's left column is narrow)? It is one resourcestring, `uAppStrings.STotalsCallsignMults`.
- [ ] **Live score check for the CW Open's Zones row (feeds a follow-up stage).** The class still counts CQ zones as a multiplier (carried from the D7 row); the sponsor's current rules name only callsigns, so removing it is a separate stage. The frozen contest matrix counts zones into the score -- 15 x (11 calls + 10 zones) = 315 -- and its QSO 16, which carries NO zone (0), still counted one zone on 80 m. Whether a live CW Open log does the same is unverified: log two QSOs and read the Zones row and the score (the issue saw 1 Pts after one QSO). Removing it is a rule change (zone pins, kind pin, matrix re-freeze), for NY4I to rule on (a follow-up issue), not done here.

## Added 2026-11-11 -- A NEW CONTEST NAMED LIKE THE OPEN LOG DOES NOT OFFER "OPEN EXISTING"

From File > Open Log, New Contest for the same contest, date and callsign as the log already running used to offer Open existing, and choosing it did nothing visible (only the quick line "That log is already open."). Now, when the taken name is the open log (`uNewContest.IsOneOfOpenContestFiles`, the same `IsSameLogFile` comparison `[OpenLog]` makes), the question says it is the log you have open and has two buttons: Create new log and Cancel (`SNewLogNameTakenOpenBody`, translations fuzzy-empty). The answer is read by modal result (`TakenLogOutcome`, unit tested). tr4w.log says `[NewContest] the log name is taken by the log already open, so Open existing is not offered: <file>`.

- [ ] **Same contest as the open log.** With a CWOps CW Open log for today open, File > Open Log > New Contest, choose CW Open with the same callsign, OK. The question names the open log, says it is the log you have open, and shows **Create new log** and **Cancel** only (no Open existing). Read the wording on Windows, and the button order on gtk2 if you can.
- [ ] **Create new log.** From that question: TR4W restarts on `... NY4I 2.db` (or the next free number), a new empty log; the old one is unchanged.
- [ ] **Cancel and Escape.** Each returns to the New Contest window as you left it; nothing is created and the running log is untouched.
- [ ] **A taken name that is NOT the open log still has three buttons.** At startup (nothing open), New Contest with a name that exists shows Create new log / Open existing log / Cancel, and Open existing opens it. Likewise from File > Open Log when the taken log is a different one from the running log.

## Added 2026-11-11 -- THE CW OPEN COUNTS NO ZONES (issue 277)

The CWOps CW Open no longer has a zone multiplier. Its sponsor's current rules (cwops.org/cwops-tests/cw-open) name one multiplier, "each different call sign ... the first time it is worked in that session", and never mention zones; DXLog's CWOpen.txt agrees. The class had carried the D7 row's 40 CQ zones. Its score is now QSO points x different callsigns. **This replaces two items in the "MULTIPLIER ROW SAYS CALLS" section above:** the left column is now QSOs and **Calls**, with no Zones row, and the live score check there is answered by this section. Unit-tested (`uTestZoneMultiplier`); the contest matrix moves for CWOPEN only (the zone flag, zones.max, the zone counts, the ADIF CQZ tag, the score 315 -> 165). Points (1 a QSO, a dupe per band) are unchanged.

- [ ] **No Zones row.** Open (or create) a CWOps CW Open log. The totals block's left column reads QSOs and **Calls** only; no Zones row. Windows and Linux (gtk2).
- [ ] **Two QSOs, the score.** Log two QSOs with different callsigns on one band (e.g. K6RB 1 ROB, W1AW 2 JOE on 20 m CW). Calls reads 2 and the score reads **2 x 2 = 4** (before this change it would have counted their zones too). Work K6RB again on 40 m: a new QSO (points 3), no new multiplier, score **3 x 2 = 6**.
- [ ] **The remaining-multipliers window** opens on callsigns/prefixes rather than zones (its default was zones, because LogCfg asks for zones before prefixes); it shows no zone list for this contest.
- [ ] **ADIF export.** File > export ADIF from that log: the records carry no `<CQZ:..>` tag. Cabrillo is unchanged (serial + name).
- [ ] **An existing CW Open log** opened after the update. Expected (by reading, not measured): on open the score STILL counts the zones, because loading trusts the zone flags stored in each QSO; after a Rescore (or `/RESCORE`) the flags are re-derived, the zones drop out, and the score is points x calls. Report whether opening alone already shows the lower score.

## Added 2026-11-12 -- EUROPEAN HF CHAMPIONSHIP AND KVP EXPORT THE STATED YEAR, NOT A CAPTURED ZONE

Unit-tested (`uTestLogMyFacts.TestALicenceYearIsNeverReplacedByACapturedZone`, through the same rule PostUnit asks); not yet seen in a real export. The fault was in NY4I's own log (`EUROPEAN HFC 2026-11-11 NY4I`): MY ZONE (the year) 80, captured ITU zone 8, Cabrillo sent `08`; editing the QSO's ITU zone to 42 sent `42`.

- [ ] **Cabrillo sends the year.** In that log (or a new EUHFC log with MY ZONE = your licence year), export Cabrillo: every QSO's sent column is `599 80` (your year), not your ITU zone.
- [ ] **ADIF sends the year.** Export ADIF: every `STX_STRING` is `599 80`; `MY_CQ_ZONE` and `MY_ITU_ZONE` still carry the captured zones, unchanged.
- [ ] **An edited ITU zone moves nothing.** Edit QSO, change "ITU zone" to 42, save, export both again: the sent year is still 80.
- [ ] **Changing MY ZONE changes the year.** Set MY ZONE to another year (e.g. 05), export: every sent column reads `05`, in both files. Same in a KVP log.
- [ ] **A real zone contest unchanged.** In a CQ WW or IARU log, edit a QSO's captured CQ (CQ WW) / ITU (IARU) zone and export: that QSO's sent zone follows the edit, as before.

## Added 2026-11-12 -- THE LINK THROUGH A TAILCAT TUNNEL (issue 293)

The forwarder is measured outside TR4W (`tools/netprobe` through it, same result as the plain port). The link INSIDE a running TR4W has not been seen. Needs the 64-bit build with `libtailcat.dll` beside the executable, and a TR4WServerPy on network protocol 3 started with `--tailcat`.

- [ ] **Connects.** Preferences > Network: paste the address, tick Use Tailcat, leave Server as it is, Save. Net > Connect. The status line reads connected to `Tailcat:1061`; `tr4w.log` has `the Tailcat tunnel is up: the server answered in N ms` and never the address.
- [ ] **Catch-up.** With QSOs in the server log that this log lacks, the catch-up runs through the tunnel (the server log shows a second connection, on the sync port).
- [ ] **QSOs pass both ways** with a second station on the LAN side.
- [ ] **Unticked** goes back to Server/Port with the address still stored.
- [ ] **Ticked with an empty address:** one warning saying so, no connection to Server.
- [ ] **Wrong address** (change a character): one warning after about 15 s that there was no answer through the tunnel; the retries stay silent.
- [ ] **Server stopped mid-session:** the link drops and retries; restart the server and it reconnects without touching Preferences.
- [ ] **Net > Disconnect, then exit:** no long wait at exit.
- [ ] **Two separate networks** (station on a phone hotspot, server at home).
- [ ] **The checkbox** sits right of the Tailcat address on the same row and does not overlap the reveal button; Tab goes address, Use Tailcat, This station.
