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
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uEditQSOForm;
{$I ..\..\tr4w.inc}

{
  THE EDIT QSO DIALOG, AS AN LCL FORM.  Phase 5 -- the densest form in TR4W,
  69 controls, and the only converted dialog that WRITES TO THE CONTEST LOG.

  THE .lfm WAS GENERATED, NOT TRANSCRIBED. Dialog 46 is one of only three that
  really have a resource template, and the template that SHIPS is the authority
  -- not res\Tr4w.rc, which is not a build input and is two features behind
  (see test\ui\Export-DialogTemplate.ps1, which measured that rather than
  assuming it). Every position, size, style bit and caption below came out of
  tr4w_eng.RES by machine, at the dialog manager's own conversion: x * 6/4 and
  y * 13/8 for MS Sans Serif 8. Nothing here was placed by eye.

  THE SAVE PATH WAS NOT REWRITTEN, AND THAT IS THE POINT (NY4I, approved).
  SaveQSOToEditableLog is ~340 lines that read the dialog and write the binary
  log. Rewriting it against named controls would be better code and a worse
  risk: a silent field mix-up there corrupts a contest log, and the log format
  is changing anyway when contest.sqlite lands. So the ids stay, and this unit
  supplies EditQSOGetText / GetInt / GetCheck against the SAME numbers the
  Win32 dialog used. The save function changed only its accessor calls, so it
  still diffs line for line.

  ALL 69 IDS ARE IN ONE TABLE, EDITQSO_FIELDS, and that table is the single
  point of coupling between an id and a control. Build\Lint-EditQSOTemplate.ps1
  checks it against the resource in three directions -- template, table, .lfm --
  so a dropped control or a typo'd id fails the build instead of quietly
  reading the wrong box.

  THE STYLE BITS ENCODE AN INVARIANT NOBODY WROTE DOWN. Of the ten check boxes,
  exactly three are BS_AUTOCHECKBOX -- S&P (125), Deleted (132) and X-QSO (170)
  -- and exactly those three are read back by the save path. The other seven
  (the four mult flags, Name Sent, Inhibit Mults, Dupe) are BS_CHECKBOX, which
  Windows does NOT toggle on click, and the save path never reads them. They
  are indicators, not inputs.

  That distinction is invisible in the LCL, where every TCheckBox toggles. So
  the seven carry Enabled = False. Without it an operator could tick "DX Mult",
  see it stick, and have it silently revert on reopen -- the UI lying about a
  scoring flag. Greyed is a visual change from the Win32 dialog and it is a
  deliberate one; the alternative was a control that accepts input it discards.

  THE RST FIELDS REFUSE A MINUS SIGN, AND THAT STAYS -- with a reason now.
  Both are ES_NUMBER in the template while the code writes them with
  tSetDlgItemIntSigned, and someone left a comment in WM_INITDIALOG saying the
  field ought not to be numeric "so the user can enter a negative". It is
  reproduced as-is (NumbersOnly = True).

  NOT because it does not matter -- NY4I confirms it has been a real nuisance --
  but because widening RST is the WRONG FIX. A negative "RST" is a WSJT-X signal
  report in dB, which is not a readability-strength-tone value at all; cramming
  it into the RST field overloads one column with two different measurements and
  leaves neither well defined. The right shape is a RECEIVED SNR and a SENT SNR
  of their own, populated from WSJT-X. That is a log SCHEMA change, so it belongs
  to contest.sqlite and not to a dialog conversion (NY4I, 2026-08-19).

  So: do not "fix" this by dropping NumbersOnly. It would let an operator type a
  dB figure into a field that means something else, into a log format that is
  about to be replaced.
}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, DateTimePicker,
  LCLType,
  uTR4WStrings,
  uQsoMyFacts,   // TQsoMyFacts -- our station as recorded for the QSO
  uExternalDelivery;  // TDeliveryStatus -- the read-only delivery line

