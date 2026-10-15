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
  since M11 S4 part 2 deleted the DX kind, three since M11 S5 part 2
  deleted the zone kind, and two since M11 S6 part 2 deleted the domestic
  kind -- each column left this unit in its deleting commit (a column
  removed, not a table regenerated -- see below).

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
   (* Contest and LOGEDIT.DoingDomesticMults -- the switch test asks the
     engine's reader of the open contest (M11 S6 part 2); ReleaseActiveContest
     puts the factory back. *)
   PostUnit,
   LogEdit,
   uContestFactory;

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
       AtUS: (Exchange: UnknownExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: UnknownExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: UnknownExchange; InitialExchange: NoInitialExchange)),
      (* SEVENQP *)
      (Token: '7QP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* ALLASIANCW *)
      (Token: 'ALL-ASIAN-DX-CW';
       AtUS: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange)),
      (* ALLASIANSSB *)
      (Token: 'ALL-ASIAN-DX-SSB';
       AtUS: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange)),
      (* ALLJA *)
      (Token: 'ALL JA';
       AtUS: (Exchange: RSTALLJAPrefectureAndPrecedenceExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTALLJAPrefectureAndPrecedenceExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTALLJAPrefectureAndPrecedenceExchange; InitialExchange: NoInitialExchange)),
      (* APSPRINT *)
      (Token: 'AP-SPRINT';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* ARCI *)
      (Token: 'ARCI';
       AtUS: (Exchange: RSTPossibleDomesticQTHAndPower; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTPossibleDomesticQTHAndPower; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTPossibleDomesticQTHAndPower; InitialExchange: NoInitialExchange)),
      (* ARI_DX *)
      (Token: 'ARI-DX';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* ARRL10 *)
      (Token: 'ARRL-10';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange)),
      (* ARRLDIGI *)
      (Token: 'ARRL-DIGI';
       AtUS: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange);
       AtVE: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange);
       AtDX: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange)),
      (* ARRL160 *)
      (Token: 'ARRL-160';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* ARRLDXCW *)
      (Token: 'ARRL-DX-CW';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* ARRLDXSSB *)
      (Token: 'ARRL-DX-SSB';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* ARRLSSCW *)
      (Token: 'ARRL-SS-CW';
       AtUS: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange);
       AtVE: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange);
       AtDX: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange)),
      (* ARRLSSSSB *)
      (Token: 'ARRL-SS-SSB';
       AtUS: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange);
       AtVE: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange);
       AtDX: (Exchange: QSONumberPrecedenceCheckDomesticQTHExchange; InitialExchange: CheckSectionInitialExchange)),
      (* ARRLVHFJAN *)
      (Token: 'ARRL-VHF-JAN';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange)),
      (* ARRLVHFJUN *)
      (Token: 'ARRL-VHF-JUN';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange)),
      (* ARRLVHFSEP *)
      (Token: 'ARRL-VHF-SEP';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange)),
      (* ArizonaQsoParty *)
      (Token: 'ARIZONA QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* BALTIC *)
      (Token: 'BALTIC';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* BWQP *)
      (Token: 'BWQP';
       AtUS: (Exchange: RSTNameAndQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTNameAndQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTNameAndQTHExchange; InitialExchange: NoInitialExchange)),
      (* CIS *)
      (Token: 'CIS';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange)),
      (* CALQSOPARTY *)
      (Token: 'CALIFORNIA QSO PARTY';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* COUNTYHUNTER *)
      (Token: 'COUNTY HUNTER';
       AtUS: (Exchange: RSTQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQTHExchange; InitialExchange: NoInitialExchange)),
      (* CQ160CW *)
      (Token: 'CQ-160-CW';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange)),
      (* CQ160SSB *)
      (Token: 'CQ-160-SSB';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange)),
      (* CQM *)
      (Token: 'CQ-M';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* CQVHF *)
      (Token: 'CQ-VHF';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange)),
      (* CQWPXCW *)
      (Token: 'CQ-WPX-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* CQWPXSSB *)
      (Token: 'CQ-WPX-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* CQWPXRTTY *)
      (Token: 'CQ-WPX-RTTY';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* CQWWCW *)
      (Token: 'CQ-WW-CW';  (* Zone since Q96 (2026-10-14); was Custom *)
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange)),
      (* CQWWSSB *)
      (Token: 'CQ-WW-SSB';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange)),
      (* CROATIAN *)
      (Token: 'CROATIAN';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange)),
      (* CUPRFCW *)
      (Token: 'RF-CUP-CW';
       AtUS: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange)),
      (* CUPRFSSB *)
      (Token: 'RF-CUP-SSB';
       AtUS: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange)),
      (* CUPRFDIG *)
      (Token: 'RF-CUP-DIG';
       AtUS: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberAndGridSquare; InitialExchange: NoInitialExchange)),
      (* CUPURAL *)
      (Token: 'URAL-CUP';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* EUSPRINT_SPRING_CW *)
      (Token: 'EU-SPRINT-SPRING-CW';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange)),
      (* EUROPEANHFC *)
      (Token: 'EUROPEAN HFC';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange)),
      (* EUROPEANVHF *)
      (Token: 'EUROPEAN VHF';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange)),
      (* TESLA *)
      (Token: 'HF-TESLA';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange)),
      (* ARRLFIELDDAY *)
      (Token: 'ARRL-FD';
       AtUS: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (* FISTS *)
      (Token: 'FISTS';
       AtUS: (Exchange: RSTQTHNameAndFistsNumberOrPowerExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQTHNameAndFistsNumberOrPowerExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQTHNameAndFistsNumberOrPowerExchange; InitialExchange: NoInitialExchange)),
      (* FOCMARATHON *)
      (Token: 'FOC MARATHON';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange)),
      (* FLORIDAQSOPARTY *)
      (Token: 'FLORIDA QSO PARTY';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (* GACWWWSACW *)
      (Token: 'GACW-WWSA-CW';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange)),
      (* GAGARINCUP *)
      (Token: 'GAGARIN-CUP';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange)),
      (* GENERALQSO *)
      (Token: 'GENERAL QSO';
       AtUS: (Exchange: RSTNameAndQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtVE: (Exchange: RSTNameAndQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtDX: (Exchange: RSTNameAndQTHExchange; InitialExchange: NameQTHInitialExchange)),
      (* GRIDLOC *)
      (Token: 'GRID LOC';
       AtUS: (Exchange: NameAndPossibleGridSquareExchange; InitialExchange: NameInitialExchange);
       AtVE: (Exchange: NameAndPossibleGridSquareExchange; InitialExchange: NameInitialExchange);
       AtDX: (Exchange: NameAndPossibleGridSquareExchange; InitialExchange: NameInitialExchange)),
      (* HADX *)
      (Token: 'HA DX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange)),
      (* YUDX *)
      (Token: 'YUDX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange)),
      (* UKEI *)
      (Token: 'UKEI';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* HELVETIA *)
      (Token: 'HELVETIA';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange)),
      (* IARU *)
      (Token: 'IARU-HF';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange)),
      (* INTERNETSPRINT *)
      (Token: 'INTERNET SPRINT';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (* IOTA *)
      (Token: 'RSGB-IOTA';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* JIDXCW *)
      (Token: 'JIDX-CW';
       AtUS: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange)),
      (* JIDXSSB *)
      (Token: 'JIDX-SSB';
       AtUS: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTPrefectureExchange; InitialExchange: NoInitialExchange)),
      (* JALONGPREFECT *)
      (Token: 'JA LONG PREFECT';
       AtUS: (Exchange: RSTLongJAPrefectureExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTLongJAPrefectureExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTLongJAPrefectureExchange; InitialExchange: NoInitialExchange)),
      (* JTDX *)
      (Token: 'MONGOLIAN DX';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange)),
      (* KCJ *)
      (Token: 'KCJ';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange)),
      (* KIDSDAY *)
      (Token: 'KIDS DAY';
       AtUS: (Exchange: KidsDayExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: KidsDayExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: KidsDayExchange; InitialExchange: NoInitialExchange)),
      (* KVP *)
      (Token: 'KVP';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: NoInitialExchange)),
      (* LABRE *)
      (Token: 'LABRE';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (* LZDX *)
      (Token: 'LZ DX';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange)),
      (* MARCONIMEMORIAL *)
      (Token: 'MARCONI MEMORIAL';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* MINITEST *)
      (Token: 'MINITEST';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* MINI80 *)
      (Token: 'MINI80';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* MINI40 *)
      (Token: 'MINI40';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* MICHQSOPARTY *)
      (Token: 'MICHIGAN QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* MINNQSOPARTY *)
      (Token: 'MINNESOTA QSO PARTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (* MOQSOPARTY *)
      (Token: 'MISSOURI QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* NAQSOCW *)
      (Token: 'NAQP-CW';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange)),
      (* NAQSOSSB *)
      (Token: 'NAQP-SSB';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange)),
      (* NAQSORTTY *)
      (Token: 'NAQP-RTTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameInitialExchange)),
      (* NASPRINTCW *)
      (Token: 'NA-SPRINT-CW';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange)),
      (* SPRINTSSB *)
      (Token: 'SSB-SPRINT';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange)),
      (* NASPRINTRTTY *)
      (Token: 'NA-SPRINT-RTTY';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange)),
      (* NCCCSPRINT *)
      (Token: 'NCCC-SPRINT';
       AtUS: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtVE: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtDX: (Exchange: QSONumberNameDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange)),
      (* NEWENGLANDQSO *)
      (Token: 'NEQP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* NCQSOPARTY *)
      (Token: 'NC QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* NRAUBALTICCW *)
      (Token: 'NRAU-BALTIC-CW';
       AtUS: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* NRAUBALTICSSB *)
      (Token: 'NRAU-BALTIC-SSB';
       AtUS: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* NZFIELDDAY *)
      (Token: 'NZ FIELD DAY';
       AtUS: (Exchange: NZFieldDayExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: NZFieldDayExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: NZFieldDayExchange; InitialExchange: NoInitialExchange)),
      (* OCEANIADXCW *)
      (Token: 'OCEANIA-DX-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* OCEANIADXSSB *)
      (Token: 'OCEANIA-DX-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* OHIOQSOPARTY *)
      (Token: 'OHIO QSO PARTY';
       AtUS: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* OKDX *)
      (Token: 'OK-OM DX CW';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* OLDNEWYEAR *)
      (Token: 'RADIO-ONY';
       AtUS: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTPowerExchange; InitialExchange: NoInitialExchange)),
      (* OZCR_O *)
      (Token: 'OZCHR-TEAMS';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange)),
      (* OZCR_Z *)
      (Token: 'OZCHR';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange)),
      (* PACC *)
      (Token: 'PACC';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* POTA *)
      (Token: 'POTA';
       AtUS: (Exchange: RSTAndPOTAPark; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndPOTAPark; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndPOTAPark; InitialExchange: NoInitialExchange)),
      (* QCWA *)
      (Token: 'QCWA';
       AtUS: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange)),
      (* QCWAGOLDEN *)
      (Token: 'QCWA GOLDEN';
       AtUS: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberNameChapterAndQTHExchange; InitialExchange: NoInitialExchange)),
      (* CANADA_WINTER *)
      (Token: 'CANADA WINTER';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* RADIOVHFFD *)
      (Token: 'RF-VHF-FD';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange)),
      (* RAEM *)
      (Token: 'RAEM';
       AtUS: (Exchange: QSONumberAndGeoCoordinates; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberAndGeoCoordinates; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberAndGeoCoordinates; InitialExchange: NoInitialExchange)),
      (* RDA *)
      (Token: 'RDAC';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange)),
      (* REGION1FIELDDAY *)
      (Token: 'REGION 1 FIELD DAY';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* REGION1FIELDDAY_RCC_CW *)
      (Token: 'REGION 1 FIELD DAY-RCC-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* REGION1FIELDDAY_RCC_SSB *)
      (Token: 'REGION 1 FIELD DAY-RCC-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* RFCHAMPIONSHIPCW *)
      (Token: 'RF-CHAMP-CW';
       AtUS: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange)),
      (* RFCHAMPIONSHIPSSB *)
      (Token: 'RF-CHAMP-SSB';
       AtUS: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: QSONumberAndZone; InitialExchange: ZoneInitialExchange)),
      (* RFASCHAMPIONSHIPCW *)
      (Token: 'AS-CHAMP';
       AtUS: (Exchange: QSONumberAndCoordinatesSum; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberAndCoordinatesSum; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberAndCoordinatesSum; InitialExchange: NoInitialExchange)),
      (* RSGB_ROPOCO_CW *)
      (Token: 'RSGB-ROPOCO-CW';
       AtUS: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange)),
      (* RSGB_ROPOCO_SSB *)
      (Token: 'RSGB-ROPOCO-SSB';
       AtUS: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndPostalCodeExchange; InitialExchange: NoInitialExchange)),
      (* RSGB18 *)
      (Token: 'RSGB-160';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* RUSSIANDX *)
      (Token: 'RDXC';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange)),
      (* SACCW *)
      (Token: 'SAC-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* YBDX *)
      (Token: 'YBDX';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* SACSSB *)
      (Token: 'SAC-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* SALMONRUN *)
      (Token: 'SALMON RUN';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* SOUTHAMERICANWW *)
      (Token: 'SOUTH AMERICAN WW';
       AtUS: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange)),
      (* SPDX *)
      (Token: 'SP DX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange)),
      (* STEWPERRY *)
      (Token: 'STEW-PERRY';
       AtUS: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndOrGridExchange; InitialExchange: NoInitialExchange)),
      (* TENTEN *)
      (Token: 'TEN TEN';
       AtUS: (Exchange: NameQTHAndPossibleTenTenNumber; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: NameQTHAndPossibleTenTenNumber; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: NameQTHAndPossibleTenTenNumber; InitialExchange: NoInitialExchange)),
      (* TEXASQSOPARTY *)
      (Token: 'TEXAS QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* TOEC *)
      (Token: 'TOEC';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* UA4WCHAMPIONSHIP *)
      (Token: 'R4W-CHAMP';
       AtUS: (Exchange: RSTAndGridSquareOrRDAExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndGridSquareOrRDAExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndGridSquareOrRDAExchange; InitialExchange: NoInitialExchange)),
      (* UBACW *)
      (Token: 'UBA-DX-CW';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* UBASSB *)
      (Token: 'UBA-DX-SSB';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* UCG *)
      (Token: 'UCG';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* UKRAINECHAMPIONSHIP *)
      (Token: 'UKRAINE CHAMPIONSHIP';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* UKRAINIAN *)
      (Token: 'UKRAINIAN';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* DARCWAEDCCW *)
      (Token: 'DARC-WAEDC-CW';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* DARCWAEDCSSB *)
      (Token: 'DARC-WAEDC-SSB';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* DARCXMAS *)
      (Token: 'DARC-XMAS';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* WAG *)
      (Token: 'WAG';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* WISCONSINQSOPARTY *)
      (Token: 'WISCONSIN QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* WWL *)
      (Token: 'WWL';
       AtUS: (Exchange: RSTAndGridExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndGridExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndGridExchange; InitialExchange: NoInitialExchange)),
      (* WWPMC *)
      (Token: 'WW PMC';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: NoInitialExchange)),
      (* XMAS *)
      (Token: 'XMAS';
       AtUS: (Exchange: RSTQSONumberAndRandomCharactersExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndRandomCharactersExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndRandomCharactersExchange; InitialExchange: NoInitialExchange)),
      (* YODX *)
      (Token: 'YO-DX-HF';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* YOUTHCHAMPIONSHIPRF *)
      (Token: 'SRR-JR';
       AtUS: (Exchange: AgeAndQSONumberExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: AgeAndQSONumberExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: AgeAndQSONumberExchange; InitialExchange: NoInitialExchange)),
      (* RU3AXMEMORIAL *)
      (Token: 'RU3AX MEMORIAL';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange)),
      (* LQP *)
      (Token: 'LOCUST QSO PARTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange)),
      (* ARKTIKA_SPRING *)
      (Token: 'ARKTIKA-SPRING';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* UNDX *)
      (Token: 'UN DX';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange)),
      (* NYQP *)
      (Token: 'NY-QSO-PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* KINGOFSPAINCW *)
      (Token: 'KING-OF-SPAIN-CW';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange)),
      (* KINGOFSPAINSSB *)
      (Token: 'KING-OF-SPAIN-SSB';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange)),
      (* WRTC *)
      (Token: 'WRTC';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange)),
      (* TENNESSEEQSOPARTY *)
      (Token: 'TENNESSEE QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* COLORADOQSOPARTY *)
      (Token: 'COLORADO QSO PARTY';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (* R9W_UW9WK_MEMORIAL *)
      (Token: 'R9W-UW9WK-MEMORIAL';
       AtUS: (Exchange: QSONumberAndZone; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberAndZone; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberAndZone; InitialExchange: NoInitialExchange)),
      (* PCC *)
      (Token: 'PCC';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* RADIOMEMORY *)
      (Token: 'RADIO-MEMORY';
       AtUS: (Exchange: RSTAgeAndPossibleSK; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAgeAndPossibleSK; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAgeAndPossibleSK; InitialExchange: NoInitialExchange)),
      (* DARC10M *)
      (Token: 'DARC-10M';
       AtUS: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* REFCW *)
      (Token: 'REF-CW';
       AtUS: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange)),
      (* REFSSB *)
      (Token: 'REF-SSB';
       AtUS: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndQSONumberOrFrenchDepartmentExchange; InitialExchange: NoInitialExchange)),
      (* BSCI *)
      (Token: 'BLACK SEA CUP';
       AtUS: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneOrSocietyExchange; InitialExchange: ZoneInitialExchange)),
      (* CQMM *)
      (Token: 'CQMM';
       AtUS: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndContinentExchange; InitialExchange: NoInitialExchange)),
      (* SASPRINT *)
      (Token: 'SA-SPRINT';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* CWOPS *)
      (Token: 'CWOPS';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange)),
      (* OZHCRVHF *)
      (Token: 'OZHCR-VHF';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: NoInitialExchange)),
      (* CANADA_DAY *)
      (Token: 'CANADA DAY';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* CQWWRTTY *)
      (Token: 'CQ-WW-RTTY';
       AtUS: (Exchange: RSTZoneAndPossibleDomesticQTHExchange; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneAndPossibleDomesticQTHExchange; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneAndPossibleDomesticQTHExchange; InitialExchange: ZoneInitialExchange)),
      (* CWOPEN *)
      (Token: 'CWOPEN';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange)),
      (* MAKROTHEN *)
      (Token: 'MAKROTHEN-RTTY';
       AtUS: (Exchange: GridExchange; InitialExchange: GridInitialExchange);
       AtVE: (Exchange: GridExchange; InitialExchange: GridInitialExchange);
       AtDX: (Exchange: GridExchange; InitialExchange: GridInitialExchange)),
      (* EUSPRINT_SPRING_SSB *)
      (Token: 'EU-SPRINT-SPRING-SSB';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange)),
      (* EUSPRINT_AUTUMN_CW *)
      (Token: 'EU-SPRINT-AUTUMN-CW';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange)),
      (* EUSPRINT_AUTUMN_SSB *)
      (Token: 'EU-SPRINT-AUTUMN-SSB';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NameInitialExchange)),
      (* ARRL_RTTY_ROUNDUP *)
      (Token: 'ARRL-RTTY';
       AtUS: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHOrQSONumberExchange; InitialExchange: NoInitialExchange)),
      (* CQIR *)
      (Token: 'CQIR';
       AtUS: (Exchange: QSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberAndPossibleDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* WWIH *)
      (Token: 'WWIH';
       AtUS: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneExchange; InitialExchange: ZoneInitialExchange)),
      (* ALRS_UA1DZ_CUP *)
      (Token: 'ALRS-UA1DZ-CUP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* WINTERFIELDDAY *)
      (Token: 'WINTER FIELD DAY';
       AtUS: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: ClassDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (* RADIOYOC *)
      (Token: 'RADIO-YOC';
       AtUS: (Exchange: QSONumberAndPreviousQSONumber; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberAndPreviousQSONumber; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberAndPreviousQSONumber; InitialExchange: NoInitialExchange)),
      (* PAQSOPARTY *)
      (Token: 'PA QSO PARTY';
       AtUS: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* INQSOPARTY *)
      (Token: 'IN QSO PARTY';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* OKOMSSB *)
      (Token: 'OK-OM DX SSB';
       AtUS: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAndQSONumberOrDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* BATAVIA_FT8 *)
      (Token: 'BATAVIA-FT8';
       AtUS: (Exchange: GridExchange; InitialExchange: GridInitialExchange);
       AtVE: (Exchange: GridExchange; InitialExchange: GridInitialExchange);
       AtDX: (Exchange: GridExchange; InitialExchange: GridInitialExchange)),
      (* WWDIGI *)
      (Token: 'WWDIGI';
       AtUS: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange);
       AtVE: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange);
       AtDX: (Exchange: Grid2Exchange; InitialExchange: GridInitialExchange)),
      (* MWC *)
      (Token: 'MWC';
       AtUS: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTQSONUMBEREXCHANGE; InitialExchange: NoInitialExchange)),
      (* IRTS *)
      (Token: 'IRTS';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: ZoneInitialExchange)),
      (* EUDX *)
      (Token: 'EUDX';
       AtUS: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTZoneOrDomesticQTH; InitialExchange: NoInitialExchange)),
      (* BCQP *)
      (Token: 'BCQP';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* VAQP *)
      (Token: 'VAQP';
       AtUS: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (* YOTA *)
      (Token: 'YOTA';
       AtUS: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTAgeExchange; InitialExchange: NoInitialExchange)),
      (* IN7QPNE *)
      (Token: 'IN7QPNE';
       AtUS: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (* MST *)
      (Token: 'MST';
       AtUS: (Exchange: QSONumberAndNameExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: QSONumberAndNameExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: QSONumberAndNameExchange; InitialExchange: NoInitialExchange)),
      (* SST *)
      (Token: 'SST';
       AtUS: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtVE: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange);
       AtDX: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NameQTHInitialExchange)),
      (* RTC *)
      (Token: 'RTC';
       AtUS: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: GridInitialExchange);
       AtVE: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: GridInitialExchange);
       AtDX: (Exchange: RSTQSONumberAndGridSquareExchange; InitialExchange: GridInitialExchange)),
      (* IDAHOQSOPARTY *)
      (Token: 'IDAHO QSO PARTY';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (* DELAWAREQSOPARTY *)
      (Token: 'DELAWARE QSO PARTY';
       AtUS: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtVE: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange);
       AtDX: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange))
   );

   (* GENERATED ONCE AT M11 S0b, with the table above. One row per party
      (IsUSQSOParty), ordered by the name of its frozen matrix record. *)
   HOST_KIND_PINS: array[1..22] of THostKindPin = (
      (Contest: ArizonaQsoParty; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'APH';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: BCQP; MyCall: 'VE7AAA'; MyCountry: 'VE'; MyState: 'ABF';
       MySection: 'BC'; MyGrid: 'CN89';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: CALQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alam';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: COLORADOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ada';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: DELAWAREQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'NDE';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: FLORIDAQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alc';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: IDAHOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ADA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: IN7QPNE; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Azaph';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: INQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'INADA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: MICHQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alco';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: MINNQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ait';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: NameAndDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: MOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ADR';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: NCQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ALA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: NYQP; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Alb';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: OHIOQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Adam';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTQSONumberAndDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: PAQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ADA';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: QSONumberDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: SALMONRUN; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ada';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: SEVENQP; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Azaph';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: TENNESSEEQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ande';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: TEXASQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ande';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: VAQP; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'ACC';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: QSONumberDomesticOrDXQTHExchange; InitialExchange: NoInitialExchange)),
      (Contest: WISCONSINQSOPARTY; MyCall: 'K0AAA'; MyCountry: 'K'; MyState: 'Ada';
       MySection: 'KS'; MyGrid: 'EM17';
       Kinds: (Exchange: RSTDomesticQTHExchange; InitialExchange: NoInitialExchange))
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
   finally
      stated.Free;
      end;
end;

function SameKinds(const a: TSessionKinds; const b: TSessionKinds): boolean;
begin
   Result := (a.Exchange = b.Exchange)               and
             (a.InitialExchange = b.InitialExchange);
end;

(* A kind's member, by name -- GetEnumName answers an AnsiString. *)
function KindName(aInfo: PTypeInfo; aOrdinal: integer): string;
begin
   Result := string(GetEnumName(aInfo, aOrdinal));
end;

(* Two assertions, by name, so a failure reads as the kind that moved. *)
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
   Inc(aChecked, 2);
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

   (* EXACT: every ContestType, DUMMYCONTEST included, two kinds at three
      stations (six until M11 S3 part 2, five until S4 part 2, four until
      S5 part 2, three until S6 part 2). *)
   CheckEquals(187, contests, 'contests whose kinds were checked');
   CheckEquals(187, Ord(High(ContestType)) + 1,
               'ContestType members -- a new contest adds its row here, by hand');
   CheckEquals(187 * 2 * 3, checked, 'kind assertions at us, ve and dx');
   (* THE STATION REACHES THE KINDS: at S0b these contests run another kind
      at one of us, ve and dx than at another -- ARRL160, ARRLDXCW,
      ARRLDXSSB, WAG, DARC10M. The rows determine this count, so it cannot
      move while they are green; it is stated so a reader sees the station
      reach the kinds. It was 7 until M11 S4 part 2 removed the DX column:
      DARCWAEDCCW and DARCWAEDCSSB varied in their DX kind only. The zone
      column (M11 S5 part 2) varied for no contest at these stations, so
      removing it left the count at 5. The domestic column (M11 S6 part 2)
      was the only one WAG and DARC10M varied in, so it is 3: ARRL160,
      ARRLDXCW and ARRLDXSSB, which vary in their exchange. Counted from the
      frozen matrix's active.* lines. *)
   CheckEquals(3, varying, 'contests whose kinds vary across us, ve and dx');
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
   CheckEquals(22 * 2, checked, 'kind assertions at us-host');
   (* IN THE HOST STATE THE KINDS DIFFER FROM THE us STATION'S for these
      parties at S0b -- ArizonaQsoParty, CALQSOPARTY, SALMONRUN, SEVENQP,
      TEXASQSOPARTY. It was 6 until M11 S4 part 2 removed the DX column:
      DELAWAREQSOPARTY differed in its DX kind only. No party differed in
      its zone kind (M11 S5 part 2) or its domestic kind (M11 S6 part 2). *)
   CheckEquals(5, varying, 'parties whose kinds differ in the host state');
end;

(* THE DOMESTIC FLAG FOLLOWS A CONTEST CHANGED WITHOUT A RESTART -- M11 S2,
  2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md F9, S0d); the contest's own
  answer since M11 S6 part 2.

  THE DEFECT. LOGDUPE held the four Doing*Mults flags as globals, and LogCfg
  derived them ONCE, at start-up, from the session's kinds. FoundContest
  rewrites the contest every time it runs, and it runs again when a
  multi-op peer sends a CONTEST line (uNet -> ApplyPeerCommand ->
  uSettingsEffects -> FoundContest). Measured at S0d on exactly that path:
  a CQ WW CW session switched to ARRL SS CW ran a domestic multiplier and
  no DX, prefix or zone one, while the flags stayed at CQ WW's FALSE TRUE
  FALSE TRUE.

  THE FIX IS STRUCTURAL, AND SINCE M11 S6 PART 2 COMPLETE. M11 S2 made the
  flags answers computed from the session's kinds; S3-S6 part 2 deleted the
  kinds, and each flag is the contest's own answer
  (LOGEDIT.Doing*Mults, TContestBase.Has*Multiplier), asked of the contest
  that is open now -- there is no store anywhere to go stale. Every member
  of each kind and the every-contest switch this test drove through the
  session went with the kinds; what is left is S0d's measured pair, by
  literal, through the reader the engine asks. Whether each contest has a
  domestic multiplier at each station is uTestDomesticMultiplier's pin.

  WHAT THIS DOES NOT DRIVE: FoundContest itself (it writes Settings, the
  domestic country list and the contest title, which this binary's other
  suites read). The peer path end to end is a bench check. *)
procedure TContestKindPinTests.Test_DoingFlagsFollowEveryContestSwitch;
var
   savedContest: ContestType;
begin
   BeginTest('Test_DoingFlagsFollowEveryContestSwitch');
   savedContest := Contest;
   try
      Contest := CQWWCW;
      CheckFalse(DoingDomesticMults, 'CQ WW CW: no domestic multiplier');
      Contest := ARRLSSCW;
      CheckTrue(DoingDomesticMults, 'CQ WW CW switched to ARRL SS CW: a domestic multiplier');
      Contest := CQWWCW;
      CheckFalse(DoingDomesticMults, 'and back to CQ WW CW: none');
   finally
      Contest := savedContest;
      ReleaseActiveContest;
      end;
end;

end.
