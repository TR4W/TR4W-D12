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

(* EVERY CONTEST STATES ITS RULES -- Q108 S1, 2026-10-16
  (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u).

  A CONTEST RULE HAS NO INHERITED DEFAULT (NY4I): each contest states its
  Cabrillo columns, its STX_STRING, its parse format, its received-exchange
  fields, its set-up flags and its scoring. The base's answer for each is
  neutral -- the error marker, a raise, nothing parsed, nothing marked, the
  empty set, no points -- so a class that FORGETS one is not a compile error
  and not a crash: it is a legal-looking blank (CLAUDE.md note 9).

  THE PIN TABLES CANNOT SEE A NEW CONTEST. uTestCabrilloColumns,
  uTestADIFSentExchange, uTestExchangeParse and uTestExchangeFields freeze
  what each LEGACY contest answers, keyed by ContestType; a contest that
  registers by its string id (Q108 S3) has no member and no row there. So
  this suite asks every REGISTERED contest the one question that needs no
  expected value: does something above TContestBase state the rule -- its
  class or its family base? (uTestRegisteredContests.ClassOverridesTheBase,
  the comparison Test_EveryClassStatesItsIdentity made first.)

  THERE ARE NO EXCEPTIONS, MEASURED. When this suite was written every one
  of the registered contests stated all seven rules (a contest whose
  Cabrillo columns print the error marker calls uCabrilloExchange's
  CabrilloSentNotHandled / CabrilloReceivedNotHandled by name, which is a
  statement). So a contest that answers with the base's code for any of
  them fails here, by name -- a new contest above all. *)
unit uTestContestStatesItsRules;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework, uTestRegisteredContests;

type
   TContestStatesItsRulesTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure CheckEveryContestStates(const aRule: string; aCodeOf: TContestMethodCode);
      procedure Test_EveryContestStatesItsCabrilloSentColumn;
      procedure Test_EveryContestStatesItsCabrilloReceivedColumn;
      procedure Test_EveryContestStatesItsADIFSentExchange;
      procedure Test_EveryContestStatesItsParseFormat;
      procedure Test_EveryContestStatesItsReceivedFields;
      procedure Test_EveryContestStatesItsFlags;
      procedure Test_EveryContestStatesItsScoring;
      procedure Test_TheCheckSeesTheBase;
      procedure CheckBandsOrModesRatchet(const aRule: string;
                                         aCodeOf: TContestMethodCode;
                                         const aNotYet: array of string;
                                         const aSetName: string);
      procedure Test_EveryContestStatesItsBandsAndModes;
      procedure Test_BandsAndModesAreAnIdentityFact;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uContestStateQSOPartyBase,
   uTestContestObjects;

