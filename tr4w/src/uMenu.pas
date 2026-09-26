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
  Classes,         // TComponent, TNotifyEvent
  LCLType,         // MAXWORD -- the LCL declares it; it is not Windows-only
  Controls,        // TCaption -- what a menu caption actually is
  Menus,           // TMainMenu, TMenuItem
  VC,
  uAccelerators,   // AcceleratorDisplayFor -- the shortcut text a menu item shows
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

(* THE MAIN MENU AS AN LCL TMainMenu, from the same T_MENU_ARRAY.

  Every item gets Tag = its command id and OnClick = aOnClick, so one handler
  dispatches the whole menu and no window message is involved. A separator is a
  row whose caption starts with '-', exactly as the Win32 walk read it.

  A menu item OWNS its keystroke: item.ShortCut is set from the accelerator
  table, and the widget set both renders it and binds it. See the
  implementation. *)
function BuildTR4WMainMenu(const aOwner: TComponent;
                           const aOnClick: TNotifyEvent): TMainMenu;

(* WHO OWNS A KEYSTROKE -- ONE RULE, READ BY BOTH SIDES.

  THE KEYS DIVIDE IN TWO AND THE TWO SETS MUST NOT OVERLAP. A keystroke that
  belongs to a menu item is carried by TMenuItem.ShortCut: the widget set draws
  it in the shortcut column -- right-aligned on Win32, as a key equivalent on
  the Cocoa menu bar, as an accel label on gtk2 -- and dispatches it. Every
  other keystroke stays with uAppInputHooks, which answers ACCELERATORS from an
  application-wide key handler.

  docs\ACCELERATOR_AUDIT.md exists because two things answering one keystroke is
  a defect. This satisfies it BY CONSTRUCTION rather than by prohibition: the
  function below is the ONLY rule, the menu builder uses it to decide what to
  put on an item, and the input hook uses the SAME function to decide what to
  skip. Neither can drift from the other because there is nothing to drift from.

  WHY SOME ROWS STAY WITH THE HOOK, measured in the LCL source rather than
  assumed. A TMenuItem.ShortCut is answered before the focused control sees the
  key and from ANY form in the application -- TApplication.IsShortcut falls back
  to the MAIN FORM's menu when the active form does not claim it
  (application.inc:2157). It cannot be declined for one window, and the hook's
  guards exist precisely to decline:

    * Ctrl+A, Ctrl+C, Ctrl+V and Ctrl+X are send-keyboard-input,
      clear-mult-sheet and execute-config. Issue #23 -- a Ctrl+C meant to copy a
      spot in the cluster window cleared the mult sheet -- and NY4I's
      2026-09-15 report that the standard editing keys do not work on a dialog.
      Both are answered by guards in uAppInputHooks that a ShortCut would
      bypass;
    * an UNMODIFIED keystroke is ordinary typing somewhere. Tab and Escape
      belong to whatever form has the keyboard (the radio editor closed on Tab,
      2026-09-09), and Ins, ` and Enter would be eaten inside any edit field on
      any window;
    * a row that does not install is not automatically excluded any more.
      acInstall False means the INPUT HOOK does not install the key; where
      nothing else binds it either, the menu item may. That is a list of two,
      named beside RowCouldBeAMenuShortCut, and it is not a general rule.

  Those rows keep advertising their keystroke through the caption, which is the
  only way left to show it, and acDisplay survives for them alone. They spell
  it IN PARENTHESES -- "Toggle insert mode (Ins)" -- which reads as part of the
  label; see CaptionWithInlineKey.

  IT WAS A TAB UNTIL 2026-09-26, and that is the defect NY4I photographed
  across three menus: DrawText is given DT_EXPANDTABS, so a tab is a TAB STOP
  chosen by each caption's own length, and a handful of rows sitting at their
  own stop beside a right-aligned column reads as ragged rather than as a
  second column. "Frankly looks bad."

  TWO OF THE FIVE LEFT THE INLINE SET ENTIRELY, by NY4I's decision the same
  day -- Alt+X (Exit Program) and Alt+- (Toggle autosend) now carry real
  ShortCuts and appear in the column. What stays inline is Ctrl+A, Ctrl+C,
  Ctrl+V and every unmodified key, all of them rows whose keystroke has to be
  declinable in a window that needs it.

  THERE IS NO DISPLAY-WITHOUT-BINDING TO FIX IT WITH, and that is measured in
  the widget set rather than assumed. EVERY path that reserves or draws the
  shortcut column is gated on ShortCut <> scNone and there is no other entry to
  it: win32wsmenus.pp:472 (the themed measure, which is the only place
  ShortCustSize.cx is computed), :584 (the classic measure), :930 (the themed
  draw) and :1161 (the classic draw). The item's own OnDrawItem is not a way
  round it -- menuitem.inc:304-323 makes it ALL OR NOTHING, so we would be
  reimplementing the themed background, gutter, check mark and icon to gain one
  column, and neither cocoawsmenus nor gtk2wsmenus routes drawing through it at
  all, so it would be a Windows-only answer to a defect that is on all three.

  PADDING THE CAPTION IS NOT AN ANSWER EITHER. The item is measured with
  GetThemeTextExtent in the MENU's font at the item's own monitor DPI
  (:461-470, GetMenuItemFont + GetDpiForWindow), so a pad would have to be
  computed in a font this unit does not have, at a DPI it does not know, and
  recomputed on a theme change or a move to another monitor -- silently wrong
  when it was not. The classic path measures the caption with the tab STRIPPED
  (:581, CompleteMenuItemCaption(..., EmptyStr)), so on that theme a padded
  caption can be clipped outright.

  SO THE KEY GOES IN THE LABEL, and the rule stays crisp: the items showing a
  keystroke inline are EXACTLY the ones whose keystroke can be declined in a
  window that needs it. Alignment could only be bought by giving that up, which
  was NY4I's decision rather than ours; what he chose instead (2026-09-26) was
  to stop the inline rows pretending to be a column. See
  docs\ACCELERATOR_SHORTCUT_PLAN.md, which records what the alternative would
  have cost.

  TWO THINGS BEHAVE DIFFERENTLY AFTER THIS, BOTH DELIBERATE AND BOTH WORTH
  KNOWING BEFORE SOMEONE REPORTS THEM AS DEFECTS.

  A DISABLED ITEM NO LONGER ANSWERS ITS KEYSTROKE. TMenu.IsShortcut walks the
  item's ancestors and gives up if any of them is disabled (menu.inc:265-272),
  where the input hook dispatched whatever the menu looked like. That is the
  native semantic and it matches what each grey-out was already saying:
  Ctrl+Alt+T, Shift+' and Ctrl+Alt+S do nothing until uNet enables the Network
  popup; Ctrl+Shift+3 and Ctrl+Shift+8 do nothing in WRTC; and Alt+1..Alt+0 do
  nothing in hand-log mode, where uProgramMain greys them because they "do
  nothing" anyway.

  AND THEY NOW WORK WHILE THE CLUSTER WINDOW HAS FOCUS. uAppInputHooks exits
  early for the Telnet form -- a blunt guard whose stated reason is the EDITING
  keys (Issue #23) -- so today no accelerator at all fires from there. The keys
  it was protecting are precisely the ones that stayed behind, and the rest now
  behave as they already do from every other tool window, which that unit calls
  a capability the LCL conversion gained. *)
function AcceleratorRowBelongsToTheMenu(const aIndex: integer): boolean;

{ The shortcut a menu item takes for this command, or scNone when the keystroke
  is not the menu's to own. }
function MenuShortCutFor(const aId: word): TShortCut;

(* A KEYSTROKE THE MENU MAY NOT OWN, SPELLED INTO THE LABEL.

  Ctrl+A/C/V/X and every unmodified key stay with the input hook -- see
  AcceleratorRowBelongsToTheMenu -- and the LCL draws its right-aligned
  shortcut column from TMenuItem.ShortCut and from nothing else, so those rows
  have only their caption in which to advertise the key.

  IT USED TO BE A TAB, which is what AppendMenu wanted. The Win32 draw path
  runs the caption through DrawText with DT_EXPANDTABS, so the tab is a TAB
  STOP chosen by the caption's own length rather than a column: a minority of
  rows sat at a stop of their own while the majority were right-aligned, which
  is the ragged menu NY4I photographed on 2026-09-26 -- "frankly looks bad".

  Parentheses read as part of the label and so cannot pretend to be a column.
  Cocoa and gtk2 never had a tab convention at all and pass the caption
  straight to the native widget, so this is equally correct there.

  NO NEW TRANSLATABLE TEXT: the words come from the row's resourcestring and
  the key from uAccelerators.AcceleratorDisplayFor. The punctuation lives HERE,
  once, rather than at each call site. *)
function CaptionWithInlineKey(const aCaption: string; const aKey: string): string;

{ The inverse, for the one reader that wants the label alone: a window's title
  is its menu row's caption (MainUnit.OpenTR4WWindow). }
function CaptionWithoutInlineKey(const aCaption: string): string;

{ Is there a main-menu row for this command id at all? }
function MenuCommandExists(const aId: word): boolean;

{ THE ITEM WITH THIS COMMAND ID, or nil.

  Replaces reaching into the menu HANDLE by id -- CheckMenuItem, EnableMenuItem,
  ModifyMenu, DeleteMenu, GetMenuString. The index is built by
  BuildTR4WMainMenu during the same walk, so it cannot describe a menu that was
  not created. }
function MenuItemById(const aId: word): TMenuItem;

{ The top-level popup at this position -- uNet enables and disables the whole
  Network menu, which it addressed by POSITION and not by id. }
function TopLevelMenuItem(const aIndex: integer): TMenuItem;
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
    T_MENU_ARRAY_SIZE                     = 176 + 1 {MMTTY window}{$IFDEF LANG_RUS} + 1{$ENDIF} {menu_wiki_rus -- was +3 until 2026-09-08, when Help->Contents and its separator had already gone} + 2 {RC_RESET_RADIO_PORTS, separator, Repeat POTA Parks} + 2 {HamScore Resync (Tools) + HamScore Status (Windows menu), Issue #783} + 1 {3830 Score under File-Reports} + 1 {Edit Cabrillo Summary under Tools, Issue #914} + 1 {Download TRMASTER.DTA, 2026-08-16} - 1 {Appearance removed, 2026-08-16} - 1 {Synchronize PC time removed, 2026-08-25 -- setting the clock needs UAC} - 1 {Device Manager removed, 2026-09-01 -- an application does not shell out to mmc} - 1 {MP3 Recorder removed, 2026-09-07 -- recording moves to QSOCapture} + 1 {Run Verification Checks under Tools, 2026-09-12} - 1 {LPT ports removed, 2026-09-13 -- the parallel port is gone from the program}
                                            - 0 {Check for Updates taken OFF the menu 2026-08-28 -- see the row below};

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
    (* The MP3 recorder row went with the recorder, 2026-09-07. *)
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
    (mrText: ''; mrId: menu_run_verification_checks),
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
    (* Help -> Contents IS GONE (2026-09-07) with the CHM help system. It was
      {$IFDEF LANG_RUS}-guarded here AND in ProcessMenu, so an English build
      had neither the row nor a handler -- but Lint-MenuDispatch reads source
      text without evaluating conditionals, so it saw a row and an arm and was
      satisfied. Removing the arm alone made it report the row as unhandled,
      which is how the pair surfaced at all. *)
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
    // CHECK FOR UPDATES -- OFF THE MENU 2026-08-28, at NY4I's request.
    //
    // There is no endpoint to ask. The check fetches a page and shows whatever
    // comes back as "the last version on server", so when tr4w.net answered
    // with a Cloudflare error the operator was shown raw HTML and invited to
    // download it:
    //
    //    The last version on server: <html><head><title>400 Bad Request</title>
    //    ... This version: TR4W v.5.0.2. Would you like to download the latest
    //    version?
    //
    // NY4I: "we still have the issue of implementing a good pattern where our
    // website can give you the latest version info... I also need to get a
    // static link that redirects to the latest. So for now, let's disable that
    // menu item."
    //
    // The unit, the handler and the id all stay: this is one line to restore
    // once the site serves a version string rather than a web page. The real
    // fix is a documented endpoint and a response this can PARSE, plus moving
    // its socket work off the main thread -- it sleeps 2 seconds on the UI
    // thread today, which is its own bench-queue item.
    // (mrText: ''; mrId: menu_check_latest_version),  // 2026-08-22
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
   (* RC_MP3REC stood here. Its ROW went with the MP3 recorder on 2026-09-07
     and this line did not, so every caption from MMTTY onwards was assigned
     to the row before it: the fourth top-level popup read "MMTTY" instead of
     "Alt-", and the menu bar ended "Band  Rescore  -  Clear multsheet in all
     logs" (NY4I, 2026-09-08). Lint-MenuDispatch counts the two sides now. *)
   Inc(i); T_MENU_ARRAY[i].mrText := 'MMTTY';
   Inc(i); T_MENU_ARRAY[i].mrText := 'Alt-';
   Inc(i); T_MENU_ARRAY[i].mrText := RC_INC_TIME;
   (* THE ONLY TEN CAPTIONS IN THE MAIN MENU THAT SPELLED THEIR OWN SHORTCUT,
     and they were the only ones showing it TWICE: the builder appends the
     accelerator table's text as well, so these read "+1<tab>Alt+1<tab>Alt+1".
     The item carries Alt+1 as a ShortCut now, like every other row. *)
   Inc(i); T_MENU_ARRAY[i].mrText := '+1';
   Inc(i); T_MENU_ARRAY[i].mrText := '+2';
   Inc(i); T_MENU_ARRAY[i].mrText := '+3';
   Inc(i); T_MENU_ARRAY[i].mrText := '+4';
   Inc(i); T_MENU_ARRAY[i].mrText := '+5';
   Inc(i); T_MENU_ARRAY[i].mrText := '+6';
   Inc(i); T_MENU_ARRAY[i].mrText := '+7';
   Inc(i); T_MENU_ARRAY[i].mrText := '+8';
   Inc(i); T_MENU_ARRAY[i].mrText := '+9';
   Inc(i); T_MENU_ARRAY[i].mrText := '+10';
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
   Inc(i); T_MENU_ARRAY[i].mrText := 'Run Verification Checks...';
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
   (* RC_CONTENTS and its separator stood here, under the LANG_RUS guard.
     Help -> Contents lost its ROWS with the CHM help system on 2026-09-07;
     these two captions stayed behind, exactly as RC_MP3REC did above. *)
   Inc(i); T_MENU_ARRAY[i].mrText := RC_HOMEPAGE;
   Inc(i); T_MENU_ARRAY[i].mrText := RC_Download;
   Inc(i); T_MENU_ARRAY[i].mrText := 'Download TRMASTER.DTA';
   Inc(i); T_MENU_ARRAY[i].mrText := 'Download POTA Parks';
   { The row this captioned was taken off the menu 2026-08-28; the caption
     goes with it, because these are assigned BY POSITION and leaving it
     would shift every caption after it -- About came out reading
     "Check for Updates". }
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

(* THE ID INDEX. A plain dynamic array of (id, item): the menu has under two
  hundred rows and every lookup is a one-off in response to something the
  operator did, so a linear scan is the right shape -- no hashing, nothing to
  keep in step, and it is emptied and refilled whenever the menu is rebuilt. *)
type
   TMenuIdEntry = record
      Id:   word;
      Item: TMenuItem;
   end;

var
   GMenuIndex: array of TMenuIdEntry;
   GMainMenu:  TMainMenu = nil;

function MenuItemById(const aId: word): TMenuItem;
var
   i: integer;
begin
   Result := nil;
   for i := 0 to High(GMenuIndex) do
      begin
      if GMenuIndex[i].Id = aId then
         begin
         Result := GMenuIndex[i].Item;
         Exit;
         end;
      end;
end;

function TopLevelMenuItem(const aIndex: integer): TMenuItem;
begin
   Result := nil;
   if (GMainMenu <> nil) and (aIndex >= 0) and
      (aIndex < GMainMenu.Items.Count) then
      begin
      Result := GMainMenu.Items[aIndex];
      end;
end;

function MenuCommandExists(const aId: word): boolean;
var
   i: integer;
begin
   Result := False;

   (* THE ROW ARRAY, NOT THE BUILT MENU. This has to answer before
     BuildTR4WMainMenu has run -- the builder itself is the first caller -- and
     T_MENU_ARRAY is what the builder walks, so the two cannot disagree about
     which commands the menu has. *)
   for i := 0 to T_MENU_ARRAY_SIZE do
      begin
      if T_MENU_ARRAY[i].mrId = aId then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(* THE ROWS A MENU ITEM MAY BIND EVEN THOUGH acInstall IS FALSE -- NAMED, ONE
  BY ONE, WITH THE REASON EACH IS HERE.

  acInstall False means the INPUT HOOK does not install the keystroke. For two
  of the four such rows that is not because somebody else answers the key:

    10320  Alt+-   Toggle autosend. NOTHING binds it, anywhere. The accelerator
                   survived only in the ger and ukr .RES files, so the English
                   menu has advertised a dead key for years
                   (docs\ACCELERATOR_AUDIT.md). Giving the item the shortcut is
                   what makes the advertised key start working, and closes that
                   defect (NY4I, 2026-09-26, who was shown the consequence and
                   accepted it).

    10337  Alt+X   Exit program. 10002 menu_exit already owns Alt+X as a real
                   menu shortcut, and both arms run the SAME ExitProgram(True)
                   (MainUnit.pas:5004 and :5544). TMenu.FindItem returns the
                   first match (menu.inc:217), so a second item carrying the
                   same TShortCut changes no behaviour -- and the LCL keeps no
                   registry of shortcuts to object to it (TMenuItem.SetShortCut
                   just repaints, menuitem.inc:1574).

  THE OTHER TWO acInstall:false ROWS MUST NOT BE ADDED HERE. 10503 PgUp and
  10504 PgDn ARE bound -- by THE ENTRY FIELD'S OWN KEY HANDLER,
  uMainWindowProc.TTR4WEntryEvents.EntryKeyDown (src\uMainWindowProc.pas:359-367)
  -- so a menu shortcut would give those keystrokes two owners and fire them
  twice. They advertise their key in the caption instead.

  IT IS NOT THE MESSAGE LOOP, whatever this note said until 2026-09-26 and
  whatever uAccelerators still said alongside it. That loop is gone: tr4w.lpr is
  585 lines and runs Application.Run. The difference is not pedantic -- the entry
  field's handler fires ONLY while a call or exchange field has focus, whereas a
  TMenuItem.ShortCut fires from any form, so giving these two a shortcut would
  WIDEN where PgUp changes CW speed (to the band map, the cluster window,
  everywhere) rather than merely move who draws the key. That is NY4I's decision
  to make and has not been made.

  A LIST, NOT A LOOSENED GUARD. Relaxing the acInstall test itself would hand
  PgUp and PgDn a second owner, and would mean that every acInstall:false row
  added in future silently gained a binding. Widening this is an edit somebody
  has to make on purpose, here, against these reasons. *)
const
   DISPLAY_ONLY_ROWS_A_MENU_ITEM_MAY_BIND: array[0..1] of word = (
      menu_alt_toogleautosend,     (* Alt+- -- nothing else binds it *)
      menu_alt_x                   (* Alt+X -- 10002 binds it, same action *)
   );

function MenuMayBindADisplayOnlyRow(const aId: word): boolean;
var
   i: integer;
begin
   Result := False;

   for i := Low(DISPLAY_ONLY_ROWS_A_MENU_ITEM_MAY_BIND)
            to High(DISPLAY_ONLY_ROWS_A_MENU_ITEM_MAY_BIND) do
      begin
      if DISPLAY_ONLY_ROWS_A_MENU_ITEM_MAY_BIND[i] = aId then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(* THE PUNCTUATION OF AN INLINE KEY, IN ONE PLACE -- both halves of it, so the
  title that strips it cannot disagree with the caption that added it. *)
const
   INLINE_KEY_OPEN  = ' (';
   INLINE_KEY_CLOSE = ')';

function CaptionWithInlineKey(const aCaption: string; const aKey: string): string;
begin
   Result := aCaption;

   if aKey = '' then
      begin
      Exit;
      end;

   Result := aCaption + INLINE_KEY_OPEN + aKey + INLINE_KEY_CLOSE;
end;

function CaptionWithoutInlineKey(const aCaption: string): string;
var
   p: integer;
   q: integer;
begin
   Result := aCaption;

   if (Length(aCaption) < 4) or (aCaption[Length(aCaption)] <> ')') then
      begin
      Exit;
      end;

   for p := Length(aCaption) - 1 downto 2 do
      begin
      if (aCaption[p] <> '(') or (aCaption[p - 1] <> ' ') then
         begin
         Continue;
         end;

      (* A KEYSTROKE HOLDS NO SPACE -- 'Ctrl+Alt+B', 'PgUp', '`'. Requiring
        that is what keeps an ordinary parenthesised caption intact. *)
      for q := p + 1 to Length(aCaption) - 1 do
         begin
         if aCaption[q] = ' ' then
            begin
            Exit;
            end;
         end;

      Result := Copy(aCaption, 1, p - 2);
      Exit;
      end;
