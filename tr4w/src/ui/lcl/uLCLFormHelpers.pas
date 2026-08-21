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
   LCLType,    // HWND
   Dialogs;    // InputQuery -- see AskForText

const
   // --- captions ------------------------------------------------------------
   // ONE place, so the i18n lift is mechanical.  See the unit header.
   TC_PREFS_TITLE            = 'TR4W Preferences';
   TC_PREFS_HARDWARE         = 'Hardware';
   TC_PREFS_CONTEST          = 'Contest';
   TC_PREFS_CW               = 'CW';
   TC_PREFS_CLUSTER          = 'DX Cluster';
   TC_PREFS_NOTMIGRATED      = 'This section has not been migrated yet.' + sLineBreak +
                               'Use the existing configuration screens for it.';

   TC_PREFS_MYRADIOS         = 'My radios';
   TC_PREFS_ADD              = 'Add...';
   TC_PREFS_EDIT             = 'Edit...';
   TC_PREFS_DUPLICATE        = 'Duplicate';
   TC_PREFS_REMOVE           = 'Remove';

   TC_PREFS_PROFILES         = 'Station profile';
   TC_PREFS_NEWPROFILE       = 'New...';
   TC_PREFS_RENAMEPROFILE    = 'Rename...';
   TC_PREFS_DELETEPROFILE    = 'Delete';
   TC_PREFS_RADIO1           = 'Radio 1';
   TC_PREFS_RADIO2           = 'Radio 2';
   TC_PREFS_NONE             = '(none)';
   TC_PREFS_CWOUTPUT1        = 'CW output 1';
   TC_PREFS_CWOUTPUT2        = 'CW output 2';
   TC_PREFS_SPEEDSYNC        = 'Speed sync';
   TC_PREFS_SO2R             = 'SO2R enabled';
   TC_PREFS_AUTOCONNECT      = 'Connect radios at startup';
   TC_PREFS_ACTIVATE         = 'Save and activate this profile';
   TC_PREFS_ACTIVELABEL      = 'Active profile: ';

   // Named for what they DO.  'OK' and 'Apply' gave no clue that they save,
   // which left "how do I save this profile?" as a fair question (NY4I).
   TC_PREFS_OK               = 'Save and close';
   TC_PREFS_CANCEL           = 'Cancel';
   TC_PREFS_APPLY            = 'Save';
   TC_PREFS_UNSAVED          = 'Save your changes before closing?';
   TC_PREFS_UNSAVEDTITLE     = 'TR4W Preferences';
   TC_RADIOEDIT_UNSAVED      = 'Save your changes to this radio?';

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
   TC_RADIOEDIT_TITLE        = 'Radio';
   TC_RADIOEDIT_NAME         = 'Name';
   TC_RADIOEDIT_TYPE         = 'Radio type';
   TC_RADIOEDIT_TRANSPORT    = 'Connection';
   TC_RADIOEDIT_SERIAL       = 'Serial';
   TC_RADIOEDIT_NETWORK      = 'Network';
   TC_RADIOEDIT_ADVANCED     = 'Advanced';
   TC_RADIOEDIT_DISCOVER     = 'Discover';
   TC_RADIOEDIT_SEARCHING    = 'Searching...';
   TC_RADIOEDIT_FOUND        = 'Found';
   TC_RADIOEDIT_NONEFOUND    = 'No radios answered.';
   TC_RADIOEDIT_PORT         = 'Port';
   TC_RADIOEDIT_BAUD         = 'Baud rate';
   TC_RADIOEDIT_DATABITS     = 'Data bits';
   TC_RADIOEDIT_PARITY       = 'Parity';
   TC_RADIOEDIT_STOPBITS     = 'Stop bits';
   TC_RADIOEDIT_PARITYNONE   = 'None';
   TC_RADIOEDIT_PARITYODD    = 'Odd';
   TC_RADIOEDIT_PARITYEVEN   = 'Even';
   TC_RADIOEDIT_IPADDRESS    = 'IP address';
   TC_RADIOEDIT_TCPPORT      = 'TCP port';
   TC_RADIOEDIT_USERNAME     = 'User name';
   TC_RADIOEDIT_PASSWORD     = 'Password';
   TC_RADIOEDIT_KEYERPORT    = 'Keyer output port';
   TC_RADIOEDIT_KEYERRTS     = 'Keyer RTS line';
   TC_RADIOEDIT_KEYERDTR     = 'Keyer DTR line';
   TC_RADIOEDIT_CATRTS       = 'CAT RTS';
   TC_RADIOEDIT_CATDTR       = 'CAT DTR';
   TC_RADIOEDIT_KEYERSTOPBITS = 'Stop bits';
   TC_RADIOEDIT_CIVADDRESS   = 'CI-V address (hex)';
   TC_RADIOEDIT_BADCIV       = 'The CI-V address must be a hex value, e.g. 88 or $88.';
   // Shown greyed INSIDE an empty field, so "blank" reads as "using this"
   // rather than as "you forgot something".
   TC_RADIOEDIT_DEFAULTHINT  = '%s (default)';
   TC_RADIOEDIT_HAMLIBID     = 'HamLib model ID';
   TC_RADIOEDIT_STARTUP      = 'Startup command';
   TC_RADIOEDIT_FILTERBYTE   = 'Icom filter byte';
   TC_RADIOEDIT_DATAMODEID   = 'Icom data mode ID';
   TC_RADIOEDIT_WIDECW       = 'Wide CW filter';
   TC_RADIOEDIT_FT1000MPREV  = 'FT-1000MP CW reverse';
   TC_RADIOEDIT_POLLING      = 'Poll this radio';
   TC_RADIOEDIT_USEHAMLIB    = 'Drive through HamLib';
   TC_RADIOEDIT_NAMEREQUIRED = 'The radio needs a name.';
   TC_RADIOEDIT_TYPEREQUIRED = 'Choose a radio type.';

   // --- layout metrics ------------------------------------------------------
   // Shared while these forms are built in code.  A form that converts to a
   // designed .fmx stops needing them -- position and size become properties
   // in the resource -- so this block should shrink to nothing over time.
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
function ShowModalOverWin32Parent(const aForm: TCustomForm; const aParent: HWND): integer;

