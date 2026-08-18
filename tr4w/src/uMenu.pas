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
  Windows;

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
    T_MENU_ARRAY_SIZE                     = 176 + 1 {MMTTY window}{$IFDEF LANG_RUS} + 3{$ENDIF} + 2 {RC_RESET_RADIO_PORTS, separator, Repeat POTA Parks} + 2 {HamScore Resync (Tools) + HamScore Status (Windows menu), Issue #783} + 1 {3830 Score under File-Reports} + 1 {Edit Cabrillo Summary under Tools, Issue #914} + 1 {Download TRMASTER.DTA, 2026-08-16} - 1 {Appearance removed, 2026-08-16};
  T_MENU_ARRAY                          : array[0..T_MENU_ARRAY_SIZE] of MenuRecord = (
    (mrText: RC_FILE; mrId: MAXWORD),
 //{
    (mrText: RC_CLEARLOG; mrId: menu_clear_log),
    (mrText: RC_OPENLOGDIR; mrId: menu_log_file_properties),
    (mrText: RC_IMPORT; mrId: MAXWORD - 1),
  //{
    (mrText: 'ADIF'; mrId: menu_import_adif),
  //}

    (mrText: RC_EXPORT; mrId: MAXWORD - 1),
  //{
    (mrText: 'ADIF'; mrId: menu_adif),
    (mrText: 'CSV'; mrId: menu_csv),
    (mrText: 'Cabrillo'#9'Ctrl+Alt+B'; mrId: menu_cabrillo),
    (mrText: 'EDI'; mrId: menu_export_edi),
    (mrText: RC_INIEXLIST; mrId: menu_initial_ex_list),
//    (mrText: RC_TRLOGFORM; mrId: menu_trlog),
    (mrText: RC_NOTES; mrId: menu_export_notes),
  //}

    (mrText: RC_REPORTS; mrId: MAXWORD - 1),
  //{
    (mrText: RC_ALLCALLS; mrId: menu_allcallsigns_list),
    (mrText: RC_BANDCHANGES; mrId: menu_band_changes),
    (mrText: RC_CONTLIST; mrId: menu_continentlist),
    (mrText: RC_FCC; mrId: menu_first_call_work_ineachcountry),
    (mrText: RC_FCZ; mrId: menu_first_call_work_InEachZone),
    (mrText: RC_QSOBYCOUNTRY; mrId: menu_qsobycountry),
    (mrText: RC_SCOREBYHOUR; mrId: menu_scorebyhour),
    (mrText: RC_SUMMARY; mrId: menu_summary),
    (mrText: '3830 Score'; mrId: menu_3830scores),
  //}
    (mrText: ''; mrId: MAXWORD - 2),
    (mrText: '-'; mrId: 0),
    (mrText: RC_EXIT; mrId: menu_exit),
 //}

    (mrText: RC_SETTINGS; mrId: MAXWORD),
 //{

    (mrText: '-'; mrId: 0),

    (mrText: RC_COLORS; mrId: menu_colors),
    // APPEARANCE REMOVED 2026-08-16 (NY4I). It opened RunOptionsDialog with the
    // cfAppearance filter, and every row that filter selected is now csOwned --
    // so it opened an empty list. Its settings live on the Preferences
    // Appearance page, which the Ctrl-J entry above reaches. menu_appearance
    // itself is kept in VC.pas and still handled in ProcessMenu, because the
    // id may arrive from an accelerator or a saved menu state.
    (mrText: 'Winkeyer'#9'Ctrl+W'; mrId: menu_winkeyer2),

    // One item, not a submenu: the Preferences window owns BOTH radio slots
    // plus the radio library and the profiles, so a per-slot entry would open
    // the same window twice.  The legacy per-slot dialog (uCAT.CATDlgProc) is
    // still reachable with the CATLEGACY call-window command while the new
    // path is being proven on the bench.
    (mrText: RC_CATANDCW; mrId: menu_radio_preferences),

    (mrText: '-'; mrId: 0),
    (mrText: RC_PROGRAMMES; mrId: menu_messages),

    (mrText: 'LPT'#9'Ctrl+Alt+L'; mrId: menu_lpt),

 //}

    (mrText: RC_WINDOWS; mrId: MAXWORD),
 //{
    (mrText: RC_BANDMAP; mrId: menu_windows_bandmap),

    (mrText: RC_DUPESHEET; mrId: MAXWORD - 1),
  //{
    (mrText: TC_RADIO1; mrId: menu_windows_dupesheet1),
    (mrText: TC_RADIO2; mrId: menu_windows_dupesheet2),
  //}
    (mrText: ''; mrId: MAXWORD - 2),
    (mrText: RC_FKEYS; mrId: menu_windows_funckeys),
    (mrText: RC_TRMASTER; mrId: menu_windows_trmasterdta),
    (mrText: RC_REMMULTS; mrId: MAXWORD - 1),
    (mrText: RC_RM_DEFAULT; mrId: menu_windows_remmults),

    (mrText: '-'; mrId: 0),
    (mrText: 'DX'; mrId: menu_rm_dx),
    (mrText: 'Domestic'; mrId: menu_rm_domestic),
    (mrText: 'Zones'; mrId: menu_rm_zone),
    (mrText: 'Prefixes'; mrId: menu_rm_prefix),
    (mrText: ''; mrId: MAXWORD - 2),
  //}

    (mrText: TC_RADIO1; mrId: menu_windows_radiointerface1),
    (mrText: TC_RADIO2; mrId: menu_windows_radiointerface2),
    (mrText: '-'; mrId: 0),
    (mrText: RC_TELNET; mrId: menu_windows_telnet),
    (mrText: RC_NETWORK; mrId: menu_windows_network),
    (mrText: '-'; mrId: 0),
    (mrText: RC_INTERCOM; mrId: menu_windows_intercom),
    (mrText: RC_POSTSCORETOGS; mrId: menu_windows_getscores),
    (mrText: 'HamScore RTC Status'; mrId: menu_windows_hamscore),  // Issue #783 Phase 4
    (mrText: RC_STATIONS; mrId: menu_windows_stations),
    (mrText: RC_MP3REC; mrId: menu_windows_mp3recorder),
    (mrText: 'MMTTY'; mrId: menu_windows_mmtty),
 //}

    (mrText: 'Alt-'; mrId: MAXWORD),
 //{
    (mrText: RC_INC_TIME; mrId: MAXWORD - 1),
  //{
    (mrText: '+1'#9'Alt+1'; mrId: menu_alt_increment_time_1),
    (mrText: '+2'#9'Alt+2'; mrId: menu_alt_increment_time_2),
    (mrText: '+3'#9'Alt+3'; mrId: menu_alt_increment_time_3),
    (mrText: '+4'#9'Alt+4'; mrId: menu_alt_increment_time_4),
    (mrText: '+5'#9'Alt+5'; mrId: menu_alt_increment_time_5),
    (mrText: '+6'#9'Alt+6'; mrId: menu_alt_increment_time_6),
    (mrText: '+7'#9'Alt+7'; mrId: menu_alt_increment_time_7),
    (mrText: '+8'#9'Alt+8'; mrId: menu_alt_increment_time_8),
    (mrText: '+9'#9'Alt+9'; mrId: menu_alt_increment_time_9),
    (mrText: '+10'#9'Alt+0'; mrId: menu_alt_increment_time_0),
  //}

    (mrText: '-'; mrId: MAXWORD - 2),
    (mrText: RC_wkMode; mrId: menu_alt_wkmode),    // 4.60.1
    (mrText: RC_BANDUP; mrId: menu_alt_bandup),
    (mrText: RC_AUTOCQRESUME; mrId: menu_alt_autocqresume),
    (mrText: RC_DUPECHECK; mrId: menu_alt_dupecheck),
    (mrText: RC_EDIT; mrId: menu_alt_SO2R_edit),
    (mrText:  RC_BACKUPLOG;mrId: menu_alt_savetofloppy),
    (mrText: RC_SWAPMULTVIEW; mrId: menu_alt_swapmults),
    (mrText: RC_INCNUMBER; mrId: menu_alt_incnumber),
    (mrText: RC_TOOGLEMB; mrId: menu_alt_multbell),
    (mrText: RC_KILLCW; mrID: menu_alt_killcw),
    (mrText: RC_SEARCHLOG; mrId: menu_alt_searchlog),
    (mrText: RC_SSBCWMODE; mrId: menu_alt_ssbcwmode),

    (mrText: RC_Download; mrId: menu_download_latest_cty_dat), // 4.75.3
//    (mrText: RC_TRANSFREQ; mrId: menu_alt_transfreq),     // 4.68.11
    (mrText: RC_ALTP; mrId: menu_alt_p),
    (mrText: RC_AUTOCQ; mrId: menu_alt_autocq),
    (mrText: RC_TOOGLERIGS; mrId: menu_alt_tooglerigs),
    (mrText: RC_CWSPEED; mrId: menu_alt_cwspeed),
    (mrText: RC_SETSYSDT; mrId: menu_alt_settime),
    (mrText: RC_BANDDOWN; mrId: menu_alt_banddown),
    (mrText: RC_INITIALIZE; mrId: menu_alt_init_qso),
    (mrText: RC_ALTX;         mrId: menu_alt_x),
    (mrText: RC_DELETELASTQSO; mrId: menu_alt_deleteqso),
    (mrText: RC_INITIALEX; mrId: menu_alt_initialexhange),
    (mrText: RC_TOOGLEST; mrId: menu_alt_tooglesidetone),
    (mrText: RC_TOOGLEAS; mrId: menu_alt_toogleautosend),
    (mrText: '-'; mrId: 0),



 //

    (mrText: 'Ctrl-'; mrId: MAXWORD),
 //{
    (mrText: RC_SENDKEYBOARD; mrId: menu_ctrl_sendkeyboardinput),
    (mrText: RC_CLEARMSHEET; mrId: menu_ctrl_clearmultsheet),
//    (mrText: RC_DAQSLINT; mrId: menu_ctrl_decAQSLinterval),  //n4af 04.37.10
 //   (mrText: RC_IAQSLINT; mrId: menu_ctrl_incAQSLinterval),   //n4af 04.37.10
    (mrText: RC_OPTIONS; mrId: menu_options),
    (mrText: RC_CLEARDUPES; mrId: menu_ctrl_cleardupesheet),
    (mrText: RC_VIEWEDITLOG; mrId: menu_ctrl_viewlogdat),
    (mrText: RC_NOTE; mrId: menu_ctrl_note),
//    (mrText: RC_MISSMULTSREP; mrId: menu_ctrl_missmultsreport),  //n4af 04/37.10
//    (mrText:  'PTT'; mrId: menu_ctrl_ptt),
    (mrText:  'Rotor control'; mrId: menu_ctrl_redoposscalls),  // 4.54.5
    (mrText: RC_QTCFUNCTIONS; mrId: menu_ctrl_qtcfunctions),
    (mrText: RC_RECALLLASTENT; mrId: menu_ctrl_recalllastentry),
    (mrText: RC_SHDX_CALLSIGN; mrId: menu_ctrl_shdxcallsign),
//    (mrText: RC_VIEWPAKSPOTS; mrId: menu_ctrl_viewpacketspots),
    (mrText: RC_EXECONFIGFILE; mrId: menu_ctrl_execute_config),
    (mrText: RC_REFRESHBM; mrId: menu_ctrl_refreshbandmap),
    (mrText: RC_CURSORINBM; mrId: menu_ctrl_cursorinbandmap),
    (mrText: RC_QSOWITHNOCW; mrId: menu_ctrl_logqsowithoutcw),
    (mrText: RC_CURSORTELNET; mrId: menu_ctrl_cursorintelnet),
    (mrText: RC_ADDBANDMAPPH; mrId: menu_ctrl_PlaceHolder),

    (mrText: RC_CT1BOHIS; mrId: menu_ctrl_ct1bohscreen),
    (mrText: RC_ADDINFO; mrId: MAXWORD - 1),
  //{
    (mrText: RC_AI_QSONUMBER; mrId: menu_ctrl_showQSONumber),
    (mrText: RC_CALLSIGN; mrId: menu_ctrl_showCallsign),
    (mrText: RC_AI_CWSPEED; mrId: menu_ctrl_showSpeed),
    (mrText: RC_BAND; mrId: menu_ctrl_showBand),
  //}

 //}

    (mrText: RC_COMMANDS; mrId: MAXWORD),
 //{

    (mrText: RC_SPLITOFF; mrId: menu_ctrl_SplitOff),      // n4af 4.47.3

    (mrText: RC_FOCUSINMW; mrId: menu_mainwindow_setfocus),
    (mrText: RC_TOGGLEINSERT; mrId: menu_insertmode),
    (mrText: RC_ESCAPE; mrId: menu_escape),
    (mrText: '-'; mrId: 0),
    (mrText: RC_CWSPEEDUP; mrId: menu_cwspeedup),
    (mrText: RC_CWSPEEDDOWN; mrId: menu_cwspeeddown),
    (mrText: '-'; mrId: 0),
    (mrText: RC_CWSPUPIR; mrId: menu_inactiveradio_cwspeedup),
    (mrText: RC_CWSPDNIR; mrId: menu_inactiveradio_cwspeeddown),
    (mrText: '-'; mrId: 0),
    (mrText: RC_CQMODE; mrId: menu_cqmode),
    (mrText: RC_SEARCHPOUNCE; mrId: menu_spmode_ortab),
    (mrText: '-'; mrId: 0),
    (mrText: RC_LOGIN; mrId: menu_login),
    (mrText: '-'; mrId: 0),
    (mrText: RC_SENDSPOT; mrId: menu_ctrl_sendspot),
    (mrText: RC_RESCORE; mrId: menu_rescore),
 //}

    (mrText: RC_TOOLS; mrId: MAXWORD),
 //{
    (mrText: RC_SYNPCTIME; mrId: menu_syncpctime),
    (mrText: RC_BEACONSM; mrId: menu_beaconsmonitor),
    (mrText: RC_WINCONTROL; mrId: menu_windowsmanager),
    (mrText: RC_SETTIMEZONE; mrId: menu_settimezone),
    (mrText: RC_DEVICEMANAGER; mrId: menu_run_devicemanager),
    (mrText: '-'; mrId: 0),
    (mrText: RC_PING; mrId: menu_pingserver),
    (mrText: RC_RUNSERVER; mrId: menu_runserver),
    (mrText: '-'; mrId: 0),
    (mrText: RC_DVKVOLCONTROL; mrId: menu_volume_control),
    (mrText: RC_RECCONTROL; mrId: menu_recording_control),
    (mrText: '-'; mrId: 0),
    (mrText: ''; mrId: menu_WA7BNM_calendar),
    (mrText: ''; mrId: menu_qrzru_calendar),
    (mrText: '-'; mrId: 0),
    (mrText: RC_CALCULATOR; mrId: item_calculator),
    (mrText: '-'; mrId: 0),
    (mrText: RC_RESET_RADIO_PORTS; mrId: menu_reset_radio_ports),
    (mrText: 'Download POTA Parks'; mrId: menu_download_pota_parks),  // issue #864
    (mrText: 'Repeat POTA Parks (2nd Op)'; mrId: menu_repeat_pota_parks),
    (mrText: 'HamScore: Resync log from scratch'; mrId: menu_hamscore_resync),  // Issue #783
    (mrText: 'Edit Cabrillo Summary...'; mrId: menu_edit_cabrillo_summary),     // Issue #914
 //}
    (mrText: '-'; mrId: 0),
    (mrText: RC_3830; mrId: menu_3830_scores_posting),
    (mrText: RC_3830_arrl; mrId: menu_arrl_submit),    // 4.53.3
    (mrText: '-'; mrId: 0),
    (mrText: RC_NET; mrId: MAXWORD),
 //{
    (mrText: RC_TIMESYN; mrId: menu_alt_setnettime),
    (mrText: RC_SENDMESSAGE; mrId: menu_send_message),
    (mrText: RC_SYNLOG; mrId: menu_getserverlog),
    (mrText: '-'; mrId: 0),
    (mrText: RC_CLEARALLLOGS; mrId: menu_clearserverlog),
    (mrText: '-'; mrId: 0),
    (mrText: RC_NET_CLDUPE; mrId: menu_clear_dupesheet_in_network),
    (mrText: RC_NET_CLMULT; mrId: menu_clear_multsheet_in_network),
 //}

    (mrText: HELP_WORD; mrId: MAXWORD),        // n4af 4.42.5
 //{
{$IFDEF LANG_RUS}
    (mrText: RC_CONTENTS; mrId: menu_contents),
    (mrText: '-'; mrId: 0),
{$ENDIF}
//    (mrText: RC_SEND_BUG; mrId: menu_send_bug),
//    (mrText: '-'; mrId: 0),
    (mrText: RC_HOMEPAGE; mrId: menu_home_page),
    (mrText: RC_Download; mrID: menu_download_latest_cty_dat), // 4.75.3
    (mrText: 'Download TRMASTER.DTA'; mrId: menu_download_trmaster),  // 2026-08-16
    (mrText: 'Download POTA Parks'; mrId: menu_download_pota_parks),  // issue #864
    {$IFDEF LANG_RUS}
    (mrText: RC_WIKI; mrId: menu_wiki_rus),
{$ENDIF}
//    (mrText: 'History.txt'; mrId: menu_historytxt),
    (mrText: RC_ABOUT; mrId: menu_about)

    );

  B_MENU_ARRAY_SIZE                     = 10;
  B_MENU_ARRAY                          : array[0..B_MENU_ARRAY_SIZE] of MenuRecord = (
    (mrText: 'BAND MAP ALL BANDS'#9'B'; mrId: 66),
    (mrText: 'BAND MAP ALL MODES'#9'M'; mrId: 77),
    (mrText: 'BAND MAP DISPLAY CQ'; mrId: 202),
    (mrText: 'BAND MAP DUPE DISPLAY'#9'D'; mrId: 68),
    (mrText: 'BAND MAP MULTS ONLY'; mrId: 69),
    (mrText: '-'; mrId: 0),
    (mrText: RC_DELETESELSPOT; mrId: 203),
    (mrText: RC_REMOVEALLSP; mrId: 204),
    (mrText: '-'; mrId: 0),
    (mrText: RC_SENDINRIG; mrId: 205),
    (mrText: 'BAND MAP SO2R DISPLAY'; mrId: 206)
    );

  E_MENU_ARRAY_SIZE                     = 7;
  E_MENU_ARRAY                          : array[0..E_MENU_ARRAY_SIZE] of MenuRecord = (
    (mrText: '&File'; mrId: MAXWORD),
    (mrText: 'Open in text &editor'; mrId: 101),
    (mrText: 'Explore'; mrId: 107),
    (mrText: '-'; mrId: 0),
    (mrText: 'E&xit'; mrId: 102),
    (mrText: '&Edit'; mrId: MAXWORD),
    (mrText: '&Copy '#9'Ctrl+C'; mrId: 103),
    (mrText: 'Select &all '#9'Ctrl+A'; mrId: 104));

implementation

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
