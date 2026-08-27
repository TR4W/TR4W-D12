{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT. 
If not, ref: 
http://www.gnu.org/licenses/gpl-3.0.txt
 }
unit uMenu;
{$I tr4w.inc}

interface

uses
  VC,
  uAccelerators,   // AcceleratorDisplayFor -- the shortcut text a menu item shows
  Windows,
  uTR4WStrings;

type

  MenuRecord = record
    { A STRING, not a PAnsiChar, and that is load-bearing rather than tidying.

      77 of the rows below build their caption by concatenating a caption
      constant with its accelerator -- RC_EXIT + RC_EXIT_HK. Folded into a
      PAnsiChar typed constant, FPC pointed the field at the string's
      DESCRIPTOR instead of its characters: every accelerator menu item came
      out as four bytes of length and refcount, and the window captions taken
      from those items (CreateWindowByID in MainUnit) came out as garbage. No
      warning, from either compiler. Delphi folded the same expression into a
      literal and hid it.

      Carrying the real string type removes the class of bug rather than the
      instance, and matches the house rule that the program passes strings and
      lets the boundary deal in pointers -- which the AppendMenuW calls below
      now do explicitly. }
    mrText: string;
    mrId: Word;
  end;

  PMenuRecord = ^MenuRecord;

{ Fill the menu captions from the resourcestrings. See the implementation. }
procedure InitializeMenuText;
function CreateTR4WMenu(m: PMenuRecord; s: integer; popup: boolean): HMENU;
const
  // GONE 2026-08-17: menu_messages no longer owns Alt+P.  NY4I -- "menu alt p
  // should be alt-p" -- moved that keystroke to 10317 menu_alt_p, whose caption
  // had claimed it all along while the accelerator table bound it here.  Two
  // commands cannot answer one keystroke, so this one gives it up and its menu
  // item now advertises nothing rather than advertising a key it does not have.
  // See docs\ACCELERATOR_AUDIT.md and src\uAccelerators.pas.
  //RC_TRANSFREQ_HK                       = #9'Alt+O';
