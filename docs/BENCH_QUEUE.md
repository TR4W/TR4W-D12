# Bench queue — what is waiting for a real run

A **living list**, not a log. An item goes in when a change lands that no
automated gate can check, and comes **out** when NY4I confirms it. Items that
pass are deleted from here; if the result is interesting it goes into the
document that owns the area (`RADIO_BENCH_STATUS.md`, `D12_HARDWARE_TEST_PLAN.md`,
`CW_Keyer_Factory_Plan.md`) rather than accumulating here.

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

- **RDXC, as a DL station:** log IT9xxx (a new multiplier, 3 points),
  4U1VIC (multiplier, 3), RI1ANx (10 points, Antarctica multiplier, exchange
  AN accepted), RI1FJx (10, FJL multiplier, FJ), UA2Fxx (10) and DL1xxx/MM
  (5 points, no multiplier). The CTY country list is now CQ's -- check the
  country display for IT9/TA1/JW/4U1V calls and that MY COUNTRY is right.
- **RDXC, as a UA3 station:** UA2Fxx and RI1ANx score 2; a call-window
  pre-fill of RI1ANx is AN and of RI1FJx is FJ; DO/HE/LU/ZP are accepted as
  oblasts (also now in the five other contests that share russian.dom).
- **RADIO-YOC:** MY STATE = the age; the CQ/S&P exchange sends it with the
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

- **Last Contest button** shows the contest's display name and year on its
  second line and the call / file name on the third; hovering shows the full
  path. Check it at 100% and 150% scaling, with a long name (e.g. the
  IN7QPNE composite) -- the year must survive any shortening.
- **The existing-log list is a grid** (Contest, Year, Call, File), newest
  year first, undescribable files (old `.cfg`, damaged `.db`) last by file
  name. Check: layout at 100%/150%; header and row height and the sideways
  scroll bar on Windows, GTK and Cocoa; the full-path hint; a double-click on
  a HEADER opens nothing, on a row opens that log.
- **Enter on a log row opens it and does NOT also create a new contest**
  (the OK default button). With no logs listed, Enter still presses OK. Key
  routing differs by widget set -- check Windows, GTK and Cocoa.
- **Fill time on a real contest directory, cold disk** -- 100 warm logs take
  ~160 ms; antivirus scanning each `.db` may be slower.
- **The peek never touches a log:** opening the dialog while the same log is
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

## Added 2026-10-17 -- Q108 S4: A CONTEST WITH NO LEGACY NUMBER IS REFUSED ON MULTI-OP

Nothing automated drives a socket, so no gate has seen any of this end to end
(the unit tests reach the predicate, the message, `PeerContestRefusal`,
`TryConnectToNetwork`'s refusal and a source read of every door). **WHAT YOU
NEED:** a contest registered by id. The application links none until the first
real one (design 8.2u S5); until then use a LOCAL build with
`uContestTestFixture in '..\test\unit\uContestTestFixture.pas'` added to
`tr4w.lpr` (`TR4W-TEST-FIXTURE`; it appears in the New Contest list) -- do not
commit that, `Lint-ContestUnitsLinked` will fail it. **Two machines**, one
running `tr4wserver`.

- [ ] **Connect with such a contest selected is refused, once, and cleanly.**
      Select `TR4W-TEST-FIXTURE`, open the Network window (or restart with it
      active) with the server running. EXPECT: NO connection attempt (the
      status never says "Connecting"), ONE warning dialog reading "TR4W-TEST-FIXTURE
      cannot be used on the multi-op network yet -- the network protocol cannot
      carry it. Use it only while this station is not connected to a multi-op
      server.", and NOTHING more on the 5-second timer's retries (it is silent
      after the first). `tr4w.log` has one `[Net] TryConnectToNetwork refused
      contest "TR4W-TEST-FIXTURE" (handle 188)` line. Then switch to a legacy
      contest: the next retry connects normally; switch back and the message
      appears again once.