const
   (* THE BANDS AND MODES RATCHET -- Q98 S1 (docs/CONTEST_OWNERSHIP_DESIGN.md
      8.2v). NY4I: "I would feel better if contest classes just explicitly
      listed the bands they allow" -- every contest states UsesBand AND
      UsesMode, with no inherited default. These are the contests that have
      not yet, by id, LITERALLY: Test_EveryContestStatesItsBandsAndModes fails
      a contest outside its set that states nothing (so a NEW contest, in
      neither set, states both from its first commit) AND a contest inside it
      that states its list (a stale entry -- take it out in the commit that
      states it). Each later Q98 stage removes its ids; the last deletes both
      sets. At S1 (2026-10-22) the bands were stated by the eleven contests
      that already had them and the CQ WW three; the modes by the CQ WW three
      alone. Generated once from the frozen contest matrix's ids; edited by
      hand from then on, only ever DOWN. *)
   BANDS_NOT_YET_STATED: array[0..167] of string = (
      'ALL JA', 'ALL-ASIAN-DX-CW', 'ALL-ASIAN-DX-SSB', 'ALRS-UA1DZ-CUP',
      'AP-SPRINT', 'ARCI', 'ARI-DX', 'ARIZONA QSO PARTY',
      'ARKTIKA-SPRING', 'ARRL-10', 'ARRL-DIGI', 'ARRL-DX-CW',
      'ARRL-DX-SSB', 'ARRL-FD', 'ARRL-RTTY', 'ARRL-SS-CW',
      'ARRL-SS-SSB', 'ARRL-VHF-JAN', 'ARRL-VHF-JUN', 'ARRL-VHF-SEP',
      'AS-CHAMP', 'BALTIC', 'BATAVIA-FT8',
      'BLACK SEA CUP', 'BWQP', 'CANADA DAY',
      'CANADA WINTER', 'CIS', 'COLORADO QSO PARTY', 'COUNTY HUNTER',
      'CQ-M', 'CQ-VHF', 'CQ-WPX-CW', 'CQ-WPX-RTTY',
      'CQ-WPX-SSB', 'CQIR', 'CQMM', 'CROATIAN',
      'CWOPEN', 'CWOPS', 'DARC-10M', 'DARC-WAEDC-CW',
      'DARC-WAEDC-SSB', 'DARC-XMAS', 'EU-SPRINT-AUTUMN-CW', 'EU-SPRINT-AUTUMN-SSB',
      'EU-SPRINT-SPRING-CW', 'EU-SPRINT-SPRING-SSB', 'EUDX', 'EUROPEAN HFC',
      'EUROPEAN VHF', 'FISTS', 'FLORIDA QSO PARTY', 'FOC MARATHON',
      'GACW-WWSA-CW', 'GAGARIN-CUP', 'GENERAL QSO', 'GRID LOC',
      'HA DX', 'HELVETIA', 'HF-TESLA', 'IARU-HF',
      'INTERNET SPRINT', 'IRTS', 'JA LONG PREFECT', 'JIDX-CW',
      'JIDX-SSB', 'KCJ', 'KIDS DAY', 'KING-OF-SPAIN-CW',
      'KING-OF-SPAIN-SSB', 'KVP', 'LABRE', 'LOCUST QSO PARTY',
      'LZ DX', 'MAKROTHEN-RTTY', 'MARCONI MEMORIAL', 'MICHIGAN QSO PARTY',
      'MINI40', 'MINI80', 'MINITEST', 'MINNESOTA QSO PARTY',
      'MONGOLIAN DX', 'MST', 'MWC',
      'NA-SPRINT-CW', 'NA-SPRINT-RTTY', 'NAQP-CW', 'NAQP-RTTY',
      'NAQP-SSB', 'NC QSO PARTY', 'NCCC-SPRINT', 'NRAU-BALTIC-CW',
      'NRAU-BALTIC-SSB', 'NY-QSO-PARTY', 'NZ FIELD DAY', 'OCEANIA-DX-CW',
      'OCEANIA-DX-SSB', 'OHIO QSO PARTY', 'OK-OM DX CW', 'OK-OM DX SSB',
      'OZCHR', 'OZCHR-TEAMS', 'OZHCR-VHF', 'PA QSO PARTY',
      'PACC', 'PCC', 'POTA', 'QCWA',
      'QCWA GOLDEN', 'R4W-CHAMP', 'R9W-UW9WK-MEMORIAL', 'RADIO-MEMORY',
      'RADIO-ONY', 'RAEM', 'RDAC',
      'RDXC', 'REF-CW', 'REF-SSB', 'REGION 1 FIELD DAY',
      'REGION 1 FIELD DAY-RCC-CW', 'REGION 1 FIELD DAY-RCC-SSB', 'RF-CHAMP-CW', 'RF-CHAMP-SSB',
      'RF-CUP-CW', 'RF-CUP-DIG', 'RF-CUP-SSB', 'RF-VHF-FD',
      'RSGB-IOTA', 'RSGB-ROPOCO-CW', 'RSGB-ROPOCO-SSB',
      'RU3AX MEMORIAL', 'SA-SPRINT', 'SAC-CW', 'SAC-SSB',
      'SALMON RUN', 'SOUTH AMERICAN WW', 'SP DX', 'SRR-JR',
      'SSB-SPRINT', 'SST', 'STEW-PERRY', 'TEN TEN',
      'TENNESSEE QSO PARTY', 'TEXAS QSO PARTY', 'TOEC', 'UBA-DX-CW',
      'UBA-DX-SSB', 'UCG', 'UKEI', 'UKRAINE CHAMPIONSHIP',
      'UKRAINIAN', 'UN DX', 'URAL-CUP', 'VAQP',
      'WAG', 'WINTER FIELD DAY', 'WISCONSIN QSO PARTY', 'WRTC',
      'WW PMC', 'WWDIGI', 'WWIH', 'WWL',
      'XMAS', 'YBDX', 'YO-DX-HF', 'YOTA',
      'YUDX'
      );

   MODES_NOT_YET_STATED: array[0..177] of string = (
      '7QP', 'ALL JA', 'ALL-ASIAN-DX-CW', 'ALL-ASIAN-DX-SSB',
      'ALRS-UA1DZ-CUP', 'AP-SPRINT', 'ARCI', 'ARI-DX',
      'ARIZONA QSO PARTY', 'ARKTIKA-SPRING', 'ARRL-10', 'ARRL-160',
      'ARRL-DIGI', 'ARRL-DX-CW', 'ARRL-DX-SSB', 'ARRL-FD',
      'ARRL-RTTY', 'ARRL-SS-CW', 'ARRL-SS-SSB', 'ARRL-VHF-JAN',
      'ARRL-VHF-JUN', 'ARRL-VHF-SEP', 'AS-CHAMP', 'BALTIC',
      'BATAVIA-FT8', 'BLACK SEA CUP', 'BWQP',
      'CANADA DAY', 'CANADA WINTER', 'CIS',
      'COLORADO QSO PARTY', 'COUNTY HUNTER', 'CQ-160-CW', 'CQ-160-SSB',
      'CQ-M', 'CQ-VHF', 'CQ-WPX-CW', 'CQ-WPX-RTTY',
      'CQ-WPX-SSB', 'CQIR', 'CQMM', 'CROATIAN',
      'CWOPEN', 'CWOPS', 'DARC-10M', 'DARC-WAEDC-CW',
      'DARC-WAEDC-SSB', 'DARC-XMAS', 'DELAWARE QSO PARTY', 'EU-SPRINT-AUTUMN-CW',
      'EU-SPRINT-AUTUMN-SSB', 'EU-SPRINT-SPRING-CW', 'EU-SPRINT-SPRING-SSB', 'EUDX',
      'EUROPEAN HFC', 'EUROPEAN VHF', 'FISTS', 'FLORIDA QSO PARTY',
      'FOC MARATHON', 'GACW-WWSA-CW', 'GAGARIN-CUP', 'GENERAL QSO',
      'GRID LOC', 'HA DX', 'HELVETIA', 'HF-TESLA',
      'IARU-HF', 'IDAHO QSO PARTY', 'IN QSO PARTY', 'IN7QPNE',
      'INTERNET SPRINT', 'IRTS', 'JA LONG PREFECT', 'JIDX-CW',
      'JIDX-SSB', 'KCJ', 'KIDS DAY', 'KING-OF-SPAIN-CW',
      'KING-OF-SPAIN-SSB', 'KVP', 'LABRE', 'LOCUST QSO PARTY',
      'LZ DX', 'MAKROTHEN-RTTY', 'MARCONI MEMORIAL', 'MICHIGAN QSO PARTY',
      'MINI40', 'MINI80', 'MINITEST', 'MINNESOTA QSO PARTY',
      'MONGOLIAN DX', 'MST', 'MWC',
      'NA-SPRINT-CW', 'NA-SPRINT-RTTY', 'NAQP-CW', 'NAQP-RTTY',
      'NAQP-SSB', 'NC QSO PARTY', 'NCCC-SPRINT', 'NEWEQP', 'NRAU-BALTIC-CW', 'NRAU-BALTIC-SSB', 'NY-QSO-PARTY',
      'NZ FIELD DAY', 'OCEANIA-DX-CW', 'OCEANIA-DX-SSB', 'OHIO QSO PARTY',
      'OK-OM DX CW', 'OK-OM DX SSB', 'OZCHR', 'OZCHR-TEAMS',
      'OZHCR-VHF', 'PA QSO PARTY', 'PACC', 'PCC',
      'POTA', 'QCWA', 'QCWA GOLDEN', 'R4W-CHAMP',
      'R9W-UW9WK-MEMORIAL', 'RADIO-MEMORY', 'RADIO-ONY',
      'RAEM', 'RDAC', 'RDXC', 'REF-CW',
      'REF-SSB', 'REGION 1 FIELD DAY', 'REGION 1 FIELD DAY-RCC-CW', 'REGION 1 FIELD DAY-RCC-SSB',
      'RF-CHAMP-CW', 'RF-CHAMP-SSB', 'RF-CUP-CW', 'RF-CUP-DIG',
      'RF-CUP-SSB', 'RF-VHF-FD', 'RSGB-160', 'RSGB-IOTA',
      'RSGB-ROPOCO-CW', 'RSGB-ROPOCO-SSB', 'RU3AX MEMORIAL',
      'SA-SPRINT', 'SAC-CW', 'SAC-SSB', 'SALMON RUN',
      'SOUTH AMERICAN WW', 'SP DX', 'SRR-JR', 'SSB-SPRINT',
      'SST', 'STEW-PERRY', 'TEN TEN', 'TENNESSEE QSO PARTY',
      'TEXAS QSO PARTY', 'TOEC', 'UBA-DX-CW', 'UBA-DX-SSB',
      'UCG', 'UKEI', 'UKRAINE CHAMPIONSHIP', 'UKRAINIAN',
      'UN DX', 'URAL-CUP', 'VAQP', 'WAG',
      'WINTER FIELD DAY', 'WISCONSIN QSO PARTY', 'WRTC', 'WW PMC',
      'WWDIGI', 'WWIH', 'WWL', 'XMAS',
      'YBDX', 'YO-DX-HF', 'YOTA', 'YUDX'
      );