end;

(* ONE ROW, ASKED IN ISOLATION: could a menu item carry this keystroke?

  Split out from AcceleratorRowBelongsToTheMenu so that the "is this the first
  such row for the command" test below can ask the same question of an earlier
  row without recursing. *)
function RowCouldBeAMenuShortCut(const aIndex: integer): boolean;
var
   row: TAcceleratorRow;
begin
   Result := False;
   row    := ACCELERATORS[aIndex];

   (* A DISPLAY-ONLY ROW, UNLESS IT IS ONE OF THE TWO NAMED ABOVE. acInstall
     False means the input hook does not install the key; for those two,
     nothing else does either, so the menu item may. *)
   if (not row.acInstall) and (not MenuMayBindADisplayOnlyRow(row.acId)) then
      begin
      Exit;
      end;

   { An unmodified keystroke is typing. }
   if not (row.acCtrl or row.acAlt or row.acShift) then
      begin
      Exit;
      end;

   (* THE STANDARD EDITING KEYS ARE NO LONGER EXCLUDED HERE (2026-09-26), and
     the guard that excluded them is DELETED rather than narrowed.

     It read: Ctrl and nothing else, with A, C, V or X -- Exit. Its reason was
     that a menu shortcut is answered from ANY form, so Ctrl+C on the DX cluster
     window or on a dialog's Name field would have cleared the mult sheet
     instead of copying. That reason no longer holds:
     TTR4WMainForm.IsShortcut declines a keystroke the focused control needs
     (uEditingKeys), which is the decline this guard existed to substitute for.
     So Ctrl+A (10400), Ctrl+C (10424) and Ctrl+V (10426) join the shortcut
     column and stop advertising their key inside their own caption.

     Ord('X') WAS DEAD TEXT AND IS NOT REPLACED BY ANYTHING. No row in
     ACCELERATORS binds Ctrl+X -- checked, not assumed -- so that name excluded
     nothing. Ctrl+X is still named in uEditingKeys, which is the half that
     matters: if a Ctrl+X row is ever added, the menu will take it AND the
     override will hand it to a focused field, which is the behaviour the guard
     was reaching for.

     THE UNMODIFIED-KEYSTROKE GUARD ABOVE IS UNTOUCHED, and it is the half that
     must not be widened: Tab, Esc, Ins, Pause, PgUp, PgDn and the spot key
     would each start firing from every window rather than only where they fire
     now, which is a behaviour decision and not a rendering fix. *)

   Result := MenuCommandExists(row.acId);
