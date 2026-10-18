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

  This is a SORTED STRING LIST -- a sorted list of (multiplier, per-band/mode
  dupe flags, alternate name), with a binary search over it. It is the
  multiplier and dupe store, and it has nothing whatever to do with TLS.

  "uSSL" reads as OpenSSL, and it misled NY4I in the very session that renamed
  it: he read a report that this unit still named Windows and answered "uSSL
  should strictly use Indy". A reasonable inference from the name, and wrong --
  the Windows reference was CompareStringA in CompareStrings, the ordering key
  for the binary search. There ARE SSL units in this tree; they are Indy's
  IdSSLOpenSSL* under include/Protocols, and their types really are TSSL_CTX_*.

  NY4I: "It is terribly misnamed. USortedStringList.pas would avoid repeating
  this mistake." *)

(* A CLASS OVER A TObjectList SINCE 2026-10-17 -- pointer audit P8
  (docs/POINTER_AUDIT.md 2.3, 6.8).

  IT WAS AN OLD-STYLE `object` WITH A VMT (two virtual methods nothing
  overrode) over a ReallocMem'd `array[0..10000] of TStringItem` reached
  through a pointer, grown and shifted by hand with System.Move, and cleared
  with FillChar. An `object` with a VMT is the shape whose instance SizeOf
  goes through the VMT pointer (CLAUDE.md's 0xC0000005 story), and its
  storage was public: four units indexed `FList^[i]` directly.

  NOW each multiplier is a TSortedStringItem and the list owns them in a
  Generics.Collections TObjectList (already linked: zonecont and logdom use
  the same unit). Consumers ask Count, Get, AltName[] and Dupes[]; nobody
  reaches the storage. Measured before and after over 3000 keys: the same
  per-operation cost to within noise (P8 in the audit). A record list would
  have been one allocation fewer per key, but FPC 3.2.2's TList<T> hands out
  COPIES of an item and has no in-place access, so every dupe-bit write would
  have been a read-modify-write of the whole record; a class item is written
  where it lives.

  SEMANTICS KEPT EXACTLY, and pinned by uTestSortedStringList against the old
  code first: ordinal case-insensitive order, a key cut to ten characters on
  insert AND lookup, a miss reporting its insertion point, the first spelling
  of a key kept, FM sharing Phone's slot, JustAdd marking nothing.

  ONE DIFFERENCE, DELIBERATE: an index out of range now raises
  (EArgumentOutOfRangeException, from the list) where the old array read
  whatever lay there. Every caller passes an index it was given by FindMult,
  StringIsDupe or a 0..Count-1 loop. *)
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  VC,
  // Issue #1034: dropped 'TF' (unused here) -- it pulled TF -> MainUnit -> LogStuff,
  // which blocked uSortedStringList (and its uMults consumer) from linking into the test EXE.
  Generics.Collections,   (* TObjectList -- the items, owned *)
  uStringCompare;         (* CompareKeyIgnoreCase -- the shared comparator *)

type

  (* ONE MULTIPLIER: its key, its dupe bits per mode (a bit per band), and
    the display name a domestic file gave it ('^' lines, LOGDOM). *)
  TSortedStringItem = class
  public
    Mult: Str10;
    Dupes: TDupesArray;
    AltName: Str30;
  end;

  TSortedStringList = class
  private
    FItems: TObjectList<TSortedStringItem>;
    function CompareStrings(const s1, s2: Str10): integer;
    procedure InsertMult(Index: integer; const s: Str10);
    function GetCount: integer;
    function GetAltName(Index: integer): Str30;
    procedure SetAltName(Index: integer; const aName: Str30);
    function GetDupes(Index: integer): TDupesArray;
  public
    constructor Create;
    destructor Destroy; override;
    function StringIsDupeByIndex(IndexInList: integer; Band: BandType; Mode: ModeType): boolean;
    function StringIsDupe(const s: string; Band: BandType; Mode: ModeType; var IndexInList: integer): boolean;
    function Get(Index: integer): string;
    function AddString(const s: string; Band: BandType; Mode: ModeType; JustAdd: boolean): integer;
    procedure Clear;
    procedure Delete(Index: integer);
    procedure ClearDupes;
    function FindMult(const s: string; var Index: integer): boolean;
    property Count: integer read GetCount;
    property AltName[Index: integer]: Str30 read GetAltName write SetAltName;
    (* A COPY of the item's bits -- read-only; AddString and ClearDupes write. *)
    property Dupes[Index: integer]: TDupesArray read GetDupes;
  end;

(* FM SHARES PHONE'S SLOT. TDupesArray is array[CW..NoMode] and FM is outside
  it, so FM must be remapped before it indexes one -- an out-of-bounds write
  in D7, a range error under checking. One routine for the three dupe stores
  (this list, uMults' tables, uCallsigns); it was written out nine times. *)
function DupeSlot(aMode: ModeType): ModeType;

implementation

function DupeSlot(aMode: ModeType): ModeType;
begin
  Result := aMode;
  if Result = FM then
     begin
     Result := Phone;
     end;
end;

constructor TSortedStringList.Create;
begin
  inherited Create;
  FItems := TObjectList<TSortedStringItem>.Create(True);
end;

destructor TSortedStringList.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TSortedStringList.GetCount: integer;
begin
  Result := FItems.Count;
end;

function TSortedStringList.GetAltName(Index: integer): Str30;
begin
  Result := FItems[Index].AltName;
end;

procedure TSortedStringList.SetAltName(Index: integer; const aName: Str30);
begin
  FItems[Index].AltName := aName;
end;

function TSortedStringList.GetDupes(Index: integer): TDupesArray;
begin
  Result := FItems[Index].Dupes;
end;

function TSortedStringList.AddString(const s: string; Band: BandType; Mode: ModeType; JustAdd: boolean): integer;
var
  item                                  : TSortedStringItem;
  slot                                  : ModeType;
begin
  if not FindMult(s, Result) then
     begin
     InsertMult(Result, ShortString(s));
     end;
  if JustAdd then
     begin
     Exit;
     end;
  slot := DupeSlot(Mode);
  item := FItems[Result];
  item.Dupes[slot] := item.Dupes[slot] or (1 shl Ord(Band));
  item.Dupes[Both] := item.Dupes[Both] or (1 shl Ord(Band));
  item.Dupes[slot] := item.Dupes[slot] or (1 shl Ord(AllBands));
  item.Dupes[Both] := item.Dupes[Both] or (1 shl Ord(AllBands));
end;

procedure TSortedStringList.Clear;
begin
  FItems.Clear;
end;

procedure TSortedStringList.Delete(Index: integer);
begin
  if (Index < 0) or (Index >= FItems.Count) then
     begin
     Exit;
     end;
  FItems.Delete(Index);
end;

function TSortedStringList.StringIsDupeByIndex(IndexInList: integer; Band: BandType; Mode: ModeType): boolean;
begin
  Result := (FItems[IndexInList].Dupes[DupeSlot(Mode)] and (1 shl Ord(Band))) <> 0;
end;

function TSortedStringList.StringIsDupe(const s: string; Band: BandType; Mode: ModeType; var IndexInList: integer): boolean;
var
  Index                                 : integer;
begin
  Result := False;
  if FindMult(s, Index) then
     begin
     Result := (FItems[Index].Dupes[DupeSlot(Mode)] and (1 shl Ord(Band))) <> 0;
     IndexInList := Index;
     end
  else
     begin
     IndexInList := -1;
     end;
end;

(* THE KEY IS CUT TO TEN CHARACTERS ONCE, here, where the old code had each
  comparison's Str10 parameter cut it -- the same conversion, made once. *)
function TSortedStringList.FindMult(const s: string; var Index: integer): boolean;
var
  l, h, i, c                            : integer;
  key                                   : Str10;
begin
  Result := False;
  key := ShortString(s);
  l := 0;
  h := FItems.Count - 1;
  while l <= h do
     begin
     i := (l + h) shr 1;
     c := CompareStrings(FItems[i].Mult, key);
     if c < 0 then
        begin
        l := i + 1;
        end
     else
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
  Result := string(FItems[Index].Mult);
end;

(* A NEW ITEM IS ZERO -- a class instance's fields are, which is what the
  FillChar over the array slot did. *)
procedure TSortedStringList.InsertMult(Index: integer; const s: Str10);
var
  item                                  : TSortedStringItem;
begin
  item := TSortedStringItem.Create;
  item.Mult := s;
  FItems.Insert(Index, item);
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
  m                                     : ModeType;
  item                                  : TSortedStringItem;
begin
  for Index := 0 to FItems.Count - 1 do
     begin
     item := FItems[Index];
     for m := Low(TDupesArray) to High(TDupesArray) do
        begin
        item.Dupes[m] := 0;
        end;
     end;
end;

end.