//  RC_PTT_HK                             = #9'Ctrl+P';      // remove 4.125.4
//  RC_TRANSFREQ_HK                       = #9'Ctrl+T';
  // Ctrl+- , not '-'. The caption had dropped its modifier while the
  // accelerator table bound Ctrl+- all along, so the menu advertised a
  // bare '-' that does nothing on its own (audited 2026-08-17, see
  // docs\ACCELERATOR_AUDIT.md; NY4I: add the Ctrl modifier).


    // 179 -> 176: Settings -> 'CAT and CW Keying' went from a submenu of two
    // per-slot entries to ONE item opening the Preferences window, removing
    // the MAXWORD-1 submenu marker, the two Radio entries and the MAXWORD-2
    // terminator, and adding one item (net -3).
    T_MENU_ARRAY_SIZE                     = 176 + 1 + 1 {Check for Updates, 2026-08-22} {MMTTY window}{$IFDEF LANG_RUS} + 3{$ENDIF} + 2 {RC_RESET_RADIO_PORTS, separator, Repeat POTA Parks} + 2 {HamScore Resync (Tools) + HamScore Status (Windows menu), Issue #783} + 1 {3830 Score under File-Reports} + 1 {Edit Cabrillo Summary under Tools, Issue #914} + 1 {Download TRMASTER.DTA, 2026-08-16} - 1 {Appearance removed, 2026-08-16} - 1 {Synchronize PC time removed, 2026-08-25 -- setting the clock needs UAC};

var
  { A var, and every mrText is BLANK here -- InitializeMenuText fills them.

    The captions were TC_/RC_ constants written straight into this typed
    constant, which folds them at COMPILE time. That is exactly what a
    resourcestring cannot do, and FPC says so rather than folding English in
    silently:

      Unicodechar/string constants cannot be converted to ansi/shortstring
      at compile-time

    The fill walks the rows with a running index rather than naming numbers,
    and carries the LANG_RUS conditionals with it, so the two stay aligned in
    every configuration by construction. Insert a row in one and the other
    follows only if you insert it there too -- which is the point: numbered
    assignments would drift silently. }
  T_MENU_ARRAY                          : array[0..T_MENU_ARRAY_SIZE] of MenuRecord = (
    (mrText: ''; mrId: MAXWORD),
 //{
    (mrText: ''; mrId: menu_clear_log),
    (mrText: ''; mrId: menu_log_file_properties),
    (mrText: ''; mrId: MAXWORD - 1),
  //{
    (mrText: ''; mrId: menu_import_adif),
  //}

    (mrText: ''; mrId: MAXWORD - 1),
  //{
    (mrText: ''; mrId: menu_adif),
    (mrText: ''; mrId: menu_csv),
    (mrText: ''; mrId: menu_cabrillo),
    (mrText: ''; mrId: menu_export_edi),
    (mrText: ''; mrId: menu_initial_ex_list),
//    (mrText: RC_TRLOGFORM; mrId: menu_trlog),
    (mrText: ''; mrId: menu_export_notes),
  //}

    (mrText: ''; mrId: MAXWORD - 1),
  //{
    (mrText: ''; mrId: menu_allcallsigns_list),
    (mrText: ''; mrId: menu_band_changes),
    (mrText: ''; mrId: menu_continentlist),
    (mrText: ''; mrId: menu_first_call_work_ineachcountry),
    (mrText: ''; mrId: menu_first_call_work_InEachZone),
    (mrText: ''; mrId: menu_qsobycountry),
    (mrText: ''; mrId: menu_scorebyhour),
    (mrText: ''; mrId: menu_summary),
    (mrText: ''; mrId: menu_3830scores),
  //}
    (mrText: ''; mrId: MAXWORD - 2),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_exit),
 //}

    (mrText: ''; mrId: MAXWORD),
 //{

    (mrText: ''; mrId: 0),

    (mrText: ''; mrId: menu_colors),
    // APPEARANCE REMOVED 2026-08-16 (NY4I). It opened RunOptionsDialog with the
    // cfAppearance filter, and every row that filter selected is now csOwned --
    // so it opened an empty list. Its settings live on the Preferences
    // Appearance page, which the Ctrl-J entry above reaches. menu_appearance
    // itself is kept in VC.pas and still handled in ProcessMenu, because the
    // id may arrive from an accelerator or a saved menu state.
    (mrText: ''; mrId: menu_winkeyer2),

    // One item, not a submenu: the Preferences window owns BOTH radio slots
    // plus the radio library and the profiles, so a per-slot entry would open
    // the same window twice.  The legacy per-slot dialog (uCAT.CATDlgProc) is
    // still reachable with the CATLEGACY call-window command while the new
    // path is being proven on the bench.
    (mrText: ''; mrId: menu_radio_preferences),

    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_messages),

    (mrText: ''; mrId: menu_lpt),

 //}

    (mrText: ''; mrId: MAXWORD),
 //{
    (mrText: ''; mrId: menu_windows_bandmap),

    (mrText: ''; mrId: MAXWORD - 1),
  //{
    (mrText: ''; mrId: menu_windows_dupesheet1),
    (mrText: ''; mrId: menu_windows_dupesheet2),
  //}
    (mrText: ''; mrId: MAXWORD - 2),
    (mrText: ''; mrId: menu_windows_funckeys),
    (mrText: ''; mrId: menu_windows_trmasterdta),
    (mrText: ''; mrId: MAXWORD - 1),
    (mrText: ''; mrId: menu_windows_remmults),

    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_rm_dx),
    (mrText: ''; mrId: menu_rm_domestic),
    (mrText: ''; mrId: menu_rm_zone),
    (mrText: ''; mrId: menu_rm_prefix),
    (mrText: ''; mrId: MAXWORD - 2),
  //}

    (mrText: ''; mrId: menu_windows_radiointerface1),
    (mrText: ''; mrId: menu_windows_radiointerface2),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_windows_telnet),
    (mrText: ''; mrId: menu_windows_network),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_windows_intercom),
    (mrText: ''; mrId: menu_windows_getscores),
    (mrText: ''; mrId: menu_windows_hamscore),  // Issue #783 Phase 4
    (mrText: ''; mrId: menu_windows_stations),
    (mrText: ''; mrId: menu_windows_mp3recorder),
    (mrText: ''; mrId: menu_windows_mmtty),
 //}

    (mrText: ''; mrId: MAXWORD),
 //{
    (mrText: ''; mrId: MAXWORD - 1),
  //{
    (mrText: ''; mrId: menu_alt_increment_time_1),
    (mrText: ''; mrId: menu_alt_increment_time_2),
    (mrText: ''; mrId: menu_alt_increment_time_3),
    (mrText: ''; mrId: menu_alt_increment_time_4),
    (mrText: ''; mrId: menu_alt_increment_time_5),
    (mrText: ''; mrId: menu_alt_increment_time_6),
    (mrText: ''; mrId: menu_alt_increment_time_7),
    (mrText: ''; mrId: menu_alt_increment_time_8),
    (mrText: ''; mrId: menu_alt_increment_time_9),
    (mrText: ''; mrId: menu_alt_increment_time_0),
  //}

    (mrText: ''; mrId: MAXWORD - 2),
    (mrText: ''; mrId: menu_alt_wkmode),    // 4.60.1
    (mrText: ''; mrId: menu_alt_bandup),
    (mrText: ''; mrId: menu_alt_autocqresume),
    (mrText: ''; mrId: menu_alt_dupecheck),
    (mrText: ''; mrId: menu_alt_SO2R_edit),
    (mrText:  '';mrId: menu_alt_savetofloppy),
    (mrText: ''; mrId: menu_alt_swapmults),
    (mrText: ''; mrId: menu_alt_incnumber),
    (mrText: ''; mrId: menu_alt_multbell),
    (mrText: ''; mrID: menu_alt_killcw),
    (mrText: ''; mrId: menu_alt_searchlog),
    (mrText: ''; mrId: menu_alt_ssbcwmode),

    (mrText: ''; mrId: menu_download_latest_cty_dat), // 4.75.3
