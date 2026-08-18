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
unit uAutoCQForm;
{$I ..\..\tr4w.inc}

{
  THE AUTO-CQ DIALOG, AS AN LCL FORM.  Phase 4a.

  TWO WIN32 CONTROLS HAD NO LCL EQUIVALENT, and how each was replaced was NY4I's
  call rather than a mechanical port.

  1. msctls_hotkey32, the hotkey-capture box.  The choice was a drop-down of the
     36 legal combinations or a box that still captures a real keypress. NY4I
     chose capture: "the muscle memory is important."

     IT NEEDS NO CUSTOM CONTROL. A stock read-only TEdit plus OnKeyDown is the
     whole mechanism -- Key arrives as VK_F1..VK_F12 and Shift as [ssCtrl] /
     [ssAlt], both LCL abstractions that every widgetset normalises, so this
     works on Cocoa and GTK/Qt unchanged.

     NOT OnUTF8KeyPress, which was the first idea: that event delivers
     CHARACTERS, and an F-key produces none, so it would never fire.

     Two platform caveats, recorded because they are decisions someone will have
     to take, not defects: on macOS ssCtrl is Control and Command arrives as
     ssMeta, and TR4W's encoding has only Ctrl and Alt slots; and some Linux
     window managers claim Alt+F2 / Alt+F4 before an application sees them.

  2. The updown buddy on the delay field became a TSpinEdit, which carries the
     500..10000 range and the 250 step the CreateUpDownControl call set, and is
     numeric by construction -- so the "field accepted letters" defect NY4I hit
     on 2026-08-18 cannot be written here at all.
}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Spin;

type
  TfrmAutoCQ = class(TForm)
    lblMemoryKey: TLabel;
    lblDelay: TLabel;
    edtHotKey: TEdit;
    spnDelay: TSpinEdit;
    btnOK: TButton;
    btnCancel: TButton;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure edtHotKeyKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FKey: word;            // VK_F1..VK_F12
    FCtrl: boolean;
    FAlt: boolean;
    procedure ShowCapturedKey;
  end;

// the Auto-CQ settings dialog.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.  This body changed when the dialog became an LCL form
// and nothing at any call site did.
procedure ShowAutoCQ;

implementation

{$R *.lfm}

uses
  LCLType,     // VK_F1..VK_F12
  VC,          // RC_AUTOCQ2, RC_PRESSMKYWTR, RC_NUMBEROSOLT
  LogCW,       // AutoCQMemory
  Tree,        // AutoCQDelayTime
  uCFG,        // SetCFGCommandValue -- the one route to a [COMMANDS] value
  MainUnit,    // RunAutoCQ, logger
  uHostedFormWindows,
  Log4D;

var
  frmAutoCQ: TfrmAutoCQ = nil;

procedure TfrmAutoCQ.ShowCapturedKey;
var
  s: string;
begin
   // Ctrl and Alt are shown EXCLUSIVELY because the encoding is exclusive -- see
   // btnOKClick.  Displaying "Ctrl+Alt+F3" for a value that will be stored as
   // Ctrl+F3 would be a lie the operator only discovers mid-contest.
   if FCtrl then
      begin
      s := 'Ctrl+'
      end
   else if FAlt then
      begin
      s := 'Alt+'
      end
   else
      begin
      s := '';
      end;

   edtHotKey.Text := s + 'F' + IntToStr(FKey - VK_F1 + 1);
end;

procedure TfrmAutoCQ.HandleShow(Sender: TObject);
begin
   RegisterHostedFormHandle(Self.Handle);

   Caption              := RC_AUTOCQ2;
   lblMemoryKey.Caption := string(RC_PRESSMKYWTR);
   lblDelay.Caption     := string(RC_NUMBEROSOLT);

   // STARTS AT F1 EVERY TIME, and that is the old behaviour preserved rather
   // than an oversight: the Win32 version sent HKM_SETHOTKEY with VK_F1 on
   // every open, so the box never showed the memory actually in use.
   //
   // Worth a decision at some point -- showing the stored AutoCQMemory would be
   // friendlier -- but it is a behaviour change, so it is not smuggled in with
   // a port.
   FKey  := VK_F1;
   FCtrl := False;
   FAlt  := False;
   ShowCapturedKey;

   spnDelay.Value := AutoCQDelayTime;

   edtHotKey.SetFocus;
end;

procedure TfrmAutoCQ.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

procedure TfrmAutoCQ.edtHotKeyKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
   // Only a function key is a memory, so anything else is ignored outright
   // rather than silently coerced.  The Win32 control accepted ANY key and the
   // decode then turned it into F1 -- an operator pressing 'Q' got F1 and no
   // indication of it.
   if (Key < VK_F1) or (Key > VK_F12) then
      begin
      Exit;
      end;

   FKey  := Key;
   FCtrl := ssCtrl in Shift;
   FAlt  := ssAlt in Shift;
   ShowCapturedKey;

   // Consumed: an F-key reaching the form would otherwise also be a CW memory.
   Key := 0;
end;

procedure TfrmAutoCQ.btnOKClick(Sender: TObject);
var
  v: integer;
begin
   // THE ENCODING, unchanged: the base VK, plus 12 for Ctrl or 24 for Alt.
   // EXCLUSIVE, because the original tested hibyte(code) against one value at a
   // time and a byte cannot equal both -- so Ctrl wins over Alt, and the
   // display above says the same thing.
   v := FKey;
   if FCtrl then
      begin
      v := v + 12;
      end
   else if FAlt then
      begin
      v := v + 24;
      end;

   AutoCQMemory := Char(v);

   // Through the registry, never straight at the ini: SetCFGCommandValue runs
   // CheckCommand first, which is what enforces the row's 500..10000 bounds and
   // assigns AutoCQDelayTime.  See c823c055.
   SetCFGCommandValue('AUTO-CQ DELAY TIME', IntToStr(spnDelay.Value));

   RunAutoCQ;
   Close;
end;

procedure TfrmAutoCQ.btnCancelClick(Sender: TObject);
begin
   Close;
end;

procedure ShowAutoCQ;
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmAutoCQ = nil then
         begin
         frmAutoCQ := TfrmAutoCQ.Create(Application);
         end;
      frmAutoCQ.ShowModal;
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowAutoCQ failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
