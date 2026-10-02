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
   end;

implementation

uses
   VC, uContestBase, uContestRegistry,
   (* Make and NoStation -- lifted there at M8. *)
   uTestContestObjects;

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
      batch 2 left the five that stay classless on purpose -- DUMMYCONTEST,
      POTA, the UA4W Championship, RSGB 1.8 MHz and IN7QPNE
      (uTestContestFactory.Test_M7bBatch2ContestsAreSiblingsOnTheBase holds
      the list). *)
   CheckTrue(classless >= 5, 'fewer than five classless contests were checked');
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
      CheckTrue(session.IsStated(svDXMult) and (session.DXMult = ARRLDXCCWithNoUSAOrCanada),
                'Salmon Run in state: DXCC without W/VE');
   finally
      session.Free;
      end;
   session := Describe(SALMONRUN, outOfState);
   try
      CheckTrue(session.Exchange = RSTDomesticQTHExchange, 'Salmon Run out of state: exchange');
      CheckTrue(not session.IsStated(svDXMult), 'Salmon Run out of state states no DX mult');
   finally
      session.Free;
      end;

   session := Describe(TEXASQSOPARTY, inState);
   try
      CheckTrue(session.IsStated(svDXMult) and (session.DXMult = ARRLDXCCWithNoUSACanadaKH6OrKL7),
                'Texas in state: DXCC without W/VE/KH6/KL7');
      CheckTrue(not session.IsStated(svExchange), 'Texas in state keeps the trait''s exchange');
   finally
      session.Free;
      end;
   session := Describe(TEXASQSOPARTY, outOfState);
   try
      CheckTrue(session.Exchange = RSTDomesticQTHExchange, 'Texas out of state: exchange');
      CheckTrue(not session.IsStated(svDXMult), 'Texas out of state states no DX mult');
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
         CheckTrue(session.DXMult = ARRLDXCCWithNoUSAOrCanada, ContestTypeSA[c] + ' W: DXCC');
         CheckTrue(not session.IsStated(svDomesticFile), ContestTypeSA[c] + ' W: no domestic file');
         CheckEquals('ARRL DX Test', session.ContestName, ContestTypeSA[c] + ' name');
         CheckEquals(2, session.DomesticCountryCount, ContestTypeSA[c] + ' K and VE');
      finally
         session.Free;
         end;

      session := Describe(c, dx);
      try
         CheckTrue(session.Exchange = RSTDomesticQTHExchange, ContestTypeSA[c] + ' DX: a state');
         CheckTrue(session.DomesticMult = DomesticFile, ContestTypeSA[c] + ' DX: domestic mults');
         CheckEquals('S48P14DC', session.DomesticFile, ContestTypeSA[c] + ' DX: S48P14DC');
         CheckTrue(not session.IsStated(svDXMult), ContestTypeSA[c] + ' DX: no DX mult stated');
      finally
         session.Free;
         end;
      end;
end;

(* THE TWO FIELD DAYS' DX MULTIPLIER: THE ROW, THE CLASS AND THE SESSION SAY
   ONE VALUE. Field Day's was made so at M2 (Q1, NoDXMults); Winter Field
   Day's at M7a, to ARRLDXCCWithNoARRLSections -- the value its arm always set
   and so the value every session ran. *)
procedure TContestSessionTests.Test_FieldDayDXMultipliersAreWhatTheSessionRuns;

   procedure Check(aContest: ContestType; aExpected: DXMultType);
   var
      row: TContestBase;
      session: TSessionDefaults;
   begin
      row := TContestBase.Create(aContest);
      try
         CheckTrue(row.DXMultiplierType = aExpected, ContestTypeSA[aContest] + ': the row');
      finally
         row.Free;
         end;
      CheckTrue(ContestIdentity(aContest).DXMultiplierType = aExpected,
                ContestTypeSA[aContest] + ': the class');
      session := Describe(aContest, KansasStation);
      try
         CheckTrue(session.IsStated(svDXMult) and (session.DXMult = aExpected),
                   ContestTypeSA[aContest] + ': the session');
      finally
         session.Free;
         end;
   end;

