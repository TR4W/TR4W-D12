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
  (* WINDOWS IS GONE (2026-09-08), and the comment that stood here was wrong.

    It said the unit needed IsChild and IsWindow, and that IsChild was "the one
    that matters". Both were operating on a value that has not been a window
    handle since 2026-09-06 -- see ForgetPanel. Removing them fixes a defect
    rather than costing one. *)
  VC;      // TMainWindowElement -- what a puElement update addresses

// Set a child control's text from ANY thread. aPanel = 0, or a panel that has
// closed, is not an error: the update is dropped, exactly as the guarded
// `if handle <> 0` at each call site did before.
procedure PostPanelText(const aPanel: integer; const aControlId: integer;
  const aText: string);

{ Enable or disable one panel control from ANY thread.

  BY (PANEL, CONTROL ID), exactly like PostPanelText.  It used to take the
  CONTROL's own window handle, which the caller got from GetDlgItem -- and that
  cannot survive the panel becoming a form, because the LCL's TLabel is a
  TGraphicControl and HAS NO HANDLE AT ALL.  There is nothing to pass.

  Addressing both kinds the same way also means the coalescing cache is keyed
  the same way for both, which it was not before. }
procedure PostPanelEnable(const aPanel: integer; const aControlId: integer;
  const aEnabled: boolean);

