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

(* EACH CONTEST DESCRIBES THE SESSION IT WANTS -- milestone M7a, 2026-10-02
  (docs/CONTEST_OWNERSHIP_DESIGN.md 4.2).

  A contest is handed a station and a TSessionDefaults, and these tests read
  back what it STATED. Nothing here applies the defaults to the program:
  FCONTEST.ApplySessionDefaults does that, and the contest matrix's set-up
  section -- frozen before the arms moved and byte-identical after -- is what
  pins the applied result for every contest and station variant.

  What is pinned here is what the matrix cannot isolate:

    * THE BASE STATES NOTHING -- for every classless contest, which is what
      lets FoundContest ask every contest and still run a classless arm after.
    * A STATED VALUE IS DISTINGUISHABLE FROM AN UNSTATED ONE, including an
      empty MY STATE (Canada Day's non-VE station) -- the reason the defaults
      are an object and not a record.
    * D8: THE FOUR PARTIES THAT CHOOSE BY THE STATE LINE state each side, and
      only that side's values.
    * THE FIELD DAYS' DX MULTIPLIER: row, class and session say one value.
    * LogCfg's CQ-EXCHANGE DEFAULTS, including the contests it did NOT name
      (the ARRL DX phone running). *)
unit uTestContestSession;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestSessionTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_TheBaseStatesNothing;
      procedure Test_AStatedValueIsKnownToBeStated;
      procedure Test_PartiesDescribeBothSidesOfTheStateLine;
      procedure Test_ARRLDXDescribesBothKindsOfStation;
      procedure Test_FieldDayDXMultipliersAreWhatTheSessionRuns;
      procedure Test_FieldDayExchangeComesFromTheStation;
      procedure Test_CanadaDayBlanksANonVEState;
      procedure Test_CQExchangeDefaultIsLogCfgsArm;
      procedure Test_MultiStatePartiesDescribeBothSides;
      procedure Test_JIDXDescribesBothSidesAndRefusesZoneMessages;
      procedure Test_M7bStationChoicesAreStatedPerSide;
      procedure Test_M7bCQExchangeDefaults;
      procedure Test_M7bBatch2StationChoicesAreStatedPerSide;
      procedure Test_M7bBatch2MessagesMemoriesAndCaptions;
      procedure Test_M7bBatch2CQExchangeDefaults;
      procedure Test_TheRunningSessionIsOneObjectWithOneWriter;
      procedure Test_JIDXRunsAnInitialExchangeItsTraitDoesNotState;
      procedure Test_ARRLDXRunsAnExchangeItsTraitDoesNotState;
      procedure Test_EveryARRLVHFRunningHasJunesSetUpAndItsOwnName;
      procedure Test_OZCHRSessionNamesAreCyrillic;
   end;

implementation

uses
   SysUtils,
   VC, uContestBase, uContestRegistry,
   (* ContestSession -- the kinds set-up resolved (M10 S9a-f). *)
   uContestSession,
   (* Make and NoStation -- lifted there at M8. *)
   uTestContestObjects,
   (* EDIContestName -- the EDI header's name (design Q42). *)
   PostUnit;

(* A US station in Kansas, every exchange field filled. *)
function KansasStation: TStationContext;
begin
   Result := NoStation;
   Result.MyCall := 'K0AAA';
   Result.MyCountry := 'K';
   Result.MyContinent := NorthAmerica;
   Result.MyState := 'KS';
   Result.MyGrid := 'EM17';
   Result.MyName := 'TOM';
   Result.MyFDClass := '2A';
   Result.MySection := 'KS';
   Result.MyPrec := 'A';
   Result.MyCheck := '99';
   Result.MyZoneText := '04';
   Result.MyZone := 4;
   Result.MyZoneValid := True;
end;

(* What aContest states for aStation. Caller frees. *)
function Describe(aContest: ContestType; const aStation: TStationContext): TSessionDefaults;
var
   obj: TContestBase;
begin
   Result := TSessionDefaults.Create;
   obj := Make(aContest);
   try
      obj.DescribeSession(aStation, Result);
   finally
      obj.Free;
      end;
end;

function CQDefault(aContest: ContestType; const aStation: TStationContext): string;
var
   obj: TContestBase;
begin
   obj := Make(aContest);
   try
      Result := obj.CQExchangeDefault(aStation);
   finally
      obj.Free;
      end;
end;

(* aContest's repeat S&P default -- M7b. *)
function RepeatDefault(aContest: ContestType; const aStation: TStationContext): string;
var
   obj: TContestBase;
begin
   obj := Make(aContest);
   try
      Result := obj.RepeatSPExchangeDefault(aStation);
   finally
      obj.Free;
      end;
end;

function StatesNothing(aSession: TSessionDefaults): boolean;
var
   v: TSessionValue;
begin
   Result := (aSession.DomesticCountryCount = 0) and (aSession.MemoryCount = 0);
   for v := Low(TSessionValue) to High(TSessionValue) do
      begin
      if aSession.IsStated(v) then
         begin
         Result := False;
         end;
      end;
end;

(* THE BASE STATES NOTHING AND OFFERS NO CQ EXCHANGE, for every contest that
   has no class -- FoundContest asks every contest, so a classless contest's
   arm must find the session exactly as the head left it. *)
procedure TContestSessionTests.Test_TheBaseStatesNothing;
var
   c: ContestType;
   session: TSessionDefaults;
   classless: integer;
begin
   BeginTest('Test_TheBaseStatesNothing');
   classless := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if ContestClassFor(c) <> nil then
         begin
         Continue;
         end;
      inc(classless);
      session := Describe(c, KansasStation);
      try
         CheckTrue(StatesNothing(session),
                   ContestTypeSA[c] + ': the base stated something');
      finally
         session.Free;
         end;
      CheckEquals('', CQDefault(c, KansasStation),
                  ContestTypeSA[c] + ': the base offered a CQ exchange');
      CheckEquals('', RepeatDefault(c, KansasStation),
                  ContestTypeSA[c] + ': the base offered a repeat S&P exchange');
      end;
   (* A FLOOR, so the loop cannot pass by finding nothing to check. M7b
      batch 1 left 45 classless (DUMMYCONTEST among them), down from 84;
      batch 2 left five classless on purpose; POTA gained its class on
      2026-10-13 (Q6), and the UA4W Championship and RSGB 1.8 MHz theirs on
      2026-10-14 (Q28, Q33), and IN7QPNE its composite class the same day
      (design 8.2r), leaving one -- DUMMYCONTEST
      (uTestContestFactory.Test_M7bBatch2ContestsAreSiblingsOnTheBase holds
      the list). *)
   CheckTrue(classless >= 1, 'no classless contest was checked');
end;

(* EVERY VALUE HAS THREE STATES. A stated False, a stated empty text and a
   stated first enum member are each STATED; a value never set is not. *)
procedure TContestSessionTests.Test_AStatedValueIsKnownToBeStated;
var
   session: TSessionDefaults;
   memory: TSessionMemory;
begin
   BeginTest('Test_AStatedValueIsKnownToBeStated');
   session := TSessionDefaults.Create;
   try
      CheckTrue(StatesNothing(session), 'a new object states nothing');

      session.WARCEnabled := False;
      session.SentState := '';
      session.Band := Low(BandType);
      CheckTrue(session.IsStated(svWARCEnabled), 'a stated False is stated');
      CheckTrue(session.IsStated(svSentState), 'a stated empty sent state is stated');
      CheckTrue(session.IsStated(svBand), 'a stated first band is stated');
      CheckTrue(not session.IsStated(svHFEnabled), 'an unset flag is not');
      CheckTrue(not session.IsStated(svContestName), 'an unset text is not');
      CheckTrue(not session.IsStated(svExchange), 'an unset exchange is not');

      (* The memories keep their order, so a later write of one key wins. *)
      session.SetCQMemory(CW, smkAltF1, 'FIRST');
      session.SetExchangeMemory(CW, smkF3, 'NR #');
      session.SetCQMemory(CW, smkAltF1, 'SECOND');
      CheckEquals(3, session.MemoryCount, 'three memory writes');
      memory := session.Memory(2);
      CheckTrue(memory.Bank = smbCQ, 'the third write is a CQ memory');
      CheckTrue(memory.Key = smkAltF1, 'the third write is Alt-F1');
      CheckEquals('SECOND', memory.Text, 'and it is the later value');
      memory := session.Memory(1);
      CheckTrue(memory.Bank = smbExchange, 'the second is an exchange memory');

      (* M7b batch 2's two values: a stated False cursor and a stated first
         member are stated; a caption is a memory in the same ordered list. *)
      session.InitialExchangeCursorAtStart := False;
      session.DXCCMultByBand := Low(TAdditionalMultByBand);
      CheckTrue(session.IsStated(svInitialExchangeCursorAtStart), 'a stated False cursor is stated');
      CheckTrue(session.IsStated(svDXCCMultByBand), 'a stated first DXCC-by-band is stated');
      session.SetExchangeCaptionMemory(CW, smkF4, 'NR');
      CheckEquals(4, session.MemoryCount, 'a caption joins the memories');
      memory := session.Memory(3);
      CheckTrue(memory.Bank = smbExchangeCaption, 'the fourth is a caption');
      CheckEquals('NR', memory.Text, 'and it says NR');

      session.AddDomesticCountries(DomesticCountriesKVE);
      session.AddDomesticCountry('KL');
      CheckEquals(3, session.DomesticCountryCount, 'K, VE, then KL');
      CheckEquals('K', session.DomesticCountry(0), 'K first');
      CheckEquals('KL', session.DomesticCountry(2), 'KL last');
   finally
      session.Free;
      end;
end;

(* D8 -- THE FOUR PARTIES WHOSE ARM CHOSE BY THE STATE LINE. Each side states
   its own values and NOTHING of the other's, because an unstated value leaves
   the trait the head wrote -- which is the in-state value for Arizona and
   Texas's exchange, and so must not be restated. *)
procedure TContestSessionTests.Test_PartiesDescribeBothSidesOfTheStateLine;
var
   inState, outOfState: TStationContext;
   session: TSessionDefaults;
begin
   BeginTest('Test_PartiesDescribeBothSidesOfTheStateLine');
   inState := KansasStation;
   inState.InHostState := True;
   outOfState := KansasStation;
   outOfState.InHostState := False;

   session := Describe(ArizonaQsoParty, inState);
   try
      CheckTrue(session.IsStated(svMultByBand) and (not session.MultByBand),
                'Arizona in state: mults not by band');
      CheckTrue(not session.IsStated(svExchange), 'Arizona in state keeps the trait''s exchange');
   finally
      session.Free;
      end;
   session := Describe(ArizonaQsoParty, outOfState);
   try
      CheckTrue(session.IsStated(svExchange) and (session.Exchange = RSTDomesticQTHExchange),
                'Arizona out of state sends the county alone');
      CheckTrue(not session.IsStated(svMultByBand), 'Arizona out of state keeps mult by band');
   finally
      session.Free;
      end;

   session := Describe(CALQSOPARTY, inState);
   try
      CheckTrue(session.Exchange = QSONumberDomesticOrDXQTHExchange, 'California in state');
   finally
      session.Free;
      end;
   session := Describe(CALQSOPARTY, outOfState);
   try
      CheckTrue(session.Exchange = QSONumberDomesticQTHExchange, 'California out of state');
   finally
      session.Free;
      end;

   session := Describe(SALMONRUN, inState);
   try
      CheckTrue(session.Exchange = RSTDomesticOrDXQTHExchange, 'Salmon Run in state: exchange');
   finally
      session.Free;
      end;
   session := Describe(SALMONRUN, outOfState);
   try
      CheckTrue(session.Exchange = RSTDomesticQTHExchange, 'Salmon Run out of state: exchange');
   finally
      session.Free;
      end;

   session := Describe(TEXASQSOPARTY, inState);
   try
      CheckTrue(not session.IsStated(svExchange), 'Texas in state keeps the trait''s exchange');
   finally
      session.Free;
      end;
   session := Describe(TEXASQSOPARTY, outOfState);
   try
      CheckTrue(session.Exchange = RSTDomesticQTHExchange, 'Texas out of state: exchange');
   finally
      session.Free;
      end;
end;

(* ARRL DX: A W/VE STATION SENDS POWER; EVERYONE ELSE SENDS A STATE OUT OF
   S48P14DC. Both runnings, one family base. *)
procedure TContestSessionTests.Test_ARRLDXDescribesBothKindsOfStation;
const
   RUNNINGS: array[0..1] of ContestType = (ARRLDXCW, ARRLDXSSB);
var
   dx: TStationContext;
   session: TSessionDefaults;
   c: ContestType;
   i: integer;
begin
   BeginTest('Test_ARRLDXDescribesBothKindsOfStation');
   dx := NoStation;
   dx.MyCountry := 'DL';
   dx.MyContinent := Europe;

   for i := Low(RUNNINGS) to High(RUNNINGS) do
      begin
      c := RUNNINGS[i];
      session := Describe(c, KansasStation);
      try
         CheckTrue(session.Exchange = RSTPowerExchange, ContestTypeSA[c] + ' W: power');
         CheckTrue(not session.IsStated(svDomesticFile), ContestTypeSA[c] + ' W: no domestic file');
         CheckEquals('ARRL DX Test', session.ContestName, ContestTypeSA[c] + ' name');
         CheckEquals(2, session.DomesticCountryCount, ContestTypeSA[c] + ' K and VE');
      finally
         session.Free;
         end;

      session := Describe(c, dx);
      try
         CheckTrue(session.Exchange = RSTDomesticQTHExchange, ContestTypeSA[c] + ' DX: a state');
         CheckEquals('S48P14DC', session.DomesticFile, ContestTypeSA[c] + ' DX: S48P14DC');
      finally
         session.Free;
         end;
      end;
end;

(* THE TWO FIELD DAYS' DX MULTIPLIER: THE ROW, THE CLASS AND THE SESSION SAID
   ONE VALUE. Field Day's was made so at M2 (Q1, NoDXMults); Winter Field
   Day's at M7a, to ARRLDXCCWithNoARRLSections -- the value its arm always set
   and so the value every session ran. Both DescribeSessions restated it until
   M11 S2 (plan 1.3). M11 S4 part 2 deleted the DX kind: the question is the
   class's HasDXMultiplier, False for Field Day (the base's) and True for
   Winter Field Day at every station. *)
procedure TContestSessionTests.Test_FieldDayDXMultipliersAreWhatTheSessionRuns;

   procedure Check(aContest: ContestType; aExpected: boolean);
   begin
      (* The row's line went with the row (M10 S8): the class is held to the
         literal, which is what the row said. *)
      CheckTrue(ContestIdentity(aContest).HasDXMultiplier = aExpected,
                ContestTypeSA[aContest] + ': the class');
   end;

begin
   BeginTest('Test_FieldDayDXMultipliersAreWhatTheSessionRuns');
   Check(ARRLFIELDDAY, False);
   (* False since 2026-10-17: Q38, NY4I -- "Winter FD does not count DXCC
      multipliers". It was True (ARRLDXCCWithNoARRLSections), tracked and
      never scored. *)
   Check(WINTERFIELDDAY, False);
end;

(* FIELD DAY'S MESSAGES ARE BUILT FROM THE STATION IT IS HANDED, and its
   domestic countries are the twenty ARRL-section countries. *)
procedure TContestSessionTests.Test_FieldDayExchangeComesFromTheStation;
var
   session: TSessionDefaults;
begin
   BeginTest('Test_FieldDayExchangeComesFromTheStation');
   session := Describe(ARRLFIELDDAY, KansasStation);
   try
      CheckEquals(' 2A KS', session.CQExchangeCW, 'CQ exchange');
      CheckEquals('2A KS', session.SPExchangeCW, 'S&P exchange');
      CheckEquals('73 \ FD', session.QSLCW, 'QSL');
      CheckTrue(session.IsStated(svWARCEnabled) and (not session.WARCEnabled), 'no WARC');
      CheckTrue(session.LiteralDomesticQTH, 'literal domestic QTH');
      CheckEquals(20, session.DomesticCountryCount, 'the ARRL-section countries');
      CheckEquals('KP5', session.DomesticCountry(19), 'KP5 last');
      CheckEquals(2, session.MemoryCount, 'CQ F1 and F2');
   finally
      session.Free;
      end;
end;

(* AN EMPTY SENT STATE IS A STATEMENT: Canada Day sends none for a non-VE
   station, and leaves a VE station's MY STATE as what it sends. Since M9a
   the statement is the session's sent state, never MY STATE (design 7.11). *)
procedure TContestSessionTests.Test_CanadaDayBlanksANonVEState;
var
   ve: TStationContext;
   session: TSessionDefaults;
begin
   BeginTest('Test_CanadaDayBlanksANonVEState');
   session := Describe(CANADA_DAY, KansasStation);
   try
      CheckTrue(session.IsStated(svSentState), 'a K station''s sent state is stated');
      CheckEquals('', session.SentState, 'and it is blank');
      CheckEquals(3, session.DomesticCountryCount, 'VE, CY0, CY9');
   finally
      session.Free;
      end;

   ve := KansasStation;
   ve.MyCountry := 'VE';
   ve.MyState := 'ON';
   session := Describe(CANADA_DAY, ve);
   try
      CheckTrue(not session.IsStated(svSentState), 'a VE station sends its MY STATE');
   finally
      session.Free;
      end;
end;

(* LogCfg's DEFAULT CQ EXCHANGE, contest by contest -- including two it did
   not name, which offer nothing. *)
procedure TContestSessionTests.Test_CQExchangeDefaultIsLogCfgsArm;
var
   noState: TStationContext;
begin
   BeginTest('Test_CQExchangeDefaultIsLogCfgsArm');
   noState := KansasStation;
   noState.MyState := '';

   CheckEquals(' 5NN KS', CQDefault(ARRLDXCW, KansasStation), 'ARRL DX CW');
   CheckEquals('', CQDefault(ARRLDXSSB, KansasStation), 'ARRL DX phone was never named');
   CheckEquals('', CQDefault(CQWWCW, KansasStation), 'CQ WW was never named');

   CheckEquals(' 5NN KS', CQDefault(IARU, KansasStation), 'IARU with a state');
   CheckEquals(' 5NN 04', CQDefault(IARU, noState), 'IARU sends the zone AS TEXT');
   CheckEquals(' 5NN 04', CQDefault(CQ160CW, noState), 'CQ 160 CW');
   CheckEquals(' 5NN 04', CQDefault(LZDX, noState), 'LZ DX');

   CheckEquals(' 5NN # KS', CQDefault(PCC, KansasStation), 'PCC with a state');
   CheckEquals(' 5NN #', CQDefault(PCC, noState), 'PCC without');
   CheckEquals(' 5NN #', CQDefault(IOTA, noState), 'IOTA without');
   CheckEquals(' KS #', CQDefault(CQIR, KansasStation), 'CQIR with a state');
   CheckEquals(' #', CQDefault(CQIR, noState), 'CQIR without');

   CheckEquals(' # TOM KS', CQDefault(LQP, KansasStation), 'Locust');
   CheckEquals(' # TOM KS', CQDefault(NCCCSPRINT, KansasStation), 'NCCC Sprint');
   CheckEquals(' KS#', CQDefault(RFCHAMPIONSHIPCW, KansasStation), 'RF Championship');
   CheckEquals(' # KS', CQDefault(CALQSOPARTY, KansasStation), 'California');
   CheckEquals(' KS', CQDefault(WISCONSINQSOPARTY, KansasStation), 'Wisconsin');
   CheckEquals(' 5NN # 04', CQDefault(NZFIELDDAY, KansasStation), 'Jock White Field Day');
   CheckEquals(' 5NN # EM17', CQDefault(OZHCRVHF, KansasStation), 'OZHCR VHF sends the whole grid');
   CheckEquals(' 5NN # KS', CQDefault(NRAUBALTICCW, KansasStation), 'NRAU-Baltic CW');
   CheckEquals(' 5NN # KS', CQDefault(NRAUBALTICSSB, KansasStation), 'NRAU-Baltic SSB');
end;

(* ---------------------------------------------------------------------------
   M7b BATCH 1 (2026-10-02) -- the classless contests' arms, moved
   --------------------------------------------------------------------------- *)

(* THE TWO MULTI-STATE PARTIES DESCRIBE BOTH SIDES. 7QP chooses on
   FoundContest's in-state answer (its row's P makes set-up run the party
   head); NEQP on MY STATE's first two characters, D7's rule as M2 restored
   it, which an EMPTY state must survive -- the defect #3 crash. Each side
   states its own values, and the DX multiplier limit is NEQP's for every
   station but 7QP's only in state. *)
procedure TContestSessionTests.Test_MultiStatePartiesDescribeBothSides;
var
   inState, outOfState, maine, noState: TStationContext;
   session: TSessionDefaults;
begin
   BeginTest('Test_MultiStatePartiesDescribeBothSides');
   inState := KansasStation;
   inState.InHostState := True;
   outOfState := KansasStation;
   outOfState.InHostState := False;

   session := Describe(SEVENQP, inState);
   try
      CheckTrue(session.Exchange = RSTDomesticOrDXQTHExchange, '7QP in state: county or DX');
      CheckTrue(session.IsStated(svDXMultLimit) and (session.DXMultLimit = 20),
                '7QP in state: at most 20 DX multipliers');
   finally
      session.Free;
      end;
   session := Describe(SEVENQP, outOfState);
   try
      CheckTrue(session.Exchange = RSTDomesticQTHExchange, '7QP out of state: a county');
      CheckTrue(not session.IsStated(svDXMultLimit), '7QP out of state states no limit');
   finally
      session.Free;
      end;

   maine := KansasStation;
   maine.MyState := 'ME';
   session := Describe(NEWENGLANDQSO, maine);
   try
      CheckEquals('NEQSOW1', session.DomesticFile, 'NEQP inside New England: NEQSOW1');
      CheckTrue(session.Exchange = RSTDomesticOrDXQTHExchange, 'NEQP inside: county or DX');
      CheckEquals(20, session.DXMultLimit, 'NEQP inside: limit 20');
      CheckEquals(4, session.DomesticCountryCount, 'NEQP: K, VE, KH6, KL');
   finally
      session.Free;
      end;
   session := Describe(NEWENGLANDQSO, KansasStation);
   try
      CheckEquals('NEQSO', session.DomesticFile, 'NEQP outside New England: NEQSO');
      CheckTrue(session.Exchange = RSTDomesticQTHExchange, 'NEQP outside: a county');
      CheckEquals(20, session.DXMultLimit, 'NEQP outside: limit 20 too');
   finally
      session.Free;
      end;
   noState := KansasStation;
   noState.MyState := '';
   session := Describe(NEWENGLANDQSO, noState);
   try
      CheckEquals('NEQSO', session.DomesticFile,
                  'NEQP with no MY STATE is outside -- and does not crash');
   finally
      session.Free;
      end;
end;

(* JIDX: A JA STATION SENDS ITS ZONE, EVERYONE ELSE A PREFECTURE -- and the
   closing set-up writes no zone-exchange messages either way, which was a
   test of the contest's name in FoundContest until M7b. (That refusal was a
   session statement, SuppressZoneExchangeMessages, until M11 S9e part 1; it
   is the class's choice of no default messages now, pinned at every
   station by uTestExchangeKindReaders. Its zone kind,
   CQ zones for JA, left with the kind at M11 S5 part 2:
   uTestZoneMultiplier pins HasZoneMultiplier on both sides.) *)
procedure TContestSessionTests.Test_JIDXDescribesBothSidesAndRefusesZoneMessages;
const
   RUNNINGS: array[0..1] of ContestType = (JIDXCW, JIDXSSB);
var
   ja: TStationContext;
   session: TSessionDefaults;
   name: string;
   i: integer;
begin
   BeginTest('Test_JIDXDescribesBothSidesAndRefusesZoneMessages');
   ja := KansasStation;
   ja.MyCountry := 'JA';
   ja.MyContinent := Asia;
   for i := Low(RUNNINGS) to High(RUNNINGS) do
      begin
      name := ContestTypeSA[RUNNINGS[i]];
      session := Describe(RUNNINGS[i], ja);
      try
         CheckTrue(session.Exchange = RSTZoneExchange, name + ' JA: zone');
         CheckTrue(session.InitialExchange = ZoneInitialExchange,
                   name + ' JA: zone initial exchange');
         CheckTrue(not session.IsStated(svDomesticFile), name + ' JA: no domestic file');
      finally
         session.Free;
         end;
      session := Describe(RUNNINGS[i], KansasStation);
      try
         CheckTrue(session.Exchange = RSTPrefectureExchange, name + ' W: prefecture');
         CheckEquals('JIDX', session.DomesticFile, name + ' W: JIDX');
      finally
         session.Free;
         end;
      end;
end;

(* THE STATION-DEPENDENT ARMS STATE ONE SIDE EACH: ARRL 160 on the
   ARRL-section countries, YU DX on the station's own country; and the
   Gagarin Cup's R150S list. (All Asian stated only its DX kind, and left
   with it at M11 S4 part 2: uTestDXMultiplierKey.HAS_DX pins its answer.) *)
procedure TContestSessionTests.Test_M7bStationChoicesAreStatedPerSide;
var
   dx, yu: TStationContext;
   session: TSessionDefaults;
begin
   BeginTest('Test_M7bStationChoicesAreStatedPerSide');
   dx := KansasStation;
   dx.MyCountry := 'DL';
   dx.MyContinent := Europe;
   yu := dx;
   yu.MyCountry := 'YU';

   session := Describe(ARRL160, KansasStation);
   try
      CheckTrue(session.Exchange = RSTDomesticOrDXQTHExchange, 'ARRL 160, W: section or DX');
      CheckEquals(20, session.DomesticCountryCount, 'ARRL 160: the ARRL-section countries');
   finally
      session.Free;
      end;
   session := Describe(ARRL160, dx);
   try
      CheckTrue(session.Exchange = RSTDomesticQTHExchange, 'ARRL 160, DX: a section');
   finally
      session.Free;
      end;

   session := Describe(YUDX, yu);
   try
      (* Whether a YU entrant counts a domestic multiplier is the class's
         answer since M11 S6 part 2 (UsesDomesticFile), pinned in
         uTestDomesticMultiplier; set-up states only the domestic country. *)
      CheckEquals(1, session.DomesticCountryCount, 'YU DX, YU: YU is domestic');
   finally
      session.Free;
      end;
   session := Describe(YUDX, dx);
   try
      CheckEquals(1, session.DomesticCountryCount, 'YU DX: YU is domestic');
   finally
      session.Free;
      end;

   session := Describe(GAGARINCUP, dx);
   try
      CheckTrue(session.IsStated(svR150SMode) and session.R150SMode, 'Gagarin Cup: R150S');
      CheckEquals('Yuri Gagarin International DX Contest', session.ContestName,
                  'Gagarin Cup: name');
   finally
      session.Free;
      end;
end;

(* LogCfg's DEFAULTS FOR THE M7b CONTESTS, and the EU Sprints' repeat S&P
   default -- the one contest family that set one. *)
procedure TContestSessionTests.Test_M7bCQExchangeDefaults;
var
   noState: TStationContext;
begin
   BeginTest('Test_M7bCQExchangeDefaults');
   noState := KansasStation;
   noState.MyState := '';

   CheckEquals(' 5NN KS', CQDefault(SEVENQP, KansasStation), '7QP');
   CheckEquals(' 5NN KS', CQDefault(ALLASIANCW, KansasStation), 'All Asian CW');
   CheckEquals(' 5NN KS', CQDefault(ALLASIANSSB, KansasStation), 'All Asian SSB');
   CheckEquals(' 5NN KS', CQDefault(ARRL160, KansasStation), 'ARRL 160');
   CheckEquals(' 5NN KS', CQDefault(OLDNEWYEAR, KansasStation), 'Old New Year');
   CheckEquals(' 5NN KS', CQDefault(JIDXCW, KansasStation), 'JIDX CW with a state');
   CheckEquals(' 5NN 04', CQDefault(JIDXSSB, noState), 'JIDX SSB sends the zone AS TEXT');
   CheckEquals(' 5NN 04', CQDefault(OZCR_O, noState), 'OZCHR teams');
   CheckEquals(' 5NN KS', CQDefault(OZCR_Z, KansasStation), 'OZCHR');
   CheckEquals(' 5NN # KS', CQDefault(HELVETIA, KansasStation), 'Helvetia with a state');
   CheckEquals(' 5NN #', CQDefault(HELVETIA, noState), 'Helvetia without');
   CheckEquals(' DE \ # TOM', CQDefault(EUSPRINT_SPRING_CW, KansasStation), 'EU Sprint');
   CheckEquals('@ DE \ # TOM', RepeatDefault(EUSPRINT_AUTUMN_SSB, KansasStation),
               'EU Sprint repeat S&P');
   CheckEquals('', CQDefault(ARRL10, KansasStation), 'ARRL 10 was never named');
   CheckEquals('', RepeatDefault(ARRL160, KansasStation), 'only the EU Sprints offer a repeat');
end;

(* M7b BATCH 2 -- THE ARMS THAT CHOSE BY THE STATION STATE ONE SIDE EACH, as
   the arm did: the South American WW both ways on the continent; IRTS, RDA and
   CQMM one way (the other side leaves the head's value). *)
procedure TContestSessionTests.Test_M7bBatch2StationChoicesAreStatedPerSide;
var
   brazil, ireland, russia, dl: TStationContext;
   session: TSessionDefaults;
begin
   BeginTest('Test_M7bBatch2StationChoicesAreStatedPerSide');
   brazil := KansasStation;
   brazil.MyCountry := 'PY';
   brazil.MyContinent := SouthAmerica;
   ireland := KansasStation;
   ireland.MyCountry := 'EI';
   ireland.MyContinent := Europe;
   russia := KansasStation;
   russia.MyCountry := 'UA';
   russia.MyContinent := Europe;
   dl := KansasStation;
   dl.MyCountry := 'DL';
   dl.MyContinent := Europe;

   session := Describe(IRTS, ireland);
   try
      CheckTrue(session.IsStated(svInitialExchangeCursorAtStart) and
                session.InitialExchangeCursorAtStart, 'IRTS: the cursor at the start');
      CheckTrue(session.Band = Band80, 'IRTS: 80 m');
      CheckTrue(session.IsStated(svDigitalModeEnable) and not session.DigitalModeEnable,
                'IRTS: digital off');
   finally
      session.Free;
      end;
   session := Describe(RDA, russia);
   try
      CheckEquals(5, session.DomesticCountryCount, 'RDA: the Russian countries');
      CheckTrue(session.DomesticMultByBand = dmbbAllBand, 'RDA: domestic mults over all bands');
   finally
      session.Free;
      end;
   session := Describe(CQMM, brazil);
   try
      CheckTrue(session.IsStated(svDXCCMultByBand) and (session.DXCCMultByBand = dmbbAllBand),
                'CQMM: DXCC by band over all bands');
      CheckTrue(session.Band = Band80, 'CQMM: 80 m');
   finally
      session.Free;
      end;
end;

(* M7b BATCH 2 -- MESSAGES, MEMORIES AND THE RTC'S CAPTIONS, in the arm's order,
   built from the station's grid, name and state. *)
procedure TContestSessionTests.Test_M7bBatch2MessagesMemoriesAndCaptions;
var
   session: TSessionDefaults;
   memory: TSessionMemory;
begin
   BeginTest('Test_M7bBatch2MessagesMemoriesAndCaptions');

   session := Describe(RTC, KansasStation);
   try
      CheckTrue(session.IsStated(svWARCEnabled) and not session.WARCEnabled, 'RTC: WARC off');
      CheckEquals(' # EM17', session.CQExchangeCW, 'RTC: CQ exchange');
      CheckEquals(' # EM17', session.SPExchangeCW, 'RTC: S&P exchange');
      CheckEquals(' # EM17', session.RepeatSPExchangeCW, 'RTC: repeat S&P exchange');
      CheckEquals(6, session.MemoryCount, 'RTC: four memories and two captions');
      memory := session.Memory(0);
      CheckTrue((memory.Bank = smbCQ) and (memory.Key = smkF3), 'RTC: CQ F3 first');
      CheckEquals('# EM17', memory.Text, 'RTC: CQ F3');
      memory := session.Memory(2);
      CheckEquals('@ DE \ # EM17', memory.Text, 'RTC: exchange F5');
      memory := session.Memory(4);
      CheckTrue((memory.Bank = smbExchangeCaption) and (memory.Key = smkF4), 'RTC: F4 caption');
      CheckEquals('NR', memory.Text, 'RTC: F4 is NR');
      memory := session.Memory(5);
      CheckEquals('Cl+Ex', memory.Text, 'RTC: F5 is Cl+Ex');
   finally
      session.Free;
      end;

   session := Describe(RSGB_ROPOCO_SSB, KansasStation);
   try
      CheckEquals('_~ %5NN (', session.CQExchangeCW, 'RoPoCo: CQ exchange');
      CheckTrue(session.IsStated(svMultipleBands) and not session.MultipleBands, 'RoPoCo: one band');
      CheckEquals(6, session.MemoryCount, 'RoPoCo: six memories, the CW ones for both runnings');
   finally
      session.Free;
      end;

   session := Describe(SST, KansasStation);
   try
      CheckEquals(' TOM KS', session.CQExchangeCW, 'SST: CQ exchange');
      CheckEquals('TOM KS', session.SPExchangeCW, 'SST: S&P exchange');
      (* Set-up restated the domestic kind until M11 S2 (plan 1.3); the kind
         is gone (M11 S6 part 2) and the class answers it. *)
      CheckTrue(ContestIdentity(SST).UsesDomesticFile,
                'SST: domestic mults from the file');
      CheckEquals(2, session.DomesticCountryCount, 'SST: K and VE');
      CheckEquals('Slow Speed Test', session.ContestName, 'SST: name');
   finally
      session.Free;
      end;

   session := Describe(STEWPERRY, KansasStation);
   try
      CheckEquals(' EM17', session.CQExchangeCW, 'Stew Perry: CQ exchange');
      CheckEquals('EM17', session.SPExchangeCW, 'Stew Perry: S&P exchange');
      CheckTrue(session.Band = Band160, 'Stew Perry: 160 m');
   finally
      session.Free;
      end;

   session := Describe(RAEM, KansasStation);
   try
      CheckTrue(session.InitialExchangeCursorAtStart, 'RAEM: the cursor at the start');
   finally
      session.Free;
      end;

   (* THE EMPTY ARMS STATE NOTHING. *)
   session := Describe(EUDX, KansasStation);
   try
      CheckTrue(StatesNothing(session), 'EUDX: its arm was empty');
   finally
      session.Free;
      end;
   session := Describe(RFASCHAMPIONSHIPCW, KansasStation);
   try
      CheckTrue(StatesNothing(session), 'AS-CHAMP: its arm was empty');
   finally
      session.Free;
      end;
end;

(* LogCfg's DEFAULTS FOR THE BATCH 2 CONTESTS -- every arm tSetupExchangeNumbers
   held for them, and one it never had. *)
procedure TContestSessionTests.Test_M7bBatch2CQExchangeDefaults;
begin
   BeginTest('Test_M7bBatch2CQExchangeDefaults');
   CheckEquals(' 5NN # EM17', CQDefault(RADIOVHFFD, KansasStation), 'Radio VHF FD');
   CheckEquals(' # KS', CQDefault(RAEM, KansasStation), 'RAEM');
   CheckEquals(' KS#', CQDefault(RFASCHAMPIONSHIPCW, KansasStation), 'AS-CHAMP');
   CheckEquals(' KS#', CQDefault(R9W_UW9WK_MEMORIAL, KansasStation), 'R9W UW9WK Memorial');
   CheckEquals(' KS', CQDefault(RADIOMEMORY, KansasStation), 'Radio Memory');
   CheckEquals(' # TOM', CQDefault(CWOPEN, KansasStation), 'CW Open');
   CheckEquals(' EM17 EM17', CQDefault(MAKROTHEN, KansasStation), 'Makrothen: four characters, twice');
   CheckEquals('', CQDefault(SST, KansasStation), 'SST was never named');
end;

(* ------------------------------------------------------------------------ *)
(* THE RUNNING SESSION -- uContestSession (M10 S9a)                           *)
(* ------------------------------------------------------------------------ *)

(* ONE OBJECT, NEVER REPLACED, AND WHAT IS WRITTEN IS WHAT IS READ.

  A reader may hold ContestSession across a set-up: the object must be the
  same one afterwards, or that reference dangles. A fresh object holds each
  kind's zero -- NoInitialExchange and UnknownExchange -- the values the globals it replaces
  started from (ActiveExchange's `= NoExchangeReceived` initializer was
  commented out, so its zero was UnknownExchange). Every member of every kind
  is written and read back through the writer FCONTEST uses, and writing one
  kind leaves the other as it was pinned (each is its own field, M10
  S9b-S9f; the prefix kind, S9b's, was deleted at M11 S3, the DX kind,
  S9d's, at M11 S4, the zone kind, S9c's, at M11 S5, and the domestic kind,
  S9e's, at M11 S6). The program's own
  values are restored,
  because this is the process-wide session and other suites run after this
  one. *)
procedure TContestSessionTests.Test_TheRunningSessionIsOneObjectWithOneWriter;
const
   KIND_INITIAL = 0;
   KIND_EXCHANGE = 5;
var
   before: TContestSession;
   fresh: TContestSession;
   savedInitial: InitialExchangeType;
   savedExchange: ExchangeType;
   initialKind: InitialExchangeType;
   exchangeKind: ExchangeType;

   (* Every kind at a value that is not its zero, so a write that leaked
     into another field would show. *)
   procedure PinAll;
   begin
      ContestSession.WriteInitialExchange(ZoneInitialExchange);
      ContestSession.WriteExchange(RSTPowerExchange);
   end;

   (* Each kind but the one just written is still where PinAll put it. *)
   procedure CheckOthersPinned(aWritten: integer; const aWhat: string);
   begin
      if aWritten <> KIND_INITIAL then
         begin
         CheckEquals(Ord(ZoneInitialExchange), Ord(ContestSession.InitialExchange),
                     aWhat + ' leaves the initial exchange');
         end;
      if aWritten <> KIND_EXCHANGE then
         begin
         CheckEquals(Ord(RSTPowerExchange), Ord(ContestSession.Exchange),
                     aWhat + ' leaves the exchange kind');
         end;
      CheckTrue(ContestSession = before,
                aWhat + ' never replaces the object');
   end;

begin
   BeginTest('Test_TheRunningSessionIsOneObjectWithOneWriter');
   before := ContestSession;
   CheckTrue(before <> nil, 'the session exists once the unit is initialised');

   fresh := TContestSession.Create;
   try
      CheckEquals(Ord(NoInitialExchange), Ord(fresh.InitialExchange),
                  'a fresh session starts from NoInitialExchange');
      CheckEquals(Ord(UnknownExchange), Ord(fresh.Exchange),
                  'a fresh session starts from UnknownExchange');
   finally
      fresh.Free;
      end;

   savedInitial := ContestSession.InitialExchange;
   savedExchange := ContestSession.Exchange;
   try
      PinAll;
      for initialKind := Low(InitialExchangeType) to High(InitialExchangeType) do
         begin
         ContestSession.WriteInitialExchange(initialKind);
         CheckEquals(Ord(initialKind), Ord(ContestSession.InitialExchange),
                     'the reader sees what the writer wrote, initial exchange '
                     + IntToStr(Ord(initialKind)));
         CheckOthersPinned(KIND_INITIAL,
                           'initial exchange ' + IntToStr(Ord(initialKind)));
         end;

      PinAll;
      for exchangeKind := Low(ExchangeType) to High(ExchangeType) do
         begin
         ContestSession.WriteExchange(exchangeKind);
         CheckEquals(Ord(exchangeKind), Ord(ContestSession.Exchange),
                     'the reader sees what the writer wrote, exchange kind '
                     + IntToStr(Ord(exchangeKind)));
         CheckOthersPinned(KIND_EXCHANGE,
                           'exchange kind ' + IntToStr(Ord(exchangeKind)));
         end;
   finally
      ContestSession.WriteInitialExchange(savedInitial);
      ContestSession.WriteExchange(savedExchange);
      end;
end;

(* THE SESSION IS NOT THE TRAIT -- why no reader may ask ContestIdentity.

  JIDX CW's class states the trait NoInitialExchange, and its DescribeSession
  states ZoneInitialExchange for a JA station only. Set-up writes the trait
  at the head (FCONTEST.ApplyContestTraits) and then what the contest stated
  (FCONTEST.ApplySessionDefaults); this applies those two writes in that
  order through the session's writer and checks the reader sees the STATED
  value at a JA station and the trait elsewhere. FCONTEST's own path is
  pinned for every contest at the matrix stations by uTestContestKindPin.

  RE-POINTED AT M11 S2 (plan 1.3, F2): this pinned KCJ, whose
  DescribeSession stated the same value for EVERY station over a trait that
  said otherwise -- a second statement of one fact, not a session that
  varies. S2 made that trait the value and deleted the statement, so KCJ no
  longer differs from its trait anywhere. JIDX varies by STATION, which is the
  case this pin exists for. *)
procedure TContestSessionTests.Test_JIDXRunsAnInitialExchangeItsTraitDoesNotState;
var
   ja: TStationContext;
   stated: TSessionDefaults;
   trait: InitialExchangeType;
   saved: InitialExchangeType;
begin
   BeginTest('Test_JIDXRunsAnInitialExchangeItsTraitDoesNotState');
   trait := ContestIdentity(JIDXCW).InitialExchangeKind;
   CheckEquals(Ord(NoInitialExchange), Ord(trait), 'JIDX: the trait');
   ja := KansasStation;
   ja.MyCountry := 'JA';
   ja.MyContinent := Asia;

   saved := ContestSession.InitialExchange;
   try
      stated := Describe(JIDXCW, ja);
      try
         CheckTrue(stated.IsStated(svInitialExchange), 'JIDX, JA: states an initial exchange');
         CheckEquals(Ord(ZoneInitialExchange), Ord(stated.InitialExchange),
                     'JIDX, JA: what it states');

         ContestSession.WriteInitialExchange(trait);
         if stated.IsStated(svInitialExchange) then
            begin
            ContestSession.WriteInitialExchange(stated.InitialExchange);
            end;

         CheckEquals(Ord(ZoneInitialExchange), Ord(ContestSession.InitialExchange),
                     'JIDX, JA: the session runs what the contest stated');
         CheckTrue(ContestSession.InitialExchange <> ContestIdentity(JIDXCW).InitialExchangeKind,
                   'JIDX, JA: the session differs from the identity''s trait');
      finally
         stated.Free;
         end;

      stated := Describe(JIDXCW, KansasStation);
      try
         CheckFalse(stated.IsStated(svInitialExchange), 'JIDX, W: states no initial exchange');
         ContestSession.WriteInitialExchange(trait);
         CheckEquals(Ord(trait), Ord(ContestSession.InitialExchange), 'JIDX, W: the session runs the trait');
      finally
         stated.Free;
         end;
   finally
      ContestSession.WriteInitialExchange(saved);
      end;
end;

(* THE DOMESTIC KIND WAS THE SESSION'S (M10 S9e) -- and its test,
  Test_OKDXRunsADomesticMultiplierItsTraitDoesNotState, went with the kind
  at M11 S6 part 2. OK/OM DX's answer at an OK station and elsewhere is
  uTestDomesticMultiplier's (UsesDomesticFile, HasDomesticMultiplier). *)

(* THE EXCHANGE KIND IS THE SESSION'S (M10 S9f).

  ARRL DX CW's class states the trait RSTPowerExchange -- what a W/VE station
  receives. Its DescribeSession states RSTDomesticQTHExchange for a station
  outside W/VE, which receives a state or province; the frozen matrix's
  active.exchange line says RSTDomesticQTHExchange for the DL1AAA variant and
  RSTPowerExchange for K0AAA and VE3AAA. A reader that asked
  ContestIdentity(Contest).ExchangeKind would parse a DX station's received
  exchange as a power. A W station states the trait's own value. *)
procedure TContestSessionTests.Test_ARRLDXRunsAnExchangeItsTraitDoesNotState;
var
   dl: TStationContext;
   stated: TSessionDefaults;
   trait: ExchangeType;
   saved: ExchangeType;
begin
   BeginTest('Test_ARRLDXRunsAnExchangeItsTraitDoesNotState');
   trait := ContestIdentity(ARRLDXCW).ExchangeKind;
   CheckEquals(Ord(RSTPowerExchange), Ord(trait), 'ARRLDXCW: the trait');

   dl := KansasStation;
   dl.MyCall := 'DL1AAA';
   dl.MyCountry := 'DL';
   dl.MyContinent := Europe;

   saved := ContestSession.Exchange;
   try
      stated := Describe(ARRLDXCW, dl);
      try
         CheckTrue(stated.IsStated(svExchange),
                   'ARRLDXCW states an exchange for a DL station');
         ContestSession.WriteExchange(trait);
         if stated.IsStated(svExchange) then
            begin
            ContestSession.WriteExchange(stated.Exchange);
            end;
         CheckEquals(Ord(RSTDomesticQTHExchange), Ord(ContestSession.Exchange),
                     'ARRLDXCW DL: the session runs what the contest stated');
         CheckTrue(ContestSession.Exchange <> ContestIdentity(ARRLDXCW).ExchangeKind,
                   'ARRLDXCW DL: the session differs from the identity''s trait');
      finally
         stated.Free;
         end;

      stated := Describe(ARRLDXCW, KansasStation);
      try
         ContestSession.WriteExchange(trait);
         if stated.IsStated(svExchange) then
            begin
            ContestSession.WriteExchange(stated.Exchange);
            end;
         CheckEquals(Ord(trait), Ord(ContestSession.Exchange),
                     'ARRLDXCW W: the session runs the trait''s value');
      finally
         stated.Free;
         end;
   finally
      ContestSession.WriteExchange(saved);
      end;
end;

(* DESIGN Q41 (NY4I, 2026-10-15): ALL THREE ARRL VHF RUNNINGS GET JUNE'S
   SET-UP -- 6 m, the HF bands off -- AND EACH ITS OWN NAME, its Cabrillo
   name's spelling. September was named 'VHF QSO JUNE' and January had no
   set-up at all until 2026-10-17. *)
procedure TContestSessionTests.Test_EveryARRLVHFRunningHasJunesSetUpAndItsOwnName;
const
   RUNNINGS: array[0..2] of ContestType = (ARRLVHFJAN, ARRLVHFJUN, ARRLVHFSEP);
   NAMES: array[0..2] of string = ('ARRL-VHF-JAN', 'ARRL-VHF-JUN', 'ARRL-VHF-SEP');
var
   session: TSessionDefaults;
   c: ContestType;
   i: integer;
begin
   BeginTest('Test_EveryARRLVHFRunningHasJunesSetUpAndItsOwnName');
   for i := Low(RUNNINGS) to High(RUNNINGS) do
      begin
      c := RUNNINGS[i];
      session := Describe(c, KansasStation);
      try
         CheckTrue(session.IsStated(svBand), ContestTypeSA[c] + ': a starting band');
         CheckTrue(session.Band = Band6, ContestTypeSA[c] + ': starts on 6 m');
         CheckTrue(session.IsStated(svHFEnabled), ContestTypeSA[c] + ': states the HF bands');
         CheckFalse(session.HFEnabled, ContestTypeSA[c] + ': HF bands off');
         CheckEquals(NAMES[i], session.ContestName, ContestTypeSA[c] + ': its own name');
         CheckEquals(ContestIdentity(ContestHandleOf(c)).CabrilloName, session.ContestName,
                     ContestTypeSA[c] + ': the name is the Cabrillo name''s spelling');
      finally
         session.Free;
         end;
      end;
end;

(* The UTF-8 bytes of aHex, decoded -- a second derivation of the expected
   text, independent of how the class's source spells it. *)
function DecodedUTF8(const aHex: string): string;
var
   bytes: RawByteString;
   i: integer;
begin
   bytes := '';
   i := 1;
   while i < Length(aHex) do
      begin
      bytes := bytes + AnsiChar(StrToInt('$' + Copy(aHex, i, 2)));
      Inc(i, 2);
      end;
   Result := UTF8Decode(bytes);
end;

(* DESIGN Q42 (NY4I, 2026-10-16: "Restore Cyrillic."): THE OZCHR SESSION
   NAMES ARE D7's CYRILLIC TEXT, CHARACTER FOR CHARACTER. The expected text is
   built from its UTF-8 bytes (Python's encoding of the strings decoded from
   D7's cp1251 bytes in b90ba930), so a source that the compiler mis-decoded
   -- the trap a non-ASCII literal in a BOM-less unit falls into -- fails
   here code point by code point. And the EDI header, an interchange file,
   writes the Cabrillo name in its place. *)
procedure TContestSessionTests.Test_OZCHRSessionNamesAreCyrillic;
const
   (* Очно-заочный чемпионат России - заочные участники *)
   OZCR_Z_UTF8 = 'd09ed187d0bdd0be2dd0b7d0b0d0bed187d0bdd18bd0b920d187d0b5d0bcd0bfd0b8d0bed0bd' +
                 'd0b0d18220d0a0d0bed181d181d0b8d0b8202d20d0b7d0b0d0bed187d0bdd18bd0b520d183' +
                 'd187d0b0d181d182d0bdd0b8d0bad0b8';
   (* Очно-заочный чемпионат России - очные участники *)
   OZCR_O_UTF8 = 'd09ed187d0bdd0be2dd0b7d0b0d0bed187d0bdd18bd0b920d187d0b5d0bcd0bfd0b8d0bed0bd' +
                 'd0b0d18220d0a0d0bed181d181d0b8d0b8202d20d0bed187d0bdd18bd0b520d183d187d0b0' +
                 'd181d182d0bdd0b8d0bad0b8';
var
   session: TSessionDefaults;
   expected: string;
   i: integer;
begin
   BeginTest('Test_OZCHRSessionNamesAreCyrillic');

   expected := DecodedUTF8(OZCR_Z_UTF8);
   CheckEquals(49, Length(expected), 'OZCR_Z: the expected text is 49 characters');
   CheckEquals($041E, Ord(expected[1]), 'OZCR_Z: the expected text starts with U+041E');
   session := Describe(OZCR_Z, KansasStation);
   try
      CheckEquals(Length(expected), Length(session.ContestName), 'OZCR_Z: the name''s length');
      for i := 1 to Length(expected) do
         begin
         if i <= Length(session.ContestName) then
            begin
            CheckEquals(Ord(expected[i]), Ord(session.ContestName[i]),
                        'OZCR_Z: code point ' + IntToStr(i));
            end;
         end;
      CheckTrue(Pos('?', session.ContestName) = 0, 'OZCR_Z: no question mark is left');
   finally
      session.Free;
      end;

   expected := DecodedUTF8(OZCR_O_UTF8);
   CheckEquals(47, Length(expected), 'OZCR_O: the expected text is 47 characters');
   session := Describe(OZCR_O, KansasStation);
   try
      CheckEquals(Length(expected), Length(session.ContestName), 'OZCR_O: the name''s length');
      for i := 1 to Length(expected) do
         begin
         if i <= Length(session.ContestName) then
            begin
            CheckEquals(Ord(expected[i]), Ord(session.ContestName[i]),
                        'OZCR_O: code point ' + IntToStr(i));
            end;
         end;
      CheckTrue(Pos('?', session.ContestName) = 0, 'OZCR_O: no question mark is left');
   finally
      session.Free;
      end;

   (* THE EDI HEADER: a non-ASCII session name gives way to the Cabrillo
      name; an ASCII one is written as it is. *)
   CheckEquals(ContestIdentity(ContestHandleOf(OZCR_Z)).CabrilloName,
               EDIContestName(DecodedUTF8(OZCR_Z_UTF8), ContestHandleOf(OZCR_Z)),
               'EDI: a Cyrillic session name gives way to the Cabrillo name');
   CheckEquals('ARRL-VHF-JUN', EDIContestName('ARRL-VHF-JUN', ContestHandleOf(ARRLVHFJUN)),
               'EDI: an ASCII session name is written as it is');
end;

procedure TContestSessionTests.RunAllTests;
begin
   Test_TheBaseStatesNothing;
   Test_AStatedValueIsKnownToBeStated;
   Test_PartiesDescribeBothSidesOfTheStateLine;
   Test_ARRLDXDescribesBothKindsOfStation;
   Test_FieldDayDXMultipliersAreWhatTheSessionRuns;
   Test_FieldDayExchangeComesFromTheStation;
   Test_CanadaDayBlanksANonVEState;
   Test_CQExchangeDefaultIsLogCfgsArm;
   Test_MultiStatePartiesDescribeBothSides;
   Test_JIDXDescribesBothSidesAndRefusesZoneMessages;
   Test_M7bStationChoicesAreStatedPerSide;
   Test_M7bCQExchangeDefaults;
   Test_M7bBatch2StationChoicesAreStatedPerSide;
   Test_M7bBatch2MessagesMemoriesAndCaptions;
   Test_M7bBatch2CQExchangeDefaults;
   Test_TheRunningSessionIsOneObjectWithOneWriter;
   Test_JIDXRunsAnInitialExchangeItsTraitDoesNotState;
   Test_ARRLDXRunsAnExchangeItsTraitDoesNotState;
   Test_EveryARRLVHFRunningHasJunesSetUpAndItsOwnName;
   Test_OZCHRSessionNamesAreCyrillic;
end;

end.
