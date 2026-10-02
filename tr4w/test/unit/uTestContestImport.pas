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

(* EACH CONTEST INTERPRETS ITS OWN ADIF IMPORT -- milestone M5a, 2026-10-01
  (docs/CONTEST_OWNERSHIP_DESIGN.md 3.2).

  The generic importer (uADIF.ApplyADIFFieldsToExchange) names no contest: it
  maps the standard tags and CAPTURES every tag whose meaning is the
  contest's. Once the whole record is read, the contest its CONTEST_ID names
  turns the captured text into the fields it keeps
  (TContestBase.ApplyADIFImport). What is pinned here:

    * THE TAG ORDER DOES NOT MATTER. APP_N1MM_EXCHANGE1 was read as it went by,
      against whichever contest was in force at that point in the record, so a
      record with the tag ahead of CONTEST_ID was misread. Both orders must now
      give one answer.
    * EVERY ARM THAT USED TO BE A `case` IN THE MAIN UNIT is its contest's
      override, and says what it said. The expected values are what the old
      tail produced, so a transcription slip shows here.
    * THE CLASSLESS DEFAULT is the base's, keyed on the session's exchange and
      multiplier kind, which arrive as data.
    * THE COMMON STEPS -- the operator, the received RST -- run for every
      contest before it is asked.

  The classes are leaves, so none of this boots the program. *)
unit uTestContestImport;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestImportTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_N1MMTagOrderDoesNotMatter;
      procedure Test_N1MMTagNeverOverridesTheStandardClass;
      procedure Test_FOCMarathonReadsItsNumber;
      procedure Test_StateExchangeContests;
      procedure Test_DomesticQTHFromSRXContests;
      procedure Test_AlphabeticSRXContests;
      procedure Test_GridContests;
      procedure Test_ARRLRTTYRoundup;
      procedure Test_CWOpsAge;
      procedure Test_SectionContests;
      procedure Test_ZoneAndSocietyContests;
      procedure Test_WAGAndIOTAReadWhatTheyWrite;
      procedure Test_ClasslessDefault;
      procedure Test_CommonStepsRunForEveryContest;
      procedure Test_ImportFromStringAsksTheClass;
      procedure Test_AlphabeticTest;
   end;

implementation

uses
   SysUtils, VC, utils_text, uContestBase, uContestRegistry, uADIF;

(* A RECORD THROUGH THE WHOLE IMPORT: lexed, mapped, interpreted. *)
function Import(const aText: string; const aSession: TADIFImportSession): ContestExchange;
var
   fields: TADIFFieldList;
   temps: TADIFRecordTemps;
begin
   ParseADIFFieldsList(aText + '<EOR>', fields);
   InitContestExchangeForParse(Result);
   ApplyADIFFieldsToExchange(fields, Result, temps);
   InterpretADIFRecord(temps, aSession, Result);
end;

(* A CONTEST ASKED DIRECTLY, with the raw text the importer would have
  captured and a record the generic mapping has already filled. *)
procedure Interpret(aContest: ContestType; const aTemps: TADIFRecordTemps;
                    var aExch: ContestExchange);
begin
   aExch.ceContest := aContest;
   ContestIdentity(aContest).ApplyADIFImport(aTemps, NeutralADIFImportSession, aExch);
end;

(* THE ADIF CONTEST_ID A CONTEST ANSWERS TO -- asked of the contest, so a rename
  cannot make this test lie. *)
function IdOf(aContest: ContestType): string;
begin
   Result := ContestIdentity(aContest).ADIFContestId;
end;

function NoTemps: TADIFRecordTemps;
begin
   InitADIFRecordTemps(Result);
end;

function NewExch(aContest: ContestType): ContestExchange;
begin
   InitContestExchangeForParse(Result);
   Result.ceContest := aContest;
   Result.RSTReceived := 59;
end;

(* An ADIF tag as another logger writes it. *)
function Tag(const aName, aValue: string): string;
begin
   Result := '<' + aName + ':' + IntToStr(Length(aValue)) + '>' + aValue + ' ';
