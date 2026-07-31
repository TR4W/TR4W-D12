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
unit uCWKeyerYCCC;

{
  YCCC SO2R+ box adapter -- thin delegation onto uYCCCSO2R.  Preserved quirks
  (docs/CW_Keyer_Factory_Plan.md):
  - Q2: SetSpeed is a no-op -- YCCCSetSpeed is commented out in today's LogCW.
  - Q4: autosend characters have NO YCCC arm today; they go to the CPU keyer.
    SendChar preserves that by delegating to KeyerCPU.
}

interface

uses
   VC, uCWKeyerBase;

type
   TCWKeyerYCCC = class(TCWKeyer)
   public
      constructor Create;
      procedure SendString(const Msg: Str160; Tone: integer); override;
      procedure SendChar(ch: Char); override;
      function StillBeingSent: boolean; override;
      function DeleteLastChar: boolean; override;
      procedure Flush; override;
      // SetSpeed: inherited no-op (Q2 -- YCCCSetSpeed commented out today).
   end;

implementation

uses
   uYCCCSO2R;

constructor TCWKeyerYCCC.Create;
begin
   inherited Create;
   FName := 'YCCC SO2R+';
   FCapabilities := [ckDeleteLastChar];
end;

procedure TCWKeyerYCCC.SendString(const Msg: Str160; Tone: integer);
begin
   YCCCAddCWMessageToBuffer(Msg);   // Tone is a CPU-keyer concept; ignored
end;

procedure TCWKeyerYCCC.SendChar(ch: Char);
begin
   // Q4 preserved: today's autosend has no YCCC arm -- chars key via the CPU
   // keyer even while the YCCC box handles messages.
   if KeyerCPU <> nil then
      begin
      KeyerCPU.SendChar(ch);
      end;
end;

function TCWKeyerYCCC.StillBeingSent: boolean;
begin
   Result := YCCCCWBusy;
end;

function TCWKeyerYCCC.DeleteLastChar: boolean;
begin
   Result := YCCCDeleteLastChar;
end;

procedure TCWKeyerYCCC.Flush;
begin
   // Guard kept from LogCW: only flush when the box is actually active.
   if ycccActive then
      begin
      YCCCFlushCWBuffer;
      end;
end;

initialization
   KeyerYCCC := TCWKeyerYCCC.Create;

finalization
   KeyerYCCC.Free;
   KeyerYCCC := nil;

end.