- [ ] **A legacy contest still works exactly as before** on the same two
      machines: connect, log QSOs at one station and see them arrive at the
      other, edit one, change a shared setting. (This is the regression check
      for the guards on the send and receive paths.)
- [ ] **Switching to such a contest while connected drops the link, with the
      message.** Connect on a legacy contest, then choose `TR4W-TEST-FIXTURE`
      (New Contest, or CONTEST in Preferences). EXPECT: the link closes (the
      Network window shows disconnected), one dialog with the same message, and
      no QSO of the new contest ever reaches the server (`tr4wserver.log`).
- [ ] **A peer's CONTEST change is not followed.** Station B, on a build that
      CAN select it, changes the contest to `TR4W-TEST-FIXTURE` while station A
      is connected on a legacy contest. EXPECT at A: the message, A keeps its
      contest, and `tr4w.log` has `[Net] a peer's CONTEST command refused ...`.
      (B itself is dropped from the network by the switch door above, so this
      needs B to switch before it notices -- or a hand-sent packet.)
- [ ] **`<contestnr>` on the wire.** With a UDP listener (N1MM-format) on the
      contact stream and the fixture selected, log a QSO: the datagram carries
      `<contestnr>1862707066</contestnr>`; a legacy contest still carries its
      legacy number (the `ContestType` ordinal -- compare with a capture from
      before this change). Wireshark on the contact stream's port will do.

---

## Added 2026-10-18 -- Q110: PEERS ON DIFFERENT CONTESTS

Two machines, one `tr4wserver`, two LEGACY contests (e.g. ARRL DX CW and CQ WW CW).
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

- **DX vs domestic in a domestic contest** (pointer audit P5): the domestic
  country list is a class now (`TDomesticCountryList`). Log a few in-country
  and DX contacts in a contest that uses it (e.g. a state QSO party from out
  of state, ARRL DX from W) and confirm each is DX or domestic as before.
- **County files** (`TDomQTHTable`, the logdom rewrite): a QSO party's county
  abbreviations still resolve, including an INCLUDE FILE (New York in-state:
  a Canadian province counts).
- **Nebraska QSO Party** (new): out of state, only NE counties score; in
  state, counties + states + provinces + countries, NE itself not a state;
  KA0BOJ bonus 100.
- **Out-of-area QSOs score 0** (Q107): as an out-of-state entrant, import an
  ADIF holding a contact with another out-of-state station; it should log
  but score 0 -- and Rescore from the menu keeps it 0.
- **Polish UI** shows "Polski", the About box credits SP2EWQ, M0GIM and
  G0DVJ; a machine-translated language credits LibreTranslate.
