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

(* THE ADIF EXCHANGE FIELDS A RECORD CARRIES ARE THE CONTEST'S -- 2026-10-17
  (NY4I: "We should not just be exporting all possible fields"; design
  docs/CONTEST_OWNERSHIP_DESIGN.md, ADIF exchange-field selection).

  THE DEFECT THIS STOPS. uADIF.EmitADIFRecord wrote QTH, PRECEDENCE, CHECK,
  NAME, the power tag, SRX, TEN_TEN and AGE whenever the field was non-empty,
  never asking the contest whether the field is part of its exchange. The
  contest matrix fills every field of every QSO on purpose, and showed a POTA
  record exporting <PRECEDENCE:1>A <CHECK:2>99 <TEN_TEN:5>00000 <AGE:3>040
  <NAME:3>JOE. POTA has none of those.

  THE EXHAUSTIVE PIN. For EVERY registered contest, a QSO with EVERY field
  filled exports exactly the exchange tags its own ReceivedExchangeFields
  declares, and no other exchange tag -- asked of the identity object and,
  because a contest's list can depend on the entrant, of the contest at each
  of the seven roster stations (uTestExchangeFields.TPinStation). The
  expectation is written here from the declaration, tag by tag, and not by
  calling the method under test.

  THE EXCHANGE TAGS are the twelve below. STX is always among them when the
  QSO has a serial: it is our own number, not a received field, and D7 wrote
  it for every contest (see TContestBase.EmitADIFReceivedFields). *)
unit uTestADIFReceivedFields;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TADIFReceivedFieldsTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EveryContestExportsExactlyWhatItDeclares;
      procedure Test_EveryContestAtEveryStationExportsExactlyWhatItDeclares;
      procedure Test_POTAExportsNoSweepstakesTenTenOrKidsFields;
      procedure Test_SweepstakesExportsPrecedenceAndCheck;
      procedure Test_ATenTenContestExportsTheNumberAndNeverAZero;
      procedure Test_AContestWithNoRSTInItsExchangeStillExportsRST;
      procedure Test_TheFOCMarathonNumberGoesToFOCNum;
      procedure Test_OurSerialIsNotAReceivedField;
      procedure Test_ARRLDXAsksTheEntrantsList;
      procedure Test_ALoggedQSOIsJudgedByItsOwnContest;
   end;

implementation

uses
   Classes,
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uADIF,
   uTestRegisteredContests,
   uTestContestObjects,
   uTestExchangeFields;

const
   (* The tags the generic block used to write unconditionally. *)
   EXCHANGE_TAGS: array[0..11] of string = (
      'AGE', 'CHECK', 'APP_TR4W_FOC_NUM', 'NAME', 'PRECEDENCE', 'QTH', 'RST_RCVD',
      'RST_SENT', 'RX_PWR', 'SRX', 'STX', 'TEN_TEN');

(* A QSO with EVERY field of the exchange filled, for aContest. *)
function FullQso(aContest: TContestHandle): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceContest := aContest;
   Result.ceRecordKind := rkQSO;
   Result.Callsign := 'K1ABC';
   Result.Band := Band20;
   Result.Mode := CW;
   Result.Frequency := 14025000;
   Result.RSTSent := 599;
   Result.RSTReceived := 579;
   Result.QTHString := 'CT';
   Result.DomesticQTH := 'CT';
   Result.Precedence := 'A';
   Result.Check := 99;
   Result.Name := 'JOE';
   Result.Power := '100';
   Result.NumberReceived := 7;
   Result.NumberSent := 8;
   Result.TenTenNum := 12345;
   Result.Age := 40;
end;

(* The names of the exchange tags in aText, sorted, one space between. *)
function ExchangeTagsOf(const aText: string): string;
var
   names: TStringList;
   i, start, colon: integer;
   tag: string;
   k: integer;
