{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
unit uSCP;
{$I tr4w.inc}

{$IMPORTEDDATA OFF}

interface

uses
  VC, TF, Windows;

procedure scpLoadInDateBase(FileName: PChar);
procedure scpClose;
function scpGetAddress(Call: CallString): PAnsiChar;
function scpMakeIndex(c: Char): integer;
function scpFoundCallsign(Call: CallPtr; ListBoxHWND: HWND; data: DataBaseEntryRecordPtr): boolean;

var
  scpDisabled                           : boolean;
  scpLoaded                             : boolean;
  scpHWND                               : HWND;
  scpFMO                                : Cardinal;
  scpMap                                : PAnsiChar;
  SCPIndexArray                         : SCPIndexArrayPtr;
  scpFileSize                           : Cardinal;

implementation

procedure scpClose;
begin
  if not scpLoaded then Exit;
  Windows.UnmapViewOfFile(scpMap);
  CloseHandle(scpFMO);
  CloseHandle(scpHWND);
  scpLoaded := False;
end;

procedure scpLoadInDateBase(FileName: PChar);
begin
  if not tOpenFileForRead(scpHWND, FileName) then
  begin
    scpDisabled := True;
    Exit;
  end;

  scpFileSize := Windows.GetFileSize(scpHWND, nil);

  if scpFileSize <= SizeOf(SCPIndexArrayType) + 4 then
  begin
    CloseHandle(scpHWND);
    Exit;
  end;

  scpFMO := Windows.CreateFileMapping(scpHWND, nil, PAGE_READONLY, 0, 0, nil);
  if scpFMO = 0 then
  begin
    CloseHandle(scpHWND);
    Exit;
  end;

  scpMap := Windows.MapViewOfFile(scpFMO, FILE_MAP_READ, 0, 0, 0);
  SCPIndexArray := Pointer(scpMap);

  scpLoaded := True;

  if scpFileSize <> PCardinal(@scpMap[SizeOf(SCPIndexArrayType)])^ then scpClose;
end;

function scpGetAddress(Call: CallString): PAnsiChar;
begin
  Result := @scpMap[SCPIndexArray[scpMakeIndex(Call[1]), scpMakeIndex(Call[2])]];
end;

function scpMakeIndex(c: Char): integer;
begin
  case c of
    'A'..'Z': Result := Ord(c) - Ord('A');
    '0'..'9': Result := Ord(c) - Ord('0') + 26;
    '/': Result := 36;
  end;
end;

function scpFoundCallsign(Call: CallPtr {eax}; ListBoxHWND: HWND {edx}; data: DataBaseEntryRecordPtr {ecx}): boolean;
label NextByte;
var
  StartingOffset, EndingOffset, Offset  : Cardinal;
  Offset1, Offset2                      : Cardinal;
  Index                                 : PAnsiChar;
  TempBuffer                            : array[0..15] of AnsiChar;
  CallBuffer                            : array[0..15] of AnsiChar;
  Partial1                              : Byte;
  Partial2                              : Byte;
  TempPointer                           : Cardinal;
  X, Y                                  : Char;
  TempListBoxHWND                       : HWND;
  NextKey                               : Char;
//  ScipThisByte                          : boolean;
begin
  Result := False;
  if not scpLoaded then Exit;
  if length(Call^) <= 2 then Exit;

  Windows.ZeroMemory(@CallBuffer, SizeOf(CallBuffer));
  Windows.CopyMemory(@CallBuffer, @Call^[1], length(Call^));
  X := #0;
  Y := #0;

  for TempPointer := 1 to length(Call^) - 1 do
    if Call^[TempPointer] <> '?' then
      if Call^[TempPointer + 1] <> '?' then
      begin
        X := Call^[TempPointer];
        Y := Call^[TempPointer + 1];
        Break;
      end;

  if X = #0 then Exit;
  if Y = #0 then Exit;

  Index := @SCPIndexArray[scpMakeIndex(X), scpMakeIndex(Y)];
  StartingOffset := pCardinal(Index)^;
  EndingOffset := pCardinal(Index + 4)^;
  if ListBoxHWND <> 0 then tLB_RESETCONTENT(ListBoxHWND);

  Offset1 := StartingOffset;
  Offset := StartingOffset;
  NextByte:
//  for Offset := StartingOffset to EndingOffset do
  begin
    if scpMap[Offset] < #30 then
    begin
      Windows.ZeroMemory(@TempBuffer, SizeOf(TempBuffer));
      Windows.CopyMemory(@TempBuffer, @scpMap[Offset1], Offset - Offset1);

      if Result = True then
        if data <> nil then
        begin

//          if ScipThisByte then Continue;

          case NextKey of

            ControlA:
              begin
                Windows.lstrcatA(@data.Section[1], TempBuffer);
                data.Section[0] := CHR(Windows.lstrlenA(TempBuffer));
              end;

            ControlC:
              begin
                Windows.lstrcatA(@data.CQZone[1], TempBuffer);
                data.CQZone[0] := CHR(Windows.lstrlenA(TempBuffer));

              end;

            ControlF:
              begin
                Windows.lstrcatA(@data.FOC[1], TempBuffer);
                data.FOC[0] := CHR(Windows.lstrlenA(TempBuffer));
              end;

            ControlG:
              begin
                Windows.lstrcatA(@data.Grid[1], TempBuffer);
                data.Grid[0] := CHR(Windows.lstrlenA(TempBuffer));
              end;

            ControlH:
              begin
                data.Hits := Ord(scpMap[Offset]);
                inc(Offset);
              end;

            ControlI:
              begin
                Windows.lstrcatA(@data.ITUZone[1], TempBuffer);
                data.ITUZone[0] := CHR(Windows.lstrlenA(TempBuffer));
              end;

            ControlK:
              begin
                Windows.lstrcatA(@data.Check[1], TempBuffer);
                data.Check[0] := CHR(Windows.lstrlenA(TempBuffer));
              end;

            ControlN:
              begin
                Windows.lstrcatA(@data.mName[1], TempBuffer);
                data.mName[0] := CHR(Windows.lstrlenA(TempBuffer));
              end;

            ControlO:
              begin
                Windows.lstrcatA(@data.OldCall[1], TempBuffer);
                data.OldCall[0] := CHR(Windows.lstrlenA(TempBuffer));
              end;

            ControlQ:
              begin
                Windows.lstrcatA(@data.QTH[1], TempBuffer);
                data.QTH[0] := CHR(Windows.lstrlenA(TempBuffer));
              end;

            ControlS:
              begin
                data.Speed := Ord(scpMap[Offset + 1]);
                inc(Offset);
              end;

            ControlT:
              begin
                Windows.lstrcatA(@data.TENTEN[1], TempBuffer);
                data.TENTEN[0] := CHR(Windows.lstrlenA(TempBuffer));
              end;

            ControlU:
              begin
                Windows.lstrcatA(@data.User1[1], TempBuffer);
                data.User1[0] := CHR(Windows.lstrlenA(TempBuffer));
              end;

            ControlV:
              begin
                Windows.lstrcatA(@data.User2[1], TempBuffer);
                data.User2[0] := CHR(Windows.lstrlenA(TempBuffer));
              end;

            ControlW:
              begin
                Windows.lstrcatA(@data.User3[1], TempBuffer);
                data.User3[0] := CHR(Windows.lstrlenA(TempBuffer));
              end;

            ControlX:
              begin
                Windows.lstrcatA(@data.User4[1], TempBuffer);
                data.User4[0] := CHR(Windows.lstrlenA(TempBuffer));
              end;

            ControlY:
              begin
                Windows.lstrcatA(@data.User5[1], TempBuffer);
                data.User5[0] := CHR(Windows.lstrlenA(TempBuffer));
              end;

          end;
          NextKey := scpMap[Offset];
          if NextKey = #0 then Exit;
//          ScipThisByte := False;
        end;

      if StrPosPartial(TempBuffer, CallBuffer) <> nil then
      begin
        if StrComp(TempBuffer, CallBuffer) = 0 then
        begin
          Result := True;
          if data <> nil then
          begin
            ZeroMemory(data, SizeOf(DataBaseEntryRecord));
            NextKey := scpMap[Offset];
            data.Call := Call^;
//            ScipThisByte := False;
          end;
        end;
        if ListBoxHWND <> 0 then tLB_ADDSTRING(ListBoxHWND, TempBuffer);
      end;
      Offset1 := Offset + 1;
    end;

  end;
  inc(Offset);
  if Offset < EndingOffset then goto NextByte;
end;

end.