end;

function AcceleratorRowBelongsToTheMenu(const aIndex: integer): boolean;
var
   i: integer;
begin
   Result := False;

   if (aIndex < Low(ACCELERATORS)) or (aIndex > High(ACCELERATORS)) then
      begin
      Exit;
      end;

   if not RowCouldBeAMenuShortCut(aIndex) then
      begin
      Exit;
      end;

   (* A SECOND BINDING FOR ONE COMMAND STAYS WITH THE HOOK. TMenuItem holds one
     ShortCut, and ShortCutKey2 is not matched by TMenu.FindItem (menu.inc:217
     compares Item.ShortCut alone), so putting the second keystroke there would
     bind nothing -- and would not even be seen: every path in
     win32wsmenus.pp that reserves or paints the shortcut column is gated on
     ShortCut <> scNone (measure :472, size :584, themed :930, classic :1162),
     and ShortCutKey2 is appended only INSIDE MenuItemShortCut (:275), which
     those gates call. So ShortCutKey2 alone displays nothing at all.
     10317 menu_alt_p is the only case: Alt+P becomes the item's shortcut and
     Ctrl+Alt+W stays an accelerator, which is what each of them already was --
     only Alt+P was ever displayed. *)
   for i := Low(ACCELERATORS) to aIndex - 1 do
      begin
      if (ACCELERATORS[i].acId = ACCELERATORS[aIndex].acId) and
         RowCouldBeAMenuShortCut(i) then
         begin
         Exit;
         end;
      end;

   Result := True;