begin
   names := TStringList.Create;
   try
      names.Sorted := True;
      names.Duplicates := dupIgnore;
      i := 1;
      while i <= Length(aText) do
         begin
         if aText[i] = '<' then
            begin
            start := i + 1;
            colon := start;
            while (colon <= Length(aText)) and
                  (aText[colon] <> ':') and
                  (aText[colon] <> '>') do
               begin
               Inc(colon);
               end;
            tag := UpperCase(Copy(aText, start, colon - start));
            for k := Low(EXCHANGE_TAGS) to High(EXCHANGE_TAGS) do
               begin
               if tag = EXCHANGE_TAGS[k] then
                  begin
                  names.Add(tag);
                  end;
               end;
            i := colon;
            end;
         Inc(i);
         end;
      Result := Trim(StringReplace(names.Text, #13#10, ' ', [rfReplaceAll]));
   finally
      names.Free;
      end;
end;

(* What aContest's declaration says the record carries, written out tag by
   tag -- NOT by asking the method under test. STX is there because the QSO
   has a serial. *)
function ExpectedTags(aContest: TContestBase): string;
var
   declared: ExchangeInformationRecord;
   names: TStringList;
begin
   declared := aContest.ReceivedExchangeFields;
   names := TStringList.Create;
   try
      names.Sorted := True;
      names.Duplicates := dupIgnore;
      names.Add('STX');
      (* The RST pair is EVERY QSO'S (NY4I, 2026-10-17: "Every QSO"),
         whatever the exchange declares. *)
      names.Add('RST_SENT');
      names.Add('RST_RCVD');
      if declared.QTH then
         begin
         names.Add('QTH');
         end;
      if declared.Precedence then
         begin
         names.Add('PRECEDENCE');
         end;
      if declared.Check then
         begin
         names.Add('CHECK');
         end;
      if declared.Name then
         begin
         names.Add('NAME');
         end;
      if declared.Power then
         begin
         names.Add(aContest.ADIFPowerTag);
         end;
      if declared.QSONumber then
         begin
         names.Add('SRX');
         end;
      if declared.TenTenNum then
         begin
         names.Add('TEN_TEN');
         end;
      if declared.Age then
         begin
         names.Add('AGE');
         end;
      Result := Trim(StringReplace(names.Text, #13#10, ' ', [rfReplaceAll]));
   finally
      names.Free;
      end;
end;

function HasTag(const aText, aTag: string): boolean;
begin
   Result := Pos('<' + aTag + ':', aText) > 0;
end;

procedure TADIFReceivedFieldsTests.Test_EveryContestExportsExactlyWhatItDeclares;
var
   contests: TContestIdentityList;
   k: integer;
   qso: ContestExchange;
begin
   BeginTest('Test_EveryContestExportsExactlyWhatItDeclares');
   (* The registry walk (Q108 S1): ContestsToWalk raises below a hundred
      contests, so an emptied registry cannot pass. *)
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      qso := FullQso(HandleOf(contests[k]));
      CheckEquals(ExpectedTags(contests[k]),
                  ExchangeTagsOf(EmitADIFRecord(qso, nil)),
                  ContestWho(contests[k]) + ': exactly the declared exchange tags');
      end;

   (* The classless contest: the base declares no field, so a full record
      carries only the serial we sent. *)
   qso := FullQso(NoContest);
   CheckEquals('RST_RCVD RST_SENT STX', ExchangeTagsOf(EmitADIFRecord(qso, nil)),
               'no contest: no exchange field is declared, the RST and our serial remain');
end;

procedure TADIFReceivedFieldsTests.Test_EveryContestAtEveryStationExportsExactlyWhatItDeclares;
var
   contests: TContestIdentityList;
   k: integer;
   s: TPinStation;
   obj: TContestBase;
   qso: ContestExchange;
   checked: integer;
begin
   BeginTest('Test_EveryContestAtEveryStationExportsExactlyWhatItDeclares');
   (* A contest's list can depend on the entrant (ARRL DX, the Japanese
      JIDX, the Dutch PACC ...): the object that carries the station is the
      one asked. *)
   contests := ContestsToWalk;
   checked := 0;
   for k := 0 to High(contests) do
      begin
      qso := FullQso(HandleOf(contests[k]));
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         obj := NewContestLike(contests[k], PinStation(s, HandleOf(contests[k])));
         try
            CheckEquals(ExpectedTags(obj),
                        ExchangeTagsOf(EmitADIFRecord(qso, obj)),
                        ContestWho(contests[k]) + ' at ' + PinStationCall(s) +
                        ': exactly the declared exchange tags');
         finally
            obj.Free;
            end;
         Inc(checked);
         end;
      end;
   CheckEquals(Length(contests) * (Ord(High(TPinStation)) + 1), checked,
               'every contest was checked at every station');
end;

procedure TADIFReceivedFieldsTests.Test_POTAExportsNoSweepstakesTenTenOrKidsFields;
var
   text: string;
begin
   BeginTest('Test_POTAExportsNoSweepstakesTenTenOrKidsFields');
   text := EmitADIFRecord(FullQso(ContestHandleOf(POTA)), nil);
   CheckFalse(HasTag(text, 'PRECEDENCE'), 'POTA has no precedence: ' + text);
   CheckFalse(HasTag(text, 'CHECK'), 'POTA has no check: ' + text);
   CheckFalse(HasTag(text, 'TEN_TEN'), 'POTA has no 10-10 number: ' + text);
   CheckFalse(HasTag(text, 'AGE'), 'POTA has no age: ' + text);
   CheckFalse(HasTag(text, 'NAME'), 'POTA has no name: ' + text);
   CheckFalse(HasTag(text, 'SRX'), 'POTA has no serial: ' + text);
   CheckFalse(HasTag(text, 'RX_PWR'), 'POTA has no power: ' + text);
   (* and what POTA does exchange is still there *)
   CheckTrue(HasTag(text, 'QTH'), 'POTA exchanges a park (QTH): ' + text);
   CheckTrue(HasTag(text, 'RST_SENT'), 'POTA exchanges an RST: ' + text);
end;

procedure TADIFReceivedFieldsTests.Test_SweepstakesExportsPrecedenceAndCheck;
var
   text: string;
begin
   BeginTest('Test_SweepstakesExportsPrecedenceAndCheck');
   text := EmitADIFRecord(FullQso(ContestHandleOf(ARRLSSCW)), nil);
   CheckTrue(Pos('<PRECEDENCE:1>A ', text) > 0, 'Sweepstakes: PRECEDENCE: ' + text);
   CheckTrue(Pos('<CHECK:2>99 ', text) > 0, 'Sweepstakes: CHECK: ' + text);
   CheckTrue(HasTag(text, 'SRX'), 'Sweepstakes: the serial received: ' + text);
   CheckTrue(HasTag(text, 'QTH'), 'Sweepstakes: the section: ' + text);
   CheckFalse(HasTag(text, 'NAME'), 'Sweepstakes: no name: ' + text);
   CheckFalse(HasTag(text, 'AGE'), 'Sweepstakes: no age: ' + text);
end;

procedure TADIFReceivedFieldsTests.Test_ATenTenContestExportsTheNumberAndNeverAZero;
var
   qso: ContestExchange;
   text: string;
begin
   BeginTest('Test_ATenTenContestExportsTheNumberAndNeverAZero');
   qso := FullQso(ContestHandleOf(TENTEN));
   text := EmitADIFRecord(qso, nil);
   CheckTrue(Pos('<TEN_TEN:5>12345 ', text) > 0, '10-10: the number: ' + text);

   (* A non-member: the parse leaves the unset sentinel ... *)
   qso.TenTenNum := $FFFF;
   CheckFalse(HasTag(EmitADIFRecord(qso, nil), 'TEN_TEN'), 'unset ($FFFF): no TEN_TEN');
   (* ... and a path that leaves it 0 must not write <TEN_TEN:5>00000. *)
   qso.TenTenNum := 0;
   CheckFalse(HasTag(EmitADIFRecord(qso, nil), 'TEN_TEN'), 'zero: no TEN_TEN');

   (* a contest that is not a 10-10 contest writes none, whatever the field
      holds *)
   qso := FullQso(ContestHandleOf(CQWWCW));
   CheckFalse(HasTag(EmitADIFRecord(qso, nil), 'TEN_TEN'), 'CQ WW: no TEN_TEN');
end;

procedure TADIFReceivedFieldsTests.Test_AContestWithNoRSTInItsExchangeStillExportsRST;
var
   contests: TContestIdentityList;
   k: integer;
   text: string;
   sawNoRST: boolean;
begin
   BeginTest('Test_AContestWithNoRSTInItsExchangeStillExportsRST');
   (* NY4I, 2026-10-17: "Every QSO". Sweepstakes and Field Day exchange no
      report, and their records still carry RST_SENT and RST_RCVD, as D7's
      did. *)
   text := EmitADIFRecord(FullQso(ContestHandleOf(ARRLSSCW)), nil);
   CheckTrue(Pos('<RST_SENT:3>599 ', text) > 0, 'Sweepstakes: RST_SENT: ' + text);
   CheckTrue(Pos('<RST_RCVD:3>579 ', text) > 0, 'Sweepstakes: RST_RCVD: ' + text);
   text := EmitADIFRecord(FullQso(ContestHandleOf(ARRLFIELDDAY)), nil);
   CheckTrue(Pos('<RST_SENT:3>599 ', text) > 0, 'Field Day: RST_SENT: ' + text);
   CheckTrue(Pos('<RST_RCVD:3>579 ', text) > 0, 'Field Day: RST_RCVD: ' + text);

   (* and one that does exchange it writes it *)
   text := EmitADIFRecord(FullQso(ContestHandleOf(CQWWCW)), nil);
   CheckTrue(Pos('<RST_SENT:3>599 ', text) > 0, 'CQ WW: RST_SENT: ' + text);
   CheckTrue(Pos('<RST_RCVD:3>579 ', text) > 0, 'CQ WW: RST_RCVD: ' + text);

   (* the invariant, over the registry: every contest writes the pair, and
      the walk does meet contests whose exchange declares none *)
   sawNoRST := False;
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      text := EmitADIFRecord(FullQso(HandleOf(contests[k])), nil);
      CheckTrue(HasTag(text, 'RST_SENT'), ContestWho(contests[k]) + ': RST_SENT');
      CheckTrue(HasTag(text, 'RST_RCVD'), ContestWho(contests[k]) + ': RST_RCVD');
      if not contests[k].ReceivedExchangeFields.RST then
         begin
         sawNoRST := True;
         end;
      end;
   CheckTrue(sawNoRST, 'the registry holds contests with no RST in the exchange');
end;

procedure TADIFReceivedFieldsTests.Test_TheFOCMarathonNumberGoesToFOCNum;
var
   text: string;
begin
   BeginTest('Test_TheFOCMarathonNumberGoesToFOCNum');
   text := EmitADIFRecord(FullQso(ContestHandleOf(FOCMARATHON)), nil);
   CheckTrue(Pos('<APP_TR4W_FOC_NUM:3>100 ', text) > 0, 'FOC Marathon: APP_TR4W_FOC_NUM: ' + text);
   CheckFalse(HasTag(text, 'FOC_NUM'), 'FOC Marathon: not the non-ADIF FOC_NUM: ' + text);
   CheckFalse(HasTag(text, 'RX_PWR'), 'FOC Marathon: not RX_PWR: ' + text);
end;

procedure TADIFReceivedFieldsTests.Test_OurSerialIsNotAReceivedField;
var
   qso: ContestExchange;
   text: string;
begin
   BeginTest('Test_OurSerialIsNotAReceivedField');
   (* ARRL DX at the US station sends and receives no serial, and the D7
      corpus reference still carries STX on every record. *)
   qso := FullQso(ContestHandleOf(ARRLDXCW));
   text := EmitADIFRecord(qso, nil);
   CheckTrue(Pos('<STX:5>00008 ', text) > 0, 'STX is written: ' + text);

   (* A QSO the log gave no serial, or the unset sentinel, writes none *)
   qso.NumberSent := 0;
   CheckFalse(HasTag(EmitADIFRecord(qso, nil), 'STX'), 'serial 0: no STX');
   qso.NumberSent := $FFFF;
   CheckFalse(HasTag(EmitADIFRecord(qso, nil), 'STX'), 'serial $FFFF: no STX');
   qso.NumberSent := -1;
   CheckFalse(HasTag(EmitADIFRecord(qso, nil), 'STX'), 'serial -1: no STX');
end;

procedure TADIFReceivedFieldsTests.Test_ARRLDXAsksTheEntrantsList;
var
   qso: ContestExchange;
   us, dx: TContestBase;
   usText, dxText: string;
begin
   BeginTest('Test_ARRLDXAsksTheEntrantsList');
   (* A US entrant is sent a power, a DX entrant a state or province and a
      serial -- the identity object, which has no station, cannot say which. *)
   qso := FullQso(ContestHandleOf(ARRLDXCW));
   us := NewContestLike(ContestIdentity(ARRLDXCW), PinStation(psUS, ARRLDXCW));
   dx := NewContestLike(ContestIdentity(ARRLDXCW), PinStation(psDX, ARRLDXCW));
   try
      usText := EmitADIFRecord(qso, us);
      dxText := EmitADIFRecord(qso, dx);
   finally
      us.Free;
      dx.Free;
      end;
   CheckTrue(HasTag(usText, 'RX_PWR'), 'US entrant: the power: ' + usText);
   CheckFalse(HasTag(usText, 'QTH'), 'US entrant: no QTH: ' + usText);
   CheckFalse(HasTag(dxText, 'RX_PWR'), 'DX entrant: no power: ' + dxText);
   CheckTrue(HasTag(dxText, 'QTH'), 'DX entrant: the state or province: ' + dxText);
   CheckTrue(HasTag(dxText, 'SRX'), 'DX entrant: the serial: ' + dxText);

   (* RX_PWR IS AN ADIF NUMBER: ARRL DX's 'K' and 'KW' are words and are left
     out (they are in SRX_STRING). 2026-10-23, from the ADIF validator. *)
   qso.Power := 'KW';
   us := NewContestLike(ContestIdentity(ARRLDXCW), PinStation(psUS, ARRLDXCW));
   try
      usText := EmitADIFRecord(qso, us);
   finally
      us.Free;
      end;
   CheckFalse(HasTag(usText, 'RX_PWR'), 'a power of KW is not written: ' + usText);
   qso.Power := '1500';
   us := NewContestLike(ContestIdentity(ARRLDXCW), PinStation(psUS, ARRLDXCW));
   try
      usText := EmitADIFRecord(qso, us);
   finally
      us.Free;
      end;
   CheckTrue(Pos('<RX_PWR:4>1500', usText) > 0, 'a numeric power is: ' + usText);
end;

procedure TADIFReceivedFieldsTests.Test_ALoggedQSOIsJudgedByItsOwnContest;
var
   sweepstakes: TContestBase;
   text: string;
begin
   BeginTest('Test_ALoggedQSOIsJudgedByItsOwnContest');
   (* A POTA record handed to an object that is the Sweepstakes: the object
      is not the QSO's contest, so the QSO's own is asked. *)
   sweepstakes := NewContestLike(ContestIdentity(ARRLSSCW), NoStation);
   try
      text := EmitADIFRecord(FullQso(ContestHandleOf(POTA)), sweepstakes);
   finally
      sweepstakes.Free;
      end;
   CheckFalse(HasTag(text, 'PRECEDENCE'), 'POTA record, SS object: no PRECEDENCE: ' + text);
   CheckFalse(HasTag(text, 'CHECK'), 'POTA record, SS object: no CHECK: ' + text);
   CheckTrue(HasTag(text, 'RST_SENT'), 'POTA record, SS object: POTA has an RST: ' + text);
end;

procedure TADIFReceivedFieldsTests.RunAllTests;
begin
   Test_EveryContestExportsExactlyWhatItDeclares;
   Test_EveryContestAtEveryStationExportsExactlyWhatItDeclares;
   Test_POTAExportsNoSweepstakesTenTenOrKidsFields;
   Test_SweepstakesExportsPrecedenceAndCheck;
   Test_ATenTenContestExportsTheNumberAndNeverAZero;
   Test_AContestWithNoRSTInItsExchangeStillExportsRST;
   Test_TheFOCMarathonNumberGoesToFOCNum;
   Test_OurSerialIsNotAReceivedField;
   Test_ARRLDXAsksTheEntrantsList;
   Test_ALoggedQSOIsJudgedByItsOwnContest;
end;

end.
