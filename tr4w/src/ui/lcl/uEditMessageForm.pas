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
unit uEditMessageForm;
{$I ..\..\tr4w.inc}

{
  THE PROGRAM MESSAGE EDITOR, AS AN LCL FORM.  Phase 4b.

  Reached from Alt-P: pick a function-key memory in the list, press Edit. The
  three fields come straight out of that list's row -- key name, message text,
  button caption -- and go back to the CONTEST .cfg on OK.

  THE FEATURE THIS DIALOG EXISTS FOR is not the text boxes, it is inserting CW
  CONTROL CHARACTERS into a message. Ctrl+P arms the escape, and the NEXT
  Ctrl+letter inserts that letter's control code -- Ctrl+P then Ctrl+A puts a #1
  in the text. Ctrl+P twice inserts #16, because the second press is already
  armed and falls through to the insert. That two-step latch is preserved
  exactly; it is the kind of thing an operator has in their fingers.

  It used to need a whole subclassed window procedure (NewMsgEditProc) to see
  those keystrokes, and hand-spliced the character into a raw buffer with a
  reverse copy loop before calling SetWindowTextA. It is OnKeyDown and SelStart
  here.

  THE .cfg WRITE STAYS A .cfg WRITE. WritePrivateProfileString to
  TR4W_CFG_FILENAME is the CONTEST configuration file, not tr4w.ini, so the
  "nothing uses the ini" rule does not apply to it -- see c823c055, which
  classified every remaining call site.
}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, LCLType;

type
  TfrmEditMessage = class(TForm)
    lblKeyName: TLabel;
    lblMessage: TLabel;
    lblCaption: TLabel;
    edtMessage: TEdit;
    edtCaption: TEdit;
    btnEditWav: TButton;
    btnOK: TButton;
    btnCancel: TButton;
    btnList: TButton;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure edtMessageEnter(Sender: TObject);
    procedure edtMessageExit(Sender: TObject);
    procedure edtCaptionEnter(Sender: TObject);
    procedure edtCaptionExit(Sender: TObject);
    procedure edtMessageKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure btnListClick(Sender: TObject);
    procedure btnEditWavClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FRow: integer;              // the Alt-P list row being edited
    FMessageSel: integer;       // caret position, remembered across focus loss
    FCaptionSel: integer;
    FAllowEscapes: boolean;     // armed by Ctrl+P -- see the unit header
    procedure SaveToConfig;
  end;

// the single-message editor.  Parent and message index both come from the
// caller (uAltP passes its own window and the selected message).
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.
procedure ShowEditMessage(const aParent: HWND; const aMessage: lParam);

implementation

{$R *.lfm}

uses
  Windows,
  VC,             // RC_*, TC_*, MesWindow / OtherMsgWin, TR4W_CFG_FILENAME
  TF,             // Format, YesOrNo
  uCFG,           // CheckCommand
  Tree,           // GetRealPath
  utils_file,     // tOpenFileForWrite, sWriteFile, GetRealPath, waveheader
  uCommctrl,      // ListView_GetItemText
  uConfigValues,  // Config.DVKRecorder, Config.DVKPath
  uMessagesList,  // ShowMessagesList, LastSelectedCommand
  uEditMessage,   // DeleteEscapeChars -- still this unit's own routine
  uAltP,          // AltPListView, DisplaymessagesList
  LogWind,
  MainUnit,       // ActiveMode, SetCommand, logger
  uLCLFormHelpers,
  uHostedFormWindows,
  Log4D;

const
  MESSAGES_SECTION = 'Messages';

var
  frmEditMessage: TfrmEditMessage = nil;

procedure TfrmEditMessage.HandleShow(Sender: TObject);
var
  buf: array[0..511] of AnsiChar;

  function ColumnText(const aCol: integer): string;
  begin
     Windows.ZeroMemory(@buf, SizeOf(buf));
     ListView_GetItemText(AltPListView, FRow, aCol, buf, SizeOf(buf));
     Result := string(PAnsiChar(@buf[0]));
  end;

