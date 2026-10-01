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

(* EACH CONTEST FORMATS ITS OWN EXPORT -- milestone M4, 2026-10-01
  (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2e).

  Every rule that was a `Contest = ...` test inside the shared exporters is
  pinned here ON ITS CONTEST'S CLASS, asked the way the exporters ask it:
  uContestRegistry.ContestIdentity. The expected strings of the branches that
  moved are the ones uTestCabrilloExchange pinned against the shared arms
  before the move -- the same bytes, now produced by the class.

  THE ROUND TRIP. For every class with an export rule of its own, one QSO is
  written through uADIF.EmitADIFRecord plus that class's STX_STRING and
  contest fields, read back through the generic importer
  (uADIF.ApplyADIFFieldsToExchange), and the fields compared. Import is NOT the
  class's yet (M5) -- this pins the class's export against TODAY's import, so
  M5 inherits a stated contract. Two fields go out and do not come back, and
  the test says so rather than skipping them: WAG's DOK and the RSGB IOTA's
  IOTA have no import arm.

  The Cabrillo side has no round trip because TR4W has no Cabrillo importer
  (design 3.2); its lines are pinned as golden strings, which is what a robot
  scorer reads. *)
unit uTestContestExport;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestExportTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_ClasslessContestGetsTheSharedArm;
      procedure Test_EveryContestFormatsItsOwnExchange;
      procedure Test_FOCMarathonSendsItsMembershipNumber;
      procedure Test_UkraineAndUralPutTheQTHFirst;
      procedure Test_UKEIAndIOTAFillAnEmptyQTH;
      procedure Test_DARC10MReceivedColumn;
      procedure Test_PACCSendsItsSerial;
      procedure Test_PCCSendsItsSerialNeverItsState;
      procedure Test_CaliforniaAndWWDigiChooseTheirQTH;
      procedure Test_SweepstakesColumns;
      procedure Test_SweepstakesEmptyPrecedenceIsABlankNotANul;
      procedure Test_FieldDayColumns;
      procedure Test_FieldDayDXIsNeverAnARRLSection;
      procedure Test_StateFromARRLSection;
      procedure Test_ContestFieldsOfTheOtherOwners;
      procedure Test_ADIFContestIdAndPowerTag;
      procedure Test_RoundTripThroughTodaysImport;
   end;

implementation

uses
   SysUtils, VC, uContestBase, uContestRegistry, uADIF,
   uARRLSections;

function EmptyQso(aContest: ContestType): ContestExchange;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.ceContest := aContest;
   Result.ceRecordKind := rkQSO;
end;

function EmptyMy: TMyStationExchange;
begin
   Result.MyState := '';  Result.MyGrid := '';  Result.MyName := '';
   Result.MyZone := '';   Result.MyFDClass := '';  Result.MySection := '';
   Result.MyCheck := '';  Result.MyPrec := '';  Result.MyFOCNumber := '';
   Result.MyPostalCode := '';  Result.MyPark := '';
end;

(* The context the Cabrillo writer hands a contest, for one QSO. *)
function Ctx(aKind: ExchangeType; const aRST, aHisQTH: string): TCabrilloQSOContext;
begin
   Result.SessionExchange := aKind;
   Result.RSTSent := aRST;
   Result.RSTReceived := aRST;
   Result.HisQTH := aHisQTH;
   Result.PreviousQTH := '';
   Result.PreviousNumberReceived := 0;
   Result.RecordNumber := 1;
   Result.ContestTitle := '';
end;