//    (mrText: RC_TRANSFREQ; mrId: menu_alt_transfreq),     // 4.68.11
    (mrText: ''; mrId: menu_alt_p),
    (mrText: ''; mrId: menu_alt_autocq),
    (mrText: ''; mrId: menu_alt_tooglerigs),
    (mrText: ''; mrId: menu_alt_cwspeed),
    (mrText: ''; mrId: menu_alt_settime),
    (mrText: ''; mrId: menu_alt_banddown),
    (mrText: ''; mrId: menu_alt_init_qso),
    (mrText: '';         mrId: menu_alt_x),
    (mrText: ''; mrId: menu_alt_deleteqso),
    (mrText: ''; mrId: menu_alt_initialexhange),
    (mrText: ''; mrId: menu_alt_tooglesidetone),
    (mrText: ''; mrId: menu_alt_toogleautosend),
    (mrText: ''; mrId: 0),



 //

    (mrText: ''; mrId: MAXWORD),
 //{
    (mrText: ''; mrId: menu_ctrl_sendkeyboardinput),
    (mrText: ''; mrId: menu_ctrl_clearmultsheet),
//    (mrText: RC_DAQSLINT; mrId: menu_ctrl_decAQSLinterval),  //n4af 04.37.10
 //   (mrText: RC_IAQSLINT; mrId: menu_ctrl_incAQSLinterval),   //n4af 04.37.10
    (mrText: ''; mrId: menu_options),
    (mrText: ''; mrId: menu_ctrl_cleardupesheet),
    (mrText: ''; mrId: menu_ctrl_viewlogdat),
    (mrText: ''; mrId: menu_ctrl_note),
//    (mrText: RC_MISSMULTSREP; mrId: menu_ctrl_missmultsreport),  //n4af 04/37.10
//    (mrText:  'PTT'; mrId: menu_ctrl_ptt),
    (mrText:  ''; mrId: menu_ctrl_redoposscalls),  // 4.54.5
    (mrText: ''; mrId: menu_ctrl_qtcfunctions),
    (mrText: ''; mrId: menu_ctrl_recalllastentry),
    (mrText: ''; mrId: menu_ctrl_shdxcallsign),