type
   (* THE PROTECTED RULES, REACHED THE WAY A DESCENDANT REACHES THEM. *)
   TRuleCracker = class(TContestBase);

   TCabrilloColumnGetter = function(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange;
                                    const aCtx: TCabrilloQSOContext): string of object;
   TADIFSentGetter = function(const aMy: TMyStationExchange;
                              const aQso: ContestExchange): string of object;
   TParseFormatter = function(const aText: string; aParsers: TExchangeParsers;
                              var aExch: ContestExchange): boolean of object;
   TFieldsGetter = function: ExchangeInformationRecord of object;
   TFlagsGetter = function: TContestFlags of object;
   TPointsScorer = procedure(var aQso: ContestExchange) of object;
   TBandRule = function(aBand: BandType): boolean of object;
   TModeRule = function(aMode: ModeType; aExtMode: ExtendedModeType): boolean of object;

function CabrilloSentCode(aObj: TContestBase): CodePointer;
var
   m: TCabrilloColumnGetter;
begin
   m := TRuleCracker(aObj).GetCabrilloSentExchange;
   Result := TMethod(m).Code;
end;

function CabrilloReceivedCode(aObj: TContestBase): CodePointer;
var
   m: TCabrilloColumnGetter;
begin
   m := TRuleCracker(aObj).GetCabrilloReceivedExchange;
   Result := TMethod(m).Code;
