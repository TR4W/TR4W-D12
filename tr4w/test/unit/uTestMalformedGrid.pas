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

(* Q37 -- A MALFORMED GRID IS NEVER MEASURED (NY4I, 2026-10-15: "a malformed
  grid should never have been logged"; built 2026-10-17).

  LOGGRID.ConvertGridToLatLon read characters 1 to 6 of whatever it was
  handed. GetDistanceBetweenGrids padded anything that was not six
  characters with 'LL', so an empty grid arrived as 'LL' and was read past
  its end -- identical ALRS QSOs scored 43, 42 and 42, following the heap --
  and 'CT' arrived as 'CTLLLL' and was measured as letters.

  ONE PREDICATE NOW DECIDES WHAT A GRID IS: uGridShape.IsGoodLookingGrid,
  Tree.GoodLookingGrid's rule lifted unchanged -- the rule the grid exchange
  parsers refuse a typed one by. What it refuses is never read: no distance
  (0), no heading (-1), and a contest scores such a QSO by its own rule at
  no distance. Pinned both ways: a real grid still measures, and the same
  malformed input gives the same answer every time. *)
unit uTestMalformedGrid;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TMalformedGridTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_OnePredicateDecidesWhatAGridIs;
      procedure Test_AGridThatIsNotOneHasNoDistance;
      procedure Test_AGridThatIsNotOneHasNoHeading;
      procedure Test_TheEuropeanDistanceReadsNothingPastTheEnd;
      procedure Test_ContestsScoreNoDistanceByTheirOwnRule;
   end;

implementation

uses
   SysUtils,
   VC,
   Tree,
   LogGrid,
   uGridShape,
   uContestBase,
   uTestContestObjects;

procedure TMalformedGridTests.Test_OnePredicateDecidesWhatAGridIs;
const
   GRIDS: array[0..7] of string = ('FN31', 'fn31', 'FN31PR', 'fn31pr', 'AA00', 'RR99', 'AR09AA', 'JO62ZZ');
   NOT_GRIDS: array[0..13] of string = ('', 'L', 'LL', 'CT', 'FN3', 'FN31P', 'FN31PRX', 'SN31',
                                        'FN3A', 'F131', 'FN31P1', 'FN31!!', 'ZZ99', 'KS');
var
   i: integer;
begin
   BeginTest('Test_OnePredicateDecidesWhatAGridIs');
   for i := Low(GRIDS) to High(GRIDS) do
      begin
      CheckTrue(IsGoodLookingGrid(GRIDS[i]), GRIDS[i] + ' is a grid');
      CheckTrue(GoodLookingGrid(Str20(GRIDS[i])), GRIDS[i] + ': Tree agrees');
      end;
   for i := Low(NOT_GRIDS) to High(NOT_GRIDS) do
      begin
      CheckFalse(IsGoodLookingGrid(NOT_GRIDS[i]), '"' + NOT_GRIDS[i] + '" is not a grid');
      CheckFalse(GoodLookingGrid(Str20(NOT_GRIDS[i])), '"' + NOT_GRIDS[i] + '": Tree agrees');
      end;
end;

procedure TMalformedGridTests.Test_AGridThatIsNotOneHasNoDistance;
const
   NOT_GRIDS: array[0..6] of string = ('', 'LL', 'CT', 'FN3', 'FN31P', 'ZZ99', 'FN3A');
var
   i: integer;
begin
   BeginTest('Test_AGridThatIsNotOneHasNoDistance');

   (* THE CONTROL: real grids still measure, four or six characters. *)
   CheckTrue(GetDistanceBetweenGrids('EL88', 'CM87') > 3000, 'EL88 to CM87 is measured');
   CheckEquals(GetDistanceBetweenGrids('EL88', 'CM87'),
               GetDistanceBetweenGrids('el88', 'cm87'), 'either case');
   CheckEquals(GetDistanceBetweenGrids('EL88LL', 'CM87LL'),
               GetDistanceBetweenGrids('EL88', 'CM87'), 'a four-character grid is its centre');
   CheckEquals(0, GetDistanceBetweenGrids('EL88', 'EL88'), 'the same grid: 0');

   for i := Low(NOT_GRIDS) to High(NOT_GRIDS) do
      begin
      CheckEquals(0, GetDistanceBetweenGrids('EM17', NOT_GRIDS[i]),
                  'EM17 to "' + NOT_GRIDS[i] + '": no distance');
      CheckEquals(0, GetDistanceBetweenGrids(NOT_GRIDS[i], 'EM17'),
                  '"' + NOT_GRIDS[i] + '" to EM17: no distance');
      (* THE SAME ANSWER EVERY TIME -- it used to follow the heap. *)
      CheckEquals(GetDistanceBetweenGrids('EM17', NOT_GRIDS[i]),
                  GetDistanceBetweenGrids('EM17', NOT_GRIDS[i]),
                  '"' + NOT_GRIDS[i] + '": the same twice');
      end;
end;

procedure TMalformedGridTests.Test_AGridThatIsNotOneHasNoHeading;
begin
   BeginTest('Test_AGridThatIsNotOneHasNoHeading');
   CheckTrue(GetBeamHeading('EM17', 'FN31') >= 0, 'EM17 to FN31 has a heading');
   CheckEquals(-1, GetBeamHeading('EM17', 'ZZ99'), 'ZZ99 is four characters and no grid');
   CheckEquals(-1, GetBeamHeading('EM17', 'CT'), 'CT has no heading');
   CheckEquals(-1, GetBeamHeading('', 'FN31'), 'nor has an empty grid of ours');
end;

procedure TMalformedGridTests.Test_TheEuropeanDistanceReadsNothingPastTheEnd;
begin
   BeginTest('Test_TheEuropeanDistanceReadsNothingPastTheEnd');
   CheckTrue(GetEuropeanDistanceBetweenGrids('JN45LL', 'JO62LL') > 0, 'six characters measure');
   CheckEquals(GetEuropeanDistanceBetweenGrids('JN45LL', 'JO62LL'),
               GetEuropeanDistanceBetweenGrids('JN45', 'JO62'),
               'a four-character grid is its centre, not read past its end');
   CheckEquals(0, GetEuropeanDistanceBetweenGrids('JN45', 'JO6'), 'three characters: no distance');
   CheckEquals(0, GetEuropeanDistanceBetweenGrids('', 'JO62'), 'empty: no distance');
end;

(* THE CONTESTS. Each scores a QSO whose grid is not a grid by its OWN rule
   at no distance: WWL's one point per 500 km begun plus one is 1, and the
   ALRS UA1DZ Cup's ten times the logarithm of the distance is not taken of
   0 -- the distance term is 0. A real grid is measured as before. *)
procedure TMalformedGridTests.Test_ContestsScoreNoDistanceByTheirOwnRule;
var
   station: TStationContext;
   obj: TContestBase;
   qso: ContestExchange;

   function Score(const aQTH: string): integer;
   begin
      FillChar(qso, SizeOf(qso), 0);
      qso.Callsign := 'W1AW';
      qso.Band := Band20;
      qso.Mode := CW;
      qso.QTHString := ShortString(aQTH);
      qso.DomesticQTH := ShortString(aQTH);
      obj.ScoreQSO(qso);
      Result := qso.QSOPoints;
   end;

begin
   BeginTest('Test_ContestsScoreNoDistanceByTheirOwnRule');

   station := NoStation;
   station.MyCall := 'K0AAA';
   station.MyCountry := 'K';
   station.MyGrid := 'EM17';
   station.MyState := 'EM17';

   obj := Make(WWL, station);
   try
      CheckEquals(1, Score('CT'), 'WWL, CT: no distance, one point');
      CheckEquals(1, Score('FN3'), 'WWL, FN3: no distance, one point');
      CheckEquals((GetDistanceBetweenGrids('EM17', 'FN31') div 500) + 1, Score('FN31'),
                  'WWL, FN31: measured');
      CheckTrue(Score('FN31') > 1, 'and more than the no-distance point');
   finally
      obj.Free;
   end;

   obj := Make(ALRS_UA1DZ_CUP, station);
   try
      CheckEquals(0, Score(''), 'ALRS, no QTH: no distance points');
      CheckEquals(0, Score(''), 'ALRS, no QTH: the same again, not the heap');
      CheckEquals(0, Score('KS'), 'ALRS, KS: no distance points');
      CheckEquals(Round(10 * Ln(GetDistanceBetweenGrids('EM17', 'FN31')) / Ln(10)),
                  Score('FN31'), 'ALRS, FN31: ten times the log of the distance');
      CheckTrue(Score('FN31') > 0, 'which is measured');
   finally
      obj.Free;
   end;
end;

procedure TMalformedGridTests.RunAllTests;
begin
   Test_OnePredicateDecidesWhatAGridIs;
   Test_AGridThatIsNotOneHasNoDistance;
   Test_AGridThatIsNotOneHasNoHeading;
   Test_TheEuropeanDistanceReadsNothingPastTheEnd;
   Test_ContestsScoreNoDistanceByTheirOwnRule;
end;

end.