//    (mrText: RC_VIEWPAKSPOTS; mrId: menu_ctrl_viewpacketspots),
    (mrText: ''; mrId: menu_ctrl_execute_config),
    (mrText: ''; mrId: menu_ctrl_refreshbandmap),
    (mrText: ''; mrId: menu_ctrl_cursorinbandmap),
    (mrText: ''; mrId: menu_ctrl_logqsowithoutcw),
    (mrText: ''; mrId: menu_ctrl_cursorintelnet),
    (mrText: ''; mrId: menu_ctrl_PlaceHolder),

    (mrText: ''; mrId: menu_ctrl_ct1bohscreen),
    (mrText: ''; mrId: MAXWORD - 1),
  //{
    (mrText: ''; mrId: menu_ctrl_showQSONumber),
    (mrText: ''; mrId: menu_ctrl_showCallsign),
    (mrText: ''; mrId: menu_ctrl_showSpeed),
    (mrText: ''; mrId: menu_ctrl_showBand),
  //}

 //}

    (mrText: ''; mrId: MAXWORD),
 //{

    (mrText: ''; mrId: menu_ctrl_SplitOff),      // n4af 4.47.3

    (mrText: ''; mrId: menu_mainwindow_setfocus),
    (mrText: ''; mrId: menu_insertmode),
    (mrText: ''; mrId: menu_escape),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_cwspeedup),
    (mrText: ''; mrId: menu_cwspeeddown),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_inactiveradio_cwspeedup),
    (mrText: ''; mrId: menu_inactiveradio_cwspeeddown),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_cqmode),
    (mrText: ''; mrId: menu_spmode_ortab),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_login),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_ctrl_sendspot),
    (mrText: ''; mrId: menu_rescore),
 //}

    (mrText: ''; mrId: MAXWORD),
 //{
    (mrText: ''; mrId: menu_beaconsmonitor),
    (mrText: ''; mrId: menu_windowsmanager),
    (mrText: ''; mrId: menu_settimezone),
    (mrText: ''; mrId: menu_run_devicemanager),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_pingserver),
    (mrText: ''; mrId: menu_runserver),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_volume_control),
    (mrText: ''; mrId: menu_recording_control),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_WA7BNM_calendar),
    (mrText: ''; mrId: menu_qrzru_calendar),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: item_calculator),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_reset_radio_ports),
    (mrText: ''; mrId: menu_download_pota_parks),  // issue #864
    (mrText: ''; mrId: menu_repeat_pota_parks),
    (mrText: ''; mrId: menu_hamscore_resync),  // Issue #783
    (mrText: ''; mrId: menu_edit_cabrillo_summary),     // Issue #914
 //}
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_3830_scores_posting),
    (mrText: ''; mrId: menu_arrl_submit),    // 4.53.3
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: MAXWORD),
 //{
    (mrText: ''; mrId: menu_alt_setnettime),
    (mrText: ''; mrId: menu_send_message),
    (mrText: ''; mrId: menu_getserverlog),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_clearserverlog),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: menu_clear_dupesheet_in_network),
    (mrText: ''; mrId: menu_clear_multsheet_in_network),
 //}

    (mrText: ''; mrId: MAXWORD),        // n4af 4.42.5
 //{
{$IFDEF LANG_RUS}
    (mrText: ''; mrId: menu_contents),
    (mrText: ''; mrId: 0),
{$ENDIF}
//    (mrText: RC_SEND_BUG; mrId: menu_send_bug),
//    (mrText: '-'; mrId: 0),
    (mrText: ''; mrId: menu_home_page),
    (mrText: ''; mrID: menu_download_latest_cty_dat), // 4.75.3
    (mrText: ''; mrId: menu_download_trmaster),  // 2026-08-16
    (mrText: ''; mrId: menu_download_pota_parks),  // issue #864
    // A LITERAL caption, like the two above it.  A new RC_ would mean editing
    // eleven per-language ANSI files -- NY4I's by hand, and the thing
    // resourcestring is replacing anyway; a resourcestring also cannot appear
    // in this typed-constant array.  These belong together in the i18n sweep.
    (mrText: ''; mrId: menu_check_latest_version),  // 2026-08-22
    {$IFDEF LANG_RUS}
    (mrText: ''; mrId: menu_wiki_rus),
{$ENDIF}
//    (mrText: 'History.txt'; mrId: menu_historytxt),
    (mrText: ''; mrId: menu_about)

    );

