TR4W 5.0.0 TEST BUILD -- 2026-08-10
Branch tci-server, v5.0.0.  DEBUG build: larger and slower than a release EXE,
and NOT for a real contest.

Installer: tr4w_setup_5.0.0.exe

This is the first build whose version string is just "TR4W v.5.0.0" -- the
"Delphi12" suffix is gone, because the Delphi 12 line is now the release line.

Two things to test here, and they are different in kind.  The TCI server is NEW
and optional.  The transmit-control fixes are OLD BUGS, they affect everyone
using PTT via CAT, and they need testing even if you never touch TCI.


1. PTT VIA CAT WAS BROKEN ON ICOM AND ON THE BINARY YAESUS  (test this first)
-----------------------------------------------------------------------------
If you key your radio from TR4W over CAT, please try it and report.

  ICOM: PTT had NEVER keyed.  On any Icom.  TR4W was sending the $1C command
  with the subcommand where the DATA byte belongs, so "key" went out as
  1C 00 and "unkey" as 1C 01 -- which are "read TX status" and "read ATU
  status".  Two harmless READS.  The radio answered politely and did nothing,
  and TR4W reported success.

  BINARY YAESU (FT-1000MP, FT-990, FT-840, FT-817/818/857/897, FT-100, FT-747):
  there was no PTT command in the driver at all, so the request was accepted
  and silently dropped.

  EITHER RADIO, SO2R: keying was aimed at the ACTIVE radio regardless of which
  radio the caller named, so a request meant for radio 2 keyed radio 1.

  To test: key and unkey from TR4W, from WSJT-X, and (SO2R) on radio 2 while
  radio 1 is the active one.

Also new: TR4W now puts every radio into RECEIVE when you quit.  Quitting while
transmitting used to leave the rig keyed -- found the hard way, with an
FT-1000MP left on the air.


2. TCI SERVER -- WSJT-X CAN NOW REACH ANY RADIO TR4W CONTROLS
--------------------------------------------------------------
Only one program can hold a COM port, so WSJT-X has always had to get at the
radio THROUGH TR4W.  TR4W now speaks TCI (the ExpertSDR3 protocol) as a SERVER,
so any TCI client can drive whatever rig TR4W is controlling -- Icom, Yaesu,
Kenwood, Elecraft, anything in the radio list.  Your radio does not need TCI of
its own.

  Turn it on:  Preferences -> Hardware -> "Enable TCI radio server".
               No restart needed -- it starts and stops as you toggle it.
  Port:        50001, bound to THIS MACHINE ONLY (127.0.0.1) by default.
  In WSJT-X:   Settings -> Radio -> Rig = "TCI", Network Server = 127.0.0.1:50001

  Radio 1 is trx 0 and radio 2 is trx 1.  WSJT-X always talks to trx 0.

  What to try: frequency, mode, split, and PTT from WSJT-X; then change
  something in TR4W and confirm WSJT-X follows.  Two clients at once is
  supported and worth trying if you have a second one.

  This does NOT replace the existing WSJT-X support (the DXLab Commander
  emulation on port 52002).  That is untouched and still there.  TCI is an
  additional, better-specified option.  Audio and IQ are deliberately not
  offered -- TR4W bridges a rig and has no audio; keep using your soundcard.


3. ELECRAFT: AUTO-INFO IS NOW ON BY DEFAULT (AI2)
--------------------------------------------------
Elecraft radios on a serial port now get AI2 at connect, so the radio TELLS
TR4W when something changes instead of being asked ten times a second.

This came out of a real measurement.  Unkeying from WSJT-X took about 250 ms,
and it was NOT TR4W's command path -- from decision to wire is 0-2 ms.  The
delay was backlog in the RADIO's own input buffer: TR4W polled faster than the
radio could answer, and the unkey had to queue behind polls already sent.  The
cost turns out to be per COMMAND (100-170 ms each while transmitting), not per
byte, which is why sending fewer, better-timed commands is the fix and a faster
baud rate is not.

  Two changes came from it:
    - TR4W now waits for the radio to finish answering before polling again.
      This applies to ALL radios, not just Elecraft.
    - Auto-info on Elecraft, which removed the trade-off entirely: VFO B stays
      live while you transmit AND unkey came back at 221 ms.

  You can override auto-info per radio in the radio editor, but TR4W will warn
  you: it is a non-standard setting and it will slow transmit/receive turnaround.

  Verified on a K3S.  K2, KX2 and KX3 use the same command and are EXPECTED to
  work -- if yours misbehaves, this is the setting to turn off first, and please
  report it.


4. FT-1000MP NOW SHOWS TRANSMIT
--------------------------------
With PTT fixed the rig keys, but TR4W still showed RECEIVE the whole time.  It
now reads the radio's actual transmit state -- including when you key from the
FRONT PANEL or the foot switch, not only when TR4W caused it.


KNOWN NOT VERIFIED
------------------
  - Icom LAN, Yaesu ASCII, and HamLib radios: no bench proof on this branch.
    Serial Icom, serial/network Elecraft, serial Kenwood, Flex CAT and binary
    Yaesu have all been verified.
  - KX2/KX3/K2 auto-info (see 3).  The K4 keeps its existing behaviour for now.
  - Poll pacing has been measured on a K3S and exercised on an FT-1000MP and an
    IC-7100.  If any radio now updates more slowly than it used to, or a display
    field goes stale, that is this change and it is worth a log.
  - SO2R with a TCI client on radio 2 across a radio swap.


BUILD PROVENANCE
----------------
Built from commit 89fb0d3 on branch tci-server with a FULL rebuild
(FullBuild.ps1 -BuildInstallers), not an incremental one.  Verified before
packaging:

  unit tests     3609 passed, 0 failed
  golden corpus  22 passed, 0 failed, 4 known-divergence  (the standing baseline)
  lints          radio registry (100 registrations, no collisions), PollRadioState,
                 PChar/Ansi, line endings, form tags, form fields, config ownership

REPORTING
---------
Please include a log.  Set DEBUG LOG LEVEL = DEBUG under [COMMANDS] in
settings\tr4w.ini; output goes to tr4w.log.  For TCI specifically, also set
TCI DEBUG = TRUE, which traces every message in and out of the server.
