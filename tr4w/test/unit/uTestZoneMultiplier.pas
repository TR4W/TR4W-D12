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

(* THE ZONE MULTIPLIER EVERY CONTEST STATES -- WHETHER IT HAS ONE, HOW MANY
  ZONES, WHICH ZONE LIST, AND WHETHER IT NUMBERS THEM FROM ZERO -- AT
  STATIONS THE CONTEST MATRIX DOES NOT RUN. M11 S5, 2026-10-14
  (docs/CONTEST_FACTORY_M11_PLAN.md S5); whether it has one since S5 part 2.

  WHY IT EXISTS. S5 moves the readers of the session's ZONE KIND that choose
  a RULE into the classes:
     LOGDUPE.SetUpRemainingMultiplierArrays' `case ZoneMult of` -- the zone
        count (MaxNumberOfZones);
     LOGEDIT.GetMultArray's `ZoneMult in [CQZones, ITUZones]`, LOGEDIT's ITU
        initial zone, POSTUNIT.ZoneSentForThisContest and the ADIF CQZ/ITUZ
        block -- which zone list the multiplier counts;
     LOGEDIT.ShowRemMultsInWindow's `ZoneMult = EUHFCYear` -- zero-based
        numbering.
  The matrix pins the count (zones.max: 40, 75, 100, 99 and 7) and the ADIF
  tag at us, ve and dx. It cannot see a JAPANESE entrant, whose JIDX session
  runs CQ zones (DescribeSession) where every other entrant's runs none. So
  this unit freezes, as LITERALS, what each contest answers at a fixed
  roster of stations, JA included.

  HOW THE LITERALS WERE MADE. Written by hand from the old code, then RUN
  GREEN AGAINST THE OLD CODE before anything moved: the Program* functions
  below returned the frozen legacy rule (Legacy...OfKind) selected by the
  session kind uTestContestKindPin.Kinds resolves -- the trait, then
  DescribeSession -- exactly what the engine selected. Then the move, and
  the same tables green against the classes.

  THE CROSS-CHECK IS GONE WITH THE KIND (S5 part 2). Before it,
  Test_EveryContestAgreesWithItsSessionKind compared every ContestType at
  every roster station with the frozen legacy rules (Legacy...OfKind) under
  the session kind; ZoneMultType is deleted, and the cross-check and the
  frozen rules went with it. The literals stay.

  WHETHER A CONTEST HAS A ZONE MULTIPLIER AT ALL (S5 part 2). The engine
  asked `kind <> NoZoneMults`; the contest answers HasZoneMultiplier now.
  Its expected value is the literal sets below -- the us/ve/dx members are
  the frozen kind pin's ZoneMult column before that column was removed
  (18 contests, the program's own S0b output), JIDX's JA row is its
  DescribeSession test -- and the INVARIANT that it is True exactly where
  the zone count is above 0 is asserted for every contest at every station.

  CROATIAN AND CW OPEN ARE PINNED ON PURPOSE (plan F5, open question Q95).
  The zone MULTIPLIER's list and the CTY lookup's ZONE MODE are two facts,
  and for these two contests they disagree today: the Croatian counts ITU
  zones over a CQ zone mode (so a W1AW contact, CQ zone 5, exports
  <ITUZ:2>05), and CW Open counts CQ zones over an ITU zone mode. S5
  transcribes that exactly; Test_CroatianAndCWOpenKeepTheirTwoZoneSystems
  Apart pins both facts for both contests, so whatever Q95 decides is a
  deliberate, visible change to this file and not a side effect of folding
  one fact into the other.

  THE TRMASTER INITIAL ZONE. Which zone a call-history entry offers is
  pinned on its own -- uContestBase.InitialZoneFromCallHistory -- with the
  list ContestIdentity's contest counts. LOGEDIT asks the ACTIVE contest
  since S5 part 2 (plan F22 is fixed); Test_TheITUQuestionDependsOnNoStation
  holds that the two give the same answer, so these pins are LOGEDIT's.

  NEVER REGENERATE IT TO CLEAR A FAILURE -- the uTestContestKindPin rule. A
  failure means a contest's zone rule changed. *)
unit uTestZoneMultiplier;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TZoneMultiplierTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EveryZoneContestGivesItsPinnedAnswers;
      procedure Test_EveryContestHasItsPinnedZoneMultiplier;
      procedure Test_CroatianAndCWOpenKeepTheirTwoZoneSystemsApart;
      procedure Test_CallHistoryOffersTheZoneOfTheContestsList;
      procedure Test_TheITUQuestionDependsOnNoStation;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uTestContestObjects,
   uTestContestKindPin,
   (* ContestsToWalk -- the invariant walks the registry (Q108 S1). *)
   uTestRegisteredContests;

type
   (* The entrants. us, ve and dx are the matrix's; host is a New England
      station inside its state party's host state; JA takes JIDX's
      DescribeSession branch, which the matrix never reaches; 9A and UA are
      the home stations of the Croatian and the Russian zone contests. *)
   TPinStation = (psUS, psVE, psDX, psHost, psJA, ps9A, psUA);

   TStationRow = record
      Call: string;
      Country: string;
      Continent: ContinentType;
      State: string;
      InHostState: boolean;
   end;

   (* One contest at one station: its zone count, its zone list -- 'CQ',
      'ITU', or 'none' for a contest with no zone multiplier or one it
      numbers itself -- and whether it numbers its zones from zero. *)
   TZonePin = record
      Contest: ContestType;
      Station: TPinStation;
      Count: integer;
      Zones: string;
      FromZero: boolean;
   end;

   (* A call-history entry's two zone fields, and the zone the contest is
      offered from them -- see HISTORY_PINS. *)
   THistoryPin = record
      Contest: ContestType;
      CQZone: string;
      ITUZone: string;
      Offers: boolean;
      Offered: string;
   end;

const
   STATIONS: array[TPinStation] of TStationRow = (
      (Call: 'K0AAA';  Country: 'K';  Continent: NorthAmerica; State: 'KS'; InHostState: False),
      (Call: 'VE3AAA'; Country: 'VE'; Continent: NorthAmerica; State: 'ON'; InHostState: False),
      (Call: 'DL1AAA'; Country: 'DL'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'K1AAA';  Country: 'K';  Continent: NorthAmerica; State: 'MA'; InHostState: True),
      (Call: 'JA1AAA'; Country: 'JA'; Continent: Asia;         State: '';   InHostState: False),
      (Call: '9A2AAA'; Country: '9A'; Continent: Europe;       State: '';   InHostState: False),
      (Call: 'UA3AAA'; Country: 'UA'; Continent: Europe;       State: '';   InHostState: False)
   );

   (* WRITTEN BY HAND FROM THE OLD CODE AND RUN GREEN AGAINST IT -- see the
      unit header. Every one of the 20 zone contests has a row, and JIDX has
      one on each side of its station test. *)
   ZONE_PINS: array[0..35] of TZonePin = (
      (* CQ ZONES, 40, AT EVERY STATION. *)
      (Contest: CQWWCW;            Station: psUS;   Count: 40;  Zones: 'CQ';   FromZero: False),
      (Contest: CQWWCW;            Station: psJA;   Count: 40;  Zones: 'CQ';   FromZero: False),
      (Contest: CQWWSSB;           Station: psVE;   Count: 40;  Zones: 'CQ';   FromZero: False),
      (Contest: CQWWRTTY;          Station: psDX;   Count: 40;  Zones: 'CQ';   FromZero: False),
      (Contest: CWOPEN;            Station: psUS;   Count: 40;  Zones: 'CQ';   FromZero: False),
      (Contest: GACWWWSACW;        Station: psDX;   Count: 40;  Zones: 'CQ';   FromZero: False),
      (Contest: WWIH;              Station: psHost; Count: 40;  Zones: 'CQ';   FromZero: False),

      (* CQ ZONES FOR A JAPANESE ENTRANT ONLY -- JIDX's DescribeSession. *)
      (Contest: JIDXCW;            Station: psJA;   Count: 40;  Zones: 'CQ';   FromZero: False),
      (Contest: JIDXCW;            Station: psUS;   Count: 0;   Zones: 'none'; FromZero: False),
      (Contest: JIDXCW;            Station: psDX;   Count: 0;   Zones: 'none'; FromZero: False),
      (Contest: JIDXSSB;           Station: psJA;   Count: 40;  Zones: 'CQ';   FromZero: False),
      (Contest: JIDXSSB;           Station: psVE;   Count: 0;   Zones: 'none'; FromZero: False),

      (* ITU ZONES, 75, AT EVERY STATION. *)
      (Contest: BSCI;              Station: psDX;   Count: 75;  Zones: 'ITU';  FromZero: False),
      (Contest: CROATIAN;          Station: ps9A;   Count: 75;  Zones: 'ITU';  FromZero: False),
      (Contest: CROATIAN;          Station: psUS;   Count: 75;  Zones: 'ITU';  FromZero: False),
      (Contest: GAGARINCUP;        Station: psUA;   Count: 75;  Zones: 'ITU';  FromZero: False),
      (Contest: IARU;              Station: psUS;   Count: 75;  Zones: 'ITU';  FromZero: False),
      (Contest: IARU;              Station: psJA;   Count: 75;  Zones: 'ITU';  FromZero: False),
      (Contest: LZDX;              Station: psDX;   Count: 75;  Zones: 'ITU';  FromZero: False),
      (Contest: OZCR_O;            Station: psUA;   Count: 75;  Zones: 'ITU';  FromZero: False),
      (Contest: OZCR_Z;            Station: psVE;   Count: 75;  Zones: 'ITU';  FromZero: False),

      (* THE YEAR LICENSED, 00 TO 99: a hundred zones, numbered from zero. *)
      (Contest: EUROPEANHFC;       Station: psDX;   Count: 100; Zones: 'none'; FromZero: True),
      (Contest: EUROPEANHFC;       Station: psUS;   Count: 100; Zones: 'none'; FromZero: True),
      (Contest: KVP;               Station: psDX;   Count: 100; Zones: 'none'; FromZero: True),

      (* THE NZART BRANCH, 1 TO 99. *)
      (Contest: NZFIELDDAY;        Station: psUS;   Count: 99;  Zones: 'none'; FromZero: False),
      (Contest: NZFIELDDAY;        Station: psDX;   Count: 99;  Zones: 'none'; FromZero: False),

      (* THE RF CHAMPIONSHIP'S SEVEN ZONES. *)
      (Contest: RFCHAMPIONSHIPCW;  Station: psUA;   Count: 7;   Zones: 'none'; FromZero: False),
      (Contest: RFCHAMPIONSHIPSSB; Station: psDX;   Count: 7;   Zones: 'none'; FromZero: False),

      (* NO ZONE MULTIPLIER -- contests the move must not give one, the All
         Asian at a Japanese station, a party in its host state, and the
         classless DUMMYCONTEST. *)
      (Contest: CQWPXCW;           Station: psUS;   Count: 0;   Zones: 'none'; FromZero: False),
      (Contest: ARRLDXCW;          Station: psUS;   Count: 0;   Zones: 'none'; FromZero: False),
      (Contest: ARRLSSCW;          Station: psVE;   Count: 0;   Zones: 'none'; FromZero: False),
      (Contest: ALLASIANCW;        Station: psJA;   Count: 0;   Zones: 'none'; FromZero: False),
      (Contest: CQ160CW;           Station: psDX;   Count: 0;   Zones: 'none'; FromZero: False),
      (Contest: NEWENGLANDQSO;     Station: psHost; Count: 0;   Zones: 'none'; FromZero: False),
      (Contest: RUSSIANDX;         Station: psUA;   Count: 0;   Zones: 'none'; FromZero: False),
      (Contest: DUMMYCONTEST;      Station: psUS;   Count: 0;   Zones: 'none'; FromZero: False)
   );

   (* THE CALL-HISTORY INITIAL ZONE -- LOGEDIT.InitialExchangeEntry's
      ZoneInitialExchange arm once CD.GetEntry has found the call, asked
      through InitialZoneFromCallHistory with the list ContestIdentity's
      contest counts (LOGEDIT asks the active contest; the answer is the
      same -- Test_TheITUQuestionDependsOnNoStation). The entry is the
      matrix fixture's JA1ABC, CQ zone 25 and
      ITU zone 45, and the two half-empty variants of it. Offered '' with
      Offers False means "CTY.DAT decides" -- the arm goes on to ctyGetZone in
      the CTY zone mode. *)
   HISTORY_PINS: array[0..11] of THistoryPin = (
      (* ITU-zone contests offer the ITU zone -- the Croatian whatever its CQ
         CTY zone mode (F5). *)
      (Contest: CROATIAN; CQZone: '25'; ITUZone: '45'; Offers: True;  Offered: '45'),
      (Contest: IARU;     CQZone: '25'; ITUZone: '45'; Offers: True;  Offered: '45'),
      (* ... and NOTHING when the entry has no ITU zone: no CQ fall-back. *)
      (Contest: CROATIAN; CQZone: '25'; ITUZone: '';   Offers: False; Offered: ''),
      (Contest: IARU;     CQZone: '25'; ITUZone: '';   Offers: False; Offered: ''),
      (* Every other contest offers the CQ zone -- IRTS and WRTC count no
         zone multiplier and run ITU CTY zone mode, and still take the CQ
         field; CQ WW and CW Open count CQ zones. *)
      (Contest: IRTS;     CQZone: '25'; ITUZone: '45'; Offers: True;  Offered: '25'),
      (Contest: WRTC;     CQZone: '25'; ITUZone: '45'; Offers: True;  Offered: '25'),
      (Contest: CQWWCW;   CQZone: '25'; ITUZone: '45'; Offers: True;  Offered: '25'),
      (Contest: CWOPEN;   CQZone: '25'; ITUZone: '45'; Offers: True;  Offered: '25'),
      (Contest: JIDXCW;   CQZone: '25'; ITUZone: '45'; Offers: True;  Offered: '25'),
      (* ... and nothing when the entry has no CQ zone: no ITU fall-back. *)
      (Contest: IRTS;     CQZone: '';   ITUZone: '45'; Offers: False; Offered: ''),
      (Contest: CQWWCW;   CQZone: '';   ITUZone: '45'; Offers: False; Offered: ''),
      (* The classless DUMMYCONTEST is not an ITU contest. *)
      (Contest: DUMMYCONTEST; CQZone: '25'; ITUZone: '45'; Offers: True; Offered: '25')
   );

   (* THE ZONE CONTESTS, AS SETS -- for every ContestType at every roster
      station. JIDX is in CQ_FOR_JA_ONLY and counts nothing elsewhere. Read
      from the frozen kind pin's ZoneMult column (us, ve, dx and us-host,
      the program's own S0b output) and JIDX's DescribeSession test. *)
   CQ_EVERYWHERE: set of ContestType = [CQWWCW, CQWWSSB, CQWWRTTY, CWOPEN,
                                        GACWWWSACW, WWIH];
   CQ_FOR_JA_ONLY: set of ContestType = [JIDXCW, JIDXSSB];
   ITU_EVERYWHERE: set of ContestType = [BSCI, CROATIAN, GAGARINCUP, IARU,
                                         LZDX, OZCR_O, OZCR_Z];
   YEAR_EVERYWHERE: set of ContestType = [EUROPEANHFC, KVP];
   BRANCH_EVERYWHERE: set of ContestType = [NZFIELDDAY];
   RF_EVERYWHERE: set of ContestType = [RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB];

(* The handle form is the registry walk's: a contest registered by its id
  gets its own session name (issue #96). *)
function PinStation(aStation: TPinStation; aContest: TContestHandle): TStationContext; overload;
begin
   Result := MatrixStation(STATIONS[aStation].Call, STATIONS[aStation].Country,
                           STATIONS[aStation].Continent, STATIONS[aStation].State,
                           'DX', '', STATIONS[aStation].InHostState,
                           SessionContestName(aContest, STATIONS[aStation].InHostState));
end;

function PinStation(aStation: TPinStation; aContest: ContestType): TStationContext; overload;
begin
   Result := PinStation(aStation, ContestHandleOf(aContest));
end;

(* The zone list as the literals spell it. *)
function ZonesText(aZones: TZoneMultiplierZones): string;
begin
   case aZones of
      zmzCQZones:
         begin
         Result := 'CQ';
         end;
      zmzITUZones:
         begin
         Result := 'ITU';
         end;
   else
      begin
      Result := 'none';
      end;
   end;
end;

(* WHAT THE PROGRAM GIVES -- what LOGDUPE, LOGEDIT and POSTUNIT ask since
   the move: the contest's own answer, on a contest object holding the
   station, as ActiveContest hands it. nil (the classless DUMMYCONTEST)
   answers as the Contest... wrappers answer nil. BEFORE THE MOVE each of
   these returned a frozen legacy rule selected by the session's zone
   kind -- the run that made the literals (deleted with the kind at S5
   part 2). *)
function ProgramHas(aContest: ContestType; const aStation: TStationContext): boolean;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      Result := ContestHasZoneMultiplier(obj);
   finally
      obj.Free;
      end;
end;

function ProgramCount(aContest: ContestType; const aStation: TStationContext): integer;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      Result := ContestZoneMultiplierCount(obj);
   finally
      obj.Free;
      end;
end;

function ProgramZones(aContest: ContestType; const aStation: TStationContext): string;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      Result := ZonesText(ContestZoneMultiplierZones(obj));
   finally
      obj.Free;
      end;
end;

function ProgramFromZero(aContest: ContestType; const aStation: TStationContext): boolean;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      Result := ContestNumbersZonesFromZero(obj);
   finally
      obj.Free;
      end;
end;

function Who(aContest: ContestType; aStation: TPinStation): string;
begin
   Result := string(ContestTypeSA[aContest]) + ' at ' + STATIONS[aStation].Call;
end;

procedure TZoneMultiplierTests.RunAllTests;
begin
   Test_EveryZoneContestGivesItsPinnedAnswers;
   Test_EveryContestHasItsPinnedZoneMultiplier;
   Test_CroatianAndCWOpenKeepTheirTwoZoneSystemsApart;
   Test_CallHistoryOffersTheZoneOfTheContestsList;
   Test_TheITUQuestionDependsOnNoStation;
end;

procedure TZoneMultiplierTests.Test_EveryZoneContestGivesItsPinnedAnswers;
var
   i: integer;
   pin: TZonePin;
   station: TStationContext;
   named: set of ContestType;
   c: ContestType;
begin
   BeginTest('Test_EveryZoneContestGivesItsPinnedAnswers');
   named := [];
   for i := Low(ZONE_PINS) to High(ZONE_PINS) do
      begin
      pin := ZONE_PINS[i];
      station := PinStation(pin.Station, pin.Contest);
      CheckEquals(pin.Count, ProgramCount(pin.Contest, station),
                  Who(pin.Contest, pin.Station) + ' zone count');
      CheckEquals(pin.Zones, ProgramZones(pin.Contest, station),
                  Who(pin.Contest, pin.Station) + ' zone list');
      CheckEquals(BoolToStr(pin.FromZero, True),
                  BoolToStr(ProgramFromZero(pin.Contest, station), True),
                  Who(pin.Contest, pin.Station) + ' numbered from zero');
      (* A ROW WITH ZONES HAS A ZONE MULTIPLIER; A ROW WITH NONE HAS NOT. *)
      CheckEquals(BoolToStr(pin.Count > 0, True),
                  BoolToStr(ProgramHas(pin.Contest, station), True),
                  Who(pin.Contest, pin.Station) + ' has a zone multiplier');
      if pin.Count > 0 then
         begin
         Include(named, pin.Contest);
         end;
      end;

   (* EVERY ZONE CONTEST HAS A ROW THAT COUNTS ZONES, AND NOTHING ELSE DOES
      -- contest by contest, against the literal sets. What the hand-kept
      count of them (20, plan S5) stood for until Q108 S1 deleted it. *)
   for c := Low(ContestType) to High(ContestType) do
      begin
      CheckTrue((c in named) = (c in CQ_EVERYWHERE + CQ_FOR_JA_ONLY + ITU_EVERYWHERE +
                                    YEAR_EVERYWHERE + BRANCH_EVERYWHERE + RF_EVERYWHERE),
                string(ContestTypeSA[c]) + ': a zone row exactly where it counts zones somewhere');
      end;
end;

procedure TZoneMultiplierTests.Test_EveryContestHasItsPinnedZoneMultiplier;
var
   c: ContestType;
   s: TPinStation;
   station: TStationContext;
   wantCount: integer;
   wantZones: string;
   checked: integer;
   contests: TContestIdentityList;
   k: integer;
   obj: TContestBase;
begin
   BeginTest('Test_EveryContestHasItsPinnedZoneMultiplier');
   (* THE LEGACY CONTESTS, FROZEN: the literal sets, at every roster station,
      contest by contest. The per-station counts of contests with a zone
      multiplier and the count of those that count zones anywhere are
      deleted (Q108 S1): each restated the sets above it, and a contest that
      gains or loses one fails here by name. *)
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         wantCount := 0;
         wantZones := 'none';
         if (c in CQ_EVERYWHERE) or
            ((c in CQ_FOR_JA_ONLY) and (s = psJA)) then
            begin
            wantCount := 40;
            wantZones := 'CQ';
            end
         else if c in ITU_EVERYWHERE then
            begin
            wantCount := 75;
            wantZones := 'ITU';
            end
         else if c in YEAR_EVERYWHERE then
            begin
            wantCount := 100;
            end
         else if c in BRANCH_EVERYWHERE then
            begin
            wantCount := 99;
            end
         else if c in RF_EVERYWHERE then
            begin
            wantCount := 7;
            end;

         CheckEquals(wantCount, ProgramCount(c, station), Who(c, s) + ' zone count');
         CheckEquals(wantZones, ProgramZones(c, station), Who(c, s) + ' zone list');
         CheckEquals(BoolToStr(c in YEAR_EVERYWHERE, True),
                     BoolToStr(ProgramFromZero(c, station), True),
                     Who(c, s) + ' numbered from zero');
         CheckEquals(BoolToStr(wantCount > 0, True), BoolToStr(ProgramHas(c, station), True),
                     Who(c, s) + ' has a zone multiplier');
         Inc(checked);
         end;
      end;
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1), checked,
               'contest x station zone answers compared');

   (* THE INVARIANT, FOR EVERY REGISTERED CONTEST AT EVERY ROSTER STATION
      (Q108 S1): it has a zone multiplier exactly where it counts zones, so
      the two statements a class makes cannot drift apart. *)
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         obj := NewContestLike(contests[k], PinStation(s, HandleOf(contests[k])));
         try
            CheckEquals(BoolToStr(ContestZoneMultiplierCount(obj) > 0, True),
                        BoolToStr(ContestHasZoneMultiplier(obj), True),
                        ContestWho(obj) + ' at ' + STATIONS[s].Call +
                        ' has a zone multiplier exactly where it counts zones');
         finally
            obj.Free;
            end;
         end;
      end;
end;

(* PLAN F5, OPEN QUESTION Q95 -- see the unit header. Two facts per contest,
   pinned side by side: the zone list the MULTIPLIER counts (the class's
   answer, which the sheet, the hint, the initial zone, the zone sent and the
   ADIF CQZ/ITUZ tag ask) and the CTY lookup's ZONE MODE (ZoneMode, from
   cfCQZoneMode, which decides which zone CTY.DAT gives a logged call). They
   disagree for these two contests and NOTHING here may reconcile them: a
   change to either line is the Q95 decision, made deliberately. *)
procedure TZoneMultiplierTests.Test_CroatianAndCWOpenKeepTheirTwoZoneSystemsApart;
var
   station: TStationContext;
begin
   BeginTest('Test_CroatianAndCWOpenKeepTheirTwoZoneSystemsApart');

   station := PinStation(psUS, CROATIAN);
   CheckEquals('ITU', ProgramZones(CROATIAN, station),
               'CROATIAN counts ITU zones (exports a CQ zone as ITUZ)');
   CheckEquals(Ord(CQZoneMode), Ord(ContestIdentity(CROATIAN).ZoneMode),
               'CROATIAN looks zones up in CQ zone mode');

   station := PinStation(psUS, CWOPEN);
   CheckEquals('CQ', ProgramZones(CWOPEN, station),
               'CWOPEN counts CQ zones (exports an ITU zone as CQZ)');
   CheckEquals(Ord(ITUZoneMode), Ord(ContestIdentity(CWOPEN).ZoneMode),
               'CWOPEN looks zones up in ITU zone mode');
end;

(* THE CALL-HISTORY INITIAL ZONE, PINNED OUTSIDE THE MATRIX -- see
   HISTORY_PINS. The matrix's initialexchange section reaches this branch
   (S0c's fixture), and since the F22 fix its JA1ABC line shows this rule
   in the ITU-zone contests; the rule is pinned here on its own as well,
   with the half-empty entries the fixture does not hold. *)
procedure TZoneMultiplierTests.Test_CallHistoryOffersTheZoneOfTheContestsList;
var
   i: integer;
   offered: ShortString;
   offers: boolean;
begin
   BeginTest('Test_CallHistoryOffersTheZoneOfTheContestsList');
   for i := Low(HISTORY_PINS) to High(HISTORY_PINS) do
      begin
      offers := InitialZoneFromCallHistory(
                   ContestZoneMultiplierZones(ContestIdentity(HISTORY_PINS[i].Contest)),
                   ShortString(HISTORY_PINS[i].CQZone),
                   ShortString(HISTORY_PINS[i].ITUZone),
                   offered);
      CheckEquals(BoolToStr(HISTORY_PINS[i].Offers, True), BoolToStr(offers, True),
                  string(ContestTypeSA[HISTORY_PINS[i].Contest]) + ' offers a zone');
      CheckEquals(HISTORY_PINS[i].Offered, string(offered),
                  string(ContestTypeSA[HISTORY_PINS[i].Contest]) + ' offered zone');
      end;
end;

(* THE ITU QUESTION DEPENDS ON NO ENTRANT -- checked for every contest at
   every roster station against the station-holding object. Until S5 part 2
   this was why LOGEDIT could ask ContestIdentity rather than the active
   contest (plan F22); LOGEDIT asks the active contest now that F22 is
   fixed, and this is why HISTORY_PINS, which ask ContestIdentity, still
   pin what LOGEDIT offers. A future contest whose ITU answer depends on
   the entrant fails this, and HISTORY_PINS must then name a station. *)
procedure TZoneMultiplierTests.Test_TheITUQuestionDependsOnNoStation;
var
   c: ContestType;
   s: TPinStation;
   identityITU: boolean;
begin
   BeginTest('Test_TheITUQuestionDependsOnNoStation');
   for c := Low(ContestType) to High(ContestType) do
      begin
      identityITU := ContestZoneMultiplierZones(ContestIdentity(c)) = zmzITUZones;
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         CheckEquals(BoolToStr(identityITU, True),
                     BoolToStr(ProgramZones(c, PinStation(s, c)) = 'ITU', True),
                     Who(c, s) + ' ITU zone list, identity versus station');
         end;
      end;
end;

end.