{ MAKE THE TR4W MAIN WINDOW THE FORM'S OWNER, AND CENTRE OVER IT.

  BOTH ARE THE SAME DEFECT, and it is a nil Application.MainForm.
  CreateTR4WMainForm builds the main window with TTR4WMainForm.CreateNew(nil)
  because Application.Run is never called and so Application.CreateForm -- the
  thing that assigns Application.MainForm -- never runs either. Two consequences
  nothing warns about:

  1. OWNERSHIP. An LCL form is owned by the hidden Application window, not by
     TR4W's main window. The taskbar button belongs to the main form
     (ShowInTaskBar := stAlways), so clicking it raises the MAIN window, and
     Windows has no reason to keep a dialog above a window that does not own it
     -- a modal dialog ends up behind its own application, and the operator has
     to hunt for it (NY4I, 2026-08-21). PopupParent is the LCL's supported way
     to set GWL_HWNDPARENT; setting it by hand does not survive a handle
     recreation.

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
procedure OwnFormByMainWindow(const aForm: TCustomForm);
procedure CentreOverMainWindow(const aForm: TCustomForm);

function AskForText(const aCaption, aPrompt: string; var aValue: string): boolean;

// Install the node class on a tree. Call BEFORE adding any node.
procedure UseNavNodes(const aTree: TTreeView);
function  NavTagOf(const aNode: TTreeNode): integer;

procedure AddListItem(const aList: TListBox; const aText, aTag: string);
procedure ClearListItems(const aList: TListBox);
// Clears a tagged COMBO -- items and tags together. Never call aCombo.Clear
// directly: it empties Items and leaves the tag list behind, after which
// SelectedTag returns a stale tag from the previous fill. See the implementation.
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
function IsIcomRadio(const aRegistryId: string): boolean;
// The role each serial control line performs, spelled EXACTLY as
// tr4w_RTSDTRTypeSA does (LOGRADIO.PAS:100).  The vocabulary is reproduced here
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

function TryParseHexByte(const aText: string; out aValue: integer): boolean;

implementation

uses
   Windows,    // EnableWindow / IsWindowEnabled -- see ShowModalOverWin32Parent
   uMainForm,  // TR4WMainForm -- the owner every dialog should have had
   Types,      // TRect
   SysUtils,
   StrUtils,
   uRadioConfigStore,
   uRadioRegistry,
   ComPortEnumerator,
   VC;

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
function ShowModalOverWin32Parent(const aForm: TCustomForm; const aParent: HWND): integer;
var
   reEnable: boolean;
begin
   // EVERY MODAL COMES THROUGH HERE, which is why ownership is applied here
   // and not in sixteen ShowBlah routines. See OwnFormByMainWindow.
   OwnFormByMainWindow(aForm);
   if aForm.Position = poMainFormCenter then
      begin
      CentreOverMainWindow(aForm);
      end;

   reEnable := (aParent <> 0) and
               Windows.IsWindow(aParent) and
               Windows.IsWindowEnabled(aParent);

   if reEnable then
      begin
      Windows.EnableWindow(aParent, False);
      end;

   try
      Result := aForm.ShowModal;
   finally
      // RE-ENABLE BEFORE THE FORM GOES, and in a finally: an exception escaping
      // ShowModal would otherwise leave the parent permanently dead, which the
      // operator experiences as a frozen window with no dialog on screen.
      if reEnable then
         begin
         Windows.EnableWindow(aParent, True);
         // Windows gives focus to nothing in particular after re-enabling, so
         // put it back where the dialog manager would have left it.
         Windows.SetActiveWindow(aParent);
         end;
   end;
end;

{ ------------------------------------------------------------- helpers ---- }

{ ---------------------------------------------------------------------------
  COMBO ITEM TAGS.

  FMX gave every list item a TagString, so a combo could carry a registry id or
  a radio name alongside the text the operator reads.  The LCL's
  TComboBox.Items is a plain TStrings: it has Objects[] for a TObject and
  nothing for a string.

  The tag must stay a STRING and must never become an index.  That is not a
  preference -- the comment the FMX version carried says index arithmetic
  against a list whose contents depend on what hardware is plugged in is how the
  legacy port combo grew its bugs, and these lists are populated at runtime from
  this machine's COM ports and the radio registry.

  So each combo gets a TComboTags companion holding a parallel TStringList.  It
  is a TComponent OWNED BY THE COMBO, which is what makes the lifetime correct
  with no explicit teardown anywhere: destroying the combo destroys the tags
  with it.  It is looked up by name, so populating a combo twice reuses the one
  holder rather than growing a second.
--------------------------------------------------------------------------- }

type
   TComboTags = class(TComponent)
   public
      Tags: TStringList;
      constructor Create(aOwner: TComponent); override;
      destructor Destroy; override;
   end;

const
   COMBO_TAGS_NAME = 'TR4WComboTags';

constructor TComboTags.Create(aOwner: TComponent);
begin
   inherited Create(aOwner);
   Name := COMBO_TAGS_NAME;
   Tags := TStringList.Create;
end;

destructor TComboTags.Destroy;
begin
   FreeAndNil(Tags);
   inherited Destroy;
end;

// The tag list for this combo, created on first use.
function TagsOf(const aOwner: TWinControl): TStringList;
var
   holder: TComponent;
begin
   holder := aOwner.FindComponent(COMBO_TAGS_NAME);
   if holder = nil then
      begin
      holder := TComboTags.Create(aOwner);
      end;
   Result := TComboTags(holder).Tags;
end;

procedure AddComboItem(const aCombo: TComboBox; const aText, aTag: string);
var
   tags: TStringList;
begin
   tags := TagsOf(aCombo);

   // The two lists stay in step by construction: one append each, in the same
   // call, and nothing else appends to either.
   aCombo.Items.Add(aText);
   tags.Add(aTag);
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

procedure AddListItem(const aList: TListBox; const aText, aTag: string);
begin
   aList.Items.Add(aText);
   TagsOf(aList).Add(aTag);
end;

procedure ClearListItems(const aList: TListBox);
begin
   // BOTH lists, always together -- they are only ever in step because every
   // mutation goes through this unit.
   aList.Items.Clear;
   TagsOf(aList).Clear;
end;

{ The combo equivalent, and its absence was a real defect.

  TListBox had ClearListItems from the start; TComboBox did not, so four call
  sites cleared the combo directly -- cbxType, cbxPort, cbxKeyerPort and the
  discovery result cbxFound. `TComboBox.Clear` empties Items and knows nothing
  about the parallel tag list, so every repopulation left the tags one full
  generation longer than the items.

  What that costs is not a crash: SelectedTag indexes the TAG list by ItemIndex,
  and the guard there only checks the index is in range. After one repopulation
  the ranges still overlap, so it returns a STALE TAG from the previous fill --
  the wrong radio, the wrong COM port, the wrong discovered address, silently and
  plausibly. Repopulate the radio-type combo a few times and the tag list is
  hundreds of entries long while the combo shows twenty.

  Everything that empties a tagged combo must come through here. }
procedure ClearComboItems(const aCombo: TComboBox);
begin
   aCombo.Items.Clear;
   TagsOf(aCombo).Clear;
end;

function SelectedListTag(const aList: TListBox): string;
var
   tags: TStringList;
begin
   Result := '';
   tags := TagsOf(aList);
   if (aList.ItemIndex >= 0) and (aList.ItemIndex < tags.Count) then
      begin
      Result := tags[aList.ItemIndex];
      end;
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
   i: integer;
   tags: TStringList;
begin
   tags := TagsOf(aCombo);
   for i := 0 to tags.Count - 1 do
      begin
      if SameText(tags[i], aTag) then
         begin
         aCombo.ItemIndex := i;
         Exit;
         end;
      end;
   if aCombo.Items.Count > 0 then
      begin
      aCombo.ItemIndex := 0;
      end;
end;

function HasTag(const aCombo: TComboBox; const aTag: string): boolean;
var
   i: integer;
   tags: TStringList;
begin
   Result := False;
   tags := TagsOf(aCombo);
   for i := 0 to tags.Count - 1 do
      begin
      if SameText(tags[i], aTag) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function SelectedTag(const aCombo: TComboBox): string;
var
   tags: TStringList;
begin
   Result := '';
   tags := TagsOf(aCombo);
   // Guarded against the TAG list, not just ItemIndex: a caller that filled
   // Items directly instead of through AddComboItem would otherwise index a
   // shorter tag list and raise.
   if (aCombo.ItemIndex >= 0) and (aCombo.ItemIndex < tags.Count) then
      begin
      Result := tags[aCombo.ItemIndex];
      end;
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

// The 'SERIAL n' vocabulary CFGCA expects, from a Windows 'COMn' name.  Kept
// here rather than in the store: the store holds whatever string the UI chose,
// and the translation is a presentation concern.
function ComNameToPortValue(const aComName: string): string;
var
   n: integer;
begin
   n := ComPortNumber(aComName);
   if n > 0 then
      begin
      Result := 'SERIAL ' + IntToStr(n);
      end
   else
      begin
      Result := PORT_NONE;
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
   aCombo.Clear;
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
   aCombo.Clear;
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

{ =========================================================== TRadioEditForm = }


class function TStopwatch.StartNew: TStopwatch;
begin
   Result.FStart := GetTickCount64;
end;

function TStopwatch.ElapsedMilliseconds: Int64;
begin
   Result := Int64(GetTickCount64 - FStart);
end;


initialization

finalization
   FreeAndNil(gNavNodeFactory);

end.
