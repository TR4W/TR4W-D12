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
unit uLPTPortEnumerator;
{$I tr4w.inc}

{
  WHICH PARALLEL PORTS THIS MACHINE ACTUALLY HAS.

  The small sibling of ComPortEnumerator, and deliberately much smaller: TR4W can
  only represent LPT1..LPT3 (PortType's Parallel1..Parallel3), so there is nothing
  to discover beyond three answers and no PnP walk worth writing.

  WHY ENUMERATE AT ALL for a port almost nobody has any more (NY4I: "not that I
  have one on any computers"). Because the alternative is a picker that offers
  three ports with no indication that two of them do not exist, and an operator
  who chooses one gets silence -- LPT keying and relay switching fail by simply
  not happening. Naming what is present turns a mystery into a glance.

  TWO PASSES, for the same reason ComPortEnumerator has three: neither source is
  complete on its own.

    1. QueryDosDevice -- the DOS device name, which is what \\.\LPT1 resolves
       through. Already used elsewhere in this tree (BeepUnit), so it is a proven
       call here rather than a new dependency.
    2. HKLM\HARDWARE\DEVICEMAP\PARALLEL PORTS -- the direct analogue of the
       SERIALCOMM key ComPortEnumerator reads. A port can appear here without a
       DOS device name in some driver arrangements.

  Present in EITHER is present. This is a hint for a UI, not a gate: nothing here
  prevents an operator selecting a port TR4W could not detect, because a wrong
  "not detected" must not stop someone using hardware that works.
}

interface

{ True when LPT<n> looks present on this machine. n is 1..3; anything else is
  False, because TR4W cannot represent it. }
function LPTPortPresent(aNumber: integer): boolean;

{ 'LPT1, LPT3' or '' -- for logging what was found, once, at panel load. }
function PresentLPTPortsDescription: string;

implementation

uses
   SysUtils
   {$IFDEF WINDOWS}, Windows{$ENDIF},
  uAnsiStr;

{$IFDEF WINDOWS}
function PresentViaDosDevice(aNumber: integer): boolean;
var
   buf: array[0..1023] of AnsiChar;
begin
   // QueryDosDevice answers 0 with ERROR_FILE_NOT_FOUND for a name that does not
   // exist. It does NOT open the port, so this is safe to call while something
   // else is using it -- which matters, because TR4W itself may already hold the
   // port for keying when Preferences opens.
   FillChar(buf, SizeOf(buf), 0);
   Result := Windows.QueryDosDeviceA(PAnsiChar(WinAnsi('LPT' + IntToStr(aNumber))),
                                     buf, Length(buf)) <> 0;
end;

function PresentViaRegistry(aNumber: integer): boolean;
var
   key: HKEY;
   idx: DWORD;
   nameBuf: array[0..255] of AnsiChar;
   dataBuf: array[0..255] of AnsiChar;
   nameLen, dataLen, valType: DWORD;
   wanted: AnsiString;
begin
   Result := False;
   if Windows.RegOpenKeyExA(HKEY_LOCAL_MACHINE,
                            'HARDWARE\DEVICEMAP\PARALLEL PORTS',
                            0, KEY_READ, key) <> ERROR_SUCCESS then
      begin
      // The key is absent on a machine with no parallel hardware at all, which
      // is not an error -- it is the answer.
      Exit;
      end;

   try
      wanted := AnsiString('LPT' + IntToStr(aNumber));
      idx := 0;
      while True do
         begin
         nameLen := Length(nameBuf);
         dataLen := Length(dataBuf);
         FillChar(nameBuf, SizeOf(nameBuf), 0);
         FillChar(dataBuf, SizeOf(dataBuf), 0);
         if Windows.RegEnumValueA(key, idx, nameBuf, nameLen, nil, @valType,
                                  PByte(@dataBuf[0]), @dataLen) <> ERROR_SUCCESS then
            begin
            Break;
            end;

         // The VALUE is the port name (\Device\Parallel0 -> LPT1), which is the
         // same shape SERIALCOMM uses for COM ports.
         if Pos(string(wanted), UpperCase(string(PAnsiChar(@dataBuf[0])))) > 0 then
            begin
            Result := True;
            Break;
            end;

         Inc(idx);
         end;
   finally
      Windows.RegCloseKey(key);
   end;
end;

{$ELSE}

function PresentViaDeviceNode(aNumber: integer): boolean;
var
   n: string;
begin
   // The Unix spelling, zero-based: LPT1 is /dev/lp0. Both names are checked
   // because which one exists depends on the driver in use (lp vs ppdev), and
   // FileExists is RTL -- no platform API and nothing to link.
   n := IntToStr(aNumber - 1);
   Result := FileExists('/dev/lp' + n) or FileExists('/dev/parport' + n);
end;

{$ENDIF}

function LPTPortPresent(aNumber: integer): boolean;
begin
   // THE ONLY PLACE THAT KNOWS WHICH PLATFORM THIS IS. Everything above and
   // everything that calls it sees one signature and no conditionals.
   Result := False;
   if (aNumber < 1) or (aNumber > 3) then
      begin
      Exit;
      end;

   {$IFDEF WINDOWS}
   Result := PresentViaDosDevice(aNumber) or PresentViaRegistry(aNumber);
   {$ELSE}
   Result := PresentViaDeviceNode(aNumber);
   {$ENDIF}
end;

function PresentLPTPortsDescription: string;
var
   i: integer;
begin
   Result := '';
   for i := 1 to 3 do
      begin
      if LPTPortPresent(i) then
         begin
         if Result <> '' then
            begin
            Result := Result + ', ';
            end;
         Result := Result + 'LPT' + IntToStr(i);
         end;
      end;
end;

end.
