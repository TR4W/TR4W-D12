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
unit uPanelUpdate;
{$I tr4w.inc}

{
  UPDATING A TOOL PANEL FROM A WORKER THREAD, SAFELY AND WITHOUT FLOODING.

  The radio panels are written by the radio's own reading thread:
  uRadioPolling calls SetDlgItemTextA and EnableWindow on
  rig^.tRadioInterfaceWndHandle and its children. That works TODAY only because
  those are Win32 controls and the API marshals across threads for you.

  IT WILL NOT SURVIVE THE LCL. LCL controls are not thread-safe, so every one of
  those writes has to arrive on the main thread before the panel can become a
  designed form. This unit is that seam, and it deliberately exists BEFORE the
  conversion: repointing the writes first is a small, reviewable change against
  the panel that exists, and it leaves the conversion with no threading in it.

  WHY NOT TThread.Queue AND NOT Synchronize. The reasoning is uTCIServer's,
  paid for on 2026-08-14, and it still holds:

    * TThread.Queue stamps each entry with the CALLING thread's id even when the
      thread argument is nil, and TThread.Destroy purges by that id -- so a
      thread that queues and then exits DELETES ITS OWN PENDING CALLBACK. Radio
      threads are torn down on every reconnect, which is exactly when a status
      update matters most.
    * TThread.Synchronize blocks the worker until the main thread runs it. A
      radio poll thread must not be held hostage to a busy UI.
    * Nothing in TR4W calls CheckSynchronize; both only work at all because
      Forms hooks WakeMainThread and the hand-rolled loop happens to fall
      through to DispatchMessage -- a mechanism Phase 3/7 deletes.

  THE MARSHALLING CHOICE HERE IS AN INTERIM.  Corrected 2026-08-24: the
  TThread.Queue objection below describes a SYMPTOM and was written as though it
  settled the question.  Its purge -- a thread that queues and then exits
  deletes its own callback -- is CORRECT semantics; what is wrong is that
  TReadingThread (uFactoryRadioBase:211) is destroyed and recreated on EVERY
  RECONNECT.  Fix the thread lifetime and TThread.Queue becomes the right
  answer, and it is RTL rather than bound to Forms.  NY4I called this, and it is
  scheduled in docs\DOMAIN_LAYER_SEQUENCE.md section 0.  Do not read the
  paragraph below as a conclusion.

  THIS USED TO BE A POSTED MESSAGE, AND THE THIRD LEG OF THAT ARGUMENT EXPIRED.
  WM_PANEL_UPDATE was chosen partly because TR4W ran a hand-rolled GetMessage
  loop -- the note above even called that "a mechanism Phase 3/7 deletes". Phase
  3/7 happened: the program runs Application.Run. So this is now
  Application.QueueAsyncCall, which answers all three objections at once -- it
  does not block the sender, is tied to no thread's lifetime, and is drained by
  the LCL's own loop. VERIFIED, not assumed: it enters FAsyncCall.CritSec
  (lcl/include/application.inc:2327), so it is genuinely safe from a worker
  thread.

  AND IT DELETED A WHOLE CLASS OF BUG WITH IT. A posted message only arrived if
  its id was listed in the main form's allow-list, and WM_PANEL_UPDATE WAS NOT --
  so this seam delivered nothing at all, which is why RIT/XIT/SPLIT stayed yellow
  on the bench and survived two wrong diagnoses. An async call has no id to
  forget to register.

  AND WHY IT COALESCES, WHICH IS THE HALF THAT IS NOT ABOUT THREADS.
  DisplayCurrentStatus runs on EVERY POLL and ends with three unconditional
  EnableWindow calls for RIT, XIT and SPLIT. Poll rates go down to 10 ms. Turning
  each of those into a post would replace a blocking call with a message flood --
  a fix that reads as a fix and performs worse.

  So a value equal to the one last posted for the same target is DROPPED. That is
  the bandmap's lesson applied: the bandmap has never marshalled per spot, it
  sets a dirty flag and repaints on a 250 ms timer, and it is the cheapest UI in
  the program because of it. Anything converted from here should coalesce too.

  THE CACHE RECORDS WHAT WAS POSTED, NOT WHAT WAS APPLIED. If the post fails the
  entry is dropped, so the next call retries rather than believing a value that
  never arrived.
}

