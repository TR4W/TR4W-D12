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
  LCLType, Windows;

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

    btnPlay, btnSave, btnCancel: TButton;

    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure FieldChanged(Sender: TObject);
    procedure CallsignChanged(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnPlayClick(Sender: TObject);
  end;

type
  // One row per control in dialog 46. The Id is the Win32 control id the save
  // path still speaks; the Name is the component in the .lfm.
  TEditQSOField = record
     Id:   integer;
     Name: string;
  end;

const
  EDITQSO_FIELDS: array[0..68] of TEditQSOField = (
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
     (Id: 180; Name: 'dtpDateTime'),
     (Id: 201; Name: 'btnPlay'));

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
function  EditQSOGetDateTime: TDateTime;
procedure EditQSOSetDateTime(const aValue: TDateTime);
procedure EditQSOSetFocusTo(const aId: integer);
procedure EditQSOCloseForm;
// The window a message box should be parented on. 0 when the form is not up,
// which is what MessageBox wants for "no owner" anyway.
function  EditQSOFormHandle: HWND;

// the Edit QSO window.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.  The HWND parameter survives because the caller varies
// -- the main window, Log Edit and Log Search each open this over themselves.
procedure ShowEditQSO(const aParent: HWND);

implementation

{$R *.lfm}

uses
  uEditQSO,           // the load and save halves, which stayed put
  uLCLFormHelpers,    // ShowModalOverWin32Parent -- every caller is still Win32
  uHostedFormWindows,
  MainUnit,           // logger
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

procedure EditQSOSetText(const aId: integer; const aText: string);
var
  c: TControl;
begin
   c := FieldControl(aId);

   if c is TCustomEdit then
      begin
      TCustomEdit(c).Text := aText;
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

function EditQSOFormHandle: HWND;
begin
   Result := 0;

   if frmEditQSO <> nil then
      begin
      Result := frmEditQSO.Handle;
      end;
end;

procedure EditQSOCloseForm;
begin
   if frmEditQSO <> nil then
      begin
      frmEditQSO.Close;
      end;
end;

// ------------------------------------------------------------------- the form
procedure TfrmEditQSO.HandleShow(Sender: TObject);
begin
   RegisterHostedFormHandle(Self.Handle);

   // LoadQSOIntoEditForm answers False for the records this dialog refuses to
   // edit -- a note, a skipped QSO, anything that is not rkQSO, or a log that
   // will not open.  The Win32 version expressed each of those as `goto 1`
   // into the WM_CLOSE arm; here they are one boolean.
   if not LoadQSOIntoEditForm then
      begin
      Close;
      Exit;
      end;

   // Save starts disabled and every field's OnChange turns it on, exactly as
   // the WM_COMMAND EN_CHANGE / CBN_SELCHANGE / BN_CLICKED arm did.
   btnSave.Enabled := True;
   EditQSOSetFocusTo(FLD_CALLSIGN);
end;

procedure TfrmEditQSO.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
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

procedure TfrmEditQSO.btnSaveClick(Sender: TObject);
begin
   if SaveQSOToEditableLog then
      begin
      Close;
      end;
end;

procedure TfrmEditQSO.btnCancelClick(Sender: TObject);
begin
   Close;
end;

procedure TfrmEditQSO.btnPlayClick(Sender: TObject);
begin
   PlayMP3ForEditedQSO;
end;

procedure ShowEditQSO(const aParent: HWND);
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
      ShowModalOverWin32Parent(frmEditQSO, aParent);
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
