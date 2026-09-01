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
unit uQTCReceiveForm;
{$I ..\..\tr4w.inc}

(*
  THE WAE QTC RECEIVE WINDOW, AS AN LCL FORM.

  Ten rows of time / callsign / serial, typed as the other station sends them,
  with a column of buttons that ask him to repeat something.  The operator works
  down the grid with Return; the window unlocks one row at a time.

  THIS WAS THE HEAVIEST OF THE EIGHT CreateModalDialog WINDOWS, because it did
  not merely create its controls -- it SUBCLASSED THIRTY-TWO OF THEM.  Every
  edit had SetWindowLong(GWL_WNDPROC) pointed at NewQTCREditProc, a single
  procedure that then had to work out which control it was running for by
  comparing handles and by reading the child id back with GetDlgCtrlID and
  taking it modulo 100.

  ALL OF THAT IS DELETED, not wrapped.  Each thing the subclass did is the
  property or the event the control already has:

    ES_UPPERCASE                 -> CharCase = ecUpperCase
    ES_NUMBER + the WM_CHAR test -> OnKeyPress, which is where a key filter goes
    EM_SETSEL swallowed          -> nothing: it was suppressing the dialog
                                    manager's select-all-on-focus, and the LCL
                                    does not do that
    WM_KEYUP VK_RETURN           -> OnKeyDown, per control, with the row known
                                    from the control's Tag instead of an id
                                    computed mod 100
    WM_NEXTDLGCTL x3 for up/down -> SelectNext three times, which is the same
                                    arithmetic and says so: three fields to a row
    WM_SYSKEYUP VK_F10           -> the form's OnKeyDown, KeyPreview
    GWL_WNDPROC chaining         -> gone entirely, with CallWindowProc

  WHY THAT MATTERS BEYOND TIDINESS: a subclass installed with SetWindowLong is
  a raw code pointer living in a window's extra bytes.  OldQTCREditProc was a
  SINGLE global overwritten by all thirty-two SetWindowLong calls, so the chain
  every control unwound through was whichever one happened to be installed last.
  It worked because they were all plain EDIT controls with the same original
  proc.  It would have stopped working the moment one of them was not.

  THE VALIDATION STAYS IN uQTCR.  CheckQTCNr, CheckQTCR and SaveQTCR are contest
  rules -- what a legal QTC number looks like, what a legal time looks like --
  and they read the typed values through this form rather than through
  GetDlgItemInt on a global HWND.
*)

interface

uses
   Classes,
   SysUtils,
   Forms,
   Controls,
   StdCtrls,
   ExtCtrls,
   uTR4WStrings;