begin
   RegisterHostedFormHandle(Self.Handle);

   Caption            := RC_PROGRMESS;
   lblMessage.Caption := string(RC_MESSAGE);
   lblCaption.Caption := string(RC_CAPTION);
   btnList.Caption    := string(TC_LIST_OF_COMMAND);
   btnEditWav.Caption := string(RC_EDIT_WORD);

   // Columns 0, 1 and 2 of the Alt-P row: key name, message, caption. The
   // Win32 version read them into controls 101, 102 and 103 with one loop over
   // `101 + i`, which is why they had to be consecutive ids.
   lblKeyName.Caption := ColumnText(0);
   edtMessage.Text    := ColumnText(1);
   edtCaption.Text    := ColumnText(2);

   // The "other messages" bank has no function-key button, so it has no caption
   // to set.
   edtCaption.Enabled := MesWindow <> OtherMsgWin;

   // The WAV editor is a Phone-mode tool: it launches the DVK recorder on the
   // file named in the message.
   btnEditWav.Enabled := ActiveMode = Phone;

   FMessageSel   := 0;
   FCaptionSel   := 0;
   FAllowEscapes := False;

   edtMessage.SetFocus;
end;

procedure TfrmEditMessage.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

{ The caret position is remembered per field across focus loss, because the
  "List of commands" button STEALS FOCUS before it can be used -- the inserted
  command has to land where the caret was, not where it ended up. The Win32
  version did this with EN_SETFOCUS / EN_KILLFOCUS and an EM_GETSEL into a
  SelPos array indexed by control id. }
procedure TfrmEditMessage.edtMessageEnter(Sender: TObject);
begin
   edtMessage.SelStart := FMessageSel;
end;

procedure TfrmEditMessage.edtMessageExit(Sender: TObject);
begin
   FMessageSel := edtMessage.SelStart;
end;

procedure TfrmEditMessage.edtCaptionEnter(Sender: TObject);
begin
   edtCaption.SelStart := FCaptionSel;
end;

procedure TfrmEditMessage.edtCaptionExit(Sender: TObject);
begin
   FCaptionSel := edtCaption.SelStart;
end;

procedure TfrmEditMessage.edtMessageKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
var
  at: integer;
  s: string;
begin
   if not (ssCtrl in Shift) then
      begin
      Exit;
      end;

   if Key = VK_CONTROL then
      begin
      Exit;      // the modifier itself, not a combination
      end;

   // Ctrl+V is blocked, as it was: a pasted control character would defeat the
   // escape mechanism below and the message format cannot carry one safely.
   if Key = Ord('V') then
      begin
      Key := 0;
      Exit;
      end;

   // Ctrl+P ARMS the escape rather than inserting one -- unless it is already
   // armed, in which case it falls through and inserts #16 like any other
   // letter. Two-step, and preserved exactly; see the unit header.
   if (Key = Ord('P')) and (not FAllowEscapes) then
      begin
      FAllowEscapes := True;
      Key := 0;
      Exit;
      end;

   if not FAllowEscapes then
      begin
      Exit;
      end;

   if (Key < Ord('A')) or (Key > Ord('Z')) then
      begin
      Exit;
      end;

   // Insert the control code at the caret. The original spliced it into a raw
   // buffer with a reverse copy loop and then SetWindowTextA'd the whole field;
   // a string and SelStart say the same thing.
   at := edtMessage.SelStart;
   s  := edtMessage.Text;
   Insert(Char(Key - 64), s, at + 1);
   edtMessage.Text     := s;
   edtMessage.SelStart := at + 1;

   FAllowEscapes := False;
   Key := 0;
end;

procedure TfrmEditMessage.btnListClick(Sender: TObject);
begin
   // FMessageSel was saved by OnExit when this button took the focus, so it
   // still holds the caret position in the message field.
   if ShowMessagesList(Self.Handle) <> 1 then
      begin
      Exit;
      end;

   edtMessage.SelStart  := FMessageSel;
   edtMessage.SelLength := 0;
   edtMessage.SelText   := string(LastSelectedCommand);
   edtMessage.SetFocus;
