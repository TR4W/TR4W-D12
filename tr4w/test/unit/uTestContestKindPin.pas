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

(* EVERY CONTEST'S SESSION KINDS, AT EVERY MATRIX STATION, FROZEN AS
  LITERALS -- M11 S0b, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md). Six
  kinds at S0b; five since M11 S3 part 2 deleted the prefix kind, four
  since M11 S4 part 2 deleted the DX kind, and three since M11 S5 part 2
  deleted the zone kind -- each column left this unit in its deleting
  commit (a column removed, not a table regenerated -- see below).

  WHY IT EXISTS. M11 moves the six kind enums' engine arms into the classes
  and then deletes five of the enums. A kind is a SESSION fact: since M10 S2
  it has exactly two writers, FCONTEST.ApplyContestTraits (the class's trait)
  and then FCONTEST.ApplySessionDefaults (what the class's DescribeSession
  stated for the station). Each M11 stage rewrites one of those two halves,
  so this pins what the PAIR resolves to, contest by contest and station by
  station, before any of it moves. Kinds resolves them exactly as FCONTEST
  does: the trait, then each stated value over it.

  THE STATIONS ARE THE CONTEST MATRIX'S, AND THEY ARE DERIVED, NOT CHOSEN.
  tr4w/test/contest-matrix/matrix-lib.sh (matrix_run) opens every contest as
     us       K0AAA, MY STATE KS, MY SECTION KS, MY GRID EM17
     ve       VE3AAA, ON, ON, FN03
     dx       DL1AAA, no MY STATE, MY SECTION DX, JO62
     us-host  only for a party (IsUSQSOParty): MY STATE is the first key of
              the party's domestic file, VE7AAA / BC / CN89 for a VE7 host;
  and every variant states MY NAME TOM, MY FD CLASS 1A, MY CHECK 99 and MY
  PREC A. The us-host station of each party is copied from its frozen
  record's "### variant us-host" line (HOST_KIND_PINS). The rest of
  TStationContext is what FCONTEST.FoundContest hands DescribeSession
  (uContestFactory.CurrentStation): the CTY country of MY CALL (K, VE, DL)
  and its continent; MY STATE (SentMyState is cleared at FoundContest's head,
  so it is MY STATE); InHostState, which is FoundMyStateInDomFile for a party
  -- True at us-host, False elsewhere; and the session's contest name with
  FoundContest's in-state / out-of-state suffix. The zone, the power, the
  category mode and the three services are left zero: measured at S0b, no
  DescribeSession in the factory reads any of them.

  HOW IT WAS MADE -- ONCE. The tables below were GENERATED at M11 S0b (HEAD
  95e127a5) by a scratch program that linked every registered class and
  printed Kinds for each ContestType at each station. Before they were
  committed, every value was compared with the frozen contest matrix's
  active.* lines -- the program's own set-up, end to end: 580 records, 3,480
  values, 0 differences. So these literals are what the program RUNS, and
  the stations above are the program's.

  IT IS NEVER REGENERATED TO CLEAR A FAILURE. A failure means a kind
  changed: a contest's session runs another exchange shape or multiplier
  kind at that station than it did at S0b. An M11 stage that moves a kind
  into a class must leave every row here green. If a change of kind is
  DELIBERATE (a sponsor rule, an answered open question), change that one
  row by hand in the same commit and say why. When a stage DELETES a kind's
  enum, that kind's column leaves this unit in the same commit -- the only
  edit that is not to one row. Regenerating the tables would turn the pin
  into a copy of whatever the classes say today.

  A NEW CONTEST adds its row to KIND_PINS by hand (and, if it is a party,
  its row to HOST_KIND_PINS), with the kinds its matrix record shows.

  WHAT IS NOT HERE. Stations the matrix does not run -- a JA, OK/OM, ON,
  Scandinavian, Russian, YB, PY, 9A, HB, EI, YU or UR entrant, an Asian or a
  South American one -- whose DescribeSession branches the plan's S0b roster
  named. They are not pinned by this unit. (For the PREFIX kind, M11 S3's
  uTestPrefixMultiplierKey pins the KEY at a PY, ON, SM, JA, OK and YB
  entrant as well, which is the branch these stations would have chosen;
  for the DX kind, M11 S4's uTestDXMultiplierKey pins the key and whether
  there is a DX multiplier at fourteen entrants; for the zone kind, M11
  S5's uTestZoneMultiplier pins the count, the list and whether there is
  a zone multiplier at seven, a JA entrant among them.)

  THE MAIN TABLE IS INDEXED BY ContestType, so the compiler refuses a table
  with a row missing or extra, and each row carries its ContestTypeSA
  spelling (Token), so a row out of order fails by name. *)
unit uTestContestKindPin;

{$I ..\..\src\tr4w.inc}

interface

uses
   VC,
   (* TStationContext -- MatrixStation and Kinds are interface now. *)
   uContestBase,
   uTR4WTestFramework;

type
   (* The kinds one session runs -- a literal row of test data. Three since
      M11 S3, S4 and S5 part 2 deleted the prefix, DX and zone kinds; each
      column left with its kind. *)
   TSessionKinds = record
      Exchange: ExchangeType;
      InitialExchange: InitialExchangeType;
      DomesticMult: DomesticMultType;
   end;

   TContestKindPinTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure CheckKinds(const aExpected: TSessionKinds;
                           const aActual: TSessionKinds;
                           const aWho: string;
                           var aChecked: integer);
      procedure Test_EveryContestRunsItsPinnedKindsAtEveryMatrixStation;
      procedure Test_EveryPartyRunsItsPinnedKindsInItsHostState;
      procedure CheckDoing(aDomestic: boolean; const aWho: string);
      procedure Test_DoingFlagsFollowEveryContestSwitch;
   end;

