(*
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
 *)

(* THE TX-INHIBITED WARNING ON THE MAIN WINDOW -- issue #97, phase 2.

  WHAT THE OPERATOR SEES, for one key-up on a radio that reports it will not
  radiate (a K4 in TX test mode), and nothing at any other time:

    * the PTT indicator says INH on the alert colour (uStateBridge.ApplyPTT and
      MainUnit.PTTIndicatorBack, driven by RadioState.TXInhibitAlert);
    * the keyed radio's status panel says "TX INHIBITED: <reason>";
    * one Warn line in tr4w.log, and an optional beep (PTT TX INHIBIT BEEP);
    * NEVER a modal dialog -- one in a pileup is worse than the problem.
  All of it clears on unkey or when the condition clears.

  THE DECISION IS uTXInhibitAlert's.  This unit feeds it and presents it, ON
  THE MAIN THREAD ONLY: every entry point that can be reached from another
  thread sets a flag and asks for the coalesced mtTXInhibitAlert job, so no
  control is touched from the polling, paddle or DVK thread (issue #108).

  THE TWO TRIGGERS, AND WHERE THEY ARE HOOKED -- the narrowest common point
  each, not every caller:
    1. TR4W keys:  LogCW.AddStringToBuffer (every CW message that is really
       sent, on the radio the active KEYER says it keys -- TCWKeyer.KeyedRadio:
       the SO2R swap for CW-by-CAT and the WinKeyer, the active radio for the
       CPU keyer, the box's TX radio for the YCCC), MainUnit.PTTOn (every PTT
       TR4W asserts, on the active radio) and logdvp.tsndPlaySound (a voice
       message on the active radio, VOX included).  NoteTransmitStarting.
       MainUnit.PTTOff is NoteTransmitEnded.
    2. The radio reports TX:  uRadioPolling.UpdateStatus, when the SETTLED
       status moves, asks for the review, which reads TXOn and the condition
       from that settled snapshot.

  A LINK THAT IS DOWN IS NOT BELIEVED.  After a drop the slot can still hold
  the last session's "inhibited" until the reconnect answers (phase 1's note).
  So a radio whose rig^.RadioDisconnected is set -- the same flag that turns
  its frequency the alert colour, maintained by the polling thread on every
  link transition and read on the main thread by the colour sweep already --
  counts as neither inhibited nor transmitting, and both link transitions ask
  for a review so an alert up at the moment of the drop is taken down.

  THIS UNIT NEVER RAISES INTO A KEYING PATH.  Its triggers run inside PTTOn
  after PTT is on, and inside AddStringToBuffer before the CW is sent; an
  exception escaping either would leave PTT held or the message unsent.  So
  NoteTransmitStarting and NoteTransmitEnded catch everything, log it at
  Error and return -- a missed warning is the right failure, a stuck
  transmitter is not.

  ONE REVIEW PER KEY-UP FROM TR4W, NOT ONE PER CHARACTER.  LogSend hands an
  F-key macro to AddStringToBuffer a character at a time, so a 30-character CQ
  was 30 reviews and 30 restarts of the wait.  GKeyUpNoted marks a slot whose
  key-up TR4W has already reported; further starts return at the cost of one
  interlocked exchange until the review sees that key-up end (or TR4W drops
  PTT). *)
unit uTXInhibitView;

{$I ..\..\tr4w.inc}

interface

uses
   LogRadio,           (* RadioPtr *)
   uTXInhibitAlert;

(* TRIGGER 1: TR4W is keying rig.  Any thread; on the main thread the warning is
  shown before this returns. *)
procedure NoteTransmitStarting(rig: RadioPtr);

(* TR4W has dropped PTT on rig.  Any thread. *)
procedure NoteTransmitEnded(rig: RadioPtr);

(* THE REVIEW: both radios' settled status, plus whatever TR4W did since the
  last review, applied and presented.  MAIN THREAD -- it is the mtTXInhibitAlert
  job, and the triggers call it directly when they are already there. *)
procedure ReviewTXInhibit;