type
  TfrmEditQSO = class(TForm)
    lblCallsign, lblCountryName, lblRadio, lblBand, lblDX, lblMode,
      lblDomestic, lblFrequency, lblPrefix, lblDate, lblZone, lblName,
      lblComputerID, lblQTH, lblQSOPoints, lblPostalCode, lblAge, lblPower,
      lblChapter, lblPrecedence, lblCheck, lblPrefecture, lblClass, lblTenTen,
      lblNumberSent, lblRSTSent, lblNumberRcvd, lblRSTReceived,
      lblOperator: TLabel;

    edtCallsign, edtDXQTH, edtDomMultQTH, edtFrequency, edtPrefix, edtZone,
      edtName, edtComputerID, edtQTHString, edtQSOPoints, edtPostalCode,
      edtAge, edtPower, edtChapter, edtPrecedence, edtCheck, edtPrefecture,
      edtClass, edtTenTen, edtNumberSent, edtRSTSent, edtNumberReceived,
      edtRSTReceived, edtOperator: TEdit;

    cboBand, cboMode: TComboBox;

    chkDXMult, chkDomesticMult, chkPrefixMult, chkZoneMult, chkNameSent,
      chkInhibitMults, chkDupe, chkDeleted, chkSAP, chkXQSO: TCheckBox;

    dtpDateTime: TDateTimePicker;

    // OUR STATION AS RECORDED FOR THIS QSO -- log schema 3 (NY4I, ruling B).
    // NOT in EDITQSO_FIELDS: these are read and written BY NAME, through
    // EditQSOShowMyFacts / EditQSOReadMyFacts, which is how a new control on
    // this form is written. The id table is the Win32 save path's, and these
    // never had an id.
    grpMyStation: TGroupBox;
    lblMyCall, lblMyGrid, lblMyState, lblMyCounty, lblMySection, lblMyPark,
      lblMyCQZone, lblMyITUZone: TLabel;
    edtMyCall, edtMyGrid, edtMyState, edtMyCounty, edtMySection, edtMyPark,
      edtMyCQZone, edtMyITUZone: TEdit;

    // WHERE AN EXTERNAL LOGGER STANDS WITH THIS QSO -- read-only, by name,
    // through EditQSOShowDelivery. A label: it raises no OnChange, so it can
    // never enable Save, which is this dialog's dirty flag.
    lblDelivery: TLabel;

    btnSave, btnCancel: TButton;

    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure HandleCloseQuery(Sender: TObject; var CanClose: boolean);
    function  ConfirmSave: boolean;
    procedure FieldChanged(Sender: TObject);
    procedure CallsignChanged(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  public
    (* LAY THE FIELDS OUT FROM WHAT THE TEXT AND THE CONTROLS MEASURE -- see
       "THE LAYOUT IS MEASURED" in the implementation. Idempotent: every
       position is computed from scratch, so calling it on every show (the
       form is hidden and reused) moves nothing that already fits. Public for
       the layout test, which calls it on a form shown off screen. *)
    procedure FitLayout;
    (* The form's height follows its last visible control: the our-station
       group, or the delivery line under it when that is shown. *)
    procedure FitHeightToContent;
    (* THE BAND AND MODE LISTS, REPLACED -- never appended to (issue 237). The
       load calls this on every open, through EditQSOFillBandAndModeLists. *)
    procedure FillBandAndModeLists;
  end;

(* The room a drop-down's chrome takes beside its text is
   uLCLFormHelpers.DROPDOWN_CHROME_96, lifted from here when the External
   logger editor became its second user (issue 232). *)

type
  // One row per control in dialog 46. The Id is the Win32 control id the save
  // path still speaks; the Name is the component in the .lfm.
  TEditQSOField = record
     Id:   integer;
     Name: string;
  end;

const
  EDITQSO_FIELDS: array[0..67] of TEditQSOField = (
     (Id: 101; Name: 'lblBand'),
     (Id: 102; Name: 'lblCallsign'),
     (Id: 103; Name: 'lblComputerID'),
     (Id: 104; Name: 'lblDate'),
     (Id: 106; Name: 'edtFrequency'),
     (Id: 107; Name: 'lblMode'),
     (Id: 108; Name: 'edtRSTReceived'),
     (Id: 109; Name: 'lblNumberSent'),
     (Id: 110; Name: 'lblQSOPoints'),
     (Id: 111; Name: 'lblRSTSent'),
     (Id: 112; Name: 'cboBand'),
     (Id: 113; Name: 'cboMode'),
     (Id: 114; Name: 'lblRadio'),
     (Id: 115; Name: 'lblCountryName'),
     (Id: 116; Name: 'edtNumberSent'),
     (Id: 117; Name: 'edtComputerID'),
     (Id: 118; Name: 'edtCallsign'),
     (Id: 119; Name: 'edtRSTSent'),
     (Id: 120; Name: 'edtTenTen'),
     (Id: 121; Name: 'edtPrefecture'),
     (Id: 122; Name: 'edtQSOPoints'),
     (Id: 123; Name: 'btnSave'),
     (Id: 124; Name: 'btnCancel'),
     (Id: 125; Name: 'chkSAP'),
     (Id: 126; Name: 'chkZoneMult'),
     (Id: 127; Name: 'chkPrefixMult'),
     (Id: 128; Name: 'chkNameSent'),
     (Id: 129; Name: 'chkDomesticMult'),
     (Id: 130; Name: 'chkDupe'),
     (Id: 132; Name: 'chkDeleted'),
     (Id: 133; Name: 'edtClass'),
     (Id: 134; Name: 'lblAge'),
     (Id: 135; Name: 'lblCheck'),
     (Id: 136; Name: 'edtAge'),
     (Id: 137; Name: 'lblClass'),
     (Id: 138; Name: 'edtChapter'),
     (Id: 139; Name: 'lblNumberRcvd'),
     (Id: 140; Name: 'lblChapter'),
     (Id: 141; Name: 'edtCheck'),
     (Id: 142; Name: 'edtPrecedence'),
     (Id: 143; Name: 'chkInhibitMults'),
     (Id: 144; Name: 'edtPower'),
     (Id: 145; Name: 'lblFrequency'),
     (Id: 146; Name: 'edtNumberReceived'),
     (Id: 147; Name: 'lblDomestic'),
     (Id: 148; Name: 'edtDXQTH'),
     (Id: 149; Name: 'lblPrefix'),
     (Id: 150; Name: 'edtDomMultQTH'),
     (Id: 151; Name: 'lblZone'),
     (Id: 152; Name: 'edtPrefix'),
     (Id: 153; Name: 'lblName'),
     (Id: 154; Name: 'edtZone'),
     (Id: 155; Name: 'lblQTH'),
     (Id: 156; Name: 'chkDXMult'),
     (Id: 157; Name: 'lblDX'),
     (Id: 158; Name: 'edtName'),
     (Id: 159; Name: 'lblPostalCode'),
     (Id: 160; Name: 'edtQTHString'),
     (Id: 161; Name: 'lblPower'),
     (Id: 162; Name: 'edtPostalCode'),
     (Id: 163; Name: 'lblPrecedence'),
     (Id: 164; Name: 'lblPrefecture'),
     (Id: 165; Name: 'lblTenTen'),
     (Id: 166; Name: 'lblRSTReceived'),
     (Id: 167; Name: 'edtOperator'),
     (Id: 168; Name: 'lblOperator'),
     (Id: 170; Name: 'chkXQSO'),
     (Id: 180; Name: 'dtpDateTime'));

// ----------------------------------------------------------------------------
// THE ACCESSOR SHIM.  These stand in for GetDialogItemText / GetDlgItemInt /
// SendDlgItemMessage(BM_GETCHECK) so the save and load paths keep speaking in
// control ids.  Every one of them is a no-op (or a benign zero) when the form
// is not up, because the old code could not be called then either.
// ----------------------------------------------------------------------------
function  EditQSOGetText(const aId: integer): string;
procedure EditQSOSetText(const aId: integer; const aText: string);
function  EditQSOGetInt(const aId: integer; out aTranslated: boolean): integer;
procedure EditQSOSetInt(const aId: integer; const aValue: integer);
function  EditQSOGetCheck(const aId: integer): boolean;
procedure EditQSOSetCheck(const aId: integer; const aValue: boolean);
procedure EditQSOSetEnabled(const aId: integer; const aEnabled: boolean);
function  EditQSOGetItemIndex(const aId: integer): integer;
procedure EditQSOSetItemIndex(const aId: integer; const aIndex: integer);
procedure EditQSOAddItem(const aId: integer; const aText: string);
procedure EditQSOClearItems(const aId: integer);
procedure EditQSOFillBandAndModeLists;
function  EditQSOGetDateTime: TDateTime;
procedure EditQSOSetDateTime(const aValue: TDateTime);
procedure EditQSOSetFocusTo(const aId: integer);
procedure EditQSOCloseForm;

// OUR STATION AS RECORDED -- shown, and read back. A no-op (and aShown back)
// when the form is not up. The read returns aShown with the typed values in
// place of the shown ones: the fields the form does not show (IOTA, country,
// continent) and the source are carried through untouched.
procedure EditQSOShowMyFacts(const aFacts: TQsoMyFacts);
function  EditQSOReadMyFacts(const aShown: TQsoMyFacts): TQsoMyFacts;

// THE EXTERNAL-LOGGER DELIVERY LINE, under the our-station group. Shown only
// when the QSO has a delivery row (aStatus.Logger <> ''), hidden otherwise,
// and the form's height follows it. A no-op when the form is not up.
procedure EditQSOShowDelivery(const aStatus: TDeliveryStatus);
// What that line says -- pure, so the tests pin every state.
function  EditQSODeliveryText(const aStatus: TDeliveryStatus): string;
// The window a message box should be parented on. 0 when the form is not up,
// which is what MessageBox wants for "no owner" anyway.

// HEADLESS FIELD ROUND-TRIP.  Puts a probe value into every input control and
// reads it straight back, reporting any that does not survive. Returns the
// number of failures and appends one line each to aReport.
//
// THIS EXISTS BECAUSE A LINT CANNOT SEE THIS CLASS OF DEFECT. Lint-EditQSOTemplate
// proves the WIRING -- that every id reaches the control it should. It cannot
// prove that a VALUE survives the trip, and the MaxLength truncation (4f0339d4)
// was exactly that: correct wiring, correct-looking .lfm, and a callsign
// silently shortened on its way into the log. It only manifested once the
// control had a window handle, so this forces handles rather than testing a
// form that was never realised.
function EditQSOFieldRoundTrip(aReport: TStrings): integer;

// The /FIELDCHECK entry point: runs the round-trip, writes the report into the
// working directory, and returns the failure count as a process exit code.
function RunEditQSOFieldCheck: integer;

// the Edit QSO window.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.  The HWND parameter survives because the caller varies
// -- the main window, Log Edit and Log Search each open this over themselves.

procedure ShowEditQSO;

implementation

{$R *.lfm}

uses
  // FIRST, so every unit below still wins any name it shares (this tree
  // resolves a name to the LAST unit declaring it).
  uAppStrings,        // SEditQSODelivery*, SEditQSOMy* -- the our-station group
  Math,               // Max -- the measured layout
  DateUtils,         // UnixToDateTime -- the delivery line's time
  uEditQSO,           // the load and save halves, which stayed put
  uLCLFormHelpers,    // ShowModalOverWin32Parent; TextWidthInFont, WidestText
  MainUnit,           // logger
  uSettingsModel,     // Settings.Log.ConfirmEditChanges
  uDialogs,           // YesOrNo
  VC,                 // TC_SAVECHANGES
  Log4D;

var
  frmEditQSO: TfrmEditQSO = nil;

// ---------------------------------------------------------------- resolution
// Looked up by name through FindComponent rather than a second hand-written
// array of references: the .lfm already names them, and one table that can
// drift is enough.
function FieldControl(const aId: integer): TControl;
var
  i: integer;
  c: TComponent;
begin
   Result := nil;
   if frmEditQSO = nil then
      begin
      Exit;
      end;

   for i := Low(EDITQSO_FIELDS) to High(EDITQSO_FIELDS) do
      begin
      if EDITQSO_FIELDS[i].Id = aId then
         begin
         c := frmEditQSO.FindComponent(EDITQSO_FIELDS[i].Name);
         if c is TControl then
            begin
            Result := TControl(c);
            end;
         Exit;
         end;
      end;
end;

function EditQSOGetText(const aId: integer): string;
var
  c: TControl;
begin
   Result := '';
   c := FieldControl(aId);

   if c is TCustomEdit then
      begin
      Result := TCustomEdit(c).Text;
      end
   else if c is TCustomComboBox then
      begin
      Result := TCustomComboBox(c).Text;
      end
   else if c is TLabel then
      begin
      Result := TLabel(c).Caption;
      end;
end;

// MAXLENGTH MUST NOT APPLY TO A LOAD, ONLY TO TYPING -- and that is not what
// the LCL does by default.
//
// The .lfm carries MaxLength for the fields the Win32 dialog limited with
// EM_SETLIMITTEXT. Those are not the same thing. EM_SETLIMITTEXT constrains what
// the OPERATOR can type and has no effect on SetDlgItemText, so the old dialog
// happily displayed a value longer than the limit. An LCL TEdit truncates on
// assignment once it has a handle -- measured, not assumed: MaxLength 12, assign
// 15 characters, and Text is 12 the moment the handle exists (it is 15 before).
//
// Left alone that is SILENT DATA LOSS IN THE CONTEST LOG: a record whose
// callsign is longer than the limit would load short and be saved short, with
// nothing to show for it. So a programmatic set lifts the limit for the
// assignment and puts it straight back, which reproduces the Win32 split
// exactly -- unrestricted load, restricted typing.
procedure EditQSOSetText(const aId: integer; const aText: string);
var
  c: TControl;
  saved: integer;
begin
   c := FieldControl(aId);

   if c is TCustomEdit then
      begin
      saved := TCustomEdit(c).MaxLength;
      try
         TCustomEdit(c).MaxLength := 0;
         TCustomEdit(c).Text := aText;
      finally
         TCustomEdit(c).MaxLength := saved;
      end;
      end
   else if c is TLabel then
      begin
      TLabel(c).Caption := aText;
      end;
end;

// The Win32 original asked GetDlgItemInt, which reports whether the box held a
// number at all.  Callers branch on that, so the out parameter is not optional
// decoration -- an empty field must read as "not translated", never as 0.
function EditQSOGetInt(const aId: integer; out aTranslated: boolean): integer;
var
  s: string;
  v: integer;
begin
   Result := 0;
   aTranslated := False;

   s := Trim(EditQSOGetText(aId));
   if s = '' then
      begin
      Exit;
      end;

   if TryStrToInt(s, v) then
      begin
      Result := v;
      aTranslated := True;
      end;
end;

procedure EditQSOSetInt(const aId: integer; const aValue: integer);
begin
   EditQSOSetText(aId, IntToStr(aValue));
end;

function EditQSOGetCheck(const aId: integer): boolean;
var
  c: TControl;
begin
   Result := False;
   c := FieldControl(aId);

   if c is TCheckBox then
      begin
      Result := TCheckBox(c).Checked;
      end;
end;

procedure EditQSOSetCheck(const aId: integer; const aValue: boolean);
var
  c: TControl;
begin
   c := FieldControl(aId);

   if c is TCheckBox then
      begin
      TCheckBox(c).Checked := aValue;
      end;
end;

procedure EditQSOSetEnabled(const aId: integer; const aEnabled: boolean);
var
  c: TControl;
begin
   c := FieldControl(aId);
   if c <> nil then
      begin
      c.Enabled := aEnabled;
      end;
end;

function EditQSOGetItemIndex(const aId: integer): integer;
var
  c: TControl;
begin
   Result := -1;
   c := FieldControl(aId);

   if c is TCustomComboBox then
      begin
      Result := TCustomComboBox(c).ItemIndex;
      end;
end;

procedure EditQSOSetItemIndex(const aId: integer; const aIndex: integer);
var
  c: TControl;
begin
   c := FieldControl(aId);

   if c is TCustomComboBox then
      begin
      if (aIndex >= 0) and (aIndex < TCustomComboBox(c).Items.Count) then
         begin
         TCustomComboBox(c).ItemIndex := aIndex;
         end;
      end;
end;

procedure EditQSOAddItem(const aId: integer; const aText: string);
var
  c: TControl;
begin
   c := FieldControl(aId);

   if c is TCustomComboBox then
      begin
      TCustomComboBox(c).Items.Add(aText);
      end;
end;

procedure EditQSOClearItems(const aId: integer);
var
  c: TControl;
begin
   c := FieldControl(aId);

   if c is TCustomComboBox then
      begin
      TCustomComboBox(c).Items.Clear;
      end;
end;

(* ISSUE 237: THE LISTS WERE APPENDED TO ON EVERY OPEN. The form is hidden on
  close and reused, and the load added every band and every mode each time
  without clearing, so the second open listed each band twice -- and Save
  reads BandType(ItemIndex), so a band picked from the second copy was a
  value past the end of the enum, on its way into the contest log.

  The data is now replaced in the control, so the item index IS the enum
  ordinal on every open. One BeginUpdate per list: Items proxies the widget. *)
procedure TfrmEditQSO.FillBandAndModeLists;
var
  bt: BandType;
  m: ExtendedModeType;
begin
   cboBand.Items.BeginUpdate;
   try
      cboBand.Items.Clear;
      for bt := Low(BandType) to High(BandType) do
         begin
         cboBand.Items.Add(UTF8Encode(BandStringsArrayWithOutSpaces[bt]));
         end;
   finally
      cboBand.Items.EndUpdate;
   end;

   cboMode.Items.BeginUpdate;
   try
      cboMode.Items.Clear;
      for m := Low(ExtendedModeType) to High(ExtendedModeType) do
         begin
         cboMode.Items.Add(UTF8Encode(ExtendedModeStringArray[m]));
         end;
   finally
      cboMode.Items.EndUpdate;
   end;
end;

procedure EditQSOFillBandAndModeLists;
begin
   if frmEditQSO <> nil then
      begin
      frmEditQSO.FillBandAndModeLists;
      end;
end;

function EditQSOGetDateTime: TDateTime;
begin
   Result := 0;
   if frmEditQSO <> nil then
      begin
      Result := frmEditQSO.dtpDateTime.DateTime;
      end;
end;

procedure EditQSOSetDateTime(const aValue: TDateTime);
begin
   if frmEditQSO <> nil then
      begin
      frmEditQSO.dtpDateTime.DateTime := aValue;
      end;
end;

procedure EditQSOSetFocusTo(const aId: integer);
var
  c: TControl;
begin
   c := FieldControl(aId);

   if (c is TWinControl) and TWinControl(c).CanFocus then
      begin
      TWinControl(c).SetFocus;
      end;
end;

procedure EditQSOCloseForm;
begin
   if frmEditQSO <> nil then
      begin
      frmEditQSO.Close;
      end;
end;

// ------------------------------------------------- our station, as recorded
// A zone of 0 is "unknown", and shows as an empty field, not as "0".
// AnsiString, the type of the control's Text and of the RTL's IntToStr, so
// nothing converts on the way in.
function ZoneText(aZone: integer): AnsiString;
begin
   Result := '';
   if aZone > 0 then
      begin
      Result := IntToStr(aZone);
      end;
end;

procedure EditQSOShowMyFacts(const aFacts: TQsoMyFacts);
begin
   if frmEditQSO = nil then
      begin
      Exit;
      end;

   // WHERE THE VALUES CAME FROM IS SAID IN THE CAPTION, because an empty
   // field means two different things: on a row recorded before log schema 3
   // nothing was recorded at all, and on any other it is unknown. A peer's
   // QSO carries this station's values, assumed.
   case aFacts.Source of
      mfsNotCaptured:
         begin
         frmEditQSO.grpMyStation.Caption := SEditQSOMyStationNotRecorded;
         end;
      mfsAssumed:
         begin
         frmEditQSO.grpMyStation.Caption := SEditQSOMyStationAssumed;
         end;
      else
         begin
         frmEditQSO.grpMyStation.Caption := SEditQSOMyStation;
         end;
   end;

   frmEditQSO.edtMyCall.Text := aFacts.Call;
   frmEditQSO.edtMyGrid.Text := aFacts.Grid;
   frmEditQSO.edtMyState.Text := aFacts.State;
   frmEditQSO.edtMyCounty.Text := aFacts.County;
   frmEditQSO.edtMySection.Text := aFacts.Section;
   frmEditQSO.edtMyPark.Text := aFacts.Park;
   frmEditQSO.edtMyCQZone.Text := ZoneText(aFacts.CQZone);
   frmEditQSO.edtMyITUZone.Text := ZoneText(aFacts.ITUZone);
end;

function EditQSOReadMyFacts(const aShown: TQsoMyFacts): TQsoMyFacts;
begin
   Result := aShown;
   if frmEditQSO = nil then
      begin
      Exit;
      end;

   Result.Call := Trim(frmEditQSO.edtMyCall.Text);
   Result.Grid := Trim(frmEditQSO.edtMyGrid.Text);
   Result.State := Trim(frmEditQSO.edtMyState.Text);
   Result.County := Trim(frmEditQSO.edtMyCounty.Text);
   Result.Section := Trim(frmEditQSO.edtMySection.Text);
   Result.Park := Trim(frmEditQSO.edtMyPark.Text);
   // An empty or unreadable zone is unknown, 0 -- never a guess.
   Result.CQZone := StrToIntDef(Trim(frmEditQSO.edtMyCQZone.Text), 0);
   Result.ITUZone := StrToIntDef(Trim(frmEditQSO.edtMyITUZone.Text), 0);
end;

// --------------------------------------------- the external-logger delivery
// The stored state words (uLogSchema's CHECK) in the operator's words -- the
// same ones the Preferences delivery summary uses. A state this build does
// not know is shown as stored rather than hidden.
function DeliveryStateText(const aStatus: TDeliveryStatus): string;
begin
   if aStatus.State = 'pending' then
      begin
      Result := SEditQSODeliveryPending;
      end
   else if aStatus.State = 'inflight' then
      begin
      Result := SEditQSODeliverySending;
      end
   else if aStatus.State = 'synced' then
      begin
      Result := SEditQSODeliverySynced;
      end
   else if aStatus.State = 'uncertain' then
      begin
      Result := SEditQSODeliveryUncertain;
      end
   else if aStatus.State = 'failed' then
      begin
      if aStatus.ErrorCode <> '' then
         begin
         Result := UnicodeFormat(SEditQSODeliveryFailedWithCode, [aStatus.ErrorCode]);
         end
      else
         begin
         Result := SEditQSODeliveryFailed;
         end;
      end
   else
      begin
      Result := aStatus.State;
      end;
end;

// LastSent is Unix seconds UTC; UnixToDateTime converts nothing by default,
// so the time shown is UTC and says so. The colon is QUOTED: a bare ':' in
// FormatDateTime is the locale's TimeSeparator, which is '.' on some
// stations, and a UTC stamp should read the same everywhere.
function EditQSODeliveryText(const aStatus: TDeliveryStatus): string;
var
  sent: string;
begin
   if aStatus.LastSent > 0 then
      begin
      sent := UnicodeFormat(SEditQSODeliveryLastSent,
         [string(FormatDateTime('yyyy-mm-dd hh":"nn',
                                DateUtils.UnixToDateTime(aStatus.LastSent)))]);
      end
   else
      begin
      sent := SEditQSODeliveryNeverSent;
      end;
   Result := UnicodeFormat(SEditQSODeliveryLine,
                           [aStatus.Logger, DeliveryStateText(aStatus), sent]);
end;

procedure EditQSOShowDelivery(const aStatus: TDeliveryStatus);
begin
   if frmEditQSO = nil then
      begin
      Exit;
      end;

   // SET EVERY TIME, shown or hidden: the form is hidden on close and reused,
   // so a line left from the previous QSO would otherwise describe this one.
   frmEditQSO.lblDelivery.Visible := aStatus.Logger <> '';
   if frmEditQSO.lblDelivery.Visible then
      begin
      // UTF8Encode: the LCL's caption is a UTF-8 AnsiString, and an implicit
      // UTF-16 to Ansi conversion is a narrowing the build counts.
      frmEditQSO.lblDelivery.Caption := UTF8Encode(EditQSODeliveryText(aStatus));
      end;

   frmEditQSO.FitHeightToContent;
end;

// ------------------------------------------------------- the measured layout
(* THE LAYOUT IS MEASURED, NOT TYPED (NY4I, macOS, 2026-11-06).

  The .lfm positions came out of the Win32 dialog template, for MS Sans Serif
  8 at 96 dpi, and they are still there: the .lfm is the designer's picture
  and the field ids the save path speaks. What they cannot be is the layout on
  a platform whose fonts and native chrome are wider. On cocoa NY4I saw three
  defects, and each was one property:

    * BAND AND MODE SHOWED "10" AND "C". The combos inherit TCustomComboBox's
      AutoSize = True. Win32 reports no preferred width for a combo, so the
      designed 135 survived there; cocoa's read-only path reports the
      NSPopUpButton's fittingSize -- which the LCL's own comment says is
      wrong -- clamped to CocoaConfigComboBox.readOnly.minWidth, 38 px. A
      typed Width cannot fix that, because AutoSize overwrites it:
      Constraints.MinWidth is what holds.
    * THE DATE RAN INTO "ZONE". TDateTimePicker is AutoSize too, and its
      preferred width is its own text plus its arrow button in the running
      font -- honest, and wider than 135 on cocoa, while lblZone sat at a
      fixed 240. The picker is not fought: its own width is measured, and the
      next column starts after it.
    * LABELS WERE CLIPPED: AutoSize = False at fixed widths of 75, 90 and 52.

  SO THE FIELDS ARE A GRID, and every column is as wide as the widest thing in
  it: a label's caption measured in its own font (TextWidthInFont), a
  drop-down's longest item plus DROPDOWN_CHROME_96, and whatever any other
  control's widget set says it prefers (GetPreferredSize -- the picker, the
  check boxes, the buttons). The designed widths are FLOORS, so on Windows at
  100% the window looks as it did unless something no longer fits. Rows are as
  tall as their tallest control, never less than the designed pitch.

  Every 96-dpi number is scaled through Scale96ToForm. The window may grow; it
  keeps its centre, so a first open is still centred over the main window and
  a window the operator moved stays where they put it. *)

