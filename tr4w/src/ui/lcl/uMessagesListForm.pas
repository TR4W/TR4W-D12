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
unit uMessagesListForm;
{$I ..\..\tr4w.inc}

{
  THE LIST OF COMMANDS PICKER, AS AN LCL FORM.  Phase 4b.

  Opened from the Program message editor's "List of commands" button: pick an
  embedded command, and the editor pastes it at the caret.

  THIS IS THE INNER HALF OF A NESTED PAIR, and converting it closes a gap the
  plan's recipe warns about. The recipe says convert inner before outer;
  d036b949 did the outer first, which left an LCL modal owning a Win32 one. That
  direction happens to be the SAFE one -- a Win32 DialogBox disables its owner,
  and the owner was the LCL form -- but it was untested nesting, and now there
  is none.

  THE RETURN VALUE IS THE CONTRACT. ShowMessagesList returns 1 when a command
  was chosen and the editor tests for exactly that before pasting. A form that
  returned mrOk would work only because LCL happens to define mrOk = 1; this
  returns 1 and 0 explicitly rather than relying on that.

  SORTED, and it matters: the list is displayed in alphabetical order, not the
  order sCommandsArray declares. The Win32 version created its listbox with
  LBS_SORT (TF.pas:1179) and therefore could not index the array by the
  selection -- it read the item's TEXT back and re-parsed it. This keeps that
  approach for the same reason.
}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, LCLType;

type
  TfrmMessagesList = class(TForm)
    lstCommands: TListBox;
    btnOK: TButton;
    btnCancel: TButton;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure lstCommandsDblClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FPicked: boolean;
    procedure Accept;
  end;

// the list of program messages, as a picker.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.  Returns 1 when a command was chosen.
function ShowMessagesList(const aParent: HWND): integer;

implementation

{$R *.lfm}

uses
  VC,               // TC_LIST_OF_COMMAND
  uProcessCommand,  // sCommands, sCommandsArray
  uMessagesList,    // GetInsertableCommand, LastSelectedCommand
  MainUnit,         // logger
  uLCLFormHelpers,
  uHostedFormWindows,
  Log4D;

var
  frmMessagesList: TfrmMessagesList = nil;

procedure TfrmMessagesList.HandleShow(Sender: TObject);
var
  i: integer;
begin
   RegisterHostedFormHandle(Self.Handle);

   Caption := string(TC_LIST_OF_COMMAND);

   lstCommands.Items.BeginUpdate;
   try
      lstCommands.Items.Clear;
      for i := 0 to sCommands - 1 do
         begin
         lstCommands.Items.Add(string(sCommandsArray[i].caCommand));
         end;
   finally
      lstCommands.Items.EndUpdate;
   end;

   FPicked := False;
   lstCommands.SetFocus;
end;

procedure TfrmMessagesList.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

procedure TfrmMessagesList.Accept;
var
  s: AnsiString;
begin
   if lstCommands.ItemIndex < 0 then
      begin
      Exit;      // nothing selected: OK does nothing, exactly as before
      end;

   // The ITEM'S TEXT, re-parsed -- not sCommandsArray[ItemIndex]. The list is
   // sorted, so the visible index does not match the array's declaration order,
   // and indexing the array would paste a different command than the one shown.
   s := AnsiString(lstCommands.Items[lstCommands.ItemIndex]);
   LastSelectedCommand := GetInsertableCommand(PAnsiChar(s));

   FPicked := True;
   Close;
end;

procedure TfrmMessagesList.lstCommandsDblClick(Sender: TObject);
begin
   Accept;
end;

procedure TfrmMessagesList.btnOKClick(Sender: TObject);
begin
   Accept;
end;

procedure TfrmMessagesList.btnCancelClick(Sender: TObject);
begin
   Close;
end;

function ShowMessagesList(const aParent: HWND): integer;
begin
   Result := 0;

   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmMessagesList = nil then
         begin
         frmMessagesList := TfrmMessagesList.Create(Application);
         end;

      // aParent is the Program message editor, which IS an LCL form now, so
      // Screen.DisableForms already covers it.  Going through the helper anyway
      // costs nothing (it no-ops on an already-disabled window) and keeps the
      // call correct if this picker is ever opened from somewhere still Win32.
      ShowModalOverWin32Parent(frmMessagesList, aParent);

      if frmMessagesList.FPicked then
         begin
         Result := 1;
         end;
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowMessagesList failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
