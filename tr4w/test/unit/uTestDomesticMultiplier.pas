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

(* THE DOMESTIC MULTIPLIER RULES EVERY CONTEST STATES, AT STATIONS THE
  CONTEST MATRIX DOES NOT RUN -- M11 S6 part 1, 2026-10-14
  (docs/CONTEST_FACTORY_M11_PLAN.md S6).

  WHY IT EXISTS. S6 part 1 moves the readers of the session's DOMESTIC KIND
  that are NOT the domestic file into the classes:
  - LOGDOM.GetDomQTH's six kind arms (RDA, WYSIWYG, DOK, IOTA, grid square,
    grid field) -- what a received domestic QTH means, before the domestic
    file is consulted;
  - LOGSTUFF.DomStringParse's five arms -- the need-multiplier hint's copy
    of the same rules (plan F6);
  - the grid-square tests (rover dupes, the partial-call mults, the grid
    status), the grid-field tests (the sheet's legacy key, WSJT-X), the
    WYSIWYG guard in GetDXQTH and POSTUNIT's "an RDA district is not a
    grid".
  The matrix pins the kinds at its own stations and S0c's parse cases run
  GetDomQTH there. It cannot see a branch only another entrant takes: the
  ALRS cup at a Russian station outside St Petersburg (RDA districts), WAG
  and the DARC 10 m at a German one. So this unit freezes, as LITERALS, what
  each of the 25 contests whose domestic QTH is not looked up in a file
  gives for a fixed set of texts at a fixed roster of stations.

  HOW THE LITERALS WERE MADE. Laid out by a scratch transcription of the
  two old routines, then RUN GREEN AGAINST THE OLD CODE before anything
  moved: the program's own arms, frozen here then (Legacy...OfKind),
  selected by the session kind uTestContestKindPin.Kinds resolved -- the
  trait, and DescribeSession over it -- exactly what the engine selected.
  Then the move, and the same tables green against the classes. Part 1b
  (the domestic file) was pinned the same way.

  THE CROSS-CHECKS ARE GONE, WITH THE KIND -- M11 S6 part 2, 2026-10-14.
  The *AgreesWith* tests compared every ContestType at every roster station
  with the frozen legacy rules under the session's kind; DomesticMultType
  is deleted, and they and the frozen rules went with it. The literals stay,
  and so do the invariants that tie the answers to each other: a contest
  that uses its file states no shape, and HasDomesticMultiplier -- whether
  the engine reads a domestic QTH at all -- is True exactly where one is
  read.

  AN ANSWER IS FOUR THINGS, written on one line so a failure reads whole:
  whether the domestic FILE is consulted next ('file') or the contest has
  decided ('decided'), whether the QTH was found, the multiplier and the
  QTH. 'file' with a key is real: the RSGB IOTA's valid reference falls
  through to the file lookup with the key already set (plan F6) -- a
  quirk kept exactly.

  THE DOK HINT FOR A TEXT WITH NO LETTER is pinned on its own, by
  Test_ADOKTextWithNoLetterHintsNothing: DomStringParse returned a local it
  never assigned (plan F6), so the old value was undefined and the
  cross-check skipped it; since the F6 fix (2026-10-14) both DOK classes
  answer an empty hint.

  NEVER REGENERATE IT TO CLEAR A FAILURE -- the uTestContestKindPin rule. A
  failure means a contest's domestic rule changed. *)
unit uTestDomesticMultiplier;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TDomesticMultiplierTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EveryContestGivesItsPinnedDomesticKey;
      procedure Test_EveryContestGivesItsPinnedHint;
      procedure Test_EveryContestStatesItsPinnedDomesticAnswers;
      procedure Test_ADOKTextWithNoLetterHintsNothing;
      procedure Test_EveryContestStatesItsPinnedDomesticFileAnswer;
      procedure Test_ADomesticFileContestStatesNoShape;
      procedure Test_EveryContestHasItsPinnedDomesticMultiplier;
      procedure Test_ADomesticMultiplierIsWhereAQTHIsRead;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uTestContestObjects,
   uTestContestKindPin,
   (* ContestsToWalk -- the invariants walk the registry (Q108 S1). *)
   uTestRegisteredContests;

type
   (* The entrants. us, ve and dx are the matrix's (dx is German); host is a
      New England station inside its party's host state; the rest take the
      DescribeSession branches the matrix never reaches. UA is a Russian
      station outside St Petersburg and its oblast, UA1 one inside it. *)
   TPinStation = (psUS, psVE, psDX, psHost, psUA, psUA1, psJA, psOK, psON,
                  psUR, psYU);

   (* The received texts, already upper case as GetDomQTH and
      DomStringParse make them. Several are chosen to read as more than one
      thing: MO12 is an RDA district and a grid square, EU12 an IOTA
      reference, an RDA district and a grid square. *)
   TPinText = (ptState, ptRDA, ptGrid4, ptGrid6, ptGrid6Bad, ptZZ, ptIOTA4,
               ptIOTA3, ptIOTA5, ptIOTA6, ptNoCont, ptNonNum, ptDash, ptDOK,
               ptDigits, ptLong);

   (* The four yes/no answers part 1 moved. *)
   TPinFlag = (pfGridSquare, pfGridField, pfReplacesDX, pfNeverAGrid);

   TStationRow = record
      Call: string;
      Country: string;
      Continent: ContinentType;
      State: string;
      InHostState: boolean;
   end;

   TKeyPin = record
      Contest: ContestType;
      Station: TPinStation;
      Text: TPinText;
      Answer: string;
   end;

   THintPin = record
      Contest: ContestType;
      Station: TPinStation;
      Text: TPinText;
      Hint: string;
   end;

const
   STATIONS: array[TPinStation] of TStationRow = (
      (Call: 'K0AAA';  Country: 'K';  Continent: NorthAmerica; State: 'KS'; InHostState: False),
      (Call: 'VE3AAA'; Country: 'VE'; Continent: NorthAmerica; State: 'ON'; InHostState: False),
      (Call: 'DL1AAA'; Country: 'DL'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'K1AAA';  Country: 'K';  Continent: NorthAmerica; State: 'MA'; InHostState: True),
      (Call: 'UA3AAA'; Country: 'UA'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'UA1AAA'; Country: 'UA'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'JA1AAA'; Country: 'JA'; Continent: Asia;         State: '';   InHostState: False),
      (Call: 'OK1AAA'; Country: 'OK'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'ON4AAA'; Country: 'ON'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'UR5AAA'; Country: 'UR'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'YU1AAA'; Country: 'YU'; Continent: Europe;       State: '';   InHostState: False)
   );

   TEXTS: array[TPinText] of string = (
      'KS', 'MO12', 'FN20', 'FN20AB', 'FN201B', 'ZZ12', 'EU12', 'NA1', 'OC123',
      'EU1234', 'XX12', 'EUAB', 'EU-12', 'B01', '123', 'ABCDEFGHIJKLMNOPQR'
   );

   FLAG_NAMES: array[TPinFlag] of string = (
      'grid square', 'grid field', 'replaces DX', 'never a grid'
   );

   (* THE CONTESTS THAT ANSWER EACH FLAG, at every station but the ones the
      tests below name. *)
   GRID_SQUARE_CONTESTS = [ARRLVHFJAN, ARRLVHFJUN, ARRLVHFSEP, CQVHF,
                           OZHCRVHF, RTC];
   GRID_FIELD_CONTESTS = [CUPRFCW, CUPRFSSB, TOEC, WWDIGI, WWL];
   WYSIWYG_EVERYWHERE = [ARKTIKA_SPRING, BSCI, DARCXMAS, GAGARINCUP, GRIDLOC,
                         IARU, OZCR_Z, UA4WCHAMPIONSHIP, WRTC];

   (* THE CONTESTS THAT STATE A SHAPE OF THEIR OWN AT SOME STATION -- the
      three sets above and the four whose shape has no flag (the ALRS cup,
      the DARC 10 m, the RSGB IOTA, RDA) and WAG; the same sets
      PinnedHasDomestic reads, so never a second list. *)
   SHAPE_SOMEWHERE = GRID_SQUARE_CONTESTS + GRID_FIELD_CONTESTS + WYSIWYG_EVERYWHERE +
                     [ALRS_UA1DZ_CUP, DARC10M, IOTA, RDA, WAG];

   (* THE CONTESTS WHOSE DOMESTIC QTH IS LOOKED UP IN THEIR DOMESTIC FILE AT
      EVERY STATION -- M11 S6 part 1b. 85 of the 94 that do at some station;
      the other nine depend on the entrant (FILE_STATION_PINS). Written from
      each class's trait and DescribeSession and run green against the
      session kind before the answer moved. *)
   DOMESTIC_FILE_EVERYWHERE = [
      ALLJA, ARCI, ARI_DX, ARRL10, ARRL160, ARRLFIELDDAY, ARRLSSCW,
      ARRLSSSSB, ARRL_RTTY_ROUNDUP, ArizonaQsoParty, BCQP, CALQSOPARTY,
      CANADA_DAY, CANADA_WINTER, CIS, COLORADOQSOPARTY, CQ160CW, CQ160SSB,
      CQIR, CQWWRTTY, CROATIAN, CUPRFDIG, CUPURAL, DELAWAREQSOPARTY, NEBRASKAQSO, EUDX,
      FISTS, FLORIDAQSOPARTY, FOCMARATHON, HADX, HELVETIA, IDAHOQSOPARTY,
      IN7QPNE, INQSOPARTY, INTERNETSPRINT, IRTS, JALONGPREFECT, KCJ,
      KINGOFSPAINCW, KINGOFSPAINSSB, LABRE, LQP, LZDX, MICHQSOPARTY,
      MINNQSOPARTY, MOQSOPARTY, MWC, NAQSOCW, NAQSORTTY, NAQSOSSB, NASPRINTCW,
      NASPRINTRTTY, NCCCSPRINT, NCQSOPARTY, NEWENGLANDQSO, NRAUBALTICCW,
      NRAUBALTICSSB, NYQP, OHIOQSOPARTY, OKOMSSB, PACC, PAQSOPARTY, REFCW,
      REFSSB, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB, RSGB18, RU3AXMEMORIAL,
      RUSSIANDX, SALMONRUN, SEVENQP, SPDX, SPRINTSSB, SST, TENNESSEEQSOPARTY,
      TEXASQSOPARTY, UKEI, UKRAINECHAMPIONSHIP, UNDX, VAQP, WINTERFIELDDAY,
      WISCONSINQSOPARTY, WWPMC, YODX, YOTA, YOUTHCHAMPIONSHIPRF];

   (* WRITTEN FROM THE OLD ROUTINES AND RUN GREEN AGAINST THEM -- see the
      unit header. Every one of the 25 contests has rows for every branch
      its rule has, and seven domestic-file contests have the base's. *)
   KEY_PINS: array[0..138] of TKeyPin = (
      (Contest: ARKTIKA_SPRING;    Station: psUS;  Text: ptState;    Answer: 'decided T [KS] [KS]'),
      (Contest: ARKTIKA_SPRING;    Station: psUS;  Text: ptLong;     Answer: 'decided T [ABCDEFGHIJ] [ABCDEFGHIJ]'),
      (Contest: ARKTIKA_SPRING;    Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO12] [MO12]'),
      (Contest: BSCI;              Station: psUS;  Text: ptState;    Answer: 'decided T [KS] [KS]'),
      (Contest: BSCI;              Station: psUS;  Text: ptLong;     Answer: 'decided T [ABCDEFGHIJ] [ABCDEFGHIJ]'),
      (Contest: BSCI;              Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO12] [MO12]'),
      (Contest: DARCXMAS;          Station: psUS;  Text: ptState;    Answer: 'decided T [KS] [KS]'),
      (Contest: DARCXMAS;          Station: psUS;  Text: ptLong;     Answer: 'decided T [ABCDEFGHIJ] [ABCDEFGHIJ]'),
      (Contest: DARCXMAS;          Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO12] [MO12]'),
      (Contest: GAGARINCUP;        Station: psUS;  Text: ptState;    Answer: 'decided T [KS] [KS]'),
      (Contest: GAGARINCUP;        Station: psUS;  Text: ptLong;     Answer: 'decided T [ABCDEFGHIJ] [ABCDEFGHIJ]'),
      (Contest: GAGARINCUP;        Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO12] [MO12]'),
      (Contest: GRIDLOC;           Station: psUS;  Text: ptState;    Answer: 'decided T [KS] [KS]'),
      (Contest: GRIDLOC;           Station: psUS;  Text: ptLong;     Answer: 'decided T [ABCDEFGHIJ] [ABCDEFGHIJ]'),
      (Contest: GRIDLOC;           Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO12] [MO12]'),
      (Contest: IARU;              Station: psUS;  Text: ptState;    Answer: 'decided T [KS] [KS]'),
      (Contest: IARU;              Station: psUS;  Text: ptLong;     Answer: 'decided T [ABCDEFGHIJ] [ABCDEFGHIJ]'),
      (Contest: IARU;              Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO12] [MO12]'),
      (Contest: OZCR_Z;            Station: psUS;  Text: ptState;    Answer: 'decided T [KS] [KS]'),
      (Contest: OZCR_Z;            Station: psUS;  Text: ptLong;     Answer: 'decided T [ABCDEFGHIJ] [ABCDEFGHIJ]'),
      (Contest: OZCR_Z;            Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO12] [MO12]'),
      (Contest: UA4WCHAMPIONSHIP;  Station: psUS;  Text: ptState;    Answer: 'decided T [KS] [KS]'),
      (Contest: UA4WCHAMPIONSHIP;  Station: psUS;  Text: ptLong;     Answer: 'decided T [ABCDEFGHIJ] [ABCDEFGHIJ]'),
      (Contest: UA4WCHAMPIONSHIP;  Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO12] [MO12]'),
      (Contest: WRTC;              Station: psUS;  Text: ptState;    Answer: 'decided T [KS] [KS]'),
      (Contest: WRTC;              Station: psUS;  Text: ptLong;     Answer: 'decided T [ABCDEFGHIJ] [ABCDEFGHIJ]'),
      (Contest: WRTC;              Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO12] [MO12]'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUS;  Text: ptState;    Answer: 'decided T [KS] [KS]'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUS;  Text: ptLong;     Answer: 'decided T [ABCDEFGHIJ] [ABCDEFGHIJ]'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO12] [MO12]'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA1; Text: ptState;    Answer: 'decided T [KS] [KS]'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA1; Text: ptLong;     Answer: 'decided T [ABCDEFGHIJ] [ABCDEFGHIJ]'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA1; Text: ptRDA;      Answer: 'decided T [MO12] [MO12]'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA;  Text: ptRDA;      Answer: 'decided T [MO12] [MO12]'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA;  Text: ptZZ;       Answer: 'decided T [ZZ12] [ZZ12]'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA;  Text: ptGrid6;    Answer: 'decided F [] []'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA;  Text: ptNonNum;   Answer: 'decided F [] []'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA;  Text: ptState;    Answer: 'decided F [] []'),
      (Contest: RDA;               Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO12] [MO12]'),
      (Contest: RDA;               Station: psUS;  Text: ptZZ;       Answer: 'decided T [ZZ12] [ZZ12]'),
      (Contest: RDA;               Station: psUS;  Text: ptGrid6;    Answer: 'decided F [] []'),
      (Contest: RDA;               Station: psUS;  Text: ptNonNum;   Answer: 'decided F [] []'),
      (Contest: RDA;               Station: psUS;  Text: ptState;    Answer: 'decided F [] []'),
      (Contest: RDA;               Station: psUA;  Text: ptIOTA4;    Answer: 'decided T [EU12] [EU12]'),
      (Contest: DARC10M;           Station: psDX;  Text: ptState;    Answer: 'decided T [KS] [KS]'),
      (Contest: DARC10M;           Station: psDX;  Text: ptLong;     Answer: 'decided T [ABCDEFGHIJ] [ABCDEFGHIJ]'),
      (Contest: DARC10M;           Station: psDX;  Text: ptRDA;      Answer: 'decided T [MO12] [MO12]'),
      (Contest: DARC10M;           Station: psUS;  Text: ptDOK;      Answer: 'decided T [B] [B01]'),
      (Contest: DARC10M;           Station: psUS;  Text: ptDigits;   Answer: 'decided F [] [123]'),
      (Contest: DARC10M;           Station: psUS;  Text: ptLong;     Answer: 'decided T [A] [ABCDEFGHIJ]'),
      (Contest: DARC10M;           Station: psUS;  Text: ptDash;     Answer: 'decided T [E] [EU-12]'),
      (Contest: WAG;               Station: psUS;  Text: ptDOK;      Answer: 'decided T [B] [B01]'),
      (Contest: WAG;               Station: psUS;  Text: ptDigits;   Answer: 'decided F [] [123]'),
      (Contest: WAG;               Station: psUS;  Text: ptLong;     Answer: 'decided T [A] [ABCDEFGHIJ]'),
      (Contest: WAG;               Station: psUS;  Text: ptDash;     Answer: 'decided T [E] [EU-12]'),
      (Contest: WAG;               Station: psJA;  Text: ptState;    Answer: 'decided T [K] [KS]'),
      (Contest: WAG;               Station: psDX;  Text: ptDOK;      Answer: 'file F [] []'),
      (Contest: IOTA;              Station: psUS;  Text: ptIOTA4;    Answer: 'file T [EU-012] [EU-012]'),
      (Contest: IOTA;              Station: psUS;  Text: ptIOTA3;    Answer: 'file T [NA-001] [NA-001]'),
      (Contest: IOTA;              Station: psUS;  Text: ptIOTA5;    Answer: 'file T [OC-123] [OC-123]'),
      (Contest: IOTA;              Station: psUS;  Text: ptIOTA6;    Answer: 'decided F [] []'),
      (Contest: IOTA;              Station: psUS;  Text: ptNoCont;   Answer: 'file F [] []'),
      (Contest: IOTA;              Station: psUS;  Text: ptNonNum;   Answer: 'decided F [] []'),
      (Contest: IOTA;              Station: psUS;  Text: ptDash;     Answer: 'decided F [] []'),
      (Contest: IOTA;              Station: psUS;  Text: ptState;    Answer: 'decided F [] []'),
      (Contest: IOTA;              Station: psUS;  Text: ptRDA;      Answer: 'file F [] []'),
      (Contest: IOTA;              Station: psUS;  Text: ptDOK;      Answer: 'file F [] []'),
      (Contest: IOTA;              Station: psUS;  Text: ptLong;     Answer: 'decided F [] []'),
      (Contest: ARRLVHFJAN;        Station: psUS;  Text: ptGrid4;    Answer: 'decided T [FN20] [FN20]'),
      (Contest: ARRLVHFJAN;        Station: psUS;  Text: ptGrid6;    Answer: 'decided T [FN20] [FN20AB]'),
      (Contest: ARRLVHFJAN;        Station: psUS;  Text: ptGrid6Bad; Answer: 'decided F [] []'),
      (Contest: ARRLVHFJAN;        Station: psUS;  Text: ptZZ;       Answer: 'decided F [] []'),
      (Contest: ARRLVHFJAN;        Station: psUS;  Text: ptDigits;   Answer: 'decided F [] []'),
      (Contest: ARRLVHFJUN;        Station: psUS;  Text: ptGrid4;    Answer: 'decided T [FN20] [FN20]'),
      (Contest: ARRLVHFJUN;        Station: psUS;  Text: ptGrid6;    Answer: 'decided T [FN20] [FN20AB]'),
      (Contest: ARRLVHFJUN;        Station: psUS;  Text: ptGrid6Bad; Answer: 'decided F [] []'),
      (Contest: ARRLVHFJUN;        Station: psUS;  Text: ptZZ;       Answer: 'decided F [] []'),
      (Contest: ARRLVHFJUN;        Station: psUS;  Text: ptDigits;   Answer: 'decided F [] []'),
      (Contest: ARRLVHFSEP;        Station: psUS;  Text: ptGrid4;    Answer: 'decided T [FN20] [FN20]'),
      (Contest: ARRLVHFSEP;        Station: psUS;  Text: ptGrid6;    Answer: 'decided T [FN20] [FN20AB]'),
      (Contest: ARRLVHFSEP;        Station: psUS;  Text: ptGrid6Bad; Answer: 'decided F [] []'),
      (Contest: ARRLVHFSEP;        Station: psUS;  Text: ptZZ;       Answer: 'decided F [] []'),
      (Contest: ARRLVHFSEP;        Station: psUS;  Text: ptDigits;   Answer: 'decided F [] []'),
      (Contest: CQVHF;             Station: psUS;  Text: ptGrid4;    Answer: 'decided T [FN20] [FN20]'),
      (Contest: CQVHF;             Station: psUS;  Text: ptGrid6;    Answer: 'decided T [FN20] [FN20AB]'),
      (Contest: CQVHF;             Station: psUS;  Text: ptGrid6Bad; Answer: 'decided F [] []'),
      (Contest: CQVHF;             Station: psUS;  Text: ptZZ;       Answer: 'decided F [] []'),
      (Contest: CQVHF;             Station: psUS;  Text: ptDigits;   Answer: 'decided F [] []'),
      (Contest: OZHCRVHF;          Station: psUS;  Text: ptGrid4;    Answer: 'decided T [FN20] [FN20]'),
      (Contest: OZHCRVHF;          Station: psUS;  Text: ptGrid6;    Answer: 'decided T [FN20] [FN20AB]'),
      (Contest: OZHCRVHF;          Station: psUS;  Text: ptGrid6Bad; Answer: 'decided F [] []'),
      (Contest: OZHCRVHF;          Station: psUS;  Text: ptZZ;       Answer: 'decided F [] []'),
      (Contest: OZHCRVHF;          Station: psUS;  Text: ptDigits;   Answer: 'decided F [] []'),
      (Contest: RTC;               Station: psUS;  Text: ptGrid4;    Answer: 'decided T [FN20] [FN20]'),
      (Contest: RTC;               Station: psUS;  Text: ptGrid6;    Answer: 'decided T [FN20] [FN20AB]'),
      (Contest: RTC;               Station: psUS;  Text: ptGrid6Bad; Answer: 'decided F [] []'),
      (Contest: RTC;               Station: psUS;  Text: ptZZ;       Answer: 'decided F [] []'),
      (Contest: RTC;               Station: psUS;  Text: ptDigits;   Answer: 'decided F [] []'),
      (Contest: CUPRFCW;           Station: psUS;  Text: ptGrid4;    Answer: 'decided T [FN] [FN20]'),
      (Contest: CUPRFCW;           Station: psUS;  Text: ptGrid6;    Answer: 'decided F [] []'),
      (Contest: CUPRFCW;           Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO] [MO12]'),
      (Contest: CUPRFCW;           Station: psUS;  Text: ptZZ;       Answer: 'decided F [] []'),
      (Contest: CUPRFSSB;          Station: psUS;  Text: ptGrid4;    Answer: 'decided T [FN] [FN20]'),
      (Contest: CUPRFSSB;          Station: psUS;  Text: ptGrid6;    Answer: 'decided F [] []'),
      (Contest: CUPRFSSB;          Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO] [MO12]'),
      (Contest: CUPRFSSB;          Station: psUS;  Text: ptZZ;       Answer: 'decided F [] []'),
      (Contest: TOEC;              Station: psUS;  Text: ptGrid4;    Answer: 'decided T [FN] [FN20]'),
      (Contest: TOEC;              Station: psUS;  Text: ptGrid6;    Answer: 'decided F [] []'),
      (Contest: TOEC;              Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO] [MO12]'),
      (Contest: TOEC;              Station: psUS;  Text: ptZZ;       Answer: 'decided F [] []'),
      (Contest: WWDIGI;            Station: psUS;  Text: ptGrid4;    Answer: 'decided T [FN] [FN20]'),
      (Contest: WWDIGI;            Station: psUS;  Text: ptGrid6;    Answer: 'decided F [] []'),
      (Contest: WWDIGI;            Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO] [MO12]'),
      (Contest: WWDIGI;            Station: psUS;  Text: ptZZ;       Answer: 'decided F [] []'),
      (Contest: WWL;               Station: psUS;  Text: ptGrid4;    Answer: 'decided T [FN] [FN20]'),
      (Contest: WWL;               Station: psUS;  Text: ptGrid6;    Answer: 'decided F [] []'),
      (Contest: WWL;               Station: psUS;  Text: ptRDA;      Answer: 'decided T [MO] [MO12]'),
      (Contest: WWL;               Station: psUS;  Text: ptZZ;       Answer: 'decided F [] []'),
      (Contest: CALQSOPARTY;       Station: psUS;  Text: ptState;    Answer: 'file F [] []'),
      (Contest: CALQSOPARTY;       Station: psUS;  Text: ptRDA;      Answer: 'file F [] []'),
      (Contest: CALQSOPARTY;       Station: psUS;  Text: ptIOTA4;    Answer: 'file F [] []'),
      (Contest: ARRLDXCW;          Station: psDX;  Text: ptState;    Answer: 'file F [] []'),
      (Contest: ARRLDXCW;          Station: psDX;  Text: ptRDA;      Answer: 'file F [] []'),
      (Contest: ARRLDXCW;          Station: psDX;  Text: ptIOTA4;    Answer: 'file F [] []'),
      (Contest: JIDXCW;            Station: psUS;  Text: ptState;    Answer: 'file F [] []'),
      (Contest: JIDXCW;            Station: psUS;  Text: ptRDA;      Answer: 'file F [] []'),
      (Contest: JIDXCW;            Station: psUS;  Text: ptIOTA4;    Answer: 'file F [] []'),
      (Contest: OKDX;              Station: psUS;  Text: ptState;    Answer: 'file F [] []'),
      (Contest: OKDX;              Station: psUS;  Text: ptRDA;      Answer: 'file F [] []'),
      (Contest: OKDX;              Station: psUS;  Text: ptIOTA4;    Answer: 'file F [] []'),
      (Contest: UBACW;             Station: psUS;  Text: ptState;    Answer: 'file F [] []'),
      (Contest: UBACW;             Station: psUS;  Text: ptRDA;      Answer: 'file F [] []'),
      (Contest: UBACW;             Station: psUS;  Text: ptIOTA4;    Answer: 'file F [] []'),
      (Contest: NAQSOCW;           Station: psVE;  Text: ptState;    Answer: 'file F [] []'),
      (Contest: NAQSOCW;           Station: psVE;  Text: ptRDA;      Answer: 'file F [] []'),
      (Contest: NAQSOCW;           Station: psVE;  Text: ptIOTA4;    Answer: 'file F [] []'),
      (Contest: RSGB18;            Station: psDX;  Text: ptState;    Answer: 'file F [] []'),
      (Contest: RSGB18;            Station: psDX;  Text: ptRDA;      Answer: 'file F [] []'),
      (Contest: RSGB18;            Station: psDX;  Text: ptIOTA4;    Answer: 'file F [] []')
   );

   (* WHAT THE NEED-MULTIPLIER HINT SHOWS -- the same rows, but for the DOK
      texts with no letter (see the unit header). *)
   HINT_PINS: array[0..136] of THintPin = (
      (Contest: ARKTIKA_SPRING;    Station: psUS;  Text: ptState;    Hint: 'KS'),
      (Contest: ARKTIKA_SPRING;    Station: psUS;  Text: ptLong;     Hint: 'ABCDEFGHIJKLMN'),
      (Contest: ARKTIKA_SPRING;    Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: BSCI;              Station: psUS;  Text: ptState;    Hint: 'KS'),
      (Contest: BSCI;              Station: psUS;  Text: ptLong;     Hint: 'ABCDEFGHIJKLMN'),
      (Contest: BSCI;              Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: DARCXMAS;          Station: psUS;  Text: ptState;    Hint: 'KS'),
      (Contest: DARCXMAS;          Station: psUS;  Text: ptLong;     Hint: 'ABCDEFGHIJKLMN'),
      (Contest: DARCXMAS;          Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: GAGARINCUP;        Station: psUS;  Text: ptState;    Hint: 'KS'),
      (Contest: GAGARINCUP;        Station: psUS;  Text: ptLong;     Hint: 'ABCDEFGHIJKLMN'),
      (Contest: GAGARINCUP;        Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: GRIDLOC;           Station: psUS;  Text: ptState;    Hint: 'KS'),
      (Contest: GRIDLOC;           Station: psUS;  Text: ptLong;     Hint: 'ABCDEFGHIJKLMN'),
      (Contest: GRIDLOC;           Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: IARU;              Station: psUS;  Text: ptState;    Hint: 'KS'),
      (Contest: IARU;              Station: psUS;  Text: ptLong;     Hint: 'ABCDEFGHIJKLMN'),
      (Contest: IARU;              Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: OZCR_Z;            Station: psUS;  Text: ptState;    Hint: 'KS'),
      (Contest: OZCR_Z;            Station: psUS;  Text: ptLong;     Hint: 'ABCDEFGHIJKLMN'),
      (Contest: OZCR_Z;            Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: UA4WCHAMPIONSHIP;  Station: psUS;  Text: ptState;    Hint: 'KS'),
      (Contest: UA4WCHAMPIONSHIP;  Station: psUS;  Text: ptLong;     Hint: 'ABCDEFGHIJKLMN'),
      (Contest: UA4WCHAMPIONSHIP;  Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: WRTC;              Station: psUS;  Text: ptState;    Hint: 'KS'),
      (Contest: WRTC;              Station: psUS;  Text: ptLong;     Hint: 'ABCDEFGHIJKLMN'),
      (Contest: WRTC;              Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUS;  Text: ptState;    Hint: 'KS'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUS;  Text: ptLong;     Hint: 'ABCDEFGHIJKLMN'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA1; Text: ptState;    Hint: 'KS'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA1; Text: ptLong;     Hint: 'ABCDEFGHIJKLMN'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA1; Text: ptRDA;      Hint: 'MO12'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA;  Text: ptZZ;       Hint: 'ZZ12'),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA;  Text: ptGrid6;    Hint: ''),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA;  Text: ptNonNum;   Hint: ''),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA;  Text: ptState;    Hint: ''),
      (Contest: RDA;               Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: RDA;               Station: psUS;  Text: ptZZ;       Hint: 'ZZ12'),
      (Contest: RDA;               Station: psUS;  Text: ptGrid6;    Hint: ''),
      (Contest: RDA;               Station: psUS;  Text: ptNonNum;   Hint: ''),
      (Contest: RDA;               Station: psUS;  Text: ptState;    Hint: ''),
      (Contest: RDA;               Station: psUA;  Text: ptIOTA4;    Hint: 'EU12'),
      (Contest: DARC10M;           Station: psDX;  Text: ptState;    Hint: 'KS'),
      (Contest: DARC10M;           Station: psDX;  Text: ptLong;     Hint: 'ABCDEFGHIJKLMN'),
      (Contest: DARC10M;           Station: psDX;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: DARC10M;           Station: psUS;  Text: ptDOK;      Hint: 'B'),
      (Contest: DARC10M;           Station: psUS;  Text: ptLong;     Hint: 'A'),
      (Contest: DARC10M;           Station: psUS;  Text: ptDash;     Hint: 'E'),
      (Contest: WAG;               Station: psUS;  Text: ptDOK;      Hint: 'B'),
      (Contest: WAG;               Station: psUS;  Text: ptLong;     Hint: 'A'),
      (Contest: WAG;               Station: psUS;  Text: ptDash;     Hint: 'E'),
      (Contest: WAG;               Station: psJA;  Text: ptState;    Hint: 'K'),
      (Contest: WAG;               Station: psDX;  Text: ptDOK;      Hint: 'B01'),
      (Contest: IOTA;              Station: psUS;  Text: ptIOTA4;    Hint: 'EU-012'),
      (Contest: IOTA;              Station: psUS;  Text: ptIOTA3;    Hint: 'NA-001'),
      (Contest: IOTA;              Station: psUS;  Text: ptIOTA5;    Hint: 'OC-123'),
      (Contest: IOTA;              Station: psUS;  Text: ptIOTA6;    Hint: ''),
      (Contest: IOTA;              Station: psUS;  Text: ptNoCont;   Hint: ''),
      (Contest: IOTA;              Station: psUS;  Text: ptNonNum;   Hint: ''),
      (Contest: IOTA;              Station: psUS;  Text: ptDash;     Hint: ''),
      (Contest: IOTA;              Station: psUS;  Text: ptState;    Hint: ''),
      (Contest: IOTA;              Station: psUS;  Text: ptRDA;      Hint: ''),
      (Contest: IOTA;              Station: psUS;  Text: ptDOK;      Hint: ''),
      (Contest: IOTA;              Station: psUS;  Text: ptLong;     Hint: ''),
      (Contest: ARRLVHFJAN;        Station: psUS;  Text: ptGrid4;    Hint: 'FN20'),
      (Contest: ARRLVHFJAN;        Station: psUS;  Text: ptGrid6;    Hint: 'FN20'),
      (Contest: ARRLVHFJAN;        Station: psUS;  Text: ptGrid6Bad; Hint: ''),
      (Contest: ARRLVHFJAN;        Station: psUS;  Text: ptZZ;       Hint: ''),
      (Contest: ARRLVHFJAN;        Station: psUS;  Text: ptDigits;   Hint: ''),
      (Contest: ARRLVHFJUN;        Station: psUS;  Text: ptGrid4;    Hint: 'FN20'),
      (Contest: ARRLVHFJUN;        Station: psUS;  Text: ptGrid6;    Hint: 'FN20'),
      (Contest: ARRLVHFJUN;        Station: psUS;  Text: ptGrid6Bad; Hint: ''),
      (Contest: ARRLVHFJUN;        Station: psUS;  Text: ptZZ;       Hint: ''),
      (Contest: ARRLVHFJUN;        Station: psUS;  Text: ptDigits;   Hint: ''),
      (Contest: ARRLVHFSEP;        Station: psUS;  Text: ptGrid4;    Hint: 'FN20'),
      (Contest: ARRLVHFSEP;        Station: psUS;  Text: ptGrid6;    Hint: 'FN20'),
      (Contest: ARRLVHFSEP;        Station: psUS;  Text: ptGrid6Bad; Hint: ''),
      (Contest: ARRLVHFSEP;        Station: psUS;  Text: ptZZ;       Hint: ''),
      (Contest: ARRLVHFSEP;        Station: psUS;  Text: ptDigits;   Hint: ''),
      (Contest: CQVHF;             Station: psUS;  Text: ptGrid4;    Hint: 'FN20'),
      (Contest: CQVHF;             Station: psUS;  Text: ptGrid6;    Hint: 'FN20'),
      (Contest: CQVHF;             Station: psUS;  Text: ptGrid6Bad; Hint: ''),
      (Contest: CQVHF;             Station: psUS;  Text: ptZZ;       Hint: ''),
      (Contest: CQVHF;             Station: psUS;  Text: ptDigits;   Hint: ''),
      (Contest: OZHCRVHF;          Station: psUS;  Text: ptGrid4;    Hint: 'FN20'),
      (Contest: OZHCRVHF;          Station: psUS;  Text: ptGrid6;    Hint: 'FN20'),
      (Contest: OZHCRVHF;          Station: psUS;  Text: ptGrid6Bad; Hint: ''),
      (Contest: OZHCRVHF;          Station: psUS;  Text: ptZZ;       Hint: ''),
      (Contest: OZHCRVHF;          Station: psUS;  Text: ptDigits;   Hint: ''),
      (Contest: RTC;               Station: psUS;  Text: ptGrid4;    Hint: 'FN20'),
      (Contest: RTC;               Station: psUS;  Text: ptGrid6;    Hint: 'FN20'),
      (Contest: RTC;               Station: psUS;  Text: ptGrid6Bad; Hint: ''),
      (Contest: RTC;               Station: psUS;  Text: ptZZ;       Hint: ''),
      (Contest: RTC;               Station: psUS;  Text: ptDigits;   Hint: ''),
      (Contest: CUPRFCW;           Station: psUS;  Text: ptGrid4;    Hint: 'FN'),
      (Contest: CUPRFCW;           Station: psUS;  Text: ptGrid6;    Hint: ''),
      (Contest: CUPRFCW;           Station: psUS;  Text: ptRDA;      Hint: 'MO'),
      (Contest: CUPRFCW;           Station: psUS;  Text: ptZZ;       Hint: ''),
      (Contest: CUPRFSSB;          Station: psUS;  Text: ptGrid4;    Hint: 'FN'),
      (Contest: CUPRFSSB;          Station: psUS;  Text: ptGrid6;    Hint: ''),
      (Contest: CUPRFSSB;          Station: psUS;  Text: ptRDA;      Hint: 'MO'),
      (Contest: CUPRFSSB;          Station: psUS;  Text: ptZZ;       Hint: ''),
      (Contest: TOEC;              Station: psUS;  Text: ptGrid4;    Hint: 'FN'),
      (Contest: TOEC;              Station: psUS;  Text: ptGrid6;    Hint: ''),
      (Contest: TOEC;              Station: psUS;  Text: ptRDA;      Hint: 'MO'),
      (Contest: TOEC;              Station: psUS;  Text: ptZZ;       Hint: ''),
      (Contest: WWDIGI;            Station: psUS;  Text: ptGrid4;    Hint: 'FN'),
      (Contest: WWDIGI;            Station: psUS;  Text: ptGrid6;    Hint: ''),
      (Contest: WWDIGI;            Station: psUS;  Text: ptRDA;      Hint: 'MO'),
      (Contest: WWDIGI;            Station: psUS;  Text: ptZZ;       Hint: ''),
      (Contest: WWL;               Station: psUS;  Text: ptGrid4;    Hint: 'FN'),
      (Contest: WWL;               Station: psUS;  Text: ptGrid6;    Hint: ''),
      (Contest: WWL;               Station: psUS;  Text: ptRDA;      Hint: 'MO'),
      (Contest: WWL;               Station: psUS;  Text: ptZZ;       Hint: ''),
      (Contest: CALQSOPARTY;       Station: psUS;  Text: ptState;    Hint: 'KS'),
      (Contest: CALQSOPARTY;       Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: CALQSOPARTY;       Station: psUS;  Text: ptIOTA4;    Hint: 'EU12'),
      (Contest: ARRLDXCW;          Station: psDX;  Text: ptState;    Hint: 'KS'),
      (Contest: ARRLDXCW;          Station: psDX;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: ARRLDXCW;          Station: psDX;  Text: ptIOTA4;    Hint: 'EU12'),
      (Contest: JIDXCW;            Station: psUS;  Text: ptState;    Hint: 'KS'),
      (Contest: JIDXCW;            Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: JIDXCW;            Station: psUS;  Text: ptIOTA4;    Hint: 'EU12'),
      (Contest: OKDX;              Station: psUS;  Text: ptState;    Hint: 'KS'),
      (Contest: OKDX;              Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: OKDX;              Station: psUS;  Text: ptIOTA4;    Hint: 'EU12'),
      (Contest: UBACW;             Station: psUS;  Text: ptState;    Hint: 'KS'),
      (Contest: UBACW;             Station: psUS;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: UBACW;             Station: psUS;  Text: ptIOTA4;    Hint: 'EU12'),
      (Contest: NAQSOCW;           Station: psVE;  Text: ptState;    Hint: 'KS'),
      (Contest: NAQSOCW;           Station: psVE;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: NAQSOCW;           Station: psVE;  Text: ptIOTA4;    Hint: 'EU12'),
      (Contest: RSGB18;            Station: psDX;  Text: ptState;    Hint: 'KS'),
      (Contest: RSGB18;            Station: psDX;  Text: ptRDA;      Hint: 'MO12'),
      (Contest: RSGB18;            Station: psDX;  Text: ptIOTA4;    Hint: 'EU12')
   );

