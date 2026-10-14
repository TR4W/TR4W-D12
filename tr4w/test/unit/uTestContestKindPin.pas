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

(* EVERY CONTEST'S SIX SESSION KINDS, AT EVERY MATRIX STATION, FROZEN AS
  LITERALS -- M11 S0b, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md).

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
  named. They are not pinned by this unit.

  THE MAIN TABLE IS INDEXED BY ContestType, so the compiler refuses a table
  with a row missing or extra, and each row carries its ContestTypeSA
  spelling (Token), so a row out of order fails by name. *)
unit uTestContestKindPin;

{$I ..\..\src\tr4w.inc}

interface

uses
   VC,
   uTR4WTestFramework;

type
   (* The six kinds one session runs -- a literal row of test data. *)
   TSessionKinds = record
      Exchange: ExchangeType;
      InitialExchange: InitialExchangeType;
      DomesticMult: DomesticMultType;
      DXMult: DXMultType;
      ZoneMult: ZoneMultType;
      PrefixMult: PrefixMultType;
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
      procedure CheckDoing(aDomestic, aDX, aPrefix, aZone: boolean; const aWho: string);
      procedure Test_DoingFlagsFollowEveryContestSwitch;
   end;

implementation

uses
   SysUtils,
   TypInfo,
   uContestBase,
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
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: UnknownExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: UnknownExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* SEVENQP *)
      (Token: '7QP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ALLASIANCW *)
      (Token: 'ALL-ASIAN-DX-CW';
       AtUS: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtVE: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtDX: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix)),
      (* ALLASIANSSB *)
      (Token: 'ALL-ASIAN-DX-SSB';
       AtUS: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtVE: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtDX: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix)),
      (* ALLJA *)
      (Token: 'ALL JA';
       AtUS: (Exchange: RSTALLJAPrefectureAndPrecedenceExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTALLJAPrefectureAndPrecedenceExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTALLJAPrefectureAndPrecedenceExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* APSPRINT *)
      (Token: 'AP-SPRINT';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix)),
      (* ARCI *)
      (Token: 'ARCI';
       AtUS: (Exchange: RSTPossibleDomesticQTHAndPower; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSACanadaKH6OrKL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTPossibleDomesticQTHAndPower; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSACanadaKH6OrKL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTPossibleDomesticQTHAndPower; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSACanadaKH6OrKL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ARI_DX *)
      (Token: 'ARI-DX';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoIOrIS0; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoIOrIS0; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoIOrIS0; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ARRL10 *)
      (Token: 'ARRL-10';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ARRLDIGI *)
      (Token: 'ARRL-DIGI';
       AtUS: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ARRL160 *)
      (Token: 'ARRL-160';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ARRLDXCW *)
      (Token: 'ARRL-DX-CW';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ARRLDXSSB *)
      (Token: 'ARRL-DX-SSB';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ARRLSSCW *)
      (Token: 'ARRL-SS-CW';
       AtUS: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ARRLSSSSB *)
      (Token: 'ARRL-SS-SSB';
       AtUS: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ARRLVHFJAN *)
      (Token: 'ARRL-VHF-JAN';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ARRLVHFJUN *)
      (Token: 'ARRL-VHF-JUN';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ARRLVHFSEP *)
      (Token: 'ARRL-VHF-SEP';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ArizonaQsoParty *)
      (Token: 'ARIZONA QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* BALTIC *)
      (Token: 'BALTIC';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* BWQP *)
      (Token: 'BWQP';
       AtUS: (Exchange: RSTNameAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTNameAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTNameAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* CIS *)
      (Token: 'CIS';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* CALQSOPARTY *)
      (Token: 'CALIFORNIA QSO PARTY';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* COUNTYHUNTER *)
      (Token: 'COUNTY HUNTER';
       AtUS: (Exchange: RSTQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* CQ160CW *)
      (Token: 'CQ-160-CW';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* CQ160SSB *)
      (Token: 'CQ-160-SSB';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* CQM *)
      (Token: 'CQ-M';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* CQVHF *)
      (Token: 'CQ-VHF';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* CQWPXCW *)
      (Token: 'CQ-WPX-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix)),
      (* CQWPXSSB *)
      (Token: 'CQ-WPX-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix)),
      (* CQWPXRTTY *)
      (Token: 'CQ-WPX-RTTY';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix)),
      (* CQWWCW *)
      (Token: 'CQ-WW-CW';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: CustomInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: CustomInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: CustomInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults)),
      (* CQWWSSB *)
      (Token: 'CQ-WW-SSB';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults)),
      (* CROATIAN *)
      (Token: 'CROATIAN';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: NoPrefixMults)),
      (* CUPRFCW *)
      (Token: 'RF-CUP-CW';
       AtUS: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* CUPRFSSB *)
      (Token: 'RF-CUP-SSB';
       AtUS: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* CUPRFDIG *)
      (Token: 'RF-CUP-DIG';
       AtUS: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* CUPURAL *)
      (Token: 'URAL-CUP';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix)),
      (* EUSPRINT_SPRING_CW *)
      (Token: 'EU-SPRINT-SPRING-CW';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* EUROPEANHFC *)
      (Token: 'EUROPEAN HFC';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: EUHFCYear; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: EUHFCYear; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: EUHFCYear; PrefixMult: NoPrefixMults)),
      (* EUROPEANVHF *)
      (Token: 'EUROPEAN VHF';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* TESLA *)
      (Token: 'HF-TESLA';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ARRLFIELDDAY *)
      (Token: 'ARRL-FD';
       AtUS: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* FISTS *)
      (Token: 'FISTS';
       AtUS: (Exchange: RSTQTHNameAndFistsNumberOrPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQTHNameAndFistsNumberOrPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQTHNameAndFistsNumberOrPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* FOCMARATHON *)
      (Token: 'FOC MARATHON';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* FLORIDAQSOPARTY *)
      (Token: 'FLORIDA QSO PARTY';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* GACWWWSACW *)
      (Token: 'GACW-WWSA-CW';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults)),
      (* GAGARINCUP *)
      (Token: 'GAGARIN-CUP';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: GCStation);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: GCStation);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: GCStation)),
      (* GENERALQSO *)
      (Token: 'GENERAL QSO';
       AtUS: (Exchange: RSTNameAndQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTNameAndQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTNameAndQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* GRIDLOC *)
      (Token: 'GRID LOC';
       AtUS: (Exchange: NameAndPossibleGridSquareExchange; InitialExchange: NameInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: NameAndPossibleGridSquareExchange; InitialExchange: NameInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: NameAndPossibleGridSquareExchange; InitialExchange: NameInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* HADX *)
      (Token: 'HA DX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* YUDX *)
      (Token: 'YUDX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* UKEI *)
      (Token: 'UKEI';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* HELVETIA *)
      (Token: 'HELVETIA';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* IARU *)
      (Token: 'IARU-HF';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: NoPrefixMults)),
      (* INTERNETSPRINT *)
      (Token: 'INTERNET SPRINT';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* IOTA *)
      (Token: 'RSGB-IOTA';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: IOTADomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: IOTADomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: IOTADomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* JIDXCW *)
      (Token: 'JIDX-CW';
       AtUS: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* JIDXSSB *)
      (Token: 'JIDX-SSB';
       AtUS: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* JALONGPREFECT *)
      (Token: 'JA LONG PREFECT';
       AtUS: (Exchange: RSTLongJAPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTLongJAPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTLongJAPrefectureExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* JTDX *)
      (Token: 'MONGOLIAN DX';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCCWithNoJT; ZoneMult: NoZoneMults; PrefixMult: MongolianCallSignPrefix);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCCWithNoJT; ZoneMult: NoZoneMults; PrefixMult: MongolianCallSignPrefix);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCCWithNoJT; ZoneMult: NoZoneMults; PrefixMult: MongolianCallSignPrefix)),
      (* KCJ *)
      (Token: 'KCJ';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* KIDSDAY *)
      (Token: 'KIDS DAY';
       AtUS: (Exchange: KidsDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: KidsDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: KidsDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* KVP *)
      (Token: 'KVP';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: EUHFCYear; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: EUHFCYear; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: EUHFCYear; PrefixMult: NoPrefixMults)),
      (* LABRE *)
      (Token: 'LABRE';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* LZDX *)
      (Token: 'LZ DX';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: NoPrefixMults)),
      (* MARCONIMEMORIAL *)
      (Token: 'MARCONI MEMORIAL';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* MINITEST *)
      (Token: 'MINITEST';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix)),
      (* MINI80 *)
      (Token: 'MINI80';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix)),
      (* MINI40 *)
      (Token: 'MINI40';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix)),
      (* MICHQSOPARTY *)
      (Token: 'MICHIGAN QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* MINNQSOPARTY *)
      (Token: 'MINNESOTA QSO PARTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* MOQSOPARTY *)
      (Token: 'MISSOURI QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* NAQSOCW *)
      (Token: 'NAQP-CW';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* NAQSOSSB *)
      (Token: 'NAQP-SSB';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* NAQSORTTY *)
      (Token: 'NAQP-RTTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* NASPRINTCW *)
      (Token: 'NA-SPRINT-CW';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* SPRINTSSB *)
      (Token: 'SSB-SPRINT';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* NASPRINTRTTY *)
      (Token: 'NA-SPRINT-RTTY';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* NCCCSPRINT *)
      (Token: 'NCCC-SPRINT';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* NEWENGLANDQSO *)
      (Token: 'NEQP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* NCQSOPARTY *)
      (Token: 'NC QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* NRAUBALTICCW *)
      (Token: 'NRAU-BALTIC-CW';
       AtUS: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* NRAUBALTICSSB *)
      (Token: 'NRAU-BALTIC-SSB';
       AtUS: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* NZFIELDDAY *)
      (Token: 'NZ FIELD DAY';
       AtUS: (Exchange: NZFieldDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: BranchZones; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: NZFieldDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: BranchZones; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: NZFieldDayExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: BranchZones; PrefixMult: NoPrefixMults)),
      (* OCEANIADXCW *)
      (Token: 'OCEANIA-DX-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix)),
      (* OCEANIADXSSB *)
      (Token: 'OCEANIA-DX-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix)),
      (* OHIOQSOPARTY *)
      (Token: 'OHIO QSO PARTY';
       AtUS: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* OKDX *)
      (Token: 'OK-OM DX CW';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* OLDNEWYEAR *)
      (Token: 'RADIO-ONY';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* OZCR_O *)
      (Token: 'OZCHR-TEAMS';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: ITUZones; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: ITUZones; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: ITUZones; PrefixMult: NoPrefixMults)),
      (* OZCR_Z *)
      (Token: 'OZCHR';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: ITUZones; PrefixMult: NoPrefixMults)),
      (* PACC *)
      (Token: 'PACC';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* POTA *)
      (Token: 'POTA';
       AtUS: (Exchange: RSTAndPOTAPark; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndPOTAPark; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndPOTAPark; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* QCWA *)
      (Token: 'QCWA';
       AtUS: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* QCWAGOLDEN *)
      (Token: 'QCWA GOLDEN';
       AtUS: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* CANADA_WINTER *)
      (Token: 'CANADA WINTER';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* RADIOVHFFD *)
      (Token: 'RF-VHF-FD';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* RAEM *)
      (Token: 'RAEM';
       AtUS: (Exchange: QSONumberAndGeoCoordinates; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberAndGeoCoordinates; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberAndGeoCoordinates; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* RDA *)
      (Token: 'RDAC';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: RDADistrict; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: RDADistrict; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: RDADistrict; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* REGION1FIELDDAY *)
      (Token: 'REGION 1 FIELD DAY';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* REGION1FIELDDAY_RCC_CW *)
      (Token: 'REGION 1 FIELD DAY-RCC-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* REGION1FIELDDAY_RCC_SSB *)
      (Token: 'REGION 1 FIELD DAY-RCC-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* RFCHAMPIONSHIPCW *)
      (Token: 'RF-CHAMP-CW';
       AtUS: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: RFChampionchipZones; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: RFChampionchipZones; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: RFChampionchipZones; PrefixMult: NoPrefixMults)),
      (* RFCHAMPIONSHIPSSB *)
      (Token: 'RF-CHAMP-SSB';
       AtUS: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: RFChampionchipZones; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: RFChampionchipZones; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: RFChampionchipZones; PrefixMult: NoPrefixMults)),
      (* RFASCHAMPIONSHIPCW *)
      (Token: 'AS-CHAMP';
       AtUS: (Exchange: QSONumberAndCoordinatesSum; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberAndCoordinatesSum; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberAndCoordinatesSum; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* RSGB_ROPOCO_CW *)
      (Token: 'RSGB-ROPOCO-CW';
       AtUS: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* RSGB_ROPOCO_SSB *)
      (Token: 'RSGB-ROPOCO-SSB';
       AtUS: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* RSGB18 *)
      (Token: 'RSGB-160';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* RUSSIANDX *)
      (Token: 'RDXC';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* SACCW *)
      (Token: 'SAC-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: SACDistricts);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: SACDistricts);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: SACDistricts)),
      (* YBDX *)
      (Token: 'YBDX';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: IndonesianDistricts);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: IndonesianDistricts);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: IndonesianDistricts)),
      (* SACSSB *)
      (Token: 'SAC-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: SACDistricts);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: SACDistricts);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: SACDistricts)),
      (* SALMONRUN *)
      (Token: 'SALMON RUN';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* SOUTHAMERICANWW *)
      (Token: 'SOUTH AMERICAN WW';
       AtUS: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: SouthAmericanPrefixes);
       AtVE: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: SouthAmericanPrefixes);
       AtDX: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: SouthAmericanPrefixes)),
      (* SPDX *)
      (Token: 'SP DX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* STEWPERRY *)
      (Token: 'STEW-PERRY';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* TENTEN *)
      (Token: 'TEN TEN';
       AtUS: (Exchange: NameQTHAndPossibleTenTenNumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: NameQTHAndPossibleTenTenNumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: NameQTHAndPossibleTenTenNumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* TEXASQSOPARTY *)
      (Token: 'TEXAS QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* TOEC *)
      (Token: 'TOEC';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* UA4WCHAMPIONSHIP *)
      (Token: 'R4W-CHAMP';
       AtUS: (Exchange: RSTAndGridSquareOrRDAExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndGridSquareOrRDAExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndGridSquareOrRDAExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* UBACW *)
      (Token: 'UBA-DX-CW';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQUBAEuropeanCountries; ZoneMult: NoZoneMults; PrefixMult: BelgiumPrefixes);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQUBAEuropeanCountries; ZoneMult: NoZoneMults; PrefixMult: BelgiumPrefixes);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQUBAEuropeanCountries; ZoneMult: NoZoneMults; PrefixMult: BelgiumPrefixes)),
      (* UBASSB *)
      (Token: 'UBA-DX-SSB';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQUBAEuropeanCountries; ZoneMult: NoZoneMults; PrefixMult: BelgiumPrefixes);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQUBAEuropeanCountries; ZoneMult: NoZoneMults; PrefixMult: BelgiumPrefixes);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQUBAEuropeanCountries; ZoneMult: NoZoneMults; PrefixMult: BelgiumPrefixes)),
      (* UCG *)
      (Token: 'UCG';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix)),
      (* UKRAINECHAMPIONSHIP *)
      (Token: 'UKRAINE CHAMPIONSHIP';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* UKRAINIAN *)
      (Token: 'UKRAINIAN';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* DARCWAEDCCW *)
      (Token: 'DARC-WAEDC-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQEuropeanCountries; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQEuropeanCountries; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CQNonEuropeanCountriesAndWAECallRegions)),
      (* DARCWAEDCSSB *)
      (Token: 'DARC-WAEDC-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQEuropeanCountries; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQEuropeanCountries; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CQNonEuropeanCountriesAndWAECallRegions)),
      (* DARCXMAS *)
      (Token: 'DARC-XMAS';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix)),
      (* WAG *)
      (Token: 'WAG';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DOKCodes; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DOKCodes; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* WISCONSINQSOPARTY *)
      (Token: 'WISCONSIN QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* WWL *)
      (Token: 'WWL';
       AtUS: (Exchange: RSTAndGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndGridExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* WWPMC *)
      (Token: 'WW PMC';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* XMAS *)
      (Token: 'XMAS';
       AtUS: (Exchange: RSTQSONumberAndRandomCharactersExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONumberAndRandomCharactersExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONumberAndRandomCharactersExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* YODX *)
      (Token: 'YO-DX-HF';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* YOUTHCHAMPIONSHIPRF *)
      (Token: 'SRR-JR';
       AtUS: (Exchange: AgeAndQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: AgeAndQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: AgeAndQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* RU3AXMEMORIAL *)
      (Token: 'RU3AX MEMORIAL';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* LQP *)
      (Token: 'LOCUST QSO PARTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ARKTIKA_SPRING *)
      (Token: 'ARKTIKA-SPRING';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* UNDX *)
      (Token: 'UN DX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* NYQP *)
      (Token: 'NY-QSO-PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* KINGOFSPAINCW *)
      (Token: 'KING-OF-SPAIN-CW';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* KINGOFSPAINSSB *)
      (Token: 'KING-OF-SPAIN-SSB';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* WRTC *)
      (Token: 'WRTC';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* TENNESSEEQSOPARTY *)
      (Token: 'TENNESSEE QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* COLORADOQSOPARTY *)
      (Token: 'COLORADO QSO PARTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* R9W_UW9WK_MEMORIAL *)
      (Token: 'R9W-UW9WK-MEMORIAL';
       AtUS: (Exchange: QSONumberAndZone; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberAndZone; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberAndZone; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* PCC *)
      (Token: 'PCC';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: Prefix)),
      (* RADIOMEMORY *)
      (Token: 'RADIO-MEMORY';
       AtUS: (Exchange: RSTAgeAndPossibleSK; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAgeAndPossibleSK; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAgeAndPossibleSK; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* DARC10M *)
      (Token: 'DARC-10M';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DOKCodes; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DOKCodes; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* REFCW *)
      (Token: 'REF-CW';
       AtUS: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* REFSSB *)
      (Token: 'REF-SSB';
       AtUS: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* BSCI *)
      (Token: 'BLACK SEA CUP';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: BlackSeaCountries; ZoneMult: ITUZones; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: BlackSeaCountries; ZoneMult: ITUZones; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: BlackSeaCountries; ZoneMult: ITUZones; PrefixMult: NoPrefixMults)),
      (* CQMM *)
      (Token: 'CQMM';
       AtUS: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: SouthAmericanPrefixes);
       AtVE: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: SouthAmericanPrefixes);
       AtDX: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: SouthAmericanPrefixes)),
      (* SASPRINT *)
      (Token: 'SA-SPRINT';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: SouthAmericanPrefixes);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: SouthAmericanPrefixes);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: SouthAmericanPrefixes)),
      (* CWOPS *)
      (Token: 'CWOPS';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix)),
      (* OZHCRVHF *)
      (Token: 'OZHCR-VHF';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* CANADA_DAY *)
      (Token: 'CANADA DAY';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* CQWWRTTY *)
      (Token: 'CQ-WW-RTTY';
       AtUS: (Exchange: RSTZoneAndPossibleDomesticQTHExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneAndPossibleDomesticQTHExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneAndPossibleDomesticQTHExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults)),
      (* CWOPEN *)
      (Token: 'CWOPEN';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: CQZones; PrefixMult: CallSignPrefix);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: CQZones; PrefixMult: CallSignPrefix);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: CQZones; PrefixMult: CallSignPrefix)),
      (* MAKROTHEN *)
      (Token: 'MAKROTHEN-RTTY';
       AtUS: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* EUSPRINT_SPRING_SSB *)
      (Token: 'EU-SPRINT-SPRING-SSB';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* EUSPRINT_AUTUMN_CW *)
      (Token: 'EU-SPRINT-AUTUMN-CW';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* EUSPRINT_AUTUMN_SSB *)
      (Token: 'EU-SPRINT-AUTUMN-SSB';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* ARRL_RTTY_ROUNDUP *)
      (Token: 'ARRL-RTTY';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* CQIR *)
      (Token: 'CQIR';
       AtUS: (Exchange: QSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* WWIH *)
      (Token: 'WWIH';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: CQZones; PrefixMult: NoPrefixMults)),
      (* ALRS_UA1DZ_CUP *)
      (Token: 'ALRS-UA1DZ-CUP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: WYSIWYGDomestic; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* WINTERFIELDDAY *)
      (Token: 'WINTER FIELD DAY';
       AtUS: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoARRLSections; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* RADIOYOC *)
      (Token: 'RADIO-YOC';
       AtUS: (Exchange: QSONumberAndPreviousQSONumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberAndPreviousQSONumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberAndPreviousQSONumber; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: ARRLDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* PAQSOPARTY *)
      (Token: 'PA QSO PARTY';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* INQSOPARTY *)
      (Token: 'IN QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* OKOMSSB *)
      (Token: 'OK-OM DX SSB';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* BATAVIA_FT8 *)
      (Token: 'BATAVIA-FT8';
       AtUS: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtVE: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: Prefix);
       AtDX: (Exchange: GridExchange; InitialExchange: GridInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: Prefix)),
      (* WWDIGI *)
      (Token: 'WWDIGI';
       AtUS: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridFields; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* MWC *)
      (Token: 'MWC';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* IRTS *)
      (Token: 'IRTS';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* EUDX *)
      (Token: 'EUDX';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: CQDXCC; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* BCQP *)
      (Token: 'BCQP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* VAQP *)
      (Token: 'VAQP';
       AtUS: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* YOTA *)
      (Token: 'YOTA';
       AtUS: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* IN7QPNE *)
      (Token: 'IN7QPNE';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* MST *)
      (Token: 'MST';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NoInitialExchange;
              DomesticMult: NoDomesticMults; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: CallSignPrefix)),
      (* SST *)
      (Token: 'SST';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange;
              DomesticMult: DomesticFile; DXMult: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* RTC *)
      (Token: 'RTC';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: GridInitialExchange;
              DomesticMult: GridSquares; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* IDAHOQSOPARTY *)
      (Token: 'IDAHO QSO PARTY';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (* DELAWAREQSOPARTY *)
      (Token: 'DELAWARE QSO PARTY';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
              DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults))
   );

   (* GENERATED ONCE AT M11 S0b, with the table above. One row per party
      (IsUSQSOParty), ordered by the name of its frozen matrix record. *)
   HOST_KIND_PINS: array[1..22] of THostKindPin = (
      (Contest: ArizonaQsoParty; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'APH';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: BCQP; MyCall: 'VE7AAA'; MyCountry: 'VE'; MyState: 'ABF';
       MySection: 'BC'; MyGrid: 'CN89';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: CALQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alam';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: COLORADOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ada';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: DELAWAREQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'NDE';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSACanadaKH6OrKL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: FLORIDAQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alc';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: IDAHOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ADA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: IN7QPNE; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Azaph';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: INQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'INADA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: MICHQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alco';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: MINNQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ait';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: MOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ADR';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: NCQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ALA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: NYQP; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alb';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: OHIOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Adam';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: PAQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ADA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: SALMONRUN; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ada';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSAOrCanada; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: SEVENQP; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Azaph';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSACanadaKH6OrKL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: TENNESSEEQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ande';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: TEXASQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ande';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: ARRLDXCCWithNoUSACanadaKH6OrKL7; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: VAQP; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ACC';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults)),
      (Contest: WISCONSINQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ada';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange;
               DomesticMult: DomesticFile; DXMult: NoDXMults; ZoneMult: NoZoneMults; PrefixMult: NoPrefixMults))
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

(* The six kinds aContest's session runs at aStation, resolved as FCONTEST
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
   Result.PrefixMult := definition.PrefixMultiplierType;
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
      if stated.IsStated(svPrefixMult) then
         begin
         Result.PrefixMult := stated.PrefixMult;
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
             (a.ZoneMult = b.ZoneMult)               and
             (a.PrefixMult = b.PrefixMult);
end;

(* A kind's member, by name -- GetEnumName answers an AnsiString. *)
function KindName(aInfo: PTypeInfo; aOrdinal: integer): string;
begin
   Result := string(GetEnumName(aInfo, aOrdinal));
end;

(* Six assertions, by name, so a failure reads as the kind that moved. *)
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
   CheckEquals(KindName(TypeInfo(PrefixMultType), Ord(aExpected.PrefixMult)),
               KindName(TypeInfo(PrefixMultType), Ord(aActual.PrefixMult)),
               aWho + ' prefix multiplier');
   Inc(aChecked, 6);
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

   (* EXACT: every ContestType, DUMMYCONTEST included, six kinds at three
      stations. *)
   CheckEquals(187, contests, 'contests whose kinds were checked');
   CheckEquals(187, Ord(High(ContestType)) + 1,
               'ContestType members -- a new contest adds its row here, by hand');
   CheckEquals(187 * 3 * 6, checked, 'kind assertions at us, ve and dx');
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
   CheckEquals(22 * 6, checked, 'kind assertions at us-host');
   (* IN THE HOST STATE THE KINDS DIFFER FROM THE us STATION'S for these
      parties at S0b -- ArizonaQsoParty, CALQSOPARTY, DELAWAREQSOPARTY, SALMONRUN, SEVENQP, TEXASQSOPARTY. *)
   CheckEquals(6, varying, 'parties whose kinds differ in the host state');
end;

(* The session's four "does it count this kind" answers, by name. *)
procedure TContestKindPinTests.CheckDoing(aDomestic, aDX, aPrefix, aZone: boolean;
                                          const aWho: string);
begin
   CheckTrue(aDomestic = ContestSession.DoingDomesticMults, aWho + ' doing domestic');
   CheckTrue(aDX = ContestSession.DoingDXMults, aWho + ' doing DX');
   CheckTrue(aPrefix = ContestSession.DoingPrefixMults, aWho + ' doing prefix');
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
    * THE SWITCH, at each matrix station: the six kinds each contest
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
   p: PrefixMultType;
   z: ZoneMultType;
   c: ContestType;
   s: integer;
   who: string;
   switches: integer;

   (* What FoundContest leaves in the session: all six kinds, written over
      whatever the previous contest left. *)
   procedure WriteSession(const aKinds: TSessionKinds);
   begin
      ContestSession.WriteExchange(aKinds.Exchange);
      ContestSession.WriteInitialExchange(aKinds.InitialExchange);
      ContestSession.WriteDomesticMult(aKinds.DomesticMult);
      ContestSession.WriteDXMult(aKinds.DXMult);
      ContestSession.WriteZoneMult(aKinds.ZoneMult);
      ContestSession.WritePrefixMult(aKinds.PrefixMult);
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
   saved.PrefixMult := ContestSession.PrefixMult;
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
      for p := Low(PrefixMultType) to High(PrefixMultType) do
         begin
         ContestSession.WritePrefixMult(p);
         CheckTrue((p <> NoPrefixMults) = ContestSession.DoingPrefixMults,
                   KindName(TypeInfo(PrefixMultType), Ord(p)));
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
         CheckDoing(False, True, False, True, 'CQ WW CW at ' + CALLS[s]);
         WriteSession(Kinds(ARRLSSCW, StationFor(s, ARRLSSCW)));
         CheckDoing(True, False, False, False,
                    'CQ WW CW switched to ARRL SS CW at ' + CALLS[s]);

         (* EVERY CONTEST, switched to from the one before it. *)
         for c := Low(ContestType) to High(ContestType) do
            begin
            resolved := Kinds(c, StationFor(s, c));
            WriteSession(resolved);
            who := string(ContestTypeSA[c]) + ' at ' + CALLS[s];
            CheckDoing(resolved.DomesticMult <> NoDomesticMults,
                       resolved.DXMult <> NoDXMults,
                       resolved.PrefixMult <> NoPrefixMults,
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