{ Sets one main-window element's text FROM A WORKER THREAD.  Coalesced and
  marshalled exactly like a panel update -- see TPanelUpdateKind.puElement for
  why it cannot simply be SetWindowText on the element's handle. }
procedure PostElementText(const aElement: TMainWindowElement; const aText: string);

// Forget everything remembered about a panel and its children. Call when a
// panel closes: a window handle can be REUSED by Windows, and a stale cache
// entry would then suppress the first update to a different window.
procedure ForgetPanel(const aPanel: integer);

type
  { WHERE A MARSHALLED UPDATE LANDS WHEN THE PANEL IS A FORM.

    Everything above this line is unchanged: the radio threads still post
    (panel handle, control id) and the coalescing is still keyed on that pair.
    What changed is the LAST STEP.  SetDlgItemTextA and EnableWindow only work
    on a Win32 control; a form's label paints from a property, and writing its
    window behind the LCL's back leaves the property holding the old text --
    the same stale-property trap as the tool-window captions.

    A HOOK RATHER THAN A uses CLAUSE, because uPanelUpdate is below the forms:
    it is used by uRadioPolling, which the form unit must be free to reference.
    uRadioPanelForm installs these in its initialization.

    RETURNING False IS NOW A REPORTED DEFECT, not a fallback.  It meant
    "not mine, use the Win32 path", and that path is gone (2026-09-06): every
    caller targets rig^.tRadioInterfaceWndHandle, which MainUnit assigns from
    TfrmRadioPanel.Handle and from nowhere else.  SetDlgItemTextA against an
    LCL form finds no dialog item, changes nothing, and returns as though it
    worked -- so an id the hook does not know would have vanished in silence.
    Now it is logged, once per id, and the update is dropped loudly. }
  TPanelTextHook = function(const aPanel: integer; const aControlId: integer;
                            const aText: string): boolean;
  TPanelEnableHook = function(const aPanel: integer; const aControlId: integer;
                              const aEnabled: boolean): boolean;

var
  PanelTextHook: TPanelTextHook = nil;
  PanelEnableHook: TPanelEnableHook = nil;

  (* IS THIS PANEL SLOT OPEN?

    Was IsWindow(upd.Target) -- a Win32 call that worked only while Target was
    a window HANDLE. It asks whether the panel closed between the post and the
    apply, which is ORDINARY rather than an error, and is why that branch
    reports nothing when it fails. When Target became a slot, IsWindow(1) was
    False and every panel update vanished silently (measured 2026-09-06: 74
    posts handed over, 0 applied, 0 reported).

    A hook for the same reason the other two are hooks: this unit sits BELOW
    the forms and cannot ask one whether it exists. Nil means "assume open",
    so a caller that installs no hook behaves as it did before any of them. *)
  PanelOpenHook: function(const aPanel: integer): boolean = nil;

implementation

uses
  SysUtils, SyncObjs,
  Forms,       // Application.QueueAsyncCall -- the transport
  uMainForm,   // SetElementText -- writing an element BY ELEMENT, which is
               // what a dispatcher has; the named sites assign the panel
               // directly
  MainUnit,    // the global `logger` -- an unclaimed panel id is reported,
               // not swallowed
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
    Target: integer;          // the PANEL for puText, the CONTROL for puEnable
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
    Target: integer;
    ControlId: integer;
    Text: string;
    Enabled: boolean;
  end;

var
  gLock: TCriticalSection = nil;
  gRunner: TPanelRunner = nil;
  gLast: array of TLastPosted;

// Caller holds the lock. Returns the index, or -1.
function IndexOf(const aKind: TPanelUpdateKind; const aTarget: integer;
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

procedure PostPanelText(const aPanel: integer; const aControlId: integer;
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

procedure PostPanelEnable(const aPanel: integer; const aControlId: integer;
  const aEnabled: boolean);
var
  upd: TPanelUpdate;
  idx: integer;
begin
   gLock.Acquire;
   try
      idx := IndexOf(puEnable, aPanel, aControlId);
      if (idx >= 0) and (gLast[idx].Enabled = aEnabled) then
         begin
         // Unchanged since the last successful hand-over: drop it. This is what
         // makes a 10 ms poll rate cost nothing in the steady state.
         Exit;
         end;

      upd := TPanelUpdate.Create;
      upd.Kind := puEnable;
      upd.Target := aPanel;
      upd.ControlId := aControlId;
      upd.Enabled := aEnabled;

      SendAndRemember(upd, idx);
   finally
      gLock.Release;
   end;
end;

(* ONCE PER CONTROL ID, because the radio thread posts on every poll.

   An unclaimed id is a coding defect -- the hook and the poller disagree about
   what a panel shows -- and a defect that repeats twice a second is one nobody
   reads.  The set is deliberately keyed on the id alone: a given id means the
   same thing on both panels, and both panels install the same hook. *)
var
  gUnclaimed: set of Byte = [];

procedure ReportUnclaimed(const aKind: string; const aControlId: integer);
begin
   if (aControlId >= 0) and (aControlId <= 255) then
      begin
      if Byte(aControlId) in gUnclaimed then
         begin
         Exit;
         end;
      Include(gUnclaimed, Byte(aControlId));
      end;

   if logger <> nil then
      begin
      logger.Error('[Panel] no radio-panel control claimed %s update for id %d '
                   + '-- the update was dropped', [aKind, aControlId]);
      end;
end;

procedure TPanelRunner.Apply(Data: PtrInt);
var
  upd: TPanelUpdate;
begin
   upd := TPanelUpdate(Data);
   if upd = nil then
      begin
      Exit;
      end;

   try
      // The panel may have closed between the post and now. That is ordinary,
      // not an error -- the same race the `if handle <> 0` guards covered.
      // See PanelOpenHook for why this is no longer IsWindow.
      if (not Assigned(PanelOpenHook)) or PanelOpenHook(upd.Target) then
         begin
         case upd.Kind of
           puText:
              begin
              if (not Assigned(PanelTextHook)) or
                 (not PanelTextHook(upd.Target, upd.ControlId, upd.Text)) then
                 begin
                 ReportUnclaimed('text', upd.ControlId);
                 end;
              end;
           puEnable:
              begin
              if (not Assigned(PanelEnableHook)) or
                 (not PanelEnableHook(upd.Target, upd.ControlId, upd.Enabled)) then
                 begin
                 ReportUnclaimed('enable', upd.ControlId);
                 end;
              end;
           end;
         end;

      (* Target is 0 for an element -- there is no window to test, and
        SetElementText guards its own control.

        BY ELEMENT, because a marshalled update carries an element ID and not
        a control: this is a dispatcher, and naming a panel here is not
        possible. *)
      if upd.Kind = puElement then
         begin
         SetElementText(TMainWindowElement(upd.ControlId), upd.Text);
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

procedure ForgetPanel(const aPanel: integer);
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
         (* MATCH THE SLOT. The two window tests that stood here were tests on
           a value that stopped being a window handle.

           WHY THE CACHE IS CLEARED AT ALL -- the original reasoning, which is
           still the reason this routine exists. CloseTR4WWindow calls
           ForgetPanel BEFORE the window goes, deliberately, so the children
           are still live at this moment and their puEnable entries would
           SURVIVE the close holding Enabled=False. Windows reuses handles, so
           a freshly created control landing on a remembered HWND matched the
           cache, PostControlEnable skipped the post, and the panel showed
           enabled controls the cache believed were disabled. A repaint could
           not fix it, because they genuinely were enabled (bench, 2026-08-20).

           THAT ACCOUNT IS HISTORY NOW, and the code had not kept up. Target
           has held a PANEL SLOT since 2026-09-06 -- 1 or 2 for puText and
           puEnable, and 0 for puElement -- because a TLabel is a
           TGraphicControl and has no handle to hold. See the note on
           PanelOpenHook, which exists because IsWindow(1) was False and every
           panel update vanished silently.

           So `IsChild(aPanel, Target)` compared two small integers as window
           handles, and `not IsWindow(Target)` was ALWAYS TRUE -- which made
           this condition always true, and ForgetPanel(1) cleared panel 2's
           entries and every puElement entry along with its own. Benign, in
           that the next post simply re-sent, but it is not what any of the
           text above claims and it hid the coalescing the cache is for.

           The slot match is the whole test. puElement entries are excluded
           explicitly: they belong to the main window, not to either panel,
           and closing a radio panel has nothing to say about them. *)
         if (gLast[i].Kind <> puElement) and (gLast[i].Target = aPanel) then
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