function PinStation(aStation: TPinStation; aContest: ContestType): TStationContext;
begin
   Result := MatrixStation(STATIONS[aStation].Call, STATIONS[aStation].Country,
                           STATIONS[aStation].Continent, STATIONS[aStation].State,
                           'DX', '', STATIONS[aStation].InHostState,
                           SessionContestName(aContest, STATIONS[aStation].InHostState));
end;

(* One line per answer, so '' and "not found" read apart on the page. *)
function KeyAnswer(aFileFollows: boolean; aFound: boolean;
                   const aMultiplier: Str10; const aQTH: Str10): string;
begin
   if aFileFollows then
      begin
      Result := 'file ';
      end
   else
      begin
      Result := 'decided ';
      end;
   if aFound then
      begin
      Result := Result + 'T';
      end
   else
      begin
      Result := Result + 'F';
      end;
   Result := Result + ' [' + string(aMultiplier) + '] [' + string(aQTH) + ']';
end;

(* WHAT THE PROGRAM GIVES -- what LOGDOM.GetDomQTH, LOGSTUFF.DomStringParse
   and the flag sites ask. BEFORE THE MOVE each returned the frozen legacy
   rule above, selected by Kinds(aContest, aStation).DomesticMult -- the run
   that made the literals. *)
function ProgramKey(aContest: ContestType;
                    const aStation: TStationContext;
                    const aText: Str20): string;
