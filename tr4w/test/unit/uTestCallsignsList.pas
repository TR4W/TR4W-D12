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

(* THE WORKED-CALLS LIST, PINNED BEFORE IT IS CONVERTED -- pointer audit P8
  (docs/POINTER_AUDIT.md 2.3, 6.9), 2026-10-17.

  uCallsigns' TCallsignsList is the program's CallsignsList: every station in
  the log, sorted, with its QSO count, its dupe bits and the initial exchange
  TRMASTER or the log gave it. It feeds the dupe check, the possible-calls
  strip (CreatePartialsList, once per keystroke), the member-number reverse
  lookup (FindNumber), Alt-D and the stations window. It was an old-style
  `object` with a VMT over a ReallocMem'd array of records, and no test
  covered it -- uTestOffBandCredit and uTestRoverDupeKey drive only its dupe
  question.

  THESE PINS WERE WRITTEN AND RUN AGAINST THAT CODE FIRST and pass
  unchanged against the class that replaced it; only NewList and FreeList
  differ between the two shapes.

  The possible-calls strip is read from its model, LOGSCP's PossibleCallList,
  which CreatePartialsList fills whether or not a main window exists; the
  window's grid is the screen's and BENCH's. DisplayDupeSheet needs a dupe
  sheet form and is BENCH too. *)
unit uTestCallsignsList;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TCallsignsListTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EmptyListFindsNothing;
      procedure Test_OrderIsOrdinalAndCaseBlind;
      procedure Test_ARepeatCountsQSOsUpTo255;
      procedure Test_ACallIsCutToItsWidth;
      procedure Test_DupeBitsAndTheByBandByModeKey;
      procedure Test_AnFMQSOMarksPhoneAndLeavesTheCallAlone;
      procedure Test_InitialExchangeAddAndReplace;
      procedure Test_TotalWorkedCountsOnlyStationsWithQSOs;
      procedure Test_ClearDupesKeepsStationsAndExchanges;
      procedure Test_FindNumberReverseLookup;
      procedure Test_PartialsListSubstringOrderAndLimit;
      procedure Test_CapacityRefusesTheHundredThousandAndFirst;
   end;

implementation

uses
   SysUtils,
   VC,
   uSettingsModel,
   uCallsigns,
   uContestRegistry,
   LogSCP,
   LogStuff,
   LogWind,
   PostUnit;

(* THE ONLY SHAPE-DEPENDENT CODE IN THIS UNIT. *)
procedure NewList(var aList: TCallsignsList);
begin
   aList := TCallsignsList.Create;
end;

procedure FreeList(var aList: TCallsignsList);
begin
   FreeAndNil(aList);
end;

(* ------------------------------------------------------------------------- *)

var
   list: TCallsignsList;

(* The globals a test changes, saved and put back so no other suite sees them. *)
var
   savedContest: TContestHandle;
   savedByBand: boolean;
   savedByMode: boolean;
   savedPossible: boolean;
   savedActiveBand: BandType;
   savedActiveMode: ModeType;
   savedCallWindow: CallString;

procedure SaveGlobals;
begin
   savedContest := Contest;
   savedByBand := Settings.Qso.ByBand;
   savedByMode := Settings.Qso.ByMode;
   savedPossible := Settings.PossibleCall.Enable;
   savedActiveBand := ActiveBand;
   savedActiveMode := ActiveMode;
   savedCallWindow := CallWindowString;
   (* CQ WW CW states no bands, so every band is credited. *)
   Contest := ContestHandleOf(CQWWCW);
   Settings.Qso.ByBand := True;
   Settings.Qso.ByMode := True;
end;

procedure RestoreGlobals;
begin
   CallWindowString := savedCallWindow;
   ActiveMode := savedActiveMode;
   ActiveBand := savedActiveBand;
   Settings.PossibleCall.Enable := savedPossible;
   Settings.Qso.ByMode := savedByMode;
   Settings.Qso.ByBand := savedByBand;
   Contest := savedContest;
end;

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

procedure TCallsignsListTests.Test_EmptyListFindsNothing;
var
   index: integer;
   dupes: TDupesArray;