(* SHARED WITH uTestPrefixMultiplierKey (M11 S3), uTestDXMultiplierKey
   (M11 S4) and uTestZoneMultiplier (M11 S5), so the pins resolve a station
   and a session exactly one way. See each body. (Since each kind's part 2
   they ask only MatrixStation and SessionContestName: the prefix, DX and
   zone kinds Kinds resolved are deleted.) *)
function MatrixStation(const aCall: string;
                       const aCountry: string;
                       aContinent: ContinentType;
                       const aState: string;
                       const aSection: string;
                       const aGrid: string;
                       aInHostState: boolean;
                       const aContestName: string): TStationContext;
function SessionContestName(aContest: ContestType; aInHostState: boolean): string;
function Kinds(aContest: ContestType; const aStation: TStationContext): TSessionKinds;

implementation

uses
   SysUtils,
   TypInfo,
   uContestRegistry,
   (* ContestSession -- the switch test writes the session as FCONTEST does
     and reads its Doing*Mults answers (M11 S2). *)
   uContestSession;

type
   (* One contest at the three stations every contest runs at. *)
   TContestKindPin = record
      Token: string;
      AtUS: TSessionKinds;
      AtVE: TSessionKinds;
      AtDX: TSessionKinds;
   end;

   (* One party at its us-host station, which is that party's own. *)
   THostKindPin = record
      Contest: ContestType;
      MyCall: string;
      MyCountry: string;
      MyState: string;
      MySection: string;
      MyGrid: string;
      Kinds: TSessionKinds;
   end;

const
   (* GENERATED ONCE AT M11 S0b -- see the unit header. Never regenerate it
      to clear a failure. *)
   KIND_PINS: array[ContestType] of TContestKindPin = (
      (* DUMMYCONTEST *)
      (Token: 'DUMMY CONTEST';
       AtUS: (Exchange: UnknownExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: UnknownExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: UnknownExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* SEVENQP *)
      (Token: '7QP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* ALLASIANCW *)
      (Token: 'ALL-ASIAN-DX-CW';
       AtUS: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* ALLASIANSSB *)
      (Token: 'ALL-ASIAN-DX-SSB';
       AtUS: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* ALLJA *)
      (Token: 'ALL JA';
       AtUS: (Exchange: RSTALLJAPrefectureAndPrecedenceExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTALLJAPrefectureAndPrecedenceExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTALLJAPrefectureAndPrecedenceExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* APSPRINT *)
      (Token: 'AP-SPRINT';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* ARCI *)
      (Token: 'ARCI';
       AtUS: (Exchange: RSTPossibleDomesticQTHAndPower; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTPossibleDomesticQTHAndPower; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTPossibleDomesticQTHAndPower; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* ARI_DX *)
      (Token: 'ARI-DX';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* ARRL10 *)
      (Token: 'ARRL-10';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* ARRLDIGI *)
      (Token: 'ARRL-DIGI';
       AtUS: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* ARRL160 *)
      (Token: 'ARRL-160';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* ARRLDXCW *)
      (Token: 'ARRL-DX-CW';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* ARRLDXSSB *)
      (Token: 'ARRL-DX-SSB';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* ARRLSSCW *)
      (Token: 'ARRL-SS-CW';
       AtUS: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile)),
      (* ARRLSSSSB *)
      (Token: 'ARRL-SS-SSB';
       AtUS: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile)),
      (* ARRLVHFJAN *)
      (Token: 'ARRL-VHF-JAN';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares)),
      (* ARRLVHFJUN *)
      (Token: 'ARRL-VHF-JUN';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares)),
      (* ARRLVHFSEP *)
      (Token: 'ARRL-VHF-SEP';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares)),
      (* ArizonaQsoParty *)
      (Token: 'ARIZONA QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* BALTIC *)
      (Token: 'BALTIC';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* BWQP *)
      (Token: 'BWQP';
       AtUS: (Exchange: RSTNameAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTNameAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTNameAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* CIS *)
      (Token: 'CIS';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* CALQSOPARTY *)
      (Token: 'CALIFORNIA QSO PARTY';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* COUNTYHUNTER *)
      (Token: 'COUNTY HUNTER';
       AtUS: (Exchange: RSTQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* CQ160CW *)
      (Token: 'CQ-160-CW';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile)),
      (* CQ160SSB *)
      (Token: 'CQ-160-SSB';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile)),
      (* CQM *)
      (Token: 'CQ-M';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* CQVHF *)
      (Token: 'CQ-VHF';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares)),
      (* CQWPXCW *)
      (Token: 'CQ-WPX-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* CQWPXSSB *)
      (Token: 'CQ-WPX-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* CQWPXRTTY *)
      (Token: 'CQ-WPX-RTTY';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* CQWWCW *)
      (Token: 'CQ-WW-CW';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: CustomInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: CustomInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: CustomInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* CQWWSSB *)
      (Token: 'CQ-WW-SSB';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* CROATIAN *)
      (Token: 'CROATIAN';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile)),
      (* CUPRFCW *)
      (Token: 'RF-CUP-CW';
       AtUS: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields);
       AtVE: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields);
       AtDX: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields)),
      (* CUPRFSSB *)
      (Token: 'RF-CUP-SSB';
       AtUS: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields);
       AtVE: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields);
       AtDX: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields)),
      (* CUPRFDIG *)
      (Token: 'RF-CUP-DIG';
       AtUS: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* CUPURAL *)
      (Token: 'URAL-CUP';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* EUSPRINT_SPRING_CW *)
      (Token: 'EU-SPRINT-SPRING-CW';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* EUROPEANHFC *)
      (Token: 'EUROPEAN HFC';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* EUROPEANVHF *)
      (Token: 'EUROPEAN VHF';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* TESLA *)
      (Token: 'HF-TESLA';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* ARRLFIELDDAY *)
      (Token: 'ARRL-FD';
       AtUS: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* FISTS *)
      (Token: 'FISTS';
       AtUS: (Exchange: RSTQTHNameAndFistsNumberOrPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTQTHNameAndFistsNumberOrPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTQTHNameAndFistsNumberOrPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* FOCMARATHON *)
      (Token: 'FOC MARATHON';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* FLORIDAQSOPARTY *)
      (Token: 'FLORIDA QSO PARTY';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* GACWWWSACW *)
      (Token: 'GACW-WWSA-CW';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* GAGARINCUP *)
      (Token: 'GAGARIN-CUP';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic)),
      (* GENERALQSO *)
      (Token: 'GENERAL QSO';
       AtUS: (Exchange: RSTNameAndQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTNameAndQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTNameAndQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* GRIDLOC *)
      (Token: 'GRID LOC';
       AtUS: (Exchange: NameAndPossibleGridSquareExchange; InitialExchange: NameInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtVE: (Exchange: NameAndPossibleGridSquareExchange; InitialExchange: NameInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtDX: (Exchange: NameAndPossibleGridSquareExchange; InitialExchange: NameInitialExchange;
              DomesticMult: WYSIWYGDomestic)),
      (* HADX *)
      (Token: 'HA DX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* YUDX *)
      (Token: 'YUDX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* UKEI *)
      (Token: 'UKEI';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* HELVETIA *)
      (Token: 'HELVETIA';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* IARU *)
      (Token: 'IARU-HF';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic)),
      (* INTERNETSPRINT *)
      (Token: 'INTERNET SPRINT';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* IOTA *)
      (Token: 'RSGB-IOTA';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: IOTADomestic);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: IOTADomestic);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: IOTADomestic)),
      (* JIDXCW *)
      (Token: 'JIDX-CW';
       AtUS: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* JIDXSSB *)
      (Token: 'JIDX-SSB';
       AtUS: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* JALONGPREFECT *)
      (Token: 'JA LONG PREFECT';
       AtUS: (Exchange: RSTLongJAPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTLongJAPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTLongJAPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* JTDX *)
      (Token: 'MONGOLIAN DX';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* KCJ *)
      (Token: 'KCJ';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile)),
      (* KIDSDAY *)
      (Token: 'KIDS DAY';
       AtUS: (Exchange: KidsDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: KidsDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: KidsDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* KVP *)
      (Token: 'KVP';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* LABRE *)
      (Token: 'LABRE';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* LZDX *)
      (Token: 'LZ DX';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile)),
      (* MARCONIMEMORIAL *)
      (Token: 'MARCONI MEMORIAL';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* MINITEST *)
      (Token: 'MINITEST';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* MINI80 *)
      (Token: 'MINI80';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* MINI40 *)
      (Token: 'MINI40';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* MICHQSOPARTY *)
      (Token: 'MICHIGAN QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* MINNQSOPARTY *)
      (Token: 'MINNESOTA QSO PARTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* MOQSOPARTY *)
      (Token: 'MISSOURI QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* NAQSOCW *)
      (Token: 'NAQP-CW';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile)),
      (* NAQSOSSB *)
      (Token: 'NAQP-SSB';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile)),
      (* NAQSORTTY *)
      (Token: 'NAQP-RTTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile)),
      (* NASPRINTCW *)
      (Token: 'NA-SPRINT-CW';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile)),
      (* SPRINTSSB *)
      (Token: 'SSB-SPRINT';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile)),
      (* NASPRINTRTTY *)
      (Token: 'NA-SPRINT-RTTY';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile)),
      (* NCCCSPRINT *)
      (Token: 'NCCC-SPRINT';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile)),
      (* NEWENGLANDQSO *)
      (Token: 'NEQP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* NCQSOPARTY *)
      (Token: 'NC QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* NRAUBALTICCW *)
      (Token: 'NRAU-BALTIC-CW';
       AtUS: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* NRAUBALTICSSB *)
      (Token: 'NRAU-BALTIC-SSB';
       AtUS: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* NZFIELDDAY *)
      (Token: 'NZ FIELD DAY';
       AtUS: (Exchange: NZFieldDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: NZFieldDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: NZFieldDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* OCEANIADXCW *)
      (Token: 'OCEANIA-DX-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* OCEANIADXSSB *)
      (Token: 'OCEANIA-DX-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* OHIOQSOPARTY *)
      (Token: 'OHIO QSO PARTY';
       AtUS: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* OKDX *)
      (Token: 'OK-OM DX CW';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* OLDNEWYEAR *)
      (Token: 'RADIO-ONY';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* OZCR_O *)
      (Token: 'OZCHR-TEAMS';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* OZCR_Z *)
      (Token: 'OZCHR';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic)),
      (* PACC *)
      (Token: 'PACC';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* POTA *)
      (Token: 'POTA';
       AtUS: (Exchange: RSTAndPOTAPark; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTAndPOTAPark; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTAndPOTAPark; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* QCWA *)
      (Token: 'QCWA';
       AtUS: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* QCWAGOLDEN *)
      (Token: 'QCWA GOLDEN';
       AtUS: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* CANADA_WINTER *)
      (Token: 'CANADA WINTER';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* RADIOVHFFD *)
      (Token: 'RF-VHF-FD';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* RAEM *)
      (Token: 'RAEM';
       AtUS: (Exchange: QSONumberAndGeoCoordinates; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: QSONumberAndGeoCoordinates; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: QSONumberAndGeoCoordinates; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* RDA *)
      (Token: 'RDAC';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: RDADistrict);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: RDADistrict);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: RDADistrict)),
      (* REGION1FIELDDAY *)
      (Token: 'REGION 1 FIELD DAY';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* REGION1FIELDDAY_RCC_CW *)
      (Token: 'REGION 1 FIELD DAY-RCC-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* REGION1FIELDDAY_RCC_SSB *)
      (Token: 'REGION 1 FIELD DAY-RCC-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* RFCHAMPIONSHIPCW *)
      (Token: 'RF-CHAMP-CW';
       AtUS: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile)),
      (* RFCHAMPIONSHIPSSB *)
      (Token: 'RF-CHAMP-SSB';
       AtUS: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile)),
      (* RFASCHAMPIONSHIPCW *)
      (Token: 'AS-CHAMP';
       AtUS: (Exchange: QSONumberAndCoordinatesSum; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: QSONumberAndCoordinatesSum; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: QSONumberAndCoordinatesSum; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* RSGB_ROPOCO_CW *)
      (Token: 'RSGB-ROPOCO-CW';
       AtUS: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* RSGB_ROPOCO_SSB *)
      (Token: 'RSGB-ROPOCO-SSB';
       AtUS: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* RSGB18 *)
      (Token: 'RSGB-160';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* RUSSIANDX *)
      (Token: 'RDXC';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* SACCW *)
      (Token: 'SAC-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* YBDX *)
      (Token: 'YBDX';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* SACSSB *)
      (Token: 'SAC-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* SALMONRUN *)
      (Token: 'SALMON RUN';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* SOUTHAMERICANWW *)
      (Token: 'SOUTH AMERICAN WW';
       AtUS: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* SPDX *)
      (Token: 'SP DX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* STEWPERRY *)
      (Token: 'STEW-PERRY';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* TENTEN *)
      (Token: 'TEN TEN';
       AtUS: (Exchange: NameQTHAndPossibleTenTenNumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: NameQTHAndPossibleTenTenNumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: NameQTHAndPossibleTenTenNumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* TEXASQSOPARTY *)
      (Token: 'TEXAS QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* TOEC *)
      (Token: 'TOEC';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields)),
      (* UA4WCHAMPIONSHIP *)
      (Token: 'R4W-CHAMP';
       AtUS: (Exchange: RSTAndGridSquareOrRDAExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtVE: (Exchange: RSTAndGridSquareOrRDAExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtDX: (Exchange: RSTAndGridSquareOrRDAExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic)),
      (* UBACW *)
      (Token: 'UBA-DX-CW';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* UBASSB *)
      (Token: 'UBA-DX-SSB';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* UCG *)
      (Token: 'UCG';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* UKRAINECHAMPIONSHIP *)
      (Token: 'UKRAINE CHAMPIONSHIP';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* UKRAINIAN *)
      (Token: 'UKRAINIAN';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* DARCWAEDCCW *)
      (Token: 'DARC-WAEDC-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* DARCWAEDCSSB *)
      (Token: 'DARC-WAEDC-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* DARCXMAS *)
      (Token: 'DARC-XMAS';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic)),
      (* WAG *)
      (Token: 'WAG';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DOKCodes);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DOKCodes);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* WISCONSINQSOPARTY *)
      (Token: 'WISCONSIN QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* WWL *)
      (Token: 'WWL';
       AtUS: (Exchange: RSTAndGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields);
       AtVE: (Exchange: RSTAndGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields);
       AtDX: (Exchange: RSTAndGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields)),
      (* WWPMC *)
      (Token: 'WW PMC';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* XMAS *)
      (Token: 'XMAS';
       AtUS: (Exchange: RSTQSONumberAndRandomCharactersExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONumberAndRandomCharactersExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONumberAndRandomCharactersExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* YODX *)
      (Token: 'YO-DX-HF';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* YOUTHCHAMPIONSHIPRF *)
      (Token: 'SRR-JR';
       AtUS: (Exchange: AgeAndQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: AgeAndQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: AgeAndQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* RU3AXMEMORIAL *)
      (Token: 'RU3AX MEMORIAL';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* LQP *)
      (Token: 'LOCUST QSO PARTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile)),
      (* ARKTIKA_SPRING *)
      (Token: 'ARKTIKA-SPRING';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic)),
      (* UNDX *)
      (Token: 'UN DX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* NYQP *)
      (Token: 'NY-QSO-PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* KINGOFSPAINCW *)
      (Token: 'KING-OF-SPAIN-CW';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* KINGOFSPAINSSB *)
      (Token: 'KING-OF-SPAIN-SSB';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* WRTC *)
      (Token: 'WRTC';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic)),
      (* TENNESSEEQSOPARTY *)
      (Token: 'TENNESSEE QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* COLORADOQSOPARTY *)
      (Token: 'COLORADO QSO PARTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* R9W_UW9WK_MEMORIAL *)
      (Token: 'R9W-UW9WK-MEMORIAL';
       AtUS: (Exchange: QSONumberAndZone; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: QSONumberAndZone; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: QSONumberAndZone; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* PCC *)
      (Token: 'PCC';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* RADIOMEMORY *)
      (Token: 'RADIO-MEMORY';
       AtUS: (Exchange: RSTAgeAndPossibleSK; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTAgeAndPossibleSK; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTAgeAndPossibleSK; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* DARC10M *)
      (Token: 'DARC-10M';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DOKCodes);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DOKCodes);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic)),
      (* REFCW *)
      (Token: 'REF-CW';
       AtUS: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* REFSSB *)
      (Token: 'REF-SSB';
       AtUS: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* BSCI *)
      (Token: 'BLACK SEA CUP';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic)),
      (* CQMM *)
      (Token: 'CQMM';
       AtUS: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* SASPRINT *)
      (Token: 'SA-SPRINT';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* CWOPS *)
      (Token: 'CWOPS';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* OZHCRVHF *)
      (Token: 'OZHCR-VHF';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares)),
      (* CANADA_DAY *)
      (Token: 'CANADA DAY';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* CQWWRTTY *)
      (Token: 'CQ-WW-RTTY';
       AtUS: (Exchange: RSTZoneAndPossibleDomesticQTHExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTZoneAndPossibleDomesticQTHExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTZoneAndPossibleDomesticQTHExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile)),
      (* CWOPEN *)
      (Token: 'CWOPEN';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* MAKROTHEN *)
      (Token: 'MAKROTHEN-RTTY';
       AtUS: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* EUSPRINT_SPRING_SSB *)
      (Token: 'EU-SPRINT-SPRING-SSB';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* EUSPRINT_AUTUMN_CW *)
      (Token: 'EU-SPRINT-AUTUMN-CW';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* EUSPRINT_AUTUMN_SSB *)
      (Token: 'EU-SPRINT-AUTUMN-SSB';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* ARRL_RTTY_ROUNDUP *)
      (Token: 'ARRL-RTTY';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* CQIR *)
      (Token: 'CQIR';
       AtUS: (Exchange: QSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* WWIH *)
      (Token: 'WWIH';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* ALRS_UA1DZ_CUP *)
      (Token: 'ALRS-UA1DZ-CUP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic)),
      (* WINTERFIELDDAY *)
      (Token: 'WINTER FIELD DAY';
       AtUS: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* RADIOYOC *)
      (Token: 'RADIO-YOC';
       AtUS: (Exchange: QSONumberAndPreviousQSONumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: QSONumberAndPreviousQSONumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: QSONumberAndPreviousQSONumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* PAQSOPARTY *)
      (Token: 'PA QSO PARTY';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* INQSOPARTY *)
      (Token: 'IN QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* OKOMSSB *)
      (Token: 'OK-OM DX SSB';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* BATAVIA_FT8 *)
      (Token: 'BATAVIA-FT8';
       AtUS: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* WWDIGI *)
      (Token: 'WWDIGI';
       AtUS: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridFields);
       AtVE: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridFields);
       AtDX: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridFields)),
      (* MWC *)
      (Token: 'MWC';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* IRTS *)
      (Token: 'IRTS';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile)),
      (* EUDX *)
      (Token: 'EUDX';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* BCQP *)
      (Token: 'BCQP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* VAQP *)
      (Token: 'VAQP';
       AtUS: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* YOTA *)
      (Token: 'YOTA';
       AtUS: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* IN7QPNE *)
      (Token: 'IN7QPNE';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* MST *)
      (Token: 'MST';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults)),
      (* SST *)
      (Token: 'SST';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile)),
      (* RTC *)
      (Token: 'RTC';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridSquares);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridSquares);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridSquares)),
      (* IDAHOQSOPARTY *)
      (Token: 'IDAHO QSO PARTY';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile)),
      (* DELAWAREQSOPARTY *)
      (Token: 'DELAWARE QSO PARTY';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile))
   );

   (* GENERATED ONCE AT M11 S0b, with the table above. One row per party
      (IsUSQSOParty), ordered by the name of its frozen matrix record. *)
   HOST_KIND_PINS: array[1..22] of THostKindPin = (
      (Contest: ArizonaQsoParty; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'APH';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: BCQP; MyCall: 'VE7AAA'; MyCountry: 'VE'; MyState: 'ABF';
       MySection: 'BC'; MyGrid: 'CN89';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: CALQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alam';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: COLORADOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ada';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: DELAWAREQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'NDE';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: FLORIDAQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alc';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: IDAHOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ADA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: IN7QPNE; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Azaph';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: INQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'INADA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: MICHQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alco';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: MINNQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ait';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: MOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ADR';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: NCQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ALA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: NYQP; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alb';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: OHIOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Adam';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: PAQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ADA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: SALMONRUN; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ada';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: SEVENQP; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Azaph';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: TENNESSEEQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ande';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: TEXASQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ande';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: VAQP; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ACC';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile)),
      (Contest: WISCONSINQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ada';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile))
   );

(* A matrix station -- see the unit header for where each field comes from. *)
function MatrixStation(const aCall: string;
                       const aCountry: string;
                       aContinent: ContinentType;
                       const aState: string;
                       const aSection: string;
                       const aGrid: string;
                       aInHostState: boolean;
                       const aContestName: string): TStationContext;
begin
   (* Default, NOT uTestContestObjects.NoStation. NoStation FillChars its
      result, and a record result is the CALLER's temporary, reused on every
      iteration here: zeroing it drops the strings the last station left in
      it without releasing them. Measured at S0b: +108 unfreed blocks under
      -Checked, and a scratch copy of this exact shape crashed. Default
      assigns, so the old strings are released. *)
   Result := Default(TStationContext);
   Result.MyCall := aCall;
   Result.MyCountry := CallString(aCountry);
   Result.MyContinent := aContinent;
   Result.MyState := aState;
   Result.MySection := aSection;
   Result.MyGrid := aGrid;
   Result.MyName := 'TOM';
   Result.MyFDClass := '1A';
   Result.MyCheck := '99';
   Result.MyPrec := 'A';
   Result.InHostState := aInHostState;
   Result.ContestName := aContestName;
end;

(* Settings.Contest.Name as FoundContest leaves it: the spelling, and for a
   party the in-state or out-of-state suffix. *)
function SessionContestName(aContest: ContestType; aInHostState: boolean): string;
begin
   Result := string(ContestTypeSA[aContest]);
   if ContestIdentity(aContest).IsUSQSOParty then
      begin
      if aInHostState then
         begin
         Result := Result + ' (in state)';
         end
      else
         begin
         Result := Result + ' (out of state)';
         end;
      end;
end;

(* The kinds aContest's session runs at aStation, resolved as FCONTEST
   resolves them: ApplyContestTraits writes the trait, then
   ApplySessionDefaults writes each value DescribeSession stated. The
   identity is the one FoundContest asks. *)
function Kinds(aContest: ContestType; const aStation: TStationContext): TSessionKinds;
var
   definition: TContestBase;
   stated: TSessionDefaults;
begin
   definition := ContestIdentity(aContest);
   Result.Exchange := definition.ExchangeKind;
   Result.InitialExchange := definition.InitialExchangeKind;
   Result.DomesticMult := definition.DomesticMultiplierType;
   stated := TSessionDefaults.Create;
   try
      definition.DescribeSession(aStation, stated);
      if stated.IsStated(svExchange) then
         begin
         Result.Exchange := stated.Exchange;
         end;
      if stated.IsStated(svInitialExchange) then
         begin
         Result.InitialExchange := stated.InitialExchange;
         end;
      if stated.IsStated(svDomesticMult) then
         begin
         Result.DomesticMult := stated.DomesticMult;
         end;
   finally
      stated.Free;
      end;
end;

function SameKinds(const a: TSessionKinds; const b: TSessionKinds): boolean;
begin
   Result := (a.Exchange = b.Exchange)               and
             (a.InitialExchange = b.InitialExchange) and
             (a.DomesticMult = b.DomesticMult);
end;

(* A kind's member, by name -- GetEnumName answers an AnsiString. *)
function KindName(aInfo: PTypeInfo; aOrdinal: integer): string;
begin
   Result := string(GetEnumName(aInfo, aOrdinal));
end;

(* Three assertions, by name, so a failure reads as the kind that moved. *)
procedure TContestKindPinTests.CheckKinds(const aExpected: TSessionKinds;
                                          const aActual: TSessionKinds;
                                          const aWho: string;
                                          var aChecked: integer);
begin
   CheckEquals(KindName(TypeInfo(ExchangeType), Ord(aExpected.Exchange)),
               KindName(TypeInfo(ExchangeType), Ord(aActual.Exchange)),
               aWho + ' exchange');
   CheckEquals(KindName(TypeInfo(InitialExchangeType), Ord(aExpected.InitialExchange)),
               KindName(TypeInfo(InitialExchangeType), Ord(aActual.InitialExchange)),
               aWho + ' initial exchange');
   CheckEquals(KindName(TypeInfo(DomesticMultType), Ord(aExpected.DomesticMult)),
               KindName(TypeInfo(DomesticMultType), Ord(aActual.DomesticMult)),
               aWho + ' domestic multiplier');
   Inc(aChecked, 3);
end;

procedure TContestKindPinTests.RunAllTests;
begin
   Test_EveryContestRunsItsPinnedKindsAtEveryMatrixStation;
   Test_EveryPartyRunsItsPinnedKindsInItsHostState;
   Test_DoingFlagsFollowEveryContestSwitch;
end;

procedure TContestKindPinTests.Test_EveryContestRunsItsPinnedKindsAtEveryMatrixStation;
var
   c: ContestType;
   pin: TContestKindPin;
   who: string;
   kindsUS: TSessionKinds;
   kindsVE: TSessionKinds;
   kindsDX: TSessionKinds;
   contests: integer;
   checked: integer;
   varying: integer;
begin
   BeginTest('Test_EveryContestRunsItsPinnedKindsAtEveryMatrixStation');
   contests := 0;
   checked := 0;
   varying := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      pin := KIND_PINS[c];
      who := string(ContestTypeSA[c]);
      (* THE ROW IS THIS CONTEST'S, before any value is believed. *)
      CheckEquals(pin.Token, who, 'row ' + IntToStr(Ord(c)) + ' is ' + pin.Token);

      kindsUS := Kinds(c, MatrixStation('K0AAA', 'K', NorthAmerica, 'KS', 'KS', 'EM17',
                                     False, SessionContestName(c, False)));
      kindsVE := Kinds(c, MatrixStation('VE3AAA', 'VE', NorthAmerica, 'ON', 'ON', 'FN03',
                                     False, SessionContestName(c, False)));
      kindsDX := Kinds(c, MatrixStation('DL1AAA', 'DL', Europe, '', 'DX', 'JO62',
                                     False, SessionContestName(c, False)));
      CheckKinds(pin.AtUS, kindsUS, who + ' at us', checked);
      CheckKinds(pin.AtVE, kindsVE, who + ' at ve', checked);
      CheckKinds(pin.AtDX, kindsDX, who + ' at dx', checked);
      if not (SameKinds(kindsUS, kindsVE) and SameKinds(kindsUS, kindsDX)) then
         begin
         Inc(varying);
         end;
      Inc(contests);
      end;

   (* EXACT: every ContestType, DUMMYCONTEST included, three kinds at three
      stations (six until M11 S3 part 2, five until S4 part 2, four until
      S5 part 2). *)
   CheckEquals(187, contests, 'contests whose kinds were checked');
   CheckEquals(187, Ord(High(ContestType)) + 1,
               'ContestType members -- a new contest adds its row here, by hand');
   CheckEquals(187 * 3 * 3, checked, 'kind assertions at us, ve and dx');
   (* THE STATION REACHES THE KINDS: at S0b these contests run another kind
      at one of us, ve and dx than at another -- ARRL160, ARRLDXCW,
      ARRLDXSSB, WAG, DARC10M. The rows determine this count, so it cannot
      move while they are green; it is stated so a reader sees the station
      reach the kinds. It was 7 until M11 S4 part 2 removed the DX column:
      DARCWAEDCCW and DARCWAEDCSSB varied in their DX kind only. The zone
      column (M11 S5 part 2) varied for no contest at these stations, so
      removing it left the count at 5. *)
   CheckEquals(5, varying, 'contests whose kinds vary across us, ve and dx');
end;

procedure TContestKindPinTests.Test_EveryPartyRunsItsPinnedKindsInItsHostState;
var
   n: integer;
   c: ContestType;
   pin: THostKindPin;
   who: string;
   kindsHost: TSessionKinds;
   kindsUS: TSessionKinds;
   seen: array[ContestType] of integer;
   parties: integer;
   checked: integer;
   varying: integer;
begin
   BeginTest('Test_EveryPartyRunsItsPinnedKindsInItsHostState');
   for c := Low(ContestType) to High(ContestType) do
      begin
      seen[c] := 0;
      end;
   checked := 0;
   varying := 0;
   for n := Low(HOST_KIND_PINS) to High(HOST_KIND_PINS) do
      begin
      pin := HOST_KIND_PINS[n];
      who := string(ContestTypeSA[pin.Contest]);
      Inc(seen[pin.Contest]);
      CheckTrue(ContestIdentity(pin.Contest).IsUSQSOParty,
                who + ': a us-host row belongs to a party');
      kindsHost := Kinds(pin.Contest,
                      MatrixStation(pin.MyCall, pin.MyCountry, NorthAmerica,
                                    pin.MyState, pin.MySection, pin.MyGrid,
                                    True, SessionContestName(pin.Contest, True)));
      CheckKinds(pin.Kinds, kindsHost, who + ' at us-host', checked);
      kindsUS := Kinds(pin.Contest, MatrixStation('K0AAA', 'K', NorthAmerica, 'KS', 'KS', 'EM17',
                                               False, SessionContestName(pin.Contest, False)));
      if not SameKinds(kindsHost, kindsUS) then
         begin
         Inc(varying);
         end;
      end;

   (* EVERY PARTY HAS EXACTLY ONE us-host ROW, and nothing else has one. *)
   parties := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if ContestIdentity(c).IsUSQSOParty then
         begin
         Inc(parties);
         CheckEquals(1, seen[c], string(ContestTypeSA[c]) + ': its us-host rows');
         end
      else
         begin
         CheckEquals(0, seen[c], string(ContestTypeSA[c]) + ': not a party, so no us-host row');
         end;
      end;

   CheckEquals(22, parties, 'parties -- a new party adds its us-host row here, by hand');
   CheckEquals(22 * 3, checked, 'kind assertions at us-host');
   (* IN THE HOST STATE THE KINDS DIFFER FROM THE us STATION'S for these
      parties at S0b -- ArizonaQsoParty, CALQSOPARTY, SALMONRUN, SEVENQP,
      TEXASQSOPARTY. It was 6 until M11 S4 part 2 removed the DX column:
      DELAWAREQSOPARTY differed in its DX kind only. No party differed in
      its zone kind (M11 S5 part 2). *)
   CheckEquals(5, varying, 'parties whose kinds differ in the host state');
end;

(* The session's one "does it count this kind" answer, by name. Prefix, DX
   and zone left the session at M11 S3, S4 and S5 part 2 with their kinds:
   the contest answers them (TContestBase.HasPrefixMultiplier,
   HasDXMultiplier and HasZoneMultiplier, pinned by uTestPrefixMultiplierKey,
   uTestDXMultiplierKey and uTestZoneMultiplier), and an answer with no
   store cannot go stale. *)
procedure TContestKindPinTests.CheckDoing(aDomestic: boolean;
                                          const aWho: string);
begin
   CheckTrue(aDomestic = ContestSession.DoingDomesticMults, aWho + ' doing domestic');
end;

(* THE Doing*Mults FLAGS FOLLOW A CONTEST CHANGED WITHOUT A RESTART -- M11 S2,
  2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md F9, S0d).

  THE DEFECT. LOGDUPE held the four flags as globals, and LogCfg derived them
  ONCE, at start-up, from the session's kinds. FoundContest rewrites the
  kinds every time it runs, and it runs again when a multi-op peer sends a
  CONTEST line (uNet -> ApplyPeerCommand -> uSettingsEffects ->
  FoundContest). Measured at S0d on exactly that path, in the program: a CQ
  WW CW session switched to ARRL SS CW ran DomesticFile and no DX, prefix or
  zone multiplier, while the flags stayed at CQ WW's FALSE TRUE FALSE TRUE.

  THE FIX IS STRUCTURAL. The flags are ContestSession's answers, computed
  from the kinds on every read, so there is no second store to go stale. This
  pins that in two halves:

    * EVERY MEMBER of each multiplier kind, written through the session's
      writer, is answered at once -- no write path can leave a flag behind;
    * THE SWITCH, at each matrix station: the four kinds each contest
      resolves to (Kinds, FCONTEST's two writes) written over the previous
      contest's, contest after contest through the whole ContestType range,
      and S0d's measured pair, CQ WW CW then ARRL SS CW, by literal.

  WHAT THIS DOES NOT DRIVE: FoundContest itself. It writes Settings, the
  domestic country list and the contest title, which this binary's other
  suites read, so no unit test calls it; what it writes into the session is
  Kinds, pinned row by row above. The peer path end to end is a bench check. *)
procedure TContestKindPinTests.Test_DoingFlagsFollowEveryContestSwitch;
const
   CALLS: array[0..2] of string = ('K0AAA', 'VE3AAA', 'DL1AAA');
   COUNTRIES: array[0..2] of string = ('K', 'VE', 'DL');
   CONTINENTS: array[0..2] of ContinentType = (NorthAmerica, NorthAmerica, Europe);
   STATES: array[0..2] of string = ('KS', 'ON', '');
   SECTIONS: array[0..2] of string = ('KS', 'ON', 'DX');
   GRIDS: array[0..2] of string = ('EM17', 'FN03', 'JO62');
var
   saved: TSessionKinds;
   resolved: TSessionKinds;
   d: DomesticMultType;
   c: ContestType;
   s: integer;
   who: string;
   switches: integer;

   (* What FoundContest leaves in the session: all three kinds, written over
      whatever the previous contest left. *)
   procedure WriteSession(const aKinds: TSessionKinds);
   begin
      ContestSession.WriteExchange(aKinds.Exchange);
      ContestSession.WriteInitialExchange(aKinds.InitialExchange);
      ContestSession.WriteDomesticMult(aKinds.DomesticMult);
   end;

   function StationFor(aIndex: integer; aContest: ContestType): TStationContext;
   begin
      Result := MatrixStation(CALLS[aIndex], COUNTRIES[aIndex], CONTINENTS[aIndex],
                              STATES[aIndex], SECTIONS[aIndex], GRIDS[aIndex],
                              False, SessionContestName(aContest, False));
   end;

begin
   BeginTest('Test_DoingFlagsFollowEveryContestSwitch');
   saved.Exchange := ContestSession.Exchange;
   saved.InitialExchange := ContestSession.InitialExchange;
   saved.DomesticMult := ContestSession.DomesticMult;
   try
      (* EVERY MEMBER, ONE KIND AT A TIME. *)
      for d := Low(DomesticMultType) to High(DomesticMultType) do
         begin
         ContestSession.WriteDomesticMult(d);
         CheckTrue((d <> NoDomesticMults) = ContestSession.DoingDomesticMults,
                   KindName(TypeInfo(DomesticMultType), Ord(d)));
         end;

      switches := 0;
      for s := Low(CALLS) to High(CALLS) do
         begin
         (* S0d's MEASURED CASE, by literal. *)
         WriteSession(Kinds(CQWWCW, StationFor(s, CQWWCW)));
         CheckDoing(False, 'CQ WW CW at ' + CALLS[s]);
         WriteSession(Kinds(ARRLSSCW, StationFor(s, ARRLSSCW)));
         CheckDoing(True,
                    'CQ WW CW switched to ARRL SS CW at ' + CALLS[s]);

         (* EVERY CONTEST, switched to from the one before it. *)
         for c := Low(ContestType) to High(ContestType) do
            begin
            resolved := Kinds(c, StationFor(s, c));
            WriteSession(resolved);
            who := string(ContestTypeSA[c]) + ' at ' + CALLS[s];
            CheckDoing(resolved.DomesticMult <> NoDomesticMults,
                       who);
            Inc(switches);
            end;
         end;
      CheckEquals(187 * 3, switches, 'contest switches checked at us, ve and dx');
   finally
      WriteSession(saved);
      end;
end;

end.
