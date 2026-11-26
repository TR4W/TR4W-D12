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
unit uCWKeyerCPU;
{$I tr4w.inc}

{
  CPU keyer adapter -- the software dit/dah engine toggling DTR/RTS/LPT
  (K1EAKeyer object in LOGK1EA, timing thread CWThreadProc).  THIN delegation;
  SendString is a verbatim move of LogCW.AddStringToBuffer's CPU arm including
  its quirks (docs/CW_Keyer_Factory_Plan.md):
  - Q8: still clears wkBusy when spawning the CW thread (4.90.5).
  - The Issue #997 TIME_CRITICAL priority call is preserved as-is.
  In the factory's end state this adapter ABSORBS the engine from LOGK1EA;
  today all state stays in the existing globals.
}

interface

uses
   VC, LogRadio, uCWKeyerBase;

type
   TCWKeyerCPU = class(TCWKeyer)
   public
      constructor Create;
      procedure SendString(const Msg: Str160; Tone: integer); override;
      procedure SendChar(ch: Char); override;
      function StillBeingSent: boolean; override;
      function DeleteLastChar: boolean; override;
      procedure Flush; override;
      procedure SetSpeed(wpm: integer); override;
      // No tune: Settings.Cw.TuneWithDits is functionally dead -- out of scope.
      (* ActiveRadioPtr, swapped or not: the CPU keyer drives the ACTIVE radio's
        keying line (LOGK1EA DriveCWLine(ActiveRadioPtr, ...)), and the port
        swap in SetUpToSendOnInactiveRadio is commented out, as it was in D7. *)
      function KeyedRadio: RadioPtr; override;
   end;

(* WHY THE CPU KEYER CANNOT KEY THIS RADIO, or '' when it can: an open keyer
  port with DTR or RTS set to CW. Pure -- reads only the radio record.
  LOGK1EA.DriveCWLine exits in silence on each of these, so this is what puts
  them into words. Log text, not operator text: no resourcestring. *)
function CPUKeyerCannotKeyReason(const aRadio: RadioPtr): string;

(* ONE WARN PER RADIO when CW goes to the CPU keyer and the reason above is not
  '', until LOGK1EA.InitializeKeyer clears CPUKeyerCannotKeyReported. MAIN
  THREAD ONLY, and never from the element timing path. *)
procedure WarnIfCPUKeyerCannotKey(const aRadio: RadioPtr);

implementation

uses
   uAppTimers,   (* StartAppTimer / StopAppTimer -- LCL TTimers, not SetTimer *)
   (* ThreadSetPriority is the RTL's, on every platform, and takes -15..+15
     where Win32 took its own constants. See the call in StartKeyerThread. *)
   Log4D,
   TF,         // tCreateThread
   MainUnit,   // PTTOn, logger
   uConfigValues, // Config.PTTEnable and the paddle settings
   LogK1EA,    // CPUKeyer, CWThreadProc, CPUKeyerCannotKeyReported
   uWinKey,    // wkBusy (Q8)
   uPortAddress; // pkSerial, EffectiveDeviceName -- the one port-name rule

function CPUKeyerCannotKeyReason(const aRadio: RadioPtr): string;
var
   portName: string;
begin
   Result := '';
   if aRadio = nil then
      begin
      Result := 'no radio is selected';
      Exit;
      end;

   if aRadio^.KeyerPortKind <> pkSerial then
      begin
      Result := 'no keyer port is configured (Radio settings: keyer output port, ' +
                'and the profile''s CW output)';
      Exit;
      end;

   portName := EffectiveDeviceName(aRadio^.tKeyerPortName, aRadio^.tKeyerPort);
   if aRadio^.tKeyerSerialPort = nil then
      begin
      Result := 'keyer port ' + portName + ' is configured but not open ' +
                '(see the [Keyer] line logged when the keyer was initialised)';
      Exit;
      end;

   if (aRadio^.tr4w_keyer_DTR_state <> RtsDtr_CW) and
      (aRadio^.tr4w_keyer_rts_state <> RtsDtr_CW) then
      begin
      Result := 'keyer port ' + portName + ' is open but neither DTR nor RTS is set to CW';
      end;
end;

procedure WarnIfCPUKeyerCannotKey(const aRadio: RadioPtr);
var
   slot: integer;
   reason: string;