type
  TFieldGrid = class
  private
    FColumns: integer;
    FCells: array of TControl;
    function RowCount: integer;
    function Cell(const aRow, aCol: integer): TControl;
  public
    ColLeft, ColWidth, RowTop, RowHeight: array of integer;
    constructor Create(const aColumns: integer);
    (* One row, left to right; nil is an empty cell. *)
    procedure AddRow(const aRow: array of TControl);
    (* Column widths and lefts. aGaps[i] is the space before column i. *)
    procedure Measure(const aLeft: integer; const aFloors, aGaps: array of integer;
                      const aLabelPad, aComboChrome: integer);
    (* Row tops and heights, then every cell placed in its cell. *)
    procedure Place(const aTop, aMinPitch, aRowGap, aMinRowHeight: integer);
    function Right: integer;
    function Bottom: integer;
  end;

(* What the widget set says a control would like to be is
   uLCLFormHelpers.ControlPreferredSize, lifted from here (issue 232). *)
function FieldNeedWidth(const aControl: TControl;
                        const aLabelPad, aComboChrome: integer): integer;
var
  h: integer;
begin
   if aControl is TLabel then
      begin
      Result := TextWidthInFont(TLabel(aControl).Font, TLabel(aControl).Caption) +
                aLabelPad;
      Exit;
      end;

   ControlPreferredSize(aControl, Result, h);
   if aControl is TComboBox then
      begin
      Result := Max(Result, WidestText(TComboBox(aControl).Font,
                                       TComboBox(aControl).Items) + aComboChrome);
      end;