end;

function Head: string;
begin
   Result := Tag('CALL', 'W1AW') + Tag('QSO_DATE', '20260115') +
             Tag('TIME_ON', '121800') + Tag('BAND', '20m') + Tag('MODE', 'CW') +
             Tag('RST_SENT', '599') + Tag('RST_RCVD', '599');
end;

(* ---------------------------------------------------------------------------
   THE N1MM TAG
   --------------------------------------------------------------------------- *)

(* THE FIELD DAYS AND THE FOC MARATHON ARE THE TWO CONTESTS THE TAG MEANT
  SOMETHING TO. A record with the tag AHEAD of CONTEST_ID used to be read for
  the contest in force at that point -- DUMMYCONTEST here, because nothing
  has been read yet, and the operator's open contest in the program -- and so
  missed. Pinned in both orders, for each contest and for a third that does
  not use the tag at all. *)
procedure TContestImportTests.Test_N1MMTagOrderDoesNotMatter;

   procedure CheckBothOrders(const aId, aWhat: string; aExpectContest: ContestType;
                             const aExpectClass, aExpectPower: string);
   var
      before, after: ContestExchange;
   begin
      before := Import(Head + Tag('APP_N1MM_EXCHANGE1', '3a') + Tag('CONTEST_ID', aId),
                       NeutralADIFImportSession);
      after := Import(Head + Tag('CONTEST_ID', aId) + Tag('APP_N1MM_EXCHANGE1', '3a'),
                      NeutralADIFImportSession);

      CheckEquals(Ord(aExpectContest), Ord(before.ceContest), aWhat + ': tag first, the contest');
      CheckEquals(Ord(aExpectContest), Ord(after.ceContest), aWhat + ': tag last, the contest');
      CheckEquals(aExpectClass, string(before.ceClass), aWhat + ': tag first, the class');
      CheckEquals(aExpectClass, string(after.ceClass), aWhat + ': tag last, the class');
      CheckEquals(aExpectPower, string(before.Power), aWhat + ': tag first, the power');
      CheckEquals(aExpectPower, string(after.Power), aWhat + ': tag last, the power');
   end;

begin
   BeginTest('Test_N1MMTagOrderDoesNotMatter');
   (* The class is upper-cased, as it always was. *)
   CheckBothOrders(IdOf(ARRLFIELDDAY), 'ARRL Field Day', ARRLFIELDDAY, '3A', '');
   CheckBothOrders(IdOf(WINTERFIELDDAY), 'Winter Field Day', WINTERFIELDDAY, '3A', '');
   (* The FOC Marathon keeps the number in Power, not a class. *)
   CheckBothOrders(IdOf(FOCMARATHON), 'FOC Marathon', FOCMARATHON, '', '3a');
   (* A contest that does not use the tag ignores it, in both orders. *)
   CheckBothOrders(IdOf(CQWWCW), 'CQ WW CW', CQWWCW, '', '');
end;