end;

procedure TfrmEditMessage.btnEditWavClick(Sender: TObject);
var
  msg: string;
  path: AnsiString;
  h: THandle;
  cmd: array[0..511] of AnsiChar;
begin
   msg := edtMessage.Text;

   // The message must NAME a .WAV file. The original tested the last four bytes
   // against the integer 1447122734, which is '.WAV' read little-endian --
   // correct, and unreadable. A suffix comparison says the same thing.
   if (Length(msg) < 5) or (not SameText(Copy(msg, Length(msg) - 3, 4), '.WAV')) then
      begin
      Exit;
      end;

   if Config.DVKRecorder[0] = #0 then
      begin
      SetCommand('DVP RECORDER');
      Exit;
      end;

   path := AnsiString(GetRealPath(Config.DVKPath, PAnsiChar(AnsiString(msg)), nil));

   // utils_file.FileExists takes a PAnsiChar; SysUtils' string overload is also
   // in scope, so the cast says which is meant rather than leaving it to the
   // uses order.
   if not utils_file.FileExists(PAnsiChar(path)) then
      begin
      if YesOrNo(Self.Handle, TC_THIS_FILE_DOES_NOT_EXIST) = IDNO then
         begin
         Exit;
         end;
      // An empty but VALID wav: the recorder is handed a file with a header
      // rather than a missing one.
      if tOpenFileForWrite(h, PAnsiChar(path)) then
         begin
         sWriteFile(h, waveheader, Length(waveheader));
         CloseHandle(h);
         end;
      end;

   TF.Format(cmd, '"%s" "%s"', Config.DVKRecorder, PAnsiChar(path));
   WinExec(cmd, SW_SHOWNORMAL);
end;

procedure TfrmEditMessage.SaveToConfig;
var
  id, cmd: ShortString;
  capValue: PAnsiChar;
  capText: AnsiString;
begin
   // THE CONTEST .cfg, NOT tr4w.ini. Different file, different rule -- see the
   // unit header and c823c055.
   id  := ShortString(lblKeyName.Caption);
   cmd := ShortString(edtMessage.Text);
   DeleteEscapeChars(cmd);

   Windows.WritePrivateProfileStringA(MESSAGES_SECTION, @id[1], @cmd[1],
                                      @TR4W_CFG_FILENAME);
   CheckCommand(@id, cmd);

   if MesWindow = OtherMsgWin then
      begin
      Exit;      // no function-key button, so no caption
      end;

   capText := AnsiString(edtCaption.Text);
   id := ShortString(lblKeyName.Caption) + ' CAPTION';

   // A nil VALUE deletes the key. An empty caption therefore REMOVES the entry
   // rather than writing a blank one, which is what the original did by setting
   // p to nil -- and it matters, because a blank caption and an absent one are
   // read differently.
   if capText = '' then
      begin
      capValue := nil;
      end
   else
      begin
      capValue := PAnsiChar(capText);
      end;

   Windows.WritePrivateProfileStringA(MESSAGES_SECTION, @id[1], capValue,
                                      @TR4W_CFG_FILENAME);

   cmd := ShortString(capText);
   CheckCommand(@id, cmd);
end;

procedure TfrmEditMessage.btnOKClick(Sender: TObject);
begin
   SaveToConfig;
   DisplaymessagesList(MesWindow, ActiveMode);
   Close;
end;

procedure TfrmEditMessage.btnCancelClick(Sender: TObject);
begin
   Close;
end;

procedure ShowEditMessage(const aParent: HWND; const aMessage: lParam);
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmEditMessage = nil then
         begin
         frmEditMessage := TfrmEditMessage.Create(Application);
         end;

      frmEditMessage.FRow := aMessage;

      // The parent is uAltP's window, which is still a raw Win32 dialog, so it
      // needs the explicit disable -- LCL ShowModal only disables LCL forms.
      ShowModalOverWin32Parent(frmEditMessage, aParent);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowEditMessage failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
