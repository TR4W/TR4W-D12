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

  HOW THE LITERALS WERE MADE. Written by hand from the old code, then RUN
  GREEN AGAINST THE OLD CODE before anything moved: the program's own case
  and set and filters, frozen below (Legacy...OfKind), selected by the
  session kind uTestContestKindPin.Kinds resolves (the trait, then
  DescribeSession) -- exactly what the engine selected. Then the move, and
  the same tables green against the classes.

  AND A CROSS-CHECK FOR EVERY CONTEST, NOT ONLY THE 78. The *AgreesWith*
  tests ask every ContestType at every roster station, and compare the
  class's answer with the frozen legacy rule under the kind the session
  resolves to. So the move is pinned in both directions: no DX contest lost a
  branch, and no other contest gained a key. It holds only while the session
  still carries DXMult; S4 part 2 deletes that kind, and these cross-checks
  and the frozen rules go with it, leaving the literals.

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
      procedure Test_EveryContestKeyAgreesWithItsSessionKind;
      procedure Test_EveryContestGivesItsPinnedCountryMode;
      procedure Test_EveryContestCountryModeAgreesWithItsSessionKind;
      procedure Test_RemainingCountriesFilterGivesItsPinnedAnswer;
      procedure Test_RemainingCountriesFilterAgreesWithItsSessionKind;
   end;

implementation