(* THE STANDARD CLASS TAG WINS, and N1MM's fills in a record that has none.
  Until M5a whichever of the two tags came LAST won, which made the answer a
  property of the file's field order. *)
procedure TContestImportTests.Test_N1MMTagNeverOverridesTheStandardClass;
var
   a, b, c: ContestExchange;
begin
   BeginTest('Test_N1MMTagNeverOverridesTheStandardClass');
   a := Import(Head + Tag('CONTEST_ID', IdOf(ARRLFIELDDAY)) + Tag('CLASS', '2A') +
               Tag('APP_N1MM_EXCHANGE1', '3A'), NeutralADIFImportSession);
   b := Import(Head + Tag('CONTEST_ID', IdOf(ARRLFIELDDAY)) + Tag('APP_N1MM_EXCHANGE1', '3A') +
               Tag('CLASS', '2A'), NeutralADIFImportSession);
   c := Import(Head + Tag('CONTEST_ID', IdOf(ARRLFIELDDAY)) + Tag('APP_N1MM_EXCHANGE1', '3A'),
               NeutralADIFImportSession);
   CheckEquals('2A', string(a.ceClass), 'CLASS first, N1MM last: the standard tag');
   CheckEquals('2A', string(b.ceClass), 'N1MM first, CLASS last: the standard tag');
   CheckEquals('3A', string(c.ceClass), 'no CLASS tag: N1MM fills it in');
end;

procedure TContestImportTests.Test_FOCMarathonReadsItsNumber;
var
   x: ContestExchange;
   t: TADIFRecordTemps;
begin
   BeginTest('Test_FOCMarathonReadsItsNumber');

   x := NewExch(FOCMARATHON);
   t := NoTemps;
   t.FOC_Num := '1234';
   t.N1MM_Exchange1 := '9999';
   Interpret(FOCMARATHON, t, x);
   CheckEquals('1234', string(x.Power), 'FOC_NUM wins over N1MM''s tag');

   x := NewExch(FOCMARATHON);
   t := NoTemps;
   t.N1MM_Exchange1 := '9999';
   Interpret(FOCMARATHON, t, x);
   CheckEquals('9999', string(x.Power), 'N1MM''s tag fills in a record with no FOC_NUM');

   (* A record with neither comes in with an EMPTY number -- the legacy arm
      assigned FOC_NUM unconditionally, wiping RX_PWR, and that is kept. *)
   x := NewExch(FOCMARATHON);
   x.Power := '100';
   Interpret(FOCMARATHON, NoTemps, x);
   CheckEquals('', string(x.Power), 'neither tag: the number is empty');
end;

(* ---------------------------------------------------------------------------
   THE ARMS, ONE CONTEST AT A TIME
   --------------------------------------------------------------------------- *)

procedure TContestImportTests.Test_StateExchangeContests;
const
   STATE_CONTESTS: array[0..3] of ContestType = (NAQSOCW, NAQSOSSB, NAQSORTTY, NCCCSPRINT);
var
   i: integer;
   x: ContestExchange;
   t: TADIFRecordTemps;
begin
   BeginTest('Test_StateExchangeContests');
   for i := Low(STATE_CONTESTS) to High(STATE_CONTESTS) do
      begin
      x := NewExch(STATE_CONTESTS[i]);
      t := NoTemps;
      t.State := 'PA';
      t.SRX_String := 'JOE PA';
      Interpret(STATE_CONTESTS[i], t, x);
      CheckEquals('PA', string(x.QTHString), string(ContestTypeSA[STATE_CONTESTS[i]]) + ': QTH');
      CheckEquals('PA', string(x.DomesticQTH), string(ContestTypeSA[STATE_CONTESTS[i]]) + ': domestic QTH');
      CheckEquals('PA', string(x.ExchString), string(ContestTypeSA[STATE_CONTESTS[i]]) + ': exchange');
      end;
end;

procedure TContestImportTests.Test_DomesticQTHFromSRXContests;
const
   CONTESTS: array[0..3] of ContestType = (CQ160CW, CQ160SSB, UBACW, UBASSB);
var
   i: integer;
   x: ContestExchange;
   t: TADIFRecordTemps;
begin
   BeginTest('Test_DomesticQTHFromSRXContests');
   for i := Low(CONTESTS) to High(CONTESTS) do
      begin
      x := NewExch(CONTESTS[i]);
      t := NoTemps;
      t.SRX_String := '59 MON';
      Interpret(CONTESTS[i], t, x);
      (* The RAW SRX_STRING, RST and all, as the arm always took it. *)
      CheckEquals('59 MON', string(x.DomesticQTH), string(ContestTypeSA[CONTESTS[i]]) + ': domestic QTH');
      end;
end;

procedure TContestImportTests.Test_AlphabeticSRXContests;
const
   CONTESTS: array[0..2] of ContestType = (UKRAINIAN, OKDX, LZDX);
var
   i: integer;
   x: ContestExchange;
   t: TADIFRecordTemps;
   what: string;
begin
   BeginTest('Test_AlphabeticSRXContests');
   for i := Low(CONTESTS) to High(CONTESTS) do
      begin
      what := string(ContestTypeSA[CONTESTS[i]]);

      x := NewExch(CONTESTS[i]);
      t := NoTemps;
      t.SRX_String := 'KI';
      Interpret(CONTESTS[i], t, x);
      CheckEquals('KI', string(x.DomesticQTH), what + ': letters are a domestic QTH');
      CheckEquals('', string(x.QTHString), what + ': and not the QTH string');

      x := NewExch(CONTESTS[i]);
      t := NoTemps;
      t.SRX_String := '599 123';
      Interpret(CONTESTS[i], t, x);
      CheckEquals('599 123', string(x.QTHString), what + ': anything else is the QTH string');
      CheckEquals('', string(x.DomesticQTH), what + ': and not a domestic QTH');
      end;
end;

procedure TContestImportTests.Test_GridContests;
var
   x: ContestExchange;
   t: TADIFRecordTemps;
begin
   BeginTest('Test_GridContests');

   (* General QSO: the grid is all three, and a record with none is untouched. *)
   x := NewExch(GENERALQSO);
   t := NoTemps;
   t.GridSquare := 'FN31';
   Interpret(GENERALQSO, t, x);
   CheckEquals('FN31', string(x.ExchString), 'General QSO: exchange');
   CheckEquals('FN31', string(x.QTHString), 'General QSO: QTH');
   CheckEquals('FN31', string(x.DomesticQTH), 'General QSO: domestic QTH');

   x := NewExch(GENERALQSO);
   x.QTHString := 'CT';
   Interpret(GENERALQSO, NoTemps, x);
   CheckEquals('CT', string(x.QTHString), 'General QSO with no grid keeps what it had');

   (* The two digital contests: the grid is the exchange and the domestic QTH. *)
   x := NewExch(WWDIGI);
   t := NoTemps;
   t.GridSquare := 'JO62';
   Interpret(WWDIGI, t, x);
   CheckEquals('JO62', string(x.ExchString), 'WW Digi: exchange');
   CheckEquals('JO62', string(x.DomesticQTH), 'WW Digi: domestic QTH');

   x := NewExch(ARRLDIGI);
   Interpret(ARRLDIGI, t, x);
   CheckEquals('JO62', string(x.ExchString), 'ARRL Digi: exchange');
   CheckEquals('JO62', string(x.DomesticQTH), 'ARRL Digi: domestic QTH');
end;

procedure TContestImportTests.Test_ARRLRTTYRoundup;
var
   x: ContestExchange;
   t: TADIFRecordTemps;
begin
   BeginTest('Test_ARRLRTTYRoundup');
   t := NoTemps;
   t.State := 'FL';

   x := NewExch(ARRL_RTTY_ROUNDUP);
   x.QTH.CountryID := 'K';
   x.RSTReceived := 599;
   Interpret(ARRL_RTTY_ROUNDUP, t, x);
   CheckEquals('599 FL', string(x.QTHString), 'US: the report and the state');
   CheckEquals('599 FL', string(x.ExchString), 'US: the exchange string');

   x := NewExch(ARRL_RTTY_ROUNDUP);
   x.QTH.CountryID := 'VE';
   x.RSTReceived := 599;
   Interpret(ARRL_RTTY_ROUNDUP, t, x);
   CheckEquals('599 FL', string(x.QTHString), 'Canada: the same');

   x := NewExch(ARRL_RTTY_ROUNDUP);
   x.QTH.CountryID := 'DL';
   x.RSTReceived := 599;
   x.NumberReceived := 45;
   Interpret(ARRL_RTTY_ROUNDUP, t, x);
   CheckEquals('599 45', string(x.QTHString), 'DX: the report and the serial');
   CheckEquals('599 45', string(x.ExchString), 'DX: the exchange string');
end;

procedure TContestImportTests.Test_CWOpsAge;
var
   x: ContestExchange;
begin
   BeginTest('Test_CWOpsAge');
   x := NewExch(CWOPS);
   x.QTHString := '45';
   Interpret(CWOPS, NoTemps, x);
   CheckEquals(45, x.Age, 'a number in the QTH is the age');

   x := NewExch(CWOPS);
   x.QTHString := 'PA';
   Interpret(CWOPS, NoTemps, x);
   CheckEquals(0, x.Age, 'a state is not an age');
end;

(* SWEEPSTAKES AND THE FIELD DAYS: ARRL_SECT WINS WHEN PRESENT, AND AN ABSENT
  TAG IS NOT AN EMPTY SECTION -- Winter Field Day's D7 log carries the section
  in <QTH> alone, and assigning the empty tag erased it on 1310 of 1316 QSOs. *)
procedure TContestImportTests.Test_SectionContests;
const
   CONTESTS: array[0..3] of ContestType = (ARRLSSCW, ARRLSSSSB, ARRLFIELDDAY, WINTERFIELDDAY);
var
   i: integer;
   x: ContestExchange;
   t: TADIFRecordTemps;
   what: string;
begin
   BeginTest('Test_SectionContests');
   for i := Low(CONTESTS) to High(CONTESTS) do
      begin
      what := string(ContestTypeSA[CONTESTS[i]]);

      x := NewExch(CONTESTS[i]);
      x.QTHString := 'OLD';
      t := NoTemps;
      t.ARRL_Sect := 'EPA';
      Interpret(CONTESTS[i], t, x);
      CheckEquals('EPA', string(x.DomesticQTH), what + ': ARRL_SECT is the multiplier');
      CheckEquals('EPA', string(x.QTHString), what + ': and the QTH');

      x := NewExch(CONTESTS[i]);
      x.QTHString := 'EPA';
      Interpret(CONTESTS[i], NoTemps, x);
      CheckEquals('EPA', string(x.DomesticQTH), what + ': no ARRL_SECT, the QTH tag supplies it');
      CheckEquals('EPA', string(x.QTHString), what + ': and survives');

      x := NewExch(CONTESTS[i]);
      Interpret(CONTESTS[i], NoTemps, x);
      CheckEquals('', string(x.DomesticQTH), what + ': neither: nothing invented');
      end;
end;

procedure TContestImportTests.Test_ZoneAndSocietyContests;
var
   x: ContestExchange;
   t: TADIFRecordTemps;
   i: integer;
begin
   BeginTest('Test_ZoneAndSocietyContests');

   (* CQ WW: the exchange left in SRX_STRING once the RST is off is the zone,
      and a zone is not a location. *)
   for i := 0 to 1 do
      begin
      x := NewExch(CQWWCW);
      if i = 1 then
         begin
         x := NewExch(CQWWSSB);
         end;
      x.RSTReceived := 59;
      t := NoTemps;
      t.SRX_String := '59 8';
      Interpret(x.ceContest, t, x);
      CheckEquals(8, x.Zone, 'CQ WW: the zone');
      CheckEquals('', string(x.QTHString), 'CQ WW: no QTH');
      end;

   (* IARU: a society is a QTH, a zone is not. *)
   x := NewExch(IARU);
   x.RSTReceived := 59;
   t := NoTemps;
   t.SRX_String := '59 ARRL';
   Interpret(IARU, t, x);
   CheckEquals('ARRL', string(x.QTHString), 'IARU: a society is the QTH');

   x := NewExch(IARU);
   x.RSTReceived := 59;
   t := NoTemps;
   t.SRX_String := '59 8';
   Interpret(IARU, t, x);
   CheckEquals('', string(x.QTHString), 'IARU: a zone is not');
end;

(* WAG AND THE RSGB IOTA WRITE A TAG THE GENERIC IMPORT DOES NOT KNOW, and read
  it back themselves. *)
procedure TContestImportTests.Test_WAGAndIOTAReadWhatTheyWrite;
var
   x: ContestExchange;
   t: TADIFRecordTemps;
begin
   BeginTest('Test_WAGAndIOTAReadWhatTheyWrite');

   x := NewExch(WAG);
   t := NoTemps;
   t.SRX_String := '599';
   t.DOK := 'B01';
   Interpret(WAG, t, x);
   CheckEquals('B01', string(x.QTHString), 'WAG: DOK is the QTH');

   x := NewExch(WAG);
   t := NoTemps;
   t.SRX_String := '599 B01';
   Interpret(WAG, t, x);
   CheckEquals('599 B01', string(x.QTHString), 'WAG with no DOK: SRX_STRING, as it always was');

   x := NewExch(IOTA);
   t := NoTemps;
   t.IOTA := 'EU-005';
   Interpret(IOTA, t, x);
   CheckEquals('EU-005', string(x.DomesticQTH), 'RSGB IOTA: the island is the domestic QTH');

   x := NewExch(IOTA);
   x.QTHString := 'XX';
   Interpret(IOTA, NoTemps, x);
   CheckEquals('', string(x.DomesticQTH), 'RSGB IOTA with no tag: the neutral session has no multipliers');
end;

(* ---------------------------------------------------------------------------
   THE CLASSLESS DEFAULT, AND THE COMMON STEPS
   --------------------------------------------------------------------------- *)

(* RSGB 1.8 MHz has no class (design Q33 holds it until M8), so it is read by
  the base's default -- the `else` of the old tail -- keyed on the SESSION.
  This test used ARRL 10 until that contest gained a class at M7b. *)
procedure TContestImportTests.Test_ClasslessDefault;
var
   x: ContestExchange;
   t: TADIFRecordTemps;
   s: TADIFImportSession;
begin
   BeginTest('Test_ClasslessDefault');
   CheckTrue(ContestClassFor(RSGB18) = nil, 'the contest this test uses is still classless');

   t := NoTemps;
   t.GridSquare := 'FN31';
   t.SRX_String := '59 MON12';

   (* A grid exchange, by the session's multiplier kind or by its exchange. *)
   s := NeutralADIFImportSession;
   s.DomesticMult := GridSquares;
   x := NewExch(RSGB18);
   x.RSTReceived := 59;
   ContestIdentity(RSGB18).ApplyADIFImport(t, s, x);
   CheckEquals('FN31', string(x.QTHString), 'grid multipliers: QTH');
   CheckEquals('FN31', string(x.DomesticQTH), 'grid multipliers: domestic QTH');
   CheckEquals('59 FN31', string(x.ExchString), 'grid multipliers: RST and grid');

   s := NeutralADIFImportSession;
   s.Exchange := Grid2Exchange;
   x := NewExch(RSGB18);
   x.RSTReceived := 59;
   ContestIdentity(RSGB18).ApplyADIFImport(t, s, x);
   CheckEquals('59 FN31', string(x.ExchString), 'a grid exchange: RST and grid');

   (* Domestic multipliers: the QTH tag when the record has one, else the
      letters leading SRX_STRING. *)
   s := NeutralADIFImportSession;
   s.DoingDomesticMults := True;
   x := NewExch(RSGB18);
   x.QTHString := 'MON';
   ContestIdentity(RSGB18).ApplyADIFImport(t, s, x);
   CheckEquals('MON', string(x.DomesticQTH), 'domestic multipliers: the QTH tag');

   x := NewExch(RSGB18);
   ContestIdentity(RSGB18).ApplyADIFImport(t, s, x);
   CheckEquals('', string(x.DomesticQTH), 'a leading digit leaves no letters');

   t.SRX_String := 'MON12';
   x := NewExch(RSGB18);
   ContestIdentity(RSGB18).ApplyADIFImport(t, s, x);
   CheckEquals('MON', string(x.DomesticQTH), 'domestic multipliers: the alpha prefix of SRX_STRING');

   (* Neither: the raw SRX_STRING is the exchange. *)
   x := NewExch(RSGB18);
   ContestIdentity(RSGB18).ApplyADIFImport(t, NeutralADIFImportSession, x);
   CheckEquals('MON12', string(x.ExchString), 'no multipliers: SRX_STRING is the exchange');
end;

procedure TContestImportTests.Test_CommonStepsRunForEveryContest;
var
   x: ContestExchange;
   s: TADIFImportSession;
begin
   BeginTest('Test_CommonStepsRunForEveryContest');
   s := NeutralADIFImportSession;
   SetCharBuffer(s.Operator, 'K0XYZ');

   (* A record with no OPERATOR gets the session's -- classless or not. *)
   x := Import(Head + Tag('CONTEST_ID', IdOf(ARRL10)), s);
   CheckEquals('K0XYZ', CharBufferText(x.ceOperator), 'a classless contest: the session operator');
   x := Import(Head + Tag('CONTEST_ID', IdOf(WAG)), s);
   CheckEquals('K0XYZ', CharBufferText(x.ceOperator), 'a contest with a class: the session operator');

   (* A record that names one keeps it. *)
   x := Import(Head + Tag('CONTEST_ID', IdOf(WAG)) + Tag('OPERATOR', 'N0ABC'), s);
   CheckEquals('N0ABC', CharBufferText(x.ceOperator), 'a named operator is kept');

   (* The received RST comes off the front of SRX_STRING, for every contest,
      before the contest is asked. CQ WW then reads the zone from what is left. *)
   x := Import(Head + Tag('CONTEST_ID', IdOf(CQWWCW)) + Tag('SRX_STRING', '599 8'), s);
   CheckEquals(8, x.Zone, 'CQ WW: the zone is what follows the RST');
   x := Import(Head + Tag('CONTEST_ID', IdOf(ARRL10)) + Tag('SRX_STRING', '599 CT'), s);
   CheckEquals('599 CT', string(x.ExchString), 'a classless contest takes the raw SRX_STRING, as the default always has');
end;

procedure TContestImportTests.Test_ImportFromStringAsksTheClass;
var
   records: TContestExchangeArray;
begin
   BeginTest('Test_ImportFromStringAsksTheClass');
   records := nil;
   CheckEquals(1, ImportADIFFromString(
      Head + Tag('CONTEST_ID', IdOf(WAG)) + Tag('SRX_STRING', '599') + Tag('DOK', 'B01') + '<EOR>',
      records), 'one record');
   CheckEquals('B01', string(records[0].QTHString), 'WAG read its DOK through the multi-record entry point');
end;

procedure TContestImportTests.Test_AlphabeticTest;
begin
   BeginTest('Test_AlphabeticTest');
   CheckTrue(ADIFTextIsAlphabetic('CT'), 'letters');
   CheckTrue(ADIFTextIsAlphabetic('abcXYZ'), 'either case');
   CheckFalse(ADIFTextIsAlphabetic(''), 'empty is not');
   CheckFalse(ADIFTextIsAlphabetic('123'), 'digits are not');
   CheckFalse(ADIFTextIsAlphabetic('C1'), 'a mixture is not');
   CheckFalse(ADIFTextIsAlphabetic('599 CT'), 'a space is not');
   CheckFalse(ADIFTextIsAlphabetic('A-B'), 'a hyphen is not');
end;

procedure TContestImportTests.RunAllTests;
begin
   Test_N1MMTagOrderDoesNotMatter;
   Test_N1MMTagNeverOverridesTheStandardClass;
   Test_FOCMarathonReadsItsNumber;
   Test_StateExchangeContests;
   Test_DomesticQTHFromSRXContests;
   Test_AlphabeticSRXContests;
   Test_GridContests;
   Test_ARRLRTTYRoundup;
   Test_CWOpsAge;
   Test_SectionContests;
   Test_ZoneAndSocietyContests;
   Test_WAGAndIOTAReadWhatTheyWrite;
   Test_ClasslessDefault;
   Test_CommonStepsRunForEveryContest;
   Test_ImportFromStringAsksTheClass;
   Test_AlphabeticTest;
end;

end.
