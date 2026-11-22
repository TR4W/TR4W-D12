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

(* THE RU3AX MEMORIAL, REBUILT TO THE 2025 RULES -- issue 57 (2026-11-22),
  docs/ContestRules/Russian 160/rules russian 160.txt. Each rule pinned with
  the case beside it that it must not touch:

    1    160 m only; CW and SSB only; two rounds, 17:00-18:59 and 19:00-20:59.
    4    RS(T) + a four-character grid; the grid is required.
    5.1  10 points to 499.99 km, one more per whole 500 km, centre to centre.
    5.2  SSB doubles.
    6    a repeat in the other round is a new QSO.
    7.1  DXCC + WAE (the CQ list); the oblast from the call (FJ, AN by call).
    7.2  Kaliningrad: DX UA2 and oblast KA. *)
unit uTestContestRU3AXMemorial;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework, VC, uContestBase;

type
   TContestRU3AXMemorialTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_PointsByDistanceBoundaries;
      procedure Test_PointsBetweenGrids;
      procedure Test_SSBDoubles;
      procedure Test_AGridThatIsNoneScoresZero;
      procedure Test_Rounds;
      procedure Test_RoundsAreDupeKeys;
      procedure Test_BandsAndModes;
      procedure Test_MultiplierRules;
      procedure Test_ExchangeIsRSTAndGrid;
      procedure Test_ParseTakesTheGridAndTheCallsOblast;
      procedure Test_ParseRefusesAReportWithoutAGrid;
      procedure Test_OblastFromCall;
   end;

implementation

uses
   SysUtils,
   uGridDistance,
   uRussianTerritories,
   uContestRU3AXMemorial,
   uContestRegistry,
   uAppStrings,
   uTestExchangeParserStub,
   uTestContestObjects;

function RoundQso(aHour: integer; aMinute: integer): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.Callsign := 'DL1ABC';
   Result.QTH.CountryID := 'DL';
   Result.Mode := CW;
   Result.Band := Band160;
   Result.tSysTime.qtHour := aHour;
   Result.tSysTime.qtMinute := aMinute;
end;

(* THE STUB FORMAT PARSE: the RST-and/or-grid parser's shape -- the last
   word as the grid (QTHString and, as the engine's parser does,
   DomesticQTH), a report of 599. Refuses an empty text. *)
function GridParser(const aHelper: string; const aText: string;
                    var aExch: ContestExchange): boolean;
var
   words: string;
   last: string;
   p: integer;
begin
   words := Trim(aText);
   last := words;
   p := LastDelimiter(' ', words);
   if p > 0 then
      begin
      last := Copy(words, p + 1, MaxInt);
      end;
   aExch.RSTReceived := 599;
   aExch.QTHString := ShortString(last);
   aExch.DomesticQTH := ShortString(last);
   Result := words <> '';
end;