uses
   SysUtils,
   VC,
   uCallSignRoutines,
   utils_text,
   uContestBase,
   uContestRegistry,
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
      unit header. Every one of the 78 DX contests has a row that gives a
      key, and every station branch its rule has. *)
   KEY_PINS: array[0..160] of TKeyPin = (
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
   MODE_PINS: array[0..41] of TModePin = (
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
      the session counts DX multipliers: FillVisibleBytes hides everything
      before the filters otherwise. *)
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

(* LOGDUPE.GetNumber AS IT STOOD AT 3c8ce116, verbatim -- PACC's arm called
   it. A different routine from uCallSignRoutines.GetNumber: the last digit
   run of the PREFIX, defaulting to '0'. Frozen here with the case below. *)
function LegacyGetNumber(Call: CallString): AnsiChar;
var
   TempString, NumberString: CallString;
begin
   LegacyGetNumber := '0';

   if (Call = '') or not StringHasNumber(Call) then
      begin
      Exit;
      end;

   TempString := GetPrefix(Call);

   NumberString := '';

   while (TempString <> '') and
         (Copy(TempString, length(TempString), 1) >= '0') and
         (Copy(TempString, length(TempString), 1) <= '9') do
      begin
      NumberString := Copy(TempString, length(TempString), 1) + NumberString;
      Delete(TempString, length(TempString), 1);
      end;

   LegacyGetNumber := NumberString[1];
end;

(* THE OLD CASE, FROZEN -- LOGDUPE.GetDXQTH's `case ContestSession.DXMult of`
   as it stood at 3c8ce116, verbatim but for the out-parameter (an arm that
   assigned answers True; one that did not, False). Its head -- COUNT
   DOMESTIC COUNTRIES, the WYSIWYG domestic QTH and the domestic-country
   call -- is the engine's and stays in GetDXQTH, so it is not here. The
   dead arms (CQ DXCC without HB9 or OK, the non-European and non-South
   American countries -- reach 0 since M11 S2) are kept, as they stood. It
   goes when S4 part 2 deletes DXMultType. *)
function LegacyDXKeyOfKind(aKind: DXMultType;
                           const RXData: ContestExchange;
                           out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   case aKind of
      NoDXMults:
         begin
         end;
      ARRLDXCCWithNoUSAOrCanada, CQDXCCWithNoUSAOrCanada:
         begin
         if (RXData.QTH.CountryID <> 'K') and (RXData.QTH.CountryID <> 'VE') then
            begin
            aKey := RXData.QTH.CountryID;
            Result := True;
            end;
         end;
      ARRLDXCCWithNoARRLSections:
         begin
         if pos(' ' + RXData.QTH.CountryID + ' ', ARRLSectionCountryString) = 0 then
            begin
            aKey := RXData.QTH.CountryID;
            Result := True;
            end;
         end;
      ARRLDXCCWithNoUSACanadaKH6OrKL7:
         begin
         if (RXData.QTH.CountryID <> 'K') and (RXData.QTH.CountryID <> 'VE') and
            (RXData.QTH.CountryID <> 'KH6') and (RXData.QTH.CountryID <> 'KL') then
            begin
            aKey := RXData.QTH.CountryID;
            Result := True;
            end;
         end;
      ARRLDXCCWithNoIOrIS0:
         begin
         if RXData.QTH.CountryID[1] <> 'I' then
            begin
            aKey := RXData.QTH.CountryID;
            Result := True;
            end;
         end;
      CQDXCCWithNoHB9:
         begin
         if RXData.QTH.CountryID <> 'HB' then
            begin
            aKey := RXData.QTH.CountryID;
            Result := True;
            end;
         end;
      CQDXCCWithNoOK:
         begin
         if RXData.QTH.CountryID <> 'OK' then
            begin
            aKey := RXData.QTH.CountryID;
            Result := True;
            end;
         end;
      ARRLDXCCWithNoJT:
         begin
         if RXData.QTH.CountryID <> 'JT' then
            begin
            aKey := RXData.QTH.CountryID;
            Result := True;
            end;
         end;
      NorthAmericanARRLDXCCWithNoUSACanadaOrkL7:
         begin
         if RXData.QTH.Continent = NorthAmerica then
            begin
            if (RXData.QTH.CountryID <> 'K') and
               (RXData.QTH.CountryID <> 'VE') and
               (RXData.QTH.CountryID <> 'KL') then
               begin
               aKey := RXData.QTH.CountryID;
               Result := True;
               end;
            end;
         end;
      CQEuropeanCountries:
         begin
         if RXData.QTH.Continent = Europe then
            begin
            aKey := RXData.QTH.CountryID;
            Result := True;
            end;
         end;
      CQUBAEuropeanCountries:
         begin
         if UBACountry(RXData.QTH.CountryID) then
            begin
            aKey := RXData.QTH.CountryID;
            Result := True;
            end;
         end;
      CQNonEuropeanCountries:
         begin
         if RXData.QTH.Continent <> Europe then
            begin
            aKey := RXData.QTH.CountryID;
            Result := True;
            end;
         end;
      NonSouthAmericanCountries:
         begin
         if RXData.QTH.Continent <> SouthAmerica then
            begin
            aKey := RXData.QTH.CountryID;
            Result := True;
            end;
         end;
      BlackSeaCountries:
         begin
         if BlackSeaRegionCountry(RXData.QTH.CountryID) then
            begin
            aKey := RXData.QTH.CountryID;
            Result := True;
            end;
         end;
      PACCCountriesAndPrefixes:
         begin
         Result := True;
         if RXData.QTH.CountryID = 'UA9' then
            begin
            if StringHas(RXData.Callsign, '9') then
               begin
               aKey := 'UA9';
               end
            else
               begin
               aKey := 'UA0';
               end;
            Exit;
            end;

         if (RXData.QTH.CountryID = 'CE') or
            (RXData.QTH.CountryID = 'JA') or (RXData.QTH.CountryID = 'LU') or
            (RXData.QTH.CountryID = 'PY') or (RXData.QTH.CountryID = 'VE') or
            (RXData.QTH.CountryID = 'K') or (RXData.QTH.CountryID = 'VK') or
            (RXData.QTH.CountryID = 'ZS') or (RXData.QTH.CountryID = 'ZL') then
            begin
            aKey := RXData.QTH.CountryID + AnsiChar(LegacyGetNumber(RXData.Callsign));
            Exit;
            end;

         aKey := RXData.QTH.CountryID;
         end;
   else
      begin
      aKey := RXData.QTH.CountryID;
      Result := True;
      end;
   end;
end;

(* THE OLD COUNTRY-MODE RULE, FROZEN -- uSettingsEffects' CONTEST arm as it
   stood at 3c8ce116, verbatim. *)
function LegacyCountryModeOfKind(aKind: DXMultType): CountryModeType;
begin
   if aKind in [ARRLDXCCWithNoUSAOrCanada,
                ARRLDXCCWithNoARRLSections,
                ARRLDXCCWithNoUSACanadaKH6OrKL7,
                ARRLDXCCWithNoIOrIS0,
                ARRLDXCCWithNoJT,
                ARRLDXCC] then
      begin
      Result := ARRLCountryMode;
      end
   else
      begin
      Result := CQCountryMode;
      end;
end;

(* THE OLD REMAINING-COUNTRIES FILTERS, FROZEN -- uMults.FillVisibleBytes'
   three `Continue`s as they stood at 3c8ce116: True means the country is
   listed (not skipped). *)
function LegacyListsCountryOfKind(aKind: DXMultType;
                                  const aCountryID: DXMultiplierString;
                                  aContinent: ContinentType): boolean;
begin
   Result := True;
   if aKind = CQNonEuropeanCountries then
      begin
      if aContinent = Europe then
         begin
         Result := False;
         end;
      end;
   if aKind = CQEuropeanCountries then
      begin
      if aContinent <> Europe then
         begin
         Result := False;
         end;
      end;
   if aKind = CQUBAEuropeanCountries then
      begin
      if not UBACountry(aCountryID) then
         begin
         Result := False;
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

(* WHAT THE PROGRAM GIVES -- what LOGDUPE.GetDXQTH, uSettingsEffects and
   uMults.FillVisibleBytes ask since the move: the contest's own rule, on a
   contest object holding the station, as ActiveContest hands it. nil (the
   classless DUMMYCONTEST) answers as the Contest... wrappers answer nil.
   BEFORE THE MOVE each of these returned the frozen legacy rule above,
   selected by Kinds(aContest, aStation).DXMult -- the run that made the
   literals (green on the old code but for one hand count, corrected). *)
function ProgramKey(aContest: ContestType;
                    const aStation: TStationContext;
                    const aQso: ContestExchange;
                    out aKey: DXMultiplierString): boolean;
var
   obj: TContestBase;
begin
   obj := MakeContest(aContest, aStation);
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
   obj := MakeContest(aContest, aStation);
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
   obj := MakeContest(aContest, aStation);
   try
      Result := ContestListsRemainingDXCountry(obj, aQso.QTH.CountryID, aQso.QTH.Continent);
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
   Test_EveryContestKeyAgreesWithItsSessionKind;
   Test_EveryContestGivesItsPinnedCountryMode;
   Test_EveryContestCountryModeAgreesWithItsSessionKind;
   Test_RemainingCountriesFilterGivesItsPinnedAnswer;
   Test_RemainingCountriesFilterAgreesWithItsSessionKind;
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

   (* EVERY DX CONTEST HAS A ROW THAT GIVES A KEY -- 78, plan 1.5 / S4. *)
   count := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if c in named then
         begin
         Inc(count);
         end;
      end;
   CheckEquals(78, count, 'contests with a pinned DX key');
end;

procedure TDXMultiplierKeyTests.Test_EveryContestKeyAgreesWithItsSessionKind;
var
   c: ContestType;
   s: TPinStation;
   q: TPinQso;
   station: TStationContext;
   kind: DXMultType;
   qso: ContestExchange;
   oldKey: DXMultiplierString;
   newKey: DXMultiplierString;
   oldAssigns: boolean;
   newAssigns: boolean;
   checked: integer;
   keyed: set of ContestType;
   count: integer;
begin
   BeginTest('Test_EveryContestKeyAgreesWithItsSessionKind');
   checked := 0;
   keyed := [];
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         kind := Kinds(c, station).DXMult;
         for q := Low(TPinQso) to High(TPinQso) do
            begin
            qso := PinQso(q);
            oldAssigns := LegacyDXKeyOfKind(kind, qso, oldKey);
            newAssigns := ProgramKey(c, station, qso, newKey);
            CheckEquals(Answer(oldAssigns, string(oldKey)), Answer(newAssigns, string(newKey)),
                        Who(c, s) + ' working ' + QSOS[q].Call);
            if newAssigns then
               begin
               Include(keyed, c);
               end;
            Inc(checked);
            end;
         end;
      end;

   (* EXACT: every contest, every roster station, every QSO. *)
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1) *
               (Ord(High(TPinQso)) + 1), checked, 'contest x station x QSO keys compared');

   (* THE 78 DX CONTESTS, AND NO OTHER, GIVE A KEY ANYWHERE ON THE ROSTER. *)
   count := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if c in keyed then
         begin
         Inc(count);
         end;
      end;
   CheckEquals(78, count, 'contests that give a DX key at some roster station');
