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

  AND A CROSS-CHECK FOR EVERY CONTEST, NOT ONLY THE 32.
  Test_EveryContestAgreesWithItsSessionKind asks every ContestType at every
  roster station for every QSO, and compares the class's answer with
  LegacyPrefixKeyOfKind below -- the old case, FROZEN HERE, selected by the
  kind the session resolves to. So the move is pinned in both directions:
  no prefix contest lost a branch, and no other contest gained a key. It
  holds only while the session still carries PrefixMult; S3 part 2 deletes
  that kind, and this test and the frozen case go with it, leaving the
  literals.

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
      procedure Test_EveryContestAgreesWithItsSessionKind;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uPrefixMultiplierKey,
   uTestContestKindPin;

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

function PinStation(aStation: TPinStation; aContest: ContestType): TStationContext;
begin
   Result := MatrixStation(STATIONS[aStation].Call, STATIONS[aStation].Country,
                           STATIONS[aStation].Continent, '', 'DX', '',
                           False, SessionContestName(aContest, False));
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

(* THE OLD CASE, FROZEN -- LOGEDIT.SetPrefix's `case ContestSession.PrefixMult
   of` as it stood at 42a999c1, verbatim but for the out-parameter (an arm
   that assigned answers True; one that did not, False) and the entrant's
   country as a parameter (the arm read Settings.My.Country). The pins above
   ran green through the program's own copy of it before the move. It exists
   only as the reference for Test_EveryContestAgreesWithItsSessionKind, and
   goes when S3 part 2 deletes PrefixMultType. The dead arms (North
   American, Asian, Russian -- reach 0 since M11 S2) are kept, as they
   stood. *)
function LegacyPrefixKeyOfKind(aKind: PrefixMultType;
                               const RData: ContestExchange;
                               const aMyCountry: string;
                               out aKey: PrefixMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   case aKind of
      CQNonEuropeanCountriesAndWAECallRegions:
         begin
         aKey := EuropeanCountriesAndWAECallRegions(RData.QTH);
         Result := True;
         end;
      BelgiumPrefixes:
         begin
         if RData.QTH.CountryID = 'ON' then
            begin
            aKey := RData.QTH.Prefix;
            Result := True;
            end;
         end;
      SACDistricts:
         begin
         aKey := SACDistrict(RData.QTH);
         Result := True;
         end;
      IndonesianDistricts:
         begin
         aKey := IndonesianDistrict(RData.QTH, aMyCountry);
         Result := True;
         end;
      Prefix:
         begin
         aKey := RData.QTH.Prefix;
         Result := True;
         end;
      SouthAmericanPrefixes:
         begin
         if RData.QTH.Continent = SouthAmerica then
            begin
            aKey := RData.QTH.Prefix;
            Result := True;
            end;
         end;
      NorthAmericanPrefixes:
         begin
         if RData.QTH.Continent = NorthAmerica then
            begin
            aKey := RData.QTH.Prefix;
            Result := True;
            end;
         end;
      AsianPrefixes:
         begin
         if RData.QTH.Continent = Asia then
            begin
            aKey := RData.QTH.Prefix;
            Result := True;
            end;
         end;
      SouthAndNorthAmericanPrefixes:
         begin
         if RData.QTH.Continent in [NorthAmerica, SouthAmerica] then
            begin
            aKey := RData.QTH.Prefix;
            Result := True;
            end;
         end;
      NonSouthAmericanPrefixes:
         begin
         if RData.QTH.Continent <> SouthAmerica then
            begin
            aKey := RData.QTH.Prefix;
            Result := True;
            end;
         end;
      CallSignPrefix:
         begin
         aKey := RData.Callsign;
         Result := True;
         end;
      MongolianCallSignPrefix:
         begin
         if RData.QTH.CountryID = 'JT' then
            begin
            aKey := RData.Callsign;
            Result := True;
            end;
         end;
      RussianPrefixes:
         begin
         if RData.QTH.CountryID = 'UA' then
            begin
            aKey := RData.Callsign;
            Result := True;
            end;
         end;
      GCStation:
         begin
         if (RData.Callsign = 'RK1G') or (RData.Callsign = 'R3K')  or
            (RData.Callsign = 'RS3A') or (RData.Callsign = 'RT3F') or
            (RData.Callsign = 'UP7Z') or (RData.Callsign = 'UN/RA3VM') then
            begin
            aKey := RData.Callsign;
            Result := True;
            end;
         end;
   end;
end;

(* THE KEY THE PROGRAM GIVES -- what LOGEDIT.SetPrefix asks since the move:
   the contest's own rule, on a contest object holding the station, as
   ActiveContest hands it. nil (the classless DUMMYCONTEST) answers as
   ContestPrefixMultiplierKey answers nil. Before the move this function
   returned LegacyPrefixKeyOfKind(Kinds(...).PrefixMult, ...) through the
   program's own copy of the case -- the run that made the literals. *)
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
      obj := cls.Create(aContest);
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
   Test_EveryContestAgreesWithItsSessionKind;
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
   count: integer;
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

   (* EVERY PREFIX CONTEST HAS A ROW THAT GIVES A KEY -- 32, plan 1.1. *)
   count := 0;
   for i := Ord(Low(ContestType)) to Ord(High(ContestType)) do
      begin
      if ContestType(i) in named then
         begin
         Inc(count);
         end;
      end;
   CheckEquals(32, count, 'contests with a pinned key');
end;

procedure TPrefixMultiplierKeyTests.Test_EveryContestAgreesWithItsSessionKind;
var
   c: ContestType;
   s: TPinStation;
   q: TPinQso;
   station: TStationContext;
   kind: PrefixMultType;
   qso: ContestExchange;
   oldKey: PrefixMultiplierString;
   newKey: PrefixMultiplierString;
   oldAssigns: boolean;
   newAssigns: boolean;
   checked: integer;
   keyed: set of ContestType;
   count: integer;
begin
   BeginTest('Test_EveryContestAgreesWithItsSessionKind');
   checked := 0;
   keyed := [];
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         kind := Kinds(c, station).PrefixMult;
         for q := Low(TPinQso) to High(TPinQso) do
            begin
            qso := PinQso(q);
            oldAssigns := LegacyPrefixKeyOfKind(kind, qso, string(station.MyCountry), oldKey);
            newAssigns := ProgramKey(c, station, qso, newKey);
            CheckEquals(Answer(oldAssigns, string(oldKey)), Answer(newAssigns, string(newKey)),
                        string(ContestTypeSA[c]) + ' at ' + STATIONS[s].Call +
                        ' working ' + QSOS[q].Call);
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
               (Ord(High(TPinQso)) + 1), checked, 'contest x station x QSO answers compared');

   (* THE 32 PREFIX CONTESTS, AND NO OTHER, GIVE A KEY ANYWHERE ON THE
      ROSTER -- plan 1.1. *)
   count := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if c in keyed then
         begin
         Inc(count);
         end;
      end;
   CheckEquals(32, count, 'contests that give a prefix key at some roster station');
end;

end.
