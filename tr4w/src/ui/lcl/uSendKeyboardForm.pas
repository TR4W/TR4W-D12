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
unit uSendKeyboardForm;
{$I ..\..\tr4w.inc}

{
  SEND CW FROM THE KEYBOARD, AS AN LCL FORM.  Phase 4a.

  This one was DEFERRED in f75eb405 and the reason has since been removed. Its
  parent is not the main window: the caller passes tr4whandle, or QTCRWindow, or
  QTCSWindow, and LCL's ShowModal disables LCL forms only -- so converting it
  used to mean the QTC window stayed clickable underneath a modal.
  ShowModalOverWin32Parent (d2aff49a) is the general answer, and this is the
  second dialog to need it.

  WHAT IT DOES, because it is not obvious from the controls: every character
  typed is sent as CW immediately, and a backspace sends the CW delete-last
  character (#8). The text box is a keyer, not a form field.

  THE POSITION COUNTER IS THE MECHANISM. oldpos remembers how long the text was
  last time; longer means a character was added and the LAST one is sent, shorter
  means something was deleted and #8 goes out. It is length-based rather than
  content-based, so pasting several characters at once sends only one -- true of
  the original too, and not changed here.

  In Phone mode nothing is keyed: the box collects WAV file names instead, and
  Enter plays them through the DVK.
}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, LCLType;

type
  TfrmSendKeyboard = class(TForm)
    edtText: TEdit;
    btnClose: TButton;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure edtTextChange(Sender: TObject);
    procedure edtTextKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure edtTextKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure btnCloseClick(Sender: TObject);
  private
    FStopSending: boolean;
    FOldPos: integer;
    procedure CloseWith(const aStopSending: boolean);
    procedure PlayPhoneFiles;
  end;

procedure CloseSendKeyboardInputDialog(StopSending: boolean);
function SendKeyboardInputDialogOpen: boolean;

// the send-CW-from-keyboard box.  Takes its parent EXPLICITLY: the caller
// passes tCardinal, not tr4whandle, and that is a real difference rather
// than an oversight -- do not quietly normalise it here.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.
procedure ShowSendKeyboardCW(const aParent: HWND);

implementation

{$R *.lfm}

uses
  Windows,
  VC,             // RC_SENDINGCW, TC_SENDINGSSBWAVFILENAME, ControlAMode
  Tree,           // RemoveFirstString, GetRidOfPrecedingSpaces
  uConfigValues,  // Config.CWTone, Config.DVKEnable
  LogCW,          // AddStringToBuffer, tAutoSendMode, CWStillBeingSent
  LOGSend,        // SendCrypticDVPString
  LogWind,
  LogK1EA,
  uCWKeyerBase,   // KeyerCPU / KeyerWinKey -- the targeted flush
  uMenu,          // menu_cwspeedup / menu_cwspeeddown
  MainUnit,       // ProcessMenu, ActiveMode, logger
  uLCLFormHelpers,
  uHostedFormWindows,
  Log4D,
  uMMTTY;      // PostMmttyMessage on close

var
  frmSendKeyboard: TfrmSendKeyboard = nil;

function SendKeyboardInputDialogOpen: boolean;
begin
   // Issue #1006: true while the box is open, so a function-key button cannot
   // open a second one on top of the first.  The Win32 version answered from a
   // stored HWND; the form's own visibility says the same thing and cannot go
   // stale.
   Result := (frmSendKeyboard <> nil) and frmSendKeyboard.Visible;
end;

procedure CloseSendKeyboardInputDialog(StopSending: boolean);
begin
   if frmSendKeyboard <> nil then
      begin
      frmSendKeyboard.CloseWith(StopSending);
      end;
end;

procedure TfrmSendKeyboard.CloseWith(const aStopSending: boolean);
begin
   FStopSending := aStopSending;
   Close;
end;

procedure TfrmSendKeyboard.HandleShow(Sender: TObject);
begin
   RegisterHostedFormHandle(Self.Handle);

   FOldPos      := 0;
   FStopSending := False;
   edtText.Text := '';

   if ActiveMode = Phone then
      begin
      Caption := TC_SENDINGSSBWAVFILENAME;
      end
   else
      begin
      Caption := RC_SENDINGCW;
      end;

   tAutoSendMode := True;
   ControlAMode  := True;

   edtText.SetFocus;
end;

procedure TfrmSendKeyboard.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   // ALL the teardown lives here, so it runs however the box is closed -- the
   // Close button, Escape, the window button, F10 or Enter.  The Win32 version
   // funnelled everything through one routine for the same reason.
   FOldPos       := 0;
   ControlAMode  := False;
   tAutoSendMode := False;

   // Only tear down the keyer/port if CW is actually being sent. When idle the
   // keying line is already low and the WinKeyer buffer already empty, so a
   // flush is pure no-op work that can cost ~300ms of serial teardown.
   // CWStillBeingSent is keyer-mode aware. Issue #1006.
   if FStopSending and CWStillBeingSent then
      begin
      // KeyerCPU.Flush is CPUKeyer.FlushCWBuffer. Deliberately NOT the
      // LogCW.FlushCWBuffer facade -- that would ALSO stop CAT sending and
      // flush the YCCC box, which this site never did.
      KeyerCPU.Flush;
      // The WinKeyer clear used to reach this site THROUGH the CPU keyer's
      // flush; it lives in the WinKeyer's own adapter now, so it has to be
      // asked for explicitly or closing this box would stop keying the CPU port
      // while leaving a sending WinKeyer running. Self-guarded.
      KeyerWinKey.Flush;
      end;

   PostMmttyMessage(RXM_PTT, RXM_PTT_SWITCH_TO_RX_AFTER_THE_TRANSMISSION_IS_COMPLETED);

   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

procedure TfrmSendKeyboard.edtTextChange(Sender: TObject);
var
  s: string;
  newPos: integer;
begin
   if ActiveMode = Phone then
      begin
      Exit;      // Phone collects WAV names; nothing is keyed as it is typed
      end;

   s := edtText.Text;
   if s = '' then
      begin
      FOldPos := 0;
      Exit;
      end;

   newPos := Length(s);
   if newPos > FOldPos then
      begin
      AddStringToBuffer(s[newPos], Config.CWTone);
      end
   else
      begin
      AddStringToBuffer(#8, Config.CWTone);   // the CW delete-last-character
      end;
   FOldPos := newPos;
end;

procedure TfrmSendKeyboard.PlayPhoneFiles;
var
  s, nextFile: ShortString;
begin
   s := ShortString(edtText.Text);
   if s = '' then
      begin
      Exit;
      end;

   if not Config.DVKEnable then
      begin
      Exit;
      end;

   // RemoveFirstString takes a var OpenString and consumes the string as it
   // goes, so this is a loop over words, each played as <word>.WAV.
   while s <> '' do
      begin
      nextFile := RemoveFirstString(s);
      GetRidOfPrecedingSpaces(nextFile);
      SendCrypticDVPString(nextFile + '.WAV');
      end;
end;

procedure TfrmSendKeyboard.edtTextKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
   if Key = VK_PRIOR then
      begin
      ProcessMenu(menu_cwspeedup);
      Key := 0;
      end
   else if Key = VK_NEXT then
      begin
      ProcessMenu(menu_cwspeeddown);
      Key := 0;
      end;
end;

procedure TfrmSendKeyboard.edtTextKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
   if Key <> VK_RETURN then
      begin
      Exit;
      end;

   if ActiveMode = Phone then
      begin
      PlayPhoneFiles;
      end;

   // Enter closes in BOTH modes -- in the original the final close call sat
   // outside the Phone test, and that is preserved.  StopSending False: Enter
   // means "I have finished typing", not "abandon what is going out".
   CloseWith(False);
end;

procedure TfrmSendKeyboard.HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
   // F10 closes.  It arrives as WM_SYSKEYDOWN, which is why the Win32 version
   // needed a separate arm; KeyPreview plus OnKeyDown covers both here.
   if Key = VK_F10 then
      begin
      Key := 0;
      CloseWith(False);
      end;
end;

procedure TfrmSendKeyboard.btnCloseClick(Sender: TObject);
begin
   // THE ONLY PATH THAT STOPS SENDING.  The button meant "stop" in the Win32
   // version (its arm passed True) while every other exit passed False, and
   // that distinction is the difference between abandoning a message mid-word
   // and letting it finish.
   CloseWith(True);
end;

procedure ShowSendKeyboardCW(const aParent: HWND);
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmSendKeyboard = nil then
         begin
         frmSendKeyboard := TfrmSendKeyboard.Create(Application);
         end;

      // The parent may be a QTC window, which is still a raw Win32 window --
      // see the helper.
      ShowModalOverWin32Parent(frmSendKeyboard, aParent);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowSendKeyboardCW failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
