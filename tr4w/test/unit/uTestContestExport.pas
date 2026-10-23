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
  (uADIF.ApplyADIFFieldsToExchange) and then the contest's own interpretation
  (uADIF.InterpretADIFRecord, M5a), and the fields compared. Since M5a the two
  fields that used to go out and not come back are read by their classes: WAG's
  DOK is its QTH and the RSGB IOTA's IOTA is its domestic QTH.

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
      procedure Test_AContestWithNoRuleOfItsOwnCallsAHelper;
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
      procedure Test_ADIFStateIsTheWorkedStations;
      procedure Test_EveryPartyAndOnlyAPartyWritesAState;
      procedure Test_BCQPExportsStateBCAndNoCounty;
   end;

implementation

uses
   SysUtils, VC, uContestBase, uContestRegistry, uADIF,
   uARRLSections, uCabrilloExchange,
   (* TContestStateQSOPartyBase -- which contests are state parties (Q76). *)
   uContestStateQSOPartyBase,
   (* ContestsToWalk -- the invariants walk the registry (Q108 S1). *)
   uTestRegisteredContests;

function EmptyQso(aContest: ContestType): ContestExchange;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.ceContest := ContestHandleOf(aContest);
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
function Ctx(const aRST, aHisQTH: string): TCabrilloQSOContext;
begin
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

(* A CONTEST WITH NO EXPORT RULE OF ITS OWN CALLS A SHARED HELPER -- the bytes
   uTestCabrilloExchange pins on the helper itself, and uTestCabrilloColumns on
   every contest. The Pennsylvania QP and the Virginia QP each state the
   serial-and-state layout and nothing else; the classless DUMMYCONTEST states
   nothing, so it writes the marker. *)
procedure TContestExportTests.Test_AContestWithNoRuleOfItsOwnCallsAHelper;
var
   qso: ContestExchange;
   my: TMyStationExchange;
   c: TCabrilloQSOContext;