begin
   BeginTest('Test_FieldDayDXMultipliersAreWhatTheSessionRuns');
   Check(ARRLFIELDDAY, NoDXMults);
   Check(WINTERFIELDDAY, ARRLDXCCWithNoARRLSections);
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
      CheckTrue(session.DXMult = ARRLDXCCWithNoUSACanadaKH6OrKL7, '7QP in state: DXCC');
      CheckTrue(session.IsStated(svDXMultLimit) and (session.DXMultLimit = 20),
                '7QP in state: at most 20 DX multipliers');
   finally
      session.Free;
      end;
   session := Describe(SEVENQP, outOfState);
   try
      CheckTrue(session.Exchange = RSTDomesticQTHExchange, '7QP out of state: a county');
      CheckTrue(not session.IsStated(svDXMult), '7QP out of state states no DX mult');
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
      CheckTrue(session.DXMult = ARRLDXCCWithNoUSACanadaKH6OrKL7, 'NEQP inside: DXCC');
      CheckEquals(20, session.DXMultLimit, 'NEQP inside: limit 20');
      CheckEquals(4, session.DomesticCountryCount, 'NEQP: K, VE, KH6, KL');
   finally
      session.Free;
      end;
   session := Describe(NEWENGLANDQSO, KansasStation);
   try
      CheckEquals('NEQSO', session.DomesticFile, 'NEQP outside New England: NEQSO');
      CheckTrue(session.Exchange = RSTDomesticQTHExchange, 'NEQP outside: a county');
      CheckTrue(not session.IsStated(svDXMult), 'NEQP outside states no DX mult');
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
   test of the contest's name in FoundContest until M7b. *)
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
         CheckTrue(session.ZoneMult = CQZones, name + ' JA: CQ zones');
         CheckTrue(session.InitialExchange = ZoneInitialExchange,
                   name + ' JA: zone initial exchange');
         CheckTrue(not session.IsStated(svDomesticFile), name + ' JA: no domestic file');
         CheckTrue(session.SuppressZoneExchangeMessages,
                   name + ' JA: no zone-exchange messages');
      finally
         session.Free;
         end;
      session := Describe(RUNNINGS[i], KansasStation);
      try
         CheckTrue(session.Exchange = RSTPrefectureExchange, name + ' W: prefecture');
         CheckEquals('JIDX', session.DomesticFile, name + ' W: JIDX');
         CheckTrue(not session.IsStated(svZoneMult), name + ' W: no zone mult');
         CheckTrue(session.SuppressZoneExchangeMessages,
                   name + ' W: no zone-exchange messages');
      finally
         session.Free;
         end;
      end;
end;