var
   obj: TContestBase;
   multiplier: Str10;
   qth: Str10;
   found: boolean;
   follows: boolean;
begin
   multiplier := '';
   qth := '';
   found := False;
   obj := MakeContestOrNil(aContest, aStation);
   try
      follows := ContestDomesticMultiplierFromQTH(obj, aText, multiplier, qth, found) =
                 dqaLookUpDomesticFile;
   finally
      obj.Free;
      end;
   Result := KeyAnswer(follows, found, multiplier, qth);
end;

function ProgramHint(aContest: ContestType;
                     const aStation: TStationContext;
                     const aText: Str14): string;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      Result := ContestDomesticMultiplierHint(obj, aText);
   finally
      obj.Free;
      end;
end;

function ProgramFlag(aContest: ContestType;
                     const aStation: TStationContext;
                     aFlag: TPinFlag): boolean;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      case aFlag of
         pfGridSquare:
            begin
            Result := ContestHasGridSquareMultiplier(obj);
            end;
         pfGridField:
            begin
            Result := ContestHasGridFieldMultiplier(obj);
            end;
         pfReplacesDX:
            begin
            Result := ContestDomesticQTHReplacesDXMultiplier(obj);
            end;
      else
         begin
         Result := ContestDomesticQTHIsNeverAGrid(obj);
         end;
      end;
   finally
      obj.Free;
      end;
