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

(* THE RECEIVED-EXCHANGE FIELDS EVERY CONTEST STATES, AT EVERY ROSTER
  STATION -- M11 S9a, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S9a).

  WHY IT EXISTS. S9a moves the first exchange-shape machine,
  LOGDUPE.SetUpExchangeInformation (which fields of the received exchange a
  contest carries), into the classes: each states its field list
  (TContestBase.ReceivedExchangeFields) by calling a named helper
  (uExchangeFields). The contest matrix prints the list
  (`exchange.fields`), but only at its three stations -- none inside a
  party's host state, none Dutch, none Japanese, none in KH6 -- and ten
  contests choose their exchange by the station.

  HOW THE LITERALS WERE MADE. The us column of the frozen matrix, grouped by
  field set, and the station branches laid out by hand from each class's
  DescribeSession. RUN GREEN AGAINST THE OLD CODE before anything moved: the
  program's answer was then the machine, frozen here (LegacyFields), on the
  session shape uTestContestKindPin.Kinds resolves -- the trait, and
  DescribeSession over it -- exactly what start-up handed the machine. Then
  the move, and the same tables green against the classes.

  THE CROSS-CHECK STAYS UNTIL S9 DELETES THE SHAPE: every ContestType at
  every roster station, the class's answer against the frozen machine.

  NEVER REGENERATE IT TO CLEAR A FAILURE -- the uTestContestKindPin rule. A
  failure means a contest's received-exchange fields changed. *)
unit uTestExchangeFields;

{$I ..\..\src\tr4w.inc}

interface

uses
   VC,
   uContestBase,
   uTR4WTestFramework;

type
   (* The entrants. us, ve and dx are the matrix's (dx is German); host is a
      Massachusetts station inside its party's host state (and in New
      England); PA a Dutch station, the PACC's own; KH6 a station in an ARRL
      section country that is neither the USA nor Canada; JA a Japanese
      station, the JIDX's own. SHARED with uTestADIFSentExchange (M11 S9b), so
      the pins that walk the roster agree on who the roster is. *)
   TPinStation = (psUS, psVE, psDX, psHost, psPA, psKH6, psJA);

   TExchangeFieldsTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EveryContestStatesItsPinnedFields;
      procedure Test_FieldsAgreeWithTheSessionShape;
      procedure Test_EachHelperMarksItsFields;
   end;

(* The roster station, resolved the way the matrix resolves one, for aContest. *)
function PinStation(aStation: TPinStation; aContest: ContestType): TStationContext;

