(*
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
 *)

(* THE DOMESTIC COUNTRY LIST (ZONECONT.TDomesticCountryList) -- 2026-10-16,
  pointer audit P5.

  The list was a hand-built linked list (New per add, a walk to the tail,
  Dispose per entry on clear). It owns a TList now, and these pin the rules
  the old code had, which the class's declaration lists: order kept,
  duplicates kept, ASCII upper-casing on add, an exact case-sensitive
  compare, storage truncated to six characters, an empty ID stored and
  matching an empty country, and Clear emptying the list AND re-arming the
  once-only empty report.

  A PRIVATE LIST, never the live ZoneCont.DomesticCountries -- except the
  last test, which checks the free routines reach the live one and puts the
  live list back exactly as it found it. *)
unit uTestDomesticCountryList;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TDomesticCountryListTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_OrderAndDuplicatesAreKept;
      procedure Test_CaseAndWidth;
      procedure Test_AnEmptyIDIsStoredAndMatchesAnEmptyCountry;
      procedure Test_ClearEmptiesAndReArmsTheEmptyReport;
      procedure Test_TheFreeRoutinesUseTheLiveList;
      procedure Test_AContestThatStatesNoneIsNotReportedEmpty;
      procedure Test_AContestThatStatesCountriesIsReportedEmpty;
      procedure Test_WhichContestsStateDomesticCountries;
   end;

implementation

uses
   SysUtils,
   VC,
   ZoneCont,
   uContestBase,
   FCONTEST,
   uTestContestObjects;

function ListText(aList: TDomesticCountryList): string;
var
   i: integer;
begin
   Result := '';
   for i := 0 to aList.Count - 1 do
      begin
      Result := Result + '[' + aList.IDs[i] + ']';
      end;
end;

procedure TDomesticCountryListTests.Test_OrderAndDuplicatesAreKept;
var
   list: TDomesticCountryList;
begin
   BeginTest('Test_OrderAndDuplicatesAreKept');

   list := TDomesticCountryList.Create;
   try
      CheckEquals(0, list.Count, 'a new list is empty');
      list.Add('K');
      list.Add('VE');
      list.Add('GM');
      list.Add('GM');
      list.Add('KH6');
      CheckEquals(5, list.Count, 'a duplicate is appended, not refused');
      CheckEquals('[K][VE][GM][GM][KH6]', ListText(list), 'in the order added');
      CheckTrue(list.HoldsCountry('KH6'), 'the last entry is found');
      CheckTrue(list.HoldsCountry('K'), 'and the first');
      CheckFalse(list.HoldsCountry('KL'), 'an ID never added is not');
   finally
      list.Free;
   end;
end;

procedure TDomesticCountryListTests.Test_CaseAndWidth;
var
   list: TDomesticCountryList;
begin
   BeginTest('Test_CaseAndWidth');

   list := TDomesticCountryList.Create;
   try
      (* UPPER-CASED ON ADD, ASCII ONLY. *)
      list.Add('kl');
      CheckEquals('[KL]', ListText(list), 'an added ID is upper-cased');
      CheckTrue(list.HoldsCountry('KL'), 'and found upper-case');
      CheckFalse(list.HoldsCountry('kl'), 'the compare is case-sensitive');

      (* A CTY ID with a lowercase letter is never matched by an added one:
         the add upper-cased it. *)
      list.Add('3D2/c');
      CheckEquals('[KL][3D2/C]', ListText(list), 'every a..z is upper-cased');
      CheckFalse(list.HoldsCountry('3D2/c'), 'so the lowercase CTY form is not domestic');

      (* EXACT, not a prefix. *)
      CheckFalse(list.HoldsCountry('K'), 'a shorter ID is not a match');
      CheckFalse(list.HoldsCountry('KL7'), 'nor a longer one');

      (* STORED AS ITS FIRST SIX, as string[6] stored it. *)
      list.Add('ABCDEFGH');
      CheckEquals('[KL][3D2/C][ABCDEF]', ListText(list), 'a long ID is stored as six');
      CheckTrue(list.HoldsCountry('ABCDEF'), 'and found as six');
      CheckFalse(list.HoldsCountry('ABCDEFGH'), 'not as itself');
   finally
      list.Free;
   end;
end;

procedure TDomesticCountryListTests.Test_AnEmptyIDIsStoredAndMatchesAnEmptyCountry;
var
   list: TDomesticCountryList;