end;

function Who(aContest: ContestType; aStation: TPinStation): string;
begin
   Result := string(ContestTypeSA[aContest]) + ' at ' + STATIONS[aStation].Call;
end;

(* THE PINNED SET OF CONTESTS ANSWERING aFlag AT aStation -- the literal
   sets above, with the station branches the four contests that have one
   take: the ALRS cup counts RDA districts at a Russian station outside St
   Petersburg (psUA), and is WYSIWYG elsewhere; the DARC 10 m is WYSIWYG at
   a German station and counts DOKs elsewhere. *)
function PinnedFlag(aContest: ContestType; aStation: TPinStation; aFlag: TPinFlag): boolean;
begin
   case aFlag of
      pfGridSquare:
         begin
         Result := aContest in GRID_SQUARE_CONTESTS;
         end;
      pfGridField:
         begin
         Result := aContest in GRID_FIELD_CONTESTS;
         end;
      pfReplacesDX:
         begin
         Result := (aContest in WYSIWYG_EVERYWHERE)                        or
                   ((aContest = ALRS_UA1DZ_CUP) and (aStation <> psUA))     or
                   ((aContest = DARC10M) and (aStation = psDX));
         end;
   else
      begin
      Result := (aContest = RDA) or
                ((aContest = ALRS_UA1DZ_CUP) and (aStation = psUA));
      end;
   end;