end;

function ADIFSentCode(aObj: TContestBase): CodePointer;
var
   m: TADIFSentGetter;
begin
   m := TRuleCracker(aObj).GetADIFSentExchange;
   Result := TMethod(m).Code;
end;

function ParseFormatCode(aObj: TContestBase): CodePointer;
var
   m: TParseFormatter;
begin
   m := TRuleCracker(aObj).ParseReceivedExchangeFormat;
   Result := TMethod(m).Code;
end;

function ReceivedFieldsCode(aObj: TContestBase): CodePointer;
var
   m: TFieldsGetter;
begin
   m := TRuleCracker(aObj).GetReceivedExchangeFields;
   Result := TMethod(m).Code;
end;

function FlagsCode(aObj: TContestBase): CodePointer;
var
   m: TFlagsGetter;
begin
   m := TRuleCracker(aObj).GetFlags;
   Result := TMethod(m).Code;
end;

function ScoringCode(aObj: TContestBase): CodePointer;
var
   m: TPointsScorer;
begin
   m := TRuleCracker(aObj).CalculateQSOPoints;
   Result := TMethod(m).Code;
end;

function UsesBandCode(aObj: TContestBase): CodePointer;
var
   m: TBandRule;
begin
   m := aObj.UsesBand;
   Result := TMethod(m).Code;
end;

function UsesModeCode(aObj: TContestBase): CodePointer;
var
   m: TModeRule;
begin
   m := aObj.UsesMode;
   Result := TMethod(m).Code;
end;