(* The roster station's call, for a failure message. *)
function PinStationCall(aStation: TPinStation): string;

implementation

uses
   SysUtils,
   uContestRegistry,
   uExchangeFields,
   uTestContestObjects,
   uTestContestKindPin;

type
   TStationRow = record
      Call: string;
      Country: string;
      Continent: ContinentType;
      State: string;
      InHostState: boolean;
   end;

const
   STATIONS: array[TPinStation] of TStationRow = (
      (Call: 'K0AAA';  Country: 'K';   Continent: NorthAmerica; State: 'KS'; InHostState: False),
      (Call: 'VE3AAA'; Country: 'VE';  Continent: NorthAmerica; State: 'ON'; InHostState: False),
      (Call: 'DL1AAA'; Country: 'DL';  Continent: Europe;       State: '';   InHostState: False),
      (Call: 'K1AAA';  Country: 'K';   Continent: NorthAmerica; State: 'MA'; InHostState: True),
      (Call: 'PA3AAA'; Country: 'PA';  Continent: Europe;       State: '';   InHostState: False),
      (Call: 'KH6AAA'; Country: 'KH6'; Continent: Oceania;      State: '';   InHostState: False),
      (Call: 'JA1AAA'; Country: 'JA';  Continent: Asia;         State: '';   InHostState: False)
   );

(* THE MACHINE, FROZEN -- LOGDUPE.SetUpExchangeInformation's `case` as it
   stood before S9a, arm for arm, its four unreached labels included. A
   shape with no arm marks nothing. *)
function LegacyFields(aShape: ExchangeType): ExchangeInformationRecord;
begin
   Result := Default(ExchangeInformationRecord);
   case aShape of
      CheckAndChapterOrQTHExchange:
         begin
         Result.Chapter := True;
         Result.Check := True;
         Result.QTH := True;
         end;
      ClassDomesticOrDXQTHExchange:
         begin
         Result.ClassEI := True;
         Result.QTH := True;
         end;
      KidsDayExchange:
         begin
         Result.Kids := True;
         end;
      RSTAndContinentExchange:
         begin
         Result.RST := True;
         Result.QTH := True;
         end;
      NameQTHAndPossibleTenTenNumber:
         begin
         Result.Name := True;
         Result.QTH := True;
         Result.TenTenNum := True;
         end;
      NameAndDomesticOrDXQTHExchange, NameAndPossibleGridSquareExchange:
         begin
         Result.Name := True;
         Result.QTH := True;
         end;
      NZFieldDayExchange:
         begin
         Result.RST := True;
         Result.QSONumber := True;
         Result.Zone := True;
         end;
      QSONumberAndCoordinatesSum, QSONumberAndGeoCoordinates:
         begin
         Result.QTH := True;
         Result.QSONumber := True;
         end;
      QSONumberAndPreviousQSONumber:
         begin
         Result.QSONumber := True;
         end;
      QSONumberAndZone:
         begin
         Result.Zone := True;
         Result.QSONumber := True;
         end;
      QSONumberAndNameExchange:
         begin
         Result.Name := True;
         Result.QSONumber := True;
         end;
      QSONumberAndGridSquare, QSONumberDomesticQTHExchange,
      QSONumberDomesticOrDXQTHExchange:
         begin
         Result.QSONumber := True;
         Result.QTH := True;
         end;
      QSONumberNameChapterAndQTHExchange:
         begin
         Result.QSONumber := True;
         Result.Name := True;
         Result.Chapter := True;
         Result.QTH := True;
         end;
      QSONumberNameDomesticOrDXQTHExchange:
         begin
         Result.QSONumber := True;
         Result.Name := True;
         Result.QTH := True;
         end;
      QSONumberPrecedenceCheckDomesticQTHExchange:
         begin
         Result.QSONumber := True;
         Result.Precedence := True;
         Result.Check := True;
         Result.QTH := True;
         end;
      AgeAndQSONumberExchange, QSONumberAndAgeExchange:
         begin
         Result.QSONumber := True;
         Result.Age := True;
         end;
      RSTAndPOTAPark:
         begin
         Result.RST := True;
         Result.QTH := True;
         end;
      RSTAgeAndPossibleSK:
         begin
         Result.RST := True;
         Result.Age := True;
         Result.QTH := True;
         end;
      RSTAgeExchange:
         begin
         Result.RST := True;
         Result.Age := True;
         end;
      RSTALLJAPrefectureAndPrecedenceExchange:
         begin
         Result.RST := True;
         Result.Precedence := True;
         Result.QTH := True;
         end;
      RSTPossibleDomesticQTHAndPower:
         begin
         Result.RST := True;
         Result.QTH := True;
         Result.Power := True;
         end;
      Grid2Exchange, RSTAndGrid3Exchange, GridExchange:
         begin
         Result.QTH := True;
         end;
      RSTAndOrGridExchange, RSTAndGridExchange, RSTAndPostalCodeExchange,
      RSTQTHExchange, RSTDomesticOrDXQTHExchange, RSTLongJAPrefectureExchange:
         begin
         Result.RST := True;
         Result.QTH := True;
         end;
      RSTDomesticQTHExchange, RSTPrefectureExchange,
      QSONumberAndPossibleDomesticQTHExchange, RSTDomesticQTHOrQSONumberExchange,
      RSTAndQSONumberOrFrenchDepartmentExchange, RSTQSONumberOrDomesticQTHExchange,
      RSTQSONumberAndPossibleDomesticQTHExchange, RSTQSONumberAndDomesticQTHExchange,
      RSTQSONumberAndGridSquareExchange, RSTAndQSONumberOrDomesticQTHExchange:
         begin
         Result.RST := True;
         Result.QTH := True;
         Result.QSONumber := True;
         end;
      RSTNameAndQTHExchange:
         begin
         Result.RST := True;
         Result.Name := True;
         Result.QTH := True;
         end;
      RSTAndFOCNumberExchange, RSTPowerExchange:
         begin
         Result.RST := True;
         Result.Power := True;
         end;
      RSTQSONumberExchange:
         begin
         Result.RST := True;
         Result.QSONumber := True;
         end;
      RSTQTHNameAndFistsNumberOrPowerExchange:
         begin
         Result.RST := True;
         Result.QTH := True;
         Result.Name := True;
         Result.Power := True;
         Result.QSONumber := True;
         end;
      RSTQSONumberAndRandomCharactersExchange:
         begin
         Result.RST := True;
         Result.RandomChars := True;
         Result.QSONumber := True;
         end;
      RSTZoneAndPossibleDomesticQTHExchange, RSTZoneOrSocietyExchange,
      RSTZoneOrDomesticQTH:
         begin
         Result.RST := True;
         Result.Zone := True;
         Result.QTH := True;
         end;
      RSTZoneExchange:
         begin
         Result.RST := True;
         Result.Zone := True;
         end;
   else
      begin
      (* No arm: UnknownExchange, NoExchangeReceived, RSTAndDOMESTICQTH,
         RSTAndSerialNumberAndGridandPossibleMemberNumber,
         RSTNameAndPossibleFOCNumber, RSTAndGridSquareOrRDAExchange. *)
      end;
   end;
end;

function PinStation(aStation: TPinStation; aContest: ContestType): TStationContext;
begin
   Result := MatrixStation(STATIONS[aStation].Call, STATIONS[aStation].Country,
                           STATIONS[aStation].Continent, STATIONS[aStation].State,
                           'DX', '', STATIONS[aStation].InHostState,
                           SessionContestName(aContest, STATIONS[aStation].InHostState));
end;

function PinStationCall(aStation: TPinStation): string;
begin
   Result := STATIONS[aStation].Call;
end;

function Who(aContest: ContestType; aStation: TPinStation): string;
begin
   Result := string(ContestTypeSA[aContest]) + ' at ' + STATIONS[aStation].Call;
end;

(* WHAT THE PROGRAM ANSWERS -- what start-up puts in LOGDUPE's
   ExchangeInformation: uProgramMain asks the open contest through the
   nil-safe ContestReceivedExchangeFields. BEFORE THE MOVE it returned the
   machine on the session shape Kinds resolves -- the run that made the
   literals. *)
function ProgramFields(aContest: ContestType;
                       const aStation: TStationContext): ExchangeInformationRecord;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      Result := ContestReceivedExchangeFields(obj);
   finally
      obj.Free;
      end;
end;

(* THE PINNED FIELD LIST: the frozen matrix's us column, grouped by field
   set, and the station branches -- each the test the contest's
   DescribeSession chooses its exchange by. *)
function PinnedFields(aContest: ContestType; aStation: TPinStation): string;
begin
   (* THE ARRL DX: a W or VE entrant sends power; anyone else a state. *)
   if aContest in [ARRLDXCW, ARRLDXSSB] then
      begin
      if aStation in [psUS, psVE, psHost] then
         begin
         Result := 'Power RST';
         end
      else
         begin
         Result := 'QSONumber QTH RST';
         end;
      Exit;
      end;

   (* ARRL 160: an entrant in an ARRL section country (W, VE, KH6) sends
      its section or takes DX; anyone else sends a domestic QTH. *)
   if aContest = ARRL160 then
      begin
      if aStation in [psDX, psPA, psJA] then
         begin
         Result := 'QSONumber QTH RST';
         end
      else
         begin
         Result := 'QTH RST';
         end;
      Exit;
      end;

   (* THE JIDX: a Japanese entrant receives a zone; anyone else a
      prefecture. *)
   if aContest in [JIDXCW, JIDXSSB] then
      begin
      if aStation = psJA then
         begin
         Result := 'RST Zone';
         end
      else
         begin
         Result := 'QSONumber QTH RST';
         end;
      Exit;
      end;

   (* FIVE PARTIES: inside the host state (New England, for NEQP) the
      domestic-or-DX exchange; outside it the domestic QTH. *)
   if aContest in [SEVENQP, ArizonaQsoParty, SALMONRUN, TEXASQSOPARTY,
                   NEWENGLANDQSO] then
      begin
      if aStation = psHost then
         begin
         Result := 'QTH RST';
         end
      else
         begin
         Result := 'QSONumber QTH RST';
         end;
      Exit;
      end;

   (* EVERY OTHER CONTEST, the same at every station. California and the
      PACC choose their exchange by the station too, but both of their
      shapes carry one field set. *)
   case aContest of
      ARI_DX, ARRL10, CIS, EUROPEANVHF, TESLA, HADX, YUDX, UKEI, HELVETIA,
      IOTA, MICHQSOPARTY, MOQSOPARTY, NCQSOPARTY, NRAUBALTICCW,
      NRAUBALTICSSB, OHIOQSOPARTY, OKDX, PACC, CANADA_WINTER, RADIOVHFFD,
      RDA, RSGB18, RUSSIANDX, SPDX, TOEC, UBACW, UBASSB, UKRAINIAN, DARCXMAS,
      WAG, WISCONSINQSOPARTY, YODX, RU3AXMEMORIAL, ARKTIKA_SPRING, UNDX,
      NYQP, KINGOFSPAINCW, KINGOFSPAINSSB, TENNESSEEQSOPARTY, PCC, DARC10M,
      REFCW, REFSSB, OZHCRVHF, CANADA_DAY, ARRL_RTTY_ROUNDUP, CQIR,
      ALRS_UA1DZ_CUP, INQSOPARTY, OKOMSSB, BCQP, IN7QPNE, RTC:
         begin
         Result := 'QSONumber QTH RST';
         end;
      APSPRINT, BALTIC, CQM, CQWPXCW, CQWPXSSB, CQWPXRTTY, MARCONIMEMORIAL,
      MINITEST, MINI80, MINI40, OCEANIADXCW, OCEANIADXSSB, REGION1FIELDDAY,
      REGION1FIELDDAY_RCC_CW, REGION1FIELDDAY_RCC_SSB, SACCW, YBDX, SACSSB,
      UCG, DARCWAEDCCW, DARCWAEDCSSB, SASPRINT, MWC:
         begin
         Result := 'QSONumber RST';
         end;
      ARRLVHFJAN, ARRLVHFJUN, ARRLVHFSEP, COUNTYHUNTER, CQVHF,
      FLORIDAQSOPARTY, JALONGPREFECT, LABRE, POTA, RSGB_ROPOCO_CW,
      RSGB_ROPOCO_SSB, SOUTHAMERICANWW, STEWPERRY, WWL, CQMM, IDAHOQSOPARTY,
      DELAWAREQSOPARTY, NEBRASKAQSO:
         begin
         Result := 'QTH RST';
         end;
      CQ160CW, CQ160SSB, CROATIAN, GAGARINCUP, IARU, KCJ, LZDX, OZCR_O,
      OZCR_Z, WWPMC, WRTC, BSCI, CQWWRTTY, IRTS, EUDX:
         begin
         Result := 'QTH RST Zone';
         end;
      CALQSOPARTY, CUPRFCW, CUPRFSSB, CUPRFDIG, CUPURAL, RAEM,
      RFASCHAMPIONSHIPCW, UKRAINECHAMPIONSHIP, PAQSOPARTY, VAQP:
         begin
         Result := 'QSONumber QTH';
         end;
      GRIDLOC, MINNQSOPARTY, NAQSOCW, NAQSOSSB, NAQSORTTY, LQP,
      COLORADOQSOPARTY, CWOPS, SST:
         begin
         Result := 'Name QTH';
         end;
      CQWWCW, CQWWSSB, EUROPEANHFC, GACWWWSACW, JTDX, KVP, WWIH:
         begin
         Result := 'RST Zone';
         end;
      EUSPRINT_SPRING_CW, CWOPEN, EUSPRINT_SPRING_SSB, EUSPRINT_AUTUMN_CW,
      EUSPRINT_AUTUMN_SSB, MST:
         begin
         Result := 'Name QSONumber';
         end;
      INTERNETSPRINT, NASPRINTCW, SPRINTSSB, NASPRINTRTTY, NCCCSPRINT:
         begin
         Result := 'Name QSONumber QTH';
         end;
      ARRLDIGI, MAKROTHEN, BATAVIA_FT8, WWDIGI:
         begin
         Result := 'QTH';
         end;
      ALLASIANCW, ALLASIANSSB, YOTA:
         begin
         Result := 'Age RST';
         end;
      RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB, R9W_UW9WK_MEMORIAL:
         begin
         Result := 'QSONumber Zone';
         end;
      QCWA, QCWAGOLDEN:
         begin
         Result := 'Chapter Name QSONumber QTH';
         end;
      ARRLSSCW, ARRLSSSSB:
         begin
         Result := 'Check Precedence QSONumber QTH';
         end;
      ARRLFIELDDAY, WINTERFIELDDAY:
         begin
         Result := 'ClassEI QTH';
         end;
      BWQP, GENERALQSO:
         begin
         Result := 'Name QTH RST';
         end;
      FOCMARATHON, OLDNEWYEAR:
         begin
         Result := 'Power RST';
         end;
      (* The UA4W Championship's shape had no arm (plan F24); the classless
         DUMMYCONTEST ran UnknownExchange. *)
      UA4WCHAMPIONSHIP, DUMMYCONTEST:
         begin
         Result := '';
         end;
      YOUTHCHAMPIONSHIPRF:
         begin
         Result := 'Age QSONumber';
         end;
      RADIOMEMORY:
         begin
         Result := 'Age QTH RST';
         end;
      KIDSDAY:
         begin
         Result := 'Kids';
         end;
      FISTS:
         begin
         Result := 'Name Power QSONumber QTH RST';
         end;
      TENTEN:
         begin
         Result := 'Name QTH TenTenNum';
         end;
      ARCI:
         begin
         Result := 'Power QTH RST';
         end;
      ALLJA:
         begin
         Result := 'Precedence QTH RST';
         end;
      RADIOYOC:
         begin
         (* Q136 (2026-10-22): age + serial. *)
         Result := 'Age QSONumber';
         end;
      NZFIELDDAY:
         begin
         Result := 'QSONumber RST Zone';
         end;
      XMAS:
         begin
         Result := 'QSONumber RandomChars RST';
         end;
   else
      begin
      Result := '<not pinned>';
      end;
   end;
end;

procedure TExchangeFieldsTests.Test_EveryContestStatesItsPinnedFields;
const
   (* HOW MANY DISTINCT FIELD SETS THE PROGRAM MARKS, over every contest at
      every roster station: the machine's 28 for the shapes registered
      contests run, the empty set among them -- 27 since Q136 (2026-10-22):
      RADIO-YOC was the one contest whose set was the serial alone
      (ExchangeFieldsQSONumber), and it receives age + serial now. *)
   DISTINCT_SETS = 27;
var
   s: TPinStation;
   c: ContestType;
   seen: string;
   text: string;
   distinct: integer;
   checked: integer;
begin
   BeginTest('Test_EveryContestStatesItsPinnedFields');
   seen := '|';
   distinct := 0;
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         text := ExchangeFieldsText(ProgramFields(c, PinStation(s, c)));
         CheckEquals(PinnedFields(c, s), text, Who(c, s) + ' received-exchange fields');
         Inc(checked);
         if Pos('|' + text + '|', seen) = 0 then
            begin
            seen := seen + text + '|';
            Inc(distinct);
            end;
         end;
      end;
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1), checked,
               'contest x station field lists pinned');
   CheckEquals(DISTINCT_SETS, distinct, 'distinct field sets marked');
