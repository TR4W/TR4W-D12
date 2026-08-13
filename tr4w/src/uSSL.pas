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
unit uSSL;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  VC,
  // Issue #1034: dropped 'TF' (unused here) -- it pulled TF -> MainUnit -> LogStuff,
  // which blocked uSSL (and its uMults consumer) from linking into the test EXE.
  //Country9,
  Windows,
  Messages;

type

  PStringItem = ^TStringItem;

  TStringItem = record
    FMult: Str10;
    FArray: TDupesArray;
    FAltName: Str30;
  end;

  PStringItemList = ^TStringItemList;
  TStringItemList = array[0..10000] of TStringItem;

  TSSL = object {class}
  private
    FCount: integer;
    FCapacity: integer;
//    FTotalMults: array[ModeType] of integer;
    procedure Grow;
  protected
    function GetCapacity: integer;
    procedure SetCapacity(NewCapacity: integer);
    function CompareStrings(const s1, s2: Str10): integer;
    procedure InsertMult(Index: integer; const s: Str10; Band: BandType; Mode: ModeType); virtual;
  public
    FList: PStringItemList;
    TotalMults: integer;
//    destructor Destroy; override;
    constructor Init;
    function StringIsDupeByIndex(IndexInList: integer; Band: BandType; Mode: ModeType): boolean;
    function StringIsDupe(const s: string; Band: BandType; Mode: ModeType; var IndexInList: integer): boolean;
    function Get(Index: integer): string;
    function AddString(const s: string; Band: BandType; Mode: ModeType; JustAdd: boolean): integer;
    procedure Clear;
    procedure Delete(Index: integer);
    procedure ClearDupes;
    function FindMult(const s: string; var Index: integer): boolean; virtual;
    property Count: integer read FCount;
//    property TotalMults: integer read FTotalMults;

  end;

implementation

constructor TSSL.Init;
begin
  Grow;
end;

{
destructor TSSL.Destroy;
begin
  inherited Destroy;
  if FCount <> 0 then Finalize(FList^[0], FCount);
  FCount := 0;
  SetCapacity(0);
end;
}

function TSSL.AddString(const s: string; Band: BandType; Mode: ModeType; JustAdd: boolean): integer;
label
  Add;
var
  TempMode                              : ModeType;
begin
  if FindMult(s, Result) then
     begin
     goto Add;
     end;
  InsertMult(Result, s, Band, Mode);
  Add:
  if JustAdd then Exit;
  // FM shares the Phone dupe/mult slot.  FArray is array[CW..NoMode]; FM
  // (ordinal 5) is OUTSIDE it, so FArray[FM] is out of bounds -- a range
  // error under D12 range-checking (a silent past-the-array write in D7).
  // StringIsDupe already remaps FM->Phone; mirror it here.
  TempMode := Mode;
  if TempMode = FM then
     begin
     TempMode := Phone;
     end;
  FList^[Result].FArray[TempMode] := FList^[Result].FArray[TempMode] or (1 shl Ord(Band));
  FList^[Result].FArray[Both] := FList^[Result].FArray[Both] or (1 shl Ord(Band));
  FList^[Result].FArray[TempMode] := FList^[Result].FArray[TempMode] or (1 shl Ord(AllBands));
  FList^[Result].FArray[Both] := FList^[Result].FArray[Both] or (1 shl Ord(AllBands));
end;

procedure TSSL.Clear;
begin
  if FCount <> 0 then
     begin

     FCount := 0;
     Windows.ZeroMemory(@TotalMults, SizeOf(TotalMults));
 //    FTotalMults := 0;
     SetCapacity(0);
     end;
end;

procedure TSSL.Delete(Index: integer);
begin
  if (Index < 0) or (Index >= FCount) then Exit; //Error(@SListIndexError, Index);
 
  dec(FCount);
  if Index < FCount then
     begin
     System.Move(FList^[Index + 1], FList^[Index], (FCount - Index) * SizeOf(TStringItem));
     end;
