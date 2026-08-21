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
unit uProgramMessageForm;
{$I ..\..\tr4w.inc}

{
  THE MEMORY PROGRAM FUNCTION BOX (Tools -> Program message), AS AN LCL FORM.
  Phase 4a, the second modal converted.

  Three buttons that choose WHICH message bank the list editor then opens.  It
  was a DialogBoxIndirectParam template with a CreateButton loop and a WM_COMMAND
  arm that switched on the control id; all of it is deleted, and each button has
  its own named handler.  NEVER BRANCH ON Sender -- that is the house rule, and
  a three-way id switch is exactly what it exists to prevent.

  ORDERING IS PRESERVED AND IT MATTERS.  The original called EndDialog and THEN
  OpenListOfMessages, so the chooser was gone before the list appeared.  A
  handler here cannot call OpenListOfMessages directly without opening the list
  underneath a dialog that is still up, so the choice is recorded and
  ShowProgramMessage opens the list after ShowModal returns.

  ONE DELIBERATE COSMETIC CHANGE: the Win32 buttons carried BS_LEFT, so their
  captions were left-aligned.  An LCL TButton centres its caption and has no
  alignment property.  The captions are long sentences in wide buttons, so they
  are still perfectly readable, but they LOOK different -- flagged rather than
  hidden, because it is the kind of difference a bench tester should be told
  about rather than left to wonder at.  If it matters, the answer is a TBitBtn
  or an owner-drawn button, not a reversion.
}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls,
  LCLType,   // VK_ESCAPE
  VC;   // MesWindowType -- named in the class declaration below, so it belongs
        // in the INTERFACE uses, not the implementation one

type
  TfrmProgramMessage = class(TForm)
    btnCQ: TButton;
    btnExchange: TButton;
    btnOther: TButton;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure btnCQClick(Sender: TObject);
    procedure btnExchangeClick(Sender: TObject);
    procedure btnOtherClick(Sender: TObject);
  private
    FChosen: boolean;
    procedure ChooseBank(const aWindow: MesWindowType);
  end;

// the program-message box (Tools -> Program message).
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.  This body changed when the dialog became an LCL form
// and nothing at any call site did.
procedure ShowProgramMessage;

implementation

{$R *.lfm}

uses
  uLCLFormHelpers,   // ShowModalOverWin32Parent -- ownership and centring
  MainUnit,    // MesWindow, OpenListOfMessages, logger
  uHostedFormWindows,
  Log4D;

var
  frmProgramMessage: TfrmProgramMessage = nil;

procedure TfrmProgramMessage.HandleShow(Sender: TObject);
begin
   RegisterHostedFormHandle(Self.Handle);

   FChosen := False;

   // Captions come from the language constants rather than the designer, so the
   // existing translation mechanism still reaches them.  The ampersands are
   // accelerators in both worlds -- BS_LEFT buttons and LCL buttons read '&C'
   // the same way -- so C, E and O keep working as shortcuts.
   Caption            := RC_MEMPROGFUNC;
   btnCQ.Caption       := RC_PRESS_C;
   btnExchange.Caption := RC_PRESS_E;
   btnOther.Caption    := RC_PRESS_O;
end;

procedure TfrmProgramMessage.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

{ ESCAPE HAS TO BE ASKED FOR.  A Win32 DialogBox synthesises IDCANCEL from the
  Escape key -- which is how the original closed, via its `wParam = 2` arm -- and
  an LCL form does no such thing: Escape activates the button whose Cancel is
  True, and does nothing at all when there isn't one.
  
  This form is three choice buttons with no Cancel, so the path is KeyPreview
  plus this handler. Forms that DO have a Cancel button use that instead; see
  Lint-FormDefaults, which now refuses a designed form with no way out. }
procedure TfrmProgramMessage.HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;      // FChosen stays False, so no list opens -- as before
      end;
end;

procedure TfrmProgramMessage.ChooseBank(const aWindow: MesWindowType);
begin
   MesWindow := aWindow;
   FChosen := True;
   Close;
end;

procedure TfrmProgramMessage.btnCQClick(Sender: TObject);
begin
   ChooseBank(CQMsgWin);
end;

procedure TfrmProgramMessage.btnExchangeClick(Sender: TObject);
begin
   ChooseBank(ExMsgWin);
end;

procedure TfrmProgramMessage.btnOtherClick(Sender: TObject);
begin
   ChooseBank(OtherMsgWin);
end;

procedure ShowProgramMessage;
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmProgramMessage = nil then
         begin
         frmProgramMessage := TfrmProgramMessage.Create(Application);
         end;

      // THROUGH THE ONE DOOR, parent 0.  There is no raw Win32 parent to
      // disable here, but ShowModalOverWin32Parent is also where the main
      // window is made the owner and the form is centred over it -- see
      // OwnFormByMainWindow.  A bare ShowModal skips both.
      ShowModalOverWin32Parent(frmProgramMessage, 0);

      // AFTER the chooser has gone, exactly as EndDialog-then-OpenListOfMessages
      // did.  Closing with the window button or Escape chooses nothing, and then
      // no list opens -- also as before.
      if frmProgramMessage.FChosen then
         begin
         OpenListOfMessages;
         end;
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowProgramMessage failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
