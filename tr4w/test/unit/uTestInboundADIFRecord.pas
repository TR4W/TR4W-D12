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

(* AN INBOUND ADIF RECORD KEEPS ITS FIELDS (NY4I, 2026-11-25: "we should parse
  the adif record into the qso record properly regardless of the contest").

  The bench: WSJT-X logged W1DJG with GRIDSQUARE FN41 and RST_RCVD -12 in the
  General QSO. uInboundQso made the ExchString from the QTH and ParametersOkay
  parsed it as TYPED text, so the QSO logged with Name FN41, no QTH, and the
  report 599.

  THE REAL PATH, SHORT OF THE LOG WRITE: uInboundQso.ParseInboundADIF, then
  CheckParsedInboundQso (ParametersOkay in its pre-parsed mode). LogContact
  is not run here -- it needs a log store -- and is pinned by a source read:
  the dupe test and the multiplier flags are its own and did not change.

  EACH CONTEST CLASS IS COMPARED WITH TYPED ENTRY of the same exchange: the
  domestic QTH, its multiplier key, the zone and the points must be the ones
  an operator typing it gets. Typed entry itself is pinned unchanged. *)
unit uTestInboundADIFRecord;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TInboundADIFRecordTests = class(TTestCase)
   protected
      procedure Test_GeneralQSOWSJTXRecordKeepsItsFields;
      procedure Test_GeneralQSOTypedEntryIsUnchanged;
      procedure Test_ARRLSectionRecordScoresAsTyped;
      procedure Test_FieldDayRecordWithoutASectionIsLoggedAndNamed;
      procedure Test_StatePartyRecordWithACounty;
      procedure Test_StatePartyRecordWithoutACounty;
      procedure Test_CQZoneRecordScoresAsTyped;
      procedure Test_CQZoneRecordWithoutAZoneIsNamed;
      procedure Test_N1MMListenerRecordShape;
      procedure Test_TheLogWriteAndItsDupeTestAreUnchanged;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uAppStrings,
   uInboundQso,
   LogDupe,
   uTestAutomaticXQSO,   (* SourceText *)
   MainUnit,
   uTestEngineEntry;

(* ONE ADIF FIELD, as WSJT-X writes it: lower-case name, a blank after. *)
function Tag(const aName, aValue: string): string;
begin
   Result := '<' + aName + ':' + IntToStr(Length(aValue)) + '>' + aValue + ' ';
end;

(* THE BENCH RECORD of 2026-11-25 01:14:45Z, field for field. *)
function WSJTXRecord(const aCall, aGrid: string): string;
begin
   Result := Tag('call', aCall) + Tag('gridsquare', aGrid) + Tag('mode', 'FT8') +
             Tag('rst_sent', '-17') + Tag('rst_rcvd', '-12') +
             Tag('qso_date', '20261125') + Tag('time_on', '011345') +
             Tag('qso_date_off', '20261125') + Tag('time_off', '011445') +
             Tag('band', '20m') + Tag('freq', '14.075950') +
             Tag('station_callsign', 'NY4I') + Tag('my_gridsquare', 'EL98') +
             Tag('tx_pwr', '500') + Tag('operator', 'NY4I') + '<EOR>';
end;

(* A CW contest record: the call, 20 m, the reports, the tags under test. *)
function CWRecord(const aCall, aTags: string): string;
begin
   Result := Tag('CALL', aCall) + Tag('BAND', '20m') + Tag('FREQ', '14.025000') +
             Tag('MODE', 'CW') + Tag('QSO_DATE', '20261125') +
             Tag('TIME_ON', '120000') + Tag('RST_SENT', '599') +
             Tag('RST_RCVD', '599') + aTags + '<EOR>';
end;

(* The inbound path short of LogContact. *)
function Inbound(const aAdif: string; var aRX: ContestExchange): boolean;
begin
   Result := ParseInboundADIF(aAdif, aRX);
   if Result then
      begin
      Result := CheckParsedInboundQso(aRX, 'test');
      end;
end;

procedure TInboundADIFRecordTests.Test_GeneralQSOWSJTXRecordKeepsItsFields;
var
   rx: ContestExchange;
begin
   BeginTest('General QSO: a WSJT-X record keeps its grid, its reports and no name');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(GENERALQSO, DomesticCountriesKVE, '');
   try
      ClearContestExchange(rx);
      CheckTrue(Inbound(WSJTXRecord('W1DJG', 'FN41'), rx), 'checked');
      CheckEquals('FN41', string(rx.QTHString), 'FN41 stays the QTH');
      CheckEquals('', string(rx.Name), 'and is not the name');
      CheckEquals(-12, rx.RSTReceived, 'the report received is the record''s -12');
      CheckEquals(-17, rx.RSTSent, 'the report sent is the record''s -17');
      CheckEquals(Ord(Band20), Ord(rx.Band), '20 m');
      CheckEquals(14075950, rx.Frequency, 'the record''s frequency');
      CheckEquals('', InboundMissingFieldsNotice(rx),
                  'the General QSO needs no field, so no notice');
   finally
      RestoreSession;
   end;
end;

procedure TInboundADIFRecordTests.Test_GeneralQSOTypedEntryIsUnchanged;
var
   rx: ContestExchange;
begin
   BeginTest('General QSO: a lone TYPED word is still a name');
   SetUpSession(GENERALQSO, DomesticCountriesKVE, '');
   try
      CheckTrue(Enter('W1DJG', 'TOM', rx), 'typed TOM accepted');
      CheckEquals('TOM', string(rx.Name), 'typed: the lone word is the name');
      CheckEquals('TOM', string(rx.ExchString), 'typed: ExchString is the text');
   finally
      RestoreSession;
   end;
end;

procedure TInboundADIFRecordTests.Test_ARRLSectionRecordScoresAsTyped;
var
   rx: ContestExchange;
   typed: ContestExchange;
begin
   BeginTest('ARRL Field Day: CLASS + ARRL_SECT gives what typing "1D EMA" gives');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLFIELDDAY, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      CheckTrue(Enter('W1AW', '1D EMA', typed), 'typed 1D EMA accepted');

      ClearContestExchange(rx);
      CheckTrue(Inbound(CWRecord('W1AW', Tag('CLASS', '1D') + Tag('ARRL_SECT', 'EMA')), rx),
                'the record is checked');
      CheckEquals(string(typed.ceClass), string(rx.ceClass), 'the class');
      CheckEquals(string(typed.DomesticQTH), string(rx.DomesticQTH), 'the section');
      CheckEquals(string(typed.DomMultQTH), string(rx.DomMultQTH), 'the multiplier key');
      CheckEquals(typed.QSOPoints, rx.QSOPoints, 'the points');
      CheckEquals('', InboundMissingFieldsNotice(rx), 'nothing missing');
   finally
      RestoreSession;
   end;
end;

procedure TInboundADIFRecordTests.Test_FieldDayRecordWithoutASectionIsLoggedAndNamed;
var
   rx: ContestExchange;
   notice: string;
begin
   BeginTest('ARRL Field Day: a record with no section is checked, and the notice names it');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLFIELDDAY, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      ClearContestExchange(rx);
      CheckTrue(Inbound(CWRecord('W1AW', Tag('CLASS', '1D')), rx),
                'accepted, NOT refused: it is logged');
      notice := InboundMissingFieldsNotice(rx);
      CheckEquals(UnicodeFormat(SInboundLoggedWithout, ['W1AW', SExchangeHintQTH]), notice,
                  'one line names the call and the missing field');
   finally
      RestoreSession;
   end;
end;

procedure TInboundADIFRecordTests.Test_StatePartyRecordWithACounty;
var
   rx: ContestExchange;
   typed: ContestExchange;
begin
   BeginTest('Michigan QP: a serial and a QTH tag county, resolved as typed entry resolves them');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(MICHQSOPARTY, DomesticCountriesKVEKH6KL, 'michigan_cty.dom');
   try
      CheckTrue(Enter('K8ABC', '12 PRES', typed), 'typed 12 PRES accepted');

      ClearContestExchange(rx);
      CheckTrue(Inbound(CWRecord('K8ABC', Tag('SRX', '12') + Tag('QTH', 'PRES')), rx), 'checked');
      CheckEquals(12, rx.NumberReceived, 'the serial as the SRX tag had it');
      CheckEquals('PRES', string(rx.QTHString), 'the QTH as received');
      (* The alias resolved -- the old inbound path overwrote this with the
        raw text after ParametersOkay. *)
      CheckEquals(string(typed.DomesticQTH), string(rx.DomesticQTH),
                  'the domestic QTH as the file spells it');
      CheckEquals(string(typed.DomMultQTH), string(rx.DomMultQTH), 'the multiplier key');
      CheckEquals(typed.QSOPoints, rx.QSOPoints, 'the points');
      CheckEquals('', InboundMissingFieldsNotice(rx), 'nothing missing');
   finally
      RestoreSession;
   end;
end;

procedure TInboundADIFRecordTests.Test_StatePartyRecordWithoutACounty;
var
   rx: ContestExchange;
begin
   BeginTest('Michigan QP: a record with no county is checked, and the notice names the QTH');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(MICHQSOPARTY, DomesticCountriesKVEKH6KL, 'michigan_cty.dom');
   try
      ClearContestExchange(rx);
      CheckTrue(Inbound(CWRecord('K8ABC', ''), rx), 'accepted, NOT refused');
      CheckEquals('', string(rx.QTHString), 'no QTH was made up');
      CheckTrue(Pos(SExchangeHintQTH, InboundMissingFieldsNotice(rx)) > 0,
                'the notice names the QTH');
   finally
      RestoreSession;
   end;
end;

procedure TInboundADIFRecordTests.Test_CQZoneRecordScoresAsTyped;
var
   rx: ContestExchange;
   typed: ContestExchange;
begin
   BeginTest('CQ WW: CQZ and SRX_STRING give what typing "599 14" gives');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(CQWWCW, [], '');
   try
      CheckTrue(Enter('DL1ABC', '599 14', typed), 'typed 599 14 accepted');

      (* THE CQ WW IMPORT READS THE ZONE FROM SRX_STRING and writes it over
        the CQZ tag (TContestCQWWBase.ApplyADIFImport) -- so the record
        carries both, as N1MM and TR4W write it. A CQZ tag alone is the next
        test. *)
      ClearContestExchange(rx);
      CheckTrue(Inbound(CWRecord('DL1ABC', Tag('CQZ', '14') + Tag('SRX_STRING', '599 14')), rx),
                'checked');
      CheckEquals(typed.Zone, rx.Zone, 'the zone');
      CheckEquals(599, rx.RSTReceived, 'the report');
      CheckEquals(typed.QSOPoints, rx.QSOPoints, 'the points');
      CheckEquals('', InboundMissingFieldsNotice(rx), 'nothing missing');
   finally
      RestoreSession;
   end;
end;

procedure TInboundADIFRecordTests.Test_CQZoneRecordWithoutAZoneIsNamed;
var
   rx: ContestExchange;
begin
   BeginTest('CQ WW: a record with no zone is checked, and the notice names the zone');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(CQWWCW, [], '');
   try
      ClearContestExchange(rx);
      CheckTrue(Inbound(CWRecord('DL1ABC', ''), rx), 'accepted, NOT refused');
      CheckEquals(UnicodeFormat(SInboundLoggedWithout, ['DL1ABC', SExchangeHintZone]),
                  InboundMissingFieldsNotice(rx), 'the zone is named');

      (* TODAY'S IMPORT, PINNED SO A FIX IS SEEN: a CQZ tag with no
        SRX_STRING reads as zone 0, which the file import does too -- the
        notice names it. Open: the CQ WW import should keep the tag. *)
      ClearContestExchange(rx);
      CheckTrue(Inbound(CWRecord('DL1ABC', Tag('CQZ', '14')), rx), 'a CQZ tag alone: accepted');
      CheckEquals(0, rx.Zone, 'the CQ WW import reads no zone from the CQZ tag (open)');
      CheckEquals(UnicodeFormat(SInboundLoggedWithout, ['DL1ABC', SExchangeHintZone]),
                  InboundMissingFieldsNotice(rx), 'and the notice names it');
   finally
      RestoreSession;
   end;
end;

(* THE N1MM LOG LISTENER'S SHAPE (JTDX, JTAlert): upper-case tags, an
  SRX_STRING beside the field tags. The fields decide; the string is only
  kept. *)
procedure TInboundADIFRecordTests.Test_N1MMListenerRecordShape;
var
   rx: ContestExchange;
begin
   BeginTest('N1MM listener record: the field tags decide, nothing is re-parsed');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(GENERALQSO, DomesticCountriesKVE, '');
   try
      ClearContestExchange(rx);
      CheckTrue(Inbound(Tag('CALL', 'K4ABC') + Tag('BAND', '40m') +
                        Tag('FREQ', '7.074000') + Tag('MODE', 'FT8') +
                        Tag('QSO_DATE', '20261125') + Tag('TIME_ON', '020000') +
                        Tag('RST_SENT', '-05') + Tag('RST_RCVD', '+03') +
                        Tag('GRIDSQUARE', 'EM73') + Tag('NAME', 'BOB') +
                        Tag('SRX_STRING', '+03 EM73') + '<EOR>', rx), 'checked');
      CheckEquals('EM73', string(rx.QTHString), 'the grid is the QTH');
      CheckEquals('BOB', string(rx.Name), 'the NAME tag is the name');
      CheckEquals(3, rx.RSTReceived, 'the received report');
      CheckEquals(-5, rx.RSTSent, 'the sent report');
      CheckEquals(Ord(Band40), Ord(rx.Band), '40 m');
   finally
      RestoreSession;
   end;
end;

procedure TInboundADIFRecordTests.Test_TheLogWriteAndItsDupeTestAreUnchanged;
var
   text: string;
begin
   BeginTest('LogParsedInboundQso: the check, then LogContact (dupe and mults), then the notice');
   text := SourceText('uInboundQso.pas');
   CheckTrue(Pos('if not CheckParsedInboundQso(aExch, aSource) then', text) > 0,
             'the check is the pre-parsed one');
   CheckTrue(Pos('if not LogContact(aExch, True) then', text) > 0,
             'the record is still logged by LogContact, whose dupe test flags a dupe');
   CheckTrue(Pos('tempMode, tempFreq, aExch, True);', text) > 0,
             'ParametersOkay is asked in its pre-parsed mode');
   CheckEquals(0, Pos('aExch.ExchString := aExch.QTHString', text),
               'no ExchString is made up from the QTH');
end;

procedure TInboundADIFRecordTests.RunAllTests;
begin
   Test_GeneralQSOWSJTXRecordKeepsItsFields;
   Test_GeneralQSOTypedEntryIsUnchanged;
   Test_ARRLSectionRecordScoresAsTyped;
   Test_FieldDayRecordWithoutASectionIsLoggedAndNamed;
   Test_StatePartyRecordWithACounty;
   Test_StatePartyRecordWithoutACounty;
   Test_CQZoneRecordScoresAsTyped;
   Test_CQZoneRecordWithoutAZoneIsNamed;
   Test_N1MMListenerRecordShape;
   Test_TheLogWriteAndItsDupeTestAreUnchanged;
end;

end.