begin
   BeginTest('Test_EmptyListFindsNothing');
   SaveGlobals;
   NewList(list);
   try
      CheckEquals(0, list.Count, 'a new list is empty');
      index := 99;
      CheckFalse(list.FindCallsign('W1AW', index), 'nothing is found');
      CheckEquals(0, index, 'the insertion point is 0');
      CheckFalse(list.CallsignIsDupe('W1AW', Band20, CW, index), 'no dupe');
      CheckEquals(-1, index, 'CallsignIsDupe reports -1 for a miss');
      CheckEquals(0, Integer(list.GetQSOs(-1)), 'GetQSOs(-1) is 0');
      CheckFalse(list.GetDupesArray(-1, dupes), 'GetDupesArray(-1) is False');
      CheckEquals('', list.GetIniitialExchange('W1AW'), 'no exchange');
      CheckEquals(0, list.GetTotalWorkedStations, 'no worked stations');
   finally
      FreeList(list);
      RestoreGlobals;
      end;
end;

procedure TCallsignsListTests.Test_OrderIsOrdinalAndCaseBlind;
var
   index: integer;
begin
   BeginTest('Test_OrderIsOrdinalAndCaseBlind');
   SaveGlobals;
   NewList(list);
   try
      list.AddCallsign('W1AW', CW, Band20, True);
      list.AddCallsign('K1AR', CW, Band20, True);
      list.AddCallsign('N6TR', CW, Band20, True);
      list.AddCallsign('9A1A', CW, Band20, True);
      list.AddCallsign('AA1A', CW, Band20, True);
      list.AddCallsign('K1AR/7', CW, Band20, True);
      CheckEquals(6, list.Count, 'six stations');
      CheckEquals('9A1A', list.Get(0), 'digits before letters');
      CheckEquals('AA1A', list.Get(1), 'AA1A');
      CheckEquals('K1AR', list.Get(2), 'K1AR');
      CheckEquals('K1AR/7', list.Get(3), 'a longer call after its prefix');
      CheckEquals('N6TR', list.Get(4), 'N6TR');
      CheckEquals('W1AW', list.Get(5), 'W1AW');
      CheckTrue(list.FindCallsign('n6tr', index), 'a lower-case lookup finds N6TR');
      CheckEquals(4, index, 'at 4');
      CheckFalse(list.FindCallsign('K1A', index), 'a prefix of a call is not that call');
      CheckEquals(2, index, 'its insertion point is before K1AR');
   finally
      FreeList(list);
      RestoreGlobals;
      end;
end;

procedure TCallsignsListTests.Test_ARepeatCountsQSOsUpTo255;
var
   i, index: integer;
begin
   BeginTest('Test_ARepeatCountsQSOsUpTo255');
   SaveGlobals;
   NewList(list);
   try
      list.AddCallsign('K1AR', CW, Band20, True);
      list.AddCallsign('k1ar', CW, Band40, True);
      CheckEquals(1, list.Count, 'K1AR and k1ar are one station');
      CheckEquals('K1AR', list.Get(0), 'which keeps its first spelling');
      CheckTrue(list.FindCallsign('K1AR', index), 'found');
      CheckEquals(2, Integer(list.GetQSOs(index)), 'two QSOs');
      for i := 1 to 300 do
         begin
         list.AddCallsign('K1AR', CW, Band20, True);
         end;
      CheckEquals(255, Integer(list.GetQSOs(index)), 'the QSO count stops at 255');
   finally
      FreeList(list);
      RestoreGlobals;
      end;
end;

procedure TCallsignsListTests.Test_ACallIsCutToItsWidth;
var
   index: integer;
begin
   BeginTest('Test_ACallIsCutToItsWidth');
   SaveGlobals;
   NewList(list);
   try
      list.AddCallsign('ABCDEFGHIJKLMNOP', CW, Band20, True);
      CheckEquals(CallstringLength, Length(list.Get(0)), 'stored at CallString width');
      CheckEquals('ABCDEFGHIJKLM', list.Get(0), 'its first thirteen characters');
      CheckTrue(list.FindCallsign('ABCDEFGHIJKLMXYZ', index), 'a lookup is cut the same way');
   finally
      FreeList(list);
      RestoreGlobals;
      end;
end;

procedure TCallsignsListTests.Test_DupeBitsAndTheByBandByModeKey;
var
   index: integer;
   dupes: TDupesArray;
