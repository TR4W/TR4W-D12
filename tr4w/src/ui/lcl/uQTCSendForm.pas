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
unit uQTCSendForm;
{$I ..\..\tr4w.inc}

(*
  THE WAE QTC SEND WINDOW, AS AN LCL FORM.

  A QTC book is up to ten QSOs read to the other station one line at a time.
  The window lists them, marks how far the operator has got, and carries the
  eight sending commands.

  THE ROWS ARE BUILT IN CODE because their number is decided at open time --
  NumberMessagesToBeSent, one to ten -- and their content comes from
  QTCsToBeSendArray.  The FRAME is designed: two panels and the anchoring.

  THE STATE IS STILL uQTCS's, deliberately.  QTCWasSend, LastSendedQTCHour and
  the send routines stay where they are and this form drives them; a QTC book
  that is half sent is contest state, not window state, and moving it would put
  it somewhere it can be lost by closing a window.

  THREE WIN32 MECHANISMS GO AWAY RATHER THAN BEING PORTED:

    RegisterHotKey.  PageUp, PageDown and F10 were registered as SYSTEM-WIDE
    hotkeys and unregistered on WM_ACTIVATE, because a Win32 dialog's buttons
    swallow keys before the dialog proc sees them.  A form with KeyPreview gets
    them first, so the global registration -- which can fail, and which affects
    every other program on the machine while this window is open -- is not
    needed for a window-local shortcut.

    WM_CTLCOLORSTATIC.  Painting the sent rows yellow and the marker blue was a
    message handler returning a brush handle; they are Color properties here,
    from the same palette entries.

    THE ARROW IS A LABEL THAT MOVES.  It was a static window repositioned with
    MoveWindow; it is a TLabel with its Top assigned.
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
   { PUBLISHED for streaming: a control binds to a field only when the field is
     published and its name matches the component's Name, and an event binds
     only when the handler is a published method, because TWriter stores it BY
     NAME.  Both directions are checked by Lint-FormFields, which gates the
     build. }
   TfrmQTCSend = class(TForm)
      pnlRows: TPanel;
      pnlCommands: TPanel;

      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var Action: TCloseAction);
      procedure HandleCloseQuery(Sender: TObject; var CanClose: boolean);
      procedure HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
      procedure CommandClick(Sender: TObject);
      procedure RowClick(Sender: TObject);
   private
      FRowText  : array[1..10] of TLabel;
      FRowButton: array[1..10] of TButton;
      FArrow    : TLabel;
      FRows     : integer;

      procedure BuildCommands;
      procedure BuildRows;
      procedure PositionArrow;
   public
      { Called by uQTCS when a line has been sent, so the view catches up with
        the state it does not own. }
      procedure RefreshProgress;
      function  RowCount: integer;
   end;

function QTCSendFormOpen: boolean;
function QTCSendForm: TfrmQTCSend;
procedure ShowQTCSendWindow;

{ Close the window from the send logic, once the book is saved.  EndDialog's
  replacement -- and it must not go through the are-you-sure question, because
  by then the operator has already answered it. }
procedure CloseQTCSendWindow;

implementation

{$R *.lfm}

uses
   Graphics,
   LCLType,               { VK_PRIOR, VK_NEXT, VK_F10 }
   VC,                    { tr4wColorsArray, the menu ids }
   LOGWAE,                { QTCsToBeSendArray, NumberMessagesToBeSent, QRVString }
   uQTCS,                 { the send state and the send routines }
   LogWind,               { QuickDisplay }
   uLCLFormHelpers,       { ApplyContentMinimumSize, ShowModalOverWin32Parent }
   uHostedFormWindows,
   MainUnit,              { ProcessMenu, YesOrNo, logger }
   Log4D;

