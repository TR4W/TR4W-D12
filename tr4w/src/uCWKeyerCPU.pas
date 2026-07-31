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
   VC, uCWKeyerBase;

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
      // No tune: TuneWithDits is functionally dead -- out of scope.
   end;

implementation

uses
   Windows,    // SetThreadPriority / THREAD_PRIORITY_TIME_CRITICAL
   Log4D,
   TF,         // tCreateThread
   MainUnit,   // PTTOn, logger
   LogRadio,   // ActiveRadioPtr, PTT_OFF
   LogK1EA,    // CPUKeyer, CWThreadProc
   uWinKey;    // wkBusy (Q8)

constructor TCWKeyerCPU.Create;
begin
   inherited Create;
   FName := 'CPU keyer';
   FCapabilities := [ckDeleteLastChar];
end;

procedure TCWKeyerCPU.SendString(const Msg: Str160; Tone: integer);
begin
   // Verbatim move of LogCW.AddStringToBuffer's CPU arm.
   if ActiveRadioPtr.tPTTStatus = PTT_OFF then
      begin
      PTTOn;
      end;
   CPUKeyer.AddStringToCWBuffer(Msg, Tone);

   if CWThreadID = 0 then
      begin
      wkBusy := False;            //  4.90.5 (Q8)
      logger.Info('Calling tCreateThread from TCWKeyerCPU.SendString');
      CWThreadHandle := tCreateThread(@CWThreadProc, CWThreadID);
      logger.Info('Created CW thread with threadid of %d', [CWThreadID]);
      // Issue #997: priority set on the REAL handle; the old asm pushed a
      // stale EAX and never applied it.  The CW thread runs TIME_CRITICAL.
      SetThreadPriority(CWThreadHandle, THREAD_PRIORITY_TIME_CRITICAL);
{$IF OZCR2008}
      if tMessagesExhangeEnable then SetTimer(tr4whandle, UPDATE_NET_CW_MESSAGE, 250, @SendMessageStatus);
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
