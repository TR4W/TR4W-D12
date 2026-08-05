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
unit uFMXSpikeForm;

{
  THROWAWAY.  This form exists to answer one question before any real work is
  built on FMX: does an FMX window behave correctly inside TR4W's hand-written
  Win32 message loop, with a radio polling and a cluster connected?  Nothing
  here is meant to survive -- the durable outputs of the spike are uFMXCoexist,
  the dpr/dproj wiring, and whatever the bench session teaches.

  WHY IT IS BUILT IN CODE AND HAS NO .fmx.  A designer form would answer TWO
  questions at once -- "does FMX coexist" and "does FMX form streaming work
  under this project's settings" -- and a failure would not say which.  The
  coexistence question is about the message loop, the keyboard, timers and
  thread marshalling, and none of those care where the controls came from.
  Whether the IDE designer round-trips a .fmx cleanly is worth testing too, but
  separately and after this passes.

  WHAT EACH CONTROL IS FOR (this is a test instrument, not a UI):

    Edit         -- the keyboard isolation test.  Type a callsign into it: the
                    characters must appear THERE and not in TR4W's Call window.
                    This is the whole ballgame; TR4W's loop routes WM_CHAR to
                    the callsign window and treats F-keys and the numeric keypad
                    as CW memories.
    Click me     -- proves ordinary mouse input and repainting work.
    Timer label  -- an FMX timer ticking proves FMX's own WM_TIMER plumbing
                    survives a foreign message loop.
    Queue test   -- a background thread calling TThread.Queue proves the main
                    thread's synchronisation queue is being drained.  It is NOT
                    drained by GetMessage; if this label never updates, every
                    radio/cluster callback that marshals to the UI would hang
                    silently, which is the failure mode that would hurt most.
    ComboBox     -- a drop-down opens a SEPARATE top-level window, which is the
                    case GetAncestor(GA_ROOT) exists to cover in uFMXCoexist.
    CheckBox     -- space-bar handling, another key TR4W's loop cares about.
    Show modal   -- ShowModal runs its OWN message loop, taking over from
                    tr4w.dpr's.  Observe once and record the verdict; the policy
                    for the real preferences window is MODELESS regardless.
}

interface

uses
   System.SysUtils,
   System.Classes,
   System.UITypes,
   FMX.Types,
   FMX.Controls,
   FMX.Forms,
   FMX.StdCtrls,
   FMX.Edit,
   FMX.ListBox,
   FMX.Controls.Presentation;

type
   TFMXSpikeForm = class(TForm)
   private
      FEdit: TEdit;
      FClickButton: TButton;
      FClickLabel: TLabel;
      FTimerLabel: TLabel;
      FQueueLabel: TLabel;
      FQueueButton: TButton;
      FCombo: TComboBox;
      FCheck: TCheckBox;
      FModalButton: TButton;
      FTimer: TTimer;
      FClicks: integer;
      FTicks: integer;

      procedure BuildControls;
      procedure HandleClick(Sender: TObject);
      procedure HandleQueueTest(Sender: TObject);
      procedure HandleModal(Sender: TObject);
      procedure HandleTimer(Sender: TObject);
      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var Action: TCloseAction);
   public
      constructor Create(AOwner: TComponent); override;
   end;

// Opens the spike form (or brings the existing one forward).  Called from the
// FMXTEST call-window command.
procedure ShowFMXSpikeForm;

implementation

uses
   FMX.Platform.Win,
   uFMXCoexist;

var
   gSpikeForm: TFMXSpikeForm = nil;

procedure ShowFMXSpikeForm;
begin
   if gSpikeForm = nil then
      begin
      gSpikeForm := TFMXSpikeForm.Create(nil);
      end;
   gSpikeForm.Show;
   gSpikeForm.BringToFront;
end;

constructor TFMXSpikeForm.Create(AOwner: TComponent);
begin
   // CreateNew, not Create: there is no .fmx resource to stream, and the
   // inherited constructor would look for one and raise.
   inherited CreateNew(AOwner);

   Caption      := 'TR4W FMX coexistence spike';
   Width        := 460;
   Height       := 360;
   Position     := TFormPosition.ScreenCenter;
   BorderStyle  := TFmxFormBorderStyle.Sizeable;
   OnShow       := HandleShow;
   OnClose      := HandleClose;

   BuildControls;
end;

procedure TFMXSpikeForm.BuildControls;
const
   LEFTMARGIN = 16;
   ROWHEIGHT  = 34;
var
   y: single;

   function NextRow: single;
   begin
      Result := y;
      y := y + ROWHEIGHT;
   end;