type
   { Which column of a row, for the focus calls.  Named, because
     Windows.SetFocus(GetDlgItem(QTCRWindow, 200 + i)) said 200 and meant
     "the time field". }
   TQTCColumn = (qcTime, qcCall, qcNumber);

   { PUBLISHED for streaming: a control binds to a field only when the field is
     published and its name matches the component's Name, and an event binds
     only when the handler is a published method, because TWriter stores it BY
     NAME.  Both directions are checked by Lint-FormFields, which gates the
     build. }
   TfrmQTCReceive = class(TForm)
      pnlHeader: TPanel;
      lblCallsign: TLabel;
      edtCallsign: TEdit;
      lblMaxQTCs: TLabel;
      edtQTCNr: TEdit;
      pnlRows: TPanel;
      pnlFooter: TPanel;
      lblStatus: TLabel;
      { NO OK BUTTON.  The Win32 dialog had one and it did NOTHING: its
        WM_COMMAND arm reads `1: ;//SaveQTCR;` with an N4AF 04.32.3 note beside
        the commented-out call, so saving on OK was deliberately switched off
        years ago.  The book is saved by finishing its last row.  Rendering a
        button that does nothing into a new form would be carrying a defect
        forward as a feature -- and Lint-FormDefaults would then require Enter
        to activate it, which would take Enter away from the grid. }
      btnCancel: TButton;

      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var Action: TCloseAction);
      procedure HandleCloseQuery(Sender: TObject; var CanClose: boolean);
      procedure HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
      procedure CancelClick(Sender: TObject);
      procedure AskClick(Sender: TObject);
      { AnsiChar, not char.  TKeyPressEvent is declared with AnsiChar and this
        unit's `char` is WideChar, so the handler simply would not bind. }
      procedure FieldKeyPress(Sender: TObject; var Key: AnsiChar);
      procedure FieldKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
      procedure QTCNrKeyPress(Sender: TObject; var Key: AnsiChar);
      procedure QTCNrKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
   private
      FTime  : array[1..10] of TEdit;
      FCall  : array[1..10] of TEdit;
      FNumber: array[1..10] of TEdit;

      procedure BuildRows;
      function  Field(const aRow: integer; const aColumn: TQTCColumn): TEdit;
      procedure StepFocus(const aForward: boolean; const aTimes: integer);
   public
      { The typed values, asked for by name.  Was GetDlgItemInt / a
        GetDialogItemText on a global HWND with a computed control id. }
      function  RowTime(const aRow: integer): AnsiString;
      function  RowCall(const aRow: integer): AnsiString;
      function  RowNumber(const aRow: integer): AnsiString;
      function  QTCNrText: AnsiString;

      procedure SetStatus(const aText: AnsiString);
      procedure EnableRow(const aRow: integer);
      procedure FocusField(const aRow: integer; const aColumn: TQTCColumn);
   end;

function QTCReceiveFormOpen: boolean;
function QTCReceiveForm: TfrmQTCReceive;
procedure ShowQTCReceiveWindow;

{ Close it from the receive logic once the book is logged.  Hide, not Close:
  the are-you-sure question has already been answered by then. }
procedure CloseQTCReceiveWindow;

implementation

{$R *.lfm}

uses
   Graphics,              { fpFixed, tlCenter }
   LCLType,               { VK_* }
   VC,                    { the menu ids }
   LogWind,               { MyCall }
   LOGWAE,                { QTCCallsign, MaxQTCsThisStation }
   LogCW,                 { SendStringAndStop }
   uQTCR,                 { the validation and the save }
   uLCLFormHelpers,       { ApplyContentMinimumSize, ShowModalOverWin32Parent }
   uHostedFormWindows,
   MainUnit,              { ProcessMenu, YesOrNo, logger }
   Log4D;

const
   { The Win32 geometry, kept: this window is typed into at speed and its
     proportions are what an operator's eye already knows. }
   ROW_H    = 26;
   ROW_GAP  = 2;
   ROW_TOP  = 4;
   NUM_L    = 5;    NUM_W    = 20;
   TIME_L   = 30;   TIME_W   = 80;
   CALL_L   = 115;  CALL_W   = 160;
   NR_L     = 280;  NR_W     = 100;
   ASK_L    = 386;  ASK_W    = 100;

var
   GForm: TfrmQTCReceive = nil;

function QTCReceiveForm: TfrmQTCReceive;
begin
   Result := GForm;
end;

function QTCReceiveFormOpen: boolean;
begin
   Result := (GForm <> nil) and GForm.Visible;
end;

function TfrmQTCReceive.Field(const aRow: integer;
                              const aColumn: TQTCColumn): TEdit;
begin
   Result := nil;
   if (aRow < 1) or (aRow > 10) then
      begin
      Exit;
      end;
   case aColumn of
      qcTime:   Result := FTime[aRow];
      qcCall:   Result := FCall[aRow];
      qcNumber: Result := FNumber[aRow];
   end;
end;

procedure TfrmQTCReceive.BuildRows;
var
   r  : integer;
   y  : integer;
   lbl: TLabel;
   btn: TButton;

   function MakeField(const aLeft, aWidth: integer;
                      const aUpper, aDigitsOnly: boolean): TEdit;
   begin
      Result := TEdit.Create(pnlRows);
      Result.Parent   := pnlRows;
      Result.AutoSize := False;
      Result.SetBounds(aLeft, y, aWidth, ROW_H);
      Result.Enabled  := False;      { WS_DISABLED: one row unlocks at a time }
      Result.Tag      := r;
      Result.Font.Pitch := fpFixed;
      if aUpper then
         begin
         { ES_UPPERCASE, as a property. }
         Result.CharCase := ecUpperCase;
         end;
      if aDigitsOnly then
         begin
         { ES_NUMBER's replacement is the key filter, not a style: the Win32
           code set BOTH and then filtered again in the subclass, because
           ES_NUMBER alone still admits a paste. }
         Result.OnKeyPress := FieldKeyPress;
         end
      else
         begin
         Result.OnKeyPress := FieldKeyPress;
         end;
      Result.OnKeyDown := FieldKeyDown;
   end;

begin
   for r := 1 to 10 do
      begin
      y := (r - 1) * (ROW_H + ROW_GAP) + ROW_TOP;

      lbl := TLabel.Create(pnlRows);
      lbl.Parent    := pnlRows;
      lbl.AutoSize  := False;
      lbl.Alignment := taCenter;
      lbl.Layout    := tlCenter;
      lbl.SetBounds(NUM_L, y, NUM_W, ROW_H);
      lbl.Caption   := AnsiString(IntToStr(r));

      FTime[r]   := MakeField(TIME_L, TIME_W, True,  True);
      FCall[r]   := MakeField(CALL_L, CALL_W, True,  False);
      FNumber[r] := MakeField(NR_L,   NR_W,   True,  True);

      btn := TButton.Create(pnlRows);
      btn.Parent  := pnlRows;
      btn.SetBounds(ASK_L, y, ASK_W, ROW_H);
      { The button SENDS ITS OWN CAPTION as CW, ampersand and all -- which is
        what GetDialogItemText(hwnddlg, wParam) returned to the WM_COMMAND arm.
        Kept byte for byte rather than "tidied" by stripping the accelerator
        marker: what those characters do in the CW encoder is a question for the
        bench, not for a port. }
      btn.Caption := AnsiString(QTCRXButtonsPChar[r]);
      { NOT a tab stop.  The Win32 buttons were created without WS_TABSTOP, and
        that is load-bearing: Down and Up move by THREE controls because a row
        is three FIELDS, and a tab-stop button would make it four. }
      btn.TabStop := False;
      btn.Tag     := r;
      btn.OnClick := AskClick;

      { '&DE <my callsign>' replaced the seventh button's caption, which is
        blank in the table.  It was done with SetDlgItemTextA on id 96 -- 89 + 7
        -- fifty lines away from where the buttons were made. }
      if r = 7 then
         begin
         btn.Caption := AnsiString('&DE ' + string(MyCall));
         end;
      end;
end;

function TfrmQTCReceive.RowTime(const aRow: integer): AnsiString;
begin
   Result := '';
   if Field(aRow, qcTime) <> nil then
      begin
      Result := Field(aRow, qcTime).Text;
      end;
end;

function TfrmQTCReceive.RowCall(const aRow: integer): AnsiString;
begin
   Result := '';
   if Field(aRow, qcCall) <> nil then
      begin
      Result := Field(aRow, qcCall).Text;
      end;
end;

function TfrmQTCReceive.RowNumber(const aRow: integer): AnsiString;
begin
   Result := '';
   if Field(aRow, qcNumber) <> nil then
      begin
      Result := Field(aRow, qcNumber).Text;
      end;
end;

function TfrmQTCReceive.QTCNrText: AnsiString;
begin
   Result := edtQTCNr.Text;
end;

procedure TfrmQTCReceive.SetStatus(const aText: AnsiString);
begin
   { Control id 106, a static created before anything else and written to from
     three different routines.  Same job, named. }
   lblStatus.Caption := aText;
end;

procedure TfrmQTCReceive.EnableRow(const aRow: integer);
begin
   if (aRow < 1) or (aRow > 10) then
      begin
      Exit;
      end;
   FTime[aRow].Enabled   := True;
   FCall[aRow].Enabled   := True;
   FNumber[aRow].Enabled := True;
end;

procedure TfrmQTCReceive.FocusField(const aRow: integer;
                                    const aColumn: TQTCColumn);
var
   e: TEdit;
begin
   e := Field(aRow, aColumn);
   if (e <> nil) and e.Enabled and e.CanFocus then
      begin
      e.SetFocus;
      end;
end;

procedure TfrmQTCReceive.StepFocus(const aForward: boolean; const aTimes: integer);
var
   i: integer;
begin
   for i := 1 to aTimes do
      begin
      SelectNext(ActiveControl, aForward, True);
      end;
end;

procedure TfrmQTCReceive.HandleShow(Sender: TObject);
begin
   RegisterHostedFormHandle(Self.Handle);

   Caption          := RC_RECVQTC;
   lblCallsign.Caption := TC_QTC_CALLSIGN;
   lblMaxQTCs.Caption  := AnsiString(SysUtils.Format(TC_ENTERQTCMAXOF,
                             [MaxQTCsThisStation]));

   { REBUILT ON EVERY OPEN.  The rows are always ten, but the fields must come
     back disabled and empty for a new station -- a form cached from the last
     QTC would open holding the last station's numbers, which in a contest is
     worse than opening blank. }
   pnlRows.DestroyComponents;
   FillChar(FTime, SizeOf(FTime), 0);
   FillChar(FCall, SizeOf(FCall), 0);
   FillChar(FNumber, SizeOf(FNumber), 0);
   BuildRows;

   edtCallsign.Text := QTCCallsign;
   edtQTCNr.Text    := '';
   lblStatus.Caption := '';

   edtQTCNr.OnKeyPress := QTCNrKeyPress;
   edtQTCNr.OnKeyDown  := QTCNrKeyDown;

   QTCsReceived := 0;
   ResetQTCGroup;

   ApplyContentMinimumSize(Self);

   { Ask him for the QTC.  The Win32 WM_INITDIALOG did this too, and it is
     deliberately AFTER the window is built rather than before -- the operator
     needs somewhere to type when the answer starts arriving. }
   SendStringAndStop('QTC?');

   if edtQTCNr.CanFocus then
      begin
      edtQTCNr.SetFocus;
      end;

   { REPORTED, so a harness can see it -- the Alt-P precedent. }
   if logger <> nil then
      begin
      logger.Debug(SysUtils.Format('[QTCRecv] opened for %s, max=%d',
                      [string(QTCCallsign), MaxQTCsThisStation]));
      end;
end;

procedure TfrmQTCReceive.HandleCloseQuery(Sender: TObject; var CanClose: boolean);
begin
   { OnCloseQuery is the hook that can REFUSE the close; the WM_CLOSE arm did it
     by Exit'ing.  Only asked once a group has been started. }
   CanClose := True;
   if QTCGroupStarted then
      begin
      CanClose := YesOrNo(TC_DOYOUREALLYWANTTOABORTTHISQTC) = IDYES;
      end;
end;

procedure TfrmQTCReceive.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

procedure TfrmQTCReceive.HandleKeyDown(Sender: TObject; var Key: word;
                                       Shift: TShiftState);
begin
   { WAS WM_SYSKEYUP AND WM_KEYDOWN INSIDE THE SUBCLASS, so it only worked while
     an edit had focus.  KeyPreview gives the form first refusal wherever the
     caret is. }
   case Key of
      VK_F10:
         begin
         Key := 0;
         ProcessMenu(menu_ctrl_sendkeyboardinput);
         end;
      VK_PRIOR:
         begin
         Key := 0;
         ProcessMenu(menu_cwspeedup);
         end;
      VK_NEXT:
         begin
         Key := 0;
         ProcessMenu(menu_cwspeeddown);
         end;
   end;
end;

procedure TfrmQTCReceive.QTCNrKeyPress(Sender: TObject; var Key: AnsiChar);
begin
   { Digits, a slash and backspace -- the QTC number is '<book>/<count>'. }
   if not (Key in ['0'..'9', '/', #8]) then
      begin
      Key := #0;
      end;
end;

procedure TfrmQTCReceive.QTCNrKeyDown(Sender: TObject; var Key: word;
                                      Shift: TShiftState);
begin
   if Key <> VK_RETURN then
      begin
      Exit;
      end;
   Key := 0;
   QTCNumberEntered;
end;

procedure TfrmQTCReceive.FieldKeyPress(Sender: TObject; var Key: AnsiChar);
begin
   { The subclass admitted letters, digits, slash and backspace in every field
     and additionally restricted the QTC-number box.  Same rule, and it is now
     ON the control that has it rather than decided by comparing handles. }
   if not (Key in ['0'..'9', 'a'..'z', 'A'..'Z', '/', #8]) then
      begin
      Key := #0;
      end;
end;

procedure TfrmQTCReceive.FieldKeyDown(Sender: TObject; var Key: word;
                                      Shift: TShiftState);
var
   e: TEdit;
begin
   e := Sender as TEdit;

   case Key of
      VK_RETURN:
         begin
         Key := 0;
         { The ROW is the control's Tag.  Was GetDlgCtrlID(hwnddlg) mod 100,
           which happened to give 1..10 for ids 201..210, 301..310 and
           401..410 -- and would have given the wrong row for any id that did
           not fit that pattern. }
         QTCRowEntered(e.Tag);
         end;

      VK_RIGHT, VK_SPACE:
         begin
         { At the end of the text, move on rather than doing nothing. }
         if e.SelStart >= Length(e.Text) then
            begin
            Key := 0;
            StepFocus(True, 1);
            end;
         end;

      VK_LEFT:
         begin
         if e.SelStart = 0 then
            begin
            Key := 0;
            StepFocus(False, 1);
            end;
         end;

      VK_DOWN:
         begin
         { THREE, because a row is three fields -- so this lands on the same
           column of the next row.  Was WM_NEXTDLGCTL sent three times, and it
           is the reason the ask buttons must not be tab stops. }
         Key := 0;
         StepFocus(True, 3);
         end;

      VK_UP:
         begin
         Key := 0;
         StepFocus(False, 3);
         end;
   end;
end;

procedure TfrmQTCReceive.AskClick(Sender: TObject);
begin
   { Send the button's own caption, which is what the WM_COMMAND 90..98 arm did
     with GetDialogItemText on the button. }
   SendStringAndStop((Sender as TButton).Caption);
end;

procedure TfrmQTCReceive.CancelClick(Sender: TObject);
begin
   Close;
end;

procedure CloseQTCReceiveWindow;
begin
   if QTCReceiveFormOpen then
      begin
      { Hide, not Close: Close runs OnCloseQuery, and asking whether to abandon
        the QTC straight after logging it would be absurd.  EndDialog had the
        same property. }
      GForm.Hide;
      end;
end;

procedure ShowQTCReceiveWindow;
begin
   { The try/except is permanent and deliberate: under FPC an exception that
     escapes into the main loop is a bare RTE with no class, and it takes the
     contest log down with it. }
   try
      if GForm = nil then
         begin
         GForm := TfrmQTCReceive.Create(Application);
         end;
      ShowModalOverWin32Parent(GForm, 0);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowQTCReceiveWindow failed: ' + E.ClassName + ': ' +
                         E.Message);
            end;
         end;
   end;
end;

end.