end;

(* WHAT THE PROGRAM GIVES FOR "IS THE DOMESTIC QTH LOOKED UP IN THE FILE" --
   what LOGSUBS2.LogContact's mobile rewrite and the readiness check ask
   (TContestBase.UsesDomesticFile, M11 S6 part 1b), on a contest object
   holding the station. BEFORE THE MOVE it returned the frozen old test,
   `kind = DomesticFile`, under the kind Kinds(aContest, aStation)
   resolves -- the run that made the literals. *)
function ProgramUsesFile(aContest: ContestType; const aStation: TStationContext): boolean;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      Result := ContestUsesDomesticFile(obj);
   finally
      obj.Free;
      end;
end;

(* THE PINNED ANSWER: the set above, and the nine whose entrant decides --
   each the test its DescribeSession states DomesticFile under. *)
function PinnedUsesFile(aContest: ContestType; aStation: TPinStation): boolean;
begin
   case aContest of
      ARRLDXCW, ARRLDXSSB:
         begin
         (* Not a W or VE entrant: a state or province out of S48P14DC. *)
         Result := not (aStation in [psUS, psVE, psHost]);
         end;
      JIDXCW, JIDXSSB:
         begin
         Result := aStation <> psJA;
         end;
      OKDX:
         begin
         (* Not an OK or OM entrant. *)
         Result := aStation <> psOK;
         end;
      UBACW, UBASSB:
         begin
         Result := aStation <> psON;
         end;
      UKRAINIAN:
         begin
         Result := aStation <> psUR;
         end;
      YUDX:
         begin
         Result := aStation <> psYU;
         end;
   else
      begin
      Result := aContest in DOMESTIC_FILE_EVERYWHERE;
      end;
   end;