const
   { The Win32 geometry, kept: this window is read at speed during a contest
     and its proportions are what an operator's eye already knows. }
   ROW_H      = 26;
   ROW_GAP    = 2;
   ROW_TOP    = 5;
   TEXT_LEFT  = 70;
   TEXT_W     = 340;
   BTN_LEFT   = 5;
   BTN_W      = 55;
   ARROW_LEFT = 418;
   ARROW_W    = 55;
   ARROW_H    = 17;

var
   GForm: TfrmQTCSend = nil;

{ WHICH COMMAND A BUTTON IS.  Tag, not caption and not position: the second
  button's caption is QRVString, which is configurable, and matching on it
  would break the moment an operator changed it. }
procedure TfrmQTCSend.BuildCommands;
const
   CMD_ID: array[0..7] of integer =
      (QTC_SEND_NEXT, QTC_SEND_QRVSTRING, QTC_SEND_QRV, QTC_SEND_TIME,
       QTC_SEND_CALL, QTC_SEND_NUMBER, QTC_SEND_ALL, QTC_SEND_STOP);
var
   i  : integer;
   btn: TButton;
begin
   for i := 0 to High(CMD_ID) do
      begin
      { Owned by the PANEL, not the form: the panel is emptied and rebuilt on
        every open and DestroyComponents frees what it owns. }
      btn := TButton.Create(pnlCommands);
      btn.Parent := pnlCommands;
      btn.SetBounds(5 + i * 58, 6, 55, 50);
      btn.Tag     := CMD_ID[i];
      btn.OnClick := CommandClick;

      if CMD_ID[i] = QTC_SEND_QRVSTRING then
         begin
         { The operator's own QRV message, whatever it is. }
         btn.Caption := AnsiString(PAnsiChar(@QRVString[0]));
         end
      else
         begin
         btn.Caption := AnsiString(QTCTXButtonsPChar[i]);
         end;

      { NEXT is the default: the operator drives the whole book with Return. }
      btn.Default := (CMD_ID[i] = QTC_SEND_NEXT);
      end;
end;

procedure TfrmQTCSend.BuildRows;
var
   i  : integer;
   lbl: TLabel;
   btn: TButton;
   y  : integer;
begin
   FRows := NumberMessagesToBeSent;
   if FRows > 10 then
      begin
      FRows := 10;
      end;

   for i := 1 to FRows do
      begin
      y := (i - 1) * (ROW_H + ROW_GAP) + ROW_TOP;

      { THE ROW BUTTON IS WIRED, AND IN THE WIN32 VERSION IT WAS NOT.  It was
        created with child id i + 200 -- the same id as the row's text -- while
        the WM_COMMAND arm that resends a line reads 301..310 and the enable
        call targets i + 300.  So Alt-1..Alt-10 reached nothing, the button
        stayed disabled forever, and a line could not be repeated.  The intent
        is not in doubt: there is a handler, an enable, and a caption for it.
        See the commit that converted this window. }
      btn := TButton.Create(pnlRows);
      btn.Parent := pnlRows;
      btn.SetBounds(BTN_LEFT, y, BTN_W, ROW_H);
      btn.Caption := AnsiString(SysUtils.Format('&%d', [i mod 10]));
      btn.Tag     := i;
      btn.Enabled := False;
      btn.OnClick := RowClick;
      FRowButton[i] := btn;

      lbl := TLabel.Create(pnlRows);
      lbl.Parent      := pnlRows;
      lbl.AutoSize    := False;
      lbl.Transparent := False;
      lbl.Layout      := tlCenter;
      lbl.SetBounds(TEXT_LEFT, y, TEXT_W, ROW_H);
      { The columns only line up in a fixed-pitch face.  By PITCH, not by
        naming a font -- see uAltPForm's header. }
      lbl.Font.Pitch := fpFixed;
      lbl.Caption := AnsiString(SysUtils.Format('%.4u %-8s %u',
                        [QTCsToBeSendArray[i].qsTime,
                         string(QTCsToBeSendArray[i].qsCall),
                         QTCsToBeSendArray[i].qsNumber]));
      FRowText[i] := lbl;
      end;

   FArrow := TLabel.Create(pnlRows);
   FArrow.Parent      := pnlRows;
   FArrow.AutoSize    := False;
   FArrow.Transparent := False;
   FArrow.Alignment   := taCenter;
   FArrow.Layout      := tlCenter;
   FArrow.Caption     := TC_NEXT;
   FArrow.Color       := TColor(tr4wColorsArray[trBlue]);
   FArrow.Font.Color  := clWhite;
   FArrow.SetBounds(ARROW_LEFT, ROW_TOP, ARROW_W, ARROW_H);
end;

procedure TfrmQTCSend.PositionArrow;
begin
   if FArrow = nil then
      begin
      Exit;
      end;

   { Hidden once the last line has been sent -- ShowWindow(SW_HIDE) did this. }
   FArrow.Visible := QTCWasSend < FRows;
   if FArrow.Visible then
      begin
      FArrow.Top := QTCWasSend * (ROW_H + ROW_GAP) + ROW_TOP;
      end;
end;

procedure TfrmQTCSend.RefreshProgress;
var
   i: integer;
begin
   for i := 1 to FRows do
      begin
      if i <= QTCWasSend then
         begin
         { WM_CTLCOLORSTATIC returned the yellow brush for every row up to the
           one just sent.  Same palette entry, as a property. }
         FRowText[i].Color := TColor(tr4wColorsArray[trYellow]);
         FRowButton[i].Enabled := True;
         end
      else
         begin
         FRowText[i].Color := pnlRows.Color;
         FRowButton[i].Enabled := False;
         end;
      end;

   PositionArrow;
end;

function TfrmQTCSend.RowCount: integer;
begin
   Result := FRows;
end;

procedure TfrmQTCSend.HandleShow(Sender: TObject);
begin
   RegisterHostedFormHandle(Self.Handle);

   { '<QRV message> for <callsign>' -- the Win32 title, from the same
     resourcestring. }
   Caption := AnsiString(SysUtils.Format(TC_QTC_FOR,
                 [AnsiString(PAnsiChar(@QRVString[0])), string(QTCCallsign)]));

   { REBUILT EVERY TIME, NOT ONCE.  The number of rows is the size of THIS
     QTC book -- one to ten, decided by NumberMessagesToBeSent when the window
     opens -- so a form cached from the previous book would show the previous
     book's lines.  The controls are owned by the panels, so DestroyComponents
     is the whole teardown. }
   pnlCommands.DestroyComponents;
   pnlRows.DestroyComponents;
   FillChar(FRowText, SizeOf(FRowText), 0);
   FillChar(FRowButton, SizeOf(FRowButton), 0);
   FArrow := nil;

   BuildCommands;
   BuildRows;

   RefreshProgress;
   ApplyContentMinimumSize(Self);

   { REPORTED, so a harness can see it -- the Alt-P precedent: a converted
     window that opens correctly and lists nothing is invisible to the corpus,
     the unit tests and every lint. }
   if logger <> nil then
      begin
      logger.Debug(SysUtils.Format('[QTCSend] %d row(s), sent=%d, call=%s',
                      [FRows, QTCWasSend, string(QTCCallsign)]));
      end;
end;

procedure TfrmQTCSend.HandleCloseQuery(Sender: TObject; var CanClose: boolean);
begin
   { The Win32 WM_CLOSE arm asked this before EndDialog.  OnCloseQuery is where
     it belongs: it is the one hook that can REFUSE the close, which the message
     handler did by Exit'ing. }
   CanClose := True;
   if QTCWasSend <> 0 then
      begin
      CanClose := YesOrNo(TC_DOYOUREALLYWANTTOABORTTHISQTC) = IDYES;
      end;
end;

procedure TfrmQTCSend.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   { Only reached once CanClose said yes.  Abandoning a part-sent book is the
     operator telling the other station it is off. }
   if QTCWasSend <> 0 then
      begin
      QuickDisplay(TC_QTCABORTEDBYOPERATOR);
      end;

   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

procedure TfrmQTCSend.HandleKeyDown(Sender: TObject; var Key: word;
                                    Shift: TShiftState);
begin
   { WAS RegisterHotKey.  A Win32 dialog's buttons eat these before the dialog
     proc runs, which is why they had to be SYSTEM-WIDE hotkeys; KeyPreview
     gives the form first refusal without affecting any other program. }
   case Key of
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
      VK_F10:
         begin
         Key := 0;
         ProcessMenu(menu_ctrl_sendkeyboardinput);
         end;
   end;
end;

procedure TfrmQTCSend.CommandClick(Sender: TObject);
begin
   { The eight commands, by Tag.  Was a WM_COMMAND case on the child id. }
   QTCSendCommand((Sender as TButton).Tag);
end;

procedure TfrmQTCSend.RowClick(Sender: TObject);
begin
   { Resend one line.  Was the 301..310 arm. }
   SendQTC((Sender as TButton).Tag);
end;

function QTCSendForm: TfrmQTCSend;
begin
   Result := GForm;
end;

function QTCSendFormOpen: boolean;
begin
   Result := (GForm <> nil) and GForm.Visible;
end;

procedure CloseQTCSendWindow;
begin
   if QTCSendFormOpen then
      begin
      { Hide, not Close: Close runs OnCloseQuery, and asking "do you really want
        to abort this QTC?" straight after saving it would be absurd.  EndDialog
        had the same property -- it did not go back through WM_CLOSE. }
      GForm.Hide;
      end;
end;

procedure ShowQTCSendWindow;
begin
   { The try/except is permanent and deliberate: under FPC an exception that
     escapes into the main loop is a bare RTE with no class, and it takes the
     contest log down with it. }
   try
      if GForm = nil then
         begin
         GForm := TfrmQTCSend.Create(Application);
         end;
      ShowModalOverWin32Parent(GForm, 0);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowQTCSendWindow failed: ' + E.ClassName + ': ' +
                         E.Message);
            end;
         end;
   end;
end;

end.