end;

constructor TFieldGrid.Create(const aColumns: integer);
begin
   inherited Create;
   FColumns := aColumns;
end;

function TFieldGrid.RowCount: integer;
begin
   Result := Length(FCells) div FColumns;
end;

function TFieldGrid.Cell(const aRow, aCol: integer): TControl;
begin
   Result := FCells[aRow * FColumns + aCol];
end;

procedure TFieldGrid.AddRow(const aRow: array of TControl);
var
  base, i: integer;
begin
   base := Length(FCells);
   SetLength(FCells, base + FColumns);
   for i := 0 to FColumns - 1 do
      begin
      if i <= High(aRow) then
         begin
         FCells[base + i] := aRow[i];
         end
      else
         begin
         FCells[base + i] := nil;
         end;
      end;
end;

procedure TFieldGrid.Measure(const aLeft: integer; const aFloors, aGaps: array of integer;
                             const aLabelPad, aComboChrome: integer);
var
  r, c, w: integer;
begin
   SetLength(ColLeft, FColumns);
   SetLength(ColWidth, FColumns);

   for c := 0 to FColumns - 1 do
      begin
      w := aFloors[c];
      for r := 0 to RowCount - 1 do
         begin
         if Cell(r, c) <> nil then
            begin
            w := Max(w, FieldNeedWidth(Cell(r, c), aLabelPad, aComboChrome));
            end;
         end;
      ColWidth[c] := w;

      if c = 0 then
         begin
         ColLeft[c] := aLeft;
         end
      else
         begin
         ColLeft[c] := ColLeft[c - 1] + ColWidth[c - 1] + aGaps[c];
         end;
      end;
