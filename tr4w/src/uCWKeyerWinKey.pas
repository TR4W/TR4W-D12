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
unit uCWKeyerWinKey;
{$I tr4w.inc}

{
  WinKeyer (K1EL WK2/WK3) adapter -- thin delegation onto uWinKey's procedural
  API.  Preserved quirks (docs/CW_Keyer_Factory_Plan.md):
  - Q1: Flush sets WKBusy := False ONLY; wkClearBuffer is deliberately NOT
    called (the historical drift; the future fix is a one-liner here).
  - Q3: DeleteLastChar previously returned garbage (LogCW exited without
    setting Result); the adapter pins the de-facto value True.
  - ToggleTune reproduces uProcessCommand.scWK_SWAPTUNE, NOT uWinKey.wkSwapTune
    (which sends `not wkBUSY` -- divergent, pre-existing).
}

interface

uses
   VC, uCWKeyerBase;

type
   TCWKeyerWinKey = class(TCWKeyer)
   public
      constructor Create;
      procedure SendString(const Msg: Str160; Tone: integer); override;
      procedure SendChar(ch: Char); override;
      function StillBeingSent: boolean; override;
      function DeleteLastChar: boolean; override;
      procedure Flush; override;
      procedure SetSpeed(wpm: integer); override;
      procedure ToggleTune; override;
   end;

implementation

uses
   uWinKey, TF;

constructor TCWKeyerWinKey.Create;
begin
   inherited Create;
   FName := 'WinKeyer';
   FCapabilities := [ckTune, ckDeleteLastChar];
end;

procedure TCWKeyerWinKey.SendString(const Msg: Str160; Tone: integer);
begin
   wkAddCWMessageToInternalBuffer(Msg);   // Tone is a CPU-keyer concept; ignored
end;

procedure TCWKeyerWinKey.SendChar(ch: Char);
begin
   // Verbatim from MainUnit's autosend WinKeyer arm -- UpCase preserved.
   // wkSendCWChar, not wkSendByte: this is CW going out, so it must register as
   // outstanding or a later flush would decline to clear a keying device.
   wkSendCWChar(AnsiChar(UpCase(ch)));
end;

function TCWKeyerWinKey.StillBeingSent: boolean;
begin
   Result := wkBUSY;
end;

function TCWKeyerWinKey.DeleteLastChar: boolean;
begin
   wkSendByte(wkCMD_BACKSPACE);
   // Q3: LogCW never set a Result on this path (de facto it returned
   // wkSendByte's nonzero count in EAX).  Pin the sane reading: we DID retract.
   Result := True;
end;

procedure TCWKeyerWinKey.Flush;
begin
   // Q1 RESOLVED (task #22).  The device clear was never actually missing -- it
   // was being issued by the CPU keyer's flush (LOGK1EA.K1EAKeyer.FlushCWBuffer)
   // on behalf of a device it does not own.  Because LogCW.FlushCWBuffer
   // broadcasts to every keyer, that put five blocking WinKeyer writes in the
   // path of every function key even when CW was going by CAT.  The clear now
   // lives here, with the device, and is issued only when the WinKeyer can
   // actually be holding something -- so a keyer that is not sending costs
   // nothing.  Order matters: test BEFORE dropping the busy latch.
   if wkHasPendingOutput then
      begin
      wkClearBuffer;
      end;
   wkBUSY := False;
end;

procedure TCWKeyerWinKey.SetSpeed(wpm: integer);
begin
   // Q5 preserved: called even when the WinKeyer is inactive; wkSetSpeed is
   // handle-guarded internally.
   wkSetSpeed(wpm);
end;

procedure TCWKeyerWinKey.ToggleTune;
begin
   // Verbatim scWK_SWAPTUNE (uProcessCommand): KEYIMMEDIATE with the INVERTED
   // tune state; only flip our flag when both bytes went out.
   if wkSendTwoBytes(wkCMD_KEYIMMEDIATE, Byte(not wkTune)) = 2 then
      begin
      TF.InvertBoolean(wkTune);
      end;
end;

initialization
   KeyerWinKey := TCWKeyerWinKey.Create;

finalization
   KeyerWinKey.Free;
   KeyerWinKey := nil;

end.
