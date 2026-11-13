{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
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
unit uLCLFormHelpers;
{$I ..\..\tr4w.inc}

{
  Captions and control-building helpers shared by the FMX preferences windows.

  WHY A SEPARATE UNIT.  A designed form owns a .fmx resource named for its unit,
  so one form per unit -- and TRadioEditForm and TPrefsForm used to share
  uPrefsForm.pas.  Splitting them left these helpers needed by both, and a unit
  that each of them can use is cleaner than either importing the other.

  THE CAPTIONS STAY TOGETHER, all of them, including the ones only one form
  uses.  They are here for the reason the original comment gives -- one place,
  so the i18n lift is mechanical -- and that argument gets weaker, not stronger,
  if they are scattered across the units that happen to reference them.  When
  the move to Delphi resourcestring happens they travel as one set.

  ON THE Make* HELPERS AND DESIGNED FORMS.  These build controls in code.  As
  each form converts to a designed .fmx its LAYOUT stops coming from here, but
  combo whose items depend on which COM ports are plugged in cannot be designed,
  and TagString-not-index stays a correctness rule either way.
}

interface

uses
   Classes,
   System.UITypes,
   Controls,
   StdCtrls,
   ComCtrls,   // TTreeView / TTreeNode -- see TNavNode below
   Forms,      // TCustomForm -- see ShowModalOverWin32Parent
   Graphics,   // TFont -- TextWidthInFont, WidestText, EffectiveFontHeight
   LCLType,    // HWND
   Dialogs,    // InputQuery -- see AskForText
   Grids,      // TCustomDrawGrid -- the column-width helpers (issue 234)
   uColumnWidthStore,   // TColumnWidthStore -- the same helpers
   ComPortEnumerator,   // TComPortEnumerator -- see FillSerialPortCombo
   uPortAddress,        // ComPortNumber -- the port-naming rules
  uTR4WStrings;

resourcestring
   // --- captions ------------------------------------------------------------
   // ONE place, so the i18n lift is mechanical.  See the unit header.
   //
   // AND THIS IS THAT LIFT: `resourcestring`, not `const`. As consts these 90
   // strings were in NO catalogue in ANY language -- not in src/lang, so
   // pas2po never saw them, and not in a resource string table, so rstconv
   // could not either. The TC_ prefix made them look translated. They never
   // were.
   //
   // The compiler now emits them to uLCLFormHelpers.rsj, which is what makes a
   // string extractable and replaceable at run time. The names are unchanged:
   // they have no translations yet, so a rename would cost nothing today, but
   // it would also buy nothing and every call site would have to move.
   TC_PREFS_HARDWARE         = 'Hardware';


   TC_PREFS_PROFILES         = 'Station profile';
   TC_PREFS_NEWPROFILE       = 'New...';
   TC_PREFS_RENAMEPROFILE    = 'Rename...';
   TC_PREFS_RADIO1           = 'Radio 1';
   TC_PREFS_RADIO2           = 'Radio 2';
   TC_PREFS_NONE             = '(none)';
   // Shown INSTEAD of a port list, on a platform whose enumeration is not
   // written yet -- see ComPortEnumerationSupported.  An empty drop-down would
   // read as "this machine has no serial ports", which is a different claim.
   TC_PREFS_PORTS_UNAVAILABLE = '(port list not available on this platform)';
   // Shown AFTER a port that exists but that the settings file has no spelling
   // for.  See FillSerialPortCombo.
   TC_PREFS_PORT_UNSUPPORTED = '(not selectable yet)';
   (* A PORT THE RADIO IS CONFIGURED FOR THAT IS NOT THERE RIGHT NOW -- an
     adapter unplugged, or a configuration carried from another machine. The
     editor ADDS it rather than dropping to NONE, because dropping to NONE is
     what silently cleared a good port the moment the dialog was opened. *)
   TC_PREFS_PORT_NOT_PRESENT = '(not present)';
   TC_PREFS_ACTIVELABEL      = 'Active profile: ';

   // Named for what they DO.  'OK' and 'Apply' gave no clue that they save,
   // which left "how do I save this profile?" as a fair question (NY4I).
   TC_PREFS_UNSAVED          = 'Save your changes before closing?';
   TC_PREFS_UNSAVEDTITLE     = 'TR4W Preferences';

   // Shown when an auto-info level is typed rather than left blank.  Names
   // what blank MEANS, because "leave it empty" is not obvious advice, and
   // says what the risk actually is rather than warning in the abstract.
   TC_RADIOEDIT_AUTOINFOWARN =
      'Setting an auto-info level by hand is a non-standard configuration.' + sLineBreak + sLineBreak +
      'Leave this box EMPTY unless you have a specific reason: the radio then uses the ' +
      'level TR4W knows works for it, and TR4W polls it as little as possible.' + sLineBreak + sLineBreak +
      'A value you type here overrides that, and it affects operating - entering 0 returns ' +
      'the radio to being polled for everything, which noticeably delays the change from ' +
      'transmit back to receive.' + sLineBreak + sLineBreak +
      'Use this value anyway?';

   TC_PREFS_PORTCONFLICT     = 'Port conflicts:' + sLineBreak + sLineBreak + '%s' +
                               sLineBreak + sLineBreak + 'Apply anyway?';
   TC_PREFS_APPLIED          = 'Profile "%s" is active.';
   TC_PREFS_NOPROFILE        = 'Select or create a station profile first.';
   // Said in the LIST ROW, at the moment of choosing -- not in a dialog
   // afterwards.  '%s' is the radio name, then which slot already has it.
   // The slot names it interpolates are TC_PREFS_RADIO1 / TC_PREFS_RADIO2,
   // already declared above -- reused so the drop-down and the field captions
   // can never drift into calling the same slot two different things.
   TC_PREFS_RADIOINUSE       = '%s  (in use as %s)';
   TC_PREFS_CONFIRMREMOVE    = 'Remove radio "%s"?';

   // --- UDP broadcast section -----------------------------------------------
   // The stream names AS THE OPERATOR SEES THEM.  Separate from the storage
   // spellings in uUDPBroadcastConfig ('appInfo', 'contact') on purpose: those
   // are written into settings\tr4w.json and must stay stable however the UI
   // words them, and they are the one thing that must NOT be translated.
   TC_PREFS_UDPSTREAM_CONTACT = 'Contact info';
   TC_PREFS_UDPSTREAM_RADIO   = 'Radio info';
   TC_PREFS_UDPSTREAM_SCORE   = 'Score';
   TC_PREFS_UDPSTREAM_ROTOR   = 'Rotor';
   TC_PREFS_UDPSTREAM_LOOKUP  = 'Callsign lookup';
   TC_PREFS_UDPSTREAM_APPINFO = 'App info';

   TC_PREFS_UDPNOSTREAMS      = '(nothing selected)';
   TC_PREFS_UDPCONFIRMREMOVE  = 'Remove the destination %s:%d?';
   TC_PREFS_UDPSELECTFIRST    = 'Select a destination to test.';
   // SENT, never "reached": UDP gives no delivery confirmation, and a message
   // that implies one sends the operator to debug the wrong end.
   TC_PREFS_UDPTESTSENT       = 'Test packet sent to %s:%d.' + sLineBreak +
                                'UDP cannot confirm it arrived -- check the ' +
                                'receiving program.';
   TC_PREFS_UDPDUPLICATE      = '%s:%d is already in the list.' + sLineBreak +
                                'Add the extra kinds of data to that ' +
                                'destination instead of listing it twice.';

   // --- radio editor --------------------------------------------------------
   TC_RADIOEDIT_DISCOVER     = 'Discover';
   TC_RADIOEDIT_SEARCHING    = 'Searching...';
   TC_RADIOEDIT_NONEFOUND    = 'No radios answered.';
   TC_RADIOEDIT_BADCIV       = 'The CI-V address must be a hex value, e.g. 88 or $88.';
   // Shown greyed INSIDE an empty field, so "blank" reads as "using this"
   // rather than as "you forgot something".
   TC_RADIOEDIT_DEFAULTHINT  = '%s (default)';
   TC_RADIOEDIT_NAMEREQUIRED = 'The radio needs a name.';
   TC_RADIOEDIT_TYPEREQUIRED = 'Choose a radio type.';

const
   // --- layout metrics ------------------------------------------------------
   // Shared while these forms are built in code.  A form that converts to a
   // designed .lfm stops needing them -- position and size become properties
   // in the resource -- so this block should shrink to nothing over time.
   //
   // `const` DELIBERATELY, and this is why the block is split: these are
   // numbers, and resourcestring takes strings only. They are also not
   // user-facing, so there is nothing here to translate.
   ROWHEIGHT  = 30;
   LEFTMARGIN = 12;
   // A TGroupBox draws its caption INSIDE the top of the frame, so content
   // placed at y=8 is drawn underneath the caption text.  Every row inside a
   // group starts below this instead.
   GROUPTOP   = 26;
   // A TTabSheet's children sit inside the tab's own content area, so they need
   // only a small margin -- the tab strip is not part of it.
   TABTOP     = 12;
   // What the tab strip itself takes out of the control's height.
   TABSTRIP   = 36;

procedure AddComboItem(const aCombo: TComboBox; const aText, aTag: string);

{ The same tag mechanism for a TListBox.  uPrefsForm keeps five of them --
  radios, keyers, clusters, rotators and UDP destinations -- and each row
  carries the NAME of the thing it stands for so a rebuild cannot renumber the
  operator's selection out from under them. }
{ A tree node that carries a Tag.

  FMX's TTreeViewItem is a TComponent and inherits the published Tag that
  Preferences dispatches on.  An LCL TTreeNode is a TPersistent -- it has no
  Tag at all, only an untyped Data: Pointer.  Storing an integer in Data is the
  old VCL habit and it is pointer punning; this is the LCL's own answer, hooked
  through TTreeView.OnCreateNodeClass so EVERY node the tree makes -- including
  ones the widgetset creates behind your back -- is a TNavNode.  That is what
  makes the cast in NavTagOf safe rather than hopeful.

  The tag stays an integer with the designer's original numbering.  See
  Lint-FormTags for why it must not be renumbered. }
type
   TNavNode = class(TTreeNode)
   public
      Tag: integer;
   end;

{ Ask the operator for one line of text.

  This exists for a boundary, not for convenience.  TR4W's units are compiled
  with the UnicodeStrings modeswitch, so `string` here is UnicodeString; the
  LCL is built without it, so `string` there is AnsiString.  A VAR parameter
  has to match EXACTLY -- no implicit conversion is allowed through one -- so
  calling Dialogs.InputQuery directly does not compile, and the error it gives
  ("expected Array Of AnsiString") points at an overload that has nothing to do
  with the problem.  Marshalling it once here keeps that puzzle in one place.

  The conversions themselves are safe: the LCL sets the default codepage to
  UTF-8 at startup, so UnicodeString <-> AnsiString round-trips losslessly for
  the non-Latin languages TR4W ships. }
{ SHOW AN LCL MODAL OVER A RAW WIN32 PARENT, disabling it the way the Win32
  dialog manager did.

  DialogBoxIndirectParam disables its owner window for the life of the dialog.
  TCustomForm.ShowModal does NOT do the equivalent: it calls Screen.DisableForms,
  which walks Screen.CustomForms -- LCL FORMS ONLY -- plus the widgetset's
  AppHandle (screen.inc:418-428). A raw Win32 window is never touched.

  That is invisible until a converted dialog is opened FROM one. TR4W has three
  such parents today -- the legacy Settings dialog (settingswindowhandle, the
  parent of the input query), and QTCRWindow / QTCSWindow (parents of the send-
  keyboard-CW box). Convert those dialogs without this and the parent stays
  clickable underneath a modal, which is a re-entrancy hazard rather than a
  cosmetic one: the operator can start a second edit in the window that owns the
  first.

  The main window needs no special handling -- it IS an LCL form since Phase 3a,
  so DisableForms already covers it. This is only for the Win32 remnants, and it
  becomes a no-op as they convert.

  aParent = 0, or an already-disabled parent, is handled: nothing is disabled and
  nothing is re-enabled, so this never enables a window that was disabled for
  some other reason. }
function ShowModalOverWin32Parent(const aForm: TCustomForm): integer;

{ MAKE THE TR4W MAIN WINDOW A MODAL DIALOG'S OWNER, AND CENTRE OVER IT.

  BOTH ARE THE SAME DEFECT, and it is a nil Application.MainForm.
  CreateTR4WMainForm builds the main window itself, and Application.CreateForm
  -- the thing that assigns Application.MainForm -- is never called. Two
  consequences nothing warns about:

  1. OWNERSHIP. An LCL form is owned by the hidden Application window, not by
     TR4W's main window. The taskbar button belongs to the main form
     (ShowInTaskBar := stAlways), so clicking it raises the MAIN window, and
     Windows has no reason to keep a dialog above a window that does not own it
     -- a modal dialog ends up behind its own application, and the operator has
     to hunt for it (NY4I, 2026-08-21). PopupParent is the LCL's supported way
     to set GWL_HWNDPARENT; setting it by hand does not survive a handle
     recreation.

     MODAL DIALOGS ONLY, since issue #1 (2026-10-29). An owned window is kept
     above its owner by Windows, always: a tool window owned by the main window
     could never be covered by it, so clicking the main window did not bring it
     forward. Non-modal tool windows call LeaveFormUnowned instead. A modal
     keeps this owner -- it must never fall behind the window it blocks
     (b076fbbb). ShowModalOverWin32Parent applies it to every modal.

  2. CENTRING. Every converted dialog says Position = poMainFormCenter, and
     customform.inc:1265 silently degrades that to poScreenCenter when
     Application.MainForm is nil. So "centre on the main window" has never once
     centred on the main window. Centring explicitly is the honest fix; setting
     Application.MainForm would fix both at a stroke but the LCL treats the main
     form closing as application shutdown, which is not a thing to change under
     a hand-rolled message loop without a bench run.

  Call OWN before showing. CENTRE is separate because a form that resizes itself
  in OnShow -- the band plan measures its columns there -- must centre AFTER
  that, and only when it has not restored a saved position. }
{ SHOW A TOOL WINDOW WITHOUT TAKING THE CARET.

  TCustomForm.Show brings the form to the front and makes it active, which
  is right for a window the operator just asked for and WRONG for one that
  opens on a background event.  The panadapter opens when the radio spectrum
  link comes up -- seconds after start-up -- and took the foreground with it,
  leaving the operator typing into a palette combo box (measured 2026-08-28:
  activeform=frmPanadapter_1, activecontrol=cboPalette).

  Restoring activation afterwards, rather than showing with SW_SHOWNOACTIVATE,
  keeps this HWND-free.  IT DOES MOVE THE Z-ORDER: tool windows are not owned
  by the main window since issue #1 (see LeaveFormUnowned), so bringing the
  previous form back to the front puts it above the window just shown wherever
  the two overlap.  An unowned tool window has no taskbar button and no
  Alt-Tab entry, so one opened wholly behind the main window is reached only
  by moving the main window or through TR4W's own window list. }
procedure ShowWithoutTakingFocus(const aForm: TCustomForm);

procedure OwnFormByMainWindow(const aForm: TCustomForm);
procedure CentreOverMainWindow(const aForm: TCustomForm);

(* A NON-MODAL TOOL WINDOW HAS NO OWNER FORM -- issue #1 (2026-10-29).

  Windows keeps an owned window above its owner at all times. While the tool
  windows were owned by the main window (OwnFormByMainWindow), clicking the
  main window activated it and left every overlapping tool window on top of
  it, which is not how a desktop application behaves. Unowned, each window
  rises when clicked.

  THIS IS THE LCL DEFAULT, so on a freshly created form it changes nothing. It
  exists so the decision is stated at each call site, in one named place,
  rather than read off the absence of an OwnFormByMainWindow call -- and so a
  form that was owned earlier is released. Idempotent; singletons call it on
  every show.

  With PopupMode pmNone a non-modal form's real owner is the hidden
  Application window (win32wsforms.pp, CreateHandle, stDefault with
  MainFormOnTaskBar False). That window is never shown, because TR4W has no
  Application.MainForm, so a tool window gets NO taskbar button of its own and
  ShowInTaskBar needs no setting. gtk2 is different: there stDefault gives
  every form a taskbar entry already, owned or not.

  SWITCHING BACK FROM ANOTHER PROGRAM (2026-11-01). The LCL still gives every
  such form the hidden Application window as its Win32 owner, so Windows
  raises the tool windows as ONE GROUP when any of them is clicked -- and the
  main window, which is unowned (stAlways), is not in that group and was left
  behind them (NY4I, bench). uMainForm.TActivationRaiser now answers
  Application.OnActivate by raising every TR4W window, the main one last. (The
  old note here said the reverse -- that coming back raised only the main
  window -- which is why ownership had been added to Preferences and Log
  Search in 2026-08.)

  MODALS MUST NOT CALL THIS. They keep OwnFormByMainWindow, through
  ShowModalOverWin32Parent. *)
procedure LeaveFormUnowned(const aForm: TCustomForm);

(* WHERE A FORM WAS LAST TIME.

  EXTRACTED FROM uPanadapterForm ON 2026-09-04, when the Search window needed
  the same thing -- NY4I: "the position of the search window should be saved
  (as all window positions should be saved) and restored upon reopening."

  Copying it would have copied three separately-earned corrections, and copies
  drift:

    * THE LCL'S OWN UNITS, never GetWindowRect. Mixing the two is what made the
      function-key window grow by its frame height on every restart
      (2026-08-25).
    * Position := poDesigned BEFORE SetBounds, or the LCL re-applies its own
      placement rule when the form is shown and throws the restored position
      away.
    * SetLayout onto an EMPTY store. SaveWindowLayout re-reads the file and
      overlays, so every other window's row survives without this one having to
      know they exist.

  A rect saved on a monitor that is no longer attached is well formed and puts
  the window where nobody can reach it, so a restore that does not overlap the
  desktop at all is declined and the caller keeps its own default. *)
procedure SaveFormBounds(const aForm: TCustomForm; const aName: string;
                         const aVisible: boolean);
function TryRestoreFormBounds(const aForm: TCustomForm;
                              const aName: string): boolean;

(* THE COLUMN WIDTHS AN OPERATOR DRAGGED (issue 234), beside the bounds for
  the same reason: one place that knows how a grid's layout is kept.

  A grid is named by its owner (aName) and each column by a TOKEN (aTokens,
  indexed by grid column; '' means "not kept" -- a fill column, a hidden
  column). Never by index or caption -- see uColumnWidthStore.

  THE CADENCE. A drag MARKS the width (SaveGridColumnWidth, or NoteColumnWidth
  for a grid that keeps its own list); nothing is written then. The marks reach
  settings\tr4w.json through FlushColumnWidths, which runs on a window's close,
  at exit and on the 5-second layout autosave (MainUnit.SaveTR4WPOSFILE). A
  restore reads the file AND the unwritten marks, so a window reopened inside
  those five seconds still gets the width just dragged.

  RESTORED WIDTHS ARE CLAMPED to the header text and to the column's minimum
  (ClampRestoredWidth), and stored at 96 dpi through the LCL's ScaleFormTo96 /
  Scale96ToForm. A token list shorter or longer than the grid is harmless:
  only columns both have are touched.

  Main thread only, like every control they touch. *)
function RestoreGridColumnWidths(const aGrid: TCustomDrawGrid; const aName: string;
                                 const aTokens: array of string): integer;
procedure SaveGridColumnWidth(const aGrid: TCustomDrawGrid; const aName: string;
                              const aTokens: array of string; const aCol: integer);

(* The two halves above against a store the caller holds, with no file --
  what the two above are built on, and what a test drives. *)
function ApplyGridColumnWidths(const aGrid: TCustomDrawGrid; const aName: string;
                               const aTokens: array of string;
                               const aStore: TColumnWidthStore): integer;
procedure CaptureGridColumnWidth(const aGrid: TCustomDrawGrid; const aName: string;
                                 const aTokens: array of string; const aCol: integer;
                                 const aStore: TColumnWidthStore);

(* ONE COLUMN TAKES THE GRID'S SLACK, so the row always ends at the grid's
  right edge (the External logger grid, issue 226; the Colours grid, issue 234).

  The LCL's AutoFillColumns gives the client width left after the fixed-size
  columns to every column whose SizePriority is not 0, in EQUAL shares --
  priority is not a weight. So aFillCol (a GRID column index) gets priority 1
  and every other column 0, a hidden zero-width one above all, or it would take
  a share and show. Below aMinSize the fill column stops shrinking, and with
  AutoFillColumns on the grid shows no horizontal scrollbar, so the row is
  clipped instead. AutoFillColumns is set LAST, because turning it on runs the
  fill.

  NEEDS A Columns COLLECTION: without one the LCL treats every column as
  priority 1. A fill column has no width of its own, so it carries no token in
  the caller's RestoreGridColumnWidths / SaveGridColumnWidth list.

  IT ALSO SETS ScrollBars := ssVertical, A PERMANENT VERTICAL BAR, and a caller
  must not set another value after it. An AUTOMATIC vertical bar cannot be
  combined with AutoFillColumns (issue 234 CI follow-up): TCustomGrid.
  UpdateCachedSizes runs the fill against the CURRENT ClientWidth, and only
  after it does CalcScrollbarsRange decide whether the bar shows; showing or hiding it
  changes ClientWidth by the bar's width, and TCustomGrid.WMSize ignores the
  resize while gfUpdatingScrollbar is set (the LCL's issue #31715), so nothing
  fills again. The row then ends one bar-width short of the edge, or one past
  it, whenever the row count crosses what the grid's height holds -- and
  whether a later layout pass happens to heal it is a matter of message timing,
  which is why the unit tests passed on one machine and failed on the CI
  runner. With the bar permanent, ClientWidth never depends on the row count.
  TLogGrid made the same choice (uLogGrid, its constructor). *)
procedure FillGridFromColumn(const aGrid: TCustomDrawGrid; const aFillCol: integer;
                             const aMinSize: integer);

(* For a grid that keeps its own width list (TLogGrid): mark one width, and
  read every saved width -- the file overlaid by the unwritten marks -- into
  aStore. *)
procedure NoteColumnWidth(const aName, aToken: string; const aWidth96: integer);
procedure LoadSavedColumnWidths(const aStore: TColumnWidthStore);

(* A width between this control's pixels and 96 dpi, by the LCL's own scaling.
  A control with no parent form is taken as 96 dpi (the LCL's scaling raises
  there). *)
function ColumnWidthTo96(const aControl: TControl; const aWidth: integer): integer;
function ColumnWidthFrom96(const aControl: TControl; const aWidth96: integer): integer;

(* Whether a drag has been marked and not yet written; and the write. *)
function ColumnWidthsPending: boolean;
procedure FlushColumnWidths;

(* The unwritten marks themselves, for a test to read or clear. *)
function PendingColumnWidths: TColumnWidthStore;

function AskForText(const aCaption, aPrompt: string; var aValue: string): boolean;

// Install the node class on a tree. Call BEFORE adding any node.
procedure UseNavNodes(const aTree: TTreeView);
function  NavTagOf(const aNode: TTreeNode): integer;

(* SELECT ONE ROW OF A LIST VIEW, IN ITS WINDOW, AND SCROLL IT INTO VIEW.
  The one way TR4W selects a TListView row (Alt-P, Stations). A row outside
  the list changes nothing. Why it is not a plain ItemIndex write: see the
  implementation. *)
procedure SelectListViewRow(const aView: TCustomListView; const aRow: integer);

procedure AddListItem(const aList: TListBox; const aText, aTag: string);
procedure ClearListItems(const aList: TListBox);
// A TAGGED CONTROL'S Items.Objects[] BELONGS TO THESE HELPERS: they test each
// slot with `is`, so a control read by SelectedTag / SelectByTag / HasTag /
// SelectedListTag must never be filled with AddObject or Items.Assign.
//
// Clears a tagged COMBO and frees its rows' tags. Each row carries its tag in
// its own Objects[] slot (issue 216), so a raw aCombo.Clear cannot hand out a
// stale tag -- but it leaves the tags owned by the combo until the next clear
// through here. See the implementation.
procedure ClearComboItems(const aCombo: TComboBox);
function  SelectedListTag(const aList: TListBox): string;
procedure SetListItemText(const aList: TListBox; const aIndex: integer;
                          const aText: string);
procedure SelectByTag(const aCombo: TComboBox; const aTag: string);
// Is this tag already in the list?  Lets a caller add a fallback entry for a
// stored value that no longer matches anything on offer, rather than silently
// dropping the operator's setting.
function HasTag(const aCombo: TComboBox; const aTag: string): boolean;
function SelectedTag(const aCombo: TComboBox): string;
// OWNER AND PARENT ARE SEPARATE ARGUMENTS, and they are not the same thing.
// These helpers used to take one object and use it for both, which is fine
// while a form is built in code and fatal the moment it is streamed: a .fmx
// contains the form and the components the FORM OWNS, so a control owned by the
// TTabSheet it sits on is simply absent from the resource.  Own everything from
// the form; parent it wherever the layout wants it.
//
// aName is what the streamer keys on -- an unnamed control cannot be written to
// a .fmx or addressed in the designer.  '' is accepted for forms not yet being
// converted.
function MakeLabel(const aOwner: TComponent; const aParent: TWinControl;
                   const aName, aText: string;
                   const aX, aY, aWidth: integer): TLabel;
function MakeRadio(const aOwner: TComponent; const aParent: TWinControl;
                   const aName, aText, aGroup: string;
                   const aX, aY, aWidth: integer): TRadioButton;
function MakeButton(const aOwner: TComponent; const aParent: TWinControl;
                    const aName, aText: string;
                    const aX, aY, aWidth: integer;
                    const aOnClick: TNotifyEvent;
                    const aAnchors: TAnchors = [akLeft,
                                                akTop]): TButton;
{ A TStopwatch with just the two members TR4W uses.

  System.Diagnostics is Delphi-only, and uPrefsForm times its startup phases
  with TStopwatch.StartNew / .ElapsedMilliseconds -- eight call sites, all of
  them logging.  A compatible record keeps every one of them unchanged, which is
  worth more here than reaching for a general timer: the only requirement is
  millisecond resolution over a window of a few hundred ms.

  GetTickCount64, not GetTickCount: the 32-bit one wraps after 49.7 days, and
  TR4W is a program people leave running for a whole contest weekend and longer. }
type
   TStopwatch = record
   private
      FStart: QWord;
   public
      class function StartNew: TStopwatch; static;
      function ElapsedMilliseconds: Int64;
   end;

function ComNameToPortValue(const aComName: string): string;
procedure FillSerialPortCombo(const aCombo: TComboBox;
                              const aEnumerator: TComPortEnumerator);
function IsIcomRadio(const aRegistryId: string): boolean;
// The role each serial control line performs, spelled EXACTLY as
// tr4w_RTSDTRTypeSA does (logradio.pas:100).  The vocabulary is reproduced here
// rather than reached for, because pulling LOGRADIO into a designed FMX form
// would drag the legacy radio unit into the UI -- but the SPELLING must match
// character for character: the store holds these strings and CheckCommand
// parses them back.  One wrong word ('NONE' for 'TCP/IP') cost a bench session
// on the radio track.
//
// This is why the keyer port needs TWO controls rather than a DTR/RTS choice:
// each line is assigned a JOB, so one can key CW while the other drives PTT --
// which is what the original TR4W radio dialog offered.
procedure FillRTSDTRCombo(const aCombo: TComboBox; const aSelected: string);
// Stop bits for a keying port: 1 or 2, plus a '(default)' entry that stores 0.
// Zero means "not stated", so the apply layer leaves the registry/model default
// in force rather than the dialog silently pinning a value the operator never
// chose -- the same convention BaudRate and ReceiverAddress already use.
procedure FillStopBitsCombo(const aCombo: TComboBox; const aSelected: integer);


{ A FORM MAY NOT BE SHRUNK PAST ITS OWN CONTENT.

  Sets Constraints.MinWidth / MinHeight from what the form actually holds: the
  SLACK is the unused space to the right of, and below, the furthest control,
  and the form may give up precisely that much and no more.

  DERIVED, NOT TYPED, which is the whole point. The obvious alternative is to
  put numbers in the .lfm, and that requires knowing whether a form's Width and
  Height include its caption and borders -- being wrong there is off by exactly
  one control, which reads as a rounding error rather than a mistake. Asking the
  form for both terms AT THE SAME MOMENT makes the frame size cancel, so it
  never has to be known. It is also self-maintaining: move or add a control and
  the minimum follows.

  Generalised from TfrmNewContest.ApplyMinimumSize (NY4I, 2026-08-31), where a
  typed MinHeight of 460 against a designed 524 clipped CATEGORY-POWER and
  CATEGORY-TRANSMITTER with nothing on screen to say so.

  EVERY VISIBLE CONTROL COUNTS, EACH ACCORDING TO HOW IT IS ANCHORED. The first
  version counted only top-left-anchored controls and SKIPPED anything anchored
  right or bottom, on the reasoning that such a control travels with the edge so
  its position at this instant says nothing about the minimum. True as far as it
  goes, and IT FAILED OPEN: on a form where EVERY control is anchored to an edge
  -- which is what a resizable window looks like -- there was nothing left to
  measure, the routine took its "say nothing rather than guess" exit, and the
  form got NO minimum at all. Alt-P called this and could still be dragged down
  to a title bar (NY4I, 2026-08-31).

  So each axis is answered by how the control behaves ON THAT AXIS. A control
  anchored to ONE edge moves, and needs its own size plus the margin it keeps. A
  control anchored to BOTH stretches, and needs its two margins plus a floor for
  what is left in the middle -- Constraints.MinWidth/MinHeight when the control
  states one, and a small documented default when it does not. A hidden control
  is not content.

  Call it once the form is laid out -- OnShow, or after any code that builds
  rows -- and call it again if the layout changes. }
procedure ApplyContentMinimumSize(const aForm: TForm);


{ CONTENT THAT GROWS WITH ITS WINDOW.

  The operator decides how big the data is: drag the window larger and the
  controls and their fonts grow with it, the way the DX cluster console already
  rescales its font on resize (NY4I, 2026-08-31).

  TWO CALLS, because a scaler cannot ask a scaled form what its design size was.
  CaptureDesignLayout records every control's bounds and font ONCE, before any
  scaling; ApplyLayoutScale then always works from those originals. Scaling from
  the CURRENT bounds instead would compound rounding on every drag tick and walk
  the layout away from itself.

  THE TWO AXES SCALE INDEPENDENTLY, so the content FILLS the window rather than
  keeping its designed proportions. Taking the smaller of the two was the first
  attempt and it is wrong for this: drag a window tall and narrow and the content
  scales to the width, leaving the bottom empty (NY4I, 2026-08-31). Width and
  height are separate questions and get separate answers.

  THE FONT TAKES THE SMALLER of the two, though, and that is not an
  inconsistency. Text has one size, and sizing it to the taller axis in a narrow
  window overflows the control it sits in. Growing rows with slightly smaller
  text is legible; text spilling out of its panel is not.

  Percent throughout, to keep the arithmetic integral -- the same reason the
  console computes a font SIZE rather than a ratio.

  THE FLOOR IS A CLAMP; THE CEILING IS OPTIONAL AND OFF BY DEFAULT. Below the
  floor text stops being readable and then stops being hit-testable. A ceiling
  was tried at 400% and it is the wrong idea: the content simply stopped growing
  part-way across a wide window and left the rest empty, which is the complaint
  the scaling exists to answer (NY4I, 2026-08-31). If the operator makes the
  window enormous they have said what they want. Pass aMaxPercent > 0 only for a
  form that genuinely has an upper bound.

  A form that must not shrink past its content should also call
  ApplyContentMinimumSize, which is the other half of this. }

type
   TDesignBounds = record
      Ctl                        : TControl;
      Left, Top, Width, Height   : integer;
      FontHeight                 : integer;
   end;
   TDesignLayout = array of TDesignBounds;

procedure CaptureDesignLayout(const aForm: TForm; out aLayout: TDesignLayout;
                              out aDesignW, aDesignH: integer);
procedure ApplyLayoutScale(const aForm: TForm; const aLayout: TDesignLayout;
                           const aDesignW, aDesignH: integer;
                           const aMinPercent: integer = 100;
                           const aMaxPercent: integer = 0);

function TryParseHexByte(const aText: string; out aValue: integer): boolean;

(* HOW WIDE A TEXT IS, IN PIXELS, IN aFont -- and the widest of several.

  LIFTED FROM uNewContestForm (2026-11-06), where WidestText measured the
  contest list and the file grid, when the Edit QSO layout became a third
  caller; GridColumnFloor below was a second, inline copy of the same
  measurement and is repointed too.

  A TBitmap canvas, not a control's: it needs no window handle and no parent,
  so it answers before a form is shown, and nothing the form last painted with
  can leak into it. The text is measured as written -- an accelerator '&'
  counts as a glyph, which over-estimates by one character and never under. *)
const
   (* THE ROOM A DROP-DOWN'S OWN CHROME TAKES BESIDE ITS TEXT, at 96 dpi: the
     frame, the text inset and the arrow (Windows) or the bezel and the
     up/down arrows (a cocoa NSPopUpButton). A STATED ALLOWANCE, NOT A
     MEASUREMENT: the LCL cannot report it -- Win32 gives a combo no preferred
     width at all, and cocoa's fittingSize is computed from the title showing
     at that moment. 40 is generous on Windows (a 17 px button and a 3 px
     frame each side) and is the number to correct if the Mac bench shows the
     text still under the arrows. The layout tests assert against this same
     constant. Lifted from uEditQSOForm (issue 232). *)
   DROPDOWN_CHROME_96 = 40;

function TextWidthInFont(const aFont: TFont; const aText: TCaption): integer;
function WidestText(const aFont: TFont; const aTexts: TStrings): integer;
(* The height of one line of aText in aFont, by the same bitmap canvas. *)
function TextHeightInFont(const aFont: TFont; const aText: TCaption): integer;
(* THE HEIGHT OF aText WRAPPED AT WORD BREAKS TO aWidth, in aFont: whole lines
  times one line's height, by the same bitmap canvas -- so it answers before
  a form is shown, which a word-wrapped label's own preferred size cannot
  (ControlPreferredSize below). Spaces are the only break, as a label's word
  wrap breaks; a word wider than aWidth has a line to itself. Issue 304: the
  generated Preferences rows are laid out at construction, long before any
  handle exists. *)
function WrappedTextHeight(const aFont: TFont; const aText: TCaption;
                           const aWidth: integer): integer;

(* WHAT THE WIDGET SET SAYS A CONTROL WOULD LIKE TO BE, without constraints.
  0 means "no opinion" -- an edit, a Win32 combo, or a label whose parent has
  no handle yet (customlabel.inc answers nothing then).

  LIFTED FROM uEditQSOForm (2026-11-06, issue 232) when the External logger
  editor became its second caller. *)
procedure ControlPreferredSize(const aControl: TControl; out aWidth, aHeight: integer);

(* THE INPUT A CAPTION NAMES: the FocusControl of a TLabel or a TStaticText,
  nil for any other control (or a caption that names nothing).

  TWO CLASSES, because they are two kinds of caption (issue 278). A TLabel is
  painted by its parent and has no window, so Windows UI Automation cannot see
  it and the input beside it reads as unnamed. A TStaticText IS a window (a
  Win32 STATIC), and UIA names an input from the static immediately before it
  in z-order. A form that wants its inputs named on Windows uses TStaticText;
  everything that pairs a caption with its input asks this, so it does not
  care which. *)
function CaptionFocusControl(const aCaption: TControl): TWinControl;

implementation

uses
   uMainForm,  // TR4WMainForm -- the owner every dialog should have had
   Types,      // TRect
   uWindowLayoutStore,  // the bounds, keyed by name
   uTR4WConfigFile,     // TR4WConfigFileName, Load/SaveWindowLayout
   SysUtils,
   StrUtils,
   MainUnit,   // logger -- the minimum-size report
   Log4D,
   uRadioConfigStore,
   uRadioRegistry,
   VC;

procedure ShowWithoutTakingFocus(const aForm: TCustomForm);
var
   prevForm: TCustomForm;
   prevCtl:  TWinControl;
begin
   if aForm = nil then
      begin
      Exit;
      end;

   prevForm := Screen.ActiveForm;
   prevCtl  := Screen.ActiveControl;

   aForm.Show;

   { Nothing to hand back to -- and never to the form just shown, which is
     what Show already did. }
   if (prevForm = nil) or (prevForm = aForm) or (not prevForm.IsVisible) then
      begin
      Exit;
      end;

   prevForm.BringToFront;
   if (prevCtl <> nil) and prevCtl.CanFocus then
      begin
      prevCtl.SetFocus;
      end;
end;

procedure OwnFormByMainWindow(const aForm: TCustomForm);
begin
   if (aForm = nil) or (TR4WMainForm = nil) then
      begin
      Exit;
      end;

   // pmExplicit already set means a caller has nominated a different owner --
   // a dialog opened from another dialog, say. Its choice wins.
   if aForm.PopupMode = pmExplicit then
      begin
      Exit;
      end;

   aForm.PopupParent := TR4WMainForm;
   aForm.PopupMode   := pmExplicit;
end;

procedure LeaveFormUnowned(const aForm: TCustomForm);
begin
   if aForm = nil then
      begin
      Exit;
      end;

   // Both, in this order: clearing PopupParent leaves the mode alone, and
   // pmNone is what stops GetRealPopupParent nominating any owner form.
   aForm.PopupParent := nil;
   // Forms.pmNone, not pmNone: ComPortEnumerator's TPortMatchKind also has a
   // member of that name, and a unit later in the uses clause wins.
   aForm.PopupMode   := Forms.pmNone;
end;

procedure CentreOverMainWindow(const aForm: TCustomForm);
var
   owner: TRect;
begin
   if (aForm = nil) or (TR4WMainForm = nil) then
      begin
      Exit;
      end;

   owner := TR4WMainForm.BoundsRect;

   // poDesigned FIRST, or the LCL re-applies its own rule when the form is
   // shown and throws this away.
   aForm.Position := poDesigned;
   aForm.SetBounds(owner.Left + ((owner.Right  - owner.Left) - aForm.Width)  div 2,
                   owner.Top  + ((owner.Bottom - owner.Top)  - aForm.Height) div 2,
                   aForm.Width, aForm.Height);
end;
function ShowModalOverWin32Parent(const aForm: TCustomForm): integer;
begin
   // EVERY MODAL COMES THROUGH HERE, which is why ownership is applied here
   // and not in sixteen ShowBlah routines. See OwnFormByMainWindow.
   OwnFormByMainWindow(aForm);
   if aForm.Position = poMainFormCenter then
      begin
      CentreOverMainWindow(aForm);
      end;

   (* THE MANUAL DISABLE IS GONE (2026-09-06), AND IT IS GONE BY ENUMERATION.

     It disabled aParent for the life of the modal, because Screen.DisableForms
     walks CustomForms -- LCL forms only -- and Telnet and MMTTY were raw Win32
     dialogs the LCL did not know about. Both became forms on 2026-08-26, and
     the comment here always said the branch would self-delete when they did.

     It was also actively harmful while it ran. Disabling a window that HAS
     focus makes Windows drop that focus at once; TCustomForm.ShowModal then
     records what to restore (customform.inc:3013) and finds nothing, so its
     RestoreFocusState puts nothing back. NY4I, 2026-08-25: after entering a
     split frequency the main window lost focus and the call field had to be
     clicked before '-' worked again.

     PROVED, not argued from the conversion. Every aParent any caller passes,
     traced to where the value comes from:

       ShowSendKeyboardCW   MainUnit:4901        tr4whandle
       ShowInputQuery       LOGWIND:1733         tr4whandle
       ShowEditMessage      uAltP:367            TR4WAltPForm.Handle
       ShowMessagesList     uEditMessageForm     Self.Handle
       OpenEditQSOWindow    MainUnit:7087        tr4whandle
       OpenEditQSOWindow    uLogEditForm:308     Self.Handle
       OpenEditQSOWindow    uLogSearchForm:768   Self.Handle
       ShowBandPlan         uPrefsForm:3373      0
       the other fourteen                        0

     tr4whandle is the main FORM's handle. Controls.FindControl answers for
     every one, so the guard was always False. aParent had no other use -- the
     centring below is CentreOverMainWindow's -- so the parameter goes too.

     THE NAME IS KEPT ON PURPOSE. It appears in about thirty comments across
     the form units, most of them explaining why a window does NOT disable its
     parent by hand; renaming it would leave those reading as though they
     described something else. What it means now is "show this form modally,
     owned and centred by the main window". *)

   (* NO try/finally ANY MORE. It existed to re-enable aParent if an exception
     escaped ShowModal -- otherwise the operator got a frozen window with no
     dialog on it. With nothing disabled there is nothing to undo. *)
   Result := aForm.ShowModal;
end;

{ ------------------------------------------------------------- helpers ---- }

(* ---------------------------------------------------------------------------
  ITEM TAGS: THE IDENTITY IS IN THE ROW (issue 216).

  FMX gave every list item a TagString, so a combo could carry a registry id or
  a radio name alongside the text the operator reads.  The LCL's Items is a
  TStrings, whose own per-row slot is Objects[].

  The tag must stay a STRING and must never become an index.  That is not a
  preference -- index arithmetic against a list whose contents depend on what
  hardware is plugged in is how the legacy port combo grew its bugs, and these
  lists are populated at runtime from this machine's COM ports and the radio
  registry.

  UNTIL ISSUE 216 THE TAGS WERE A SECOND LIST BESIDE THE CONTROL -- a
  TStringList in a companion component -- and every defect in this area was
  the two lists disagreeing: a raw Clear (2026-08-31: a new station profile
  could not be selected), a Delete, an Insert, Sorted, design-time items.  A
  check squared them up and logged an Error after the fact.

  NOW EACH ROW CARRIES A TItemTag IN ITS OWN Objects[] SLOT, so the control
  holds its data and a desync is unrepresentable: whatever moves, sorts, deletes
  or clears a row moves, sorts, deletes or clears its tag with it, on every
  widget set (each one's Items keeps a row's object -- Win32 as the item data,
  and Put keeps it across a text change).  A row added straight to Items has
  no TItemTag and reads as '', never as a neighbour's tag.

  THE TAG IS OWNED BY THE CONTROL (a TComponent with the control as Owner), so
  the lifetime needs no teardown anywhere: destroying the control destroys its
  tags.  ClearComboItems / ClearListItems free them at once; a raw Clear only
  leaves them unreferenced until the next helper clear or the control's end --
  never matched, because nothing in Items points at them any more.

  A typed object checked with `is`, not an integer dressed as a pointer: the
  same shape as the DX console's TConsoleLineKind (pointer audit P9).
--------------------------------------------------------------------------- *)

type
   TItemTag = class(TComponent)
   private
      FTagString: string;
   public
      constructor CreateTag(const aOwner: TComponent; const aTag: string);
      property TagString: string read FTagString;
   end;

constructor TItemTag.CreateTag(const aOwner: TComponent; const aTag: string);
begin
   inherited Create(aOwner);
   FTagString := aTag;
end;

(* The tag row aIndex carries, or '' for a row that is not there or was added
  without one.  The one reader of Objects[] for a tagged control. *)
function TagOfRow(const aItems: TStrings; const aIndex: integer): string;
var
   item: TObject;
begin
   Result := '';
   if (aIndex < 0) or (aIndex >= aItems.Count) then
      begin
      Exit;
      end;
   item := aItems.Objects[aIndex];
   if item is TItemTag then
      begin
      Result := TItemTag(item).TagString;
      end;
end;

(* The first row whose tag matches, case-insensitively, or -1.  UnicodeSameText
  because both sides are UnicodeString here; SysUtils.SameText takes AnsiString
  in FPC 3.2.2 and would narrow them. *)
function RowOfTag(const aItems: TStrings; const aTag: string): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to aItems.Count - 1 do
      begin
      if (aItems.Objects[i] is TItemTag) and
         UnicodeSameText(TagOfRow(aItems, i), aTag) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

procedure AddTaggedRow(const aControl: TComponent; const aItems: TStrings;
                       const aText, aTag: string);
begin
   aItems.AddObject(aText, TItemTag.CreateTag(aControl, aTag));
end;

(* Items FIRST, then the tags: at no point does a row point at a freed tag.
  Every TItemTag the control owns goes, which also collects any a raw Clear
  left behind, so a control refilled many times never accumulates them. *)
procedure ClearTaggedRows(const aControl: TComponent; const aItems: TStrings);
var
   i: integer;
begin
   aItems.Clear;
   for i := aControl.ComponentCount - 1 downto 0 do
      begin
      if aControl.Components[i] is TItemTag then
         begin
         aControl.Components[i].Free;
         end;
      end;
end;

procedure AddComboItem(const aCombo: TComboBox; const aText, aTag: string);
begin
   AddTaggedRow(aCombo, aCombo.Items, aText, aTag);
end;

type
   // OnCreateNodeClass is an event, not a virtual, so it needs an object to
   // hang off.  One shared instance is enough -- it holds no state.
   TNavNodeFactory = class
      procedure CreateClass(Sender: TCustomTreeView; var NodeClass: TTreeNodeClass);
   end;

var
   gNavNodeFactory: TNavNodeFactory = nil;

procedure TNavNodeFactory.CreateClass(Sender: TCustomTreeView;
                                      var NodeClass: TTreeNodeClass);
begin
   NodeClass := TNavNode;
end;

function AskForText(const aCaption, aPrompt: string; var aValue: string): boolean;
var
   buf: AnsiString;
begin
   buf    := AnsiString(aValue);
   Result := InputQuery(AnsiString(aCaption), AnsiString(aPrompt), buf);
   if Result then
      begin
      aValue := string(buf);
      end;
end;

procedure UseNavNodes(const aTree: TTreeView);
begin
   if gNavNodeFactory = nil then
      begin
      gNavNodeFactory := TNavNodeFactory.Create;
      end;
   aTree.OnCreateNodeClass := gNavNodeFactory.CreateClass;
end;

function NavTagOf(const aNode: TTreeNode): integer;
begin
   // Fails CLOSED: a node the factory did not make reports "no section", which
   // shows the placeholder, rather than reading a garbage tag and opening the
   // wrong page.
   if aNode is TNavNode then
      begin
      Result := TNavNode(aNode).Tag;
      end
   else
      begin
      Result := 0;
      end;
end;

(* A TLISTVIEW SELECTION ONLY COUNTS ONCE IT IS IN THE WINDOW (Lazarus 4.8,
  lcl/include/customlistview.inc).

  With no handle, SetSelection (1773) writes only the private cache FSelected
  and leaves it unmarked (lffSelectedValid is set by the nil branch alone,
  1798). Whether that write survives the handle's creation is up to the
  widget set: InitializeWnd re-applies FSelected (617-618), and Windows and
  Cocoa keep it, but on gtk2 a selection written before the handle reads -1
  afterwards (measured on the Linux CI runner, 2026-11-07; pinned in
  uTestAltPRows). So THE HANDLE COMES FIRST. HandleNeeded is a no-op for a
  list that is showing; for one that is not, it builds the window now (and
  its parent's), so the write below goes to the widget set at once
  (SetSelection, 1802-1804) rather than waiting on InitializeWnd's re-apply.
  uTestListViewSelection asks the widget which row is selected, both for a
  list that is showing (the order Alt-P and Stations use) and for one whose
  rows were added before its window; the Linux CI run is what proves the
  second on gtk2.

  NIL, THEN THE ROW -- the LCL's own idiom (TListItem.EditCaption,
  listitem.inc 375-376). SetSelection exits early when FSelected already
  equals the row (1779), so a cache left pointing at it by any earlier write
  would make a plain assignment a silent no-op while the window shows no
  selection. The nil step resets the cache and marks it valid, and the row
  is then written to the window. The cost: the list raises its change and
  select events twice (a deselect, then the select). Neither Alt-P nor
  Stations handles OnSelectItem or OnChange; a list that does must expect
  the pair. *)
procedure SelectListViewRow(const aView: TCustomListView; const aRow: integer);
var
   row: TListItem;
begin
   if (aView = nil)               or
      (aRow < 0)                  or
      (aRow >= aView.Items.Count) then
      begin
      Exit;
      end;

   (* A list on no form has no window to build and none to show; it keeps
     the cache write, which is all such a list can have. *)
   if GetParentForm(aView) <> nil then
      begin
      aView.HandleNeeded;
      end;
   row := aView.Items[aRow];
   aView.Selected := nil;
   aView.Selected := row;
   row.MakeVisible(False);
end;

procedure AddListItem(const aList: TListBox; const aText, aTag: string);
begin
   AddTaggedRow(aList, aList.Items, aText, aTag);
end;

procedure ClearListItems(const aList: TListBox);
begin
   ClearTaggedRows(aList, aList.Items);
end;

(* Since issue 216 a raw TComboBox.Clear can no longer hand out a stale tag --
  the tags go with the rows -- but it leaves the cleared rows' TItemTags owned
  by the combo until the next ClearComboItems.  So everything that empties a
  tagged combo still comes through here. *)
procedure ClearComboItems(const aCombo: TComboBox);
begin
   ClearTaggedRows(aCombo, aCombo.Items);
end;

function SelectedListTag(const aList: TListBox): string;
begin
   Result := TagOfRow(aList.Items, aList.ItemIndex);
end;

// Rewrite one row's text WITHOUT rebuilding the list.  The FMX code was
// explicit that assigning to Items fires a rebuild and loses the selection;
// the LCL behaves the same way, so the row is edited in place.
procedure SetListItemText(const aList: TListBox; const aIndex: integer;
                          const aText: string);
begin
   if (aIndex >= 0) and (aIndex < aList.Items.Count) then
      begin
      aList.Items[aIndex] := aText;
      end;
end;

// Select the item whose tag matches, or the first item when it is absent.
procedure SelectByTag(const aCombo: TComboBox; const aTag: string);
var
   row: integer;
begin
   row := RowOfTag(aCombo.Items, aTag);
   if (row < 0) and (aCombo.Items.Count > 0) then
      begin
      row := 0;
      end;
   if row >= 0 then
      begin
      aCombo.ItemIndex := row;
      end;
end;

function HasTag(const aCombo: TComboBox; const aTag: string): boolean;
begin
   Result := RowOfTag(aCombo.Items, aTag) >= 0;
end;

function SelectedTag(const aCombo: TComboBox): string;
begin
   Result := TagOfRow(aCombo.Items, aCombo.ItemIndex);
end;


// Named before anything else is assigned, so that if the name collides with one
// already used in this owner the failure is immediate and points at the control
// being created, not at some later property write.
procedure NameIt(const aControl: TComponent; const aName: string);
begin
   if aName <> '' then
      begin
      aControl.Name := aName;
      end;
end;

function MakeLabel(const aOwner: TComponent; const aParent: TWinControl;
                   const aName, aText: string;
                   const aX, aY, aWidth: integer): TLabel;
begin
   Result := TLabel.Create(aOwner);
   NameIt(Result, aName);
   Result.Parent     := aParent;
   Result.Left       := Round(aX);
   Result.Top        := Round(aY);
   Result.Width      := Round(aWidth);
   // AutoSize OFF before the width is honoured -- an LCL TLabel/TRadioButton
   // sizes itself to its caption otherwise, which is the same hazard the .lfm
   // converter emits AutoSize = False for.  Proven in spike\lclprobe.
   Result.AutoSize   := False;
   Result.Caption    := aText;
end;

function MakeRadio(const aOwner: TComponent; const aParent: TWinControl;
                   const aName, aText, aGroup: string;
                   const aX, aY, aWidth: integer): TRadioButton;
begin
   Result := TRadioButton.Create(aOwner);
   NameIt(Result, aName);
   Result.Parent     := aParent;
   Result.Left       := Round(aX);
   Result.Top        := Round(aY);
   Result.Width      := Round(aWidth);
   // AutoSize OFF before the width is honoured -- an LCL TLabel/TRadioButton
   // sizes itself to its caption otherwise, which is the same hazard the .lfm
   // converter emits AutoSize = False for.  Proven in spike\lclprobe.
   Result.AutoSize   := False;
   Result.Caption    := aText;
   // THE LCL GROUPS RADIO BUTTONS BY PARENT, not by a GroupName property.
   // FMX needed the explicit group precisely because its grouping was
   // parent-derived and the call sites shared a parent; here the parent IS
   // the group, so aGroup is accepted and deliberately unused rather than
   // dropped from the signature -- every call site keeps compiling, and the
   // caller's intent stays readable at the call.
   if aGroup = '' then
      begin
      end;
end;

// aAnchors defaults to FMX's own default, so every existing caller is unchanged.
// A FOOTER button must pass [akRight, akBottom]: positioning it once at
// ClientWidth/ClientHeight minus an offset places it correctly on a form that
// never resizes, and strands it in open space on one that does.  See the call
// sites for the two footers this bit (NY4I, 2026-08-05).
function MakeButton(const aOwner: TComponent; const aParent: TWinControl;
                    const aName, aText: string;
                    const aX, aY, aWidth: integer;
                    const aOnClick: TNotifyEvent;
                    const aAnchors: TAnchors = [akLeft,
                                                akTop]): TButton;
begin
   Result := TButton.Create(aOwner);
   NameIt(Result, aName);
   Result.Parent     := aParent;
   Result.Left       := Round(aX);
   Result.Top        := Round(aY);
   Result.Width      := Round(aWidth);
   Result.AutoSize   := False;
   Result.Height     := 25;
   Result.Caption    := aText;
   Result.OnClick    := aOnClick;
   // Anchors are honoured only while Align is alNone, which is the
   // default and what every control on these forms uses.
   Result.Anchors    := aAnchors;
end;

(* THE VALUE A PORT IS STORED AS: THE NAME THE OPERATING SYSTEM USES.

  It rendered 'SERIAL n' until 2026-09-10.  NY4I: SERIAL n is not an OS name --
  COM7 and /dev/ttyUSB0 are -- and it cannot spell a device node at all, so a
  Linux port could be shown and not saved.

  The store field is a free string and always was, so this needed no schema
  change.  What still expects 'SERIAL n' is the legacy CFGCA bridge, and
  uPortAddress.SerialTokenFor translates for it at the one place that renders
  those keys.

  PORT_NONE FOR AN EMPTY NAME, not for an unparseable one: '/dev/ttyUSB0' has
  no COM number and is a perfectly good port. *)
function ComNameToPortValue(const aComName: string): string;
begin
   Result := Trim(aComName);
   if Result = '' then
      begin
      Result := PORT_NONE;
      end;
end;

(* ONE FILLER FOR EVERY SERIAL-PORT DROP-DOWN.  There were three copies of this
  loop -- the radio editor filling two combos, the keyer editor, and the rotator
  list in Preferences -- and they had already begun to differ: one cleared with
  TComboBox.Clear, which then desynced AddComboItem's parallel tag list (the
  tags are in the rows themselves since issue 216).

  THE CAPTION IS FOR THE OPERATOR, THE TAG IS THE CONFIG VALUE.  Storing what is
  displayed would put 'COM17 - Silicon Labs CP210x' into the settings file,
  which is the corruption the legacy dialog had to be fixed for.

  A PORT THAT CANNOT BE SELECTED IS LISTED AND SAYS SO.  Two things reach that
  arm: a COM number above what PortType can represent, and -- today -- every
  port on Linux, where the settings file has no spelling for a device node at
  all.  Both get PORT_NONE as their tag and a caption that says why, because
  dropping them silently turns "TR4W cannot address my port yet" into "TR4W
  cannot see my adapter", and only one of those is true.  It is also the rule
  ComPortEnumerator's own header lays down (note 1). *)
procedure FillSerialPortCombo(const aCombo: TComboBox;
                              const aEnumerator: TComPortEnumerator);
var
   i: integer;
   info: TComPortInfo;
begin
   ClearComboItems(aCombo);
   AddComboItem(aCombo, TC_PREFS_NONE, PORT_NONE);

   if not ComPortEnumerationSupported then
      begin
      AddComboItem(aCombo, TC_PREFS_PORTS_UNAVAILABLE, PORT_NONE);
      Exit;
      end;

   if aEnumerator = nil then
      begin
      Exit;
      end;

   for i := 0 to aEnumerator.Count - 1 do
      begin
      info := aEnumerator.Ports[i];
      if info.Addressable then
         begin
         AddComboItem(aCombo, info.Describe, ComNameToPortValue(info.PortName));
         end
      else
         begin
         AddComboItem(aCombo,
                      info.Describe + '  ' + TC_PREFS_PORT_UNSUPPORTED,
                      PORT_NONE);
         end;
      end;
end;

// Is this registry id an Icom?  ManufacturerOf reads the first word of the
// registry DISPLAY NAME ('Icom IC-7300' -> 'Icom'), which is the only
// manufacturer the registry actually records.  For a string-id radio there is
// no enum to ask, so the display name is read directly -- the same rule, one
// step earlier.
//
// A capability flag would be better than a brand test, and if a non-Icom radio
// ever grows a filter byte this should become one.  It is a brand test today
// because the two settings it gates ARE brand-specific: 'ICOM FILTER BYTE' and
// 'ICOM DATA MODE ID' are the config keys' own names.
function IsIcomRadio(const aRegistryId: string): boolean;
var
   model: InterfacedRadioType;
begin
   if Trim(aRegistryId) = '' then
      begin
      Result := False;
      Exit;
      end;

   model := ModelForId(aRegistryId);
   if model <> NoInterfacedRadio then
      begin
      Result := SameText(ManufacturerOf(model), 'Icom');
      end
   else
      begin
      Result := SameText(Copy(Trim(DisplayNameId(aRegistryId)), 1, 4), 'Icom');
      end;
end;

procedure FillStopBitsCombo(const aCombo: TComboBox; const aSelected: integer);
begin
   ClearComboItems(aCombo);
   AddComboItem(aCombo, TC_PREFS_NONE, '0');
   AddComboItem(aCombo, '1', '1');
   AddComboItem(aCombo, '2', '2');
   SelectByTag(aCombo, IntToStr(aSelected));
end;

procedure FillRTSDTRCombo(const aCombo: TComboBox; const aSelected: string);
const
   RTSDTRROLES: array[0..4] of string = ('NONE', 'OFF', 'ON', 'CW', 'PTT');
var
   i: integer;
begin
   ClearComboItems(aCombo);
   for i := Low(RTSDTRROLES) to High(RTSDTRROLES) do
      begin
      AddComboItem(aCombo, RTSDTRROLES[i], RTSDTRROLES[i]);
      end;
   SelectByTag(aCombo, aSelected);
end;

// Parses a CI-V address written the way manuals and radio menus write it: hex,
// with or without a '$' or '0x'.  An empty box is a legitimate "not set" and
// yields 0, so it must not be an error.
function TryParseHexByte(const aText: string; out aValue: integer): boolean;
var
   t: string;
begin
   aValue := 0;
   t := Trim(aText);
   if t = '' then
      begin
      Result := True;
      Exit;
      end;

   if (Length(t) > 1) and (LowerCase(Copy(t, 1, 2)) = '0x') then
      begin
      t := Copy(t, 3, MaxInt);
      end
   else if t[1] = '$' then
      begin
      t := Copy(t, 2, MaxInt);
      end;

   Result := TryStrToInt('$' + t, aValue) and (aValue >= 0) and (aValue <= 255);
end;

function TextWidthInFont(const aFont: TFont; const aText: TCaption): integer;
var
   probe: TBitmap;
begin
   probe := TBitmap.Create;
   try
      probe.SetSize(1, 1);
      probe.Canvas.Font := aFont;
      Result := probe.Canvas.TextWidth(aText);
   finally
      probe.Free;
   end;
end;

function WidestText(const aFont: TFont; const aTexts: TStrings): integer;
var
   probe: TBitmap;
   i, w:  integer;
begin
   Result := 0;

   probe := TBitmap.Create;
   try
      probe.SetSize(1, 1);
      probe.Canvas.Font := aFont;

      for i := 0 to aTexts.Count - 1 do
         begin
         w := probe.Canvas.TextWidth(aTexts[i]);
         if w > Result then
            begin
            Result := w;
            end;
         end;
   finally
      probe.Free;
   end;
end;

function TextHeightInFont(const aFont: TFont; const aText: TCaption): integer;
var
   probe: TBitmap;
begin
   probe := TBitmap.Create;
   try
      probe.SetSize(1, 1);
      probe.Canvas.Font := aFont;
      Result := probe.Canvas.TextHeight(aText);
   finally
      probe.Free;
   end;
end;

function WrappedTextHeight(const aFont: TFont; const aText: TCaption;
                           const aWidth: integer): integer;
var
   probe:     TBitmap;
   lines:     integer;
   i, start:  integer;
   token:      TCaption;
   line:      TCaption;
   candidate: TCaption;
begin
   probe := TBitmap.Create;
   try
      probe.SetSize(1, 1);
      probe.Canvas.Font := aFont;

      lines := 1;
      line  := '';
      i     := 1;
      while i <= Length(aText) do
         begin
         (* One word: up to the next space, the spaces themselves skipped. *)
         while (i <= Length(aText)) and (aText[i] = ' ') do
            begin
            Inc(i);
            end;
         start := i;
         while (i <= Length(aText)) and (aText[i] <> ' ') do
            begin
            Inc(i);
            end;
         token := Copy(aText, start, i - start);
         if token = '' then
            begin
            Continue;
            end;

         if line = '' then
            begin
            candidate := token;
            end
         else
            begin
            candidate := line + ' ' + token;
            end;

         (* A word that does not fit on the current line starts the next one; a
           word wider than the whole width has a line of its own, as a word
           break leaves it. *)
         if (line <> '') and (probe.Canvas.TextWidth(candidate) > aWidth) then
            begin
            Inc(lines);
            line := token;
            end
         else
            begin
            line := candidate;
            end;
         end;

      Result := lines * probe.Canvas.TextHeight('Wg');
   finally
      probe.Free;
   end;
end;

procedure ControlPreferredSize(const aControl: TControl; out aWidth, aHeight: integer);
begin
   aWidth := 0;
   aHeight := 0;
   aControl.GetPreferredSize(aWidth, aHeight, True, True);
   if aWidth < 0 then
      begin
      aWidth := 0;
      end;
   if aHeight < 0 then
      begin
      aHeight := 0;
      end;
end;

function CaptionFocusControl(const aCaption: TControl): TWinControl;
begin
   Result := nil;
   if aCaption is TLabel then
      begin
      Result := TLabel(aCaption).FocusControl;
      end
   else if aCaption is TStaticText then
      begin
      Result := TStaticText(aCaption).FocusControl;
      end;
end;

{ =========================================================== TRadioEditForm = }


class function TStopwatch.StartNew: TStopwatch;
begin
   Result.FStart := GetTickCount64;
end;


{ The client extent one control needs along one axis, given how it is anchored.

  THREE CASES, and the middle one is the whole fix.

    fixed     (near edge only, or neither)  its position plus its size
    moves     (far edge only)               its size plus the far margin, since
                                            the near margin is what collapses
    stretches (both edges)                  near margin + a content floor + far
                                            margin, because both margins are
                                            preserved and only the middle shrinks

  aMinContent is what the control may shrink TO, not what it measures now. }
function NeededExtent(const aPos, aSize, aClient, aMinContent: integer;
                      const aNearAnchored, aFarAnchored: boolean): integer;
var
   farMargin: integer;
begin
   farMargin := aClient - aPos - aSize;
   if farMargin < 0 then
      begin
      farMargin := 0;
      end;

   if aNearAnchored and aFarAnchored then
      begin
      Result := aPos + aMinContent + farMargin;
      end
   else if aFarAnchored then
      begin
      Result := aSize + farMargin;
      end
   else
      begin
      Result := aPos + aSize;
      end;
end;

{ What a stretching control may shrink to.

  A STATED CONSTRAINT IS TAKEN AS STATED. The first version clamped it to
  aDesigned -- the control's CURRENT width -- to stop a bogus constraint
  demanding a window bigger than the designer drew. That reasoning is wrong for
  a control that stretches, because its current width is the WINDOW's width:
  clamping against it means a window that has been dragged small reports a small
  content minimum, which becomes its new floor, which lets it be dragged smaller
  still. The minimum RATCHETED DOWN every time the window was reopened, and the
  QTC send window ended up draggable to a sliver (NY4I, screenshot, 2026-09-01).

  A Constraints.MinWidth is a statement about CONTENT and does not change when
  the window does. It is the only thing here that can be trusted across a
  resize, so it is used unaltered.

  The DEFAULT floor is still clamped: it is a guess, and demanding more than the
  control currently occupies on the strength of a guess would be worse. }
function ShrinkFloor(const aConstraint, aDesigned, aFloor: integer): integer;
begin
   if aConstraint > 0 then
      begin
      Result := aConstraint;
      Exit;
      end;

   Result := aFloor;
   if Result > aDesigned then
      begin
      Result := aDesigned;
      end;
end;

{ HOW A CONTROL BEHAVES ON EACH AXIS, given that Align OVERRIDES Anchors.

  An alClient control is pinned on all four sides whatever its Anchors property
  says, and reading Anchors alone would call it fixed and pin the FORM to
  whatever size it opened at -- the same class of wrong answer as skipping it,
  in the opposite direction. }
function EffectiveAnchors(const aCtl: TControl): TAnchors;
begin
   case aCtl.Align of
      alTop:    Result := [akLeft, akTop, akRight];
      alBottom: Result := [akLeft, akRight, akBottom];
      alLeft:   Result := [akLeft, akTop, akBottom];
      alRight:  Result := [akTop, akRight, akBottom];
      alClient: Result := [akLeft, akTop, akRight, akBottom];
   else
      Result := aCtl.Anchors;
   end;
end;

procedure ApplyContentMinimumSize(const aForm: TForm);
const
   { The floor for a control that stretches and says nothing about its own
     minimum. Below roughly this there is no room for a column, a caption and a
     scrollbar. A form that knows better states it on the control:
     Constraints.MinWidth / MinHeight are read first and this is the fallback. }
   MIN_STRETCH_WIDTH  = 120;
   MIN_STRETCH_HEIGHT = 60;
var
   i             : integer;
   c             : TControl;
   anc           : TAnchors;
   maxR, maxB    : integer;
   needW, needH  : integer;
   slackW, slackH: integer;
   newW, newH    : integer;
begin
   if aForm = nil then
      begin
      Exit;
      end;

   maxR := 0;
   maxB := 0;

   for i := 0 to aForm.ControlCount - 1 do
      begin
      c := aForm.Controls[i];

      if not c.Visible then
         begin
         Continue;
         end;

      anc := EffectiveAnchors(c);

      needW := NeededExtent(c.Left, c.Width, aForm.ClientWidth,
                            ShrinkFloor(c.Constraints.MinWidth, c.Width,
                                        MIN_STRETCH_WIDTH),
                            akLeft in anc, akRight in anc);

      needH := NeededExtent(c.Top, c.Height, aForm.ClientHeight,
                            ShrinkFloor(c.Constraints.MinHeight, c.Height,
                                        MIN_STRETCH_HEIGHT),
                            akTop in anc, akBottom in anc);

      if needW > maxR then
         begin
         maxR := needW;
         end;
      if needH > maxB then
         begin
         maxB := needH;
         end;
      end;

   if (maxR = 0) or (maxB = 0) then
      begin
      { Genuinely nothing to measure -- an empty form. }
      Exit;
      end;

   slackW := aForm.ClientWidth - maxR;
   slackH := aForm.ClientHeight - maxB;

   { Both read at this instant, so (Width - ClientWidth) never appears.

     SET UNCONDITIONALLY, INCLUDING ON NEGATIVE SLACK, and each of the three
     cases was got wrong in turn:

       positive   room to spare. Always worked.

       zero       the form is exactly the size its content needs -- the most
                  likely size for a form somebody laid out carefully -- and the
                  original `> 0` set NOTHING, so the most carefully drawn forms
                  were the ones left unprotected.

       negative   the form is CURRENTLY SMALLER than its content. The previous
                  fix still ignored this, on the reasoning that content wider
                  than its form is a layout defect for uTextFitAudit to report
                  rather than something to paper over by inflating the window.

                  That confused two situations. A control designed outside its
                  parent is a layout defect and the audit does name it. A window
                  the operator has dragged below its content is not a defect at
                  all -- it is EXACTLY what a minimum exists to prevent, and
                  refusing to act on it is how the QTC window kept the sliver it
                  had been dragged to.

     In all three cases the answer is the same and needs no test: the form may
     not be smaller than its content, so its minimum is its current size less
     whatever slack that content leaves -- which is larger than the current size
     when the slack is negative, and the window grows back to fit. }
   aForm.Constraints.MinWidth  := aForm.Width - slackW;
   aForm.Constraints.MinHeight := aForm.Height - slackH;

   { AND APPLIED, NOT MERELY DECLARED.

     Setting Constraints on a form that is ALREADY SHOWING does not resize it:
     the LCL enforces them the next time the bounds change.  This routine is
     called from OnShow -- it has to be, because that is when the content
     exists -- and ShowModalOverWin32Parent centres and shows BEFORE OnShow
     fires.  So the window opened at its designed size with its content clipped,
     and jumped to the correct size the instant the operator touched a corner
     (NY4I, screenshot, 2026-09-01).

     A minimum that is right and unapplied looks exactly like a minimum that is
     wrong, which is how this survived three passes over the same routine.

     NOT RE-CENTRED afterwards, deliberately.  Growing pushes the window right
     and down by half the shortfall -- tens of pixels -- and re-centring here
     would move a window that had RESTORED a saved position, which is a worse
     failure than being slightly off centre.  The centring nuance is noted in
     ShowModalOverWin32Parent's header and belongs there if it is ever wanted. }
   newW := aForm.Width;
   newH := aForm.Height;
   if newW < aForm.Constraints.MinWidth then
      begin
      newW := aForm.Constraints.MinWidth;
      end;
   if newH < aForm.Constraints.MinHeight then
      begin
      newH := aForm.Constraints.MinHeight;
      end;
   if (newW <> aForm.Width) or (newH <> aForm.Height) then
      begin
      aForm.SetBounds(aForm.Left, aForm.Top, newW, newH);
      end;

   { REPORTED, because every one of the three cases above failed SILENTLY and
     looked identical from outside: a window that could be dragged too small.
     The numbers say which control set the bound and how much room it thought it
     had, which is the difference between reading this and guessing again. }
   if logger <> nil then
      begin
      logger.Debug('[MinSize] %s: client %dx%d, content %dx%d, ' +
                   'slack %dx%d -> min %dx%d, window now %dx%d',
                   [aForm.Name, aForm.ClientWidth, aForm.ClientHeight,
                    maxR, maxB, slackW, slackH,
                    aForm.Constraints.MinWidth, aForm.Constraints.MinHeight,
                    aForm.Width, aForm.Height]);
      end;
end;


{ THE FONT HEIGHT A CONTROL ACTUALLY RENDERS AT.

  Font.Height is 0 on any control that has not been given one -- which is most
  of them, because a designed form only writes a Font entry for the controls
  whose font was changed. Scaling that 0 yields 0, and assigning 0 back means
  "use the default", so the control never grows.

  That is not hypothetical: ten of the radio panel's twelve controls inherit
  their font, so the two VFO panels (the only ones with an explicit
  Font.Height = -16) scaled while every label stayed put. The frequency ended up
  many times the size of everything around it (NY4I, 2026-08-31).

  Height is resolved from Size when Size is set -- Height is Size in points
  converted through the font's own PixelsPerInch -- and from the system font
  when neither is. Integer arithmetic and LCL only; MulDiv is a Win32 call. }
function EffectiveFontHeight(const aFont: TFont): integer;
begin
   Result := aFont.Height;
   if Result <> 0 then
      begin
      Exit;
      end;

   if aFont.Size <> 0 then
      begin
      Result := -((aFont.Size * aFont.PixelsPerInch) div 72);
      Exit;
      end;

   { Inherited all the way to the system font. }
   Result := Screen.SystemFont.Height;
   if (Result = 0) and (Screen.SystemFont.Size <> 0) then
      begin
      Result := -((Screen.SystemFont.Size * Screen.SystemFont.PixelsPerInch) div 72);
      end;

   if Result = 0 then
      begin
      Result := -12;   { the LCL's own fallback, and better than not scaling }
      end;
end;

type
   { TControl.Font is PROTECTED -- published only from TWinControl down. An
     access class is the standard way to reach it without requiring every
     caller to know which concrete control it holds. }
   TControlAccess = class(TControl);

procedure CaptureDesignLayout(const aForm: TForm; out aLayout: TDesignLayout;
                              out aDesignW, aDesignH: integer);
var
   i: integer;
begin
   SetLength(aLayout, 0);
   aDesignW := 0;
   aDesignH := 0;

   if aForm = nil then
      begin
      Exit;
      end;

   aDesignW := aForm.ClientWidth;
   aDesignH := aForm.ClientHeight;

   SetLength(aLayout, aForm.ControlCount);
   for i := 0 to aForm.ControlCount - 1 do
      begin
      aLayout[i].Ctl    := aForm.Controls[i];
      aLayout[i].Left   := aForm.Controls[i].Left;
      aLayout[i].Top    := aForm.Controls[i].Top;
      aLayout[i].Width  := aForm.Controls[i].Width;
      aLayout[i].Height := aForm.Controls[i].Height;

      { Font.Height, not Font.Size: Height is in pixels and scales linearly,
        while Size is in points and is rounded through the screen DPI on the way
        in and out -- scaling that quantises and drifts. Height is negative for
        a character-height font, which is why the sign is preserved below. }
      if aForm.Controls[i] is TControl then
         begin
         aLayout[i].FontHeight := EffectiveFontHeight(TControlAccess(aForm.Controls[i]).Font);
         end;

      { THE SCALER OWNS THE LAYOUT FROM HERE, so every control is pinned to the
        top left and positioned explicitly.

        An edge anchor and a scaler are two things laying out the same control
        and they disagree. A right-anchored panel keeps its own right edge
        against the form while its left edge is being scaled, so it stretches
        instead of scaling and drifts away from the controls it was designed
        beside -- that is exactly what the radio panel's status box did (NY4I,
        2026-08-31). It also made the control invisible to
        ApplyContentMinimumSize, which must skip edge-anchored controls because
        their current position says nothing about the minimum, so the window
        could be shrunk until the status box was gone.

        Recorded BEFORE this, so the designed bounds are the anchored ones.

        A form whose content should FILL rather than scale -- a grid -- wants
        its anchors left alone and must not use this scaler. }

      aForm.Controls[i].Anchors := [akLeft, akTop];
      end;
end;

procedure ApplyLayoutScale(const aForm: TForm; const aLayout: TDesignLayout;
                           const aDesignW, aDesignH: integer;
                           const aMinPercent: integer = 100;
                           const aMaxPercent: integer = 0);
var
   i, pct, pctW, pctH: integer;
   c: TControl;
begin
   if (aForm = nil) or (Length(aLayout) = 0) or
      (aDesignW < 1) or (aDesignH < 1) then
      begin
      Exit;
      end;

   if (aForm.ClientWidth < 1) or (aForm.ClientHeight < 1) then
      begin
      Exit;      { mid-layout, or minimised }
      end;

   pctW := (aForm.ClientWidth  * 100) div aDesignW;
   pctH := (aForm.ClientHeight * 100) div aDesignH;

   if pctW < aMinPercent then
      begin
      pctW := aMinPercent;
      end;
   if (aMaxPercent > 0) and (pctW > aMaxPercent) then
      begin
      pctW := aMaxPercent;
      end;

   if pctH < aMinPercent then
      begin
      pctH := aMinPercent;
      end;
   if (aMaxPercent > 0) and (pctH > aMaxPercent) then
      begin
      pctH := aMaxPercent;
      end;

   { The font follows the TIGHTER axis so text cannot overflow its control. }
   if pctW < pctH then
      begin
      pct := pctW;
      end
   else
      begin
      pct := pctH;
      end;

   { NOTHING TO DO is the common case once a drag settles inside the clamp, and
     re-laying the form out anyway is the flicker this exists to avoid. }
   if (aLayout[0].Ctl <> nil) and
      (aLayout[0].Ctl.Left   = (aLayout[0].Left   * pctW) div 100) and
      (aLayout[0].Ctl.Width  = (aLayout[0].Width  * pctW) div 100) and
      (aLayout[0].Ctl.Top    = (aLayout[0].Top    * pctH) div 100) and
      (aLayout[0].Ctl.Height = (aLayout[0].Height * pctH) div 100) then
      begin
      Exit;
      end;

   aForm.DisableAlign;
   try
      for i := 0 to High(aLayout) do
         begin
         c := aLayout[i].Ctl;
         if c = nil then
            begin
            Continue;
            end;

         TControlAccess(c).Font.Height := (aLayout[i].FontHeight * pct) div 100;

         c.SetBounds((aLayout[i].Left   * pctW) div 100,
                     (aLayout[i].Top    * pctH) div 100,
                     (aLayout[i].Width  * pctW) div 100,
                     (aLayout[i].Height * pctH) div 100);
         end;
   finally
      aForm.EnableAlign;
   end;
end;

function TStopwatch.ElapsedMilliseconds: Int64;
begin
   Result := Int64(GetTickCount64 - FStart);
end;


(* The live rectangle, in the LCL's own units -- see the note on the
  declaration for why this is not GetWindowRect. *)
function LiveFormBounds(const aForm: TCustomForm): TRect;
begin
   Result := Rect(aForm.Left, aForm.Top,
                  aForm.Left + aForm.Width, aForm.Top + aForm.Height);
end;

procedure SaveFormBounds(const aForm: TCustomForm; const aName: string;
                         const aVisible: boolean);
var
   store: TWindowLayoutStore;
begin
   if (aForm = nil) or (aName = '') then
      begin
      Exit;
      end;

   (* Minimised or maximised bounds are not what to restore. *)
   if aForm.WindowState <> wsNormal then
      begin
      Exit;
      end;

   store := TWindowLayoutStore.Create;
   try
      store.SetLayout(aName, LiveFormBounds(aForm), aVisible);
      SaveWindowLayout(TR4WConfigFileName, store);
   finally
      store.Free;
   end;
end;

function TryRestoreFormBounds(const aForm: TCustomForm;
                              const aName: string): boolean;
var
   store: TWindowLayoutStore;
   saved, desktop, overlap: TRect;
   visible: boolean;
begin
   Result := False;
   if (aForm = nil) or (aName = '') then
      begin
      Exit;
      end;

   store := TWindowLayoutStore.Create;
   try
      if not LoadWindowLayout(TR4WConfigFileName, store) then
         begin
         Exit;
         end;

      if not store.TryGetLayout(aName, saved, visible) then
         begin
         Exit;
         end;

      desktop := Rect(Screen.DesktopLeft, Screen.DesktopTop,
                      Screen.DesktopLeft + Screen.DesktopWidth,
                      Screen.DesktopTop  + Screen.DesktopHeight);

      if not IntersectRect(overlap, saved, desktop) then
         begin
         Exit;
         end;

      aForm.Position := poDesigned;
      aForm.SetBounds(saved.Left, saved.Top,
                      saved.Right - saved.Left, saved.Bottom - saved.Top);
      Result := True;
   finally
      store.Free;
   end;
end;

const
   (* Room either side of a header's text, so a clamped column does not sit
     its caption hard against the divider. The LCL's own cell padding is
     3 px a side; this is a little more, because the floor is a minimum to
     READ the header, not to fit it exactly. *)
   COLUMN_HEADER_PAD = 12;

   (* No restored column narrower than this whatever the file says -- a
     column this narrow cannot be seen to be dragged back. *)
   COLUMN_FLOOR = 8;

var
   (* The widths dragged and not yet written. Created in initialization, so
     there is no lazy creation to race; main thread only. *)
   GPendingColumnWidths: TColumnWidthStore = nil;

function ColumnWidthTo96(const aControl: TControl; const aWidth: integer): integer;
begin
   Result := aWidth;
   if (aControl <> nil) and (GetParentDesignControl(aControl) <> nil) then
      begin
      Result := aControl.ScaleFormTo96(aWidth);
      end;
end;

function ColumnWidthFrom96(const aControl: TControl; const aWidth96: integer): integer;
begin
   Result := aWidth96;
   if (aControl <> nil) and (GetParentDesignControl(aControl) <> nil) then
      begin
      Result := aControl.Scale96ToForm(aWidth96);
      end;
end;

(* The header's caption: a Columns title when the grid has a Columns
  collection, otherwise the fixed row's cell of a string grid. '' when there
  is neither, and the floor is then only the minimum. A TCaption -- the LCL's
  own UTF-8 string -- because it only ever goes back to the LCL to be
  measured, so it is never converted at all. *)
function GridHeaderText(const aGrid: TCustomDrawGrid; const aCol: integer): TCaption;
var
   idx: integer;
begin
   Result := '';
   if aGrid.Columns.Enabled and (aCol >= aGrid.FixedCols) then
      begin
      idx := aCol - aGrid.FixedCols;
      if idx < aGrid.Columns.Count then
         begin
         Result := aGrid.Columns[idx].Title.Caption;
         end;
      Exit;
      end;

   if (aGrid is TCustomStringGrid) and (aGrid.FixedRows > 0) then
      begin
      Result := TCustomStringGrid(aGrid).Cells[aCol, 0];
      end;
end;

(* The narrowest a restored column may be: its header, read, and its own
  minimum. Measured on a scratch canvas in the grid's font, so it needs no
  window handle -- a restore runs before the form is shown. *)
function GridColumnFloor(const aGrid: TCustomDrawGrid; const aCol: integer): integer;
var
   text: TCaption;
   header, minimum: integer;
begin
   header := 0;
   text := GridHeaderText(aGrid, aCol);
   if text <> '' then
      begin
      header := TextWidthInFont(aGrid.Font, text) + COLUMN_HEADER_PAD;
      end;

   minimum := COLUMN_FLOOR;
   if aGrid.Columns.Enabled and (aCol >= aGrid.FixedCols) and
      (aCol - aGrid.FixedCols < aGrid.Columns.Count) and
      (aGrid.Columns[aCol - aGrid.FixedCols].MinSize > minimum) then
      begin
      minimum := aGrid.Columns[aCol - aGrid.FixedCols].MinSize;
      end;

   Result := ClampRestoredWidth(0, header, minimum);
end;

function ApplyGridColumnWidths(const aGrid: TCustomDrawGrid; const aName: string;
                               const aTokens: array of string;
                               const aStore: TColumnWidthStore): integer;
var
   col: integer;
   width96: integer;
begin
   Result := 0;
   if (aGrid = nil) or (aName = '') or (aStore = nil) then
      begin
      Exit;
      end;

   for col := 0 to aGrid.ColCount - 1 do
      begin
      if (col > High(aTokens)) or (aTokens[col] = '') then
         begin
         Continue;
         end;

      width96 := 0;
      if not aStore.TryGetWidth(aName, aTokens[col], width96) then
         begin
         Continue;
         end;

      aGrid.ColWidths[col] := ClampRestoredWidth(ColumnWidthFrom96(aGrid, width96),
                                                 GridColumnFloor(aGrid, col), 0);
      Inc(Result);
      end;
end;

procedure CaptureGridColumnWidth(const aGrid: TCustomDrawGrid; const aName: string;
                                 const aTokens: array of string; const aCol: integer;
                                 const aStore: TColumnWidthStore);
begin
   if (aGrid = nil) or (aName = '') or (aStore = nil) then
      begin
      Exit;
      end;

   if (aCol < 0) or (aCol >= aGrid.ColCount) or (aCol > High(aTokens)) or
      (aTokens[aCol] = '') then
      begin
      Exit;
      end;

   aStore.SetWidth(aName, aTokens[aCol],
                   ColumnWidthTo96(aGrid, aGrid.ColWidths[aCol]));
end;

procedure LoadSavedColumnWidths(const aStore: TColumnWidthStore);
begin
   if aStore = nil then
      begin
      Exit;
      end;

   LoadColumnWidths(TR4WConfigFileName, aStore);
   aStore.MergeFrom(GPendingColumnWidths);
end;

function RestoreGridColumnWidths(const aGrid: TCustomDrawGrid; const aName: string;
                                 const aTokens: array of string): integer;
var
   store: TColumnWidthStore;
begin
   store := TColumnWidthStore.Create;
   try
      LoadSavedColumnWidths(store);
      Result := ApplyGridColumnWidths(aGrid, aName, aTokens, store);
   finally
      store.Free;
   end;
end;

procedure SaveGridColumnWidth(const aGrid: TCustomDrawGrid; const aName: string;
                              const aTokens: array of string; const aCol: integer);
begin
   CaptureGridColumnWidth(aGrid, aName, aTokens, aCol, GPendingColumnWidths);
end;

procedure FillGridFromColumn(const aGrid: TCustomDrawGrid; const aFillCol: integer;
                             const aMinSize: integer);
var
   i, fillIndex: integer;
begin
   fillIndex := aFillCol - aGrid.FixedCols;
   for i := 0 to aGrid.Columns.Count - 1 do
      begin
      aGrid.Columns[i].SizePriority := 0;
      end;
   aGrid.Columns[fillIndex].SizePriority := 1;
   aGrid.Columns[fillIndex].MinSize := aMinSize;
   (* BEFORE AutoFillColumns (the interface comment says why the bar is
      permanent): with a handle, this shows the bar first, so the fill that
      turning AutoFillColumns on runs measures the width it will keep. *)
   aGrid.ScrollBars := ssVertical;
   aGrid.AutoFillColumns := True;
end;

procedure NoteColumnWidth(const aName, aToken: string; const aWidth96: integer);
begin
   if GPendingColumnWidths <> nil then
      begin
      GPendingColumnWidths.SetWidth(aName, aToken, aWidth96);
      end;
end;

function ColumnWidthsPending: boolean;
begin
   Result := (GPendingColumnWidths <> nil) and
             (GPendingColumnWidths.EntryCount > 0);
end;

procedure FlushColumnWidths;
begin
   if not ColumnWidthsPending then
      begin
      (* Nothing dragged is the normal case, and it must not rewrite the
        file. *)
      Exit;
      end;

   SaveColumnWidths(TR4WConfigFileName, GPendingColumnWidths);
   GPendingColumnWidths.Clear;
end;

function PendingColumnWidths: TColumnWidthStore;
begin
   Result := GPendingColumnWidths;
end;

initialization
   GPendingColumnWidths := TColumnWidthStore.Create;

finalization
   (* NOT flushed here: ExitProgram's SaveTR4WPOSFILE already wrote the
     marks, and a write from finalization would run with the program half
     torn down. *)
   FreeAndNil(GPendingColumnWidths);
   FreeAndNil(gNavNodeFactory);

end.
