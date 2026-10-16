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

(* THE DX MULTIPLIER KEY, THE CTY COUNTRY MODE AND THE REMAINING-COUNTRIES
  FILTER EVERY CONTEST GIVES, AT STATIONS THE CONTEST MATRIX DOES NOT RUN --
  M11 S4, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S4).

  WHY IT EXISTS. S4 moves three readers of the session's DX KIND into the
  classes: LOGDUPE.GetDXQTH's `case ContestSession.DXMult of` (the key),
  uSettingsEffects' `DXMult in [the ARRL kinds]` (the CTY country mode) and
  uMults.FillVisibleBytes' three filters (which countries the remaining-mults
  window lists). The matrix pins the key and the mode at its own stations
  (us, ve, dx, and us-host for a party) and S0c's `== keys` QSOs execute most
  key arms there. It cannot see a branch only another entrant takes: PACC at
  a Dutch station, JIDX and the All Asian at a Japanese one, SAC in
  Scandinavia, Helvetia in Switzerland, the Croatian in Croatia, YU DX in
  Serbia, UBA in Belgium, RDA and the ALRS cup in Russia, IRTS in Ireland,
  NEQP in New England. So this unit freezes, as LITERALS, what each of the 78
  DX contests gives for a fixed set of QSOs at a fixed roster of stations,
  including those.

  79 SINCE 2026-10-16, CHANGED BY HAND: the SSB Sprint gained the North
  American DX multiplier its sponsor's rule 10 counts (Q16,
  docs/CONTEST_FACTORY_OPEN_QUESTIONS.md). It joins DX_EVERYWHERE, every
  HAS_DX_COUNT rises by one, and its KEY_PINS rows pin XE and KP4 counted, K,
  VE, KL7 and KH6 (states, by the sponsor's rule) and a European not.

  80 SINCE 2026-10-16, BY HAND: the Nebraska QSO Party, a new contest
  (design Q105), counts DXCC entities for a Nebraska entrant only -- the
  same rule as Delaware's. It joins HAS_DX at psHost (whose count rises by
  one), and its KEY_PINS and MODE_PINS rows are Delaware's shape.

  HOW THE LITERALS WERE MADE. Written by hand from the old code, then RUN
  GREEN AGAINST THE OLD CODE before anything moved: the program's own case
  and set and filters, frozen here (Legacy...OfKind, deleted at part 2),
  selected by the session kind uTestContestKindPin.Kinds resolved (the trait, then
  DescribeSession) -- exactly what the engine selected. Then the move, and
  the same tables green against the classes.

  AND A CROSS-CHECK FOR EVERY CONTEST, NOT ONLY THE 78 -- part 1's, GONE.
  Until M11 S4 part 2, three *AgreesWith* tests asked every ContestType at
  every roster station and compared the class's answer with the frozen
  legacy rule under the kind the session resolved to: no DX contest lost a
  branch, and no other contest gained a key. Part 2 deleted that kind, and
  the cross-checks and their frozen rules went with it (git history at
  6b874f1a holds both). The literals stay: they are the permanent oracle.

  WHETHER A CONTEST HAS A DX MULTIPLIER AT ALL -- part 2's question, which
  replaced the kind (TContestBase.HasDXMultiplier). Pinned by
  Test_EveryContestHasItsPinnedDXMultiplier, for every ContestType at every
  roster station, against HAS_DX below. Its us, ve and dx sets are the
  frozen kind pin's DX column read as "not NoDXMults" (uTestContestKindPin,
  made from the program at S0b), taken before that column was deleted; the
  other eleven stations' sets are each station-dependent contest's
  DescribeSession test as it stood at 6b874f1a, by hand. And THE INVARIANT
  the engine relies on: no contest gives a key where it says it has no DX
  multiplier -- checked for every contest, station and QSO.

  "NONE" IS NOT ''. Every arm of the old case assigned only on a match and
  otherwise LEFT THE QSO'S DX QTH AS IT WAS; PACC always assigned. The
  rescore runs GetDXQTH over a stored record (after clearing it), live entry
  over a fresh one, so the table says which: Assigns False means "no key",
  True with '' means "the key is empty" (ARI's test on an empty country).

  NEVER REGENERATE IT TO CLEAR A FAILURE -- the uTestContestKindPin rule. A
  failure means a contest's DX rule changed. *)
unit uTestDXMultiplierKey;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TDXMultiplierKeyTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EveryDXContestGivesItsPinnedKey;
      procedure Test_EveryContestHasItsPinnedDXMultiplier;
      procedure Test_EveryContestGivesItsPinnedCountryMode;
      procedure Test_RemainingCountriesFilterGivesItsPinnedAnswer;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uTestContestObjects,
   uTestContestKindPin;

type
   (* The entrants. us, ve and dx are the matrix's; host is a New England
      station inside its state party's host state; the rest take the
      DescribeSession branches the matrix never reaches. UA is a Russian
      station outside St Petersburg and its oblast, UA1 one inside it. *)
   TPinStation = (psUS, psVE, psDX, psHost, psPA, psJA, psSM, psHB, ps9A,
                  psYU, psON, psUA, psUA1, psEI);

   (* The worked stations: the CTY facts a logged QSO carries, typed in
      rather than looked up, so CTY.DAT cannot move a row. pqNone carries
      no country at all -- a call the country file did not know. *)
   TPinQso = (pqW1AW, pqVE3, pqKH6, pqKL7, pqKP4, pqXE1, pqON4, pqG3, pq9A2,
              pqI1, pqIS0, pqLZ1, pqUR5, pqJT1, pqJA1, pqUA9, pqUA0, pqPY2,
              pqVK2, pqNone);

   TStationRow = record
      Call: string;
      Country: string;
      Continent: ContinentType;
      State: string;
      InHostState: boolean;
   end;

   TQsoRow = record
      Call: string;
      CountryID: string;
      Continent: ContinentType;
   end;

   TKeyPin = record
      Contest: ContestType;
      Station: TPinStation;
      Qso: TPinQso;
      Assigns: boolean;
      Key: string;
   end;

   TModePin = record
      Contest: ContestType;
      Station: TPinStation;
      Mode: CountryModeType;
   end;

   TListPin = record
      Contest: ContestType;
      Station: TPinStation;
      Qso: TPinQso;
      Listed: boolean;
   end;

const
   STATIONS: array[TPinStation] of TStationRow = (
      (Call: 'K0AAA';  Country: 'K';  Continent: NorthAmerica; State: 'KS'; InHostState: False),
      (Call: 'VE3AAA'; Country: 'VE'; Continent: NorthAmerica; State: 'ON'; InHostState: False),
      (Call: 'DL1AAA'; Country: 'DL'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'K1AAA';  Country: 'K';  Continent: NorthAmerica; State: 'MA'; InHostState: True),
      (Call: 'PA3AAA'; Country: 'PA'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'JA1AAA'; Country: 'JA'; Continent: Asia;         State: '';   InHostState: False),
      (Call: 'SM5AAA'; Country: 'SM'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'HB9AAA'; Country: 'HB'; Continent: Europe;       State: '';   InHostState: False),
      (Call: '9A2AAA'; Country: '9A'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'YU1AAA'; Country: 'YU'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'ON4AAA'; Country: 'ON'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'UA3AAA'; Country: 'UA'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'UA1AAA'; Country: 'UA'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'EI2AAA'; Country: 'EI'; Continent: Europe;       State: '';   InHostState: False)
   );

   QSOS: array[TPinQso] of TQsoRow = (
      (Call: 'W1AW';   CountryID: 'K';   Continent: NorthAmerica),
      (Call: 'VE3ABC'; CountryID: 'VE';  Continent: NorthAmerica),
      (Call: 'KH6ABC'; CountryID: 'KH6'; Continent: Oceania),
      (Call: 'KL7ABC'; CountryID: 'KL';  Continent: NorthAmerica),
      (Call: 'KP4ABC'; CountryID: 'KP4'; Continent: NorthAmerica),
      (Call: 'XE1ABC'; CountryID: 'XE';  Continent: NorthAmerica),
      (Call: 'ON4ABC'; CountryID: 'ON';  Continent: Europe),
      (Call: 'G3ABC';  CountryID: 'G';   Continent: Europe),
      (Call: '9A2ABC'; CountryID: '9A';  Continent: Europe),
      (Call: 'I1ABC';  CountryID: 'I';   Continent: Europe),
      (Call: 'IS0ABC'; CountryID: 'IS';  Continent: Europe),
      (Call: 'LZ1ABC'; CountryID: 'LZ';  Continent: Europe),
      (Call: 'UR5ABC'; CountryID: 'UR';  Continent: Europe),
      (Call: 'JT1ABC'; CountryID: 'JT';  Continent: Asia),
      (Call: 'JA1ABC'; CountryID: 'JA';  Continent: Asia),
      (Call: 'UA9ABC'; CountryID: 'UA9'; Continent: Asia),
      (Call: 'UA0ABC'; CountryID: 'UA9'; Continent: Asia),
      (Call: 'PY2ABC'; CountryID: 'PY';  Continent: SouthAmerica),
      (Call: 'VK2ABC'; CountryID: 'VK';  Continent: Oceania),
      (Call: 'XX9ZZ';  CountryID: '';    Continent: UnknownContinent)
   );

   (* WRITTEN BY HAND FROM THE OLD CASE AND RUN GREEN AGAINST IT -- see the
      unit header. Every one of the 79 DX contests has a row that gives a
      key, and every station branch its rule has. *)
   KEY_PINS: array[0..170] of TKeyPin = (
      (* EVERY COUNTRY, AT EVERY STATION -- the old ARRLDXCC / CQDXCC kinds,
         the case's `else`. *)
      (Contest: ARRL_RTTY_ROUNDUP;       Station: psUS; Qso: pqW1AW; Assigns: True; Key: 'K'),
      (Contest: CIS;                     Station: psDX; Qso: pqUA9;  Assigns: True; Key: 'UA9'),
      (Contest: LABRE;                   Station: psVE; Qso: pqPY2;  Assigns: True; Key: 'PY'),
      (Contest: RADIOYOC;                Station: psDX; Qso: pqVE3;  Assigns: True; Key: 'VE'),
      (Contest: RU3AXMEMORIAL;           Station: psUA; Qso: pqJA1;  Assigns: True; Key: 'JA'),
      (Contest: RUSSIANDX;               Station: psUS; Qso: pqUA0;  Assigns: True; Key: 'UA9'),
      (Contest: UNDX;                    Station: psJA; Qso: pqKH6;  Assigns: True; Key: 'KH6'),
      (Contest: WRTC;                    Station: psUS; Qso: pqW1AW; Assigns: True; Key: 'K'),
      (Contest: YBDX;                    Station: psDX; Qso: pqKL7;  Assigns: True; Key: 'KL'),
      (Contest: YODX;                    Station: psVE; Qso: pqG3;   Assigns: True; Key: 'G'),
      (Contest: YOUTHCHAMPIONSHIPRF;     Station: psUA; Qso: pqUR5;  Assigns: True; Key: 'UR'),
      (Contest: BATAVIA_FT8;             Station: psUS; Qso: pqVK2;  Assigns: True; Key: 'VK'),
      (Contest: CQM;                     Station: psUA; Qso: pqW1AW; Assigns: True; Key: 'K'),
      (Contest: CQMM;                    Station: psDX; Qso: pqPY2;  Assigns: True; Key: 'PY'),
      (Contest: CQWWCW;                  Station: psUS; Qso: pqW1AW; Assigns: True; Key: 'K'),
      (Contest: CQWWCW;                  Station: psJA; Qso: pqJA1;  Assigns: True; Key: 'JA'),
      (Contest: CQWWSSB;                 Station: psVE; Qso: pqVE3;  Assigns: True; Key: 'VE'),
      (Contest: CQWWRTTY;                Station: psDX; Qso: pqIS0;  Assigns: True; Key: 'IS'),
      (Contest: DARC10M;                 Station: psDX; Qso: pqON4;  Assigns: True; Key: 'ON'),
      (Contest: DARC10M;                 Station: psUS; Qso: pqW1AW; Assigns: True; Key: 'K'),
      (Contest: EUDX;                    Station: psDX; Qso: pqXE1;  Assigns: True; Key: 'XE'),
      (Contest: FOCMARATHON;             Station: psUS; Qso: pqG3;   Assigns: True; Key: 'G'),
      (Contest: GACWWWSACW;              Station: psVE; Qso: pqI1;   Assigns: True; Key: 'I'),
      (Contest: HADX;                    Station: psDX; Qso: pqLZ1;  Assigns: True; Key: 'LZ'),
      (Contest: KINGOFSPAINCW;           Station: psUS; Qso: pqJT1;  Assigns: True; Key: 'JT'),
      (Contest: KINGOFSPAINSSB;          Station: psDX; Qso: pqKP4;  Assigns: True; Key: 'KP4'),
      (Contest: MARCONIMEMORIAL;         Station: psDX; Qso: pq9A2;  Assigns: True; Key: '9A'),
      (Contest: OKDX;                    Station: psUS; Qso: pqON4;  Assigns: True; Key: 'ON'),
      (Contest: OKOMSSB;                 Station: psDX; Qso: pqW1AW; Assigns: True; Key: 'K'),
      (Contest: OZCR_O;                  Station: psVE; Qso: pqUA9;  Assigns: True; Key: 'UA9'),
      (Contest: REGION1FIELDDAY;         Station: psDX; Qso: pqG3;   Assigns: True; Key: 'G'),
      (Contest: REGION1FIELDDAY_RCC_CW;  Station: psUA; Qso: pqUR5;  Assigns: True; Key: 'UR'),
      (Contest: REGION1FIELDDAY_RCC_SSB; Station: psUA; Qso: pqLZ1;  Assigns: True; Key: 'LZ'),
      (Contest: RSGB18;                  Station: psDX; Qso: pqW1AW; Assigns: True; Key: 'K'),
      (Contest: UKEI;                    Station: psUS; Qso: pqVE3;  Assigns: True; Key: 'VE'),
      (Contest: UKRAINIAN;               Station: psDX; Qso: pqUR5;  Assigns: True; Key: 'UR'),
      (Contest: WWIH;                    Station: psUS; Qso: pqXE1;  Assigns: True; Key: 'XE'),
      (Contest: YUDX;                    Station: psYU; Qso: pqW1AW; Assigns: True; Key: 'K'),
      (Contest: YUDX;                    Station: psDX; Qso: pqJA1;  Assigns: True; Key: 'JA'),

      (* EVERY COUNTRY, AT SOME STATIONS ONLY. *)
      (Contest: RDA;                     Station: psUA;  Qso: pqW1AW; Assigns: True;  Key: 'K'),
      (Contest: RDA;                     Station: psUS;  Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: ALRS_UA1DZ_CUP;          Station: psUS;  Qso: pqON4;  Assigns: True;  Key: 'ON'),
      (Contest: ALRS_UA1DZ_CUP;          Station: psUA1; Qso: pqW1AW; Assigns: True;  Key: 'K'),
      (Contest: ALRS_UA1DZ_CUP;          Station: psUA;  Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: WAG;                     Station: psDX;  Qso: pqW1AW; Assigns: True;  Key: 'K'),
      (Contest: WAG;                     Station: psUS;  Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: CROATIAN;                Station: ps9A;  Qso: pqW1AW; Assigns: True;  Key: 'K'),
      (Contest: CROATIAN;                Station: psUS;  Qso: pqON4;  Assigns: False; Key: ''),
      (Contest: HELVETIA;                Station: psHB;  Qso: pqJA1;  Assigns: True;  Key: 'JA'),
      (Contest: HELVETIA;                Station: psDX;  Qso: pqJA1;  Assigns: False; Key: ''),
      (Contest: JIDXCW;                  Station: psJA;  Qso: pqW1AW; Assigns: True;  Key: 'K'),
      (Contest: JIDXCW;                  Station: psUS;  Qso: pqJA1;  Assigns: False; Key: ''),
      (Contest: JIDXSSB;                 Station: psJA;  Qso: pqON4;  Assigns: True;  Key: 'ON'),
      (Contest: JIDXSSB;                 Station: psDX;  Qso: pqJA1;  Assigns: False; Key: ''),
      (Contest: SACCW;                   Station: psSM;  Qso: pqW1AW; Assigns: True;  Key: 'K'),
      (Contest: SACCW;                   Station: psUS;  Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: SACSSB;                  Station: psSM;  Qso: pqJT1;  Assigns: True;  Key: 'JT'),
      (Contest: SACSSB;                  Station: psDX;  Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: ALLASIANCW;              Station: psJA;  Qso: pqW1AW; Assigns: True;  Key: 'K'),
      (Contest: ALLASIANCW;              Station: psUS;  Qso: pqJA1;  Assigns: False; Key: ''),
      (Contest: ALLASIANSSB;             Station: psJA;  Qso: pqUA9;  Assigns: True;  Key: 'UA9'),
      (Contest: ALLASIANSSB;             Station: psDX;  Qso: pqJA1;  Assigns: False; Key: ''),

      (* EVERY COUNTRY BUT THE ARRL SECTION COUNTRIES. ARRL 160 only for an
         entrant IN one; nothing for anyone else. *)
      (Contest: ARRL10;                  Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: ARRL10;                  Station: psUS; Qso: pqKP4;  Assigns: False; Key: ''),
      (Contest: ARRL10;                  Station: psUS; Qso: pqKH6;  Assigns: False; Key: ''),
      (Contest: ARRL10;                  Station: psUS; Qso: pqXE1;  Assigns: True;  Key: 'XE'),
      (Contest: ARRL10;                  Station: psDX; Qso: pqON4;  Assigns: True;  Key: 'ON'),
      (Contest: WINTERFIELDDAY;          Station: psUS; Qso: pqVE3;  Assigns: False; Key: ''),
      (Contest: WINTERFIELDDAY;          Station: psUS; Qso: pqJA1;  Assigns: True;  Key: 'JA'),
      (Contest: ARRL160;                 Station: psUS; Qso: pqKL7;  Assigns: False; Key: ''),
      (Contest: ARRL160;                 Station: psUS; Qso: pqON4;  Assigns: True;  Key: 'ON'),
      (Contest: ARRL160;                 Station: psVE; Qso: pqXE1;  Assigns: True;  Key: 'XE'),
      (Contest: ARRL160;                 Station: psDX; Qso: pqON4;  Assigns: False; Key: ''),

      (* EVERY COUNTRY BUT THE USA AND CANADA. ARRL DX only for a W/VE
         entrant; Salmon Run only inside Washington. *)
      (Contest: ARRLDXCW;                Station: psUS;   Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: ARRLDXCW;                Station: psUS;   Qso: pqVE3;  Assigns: False; Key: ''),
      (Contest: ARRLDXCW;                Station: psUS;   Qso: pqKH6;  Assigns: True;  Key: 'KH6'),
      (Contest: ARRLDXCW;                Station: psVE;   Qso: pqON4;  Assigns: True;  Key: 'ON'),
      (Contest: ARRLDXCW;                Station: psDX;   Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: ARRLDXSSB;               Station: psVE;   Qso: pqKL7;  Assigns: True;  Key: 'KL'),
      (Contest: ARRLDXSSB;               Station: psDX;   Qso: pqJA1;  Assigns: False; Key: ''),
      (Contest: CQ160CW;                 Station: psUS;   Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: CQ160CW;                 Station: psDX;   Qso: pqVE3;  Assigns: False; Key: ''),
      (Contest: CQ160CW;                 Station: psDX;   Qso: pqKL7;  Assigns: True;  Key: 'KL'),
      (Contest: CQ160SSB;                Station: psUS;   Qso: pqXE1;  Assigns: True;  Key: 'XE'),
      (Contest: ArizonaQsoParty;         Station: psUS;   Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: ArizonaQsoParty;         Station: psUS;   Qso: pqKH6;  Assigns: True;  Key: 'KH6'),
      (Contest: FLORIDAQSOPARTY;         Station: psDX;   Qso: pqON4;  Assigns: True;  Key: 'ON'),
      (Contest: IDAHOQSOPARTY;           Station: psHost; Qso: pqVE3;  Assigns: False; Key: ''),
      (Contest: IDAHOQSOPARTY;           Station: psUS;   Qso: pqJA1;  Assigns: True;  Key: 'JA'),
      (Contest: SALMONRUN;               Station: psHost; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: SALMONRUN;               Station: psHost; Qso: pqKH6;  Assigns: True;  Key: 'KH6'),
      (Contest: SALMONRUN;               Station: psUS;   Qso: pqKH6;  Assigns: False; Key: ''),

      (* EVERY COUNTRY BUT THE USA, CANADA, HAWAII AND ALASKA. Delaware, 7QP
         and Texas only inside the host state; NEQP only in New England. *)
      (Contest: ARCI;                    Station: psUS;   Qso: pqKH6;  Assigns: False; Key: ''),
      (Contest: ARCI;                    Station: psUS;   Qso: pqKL7;  Assigns: False; Key: ''),
      (Contest: ARCI;                    Station: psUS;   Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: ARCI;                    Station: psUS;   Qso: pqVE3;  Assigns: False; Key: ''),
      (Contest: ARCI;                    Station: psUS;   Qso: pqKP4;  Assigns: True;  Key: 'KP4'),
      (Contest: ARCI;                    Station: psDX;   Qso: pqXE1;  Assigns: True;  Key: 'XE'),
      (Contest: DELAWAREQSOPARTY;        Station: psHost; Qso: pqKH6;  Assigns: False; Key: ''),
      (Contest: DELAWAREQSOPARTY;        Station: psHost; Qso: pqON4;  Assigns: True;  Key: 'ON'),
      (Contest: DELAWAREQSOPARTY;        Station: psUS;   Qso: pqON4;  Assigns: False; Key: ''),
      (Contest: NEBRASKAQSO;             Station: psHost; Qso: pqKH6;  Assigns: False; Key: ''),
      (Contest: NEBRASKAQSO;             Station: psHost; Qso: pqON4;  Assigns: True;  Key: 'ON'),
      (Contest: NEBRASKAQSO;             Station: psUS;   Qso: pqON4;  Assigns: False; Key: ''),
      (Contest: NEWENGLANDQSO;           Station: psHost; Qso: pqKL7;  Assigns: False; Key: ''),
      (Contest: NEWENGLANDQSO;           Station: psHost; Qso: pqXE1;  Assigns: True;  Key: 'XE'),
      (Contest: NEWENGLANDQSO;           Station: psUS;   Qso: pqXE1;  Assigns: False; Key: ''),
      (Contest: SEVENQP;                 Station: psHost; Qso: pqJA1;  Assigns: True;  Key: 'JA'),
      (Contest: SEVENQP;                 Station: psUS;   Qso: pqJA1;  Assigns: False; Key: ''),
      (Contest: TEXASQSOPARTY;           Station: psHost; Qso: pqVE3;  Assigns: False; Key: ''),
      (Contest: TEXASQSOPARTY;           Station: psHost; Qso: pqPY2;  Assigns: True;  Key: 'PY'),
      (Contest: TEXASQSOPARTY;           Station: psDX;   Qso: pqPY2;  Assigns: False; Key: ''),

      (* EVERY COUNTRY BUT ITALY: the first letter of the country, so an
         empty country (byte 1 of an empty field) still counts, with an
         EMPTY key. *)
      (Contest: ARI_DX;                  Station: psDX; Qso: pqI1;   Assigns: False; Key: ''),
      (Contest: ARI_DX;                  Station: psDX; Qso: pqIS0;  Assigns: False; Key: ''),
      (Contest: ARI_DX;                  Station: psDX; Qso: pq9A2;  Assigns: True;  Key: '9A'),
      (Contest: ARI_DX;                  Station: psDX; Qso: pqNone; Assigns: True;  Key: ''),

      (* EVERY COUNTRY BUT MONGOLIA. *)
      (Contest: JTDX;                    Station: psUS; Qso: pqJT1;  Assigns: False; Key: ''),
      (Contest: JTDX;                    Station: psUS; Qso: pqW1AW; Assigns: True;  Key: 'K'),

      (* THE BLACK SEA COUNTRIES. *)
      (Contest: BSCI;                    Station: psDX; Qso: pqLZ1;  Assigns: True;  Key: 'LZ'),
      (Contest: BSCI;                    Station: psDX; Qso: pqUR5;  Assigns: True;  Key: 'UR'),
      (Contest: BSCI;                    Station: psDX; Qso: pqG3;   Assigns: False; Key: ''),
      (Contest: BSCI;                    Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),

      (* NORTH AMERICA, BUT NOT THE USA, CANADA OR ALASKA. *)
      (Contest: NAQSOCW;                 Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: NAQSOCW;                 Station: psUS; Qso: pqVE3;  Assigns: False; Key: ''),
      (Contest: NAQSOCW;                 Station: psUS; Qso: pqKL7;  Assigns: False; Key: ''),
      (Contest: NAQSOCW;                 Station: psUS; Qso: pqKH6;  Assigns: False; Key: ''),
      (Contest: NAQSOCW;                 Station: psUS; Qso: pqON4;  Assigns: False; Key: ''),
      (Contest: NAQSOCW;                 Station: psUS; Qso: pqXE1;  Assigns: True;  Key: 'XE'),
      (Contest: NAQSOCW;                 Station: psUS; Qso: pqKP4;  Assigns: True;  Key: 'KP4'),
      (Contest: NAQSOSSB;                Station: psVE; Qso: pqXE1;  Assigns: True;  Key: 'XE'),
      (Contest: NAQSORTTY;               Station: psDX; Qso: pqKP4;  Assigns: True;  Key: 'KP4'),
      (Contest: NASPRINTCW;              Station: psUS; Qso: pqXE1;  Assigns: True;  Key: 'XE'),
      (Contest: NASPRINTRTTY;            Station: psUS; Qso: pqKP4;  Assigns: True;  Key: 'KP4'),
      (* The SSB Sprint, its own copy of the rule since Q16 (2026-10-16):
         KL7 and KH6 count as states, never as countries. *)
      (Contest: SPRINTSSB;               Station: psUS; Qso: pqXE1;  Assigns: True;  Key: 'XE'),
      (Contest: SPRINTSSB;               Station: psVE; Qso: pqKP4;  Assigns: True;  Key: 'KP4'),
      (Contest: SPRINTSSB;               Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: SPRINTSSB;               Station: psUS; Qso: pqVE3;  Assigns: False; Key: ''),
      (Contest: SPRINTSSB;               Station: psUS; Qso: pqKL7;  Assigns: False; Key: ''),
      (Contest: SPRINTSSB;               Station: psUS; Qso: pqKH6;  Assigns: False; Key: ''),
      (Contest: SPRINTSSB;               Station: psDX; Qso: pqON4;  Assigns: False; Key: ''),
      (Contest: INTERNETSPRINT;          Station: psUS; Qso: pqXE1;  Assigns: True;  Key: 'XE'),
      (Contest: SST;                     Station: psUS; Qso: pqXE1;  Assigns: True;  Key: 'XE'),
      (Contest: SST;                     Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),

      (* UBA: its own list of European countries (9A and LZ on it, G and ON
         not) for an entrant outside Belgium; every country for a Belgian. *)
      (Contest: UBACW;                   Station: psUS; Qso: pq9A2;  Assigns: True;  Key: '9A'),
      (Contest: UBACW;                   Station: psUS; Qso: pqLZ1;  Assigns: True;  Key: 'LZ'),
      (Contest: UBACW;                   Station: psUS; Qso: pqG3;   Assigns: False; Key: ''),
      (Contest: UBACW;                   Station: psUS; Qso: pqON4;  Assigns: False; Key: ''),
      (Contest: UBACW;                   Station: psON; Qso: pqG3;   Assigns: True;  Key: 'G'),
      (Contest: UBASSB;                  Station: psDX; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: UBASSB;                  Station: psON; Qso: pqON4;  Assigns: True;  Key: 'ON'),

      (* WAE: the European countries for an entrant outside Europe; nothing
         for a European, whose multiplier is the WAE prefix. *)
      (Contest: DARCWAEDCCW;             Station: psUS; Qso: pqON4;  Assigns: True;  Key: 'ON'),
      (Contest: DARCWAEDCCW;             Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: DARCWAEDCCW;             Station: psDX; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: DARCWAEDCSSB;            Station: psVE; Qso: pqG3;   Assigns: True;  Key: 'G'),
      (Contest: DARCWAEDCSSB;            Station: psDX; Qso: pqJA1;  Assigns: False; Key: ''),

      (* PACC, FOR A DUTCH ENTRANT: Asiatic Russia split by call area, nine
         countries keyed with their call area's digit, everyone else by
         country; nothing for anyone outside the Netherlands. *)
      (Contest: PACC;                    Station: psPA; Qso: pqUA9;  Assigns: True;  Key: 'UA9'),
      (Contest: PACC;                    Station: psPA; Qso: pqUA0;  Assigns: True;  Key: 'UA0'),
      (Contest: PACC;                    Station: psPA; Qso: pqJA1;  Assigns: True;  Key: 'JA1'),
      (Contest: PACC;                    Station: psPA; Qso: pqW1AW; Assigns: True;  Key: 'K1'),
      (Contest: PACC;                    Station: psPA; Qso: pqVE3;  Assigns: True;  Key: 'VE3'),
      (Contest: PACC;                    Station: psPA; Qso: pqPY2;  Assigns: True;  Key: 'PY2'),
      (Contest: PACC;                    Station: psPA; Qso: pqVK2;  Assigns: True;  Key: 'VK2'),
      (Contest: PACC;                    Station: psPA; Qso: pqKH6;  Assigns: True;  Key: 'KH6'),
      (Contest: PACC;                    Station: psPA; Qso: pqON4;  Assigns: True;  Key: 'ON'),
      (Contest: PACC;                    Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),

      (* NO DX MULTIPLIER AT ALL -- contests the move must not give one,
         IRTS at an Irish station and elsewhere, and the classless
         DUMMYCONTEST. *)
      (Contest: CQWPXCW;                 Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: ARRLSSCW;                Station: psUS; Qso: pqXE1;  Assigns: False; Key: ''),
      (Contest: IARU;                    Station: psJA; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: IRTS;                    Station: psEI; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: IRTS;                    Station: psUS; Qso: pqG3;   Assigns: False; Key: ''),
      (Contest: DUMMYCONTEST;            Station: psUS; Qso: pqW1AW; Assigns: False; Key: '')
   );

   (* THE CTY COUNTRY MODE THE CONTEST CHOOSES -- ARRL (DXCC only) for the
      six ARRL kinds, CQ (DXCC + WAE) for every other, NO DX MULTIPLIER
      INCLUDED; so a station that runs none gets the CQ list, and the North
      American kind, whatever its name, gets CQ. *)
   MODE_PINS: array[0..43] of TModePin = (
      (Contest: ARRLDXCW;          Station: psUS;   Mode: ARRLCountryMode),
      (Contest: ARRLDXCW;          Station: psVE;   Mode: ARRLCountryMode),
      (Contest: ARRLDXCW;          Station: psDX;   Mode: CQCountryMode),
      (Contest: ARRLDXSSB;         Station: psJA;   Mode: CQCountryMode),
      (Contest: YUDX;              Station: psYU;   Mode: ARRLCountryMode),
      (Contest: YUDX;              Station: psDX;   Mode: CQCountryMode),
      (Contest: JIDXCW;            Station: psJA;   Mode: ARRLCountryMode),
      (Contest: JIDXCW;            Station: psUS;   Mode: CQCountryMode),
      (Contest: ALLASIANCW;        Station: psJA;   Mode: ARRLCountryMode),
      (Contest: ALLASIANSSB;       Station: psUS;   Mode: CQCountryMode),
      (Contest: SACCW;             Station: psSM;   Mode: ARRLCountryMode),
      (Contest: SACSSB;            Station: psUS;   Mode: CQCountryMode),
      (Contest: HELVETIA;          Station: psHB;   Mode: ARRLCountryMode),
      (Contest: HELVETIA;          Station: psDX;   Mode: CQCountryMode),
      (Contest: RDA;               Station: psUA;   Mode: ARRLCountryMode),
      (Contest: RDA;               Station: psUS;   Mode: CQCountryMode),
      (Contest: DELAWAREQSOPARTY;  Station: psHost; Mode: ARRLCountryMode),
      (Contest: DELAWAREQSOPARTY;  Station: psUS;   Mode: CQCountryMode),
      (Contest: NEBRASKAQSO;       Station: psHost; Mode: ARRLCountryMode),
      (Contest: NEBRASKAQSO;       Station: psUS;   Mode: CQCountryMode),
      (Contest: NEWENGLANDQSO;     Station: psHost; Mode: ARRLCountryMode),
      (Contest: NEWENGLANDQSO;     Station: psUS;   Mode: CQCountryMode),
      (Contest: SEVENQP;           Station: psHost; Mode: ARRLCountryMode),
      (Contest: TEXASQSOPARTY;     Station: psUS;   Mode: CQCountryMode),
      (Contest: SALMONRUN;         Station: psHost; Mode: ARRLCountryMode),
      (Contest: SALMONRUN;         Station: psUS;   Mode: CQCountryMode),
      (Contest: ARRL160;           Station: psUS;   Mode: ARRLCountryMode),
      (Contest: ARRL160;           Station: psDX;   Mode: CQCountryMode),
      (Contest: ARRL10;            Station: psDX;   Mode: ARRLCountryMode),
      (Contest: WINTERFIELDDAY;    Station: psUS;   Mode: ARRLCountryMode),
      (Contest: ARI_DX;            Station: psDX;   Mode: ARRLCountryMode),
      (Contest: JTDX;              Station: psUS;   Mode: ARRLCountryMode),
      (Contest: ARCI;              Station: psUS;   Mode: ARRLCountryMode),
      (Contest: ArizonaQsoParty;   Station: psDX;   Mode: ARRLCountryMode),
      (Contest: YBDX;              Station: psUS;   Mode: ARRLCountryMode),
      (Contest: NAQSOCW;           Station: psUS;   Mode: CQCountryMode),
      (Contest: CQ160CW;           Station: psUS;   Mode: CQCountryMode),
      (Contest: CQWWCW;            Station: psUS;   Mode: CQCountryMode),
      (Contest: ALRS_UA1DZ_CUP;    Station: psUA1;  Mode: CQCountryMode),
      (Contest: CROATIAN;          Station: ps9A;   Mode: CQCountryMode),
      (Contest: UBACW;             Station: psON;   Mode: CQCountryMode),
      (Contest: PACC;              Station: psPA;   Mode: CQCountryMode),
      (Contest: CQWPXCW;           Station: psUS;   Mode: CQCountryMode),
      (Contest: DUMMYCONTEST;      Station: psUS;   Mode: CQCountryMode)
   );

   (* WHICH COUNTRIES THE REMAINING-MULTS WINDOW LISTS -- today's three
      filters exactly, and not the whole DX rule (plan F7). Asked only where
      the contest has a DX multiplier (HasDXMultiplier, since M11 S4 part 2):
      FillVisibleBytes hides everything before the filters otherwise. *)
   LIST_PINS: array[0..12] of TListPin = (
      (Contest: DARCWAEDCCW;   Station: psUS; Qso: pqON4;  Listed: True),
      (Contest: DARCWAEDCCW;   Station: psUS; Qso: pqW1AW; Listed: False),
      (Contest: DARCWAEDCSSB;  Station: psVE; Qso: pqJA1;  Listed: False),
      (Contest: UBACW;         Station: psUS; Qso: pq9A2;  Listed: True),
      (Contest: UBACW;         Station: psUS; Qso: pqG3;   Listed: False),
      (Contest: UBACW;         Station: psUS; Qso: pqON4;  Listed: False),
      (Contest: UBACW;         Station: psON; Qso: pqG3;   Listed: True),
      (Contest: UBASSB;        Station: psDX; Qso: pqW1AW; Listed: False),
      (Contest: CQWWCW;        Station: psUS; Qso: pqW1AW; Listed: True),
      (Contest: ARRLDXCW;      Station: psUS; Qso: pqW1AW; Listed: True),
      (Contest: NAQSOCW;       Station: psUS; Qso: pqON4;  Listed: True),
      (Contest: BSCI;          Station: psDX; Qso: pqG3;   Listed: True),
      (Contest: PACC;          Station: psPA; Qso: pqUA9;  Listed: True)
   );

type
   TContestSet = set of ContestType;

const
   (* A DX MULTIPLIER AT EVERY STATION: the 56 contests whose session ran a
      DX kind wherever it ran, and the SSB Sprint since Q16 (2026-10-16) --
      57. *)
   DX_EVERYWHERE = [ARCI, ARI_DX, ARRL10, ARRL_RTTY_ROUNDUP, ArizonaQsoParty,
                    BATAVIA_FT8, BSCI, CIS, CQ160CW, CQ160SSB, CQM, CQMM,
                    CQWWCW, CQWWRTTY, CQWWSSB, DARC10M, EUDX, FLORIDAQSOPARTY,
                    FOCMARATHON, GACWWWSACW, HADX, IDAHOQSOPARTY,
                    INTERNETSPRINT, JTDX, KINGOFSPAINCW, KINGOFSPAINSSB, LABRE,
                    MARCONIMEMORIAL, NAQSOCW, NAQSORTTY, NAQSOSSB, NASPRINTCW,
                    NASPRINTRTTY, OKDX, OKOMSSB, OZCR_O, RADIOYOC,
                    REGION1FIELDDAY, REGION1FIELDDAY_RCC_CW,
                    REGION1FIELDDAY_RCC_SSB, RSGB18, RU3AXMEMORIAL, RUSSIANDX,
                    SPRINTSSB, SST, UBACW, UBASSB, UKEI, UKRAINIAN, UNDX, WINTERFIELDDAY,
                    WRTC, WWIH, YBDX, YODX, YOUTHCHAMPIONSHIPRF, YUDX];

   (* WHO HAS A DX MULTIPLIER AT EACH ROSTER STATION -- see the unit header
      for where each set comes from. The other 22 DX contests decide by the
      entrant: the ALRS cup (not a Russian outside St Petersburg), ARRL 160
      (an ARRL section country), ARRL DX x2 (W/VE), WAE x2 (outside Europe),
      WAG (DL), the All Asian x2 (Asia), JIDX x2 (JA), SAC x2 (Scandinavia),
      Helvetia (HB), the Croatian (9A), PACC (PA), RDA (Russia), NEQP (New
      England), and Delaware, 7QP, Texas and the Salmon Run (in the host
      state). NEVER REGENERATE A SET TO CLEAR A FAILURE. *)
   HAS_DX: array[TPinStation] of TContestSet = (
      (* psUS K0AAA *)   DX_EVERYWHERE + [ALRS_UA1DZ_CUP, ARRL160, ARRLDXCW, ARRLDXSSB,
                                          DARCWAEDCCW, DARCWAEDCSSB],
      (* psVE VE3AAA *)  DX_EVERYWHERE + [ALRS_UA1DZ_CUP, ARRL160, ARRLDXCW, ARRLDXSSB,
                                          DARCWAEDCCW, DARCWAEDCSSB],
      (* psDX DL1AAA *)  DX_EVERYWHERE + [ALRS_UA1DZ_CUP, WAG],
      (* psHost K1AAA *) DX_EVERYWHERE + [ALRS_UA1DZ_CUP, ARRL160, ARRLDXCW, ARRLDXSSB,
                                          DARCWAEDCCW, DARCWAEDCSSB, DELAWAREQSOPARTY, NEBRASKAQSO,
                                          NEWENGLANDQSO, SALMONRUN, SEVENQP, TEXASQSOPARTY],
      (* psPA PA3AAA *)  DX_EVERYWHERE + [ALRS_UA1DZ_CUP, PACC],
      (* psJA JA1AAA *)  DX_EVERYWHERE + [ALLASIANCW, ALLASIANSSB, ALRS_UA1DZ_CUP,
                                          DARCWAEDCCW, DARCWAEDCSSB, JIDXCW, JIDXSSB],
      (* psSM SM5AAA *)  DX_EVERYWHERE + [ALRS_UA1DZ_CUP, SACCW, SACSSB],
      (* psHB HB9AAA *)  DX_EVERYWHERE + [ALRS_UA1DZ_CUP, HELVETIA],
      (* ps9A 9A2AAA *)  DX_EVERYWHERE + [ALRS_UA1DZ_CUP, CROATIAN],
      (* psYU YU1AAA *)  DX_EVERYWHERE + [ALRS_UA1DZ_CUP],
      (* psON ON4AAA *)  DX_EVERYWHERE + [ALRS_UA1DZ_CUP],
      (* psUA UA3AAA *)  DX_EVERYWHERE + [RDA],
      (* psUA1 UA1AAA *) DX_EVERYWHERE + [ALRS_UA1DZ_CUP, RDA],
      (* psEI EI2AAA *)  DX_EVERYWHERE + [ALRS_UA1DZ_CUP]
   );

   (* How many contests each set holds -- stated so a set edited by mistake
      fails by count as well as by name. *)
   HAS_DX_COUNT: array[TPinStation] of integer =
      (63, 63, 59, 69, 59, 64, 60, 59, 59, 58, 58, 58, 59, 58);

function PinStation(aStation: TPinStation; aContest: ContestType): TStationContext;
begin
   Result := MatrixStation(STATIONS[aStation].Call, STATIONS[aStation].Country,
                           STATIONS[aStation].Continent, STATIONS[aStation].State,
                           'DX', '', STATIONS[aStation].InHostState,
                           SessionContestName(aContest, STATIONS[aStation].InHostState));
end;

function PinQso(aQso: TPinQso): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.Callsign := CallString(QSOS[aQso].Call);
   Result.QTH.CountryID := DXMultiplierString(QSOS[aQso].CountryID);
   Result.QTH.Continent := QSOS[aQso].Continent;
   Result.QTH.StandardCall := CallString(QSOS[aQso].Call);
end;

(* WHAT THE PROGRAM GIVES -- what LOGDUPE.GetDXQTH, uSettingsEffects and
   uMults.FillVisibleBytes ask since the move: the contest's own rule, on a
   contest object holding the station, as ActiveContest hands it. nil (the
   classless DUMMYCONTEST) answers as the Contest... wrappers answer nil.
   BEFORE THE MOVE each of these returned the frozen legacy rule (deleted at
   M11 S4 part 2), selected by Kinds(aContest, aStation).DXMult -- the run
   that made the literals (green on the old code but for one hand count,
   corrected). *)
function ProgramKey(aContest: ContestType;
                    const aStation: TStationContext;
                    const aQso: ContestExchange;
                    out aKey: DXMultiplierString): boolean;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      Result := ContestDXMultiplierKey(obj, aQso, aKey);
   finally
      obj.Free;
      end;
end;

function ProgramCountryMode(aContest: ContestType;
                            const aStation: TStationContext): CountryModeType;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      Result := ContestCountryMode(obj);
   finally
      obj.Free;
      end;
end;

function ProgramListsCountry(aContest: ContestType;
                             const aStation: TStationContext;
                             const aQso: ContestExchange): boolean;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      Result := ContestListsRemainingDXCountry(obj, aQso.QTH.CountryID, aQso.QTH.Continent);
   finally
      obj.Free;
      end;
end;

(* WHETHER THE PROGRAM SAYS THE CONTEST HAS A DX MULTIPLIER -- what
   LOGEDIT.DoingDXMults and every reader holding the object ask since M11 S4
   part 2, on an object holding the station, as ActiveContest hands it. *)
function ProgramHas(aContest: ContestType; const aStation: TStationContext): boolean;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      Result := ContestHasDXMultiplier(obj);
   finally
      obj.Free;
      end;
end;

(* "none", or the key in brackets -- so '' and "no key" differ on the page. *)
function Answer(aAssigns: boolean; const aKey: string): string;
begin
   if aAssigns then
      begin
      Result := '[' + aKey + ']';
      end
   else
      begin
      Result := 'none';
      end;
end;

function ModeName(aMode: CountryModeType): string;
begin
   if aMode = ARRLCountryMode then
      begin
      Result := 'ARRL';
      end
   else
      begin
      Result := 'CQ';
      end;
end;

function Who(aContest: ContestType; aStation: TPinStation): string;
begin
   Result := string(ContestTypeSA[aContest]) + ' at ' + STATIONS[aStation].Call;
end;

procedure TDXMultiplierKeyTests.RunAllTests;
begin
   Test_EveryDXContestGivesItsPinnedKey;
   Test_EveryContestHasItsPinnedDXMultiplier;
   Test_EveryContestGivesItsPinnedCountryMode;
   Test_RemainingCountriesFilterGivesItsPinnedAnswer;
end;

procedure TDXMultiplierKeyTests.Test_EveryDXContestGivesItsPinnedKey;
var
   i: integer;
   pin: TKeyPin;
   key: DXMultiplierString;
   assigns: boolean;
   named: set of ContestType;
   count: integer;
   c: ContestType;
begin
   BeginTest('Test_EveryDXContestGivesItsPinnedKey');
   named := [];
   for i := Low(KEY_PINS) to High(KEY_PINS) do
      begin
      pin := KEY_PINS[i];
      assigns := ProgramKey(pin.Contest, PinStation(pin.Station, pin.Contest),
                            PinQso(pin.Qso), key);
      CheckEquals(Answer(pin.Assigns, pin.Key), Answer(assigns, string(key)),
                  Who(pin.Contest, pin.Station) + ' working ' + QSOS[pin.Qso].Call);
      if pin.Assigns then
         begin
         Include(named, pin.Contest);
         end;
      end;

   (* EVERY DX CONTEST HAS A ROW THAT GIVES A KEY -- 78, plan 1.5 / S4; 79
      since the SSB Sprint's (Q16, 2026-10-16). *)
   count := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if c in named then
         begin
         Inc(count);
         end;
      end;
   CheckEquals(80, count, 'contests with a pinned DX key');
end;

procedure TDXMultiplierKeyTests.Test_EveryContestHasItsPinnedDXMultiplier;
var
   c: ContestType;
   s: TPinStation;
   q: TPinQso;
   station: TStationContext;
   key: DXMultiplierString;
   has: boolean;
   checked: integer;
   counted: integer;
   anywhere: TContestSet;
   count: integer;
begin
   BeginTest('Test_EveryContestHasItsPinnedDXMultiplier');
   checked := 0;
   anywhere := [];
   for s := Low(TPinStation) to High(TPinStation) do
      begin
      counted := 0;
      for c := Low(ContestType) to High(ContestType) do
         begin
         if c in HAS_DX[s] then
            begin
            Inc(counted);
            end;
         end;
      CheckEquals(HAS_DX_COUNT[s], counted, 'contests in the set for ' + STATIONS[s].Call);

      for c := Low(ContestType) to High(ContestType) do
         begin
         station := PinStation(s, c);
         has := ProgramHas(c, station);
         CheckTrue(has = (c in HAS_DX[s]), Who(c, s) + ' has a DX multiplier');
         if has then
            begin
            Include(anywhere, c);
            end
         else
            begin
            (* THE INVARIANT: a key only where there is a DX multiplier. *)
            for q := Low(TPinQso) to High(TPinQso) do
               begin
               CheckFalse(ProgramKey(c, station, PinQso(q), key),
                          Who(c, s) + ' gives no key working ' + QSOS[q].Call);
               end;
            end;
         Inc(checked);
         end;
      end;

   (* EXACT: every contest at every roster station. *)
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1), checked,
               'contest x station answers compared');

   (* THE 79 DX CONTESTS, AND NO OTHER, HAVE ONE SOMEWHERE ON THE ROSTER. *)
   count := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if c in anywhere then
         begin
         Inc(count);
         end;
      end;
   CheckEquals(80, count, 'contests with a DX multiplier at some roster station');
end;

procedure TDXMultiplierKeyTests.Test_EveryContestGivesItsPinnedCountryMode;
var
   i: integer;
   pin: TModePin;
   c: ContestType;
   s: TPinStation;
   arrl: TContestSet;
   count: integer;
begin
   BeginTest('Test_EveryContestGivesItsPinnedCountryMode');
   for i := Low(MODE_PINS) to High(MODE_PINS) do
      begin
      pin := MODE_PINS[i];
      CheckEquals(ModeName(pin.Mode),
                  ModeName(ProgramCountryMode(pin.Contest, PinStation(pin.Station, pin.Contest))),
                  Who(pin.Contest, pin.Station));
      end;

   (* 36 contests choose the ARRL list at some roster station: the 21 whose
      trait was an ARRL kind and the 15 whose DescribeSession stated one for
      some entrant. Measured on the old code at S4 part 1 (the hand count said
      35); kept as a literal count when the cross-check that measured it went
      with the kind (M11 S4 part 2). *)
   arrl := [];
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         if ProgramCountryMode(c, PinStation(s, c)) = ARRLCountryMode then
            begin
            Include(arrl, c);
            end;
         end;
      end;
   count := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if c in arrl then
         begin
         Inc(count);
         end;
      end;
   (* 37 since the Nebraska QSO Party (2026-10-16), ARRL for its entrant. *)
   CheckEquals(37, count, 'contests choosing the ARRL country list at some roster station');
end;

procedure TDXMultiplierKeyTests.Test_RemainingCountriesFilterGivesItsPinnedAnswer;
var
   i: integer;
   pin: TListPin;
begin
   BeginTest('Test_RemainingCountriesFilterGivesItsPinnedAnswer');
   for i := Low(LIST_PINS) to High(LIST_PINS) do
      begin
      pin := LIST_PINS[i];
      CheckEquals(BoolToStr(pin.Listed, True),
                  BoolToStr(ProgramListsCountry(pin.Contest, PinStation(pin.Station, pin.Contest),
                                                PinQso(pin.Qso)), True),
                  Who(pin.Contest, pin.Station) + ' listing ' + QSOS[pin.Qso].CountryID);
      end;
end;

end.