- **N1MM listener** receives `<mycall>` again (UDP contact broadcast).
- **The installer** (`dom\*.dom` wildcard): an installed copy has all 124
  files in `dom\`, including `prov12.dom`.
- **Every worker thread has a new signature** (pointer audit P1, defect D2).
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
- **The CW-memory command table** (pointer audit P1): its handler column is a
  typed procedure now and every row names its routine bare. No row changed
  its target, and the compiler checked all 81; still, run two or three
  memory commands (e.g. `SWAPRADIOS`, `BANDUP`, `CQMODE` in a function-key
  message) and confirm each does what it did.
- **MMTTY RTTY text** (pointer audit P2, defect D3): with MMTTY running,
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

- **Outside all four areas** (`MY STATE` e.g. KS): an Indiana county scores
  2 on any mode; a 7QP county 3 CW / 2 phone; a New England county 2 CW /
  1 phone; a Delaware county 20 CW / 10 phone, and **0 on 30, 17 or 12 m**.
  A station sending a state or DX is refused with "Out of state: work IN,
  7th area, NE or DE stations only" (only if the exchange lets you type one).
- **Inside one** (`MY STATE` a county, e.g. `INADA` or `KDE`): a station in
  another party scores by THAT party's rules (a DE entrant working an
  Arizona county: 7QP's 3 on CW); a state, province or DX station scores by
  your own party's (a DE entrant: 2 CW, 1 phone).
- **Multipliers**: a Delaware county worked on 30 m earns none; an Indiana
  entrant's DX contact -- see Q84.
- **The score shown** is points x multipliers over the whole log: no
  sponsor's score (Q77). Check it is not mistaken for one party's.
- **Cabrillo**: `CONTEST: IN7QPNE-QSO-PARTY`, one file for all four sponsors.
- **No score posting**: Post Scores is greyed; with `HAMSCORE ENABLE` on, the
  HamScore window's status reads "Score posting is not permitted for this
  contest" and nothing is sent. (WRTC now behaves the same -- Q83.)

---

## Added 2026-10-14 -- THE DELAWARE QSO PARTY IS A NEW CONTEST

`DELAWAREQSOPARTY` is a new contest type with its own class
(`uContestDelawareQP`, design 8.2q). Unit tests pin the class; **nothing
automated types a Delaware exchange or loads its `.dom` files**, and the
contest matrix shows it unfrozen. To exercise, create it from the New Contest
dialog (the template `.cfg` was deleted 2026-10-15):

- **In-state** (`MY STATE` a county: NDE, KDE or SDE): states, provinces and
  DX countries are multipliers **per band**; working another DE county counts
  the ONE multiplier "Delaware". Points CW 2, digital 2, phone 1.
- **Out-of-state** (`MY STATE` e.g. PA): NDE, KDE and SDE are the only
  multipliers, per band; a non-DE station is refused with "Out of state: work
  DE stations only". Points CW 20, digital 20, phone 10.
- **Bands**: a QSO on 30, 17 or 12 m is logged and scores 0; 6 m and 2 m score.
- **Score**: CATEGORY-POWER LOW doubles, QRP triples, and 50 is added.
- **Cabrillo**: `CONTEST: DE-QSO-PARTY`, an FT8 QSO's mode is `RY`, and the
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

- **The New Contest drop-down** (`uNewContestForm.FillContests`,
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
- **CATEGORY-POWER is one value** (`uCabrilloSummaryForm.CommitCategoryPower`,
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
- **Call entry, General QSO** (`ShowsContestStatus`): in a General QSO log,
  typing a call shows **no** multiplier/QSO status, station information or
  possible calls, as before; in any contest they show as before.
- **Band up/down, General QSO** (`BandStepIncludesWARC`): steps onto 30, 17 and
  12 m (with WARC enabled); a contest skips them, as before.
- **The summary sheet's ten-date warning** (`MaximumContestDates`): a contest
  log spanning more than ten dates warns; General QSO never does -- as before.
- **The FOC Marathon log** (`PowerFieldIsFOCNumber`): the member number shows
  under **FOC#**, and there is no PWR column; any contest with a power exchange
  shows PWR as before.
- **WAG** (`CallEntryFrequencyWarning`): with the radio at 3.675 MHz, typing a
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

- **The New Contest dialog** (`uNewContest` renders
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
- **The totals window** (`uTotal` reads `TotalsDisplay`): **IARU** labels the
  domestic row *HQ Mults* (by mode: *CW HQ* / *Ph HQ*); **Russian DX** and
  **RU3AX** *Oblasts*; **OZCHR teams** (QSO by mode, CW and phone both worked)
  shows *CW: nn%* / *PH: nn%* in place of the per-mode QSO rows. Every other
  contest *Dom Mults*, *CW Dom*, *Ph Dom* as before.
- **The summary sheet** (PostUnit reads `SummarySheet`): **Winter Field Day**'s
  multiplier columns show 1 per band/mode row and the row count on the total
  line; **ARRL Field Day**'s claimed score is the QSO point total, one column
  further in; every other contest states `Claimed Score = <score>`.
- **The hour-by-hour report** (`ReportsRunningScore`): no SCORE column for the
  Cup RF CW/SSB, Ural Cup, Ukraine Championship, RF Championship CW/SSB and
  RU3AX; every other contest keeps it.
- **The Cabrillo header**: ARRL 10 and Winter Field Day still refuse to start
  without a LOCATION (`TC_LOCATIONFIELDEMPTY`); Winter Field Day's
  `ARRL-SECTION:` and `X-EXCHANGE:` lines still precede `LOCATION:`; General
  QSO's `CONTEST:` is the title, else the contest name.
- **HamScore / the UDP contact broadcast / the log's `exchange_sent`**
  (`uExchangeBuilder` asks `CanonicalReceived/SentExchange`): with HamScore on,
  log one QSO each in **CQ WW** (`599 5`), **ARRL DX** from a W and from a DX
  station (`599 CT` / `599 100`), **NAQP** (`JOE CT`), **CW Open** (`123 JOE`),
  **RTC** (`123 EM17` received, `7 EM17` sent -- no RST either way) and **Field
  Day** (`2A CT`); every other contest sends the exchange as typed.
- **WRTC**: the master-file, Telnet and post-scores menu rows are greyed, the
  three windows do not open, and Super Check Partial shows nothing -- now from
  `PermittedOperatingAids`. The **WAE** runnings still offer the QTC menu; every
  other contest greys it.
- **Score posting XML** (UDP score broadcast, Q109, `a5afe844`): every
  contest posts `state`, `country`, `zone`, `prefix` `<mult>` rows per band
  and mode, **plus the ALL rows**, and the total row is per mode -- CW 5 on
  20 m and PH 3 on 15 m reads CW 5 / PH 3 / ALL 8. **WRTC now posts its HQ and
  country multipliers** (it posted none before -- Q55).
- **THE ONE DELIBERATE CHANGE -- design 7.11, MY STATE IS NEVER WRITTEN BY A
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

- **Dupes**: the 30 m QSO is **not** shown or logged as a dupe, and a second
  30 m QSO with it is not either. A 20 m repeat still is.
- **Displays that read the dupe sheet** -- a deliberate consequence, Q51:
  the 30 m dupe sheet does not list the station, and the Stations window
  shows no `+` for an off-band band it shows (6 m and up, in its VHF view).
  The possible-calls strip does not mark it a dupe on 30 m.
- **Need-multiplier hints** on 30 m: typing a DX call that is a needed
  country on 20 m shows **no** "new multiplier" indicator, the mult-needs
  strip shows no off-band band as needed, and the band map does not flag a
  30 m spot as a multiplier.
- **A defect that went with it**: in Idaho (multipliers not counted per
  band) typing a county the log does not have now shows it **needed** while
  on an Idaho band -- before M8 the county strip said "not needed" for every
  county, always.
- **Everything else is as before** -- the score, the multiplier counts and
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

- **North Carolina, the Rarest-of-NC sweep (NEW)**: log stations in four of
  CAB, GRM, VAN, MAC, DAV, CUR, PAM, ALL, PER, CAS -- no bonus; the fifth adds
  **500 once**, after the multiplication (the score is points x mults + 500).
  A sixth county adds nothing more.
- **Salmon Run, W7DX (NEW)**: CATEGORY-MODE MIXED -- a W7DX CW contact adds
  500, a W7DX phone contact another 500, a second CW band nothing. Set
  CATEGORY-MODE CW and the phone contact stops paying (the score drops 500).
  **An operator who never chose a CATEGORY-MODE is a CW entry** -- that is the
  setting's default and what the Cabrillo header says.
- **Idaho, the dormant county (NEW; one table per contest YEAR since Q35,
  `b6e7d19b`)**: the year comes from the LOG -- today its QSO dates -- and
  only 2026 has a table. In a log dated 2026, an in-state station with MY
  STATE `BUT` (Butte) -- nine valid QSOs, no bonus; the tenth adds **1000**.
  `ADM` pays 500; `ADA` and `WAS` are not in the 2026 table and pay nothing.
  A dupe or a 30 m QSO is not a valid QSO. A log dated another year pays no
  county bonus, and `tr4w.log` carries one error naming the year.
- **The moved formulas -- spot-check one each against a hand calculation**:
  WAE (weighted multipliers, QTCs as points), Winter Field Day (band-modes x
  points x 2 for LOW / 5 for QRP), RF Cup / ALRS / RF Championship / Ukraine
  Championship / OZHCR (points PLUS 100 / 300 / 50 / 10 / 1000 per
  multiplier), Ural Cup (prefixes are 10 points each, after the
  multiplication).
- **A score-posting client** (HamScore / getscores.org) posts the score the
  main window shows -- off the main thread it now reads the last score the
  window computed.

---

## Added 2026-10-02 -- EACH CONTEST PARSES ITS OWN EXCHANGE (M5b), AND TWO NEW REFUSALS

Exchange parsing moved onto the contest classes
(`TContestBase.ParseReceivedExchange`). The contest matrix types 66 exchanges
through `ParametersOkay` for every contest and proved nothing else moved; **no
gate types into the real window**, so nothing has seen a refusal's message on
screen or a valid exchange log from the entry fields. To exercise:

- **Sweepstakes, no precedence** (NY4I, design 7.10): type `123 99 CT` and
  Enter -- NOT logged, and the notice line says `Missing precedence (Q A B U M S)`.
  It used to refuse silently. `123 A 99 CT` logs as before.
- **A QSO party, out-of-state station** (NY4I, design 7.10) -- Florida, MY
  STATE `KS`: a DX station `DL1ABC` with `599 DL` is NOT logged and the notice
  says `Out of state: work FL stations only`; a Florida county logs. With MY
  STATE a Florida county (in state), the DX station logs.
- **NC QSO Party**: out of state, `599 GA` from `K4ABC` is now refused (an
  improper domestic QTH -- `nc_cty.dom` is the hundred counties); a county logs.
  A VE station with MY STATE `ON` is now OUT of state for NC. In state, states,
  provinces, DC and DX are still accepted.
- **Field Day DX**: log `DL1ABC` with `1D` (or `1D DX`), export ADIF -- the
  record carries `CLASS 1D`, `SRX_STRING 1D DX`, and no `ARRL_SECT`. Import that
  file back: the QSO's QTH is DX and it is NOT a section.
- **Unchanged, but moved -- spot-check one each**: RAC Canada Day `VE0ABC 599 123`
  logs a serial; PCC `599 GR` a QTH and `599 123` a serial; IARU `ARRL` alone
  logs with the station's zone filled; UK/EI `G3ABC` with only `123` is refused
  `Invalid Entry`; SAC with `UA3ABC` in the call window clears the entry; LABRE
  `PY2ABC 599 SP` logs SP as the state.
- **CQ WW RTTY `599 14` from a DX station** now answers the same every time --
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

- Log a Croatian QSO by day and one at night (or with the clock set): day
  points by day, doubled at night.
- Rescore the log at the other time of day: points do NOT change.
- Same for UK/EI from a G station.

---

## Added 2026-10-01 -- THE IDAHO QSO PARTY HAS ITS OWN CONTEST

`IDAHOQSOPARTY` is a new contest type with its own class (`uContestIdahoQP`); the
template `Idaho QSO Party.cfg` no longer borrowed `CONTEST = NEQP` (and was deleted
2026-10-15; create the contest from the New Contest dialog). Unit tests pin
the class; **nothing automated types an Idaho exchange**, and the multiplier
lists come from `.dom` files no gate loads. To exercise:

- **In-state** (`MY STATE` an Idaho county, e.g. ADA): states, Canadian
  provinces and DX countries are multipliers, and every Idaho county counts as
  the ONE multiplier "Idaho". Before this change in-state got the 44 counties
  and no states or provinces at all -- `IDAHO.DOM` wrote `INCLUDE S50.DOM`
  without the word `FILE`, which `logdom` silently skips.
- **Out-of-state**: each of the 44 counties is its own multiplier; nothing else.
- **Points**: CW 2, phone 1, digital 2, FM 1 -- the old `.cfg` scored CW 4 and
  phone 2 through the rotated spelling table.
- **County line**: a third county in one exchange is refused; two are accepted.
- **Export**: Cabrillo `CONTEST: ID-QSO-PARTY`, ADIF `CONTEST_ID` `ID-QSO-PARTY`.

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

- **`PADDLE MONITOR TONE` -- RULED 2026-10-18 (NY4I): *"Keep it."*** The
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

- Create a contest on the Debian box. Its `.db` should be in `~/tr4w`, not
  under `/tmp/.mount_...` (a new contest writes no `.cfg`).
- Log a QSO, restart, and confirm it is still there.
- "Download latest cty.dat" should succeed rather than failing with
  *"Read-only file system"*.

**Existing contests are unaffected** -- they keep pointing wherever their `.cfg`
already lives. This changes where NEW ones are created.

### 4. WINDOWS: A SERIAL RADIO STILL OPENS

Nothing above is a Windows feature, and that is exactly why this is here. The
port work moved what the store holds from `SERIAL n` to the device name
(`269b99ea`), and a careless step there leaves a Windows station whose radio
silently stops opening.

- One serial rig, from an EXISTING configuration, so the `SERIAL n` a saved
  station already holds is exercised on the upgrade path.
- Then change the port in Preferences, restart, and confirm it sticks.

---

## 2026-09-05 overnight -- the main window has no Win32 children left

**Two commits plus follow-on work.** `839aeb1f` replaced the last sixty-seven raw
Win32 STATICs on the main form with designed LCL panels; `d568e5e3` made the
window resizeable. Everything below is a LOOK-AT-IT item -- lints 31/31, unit
tests 22513/0 and the corpus 24/0/2 were all green while the four regressions in
the second group were on screen.

### Already confirmed by NY4I, not waiting

- The form is correct again after the border-style fix (title bar, menu,
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

- Logging works again after the CONTEST fix. The title bar shows the contest.
- The main editable log renders again after the column-width unit bug.
- Log Edit columns are measured and distributed, and the grid no longer
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

* the per-line resend buttons (Alt+1..Alt+0) **now work**; in the Win32 version
  they never did, because they were created with the wrong control id. Wiring
  them was a judgement call and is one line to undo;
* the receive window's **OK button is gone** -- it did nothing, and its handler
  still carries an N4AF 04.32.3 note beside the commented-out save;
* the Cabrillo **transmitter id** diverges from the specification in two ways
  and has NOT been touched. See Part 4 of the handoff.

Nothing here blocks anything else. It is on this list so it does not quietly
become "converted, therefore done".

## Added 2026-08-28 (night) -- FOUR KENWOODS CHANGE DRIVER ON UPGRADE

### [ ] This one needs a release note, not just a bench run

`InterfacedRadioTypeSA` -- the table `RADIO ONE MODEL = ...` was matched against
-- had drifted one row from the enum in `VC.pas`. It was missing `TS140` and
carried a `TS530` the enum never had, so from that point on it was off by one:

| the config said | the operator actually got | after the fix |
|---|---|---|
| `TS440` | TS-140 driver | TS-440 driver |
| `TS450` | TS-440 driver | TS-450 driver |
| `TS480` | TS-450 driver | TS-480 driver |
| `TS530` | TS-480 driver | **no match** -- TR4W has no TS-530 driver |
| `TS140` | no match at all | TS-140 driver |

**Existing configs will behave differently after upgrading**, and for these four
that means correctly rather than as before. Two things follow:

* somebody with a TS-440/450/480 should confirm on hardware that the *correct*
  driver actually works -- they have been running the neighbouring one, possibly
  for years, and nobody has exercised the right one;
* `TS530` was never a real TR4W model. Anyone whose config says that was getting
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
|---|---:|---:|
| 1 | 21 | 9 |
| 2 | 8 | 2 |
| 3 | 2 | 1 |
| 4 | 1 | 0 |

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

| Question | Tool | Verified tonight |
|---|---|---|
| Does a dialog open at all? | `Invoke-MenuSmoke.ps1` | 8 commands, 7 windows |
| Do Edit QSO's fields round-trip? | `Invoke-FieldCheck.ps1` | 69/69 |
| Is a menu caption, id or shortcut right? | `Dump-Menu.ps1` | caught About reading "Check for Updates" |
| Do accelerators collide? | `uTestAccelerators.Test_NoDuplicateKeystroke` (unit tests) | -- |
| Did a window lose a control, or its size? | `Dump-WindowTree.ps1` + `Compare-WindowTree.ps1` | -- |
| Does a translated caption still fit? | `Test-TextFit.ps1` | -- |
| Does typing reach the right field? | `Test-Typing.ps1` | -- |
| Does Preferences show every section? | `Test-PreferencesSections.ps1` | -- |
| Did the program write what it claims? | read `target/tr4w.log` | proved the Spanish menu is not ours |

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

- [ ] **15 unreferenced routines in `TF.pas` and `uDialogs.pas`** --
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

Converted from 33 generated edit boxes to a single `TStringGrid`.

**Confirmed 2026-08-21 (NY4I):** it opens from Preferences, it is resizable, the
headings are readable, the grid fills the window, and the position is remembered
across openings. **What is still unrun is everything that WRITES:**

- [x] It **opens** and shows one row per band with the three current values.
- [ ] ~~Editing a cell and pressing **OK** writes `[BAND PLAN]` in `tr4w.ini` and
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
- [ ] **ACCENTED TEXT, IN A NON-ENGLISH CATALOGUE, AFTER TF.Format BECAME
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

- [ ] Settings > WinKeyer must land on **CW Settings**, with the keying devices
  list at the top. Pick the keyer, **Edit...**, and all seventeen options are
  there.
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

- [ ] **MULTI-OP SYNCHRONISATION DOES NOT WORK, ON PURPOSE.** Log comparison
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

  | what you see | what it means |
  |---|---|
  | an `ENTER` with no matching `EXIT`, and the log stops | the deadlock. The line names the thread, whether it is the main one, and how many sends were already inside Indy |
  | `SEND OVERLAP` | two or more threads inside the send at once -- the shape the original comment blamed |
  | `mainthread=True` on the stuck one | exactly the case that comment named |
  | `SLOW SEND: N ms` | Indy blocked but survived. The same contention, and far likelier to be caught than a full hang -- threshold is 20 ms, deliberately low |

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

- **Eleven flagged parties have no established county limit** and are left
  unlimited (today's behaviour). 7QP is known to be 4 on NY4I's geometric
  argument -- four counties is the most that can meet at a point with
  right-angle borders. 7QP has a class now (`uContestSevenQP`), and it states
  no county-line limit of its own.

---

## Known and accepted — no action, listed so they are not re-reported

- **CW-by-CAT keys one character per `KY` command** when typing into the
  send-from-keyboard box (Ctrl+A) or during autosend. Staccato, inherent, and
  better than D7 (which sent nothing until Enter). Full explanation and three
  untried directions in `CW_Keyer_Factory_Plan.md`.
- **Preferences collapses the Hardware branch** after visiting another section.
  That is the one-branch-at-a-time rule working. The pane arithmetic behind it
  was recounted 2026-08-18 and two branches now overflow; NY4I is rearranging the
  sections first, then it gets revisited.