(* The alert for rig's slot, for a test to ask.  Never nil. *)
function TXInhibitAlertOf(rig: RadioPtr): TTXInhibitAlert;

(* TEST ONLY: while True, every review raises -- the way a test proves that a
  fault here never reaches PTTOn or AddStringToBuffer.  Never set in the
  program. *)
var
   TXInhibitFaultInjection: boolean = False;

(* PUT EVERYTHING BACK: both alerts fresh, nothing pending, the wait disarmed,
  this unit's status text taken down and the PTT indicator's alert off.  For a
  test, so one leaves nothing behind for the next.  Main thread. *)
procedure ResetTXInhibitAlerts;

implementation

uses
   SysUtils,
   ExtCtrls,           (* TTimer -- the one-shot wait for the radio's TX report *)
   VC,                 (* TStatusOwner *)
   uCrashLog,          (* OnMainThread *)
   uMainThreadWork,    (* RequestMainThreadJob, RegisterMainThreadJob *)
   uPanelUpdate,       (* PostStatusText / CurrentStatusText *)
   uRadioState,        (* TXInhibitAlert -- what the PTT indicator paints from *)
   uSettingsModel,     (* Settings.Ptt.TxInhibitBeep *)
   LogK1EA,            (* DoABeep *)
   MainUnit;           (* logger *)

const
   (* HOW LONG A KEY-UP TR4W STARTED WAITS FOR THE RADIO TO SAY IT TRANSMITS.
     A network K4 reports TX in about a tenth of a second and a serial one
     within a poll; a radio that has said nothing after this did not key, and
     the alert must not stay up over a receiving station. *)
   PROGRAM_KEY_WAIT_MS = 3000;

type
   TRadioSlot = stoRadio1..stoRadio2;

   (* TTimer wants a method, so one object owns the wait. *)
   TTXInhibitWaiter = class(TObject)
   public
      procedure Expired(Sender: TObject);
   end;

var
   GAlerts: array[TRadioSlot] of TTXInhibitAlert;
   (* Set from any thread, taken on the main thread by the review. *)
   GKeyPending: array[TRadioSlot] of LongInt;
   GUnkeyPending: array[TRadioSlot] of LongInt;
   (* 1 while a key-up TR4W started on the slot is already reported -- see the
     header.  Set by NoteTransmitStarting, cleared by NoteTransmitEnded and by
     the review once the alert's key-up is over. *)
   GKeyUpNoted: array[TRadioSlot] of LongInt;
   (* THE TEXT THIS UNIT PUT ON A STATUS PANEL, so the clear takes down only its
     own.  The panel is shared with the radio's other conditions (split, link
     failure); the clear asks the panel's cache whether this text is still the
     one showing before it writes ''. *)
   GPosted: array[TRadioSlot] of string;
   GWaitTimer: TTimer = nil;
   GWaiter: TTXInhibitWaiter = nil;

function SlotOf(rig: RadioPtr): TRadioSlot;
begin
   Result := RadioStatusOwner(rig);
end;

function RadioOfSlot(const aSlot: TRadioSlot): RadioPtr;
begin
   if aSlot = stoRadio2 then
      begin
      Result := @Radio2;
      end
   else
      begin
      Result := @Radio1;
      end;
end;

function TXInhibitAlertOf(rig: RadioPtr): TTXInhibitAlert;
begin
   Result := GAlerts[SlotOf(rig)];
end;

(* PRESENT ONE SLOT: the once-per-key-up warning, and the status panel. *)
procedure PresentSlot(const aSlot: TRadioSlot);
var
   alert: TTXInhibitAlert;
   rig: RadioPtr;
   beep: boolean;
begin
   alert := GAlerts[aSlot];
   rig := RadioOfSlot(aSlot);

   if alert.TakeKeyUpWarning(beep) then
      begin
      logger.Warn('[TX inhibit] %s is keyed and reports TX inhibited (%s) -- ' +
                  'no RF is going out', [string(rig^.RadioName), alert.Reason]);
      if beep then
         begin
         (* A thread of its own -- a key-up is the wrong moment to block the
           main thread for the length of a tone. *)
         DoABeep(LogK1EA.Warning);
         end;
      end;

   if alert.Showing then
      begin
      GPosted[aSlot] := alert.StatusText;
      PostStatusText(aSlot, GPosted[aSlot]);
      end
   else if GPosted[aSlot] <> '' then
      begin
      if CurrentStatusText(aSlot) = GPosted[aSlot] then
         begin
         PostStatusText(aSlot, '');
         end;
      GPosted[aSlot] := '';
      end;
end;

(* THE ONE-SHOT WAIT: armed while a key-up TR4W started has not been confirmed
  by the radio, restarted by each new one, off otherwise. *)
procedure ArmWait(const aRestart: boolean);
var
   awaiting: boolean;
begin
   awaiting := GAlerts[stoRadio1].AwaitingRadioTX or
               GAlerts[stoRadio2].AwaitingRadioTX;

   if not awaiting then
      begin
      if GWaitTimer <> nil then
         begin
         GWaitTimer.Enabled := False;
         end;
      Exit;
      end;

   if GWaitTimer = nil then
      begin
      GWaiter := TTXInhibitWaiter.Create;
      GWaitTimer := TTimer.Create(nil);
      GWaitTimer.Enabled := False;
      GWaitTimer.Interval := PROGRAM_KEY_WAIT_MS;
      GWaitTimer.OnTimer := GWaiter.Expired;
      end;

   (* Enabled False then True is what restarts a TTimer's countdown. *)
   if aRestart then
      begin
      GWaitTimer.Enabled := False;
      end;
   GWaitTimer.Enabled := True;
end;

(* THE KEY-UP IS OVER: let the next start through. *)
procedure SyncKeyUpNoted(const aSlot: TRadioSlot);
begin
   if not GAlerts[aSlot].ProgramKeyUp then
      begin
      InterlockedExchange(GKeyUpNoted[aSlot], 0);
      end;
end;

procedure PublishIndicator;
begin
   if RadioState <> nil then
      begin
      RadioState.TXInhibitAlert := GAlerts[stoRadio1].Showing or
                                   GAlerts[stoRadio2].Showing;
      end;
end;

procedure ReviewTXInhibit;
var
   slot: TRadioSlot;
   rig: RadioPtr;
   alert: TTXInhibitAlert;
   linkUp: boolean;
   inhibited: boolean;
   reason: string;
   radioTX: boolean;
   restart: boolean;
begin
   if TXInhibitFaultInjection then
      begin
      raise Exception.Create('injected TX-inhibit review fault (test only)');
      end;

   restart := False;

   for slot := Low(TRadioSlot) to High(TRadioSlot) do
      begin
      rig := RadioOfSlot(slot);
      alert := GAlerts[slot];

      (* NOT ACROSS A DOWN LINK -- see the header. *)
      linkUp := not rig^.RadioDisconnected;
      inhibited := linkUp and RadioTXInhibited(rig, reason);
      radioTX := linkUp and ReadRadioStatus(rig).TXOn;

      alert.BeepEnabled := Settings.Ptt.TxInhibitBeep;
      alert.RadioReport(radioTX, inhibited, reason);

      (* Unkey before key: the order TR4W does them in when one message
        follows another (flush and drop PTT, then send). *)
      if InterlockedExchange(GUnkeyPending[slot], 0) <> 0 then
         begin
         alert.ProgramUnkeyed;
         end;
      if InterlockedExchange(GKeyPending[slot], 0) <> 0 then
         begin
         alert.ProgramKeyed;
         restart := True;
         end;

      SyncKeyUpNoted(slot);
      PresentSlot(slot);
      end;

   PublishIndicator;
   ArmWait(restart);
end;

procedure TTXInhibitWaiter.Expired(Sender: TObject);
var
   slot: TRadioSlot;
begin
   GWaitTimer.Enabled := False;     (* one shot *)

   for slot := Low(TRadioSlot) to High(TRadioSlot) do
      begin
      GAlerts[slot].ProgramKeyExpired;
      SyncKeyUpNoted(slot);
      PresentSlot(slot);
      end;

   PublishIndicator;
end;

procedure RequestReview;
begin
   if OnMainThread then
      begin
      ReviewTXInhibit;
      end
   else
      begin
      RequestMainThreadJob(mtTXInhibitAlert);
      end;
end;

(* A FAULT HERE IS LOGGED AND SWALLOWED -- see the header. *)
procedure ReportFault(const aWhere: string; E: Exception);
begin
   try
      logger.Error('[TX inhibit] %s failed, keying carries on without the ' +
                   'warning: %s: %s', [aWhere, E.ClassName, E.Message]);
   except
      (* Nothing -- not even a failed log line may reach the keying path. *)
   end;
end;

procedure NoteTransmitStarting(rig: RadioPtr);
var
   slot: TRadioSlot;
begin
   try
      if rig = nil then
         begin
         Exit;
         end;
      slot := SlotOf(rig);
      if InterlockedExchange(GKeyUpNoted[slot], 1) = 1 then
         begin
         Exit;      (* this key-up is already reported *)
         end;
      InterlockedExchange(GKeyPending[slot], 1);
      RequestReview;
   except
      on E: Exception do
         begin
         ReportFault('the key-up review', E);
         end;
   end;
end;

procedure NoteTransmitEnded(rig: RadioPtr);
var
   slot: TRadioSlot;
begin
   try
      if rig = nil then
         begin
         Exit;
         end;
      slot := SlotOf(rig);
      InterlockedExchange(GKeyUpNoted[slot], 0);
      InterlockedExchange(GUnkeyPending[slot], 1);
      RequestReview;
   except
      on E: Exception do
         begin
         ReportFault('the unkey review', E);
         end;
   end;
end;

procedure ResetTXInhibitAlerts;
var
   slot: TRadioSlot;
begin
   for slot := Low(TRadioSlot) to High(TRadioSlot) do
      begin
      GAlerts[slot].Free;
      GAlerts[slot] := TTXInhibitAlert.Create;
      GKeyPending[slot] := 0;
      GUnkeyPending[slot] := 0;
      GKeyUpNoted[slot] := 0;
      PresentSlot(slot);
      end;
   PublishIndicator;
   ArmWait(False);
end;

procedure CreateAlerts;
var
   slot: TRadioSlot;
begin
   for slot := Low(TRadioSlot) to High(TRadioSlot) do
      begin
      GAlerts[slot] := TTXInhibitAlert.Create;
      end;
end;

procedure FreeAlerts;
var
   slot: TRadioSlot;
begin
   for slot := Low(TRadioSlot) to High(TRadioSlot) do
      begin
      FreeAndNil(GAlerts[slot]);
      end;
end;

initialization
   CreateAlerts;
   RegisterMainThreadJob(mtTXInhibitAlert, @ReviewTXInhibit);

finalization
   (* The timer before the object its OnTimer names. *)
   FreeAndNil(GWaitTimer);
   FreeAndNil(GWaiter);
   FreeAlerts;

end.
