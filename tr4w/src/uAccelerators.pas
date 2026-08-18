unit uAccelerators;
{$I tr4w.inc}
{
  THE KEYBOARD BINDINGS, AS DATA, IN ONE PLACE.

  A command's keystroke used to be stated TWICE, with nothing keeping the two in
  step:

    * the 'T' ACCELERATORS resource inside tr4w_eng.RES, loaded with
      LoadAccelerators and applied by TranslateAccelerator -- what actually
      fires;
    * a caption constant in uMenu.pas (RC_EXIT_HK = #9'Alt+X') concatenated onto
      the menu text -- what the operator READS.

  Worse, there were ELEVEN accelerator tables, one per language .RES, and they
  had drifted from each other. Measured 2026-08-17 and written up in
  docs\ACCELERATOR_AUDIT.md:

    * Ctrl+T (POTA repeat) existed in English ONLY;
    * Alt+- (toggle autosend) was bound in ger and ukr and nowhere else, which
      is why the English menu advertised a keystroke that did nothing;
    * commit 344ddea9, "update Alt+O accelerator ID to 10603 in ALL language
      files", reached eight of the eleven.

  One Pascal table makes that class of drift impossible rather than merely
  unlikely, and it is a PREREQUISITE for the LCL migration: TranslateAccelerator
  is Win32 and dies with the message loop, so TMenuItem.ShortCut has to be
  carrying every binding before the loop goes.

  SEEDED FROM THE BINARY, NOT FROM THE CAPTIONS. The rows below were generated
  by test\ui\Dump-Accelerators.ps1 reading the live table out of tr4w.exe. That
  matters: 25 of the 97 bindings are displayed by NO menu row, so transcribing
  the _HK constants would have silently dropped a quarter of the keyboard --
  Ctrl+Alt+B Cabrillo, Ctrl+W WinKeyer, Alt+0..Alt+9 time increment, Ctrl+O
  missing-mults, Ctrl+T POTA, and Enter (id 10651, which has no menu_ constant
  at all). And the captions were the very thing under suspicion, so they could
  not also be the oracle.

  ONE DELIBERATE CHANGE from what the binary said (NY4I, 2026-08-17: "menu alt p
  should be alt-p"): Alt+P moves from 10101 menu_messages to 10317 menu_alt_p,
  whose caption had claimed it all along. 10101 gives it up -- two commands
  cannot answer one keystroke. 10317 keeps Ctrl+Alt+W as well; nobody asked for
  that to be removed and a second accelerator for one command is legal.

  NOT INCLUDED, and this is the trap to remember: PgUp and PgDn (CW speed
  up/down, ids 10503/10504) are bound by the MESSAGE LOOP at tr4w.dpr:1589-1590,
  not by any accelerator table. They are invisible to a tool that reads the
  .RES, and they DIE WITH THE LOOP unless they are carried across in Phase 3.
  The loop's WM_KEYDOWN arms are a third place a keystroke can be defined.
}

interface

uses
  Windows;

type
  { One binding. acDisplay is what the menu shows, so the keystroke and the text
    that advertises it can no longer disagree -- that is the whole point. }
  TAcceleratorRow = record
    acId:      Word;
    acCtrl:    boolean;
    acAlt:     boolean;
    acShift:   boolean;
    acKey:     Word;     // a virtual-key code; every row is FVIRTKEY
    acDisplay: string;
  end;

const
  ACCELERATORS: array[0..96] of TAcceleratorRow = (
    (acId: 10002; acCtrl: false; acAlt: true ; acShift: false; acKey: $58; acDisplay: 'Alt+X'),   // menu_exit
    (acId: 10003; acCtrl: true ; acAlt: true ; acShift: false; acKey: $42; acDisplay: 'Ctrl+Alt+B'),   // menu_cabrillo
    (acId: 10100; acCtrl: true ; acAlt: false; acShift: false; acKey: $4A; acDisplay: 'Ctrl+J'),   // menu_options
    (acId: 10103; acCtrl: true ; acAlt: true ; acShift: false; acKey: $31; acDisplay: 'Ctrl+Alt+1'),   // menu_cat_radio_one
    (acId: 10104; acCtrl: true ; acAlt: true ; acShift: false; acKey: $4C; acDisplay: 'Ctrl+Alt+L'),   // menu_lpt
    (acId: 10106; acCtrl: true ; acAlt: true ; acShift: false; acKey: $32; acDisplay: 'Ctrl+Alt+2'),   // menu_cat_radio_two
    (acId: 10107; acCtrl: true ; acAlt: false; acShift: false; acKey: $57; acDisplay: 'Ctrl+W'),   // menu_winkeyer2
    (acId: 10200; acCtrl: true ; acAlt: false; acShift: true ; acKey: $C0; acDisplay: 'Ctrl+Shift+`'),   // menu_windows_bandmap
    (acId: 10201; acCtrl: true ; acAlt: false; acShift: true ; acKey: $31; acDisplay: 'Ctrl+Shift+1'),   // menu_windows_dupesheet1
    (acId: 10202; acCtrl: true ; acAlt: false; acShift: true ; acKey: $32; acDisplay: 'Ctrl+Shift+2'),   // menu_windows_funckeys
    (acId: 10203; acCtrl: true ; acAlt: false; acShift: true ; acKey: $33; acDisplay: 'Ctrl+Shift+3'),   // menu_windows_trmasterdta
    (acId: 10204; acCtrl: true ; acAlt: false; acShift: true ; acKey: $34; acDisplay: 'Ctrl+Shift+4'),   // menu_windows_remmults
    (acId: 10205; acCtrl: true ; acAlt: false; acShift: true ; acKey: $35; acDisplay: 'Ctrl+Shift+5'),   // menu_windows_radiointerface1
    (acId: 10206; acCtrl: true ; acAlt: false; acShift: true ; acKey: $36; acDisplay: 'Ctrl+Shift+6'),   // menu_windows_radiointerface2
    (acId: 10210; acCtrl: true ; acAlt: false; acShift: true ; acKey: $37; acDisplay: 'Ctrl+Shift+7'),   // menu_windows_intercom
    (acId: 10211; acCtrl: true ; acAlt: false; acShift: true ; acKey: $38; acDisplay: 'Ctrl+Shift+8'),   // menu_windows_getscores
    (acId: 10212; acCtrl: true ; acAlt: false; acShift: true ; acKey: $39; acDisplay: 'Ctrl+Shift+9'),   // menu_windows_stations
    (acId: 10216; acCtrl: true ; acAlt: false; acShift: true ; acKey: $30; acDisplay: 'Ctrl+Shift+0'),   // menu_windows_mp3recorder
    (acId: 10300; acCtrl: false; acAlt: true ; acShift: false; acKey: $41; acDisplay: 'Alt+A'),   // menu_alt_wkmode
    (acId: 10301; acCtrl: false; acAlt: true ; acShift: false; acKey: $43; acDisplay: 'Alt+C'),   // menu_alt_autocqresume
    (acId: 10302; acCtrl: false; acAlt: true ; acShift: false; acKey: $44; acDisplay: 'Alt+D'),   // menu_alt_dupecheck
    (acId: 10303; acCtrl: false; acAlt: true ; acShift: false; acKey: $45; acDisplay: 'Alt+E'),   // menu_alt_SO2R_edit
    (acId: 10304; acCtrl: false; acAlt: true ; acShift: false; acKey: $46; acDisplay: 'Alt+F'),   // menu_alt_savetofloppy
    (acId: 10305; acCtrl: false; acAlt: true ; acShift: false; acKey: $47; acDisplay: 'Alt+G'),   // menu_alt_swapmults
    (acId: 10306; acCtrl: false; acAlt: true ; acShift: false; acKey: $49; acDisplay: 'Alt+I'),   // menu_alt_incnumber
    (acId: 10307; acCtrl: false; acAlt: true ; acShift: false; acKey: $4A; acDisplay: 'Alt+J'),   // menu_alt_multbell
    (acId: 10308; acCtrl: false; acAlt: true ; acShift: false; acKey: $4B; acDisplay: 'Alt+K'),   // menu_alt_killcw
    (acId: 10309; acCtrl: false; acAlt: true ; acShift: false; acKey: $4C; acDisplay: 'Alt+L'),   // menu_alt_searchlog
    (acId: 10310; acCtrl: false; acAlt: true ; acShift: false; acKey: $4E; acDisplay: 'Alt+N'),   // menu_alt_transfreq
    (acId: 10312; acCtrl: false; acAlt: true ; acShift: false; acKey: $51; acDisplay: 'Alt+Q'),   // menu_alt_autocq
    (acId: 10313; acCtrl: false; acAlt: true ; acShift: false; acKey: $52; acDisplay: 'Alt+R'),   // menu_alt_tooglerigs
    (acId: 10314; acCtrl: false; acAlt: true ; acShift: false; acKey: $53; acDisplay: 'Alt+S'),   // menu_alt_cwspeed
    (acId: 10315; acCtrl: false; acAlt: true ; acShift: false; acKey: $54; acDisplay: 'Alt+T'),   // menu_alt_settime
    (acId: 10317; acCtrl: false; acAlt: true ; acShift: false; acKey: $50; acDisplay: 'Alt+P'),   // menu_alt_p
    (acId: 10317; acCtrl: true ; acAlt: true ; acShift: false; acKey: $57; acDisplay: 'Ctrl+Alt+W'),   // menu_alt_p
    (acId: 10318; acCtrl: false; acAlt: true ; acShift: false; acKey: $5A; acDisplay: 'Alt+Z'),   // menu_alt_initialexhange
    (acId: 10319; acCtrl: false; acAlt: true ; acShift: false; acKey: $BB; acDisplay: 'Alt+='),   // menu_alt_tooglesidetone
    (acId: 10321; acCtrl: false; acAlt: true ; acShift: false; acKey: $42; acDisplay: 'Alt+B'),   // menu_alt_bandup
    (acId: 10322; acCtrl: false; acAlt: true ; acShift: false; acKey: $56; acDisplay: 'Alt+V'),   // menu_alt_banddown
    (acId: 10323; acCtrl: false; acAlt: true ; acShift: false; acKey: $4D; acDisplay: 'Alt+M'),   // menu_alt_ssbcwmode
    (acId: 10324; acCtrl: false; acAlt: true ; acShift: false; acKey: $59; acDisplay: 'Alt+Y'),   // menu_alt_deleteqso
    (acId: 10325; acCtrl: false; acAlt: true ; acShift: false; acKey: $57; acDisplay: 'Alt+W'),   // menu_alt_init_qso
    (acId: 10326; acCtrl: true ; acAlt: true ; acShift: false; acKey: $54; acDisplay: 'Ctrl+Alt+T'),   // menu_alt_setnettime
    (acId: 10327; acCtrl: false; acAlt: true ; acShift: false; acKey: $31; acDisplay: 'Alt+1'),   // menu_alt_increment_time_1
    (acId: 10328; acCtrl: false; acAlt: true ; acShift: false; acKey: $32; acDisplay: 'Alt+2'),   // menu_alt_increment_time_2
    (acId: 10329; acCtrl: false; acAlt: true ; acShift: false; acKey: $33; acDisplay: 'Alt+3'),   // menu_alt_increment_time_3
    (acId: 10330; acCtrl: false; acAlt: true ; acShift: false; acKey: $34; acDisplay: 'Alt+4'),   // menu_alt_increment_time_4
    (acId: 10331; acCtrl: false; acAlt: true ; acShift: false; acKey: $35; acDisplay: 'Alt+5'),   // menu_alt_increment_time_5
    (acId: 10332; acCtrl: false; acAlt: true ; acShift: false; acKey: $36; acDisplay: 'Alt+6'),   // menu_alt_increment_time_6
    (acId: 10333; acCtrl: false; acAlt: true ; acShift: false; acKey: $37; acDisplay: 'Alt+7'),   // menu_alt_increment_time_7
    (acId: 10334; acCtrl: false; acAlt: true ; acShift: false; acKey: $38; acDisplay: 'Alt+8'),   // menu_alt_increment_time_8
    (acId: 10335; acCtrl: false; acAlt: true ; acShift: false; acKey: $39; acDisplay: 'Alt+9'),   // menu_alt_increment_time_9
    (acId: 10336; acCtrl: false; acAlt: true ; acShift: false; acKey: $30; acDisplay: 'Alt+0'),   // menu_alt_increment_time_0
    (acId: 10400; acCtrl: true ; acAlt: false; acShift: false; acKey: $41; acDisplay: 'Ctrl+A'),   // menu_ctrl_sendkeyboardinput
    (acId: 10401; acCtrl: true ; acAlt: false; acShift: false; acKey: $42; acDisplay: 'Ctrl+B'),   // menu_ctrl_commtopacket
    (acId: 10402; acCtrl: true ; acAlt: false; acShift: false; acKey: $4B; acDisplay: 'Ctrl+K'),   // menu_ctrl_cleardupesheet
    (acId: 10403; acCtrl: true ; acAlt: false; acShift: false; acKey: $4C; acDisplay: 'Ctrl+L'),   // menu_ctrl_viewlogdat
    (acId: 10404; acCtrl: true ; acAlt: false; acShift: false; acKey: $4E; acDisplay: 'Ctrl+N'),   // menu_ctrl_note
    (acId: 10405; acCtrl: true ; acAlt: false; acShift: false; acKey: $4F; acDisplay: 'Ctrl+O'),   // menu_ctrl_missmultsreport
    (acId: 10406; acCtrl: true ; acAlt: false; acShift: false; acKey: $50; acDisplay: 'Ctrl+P'),   // menu_ctrl_redoposscalls
    (acId: 10407; acCtrl: true ; acAlt: false; acShift: false; acKey: $51; acDisplay: 'Ctrl+Q'),   // menu_ctrl_qtcfunctions
    (acId: 10408; acCtrl: true ; acAlt: false; acShift: false; acKey: $52; acDisplay: 'Ctrl+R'),   // menu_ctrl_recalllastentry
    (acId: 10409; acCtrl: true ; acAlt: false; acShift: false; acKey: $55; acDisplay: 'Ctrl+U'),   // menu_ctrl_viewpacketspots
    (acId: 10410; acCtrl: true ; acAlt: false; acShift: false; acKey: $59; acDisplay: 'Ctrl+Y'),   // menu_ctrl_refreshbandmap
    (acId: 10411; acCtrl: true ; acAlt: false; acShift: false; acKey: $BD; acDisplay: 'Ctrl+-'),   // menu_ctrl_SplitOff
    (acId: 10413; acCtrl: true ; acAlt: false; acShift: false; acKey: $23; acDisplay: 'Ctrl+End'),   // menu_ctrl_cursorinbandmap
    (acId: 10414; acCtrl: true ; acAlt: false; acShift: false; acKey: $0D; acDisplay: 'Ctrl+Enter'),   // menu_ctrl_logqsowithoutcw
    (acId: 10415; acCtrl: true ; acAlt: false; acShift: false; acKey: $2D; acDisplay: 'Ctrl+Ins'),   // menu_ctrl_PlaceHolder
    (acId: 10416; acCtrl: true ; acAlt: false; acShift: false; acKey: $DD; acDisplay: 'Ctrl+]'),   // menu_ctrl_ct1bohscreen
    (acId: 10417; acCtrl: true ; acAlt: false; acShift: false; acKey: $24; acDisplay: 'Ctrl+Home'),   // menu_ctrl_cursorintelnet
    (acId: 10418; acCtrl: true ; acAlt: false; acShift: false; acKey: $49; acDisplay: 'Ctrl+I'),   // menu_ctrl_incAQSLinterval
    (acId: 10419; acCtrl: true ; acAlt: false; acShift: false; acKey: $44; acDisplay: 'Ctrl+D'),   // menu_ctrl_decAQSLinterval
    (acId: 10420; acCtrl: true ; acAlt: false; acShift: false; acKey: $32; acDisplay: 'Ctrl+2'),   // menu_ctrl_showCallsign
    (acId: 10421; acCtrl: true ; acAlt: false; acShift: false; acKey: $33; acDisplay: 'Ctrl+3'),   // menu_ctrl_showSpeed
    (acId: 10422; acCtrl: true ; acAlt: false; acShift: false; acKey: $34; acDisplay: 'Ctrl+4'),   // menu_ctrl_showBand
    (acId: 10423; acCtrl: true ; acAlt: false; acShift: false; acKey: $31; acDisplay: 'Ctrl+1'),   // menu_ctrl_showQSONumber
    (acId: 10424; acCtrl: true ; acAlt: false; acShift: false; acKey: $43; acDisplay: 'Ctrl+C'),   // menu_ctrl_clearmultsheet
    (acId: 10425; acCtrl: true ; acAlt: false; acShift: false; acKey: $53; acDisplay: 'Ctrl+S'),   // menu_ctrl_shdxcallsign
    (acId: 10426; acCtrl: true ; acAlt: false; acShift: false; acKey: $56; acDisplay: 'Ctrl+V'),   // menu_ctrl_execute_config
    (acId: 10428; acCtrl: true ; acAlt: true ; acShift: false; acKey: $50; acDisplay: 'Ctrl+Alt+P'),   // menu_alt_ctrl_redoposscalls
    (acId: 10500; acCtrl: false; acAlt: false; acShift: false; acKey: $13; acDisplay: 'Pause'),   // menu_mainwindow_setfocus
    (acId: 10501; acCtrl: false; acAlt: false; acShift: false; acKey: $2D; acDisplay: 'Ins'),   // menu_insertmode
    (acId: 10502; acCtrl: false; acAlt: false; acShift: false; acKey: $1B; acDisplay: 'Esc'),   // menu_escape
    (acId: 10505; acCtrl: false; acAlt: false; acShift: true ; acKey: $09; acDisplay: 'Shift+Tab'),   // menu_cqmode
    (acId: 10506; acCtrl: false; acAlt: false; acShift: false; acKey: $09; acDisplay: 'Tab'),   // menu_spmode_ortab
    (acId: 10507; acCtrl: false; acAlt: false; acShift: false; acKey: $C0; acDisplay: '`'),   // menu_ctrl_sendspot
    (acId: 10509; acCtrl: false; acAlt: false; acShift: true ; acKey: $DE; acDisplay: 'Shift+'''),   // menu_send_message
    (acId: 10510; acCtrl: true ; acAlt: true ; acShift: false; acKey: $53; acDisplay: 'Ctrl+Alt+S'),   // menu_getserverlog
    (acId: 10513; acCtrl: true ; acAlt: false; acShift: false; acKey: $21; acDisplay: 'Ctrl+PgUp'),   // menu_inactiveradio_cwspeedup
    (acId: 10514; acCtrl: true ; acAlt: false; acShift: false; acKey: $22; acDisplay: 'Ctrl+PgDn'),   // menu_inactiveradio_cwspeeddown
    (acId: 10517; acCtrl: true ; acAlt: true ; acShift: false; acKey: $49; acDisplay: 'Ctrl+Alt+I'),   // menu_login
    (acId: 10550; acCtrl: true ; acAlt: true ; acShift: false; acKey: $4E; acDisplay: 'Ctrl+Alt+N'),   // menu_syncpctime
    (acId: 10557; acCtrl: true ; acAlt: true ; acShift: false; acKey: $4D; acDisplay: 'Ctrl+Alt+M'),   // menu_windowsmanager
    (acId: 10602; acCtrl: false; acAlt: true ; acShift: false; acKey: $48; acDisplay: 'Alt+H'),   // menu_contents
    (acId: 10603; acCtrl: false; acAlt: true ; acShift: false; acKey: $4F; acDisplay: 'Alt+O'),   // menu_download_latest_cty_dat
    (acId: 10608; acCtrl: true ; acAlt: false; acShift: false; acKey: $54; acDisplay: 'Ctrl+T'),   // menu_repeat_pota_parks
    (acId: 10651; acCtrl: false; acAlt: false; acShift: false; acKey: $0D; acDisplay: 'Enter')    // no menu_ constant
  );

{ The table Windows applies. Replaces LoadAccelerators(hInstance, 'T') -- so the
  binding no longer comes from a binary resource nobody can diff. The caller owns
  the handle and should DestroyAcceleratorTable it; TR4W builds one at startup
  and keeps it for the life of the program, exactly as it did with the resource. }
function BuildAcceleratorTable: HACCEL;

{ What the menu should show for a command, or '' when it has no binding.
  ONE source for both halves: the menu caption is now derived from the same row
  that produces the ACCEL entry. }
function AcceleratorDisplayFor(const aId: Word): string;

implementation

function BuildAcceleratorTable: HACCEL;
var
   tbl: array of TAccel;
   i:   integer;
begin
   SetLength(tbl, Length(ACCELERATORS));
   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      // FVIRTKEY on every row: acKey is a virtual-key code, not a character.
      // Without it Windows would compare against the ASCII value and Alt+1
      // would never match.
      tbl[i].fVirt := FVIRTKEY;
      if ACCELERATORS[i].acCtrl then
         begin
         tbl[i].fVirt := tbl[i].fVirt or FCONTROL;
         end;
      if ACCELERATORS[i].acAlt then
         begin
         tbl[i].fVirt := tbl[i].fVirt or FALT;
         end;
      if ACCELERATORS[i].acShift then
         begin
         tbl[i].fVirt := tbl[i].fVirt or FSHIFT;
         end;
      tbl[i].key := ACCELERATORS[i].acKey;
      tbl[i].cmd := ACCELERATORS[i].acId;
      end;
   Result := CreateAcceleratorTable(tbl[0], Length(tbl));
end;

function AcceleratorDisplayFor(const aId: Word): string;
var
   i: integer;
begin
   Result := '';
   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      if ACCELERATORS[i].acId = aId then
         begin
         Result := ACCELERATORS[i].acDisplay;
         Exit;
         end;
      end;
end;

end.