end;

procedure TFieldGrid.Place(const aTop, aMinPitch, aRowGap, aMinRowHeight: integer);
var
  r, c, top, content, pw, ph, h: integer;
  ctl: TControl;
begin
   SetLength(RowTop, RowCount);
   SetLength(RowHeight, RowCount);
   top := aTop;

   for r := 0 to RowCount - 1 do
      begin
      (* The row is as tall as its tallest control. A label is not counted: it
         takes the row's height, and its Layout = tlCenter centres the text. *)
      content := aMinRowHeight;
      for c := 0 to FColumns - 1 do
         begin
         ctl := Cell(r, c);
         if (ctl <> nil) and not (ctl is TLabel) then
            begin
            ControlPreferredSize(ctl, pw, ph);
            content := Max(content, Max(ctl.Height, ph));
            end;
         end;
      RowTop[r] := top;
      RowHeight[r] := content;

      for c := 0 to FColumns - 1 do
         begin
         ctl := Cell(r, c);
         if ctl = nil then
            begin
            Continue;
            end;

         if ctl is TLabel then
            begin
            ctl.SetBounds(ColLeft[c], top, ColWidth[c], content);
            end
         else
            begin
            (* MinWidth AS WELL AS Width: an AutoSize control's widget set
               would otherwise put its own preferred width back -- which is
               the cocoa drop-down defect. Its height stays the widget set's;
               it is centred in the row. *)
            ControlPreferredSize(ctl, pw, ph);
            h := Max(ctl.Height, ph);
            ctl.Constraints.MinWidth := ColWidth[c];
            ctl.SetBounds(ColLeft[c], top + (content - h) div 2, ColWidth[c], h);
            end;
         end;

      top := top + Max(aMinPitch, content + aRowGap);
      end;
end;

function TFieldGrid.Right: integer;
begin
   Result := ColLeft[FColumns - 1] + ColWidth[FColumns - 1];
end;

function TFieldGrid.Bottom: integer;
begin
   Result := RowTop[RowCount - 1] + RowHeight[RowCount - 1];
end;

procedure TfrmEditQSO.FitHeightToContent;
var
  bottom: integer;
begin
   bottom := grpMyStation.Top + grpMyStation.Height;
   if lblDelivery.Visible then
      begin
      bottom := lblDelivery.Top + lblDelivery.Height;
      end;

   // The designed margin below the group (498 - 490), kept under whichever
   // control is last, so a QSO without a delivery row gets no empty band.
   ClientHeight := bottom + Scale96ToForm(8);
end;

procedure TfrmEditQSO.FitLayout;

   function Px(const a96: integer): integer;
   begin
      Result := Scale96ToForm(a96);
   end;

var
  fields, mine: TFieldGrid;
  oldW, oldH, centreX, centreY, groupNeed, frameW, frameH: integer;
  widths: string;
begin
   oldW := Width;
   oldH := Height;
   centreX := Left + oldW div 2;
   centreY := Top + oldH div 2;

   fields := TFieldGrid.Create(5);
   mine := TFieldGrid.Create(8);
   try
      (* label, field, label, field, indicator -- the designed rows, in order.
         The first row's middle is the country name, which spans both. *)
      fields.AddRow([lblCallsign,   edtCallsign,       nil,            nil,              lblRadio]);
      fields.AddRow([lblBand,       cboBand,           lblDX,          edtDXQTH,         chkDXMult]);
      fields.AddRow([lblMode,       cboMode,           lblDomestic,    edtDomMultQTH,    chkDomesticMult]);
      fields.AddRow([lblFrequency,  edtFrequency,      lblPrefix,      edtPrefix,        chkPrefixMult]);
      fields.AddRow([lblDate,       dtpDateTime,       lblZone,        edtZone,          chkZoneMult]);
      fields.AddRow([nil,           nil,               lblName,        edtName,          chkNameSent]);
      fields.AddRow([lblComputerID, edtComputerID,     lblQTH,         edtQTHString,     chkInhibitMults]);
      fields.AddRow([lblQSOPoints,  edtQSOPoints,      lblPostalCode,  edtPostalCode,    chkDupe]);
      fields.AddRow([lblAge,        edtAge,            lblPower,       edtPower,         chkDeleted]);
      fields.AddRow([lblChapter,    edtChapter,        lblPrecedence,  edtPrecedence,    chkSAP]);
      fields.AddRow([lblCheck,      edtCheck,          lblPrefecture,  edtPrefecture,    chkXQSO]);
      fields.AddRow([lblClass,      edtClass,          lblTenTen,      edtTenTen,        nil]);
      fields.AddRow([lblNumberSent, edtNumberSent,     lblRSTSent,     edtRSTSent,       nil]);
      fields.AddRow([lblNumberRcvd, edtNumberReceived, lblRSTReceived, edtRSTReceived,   nil]);
      fields.AddRow([lblOperator,   edtOperator,       nil,            nil,              btnSave]);
      fields.AddRow([nil,           nil,               nil,            nil,              btnCancel]);

      (* The floors and gaps are the designed ones (.lfm): labels at 8 and 240,
         fields at 90 and 338, 135 wide, indicators at 480. *)
      fields.Measure(Px(8), [Px(75), Px(135), Px(90), Px(135), Px(90)],
                     [0, Px(7), Px(15), Px(8), Px(7)],
                     Px(2), Px(DROPDOWN_CHROME_96));
      fields.Place(Px(16), Px(24), Px(3), Px(17));

      lblCountryName.SetBounds(fields.ColLeft[2], fields.RowTop[0],
                               fields.ColLeft[3] + fields.ColWidth[3] - fields.ColLeft[2],
                               fields.RowHeight[0]);

      mine.AddRow([lblMyCall,    edtMyCall,    lblMyGrid, edtMyGrid,
                   lblMyState,   edtMyState,   lblMyCounty, edtMyCounty]);
      mine.AddRow([lblMySection, edtMySection, lblMyPark, edtMyPark,
                   lblMyCQZone,  edtMyCQZone,  lblMyITUZone, edtMyITUZone]);
      mine.Measure(Px(6), [Px(52), Px(76), Px(52), Px(76), Px(52), Px(76), Px(52), Px(76)],
                   [0, Px(2), Px(10), Px(2), Px(10), Px(2), Px(10), Px(2)],
                   Px(2), Px(DROPDOWN_CHROME_96));
      mine.Place(Px(4), Px(28), Px(4), Px(17));

      (* The group's frame, read from the group as it is now: the caption band
         and borders differ by widget set. *)
      frameW := grpMyStation.Width - grpMyStation.ClientWidth;
      frameH := grpMyStation.Height - grpMyStation.ClientHeight;
      groupNeed := Max(mine.Right + Px(6),
                       TextWidthInFont(grpMyStation.Font, grpMyStation.Caption) + Px(16)) +
                   frameW;

      ClientWidth := Max(fields.Right + Px(11), Px(8) + groupNeed + Px(8));

      grpMyStation.SetBounds(Px(8), fields.Bottom + Px(8), ClientWidth - Px(16),
                             mine.Bottom + Px(9) + frameH);
      lblDelivery.SetBounds(Px(8), grpMyStation.Top + grpMyStation.Height + Px(4),
                            ClientWidth - Px(16), Px(17));
      FitHeightToContent;

      widths := UnicodeFormat('%d/%d/%d/%d/%d', [fields.ColWidth[0], fields.ColWidth[1],
                                          fields.ColWidth[2], fields.ColWidth[3],
                                          fields.ColWidth[4]]);
   finally
      mine.Free;
      fields.Free;
   end;

   (* KEEP THE CENTRE. A first open was centred over the main window before
      OnShow (ShowModalOverWin32Parent), and a later one is where the operator
      left it; growing about the centre keeps both true. Unchanged size, no
      move -- which is what makes this safe to run on every show. *)
   if (Width <> oldW) or (Height <> oldH) then
      begin
      SetBounds(centreX - Width div 2, centreY - Height div 2, Width, Height);
      end;

   (* REPORTED, the NewContest "grew" diagnostic: which column set the width
      is what a bench screenshot cannot say. *)
   if (logger <> nil) and logger.IsDebugEnabled then
      begin
      logger.Debug('[EditQSO] layout: columns %s, form %dx%d (was %dx%d)',
                   [widths, Width, Height, oldW, oldH]);
      end;
end;

// ------------------------------------------------------------------- the form
// THE CAPTIONS OF THE OUR-STATION GROUP COME FROM uAppStrings, so they are
// translatable; the .lfm text is a designer placeholder (uServerLogForm's
// pattern). The group's own caption is set with the values, in
// EditQSOShowMyFacts, because it says where they came from.
procedure AssignMyStationCaptions(aForm: TfrmEditQSO);
begin
   aForm.lblMyCall.Caption := SEditQSOMyCall;
   aForm.lblMyGrid.Caption := SEditQSOMyGrid;
   aForm.lblMyState.Caption := SEditQSOMyState;
   aForm.lblMyCounty.Caption := SEditQSOMyCounty;
   aForm.lblMySection.Caption := SEditQSOMySection;
   aForm.lblMyPark.Caption := SEditQSOMyPark;
   aForm.lblMyCQZone.Caption := SEditQSOMyCQZone;
   aForm.lblMyITUZone.Caption := SEditQSOMyITUZone;
end;

procedure TfrmEditQSO.HandleShow(Sender: TObject);
begin
   AssignMyStationCaptions(Self);

   // LoadQSOIntoEditForm answers False for the records this dialog refuses to
   // edit -- a note, a skipped QSO, anything that is not rkQSO, or a log that
   // will not open.  The Win32 version expressed each of those as `goto 1`
   // into the WM_CLOSE arm; here they are one boolean.
   if not LoadQSOIntoEditForm then
      begin
      Close;
      Exit;
      end;

   (* AFTER the load, which fills the drop-downs, the radio label and the
      our-station caption the columns are measured from. *)
   FitLayout;

   // Save starts DISABLED and every field's OnChange turns it on, exactly as
   // the WM_COMMAND EN_CHANGE / CBN_SELCHANGE / BN_CLICKED arm did.
   //
   // This line said True, which is what the comment above it has always said it
   // should not (bench, NY4I 2026-08-20: "Save was already enabled upon dialog
   // open and I was prompted to save upon close even though I changed
   // nothing").  D7 enables it only from that message arm --
   // EnableWindowTrue(hwnddlg, FLD_SAVE_BUTTON) -- so this was a port
   // regression, not a design choice.
   //
   // AND IT IS THE DIRTY FLAG, which is why it is worth more than it looks:
   // the dialog has no other record of whether anything changed, and
   // HandleCloseQuery below asks this button whether to confirm.  Enabling it
   // on open did not just offer a pointless Save -- it destroyed the only
   // change-tracking the dialog has.
   btnSave.Enabled := False;
   EditQSOSetFocusTo(FLD_CALLSIGN);
end;

procedure TfrmEditQSO.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   Action := caHide;
   AfterEditQSOClosed;
end;

procedure TfrmEditQSO.FieldChanged(Sender: TObject);
begin
   btnSave.Enabled := True;
end;

procedure TfrmEditQSO.CallsignChanged(Sender: TObject);
begin
   // The country, prefix and DX QTH follow the callsign as it is typed. That
   // was the EN_CHANGE arm; it is one handler now because only one control
   // ever reached it.
   CallsignChangedInEditForm;
   btnSave.Enabled := True;
end;

// "Save changes?", when CONFIRM EDIT CHANGES asks for it. True to go ahead.
//
// ONE PLACE, because there are now two ways to reach a save -- the button, and
// answering Yes on the way out -- and the question must be asked once per
// operator action. It used to live inside SaveQSOToEditableLog; see the note
// there for why a routine that writes to the contest log should not be the one
// asking.
function TfrmEditQSO.ConfirmSave: boolean;
begin
   Result := (not Settings.Log.ConfirmEditChanges) or
             (YesOrNo(TC_SAVECHANGES) = IDyes);
end;

procedure TfrmEditQSO.btnSaveClick(Sender: TObject);
begin
   if not ConfirmSave then
      begin
      Exit;
      end;

   if SaveQSOToEditableLog then
      begin
      // Not dirty any more, so HandleCloseQuery does not ask a second time for
      // the same action. The button's enabled state IS the dirty flag.
      btnSave.Enabled := False;
      Close;
      end;
end;

procedure TfrmEditQSO.btnCancelClick(Sender: TObject);
begin
   // Nothing but Close: the confirmation belongs to HandleCloseQuery, which
   // covers Escape and the window's X as well. Asking here would leave the
   // other two routes silent, which is the state this replaced.
   Close;
end;

// Escape, Cancel and the window's X all arrive here -- Escape because
// btnCancel has Cancel = True in the .lfm, so it raises btnCancelClick.
//
// NEW BEHAVIOUR, and worth saying so plainly: D7 did NOT do this. Its WM_CLOSE
// was a bare EndDialog(hwnddlg, 0) and discarded silently. Requested by NY4I on
// the bench 2026-08-20 ("I do have edit confirm enabled so when I change a
// field and hit esc, I should be prompted"), and gated on the same
// CONFIRM EDIT CHANGES setting so an operator who turned it off still gets the
// old silent discard.
//
// It costs nothing to track because btnSave.Enabled already answers "has
// anything changed" -- provided OnShow leaves it False, which is what the
// regression above was about.
procedure TfrmEditQSO.HandleCloseQuery(Sender: TObject; var CanClose: boolean);
begin
   CanClose := True;

   if not btnSave.Enabled then
      begin
      // Nothing changed. Close without a word, exactly as before.
      Exit;
      end;

   if not Settings.Log.ConfirmEditChanges then
      begin
      Exit;
      end;

   if YesOrNo(TC_SAVECHANGES) = IDno then
      begin
      // Discard. This is the answer that throws the edits away, and it is the
      // one D7 gave silently.
      Exit;
      end;

   // Yes -- write it. A save that FAILS must not close: the operator would lose
   // the edit to a validation refusal they never saw resolved.
   CanClose := SaveQSOToEditableLog;
   if CanClose then
      begin
      btnSave.Enabled := False;
      end;
end;

// The probe for one edit box: longer than any limit it declares, so a limit
// that wrongly applies to a programmatic set shows up as a short read-back.
// Uppercase and digits only, because CharCase and NumbersOnly legitimately
// transform input and this routine is not testing those.
function ProbeFor(const aEdit: TCustomEdit): string;
const
  LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ';
  DIGITS  = '12345678901234567890123456789012345678901234567890';
var
  want: integer;
  src: string;
begin
   want := 20;
   if aEdit.MaxLength > 0 then
      begin
      want := aEdit.MaxLength + 5;
      end;

   if (aEdit is TEdit) and TEdit(aEdit).NumbersOnly then
      begin
      src := DIGITS;
      end
   else
      begin
      src := LETTERS;
      end;

   if want > Length(src) then
      begin
      want := Length(src);
      end;
   Result := Copy(src, 1, want);
end;

function EditQSOFieldRoundTrip(aReport: TStrings): integer;
var
  i: integer;
  c: TControl;
  name: string;
  probe, back: string;
  whenSet, whenBack: TDateTime;
begin
   Result := 0;

   if frmEditQSO = nil then
      begin
      frmEditQSO := TfrmEditQSO.Create(Application);
      end;

   // The truncation this exists to catch only happens once the control has a
   // handle, so realise the form and every child WITHOUT showing it.
   frmEditQSO.HandleNeeded;

   for i := Low(EDITQSO_FIELDS) to High(EDITQSO_FIELDS) do
      begin
      c := FieldControl(EDITQSO_FIELDS[i].Id);
      name := Format('%s (id %d)', [EDITQSO_FIELDS[i].Name, EDITQSO_FIELDS[i].Id]);

      if c = nil then
         begin
         aReport.Add(name + ': no control -- Lint-EditQSOTemplate should have caught this');
         Inc(Result);
         Continue;
         end;

      if c is TWinControl then
         begin
         TWinControl(c).HandleNeeded;
         end;

      if c is TCustomEdit then
         begin
         probe := ProbeFor(TCustomEdit(c));
         EditQSOSetText(EDITQSO_FIELDS[i].Id, probe);
         back := EditQSOGetText(EDITQSO_FIELDS[i].Id);

         if back <> probe then
            begin
            aReport.Add(Format('%s: set %d char(s) %s, read back %d %s',
              [name, Length(probe), QuotedStr(probe), Length(back), QuotedStr(back)]));
            Inc(Result);
            end;
         end
      else if c is TCheckBox then
         begin
         EditQSOSetCheck(EDITQSO_FIELDS[i].Id, True);
         if not EditQSOGetCheck(EDITQSO_FIELDS[i].Id) then
            begin
            aReport.Add(name + ': set True, read back False');
            Inc(Result);
            end;

         EditQSOSetCheck(EDITQSO_FIELDS[i].Id, False);
         if EditQSOGetCheck(EDITQSO_FIELDS[i].Id) then
            begin
            aReport.Add(name + ': set False, read back True');
            Inc(Result);
            end;
         end
      else if c is TCustomComboBox then
         begin
         EditQSOClearItems(EDITQSO_FIELDS[i].Id);
         EditQSOAddItem(EDITQSO_FIELDS[i].Id, 'ZERO');
         EditQSOAddItem(EDITQSO_FIELDS[i].Id, 'ONE');
         EditQSOAddItem(EDITQSO_FIELDS[i].Id, 'TWO');
         EditQSOSetItemIndex(EDITQSO_FIELDS[i].Id, 2);

         if EditQSOGetItemIndex(EDITQSO_FIELDS[i].Id) <> 2 then
            begin
            aReport.Add(Format('%s: set item index 2, read back %d',
              [name, EditQSOGetItemIndex(EDITQSO_FIELDS[i].Id)]));
            Inc(Result);
            end;
         end
      else if c is TDateTimePicker then
         begin
         // A date and a time together, which is the whole point of this field:
         // the defect it replaced showed only the hour.
         whenSet := EncodeDate(2024, 11, 23) + EncodeTime(23, 46, 17, 0);
         EditQSOSetDateTime(whenSet);
         whenBack := EditQSOGetDateTime;

         // One second of tolerance: the control stores whole seconds.
         if Abs(whenBack - whenSet) > (1 / (24 * 60 * 60)) then
            begin
            aReport.Add(Format('%s: set %s, read back %s',
              [name, FormatDateTime('yyyy-mm-dd hh:nn:ss', whenSet),
                     FormatDateTime('yyyy-mm-dd hh:nn:ss', whenBack)]));
            Inc(Result);
            end;
         end;
      // TLabel and TButton carry no operator value; nothing to round-trip.
      end;
end;

function RunEditQSOFieldCheck: integer;
var
  report: TStringList;
begin
   report := TStringList.Create;
   try
      try
         Result := EditQSOFieldRoundTrip(report);

         if Result = 0 then
            begin
            report.Insert(0, Format('OK: %d field(s) round-tripped.',
              [Length(EDITQSO_FIELDS)]));
            end
         else
            begin
            report.Insert(0, Format('FAIL: %d field(s) did not survive a set/get.',
              [Result]));
            end;
      except
         on E: Exception do
            begin
            // An exception here IS the finding, and the process must not exit 0
            // because the check never ran.
            report.Add('EXCEPTION: ' + E.ClassName + ': ' + E.Message);
            Result := -1;
            end;
      end;

      try
         report.SaveToFile('editqso-fieldcheck.txt');
      except
         // A report we cannot write does not change the verdict.
         on E: Exception do ;
      end;
   finally
      report.Free;
   end;
end;

procedure ShowEditQSO;
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmEditQSO = nil then
         begin
         frmEditQSO := TfrmEditQSO.Create(Application);
         end;

      // Every caller is still a raw Win32 window -- the main window, Log Edit
      // or Log Search -- and Screen.DisableForms walks LCL forms only, so
      // without this the parent stays clickable underneath a modal.
      ShowModalOverWin32Parent(frmEditQSO);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowEditQSO failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