end;

procedure TDomesticMultiplierTests.Test_EveryContestStatesItsPinnedDomesticFileAnswer;
var
   c: ContestType;
   s: TPinStation;
begin
   BeginTest('Test_EveryContestStatesItsPinnedDomesticFileAnswer');
   (* THE LEGACY CONTESTS, FROZEN: PinnedUsesFile, contest by contest, at
      every roster station. The per-station counts (93 to 95) and the count
      at some station (95) that stood beside it are deleted (Q108 S1): each
      restated the set, and moved by hand with every domestic-file contest
      added. A contest that gains or loses its file fails here by name. *)
   for s := Low(TPinStation) to High(TPinStation) do
      begin
      for c := Low(ContestType) to High(ContestType) do
         begin
         CheckEquals(BoolToStr(PinnedUsesFile(c, s), True),
                     BoolToStr(ProgramUsesFile(c, PinStation(s, c)), True),
                     Who(c, s) + ' uses its domestic file');
         end;
      end;
end;

(* A CONTEST THAT LOOKS ITS QTH UP IN THE FILE STATES NO SHAPE -- the two
   answers are one rule seen twice: DomesticMultiplierFromQTH hands every
   text to the file (the base's answer, writing nothing), and none of the
   four shape flags is set. *)
procedure TDomesticMultiplierTests.Test_ADomesticFileContestStatesNoShape;
var
   q108Contests: TContestIdentityList;
   k: integer;
   c: ContestType;
   s: TPinStation;
   t: TPinText;
   f: TPinFlag;
   station: TStationContext;
   checked: integer;
begin
   BeginTest('Test_ADomesticFileContestStatesNoShape');
   checked := 0;
   (* EVERY REGISTERED CONTEST, BY THE REGISTRY -- an invariant, so a
      contest registered by its id is held to it too (Q108 S1). *)
   q108Contests := ContestsToWalk;
   for k := 0 to High(q108Contests) do
      begin
      c := ContestOf(q108Contests[k]);
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         if not ProgramUsesFile(c, station) then
            begin
            Continue;
            end;
         for t := Low(TPinText) to High(TPinText) do
            begin
            CheckEquals('file F [] []', ProgramKey(c, station, Str20(TEXTS[t])),
                        Who(c, s) + ' receiving ' + TEXTS[t]);
            end;
         for f := Low(TPinFlag) to High(TPinFlag) do
            begin
            CheckFalse(ProgramFlag(c, station, f), Who(c, s) + ' ' + FLAG_NAMES[f]);
            end;
         Inc(checked);
         end;
      end;
   CheckTrue(checked > 0, 'domestic-file contests checked');
end;

(* DOES THE CONTEST HAVE A DOMESTIC MULTIPLIER? -- the pinned answer, M11 S6
   part 2: the domestic-file contests (PinnedUsesFile) and the 25 that state
   a shape, WAG for an entrant outside Germany only. *)
function PinnedHasDomestic(aContest: ContestType; aStation: TPinStation): boolean;
begin
   Result := PinnedUsesFile(aContest, aStation)                       or
             (aContest in GRID_SQUARE_CONTESTS)                        or
             (aContest in GRID_FIELD_CONTESTS)                         or
             (aContest in WYSIWYG_EVERYWHERE)                          or
             (aContest in [ALRS_UA1DZ_CUP, DARC10M, IOTA, RDA])        or
             ((aContest = WAG) and (aStation <> psDX));
end;

function ProgramHasDomestic(aContest: ContestType; const aStation: TStationContext): boolean;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      Result := ContestHasDomesticMultiplier(obj);
   finally
      obj.Free;
      end;
end;

(* EVERY CONTEST'S DOMESTIC MULTIPLIER, AT EVERY STATION -- M11 S6 part 2.
   It replaces the session's `kind <> NoDomesticMults`. The counts at us, ve
   and dx are the frozen matrix's (117, 117, 118 variants whose
   doing.domestic word is TRUE); a script predicted all 580 frozen variants
   from the classes' source with 0 mismatches before the kind went. The
   per-station counts that stood here went at Q108 S1 (2026-10-16). *)
