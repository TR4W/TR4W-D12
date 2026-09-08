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
unit uSortedStringList;

(* RENAMED FROM uSSL / TSSL ON 2026-09-07, AND THE OLD NAME COST REAL TIME.

  This is a SORTED STRING LIST -- a hand-rolled sorted array of
  (multiplier, per-band/mode dupe flags, alternate name), with a binary search
  over it. It is the multiplier and dupe store, and it has nothing whatever to
  do with TLS.

  "uSSL" reads as OpenSSL, and it misled NY4I in the very session that renamed
  it: he read a report that this unit still named Windows and answered "uSSL
  should strictly use Indy". A reasonable inference from the name, and wrong --
  the Windows reference was CompareStringA in CompareStrings, the ordering key
  for the binary search. There ARE SSL units in this tree; they are Indy's
  IdSSLOpenSSL* under include/Protocols, and their types really are TSSL_CTX_*.

  NY4I: "It is terribly misnamed. USortedStringList.pas would avoid repeating
  this mistake." *)
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  VC,
  // Issue #1034: dropped 'TF' (unused here) -- it pulled TF -> MainUnit -> LogStuff,
  // which blocked uSortedStringList (and its uMults consumer) from linking into the test EXE.
  //Country9,
  uStringCompare;   (* CompareKeyIgnoreCase -- the shared comparator *)

type

  PStringItem = ^TStringItem;

  TStringItem = record
    FMult: Str10;
    FArray: TDupesArray;
    FAltName: Str30;
  end;

  PStringItemList = ^TStringItemList;
  TStringItemList = array[0..10000] of TStringItem;

  TSortedStringList = object {class}
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

constructor TSortedStringList.Init;
begin
  Grow;
end;

{
destructor TSortedStringList.Destroy;
begin
  inherited Destroy;
  if FCount <> 0 then Finalize(FList^[0], FCount);
  FCount := 0;
  SetCapacity(0);
end;
}

function TSortedStringList.AddString(const s: string; Band: BandType; Mode: ModeType; JustAdd: boolean): integer;
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

procedure TSortedStringList.Clear;
begin
  if FCount <> 0 then
     begin

     FCount := 0;
     FillChar(TotalMults, SizeOf(TotalMults), 0);
 //    FTotalMults := 0;
     SetCapacity(0);
     end;
end;

procedure TSortedStringList.Delete(Index: integer);
begin
  if (Index < 0) or (Index >= FCount) then Exit; //Error(@SListIndexError, Index);
 
  dec(FCount);
  if Index < FCount then
     begin
     System.Move(FList^[Index + 1], FList^[Index], (FCount - Index) * SizeOf(TStringItem));
     end;
end;

function TSortedStringList.StringIsDupeByIndex(IndexInList: integer; Band: BandType; Mode: ModeType): boolean;
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

function TSortedStringList.StringIsDupe(const s: string; Band: BandType; Mode: ModeType; var IndexInList: integer): boolean;
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

function TSortedStringList.FindMult(const s: string; var Index: integer): boolean;
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

function TSortedStringList.Get(Index: integer): string;
begin
  Result := FList^[Index].FMult;
end;

function TSortedStringList.GetCapacity: integer;
begin
  Result := FCapacity;
end;

procedure TSortedStringList.Grow;
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

procedure TSortedStringList.InsertMult(Index: integer; const s: Str10; Band: BandType; Mode: ModeType);
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

  FillChar(FList^[Index], SizeOf(FList^[Index]), 0);
  FList^[Index].FMult := s;
  inc(FCount);
end;

procedure TSortedStringList.SetCapacity(NewCapacity: integer);
begin
  ReallocMem(FList, NewCapacity * SizeOf(TStringItem));
  FCapacity := NewCapacity;
end;

function TSortedStringList.CompareStrings(const s1, s2: Str10): integer;
begin
  (* CompareText, NOT CompareStringA -- and the Win32 call had a defect of its
    own that is worth recording, because it was invisible.

    WHAT IT WAS. CompareStringA with LOCALE_SYSTEM_DEFAULT and NORM_IGNORECASE,
    minus 2 to turn Windows' 1/2/3 (LESS/EQUAL/GREATER) into -1/0/1. The A
    suffix was itself a fix: the unsuffixed CompareString binds to the W
    variant, which read these ANSI ShortStrings as UTF-16 and produced garbage
    ordering -- unbounded list growth, a range error at FArray[Mode] in Winter
    FD, and silent multiplier miscounts on logs that did not crash.

    WHY IT STILL HAD TO GO, beyond not existing off Windows: LOCALE_SYSTEM_DEFAULT
    means the ordering of the multiplier list DEPENDED ON THE OPERATOR'S
    WINDOWS LOCALE. The same log, opened on two machines, could order its
    mults differently. Nothing about a contest multiplier is linguistic.

    CompareText is ordinal, case-insensitive, identical on every machine, and
    it is what the third copy of this routine (TDXSpotsList.CompareStrings,
    uSpots.pas) has always done by hand.

    SAFE FOR THIS ALPHABET. Mults are A-Z, 0-9 and '/'. Ordinal puts '/' (47)
    before the digits (48-57) before the letters (65-90); the Windows word sort
    orders that set the same way, and does not treat '/' as ignorable. The
    binary search and the insertion use this one comparator, so consistency --
    not any particular collation -- is what correctness rests on here.
    REPOINTED 2026-09-08 to uStringCompare.CompareKeyIgnoreCase. That is a
    NO-OP here -- it is CompareText with the result normalised to a sign --
    and it is done so the shared unit has a live caller rather than sitting
    as untested scaffolding. The reasoning above is why the shared one is
    ordinal too. *)
  Result := CompareKeyIgnoreCase(s1, s2);
end;

procedure TSortedStringList.ClearDupes;
var
  Index                                 : integer;
begin
  for Index := 0 to FCount - 1 do
     begin
     FillChar(FList^[Index].FArray, SizeOf(TDupesArray), 0);
     end;
end;

end.

