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

(* SCORING AND ENTRY RULES NY4I RULED ON 2026-10-15/16, BUILT 2026-10-17.

  Each test pins one ruling of docs/CONTEST_FACTORY_OPEN_QUESTIONS.md, BOTH
  WAYS -- what the rule now gives, and the case right beside it that it must
  not touch:

    Q45  EUDX and IRTS: "he is in the EU" is his resolved domestic QTH (the
         record's DomesticQTH), not the never-false `DomMultQTH[4] <> ''`.
    Q49  British Columbia: a DX contact earns no domestic multiplier.
    Q84  A party's DX-multiplier test ignores case -- Indiana, New York, BC,
         and Indiana's rule inside IN7QPNE, whose file says `dx = dx`.
    Q71  RSGB 1.8 MHz, ARRL 160 and the CQ 160 runnings credit 160 m only;
         the UA4W Championship's prompt is TC_ENTERYOURRDAIDORGRID.
    Q85  7QP scores digital 4 (CW 3, phone 2).
    Q104 New Contest refuses IN7QPNE for a MY STATE inside one of its four
         parties, naming the party (7QP for every 7th-area state).

  Q38 (Winter Field Day has no DX multiplier) is pinned where every DX
  multiplier is, uTestDXMultiplierKey. *)
unit uTestContestRulings2026Oct;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework, VC, uContestBase;

type
   TContestRulings2026OctTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      (* The points aContest's ScoreQSO gives a 20 m CW QSO with a station
         of aCountry on aContinent whose exchange resolved to aDomesticQTH
         ('' for a zone), worked from aStation. *)
      function PointsFor(aContest: ContestType; const aStation: TStationContext;
                         const aCountry: string; aContinent: ContinentType;
                         const aDomesticQTH: string): integer;
      (* Does aContest count a multiplier from a QSO whose domestic
         multiplier is aMult, worked from aStation? *)
      function CountsDomestic(aContest: ContestType; const aStation: TStationContext;
                              const aMult: string): boolean;
      procedure Test_EUDXNonEUEntrantScoresByResolvedRegion;
      procedure Test_EUDXEUEntrantScoresByResolvedRegion;
      procedure Test_IRTSScoresByResolvedCounty;
      procedure Test_DomesticMultiplierIsDXIgnoresCase;
      procedure Test_BritishColumbiaDXEarnsNoMultiplier;
      procedure Test_IndianaAndNewYorkIgnoreCase;
      procedure Test_IN7QPNEIndianaJudgedDXEarnsNoMultiplier;
      procedure Test_The160MetreContestsCredit160Only;
      procedure Test_UA4WPromptIsTheTranslatedString;
      procedure Test_SevenQPScoresDigitalFour;
      procedure Test_IN7QPNERefusesAnInAreaStation;
      procedure Test_IN7QPNEAcceptsAnOutOfAreaStation;
   end;

implementation

uses
   SysUtils,
   uTR4WStrings,      (* TC_ENTERYOURRDAIDORGRID *)
   uAppStrings,       (* SNewContestIN7QPNEInsideAParty *)
   uContestIN7QPNE,
   uTestContestObjects;

function TContestRulings2026OctTests.PointsFor(aContest: ContestType;
                                                const aStation: TStationContext;
                                                const aCountry: string;
                                                aContinent: ContinentType;
                                                const aDomesticQTH: string): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(aContest, aStation);
   try
      qso := Default(ContestExchange);
      qso.Band := Band20;
      qso.Mode := CW;
      qso.QTH.CountryID := ShortString(aCountry);
      qso.QTH.Continent := aContinent;
      qso.DomesticQTH := ShortString(aDomesticQTH);
      qso.QTHString := ShortString(aDomesticQTH);
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

function TContestRulings2026OctTests.CountsDomestic(aContest: ContestType;
                                                     const aStation: TStationContext;
                                                     const aMult: string): boolean;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(aContest, aStation);
   try
      qso := Default(ContestExchange);
      qso.Band := Band20;
      qso.Mode := CW;
      qso.DomMultQTH := ShortString(aMult);
      qso.DomesticQTH := ShortString(aMult);
      qso.QTHString := ShortString(aMult);
      Result := ContestCountsMultiplier(contestObject, qso, rmDomestic);
   finally
      contestObject.Free;
   end;
end;

function USStation: TStationContext;
begin
   Result := NoStation;
   Result.MyCall := 'K0AAA';
   Result.MyCountry := 'K';
   Result.MyContinent := NorthAmerica;
   Result.MyState := 'KS';
end;

function EUStation: TStationContext;
begin
   Result := NoStation;
   Result.MyCall := 'DL1AAA';
   Result.MyCountry := 'DL';
   Result.MyContinent := Europe;
   (* A four-character region: the EUDX table's "we are in the EU". *)
   Result.MyState := 'DE11';
end;

(* Q45, FROM OUTSIDE THE EU. A zone (no resolved region) is no longer 10: a
   European outside the EU sending a zone is off our continent (5), a North
   American another country (3), a W our own (2). A resolved region is 10. *)
procedure TContestRulings2026OctTests.Test_EUDXNonEUEntrantScoresByResolvedRegion;
begin
   BeginTest('Test_EUDXNonEUEntrantScoresByResolvedRegion');
   CheckEquals(10, PointsFor(EUDX, USStation, 'DL', Europe, 'DE11'),
               'EUDX: K working an EU region scores 10');
   CheckEquals(5, PointsFor(EUDX, USStation, 'G', Europe, ''),
               'EUDX: K working a European zone scores 5, not 10');
   CheckEquals(3, PointsFor(EUDX, USStation, 'XE', NorthAmerica, ''),
               'EUDX: K working XE (a zone) scores 3, not 10');
   CheckEquals(2, PointsFor(EUDX, USStation, 'K', NorthAmerica, ''),
               'EUDX: K working K (a zone) scores 2, not 10');
end;

(* Q45, FROM INSIDE THE EU: another EU country's region 10, our own 2; a
   station with no region 5 off our continent, 3 on it. *)
procedure TContestRulings2026OctTests.Test_EUDXEUEntrantScoresByResolvedRegion;
begin
   BeginTest('Test_EUDXEUEntrantScoresByResolvedRegion');
   CheckEquals(10, PointsFor(EUDX, EUStation, 'F', Europe, 'FR01'),
               'EUDX: DL working an F region scores 10');
   CheckEquals(2, PointsFor(EUDX, EUStation, 'DL', Europe, 'DE05'),
               'EUDX: DL working a DL region scores 2');
   CheckEquals(5, PointsFor(EUDX, EUStation, 'JA', Asia, ''),
               'EUDX: DL working JA (a zone) scores 5, not 10');
   CheckEquals(3, PointsFor(EUDX, EUStation, 'G', Europe, ''),
               'EUDX: DL working G (a zone) scores 3, not 10');
end;

(* Q45 IN IRTS: the same test, over IRTS's own file (Irish counties). *)
procedure TContestRulings2026OctTests.Test_IRTSScoresByResolvedCounty;
begin
   BeginTest('Test_IRTSScoresByResolvedCounty');
   CheckEquals(10, PointsFor(IRTS, USStation, 'EI', Europe, 'COR'),
               'IRTS: K working a county scores 10');
   CheckEquals(5, PointsFor(IRTS, USStation, 'EI', Europe, ''),
               'IRTS: K working EI with no county scores 5, not 10');
   CheckEquals(2, PointsFor(IRTS, USStation, 'K', NorthAmerica, ''),
               'IRTS: K working K (a zone) scores 2, not 10');
end;

procedure TContestRulings2026OctTests.Test_DomesticMultiplierIsDXIgnoresCase;
begin
   BeginTest('Test_DomesticMultiplierIsDXIgnoresCase');
   CheckTrue(DomesticMultiplierIsDX('DX'), 'DX');
   CheckTrue(DomesticMultiplierIsDX('dx'), 'dx');
   CheckTrue(DomesticMultiplierIsDX('Dx'), 'Dx');
   CheckFalse(DomesticMultiplierIsDX(''), 'empty is not DX');
   CheckFalse(DomesticMultiplierIsDX('DE'), 'DE is not DX');
   CheckFalse(DomesticMultiplierIsDX('DXX'), 'DXX is not DX');
end;

(* Q49: ve7.dom maps dx=DX, so the multiplier is 'DX' -- which the old 'dx'
   test never matched. A county still counts. *)
procedure TContestRulings2026OctTests.Test_BritishColumbiaDXEarnsNoMultiplier;
var
   station: TStationContext;
begin
   BeginTest('Test_BritishColumbiaDXEarnsNoMultiplier');
   station := NoStation;
   station.MyCall := 'VE7AAA';
   station.MyCountry := 'VE';
   station.InHostState := True;
   station := WithHostAreaTable(station);
   CheckFalse(CountsDomestic(BCQP, station, 'DX'), 'BC: DX earns no multiplier');
   CheckFalse(CountsDomestic(BCQP, station, 'dx'), 'BC: dx earns no multiplier');
   CheckTrue(CountsDomestic(BCQP, station, 'VAN'), 'BC: a county still counts');
end;

procedure TContestRulings2026OctTests.Test_IndianaAndNewYorkIgnoreCase;
var
   station: TStationContext;
begin
   BeginTest('Test_IndianaAndNewYorkIgnoreCase');
   station := NoStation;
   station.InHostState := True;
   station := WithHostAreaTable(station);
   CheckFalse(CountsDomestic(INQSOPARTY, station, 'dx'), 'Indiana: dx earns no multiplier');
   CheckFalse(CountsDomestic(INQSOPARTY, station, 'DX'), 'Indiana: DX earns no multiplier');
   CheckTrue(CountsDomestic(INQSOPARTY, station, 'ADA'), 'Indiana: a county counts');
   CheckFalse(CountsDomestic(NYQP, station, 'Dx'), 'New York: Dx earns no multiplier');
   CheckTrue(CountsDomestic(NYQP, station, 'ALB'), 'New York: a county counts');
end;

(* Q84: IN7QPNE's in-area file says `dx = dx`. An Indiana entrant's DX QSO is
   judged by Indiana (the entrant's party), whose rule now matches it. *)
procedure TContestRulings2026OctTests.Test_IN7QPNEIndianaJudgedDXEarnsNoMultiplier;
var
   station: TStationContext;
begin
   BeginTest('Test_IN7QPNEIndianaJudgedDXEarnsNoMultiplier');
   station := NoStation;
   station.MyState := 'INADA';
   station.InHostState := True;
   station := WithHostAreaTable(station);
   CheckFalse(CountsDomestic(IN7QPNE, station, 'dx'),
              'IN7QPNE: an Indiana entrant''s dx earns no multiplier');
   CheckTrue(CountsDomestic(IN7QPNE, station, 'INALL'),
             'IN7QPNE: an Indiana county still counts');
end;

(* Q71: every BandType, both ways, and a 80 m QSO scores 0. *)
procedure TContestRulings2026OctTests.Test_The160MetreContestsCredit160Only;
const
   CONTESTS: array[0..3] of ContestType = (RSGB18, ARRL160, CQ160CW, CQ160SSB);
var
   i: integer;
   b: BandType;
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('Test_The160MetreContestsCredit160Only');
   for i := Low(CONTESTS) to High(CONTESTS) do
      begin
      contestObject := Make(CONTESTS[i], USStation);
      try
         for b := Low(BandType) to High(BandType) do
            begin
            CheckEquals(Ord(b = Band160), Ord(ContestCreditsBand(contestObject, b)),
                        string(ContestTypeSA[CONTESTS[i]]) + ' band ' + IntToStr(Ord(b)));
            end;
         qso := Default(ContestExchange);
         qso.Band := Band80;
         qso.Mode := CW;
         qso.QTH.CountryID := 'DL';
         qso.QTH.Continent := Europe;
         qso.QSOPoints := 99;
         contestObject.ScoreQSO(qso);
         CheckEquals(0, qso.QSOPoints,
                     string(ContestTypeSA[CONTESTS[i]]) + ': an 80 m QSO scores 0');
      finally
         contestObject.Free;
      end;
      end;
end;

procedure TContestRulings2026OctTests.Test_UA4WPromptIsTheTranslatedString;
var
   contestObject: TContestBase;
   prompts: TNewContestPrompts;
begin
   BeginTest('Test_UA4WPromptIsTheTranslatedString');
   contestObject := Make(UA4WCHAMPIONSHIP);
   prompts := TNewContestPrompts.Create;
   try
      contestObject.DescribeNewContestPrompts(prompts);
      CheckEquals(1, prompts.ChoiceCount, 'UA4W: one prompt on choosing');
      if prompts.ChoiceCount = 1 then
         begin
         CheckEquals(TC_ENTERYOURRDAIDORGRID, prompts.Choice(0).Text,
                     'UA4W: the prompt is TC_ENTERYOURRDAIDORGRID');
         CheckTrue(prompts.Choice(0).Field = ncfMyQTH, 'UA4W: in MY QTH');
         end;
      CheckEquals(0, prompts.InsideCount, 'UA4W: nothing on ticking a box');
   finally
      prompts.Free;
      contestObject.Free;
   end;
end;

(* Q85: digital 4; CW and phone unchanged; FM is phone; off-band still 0. *)
procedure TContestRulings2026OctTests.Test_SevenQPScoresDigitalFour;

   function SevenQPPoints(aBand: BandType; aMode: ModeType): integer;
   var
      contestObject: TContestBase;
      station: TStationContext;
      qso: ContestExchange;
   begin
      station := NoStation;
      station.MyState := 'AZMAR';
      station.InHostState := True;
      station := WithHostAreaTable(station);
      contestObject := Make(SEVENQP, station);
      try
         qso := Default(ContestExchange);
         qso.Band := aBand;
         qso.Mode := aMode;
         qso.QTHString := 'AZPMA';
         qso.DomesticQTH := 'AZPMA';
         contestObject.ScoreQSO(qso);
         Result := qso.QSOPoints;
      finally
         contestObject.Free;
      end;
   end;

begin
   BeginTest('Test_SevenQPScoresDigitalFour');
   CheckEquals(4, SevenQPPoints(Band20, Digital), '7QP: digital 4');
   CheckEquals(3, SevenQPPoints(Band20, CW), '7QP: CW 3');
   CheckEquals(2, SevenQPPoints(Band20, Phone), '7QP: phone 2');
   CheckEquals(2, SevenQPPoints(Band10, FM), '7QP: FM is phone, 2');
   CheckEquals(0, SevenQPPoints(Band30, Digital), '7QP: digital on 30 m is off-band, 0');
end;

(* Q104: each of the fourteen states, and a county key of each party, is
   refused with the party's own contest named -- 7QP for every 7th-area
   state, never a single state's party. *)
procedure TContestRulings2026OctTests.Test_IN7QPNERefusesAnInAreaStation;

   procedure CheckRefused(aContestObject: TContestBase; const aValue: string;
                          aParty: ContestType);
   var
      party: TContestBase;
      expected: string;
   begin
      party := Make(aParty);
      try
         expected := Format(SNewContestIN7QPNEInsideAParty,
                            [UpperCase(Trim(aValue)), party.DisplayName]);
      finally
         party.Free;
      end;
      CheckEquals(expected, aContestObject.NewContestValueRefusal(ncfMyState, aValue),
                  'IN7QPNE refuses MY STATE ' + aValue);
   end;

var
   contestObject: TContestBase;
begin
   BeginTest('Test_IN7QPNERefusesAnInAreaStation');
   contestObject := Make(IN7QPNE);
   try
      CheckRefused(contestObject, 'IN', INQSOPARTY);
      CheckRefused(contestObject, 'in ', INQSOPARTY);
      CheckRefused(contestObject, 'AZ', SEVENQP);
      CheckRefused(contestObject, 'ID', SEVENQP);
      CheckRefused(contestObject, 'MT', SEVENQP);
      CheckRefused(contestObject, 'NV', SEVENQP);
      CheckRefused(contestObject, 'OR', SEVENQP);
      CheckRefused(contestObject, 'UT', SEVENQP);
      CheckRefused(contestObject, 'WA', SEVENQP);
      CheckRefused(contestObject, 'WY', SEVENQP);
      CheckRefused(contestObject, 'CT', NEWENGLANDQSO);
      CheckRefused(contestObject, 'MA', NEWENGLANDQSO);
      CheckRefused(contestObject, 'ME', NEWENGLANDQSO);
      CheckRefused(contestObject, 'NH', NEWENGLANDQSO);
      CheckRefused(contestObject, 'RI', NEWENGLANDQSO);
      CheckRefused(contestObject, 'VT', NEWENGLANDQSO);
      CheckRefused(contestObject, 'DE', DELAWAREQSOPARTY);
      (* The prompt (Q87) still invites an in-area station's county. *)
      CheckRefused(contestObject, 'INADA', INQSOPARTY);
      CheckRefused(contestObject, 'Azaph', SEVENQP);
      CheckRefused(contestObject, 'MEAnd', NEWENGLANDQSO);
      CheckRefused(contestObject, 'NDE', DELAWAREQSOPARTY);
   finally
      contestObject.Free;
   end;
end;

procedure TContestRulings2026OctTests.Test_IN7QPNEAcceptsAnOutOfAreaStation;
var
   contestObject: TContestBase;
   other: TContestBase;
begin
   BeginTest('Test_IN7QPNEAcceptsAnOutOfAreaStation');
   contestObject := Make(IN7QPNE);
   try
      CheckEquals('', contestObject.NewContestValueRefusal(ncfMyState, 'KS'), 'KS accepted');
      CheckEquals('', contestObject.NewContestValueRefusal(ncfMyState, 'NY'), 'NY accepted');
      CheckEquals('', contestObject.NewContestValueRefusal(ncfMyState, 'CA'), 'CA accepted');
      CheckEquals('', contestObject.NewContestValueRefusal(ncfMyState, 'ON'), 'ON accepted');
      CheckEquals('', contestObject.NewContestValueRefusal(ncfMyState, 'DX'), 'DX accepted');
      CheckEquals('', contestObject.NewContestValueRefusal(ncfMyState, ''), 'empty accepted');
      (* Only MY STATE is asked about. *)
      CheckEquals('', contestObject.NewContestValueRefusal(ncfMyQTH, 'IN'), 'MY QTH IN accepted');
   finally
      contestObject.Free;
   end;

   (* THE BASE REFUSES NOTHING -- every other contest, as before Q104. *)
   other := Make(INQSOPARTY);
   try
      CheckEquals('', other.NewContestValueRefusal(ncfMyState, 'IN'),
                  'Indiana itself accepts IN');
   finally
      other.Free;
   end;
end;

procedure TContestRulings2026OctTests.RunAllTests;
begin
   Test_EUDXNonEUEntrantScoresByResolvedRegion;
   Test_EUDXEUEntrantScoresByResolvedRegion;
   Test_IRTSScoresByResolvedCounty;
   Test_DomesticMultiplierIsDXIgnoresCase;
   Test_BritishColumbiaDXEarnsNoMultiplier;
   Test_IndianaAndNewYorkIgnoreCase;
   Test_IN7QPNEIndianaJudgedDXEarnsNoMultiplier;
   Test_The160MetreContestsCredit160Only;
   Test_UA4WPromptIsTheTranslatedString;
   Test_SevenQPScoresDigitalFour;
   Test_IN7QPNERefusesAnInAreaStation;
   Test_IN7QPNEAcceptsAnOutOfAreaStation;
end;

end.
