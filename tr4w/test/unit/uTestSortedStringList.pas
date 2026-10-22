(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

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

(* THE MULTIPLIER STORE, PINNED BEFORE IT IS CONVERTED -- pointer audit P8
  (docs/POINTER_AUDIT.md 2.3, 6.7, 6.8), 2026-10-17.

  uSortedStringList's TSortedStringList is the sorted list behind the prefix
  and domestic multipliers (uMults.mo.PrfList / mo.DomList): a key, a dupe
  bit set per mode and band, and the domestic file's display name. It was an
  old-style `object` with a VMT over a ReallocMem'd array of records. These
  pins were WRITTEN AND RUN AGAINST THAT CODE FIRST, and pass unchanged
  against the class that replaced it; only the four helpers below (how a
  list is made, freed, and how one item's alternate name and dupe bits are
  reached) differ between the two shapes.

  WHAT IS PINNED, beyond uTestMults' zone path:
    - the order is ordinal and case-INSENSITIVE ('/' < digits < letters),
      whatever order the keys arrive in;
    - a key arriving twice is one entry, and keeps the case it first had;
    - a key is cut to TEN characters (Str10) on insert AND on lookup;
    - a miss reports the insertion point, which IsDmMult's grid-field
      fallback depends on;
    - the dupe bits: the band in the mode, in Both, and the AllBands key in
      each; FM shares Phone's slot; JustAdd marks nothing;
    - ClearDupes keeps the entries and their names; Clear and Delete;
    - growth past the old array type's declared bound of 10,001 items, with
      a name travelling with its key when later inserts shift it;
    - MultsObject's prefix and domestic paths and its ClearAllMults. *)
unit uTestSortedStringList;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TSortedStringListTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EmptyListFindsNothing;
      procedure Test_OrderIsOrdinalWhateverTheArrivalOrder;
      procedure Test_ADuplicateIsOneEntryAndKeepsItsFirstCase;
      procedure Test_AKeyIsCutToTenCharacters;
      procedure Test_AMissReportsTheInsertionPoint;
      procedure Test_DupeBitsPerModeAndBand;
      procedure Test_JustAddMarksNothing;
      procedure Test_ClearDupesKeepsEntriesAndNames;
      procedure Test_DeleteAndClear;
      procedure Test_GrowsPastTheOldBoundAndNamesTravel;
      procedure Test_MultsPrefixPath;
      procedure Test_MultsDomesticPath;
      procedure Test_MultsGridFieldFallback;
      procedure Test_MultsClearAllKeepsTheKeys;
      procedure Test_MultsClearAllClearsTheWholeDXTable;
   end;

implementation

uses
   SysUtils,
   VC,
   uSortedStringList,
   uCTYDAT,   (* MaxCountries *)
   uMults;

(* THE ONLY SHAPE-DEPENDENT CODE IN THIS UNIT. Everything below calls these. *)
procedure NewList(var aList: TSortedStringList);
begin
   aList := TSortedStringList.Create;
end;

procedure FreeList(var aList: TSortedStringList);
begin
   FreeAndNil(aList);
end;

function AltNameOf(var aList: TSortedStringList; aIndex: integer): string;
begin
   Result := string(aList.AltName[aIndex]);
end;

procedure SetAltNameOf(var aList: TSortedStringList; aIndex: integer; const aName: string);
begin
   aList.AltName[aIndex] := ShortString(aName);
end;

function DupesOf(var aList: TSortedStringList; aIndex: integer): TDupesArray;
begin
   Result := aList.Dupes[aIndex];
end;

procedure NewMults(var aMults: TMultsObject);
begin
   aMults := TMultsObject.Create;
end;

procedure FreeMults(var aMults: TMultsObject);
begin
   FreeAndNil(aMults);
end;

(* ------------------------------------------------------------------------- *)

var
   list: TSortedStringList;
   mults: TMultsObject;

function AllZero(const aDupes: TDupesArray): boolean;
var
   m: ModeType;
begin
   Result := True;
   for m := Low(TDupesArray) to High(TDupesArray) do
      begin
      if aDupes[m] <> 0 then
         begin
         Result := False;
         end;
      end;
end;

procedure TSortedStringListTests.Test_EmptyListFindsNothing;
var
   index: integer;
begin
   BeginTest('Test_EmptyListFindsNothing');
   NewList(list);
   try
      CheckEquals(0, list.Count, 'a new list is empty');
      index := 99;
      CheckFalse(list.FindMult('W', index), 'nothing is found in an empty list');
      CheckEquals(0, index, 'and the insertion point is 0');
      index := 99;
      CheckFalse(list.StringIsDupe('W', Band20, CW, index), 'no dupe in an empty list');
      CheckEquals(-1, index, 'StringIsDupe reports -1 for a miss');
   finally
      FreeList(list);
      end;
end;

procedure TSortedStringListTests.Test_OrderIsOrdinalWhateverTheArrivalOrder;
begin
   BeginTest('Test_OrderIsOrdinalWhateverTheArrivalOrder');
   NewList(list);
   try
      list.AddString('W', Band20, CW, True);
      list.AddString('a', Band20, CW, True);
      list.AddString('K', Band20, CW, True);
      list.AddString('9', Band20, CW, True);
      list.AddString('/X', Band20, CW, True);
      list.AddString('B', Band20, CW, True);
      list.AddString('0', Band20, CW, True);
      CheckEquals(7, list.Count, 'seven distinct keys');
      CheckEquals('/X', list.Get(0), 'the slash sorts before the digits');
      CheckEquals('0', list.Get(1), 'then 0');
      CheckEquals('9', list.Get(2), 'then 9');
      CheckEquals('a', list.Get(3), 'then the letters, case-blind: a');
      CheckEquals('B', list.Get(4), 'B');
      CheckEquals('K', list.Get(5), 'K');
      CheckEquals('W', list.Get(6), 'W');
   finally
      FreeList(list);
      end;
end;

procedure TSortedStringListTests.Test_ADuplicateIsOneEntryAndKeepsItsFirstCase;
var
   first, second, index: integer;
begin
   BeginTest('Test_ADuplicateIsOneEntryAndKeepsItsFirstCase');
   NewList(list);
   try
      first := list.AddString('ada', Band20, CW, True);
      second := list.AddString('ADA', Band40, CW, True);
      CheckEquals(1, list.Count, 'ada and ADA are one entry');
      CheckEquals(first, second, 'and AddString returns the same index');
      CheckEquals('ada', list.Get(0), 'the entry keeps the case it first had');
      CheckTrue(list.FindMult('AdA', index), 'any case finds it');
      CheckEquals(0, index, 'at its index');
   finally
      FreeList(list);
      end;
end;

procedure TSortedStringListTests.Test_AKeyIsCutToTenCharacters;
var
   index: integer;
begin
   BeginTest('Test_AKeyIsCutToTenCharacters');
   NewList(list);
   try
      list.AddString('ABCDEFGHIJKL', Band20, CW, True);
      CheckEquals('ABCDEFGHIJ', list.Get(0), 'stored as its first ten characters');
      CheckTrue(list.FindMult('ABCDEFGHIJXYZ', index),
                'a lookup is cut to ten characters too');
      list.AddString('ABCDEFGHIJ', Band20, CW, True);
      CheckEquals(1, list.Count, 'so the ten-character key is the same entry');
   finally
      FreeList(list);
      end;
end;

procedure TSortedStringListTests.Test_AMissReportsTheInsertionPoint;
var
   index: integer;
begin
   BeginTest('Test_AMissReportsTheInsertionPoint');
   NewList(list);
   try
      list.AddString('A', Band20, CW, True);
      list.AddString('C', Band20, CW, True);
      list.AddString('E', Band20, CW, True);
      CheckFalse(list.FindMult('0', index), '0 is not there');
      CheckEquals(0, index, 'it would go first');
      CheckFalse(list.FindMult('B', index), 'B is not there');
      CheckEquals(1, index, 'it would go between A and C');
      CheckFalse(list.FindMult('D', index), 'D is not there');
      CheckEquals(2, index, 'it would go between C and E');
      CheckFalse(list.FindMult('Z', index), 'Z is not there');
      CheckEquals(3, index, 'it would go last');
      CheckTrue(list.FindMult('E', index), 'E is there');
      CheckEquals(2, index, 'at 2');
   finally
      FreeList(list);
      end;
end;

procedure TSortedStringListTests.Test_DupeBitsPerModeAndBand;
var
   index: integer;
   dupes: TDupesArray;
begin
   BeginTest('Test_DupeBitsPerModeAndBand');
   NewList(list);
   try
      list.AddString('ID', Band20, CW, False);
      CheckTrue(list.StringIsDupe('ID', Band20, CW, index), 'worked on 20 m CW');
      CheckEquals(0, index, 'at index 0');
      CheckFalse(list.StringIsDupe('ID', Band40, CW, index), 'not on 40 m CW');
      CheckFalse(list.StringIsDupe('ID', Band20, Phone, index), 'not on 20 m Phone');
      CheckTrue(list.StringIsDupe('ID', Band20, Both, index), 'Both carries 20 m');
      CheckTrue(list.StringIsDupe('ID', AllBands, CW, index), 'AllBands is marked in CW');
      CheckTrue(list.StringIsDupe('ID', AllBands, Both, index), 'and in Both');
      CheckFalse(list.StringIsDupe('ID', AllBands, Phone, index), 'and not in Phone');
      CheckTrue(list.StringIsDupeByIndex(0, Band20, CW), 'by index: 20 m CW');
      CheckFalse(list.StringIsDupeByIndex(0, Band40, CW), 'by index: not 40 m CW');

      dupes := DupesOf(list, 0);
      CheckEquals(Integer((Cardinal(1) shl Ord(Band20)) or (Cardinal(1) shl Ord(AllBands))),
                  Integer(dupes[CW]), 'the CW bits are exactly 20 m and AllBands');
      CheckEquals(Integer(dupes[CW]), Integer(dupes[Both]), 'Both has the same bits');
      CheckEquals(0, Integer(dupes[Phone]), 'Phone has none');
      CheckEquals(0, Integer(dupes[Digital]), 'Digital has none');

      (* FM SHARES PHONE'S SLOT -- TDupesArray stops at NoMode. *)
      list.AddString('MT', Band15, FM, False);
      CheckTrue(list.StringIsDupe('MT', Band15, Phone, index), 'an FM QSO marks Phone');
      CheckTrue(list.StringIsDupe('MT', Band15, FM, index), 'and FM reads Phone');
      CheckTrue(list.StringIsDupeByIndex(index, Band15, FM), 'by index too');
      CheckFalse(list.StringIsDupe('MT', Band15, CW, index), 'not CW');
   finally
      FreeList(list);
      end;
end;

procedure TSortedStringListTests.Test_JustAddMarksNothing;
var
   index: integer;
begin
   BeginTest('Test_JustAddMarksNothing');
   NewList(list);
   try
      list.AddString('ID', Band20, CW, True);
      CheckFalse(list.StringIsDupe('ID', Band20, CW, index), 'JustAdd marks no bit');
      CheckEquals(0, index, 'but the entry is there');
      CheckTrue(AllZero(DupesOf(list, 0)), 'every slot is zero');
      list.AddString('ID', Band20, CW, False);
      CheckTrue(list.StringIsDupe('ID', Band20, CW, index), 'a real add then marks');
   finally
      FreeList(list);
      end;
end;

procedure TSortedStringListTests.Test_ClearDupesKeepsEntriesAndNames;
var
   index: integer;
begin
   BeginTest('Test_ClearDupesKeepsEntriesAndNames');
   NewList(list);
   try
      list.AddString('ADA', Band20, CW, False);
      list.AddString('BOI', Band40, Phone, False);
      SetAltNameOf(list, 0, 'Ada County');
      list.ClearDupes;
      CheckEquals(2, list.Count, 'ClearDupes keeps the entries');
      CheckEquals('Ada County', AltNameOf(list, 0), 'and their names');
      CheckFalse(list.StringIsDupe('ADA', Band20, CW, index), 'but no bit is left');
      CheckTrue(AllZero(DupesOf(list, 1)), 'on any entry');
   finally
      FreeList(list);
      end;
end;

procedure TSortedStringListTests.Test_DeleteAndClear;
var
   index: integer;
begin
   BeginTest('Test_DeleteAndClear');
   NewList(list);
   try
      list.AddString('A', Band20, CW, False);
      list.AddString('B', Band20, CW, False);
      list.AddString('C', Band20, CW, False);
      SetAltNameOf(list, 2, 'Charlie');
      list.Delete(1);
      CheckEquals(2, list.Count, 'Delete removes one');
      CheckEquals('A', list.Get(0), 'A stays first');
      CheckEquals('C', list.Get(1), 'C moves down');
      CheckEquals('Charlie', AltNameOf(list, 1), 'with its name');
      CheckTrue(list.StringIsDupe('C', Band20, CW, index), 'and its bits');
      list.Delete(-1);
      list.Delete(2);
      CheckEquals(2, list.Count, 'an index out of range deletes nothing');

      list.Clear;
      CheckEquals(0, list.Count, 'Clear empties it');
      CheckFalse(list.FindMult('A', index), 'A is gone');
      list.AddString('Z', Band20, CW, False);
      CheckEquals(1, list.Count, 'and it takes new keys afterwards');
      CheckTrue(list.StringIsDupe('Z', Band20, CW, index), 'with their bits');
      CheckEquals('', AltNameOf(list, 0), 'and no name left over');
   finally
      FreeList(list);
      end;
end;

procedure TSortedStringListTests.Test_GrowsPastTheOldBoundAndNamesTravel;
const
   N = 12000;
var
   i, index: integer;
   inOrder: boolean;
begin
   BeginTest('Test_GrowsPastTheOldBoundAndNamesTravel');
   NewList(list);
   try
      (* Ascending, so each insert is an append: past 10,001 items cheaply. *)
      for i := 0 to N - 1 do
         begin
         list.AddString('M' + Format('%.5d', [i * 2]), Band20, CW, False);
         end;
      CheckEquals(N, list.Count, '12,000 keys, past the old type''s 10,001');
      CheckTrue(list.FindMult('M00000', index), 'the first is found');
      SetAltNameOf(list, index, 'first');
      CheckTrue(list.FindMult('M23998', index), 'the last is found');
      CheckEquals(N - 1, index, 'at the end');
      SetAltNameOf(list, index, 'last');

      (* Odd keys between them: every one shifts the entries above it. *)
      for i := 0 to 49 do
         begin
         list.AddString('M' + Format('%.5d', [i * 400 + 1]), Band40, Phone, False);
         end;
      CheckEquals(N + 50, list.Count, 'fifty more');

      inOrder := True;
      for i := 1 to list.Count - 1 do
         begin
         if CompareText(AnsiString(list.Get(i - 1)), AnsiString(list.Get(i))) >= 0 then
            begin
            inOrder := False;
            end;
         end;
      CheckTrue(inOrder, 'still strictly in order');
      CheckTrue(list.FindMult('M23998', index), 'the last is still found');
      CheckEquals(N + 49, index, 'shifted up by every insert below it');
      CheckEquals('last', AltNameOf(list, index), 'and its name went with it');
      CheckTrue(list.StringIsDupe('M23998', Band20, CW, index), 'its bits too');
      CheckTrue(list.FindMult('M00000', index), 'the first is still first');
      CheckEquals('first', AltNameOf(list, index), 'named');
      CheckTrue(list.FindMult('M00401', index), 'an inserted key is found');
      CheckTrue(list.StringIsDupe('M00401', Band40, Phone, index), 'with its own bits');
      CheckFalse(list.StringIsDupe('M00401', Band20, CW, index), 'and not another''s');
   finally
      FreeList(list);
      end;
end;

procedure TSortedStringListTests.Test_MultsPrefixPath;
begin
   BeginTest('Test_MultsPrefixPath');
   NewMults(mults);
   try
      CheckTrue(mults.IsPxMult('W1', Band20, CW), 'an unseen prefix is a new multiplier');
      mults.SetPxMult('W1', Band20, CW);
      CheckFalse(mults.IsPxMult('W1', Band20, CW), 'worked on 20 m CW');
      CheckTrue(mults.IsPxMult('W1', Band40, CW), 'still needed on 40 m');
      CheckTrue(mults.IsPxMult('W1', Band20, Phone), 'and on Phone');
      CheckEquals(1, mults.PrfList.Count, 'one prefix in the list');
      CheckEquals(1, Integer(mults.MTotals[Band20, CW, rmPrefix]), 'counted on 20 m CW');
      CheckEquals(1, Integer(mults.MTotals[AllBands, Both, rmPrefix]), 'and rolled up');

      (* SetPxMult COUNTS EVERY CALL -- the caller asks IsPxMult first. *)
      mults.SetPxMult('W1', Band20, CW);
      CheckEquals(2, Integer(mults.MTotals[Band20, CW, rmPrefix]), 'a second Set counts again');
      CheckEquals(1, mults.PrfList.Count, 'but adds no entry');

      (* FM counts as Phone. *)
      mults.SetPxMult('K2', Band15, FM);
      CheckEquals(1, Integer(mults.MTotals[Band15, Phone, rmPrefix]), 'FM counts in Phone');
      CheckFalse(mults.IsPxMult('K2', Band15, Phone), 'and is worked in Phone');
   finally
      FreeMults(mults);
      end;
end;

procedure TSortedStringListTests.Test_MultsDomesticPath;
begin
   BeginTest('Test_MultsDomesticPath');
   NewMults(mults);
   try
      CheckTrue(mults.IsDmMult('ADA', Band20, CW, False), 'an unseen county is new');
      mults.SetDmMult('ADA', Band20, CW);
      CheckFalse(mults.IsDmMult('ADA', Band20, CW, False), 'worked on 20 m CW');
      CheckFalse(mults.IsDmMult('ada', Band20, CW, False), 'case-blind');
      CheckTrue(mults.IsDmMult('ADA', Band80, CW, False), 'needed on 80 m');
      CheckTrue(mults.IsDmMult('BOI', Band20, CW, False), 'another county is new');
      CheckEquals(1, Integer(mults.MTotals[Band20, CW, rmDomestic]), 'counted');
      CheckEquals(1, mults.DomList.Count, 'one entry');
   finally
      FreeMults(mults);
      end;
end;

procedure TSortedStringListTests.Test_MultsGridFieldFallback;
begin
   BeginTest('Test_MultsGridFieldFallback');
   NewMults(mults);
   try
      (* An OLD log stored the whole grid; a grid-field contest asks by field. *)
      mults.DomList.AddString('FN20', NoBand, NoMode, True);
      CheckTrue(mults.IsDmMult('FN31', Band20, CW, True),
                'a stored FN20 with no bit: FN is still needed');
      mults.SetDmMult('FN20', Band20, CW);
      CheckFalse(mults.IsDmMult('FN31', Band20, CW, True),
                 'once FN20 is worked, any FN grid is the same field');
      CheckTrue(mults.IsDmMult('FN31', Band40, CW, True), 'not on another band');
      CheckTrue(mults.IsDmMult('EM10', Band20, CW, True), 'and EM is another field');

      (* A NEW log stores the field itself. *)
      mults.SetDmMult('EM', Band20, CW);
      CheckFalse(mults.IsDmMult('EM73', Band20, CW, True), 'the exact field matches');
      CheckTrue(mults.IsDmMult('EM73', Band20, CW, False),
                'not keyed on the field, EM73 is its own key');
   finally
      FreeMults(mults);
      end;
end;

procedure TSortedStringListTests.Test_MultsClearAllKeepsTheKeys;
begin
   BeginTest('Test_MultsClearAllKeepsTheKeys');
   NewMults(mults);
   try
      mults.SetPxMult('W1', Band20, CW);
      mults.SetDmMult('ADA', Band20, CW);
      mults.SetZnMult(5, Band20, CW);
      mults.ClearAllMults;
      CheckEquals(1, mults.PrfList.Count, 'the prefix entry stays');
      CheckEquals(1, mults.DomList.Count, 'the domestic entry stays');
      CheckTrue(mults.IsPxMult('W1', Band20, CW), 'but the prefix is needed again');
      CheckTrue(mults.IsDmMult('ADA', Band20, CW, False), 'and the county');
      CheckTrue(mults.IsZnMult(5, Band20, CW), 'and the zone');
      CheckEquals(0, Integer(mults.MTotals[AllBands, Both, rmPrefix]), 'no prefix counted');
      CheckEquals(0, Integer(mults.MTotals[AllBands, Both, rmDomestic]), 'no county');
      CheckEquals(0, Integer(mults.MTotals[AllBands, Both, rmZone]), 'no zone');
      CheckFalse(mults.IsDXMult(MaxCountries, Band20, CW),
                 'a country past the table is never a multiplier');
   finally
      FreeMults(mults);
      end;
end;

(* THE WHOLE DX TABLE IS CLEARED. ClearAllMults cleared it with
   FillChar(DXMultsArray, SizeOf(DXMultsArray), 0) inside a method of an
   object whose unit ALSO declared a record TYPE named DXMultsArray (28
   bytes, used nowhere). The field won, but a SizeOf that bound to the type
   would clear one country and leave the rest -- so the LAST country is the
   one asked about. SetDXMult refuses a country number until a country file
   is loaded, so the shipped one is, as uTestOffBandCredit loads it. *)
procedure TSortedStringListTests.Test_MultsClearAllClearsTheWholeDXTable;
var
   ctyPath: string;
   last: Word;
begin
   BeginTest('Test_MultsClearAllClearsTheWholeDXTable');
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat loads');
   CheckTrue(CTY.ctyNumberCountries > 300, 'with its few hundred countries');
   last := CTY.ctyNumberCountries - 1;
   NewMults(mults);
   try
      CheckTrue(mults.IsDXMult(last, Band20, CW), 'the last country is needed');
      mults.SetDXMult(last, Band20, CW);
      mults.SetDXMult(0, Band20, CW);
      CheckFalse(mults.IsDXMult(last, Band20, CW), 'worked');
      CheckFalse(mults.IsDXMult(0, Band20, CW), 'and the first');
      CheckEquals(2, Integer(mults.MTotals[AllBands, Both, rmDX]), 'two DX counted');
      mults.SetDXMult(CTY.ctyNumberCountries, Band20, CW);
      CheckEquals(2, Integer(mults.MTotals[AllBands, Both, rmDX]),
                  'a country past the loaded table is refused');
      mults.ClearAllMults;
      CheckTrue(mults.IsDXMult(last, Band20, CW), 'cleared: the last is needed again');
      CheckTrue(mults.IsDXMult(0, Band20, CW), 'and the first');
   finally
      FreeMults(mults);
      end;
end;

procedure TSortedStringListTests.RunAllTests;
begin
   Test_EmptyListFindsNothing;
   Test_OrderIsOrdinalWhateverTheArrivalOrder;
   Test_ADuplicateIsOneEntryAndKeepsItsFirstCase;
   Test_AKeyIsCutToTenCharacters;
   Test_AMissReportsTheInsertionPoint;
   Test_DupeBitsPerModeAndBand;
   Test_JustAddMarksNothing;
   Test_ClearDupesKeepsEntriesAndNames;
   Test_DeleteAndClear;
   Test_GrowsPastTheOldBoundAndNamesTravel;
   Test_MultsPrefixPath;
   Test_MultsDomesticPath;
   Test_MultsGridFieldFallback;
   Test_MultsClearAllKeepsTheKeys;
   Test_MultsClearAllClearsTheWholeDXTable;
end;

end.