begin
   if aRadio = @Radio2 then
      begin
      slot := 2;
      end
   else
      begin
      slot := 1;
      end;
   if CPUKeyerCannotKeyReported[slot] then
      begin
      Exit;
      end;

   reason := CPUKeyerCannotKeyReason(aRadio);
   if reason = '' then
      begin
      Exit;
      end;

   CPUKeyerCannotKeyReported[slot] := True;
   if aRadio = nil then
      begin
      logger.Warn('[Keyer] CPU keyer: CW will not key -- ' + reason);
      end
   else
      begin
      logger.Warn('[Keyer] CPU keyer: CW will not key ' + aRadio^.RadioName + ' -- ' + reason);
      end;
end;

function TCWKeyerCPU.KeyedRadio: RadioPtr;
begin
   Result := ActiveRadioPtr;
end;

constructor TCWKeyerCPU.Create;
begin
   inherited Create;
   FName := 'CPU keyer';
   FCapabilities := [ckDeleteLastChar];
end;

procedure TCWKeyerCPU.SendString(const Msg: Str160; Tone: integer);
begin
   (* SAID BEFORE ANYTHING IS QUEUED, once per radio per keyer initialisation:
     a CPU keyer with no line to drive used to run its thread and key nothing,
     in silence (a network K4 with its keyer port never applied, 2026-11-26).
     Not for '' -- the sidetone toggle sends one. *)
   if Msg <> '' then
      begin
      WarnIfCPUKeyerCannotKey(KeyedRadio);
      end;

   // Verbatim move of LogCW.AddStringToBuffer's CPU arm.
   if ActiveRadioPtr.tPTTStatus = PTT_OFF then
      begin
      PTTOn;
      end;
   CPUKeyer.AddStringToCWBuffer(Msg, Tone);

   if not ThreadStarted(CWThreadID) then
      begin
      wkBusy := False;            //  4.90.5 (Q8)
      logger.Info('Calling tCreateThread from TCWKeyerCPU.SendString');
      CWThreadHandle := tCreateThread(CWThreadProc, CWThreadID);
      logger.Info('Created CW thread with threadid of %u', [PtrUInt(CWThreadID)]);
      // Issue #997: priority set on the REAL handle; the old asm pushed a
      // stale EAX and never applied it.  The CW thread runs TIME_CRITICAL.
      (* ThreadSetPriority(h, 15), not SetThreadPriority(h,
        THREAD_PRIORITY_TIME_CRITICAL). The RTL's scale is -15..+15 and 15 is
        its top, which is what the Win32 backend maps to TIME_CRITICAL; the
        handle is a TThreadID from tCreateThread's BeginThread, which is what
        this function takes.

        OFF WINDOWS THIS IS ADVISORY. A pthread priority change usually needs
        a real-time scheduling policy and privileges, so it can fail silently
        -- and CW element timing is the thing that suffers. That is already
        recorded against the clock work (docs\PLATFORM_CLOCK_ABSTRACTION.md);
        the Windows behaviour is unchanged. *)
      ThreadSetPriority(CWThreadHandle, 15);
{$IF OZCR2008}
      if tMessagesExhangeEnable then
         begin
         (* SendMessageStatus is a plain procedure and this passed it as a
           Win32 TIMERPROC -- the same stack mismatch LOGWIND had. See
           uAppTimers. *)
         StartAppTimer(atNetCWStatus, 250, @SendMessageStatus);
         end;
{$IFEND}
      end;
end;

procedure TCWKeyerCPU.SendChar(ch: Char);
begin
   // Verbatim from MainUnit's autosend CPU arm: buffer the raw character --
   // no PTTOn, no thread spawn (the running thread picks it up).
   CPUKeyer.AddCharacterToCWBuffer(ch);
end;

function TCWKeyerCPU.StillBeingSent: boolean;
begin
   Result := CPUKeyer.CWStillBeingSent;
end;

function TCWKeyerCPU.DeleteLastChar: boolean;
begin
   Result := CPUKeyer.DeleteLastCharacter;
end;

procedure TCWKeyerCPU.Flush;
begin
   CPUKeyer.FlushCWBuffer;
end;

procedure TCWKeyerCPU.SetSpeed(wpm: integer);
begin
   CPUKeyer.SetSpeed(wpm);
end;

initialization
   KeyerCPU := TCWKeyerCPU.Create;

finalization
   KeyerCPU.Free;
   KeyerCPU := nil;

end.