begin
   BeginTest('Test_AContestWithNoRuleOfItsOwnCallsAHelper');
   qso := EmptyQso(PAQSOPARTY);
   qso.NumberSent := 12;
   qso.NumberReceived := 34;
   my := EmptyMy;
   my.MyState := 'FL';
   c := Ctx('', 'GA');
   CheckEquals('12   FL    ', Sent(PAQSOPARTY, my, qso, c), 'a class with no export rule: the sent column');
   CheckEquals('0034 GA    ', Received(PAQSOPARTY, my, qso, c), 'a class with no export rule: the received column');
   CheckEquals('12   FL    ', Sent(VAQP, my, qso, c), 'another class stating the same helper');
   CheckEquals(CabrilloExchangeErrorMarker, Sent(DUMMYCONTEST, my, qso, c),
               'a classless contest: the marker, sent');
   CheckEquals(CabrilloExchangeErrorMarker, Received(DUMMYCONTEST, my, qso, c),
               'a classless contest: the marker, received');
   CheckEquals(CabrilloQSOLineFormatDefault, ContestIdentity(PAQSOPARTY).CabrilloQSOLineFormat,
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
      context := Ctx('599', 'GA');
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
   c := Ctx('599', '');
   CheckEquals('599 5678   ', Sent(FOCMARATHON, my, qso, c), 'FOC MyEx: my FOC number');
   CheckEquals('599 1234   ', Received(FOCMARATHON, my, qso, c), 'FOC HisEx: his number, from Power');
   CheckEquals('599 5678   ',
               ContestIdentity(FOCMARATHON).FormatADIFSentExchange(my, qso),
               'FOC STX_STRING: my FOC number');
   CheckEquals('599 FL     ', Sent(OLDNEWYEAR, my, qso, c),
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
   c := Ctx('', 'GA');

   qso := EmptyQso(UKRAINECHAMPIONSHIP);
   qso.NumberSent := 12;
   qso.NumberReceived := 34;
   CheckEquals('FL   0012  ', Sent(UKRAINECHAMPIONSHIP, my, qso, c), 'Ukraine MyEx');
   CheckEquals('GA   0034  ', Received(UKRAINECHAMPIONSHIP, my, qso, c), 'Ukraine HisEx');

   qso.ceContest := ContestHandleOf(CUPURAL);
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
   c := Ctx('599', '');

   qso := EmptyQso(UKEI);
   qso.NumberSent := 12;
   qso.NumberReceived := 34;
   CheckEquals('599 0034   --', Received(UKEI, my, qso, c), 'UK/EI: no QTH is --');
   CheckEquals('599 0012     FL      ', Sent(UKEI, my, qso, c), 'UK/EI MyEx: the shared arm');

   qso.ceContest := ContestHandleOf(IOTA);
   CheckEquals('599 0034 ------', Received(IOTA, my, qso, c), 'IOTA: no island is ------');

   qso.ceContest := ContestHandleOf(UKEI);
   qso.QTHString := 'EU';
   c := Ctx('599', 'EU');
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
   c := Ctx('599', 'GA');
   CheckEquals('599 0034  GA', Received(DARC10M, my, qso, c), 'DARC 10 m: a three-wide DOK');
   CheckEquals('599 0034   GA', Received(UBACW, my, qso, c), 'the shared helper: four wide');
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
   c := Ctx('599', 'NH');
   CheckEquals('599 7      ', Sent(PACC, my, qso, c), 'PACC MyEx: the serial in the state column');
   CheckEquals('599 NH     ', Received(PACC, my, qso, c), 'PACC HisEx: the shared arm');
   CheckEquals('599 7      ',
               ContestIdentity(PACC).FormatADIFSentExchange(my, qso),
               'PACC STX_STRING: the serial');
   CheckEquals('599 FL     ', Sent(OLDNEWYEAR, my, qso, c), 'any other contest sends the state');
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
   c := Ctx('599', '');

   my.MyState := '014';
   CheckEquals('599  0007/M   ', Sent(PCC, my, qso, c), 'PCC MyEx: an all-digit MY STATE adds /M');
   CheckEquals('599 031', Received(PCC, my, qso, c), 'PCC HisEx: the shared arm');
   CheckEquals('599    7/M   ',
               ContestIdentity(PCC).FormatADIFSentExchange(my, qso),
               'PCC STX_STRING: /M');

   my.MyState := 'FL';
   CheckEquals('599  0007   ', Sent(PCC, my, qso, c), 'PCC MyEx: never the state');
   CheckEquals('599 FL     ', Sent(OLDNEWYEAR, my, qso, c), 'any other contest sends the state');
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
   c := Ctx('', 'XYZ');
   CheckEquals('0034 LAX   ', Received(CALQSOPARTY, my, qso, c),
               'California: the QSO''s QTHString, not the exporter''s choice');
   qso.DomMultQTH := '';
   CheckEquals('0034 DX    ', Received(CALQSOPARTY, my, qso, c),
               'California: no domestic multiplier is DX');

   qso := EmptyQso(WWDIGI);
   qso.QTHString := 'FN31';
   qso.DomesticQTH := 'fn31';
   c := Ctx('', 'fn31');
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
   c := Ctx('', 'SC');
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
   c := Ctx('', '');
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
   c := Ctx('', 'SC');
   CheckEquals('3A  GA      ', Sent(ARRLFIELDDAY, my, qso, c), 'FD MyEx');
   CheckEquals('2A  SC     ', Received(ARRLFIELDDAY, my, qso, c), 'FD HisEx');
   CheckEquals('3A  GA      ',
               ContestIdentity(ARRLFIELDDAY).FormatADIFSentExchange(my, qso),
               'FD STX_STRING');
   CheckEquals('2A  SC     ', Received(WINTERFIELDDAY, my, qso, c), 'WFD HisEx');
end;

(* NY4I, 2026-10-01 (design Q1): "DX IS NOT AN ARRL SECTION." A DX station
   sends a class and DX; the DX goes in the section POSITION of the Cabrillo
   line and never into ADIF ARRL_SECT. Pinned for both Field Days.

   AND SINCE M5b (NY4I 2026-10-02, design 7.10, Q20): the DX station's ADIF
   CLASS is the class it was logged with, and its SRX_STRING is the full
   received exchange, '1D DX' -- whether the operator typed the DX or the
   class alone resolved to it. A domestic QSO's SRX_STRING is unchanged: the
   typed exchange. *)
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
      c := Ctx('', 'DX');
      CheckEquals('1D  DX     ', Received(fd, my, qso, c),
                  string(ContestTypeSA[fd]) + ': DX in the section position of the line');
      CheckEquals('<CLASS:2>1D ', ContestIdentity(fd).EmitADIFContestFields(qso),
                  string(ContestTypeSA[fd]) + ': DX writes its CLASS and no ARRL_SECT, STATE or DXCC');
      qso.ExchString := '1D';
      CheckEquals('1D DX', ContestIdentity(fd).FormatADIFReceivedExchange(qso, False),
                  string(ContestTypeSA[fd]) + ': SRX_STRING is the class and DX, though only the class was typed');
      qso.ExchString := '1D DX';
      CheckEquals('1D DX', ContestIdentity(fd).FormatADIFReceivedExchange(qso, False),
                  string(ContestTypeSA[fd]) + ': SRX_STRING when DX was typed');

      qso.QTHString := 'WCF';
      qso.QTH.CountryID := 'K';
      qso.ExchString := '1D WCF';
      CheckEquals('1D WCF', ContestIdentity(fd).FormatADIFReceivedExchange(qso, False),
                  string(ContestTypeSA[fd]) + ': a section''s SRX_STRING is the typed exchange');
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

   CheckEquals('', ContestIdentity(ARRL10).EmitADIFContestFields(qso), 'a classless contest: nothing');
   CheckEquals('', ContestIdentity(NASPRINTCW).EmitADIFContestFields(qso),
               'the NA Sprint: nothing -- D6''s no-op arm said the same');
end;

procedure TContestExportTests.Test_ADIFContestIdAndPowerTag;
begin
   BeginTest('Test_ADIFContestIdAndPowerTag');
   CheckFalse(ContestIdentity(GENERALQSO).WritesADIFContestId, 'General QSO writes no CONTEST_ID');
   CheckTrue(ContestIdentity(CQWWCW).WritesADIFContestId, 'CQ WW writes one');
   CheckTrue(ContestIdentity(ARRL10).WritesADIFContestId, 'a classless contest writes one');
   CheckEquals('FOC_NUM', ContestIdentity(FOCMARATHON).ADIFPowerTag, 'FOC: the number is FOC_NUM');
   CheckEquals('RX_PWR', ContestIdentity(ARRLDXCW).ADIFPowerTag, 'ARRL DX: a power');
   CheckEquals('RX_PWR', ContestIdentity(ARRL10).ADIFPowerTag, 'classless: a power');
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
                           Trim(contest.FormatADIFSentExchange(GRoundTripMy, aQso)));
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
      declared: ExchangeInformationRecord;
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

      stx := Trim(contest.FormatADIFSentExchange(GRoundTripMy, qso));
      text := EmitADIFRecord(qso) + RoundTripTail(qso) + '<EOR>';

      CheckTrue(ParseADIFFieldsList(text, fields), what + ': the record lexes');
      InitContestExchangeForParse(back);
      InitADIFRecordTemps(temps);
      CheckTrue(ApplyADIFFieldsToExchange(fields, back, temps), what + ': the record maps');
      (* THEN THE CONTEST NAMED BY CONTEST_ID READS WHAT THE MAPPING CAPTURED.
         No session: nothing here is running a contest. *)
      InterpretADIFRecord(temps, NeutralADIFImportSession, back);

      CheckEquals('K1ABC', string(back.Callsign), what + ': CALL');
      CheckEquals(Ord(Band20), Ord(back.Band), what + ': BAND');
      CheckEquals(Ord(CW), Ord(back.Mode), what + ': MODE');
      (* THE RECEIVED EXCHANGE COMES BACK EXACTLY AS FAR AS THE CLASS DECLARES
         IT (2026-10-17): the QSO above has every field filled, and export
         writes only the ones the contest's own ReceivedExchangeFields names
         (TContestBase.EmitADIFReceivedFields). A declared field must come
         back; an undeclared one must not have been written at all. *)
      declared := contest.ReceivedExchangeFields;
      CheckTrue(Pos('<RST_SENT:', text) > 0, what + ': RST_SENT, every QSO''s (NY4I, 2026-10-17)');
      CheckTrue(Pos('<RST_RCVD:', text) > 0, what + ': RST_RCVD, every QSO''s (NY4I, 2026-10-17)');
      CheckEquals(Ord(declared.QSONumber), Ord(Pos('<SRX:', text) > 0), what + ': SRX only if declared');
      CheckEquals(Ord(declared.QTH), Ord(Pos('<QTH:', text) > 0), what + ': QTH only if declared');
      CheckEquals(Ord(declared.Precedence), Ord(Pos('<PRECEDENCE:', text) > 0), what + ': PRECEDENCE only if declared');
      CheckEquals(Ord(declared.Check), Ord(Pos('<CHECK:', text) > 0), what + ': CHECK only if declared');
      CheckEquals(Ord(declared.Name), Ord(Pos('<NAME:', text) > 0), what + ': NAME only if declared');
      CheckEquals(Ord(declared.Power),
                  Ord((Pos('<RX_PWR:', text) > 0) or (Pos('<FOC_NUM:', text) > 0)),
                  what + ': the power only if declared');
      CheckTrue(Pos('<TEN_TEN:', text) = 0, what + ': no 10-10 number, none declared and none set');
      CheckTrue(Pos('<AGE:', text) = 0, what + ': no age, none declared and none set');
      CheckEquals(599, back.RSTSent, what + ': RST_SENT');
      CheckEquals(579, back.RSTReceived, what + ': RST_RCVD');
      CheckEquals(7, back.NumberSent, what + ': STX');
      if declared.QSONumber then
         begin
         CheckEquals(12, back.NumberReceived, what + ': SRX');
         end;
      if declared.QTH then
         begin
         CheckEquals(aQTH, string(back.QTHString), what + ': QTH');
         end;
      if declared.Precedence then
         begin
         CheckEquals('A', string(back.Precedence), what + ': PRECEDENCE');
         end;
      if declared.Check then
         begin
         CheckEquals(72, back.Check, what + ': CHECK');
         end;
      if declared.Name then
         begin
         CheckEquals('JOE', string(back.Name), what + ': NAME');
         end;
      CheckEquals(stx, temps.STX_String, what + ': STX_STRING is the class''s sent exchange');

      if contest.WritesADIFContestId then
         begin
         CheckEquals(Ord(aContest), back.ceContest.ToByte, what + ': CONTEST_ID names it');
         end;

      if declared.Power then
         begin
         if contest.ADIFPowerTag = 'RX_PWR' then
            begin
            CheckEquals('100', string(back.Power), what + ': RX_PWR');
            end
         else
            begin
            CheckEquals('100', temps.FOC_Num, what + ': the power field went to ' + contest.ADIFPowerTag);
            end;
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
      if aContest = FOCMARATHON then
         begin
         CheckEquals('100', string(back.Power), what + ': the class reads FOC_NUM into Power');
         end;
      (* EXPORTED, AND NOW READ BACK BY THE CLASS THAT WROTE THEM (M5a). Both
         assertions would fail on the generic mapping alone: WAG's SRX_STRING
         is the received RST and the QTH tag is not what the class keeps; the
         island is in no standard tag. *)
      if aContest = WAG then
         begin
         CheckTrue(Pos('<DOK:3>' + aQTH, text) > 0, what + ': DOK is exported');
         CheckEquals(aQTH, temps.DOK, what + ': DOK is captured');
         CheckEquals(aQTH, string(back.QTHString), what + ': DOK is the QTH again');
         end;
      if aContest = IOTA then
         begin
         CheckTrue(Pos('<IOTA:', text) > 0, what + ': IOTA is exported');
         CheckEquals(aQTH, temps.IOTA, what + ': IOTA is captured');
         CheckEquals(aQTH, string(back.DomesticQTH), what + ': the island is the domestic QTH again');
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

(* Q76/Q89 (NY4I, 2026-10-16): THE ADIF STATE IS THE WORKED STATION'S.

   "ADIF typically prefaces the local station fields with MY_ (as in
   MY_STATE). So if you write STATE in ADIF, that is the state of the worked
   station." Until then -- and in D7 -- a party wrote its HOST's state on every
   QSO carrying a QTH (a Michigan log: STATE:MI for a station in DC), and
   British Columbia wrote none.

   THE RULE, PINNED PER PARTY AND PER WORKED STATION: a host county gives the
   county's state; an out-of-state station's state or a VE's province gives
   itself when ADIF allows that code for the station's country; DX, or a code
   ADIF does not allow for that country, gives none. The key is the domestic
   table's (DomesticQTH) when there is one, else the logged QTH. *)
function PartyQSO(aContest: TContestHandle;
                  const aQTH, aDomesticKey, aCountryID: string): ContestExchange; overload;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.ceContest := aContest;
   Result.Callsign := 'K1ABC';
   Result.Band := Band20;
   Result.Mode := CW;
   Result.QTHString := ShortString(aQTH);
   Result.DomesticQTH := ShortString(aDomesticKey);
   Result.QTH.CountryID := ShortString(aCountryID);
end;

(* A LEGACY CONTEST BY ITS MEMBER -- the pins below name legacy contests. A
   registry walk passes the HANDLE (HandleOf): a contest registered by its id
   has no member, and ContestOf answers DUMMYCONTEST for it, so a QSO built
   from the member would ask "no contest" and pass or fail for the wrong
   contest (found adding the Georgia QSO Party, 2026-10-23). *)
function PartyQSO(aContest: ContestType;
                  const aQTH, aDomesticKey, aCountryID: string): ContestExchange; overload;
begin
   Result := PartyQSO(ContestHandleOf(aContest), aQTH, aDomesticKey, aCountryID);
end;

procedure TContestExportTests.Test_ADIFStateIsTheWorkedStations;

   procedure Pin(aContest: ContestType; const aQTH, aKey, aCountry, aExpected: string);
   begin
      CheckEquals(aExpected,
                  GetADIFStateForQSO(PartyQSO(aContest, aQTH, aKey, aCountry)),
                  string(ContestTypeSA[aContest]) + ': QTH ' + aQTH + ' key ' +
                  aKey + ' country ' + aCountry);
   end;

begin
   BeginTest('Test_ADIFStateIsTheWorkedStations');

   (* A SINGLE-STATE PARTY: Florida. *)
   Pin(FLORIDAQSOPARTY, 'LEE', 'Lee', 'K', 'FL');      (* in-state county *)
   Pin(FLORIDAQSOPARTY, 'MON', '', 'K', 'FL');         (* no key: the logged QTH *)
   Pin(FLORIDAQSOPARTY, 'CT', 'Ct', 'K', 'CT');        (* out-of-state station *)
   Pin(FLORIDAQSOPARTY, 'CON', 'Ct', 'K', 'CT');       (* an alias: the key decides *)
   Pin(FLORIDAQSOPARTY, 'DC', 'DC', 'K', 'DC');        (* DC is a 291 subdivision *)
   Pin(FLORIDAQSOPARTY, 'AK', 'Ak', 'KL', 'AK');       (* Alaska, DXCC 6 *)
   Pin(FLORIDAQSOPARTY, 'HI', 'Hi', 'KH6', 'HI');      (* Hawaii, DXCC 110 *)
   Pin(FLORIDAQSOPARTY, 'ON', 'On', 'VE', 'ON');       (* a VE's province *)
   Pin(FLORIDAQSOPARTY, 'DX', 'dx', 'DL', '');         (* DX: no STATE *)
   Pin(FLORIDAQSOPARTY, 'ON', 'On', 'K', '');          (* not a US code: none invented *)
   Pin(FLORIDAQSOPARTY, 'AK', 'Ak', 'K', '');          (* Alaska is not DXCC 291 *)
   Pin(FLORIDAQSOPARTY, 'CT', 'Ct', '', '');           (* unknown country: none *)

   (* THE CORPUS'S MICHIGAN LOG: four out-of-state stations. *)
   Pin(MICHQSOPARTY, 'DC', 'DC', 'K', 'DC');
   Pin(MICHQSOPARTY, 'OH', 'Oh', 'K', 'OH');
   Pin(MICHQSOPARTY, 'MAR', 'Mar', 'K', 'MI');

   (* BRITISH COLUMBIA: a regional district is BC. *)
   Pin(BCQP, 'ABF', 'Abf', 'VE', 'BC');
   Pin(BCQP, 'CT', 'Ct', 'K', 'CT');
   Pin(BCQP, 'ON', 'On', 'VE', 'ON');
   Pin(BCQP, 'DX', 'dx', 'DL', '');

   (* DELAWARE: its counties are three letters. *)
   Pin(DELAWAREQSOPARTY, 'NDE', 'NDE', 'K', 'DE');
   Pin(DELAWAREQSOPARTY, 'MD', 'Md', 'K', 'MD');

   (* NEBRASKA: its counties are four letters (2026-10-16). *)
   Pin(NEBRASKAQSO, 'LNCS', 'LNCS', 'K', 'NE');
   Pin(NEBRASKAQSO, 'KS', 'Ks', 'K', 'KS');
   Pin(NEBRASKAQSO, 'DX', 'dx', 'DL', '');

   (* THE 7QP: keys lead with the state. *)
   Pin(SEVENQP, 'AZAPH', 'Azaph', 'K', 'AZ');
   Pin(SEVENQP, 'WAKIN', 'Wakin', 'K', 'WA');
   Pin(SEVENQP, 'CT', 'Ct', 'K', 'CT');
   Pin(SEVENQP, 'BC', 'Bc', 'VE', 'BC');
   Pin(SEVENQP, 'DX', 'dx', 'DL', '');
   Pin(SEVENQP, 'CTCAP', 'CTCap', 'K', '');            (* not a 7th-area state *)

   (* NEW ENGLAND: keys LEAD with the state since Q81 (2026-10-17), the
      sponsor's spelling; NEQSOW1's alias is shorter, and the old
      county-first spelling is typed but never the key. *)
   Pin(NEWENGLANDQSO, 'MEAND', 'MEAnd', 'K', 'ME');
   Pin(NEWENGLANDQSO, 'ANDME', 'MEAnd', 'K', 'ME');
   Pin(NEWENGLANDQSO, 'AD', 'VTAdd', 'K', 'VT');
   Pin(NEWENGLANDQSO, 'CTCAP', 'CTCap', 'K', 'CT');
   Pin(NEWENGLANDQSO, 'VTWAS', 'VTWas', 'K', 'VT');    (* not read as WA *)
   Pin(NEWENGLANDQSO, 'ADDVT', 'AddVT', 'K', '');      (* an old key names no state now *)
   Pin(NEWENGLANDQSO, 'FL', 'Fl', 'K', 'FL');
   Pin(NEWENGLANDQSO, 'QC', 'Qc', 'VE', 'QC');
   Pin(NEWENGLANDQSO, 'DX', 'dx', 'DL', '');

   (* IN7QPNE: the composite's own routing (in7qpne_cty.dom's spelling). *)
   Pin(IN7QPNE, 'INADA', 'Inada', 'K', 'IN');
   Pin(IN7QPNE, 'AZAPH', 'Azaph', 'K', 'AZ');
   Pin(IN7QPNE, 'MEAND', 'MEAnd', 'K', 'ME');
   Pin(IN7QPNE, 'NDE', 'NDE', 'K', 'DE');
   Pin(IN7QPNE, 'TX', 'Tx', 'K', 'TX');
   Pin(IN7QPNE, 'ON', 'On', 'VE', 'ON');
   Pin(IN7QPNE, 'DX', 'dx', 'DL', '');

   (* NOT A QSO PARTY: no STATE in the record body, whatever the QTH. *)
   Pin(CQWWCW, 'CT', 'Ct', 'K', '');
   Pin(ARRLDXCW, 'CT', 'Ct', 'K', '');
   Pin(ARRLFIELDDAY, 'CT', 'Ct', 'K', '');

   (* THE ENUMERATION ITSELF, at its edges. *)
   CheckTrue(IsADIFPrimarySubdivision('K', 'DC'), 'DC is DXCC 291');
   CheckFalse(IsADIFPrimarySubdivision('K', 'HI'), 'HI is not DXCC 291');
   CheckTrue(IsADIFPrimarySubdivision('VE', 'NU'), 'Nunavut is DXCC 1');
   CheckFalse(IsADIFPrimarySubdivision('VE', 'NF'), 'NF is not an ADIF code');
   CheckFalse(IsADIFPrimarySubdivision('K', 'D'), 'one letter is no code');
end;

(* EVERY CONTEST: which ones answer at all, and where CNTY is written.

   An out-of-state station in Connecticut gets STATE:CT from exactly the QSO
   parties -- every state party (TContestStateQSOPartyBase), the 7QP, New
   England and IN7QPNE -- and nothing from any other contest. CNTY is
   written by every state party but British Columbia (ADIF has no Canadian
   county enumeration), and by no multi-state party, as before. A state
   party's host county is its HostState, a two-letter code. *)
procedure TContestExportTests.Test_EveryPartyAndOnlyAPartyWritesAState;
var
   contests: TContestIdentityList;
   k: integer;
   c: ContestType;
   identity: TContestBase;
   isStateParty: boolean;
   isParty: boolean;
begin
   BeginTest('Test_EveryPartyAndOnlyAPartyWritesAState');
   (* AN INVARIANT OVER THE REGISTRY (Q108 S1), not a count: a contest writes
      a worked station's STATE exactly where it is a QSO party, and "is a QSO
      party" is the rover-split answer, which uTestContestFactory pins for
      every legacy contest (ROVER_SPLIT_PARTIES). So a party that forgets one
      of the two answers fails here, by name, and no number moves when a
      party is added. *)
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      identity := contests[k];
      c := ContestOf(identity);
      isStateParty := identity is TContestStateQSOPartyBase;
      isParty := identity.SplitsRoverCallOnExport;
      CheckTrue(isParty or not isStateParty,
                ContestWho(identity) + ': a state party is a QSO party');
      (* THE HANDLE, NEVER c, for the QSO: c is DUMMYCONTEST for a contest
         registered by its id (see PartyQSO). *)
      if isParty then
         begin
         CheckEquals('CT', GetADIFStateForQSO(PartyQSO(HandleOf(identity), 'CT', 'Ct', 'K')),
                     ContestWho(identity) + ': a Connecticut station is CT');
         end
      else
         begin
         CheckEquals('', GetADIFStateForQSO(PartyQSO(HandleOf(identity), 'CT', 'Ct', 'K')),
                     ContestWho(identity) + ': not a QSO party, no STATE');
         end;

      CheckEquals(Ord(isStateParty and (c <> BCQP)), Ord(identity.WritesADIFCounty),
                  ContestWho(identity) + ': CNTY exactly for the state parties but BC');

      if isStateParty then
         begin
         CheckEquals(2, Length(identity.HostState),
                     ContestWho(identity) + ': the host is a two-letter code');
         CheckEquals(identity.HostState,
                     GetADIFStateForQSO(PartyQSO(HandleOf(identity), 'XYZ', 'Xyz', 'K')),
                     ContestWho(identity) + ': a host county is the host''s state');
         end;
      end;

   (* The three multi-state parties, by name -- they are not on the base. *)
   CheckTrue(ContestIdentity(SEVENQP).SplitsRoverCallOnExport, '7QP is a QSO party');
   CheckTrue(ContestIdentity(NEWENGLANDQSO).SplitsRoverCallOnExport, 'New England is a QSO party');
   CheckTrue(ContestIdentity(IN7QPNE).SplitsRoverCallOnExport, 'IN7QPNE is a QSO party');
end;

(* THE EXPORTED RECORD ITSELF: a worked BC station's QSO carries STATE:BC,
   a Florida QSO still carries STATE:FL. (CNTY is PostUnit's tail, asked
   through WritesADIFCounty above; the record here is uADIF's body.) *)
procedure TContestExportTests.Test_BCQPExportsStateBCAndNoCounty;
var
   qso: ContestExchange;
   text: string;
begin
   BeginTest('Test_BCQPExportsStateBCAndNoCounty');
   FillChar(qso, SizeOf(qso), 0);
   qso.ceContest := ContestHandleOf(BCQP);
   qso.Band := Band20;
   qso.Mode := CW;
   qso.Callsign := 'VE7ABC';
   qso.QTHString := 'ABF';
   qso.DomesticQTH := 'ABF';
   text := EmitADIFRecord(qso);
   CheckTrue(Pos('<STATE:2>BC ', text) > 0, 'BCQP writes STATE:BC: ' + text);
   CheckTrue(Pos('<CNTY', text) = 0, 'and the body writes no CNTY: ' + text);

   qso.ceContest := ContestHandleOf(FLORIDAQSOPARTY);
   qso.Callsign := 'K4ABC';
   qso.QTHString := 'LEE';
   qso.DomesticQTH := 'LEE';
   text := EmitADIFRecord(qso);
   CheckTrue(Pos('<STATE:2>FL ', text) > 0, 'Florida still writes STATE:FL: ' + text);

   (* Q76: an out-of-state station's record carries ITS state, not the
      host's -- the corpus's Michigan QSO with W3ED in DC. *)
   qso.ceContest := ContestHandleOf(MICHQSOPARTY);
   qso.Callsign := 'W3ED';
   qso.QTHString := 'DC';
   qso.DomesticQTH := 'DC';
   qso.QTH.CountryID := 'K';
   text := EmitADIFRecord(qso);
   CheckTrue(Pos('<STATE:2>DC ', text) > 0, 'Michigan, W3ED in DC: STATE:DC: ' + text);
   CheckTrue(Pos('<STATE:2>MI ', text) = 0, 'and not the host''s MI: ' + text);
end;

procedure TContestExportTests.RunAllTests;
begin
   Test_AContestWithNoRuleOfItsOwnCallsAHelper;
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
   Test_ADIFStateIsTheWorkedStations;
   Test_EveryPartyAndOnlyAPartyWritesAState;
   Test_BCQPExportsStateBCAndNoCounty;
end;

end.