function Sent(aContest: ContestType; const aMy: TMyStationExchange;
              const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := ContestIdentity(aContest).FormatCabrilloSentExchange(aMy, aQso, aCtx);
end;

function Received(aContest: ContestType; const aMy: TMyStationExchange;
                  const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := ContestIdentity(aContest).FormatCabrilloReceivedExchange(aMy, aQso, aCtx);
end;

(* A CONTEST WITH NO EXPORT RULE GETS THE SHARED ARM FOR ITS SESSION'S
   EXCHANGE -- the bytes uTestCabrilloExchange pins on the arm itself. CQ 160
   has no class at all; the KVP has one and no export rule. *)
procedure TContestExportTests.Test_ClasslessContestGetsTheSharedArm;
var
   qso: ContestExchange;
   my: TMyStationExchange;
   c: TCabrilloQSOContext;
begin
   BeginTest('Test_ClasslessContestGetsTheSharedArm');
   qso := EmptyQso(CQ160CW);
   qso.NumberSent := 12;
   qso.NumberReceived := 34;
   my := EmptyMy;
   my.MyState := 'FL';
   c := Ctx(QSONumberDomesticQTHExchange, '', 'GA');
   CheckEquals('12   FL    ', Sent(CQ160CW, my, qso, c), 'classless: the shared sent column');
   CheckEquals('0034 GA    ', Received(CQ160CW, my, qso, c), 'classless: the shared received column');
   CheckEquals('12   FL    ', Sent(KVP, my, qso, c), 'a class with no export rule: the same');
   CheckEquals(CabrilloQSOLineFormatDefault, ContestIdentity(CQ160CW).CabrilloQSOLineFormat,
               'the one line layout');
end;

(* EVERY ContestType ANSWERS, for its own exchange, without raising. The
   exporters ask every contest now, so a contest whose answer raised would
   take an export down rather than fall back to anything. *)
procedure TContestExportTests.Test_EveryContestFormatsItsOwnExchange;
var
   c: ContestType;
   qso: ContestExchange;
   my: TMyStationExchange;
   context: TCabrilloQSOContext;
   contest: TContestBase;
   failed: string;
   line: string;
begin
   BeginTest('Test_EveryContestFormatsItsOwnExchange');
   failed := '';
   my := EmptyMy;
   for c := Succ(Low(ContestType)) to High(ContestType) do
      begin
      contest := ContestIdentity(c);
      qso := EmptyQso(c);
      context := Ctx(contest.ExchangeKind, '599', 'GA');
      try
         line := contest.FormatCabrilloSentExchange(my, qso, context)
                 + contest.FormatCabrilloReceivedExchange(my, qso, context);
         line := line + contest.EmitADIFContestFields(qso);
      except
         on E: Exception do
            begin
            failed := failed + ' ' + string(ContestTypeSA[c]) + '(' + E.Message + ')';
            end;
      end;
      end;
   CheckEquals('', failed, 'every contest formats its export without raising');
end;

procedure TContestExportTests.Test_FOCMarathonSendsItsMembershipNumber;
var
   qso: ContestExchange;
   my: TMyStationExchange;
   c: TCabrilloQSOContext;
begin
   BeginTest('Test_FOCMarathonSendsItsMembershipNumber');
   qso := EmptyQso(FOCMARATHON);
   qso.Power := '1234';
   qso.RSTSent := 599;
   my := EmptyMy;
   my.MyFOCNumber := '5678';
   my.MyState := 'FL';
   c := Ctx(RSTPowerExchange, '599', '');
   CheckEquals('599 5678   ', Sent(FOCMARATHON, my, qso, c), 'FOC MyEx: my FOC number');
   CheckEquals('599 1234   ', Received(FOCMARATHON, my, qso, c), 'FOC HisEx: his number, from Power');
   CheckEquals('599 5678   ',
               ContestIdentity(FOCMARATHON).FormatADIFSentExchange(my, qso, RSTPowerExchange),
               'FOC STX_STRING: my FOC number');
   CheckEquals('599 FL     ', Sent(CQ160CW, my, qso, c),
               'the same exchange for any other contest sends the state');
end;

procedure TContestExportTests.Test_UkraineAndUralPutTheQTHFirst;
var
   qso: ContestExchange;
   my: TMyStationExchange;
   c: TCabrilloQSOContext;
begin
   BeginTest('Test_UkraineAndUralPutTheQTHFirst');
   my := EmptyMy;
   my.MyState := 'FL';
   c := Ctx(QSONumberDomesticQTHExchange, '', 'GA');

   qso := EmptyQso(UKRAINECHAMPIONSHIP);
   qso.NumberSent := 12;
   qso.NumberReceived := 34;
   CheckEquals('FL   0012  ', Sent(UKRAINECHAMPIONSHIP, my, qso, c), 'Ukraine MyEx');
   CheckEquals('GA   0034  ', Received(UKRAINECHAMPIONSHIP, my, qso, c), 'Ukraine HisEx');

   qso.ceContest := CUPURAL;
   CheckEquals('FL   0012  ', Sent(CUPURAL, my, qso, c), 'Ural Cup MyEx');
   CheckEquals('GA   0034  ', Received(CUPURAL, my, qso, c), 'Ural Cup HisEx');
end;

procedure TContestExportTests.Test_UKEIAndIOTAFillAnEmptyQTH;
var
   qso: ContestExchange;
   my: TMyStationExchange;
   c: TCabrilloQSOContext;
begin
   BeginTest('Test_UKEIAndIOTAFillAnEmptyQTH');
   my := EmptyMy;
   my.MyState := 'FL';
   c := Ctx(RSTQSONumberAndPossibleDomesticQTHExchange, '599', '');

   qso := EmptyQso(UKEI);
   qso.NumberSent := 12;
   qso.NumberReceived := 34;
   CheckEquals('599 0034   --', Received(UKEI, my, qso, c), 'UK/EI: no QTH is --');
   CheckEquals('599 0012     FL      ', Sent(UKEI, my, qso, c), 'UK/EI MyEx: the shared arm');

   qso.ceContest := IOTA;
   CheckEquals('599 0034 ------', Received(IOTA, my, qso, c), 'IOTA: no island is ------');

   qso.ceContest := UKEI;
   qso.QTHString := 'EU';
   c := Ctx(RSTQSONumberAndPossibleDomesticQTHExchange, '599', 'EU');
   CheckEquals('599 0034   EU', Received(UKEI, my, qso, c), 'UK/EI: a QTH is itself');
end;

procedure TContestExportTests.Test_DARC10MReceivedColumn;
var
   qso: ContestExchange;
   my: TMyStationExchange;
   c: TCabrilloQSOContext;
begin
   BeginTest('Test_DARC10MReceivedColumn');
   my := EmptyMy;
   qso := EmptyQso(DARC10M);
   qso.NumberReceived := 34;
   c := Ctx(RSTQSONumberAndPossibleDomesticQTHExchange, '599', 'GA');
   CheckEquals('599 0034  GA', Received(DARC10M, my, qso, c), 'DARC 10 m: a three-wide DOK');
   CheckEquals('599 0034   GA', Received(CQ160CW, my, qso, c), 'the shared arm: four wide');
end;

procedure TContestExportTests.Test_PACCSendsItsSerial;
var
   qso: ContestExchange;
   my: TMyStationExchange;
   c: TCabrilloQSOContext;
begin
   BeginTest('Test_PACCSendsItsSerial');
   my := EmptyMy;
   my.MyState := 'FL';
   qso := EmptyQso(PACC);
   qso.NumberSent := 7;
   qso.RSTSent := 599;
   qso.QTHString := 'NH';
   c := Ctx(RSTDomesticQTHExchange, '599', 'NH');
   CheckEquals('599 7      ', Sent(PACC, my, qso, c), 'PACC MyEx: the serial in the state column');
   CheckEquals('599 NH     ', Received(PACC, my, qso, c), 'PACC HisEx: the shared arm');
   CheckEquals('599 7      ',
               ContestIdentity(PACC).FormatADIFSentExchange(my, qso, RSTDomesticQTHExchange),
               'PACC STX_STRING: the serial');
   CheckEquals('599 FL     ', Sent(CQ160CW, my, qso, c), 'any other contest sends the state');
end;

procedure TContestExportTests.Test_PCCSendsItsSerialNeverItsState;
var
   qso: ContestExchange;
   my: TMyStationExchange;
   c: TCabrilloQSOContext;
begin
   BeginTest('Test_PCCSendsItsSerialNeverItsState');
   qso := EmptyQso(PCC);
   qso.NumberSent := 7;
   qso.NumberReceived := 31;
   qso.RSTSent := 599;
   my := EmptyMy;
   c := Ctx(RSTAndQSONumberOrDomesticQTHExchange, '599', '');

   my.MyState := '014';
   CheckEquals('599  0007/M   ', Sent(PCC, my, qso, c), 'PCC MyEx: an all-digit MY STATE adds /M');
   CheckEquals('599 031', Received(PCC, my, qso, c), 'PCC HisEx: the shared arm');
   CheckEquals('599    7/M   ',
               ContestIdentity(PCC).FormatADIFSentExchange(my, qso, RSTAndQSONumberOrDomesticQTHExchange),
               'PCC STX_STRING: /M');

   my.MyState := 'FL';
   CheckEquals('599  0007   ', Sent(PCC, my, qso, c), 'PCC MyEx: never the state');
   CheckEquals('599 FL     ', Sent(CQ160CW, my, qso, c), 'any other contest sends the state');
end;

(* CALIFORNIA AND WW DIGI CHOOSE THEIR OWN RECEIVED QTH -- both were tests in
   PostUnit's Cabrillo writer, before it asked the contest. *)
procedure TContestExportTests.Test_CaliforniaAndWWDigiChooseTheirQTH;
var
   qso: ContestExchange;
   my: TMyStationExchange;
   c: TCabrilloQSOContext;
begin
   BeginTest('Test_CaliforniaAndWWDigiChooseTheirQTH');
   my := EmptyMy;
   qso := EmptyQso(CALQSOPARTY);
   qso.NumberReceived := 34;
   qso.QTHString := 'LAX';
   qso.DomMultQTH := 'LAX';
   c := Ctx(QSONumberDomesticOrDXQTHExchange, '', 'XYZ');
   CheckEquals('0034 LAX   ', Received(CALQSOPARTY, my, qso, c),
               'California: the QSO''s QTHString, not the exporter''s choice');
   qso.DomMultQTH := '';
   CheckEquals('0034 DX    ', Received(CALQSOPARTY, my, qso, c),
               'California: no domestic multiplier is DX');

   qso := EmptyQso(WWDIGI);
   qso.QTHString := 'FN31';
   qso.DomesticQTH := 'fn31';
   c := Ctx(Grid2Exchange, '', 'fn31');
   CheckEquals('FN31       ', Received(WWDIGI, my, qso, c), 'WW Digi: the QSO''s QTHString');
end;

procedure TContestExportTests.Test_SweepstakesColumns;
var
   qso: ContestExchange;
   my: TMyStationExchange;
   c: TCabrilloQSOContext;
begin
   BeginTest('Test_SweepstakesColumns');
   qso := EmptyQso(ARRLSSCW);
   qso.NumberSent := 12;
   qso.NumberReceived := 34;
   qso.Precedence := 'A';
   qso.Check := 72;
   my := EmptyMy;
   my.MyPrec := 'B';
   my.MyCheck := '59';
   my.MySection := 'GA';
   c := Ctx(QSONumberPrecedenceCheckDomesticQTHExchange, '', 'SC');
   CheckEquals('12   B 59 GA  ', Sent(ARRLSSCW, my, qso, c), 'SS MyEx');
   CheckEquals('34   A 72 SC ', Received(ARRLSSCW, my, qso, c), 'SS HisEx');
   CheckEquals('34   A 72 SC ', Received(ARRLSSSSB, my, qso, c), 'SS SSB: the family');
end;

(* DEFECT #4 OF THE M0 MATRIX, FIXED AT M4: a QSO with no precedence wrote a
   NUL byte into the Cabrillo line. It writes one blank now -- the column
   keeps its width, and every later column its place. *)
procedure TContestExportTests.Test_SweepstakesEmptyPrecedenceIsABlankNotANul;
var
   qso: ContestExchange;
   my: TMyStationExchange;
   c: TCabrilloQSOContext;
   line: string;
begin
   BeginTest('Test_SweepstakesEmptyPrecedenceIsABlankNotANul');
   qso := EmptyQso(ARRLSSCW);
   qso.NumberReceived := -1;
   my := EmptyMy;
   c := Ctx(QSONumberPrecedenceCheckDomesticQTHExchange, '', '');
   line := Received(ARRLSSCW, my, qso, c);
   CheckEquals(0, Pos(#0, line), 'no NUL in a Cabrillo line');
   CheckEquals('0      00    ', line, 'the precedence column is one blank');
end;

procedure TContestExportTests.Test_FieldDayColumns;
var
   qso: ContestExchange;
   my: TMyStationExchange;
   c: TCabrilloQSOContext;
begin
   BeginTest('Test_FieldDayColumns');
   qso := EmptyQso(ARRLFIELDDAY);
   qso.ceClass := '2A';
   qso.QTHString := 'SC';
   my := EmptyMy;
   my.MyFDClass := '3A';
   my.MySection := 'GA';
   c := Ctx(ClassDomesticOrDXQTHExchange, '', 'SC');
   CheckEquals('3A  GA      ', Sent(ARRLFIELDDAY, my, qso, c), 'FD MyEx');
   CheckEquals('2A  SC     ', Received(ARRLFIELDDAY, my, qso, c), 'FD HisEx');
   CheckEquals('3A  GA      ',
               ContestIdentity(ARRLFIELDDAY).FormatADIFSentExchange(my, qso, ClassDomesticOrDXQTHExchange),
               'FD STX_STRING');
   CheckEquals('2A  SC     ', Received(WINTERFIELDDAY, my, qso, c), 'WFD HisEx');
end;

(* NY4I, 2026-10-01 (design Q1): "DX IS NOT AN ARRL SECTION." A DX station
   sends a class and DX; the DX goes in the section POSITION of the Cabrillo
   line and never into ADIF ARRL_SECT. Pinned for both Field Days. *)
procedure TContestExportTests.Test_FieldDayDXIsNeverAnARRLSection;
var
   qso: ContestExchange;
   my: TMyStationExchange;
   c: TCabrilloQSOContext;
   fd: ContestType;
begin
   BeginTest('Test_FieldDayDXIsNeverAnARRLSection');
   my := EmptyMy;
   for fd in [ARRLFIELDDAY, WINTERFIELDDAY] do
      begin
      qso := EmptyQso(fd);
      qso.ceClass := '1D';
      qso.QTHString := 'DX';
      qso.QTH.CountryID := 'G';
      c := Ctx(ClassDomesticOrDXQTHExchange, '', 'DX');
      CheckEquals('1D  DX     ', Received(fd, my, qso, c),
                  string(ContestTypeSA[fd]) + ': DX in the section position of the line');
      CheckEquals('', ContestIdentity(fd).EmitADIFContestFields(qso),
                  string(ContestTypeSA[fd]) + ': DX writes no ARRL_SECT, STATE or DXCC');

      qso.QTHString := 'WCF';
      qso.QTH.CountryID := 'K';
      CheckEquals('<DXCC:3>291 <STATE:2>FL <ARRL_SECT:3>WCF <CLASS:2>1D ',
                  ContestIdentity(fd).EmitADIFContestFields(qso),
                  string(ContestTypeSA[fd]) + ': a US section');

      qso.QTHString := 'GTA';
      qso.QTH.CountryID := 'VE';
      CheckEquals('<DXCC:1>1 <STATE:2>ON <ARRL_SECT:3>GTA <CLASS:2>1D ',
                  ContestIdentity(fd).EmitADIFContestFields(qso),
                  string(ContestTypeSA[fd]) + ': a Canadian section');
      end;
end;

(* THE LIFTED SECTION-TO-STATE TABLE (M4) -- one answer from each layer it
   merged: PostUnit's modern names first, then Tree's plain states and the
   older two-letter names, with the case folded as both did. *)
procedure TContestExportTests.Test_StateFromARRLSection;
begin
   BeginTest('Test_StateFromARRLSection');
   CheckEquals('FL', StateFromARRLSection('WCF'), 'a modern Florida section');
   CheckEquals('FL', StateFromARRLSection('nfl'), 'case folded');
   CheckEquals('MA', StateFromARRLSection('EMA'), 'PostUnit''s Massachusetts');
   CheckEquals('MA', StateFromARRLSection('EM'), 'Tree''s older two-letter name');
   CheckEquals('CA', StateFromARRLSection('SF'), 'San Francisco is California, not Florida');
   CheckEquals('HI', StateFromARRLSection('PAC'), 'Pacific');
   CheckEquals('ON', StateFromARRLSection('GTA'), 'a Canadian section');
   CheckEquals('NS', StateFromARRLSection('MAR'), 'Maritime');
   CheckEquals('KS', StateFromARRLSection('KS'), 'a state answers itself');
   CheckEquals('', StateFromARRLSection('DX'), 'DX is no state');
   CheckEquals('', StateFromARRLSection(''), 'nothing is no state');
end;

procedure TContestExportTests.Test_ContestFieldsOfTheOtherOwners;
var
   qso: ContestExchange;
begin
   BeginTest('Test_ContestFieldsOfTheOtherOwners');
   qso := EmptyQso(ARRLSSCW);
   qso.QTHString := 'CT';
   CheckEquals('<ARRL_SECT:2>CT ', ContestIdentity(ARRLSSCW).EmitADIFContestFields(qso), 'SS section');
   qso.QTHString := 'DX';
   CheckEquals('', ContestIdentity(ARRLSSSSB).EmitADIFContestFields(qso), 'SS: DX is not a section');

   qso := EmptyQso(IARU);
   qso.QTHString := 'ARRL';
   CheckEquals('<APP_TR4W_HQ:4>ARRL ', ContestIdentity(IARU).EmitADIFContestFields(qso), 'IARU society');

   qso := EmptyQso(IOTA);
   qso.QTHString := 'EU5';
   qso.DomesticQTH := 'EU-005';
   CheckEquals('<IOTA:6>EU-005 ', ContestIdentity(IOTA).EmitADIFContestFields(qso), 'IOTA reference');

   qso := EmptyQso(WAG);
   qso.QTHString := 'B01';
   CheckEquals('<DOK:3>B01 ', ContestIdentity(WAG).EmitADIFContestFields(qso), 'WAG DOK');

   qso := EmptyQso(ARRLDIGI);
   qso.QTHString := 'FN31';
   CheckEquals('<GRIDSQUARE:4>FN31 ', ContestIdentity(ARRLDIGI).EmitADIFContestFields(qso), 'ARRL Digi grid');
   CheckEquals('<GRIDSQUARE:4>FN31 ', ContestIdentity(WWDIGI).EmitADIFContestFields(qso), 'WW Digi grid');
   CheckEquals('<GRIDSQUARE:4>FN31 ', ContestIdentity(BATAVIA_FT8).EmitADIFContestFields(qso), 'Batavia grid');

   CheckEquals('', ContestIdentity(CQ160CW).EmitADIFContestFields(qso), 'a classless contest: nothing');
   CheckEquals('', ContestIdentity(NASPRINTCW).EmitADIFContestFields(qso),
               'the NA Sprint: nothing -- D6''s no-op arm said the same');
end;

procedure TContestExportTests.Test_ADIFContestIdAndPowerTag;
begin
   BeginTest('Test_ADIFContestIdAndPowerTag');
   CheckFalse(ContestIdentity(GENERALQSO).WritesADIFContestId, 'General QSO writes no CONTEST_ID');
   CheckTrue(ContestIdentity(CQWWCW).WritesADIFContestId, 'CQ WW writes one');
   CheckTrue(ContestIdentity(CQ160CW).WritesADIFContestId, 'a classless contest writes one');
   CheckEquals('FOC_NUM', ContestIdentity(FOCMARATHON).ADIFPowerTag, 'FOC: the number is FOC_NUM');
   CheckEquals('RX_PWR', ContestIdentity(ARRLDXCW).ADIFPowerTag, 'ARRL DX: a power');
   CheckEquals('RX_PWR', ContestIdentity(CQ160CW).ADIFPowerTag, 'classless: a power');
end;

(* ---------------------------------------------------------------------------
   THE ROUND TRIP
   --------------------------------------------------------------------------- *)

var
   GRoundTripMy: TMyStationExchange;

(* What PostUnit's tail emitter asks of a contest, without PostUnit's globals:
   the STX_STRING and the contest's own fields. *)
function RoundTripTail(const aQso: ContestExchange): string;
var
   contest: TContestBase;
begin
   contest := ContestIdentity(aQso.ceContest);
   Result := EmitADIFField('STX_STRING',
                           Trim(contest.FormatADIFSentExchange(GRoundTripMy, aQso,
                                                               contest.ExchangeKind)));
   if aQso.QTHString <> '' then
      begin
      Result := Result + contest.EmitADIFContestFields(aQso);
      end;
end;

procedure TContestExportTests.Test_RoundTripThroughTodaysImport;

   procedure RoundTrip(aContest: ContestType; const aQTH: string);
   var
      qso, back: ContestExchange;
      temps: TADIFRecordTemps;
      fields: TADIFFieldList;
      text, what, stx: string;
      contest: TContestBase;
   begin
      what := string(ContestTypeSA[aContest]);
      contest := ContestIdentity(aContest);

      qso := EmptyQso(aContest);
      qso.Callsign := 'K1ABC';
      qso.Band := Band20;
      qso.Mode := CW;
      qso.ExtMode := eCW;
      qso.Frequency := 14025000;
      qso.tSysTime.qtYear := 26;
      qso.tSysTime.qtMonth := 1;
      qso.tSysTime.qtDay := 15;
      qso.tSysTime.qtHour := 12;
      qso.tSysTime.qtMinute := 1;
      qso.RSTSent := 599;
      qso.RSTReceived := 579;
      qso.NumberSent := 7;
      qso.NumberReceived := 12;
      qso.QTHString := aQTH;
      qso.DomesticQTH := aQTH;
      qso.Precedence := 'A';
      qso.Check := 72;
      qso.Name := 'JOE';
      qso.Power := '100';
      qso.ceClass := '2A';
      qso.QTH.CountryID := 'K';
      qso.TenTenNum := $FFFF;

      stx := Trim(contest.FormatADIFSentExchange(GRoundTripMy, qso, contest.ExchangeKind));
      text := EmitADIFRecord(qso) + RoundTripTail(qso) + '<EOR>';

      CheckTrue(ParseADIFFieldsList(text, fields), what + ': the record lexes');
      InitContestExchangeForParse(back);
      InitADIFRecordTemps(temps);
      CheckTrue(ApplyADIFFieldsToExchange(fields, back, temps), what + ': the record maps');

      CheckEquals('K1ABC', string(back.Callsign), what + ': CALL');
      CheckEquals(Ord(Band20), Ord(back.Band), what + ': BAND');
      CheckEquals(Ord(CW), Ord(back.Mode), what + ': MODE');
      CheckEquals(599, back.RSTSent, what + ': RST_SENT');
      CheckEquals(579, back.RSTReceived, what + ': RST_RCVD');
      CheckEquals(7, back.NumberSent, what + ': STX');
      CheckEquals(12, back.NumberReceived, what + ': SRX');
      CheckEquals(aQTH, string(back.QTHString), what + ': QTH');
      CheckEquals('A', string(back.Precedence), what + ': PRECEDENCE');
      CheckEquals(72, back.Check, what + ': CHECK');
      CheckEquals('JOE', string(back.Name), what + ': NAME');
      CheckEquals(stx, temps.STX_String, what + ': STX_STRING is the class''s sent exchange');

      if contest.WritesADIFContestId then
         begin
         CheckEquals(Ord(aContest), Ord(back.ceContest), what + ': CONTEST_ID names it');
         end;

      if contest.ADIFPowerTag = 'RX_PWR' then
         begin
         CheckEquals('100', string(back.Power), what + ': RX_PWR');
         end
      else
         begin
         CheckEquals('100', temps.FOC_Num, what + ': the power field went to ' + contest.ADIFPowerTag);
         end;

      if aContest in [ARRLFIELDDAY, WINTERFIELDDAY] then
         begin
         CheckEquals(aQTH, temps.ARRL_Sect, what + ': ARRL_SECT');
         CheckEquals('2A', string(back.ceClass), what + ': CLASS');
         CheckEquals('FL', temps.State, what + ': STATE from the section');
         end;
      if aContest in [ARRLSSCW, ARRLSSSSB] then
         begin
         CheckEquals(aQTH, temps.ARRL_Sect, what + ': ARRL_SECT');
         end;
      if aContest = IARU then
         begin
         CheckEquals(aQTH, temps.APP_HQ, what + ': APP_TR4W_HQ');
         end;
      if aContest in [ARRLDIGI, WWDIGI, BATAVIA_FT8] then
         begin
         CheckEquals(aQTH, temps.GridSquare, what + ': GRIDSQUARE');
         end;
      (* EXPORTED AND NOT IMPORTED -- the import arm is M5's. Pinned so the
         day it exists this assertion is what changes. *)
      if aContest = WAG then
         begin
         CheckTrue(Pos('<DOK:3>' + aQTH, text) > 0, what + ': DOK is exported');
         end;
      if aContest = IOTA then
         begin
         CheckTrue(Pos('<IOTA:', text) > 0, what + ': IOTA is exported');
         end;
   end;

begin
   BeginTest('Test_RoundTripThroughTodaysImport');
   GRoundTripMy := EmptyMy;
   GRoundTripMy.MyState := 'FL';
   GRoundTripMy.MyGrid := 'EL88';
   GRoundTripMy.MyName := 'TOM';
   GRoundTripMy.MyZone := '5';
   GRoundTripMy.MyFDClass := '1D';
   GRoundTripMy.MySection := 'WCF';
   GRoundTripMy.MyCheck := '84';
   GRoundTripMy.MyPrec := 'A';
   GRoundTripMy.MyFOCNumber := '1234';

   (* Every class that formats its exchange, or its fields, itself. *)
   RoundTrip(ARRLSSCW, 'CT');
   RoundTrip(ARRLSSSSB, 'CT');
   RoundTrip(ARRLDXCW, 'CT');
   RoundTrip(ARRLDXSSB, 'CT');
   RoundTrip(CQWPXCW, 'CT');
   RoundTrip(CQWPXSSB, 'CT');
   RoundTrip(CQWWCW, 'CT');
   RoundTrip(CQWWSSB, 'CT');
   RoundTrip(FLORIDAQSOPARTY, 'LEE');
   RoundTrip(GENERALQSO, 'CT');
   RoundTrip(IARU, 'ARRL');
   RoundTrip(NASPRINTCW, 'CT');
   RoundTrip(ARRLFIELDDAY, 'WCF');
   RoundTrip(WINTERFIELDDAY, 'WCF');
   RoundTrip(CALQSOPARTY, 'LAX');
   RoundTrip(FOCMARATHON, 'CT');
   RoundTrip(UKRAINECHAMPIONSHIP, 'KV');
   RoundTrip(CUPURAL, 'KV');
   RoundTrip(UKEI, 'LN');
   RoundTrip(IOTA, 'EU-005');
   RoundTrip(DARC10M, 'B01');
   RoundTrip(PACC, 'NH');
   RoundTrip(PCC, 'CT');
   RoundTrip(WAG, 'B01');
   RoundTrip(ARRLDIGI, 'FN31');
   RoundTrip(WWDIGI, 'FN31');
   RoundTrip(BATAVIA_FT8, 'FN31');
end;

procedure TContestExportTests.RunAllTests;
begin
   Test_ClasslessContestGetsTheSharedArm;
   Test_EveryContestFormatsItsOwnExchange;
   Test_FOCMarathonSendsItsMembershipNumber;
   Test_UkraineAndUralPutTheQTHFirst;
   Test_UKEIAndIOTAFillAnEmptyQTH;
   Test_DARC10MReceivedColumn;
   Test_PACCSendsItsSerial;
   Test_PCCSendsItsSerialNeverItsState;
   Test_CaliforniaAndWWDigiChooseTheirQTH;
   Test_SweepstakesColumns;
   Test_SweepstakesEmptyPrecedenceIsABlankNotANul;
   Test_FieldDayColumns;
   Test_FieldDayDXIsNeverAnARRLSection;
   Test_StateFromARRLSection;
   Test_ContestFieldsOfTheOtherOwners;
   Test_ADIFContestIdAndPowerTag;
   Test_RoundTripThroughTodaysImport;
end;

end.