(* THE STATION-DEPENDENT ARMS STATE ONE SIDE EACH: All Asian on the
   continent, ARRL 160 on the ARRL-section countries, YU DX on the station's
   own country; and the Gagarin Cup's R150S list. *)
procedure TContestSessionTests.Test_M7bStationChoicesAreStatedPerSide;
var
   asian, dx, yu: TStationContext;
   session: TSessionDefaults;
begin
   BeginTest('Test_M7bStationChoicesAreStatedPerSide');
   asian := KansasStation;
   asian.MyCountry := 'JA';
   asian.MyContinent := Asia;
   dx := KansasStation;
   dx.MyCountry := 'DL';
   dx.MyContinent := Europe;
   yu := dx;
   yu.MyCountry := 'YU';

   session := Describe(ALLASIANCW, asian);
   try
      CheckTrue(session.IsStated(svDXMult) and (session.DXMult = ARRLDXCC), 'All Asian, Asia: DXCC');
      CheckTrue(not session.IsStated(svPrefixMult), 'All Asian, Asia: no prefixes stated');
   finally
      session.Free;
      end;
   session := Describe(ALLASIANSSB, KansasStation);
   try
      CheckTrue(session.IsStated(svPrefixMult) and (session.PrefixMult = Prefix),
                'All Asian, W: prefixes');
      CheckTrue(not session.IsStated(svDXMult), 'All Asian, W: no DXCC stated');
   finally
      session.Free;
      end;

   session := Describe(ARRL160, KansasStation);
   try
      CheckTrue(session.Exchange = RSTDomesticOrDXQTHExchange, 'ARRL 160, W: section or DX');
      CheckTrue(session.DXMult = ARRLDXCCWithNoARRLSections, 'ARRL 160, W: DXCC');
      CheckEquals(20, session.DomesticCountryCount, 'ARRL 160: the ARRL-section countries');
   finally
      session.Free;
      end;
   session := Describe(ARRL160, dx);
   try
      CheckTrue(session.Exchange = RSTDomesticQTHExchange, 'ARRL 160, DX: a section');
      CheckTrue(not session.IsStated(svDXMult), 'ARRL 160, DX: no DX mult stated');
   finally
      session.Free;
      end;

   session := Describe(YUDX, yu);
   try
      CheckTrue(session.DomesticMult = NoDomesticMults, 'YU DX, YU: no domestic mults');
      CheckTrue(session.DXMult = ARRLDXCC, 'YU DX, YU: DXCC');
   finally
      session.Free;
      end;
   session := Describe(YUDX, dx);
   try
      CheckTrue(not session.IsStated(svDomesticMult), 'YU DX, DL: domestic mults as the trait');
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

   session := Describe(SOUTHAMERICANWW, brazil);
   try
      CheckTrue(session.PrefixMult = NonSouthAmericanPrefixes, 'SA WW, PY: non-SA prefixes');
   finally
      session.Free;
      end;
   session := Describe(SOUTHAMERICANWW, KansasStation);
   try
      CheckTrue(session.PrefixMult = SouthAmericanPrefixes, 'SA WW, W: SA prefixes');
   finally
      session.Free;
      end;

   session := Describe(IRTS, ireland);
   try
      CheckTrue(not session.IsStated(svDXMult), 'IRTS, EI: the DX multiplier is the head''s');
      CheckTrue(session.IsStated(svInitialExchangeCursorAtStart) and
                session.InitialExchangeCursorAtStart, 'IRTS: the cursor at the start');
      CheckTrue(session.Band = Band80, 'IRTS: 80 m');
      CheckTrue(session.IsStated(svDigitalModeEnable) and not session.DigitalModeEnable,
                'IRTS: digital off');
   finally
      session.Free;
      end;
   session := Describe(IRTS, dl);
   try
      CheckTrue(session.IsStated(svDXMult) and (session.DXMult = NoDXMults),
                'IRTS, DL: no DX multiplier');
   finally
      session.Free;
      end;

   session := Describe(RDA, russia);
   try
      CheckTrue(not session.IsStated(svDXMult), 'RDA, UA: the DX multiplier is the head''s');
      CheckEquals(5, session.DomesticCountryCount, 'RDA: the Russian countries');
      CheckTrue(session.DomesticMultByBand = dmbbAllBand, 'RDA: domestic mults over all bands');
   finally
      session.Free;
      end;
   session := Describe(RDA, dl);
   try
      CheckTrue(session.IsStated(svDXMult) and (session.DXMult = NoDXMults),
                'RDA, DL: no DX multiplier');
   finally
      session.Free;
      end;

   session := Describe(CQMM, brazil);
   try
      CheckTrue(session.PrefixMult = SouthAndNorthAmericanPrefixes, 'CQMM, PY: S and N American prefixes');
      CheckTrue(session.IsStated(svDXCCMultByBand) and (session.DXCCMultByBand = dmbbAllBand),
                'CQMM: DXCC by band over all bands');
      CheckTrue(session.Band = Band80, 'CQMM: 80 m');
   finally
      session.Free;
      end;
   session := Describe(CQMM, KansasStation);
   try
      CheckTrue(not session.IsStated(svPrefixMult), 'CQMM, W: the prefix multiplier is the head''s');
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
      CheckTrue(session.DomesticMult = DomesticFile, 'SST: domestic mults from the file');
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
end;

end.