procedure TDomesticMultiplierTests.Test_EveryContestHasItsPinnedDomesticMultiplier;
var
   c: ContestType;
   s: TPinStation;
begin
   BeginTest('Test_EveryContestHasItsPinnedDomesticMultiplier');
   (* THE LEGACY CONTESTS, FROZEN: PinnedHasDomestic at every roster station.
      The per-station counts (118 to 120) are deleted (Q108 S1): they
      restated PinnedHasDomestic, which fails here by name. *)
   for s := Low(TPinStation) to High(TPinStation) do
      begin
      for c := Low(ContestType) to High(ContestType) do
         begin
         CheckEquals(BoolToStr(PinnedHasDomestic(c, s), True),
                     BoolToStr(ProgramHasDomestic(c, PinStation(s, c)), True),
                     Who(c, s) + ' has a domestic multiplier');
         end;
      end;
end;

(* A DOMESTIC MULTIPLIER IS WHERE A DOMESTIC QTH IS READ -- the invariant
   that ties HasDomesticMultiplier to the rules it gates, for every
   ContestType at every station: True exactly where the contest uses its
   domestic file or decides at least one text itself (its key differs from
   the base's "hand it to the file, writing nothing" for some text). So the
   base's composition and the three overrides (the RSGB IOTA, WAG, the DARC
   10 m) cannot drift from the shape answers. *)
