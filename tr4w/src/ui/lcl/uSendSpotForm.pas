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
unit uSendSpotForm;
{$I ..\..\tr4w.inc}

{
  THE SEND SPOT DIALOG, AS AN LCL FORM.  Phase 4a, fourth modal converted.

  Callsign, frequency and comment, plus a "contest name in comment" tick, and it
  posts a DX spot either straight up the cluster link or through the TR4W
  network when the link is down.

  THE ONE THING TO GET EXACTLY RIGHT IS THE SPOT STRING, because it goes to a
  cluster and a malformed one is rejected silently by the far end.

  The original built it with pointer tricks: it wrote the four bytes 'D','X',0,0
  over the head of TempBuffer2 as an integer, put a single space at
  TempBuffer1[0], then read each of the three control texts in at
  TempBuffer1[1] and appended the lot with lstrcatA.

  The result is 'DX' followed by each field preceded by ONE SPACE, including
  when a field is empty. The concatenation below reproduces that byte for byte,
  trailing space and all, rather than tidying it into something a cluster might
  parse differently.
}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls;

type
  TfrmSendSpot = class(TForm)
    lblCallsign: TLabel;
    lblFrequency: TLabel;
    lblComment: TLabel;
    edtCallsign: TEdit;
    edtFrequency: TEdit;
    edtComment: TEdit;
    chkContestName: TCheckBox;
    btnOK: TButton;
    btnCancel: TButton;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure chkContestNameChange(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  end;

// the Send Spot dialog.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.  This body changed when the dialog became an LCL form
// and nothing at any call site did.
procedure ShowSendSpot;

implementation

{$R *.lfm}

uses
  uLCLFormHelpers,   // ShowModalOverWin32Parent -- ownership and centring
  VC,           // RC_* captions, ContestTypeSA, tContestNameInComment
  PostUnit,     // Contest -- the active contest type
  TF,           // FreqToPChar
  LogStuff,     // CallWindowString
  LogEdit,      // VisibleLog.LastEntry
  LogRadio,     // ActiveRadioPtr
  uNet,         // SendSpotViaNetwork, SendToNet
  uTelnet,      // TelnetIsConnected, SendViaTelnetSocket
  MainUnit,     // logger
  uHostedFormWindows,
  Log4D;

var
  frmSendSpot: TfrmSendSpot = nil;

procedure TfrmSendSpot.HandleShow(Sender: TObject);
var
  hz100: integer;
  freq: integer;
  lastCall: CallString;
begin
   RegisterHostedFormHandle(Self.Handle);

   Caption               := RC_SENDSPOT;
   lblCallsign.Caption   := string(RC_CALLSIGN);
   lblFrequency.Caption  := string(RC_FREQUENCY);
   lblComment.Caption    := string(RC_COMMENT);
   chkContestName.Caption := string(RC_CONTESTNAMEIC);

   // The call being worked, or the last one logged if the entry field is empty.
   if CallWindowString <> '' then
      begin
      edtCallsign.Text := string(CallWindowString);
      end
   else
      begin
      lastCall := VisibleLog.LastEntry(True, letCallsign);
      edtCallsign.Text := string(lastCall);
      end;

   // ROUNDED TO THE NEAREST 100 Hz, not truncated -- a spot is posted in whole
   // hundreds and the original rounded up at 50.  Preserved exactly.
   hz100 := ActiveRadioPtr.LastDisplayedFreq mod 100;
   freq  := ActiveRadioPtr.LastDisplayedFreq - hz100;
   if hz100 >= 50 then
      begin
      freq := freq + 100;
      end;
   edtFrequency.Text := FreqToPChar(freq);

   // tContestNameInComment is remembered ACROSS openings, so the tick and the
   // comment are restored together. Setting Checked fires OnChange, which is
   // what fills the comment -- the same coupling the WM_COMMAND arm had.
   chkContestName.Checked := tContestNameInComment;
   if not tContestNameInComment then
      begin
      edtComment.Text := '';
      end;

   edtCallsign.SetFocus;
end;

procedure TfrmSendSpot.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

procedure TfrmSendSpot.chkContestNameChange(Sender: TObject);
begin
   tContestNameInComment := chkContestName.Checked;

   if tContestNameInComment then
      begin
      edtComment.Text := string(ContestTypeSA[Contest]);
      end
   else
      begin
      edtComment.Text := '';
      end;
end;

procedure TfrmSendSpot.btnOKClick(Sender: TObject);
var
  spot: AnsiString;
  n: integer;
begin
   // Byte-for-byte as the pointer version built it: 'DX', then each field with
   // exactly one leading space whether or not the field is empty.
   spot := AnsiString('DX' +
                      ' ' + edtCallsign.Text +
                      ' ' + edtFrequency.Text +
                      ' ' + edtComment.Text);

   if TelnetIsConnected then
      begin
      SendViaTelnetSocket(PAnsiChar(spot));
      end
   else
      begin
      // The network record's message field is a FIXED 46-byte array and the
      // original zeroed it before copying, so a shorter spot could not leave the
      // tail of a longer one behind. Same here, and the copy is bounded at
      // SizeOf - 1 so the terminator survives.
      FillChar(SendSpotViaNetwork.vnMessage, SizeOf(SendSpotViaNetwork.vnMessage), 0);
      n := Length(spot);
      if n > SizeOf(SendSpotViaNetwork.vnMessage) - 1 then
         begin
         n := SizeOf(SendSpotViaNetwork.vnMessage) - 1;
         end;
      if n > 0 then
         begin
         Move(spot[1], SendSpotViaNetwork.vnMessage, n);
         end;
      SendToNet(SendSpotViaNetwork, SizeOf(SendSpotViaNetwork));
      end;

   Close;
end;

procedure TfrmSendSpot.btnCancelClick(Sender: TObject);
begin
   Close;
end;

procedure ShowSendSpot;
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmSendSpot = nil then
         begin
         frmSendSpot := TfrmSendSpot.Create(Application);
         end;
      // THROUGH THE ONE DOOR, parent 0.  There is no raw Win32 parent to
      // disable here, but ShowModalOverWin32Parent is also where the main
      // window is made the owner and the form is centred over it -- see
      // OwnFormByMainWindow.  A bare ShowModal skips both.
      ShowModalOverWin32Parent(frmSendSpot, 0);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowSendSpot failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