(* THE TABLE: russian.dom's spelling for KA and MA, nothing else. *)
function ResolveOblast(const aQTH: string;
                       out aDomesticQTH: string;
                       out aMultiplier: string): boolean;
begin
   aDomesticQTH := '';
   aMultiplier := '';
   Result := (aQTH = 'KA') or (aQTH = 'MA');
   if Result then
      begin
      aDomesticQTH := aQTH[1] + LowerCase(aQTH[2]);
      aMultiplier := aDomesticQTH;
      end;
end;

function TestSession: TReceivedExchangeSession;
begin
   Result := Default(TReceivedExchangeSession);
   Result.Parsers := StubExchangeParsers(@GridParser);
   Result.ResolveDomesticQTH := @ResolveOblast;
end;

(* RULE 5.1: "up to 500 km is 10 points, from 500 to 1000 km - 11 points,
   from 1000 to 1500 km - 12 points". *)
procedure TContestRU3AXMemorialTests.Test_PointsByDistanceBoundaries;
begin
   BeginTest('Test_PointsByDistanceBoundaries');
   CheckEquals(10, RU3AXPointsForDistance(0.0), '0 km: the minimum');
   CheckEquals(10, RU3AXPointsForDistance(1.0), '1 km');
   CheckEquals(10, RU3AXPointsForDistance(499.0), '499 km');
   CheckEquals(10, RU3AXPointsForDistance(499.999), 'just under 500 km');
   CheckEquals(11, RU3AXPointsForDistance(500.0), '500 km: "from 500 to 1000 km - 11"');
   CheckEquals(11, RU3AXPointsForDistance(999.9), '999.9 km');
   CheckEquals(12, RU3AXPointsForDistance(1000.0), '1000 km');
   CheckEquals(13, RU3AXPointsForDistance(1500.0), '1500 km');
   CheckEquals(29, RU3AXPointsForDistance(9999.0), '9999 km: 10 + 19');
   CheckEquals(10, RU3AXPointsForDistance(-1.0), 'no negative distance is below the minimum');
end;

(* RULE 5.1's DISTANCE IS GridHaversineKm, CENTRE TO CENTRE. *)
procedure TContestRU3AXMemorialTests.Test_PointsBetweenGrids;
begin
   BeginTest('Test_PointsBetweenGrids');
   CheckEquals(10, RU3AXQSOPoints('KO85', 'KO85', CW), 'the same square: 0 km, 10 points');
   CheckEquals(RU3AXPointsForDistance(GridHaversineKm('KO85', 'FN31')),
               RU3AXQSOPoints('KO85', 'FN31', CW),
               'KO85 to FN31: the centre-to-centre distance');
   CheckEquals(RU3AXQSOPoints('KO85', 'FN31', CW),
               RU3AXQSOPoints('KO85UR', 'FN31PR', CW),
               'a six-character grid is its square''s centre');
   CheckEquals(RU3AXQSOPoints('KO85', 'FN31', CW),
               RU3AXQSOPoints('ko85', 'fn31', CW),
               'case does not matter');
   CheckTrue(RU3AXQSOPoints('KO85', 'FN31', CW) > 10, 'Moscow to New England is more than 500 km');
end;

(* RULE 5.2: "SSB points are multiplied by factor 2." *)
procedure TContestRU3AXMemorialTests.Test_SSBDoubles;
begin
   BeginTest('Test_SSBDoubles');
   CheckEquals(20, RU3AXQSOPoints('KO85', 'KO85', Phone), 'SSB doubles the minimum');
   CheckEquals(2 * RU3AXQSOPoints('KO85', 'FN31', CW),
               RU3AXQSOPoints('KO85', 'FN31', Phone),
               'SSB doubles a distance');
end;

(* Q37: a malformed grid is never measured. *)
procedure TContestRU3AXMemorialTests.Test_AGridThatIsNoneScoresZero;
begin
   BeginTest('Test_AGridThatIsNoneScoresZero');
   CheckEquals(0, RU3AXQSOPoints('', 'KO85', CW), 'no MY GRID');
   CheckEquals(0, RU3AXQSOPoints('KO85', '', CW), 'no received grid');
   CheckEquals(0, RU3AXQSOPoints('KO85', 'MA', CW), 'an oblast is no grid');
   CheckEquals(0, RU3AXQSOPoints('KO85', '599', Phone), 'a report is no grid');
end;

(* RULE 1: "The 1st round from 17:00 to 18:59 UTC / The 2nd round from 19:00
   to 20:59 UTC". *)
procedure TContestRU3AXMemorialTests.Test_Rounds;
begin
   BeginTest('Test_Rounds');
   CheckEquals(0, RU3AXRoundOf(16, 59), '16:59 is before the contest');
   CheckEquals(1, RU3AXRoundOf(17, 0), '17:00 opens round 1');
   CheckEquals(1, RU3AXRoundOf(18, 59), '18:59 is round 1');
   CheckEquals(2, RU3AXRoundOf(19, 0), '19:00 opens round 2');
   CheckEquals(2, RU3AXRoundOf(20, 59), '20:59 is round 2');
   CheckEquals(0, RU3AXRoundOf(21, 0), '21:00 is after the contest');
end;

(* RULE 6.1/6.3: a dupe is the same mode AND the same round. *)
procedure TContestRU3AXMemorialTests.Test_RoundsAreDupeKeys;
var
   c: TContestBase;
begin
   BeginTest('Test_RoundsAreDupeKeys');
   c := ContestIdentity(RU3AXMEMORIAL);
   CheckEquals('ROUND 1', c.DupeKeyTour(RoundQso(17, 30)), 'round 1 names itself');
   CheckEquals('ROUND 2', c.DupeKeyTour(RoundQso(19, 30)), 'round 2 names itself');
   CheckTrue(c.DupeKeyQualifier(RoundQso(17, 30)) <> c.DupeKeyQualifier(RoundQso(19, 30)),
             'rounds 1 and 2 are different dupe keys');
   CheckEquals(c.DupeKeyQualifier(RoundQso(17, 0)), c.DupeKeyQualifier(RoundQso(18, 59)),
               'one round, one key');
   CheckEquals('', c.DupeKeyTour(RoundQso(12, 0)), 'outside the contest: the call alone');
   CheckTrue(cfQSOByMode in c.Flags, 'dupes per mode (6.1)');
end;

(* RULE 1: "on 1.8 MHz amateur band ONLY. Modes: CW and SSB." *)
procedure TContestRU3AXMemorialTests.Test_BandsAndModes;
var
   c: TContestBase;
begin
   BeginTest('Test_BandsAndModes');
   c := ContestIdentity(RU3AXMEMORIAL);
   CheckTrue(c.UsesBand(Band160), '160 m');
   CheckFalse(c.UsesBand(Band80), 'not 80 m');
   CheckFalse(c.UsesBand(Band20), 'not 20 m');
   CheckTrue(c.UsesMode(CW, eNoMode), 'CW');
   CheckTrue(c.UsesMode(Phone, eNoMode), 'SSB');
   CheckFalse(c.UsesMode(Digital, eNoMode), 'not digital');
   CheckFalse(c.UsesMode(FM, eNoMode), 'not FM');
end;

(* RULES 7.1-7.4. *)
procedure TContestRU3AXMemorialTests.Test_MultiplierRules;
var
   c: TContestBase;
   q: ContestExchange;
   key: DXMultiplierString;
begin
   BeginTest('Test_MultiplierRules');
   c := ContestIdentity(RU3AXMEMORIAL);
   CheckTrue(c.CountryMode = CQCountryMode, '7.1: territories are DXCC + WAE (the CQ list)');
   CheckTrue(cfMultByMode in c.Flags, '7.3: multipliers by mode, summed');
   CheckFalse(cfMultByBand in c.Flags, 'one band');
   CheckTrue(c.HasDXMultiplier, 'a DX multiplier');
   CheckTrue(c.UsesDomesticFile, 'the oblasts, from russian.dom');

   q := RoundQso(17, 0);
   q.Callsign := 'UA2FAA';
   q.QTH.CountryID := 'UA2';
   CheckTrue(c.DXMultiplierKey(q, key), 'Kaliningrad has a DX key');
   CheckEquals('UA2', string(key), '7.2: Kaliningrad is a DXCC multiplier');
   CheckEquals('KA', RDXCOblastFromCall('UA2FAA', 'UA2'), '7.2: and an oblast');
end;

(* RULE 4: "RS(T) + Four character grid square". *)
procedure TContestRU3AXMemorialTests.Test_ExchangeIsRSTAndGrid;
var
   c: TContestBase;
begin
   BeginTest('Test_ExchangeIsRSTAndGrid');
   c := ContestIdentity(RU3AXMEMORIAL);
   CheckTrue(c.ExchangeKind = RSTAndOrGridExchange, 'the RST-and/or-grid format');
   CheckTrue(c.ExchangeCarriesGridSquare, 'the exchange carries a grid (MY GRID is asked)');
   CheckFalse(c.ExchangeCarriesDomesticQTH, 'no oblast is sent any more');
   CheckTrue(c.ExchangeTextMayHoldGridSquare, 'a word may be a grid');
   CheckFalse(c.MayBeACallsign('KO85UR'), 'a six-character grid is never a call');
   CheckTrue(c.MayBeACallsign('UA3ABC'), 'a call is');
   CheckEquals('RADIO-160', c.CabrilloName, 'the Cabrillo name is unchanged');
   CheckEquals('RU3AX MEMORIAL', c.ADIFContestId, 'the ADIF id is unchanged');
end;

(* THE GRID IS QTHString, CUT TO FOUR; THE OBLAST IS THE CALL'S, IN THE
   TABLE'S SPELLING; A STATION THAT IS NOT RUSSIAN HAS NONE. *)
procedure TContestRU3AXMemorialTests.Test_ParseTakesTheGridAndTheCallsOblast;
var
   c: TContestBase;
   q: ContestExchange;
   msg: string;
begin
   BeginTest('Test_ParseTakesTheGridAndTheCallsOblast');
   c := ContestIdentity(RU3AXMEMORIAL);

   q := RoundQso(17, 0);
   q.Callsign := 'UA2FAA';
   q.QTH.CountryID := 'UA2';
   CheckTrue(c.ParseReceivedExchange('599 KO04', TestSession, q, msg), 'Kaliningrad 599 KO04');
   CheckEquals('KO04', string(q.QTHString), 'the grid is QTHString');
   CheckEquals('Ka', string(q.DomesticQTH), 'the oblast, as the table spells it');
   CheckEquals('Ka', string(q.DomMultQTH), 'and its multiplier key');

   q := RoundQso(17, 0);
   CheckTrue(c.ParseReceivedExchange('599 JO62QM', TestSession, q, msg), 'DL 599 JO62QM');
   CheckEquals('JO62', string(q.QTHString), 'a six-character grid is kept as its square');
   CheckEquals('', string(q.DomesticQTH), 'not Russian: no oblast -- never the grid');
   CheckEquals('', string(q.DomMultQTH), 'and no domestic multiplier');
end;

procedure TContestRU3AXMemorialTests.Test_ParseRefusesAReportWithoutAGrid;
var
   c: TContestBase;
   q: ContestExchange;
   msg: string;
begin
   BeginTest('Test_ParseRefusesAReportWithoutAGrid');
   c := ContestIdentity(RU3AXMEMORIAL);
   q := RoundQso(17, 0);
   CheckFalse(c.ParseReceivedExchange('599', TestSession, q, msg), 'a report alone');
   CheckEquals(SExchangeGridRequired, msg, 'refused: the grid is required');
   CheckEquals('', string(q.QTHString), 'a refusal writes nothing into the QSO');
   CheckEquals(0, q.RSTReceived, 'not even the report');
end;

(* RULE 7.1: "Separate Russian Oblasts are Franz Joseph (R1FJ) and Russian
   stations in Antarctica (R1AN)." *)
procedure TContestRU3AXMemorialTests.Test_OblastFromCall;
var
   c: TContestBase;
   lookups: TMultiplierHintLookups;
begin
   BeginTest('Test_OblastFromCall');
   CheckEquals('FJ', RDXCOblastFromCall('R1FJL', 'R1FJ'), 'Franz Josef Land is FJ');
   CheckEquals('AN', RDXCOblastFromCall('RI1ANA', 'UA'), 'RI1AN is AN');
   CheckEquals('', RDXCOblastFromCall('DL1ABC', 'DL'), 'DL has no oblast');

   c := ContestIdentity(RU3AXMEMORIAL);
   lookups := Default(TMultiplierHintLookups);
   CheckEquals('', c.DomesticMultiplierFromCall('UA2FAA', lookups),
               'no country service, no hint');
end;

procedure TContestRU3AXMemorialTests.RunAllTests;
begin
   Test_PointsByDistanceBoundaries;
   Test_PointsBetweenGrids;
   Test_SSBDoubles;
   Test_AGridThatIsNoneScoresZero;
   Test_Rounds;
   Test_RoundsAreDupeKeys;
   Test_BandsAndModes;
   Test_MultiplierRules;
   Test_ExchangeIsRSTAndGrid;
   Test_ParseTakesTheGridAndTheCallsOblast;
   Test_ParseRefusesAReportWithoutAGrid;
   Test_OblastFromCall;
end;

end.
