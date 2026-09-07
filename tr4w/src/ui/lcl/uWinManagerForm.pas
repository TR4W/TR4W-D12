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
unit uWinManagerForm;
{$I ..\..\tr4w.inc}

{
  THE WINDOW CONTROL DIALOG, AS AN LCL FORM.  Phase 4b.

  Lists every visible TR4W window by title; picking one flashes it, and OK hands
  the FORM back in ManageForm so the caller can move it.

  THE OUTPUT IS A GLOBAL, AND ITS NIL IS MEANINGFUL. The caller tests
  `ManageForm = nil` to mean "nothing chosen" before it touches the window. Every
  exit that is not OK or a double-click must therefore clear it -- Cancel,
  Escape, the window button. Setting it only on success and forgetting the
  clearing paths would leave a STALE form from the previous opening, and the
  caller would move whatever window was picked last time.

  WHAT IS LEFT IN WIN32, AND IT IS ONE CALL: FlashWindow, to point a row out.
  The LCL has no equivalent, and the handle for it is derived at that one call
  rather than carried as the row's identity.

  THE REST OF THAT LIST IS GONE, and the note claiming otherwise was stale by
  the time it was read. It said "EnumWindows to find the windows, GetWindowText
  to name them ... it can only stop doing that when the windows it lists stop
  being raw HWNDs" -- but the list has been Screen.Forms for some time (see the
  note on BuildList), and every window TR4W opens is an LCL form. So the
  condition that comment set for itself had already been met.
}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, LCLType,
  uTR4WStrings;

type
  TfrmWinManager = class(TForm)
    lstWindows: TListBox;
    btnOK: TButton;
    btnCancel: TButton;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure lstWindowsSelectionChange(Sender: TObject; User: boolean);
    procedure lstWindowsDblClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FAccepted: boolean;
    function SelectedForm: TCustomForm;
    procedure Accept;
  end;

// the Window control dialog.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.  The chosen window comes back in ManageWindow.
procedure ShowWindowsManager;

implementation

{$R *.lfm}

uses
  uLCLFormHelpers,   // ShowModalOverWin32Parent -- ownership and centring
  Windows,
  VC,              // RC_WINCONTROL2, tr4whandle
  uWinManager,     // ManageForm -- the caller reads it there
  MainUnit,        // logger
  Log4D;

var
  frmWinManager: TfrmWinManager = nil;

{ THE LIST IS Screen.Forms, NOT EnumWindows.

  IT LISTED ONLY THE MAIN WINDOW (NY4I, 2026-08-26: "I have many windows open
  but just one appears") and the reason is conversion damage of the quietest
  kind.  The filter was

      if (GetParent(wnd) <> tr4whandle) and (wnd <> tr4whandle) then Exit;

  which was correct while every tool window was a CreateDialogParam child of the
  main window: GetParent returned tr4whandle and the row went in.  They are LCL
  FORMS now, OWNED through PopupParent rather than parented, so GetParent stops
  answering tr4whandle and every one of them fails the test.  Only the main
  window itself still matched -- which is exactly the one row that showed.

  Nothing warned.  The test still compiled, still ran, and still returned a
  perfectly good list of length one.

  So this now asks the FRAMEWORK which forms exist instead of asking Windows
  which HWNDs are children.  That is the fix and it is also the portable answer:
  Screen.Forms is the same on every widget set, and this unit's own header
  claimed the Win32 enumeration could only go when the windows stopped being raw
  HWNDs.  They have. }
procedure FillWindowList(const aList: TListBox);
var
  i: integer;
  f: TForm;
begin
   for i := 0 to Screen.FormCount - 1 do
      begin
      f := Screen.Forms[i];

      // Hidden forms are not windows the operator can be shown or move, and
      // every converted tool window is caHide when closed -- so without this
      // the list would name windows that are not on screen.
      if not f.Visible then
         begin
         Continue;
         end;

      // This dialog itself has no business being in its own list.
      if f = frmWinManager then
         begin
         Continue;
         end;

      // THE FORM travels with the row. It used to be the form's HANDLE, cast
      // through PtrUInt into Items.Objects and cast back on the way out -- a
      // round trip that started and ended with this same object.
      aList.Items.AddObject(f.Caption, f);
      end;
end;

function TfrmWinManager.SelectedForm: TCustomForm;
begin
   Result := nil;
   if lstWindows.ItemIndex >= 0 then
      begin
      Result := TCustomForm(lstWindows.Items.Objects[lstWindows.ItemIndex]);
      end;
end;

procedure TfrmWinManager.HandleShow(Sender: TObject);
begin

   Caption   := RC_WINCONTROL2;
   FAccepted := False;

   lstWindows.Items.BeginUpdate;
   try
      lstWindows.Items.Clear;
      FillWindowList(lstWindows);
   finally
      lstWindows.Items.EndUpdate;
   end;

   if lstWindows.Items.Count > 0 then
      begin
      lstWindows.ItemIndex := 0;
      end;

   lstWindows.SetFocus;
end;

procedure TfrmWinManager.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   // EVERY exit that is not an acceptance clears the output.  See the unit
   // header: the caller tests ManageWindow = 0 for "nothing chosen", and a stale
   // handle from a previous opening would move the wrong window.
   if not FAccepted then
      begin
      ManageForm := nil;
      end;

   Action := caHide;
end;

procedure TfrmWinManager.lstWindowsSelectionChange(Sender: TObject; User: boolean);
begin
   // Flashing the window as the selection moves is how the operator tells which
   // row is which -- the titles alone are not always distinct.
   //
   // FlashWindow IS GENUINELY WINDOWS-ONLY -- the LCL has no equivalent -- so
   // the handle is derived here, at the one call that needs it, rather than
   // carried around as the row's identity.
   if SelectedForm <> nil then
      begin
      Windows.FlashWindow(SelectedForm.Handle, True);
      end;
end;

procedure TfrmWinManager.Accept;
begin
   ManageForm := SelectedForm;
   FAccepted    := True;
   Close;
end;

procedure TfrmWinManager.lstWindowsDblClick(Sender: TObject);
begin
   Accept;
end;

procedure TfrmWinManager.btnOKClick(Sender: TObject);
begin
   Accept;
end;

procedure TfrmWinManager.btnCancelClick(Sender: TObject);
begin
   Close;      // HandleClose clears ManageWindow
end;

procedure ShowWindowsManager;
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmWinManager = nil then
         begin
         frmWinManager := TfrmWinManager.Create(Application);
         end;
      // THROUGH THE ONE DOOR, parent 0.  There is no raw Win32 parent to
      // disable here, but ShowModalOverWin32Parent is also where the main
      // window is made the owner and the form is centred over it -- see
      // OwnFormByMainWindow.  A bare ShowModal skips both.
      ShowModalOverWin32Parent(frmWinManager);
   except
      on E: Exception do
         begin
         ManageForm := nil;   // a failure is not a selection
         if logger <> nil then
            begin
            logger.Error('ShowWindowsManager failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