begin
   BeginTest('Test_DupeBitsAndTheByBandByModeKey');
   SaveGlobals;
   NewList(list);
   try
      list.AddCallsign('DL1ABC', CW, Band20, True);
      CheckFalse(list.CallsignIsDupe('DL1ABC', Band20, CW, index), 'JustAddToList marks nothing');
      CheckEquals(0, index, 'but reports where it is');
      CheckTrue(list.GetDupesArray(index, dupes), 'its dupe bits are readable');
      CheckTrue(AllZero(dupes), 'and all zero');

      list.AddCallsign('DL1ABC', CW, Band20, False);
      CheckTrue(list.CallsignIsDupe('DL1ABC', Band20, CW, index), 'by band and mode: 20 m CW is a dupe');
      CheckFalse(list.CallsignIsDupe('DL1ABC', Band40, CW, index), '40 m CW is not');
      CheckFalse(list.CallsignIsDupe('DL1ABC', Band20, Phone, index), '20 m Phone is not');
      CheckTrue(list.GetDupesArray(index, dupes), 'bits readable');
      CheckEquals(Integer((Cardinal(1) shl Ord(Band20)) or (Cardinal(1) shl Ord(AllBands))),
                  Integer(dupes[CW]), 'CW holds 20 m and the AllBands key');
      CheckEquals(Integer(dupes[CW]), Integer(dupes[Both]), 'and Both the same');
      CheckEquals(0, Integer(dupes[Phone]), 'Phone nothing');

      Settings.Qso.ByMode := False;
      CheckTrue(list.CallsignIsDupe('DL1ABC', Band20, Phone, index), 'not by mode: 20 m Phone is a dupe');
      CheckFalse(list.CallsignIsDupe('DL1ABC', Band40, Phone, index), 'but 40 m is not');
      Settings.Qso.ByBand := False;
      CheckTrue(list.CallsignIsDupe('DL1ABC', Band40, Phone, index), 'not by band either: any QSO is a dupe');
      Settings.Qso.ByMode := True;
      CheckTrue(list.CallsignIsDupe('DL1ABC', Band40, CW, index), 'not by band, by mode: 40 m CW is a dupe');
      CheckFalse(list.CallsignIsDupe('DL1ABC', Band40, Phone, index), 'and Phone is not');
      CheckEquals(2, Integer(list.GetQSOs(index)), 'a listed add and a logged add each count a QSO');
   finally
      FreeList(list);
      RestoreGlobals;
      end;
end;

(* AN FM QSO MARKS PHONE'S BITS AND LEAVES THE CALL ALONE -- a FIX, not a pin
   of the old code (P8, 2026-10-17). AddCallsign indexed the dupe bits with
   the mode itself, and TDupesArray stops at NoMode, so an FM QSO wrote PAST
   the array into the entry's call: measured with the old record layout,
   'K1AR' on 20 m FM became a 12-character 'KqAR' plus NULs, which also breaks
   the list's order and so every later binary search over it. The loader
   and LogContact remap FM before calling; the rescore passes the record's
   mode as stored. *)
procedure TCallsignsListTests.Test_AnFMQSOMarksPhoneAndLeavesTheCallAlone;
var
   index: integer;
begin
   BeginTest('Test_AnFMQSOMarksPhoneAndLeavesTheCallAlone');
   SaveGlobals;
   NewList(list);
   try
      list.AddCallsign('K1AR', FM, Band20, False);
      list.AddCallsign('W1AW', FM, Band20, False);
      CheckEquals('K1AR', list.Get(0), 'the call is untouched');
      CheckEquals('W1AW', list.Get(1), 'and so is the next');
      CheckTrue(list.FindCallsign('K1AR', index), 'so it is still found');
      CheckTrue(list.CallsignIsDupe('K1AR', Band20, Phone, index), 'an FM QSO marks Phone');
      CheckTrue(list.CallsignIsDupe('K1AR', Band20, FM, index), 'and FM reads Phone');
      CheckFalse(list.CallsignIsDupe('K1AR', Band20, CW, index), 'not CW');
      CheckFalse(list.CallsignIsDupe('K1AR', Band40, Phone, index), 'nor another band');
   finally
      FreeList(list);
      RestoreGlobals;
      end;
end;

procedure TCallsignsListTests.Test_InitialExchangeAddAndReplace;
var
   index: integer;