interface

uses
  Windows,
  VC;      // TMainWindowElement -- what a puElement update addresses

// Set a child control's text from ANY thread. aPanel = 0, or a panel that has
// closed, is not an error: the update is dropped, exactly as the guarded
// `if handle <> 0` at each call site did before.
procedure PostPanelText(const aPanel: HWND; const aControlId: integer;
  const aText: string);

// Enable or disable one control from ANY thread, by its window handle.
procedure PostControlEnable(const aControl: HWND; const aEnabled: boolean);

{ Sets one main-window element's text FROM A WORKER THREAD.  Coalesced and
  marshalled exactly like a panel update -- see TPanelUpdateKind.puElement for
  why it cannot simply be SetWindowText on the element's handle. }
procedure PostElementText(const aElement: TMainWindowElement; const aText: string);

// Forget everything remembered about a panel and its children. Call when a
// panel closes: a window handle can be REUSED by Windows, and a stale cache
// entry would then suppress the first update to a different window.
procedure ForgetPanel(const aPanel: HWND);

implementation

uses
  SysUtils, SyncObjs,
  Forms,       // Application.QueueAsyncCall -- the transport
  TF,          // SetMainWindowText -- the only supported way to write an element
  uCrashLog;   // LogCaughtException -- a failed hand-off must not be silent

type
  { puElement IS THE ONE THAT DOES NOT TAKE A HANDLE.

    The main window's elements are LCL controls now, and an LCL control paints
    its caption from a PROPERTY -- so SetWindowTextW on its handle, which is
    what the polling thread used to do to the frequency and radio-name rows,
    writes to the window and leaves the property holding the old text.  The
    control repaints itself from the property and the operator sees nothing
    change.  (The same stale-property trap as the tool-window captions, and the
    reason OpenTR4WWindow stopped calling SetWindowTextW on a form.)

    So the element travels as its ENUM and the main thread does the assignment
    through SetMainWindowText, which is the only supported way to write one. }
  TPanelUpdateKind = (puText, puEnable, puElement);

  // The payload handed across the thread boundary. One allocation per update
  // that actually needs to travel; freed by RunQueuedPanelUpdate.
  TPanelUpdate = class(TObject)
  public
    Kind: TPanelUpdateKind;
    Target: HWND;          // the PANEL for puText, the CONTROL for puEnable
    ControlId: integer;    // for puElement: Ord(TMainWindowElement)
    Text: string;
    Enabled: boolean;
  end;

  // QueueAsyncCall wants a method, so one object owns it.
  TPanelRunner = class(TObject)
  public
    procedure Apply(Data: PtrInt);
  end;

  // What was last successfully handed over for one target. Small and linear: there
  // are two radio panels with a handful of controls each, so a list beats a
  // hash both in code and in cache lines.
  TLastPosted = record
    Kind: TPanelUpdateKind;
    Target: HWND;
    ControlId: integer;
    Text: string;
    Enabled: boolean;
  end;

var
  gLock: TCriticalSection = nil;
  gRunner: TPanelRunner = nil;
  gLast: array of TLastPosted;

// Caller holds the lock. Returns the index, or -1.
function IndexOf(const aKind: TPanelUpdateKind; const aTarget: HWND;
  const aControlId: integer): integer;
var
  i: integer;
begin
   Result := -1;

   for i := 0 to High(gLast) do
      begin
      if (gLast[i].Kind = aKind) and
         (gLast[i].Target = aTarget) and
         (gLast[i].ControlId = aControlId) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

// Caller holds the lock.
procedure Forget(const aIndex: integer);
var
  i: integer;
begin
   for i := aIndex to High(gLast) - 1 do
      begin
      gLast[i] := gLast[i + 1];
      end;
   SetLength(gLast, Length(gLast) - 1);
end;

// Hands the payload to the main thread and records what was sent, or frees it
// and forgets.  Caller holds the lock; aIndex is the cache slot to update, or
// -1 to append.
function HandOver(aUpdate: TPanelUpdate): boolean;
begin
   Result := False;

   // QueueAsyncCall RAISES once the queue is shut down, and a radio thread polls
   // until its object is torn down -- so this is reached on an ordinary exit,
   // not only on a fault.
   if (Application = nil) or Application.Terminated then
      begin
      Exit;
      end;

   try
      Application.QueueAsyncCall(gRunner.Apply, PtrInt(aUpdate));
      Result := True;
   except
      on E: TObject do
         begin
         LogCaughtException('uPanelUpdate.HandOver', E);
         end;
   end;
end;

procedure SendAndRemember(aUpdate: TPanelUpdate; const aIndex: integer);
var
  slot: integer;
begin
   if not HandOver(aUpdate) then
      begin
      // NEVER BELIEVE A VALUE THAT DID NOT TRAVEL. Dropping the cache entry
      // means the next identical call tries again instead of assuming the panel
      // already shows it.
      aUpdate.Free;

      if aIndex >= 0 then
         begin
         Forget(aIndex);
         end;
      Exit;
      end;

   slot := aIndex;
   if slot < 0 then
      begin
      SetLength(gLast, Length(gLast) + 1);
      slot := High(gLast);
      end;

   gLast[slot].Kind      := aUpdate.Kind;
   gLast[slot].Target    := aUpdate.Target;
   gLast[slot].ControlId := aUpdate.ControlId;
   gLast[slot].Text      := aUpdate.Text;
   gLast[slot].Enabled   := aUpdate.Enabled;
end;

procedure PostPanelText(const aPanel: HWND; const aControlId: integer;
  const aText: string);
var
  i: integer;
  upd: TPanelUpdate;
begin
   if aPanel = 0 then
      begin
      Exit;
      end;

   gLock.Acquire;
   try
      i := IndexOf(puText, aPanel, aControlId);
      if (i >= 0) and (gLast[i].Text = aText) then
         begin
         Exit;
         end;

      upd := TPanelUpdate.Create;
      upd.Kind      := puText;
      upd.Target    := aPanel;
      upd.ControlId := aControlId;
      upd.Text      := aText;

      SendAndRemember(upd, i);
   finally
      gLock.Release;
   end;
end;

procedure PostControlEnable(const aControl: HWND; const aEnabled: boolean);
var
  i: integer;
  upd: TPanelUpdate;
begin
   if aControl = 0 then
      begin
      Exit;
      end;

   gLock.Acquire;
   try
      i := IndexOf(puEnable, aControl, 0);
      if (i >= 0) and (gLast[i].Enabled = aEnabled) then
         begin
         Exit;
         end;

      upd := TPanelUpdate.Create;
      upd.Kind    := puEnable;
      upd.Target  := aControl;
      upd.Enabled := aEnabled;

      SendAndRemember(upd, i);
   finally
      gLock.Release;
   end;
end;

procedure TPanelRunner.Apply(Data: PtrInt);
var
  upd: TPanelUpdate;
  ansi: AnsiString;
begin
   upd := TPanelUpdate(Data);
   if upd = nil then
      begin
      Exit;
      end;

   try
      // The panel may have closed between the post and now. That is ordinary,
      // not an error -- the same race the `if handle <> 0` guards covered.
      if IsWindow(upd.Target) then
         begin
         case upd.Kind of
           puText:
              begin
              // SetDlgItemTextA explicitly, not the generic name: under FPC the
              // generic binds to the W variant and would write UTF-16 into a
              // control expecting ANSI. See CLAUDE.md on 1bea7af4.
              ansi := AnsiString(upd.Text);
              Windows.SetDlgItemTextA(upd.Target, upd.ControlId, PAnsiChar(ansi));
              end;
           puEnable:
              begin
              Windows.EnableWindow(upd.Target, upd.Enabled);
              end;
           end;
         end;

      // Target is 0 for an element -- there is no window to test, and
      // SetMainWindowText guards its own control.
      if upd.Kind = puElement then
         begin
         SetMainWindowText(TMainWindowElement(upd.ControlId), upd.Text);
         end;
   finally
      upd.Free;
   end;
end;

procedure PostElementText(const aElement: TMainWindowElement; const aText: string);
var
  upd: TPanelUpdate;
  idx: integer;
begin
  gLock.Acquire;
  try
     // The same coalescing the panel updates get, and for the same reason: a
     // radio polled every 10 ms hands over the same frequency string most of
     // the time.
     idx := IndexOf(puElement, 0, Ord(aElement));
     if (idx >= 0) and (gLast[idx].Text = aText) then
        begin
        Exit;
        end;

     upd := TPanelUpdate.Create;
     upd.Kind := puElement;
     upd.Target := 0;
     upd.ControlId := Ord(aElement);
     upd.Text := aText;
     SendAndRemember(upd, idx);
  finally
     gLock.Release;
  end;
end;

procedure ForgetPanel(const aPanel: HWND);
var
  i: integer;
begin
   if aPanel = 0 then
      begin
      Exit;
      end;

   gLock.Acquire;
   try
      // Backwards, because Forget shuffles the tail down.
      for i := High(gLast) downto 0 do
         begin
         // Children are forgotten by handle, and a child's handle is not the
         // panel's -- so ask Windows whether the target IS one of this panel's
         // children while the panel still exists.
         //
         // THIS USED TO SAY `not IsWindow(Target)` AND THAT DID NOT WORK, which
         // NY4I found on the bench 2026-08-20: RIT, XIT and SPLIT came back
         // YELLOW after closing and reopening the panel with no radio attached,
         // and no amount of forcing a repaint changed it.
         //
         // The reason is the call ORDER, and the old comment claiming this line
         // "is what actually clears the RIT/XIT/SPLIT statics" was simply wrong.
         // CloseTR4WWindow calls ForgetPanel BEFORE DestroyWindow -- deliberately
         // -- so at this moment the children are still perfectly good windows and
         // IsWindow says so. Their three puEnable entries therefore SURVIVED the
         // close holding Enabled=False. Windows reuses handles, so a freshly
         // created static landing on a remembered HWND made PostControlEnable
         // match the cache and SKIP the post -- while the new control was created
         // ENABLED. The panel then showed enabled (yellow) controls that the
         // cache believed were disabled, and a repaint could not fix it because
         // they genuinely were enabled.
         //
         // MOVING THE CALL AFTER DestroyWindow WOULD NOT BE A FIX. A freed HWND
         // can be reused immediately, so IsWindow can be true again for an
         // unrelated window and the stale entry survives anyway. IsChild answers
         // the question actually being asked, and only works BEFORE the destroy,
         // which is why the existing order is right and only this test was wrong.
         //
         // The IsWindow arm stays as a backstop for an entry whose window died
         // some other way -- it is now belt-and-braces rather than the mechanism.
         if (gLast[i].Target = aPanel) or
            IsChild(aPanel, gLast[i].Target) or
            (not IsWindow(gLast[i].Target)) then
            begin
            Forget(i);
            end;
         end;
   finally
      gLock.Release;
   end;
end;

initialization
   gLock := TCriticalSection.Create;
   gRunner := TPanelRunner.Create;

finalization
   // Any payload still in the async queue at shutdown is leaked deliberately:
   // freeing it here would race the loop that is still draining.
   FreeAndNil(gLock);
   FreeAndNil(gRunner);

end.