end;

(* THE CROSS-CHECK: the program's answer against the frozen machine on the
   session shape, for every ContestType at every roster station. Until S9
   deletes the shape. *)
procedure TExchangeFieldsTests.Test_FieldsAgreeWithTheSessionShape;
var
   s: TPinStation;
   c: ContestType;
   station: TStationContext;
   checked: integer;
begin
   BeginTest('Test_FieldsAgreeWithTheSessionShape');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         CheckEquals(ExchangeFieldsText(LegacyFields(Kinds(c, station).Exchange)),
                     ExchangeFieldsText(ProgramFields(c, station)),
                     Who(c, s) + ' fields as its session shape marked them');
         Inc(checked);
         end;
      end;
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1), checked,
               'contest x station field lists compared');
end;

(* EVERY HELPER, BY NAME -- the set it marks, literally. *)
procedure TExchangeFieldsTests.Test_EachHelperMarksItsFields;

   procedure Check1(const aExpected: string; const aInfo: ExchangeInformationRecord;
                    const aHelper: string);
   begin
      CheckEquals(aExpected, ExchangeFieldsText(aInfo), aHelper);
   end;

begin
   BeginTest('Test_EachHelperMarksItsFields');
   Check1('', ExchangeFieldsNone, 'ExchangeFieldsNone');
   Check1('ClassEI QTH', ExchangeFieldsClassQTH, 'ExchangeFieldsClassQTH');
   Check1('Kids', ExchangeFieldsKids, 'ExchangeFieldsKids');
   Check1('Name QTH', ExchangeFieldsNameQTH, 'ExchangeFieldsNameQTH');
   Check1('Name QTH TenTenNum', ExchangeFieldsNameQTHTenTenNumber, 'ExchangeFieldsNameQTHTenTenNumber');
   Check1('QSONumber', ExchangeFieldsQSONumber, 'ExchangeFieldsQSONumber');
   Check1('Age QSONumber', ExchangeFieldsQSONumberAge, 'ExchangeFieldsQSONumberAge');
   Check1('Name QSONumber', ExchangeFieldsQSONumberName, 'ExchangeFieldsQSONumberName');
   Check1('Chapter Name QSONumber QTH', ExchangeFieldsQSONumberNameChapterQTH, 'ExchangeFieldsQSONumberNameChapterQTH');
   Check1('Name QSONumber QTH', ExchangeFieldsQSONumberNameQTH, 'ExchangeFieldsQSONumberNameQTH');
   Check1('Check Precedence QSONumber QTH', ExchangeFieldsQSONumberPrecedenceCheckQTH, 'ExchangeFieldsQSONumberPrecedenceCheckQTH');
   Check1('QSONumber QTH', ExchangeFieldsQSONumberQTH, 'ExchangeFieldsQSONumberQTH');
   Check1('QSONumber Zone', ExchangeFieldsQSONumberZone, 'ExchangeFieldsQSONumberZone');
   Check1('QTH', ExchangeFieldsQTH, 'ExchangeFieldsQTH');
   Check1('Age RST', ExchangeFieldsRSTAge, 'ExchangeFieldsRSTAge');
   Check1('Age QTH RST', ExchangeFieldsRSTAgeQTH, 'ExchangeFieldsRSTAgeQTH');
   Check1('Name QTH RST', ExchangeFieldsRSTNameQTH, 'ExchangeFieldsRSTNameQTH');
   Check1('Power RST', ExchangeFieldsRSTPower, 'ExchangeFieldsRSTPower');
   Check1('Precedence QTH RST', ExchangeFieldsRSTPrecedenceQTH, 'ExchangeFieldsRSTPrecedenceQTH');
   Check1('QSONumber RST', ExchangeFieldsRSTQSONumber, 'ExchangeFieldsRSTQSONumber');
   Check1('QSONumber QTH RST', ExchangeFieldsRSTQSONumberQTH, 'ExchangeFieldsRSTQSONumberQTH');
   Check1('QSONumber RandomChars RST', ExchangeFieldsRSTQSONumberRandomChars, 'ExchangeFieldsRSTQSONumberRandomChars');
   Check1('QSONumber RST Zone', ExchangeFieldsRSTQSONumberZone, 'ExchangeFieldsRSTQSONumberZone');
   Check1('QTH RST', ExchangeFieldsRSTQTH, 'ExchangeFieldsRSTQTH');
   Check1('Name Power QSONumber QTH RST', ExchangeFieldsRSTQTHNamePowerQSONumber, 'ExchangeFieldsRSTQTHNamePowerQSONumber');
   Check1('Power QTH RST', ExchangeFieldsRSTQTHPower, 'ExchangeFieldsRSTQTHPower');
   Check1('RST Zone', ExchangeFieldsRSTZone, 'ExchangeFieldsRSTZone');
   Check1('QTH RST Zone', ExchangeFieldsRSTZoneQTH, 'ExchangeFieldsRSTZoneQTH');
end;

procedure TExchangeFieldsTests.RunAllTests;
begin
   Test_EveryContestStatesItsPinnedFields;
   Test_FieldsAgreeWithTheSessionShape;
   Test_EachHelperMarksItsFields;
end;

end.
