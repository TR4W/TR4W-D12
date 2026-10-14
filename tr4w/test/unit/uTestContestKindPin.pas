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
  kinds at S0b; five since M11 S3 part 2 deleted the prefix kind, whose
  column left this unit in that commit (a column removed, not a table
  regenerated -- see below).

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
  entrant as well, which is the branch these stations would have chosen.)

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
   (* The kinds one session runs -- a literal row of test data. Five since
      M11 S3 part 2 deleted the prefix kind; its column left with it. *)
   TSessionKinds = record
      Exchange: ExchangeType;
      InitialExchange: InitialExchangeType;
      DomesticMult: DomesticMultType;
      DXMult: DXMultType;
      ZoneMult: ZoneMultType;
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
      procedure CheckDoing(aDomestic, aDX, aZone: boolean; const aWho: string);
      procedure Test_DoingFlagsFollowEveryContestSwitch;
   end;

(* SHARED WITH uTestPrefixMultiplierKey (M11 S3), so the two pins resolve a
   station and a session exactly one way. See each body. (Since M11 S3 part 2
   it asks only MatrixStation and SessionContestName: the prefix kind Kinds
   resolved is deleted.) *)
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
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: UnknownExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: UnknownExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* SEVENQP *)
      (Token: '7QP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ALLASIANCW *)
      (Token: 'ALL-ASIAN-DX-CW';
       AtUS: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ALLASIANSSB *)
      (Token: 'ALL-ASIAN-DX-SSB';
       AtUS: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ALLJA *)
      (Token: 'ALL JA';
       AtUS: (Exchange: RSTALLJAPrefectureAndPrecedenceExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTALLJAPrefectureAndPrecedenceExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTALLJAPrefectureAndPrecedenceExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* APSPRINT *)
      (Token: 'AP-SPRINT';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ARCI *)
      (Token: 'ARCI';
       AtUS: (Exchange: RSTPossibleDomesticQTHAndPower; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSACanadaKH6OrKL7; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTPossibleDomesticQTHAndPower; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSACanadaKH6OrKL7; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTPossibleDomesticQTHAndPower; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSACanadaKH6OrKL7; ZoneMult: NoZoneMults)),
      (* ARI_DX *)
      (Token: 'ARI-DX';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoIOrIS0; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoIOrIS0; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoIOrIS0; ZoneMult: NoZoneMults)),
      (* ARRL10 *)
      (Token: 'ARRL-10';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults)),
      (* ARRLDIGI *)
      (Token: 'ARRL-DIGI';
       AtUS: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ARRL160 *)
      (Token: 'ARRL-160';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ARRLDXCW *)
      (Token: 'ARRL-DX-CW';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ARRLDXSSB *)
      (Token: 'ARRL-DX-SSB';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ARRLSSCW *)
      (Token: 'ARRL-SS-CW';
       AtUS: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ARRLSSSSB *)
      (Token: 'ARRL-SS-SSB';
       AtUS: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ARRLVHFJAN *)
      (Token: 'ARRL-VHF-JAN';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ARRLVHFJUN *)
      (Token: 'ARRL-VHF-JUN';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ARRLVHFSEP *)
      (Token: 'ARRL-VHF-SEP';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ArizonaQsoParty *)
      (Token: 'ARIZONA QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults)),
      (* BALTIC *)
      (Token: 'BALTIC';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* BWQP *)
      (Token: 'BWQP';
       AtUS: (Exchange: RSTNameAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTNameAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTNameAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* CIS *)
      (Token: 'CIS';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults)),
      (* CALQSOPARTY *)
      (Token: 'CALIFORNIA QSO PARTY';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* COUNTYHUNTER *)
      (Token: 'COUNTY HUNTER';
       AtUS: (Exchange: RSTQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* CQ160CW *)
      (Token: 'CQ-160-CW';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults)),
      (* CQ160SSB *)
      (Token: 'CQ-160-SSB';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults)),
      (* CQM *)
      (Token: 'CQ-M';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* CQVHF *)
      (Token: 'CQ-VHF';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* CQWPXCW *)
      (Token: 'CQ-WPX-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* CQWPXSSB *)
      (Token: 'CQ-WPX-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* CQWPXRTTY *)
      (Token: 'CQ-WPX-RTTY';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* CQWWCW *)
      (Token: 'CQ-WW-CW';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: CustomInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: CustomInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: CustomInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones)),
      (* CQWWSSB *)
      (Token: 'CQ-WW-SSB';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones)),
      (* CROATIAN *)
      (Token: 'CROATIAN';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: ITUZones);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: ITUZones);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: ITUZones)),
      (* CUPRFCW *)
      (Token: 'RF-CUP-CW';
       AtUS: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* CUPRFSSB *)
      (Token: 'RF-CUP-SSB';
       AtUS: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* CUPRFDIG *)
      (Token: 'RF-CUP-DIG';
       AtUS: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* CUPURAL *)
      (Token: 'URAL-CUP';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* EUSPRINT_SPRING_CW *)
      (Token: 'EU-SPRINT-SPRING-CW';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* EUROPEANHFC *)
      (Token: 'EUROPEAN HFC';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: EUHFCYear);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: EUHFCYear);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: EUHFCYear)),
      (* EUROPEANVHF *)
      (Token: 'EUROPEAN VHF';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* TESLA *)
      (Token: 'HF-TESLA';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ARRLFIELDDAY *)
      (Token: 'ARRL-FD';
       AtUS: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* FISTS *)
      (Token: 'FISTS';
       AtUS: (Exchange: RSTQTHNameAndFistsNumberOrPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQTHNameAndFistsNumberOrPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQTHNameAndFistsNumberOrPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* FOCMARATHON *)
      (Token: 'FOC MARATHON';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* FLORIDAQSOPARTY *)
      (Token: 'FLORIDA QSO PARTY';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults)),
      (* GACWWWSACW *)
      (Token: 'GACW-WWSA-CW';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones)),
      (* GAGARINCUP *)
      (Token: 'GAGARIN-CUP';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones)),
      (* GENERALQSO *)
      (Token: 'GENERAL QSO';
       AtUS: (Exchange: RSTNameAndQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTNameAndQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTNameAndQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* GRIDLOC *)
      (Token: 'GRID LOC';
       AtUS: (Exchange: NameAndPossibleGridSquareExchange; InitialExchange: NameInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: NameAndPossibleGridSquareExchange; InitialExchange: NameInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: NameAndPossibleGridSquareExchange; InitialExchange: NameInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* HADX *)
      (Token: 'HA DX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* YUDX *)
      (Token: 'YUDX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* UKEI *)
      (Token: 'UKEI';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* HELVETIA *)
      (Token: 'HELVETIA';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* IARU *)
      (Token: 'IARU-HF';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones)),
      (* INTERNETSPRINT *)
      (Token: 'INTERNET SPRINT';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults)),
      (* IOTA *)
      (Token: 'RSGB-IOTA';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: IOTADomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: IOTADomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: IOTADomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* JIDXCW *)
      (Token: 'JIDX-CW';
       AtUS: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* JIDXSSB *)
      (Token: 'JIDX-SSB';
       AtUS: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* JALONGPREFECT *)
      (Token: 'JA LONG PREFECT';
       AtUS: (Exchange: RSTLongJAPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTLongJAPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTLongJAPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* JTDX *)
      (Token: 'MONGOLIAN DX';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCCWithNoJT; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCCWithNoJT; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCCWithNoJT; ZoneMult: NoZoneMults)),
      (* KCJ *)
      (Token: 'KCJ';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* KIDSDAY *)
      (Token: 'KIDS DAY';
       AtUS: (Exchange: KidsDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: KidsDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: KidsDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* KVP *)
      (Token: 'KVP';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: EUHFCYear);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: EUHFCYear);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: EUHFCYear)),
      (* LABRE *)
      (Token: 'LABRE';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults)),
      (* LZDX *)
      (Token: 'LZ DX';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: ITUZones);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: ITUZones);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: ITUZones)),
      (* MARCONIMEMORIAL *)
      (Token: 'MARCONI MEMORIAL';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* MINITEST *)
      (Token: 'MINITEST';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* MINI80 *)
      (Token: 'MINI80';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* MINI40 *)
      (Token: 'MINI40';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* MICHQSOPARTY *)
      (Token: 'MICHIGAN QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* MINNQSOPARTY *)
      (Token: 'MINNESOTA QSO PARTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* MOQSOPARTY *)
      (Token: 'MISSOURI QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* NAQSOCW *)
      (Token: 'NAQP-CW';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults)),
      (* NAQSOSSB *)
      (Token: 'NAQP-SSB';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults)),
      (* NAQSORTTY *)
      (Token: 'NAQP-RTTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults)),
      (* NASPRINTCW *)
      (Token: 'NA-SPRINT-CW';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults)),
      (* SPRINTSSB *)
      (Token: 'SSB-SPRINT';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* NASPRINTRTTY *)
      (Token: 'NA-SPRINT-RTTY';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults)),
      (* NCCCSPRINT *)
      (Token: 'NCCC-SPRINT';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* NEWENGLANDQSO *)
      (Token: 'NEQP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* NCQSOPARTY *)
      (Token: 'NC QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* NRAUBALTICCW *)
      (Token: 'NRAU-BALTIC-CW';
       AtUS: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* NRAUBALTICSSB *)
      (Token: 'NRAU-BALTIC-SSB';
       AtUS: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* NZFIELDDAY *)
      (Token: 'NZ FIELD DAY';
       AtUS: (Exchange: NZFieldDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: BranchZones);
       AtVE: (Exchange: NZFieldDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: BranchZones);
       AtDX: (Exchange: NZFieldDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: BranchZones)),
      (* OCEANIADXCW *)
      (Token: 'OCEANIA-DX-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* OCEANIADXSSB *)
      (Token: 'OCEANIA-DX-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* OHIOQSOPARTY *)
      (Token: 'OHIO QSO PARTY';
       AtUS: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* OKDX *)
      (Token: 'OK-OM DX CW';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* OLDNEWYEAR *)
      (Token: 'RADIO-ONY';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* OZCR_O *)
      (Token: 'OZCHR-TEAMS';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: ITUZones);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: ITUZones);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: ITUZones)),
      (* OZCR_Z *)
      (Token: 'OZCHR';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones)),
      (* PACC *)
      (Token: 'PACC';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* POTA *)
      (Token: 'POTA';
       AtUS: (Exchange: RSTAndPOTAPark; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndPOTAPark; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndPOTAPark; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* QCWA *)
      (Token: 'QCWA';
       AtUS: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* QCWAGOLDEN *)
      (Token: 'QCWA GOLDEN';
       AtUS: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* CANADA_WINTER *)
      (Token: 'CANADA WINTER';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* RADIOVHFFD *)
      (Token: 'RF-VHF-FD';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* RAEM *)
      (Token: 'RAEM';
       AtUS: (Exchange: QSONumberAndGeoCoordinates; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberAndGeoCoordinates; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberAndGeoCoordinates; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* RDA *)
      (Token: 'RDAC';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: RDADistrict; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: RDADistrict; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: RDADistrict; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* REGION1FIELDDAY *)
      (Token: 'REGION 1 FIELD DAY';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* REGION1FIELDDAY_RCC_CW *)
      (Token: 'REGION 1 FIELD DAY-RCC-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* REGION1FIELDDAY_RCC_SSB *)
      (Token: 'REGION 1 FIELD DAY-RCC-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* RFCHAMPIONSHIPCW *)
      (Token: 'RF-CHAMP-CW';
       AtUS: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: RFChampionchipZones);
       AtVE: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: RFChampionchipZones);
       AtDX: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: RFChampionchipZones)),
      (* RFCHAMPIONSHIPSSB *)
      (Token: 'RF-CHAMP-SSB';
       AtUS: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: RFChampionchipZones);
       AtVE: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: RFChampionchipZones);
       AtDX: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: RFChampionchipZones)),
      (* RFASCHAMPIONSHIPCW *)
      (Token: 'AS-CHAMP';
       AtUS: (Exchange: QSONumberAndCoordinatesSum; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberAndCoordinatesSum; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberAndCoordinatesSum; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* RSGB_ROPOCO_CW *)
      (Token: 'RSGB-ROPOCO-CW';
       AtUS: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* RSGB_ROPOCO_SSB *)
      (Token: 'RSGB-ROPOCO-SSB';
       AtUS: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* RSGB18 *)
      (Token: 'RSGB-160';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* RUSSIANDX *)
      (Token: 'RDXC';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults)),
      (* SACCW *)
      (Token: 'SAC-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* YBDX *)
      (Token: 'YBDX';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCC; ZoneMult: NoZoneMults)),
      (* SACSSB *)
      (Token: 'SAC-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* SALMONRUN *)
      (Token: 'SALMON RUN';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* SOUTHAMERICANWW *)
      (Token: 'SOUTH AMERICAN WW';
       AtUS: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* SPDX *)
      (Token: 'SP DX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* STEWPERRY *)
      (Token: 'STEW-PERRY';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* TENTEN *)
      (Token: 'TEN TEN';
       AtUS: (Exchange: NameQTHAndPossibleTenTenNumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: NameQTHAndPossibleTenTenNumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: NameQTHAndPossibleTenTenNumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* TEXASQSOPARTY *)
      (Token: 'TEXAS QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* TOEC *)
      (Token: 'TOEC';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* UA4WCHAMPIONSHIP *)
      (Token: 'R4W-CHAMP';
       AtUS: (Exchange: RSTAndGridSquareOrRDAExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndGridSquareOrRDAExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndGridSquareOrRDAExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* UBACW *)
      (Token: 'UBA-DX-CW';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQUBAEuropeanCountries; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQUBAEuropeanCountries; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQUBAEuropeanCountries; ZoneMult: NoZoneMults)),
      (* UBASSB *)
      (Token: 'UBA-DX-SSB';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQUBAEuropeanCountries; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQUBAEuropeanCountries; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQUBAEuropeanCountries; ZoneMult: NoZoneMults)),
      (* UCG *)
      (Token: 'UCG';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* UKRAINECHAMPIONSHIP *)
      (Token: 'UKRAINE CHAMPIONSHIP';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* UKRAINIAN *)
      (Token: 'UKRAINIAN';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* DARCWAEDCCW *)
      (Token: 'DARC-WAEDC-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQEuropeanCountries; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQEuropeanCountries; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* DARCWAEDCSSB *)
      (Token: 'DARC-WAEDC-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQEuropeanCountries; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQEuropeanCountries; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* DARCXMAS *)
      (Token: 'DARC-XMAS';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* WAG *)
      (Token: 'WAG';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DOKCodes; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DOKCodes; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* WISCONSINQSOPARTY *)
      (Token: 'WISCONSIN QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* WWL *)
      (Token: 'WWL';
       AtUS: (Exchange: RSTAndGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* WWPMC *)
      (Token: 'WW PMC';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* XMAS *)
      (Token: 'XMAS';
       AtUS: (Exchange: RSTQSONumberAndRandomCharactersExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndRandomCharactersExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndRandomCharactersExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* YODX *)
      (Token: 'YO-DX-HF';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults)),
      (* YOUTHCHAMPIONSHIPRF *)
      (Token: 'SRR-JR';
       AtUS: (Exchange: AgeAndQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: AgeAndQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: AgeAndQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults)),
      (* RU3AXMEMORIAL *)
      (Token: 'RU3AX MEMORIAL';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults)),
      (* LQP *)
      (Token: 'LOCUST QSO PARTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ARKTIKA_SPRING *)
      (Token: 'ARKTIKA-SPRING';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* UNDX *)
      (Token: 'UN DX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults)),
      (* NYQP *)
      (Token: 'NY-QSO-PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* KINGOFSPAINCW *)
      (Token: 'KING-OF-SPAIN-CW';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* KINGOFSPAINSSB *)
      (Token: 'KING-OF-SPAIN-SSB';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* WRTC *)
      (Token: 'WRTC';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: ARRLDXCC; ZoneMult: NoZoneMults)),
      (* TENNESSEEQSOPARTY *)
      (Token: 'TENNESSEE QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* COLORADOQSOPARTY *)
      (Token: 'COLORADO QSO PARTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* R9W_UW9WK_MEMORIAL *)
      (Token: 'R9W-UW9WK-MEMORIAL';
       AtUS: (Exchange: QSONumberAndZone; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberAndZone; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberAndZone; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* PCC *)
      (Token: 'PCC';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* RADIOMEMORY *)
      (Token: 'RADIO-MEMORY';
       AtUS: (Exchange: RSTAgeAndPossibleSK; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAgeAndPossibleSK; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAgeAndPossibleSK; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* DARC10M *)
      (Token: 'DARC-10M';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DOKCodes; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DOKCodes; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* REFCW *)
      (Token: 'REF-CW';
       AtUS: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* REFSSB *)
      (Token: 'REF-SSB';
       AtUS: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* BSCI *)
      (Token: 'BLACK SEA CUP';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: BlackSeaCountries; ZoneMult: ITUZones);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: BlackSeaCountries; ZoneMult: ITUZones);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: BlackSeaCountries; ZoneMult: ITUZones)),
      (* CQMM *)
      (Token: 'CQMM';
       AtUS: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* SASPRINT *)
      (Token: 'SA-SPRINT';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* CWOPS *)
      (Token: 'CWOPS';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* OZHCRVHF *)
      (Token: 'OZHCR-VHF';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* CANADA_DAY *)
      (Token: 'CANADA DAY';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* CQWWRTTY *)
      (Token: 'CQ-WW-RTTY';
       AtUS: (Exchange: RSTZoneAndPossibleDomesticQTHExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: CQZones);
       AtVE: (Exchange: RSTZoneAndPossibleDomesticQTHExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: CQZones);
       AtDX: (Exchange: RSTZoneAndPossibleDomesticQTHExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: CQZones)),
      (* CWOPEN *)
      (Token: 'CWOPEN';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: CQZones);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: CQZones);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: CQZones)),
      (* MAKROTHEN *)
      (Token: 'MAKROTHEN-RTTY';
       AtUS: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* EUSPRINT_SPRING_SSB *)
      (Token: 'EU-SPRINT-SPRING-SSB';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* EUSPRINT_AUTUMN_CW *)
      (Token: 'EU-SPRINT-AUTUMN-CW';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* EUSPRINT_AUTUMN_SSB *)
      (Token: 'EU-SPRINT-AUTUMN-SSB';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* ARRL_RTTY_ROUNDUP *)
      (Token: 'ARRL-RTTY';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults)),
      (* CQIR *)
      (Token: 'CQIR';
       AtUS: (Exchange: QSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* WWIH *)
      (Token: 'WWIH';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones)),
      (* ALRS_UA1DZ_CUP *)
      (Token: 'ALRS-UA1DZ-CUP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* WINTERFIELDDAY *)
      (Token: 'WINTER FIELD DAY';
       AtUS: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults);
       AtVE: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults);
       AtDX: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults)),
      (* RADIOYOC *)
      (Token: 'RADIO-YOC';
       AtUS: (Exchange: QSONumberAndPreviousQSONumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberAndPreviousQSONumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberAndPreviousQSONumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCC; ZoneMult: NoZoneMults)),
      (* PAQSOPARTY *)
      (Token: 'PA QSO PARTY';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* INQSOPARTY *)
      (Token: 'IN QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* OKOMSSB *)
      (Token: 'OK-OM DX SSB';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* BATAVIA_FT8 *)
      (Token: 'BATAVIA-FT8';
       AtUS: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* WWDIGI *)
      (Token: 'WWDIGI';
       AtUS: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* MWC *)
      (Token: 'MWC';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* IRTS *)
      (Token: 'IRTS';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* EUDX *)
      (Token: 'EUDX';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults)),
      (* BCQP *)
      (Token: 'BCQP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* VAQP *)
      (Token: 'VAQP';
       AtUS: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* YOTA *)
      (Token: 'YOTA';
       AtUS: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* IN7QPNE *)
      (Token: 'IN7QPNE';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* MST *)
      (Token: 'MST';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* SST *)
      (Token: 'SST';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults)),
      (* RTC *)
      (Token: 'RTC';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (* IDAHOQSOPARTY *)
      (Token: 'IDAHO QSO PARTY';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults)),
      (* DELAWAREQSOPARTY *)
      (Token: 'DELAWARE QSO PARTY';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults))
   );

   (* GENERATED ONCE AT M11 S0b, with the table above. One row per party
      (IsUSQSOParty), ordered by the name of its frozen matrix record. *)
   HOST_KIND_PINS: array[1..22] of THostKindPin = (
      (Contest: ArizonaQsoParty; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'APH';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults)),
      (Contest: BCQP; MyCall: 'VE7AAA'; MyCountry: 'VE'; MyState: 'ABF';
       MySection: 'BC'; MyGrid: 'CN89';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (Contest: CALQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alam';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (Contest: COLORADOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ada';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (Contest: DELAWAREQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'NDE';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSACanadaKH6OrKL7; ZoneMult: NoZoneMults)),
      (Contest: FLORIDAQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alc';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults)),
      (Contest: IDAHOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ADA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults)),
      (Contest: IN7QPNE; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Azaph';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (Contest: INQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'INADA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (Contest: MICHQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alco';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (Contest: MINNQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ait';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (Contest: MOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ADR';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (Contest: NCQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ALA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (Contest: NYQP; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alb';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (Contest: OHIOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Adam';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (Contest: PAQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ADA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (Contest: SALMONRUN; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ada';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults)),
      (Contest: SEVENQP; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Azaph';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSACanadaKH6OrKL7; ZoneMult: NoZoneMults)),
      (Contest: TENNESSEEQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ande';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (Contest: TEXASQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ande';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSACanadaKH6OrKL7; ZoneMult: NoZoneMults)),
      (Contest: VAQP; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ACC';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults)),
      (Contest: WISCONSINQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ada';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults))
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
   Result.DXMult := definition.DXMultiplierType;
   Result.ZoneMult := definition.ZoneMultiplierType;
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
      if stated.IsStated(svDXMult) then
         begin
         Result.DXMult := stated.DXMult;
         end;
      if stated.IsStated(svZoneMult) then
         begin
         Result.ZoneMult := stated.ZoneMult;
         end;
   finally
      stated.Free;
      end;
end;

function SameKinds(const a: TSessionKinds; const b: TSessionKinds): boolean;
begin
   Result := (a.Exchange = b.Exchange)               and
             (a.InitialExchange = b.InitialExchange) and
             (a.DomesticMult = b.DomesticMult)       and
             (a.DXMult = b.DXMult)                   and
             (a.ZoneMult = b.ZoneMult);
end;

(* A kind's member, by name -- GetEnumName answers an AnsiString. *)
function KindName(aInfo: PTypeInfo; aOrdinal: integer): string;
begin
   Result := string(GetEnumName(aInfo, aOrdinal));
end;

(* Five assertions, by name, so a failure reads as the kind that moved. *)
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
   CheckEquals(KindName(TypeInfo(DXMultType), Ord(aExpected.DXMult)),
               KindName(TypeInfo(DXMultType), Ord(aActual.DXMult)),
               aWho + ' DX multiplier');
   CheckEquals(KindName(TypeInfo(ZoneMultType), Ord(aExpected.ZoneMult)),
               KindName(TypeInfo(ZoneMultType), Ord(aActual.ZoneMult)),
               aWho + ' zone multiplier');
   Inc(aChecked, 5);
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

   (* EXACT: every ContestType, DUMMYCONTEST included, five kinds at three
      stations (six until M11 S3 part 2). *)
   CheckEquals(187, contests, 'contests whose kinds were checked');
   CheckEquals(187, Ord(High(ContestType)) + 1,
               'ContestType members -- a new contest adds its row here, by hand');
   CheckEquals(187 * 3 * 5, checked, 'kind assertions at us, ve and dx');
   (* THE STATION REACHES THE KINDS: at S0b these contests run another kind
      at one of us, ve and dx than at another -- ARRL160, ARRLDXCW, ARRLDXSSB, DARCWAEDCCW, DARCWAEDCSSB, WAG, DARC10M.
      The rows determine this count, so it cannot move while they are
      green; it is stated so a reader sees the station reach the kinds. *)
   CheckEquals(7, varying, 'contests whose kinds vary across us, ve and dx');
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
   CheckEquals(22 * 5, checked, 'kind assertions at us-host');
   (* IN THE HOST STATE THE KINDS DIFFER FROM THE us STATION'S for these
      parties at S0b -- ArizonaQsoParty, CALQSOPARTY, DELAWAREQSOPARTY, SALMONRUN, SEVENQP, TEXASQSOPARTY. *)
   CheckEquals(6, varying, 'parties whose kinds differ in the host state');
end;

(* The session's three "does it count this kind" answers, by name. The
   fourth, prefix, left the session at M11 S3 part 2 with the prefix kind:
   the contest answers it (TContestBase.HasPrefixMultiplier, pinned by
   uTestPrefixMultiplierKey), and an answer with no store cannot go stale. *)
procedure TContestKindPinTests.CheckDoing(aDomestic, aDX, aZone: boolean;
                                          const aWho: string);
begin
   CheckTrue(aDomestic = ContestSession.DoingDomesticMults, aWho + ' doing domestic');
   CheckTrue(aDX = ContestSession.DoingDXMults, aWho + ' doing DX');
   CheckTrue(aZone = ContestSession.DoingZoneMults, aWho + ' doing zone');
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
    * THE SWITCH, at each matrix station: the five kinds each contest
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
   x: DXMultType;
   z: ZoneMultType;
   c: ContestType;
   s: integer;
   who: string;
   switches: integer;

   (* What FoundContest leaves in the session: all five kinds, written over
      whatever the previous contest left. *)
   procedure WriteSession(const aKinds: TSessionKinds);
   begin
      ContestSession.WriteExchange(aKinds.Exchange);
      ContestSession.WriteInitialExchange(aKinds.InitialExchange);
      ContestSession.WriteDomesticMult(aKinds.DomesticMult);
      ContestSession.WriteDXMult(aKinds.DXMult);
      ContestSession.WriteZoneMult(aKinds.ZoneMult);
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
   saved.DXMult := ContestSession.DXMult;
   saved.ZoneMult := ContestSession.ZoneMult;
   try
      (* EVERY MEMBER, ONE KIND AT A TIME. *)
      for d := Low(DomesticMultType) to High(DomesticMultType) do
         begin
         ContestSession.WriteDomesticMult(d);
         CheckTrue((d <> NoDomesticMults) = ContestSession.DoingDomesticMults,
                   KindName(TypeInfo(DomesticMultType), Ord(d)));
         end;
      for x := Low(DXMultType) to High(DXMultType) do
         begin
         ContestSession.WriteDXMult(x);
         CheckTrue((x <> NoDXMults) = ContestSession.DoingDXMults,
                   KindName(TypeInfo(DXMultType), Ord(x)));
         end;
      for z := Low(ZoneMultType) to High(ZoneMultType) do
         begin
         ContestSession.WriteZoneMult(z);
         CheckTrue((z <> NoZoneMults) = ContestSession.DoingZoneMults,
                   KindName(TypeInfo(ZoneMultType), Ord(z)));
         end;

      switches := 0;
      for s := Low(CALLS) to High(CALLS) do
         begin
         (* S0d's MEASURED CASE, by literal. *)
         WriteSession(Kinds(CQWWCW, StationFor(s, CQWWCW)));
         CheckDoing(False, True, True, 'CQ WW CW at ' + CALLS[s]);
         WriteSession(Kinds(ARRLSSCW, StationFor(s, ARRLSSCW)));
         CheckDoing(True, False, False,
                    'CQ WW CW switched to ARRL SS CW at ' + CALLS[s]);

         (* EVERY CONTEST, switched to from the one before it. *)
         for c := Low(ContestType) to High(ContestType) do
            begin
            resolved := Kinds(c, StationFor(s, c));
            WriteSession(resolved);
            who := string(ContestTypeSA[c]) + ' at ' + CALLS[s];
            CheckDoing(resolved.DomesticMult <> NoDomesticMults,
                       resolved.DXMult <> NoDXMults,
                       resolved.ZoneMult <> NoZoneMults,
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