begin
   BeginTest('Test_InitialExchangeAddAndReplace');
   SaveGlobals;
   NewList(list);
   try
      CheckTrue(list.AddIniitialExchange('N6TR', 'TREE OR'), 'a new station: True');
      CheckEquals(1, list.Count, 'it is added');
      CheckTrue(list.FindCallsign('N6TR', index), 'found');
      CheckEquals(0, Integer(list.GetQSOs(index)), 'with no QSOs');
      CheckEquals('TREE OR', list.GetIniitialExchange('n6tr'), 'its exchange, case-blind lookup');
      CheckEquals('TREE OR', list.GetIniitialExchangeByIndex(index), 'by index too');
      CheckFalse(list.AddIniitialExchange('N6TR', 'LARRY OR'), 'a known station: False');
      CheckEquals('LARRY OR', list.GetIniitialExchange('N6TR'), 'but the exchange is replaced');
      CheckEquals(1, list.Count, 'and nothing is added');
      list.AddIniitialExchange('K1AR', 'ABCDEFGHIJKLMNOPQRST');
      CheckEquals('ABCDEFGHIJKLMN', list.GetIniitialExchange('K1AR'),
                  'an exchange is kept to fourteen characters');
      list.AddCallsign('N6TR', CW, Band20, True);
      CheckEquals('LARRY OR', list.GetIniitialExchange('N6TR'), 'a QSO keeps the exchange');
      CheckEquals('', list.GetIniitialExchange('W1AW'), 'a miss is empty');
   finally
      FreeList(list);
      RestoreGlobals;
      end;
end;

procedure TCallsignsListTests.Test_TotalWorkedCountsOnlyStationsWithQSOs;
begin
   BeginTest('Test_TotalWorkedCountsOnlyStationsWithQSOs');
   SaveGlobals;
   NewList(list);
   try
      list.AddIniitialExchange('N6TR', 'TREE OR');
      list.AddIniitialExchange('K1AR', 'JOHN MA');
      list.AddCallsign('K1AR', CW, Band20, False);
      list.AddCallsign('W1AW', CW, Band20, False);
      list.AddCallsign('W1AW', CW, Band40, False);
      CheckEquals(3, list.Count, 'three stations known');
      CheckEquals(2, list.GetTotalWorkedStations, 'two of them worked');
   finally
      FreeList(list);
      RestoreGlobals;
      end;
end;

procedure TCallsignsListTests.Test_ClearDupesKeepsStationsAndExchanges;
var
   index: integer;
begin
   BeginTest('Test_ClearDupesKeepsStationsAndExchanges');
   SaveGlobals;
   NewList(list);
   try
      list.AddCallsign('K1AR', CW, Band20, False);
      list.AddIniitialExchange('K1AR', 'JOHN MA');
      list.ClearDupes;
      CheckEquals(1, list.Count, 'the station stays');
      CheckTrue(list.FindCallsign('K1AR', index), 'found');
      CheckEquals(0, Integer(list.GetQSOs(index)), 'with no QSOs');
      CheckFalse(list.CallsignIsDupe('K1AR', Band20, CW, index), 'and no dupe');
      CheckEquals('JOHN MA', list.GetIniitialExchange('K1AR'), 'its exchange stays');
      CheckEquals(0, list.GetTotalWorkedStations, 'nobody is worked');
   finally
      FreeList(list);
      RestoreGlobals;
      end;
end;

procedure TCallsignsListTests.Test_FindNumberReverseLookup;
begin
   BeginTest('Test_FindNumberReverseLookup');
   SaveGlobals;
   NewList(list);
   try
      list.AddIniitialExchange('N4AF', 'HOWIE 1234');
      list.AddIniitialExchange('K1AR', 'JOHN 77');
      list.AddIniitialExchange('W1AW', 'HQ');
      CallWindowString := '';
      CheckTrue(list.FindNumber('77'), 'the last word of an exchange is the number');
      CheckEquals('K1AR', string(CallWindowString), 'and its call goes to the call window');
      CheckTrue(list.FindNumber('1234'), 'another number');
      CheckEquals('N4AF', string(CallWindowString), 'its call');
      CheckTrue(list.FindNumber('hq'), 'case-blind, and a one-word exchange is its own last word');
      CheckEquals('W1AW', string(CallWindowString), 'W1AW');
      CallWindowString := 'UNTOUCHED';
      CheckFalse(list.FindNumber('4321'), 'a number nobody sent is not found');
      CheckEquals('UNTOUCHED', string(CallWindowString), 'and the call window is left alone');
      CheckFalse(list.FindNumber('HOWIE'), 'a word that is not the last one is not a number');
   finally
      FreeList(list);
      RestoreGlobals;
      end;
end;

procedure TCallsignsListTests.Test_PartialsListSubstringOrderAndLimit;
var
   i, n: integer;