const
  { Back to const: only T_MENU_ARRAY above had to become a var, because only
    its captions come from resourcestrings. E_MENU_ARRAY's are literals. }

  // B_MENU_ARRAY -- the band map context menu -- was here.  It is a TPopupMenu
  // in uBandMapForm.lfm now, so the items can be seen and edited in the form
  // designer instead of being numeric ids matched against a WM_COMMAND case.

  E_MENU_ARRAY_SIZE                     = 7;

var
  { A var, filled by InitializeMenuText -- the captions are resourcestrings
    now and a typed constant would fold the English in at compile time. This
    is the file viewer menu NY4I saw untranslated (2026-08-27). }
  E_MENU_ARRAY                          : array[0..E_MENU_ARRAY_SIZE] of MenuRecord = (
    (mrText: ''; mrId: MAXWORD),
    (mrText: ''; mrId: 101),
    (mrText: ''; mrId: 107),
    (mrText: ''; mrId: 0),
    (mrText: ''; mrId: 102),
    (mrText: ''; mrId: MAXWORD),
    (mrText: ''; mrId: 103),
    (mrText: ''; mrId: 104));

implementation

procedure InitializeMenuText;
{ Menu captions, assigned at RUN time so a translated resourcestring reaches
  them. Call after the translation is loaded and before the menu is built. }
var
   i: integer;
begin
   i := -1;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_FILE;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CLEARLOG;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_OPENLOGDIR;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_IMPORT;
   Inc(i); T_MENU_ARRAY[i].mrText := 'ADIF';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_EXPORT;
   Inc(i); T_MENU_ARRAY[i].mrText := 'ADIF';
   Inc(i); T_MENU_ARRAY[i].mrText := 'CSV';
   Inc(i); T_MENU_ARRAY[i].mrText := 'Cabrillo';
   Inc(i); T_MENU_ARRAY[i].mrText := 'EDI';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_INIEXLIST;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_NOTES;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_REPORTS;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_ALLCALLS;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_BANDCHANGES;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CONTLIST;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_FCC;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_FCZ;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_QSOBYCOUNTRY;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SCOREBYHOUR;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SUMMARY;
   Inc(i); T_MENU_ARRAY[i].mrText := '3830 Score';
   Inc(i); T_MENU_ARRAY[i].mrText := '';
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_EXIT;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SETTINGS;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_COLORS;
   Inc(i); T_MENU_ARRAY[i].mrText := 'Winkeyer';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CATANDCW;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_PROGRAMMES;
   Inc(i); T_MENU_ARRAY[i].mrText := 'LPT';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_WINDOWS;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_BANDMAP;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_DUPESHEET;
   Inc(i); T_MENU_ARRAY[i].mrText := TC_RADIO1;
   Inc(i); T_MENU_ARRAY[i].mrText := TC_RADIO2;
   Inc(i); T_MENU_ARRAY[i].mrText := '';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_FKEYS;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_TRMASTER;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_REMMULTS;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_RM_DEFAULT;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := 'DX';
   Inc(i); T_MENU_ARRAY[i].mrText := 'Domestic';
   Inc(i); T_MENU_ARRAY[i].mrText := 'Zones';
   Inc(i); T_MENU_ARRAY[i].mrText := 'Prefixes';
   Inc(i); T_MENU_ARRAY[i].mrText := '';
   Inc(i); T_MENU_ARRAY[i].mrText := TC_RADIO1;
   Inc(i); T_MENU_ARRAY[i].mrText := TC_RADIO2;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_TELNET;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_NETWORK;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_INTERCOM;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_POSTSCORETOGS;
   Inc(i); T_MENU_ARRAY[i].mrText := 'HamScore RTC Status';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_STATIONS;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_MP3REC;
   Inc(i); T_MENU_ARRAY[i].mrText := 'MMTTY';
   Inc(i); T_MENU_ARRAY[i].mrText := 'Alt-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_INC_TIME;
   Inc(i); T_MENU_ARRAY[i].mrText := '+1'#9'Alt+1';
   Inc(i); T_MENU_ARRAY[i].mrText := '+2'#9'Alt+2';
   Inc(i); T_MENU_ARRAY[i].mrText := '+3'#9'Alt+3';
   Inc(i); T_MENU_ARRAY[i].mrText := '+4'#9'Alt+4';
   Inc(i); T_MENU_ARRAY[i].mrText := '+5'#9'Alt+5';
   Inc(i); T_MENU_ARRAY[i].mrText := '+6'#9'Alt+6';
   Inc(i); T_MENU_ARRAY[i].mrText := '+7'#9'Alt+7';
   Inc(i); T_MENU_ARRAY[i].mrText := '+8'#9'Alt+8';
   Inc(i); T_MENU_ARRAY[i].mrText := '+9'#9'Alt+9';
   Inc(i); T_MENU_ARRAY[i].mrText := '+10'#9'Alt+0';
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_wkMode;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_BANDUP;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_AUTOCQRESUME;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_DUPECHECK;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_EDIT;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_BACKUPLOG;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SWAPMULTVIEW;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_INCNUMBER;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_TOOGLEMB;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_KILLCW;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SEARCHLOG;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SSBCWMODE;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_Download;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_ALTP;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_AUTOCQ;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_TOOGLERIGS;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CWSPEED;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SETSYSDT;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_BANDDOWN;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_INITIALIZE;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_ALTX;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_DELETELASTQSO;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_INITIALEX;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_TOOGLEST;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_TOOGLEAS;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := 'Ctrl-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SENDKEYBOARD;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CLEARMSHEET;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_OPTIONS;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CLEARDUPES;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_VIEWEDITLOG;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_NOTE;
   Inc(i); T_MENU_ARRAY[i].mrText := 'Rotor control';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_QTCFUNCTIONS;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_RECALLLASTENT;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SHDX_CALLSIGN;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_EXECONFIGFILE;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_REFRESHBM;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CURSORINBM;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_QSOWITHNOCW;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CURSORTELNET;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_ADDBANDMAPPH;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CT1BOHIS;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_ADDINFO;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_AI_QSONUMBER;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CALLSIGN;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_AI_CWSPEED;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_BAND;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_COMMANDS;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SPLITOFF;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_FOCUSINMW;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_TOGGLEINSERT;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_ESCAPE;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CWSPEEDUP;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CWSPEEDDOWN;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CWSPUPIR;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CWSPDNIR;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CQMODE;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SEARCHPOUNCE;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_LOGIN;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SENDSPOT;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_RESCORE;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_TOOLS;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_BEACONSM;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_WINCONTROL;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SETTIMEZONE;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_DEVICEMANAGER;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_PING;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_RUNSERVER;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_DVKVOLCONTROL;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_RECCONTROL;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := '';
   Inc(i); T_MENU_ARRAY[i].mrText := '';
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CALCULATOR;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_RESET_RADIO_PORTS;
   Inc(i); T_MENU_ARRAY[i].mrText := 'Download POTA Parks';
   Inc(i); T_MENU_ARRAY[i].mrText := 'Repeat POTA Parks (2nd Op)';
   Inc(i); T_MENU_ARRAY[i].mrText := 'HamScore: Resync log from scratch';
   Inc(i); T_MENU_ARRAY[i].mrText := 'Edit Cabrillo Summary...';
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_3830;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_3830_arrl;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_NET;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_TIMESYN;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SENDMESSAGE;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_SYNLOG;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CLEARALLLOGS;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_NET_CLDUPE;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_NET_CLMULT;
   Inc(i); T_MENU_ARRAY[i].mrText := HELP_WORD;
{$IFDEF LANG_RUS}
   Inc(i); T_MENU_ARRAY[i].mrText := RC_CONTENTS;
   Inc(i); T_MENU_ARRAY[i].mrText := '-';
{$ENDIF}
   Inc(i); T_MENU_ARRAY[i].mrText := RC_HOMEPAGE;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_Download;
   Inc(i); T_MENU_ARRAY[i].mrText := 'Download TRMASTER.DTA';
   Inc(i); T_MENU_ARRAY[i].mrText := 'Download POTA Parks';
   Inc(i); T_MENU_ARRAY[i].mrText := 'Check for Updates';
{$IFDEF LANG_RUS}
   Inc(i); T_MENU_ARRAY[i].mrText := RC_WIKI;
{$ENDIF}
   Inc(i); T_MENU_ARRAY[i].mrText := RC_ABOUT;

   { the file viewer menu -- same reason, same mechanism }
   i := -1;
   Inc(i); E_MENU_ARRAY[i].mrText := RC_FILE;
   Inc(i); E_MENU_ARRAY[i].mrText := TC_EDITOR_OPENINEDITOR;
   Inc(i); E_MENU_ARRAY[i].mrText := TC_EDITOR_EXPLORE;
   Inc(i); E_MENU_ARRAY[i].mrText := '-';
   Inc(i); E_MENU_ARRAY[i].mrText := RC_EXIT;
   Inc(i); E_MENU_ARRAY[i].mrText := TC_EDITOR_EDIT;
   Inc(i); E_MENU_ARRAY[i].mrText := TC_EDITOR_COPY + #9'Ctrl+C';
   Inc(i); E_MENU_ARRAY[i].mrText := TC_EDITOR_SELECTALL + #9'Ctrl+A';
end;

function CreateTR4WMenu(m: PMenuRecord; s: integer; popup: boolean): HMENU;

var
  i                                     : integer;
  uFlags                                : UINT;
  TempMenuRecord                        : MenuRecord;
//  TempMenu                              : HMENU;

  CurrMenu                              : HMENU;
  LatestMenu                            : HMENU;
  Caption                               : string;
  Shortcut                              : string;
begin
  if popup then
     begin
     Result := CreatePopupMenu
     end
  else
     begin
     Result := CreateMenu;
     end;

  LatestMenu := Result;
  CurrMenu := Result;

  for i := 0 to s do
     begin
     TempMenuRecord := PMenuRecord(integer(m) + (SizeOf(MenuRecord) * i))^;
     uFlags := MF_STRING;
     // A string is 1-based where the PAnsiChar was 0-based.
     if TempMenuRecord.mrText <> '' then
       if TempMenuRecord.mrText[1] = '-' then
          begin
          uFlags := MF_SEPARATOR;
          end;

     if TempMenuRecord.mrId = MAXWORD then
        begin
        CurrMenu := CreatePopupMenu;
        LatestMenu := CurrMenu;

        Windows.AppendMenuW(Result, MF_STRING + MF_POPUP, CurrMenu, PWideChar(TempMenuRecord.mrText));
        Continue;
        end;

     if TempMenuRecord.mrId = MAXWORD - 1 then
        begin
        CurrMenu := CreatePopupMenu;
        Windows.AppendMenuW(LatestMenu, MF_STRING + MF_POPUP, CurrMenu, PWideChar(TempMenuRecord.mrText));
        Continue;
        end;
     if TempMenuRecord.mrId = MAXWORD - 2 then
        begin
        CurrMenu := LatestMenu;
        Continue;
        end;
     // THE SHORTCUT TEXT COMES FROM THE ACCELERATOR TABLE, not from a constant
     // concatenated into mrText.  77 rows used to read `RC_EXIT + RC_EXIT_HK`,
     // which is how the menu came to advertise keys the table did not bind and
     // vice versa -- Alt+P on two commands, a bare '-' for Ctrl+-, Alt+- for
     // nothing at all.  One row now produces both the binding and the label, so
     // they cannot disagree.  See docs\ACCELERATOR_AUDIT.md.
     { AND THE ROW MUST NOT SPELL THE SHORTCUT ITSELF.  Three did --
       'Cabrillo'#9'Ctrl+Alt+B', 'Winkeyer'#9'Ctrl+W', 'LPT'#9'Ctrl+Alt+L' --
       so the operator saw the key TWICE: the row's copy and this one.
       Found 2026-08-26 by test\ui\Dump-Menu.ps1 on its first run.  The
       2026-08-17 sweep that removed 77 `RC_x + RC_x_HK` concatenations
       missed them because they carried a literal tab inside a quoted
       string rather than an _HK constant. }
     Caption := TempMenuRecord.mrText;
     if uFlags = MF_STRING then
        begin
        Shortcut := AcceleratorDisplayFor(TempMenuRecord.mrId);
        if Shortcut <> '' then
           begin
           Caption := Caption + #9 + Shortcut;
           end;
        end;
     Windows.AppendMenuW(CurrMenu, uFlags, TempMenuRecord.mrId, PWideChar(Caption));
     end;


end;

end.
