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

(* THREE READ-PAST-THE-END SHAPES, BOUNDED -- design Q47 (2026-10-22).

  Each was copied verbatim from D7 and is a DEFECT, not a rule: a memory read
  has no D7 answer to recreate. Each test pins what the bounded code gives
  for the input that used to read outside the text, and the ordinary case
  beside it that must not move:

    MWC                    the multiplier character of the worked call --
                           walked within the call, never a '/', '' for an
                           empty call or one of slashes only.
    Region 1 Field Day     an empty MY COUNTRY is not 'G', so 160 and 10 m
                           are not doubled.
    Region 1 FD, RCC CW/SSB  4 only when the call ENDS in /P or /M; a
                           one-character call no longer scores 4, and an
                           earlier '/P' no longer hides a closing /M.

  THE EMPTY MY COUNTRY TEST CANNOT FAIL ON DEMAND, and says so. The old
  code read the first byte of a LOCAL copy of MY COUNTRY, and a ShortString
  assignment copies only the used bytes, so that byte is whatever the stack
  held -- measured 2026-10-23: with the bound removed, scoring a 'G' station
  first on the same object, or handing in an empty MY COUNTRY with a 'G'
  left in its buffer, still read a byte that was not 'G'. So the test pins
  what the bounded code gives; it is not a mutation detector for that line.
  The MWC and RCC tests are: each fails with its bound removed. *)
unit uTestContestReadBounds;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework, VC, uContestBase;

type
   TContestReadBoundsTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      (* The domestic multiplier MWC's ScoreQSO gives a QSO with aCall. *)
      function MWCMultiplierOf(const aCall: string): string;
      (* The points aContest's ScoreQSO gives a QSO with aCall, from a
         station of aCountry, on aBand, with a station of rxCountry on
         rxContinent. *)
      function PointsFor(aContest: ContestType; const aMyCountry: string;
                         aMyContinent: ContinentType; const aCall: string;
                         aBand: BandType; const rxCountry: string;
                         rxContinent: ContinentType): integer;
      procedure Test_MWCReadsOnlyInsideTheCall;
      procedure Test_MWCOrdinaryCallsAreUnchanged;
      procedure Test_Region1FieldDayEmptyCountryIsNotG;
      procedure Test_Region1FieldDayRCCScoresFourOnlyForAClosingSuffix;
   end;

implementation

uses
   uTestContestObjects;

procedure TContestReadBoundsTests.RunAllTests;
begin
   Test_MWCReadsOnlyInsideTheCall;
   Test_MWCOrdinaryCallsAreUnchanged;
   Test_Region1FieldDayEmptyCountryIsNotG;
   Test_Region1FieldDayRCCScoresFourOnlyForAClosingSuffix;
end;

function TContestReadBoundsTests.MWCMultiplierOf(const aCall: string): string;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(MWC, NoStation);
   try
      qso := Default(ContestExchange);
      qso.Band := Band80;
      qso.Mode := CW;
      qso.Callsign := CallString(aCall);
      contestObject.ScoreQSO(qso);
      Result := string(qso.DomMultQTH);
   finally
      contestObject.Free;
   end;
end;

function TContestReadBoundsTests.PointsFor(aContest: ContestType;
                                           const aMyCountry: string;
                                           aMyContinent: ContinentType;
                                           const aCall: string;
                                           aBand: BandType;
                                           const rxCountry: string;
                                           rxContinent: ContinentType): integer;
var
   station: TStationContext;
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   station := NoStation;
   station.MyCountry := CallString(aMyCountry);
   station.MyContinent := aMyContinent;
   contestObject := Make(aContest, station);
   try
      qso := Default(ContestExchange);
      qso.Band := aBand;
      qso.Mode := CW;
      qso.Callsign := CallString(aCall);
      qso.QTH.CountryID := ShortString(rxCountry);
      qso.QTH.Continent := rxContinent;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* THE CALLS THAT USED TO BE READ OUTSIDE: eleven characters with no early
  '/'-letter (read past the string[10] copy), a closing '/' (one past the
  end), an opening '/' (the length byte), and an empty call. *)
procedure TContestReadBoundsTests.Test_MWCReadsOnlyInsideTheCall;
begin
   BeginTest('Test_MWCReadsOnlyInsideTheCall');
   CheckEquals('G', MWCMultiplierOf('W1ABCDEFG/P'),
               'MWC: an eleven-character call is walked to its own /P');
   CheckEquals('G', MWCMultiplierOf('W1ABCDEFGHG'),
               'MWC: an eleven-character call gives its own last character');
   CheckEquals('A', MWCMultiplierOf('PA/W1ABCD/P'),
               'MWC: PA/W1ABCD/P gives the character before the first /-letter');
   CheckEquals('W', MWCMultiplierOf('W1AW/'),
               'MWC: a closing / is not the multiplier; the last other character is');
   CheckEquals('P', MWCMultiplierOf('/P'),
               'MWC: an opening / has no character before it');
   CheckEquals('W', MWCMultiplierOf('/W1AW'),
               'MWC: an opening / before a call gives the call''s last character');
   CheckEquals('', MWCMultiplierOf(''),
               'MWC: an empty call gives no multiplier');
   CheckEquals('', MWCMultiplierOf('//'),
               'MWC: a call of slashes only gives no multiplier');