begin
   BeginTest('Test_PartialsListSubstringOrderAndLimit');
   SaveGlobals;
   NewList(list);
   try
      Settings.PossibleCall.Enable := True;
      ActiveBand := Band20;
      ActiveMode := CW;
      list.AddCallsign('W1AW', CW, Band20, False);
      list.AddCallsign('K1AR', CW, Band40, False);
      list.AddCallsign('N6TR', CW, Band20, False);
      list.AddCallsign('KA1ARX', CW, Band20, True);
      list.AddCallsign('AA1AR', CW, Band20, False);

      n := list.CreatePartialsList('1AR');
      CheckEquals(3, n, 'three calls contain 1AR');
      CheckEquals('AA1AR', string(PossibleCallList.List[0].Call), 'in the list''s order: AA1AR');
      CheckEquals('K1AR', string(PossibleCallList.List[1].Call), 'K1AR');
      CheckEquals('KA1ARX', string(PossibleCallList.List[2].Call), 'KA1ARX');
      CheckTrue(PossibleCallList.List[0].Dupe, 'AA1AR was worked on 20 m CW: a dupe here');
      CheckFalse(PossibleCallList.List[1].Dupe, 'K1AR was worked on 40 m: not a dupe on 20 m');
      CheckFalse(PossibleCallList.List[2].Dupe, 'KA1ARX was only listed: not a dupe');

      CheckEquals(0, list.CreatePartialsList('1ar'), 'the match is case-SENSITIVE');
      CheckEquals(0, list.CreatePartialsList('1'), 'fewer than two characters lists nothing');
      CheckEquals(0, list.CreatePartialsList('ZZ'), 'no match, nothing');

      for i := 0 to 19 do
         begin
         list.AddCallsign('K' + IntToStr(i) + 'QQ', CW, Band20, True);
         end;
      n := list.CreatePartialsList('QQ');
      CheckEquals(MaxCallsignsInPossibleCallsList, n, 'the strip stops at nine');
      CheckEquals('K0QQ', string(PossibleCallList.List[0].Call), 'the first nine in order: K0QQ');
      CheckEquals('K10QQ', string(PossibleCallList.List[1].Call), 'then K10QQ, ordinal');
      CheckEquals('K17QQ', string(PossibleCallList.List[8].Call), 'and the ninth is K17QQ');

      Settings.PossibleCall.Enable := False;
      CheckEquals(0, list.CreatePartialsList('1AR'), 'disabled, nothing');
   finally
      FreeList(list);
      RestoreGlobals;
      end;
end;

procedure TCallsignsListTests.Test_CapacityRefusesTheHundredThousandAndFirst;
var
   i, index: integer;
begin
   BeginTest('Test_CapacityRefusesTheHundredThousandAndFirst');
   SaveGlobals;
   NewList(list);
   try
      (* Ascending, so every add is an append. *)
      for i := 0 to MAXCALLSIGNSINLIST - 1 do
         begin
         list.AddCallsign('A' + Format('%.6d', [i]), CW, Band20, True);
         end;
      CheckEquals(MAXCALLSIGNSINLIST, list.Count, 'the list holds 100,000 stations');
      list.AddCallsign('ZZ9ZZ', CW, Band20, True);
      CheckEquals(MAXCALLSIGNSINLIST, list.Count, 'and refuses the next one');
      CheckFalse(list.FindCallsign('ZZ9ZZ', index), 'which is not in it');
      list.AddIniitialExchange('ZZ8ZZ', 'X');
      CheckEquals(MAXCALLSIGNSINLIST, list.Count, 'nor does an initial exchange add one');
      list.AddCallsign('A050000', CW, Band20, True);
      CheckTrue(list.FindCallsign('A050000', index), 'a known station still counts');
      CheckEquals(2, Integer(list.GetQSOs(index)), 'its second QSO');
      CheckEquals('A099999', list.Get(MAXCALLSIGNSINLIST - 1), 'the last is in place');
   finally
      FreeList(list);
      RestoreGlobals;
      end;
end;

procedure TCallsignsListTests.RunAllTests;
begin
   Test_EmptyListFindsNothing;
   Test_OrderIsOrdinalAndCaseBlind;
   Test_ARepeatCountsQSOsUpTo255;
   Test_ACallIsCutToItsWidth;
   Test_DupeBitsAndTheByBandByModeKey;
   Test_AnFMQSOMarksPhoneAndLeavesTheCallAlone;
   Test_InitialExchangeAddAndReplace;
   Test_TotalWorkedCountsOnlyStationsWithQSOs;
   Test_ClearDupesKeepsStationsAndExchanges;
   Test_FindNumberReverseLookup;
   Test_PartialsListSubstringOrderAndLimit;
   Test_CapacityRefusesTheHundredThousandAndFirst;
end;

end.
