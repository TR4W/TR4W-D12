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

(* THE PREFIX MULTIPLIER KEY EVERY PREFIX CONTEST GIVES, AT STATIONS THE
  CONTEST MATRIX DOES NOT RUN -- M11 S3, 2026-10-14
  (docs/CONTEST_FACTORY_M11_PLAN.md S3).

  WHY IT EXISTS. S3 moves LOGEDIT.SetPrefix's `case ContestSession.PrefixMult
  of` into the classes. The matrix pins SetPrefix for its own stations (us,
  ve, dx), and S0c's `== keys` QSOs execute most arms there. It cannot see a
  branch only another entrant takes: CQ MM and the South American WW at a
  South American station, UBA at a Belgian one, SAC at a Scandinavian one,
  the All Asian at an Asian one, OK DX at a Czech one, YB DX at an Indonesian
  one (plan S0c, "NOT covered"). So this unit freezes, as LITERALS, the key
  each of the 32 prefix contests gives for a fixed set of QSOs at a fixed
  roster of stations, including those.

  HOW THE LITERALS WERE MADE. Written by hand from the old case, then RUN
  GREEN AGAINST THE OLD CODE before anything moved: the program's own case,
  lifted verbatim into a leaf for that one run, selected by the session kind
  uTestContestKindPin.Kinds resolves (the trait, then DescribeSession) --
  exactly what LOGEDIT.SetPrefix selected. Then the move, and the same table
  green against the classes.

  AND A CROSS-CHECK FOR EVERY CONTEST, NOT ONLY THE 32 -- part 1's, GONE.
  Until M11 S3 part 2, Test_EveryContestAgreesWithItsSessionKind compared
  every ContestType at every roster station for every QSO with the old case,
  frozen here, selected by the session's prefix kind. Part 2 deleted that
  kind, and the cross-check and its frozen case went with it (git history at
  cbcba524 holds both). The literals stay: they are the permanent oracle.

  WHETHER A CONTEST HAS A PREFIX MULTIPLIER AT ALL -- part 2's question,
  which replaced the kind (TContestBase.HasPrefixMultiplier). Pinned by
  Test_EveryContestHasItsPinnedPrefixMultiplier, for every ContestType at
  every roster station, against HAS_PREFIX below. Its us, ve and dx sets
  are the frozen kind pin's prefix column read as "not NoPrefixMults"
  (uTestContestKindPin, made from the program at S0b), taken before that
  column was deleted; the other six stations' sets are each station-
  dependent contest's DescribeSession test as it stood at cbcba524, by hand.
  And THE INVARIANT the engine relies on: no contest gives a key where it
  says it has no prefix multiplier -- checked for every contest, station
  and QSO.

  "NONE" IS NOT ''. Several arms assign only on a match (Belgium, the
  continent filters, Mongolia, the Gagarin stations) and otherwise LEAVE THE
  QSO'S PREFIX AS IT WAS; others always assign, possibly '' (SAC, WAE, YB).
  The rescore runs SetPrefix over a stored record, so the difference is
  observable, and the table says which: Assigns False means "no key", True
  with '' means "the key is empty".

  NEVER REGENERATE IT TO CLEAR A FAILURE -- the uTestContestKindPin rule. A
  failure means a contest's prefix rule changed. *)
unit uTestPrefixMultiplierKey;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TPrefixMultiplierKeyTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EveryPrefixContestGivesItsPinnedKey;
      procedure Test_EveryContestHasItsPinnedPrefixMultiplier;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uTestContestKindPin,
   (* ContestsToWalk -- the invariant walks the registry (Q108 S1). *)
   uTestRegisteredContests;

type
   (* The entrants. us, ve and dx are the matrix's; the rest take the
      DescribeSession branches the matrix never reaches. *)
   TPinStation = (psUS, psVE, psDX, psPY, psON, psSM, psJA, psOK, psYB);

   (* The worked stations: the CTY facts a logged QSO carries, typed in
      rather than looked up, so CTY.DAT cannot move a row. *)
   TPinQso = (pqW1AW, pqON4, pqPY2, pqSM5, pqOH0, pqJT1, pqYB1, pqUA9,
              pqRK1G, pqKL7, pqWB9ABCD);

   TStationRow = record
      Call: string;
      Country: string;
      Continent: ContinentType;
   end;

   TQsoRow = record
      Call: string;
      CountryID: string;
      Prefix: string;
      Continent: ContinentType;
   end;

   TKeyPin = record
      Contest: ContestType;
      Station: TPinStation;
      Qso: TPinQso;
      Assigns: boolean;
      Key: string;
   end;

const
   STATIONS: array[TPinStation] of TStationRow = (
      (Call: 'K0AAA';  Country: 'K';  Continent: NorthAmerica),
      (Call: 'VE3AAA'; Country: 'VE'; Continent: NorthAmerica),
      (Call: 'DL1AAA'; Country: 'DL'; Continent: Europe),
      (Call: 'PY1AAA'; Country: 'PY'; Continent: SouthAmerica),
      (Call: 'ON4AAA'; Country: 'ON'; Continent: Europe),
      (Call: 'SM5AAA'; Country: 'SM'; Continent: Europe),
      (Call: 'JA1AAA'; Country: 'JA'; Continent: Asia),
      (Call: 'OK1AAA'; Country: 'OK'; Continent: Europe),
      (Call: 'YB1AAA'; Country: 'YB'; Continent: Oceania)
   );

   QSOS: array[TPinQso] of TQsoRow = (
      (Call: 'W1AW';    CountryID: 'K';   Prefix: 'W1';  Continent: NorthAmerica),
      (Call: 'ON4ABC';  CountryID: 'ON';  Prefix: 'ON4'; Continent: Europe),
      (Call: 'PY2ABC';  CountryID: 'PY';  Prefix: 'PY2'; Continent: SouthAmerica),
      (Call: 'SM5ABC';  CountryID: 'SM';  Prefix: 'SM5'; Continent: Europe),
      (Call: 'OH0ABC';  CountryID: 'OH0'; Prefix: 'OH0'; Continent: Europe),
      (Call: 'JT1ABC';  CountryID: 'JT';  Prefix: 'JT1'; Continent: Asia),
      (Call: 'YB1ABC';  CountryID: 'YB';  Prefix: 'YB1'; Continent: Oceania),
      (Call: 'UA9ABC';  CountryID: 'UA9'; Prefix: 'UA9'; Continent: Asia),
      (Call: 'RK1G';    CountryID: 'UA';  Prefix: 'RK1'; Continent: Europe),
      (Call: 'KL7ABC';  CountryID: 'KL';  Prefix: 'KL7'; Continent: NorthAmerica),
      (* Seven characters: the callsign key is cut to the field's six. *)
      (Call: 'WB9ABCD'; CountryID: 'K';   Prefix: 'WB9'; Continent: NorthAmerica)
   );

   (* WRITTEN BY HAND FROM THE OLD CASE AND RUN GREEN AGAINST IT -- see the
      unit header. Every one of the 32 prefix contests appears, and every
      station branch its rule has. *)
   KEY_PINS: array[0..78] of TKeyPin = (
      (* THE CTY PREFIX, AT EVERY STATION -- the old `Prefix` arm. *)
      (Contest: APSPRINT;       Station: psUS; Qso: pqW1AW; Assigns: True; Key: 'W1'),
      (Contest: APSPRINT;       Station: psJA; Qso: pqON4;  Assigns: True; Key: 'ON4'),
      (Contest: BATAVIA_FT8;    Station: psYB; Qso: pqW1AW; Assigns: True; Key: 'W1'),
      (Contest: CQWPXCW;        Station: psUS; Qso: pqW1AW; Assigns: True; Key: 'W1'),
      (Contest: CQWPXCW;        Station: psPY; Qso: pqUA9;  Assigns: True; Key: 'UA9'),
      (Contest: CQWPXSSB;       Station: psDX; Qso: pqRK1G; Assigns: True; Key: 'RK1'),
      (Contest: CQWPXRTTY;      Station: psVE; Qso: pqKL7;  Assigns: True; Key: 'KL7'),
      (Contest: DARCXMAS;       Station: psDX; Qso: pqPY2;  Assigns: True; Key: 'PY2'),
      (Contest: OCEANIADXCW;    Station: psUS; Qso: pqYB1;  Assigns: True; Key: 'YB1'),
      (Contest: OCEANIADXSSB;   Station: psYB; Qso: pqW1AW; Assigns: True; Key: 'W1'),
      (Contest: PCC;            Station: psUS; Qso: pqJT1;  Assigns: True; Key: 'JT1'),
      (Contest: UCG;            Station: psDX; Qso: pqSM5;  Assigns: True; Key: 'SM5'),

      (* THE CALLSIGN, AT EVERY STATION -- the old `CallSignPrefix` arm, cut
         to the six characters the field holds. *)
      (Contest: CWOPEN;         Station: psUS; Qso: pqW1AW;    Assigns: True; Key: 'W1AW'),
      (Contest: CWOPEN;         Station: psUS; Qso: pqWB9ABCD; Assigns: True; Key: 'WB9ABC'),
      (Contest: CWOPS;          Station: psDX; Qso: pqRK1G;    Assigns: True; Key: 'RK1G'),
      (Contest: MINI80;         Station: psVE; Qso: pqON4;     Assigns: True; Key: 'ON4ABC'),
      (Contest: MINI40;         Station: psVE; Qso: pqWB9ABCD; Assigns: True; Key: 'WB9ABC'),
      (Contest: MINITEST;       Station: psUS; Qso: pqJT1;     Assigns: True; Key: 'JT1ABC'),
      (Contest: MST;            Station: psUS; Qso: pqKL7;     Assigns: True; Key: 'KL7ABC'),
      (Contest: CUPURAL;        Station: psDX; Qso: pqUA9;     Assigns: True; Key: 'UA9ABC'),

      (* MONGOLIA: a JT station's callsign, and nothing else. *)
      (Contest: JTDX;           Station: psUS; Qso: pqJT1;  Assigns: True;  Key: 'JT1ABC'),
      (Contest: JTDX;           Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),

      (* THE GAGARIN CUP: the six memorial stations' callsigns. *)
      (Contest: GAGARINCUP;     Station: psDX; Qso: pqRK1G; Assigns: True;  Key: 'RK1G'),
      (Contest: GAGARINCUP;     Station: psDX; Qso: pqUA9;  Assigns: False; Key: ''),

      (* SOUTH AMERICA ONLY. *)
      (Contest: SASPRINT;       Station: psUS; Qso: pqPY2;  Assigns: True;  Key: 'PY2'),
      (Contest: SASPRINT;       Station: psPY; Qso: pqW1AW; Assigns: False; Key: ''),

      (* YB DX: the WPX prefix if either end is Indonesian, else an EMPTY key. *)
      (Contest: YBDX;           Station: psUS; Qso: pqYB1;  Assigns: True;  Key: 'YB1'),
      (Contest: YBDX;           Station: psUS; Qso: pqW1AW; Assigns: True;  Key: ''),
      (Contest: YBDX;           Station: psYB; Qso: pqW1AW; Assigns: True;  Key: 'W1'),
      (Contest: YBDX;           Station: psYB; Qso: pqRK1G; Assigns: True;  Key: 'RK1'),

      (* UBA: Belgian prefixes, for an entrant outside Belgium; none in it. *)
      (Contest: UBACW;          Station: psUS; Qso: pqON4;  Assigns: True;  Key: 'ON4'),
      (Contest: UBACW;          Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: UBACW;          Station: psDX; Qso: pqON4;  Assigns: True;  Key: 'ON4'),
      (Contest: UBACW;          Station: psON; Qso: pqON4;  Assigns: False; Key: ''),
      (Contest: UBASSB;         Station: psVE; Qso: pqON4;  Assigns: True;  Key: 'ON4'),
      (Contest: UBASSB;         Station: psON; Qso: pqON4;  Assigns: False; Key: ''),
      (Contest: UBASSB;         Station: psON; Qso: pqW1AW; Assigns: False; Key: ''),

      (* CQ MM: South America from outside it; the Americas from inside. *)
      (Contest: CQMM;           Station: psUS; Qso: pqPY2;  Assigns: True;  Key: 'PY2'),
      (Contest: CQMM;           Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: CQMM;           Station: psDX; Qso: pqPY2;  Assigns: True;  Key: 'PY2'),
      (Contest: CQMM;           Station: psPY; Qso: pqW1AW; Assigns: True;  Key: 'W1'),
      (Contest: CQMM;           Station: psPY; Qso: pqPY2;  Assigns: True;  Key: 'PY2'),
      (Contest: CQMM;           Station: psPY; Qso: pqON4;  Assigns: False; Key: ''),

      (* SOUTH AMERICAN WW: South America from outside; the rest from inside. *)
      (Contest: SOUTHAMERICANWW; Station: psUS; Qso: pqPY2;  Assigns: True;  Key: 'PY2'),
      (Contest: SOUTHAMERICANWW; Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: SOUTHAMERICANWW; Station: psPY; Qso: pqW1AW; Assigns: True;  Key: 'W1'),
      (Contest: SOUTHAMERICANWW; Station: psPY; Qso: pqON4;  Assigns: True;  Key: 'ON4'),
      (Contest: SOUTHAMERICANWW; Station: psPY; Qso: pqPY2;  Assigns: False; Key: ''),

      (* ALL ASIAN: prefixes for an entrant outside Asia; none in it. *)
      (Contest: ALLASIANCW;     Station: psUS; Qso: pqJT1;  Assigns: True;  Key: 'JT1'),
      (Contest: ALLASIANCW;     Station: psJA; Qso: pqJT1;  Assigns: False; Key: ''),
      (Contest: ALLASIANSSB;    Station: psDX; Qso: pqUA9;  Assigns: True;  Key: 'UA9'),
      (Contest: ALLASIANSSB;    Station: psJA; Qso: pqW1AW; Assigns: False; Key: ''),

      (* OK DX: prefixes for a Czech or Slovak entrant only. *)
      (Contest: OKDX;           Station: psOK; Qso: pqW1AW; Assigns: True;  Key: 'W1'),
      (Contest: OKDX;           Station: psOK; Qso: pqRK1G; Assigns: True;  Key: 'RK1'),
      (Contest: OKDX;           Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: OKDX;           Station: psDX; Qso: pqW1AW; Assigns: False; Key: ''),

      (* WAE: a European entrant keys the rest of the world by country and
         call region (an EMPTY key for a European QSO); none outside Europe. *)
      (Contest: DARCWAEDCCW;    Station: psDX; Qso: pqW1AW; Assigns: True;  Key: 'K1'),
      (Contest: DARCWAEDCCW;    Station: psDX; Qso: pqUA9;  Assigns: True;  Key: 'UA99'),
      (Contest: DARCWAEDCCW;    Station: psDX; Qso: pqKL7;  Assigns: True;  Key: 'KL'),
      (Contest: DARCWAEDCCW;    Station: psDX; Qso: pqPY2;  Assigns: True;  Key: 'PY2'),
      (Contest: DARCWAEDCCW;    Station: psDX; Qso: pqSM5;  Assigns: True;  Key: ''),
      (Contest: DARCWAEDCCW;    Station: psSM; Qso: pqWB9ABCD; Assigns: True; Key: 'K9'),
      (Contest: DARCWAEDCCW;    Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: DARCWAEDCSSB;   Station: psON; Qso: pqJT1;  Assigns: True;  Key: 'JT'),
      (Contest: DARCWAEDCSSB;   Station: psDX; Qso: pqYB1;  Assigns: True;  Key: 'YB'),
      (Contest: DARCWAEDCSSB;   Station: psJA; Qso: pqW1AW; Assigns: False; Key: ''),

      (* SAC: the Scandinavian district for an entrant outside Scandinavia
         (OH0 its own; an EMPTY key for anyone else); none inside it. *)
      (Contest: SACCW;          Station: psUS; Qso: pqSM5;  Assigns: True;  Key: 'SM5'),
      (Contest: SACCW;          Station: psUS; Qso: pqOH0;  Assigns: True;  Key: 'OH0'),
      (Contest: SACCW;          Station: psUS; Qso: pqW1AW; Assigns: True;  Key: ''),
      (Contest: SACCW;          Station: psSM; Qso: pqSM5;  Assigns: False; Key: ''),
      (Contest: SACSSB;         Station: psDX; Qso: pqSM5;  Assigns: True;  Key: 'SM5'),
      (Contest: SACSSB;         Station: psSM; Qso: pqOH0;  Assigns: False; Key: ''),

      (* NO PREFIX RULE AT ALL -- a contest the move must not give one, and
         the classless DUMMYCONTEST. *)
      (Contest: CQWWCW;         Station: psDX; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: CQWWCW;         Station: psPY; Qso: pqON4;  Assigns: False; Key: ''),
      (Contest: ARRLDXCW;       Station: psUS; Qso: pqON4;  Assigns: False; Key: ''),
      (Contest: IARU;           Station: psJA; Qso: pqJT1;  Assigns: False; Key: ''),
      (Contest: NAQSOCW;        Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: DUMMYCONTEST;   Station: psUS; Qso: pqW1AW; Assigns: False; Key: ''),
      (Contest: RDA;            Station: psDX; Qso: pqRK1G; Assigns: False; Key: '')
   );

type
   TContestSet = set of ContestType;

const
   (* A PREFIX MULTIPLIER AT EVERY STATION: the 23 contests whose session ran
      a prefix kind wherever it ran. *)
   PREFIX_EVERYWHERE = [APSPRINT, BATAVIA_FT8, CQWPXCW, CQWPXSSB, CQWPXRTTY,
                        DARCXMAS, OCEANIADXCW, OCEANIADXSSB, PCC, UCG,
                        CWOPEN, CWOPS, MINI40, MINI80, MINITEST, MST, CUPURAL,
                        JTDX, GAGARINCUP, SASPRINT, YBDX, CQMM, SOUTHAMERICANWW];

   (* WHO HAS A PREFIX MULTIPLIER AT EACH ROSTER STATION -- see the unit
      header for where each set comes from. The other nine prefix contests
      decide by the entrant: UBA (not in Belgium), the All Asian (not in
      Asia), OK DX (in OK/OM only), WAE (in Europe only), SAC (not in
      Scandinavia). NEVER REGENERATE A SET TO CLEAR A FAILURE. *)
   HAS_PREFIX: array[TPinStation] of TContestSet = (
      (* psUS K0AAA *)  PREFIX_EVERYWHERE + [UBACW, UBASSB, ALLASIANCW, ALLASIANSSB, SACCW, SACSSB],
      (* psVE VE3AAA *) PREFIX_EVERYWHERE + [UBACW, UBASSB, ALLASIANCW, ALLASIANSSB, SACCW, SACSSB],
      (* psDX DL1AAA *) PREFIX_EVERYWHERE + [UBACW, UBASSB, ALLASIANCW, ALLASIANSSB, DARCWAEDCCW,
                                             DARCWAEDCSSB, SACCW, SACSSB],
      (* psPY PY1AAA *) PREFIX_EVERYWHERE + [UBACW, UBASSB, ALLASIANCW, ALLASIANSSB, SACCW, SACSSB],
      (* psON ON4AAA *) PREFIX_EVERYWHERE + [ALLASIANCW, ALLASIANSSB, DARCWAEDCCW, DARCWAEDCSSB,
                                             SACCW, SACSSB],
      (* psSM SM5AAA *) PREFIX_EVERYWHERE + [UBACW, UBASSB, ALLASIANCW, ALLASIANSSB, DARCWAEDCCW,
                                             DARCWAEDCSSB],
      (* psJA JA1AAA *) PREFIX_EVERYWHERE + [UBACW, UBASSB, SACCW, SACSSB],
      (* psOK OK1AAA *) PREFIX_EVERYWHERE + [UBACW, UBASSB, ALLASIANCW, ALLASIANSSB, OKDX,
                                             DARCWAEDCCW, DARCWAEDCSSB, SACCW, SACSSB],
      (* psYB YB1AAA *) PREFIX_EVERYWHERE + [UBACW, UBASSB, ALLASIANCW, ALLASIANSSB, SACCW, SACSSB]
   );

(* THE CONTESTS WITH A PREFIX MULTIPLIER AT SOME ROSTER STATION -- the union
   of the HAS_PREFIX sets, so it is never typed a second time. *)
function PrefixSomewhere: TContestSet;
var
   s: TPinStation;
begin
   Result := [];
   for s := Low(TPinStation) to High(TPinStation) do
      begin
      Result := Result + HAS_PREFIX[s];
      end;
end;

(* The handle form is the registry walk's: a contest registered by its id
  gets its own session name (issue #96). *)
function PinStation(aStation: TPinStation; aContest: TContestHandle): TStationContext; overload;
begin
   Result := MatrixStation(STATIONS[aStation].Call, STATIONS[aStation].Country,
                           STATIONS[aStation].Continent, '', 'DX', '',
                           False, SessionContestName(aContest, False));
end;

function PinStation(aStation: TPinStation; aContest: ContestType): TStationContext; overload;
begin
   Result := PinStation(aStation, ContestHandleOf(aContest));
end;

function PinQso(aQso: TPinQso): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.Callsign := CallString(QSOS[aQso].Call);
   Result.QTH.CountryID := DXMultiplierString(QSOS[aQso].CountryID);
   Result.QTH.Prefix := PrefixMultiplierString(QSOS[aQso].Prefix);
   Result.QTH.Continent := QSOS[aQso].Continent;
   Result.QTH.StandardCall := CallString(QSOS[aQso].Call);
end;

(* THE KEY THE PROGRAM GIVES -- what LOGEDIT.SetPrefix asks since the move:
   the contest's own rule, on a contest object holding the station, as
   ActiveContest hands it. nil (the classless DUMMYCONTEST) answers as
   ContestPrefixMultiplierKey answers nil. Before the move this function
   returned LegacyPrefixKeyOfKind(Kinds(...).PrefixMult, ...) through the
   program's own copy of the case -- the run that made the literals; the
   case is deleted (M11 S3 part 2). *)
function ProgramKey(aContest: ContestType;
                    const aStation: TStationContext;
                    const aQso: ContestExchange;
                    out aKey: PrefixMultiplierString): boolean;
var
   cls: TContestClass;
   obj: TContestBase;
begin
   obj := nil;
   cls := ContestClassFor(aContest);
   if cls <> nil then
      begin
      obj := cls.Create(ContestHandleOf(aContest));
      end;
   try
      if obj <> nil then
         begin
         obj.SetStation(aStation);
         end;
      Result := ContestPrefixMultiplierKey(obj, aQso, aKey);
   finally
      obj.Free;
      end;
end;

(* WHETHER THE PROGRAM SAYS THE CONTEST HAS A PREFIX MULTIPLIER -- what
   LOGEDIT.DoingPrefixMults asks since M11 S3 part 2, on an object holding
   the station, as ActiveContest hands it. *)
function ProgramHas(aContest: ContestType; const aStation: TStationContext): boolean;
var
   cls: TContestClass;
   obj: TContestBase;
begin
   obj := nil;
   cls := ContestClassFor(aContest);
   if cls <> nil then
      begin
      obj := cls.Create(ContestHandleOf(aContest));
      end;
   try
      if obj <> nil then
         begin
         obj.SetStation(aStation);
         end;
      Result := ContestHasPrefixMultiplier(obj);
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

procedure TPrefixMultiplierKeyTests.RunAllTests;
begin
   Test_EveryPrefixContestGivesItsPinnedKey;
   Test_EveryContestHasItsPinnedPrefixMultiplier;
end;

procedure TPrefixMultiplierKeyTests.Test_EveryPrefixContestGivesItsPinnedKey;
var
   i: integer;
   pin: TKeyPin;
   station: TStationContext;
   key: PrefixMultiplierString;
   assigns: boolean;
   who: string;
   named: set of ContestType;
   c: ContestType;
begin
   BeginTest('Test_EveryPrefixContestGivesItsPinnedKey');
   named := [];
   for i := Low(KEY_PINS) to High(KEY_PINS) do
      begin
      pin := KEY_PINS[i];
      station := PinStation(pin.Station, pin.Contest);
      assigns := ProgramKey(pin.Contest, station, PinQso(pin.Qso), key);
      who := string(ContestTypeSA[pin.Contest]) + ' at ' + STATIONS[pin.Station].Call +
             ' working ' + QSOS[pin.Qso].Call;
      CheckEquals(Answer(pin.Assigns, pin.Key), Answer(assigns, string(key)), who);
      if pin.Assigns then
         begin
         Include(named, pin.Contest);
         end;
      end;

   (* EVERY PREFIX CONTEST HAS A ROW THAT GIVES A KEY, AND NOTHING ELSE DOES
      -- contest by contest, against the HAS_PREFIX sets. This is what the
      hand-kept count of keyed contests (32, plan 1.1) stood for until Q108
      S1 deleted it. *)
   for c := Low(ContestType) to High(ContestType) do
      begin
      CheckTrue((c in named) = (c in PrefixSomewhere),
                string(ContestTypeSA[c]) + ': a key row exactly where there is a prefix multiplier');
      end;
end;

procedure TPrefixMultiplierKeyTests.Test_EveryContestHasItsPinnedPrefixMultiplier;
var
   c: ContestType;
   s: TPinStation;
   q: TPinQso;
   key: PrefixMultiplierString;
   checked: integer;
   contests: TContestIdentityList;
   k: integer;
   obj: TContestBase;
begin
   BeginTest('Test_EveryContestHasItsPinnedPrefixMultiplier');
   (* THE LEGACY CONTESTS, FROZEN: HAS_PREFIX at every roster station. The
      per-station counts (HAS_PREFIX_COUNT) and the count of contests with
      one somewhere are deleted (Q108 S1): each restated the set beside it,
      and a set edited by mistake fails here by name. *)
   checked := 0;
   for s := Low(TPinStation) to High(TPinStation) do
      begin
      for c := Low(ContestType) to High(ContestType) do
         begin
         CheckTrue(ProgramHas(c, PinStation(s, c)) = (c in HAS_PREFIX[s]),
                   string(ContestTypeSA[c]) + ' at ' + STATIONS[s].Call + ' has a prefix multiplier');
         Inc(checked);
         end;
      end;
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1), checked,
               'contest x station answers compared');

   (* THE INVARIANT, FOR EVERY REGISTERED CONTEST (Q108 S1): a key only where
      there is a prefix multiplier. *)
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         obj := NewContestLike(contests[k], PinStation(s, HandleOf(contests[k])));
         try
            if not ContestHasPrefixMultiplier(obj) then
               begin
               for q := Low(TPinQso) to High(TPinQso) do
                  begin
                  CheckFalse(ContestPrefixMultiplierKey(obj, PinQso(q), key),
                             ContestWho(obj) + ' at ' + STATIONS[s].Call +
                             ' gives no key working ' + QSOS[q].Call);
                  end;
               end;
         finally
            obj.Free;
            end;
         end;
      end;
end;

end.