end;

function TSSL.StringIsDupeByIndex(IndexInList: integer; Band: BandType; Mode: ModeType): boolean;
var
  TempMode                              : ModeType;
begin
  // FM shares the Phone slot (see AddString): FArray is array[CW..NoMode] and
  // FM is outside it, so remap before indexing to avoid an out-of-bounds read.
  TempMode := Mode;
  if TempMode = FM then
     begin
     TempMode := Phone;
     end;
  Result := (FList^[IndexInList].FArray[TempMode] and (1 shl Ord(Band))) <> 0;
end;

function TSSL.StringIsDupe(const s: string; Band: BandType; Mode: ModeType; var IndexInList: integer): boolean;
var
  Index                                 : integer;
  TempMode                              : ModeType;
begin
  Result := False;
  if FindMult(s, Index) then
     begin
     TempMode := Mode;
     if TempMode = FM then
        begin
        TempMode := Phone;
        end;
     Result := (FList^[Index].FArray[TempMode] and (1 shl Ord(Band))) <> 0;
     IndexInList := Index;
     end
  else
     begin
     IndexInList := -1;
     end;
end;

function TSSL.FindMult(const s: string; var Index: integer): boolean;
var
  l, h, i, c                            : integer;
begin
  Result := False;
  l := 0;
  h := FCount - 1;
  while l <= h do
     begin
     i := (l + h) shr 1;
     c := CompareStrings(FList^[i].FMult, s);
     if c < 0 then l := i + 1 else
                                 begin
                                 h := i - 1;
                                 if c = 0 then
                                    begin
                                    Result := True;
                                    l := i;
                                    end;
                                 end;
     end;
  Index := l;
end;

function TSSL.Get(Index: integer): string;
begin
  Result := FList^[Index].FMult;
end;

function TSSL.GetCapacity: integer;
begin
  Result := FCapacity;
end;

procedure TSSL.Grow;
var
  delta                                 : integer;
begin
  if FCapacity > 64 then delta := FCapacity div 4 else
    if FCapacity > 8 then delta := 16 else
                                         begin
                                         delta := 4;
                                         end;
  SetCapacity(FCapacity + delta);
end;

procedure TSSL.InsertMult(Index: integer; const s: Str10; Band: BandType; Mode: ModeType);
begin
  if FCount = FCapacity then
     begin
     Grow;
     end;
  if Index < FCount then
     begin
     System.Move(FList^[Index], FList^[Index + 1],
       (FCount - Index) * SizeOf(TStringItem));
     end;

  Windows.ZeroMemory(@FList^[Index], SizeOf(FList^[Index]));
  FList^[Index].FMult := s;
  inc(FCount);
end;

procedure TSSL.SetCapacity(NewCapacity: integer);
begin
  ReallocMem(FList, NewCapacity * SizeOf(TStringItem));
  FCapacity := NewCapacity;
end;

function TSSL.CompareStrings(const s1, s2: Str10): integer;
begin
  // CompareStringA (not the unsuffixed CompareString, which is CompareStringW
  // under D12): s1/s2 are ANSI ShortStrings (Str10).  Passing ANSI bytes to
  // the wide API compared them as UTF-16 -> garbage ordering in the mult/dupe
  // binary search -> unbounded list growth + range error (WFD range error at
  // FArray[Mode]), and silent multiplier miscounts on logs that don't crash.
  Result := CompareStringA(LOCALE_SYSTEM_DEFAULT, NORM_IGNORECASE, @s1[1], length(s1), @s2[1], length(s2)) - 2;
//  RESULT := StrComp(@s1[1], @s2[1]);
end;

procedure TSSL.ClearDupes;
var
  Index                                 : integer;
begin
  for Index := 0 to FCount - 1 do
     begin
     Windows.ZeroMemory(@FList^[Index].FArray, SizeOf(TDupesArray));
     end;
end;

end.

