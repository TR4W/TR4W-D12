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
  moved: the program's own arms, frozen below (Legacy...OfKind), selected by
  the session kind uTestContestKindPin.Kinds resolves -- the trait, and
  DescribeSession over it -- exactly what the engine selected. Then the move, and
  the same tables green against the classes.

  AND A CROSS-CHECK FOR EVERY CONTEST, NOT ONLY THE 25. The *AgreesWith*
  tests ask every ContestType at every roster station, and compare the
  class's answer with the frozen legacy rule under the kind the session
  resolves to. It holds only while the session still carries DomesticMult;
  S6 part 2 deletes that kind, and these cross-checks and the frozen rules
  go with it, leaving the literals.

  AN ANSWER IS FOUR THINGS, written on one line so a failure reads whole:
  whether the domestic FILE is consulted next ('file') or the contest has
  decided ('decided'), whether the QTH was found, the multiplier and the
  QTH. 'file' with a key is real: the RSGB IOTA's valid reference falls
  through to the file lookup with the key already set (plan F6) -- a
  quirk kept exactly.

  THE DOK HINT FOR A TEXT WITH NO LETTER is pinned on its own, by
  Test_ADOKTextWithNoLetterHintsNothing: DomStringParse returned a local it
  never assigned (plan F6), so the old value was undefined and the
  cross-check below still skips it; since the F6 fix (2026-10-14) both DOK
  classes answer an empty hint.

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
      procedure Test_EveryContestDomesticKeyAgreesWithItsSessionKind;
      procedure Test_EveryContestGivesItsPinnedHint;
      procedure Test_EveryContestHintAgreesWithItsSessionKind;
      procedure Test_EveryContestStatesItsPinnedDomesticAnswers;
      procedure Test_EveryContestDomesticAnswerAgreesWithItsSessionKind;
      procedure Test_ADOKTextWithNoLetterHintsNothing;
      procedure Test_EveryContestStatesItsPinnedDomesticFileAnswer;
      procedure Test_EveryContestDomesticFileAnswerAgreesWithItsSessionKind;
      procedure Test_ADomesticFileContestStatesNoShape;
   end;

implementation