begin
   BeginTest('Test_AnEmptyIDIsStoredAndMatchesAnEmptyCountry');

   list := TDomesticCountryList.Create;
   try
      CheckFalse(list.HoldsCountry(''), 'an empty list holds no empty country');
      list.Add('');
      CheckEquals(1, list.Count, 'an empty ID is stored');
      CheckTrue(list.HoldsCountry(''), 'and matches an unknown (empty) country');
   finally
      list.Free;
   end;
end;

procedure TDomesticCountryListTests.Test_ClearEmptiesAndReArmsTheEmptyReport;
var
   list: TDomesticCountryList;
begin
   BeginTest('Test_ClearEmptiesAndReArmsTheEmptyReport');

   list := TDomesticCountryList.Create;
   try
      (* ONCE per Create or Clear. *)
      CheckTrue(list.ClaimEmptyReport, 'the first claim reports');
      CheckFalse(list.ClaimEmptyReport, 'the second does not');

      (* Adding does not re-arm it: only Clear does. *)
      list.Add('DL');
      CheckFalse(list.ClaimEmptyReport, 'an add does not re-arm the report');

      list.Clear;
      CheckEquals(0, list.Count, 'Clear empties the list');
      CheckFalse(list.HoldsCountry('DL'), 'and nothing of it is found');
      CheckTrue(list.ClaimEmptyReport, 'and re-arms the report');

      (* A RELOAD after Clear is the second contest's list, alone. *)
      list.Add('OK');
      list.Add('OM');
      CheckEquals('[OK][OM]', ListText(list), 'a reload after Clear holds only the new IDs');

      (* WITHOUT a Clear, a second set ACCUMULATES -- FoundContest appends. *)
      list.Add('OK');
      CheckEquals('[OK][OM][OK]', ListText(list), 'a second add without Clear appends');
   finally
      list.Free;
   end;
end;

procedure TDomesticCountryListTests.Test_TheFreeRoutinesUseTheLiveList;
var
   saved: array of string;
   i: integer;
   countBefore: integer;
begin
   BeginTest('Test_TheFreeRoutinesUseTheLiveList');

   CheckTrue(DomesticCountries <> nil, 'the live list exists once the unit is initialised');

   countBefore := DomesticCountries.Count;
   SetLength(saved, countBefore);
   for i := 0 to countBefore - 1 do
      begin
      saved[i] := DomesticCountries.IDs[i];
      end;
   try
      AddDomesticCountry('zzq');
      CheckEquals(countBefore + 1, DomesticCountries.Count, 'AddDomesticCountry adds to the live list');
      CheckEquals('ZZQ', DomesticCountries.IDs[countBefore], 'at its end, upper-cased');

      ClearDomesticCountryList;
      CheckEquals(0, DomesticCountries.Count, 'ClearDomesticCountryList empties it');
   finally
      (* PUT IT BACK. Clear first, so the restore does not depend on what
         the body reached; the empty report's latch is left armed, which is
         what Clear leaves for the next contest anyway. *)
      DomesticCountries.Clear;
      for i := 0 to High(saved) do
         begin
         DomesticCountries.Add(CallString(saved[i]));
         end;
   end;
end;

(* A DX CONTEST'S EMPTY LIST IS ITS ANSWER, NOT A MISSING INPUT -- 2026-10-23.
   NY4I's CQ WW SSB log logged "the domestic country list is EMPTY ... the
   contest was not set up" on File > Clear log, of a contest that was set up
   and has no domestic country. FoundContest records the set-up's statement
   (RecordContestSetUp); the report is withheld while it said none. *)
procedure TDomesticCountryListTests.Test_AContestThatStatesNoneIsNotReportedEmpty;
var
   list: TDomesticCountryList;
begin
   BeginTest('Test_AContestThatStatesNoneIsNotReportedEmpty');

   list := TDomesticCountryList.Create;
   try
      list.RecordContestSetUp(False);
      CheckEquals(0, list.Count, 'the contest added nothing');
      CheckFalse(list.ClaimEmptyReport, 'a contest that states none is not reported empty');
      CheckFalse(list.ClaimEmptyReport, 'nor on a later ask');

      (* CLEAR FORGETS THE STATEMENT: a .cfg that never reaches its CONTEST
         line is the case the report exists for, and the previous contest
         must not excuse it. *)
      list.Clear;
      CheckTrue(list.ClaimEmptyReport, 'after Clear an empty list is reported again');
   finally
      list.Free;
   end;
end;

(* THE CASE THE REPORT WAS BUILT FOR STILL REPORTS: never set up, or set up by
   a contest that states countries and left empty (an operator's
   ADD DOMESTIC COUNTRY = CLEAR, after which the statement is forgotten, is
   the one route; here the statement is kept to pin the rule itself). *)
procedure TDomesticCountryListTests.Test_AContestThatStatesCountriesIsReportedEmpty;
var
   list: TDomesticCountryList;
begin
   BeginTest('Test_AContestThatStatesCountriesIsReportedEmpty');

   list := TDomesticCountryList.Create;
   try
      CheckTrue(list.ClaimEmptyReport, 'never set up: an empty list is reported');
   finally
      list.Free;
   end;

   list := TDomesticCountryList.Create;
   try
      list.RecordContestSetUp(True);
      CheckTrue(list.ClaimEmptyReport, 'a contest that states countries, empty: reported');
      CheckFalse(list.ClaimEmptyReport, 'once');
   finally
      list.Free;
   end;

   (* THE LATEST SET-UP'S ANSWER STANDS: a DX contest followed by a domestic
      one (a peer's CONTEST line) reports again. *)
   list := TDomesticCountryList.Create;
   try
      list.RecordContestSetUp(False);
      CheckFalse(list.ClaimEmptyReport, 'the DX contest first: not reported');
      list.RecordContestSetUp(True);
      CheckTrue(list.ClaimEmptyReport, 'then a domestic contest, still empty: reported');
   finally
      list.Free;
   end;
end;

function StatesCountries(aContest: ContestType; const aStation: TStationContext): boolean;
var
   obj: TContestBase;
   session: TSessionDefaults;
begin
   obj := Make(aContest, aStation);
   session := TSessionDefaults.Create;
   try
      obj.DescribeSession(aStation, session);
      Result := ContestSetUpStatesDomesticCountries(obj, session);
   finally
      session.Free;
      obj.Free;
      end;
end;

(* WHICH CONTESTS STATE DOMESTIC COUNTRIES -- the statement FoundContest
   records. CQ WW none at any station (D7's CQWW arms added none; CQ WW
   RTTY's Add_KVE was commented out there too); ARRL 10 states
   K/VE/KH6/KL and XE; a US QSO party's head adds K/VE/KH6/KL. *)
procedure TDomesticCountryListTests.Test_WhichContestsStateDomesticCountries;
var
   usStation, dxStation: TStationContext;
begin
   BeginTest('Test_WhichContestsStateDomesticCountries');

   usStation := NoStation;
   usStation.MyCall := 'NY4I';
   usStation.MyCountry := 'K';
   usStation.MyContinent := NorthAmerica;
   usStation.MyState := 'FL';

   dxStation := NoStation;
   dxStation.MyCall := 'DL1AAA';
   dxStation.MyCountry := 'DL';
   dxStation.MyContinent := Europe;

   CheckFalse(StatesCountries(CQWWSSB, usStation), 'CQ WW SSB, US station: none');
   CheckFalse(StatesCountries(CQWWSSB, dxStation), 'CQ WW SSB, DL station: none');
   CheckFalse(StatesCountries(CQWWCW, usStation), 'CQ WW CW, US station: none');
   CheckFalse(StatesCountries(CQWWCW, dxStation), 'CQ WW CW, DL station: none');

   CheckTrue(StatesCountries(ARRL10, usStation), 'ARRL 10, US station: K/VE/KH6/KL and XE');
   CheckTrue(StatesCountries(ARRL10, dxStation), 'ARRL 10, DL station: the same');
   CheckTrue(StatesCountries(IDAHOQSOPARTY, usStation), 'Idaho QP: the party head adds K/VE/KH6/KL');
end;

procedure TDomesticCountryListTests.RunAllTests;
begin
   Test_OrderAndDuplicatesAreKept;
   Test_CaseAndWidth;
   Test_AnEmptyIDIsStoredAndMatchesAnEmptyCountry;
   Test_ClearEmptiesAndReArmsTheEmptyReport;
   Test_TheFreeRoutinesUseTheLiveList;
   Test_AContestThatStatesNoneIsNotReportedEmpty;
   Test_AContestThatStatesCountriesIsReportedEmpty;
   Test_WhichContestsStateDomesticCountries;
end;

end.