end;

function MenuShortCutFor(const aId: word): TShortCut;
var
   i:     integer;
   shift: TShiftState;
begin
   Result := scNone;

   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      if (ACCELERATORS[i].acId = aId) and AcceleratorRowBelongsToTheMenu(i) then
         begin
         shift := [];
         if ACCELERATORS[i].acCtrl then
            begin
            Include(shift, ssCtrl);
            end;
         if ACCELERATORS[i].acAlt then
            begin
            Include(shift, ssAlt);
            end;
         if ACCELERATORS[i].acShift then
            begin
            Include(shift, ssShift);
            end;

         { acKey IS a virtual-key code and TShortCut is one too, which is what
           makes this a translation of the modifiers and nothing more. }
         Result := Menus.ShortCut(ACCELERATORS[i].acKey, shift);
         Exit;
         end;
      end;
end;

function BuildTR4WMainMenu(const aOwner: TComponent;
                           const aOnClick: TNotifyEvent): TMainMenu;
var
   i:        integer;
   row:      MenuRecord;
   curr:     TMenuItem;   { where items are being added }
   latest:   TMenuItem;   { the top-level popup most recently opened }
   item:     TMenuItem;
   caption:  string;
begin
   Result     := TMainMenu.Create(aOwner);
   GMainMenu  := Result;
   GMenuIndex := nil;

   latest := Result.Items;
   curr   := Result.Items;

   for i := 0 to T_MENU_ARRAY_SIZE do
      begin
      row := T_MENU_ARRAY[i];

      (* A TOP-LEVEL POPUP. Was CreatePopupMenu + AppendMenuW(Result, MF_POPUP);
        a TMenuItem with children IS a popup, so there is nothing to create
        separately. *)
      if row.mrId = MAXWORD then
         begin
         item := TMenuItem.Create(aOwner);
         { TCaption: the LCL keeps captions as UTF-8 AnsiString, so the
           conversion is written down rather than left implicit. }
         item.Caption := TCaption(row.mrText);
         Result.Items.Add(item);
         latest := item;
         curr   := item;
         Continue;
         end;

      { A SUBMENU of the popup most recently opened. }
      if row.mrId = MAXWORD - 1 then
         begin
         item := TMenuItem.Create(aOwner);
         item.Caption := TCaption(row.mrText);
         latest.Add(item);
         curr := item;
         Continue;
         end;

      { Back out of the submenu. }
      if row.mrId = MAXWORD - 2 then
         begin
         curr := latest;
         Continue;
         end;

      item := TMenuItem.Create(aOwner);

      if (row.mrText <> '') and (row.mrText[1] = '-') then
         begin
         { A separator is a caption of '-' to the LCL, as it was MF_SEPARATOR
           to Windows. }
         item.Caption := '-';
         end
      else
         begin
         (* THE ITEM OWNS ITS KEYSTROKE.

           IT USED TO BE SPELLED INTO THE CAPTION, as AppendMenu wanted it:
           'Band Up'#9'Alt+B', with ShortCut left unset so that nothing would
           bind the key twice. That is a Win32 artifact and it does not render.
           The LCL's Win32 menus are ALWAYS owner-drawn (win32wsmenus.pp:1547,
           fType := MFT_OWNERDRAW), and the draw path puts the caption through
           DrawText with DT_EXPANDTABS (:898) -- a TAB STOP, not right
           alignment -- while the right-aligned shortcut column is drawn from
           AMenuItem.ShortCut and from nothing else (:930-942, and :1161-1172
           on the classic path). So every shortcut sat at a tab stop chosen by
           its own caption's length: NY4I, 2026-09-25, "menu accelerator
           shortcuts are usually right aligned". Cocoa and gtk2 never had a tab
           convention at all and passed the character straight to the native
           widget.

           NO CAPTION CARRIES A TAB ANY MORE (2026-09-26). The rows whose
           keystroke the menu may not own spell it in parentheses instead --
           CaptionWithInlineKey -- because a tab stop in a minority of rows is
           exactly what made the column look ragged.

           ShortCut is the property that does both jobs on all three, so the
           caption is now just the caption. Which rows the menu may own, and
           why some may not, is AcceleratorRowBelongsToTheMenu -- and the input
           hook skips exactly those, so no keystroke has two owners. *)
         caption  := row.mrText;
         item.ShortCut := MenuShortCutFor(row.mrId);

         if item.ShortCut = scNone then
            begin
            (* A KEYSTROKE THE MENU MAY NOT OWN still has to be advertised, and
              a caption is the only place left: the LCL draws its shortcut
              column from ShortCut alone, so there is no
              display-without-binding.

              IT READS AS PART OF THE LABEL, in parentheses -- "Toggle insert
              mode (Ins)". A tab stood here and looked like a column without
              being one; see CaptionWithInlineKey for why that rendered ragged
              and why the punctuation lives there rather than on this line. *)
            caption := CaptionWithInlineKey(caption,
                                            AcceleratorDisplayFor(row.mrId));
            end;

         item.Caption := TCaption(caption);
         item.Tag     := row.mrId;
         item.OnClick := aOnClick;

         SetLength(GMenuIndex, Length(GMenuIndex) + 1);
         GMenuIndex[High(GMenuIndex)].Id   := row.mrId;
         GMenuIndex[High(GMenuIndex)].Item := item;
         end;

      curr.Add(item);
      end;
end;

(* CreateTR4WMenu IS DELETED (2026-09-07). It built the menu bar with
  CreateMenu / CreatePopupMenu / AppendMenuW -- HMENU handles, straight Win32
  -- and it had NO CALLER. BuildTR4WMainMenu above replaced it with LCL
  TMenuItems, and uMainForm.pas:1769 is the only thing that builds a menu:

      Menu := BuildTR4WMainMenu(Self, MenuItemClick);

  NY4I flagged that the menus were already converted and I had reported them
  as outstanding work -- because a raw grep for AppendMenuW finds live-looking
  code and says nothing about whether anything reaches it. Searching for the
  FUNCTION NAME, not the API, is what answers that.

  Its 80 lines are in git history. Deleting them is what actually removed this
  unit's `uses Windows`. *)

end.