function IdIsIn(const aId: string; const aSet: array of string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(aSet) to High(aSet) do
      begin
      if aSet[i] = aId then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(* ------------------------------------------------------------------------ *)

procedure TContestStatesItsRulesTests.CheckEveryContestStates(const aRule: string;
                                                             aCodeOf: TContestMethodCode);
var
   contests: TContestIdentityList;
   k: integer;
begin
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      CheckTrue(ClassOverridesTheBase(contests[k], aCodeOf),
                ContestWho(contests[k]) + ' states its ' + aRule +
                ' (on its class or its family base)');
      end;
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsCabrilloSentColumn;
begin
   BeginTest('Test_EveryContestStatesItsCabrilloSentColumn');
   CheckEveryContestStates('Cabrillo sent column', CabrilloSentCode);
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsCabrilloReceivedColumn;
begin
   BeginTest('Test_EveryContestStatesItsCabrilloReceivedColumn');
   CheckEveryContestStates('Cabrillo received column', CabrilloReceivedCode);
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsADIFSentExchange;
begin
   BeginTest('Test_EveryContestStatesItsADIFSentExchange');
   CheckEveryContestStates('ADIF STX_STRING', ADIFSentCode);
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsParseFormat;
begin
   BeginTest('Test_EveryContestStatesItsParseFormat');
   CheckEveryContestStates('exchange parse format', ParseFormatCode);
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsReceivedFields;
begin
   BeginTest('Test_EveryContestStatesItsReceivedFields');
   CheckEveryContestStates('received-exchange fields', ReceivedFieldsCode);
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsFlags;
begin
   BeginTest('Test_EveryContestStatesItsFlags');
   CheckEveryContestStates('set-up flags', FlagsCode);
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsScoring;
begin
   BeginTest('Test_EveryContestStatesItsScoring');
   CheckEveryContestStates('scoring (CalculateQSOPoints)', ScoringCode);
end;

(* THE CHECK CAN FAIL -- a negative control: a plain TContestBase states
   none of these, and is seen not to. *)
procedure TContestStatesItsRulesTests.Test_TheCheckSeesTheBase;
var
   base: TContestBase;
begin
   BeginTest('Test_TheCheckSeesTheBase');
   base := TContestBase.Create(NoContest);
   try
      CheckFalse(ClassOverridesTheBase(base, CabrilloSentCode), 'the base states no Cabrillo column');
      CheckFalse(ClassOverridesTheBase(base, ScoringCode), 'the base states no scoring');
   finally
      base.Free;
      end;
end;

(* ONE HALF OF THE Q98 RATCHET -- see BANDS_NOT_YET_STATED. *)
procedure TContestStatesItsRulesTests.CheckBandsOrModesRatchet(const aRule: string;
                                                              aCodeOf: TContestMethodCode;
                                                              const aNotYet: array of string;
                                                              const aSetName: string);
var
   contests: TContestIdentityList;
   k: integer;
   i: integer;
   id: string;
   states: boolean;
   found: boolean;
begin
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      id := ContestId(HandleOf(contests[k]));
      states := ClassOverridesTheBase(contests[k], aCodeOf);
      if IdIsIn(id, aNotYet) then
         begin
         CheckFalse(states, ContestWho(contests[k]) + ' states its ' + aRule +
                    ' -- take it out of ' + aSetName);
         end
      else
         begin
         CheckTrue(states, ContestWho(contests[k]) + ' states its ' + aRule +
                   ' (Q98: no inherited default -- a new contest states it from its first commit)');
         end;

      (* A STATE QSO PARTY STATES ITS OWN: TContestStateQSOPartyBase never
         states a list (design 8.2v -- parties differ, and a list there
         would be the default NY4I ruled out). *)
      if (contests[k] is TContestStateQSOPartyBase) and states then
         begin
         CheckTrue(ClassStatesItself(contests[k], aCodeOf),
                   ContestWho(contests[k]) + ' states its ' + aRule +
                   ' on its own class, never on the state-party base');
         end;
      end;

   (* NO STALE ENTRY: every id in the set is a registered contest. *)
   for i := Low(aNotYet) to High(aNotYet) do
      begin
      found := False;
      for k := 0 to High(contests) do
         begin
         if ContestId(HandleOf(contests[k])) = aNotYet[i] then
            begin
            found := True;
            Break;
            end;
         end;
      CheckTrue(found, aSetName + ' names ' + aNotYet[i] + ', which is no registered contest');
      end;
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsBandsAndModes;
var
   base: TContestBase;
   cqww: TContestBase;
begin
   BeginTest('Test_EveryContestStatesItsBandsAndModes');
   CheckBandsOrModesRatchet('bands (UsesBand)', UsesBandCode,
                            BANDS_NOT_YET_STATED, 'BANDS_NOT_YET_STATED');
   CheckBandsOrModesRatchet('modes (UsesMode)', UsesModeCode,
                            MODES_NOT_YET_STATED, 'MODES_NOT_YET_STATED');

   (* THE CHECK CAN FAIL BOTH WAYS: the base states neither; CQ WW SSB
      states both, its bands on its family base. *)
   base := TContestBase.Create(NoContest);
   try
      CheckFalse(ClassOverridesTheBase(base, UsesBandCode), 'the base states no bands');
      CheckFalse(ClassOverridesTheBase(base, UsesModeCode), 'the base states no modes');
   finally
      base.Free;
      end;
   cqww := ContestIdentity(ContestHandleOf(CQWWSSB));
   CheckTrue(ClassOverridesTheBase(cqww, UsesBandCode), 'CQ WW SSB states its bands');
   CheckFalse(ClassStatesItself(cqww, UsesBandCode), 'CQ WW SSB''s bands are its family base''s');
   CheckTrue(ClassStatesItself(cqww, UsesModeCode), 'CQ WW SSB states its own mode');
end;

(* A CONTEST'S BANDS AND MODES ARE AN IDENTITY FACT, NEVER THE ENTRANT'S
   (design 8.2v): every reader of an automatic X-QSO asks the station-less
   identity object (LoggedQSOIsXQSO), so a contest object holding a station
   must give the same answer for every band, mode and submode -- at a US
   station in and out of a host area, a European one and a Japanese one. A
   contest whose sponsor's bands depend on the entrant is a question for
   NY4I, not an override. *)
procedure TContestStatesItsRulesTests.Test_BandsAndModesAreAnIdentityFact;
var
   contests: TContestIdentityList;
   stations: array[0..3] of TStationContext;
   k: integer;
   s: integer;
   obj: TContestBase;
   b: BandType;
   m: ModeType;
   e: ExtendedModeType;
   same: boolean;
begin
   BeginTest('Test_BandsAndModesAreAnIdentityFact');

   stations[0] := NoStation;
   stations[0].MyCall := 'K0AAA';
   stations[0].MyCountry := 'K';
   stations[0].MyContinent := NorthAmerica;
   stations[0].MyState := 'KS';
   stations[1] := stations[0];
   stations[1].InHostState := True;
   stations[2] := NoStation;
   stations[2].MyCall := 'DL1AAA';
   stations[2].MyCountry := 'DL';
   stations[2].MyContinent := Europe;
   stations[3] := NoStation;
   stations[3].MyCall := 'JA1AAA';
   stations[3].MyCountry := 'JA';
   stations[3].MyContinent := Asia;

   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      for s := Low(stations) to High(stations) do
         begin
         obj := NewContestLike(contests[k], stations[s]);
         try
            same := True;
            for b := Low(BandType) to High(BandType) do
               begin
               if obj.UsesBand(b) <> contests[k].UsesBand(b) then
                  begin
                  same := False;
                  end;
               end;
            for m := Low(ModeType) to High(ModeType) do
               begin
               for e := Low(ExtendedModeType) to High(ExtendedModeType) do
                  begin
                  if obj.UsesMode(m, e) <> contests[k].UsesMode(m, e) then
                     begin
                     same := False;
                     end;
                  end;
               end;
            CheckTrue(same, ContestWho(contests[k]) +
                      '''s bands and modes do not depend on the station (' +
                      string(stations[s].MyCall) + ')');
         finally
            obj.Free;
            end;
         end;
      end;
end;

procedure TContestStatesItsRulesTests.RunAllTests;
begin
   Test_EveryContestStatesItsBandsAndModes;
   Test_BandsAndModesAreAnIdentityFact;
   Test_EveryContestStatesItsCabrilloSentColumn;
   Test_EveryContestStatesItsCabrilloReceivedColumn;
   Test_EveryContestStatesItsADIFSentExchange;
   Test_EveryContestStatesItsParseFormat;
   Test_EveryContestStatesItsReceivedFields;
   Test_EveryContestStatesItsFlags;
   Test_EveryContestStatesItsScoring;
   Test_TheCheckSeesTheBase;
end;

end.