begin
   y := 16;

   FEdit := TEdit.Create(Self);
   FEdit.Parent   := Self;
   FEdit.Position.X := LEFTMARGIN;
   FEdit.Position.Y := NextRow;
   FEdit.Width    := 260;
   FEdit.TextPrompt := 'Type a callsign here -- it must NOT reach TR4W';
   FEdit.TabOrder := 0;

   FClickButton := TButton.Create(Self);
   FClickButton.Parent     := Self;
   FClickButton.Position.X := LEFTMARGIN;
   FClickButton.Position.Y := NextRow;
   FClickButton.Text       := 'Click me';
   FClickButton.OnClick    := HandleClick;
   FClickButton.TabOrder   := 1;

   FClickLabel := TLabel.Create(Self);
   FClickLabel.Parent     := Self;
   FClickLabel.Position.X := LEFTMARGIN + 110;
   FClickLabel.Position.Y := FClickButton.Position.Y + 4;
   FClickLabel.Width      := 280;
   FClickLabel.Text       := 'clicks: 0';

   FTimerLabel := TLabel.Create(Self);
   FTimerLabel.Parent     := Self;
   FTimerLabel.Position.X := LEFTMARGIN;
   FTimerLabel.Position.Y := NextRow;
   FTimerLabel.Width      := 400;
   FTimerLabel.Text       := 'timer: waiting for the first tick';

   FQueueButton := TButton.Create(Self);
   FQueueButton.Parent     := Self;
   FQueueButton.Position.X := LEFTMARGIN;
   FQueueButton.Position.Y := NextRow;
   FQueueButton.Width      := 100;
   FQueueButton.Text       := 'Queue test';
   FQueueButton.OnClick    := HandleQueueTest;
   FQueueButton.TabOrder   := 2;

   FQueueLabel := TLabel.Create(Self);
   FQueueLabel.Parent     := Self;
   FQueueLabel.Position.X := LEFTMARGIN + 110;
   FQueueLabel.Position.Y := FQueueButton.Position.Y + 4;
   FQueueLabel.Width      := 300;
   FQueueLabel.Text       := 'queue: not run yet';

   FCombo := TComboBox.Create(Self);
   FCombo.Parent     := Self;
   FCombo.Position.X := LEFTMARGIN;
   FCombo.Position.Y := NextRow;
   FCombo.Width      := 200;
   FCombo.Items.Add('SERIAL 1');
   FCombo.Items.Add('SERIAL 5');
   FCombo.Items.Add('SERIAL 17');
   FCombo.ItemIndex  := 0;
   FCombo.TabOrder   := 3;

   FCheck := TCheckBox.Create(Self);
   FCheck.Parent     := Self;
   FCheck.Position.X := LEFTMARGIN;
   FCheck.Position.Y := NextRow;
   FCheck.Width      := 260;
   FCheck.Text       := 'Space toggles this (another key TR4W wants)';
   FCheck.TabOrder   := 4;

   FModalButton := TButton.Create(Self);
   FModalButton.Parent     := Self;
   FModalButton.Position.X := LEFTMARGIN;
   FModalButton.Position.Y := NextRow;
   FModalButton.Width      := 160;
   FModalButton.Text       := 'Show modal child';
   FModalButton.OnClick    := HandleModal;
   FModalButton.TabOrder   := 5;

   FTimer := TTimer.Create(Self);
   FTimer.Interval := 1000;
   FTimer.OnTimer  := HandleTimer;
   FTimer.Enabled  := True;
end;

procedure TFMXSpikeForm.HandleShow(Sender: TObject);
begin
   // Registering here rather than in the constructor: the window handle does
   // not exist until the form is shown, and a 0 handle would register nothing
   // while looking like it had worked.
   RegisterFMXFormHandle(FormToHWND(Self));
end;

procedure TFMXSpikeForm.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterFMXFormHandle(FormToHWND(Self));
   // Hide, do not free: the form is reopened by the same FMXTEST command, and
   // freeing it here while its own event handler is running is the classic way
   // to crash on the way out.
   Action := TCloseAction.caHide;
end;

procedure TFMXSpikeForm.HandleClick(Sender: TObject);
begin
   Inc(FClicks);
   FClickLabel.Text := Format('clicks: %d', [FClicks]);
end;

procedure TFMXSpikeForm.HandleTimer(Sender: TObject);
begin
   Inc(FTicks);
   FTimerLabel.Text := Format('timer: %d tick(s) -- FMX timers survive the loop', [FTicks]);
end;

procedure TFMXSpikeForm.HandleQueueTest(Sender: TObject);
begin
   FQueueLabel.Text := 'queue: thread started...';

   // The important test.  TThread.Queue posts to the main thread's
   // synchronisation queue, which GetMessage does NOT drain by itself.  If this
   // label never changes, every radio or cluster callback that marshals to the
   // UI would hang silently -- the worst failure mode available here, because
   // nothing errors.
   TThread.CreateAnonymousThread(
      procedure
      begin
         Sleep(300);
         TThread.Queue(nil,
            procedure
            begin
               FQueueLabel.Text := 'queue: updated from a worker thread';
            end);
      end).Start;
end;

procedure TFMXSpikeForm.HandleModal(Sender: TObject);
var
   child: TForm;
   closeButton: TButton;
begin
   // ShowModal runs FMX's OWN message loop, which takes over from tr4w.dpr's
   // for as long as it is up -- meaning TR4W's key handling, and anything else
   // the loop does per message, is not running.  Observe it once and record the
   // verdict; the policy for the real preferences window is MODELESS whatever
   // this shows.
   child := TForm.CreateNew(nil);
   try
      child.Caption  := 'Modal child -- TR4W''s loop is NOT running';
      child.Width    := 320;
      child.Height   := 140;
      child.Position := TFormPosition.ScreenCenter;

      closeButton := TButton.Create(child);
      closeButton.Parent     := child;
      closeButton.Position.X := 100;
      closeButton.Position.Y := 50;
      closeButton.Width      := 120;
      closeButton.Text       := 'Close';
      closeButton.ModalResult := mrOk;

      RegisterFMXFormHandle(FormToHWND(child));
      try
         child.ShowModal;
      finally
         UnregisterFMXFormHandle(FormToHWND(child));
      end;
   finally
      child.Free;
   end;
end;

initialization

finalization
   // Freed at shutdown rather than on close, so that reopening is cheap and so
   // that nothing frees a form from inside its own event handler.
   FreeAndNil(gSpikeForm);

end.
