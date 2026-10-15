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

(* THE EXCHANGE RULES EVERY CONTEST STATES, AT STATIONS THE CONTEST MATRIX
  DOES NOT RUN -- M11 S7, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S7).

  WHY IT EXISTS. S7 moves the RULES that the engine decided by comparing the
  session's exchange SHAPE (ContestSession.Exchange = X) into the classes:
  - is a call's /suffix a rover's county? (MainUnit's two rover routines --
    the RSTDomesticQTH, RSTQTH and RSTDomesticOrDXQTH shapes, 25 contests);
  - does an S&P entry carry several QTHs? (MainUnit.ReturnInSAPOpMode -- the
    RSTDomesticQTH and RSTQTH shapes, 21 contests);
  - may the exchange be blank? (ParametersOkay and LOGSTUFF.ProcessExchange
    -- RSTNameAndQTH and RSTAndPOTAPark: BWQP, General QSO, POTA);
  - does the zone exchange carry the sent state? (FCONTEST's zone messages --
    RSTZoneAndPossibleDomesticQTH: CQ WW RTTY);
  - is a typed park looked up? (MainUnit.ExchangeWindowChange --
    RSTAndPOTAPark: POTA, whose OffersParkTools already said so);
  - does the final score ignore the multipliers? (TContestBase.CombineScore
    -- the FISTS exchange: FISTS).
  Most of those sites are UI paths no oracle runs, and the matrix's stations
  do not reach the station branches (an entrant inside a party's host state,
  a Dutch station in the PACC, a KH6 station in ARRL 160 and the ARRL DX).

  HOW THE LITERALS WERE MADE. Laid out by hand from each class's trait and
  DescribeSession, and RUN GREEN AGAINST THE OLD CODE before anything moved:
  the program's answer was then the old compare, frozen here (LegacyAnswer),
  on the session shape uTestContestKindPin.Kinds resolves -- the trait, and
  DescribeSession over it -- exactly what the engine compared. Then the move,
  and the same tables green against the classes.

  THE CROSS-CHECK STAYS UNTIL S9 DELETES THE SHAPE: every ContestType at
  every roster station, the class's answer against the frozen compare.

  NEVER REGENERATE IT TO CLEAR A FAILURE -- the uTestContestKindPin rule. A
  failure means a contest's exchange rule changed; Q94 (with Q90) is open on
  which contests really have /county rovers, and until NY4I answers it the
  rover sets are TODAY's, exactly. *)
unit uTestExchangeRules;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TExchangeRuleTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EveryContestStatesItsPinnedExchangeRules;
      procedure Test_ExchangeRulesAgreeWithTheSessionShape;
      procedure Test_FISTSScoresItsPointsAlone;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uTestContestKindPin;

type
   (* The entrants. us, ve and dx are the matrix's (dx is German); host is a
      Massachusetts station inside its party's host state (and in New
      England); PA a Dutch station, the PACC's own; KH6 a station in an ARRL
      section country that is neither the USA nor Canada -- where ARRL 160
      and the ARRL DX part company. *)
   TPinStation = (psUS, psVE, psDX, psHost, psPA, psKH6);

   (* The five yes/no rules S7 moved. The FISTS score has its own test. *)
   TExchangeRule = (erRoverCounty, erSeveralQTHs, erBlankExchange,
                    erStateAfterZone, erParkLookup);

   TStationRow = record
      Call: string;
      Country: string;
      Continent: ContinentType;
      State: string;
      InHostState: boolean;
   end;