end;

(* EVERY CALL OF TEN CHARACTERS OR FEWER THAT NEITHER STARTS NOR ENDS WITH A
  '/' GIVES WHAT THE ARM GAVE. *)
procedure TContestReadBoundsTests.Test_MWCOrdinaryCallsAreUnchanged;
begin
   BeginTest('Test_MWCOrdinaryCallsAreUnchanged');
   CheckEquals('C', MWCMultiplierOf('OK1ABC'), 'MWC: OK1ABC');
   CheckEquals('C', MWCMultiplierOf('OK1ABC/P'), 'MWC: OK1ABC/P');
   CheckEquals('9', MWCMultiplierOf('OK1ABC/9'), 'MWC: OK1ABC/9 -- a digit after the / is no suffix');
   CheckEquals('K', MWCMultiplierOf('OK/W1AW'), 'MWC: OK/W1AW');
   CheckEquals('A', MWCMultiplierOf('A'), 'MWC: a one-character call');
end;

(* AN EMPTY MY COUNTRY IS NOT 'G': a 160 m or 10 m QSO from it is not
  doubled. ONE object scores a 'G' station's QSO and then, with nothing in
  between but SetStation, the empty station's -- the likeliest way to leave
  a 'G' where the old read looked, though not a certain one (see the
  header). *)
procedure TContestReadBoundsTests.Test_Region1FieldDayEmptyCountryIsNotG;
var
   gStation: TStationContext;
   emptyStation: TStationContext;
   contestObject: TContestBase;
   qso: ContestExchange;
   band: BandType;
begin
   BeginTest('Test_Region1FieldDayEmptyCountryIsNotG');
   gStation := NoStation;
   gStation.MyCountry := 'G';
   gStation.MyContinent := Europe;
   emptyStation := NoStation;
   emptyStation.MyContinent := Europe;

   for band in [Band160, Band10] do
      begin
      contestObject := Make(REGION1FIELDDAY, gStation);
      try
         qso := Default(ContestExchange);
         qso.Band := band;
         qso.Mode := CW;
         qso.Callsign := 'DL1AAA';
         qso.QTH.CountryID := 'DL';
         qso.QTH.Continent := Europe;
         contestObject.ScoreQSO(qso);
         CheckEquals(4, qso.QSOPoints,
                     'Region 1 FD: a G station''s ' + BandStringsArray[band] + ' QSO is doubled');

         contestObject.SetStation(emptyStation);
         qso.QSOPoints := 0;
         contestObject.ScoreQSO(qso);
         CheckEquals(2, qso.QSOPoints,
                     'Region 1 FD: no MY COUNTRY is not G -- ' + BandStringsArray[band] +
                     ' is not doubled');
      finally
         contestObject.Free;
      end;
      end;

   CheckEquals(2, PointsFor(REGION1FIELDDAY, 'G', Europe, 'DL1AAA', Band20, 'DL', Europe),
               'Region 1 FD: a G station''s 20 m QSO is not doubled');
end;

(* 4 ONLY FOR A CALL THAT ENDS IN /P OR /M, in both runnings -- each class
  owns its copy (Q7/Q43; no RCC family base is built yet). *)
procedure TContestReadBoundsTests.Test_Region1FieldDayRCCScoresFourOnlyForAClosingSuffix;
const
   RUNNINGS: array[0..1] of ContestType = (REGION1FIELDDAY_RCC_CW, REGION1FIELDDAY_RCC_SSB);
var
   i: integer;
   who: string;
   c: ContestType;
begin
   BeginTest('Test_Region1FieldDayRCCScoresFourOnlyForAClosingSuffix');
   for i := Low(RUNNINGS) to High(RUNNINGS) do
      begin
      c := RUNNINGS[i];
      who := string(ContestTypeSA[c]) + ': ';
      CheckEquals(2, PointsFor(c, 'UA', Europe, 'A', Band20, 'DL', Europe),
                  who + 'a one-character call is not /P');
      CheckEquals(3, PointsFor(c, 'UA', Europe, 'K', Band20, 'K', NorthAmerica),
                  who + 'a one-character call off our continent is not /P');
      CheckEquals(2, PointsFor(c, 'UA', Europe, 'DL1AAA', Band20, 'DL', Europe),
                  who + 'a plain call on our continent');
      CheckEquals(4, PointsFor(c, 'UA', Europe, 'DL1AAA/P', Band20, 'DL', Europe),
                  who + 'a closing /P');
      CheckEquals(4, PointsFor(c, 'UA', Europe, 'DL1AAA/M', Band20, 'DL', Europe),
                  who + 'a closing /M');
      CheckEquals(4, PointsFor(c, 'UA', Europe, 'DL/PA1AB/M', Band20, 'DL', Europe),
                  who + 'an earlier /P does not hide a closing /M');
      CheckEquals(2, PointsFor(c, 'UA', Europe, 'DL1AAA/PX', Band20, 'DL', Europe),
                  who + 'a /P that does not close the call is not the suffix');
      CheckEquals(4, PointsFor(c, 'UA', Europe, '/P', Band20, 'DL', Europe),
                  who + 'a bare /P closes the call');
      end;
end;

end.
