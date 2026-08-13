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
unit uFMXFormHelpers;
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
  the vocabulary helpers (AddComboItem, SelectByTag, SelectedTag) do not: a
  combo whose items depend on which COM ports are plugged in cannot be designed,
  and TagString-not-index stays a correctness rule either way.
}

interface

uses
   Classes,
   System.UITypes,
   FMX.Types,
   FMX.Controls,
   FMX.StdCtrls,
   FMX.Edit,
   FMX.ListBox,
   FMX.Controls.Presentation;

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
   // A TTabItem's children sit inside the tab's own content area, so they need
   // only a small margin -- the tab strip is not part of it.
   TABTOP     = 12;
   // What the tab strip itself takes out of the control's height.
   TABSTRIP   = 36;

function AddComboItem(const aCombo: TComboBox; const aText, aTag: string): TListBoxItem;
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
// TTabItem it sits on is simply absent from the resource.  Own everything from
// the form; parent it wherever the layout wants it.
//
// aName is what the streamer keys on -- an unnamed control cannot be written to
// a .fmx or addressed in the designer.  '' is accepted for forms not yet being
// converted.
function MakeLabel(const aOwner: TComponent; const aParent: TFmxObject;
                   const aName, aText: string;
                   const aX, aY, aWidth: single): TLabel;
function MakeRadio(const aOwner: TComponent; const aParent: TFmxObject;
                   const aName, aText, aGroup: string;
                   const aX, aY, aWidth: single): TRadioButton;
function MakeButton(const aOwner: TComponent; const aParent: TFmxObject;
                    const aName, aText: string;
                    const aX, aY, aWidth: single;
                    const aOnClick: TNotifyEvent;
                    const aAnchors: TAnchors = [TAnchorKind.akLeft,
                                                TAnchorKind.akTop]): TButton;
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
   SysUtils,
   StrUtils,
   uRadioConfigStore,
   uRadioRegistry,
   ComPortEnumerator,
   VC;

{ ------------------------------------------------------------- helpers ---- }

function AddComboItem(const aCombo: TComboBox; const aText, aTag: string): TListBoxItem;
begin
   Result := TListBoxItem.Create(aCombo);
   Result.Parent    := aCombo;
   // NOT STORED, and this is load-bearing rather than tidiness.
   // TCustomComboBox.GetChildren (FMX.ListBox.pas) writes every list item whose
   // Stored is True into the form resource.  These items are POPULATED AT
   // RUNTIME from the COM ports on this machine and the radios in the registry,
   // so persisting them would freeze one developer's hardware into the .fmx --
   // and it would do it silently, because a stale list looks exactly like a
   // fresh one.  The agreed split is that layout is designed and population is
   // code; this is what makes the streamer honour it.
   Result.Stored    := False;
   Result.Text      := aText;
   // The registry id / radio name travels in TagString, never as an index.
   // Index arithmetic against a list whose contents depend on what is plugged
   // in is how the legacy port combo grew its bugs.
   Result.TagString := aTag;
end;

// Select the item whose TagString matches, or the first item when it is absent.
procedure SelectByTag(const aCombo: TComboBox; const aTag: string);
var
   i: integer;
begin
   for i := 0 to aCombo.Items.Count - 1 do
      begin
      if SameText(aCombo.ListItems[i].TagString, aTag) then
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
begin
   Result := False;
   for i := 0 to aCombo.Items.Count - 1 do
      begin
      if SameText(aCombo.ListItems[i].TagString, aTag) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function SelectedTag(const aCombo: TComboBox): string;
begin
   Result := '';
   if (aCombo.ItemIndex >= 0) and (aCombo.ItemIndex < aCombo.Items.Count) then
      begin
      Result := aCombo.ListItems[aCombo.ItemIndex].TagString;
      end;
end;

// Named before anything else is assigned, so that if the name collides with one
// already used in this owner the failure is immediate and points at the control
// being created, not at some later property write.
procedure NameIt(const aControl: TFmxObject; const aName: string);
begin
   if aName <> '' then
      begin
      aControl.Name := aName;
      end;
end;

function MakeLabel(const aOwner: TComponent; const aParent: TFmxObject;
                   const aName, aText: string;
                   const aX, aY, aWidth: single): TLabel;
begin
   Result := TLabel.Create(aOwner);
   NameIt(Result, aName);
   Result.Parent     := aParent;
   Result.Position.X := aX;
   Result.Position.Y := aY;
   Result.Width      := aWidth;
   Result.Text       := aText;
end;

function MakeRadio(const aOwner: TComponent; const aParent: TFmxObject;
                   const aName, aText, aGroup: string;
                   const aX, aY, aWidth: single): TRadioButton;
begin
   Result := TRadioButton.Create(aOwner);
   NameIt(Result, aName);
   Result.Parent     := aParent;
   Result.Position.X := aX;
   Result.Position.Y := aY;
   Result.Width      := aWidth;
   Result.Text       := aText;
   // Explicit group, never the parent-derived default -- see the call site.
   Result.GroupName  := aGroup;
end;

// aAnchors defaults to FMX's own default, so every existing caller is unchanged.
// A FOOTER button must pass [akRight, akBottom]: positioning it once at
// ClientWidth/ClientHeight minus an offset places it correctly on a form that
// never resizes, and strands it in open space on one that does.  See the call
// sites for the two footers this bit (NY4I, 2026-08-05).
function MakeButton(const aOwner: TComponent; const aParent: TFmxObject;
                    const aName, aText: string;
                    const aX, aY, aWidth: single;
                    const aOnClick: TNotifyEvent;
                    const aAnchors: TAnchors = [TAnchorKind.akLeft,
                                                TAnchorKind.akTop]): TButton;
begin
   Result := TButton.Create(aOwner);
   NameIt(Result, aName);
   Result.Parent     := aParent;
   Result.Position.X := aX;
   Result.Position.Y := aY;
   Result.Width      := aWidth;
   Result.Height     := 25;
   Result.Text       := aText;
   Result.OnClick    := aOnClick;
   // Anchors are honoured only while Align is TAlignLayout.None, which is the
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

end.