const
   STATIONS: array[TPinStation] of TStationRow = (
      (Call: 'K0AAA';  Country: 'K';   Continent: NorthAmerica; State: 'KS'; InHostState: False),
      (Call: 'VE3AAA'; Country: 'VE';  Continent: NorthAmerica; State: 'ON'; InHostState: False),
      (Call: 'DL1AAA'; Country: 'DL';  Continent: Europe;       State: '';   InHostState: False),
      (Call: 'K1AAA';  Country: 'K';   Continent: NorthAmerica; State: 'MA'; InHostState: True),
      (Call: 'PA3AAA'; Country: 'PA';  Continent: Europe;       State: '';   InHostState: False),
      (Call: 'KH6AAA'; Country: 'KH6'; Continent: Oceania;      State: '';   InHostState: False)
   );

   RULE_NAMES: array[TExchangeRule] of string = (
      'strips a rover county', 'logs several QTHs from one entry',
      'accepts a blank exchange', 'sends the state after the zone',
      'looks a typed park up'
   );

   (* THE CONTESTS THAT ANSWER EACH RULE AT EVERY STATION. The station
      branches are PinnedAnswer's. *)
   ROVER_EVERYWHERE = [
      SEVENQP, ARRL160, ArizonaQsoParty, COUNTYHUNTER, FLORIDAQSOPARTY, LABRE,
      IDAHOQSOPARTY, DELAWAREQSOPARTY, MICHQSOPARTY, MOQSOPARTY, NCQSOPARTY,
      TOEC, WISCONSINQSOPARTY, NYQP, TENNESSEEQSOPARTY, ALRS_UA1DZ_CUP,
      INQSOPARTY, BCQP, IN7QPNE, NEWENGLANDQSO, SALMONRUN, TEXASQSOPARTY];

   SEVERAL_QTHS_EVERYWHERE = [
      COUNTYHUNTER, MICHQSOPARTY, MOQSOPARTY, NCQSOPARTY, TOEC,
      WISCONSINQSOPARTY, NYQP, TENNESSEEQSOPARTY, ALRS_UA1DZ_CUP, INQSOPARTY,
      BCQP, IN7QPNE];

   BLANK_EXCHANGE_EVERYWHERE = [BWQP, GENERALQSO, POTA];

(* THE OLD COMPARE, FROZEN -- each site's test of the session shape, as it
   stood before S7. *)
function LegacyAnswer(aRule: TExchangeRule; aShape: ExchangeType): boolean;
begin
   case aRule of
      erRoverCounty:
         begin
         Result := (aShape = RSTDomesticQTHExchange) or
                   (aShape = RSTQTHExchange)         or
                   (aShape = RSTDomesticOrDXQTHExchange);
         end;
      erSeveralQTHs:
         begin
         Result := (aShape = RSTDomesticQTHExchange) or
                   (aShape = RSTQTHExchange);
         end;
      erBlankExchange:
         begin
         Result := aShape in [RSTNameAndQTHExchange, RSTAndPOTAPark];
         end;
      erStateAfterZone:
         begin
         Result := aShape = RSTZoneAndPossibleDomesticQTHExchange;
         end;
   else
      begin
      Result := aShape = RSTAndPOTAPark;
      end;
   end;
end;

function PinStation(aStation: TPinStation; aContest: ContestType): TStationContext;
begin
   Result := MatrixStation(STATIONS[aStation].Call, STATIONS[aStation].Country,
                           STATIONS[aStation].Continent, STATIONS[aStation].State,
                           'DX', '', STATIONS[aStation].InHostState,
                           SessionContestName(aContest, STATIONS[aStation].InHostState));
end;

function Who(aContest: ContestType; aStation: TPinStation): string;
begin
   Result := string(ContestTypeSA[aContest]) + ' at ' + STATIONS[aStation].Call;
end;

(* A contest object holding the station, as ActiveContest hands it; nil for
   the classless DUMMYCONTEST. The caller frees it. *)
function MakeContest(aContest: ContestType; const aStation: TStationContext): TContestBase;
var
   cls: TContestClass;
begin
   Result := nil;
   cls := ContestClassFor(aContest);
   if cls <> nil then
      begin
      Result := cls.Create(aContest);
      Result.SetStation(aStation);
      end;
end;

(* WHAT THE PROGRAM ANSWERS -- what each engine site asks of the contest:
   MainUnit's rover routines, ReturnInSAPOpMode, ParametersOkay and
   LOGSTUFF.ProcessExchange through the nil-safe Contest... functions;
   FCONTEST and ExchangeWindowChange of the contest's identity, which a
   classless contest's is a plain TContestBase answering False. BEFORE THE
   MOVE it returned the frozen old compare on the session shape Kinds
   resolves -- the run that made the literals. *)
function ProgramAnswer(aRule: TExchangeRule;
                       aContest: ContestType;
                       const aStation: TStationContext): boolean;
var
   obj: TContestBase;
begin
   obj := MakeContest(aContest, aStation);
   try
      case aRule of
         erRoverCounty:
            begin
            Result := ContestStripsRoverCountyFromCall(obj);
            end;
         erSeveralQTHs:
            begin
            Result := ContestLogsSeveralQTHsFromOneEntry(obj);
            end;
         erBlankExchange:
            begin
            Result := ContestAcceptsBlankExchange(obj);
            end;
         erStateAfterZone:
            begin
            Result := (obj <> nil) and obj.SendsStateAfterZone;
            end;
      else
         begin
         Result := (obj <> nil) and obj.OffersParkTools;
         end;
      end;
   finally
      obj.Free;
      end;
end;

(* THE PINNED ANSWER: the sets above, and the station branches -- each the
   test the contest's DescribeSession chooses its shape by. *)
function PinnedAnswer(aRule: TExchangeRule;
                      aContest: ContestType;
                      aStation: TPinStation): boolean;
var
   notWOrVE: boolean;
   notSectionCountry: boolean;
begin
   (* The ARRL DX: a W or VE entrant sends power. *)
   notWOrVE := not (aStation in [psUS, psVE, psHost]);
   (* ARRL 160: an entrant in an ARRL section country sends a section or
      takes DX. *)
   notSectionCountry := aStation in [psDX, psPA];
   case aRule of
      erRoverCounty:
         begin
         Result := (aContest in ROVER_EVERYWHERE)                           or
                   ((aContest in [ARRLDXCW, ARRLDXSSB]) and notWOrVE)       or
                   ((aContest = PACC) and (aStation <> psPA));
         end;
      erSeveralQTHs:
         begin
         Result := (aContest in SEVERAL_QTHS_EVERYWHERE)                    or
                   ((aContest in [SEVENQP, ArizonaQsoParty, SALMONRUN,
                                  TEXASQSOPARTY]) and (aStation <> psHost))  or
                   ((aContest = ARRL160) and notSectionCountry)             or
                   ((aContest in [ARRLDXCW, ARRLDXSSB]) and notWOrVE)       or
                   ((aContest = NEWENGLANDQSO) and (aStation <> psHost))    or
                   ((aContest = PACC) and (aStation <> psPA));
         end;
      erBlankExchange:
         begin
         Result := aContest in BLANK_EXCHANGE_EVERYWHERE;
         end;
      erStateAfterZone:
         begin
         Result := aContest = CQWWRTTY;
         end;
   else
      begin
      Result := aContest = POTA;
      end;
   end;
end;

procedure TExchangeRuleTests.Test_EveryContestStatesItsPinnedExchangeRules;
const
   (* HOW MANY CONTESTS ANSWER EACH RULE AT EACH STATION, counted by hand
      from the sets and branches above. The rover: 22 everywhere, the PACC
      but at PA, the two ARRL DX but at a W or VE. Several QTHs: 12
      everywhere; 7QP, Arizona, the Salmon Run and Texas out of their host
      state; ARRL 160 outside a section country; the ARRL DX at a non-W/VE;
      NEQP outside New England; the PACC but at PA. *)
   COUNTS: array[TExchangeRule, TPinStation] of integer = (
      (23, 23, 25, 23, 24, 25),
      (18, 18, 21, 13, 20, 20),
      (3, 3, 3, 3, 3, 3),
      (1, 1, 1, 1, 1, 1),
      (1, 1, 1, 1, 1, 1)
   );
   (* At some roster station -- plan 2.1's 25 and 21. *)
   COUNT_ANYWHERE: array[TExchangeRule] of integer = (25, 21, 3, 1, 1);
var
   r: TExchangeRule;
   s: TPinStation;
   c: ContestType;
   answer: boolean;
   count: integer;
   anywhere: set of ContestType;
   total: integer;
begin
   BeginTest('Test_EveryContestStatesItsPinnedExchangeRules');
   for r := Low(TExchangeRule) to High(TExchangeRule) do
      begin
      anywhere := [];
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         count := 0;
         for c := Low(ContestType) to High(ContestType) do
            begin
            answer := ProgramAnswer(r, c, PinStation(s, c));
            CheckEquals(BoolToStr(PinnedAnswer(r, c, s), True), BoolToStr(answer, True),
                        Who(c, s) + ' ' + RULE_NAMES[r]);
            if answer then
               begin
               Inc(count);
               Include(anywhere, c);
               end;
            end;
         CheckEquals(COUNTS[r, s], count,
                     'contests that ' + RULE_NAMES[r] + ' at ' + STATIONS[s].Call);
         end;
      total := 0;
      for c := Low(ContestType) to High(ContestType) do
         begin
         if c in anywhere then
            begin
            Inc(total);
            end;
         end;
      CheckEquals(COUNT_ANYWHERE[r], total, 'contests that ' + RULE_NAMES[r] + ' at some station');
      end;
end;

(* THE CROSS-CHECK: the program's answer against the frozen old compare, for
   every ContestType at every roster station. Until S9 deletes the shape. *)
procedure TExchangeRuleTests.Test_ExchangeRulesAgreeWithTheSessionShape;
var
   r: TExchangeRule;
   s: TPinStation;
   c: ContestType;
   station: TStationContext;
   checked: integer;
begin
   BeginTest('Test_ExchangeRulesAgreeWithTheSessionShape');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         for r := Low(TExchangeRule) to High(TExchangeRule) do
            begin
            CheckEquals(BoolToStr(LegacyAnswer(r, Kinds(c, station).Exchange), True),
                        BoolToStr(ProgramAnswer(r, c, station), True),
                        Who(c, s) + ' ' + RULE_NAMES[r] + ' as its session shape did');
            Inc(checked);
            end;
         end;
      end;
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1) *
               (Ord(High(TExchangeRule)) + 1), checked,
               'contest x station x rule answers compared');
end;

(* THE FISTS FINAL SCORE IS ITS POINTS ALONE, multipliers or not -- a D7
   note: "Ugly fix for FISTS because mults don't work". Ten QSO points and one
   QTC point against nine multipliers; CQ WW CW, which multiplies, beside it.
   BEFORE THE MOVE the session shape each resolved (Kinds) was handed in as
   TScoreTotals.SessionExchange, which went with the move: FISTS states its
   own CombineWithMultipliers now. *)
procedure TExchangeRuleTests.Test_FISTSScoresItsPointsAlone;
var
   s: TPinStation;
   t: TScoreTotals;
   obj: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_FISTSScoresItsPointsAlone');
   for s := Low(TPinStation) to High(TPinStation) do
      begin
      FillChar(t, SizeOf(t), 0);
      t.QSOPoints := 10;
      t.QTCPoints := 1;
      t.ScoredBand := AllBands;
      t.SessionCountsMultipliers := True;
      t.Mults[AllBands, Both, rmDX] := 9;

      station := PinStation(s, FISTS);
      obj := ContestClassFor(FISTS).Create(FISTS);
      try
         obj.SetStation(station);
         CheckEquals(11, obj.CombineScore(t), Who(FISTS, s) + ' scores its points alone');
      finally
         obj.Free;
         end;

      station := PinStation(s, CQWWCW);
      obj := ContestClassFor(CQWWCW).Create(CQWWCW);
      try
         obj.SetStation(station);
         CheckEquals(99, obj.CombineScore(t), Who(CQWWCW, s) + ' multiplies');
      finally
         obj.Free;
         end;
      end;
end;

procedure TExchangeRuleTests.RunAllTests;
begin
   Test_EveryContestStatesItsPinnedExchangeRules;
   Test_ExchangeRulesAgreeWithTheSessionShape;
   Test_FISTSScoresItsPointsAlone;
end;

end.