uses
   SysUtils,
   VC,
   utils_text,
   uContestBase,
   uContestRegistry,
   uTestContestKindPin;

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

   (* THE CONTESTS WHOSE DOMESTIC QTH IS LOOKED UP IN THEIR DOMESTIC FILE AT
      EVERY STATION -- M11 S6 part 1b. 85 of the 94 that do at some station;
      the other nine depend on the entrant (FILE_STATION_PINS). Written from
      each class's trait and DescribeSession and run green against the
      session kind before the answer moved. *)
   DOMESTIC_FILE_EVERYWHERE = [
      ALLJA, ARCI, ARI_DX, ARRL10, ARRL160, ARRLFIELDDAY, ARRLSSCW,
      ARRLSSSSB, ARRL_RTTY_ROUNDUP, ArizonaQsoParty, BCQP, CALQSOPARTY,
      CANADA_DAY, CANADA_WINTER, CIS, COLORADOQSOPARTY, CQ160CW, CQ160SSB,
      CQIR, CQWWRTTY, CROATIAN, CUPRFDIG, CUPURAL, DELAWAREQSOPARTY, EUDX,
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

(* THE OLD KIND ARMS, FROZEN -- LOGDOM.GetDomQTH as it stood at 45ca8855,
   verbatim from below its no-domestic exit to the domestic-file lookup,
   which is the engine's and stays there. An arm that Exits answers
   "decided" (False); one that falls through answers "the file follows"
   (True) -- the IOTA arm alone, when its reference is valid or its
   continent unknown. The caller zeroes the outputs, as GetDomQTH did. It
   goes when S6 part 2 deletes DomesticMultType. *)
function LegacyDomesticKeyOfKind(aKind: DomesticMultType;
                                 InputString: Str20;
                                 var Multiplier: Str10;
                                 var QTH: Str10;
                                 var aFound: boolean): boolean;
var
   Index: integer;
   ContinentString, NumberString: Str20;
begin
   Result := False;

   if aKind = RDADistrict then
      begin
      if (length(InputString) = 4)        and
         (InputString[1] in ['A'..'Z']) and
         (InputString[2] in ['A'..'Z']) and
         (InputString[3] in ['0'..'9']) and
         (InputString[4] in ['0'..'9'])  then
         begin
         Multiplier := InputString;
         QTH := InputString;
         aFound := True;
         end;
      Exit;
      end;

   if aKind = WYSIWYGDomestic then
      begin
      Multiplier := InputString;
      QTH := InputString;
      aFound := True;
      Exit;
      end;

   if aKind = DOKCodes then
      begin
      for Index := 1 to length(InputString) do
         begin
         if InputString[Index] in ['A'..'Z'] then
            begin
            Multiplier := Copy(InputString, Index, 1);
            Break;
            end;
         end;

      QTH := InputString;
      aFound := Multiplier <> '';
      Exit;
      end;

   if aKind = IOTADomestic then
      begin
      if (length(InputString) < 3) or (length(InputString) > 5) then
         begin
         Exit;
         end;

      ContinentString := ShortString(UpperCase(Copy(InputString, 1, 2)));
      if GetContinentFromString(ContinentString) <> UnknownContinent then
         begin
         NumberString := Copy(InputString, 3, length(InputString) - 2);

         if not StringIsAllNumbers(NumberString) then
            begin
            Exit;
            end;

         while length(NumberString) < 3 do
            begin
            NumberString := '0' + NumberString;
            end;

         Multiplier := ContinentString + '-' + NumberString;
         QTH := Multiplier;
         aFound := True;
         end;
      end;

   if aKind = GridSquares then
      begin
      if (length(InputString) <> 4) and (length(InputString) <> 6) then
         begin
         Exit;
         end;

      if (InputString[1] < 'A') or (InputString[1] > 'R') or
        (InputString[2] < 'A') or (InputString[2] > 'R') or
        (InputString[3] > '9') or (InputString[3] < '0') or
        (InputString[4] > '9') or (InputString[4] < '0') then
         begin
         Exit;
         end;

      if length(InputString) = 6 then
         begin
         if (InputString[5] < 'A') or (InputString[5] > 'Z') or
            (InputString[6] < 'A') or (InputString[6] > 'Z') then
            begin
            Exit;
            end;
         end;

      Multiplier := Copy(InputString, 1, 4);
      QTH := InputString;
      aFound := True;
      Exit;
      end;

   if aKind = GridFields then
      begin
      if (length(InputString) <> 4) or (InputString[1] < 'A') or (InputString[1] > 'R') or
        (InputString[2] < 'A') or (InputString[2] > 'R') or
        (InputString[3] > '9') or (InputString[3] < '0') or
        (InputString[4] > '9') or (InputString[4] < '0') then
         begin
         Exit;
         end;

      Multiplier := Copy(InputString, 1, 2);
      QTH := InputString;
      aFound := True;
      Exit;
      end;

   Result := True;
end;

const
   (* What the old DOK arm returned for a text with no letter: an
      unassigned local -- no value. *)
   UNDEFINED_HINT = '<undefined>';

(* THE OLD HINT, FROZEN -- LOGSTUFF.DomStringParse as it stood at 45ca8855,
   verbatim but for two things the run cannot reproduce: the IOTA arm's
   scratch global (LOGWIND.ContinentString, which nothing read) is a local,
   and the DOK arm's unassigned local answers UNDEFINED_HINT. The caller
   upper-cases the text, as DomStringParse did first. *)
function LegacyHintOfKind(aKind: DomesticMultType; InputString: Str14): string;
var
   Index: integer;
   TempMultiplier, NumberString: Str14;
   ContinentString: Str20;
begin
   result := InputString;

   if aKind = RDADistrict then
      begin
      result := '';
      if (length(InputString) = 4)        and
         (InputString[1] in ['A'..'Z']) and
         (InputString[2] in ['A'..'Z']) and
         (InputString[3] in ['0'..'9']) and
         (InputString[4] in ['0'..'9'])  then
         begin
         result := InputString;
         end;
      Exit;
      end;

   if aKind = DOKCodes then
      begin
      result := UNDEFINED_HINT;
      for Index := 1 to length(InputString) do
         begin
         if InputString[Index] in ['A'..'Z'] then
            begin
            TempMultiplier := Copy(InputString, Index, 1);
            result := TempMultiplier;
            Break;
            end;
         end;
      Exit;
      end;

   if aKind = IOTADomestic then
      begin
      result := '';
      if (length(InputString) < 3) or (length(InputString) > 5) then
         begin
         Exit;
         end;

      ContinentString := ShortString(UpperCase(Copy(InputString, 1, 2)));
      if GetContinentFromString(ContinentString) <> UnknownContinent then
         begin
         NumberString := Copy(InputString, 3, length(InputString) - 2);

         if not StringIsAllNumbers(NumberString) then
            begin
            Exit;
            end;

         while length(NumberString) < 3 do
            begin
            NumberString := '0' + NumberString;
            end;

         TempMultiplier := ContinentString + '-' + NumberString;
         result := TempMultiplier;
         end;
      end;

   if aKind = GridSquares then
      begin
      result := '';
      if (length(InputString) <> 4) and (length(InputString) <> 6) then
         begin
         Exit;
         end;

      if (InputString[1] < 'A') or (InputString[1] > 'R') or
        (InputString[2] < 'A') or (InputString[2] > 'R') or
        (InputString[3] > '9') or (InputString[3] < '0') or
        (InputString[4] > '9') or (InputString[4] < '0') then
         begin
         Exit;
         end;

      if length(InputString) = 6 then
         begin
         if (InputString[5] < 'A') or (InputString[5] > 'Z') or
            (InputString[6] < 'A') or (InputString[6] > 'Z') then
            begin
            Exit;
            end;
         end;

      TempMultiplier := Copy(InputString, 1, 4);
      result := TempMultiplier;
      Exit;
      end;

   if aKind = GridFields then
      begin
      result := '';
      if (length(InputString) <> 4) or (InputString[1] < 'A') or (InputString[1] > 'R') or
        (InputString[2] < 'A') or (InputString[2] > 'R') or
        (InputString[3] > '9') or (InputString[3] < '0') or
        (InputString[4] > '9') or (InputString[4] < '0') then
         begin
         Exit;
         end;

      TempMultiplier := Copy(InputString, 1, 2);
      result := TempMultiplier;
      Exit;
      end;
end;

(* THE OLD YES/NO TESTS, FROZEN -- each site's session-kind comparison as
   it stood at 45ca8855: `= GridSquares` (LOGEDIT.CallIsADupe, LOGSUBS2's
   partial-call mults and LogContact, LOGSTUFF.DisplayGridSquareStatus),
   `= GridFields` (uMults.IsDmMult, uWSJTX, the sheet's service),
   `= WYSIWYGDomestic` (LOGDUPE.GetDXQTH) and `<> RDADistrict` inverted
   (POSTUNIT's GRIDSQUARE). *)
function LegacyFlagOfKind(aKind: DomesticMultType; aFlag: TPinFlag): boolean;
begin
   case aFlag of
      pfGridSquare:
         begin
         Result := aKind = GridSquares;
         end;
      pfGridField:
         begin
         Result := aKind = GridFields;
         end;
      pfReplacesDX:
         begin
         Result := aKind = WYSIWYGDomestic;
         end;
   else
      begin
      Result := aKind = RDADistrict;
      end;
   end;
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
   obj := MakeContest(aContest, aStation);
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
   obj := MakeContest(aContest, aStation);
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
   obj := MakeContest(aContest, aStation);
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

function LegacyKey(aKind: DomesticMultType; const aText: Str20): string;
var
   multiplier: Str10;
   qth: Str10;
   found: boolean;
   follows: boolean;
begin
   multiplier := '';
   qth := '';
   found := False;
   follows := LegacyDomesticKeyOfKind(aKind, aText, multiplier, qth, found);
   Result := KeyAnswer(follows, found, multiplier, qth);
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
   obj := MakeContest(aContest, aStation);
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
const
   (* HOW MANY CONTESTS LOOK THEIR DOMESTIC QTH UP IN A FILE AT EACH STATION,
      counted by hand: the 85, plus each station-dependent one whose
      entrant test passes there. The matrix agrees at us, ve and dx (92, 92,
      94 DomesticFile records). *)
   COUNTS: array[TPinStation] of integer = (
      92,    (* us -- not ARRL DX *)
      92,    (* ve *)
      94,    (* dx (DL) -- all nine *)
      92,    (* host (K) *)
      94,    (* UA *)
      94,    (* UA1 *)
      92,    (* JA -- not JIDX *)
      93,    (* OK -- not OK DX *)
      92,    (* ON -- not the two UBA *)
      93,    (* UR -- not the Ukrainian DX *)
      93     (* YU -- not YU DX *)
   );
var
   c: ContestType;
   s: TPinStation;
   answer: boolean;
   count: integer;
   anywhere: set of ContestType;
   total: integer;
begin
   BeginTest('Test_EveryContestStatesItsPinnedDomesticFileAnswer');
   anywhere := [];
   for s := Low(TPinStation) to High(TPinStation) do
      begin
      count := 0;
      for c := Low(ContestType) to High(ContestType) do
         begin
         answer := ProgramUsesFile(c, PinStation(s, c));
         CheckEquals(BoolToStr(PinnedUsesFile(c, s), True), BoolToStr(answer, True),
                     Who(c, s) + ' uses its domestic file');
         if answer then
            begin
            Inc(count);
            Include(anywhere, c);
            end;
         end;
      CheckEquals(COUNTS[s], count, 'contests using a domestic file at ' + STATIONS[s].Call);
      end;

   (* 94 AT SOME STATION -- plan 2.6. *)
   total := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if c in anywhere then
         begin
         Inc(total);
         end;
      end;
   CheckEquals(94, total, 'contests using a domestic file at some roster station');
end;

procedure TDomesticMultiplierTests.Test_EveryContestDomesticFileAnswerAgreesWithItsSessionKind;
var
   c: ContestType;
   s: TPinStation;
   station: TStationContext;
   checked: integer;
begin
   BeginTest('Test_EveryContestDomesticFileAnswerAgreesWithItsSessionKind');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         CheckEquals(BoolToStr(Kinds(c, station).DomesticMult = DomesticFile, True),
                     BoolToStr(ProgramUsesFile(c, station), True),
                     Who(c, s) + ' uses its domestic file');
         Inc(checked);
         end;
      end;
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1), checked,
               'contest x station domestic-file answers compared');
end;

(* A CONTEST THAT LOOKS ITS QTH UP IN THE FILE STATES NO SHAPE -- the two
   answers are one rule seen twice: DomesticMultiplierFromQTH hands every
   text to the file (the base's answer, writing nothing), and none of the
   four shape flags is set. *)
procedure TDomesticMultiplierTests.Test_ADomesticFileContestStatesNoShape;
var
   c: ContestType;
   s: TPinStation;
   t: TPinText;
   f: TPinFlag;
   station: TStationContext;
   checked: integer;
begin
   BeginTest('Test_ADomesticFileContestStatesNoShape');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
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

procedure TDomesticMultiplierTests.RunAllTests;
begin
   Test_EveryContestGivesItsPinnedDomesticKey;
   Test_EveryContestDomesticKeyAgreesWithItsSessionKind;
   Test_EveryContestGivesItsPinnedHint;
   Test_EveryContestHintAgreesWithItsSessionKind;
   Test_EveryContestStatesItsPinnedDomesticAnswers;
   Test_EveryContestDomesticAnswerAgreesWithItsSessionKind;
   Test_ADOKTextWithNoLetterHintsNothing;
   Test_EveryContestStatesItsPinnedDomesticFileAnswer;
   Test_EveryContestDomesticFileAnswerAgreesWithItsSessionKind;
   Test_ADomesticFileContestStatesNoShape;
end;

procedure TDomesticMultiplierTests.Test_EveryContestGivesItsPinnedDomesticKey;
var
   i: integer;
   pin: TKeyPin;
   decided: set of ContestType;
   count: integer;
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
      DECIDES -- 25, plan S6. *)
   count := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if c in decided then
         begin
         Inc(count);
         end;
      end;
   CheckEquals(25, count, 'contests with a pinned domestic answer of their own');
end;

procedure TDomesticMultiplierTests.Test_EveryContestDomesticKeyAgreesWithItsSessionKind;
var
   c: ContestType;
   s: TPinStation;
   t: TPinText;
   station: TStationContext;
   kind: DomesticMultType;
   answer: string;
   checked: integer;
   decided: set of ContestType;
   count: integer;
begin
   BeginTest('Test_EveryContestDomesticKeyAgreesWithItsSessionKind');
   checked := 0;
   decided := [];
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         kind := Kinds(c, station).DomesticMult;
         (* GetDomQTH answers before any kind arm when the session counts no
            domestic multiplier, so nothing is asked there. *)
         if kind = NoDomesticMults then
            begin
            Continue;
            end;
         for t := Low(TPinText) to High(TPinText) do
            begin
            answer := ProgramKey(c, station, Str20(TEXTS[t]));
            CheckEquals(LegacyKey(kind, Str20(TEXTS[t])), answer,
                        Who(c, s) + ' receiving ' + TEXTS[t]);
            if Copy(answer, 1, 7) = 'decided' then
               begin
               Include(decided, c);
               end;
            Inc(checked);
            end;
         end;
      end;
   CheckTrue(checked > 0, 'domestic answers compared');

   (* THE 25, AND NO OTHER, DECIDE ANYWHERE ON THE ROSTER. *)
   count := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if c in decided then
         begin
         Inc(count);
         end;
      end;
   CheckEquals(25, count, 'contests that decide a domestic QTH at some roster station');
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

procedure TDomesticMultiplierTests.Test_EveryContestHintAgreesWithItsSessionKind;
var
   c: ContestType;
   s: TPinStation;
   t: TPinText;
   station: TStationContext;
   kind: DomesticMultType;
   legacy: string;
   hint: string;
   checked: integer;
   rewrites: set of ContestType;
   count: integer;
begin
   BeginTest('Test_EveryContestHintAgreesWithItsSessionKind');
   checked := 0;
   rewrites := [];
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         kind := Kinds(c, station).DomesticMult;
         for t := Low(TPinText) to High(TPinText) do
            begin
            legacy := LegacyHintOfKind(kind, Str14(TEXTS[t]));
            if legacy = UNDEFINED_HINT then
               begin
               Continue;
               end;
            hint := ProgramHint(c, station, Str14(TEXTS[t]));
            CheckEquals(legacy, hint, Who(c, s) + ' hinting ' + TEXTS[t]);
            if hint <> string(Str14(TEXTS[t])) then
               begin
               Include(rewrites, c);
               end;
            Inc(checked);
            end;
         end;
      end;
   CheckTrue(checked > 0, 'hints compared');

   (* SIXTEEN CONTESTS' HINTS ARE NOT THE TEXT ITSELF somewhere on the
      roster: RDA, the ALRS cup (at UA), WAG, the DARC 10 m, the RSGB IOTA,
      the six grid-square and the five grid-field contests. *)
   count := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if c in rewrites then
         begin
         Inc(count);
         end;
      end;
   CheckEquals(16, count, 'contests whose hint rewrites the text at some roster station');
end;

procedure TDomesticMultiplierTests.Test_EveryContestStatesItsPinnedDomesticAnswers;
const
   (* HOW MANY CONTESTS ANSWER EACH FLAG AT EACH STATION -- counted by hand
      from the sets above, so a contest that gains a flag fails here even
      if the sets were edited with it. *)
   COUNTS: array[TPinStation, TPinFlag] of integer = (
      (6, 5, 10, 1),     (* us   *)
      (6, 5, 10, 1),     (* ve   *)
      (6, 5, 11, 1),     (* dx -- the DARC 10 m is WYSIWYG for a German *)
      (6, 5, 10, 1),     (* host *)
      (6, 5,  9, 2),     (* UA -- the ALRS cup counts RDA districts *)
      (6, 5, 10, 1),     (* UA1 *)
      (6, 5, 10, 1),     (* JA *)
      (6, 5, 10, 1),     (* OK *)
      (6, 5, 10, 1),     (* ON *)
      (6, 5, 10, 1),     (* UR *)
      (6, 5, 10, 1)      (* YU *)
   );
var
   c: ContestType;
   s: TPinStation;
   f: TPinFlag;
   answer: boolean;
   count: integer;
begin
   BeginTest('Test_EveryContestStatesItsPinnedDomesticAnswers');
   for s := Low(TPinStation) to High(TPinStation) do
      begin
      for f := Low(TPinFlag) to High(TPinFlag) do
         begin
         count := 0;
         for c := Low(ContestType) to High(ContestType) do
            begin
            answer := ProgramFlag(c, PinStation(s, c), f);
            CheckEquals(BoolToStr(PinnedFlag(c, s, f), True), BoolToStr(answer, True),
                        Who(c, s) + ' ' + FLAG_NAMES[f]);
            if answer then
               begin
               Inc(count);
               end;
            end;
         CheckEquals(COUNTS[s, f], count,
                     'contests answering ' + FLAG_NAMES[f] + ' at ' + STATIONS[s].Call);
         end;
      end;
end;

procedure TDomesticMultiplierTests.Test_EveryContestDomesticAnswerAgreesWithItsSessionKind;
var
   c: ContestType;
   s: TPinStation;
   f: TPinFlag;
   station: TStationContext;
   kind: DomesticMultType;
   checked: integer;
begin
   BeginTest('Test_EveryContestDomesticAnswerAgreesWithItsSessionKind');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         kind := Kinds(c, station).DomesticMult;
         for f := Low(TPinFlag) to High(TPinFlag) do
            begin
            CheckEquals(BoolToStr(LegacyFlagOfKind(kind, f), True),
                        BoolToStr(ProgramFlag(c, station, f), True),
                        Who(c, s) + ' ' + FLAG_NAMES[f]);
            Inc(checked);
            end;
         end;
      end;

   (* EXACT: every contest, every roster station, every flag. *)
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1) *
               (Ord(High(TPinFlag)) + 1), checked, 'contest x station x flag answers compared');
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