procedure TDomesticMultiplierTests.Test_ADomesticMultiplierIsWhereAQTHIsRead;
var
   contests: TContestIdentityList;
   k: integer;
   c: ContestType;
   s: TPinStation;
   t: TPinText;
   station: TStationContext;
   reads: boolean;
   checked: integer;
begin
   BeginTest('Test_ADomesticMultiplierIsWhereAQTHIsRead');
   checked := 0;
   (* EVERY REGISTERED CONTEST, BY THE REGISTRY -- an invariant, so a
      contest registered by its id is held to it too (Q108 S1). *)
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      c := ContestOf(contests[k]);
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         reads := ProgramUsesFile(c, station);
         for t := Low(TPinText) to High(TPinText) do
            begin
            if ProgramKey(c, station, Str20(TEXTS[t])) <> 'file F [] []' then
               begin
               reads := True;
               end;
            end;
         CheckEquals(BoolToStr(reads, True), BoolToStr(ProgramHasDomestic(c, station), True),
                     Who(c, s) + ' reads a domestic QTH');
         Inc(checked);
         end;
      end;
   CheckEquals(Length(contests) * (Ord(High(TPinStation)) + 1), checked,
               'registered contest x station domestic answers compared');
end;

procedure TDomesticMultiplierTests.RunAllTests;
begin
   Test_EveryContestGivesItsPinnedDomesticKey;
   Test_EveryContestGivesItsPinnedHint;
   Test_EveryContestStatesItsPinnedDomesticAnswers;
   Test_ADOKTextWithNoLetterHintsNothing;
   Test_EveryContestStatesItsPinnedDomesticFileAnswer;
   Test_ADomesticFileContestStatesNoShape;
   Test_EveryContestHasItsPinnedDomesticMultiplier;
   Test_ADomesticMultiplierIsWhereAQTHIsRead;
end;

procedure TDomesticMultiplierTests.Test_EveryContestGivesItsPinnedDomesticKey;
var
   i: integer;
   pin: TKeyPin;
   decided: set of ContestType;
   c: ContestType;
begin
   BeginTest('Test_EveryContestGivesItsPinnedDomesticKey');
   decided := [];
   for i := Low(KEY_PINS) to High(KEY_PINS) do
      begin
      pin := KEY_PINS[i];
      CheckEquals(pin.Answer,
                  ProgramKey(pin.Contest, PinStation(pin.Station, pin.Contest),
                             Str20(TEXTS[pin.Text])),
                  Who(pin.Contest, pin.Station) + ' receiving ' + TEXTS[pin.Text]);
      if Copy(pin.Answer, 1, 7) = 'decided' then
         begin
         Include(decided, pin.Contest);
         end;
      end;

   (* EVERY CONTEST WHOSE DOMESTIC QTH IS NOT A FILE LOOKUP HAS A ROW THAT
      DECIDES, AND NO OTHER -- contest by contest, against the shape sets
      PinnedHasDomestic reads. What the hand-kept count of them (25, plan S6)
      stood for until Q108 S1 deleted it. *)
   for c := Low(ContestType) to High(ContestType) do
      begin
      CheckTrue((c in decided) = (c in SHAPE_SOMEWHERE),
                string(ContestTypeSA[c]) + ': a deciding key row exactly where it states a shape');
      end;
end;

procedure TDomesticMultiplierTests.Test_EveryContestGivesItsPinnedHint;
var
   i: integer;
   pin: THintPin;
begin
   BeginTest('Test_EveryContestGivesItsPinnedHint');
   for i := Low(HINT_PINS) to High(HINT_PINS) do
      begin
      pin := HINT_PINS[i];
      CheckEquals(pin.Hint,
                  ProgramHint(pin.Contest, PinStation(pin.Station, pin.Contest),
                              Str14(TEXTS[pin.Text])),
                  Who(pin.Contest, pin.Station) + ' hinting ' + TEXTS[pin.Text]);
      end;
end;

procedure TDomesticMultiplierTests.Test_EveryContestStatesItsPinnedDomesticAnswers;
var
   c: ContestType;
   s: TPinStation;
   f: TPinFlag;
begin
   BeginTest('Test_EveryContestStatesItsPinnedDomesticAnswers');
   (* THE LEGACY CONTESTS, FROZEN: PinnedFlag for every flag at every roster
      station. The table of how many contests answered each flag at each
      station is deleted (Q108 S1): it was counted from the sets PinnedFlag
      reads, so it restated them, and a contest that gains a flag fails
      here by name. *)
   for s := Low(TPinStation) to High(TPinStation) do
      begin
      for f := Low(TPinFlag) to High(TPinFlag) do
         begin
         for c := Low(ContestType) to High(ContestType) do
            begin
            CheckEquals(BoolToStr(PinnedFlag(c, s, f), True),
                        BoolToStr(ProgramFlag(c, PinStation(s, c), f), True),
                        Who(c, s) + ' ' + FLAG_NAMES[f]);
            end;
         end;
      end;
end;

(* NO LETTER, NO HINT -- plan F6, fixed 2026-10-14. WAG and DARC 10 m
   returned an unassigned local here (whatever the stack held); both now
   answer ''. Asked at stations outside DL, where the DOK rule applies. *)
procedure TDomesticMultiplierTests.Test_ADOKTextWithNoLetterHintsNothing;
const
   DOK_CONTESTS: array[0..1] of ContestType = (WAG, DARC10M);
   NON_DL_STATIONS: array[0..1] of TPinStation = (psUS, psJA);
var
   i, j: integer;
begin
   BeginTest('Test_ADOKTextWithNoLetterHintsNothing');
   for i := Low(DOK_CONTESTS) to High(DOK_CONTESTS) do
      begin
      for j := Low(NON_DL_STATIONS) to High(NON_DL_STATIONS) do
         begin
         CheckEquals('',
                     ProgramHint(DOK_CONTESTS[i],
                                 PinStation(NON_DL_STATIONS[j], DOK_CONTESTS[i]),
                                 Str14(TEXTS[ptDigits])),
                     Who(DOK_CONTESTS[i], NON_DL_STATIONS[j]) + ' hinting ' + TEXTS[ptDigits]);
         end;
      end;
end;

end.