end;

procedure TDXMultiplierKeyTests.Test_EveryContestGivesItsPinnedCountryMode;
var
   i: integer;
   pin: TModePin;
begin
   BeginTest('Test_EveryContestGivesItsPinnedCountryMode');
   for i := Low(MODE_PINS) to High(MODE_PINS) do
      begin
      pin := MODE_PINS[i];
      CheckEquals(ModeName(pin.Mode),
                  ModeName(ProgramCountryMode(pin.Contest, PinStation(pin.Station, pin.Contest))),
                  Who(pin.Contest, pin.Station));
      end;
end;

procedure TDXMultiplierKeyTests.Test_EveryContestCountryModeAgreesWithItsSessionKind;
var
   c: ContestType;
   s: TPinStation;
   station: TStationContext;
   checked: integer;
   arrl: set of ContestType;
   count: integer;
begin
   BeginTest('Test_EveryContestCountryModeAgreesWithItsSessionKind');
   checked := 0;
   arrl := [];
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         CheckEquals(ModeName(LegacyCountryModeOfKind(Kinds(c, station).DXMult)),
                     ModeName(ProgramCountryMode(c, station)), Who(c, s));
         if ProgramCountryMode(c, station) = ARRLCountryMode then
            begin
            Include(arrl, c);
            end;
         Inc(checked);
         end;
      end;
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1), checked,
               'contest x station country modes compared');

   (* 36 contests choose the ARRL list at some roster station: the 21 whose
      trait is an ARRL kind and the 15 whose DescribeSession states one for
      some entrant. Measured on the old code (run 1); the hand count said 35. *)
   count := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if c in arrl then
         begin
         Inc(count);
         end;
      end;
   CheckEquals(36, count, 'contests choosing the ARRL country list at some roster station');
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

procedure TDXMultiplierKeyTests.Test_RemainingCountriesFilterAgreesWithItsSessionKind;
var
   c: ContestType;
   s: TPinStation;
   q: TPinQso;
   station: TStationContext;
   kind: DXMultType;
   qso: ContestExchange;
   checked: integer;
begin
   BeginTest('Test_RemainingCountriesFilterAgreesWithItsSessionKind');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         kind := Kinds(c, station).DXMult;
         (* FillVisibleBytes hides every country before the filters when the
            session counts no DX multiplier, so nothing is asked there. *)
         if kind = NoDXMults then
            begin
            Continue;
            end;
         for q := Low(TPinQso) to High(TPinQso) do
            begin
            qso := PinQso(q);
            CheckEquals(BoolToStr(LegacyListsCountryOfKind(kind, qso.QTH.CountryID,
                                                           qso.QTH.Continent), True),
                        BoolToStr(ProgramListsCountry(c, station, qso), True),
                        Who(c, s) + ' listing ' + QSOS[q].CountryID);
            Inc(checked);
            end;
         end;
      end;
   CheckTrue(checked > 0, 'remaining-countries answers compared');
end;

end.
