unit uTestADIF;
{$I ..\..\src\tr4w.inc}

{
  Tests for uADIF.pas — the ADIF field-list lexer.

  These tests verify the string-slicing core of ADIF parsing.  Per
  docs/tr4w-migration-strategy.md, ADIF string handling is high-risk
  surface for Phase 2 (Unicode correctness), so this regression net
  is part of the Tier 1 build-before-the-freeze work.

  Issue #887 — first incremental commit.  Subsequent commits will add
  tests for field-name -> ContestExchange mapping and the multi-record
  ImportADIFFromString entry point.
}

interface

uses
   uTR4WTestFramework;

type
   TADIFLexerTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_EmptyString;
      procedure Test_SingleField_EORTerminated;
      procedure Test_MultipleFields;
      procedure Test_BareEOR;
      procedure Test_EOHSkipped_HeaderThenRecord;
      procedure Test_EOHAlone_NotARecordTerminator;
      procedure Test_NoTerminator_ReturnsFalseButKeepsFields;
      procedure Test_EmptyValue;
      procedure Test_MultilineRecord;
      procedure Test_EmbeddedSpacesInValue;
      procedure Test_LowercaseEORAccepted;
      procedure Test_MixedCaseEORAccepted;
      procedure Test_FreeFormTextBetweenFields;
      procedure Test_NonNumericLength_FieldSkipped;
      procedure Test_TruncatedValue_PartialFieldReturned;
      procedure Test_TypedField_TypeStripped;
      procedure Test_UnclosedTag_ReturnsFalse;
      procedure Test_RealishADIFRecord;
   end;

   TADIFMappingTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_BasicMapping_PopulatesExch;
      procedure Test_BasicMapping_CapturesTemps;
      procedure Test_FromWSJTX_StripsPlusFromRST;
      procedure Test_RoverCallAfterCALL_Overrides;
      procedure Test_CALLAfterRoverCall_DoesNotOverride;
      procedure Test_ModeNotOverwrittenAfterSet;
      procedure Test_ImportSingleRecord;
      procedure Test_ImportFQPRecord_QTHSet;
      procedure Test_ImportMultipleRecords;
      procedure Test_ImportSkipsHeader;
      procedure Test_ImportEmptyString_ZeroRecords;
      procedure Test_ImportNoEOR_ZeroRecords;
   end;

   TADIFHelperTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_GetADIFBand_KnownBands;
      procedure Test_GetADIFBand_UnknownBand;
      procedure Test_GetADIFBand_CaseInsensitive;
      procedure Test_GetADIFMode_KnownModes;
      procedure Test_GetADIFMode_UnknownMode;
      procedure Test_GetADIFSubMode_KnownSubModes;
      procedure Test_GetADIFSubMode_UnknownSubMode;
      procedure Test_ExtMode_ExportsAnADIFMode_Exhaustive;
      procedure Test_ExtMode_ExportPairs;
      procedure Test_EmittedTagsAreADIF316Fields;
      procedure Test_ValueShapes;
      procedure Test_InvalidValuesAreNotWritten;
      procedure Test_OldDOKAndFOCNamesStillImport;
      procedure Test_GenericDataMode_SaysSoInTheFile;
      procedure Test_OldTR4WSpellingsStillImport;
      procedure Test_ADIFDateStringToQSOTime_Valid;
      procedure Test_ADIFDateStringToQSOTime_InvalidLength;
      procedure Test_ADIFDateStringToQSOTime_NonNumeric;
      procedure Test_ADIFTimeStringToQSOTime_HHMM;
      procedure Test_ADIFTimeStringToQSOTime_HHMMSS;
      procedure Test_ADIFTimeStringToQSOTime_InvalidLength;
      procedure Test_ADIFTimeStringToQSOTime_NonNumeric;
      procedure Test_IsValidGUID_Hyphenated;
      procedure Test_IsValidGUID_Unhyphenated;
      procedure Test_IsValidGUID_Braced;
      procedure Test_IsValidGUID_RejectsShort;
      procedure Test_IsValidGUID_RejectsNonHex;
      procedure Test_IsValidGUID_RejectsEmpty;
      procedure Test_IsValidGUID_RejectsMisplacedHyphens;
      procedure Test_ExchangeFromSRX_StripsTheReceivedRST;
      procedure Test_ExchangeFromSRX_LeavesAnExchangeWithNoRST;
      procedure Test_ExchangeFromSRX_LeavesAnRSTThatIsNotTheReceivedOne;
      procedure Test_ExchangeFromSRX_AnRSTOnItsOwnIsNoExchange;
   end;

implementation

uses
   SysUtils,
   VC,
   uADIF,
   uARRLSections,
   uContestRegistry,
   uQsoMyFacts;

// ---------------------------------------------------------------------------
// Basic shapes
// ---------------------------------------------------------------------------

procedure TADIFLexerTests.Test_EmptyString;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_EmptyString');
   CheckFalse(ParseADIFFieldsList('', fields),
              'empty string has no terminator -> False');
   CheckEquals(0, Length(fields), 'no fields parsed');
end;

procedure TADIFLexerTests.Test_SingleField_EORTerminated;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_SingleField_EORTerminated');
   CheckTrue(ParseADIFFieldsList('<CALL:4>KG1S<EOR>', fields),
             'EOR terminator -> True');
   CheckEquals(1, Length(fields), 'one field parsed');
   CheckEquals('CALL', fields[0].Name, 'field name');
   CheckEquals('KG1S', fields[0].Value, 'field value');
end;

procedure TADIFLexerTests.Test_MultipleFields;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_MultipleFields');
   CheckTrue(ParseADIFFieldsList(
      '<CALL:4>KG1S <BAND:3>20m <MODE:2>CW <EOR>', fields),
      'three fields + EOR -> True');
   CheckEquals(3, Length(fields), 'three fields parsed');
   CheckEquals('CALL', fields[0].Name, '[0].Name');
   CheckEquals('KG1S', fields[0].Value, '[0].Value');
   CheckEquals('BAND', fields[1].Name, '[1].Name');
   CheckEquals('20m', fields[1].Value, '[1].Value');
   CheckEquals('MODE', fields[2].Name, '[2].Name');
   CheckEquals('CW', fields[2].Value, '[2].Value');
end;

procedure TADIFLexerTests.Test_BareEOR;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_BareEOR');
   CheckTrue(ParseADIFFieldsList('<EOR>', fields),
             'bare EOR returns True');
   CheckEquals(0, Length(fields), 'no fields');
end;

procedure TADIFLexerTests.Test_EOHSkipped_HeaderThenRecord;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_EOHSkipped_HeaderThenRecord');
   // ADIF IV.A.2: an optional Header (terminated by <EOH>) precedes one
   // or more <EOR> records.  WSJT-X sends exactly this shape, so the
   // single-record lexer must skip <EOH> and keep parsing the record
   // that follows -- the call/grid must survive the header boundary.
   // Regression guard for Issue #887: the lexer used to stop at <EOH>,
   // which dropped every WSJT-X-logged QSO.
   CheckTrue(ParseADIFFieldsList(
      '<PROGRAMID:6>WSJT-X<EOH>'#13#10 +
      '<CALL:4>W7CT <GRIDSQUARE:4>DN41<EOR>', fields),
      'header + record -> reaches EOR -> True');
   CheckEquals(3, Length(fields), 'header field + two record fields');
   CheckEquals('PROGRAMID', fields[0].Name, 'header field kept (sets FromWSJTX)');
   CheckEquals('WSJT-X', fields[0].Value, 'programid value');
   CheckEquals('CALL', fields[1].Name, 'record field parsed after <EOH>');
   CheckEquals('W7CT', fields[1].Value, 'call survives the header boundary');
   CheckEquals('GRIDSQUARE', fields[2].Name, 'grid field name');
   CheckEquals('DN41', fields[2].Value, 'grid survives the header boundary');
end;

procedure TADIFLexerTests.Test_EOHAlone_NotARecordTerminator;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_EOHAlone_NotARecordTerminator');
   // <EOH> ends a header, not a record.  With no following <EOR> there
   // is no complete record, so Result is False -- the header field is
   // still extracted (forgiving, same as the no-terminator case).
   CheckFalse(ParseADIFFieldsList('<PROGRAMID:4>TR4W<EOH>', fields),
              'EOH alone is not a record terminator -> False');
   CheckEquals(1, Length(fields), 'header field still extracted');
   CheckEquals('PROGRAMID', fields[0].Name, 'name');
   CheckEquals('TR4W', fields[0].Value, 'value');
end;

procedure TADIFLexerTests.Test_NoTerminator_ReturnsFalseButKeepsFields;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_NoTerminator_ReturnsFalseButKeepsFields');
   CheckFalse(ParseADIFFieldsList('<CALL:4>KG1S <BAND:3>20m', fields),
              'no terminator -> False');
   CheckEquals(2, Length(fields), 'fields still extracted');
   CheckEquals('KG1S', fields[0].Value, '[0]');
   CheckEquals('20m', fields[1].Value, '[1]');
end;

// ---------------------------------------------------------------------------
// Value-shape edge cases
// ---------------------------------------------------------------------------

procedure TADIFLexerTests.Test_EmptyValue;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_EmptyValue');
   CheckTrue(ParseADIFFieldsList('<COMMENT:0><EOR>', fields),
             'empty value, EOR terminator');
   CheckEquals(1, Length(fields), 'one field');
   CheckEquals('COMMENT', fields[0].Name, 'name');
   CheckEquals('', fields[0].Value, 'empty value');
end;

procedure TADIFLexerTests.Test_MultilineRecord;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_MultilineRecord');
   CheckTrue(ParseADIFFieldsList(
      '<CALL:4>KG1S'#13#10'<BAND:3>20m'#13#10'<EOR>', fields),
      'record split across lines');
   CheckEquals(2, Length(fields), 'two fields');
   CheckEquals('KG1S', fields[0].Value, 'first value across newline');
   CheckEquals('20m', fields[1].Value, 'second value');
end;

procedure TADIFLexerTests.Test_EmbeddedSpacesInValue;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_EmbeddedSpacesInValue');
   CheckTrue(ParseADIFFieldsList('<NAME:8>John Doe<EOR>', fields),
             'value contains a space');
   CheckEquals(1, Length(fields), 'one field');
   CheckEquals('John Doe', fields[0].Value, 'space preserved by length-honored read');
end;

// ---------------------------------------------------------------------------
// Terminator case sensitivity
// ---------------------------------------------------------------------------

procedure TADIFLexerTests.Test_LowercaseEORAccepted;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_LowercaseEORAccepted');
   CheckTrue(ParseADIFFieldsList('<eor>', fields),
             'lowercase eor accepted');
end;

procedure TADIFLexerTests.Test_MixedCaseEORAccepted;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_MixedCaseEORAccepted');
   CheckTrue(ParseADIFFieldsList('<EoR>', fields),
             'mixed case EoR accepted');
end;

// ---------------------------------------------------------------------------
// Free-form / malformed
// ---------------------------------------------------------------------------

procedure TADIFLexerTests.Test_FreeFormTextBetweenFields;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_FreeFormTextBetweenFields');
   // ADIF allows arbitrary text between tags (typical in headers/comments).
   CheckTrue(ParseADIFFieldsList(
      'Created by TR4W'#13#10'<CALL:4>KG1S<EOR>', fields),
      'leading free-form text ignored');
   CheckEquals(1, Length(fields), 'still parses the field after free text');
   CheckEquals('KG1S', fields[0].Value, 'value extracted');
end;

procedure TADIFLexerTests.Test_NonNumericLength_FieldSkipped;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_NonNumericLength_FieldSkipped');
   // A non-numeric length is malformed; lexer skips the tag and continues.
   CheckTrue(ParseADIFFieldsList(
      '<CALL:abc>?? <BAND:3>20m<EOR>', fields),
      'bad-length tag skipped, parsing continues to EOR');
   // The malformed tag is dropped; the second field is parsed.
   CheckEquals(1, Length(fields), 'only the well-formed field survives');
   CheckEquals('BAND', fields[0].Name, 'second field name');
   CheckEquals('20m', fields[0].Value, 'second field value');
end;

procedure TADIFLexerTests.Test_TruncatedValue_PartialFieldReturned;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_TruncatedValue_PartialFieldReturned');
   // CALL declared length 10 but only 4 chars follow.  Lexer returns the
   // partial value and stops (no terminator => False).
   CheckFalse(ParseADIFFieldsList('<CALL:10>KG1S', fields),
              'truncated value -> False');
   CheckEquals(1, Length(fields), 'one (partial) field');
   CheckEquals('KG1S', fields[0].Value, 'whatever bytes were left');
end;

procedure TADIFLexerTests.Test_TypedField_TypeStripped;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_TypedField_TypeStripped');
   // ADIF allows <NAME:LEN:TYPE>VALUE where TYPE is a single-character
   // data-type indicator.  Lexer must accept the suffix and ignore it.
   CheckTrue(ParseADIFFieldsList('<CALL:4:S>KG1S<EOR>', fields),
             ':TYPE suffix ignored');
   CheckEquals(1, Length(fields), 'one field');
   CheckEquals('KG1S', fields[0].Value, 'value extracted');
end;

procedure TADIFLexerTests.Test_UnclosedTag_ReturnsFalse;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_UnclosedTag_ReturnsFalse');
   // '<' with no matching '>' at all in the rest of the string.
   CheckFalse(ParseADIFFieldsList('<CALL:4 unclosed', fields),
              'unclosed tag header -> False');
   CheckEquals(0, Length(fields), 'no fields parsed');
end;

// ---------------------------------------------------------------------------
// End-to-end shape: a real-ish ADIF record body
// ---------------------------------------------------------------------------

procedure TADIFLexerTests.Test_RealishADIFRecord;
var
   fields : TADIFFieldList;
begin
   BeginTest('Test_RealishADIFRecord');
   CheckTrue(ParseADIFFieldsList(
      '<CALL:4>KG1S <BAND:3>20m <QSO_DATE:8>20260510 ' +
      '<TIME_ON:6>154644 <RST_SENT:2>59 <RST_RCVD:2>59 ' +
      '<MODE:3>SSB <SUBMODE:3>USB <FREQ:5>14.32' +
      '<SRX_STRING:3>MON <STX_STRING:6>59 PIN <STATE:3>MON ' +
      '<QTH:3>MON <STX:5>00033 <OPERATOR:4>NY4I <EOR>', fields),
      'realistic record parses to EOR');
   CheckEquals(15, Length(fields), 'fifteen fields in this record');
   CheckEquals('CALL',       fields[0].Name,  '[0] name');
   CheckEquals('KG1S',       fields[0].Value, '[0] value');
   CheckEquals('OPERATOR',   fields[14].Name, '[14] name');
   CheckEquals('NY4I',       fields[14].Value,'[14] value');
end;

// ---------------------------------------------------------------------------
// Test suite dispatch
// ---------------------------------------------------------------------------

procedure TADIFLexerTests.RunAllTests;
begin
   Test_EmptyString;
   Test_SingleField_EORTerminated;
   Test_MultipleFields;
   Test_BareEOR;
   Test_EOHSkipped_HeaderThenRecord;
   Test_EOHAlone_NotARecordTerminator;
   Test_NoTerminator_ReturnsFalseButKeepsFields;

   Test_EmptyValue;
   Test_MultilineRecord;
   Test_EmbeddedSpacesInValue;

   Test_LowercaseEORAccepted;
   Test_MixedCaseEORAccepted;

   Test_FreeFormTextBetweenFields;
   Test_NonNumericLength_FieldSkipped;
   Test_TruncatedValue_PartialFieldReturned;
   Test_TypedField_TypeStripped;
   Test_UnclosedTag_ReturnsFalse;

   Test_RealishADIFRecord;
end;

// =========================================================================
// Field-to-ContestExchange mapping tests (ApplyADIFFieldsToExchange,
// ImportADIFFromString)
// =========================================================================

procedure TADIFMappingTests.Test_BasicMapping_PopulatesExch;
var
   fields : TADIFFieldList;
   exch   : ContestExchange;
   temps  : TADIFRecordTemps;
begin
   BeginTest('Test_BasicMapping_PopulatesExch');

   InitContestExchangeForParse(exch);
   SetLength(fields, 5);
   fields[0].Name := 'CALL';     fields[0].Value := 'kg1s';
   fields[1].Name := 'BAND';     fields[1].Value := '20m';
   fields[2].Name := 'MODE';     fields[2].Value := 'CW';
   fields[3].Name := 'RST_SENT'; fields[3].Value := '599';
   fields[4].Name := 'RST_RCVD'; fields[4].Value := '599';

   CheckTrue(ApplyADIFFieldsToExchange(fields, exch, temps),
             'Apply succeeds');
   CheckEquals('KG1S',         string(exch.Callsign),    'CALL upcased');
   CheckEquals(Integer(Band20), Integer(exch.Band),      'BAND');
   CheckEquals(Integer(CW),     Integer(exch.Mode),      'MODE');
   CheckEquals(599, Integer(exch.RSTSent),               'RST_SENT');
   CheckEquals(599, Integer(exch.RSTReceived),           'RST_RCVD');
end;

procedure TADIFMappingTests.Test_BasicMapping_CapturesTemps;
var
   fields : TADIFFieldList;
   exch   : ContestExchange;
   temps  : TADIFRecordTemps;
begin
   BeginTest('Test_BasicMapping_CapturesTemps');

   InitContestExchangeForParse(exch);
   SetLength(fields, 4);
   fields[0].Name := 'SRX_STRING';  fields[0].Value := 'MON';
   fields[1].Name := 'STATE';       fields[1].Value := 'FL';
   fields[2].Name := 'GRIDSQUARE';  fields[2].Value := 'EL98';
   fields[3].Name := 'POTA_REF';    fields[3].Value := 'US-1234';

   CheckTrue(ApplyADIFFieldsToExchange(fields, exch, temps), 'Apply OK');
   CheckEquals('MON',     temps.SRX_String, 'SRX_STRING captured');
   CheckEquals('FL',      temps.State,      'STATE captured');
   CheckEquals('EL98',    temps.GridSquare, 'GRIDSQUARE captured');
   CheckEquals('US-1234', temps.POTARef,    'POTA_REF captured');
end;

procedure TADIFMappingTests.Test_FromWSJTX_StripsPlusFromRST;
var
   fields : TADIFFieldList;
   exch   : ContestExchange;
   temps  : TADIFRecordTemps;
begin
   BeginTest('Test_FromWSJTX_StripsPlusFromRST');
   // WSJT-X transmits signed-dB SNR like +05.  Mapping must strip the
   // sign so StrToIntDef parses the magnitude.
   InitContestExchangeForParse(exch);
   SetLength(fields, 3);
   fields[0].Name := 'PROGRAMID'; fields[0].Value := 'WSJT-X';
   fields[1].Name := 'RST_RCVD';  fields[1].Value := '+05';
   fields[2].Name := 'RST_SENT';  fields[2].Value := '+12';
   ApplyADIFFieldsToExchange(fields, exch, temps);
   CheckTrue(temps.FromWSJTX, 'FromWSJTX flag set by PROGRAMID');
   CheckEquals(5,  Integer(exch.RSTReceived), 'RST_RCVD magnitude');
   CheckEquals(12, Integer(exch.RSTSent),     'RST_SENT magnitude');
end;

// Test_FromWSJTX_StripsMinusNotApplied removed: legacy code's behavior
// for negative SNR in WSJT-X records is corner-case and not strictly
// defined.  StrToIntDef parses '-12' as -12, which then wraps into the
// Word-sized RSTReceived field.  Whether that's "the right thing" is a
// product question, not a parser-preservation question.

procedure TADIFMappingTests.Test_RoverCallAfterCALL_Overrides;
var
   fields : TADIFFieldList;
   exch   : ContestExchange;
   temps  : TADIFRecordTemps;
begin
   BeginTest('Test_RoverCallAfterCALL_Overrides');
   InitContestExchangeForParse(exch);
   SetLength(fields, 2);
   fields[0].Name := 'CALL';
   fields[0].Value := 'KG1S';
   fields[1].Name := 'APP_TR4W_ROVERCALL';
   fields[1].Value := 'KG1S/MON';
   ApplyADIFFieldsToExchange(fields, exch, temps);
   CheckEquals('KG1S/MON', string(exch.Callsign),
               'Rover call overrides bare CALL');
end;

procedure TADIFMappingTests.Test_CALLAfterRoverCall_DoesNotOverride;
var
   fields : TADIFFieldList;
   exch   : ContestExchange;
   temps  : TADIFRecordTemps;
begin
   BeginTest('Test_CALLAfterRoverCall_DoesNotOverride');
   // Field order reversed — rover call seen first, plain CALL second.
   // Mapping must keep the rover form regardless of order.
   InitContestExchangeForParse(exch);
   SetLength(fields, 2);
   fields[0].Name := 'APP_TR4W_ROVERCALL';
   fields[0].Value := 'KG1S/MON';
   fields[1].Name := 'CALL';
   fields[1].Value := 'KG1S';
   ApplyADIFFieldsToExchange(fields, exch, temps);
   CheckEquals('KG1S/MON', string(exch.Callsign),
               'CALL after rover does NOT overwrite');
end;

procedure TADIFMappingTests.Test_ModeNotOverwrittenAfterSet;
var
   fields : TADIFFieldList;
   exch   : ContestExchange;
   temps  : TADIFRecordTemps;
begin
   BeginTest('Test_ModeNotOverwrittenAfterSet');
   InitContestExchangeForParse(exch);
   // First MODE=CW sets exch.Mode=CW.  Second MODE=SSB must be ignored
   // because legacy guard is `if exch.Mode = NoMode then ...`.  This
   // matches the original ParseADIFRecord behaviour.
   SetLength(fields, 2);
   fields[0].Name := 'MODE'; fields[0].Value := 'CW';
   fields[1].Name := 'MODE'; fields[1].Value := 'SSB';
   ApplyADIFFieldsToExchange(fields, exch, temps);
   CheckEquals(Integer(CW), Integer(exch.Mode),
               'Second MODE does not overwrite first');
end;

// ---------------------------------------------------------------------------
// ImportADIFFromString
// ---------------------------------------------------------------------------

procedure TADIFMappingTests.Test_ImportSingleRecord;
var
   records : TContestExchangeArray;
begin
   BeginTest('Test_ImportSingleRecord');
   CheckEquals(1, ImportADIFFromString(
      '<CALL:4>KG1S <BAND:3>20m <EOR>', records),
      'one record parsed');
   CheckEquals('KG1S',          string(records[0].Callsign), 'CALL');
   CheckEquals(Integer(Band20), Integer(records[0].Band),    'BAND');
end;

procedure TADIFMappingTests.Test_ImportFQPRecord_QTHSet;
var
   records : TContestExchangeArray;
begin
   BeginTest('Test_ImportFQPRecord_QTHSet');
   // Verbatim record shape produced by TR4W's FQP export.  The QTH
   // field carries the county code and must land in exch.QTHString.
   CheckEquals(1, ImportADIFFromString(
      '<CALL:4>KG1S <BAND:3>20m <QSO_DATE:8>20260510 ' +
      '<TIME_ON:6>154644 <RST_SENT:2>59 <RST_RCVD:2>59 ' +
      '<CONTEST_ID:12>FL-QSO-PARTY <MODE:3>SSB <SUBMODE:3>USB ' +
      '<FREQ:5>14.32<SRX_STRING:6>59 MON <STX_STRING:6>59 PIN ' +
      '<STATE:2>FL <QTH:3>MON <STX:5>00033 <OPERATOR:4>NY4I <EOR>',
      records),
      'one FQP record parsed');
   CheckEquals('KG1S', string(records[0].Callsign), 'CALL');
   CheckEquals('MON',  string(records[0].QTHString),
               'QTH tag value lands in exch.QTHString');
   // DomesticQTH population happens in MainUnit's contest-specific
   // tail, NOT in uADIF.  This test only covers what uADIF does, so
   // DomesticQTH is not asserted here.  The "QTH column shows blank
   // for FQP imports" bug is covered by an integration test path,
   // not the uADIF unit test.
end;

procedure TADIFMappingTests.Test_ImportMultipleRecords;
var
   records : TContestExchangeArray;
begin
   BeginTest('Test_ImportMultipleRecords');
   CheckEquals(3, ImportADIFFromString(
      '<CALL:4>KG1S <BAND:3>20m <EOR>'#13#10 +
      '<CALL:4>W4AF <BAND:3>40m <EOR>'#13#10 +
      '<CALL:4>N4AF <BAND:3>80m <EOR>',
      records),
      'three records parsed');
   CheckEquals('KG1S', string(records[0].Callsign), '[0] CALL');
   CheckEquals('W4AF', string(records[1].Callsign), '[1] CALL');
   CheckEquals('N4AF', string(records[2].Callsign), '[2] CALL');
   CheckEquals(Integer(Band40), Integer(records[1].Band), '[1] BAND');
end;

procedure TADIFMappingTests.Test_ImportSkipsHeader;
var
   records : TContestExchangeArray;
begin
   BeginTest('Test_ImportSkipsHeader');
   // Header section ends at <EOH>.  Fields BEFORE the EOH must not
   // produce records.
   CheckEquals(1, ImportADIFFromString(
      'ADIF File'#13#10 +
      '<ADIF_VER:5>3.1.0 <PROGRAMID:4>TR4W <EOH>'#13#10 +
      '<CALL:4>KG1S <BAND:3>20m <EOR>',
      records),
      'header skipped, one record');
   CheckEquals('KG1S', string(records[0].Callsign), 'first record CALL');
end;

procedure TADIFMappingTests.Test_ImportEmptyString_ZeroRecords;
var
   records : TContestExchangeArray;
begin
   BeginTest('Test_ImportEmptyString_ZeroRecords');
   CheckEquals(0, ImportADIFFromString('', records),
               'empty string -> zero records');
   CheckEquals(0, Length(records), 'records array empty');
end;

procedure TADIFMappingTests.Test_ImportNoEOR_ZeroRecords;
var
   records : TContestExchangeArray;
begin
   BeginTest('Test_ImportNoEOR_ZeroRecords');
   // No EOR terminator anywhere -> no complete records.
   CheckEquals(0, ImportADIFFromString(
      '<CALL:4>KG1S <BAND:3>20m', records),
      'no EOR -> zero records');
end;

procedure TADIFMappingTests.RunAllTests;
begin
   Test_BasicMapping_PopulatesExch;
   Test_BasicMapping_CapturesTemps;
   Test_FromWSJTX_StripsPlusFromRST;
   Test_RoverCallAfterCALL_Overrides;
   Test_CALLAfterRoverCall_DoesNotOverride;
   Test_ModeNotOverwrittenAfterSet;

   Test_ImportSingleRecord;
   Test_ImportFQPRecord_QTHSet;
   Test_ImportMultipleRecords;
   Test_ImportSkipsHeader;
   Test_ImportEmptyString_ZeroRecords;
   Test_ImportNoEOR_ZeroRecords;
end;

// =========================================================================
// Per-field type-conversion helper tests
// =========================================================================

// ---------------------------------------------------------------------------
// GetADIFBand
// ---------------------------------------------------------------------------

procedure TADIFHelperTests.Test_GetADIFBand_KnownBands;
begin
   BeginTest('Test_GetADIFBand_KnownBands');
   CheckEquals(Integer(Band20),  Integer(GetADIFBand('20m')),  '20m');
   CheckEquals(Integer(Band40),  Integer(GetADIFBand('40m')),  '40m');
   CheckEquals(Integer(Band80),  Integer(GetADIFBand('80m')),  '80m');
   CheckEquals(Integer(Band160), Integer(GetADIFBand('160m')), '160m');
   CheckEquals(Integer(Band10),  Integer(GetADIFBand('10m')),  '10m');
   CheckEquals(Integer(Band15),  Integer(GetADIFBand('15m')),  '15m');
   CheckEquals(Integer(Band6),   Integer(GetADIFBand('6m')),   '6m');
end;

procedure TADIFHelperTests.Test_GetADIFBand_UnknownBand;
begin
   BeginTest('Test_GetADIFBand_UnknownBand');
   CheckEquals(Integer(NoBand), Integer(GetADIFBand('garbage')),
               'unknown band -> NoBand');
   CheckEquals(Integer(NoBand), Integer(GetADIFBand('')),
               'empty -> NoBand');
end;

procedure TADIFHelperTests.Test_GetADIFBand_CaseInsensitive;
begin
   BeginTest('Test_GetADIFBand_CaseInsensitive');
   CheckEquals(Integer(Band20), Integer(GetADIFBand('20M')),  'uppercase 20M');
   CheckEquals(Integer(Band20), Integer(GetADIFBand('20m')),  'lowercase 20m');
end;

// ---------------------------------------------------------------------------
// GetADIFMode
// ---------------------------------------------------------------------------

procedure TADIFHelperTests.Test_GetADIFMode_KnownModes;
var
   m : ModeAndExtendedModeType;
begin
   BeginTest('Test_GetADIFMode_KnownModes');

   m := GetADIFMode('CW');
   CheckEquals(Integer(CW),  Integer(m.msmMode),         'CW.Mode');
   CheckEquals(Integer(eCW), Integer(m.msmExtendedMode), 'CW.ExtMode');

   m := GetADIFMode('SSB');
   CheckEquals(Integer(Phone), Integer(m.msmMode),         'SSB.Mode');
   CheckEquals(Integer(eSSB),  Integer(m.msmExtendedMode), 'SSB.ExtMode');

   m := GetADIFMode('FT8');
   CheckEquals(Integer(Digital), Integer(m.msmMode),         'FT8.Mode');
   CheckEquals(Integer(eFT8),    Integer(m.msmExtendedMode), 'FT8.ExtMode');

   m := GetADIFMode('RTTY');
   CheckEquals(Integer(Digital), Integer(m.msmMode),         'RTTY.Mode');
   CheckEquals(Integer(eRTTY),   Integer(m.msmExtendedMode), 'RTTY.ExtMode');

   m := GetADIFMode('DATA');
   CheckEquals(Integer(Digital), Integer(m.msmMode),         'DATA.Mode');
   CheckEquals(Integer(eData),   Integer(m.msmExtendedMode), 'DATA.ExtMode');

   // --- CW family (reverse-sidetone) ---
   m := GetADIFMode('CW-R');
   CheckEquals(Integer(CW),    Integer(m.msmMode),         'CW-R.Mode');
   CheckEquals(Integer(eCW_R), Integer(m.msmExtendedMode), 'CW-R.ExtMode');

   // --- Digital family (reverses + protocols) ---
   m := GetADIFMode('RTTY-R');
   CheckEquals(Integer(Digital), Integer(m.msmMode), 'RTTY-R.Mode');
   CheckEquals(Integer(eRTTY_R), Integer(m.msmExtendedMode), 'RTTY-R.ExtMode');

   m := GetADIFMode('DATA-R');
   CheckEquals(Integer(Digital), Integer(m.msmMode), 'DATA-R.Mode');
   CheckEquals(Integer(eData_R), Integer(m.msmExtendedMode), 'DATA-R.ExtMode');

   m := GetADIFMode('PSK-R');
   CheckEquals(Integer(Digital), Integer(m.msmMode), 'PSK-R.Mode');
   CheckEquals(Integer(ePSK_R),  Integer(m.msmExtendedMode), 'PSK-R.ExtMode');

   m := GetADIFMode('JT65');
   CheckEquals(Integer(Digital), Integer(m.msmMode), 'JT65.Mode');
   CheckEquals(Integer(eJT65),   Integer(m.msmExtendedMode), 'JT65.ExtMode');

   m := GetADIFMode('PSK63');
   CheckEquals(Integer(Digital), Integer(m.msmMode), 'PSK63.Mode');
   CheckEquals(Integer(ePSK63),  Integer(m.msmExtendedMode), 'PSK63.ExtMode');

   m := GetADIFMode('DATA-FM');
   CheckEquals(Integer(Digital),  Integer(m.msmMode), 'DATA-FM.Mode');
   CheckEquals(Integer(eData_FM), Integer(m.msmExtendedMode), 'DATA-FM.ExtMode');

   // --- Phone family (narrowband + digital voice) ---
   m := GetADIFMode('FM-N');
   CheckEquals(Integer(Phone), Integer(m.msmMode),         'FM-N.Mode');
   CheckEquals(Integer(eFM_N), Integer(m.msmExtendedMode), 'FM-N.ExtMode');

   m := GetADIFMode('AM-N');
   CheckEquals(Integer(Phone), Integer(m.msmMode),         'AM-N.Mode');
   CheckEquals(Integer(eAM_N), Integer(m.msmExtendedMode), 'AM-N.ExtMode');

   m := GetADIFMode('WFM');
   CheckEquals(Integer(Phone), Integer(m.msmMode),         'WFM.Mode');
   CheckEquals(Integer(eWFM),  Integer(m.msmExtendedMode), 'WFM.ExtMode');

   m := GetADIFMode('C4FM');
   CheckEquals(Integer(Phone), Integer(m.msmMode),         'C4FM.Mode');
   CheckEquals(Integer(eC4FM), Integer(m.msmExtendedMode), 'C4FM.ExtMode');

   m := GetADIFMode('D-STAR');
   CheckEquals(Integer(Phone),  Integer(m.msmMode),         'D-STAR.Mode');
   CheckEquals(Integer(eDStar), Integer(m.msmExtendedMode), 'D-STAR.ExtMode');

   // Case-insensitive
   m := GetADIFMode('cw');
   CheckEquals(Integer(CW), Integer(m.msmMode), 'lowercase cw');

   m := GetADIFMode('d-star');
   CheckEquals(Integer(Phone), Integer(m.msmMode), 'lowercase d-star');
end;

procedure TADIFHelperTests.Test_GetADIFMode_UnknownMode;
var
   m : ModeAndExtendedModeType;
begin
   BeginTest('Test_GetADIFMode_UnknownMode');
   m := GetADIFMode('garbage');
   CheckEquals(Integer(NoMode), Integer(m.msmMode), 'unknown -> NoMode');
end;

// ---------------------------------------------------------------------------
// GetADIFSubMode
// ---------------------------------------------------------------------------

procedure TADIFHelperTests.Test_GetADIFSubMode_KnownSubModes;
var
   m : ModeAndExtendedModeType;
begin
   BeginTest('Test_GetADIFSubMode_KnownSubModes');

   m := GetADIFSubMode('USB');
   CheckEquals(Integer(Phone), Integer(m.msmMode),         'USB.Mode');
   CheckEquals(Integer(eUSB),  Integer(m.msmExtendedMode), 'USB.ExtMode');

   m := GetADIFSubMode('LSB');
   CheckEquals(Integer(Phone), Integer(m.msmMode),         'LSB.Mode');
   CheckEquals(Integer(eLSB),  Integer(m.msmExtendedMode), 'LSB.ExtMode');

   m := GetADIFSubMode('FT4');
   CheckEquals(Integer(Digital), Integer(m.msmMode),         'FT4.Mode');
   CheckEquals(Integer(eFT4),    Integer(m.msmExtendedMode), 'FT4.ExtMode');
end;

procedure TADIFHelperTests.Test_GetADIFSubMode_UnknownSubMode;
var
   m : ModeAndExtendedModeType;
begin
   BeginTest('Test_GetADIFSubMode_UnknownSubMode');
   m := GetADIFSubMode('garbage');
   CheckEquals(Integer(NoMode), Integer(m.msmMode), 'unknown -> NoMode');
end;

// ---------------------------------------------------------------------------
// ExtendedModeType -> ADIF (MODE, SUBMODE).  NY4I's bench, 2026-10-23: a
// validator rejected <MODE:4>DATA, TR4W's own name for a radio data mode.
// ---------------------------------------------------------------------------

const
   (* ADIF 3.1.6 Mode enumeration (adif.org.uk/316), the MODE column. *)
   ADIFModeEnumeration =
      ',AM,ARDOP,ATV,CHIP,CLO,CONTESTI,CW,DIGITALVOICE,DOMINO,DYNAMIC,FAX,FM,' +
      'FSK441,FSK,FT8,HELL,ISCAT,JT4,JT6M,JT9,JT44,JT65,MFSK,MSK144,MTONE,MT63,' +
      'OLIVIA,OPERA,PAC,PAX,PKT,PSK,PSK2K,Q15,QRA64,ROS,RTTY,RTTYM,SSB,SSTV,' +
      'T10,THOR,THRB,TOR,V4,VOI,WINMOR,WSPR,';

   (* The same enumeration's submodes of the modes TR4W can write, as
     MODE:SUBMODE pairs. *)
   ADIFSubModeEnumeration =
      ',SSB:USB,SSB:LSB,PSK:PSK31,PSK:PSK63,MFSK:FT4,MFSK:JS8,' +
      'DIGITALVOICE:C4FM,DIGITALVOICE:DSTAR,';

procedure TADIFHelperTests.Test_ExtMode_ExportsAnADIFMode_Exhaustive;
var
   e : ExtendedModeType;
   m : string;
   s : string;
begin
   BeginTest('Test_ExtMode_ExportsAnADIFMode_Exhaustive');
   for e := Succ(Low(ExtendedModeType)) to High(ExtendedModeType) do
      begin
      m := ADIFModeForExtMode(e);
      s := ADIFSubModeForExtMode(e);
      CheckTrue(Pos(',' + m + ',', ADIFModeEnumeration) > 0,
                ExtendedModeStringArray[e] + ' exports MODE "' + m +
                '", which is not in the ADIF enumeration');
      if s <> '' then
         begin
         CheckTrue(Pos(',' + m + ':' + s + ',', ADIFSubModeEnumeration) > 0,
                   ExtendedModeStringArray[e] + ' exports SUBMODE "' + s +
                   '", which does not belong to MODE ' + m);
         end;
      end;
end;

procedure TADIFHelperTests.Test_ExtMode_ExportPairs;

   procedure Pair(aExt: ExtendedModeType; const aMode, aSub: string);
   begin
      CheckEquals(aMode, ADIFModeForExtMode(aExt),
                  ExtendedModeStringArray[aExt] + ' MODE');
      CheckEquals(aSub, ADIFSubModeForExtMode(aExt),
                  ExtendedModeStringArray[aExt] + ' SUBMODE');
   end;

begin
   BeginTest('Test_ExtMode_ExportPairs');
   Pair(eCW,     'CW',   '');
   Pair(eCW_R,   'CW',   '');
   Pair(eRTTY,   'RTTY', '');
   Pair(eRTTY_R, 'RTTY', '');
   // NY4I, 2026-10-23: generic data is RTTY, as issue 457.
   Pair(eData,    'RTTY', '');
   Pair(eData_R,  'RTTY', '');
   Pair(eData_FM, 'RTTY', '');
   Pair(eFM,     'FM',   '');
   Pair(eFM_N,   'FM',   '');
   Pair(eWFM,    'FM',   '');
   Pair(eAM,     'AM',   '');
   Pair(eAM_N,   'AM',   '');
   Pair(ePSK31,  'PSK',  'PSK31');
   Pair(ePSK63,  'PSK',  'PSK63');
   Pair(ePSK_R,  'PSK',  '');
   Pair(eJS8,    'MFSK', 'JS8');
   Pair(eFT4,    'MFSK', 'FT4');
   Pair(eMFSK,   'MFSK', '');
   Pair(eFT8,    'FT8',  '');
   Pair(eJT65,   'JT65', '');
   Pair(eC4FM,   'DIGITALVOICE', 'C4FM');
   Pair(eDStar,  'DIGITALVOICE', 'DSTAR');
   Pair(eUSB,    'SSB',  'USB');
   Pair(eLSB,    'SSB',  'LSB');
   Pair(eSSB,    'SSB',  '');
end;

(* EVERY NON-APP_ TAG TR4W CAN WRITE IS A FIELD OF THE ADIF VERSION IT DECLARES.
  NY4I, 2026-10-23: the header said 3.1.0 while MY_ARRL_SECT, a 3.1.3 field, was
  being written. The list below is the QSO Field table of ADIF 3.1.6
  (adif.org.uk/316); APP_ fields are application-defined and always legal, so
  they are not tested. *)
const
   ADIF316QSOFields =
      ',ADDRESS,ADDRESS_INTL,AGE,ALTITUDE,ANT_AZ,ANT_EL,ANT_PATH,ARRL_SECT,' +
      'AWARD_GRANTED,AWARD_SUBMITTED,A_INDEX,BAND,BAND_RX,CALL,CHECK,CLASS,' +
      'CLUBLOG_QSO_UPLOAD_DATE,CLUBLOG_QSO_UPLOAD_STATUS,CNTY,CNTY_ALT,' +
      'COMMENT,COMMENT_INTL,CONT,CONTACTED_OP,CONTEST_ID,COUNTRY,' +
      'COUNTRY_INTL,CQZ,CREDIT_GRANTED,CREDIT_SUBMITTED,DARC_DOK,' +
      'DCL_QSLRDATE,DCL_QSLSDATE,DCL_QSL_RCVD,DCL_QSL_SENT,DISTANCE,DXCC,' +
      'EMAIL,EQSL_AG,EQSL_QSLRDATE,EQSL_QSLSDATE,EQSL_QSL_RCVD,' +
      'EQSL_QSL_SENT,EQ_CALL,FISTS,FISTS_CC,FORCE_INIT,FREQ,FREQ_RX,' +
      'GRIDSQUARE,GRIDSQUARE_EXT,GUEST_OP,HAMLOGEU_QSO_UPLOAD_DATE,' +
      'HAMLOGEU_QSO_UPLOAD_STATUS,HAMQTH_QSO_UPLOAD_DATE,' +
      'HAMQTH_QSO_UPLOAD_STATUS,HRDLOG_QSO_UPLOAD_DATE,' +
      'HRDLOG_QSO_UPLOAD_STATUS,IOTA,IOTA_ISLAND_ID,ITUZ,K_INDEX,LAT,LON,' +
      'LOTW_QSLRDATE,LOTW_QSLSDATE,LOTW_QSL_RCVD,LOTW_QSL_SENT,MAX_BURSTS,' +
      'MODE,MORSE_KEY_INFO,MORSE_KEY_TYPE,MS_SHOWER,MY_ALTITUDE,MY_ANTENNA,' +
      'MY_ANTENNA_INTL,MY_ARRL_SECT,MY_CITY,MY_CITY_INTL,MY_CNTY,' +
      'MY_CNTY_ALT,MY_COUNTRY,MY_COUNTRY_INTL,MY_CQ_ZONE,MY_DARC_DOK,' +
      'MY_DXCC,MY_FISTS,MY_GRIDSQUARE,MY_GRIDSQUARE_EXT,MY_IOTA,' +
      'MY_IOTA_ISLAND_ID,MY_ITU_ZONE,MY_LAT,MY_LON,MY_MORSE_KEY_INFO,' +
      'MY_MORSE_KEY_TYPE,MY_NAME,MY_NAME_INTL,MY_POSTAL_CODE,' +
      'MY_POSTAL_CODE_INTL,MY_POTA_REF,MY_RIG,MY_RIG_INTL,MY_SIG,' +
      'MY_SIG_INFO,MY_SIG_INFO_INTL,MY_SIG_INTL,MY_SOTA_REF,MY_STATE,' +
      'MY_STREET,MY_STREET_INTL,MY_USACA_COUNTIES,MY_VUCC_GRIDS,' +
      'MY_WWFF_REF,NAME,NAME_INTL,NOTES,NOTES_INTL,NR_BURSTS,NR_PINGS,' +
      'OPERATOR,OWNER_CALLSIGN,PFX,POTA_REF,PRECEDENCE,PROP_MODE,' +
      'PUBLIC_KEY,QRZCOM_QSO_DOWNLOAD_DATE,QRZCOM_QSO_DOWNLOAD_STATUS,' +
      'QRZCOM_QSO_UPLOAD_DATE,QRZCOM_QSO_UPLOAD_STATUS,QSLMSG,QSLMSG_INTL,' +
      'QSLMSG_RCVD,QSLRDATE,QSLSDATE,QSL_RCVD,QSL_RCVD_VIA,QSL_SENT,' +
      'QSL_SENT_VIA,QSL_VIA,QSO_COMPLETE,QSO_DATE,QSO_DATE_OFF,QSO_RANDOM,' +
      'QTH,QTH_INTL,REGION,RIG,RIG_INTL,RST_RCVD,RST_SENT,RX_PWR,SAT_MODE,' +
      'SAT_NAME,SFI,SIG,SIG_INFO,SIG_INFO_INTL,SIG_INTL,SILENT_KEY,SKCC,' +
      'SOTA_REF,SRX,SRX_STRING,STATE,STATION_CALLSIGN,STX,STX_STRING,' +
      'SUBMODE,SWL,TEN_TEN,TIME_OFF,TIME_ON,TX_PWR,UKSMG,USACA_COUNTIES,' +
      'VE_PROV,VUCC_GRIDS,WEB,WWFF_REF,';

   (* Every tag written by EmitADIFRecord, the contests' EmitADIF* methods and
     the my-station block. One entry per EmitADIFField name, so a new tag is a
     new entry here AND a field of the spec, or this test fails. *)
   TR4WEmittedFields =
      ',CALL,BAND,QSO_DATE,TIME_ON,TIME_OFF,CONTEST_ID,MODE,SUBMODE,FREQ,' +
      'STATE,OPERATOR,ARRL_SECT,GRIDSQUARE,CLASS,DXCC,CNTY,CQZ,ITUZ,' +
      'STATION_CALLSIGN,RST_SENT,RST_RCVD,QTH,PRECEDENCE,CHECK,NAME,SRX,STX,' +
      'TEN_TEN,AGE,SRX_STRING,STX_STRING,RX_PWR,IOTA,SIG,SIG_INFO,POTA_REF,' +
      'MY_GRIDSQUARE,MY_STATE,MY_CNTY,MY_ARRL_SECT,MY_IOTA,MY_CQ_ZONE,' +
      'MY_ITU_ZONE,MY_DXCC,MY_SIG,MY_SIG_INFO,MY_POTA_REF,DARC_DOK,';
   (* DOK and FOC_NUM, which TR4W wrote until 2026-10-23 and ADIF 3.1.6 does
     not have, are DARC_DOK and the application-defined APP_TR4W_FOC_NUM now
     (APP_ tags are always legal and are not listed). *)

   (* Header fields, ADIF 3.1.6. *)
   ADIF316HeaderFields = ',ADIF_VER,CREATED_TIMESTAMP,PROGRAMID,PROGRAMVERSION,USERDEF,';

procedure TADIFHelperTests.Test_EmittedTagsAreADIF316Fields;
var
   rest : string;
   name : string;
   p    : Integer;
   hdr  : string;
begin
   BeginTest('Test_EmittedTagsAreADIF316Fields');
   CheckEquals('3.1.6', ADIF_SPEC_VERSION, 'declared spec version');
   hdr := EmitADIFHeader('x');
   CheckTrue(Pos('<ADIF_VER:5>3.1.6', hdr) > 0, 'the header declares 3.1.6');
   CheckTrue(Pos(',ADIF_VER,', ADIF316HeaderFields) > 0, 'header field ADIF_VER');
   CheckTrue(Pos(',CREATED_TIMESTAMP,', ADIF316HeaderFields) > 0, 'header field');
   CheckTrue(Pos(',PROGRAMID,', ADIF316HeaderFields) > 0, 'header field');
   CheckTrue(Pos(',PROGRAMVERSION,', ADIF316HeaderFields) > 0, 'header field');

   rest := Copy(TR4WEmittedFields, 2, Length(TR4WEmittedFields));
   while rest <> '' do
      begin
      p := Pos(',', rest);
      name := Copy(rest, 1, p - 1);
      rest := Copy(rest, p + 1, Length(rest));
      CheckTrue(Pos(',' + name + ',', ADIF316QSOFields) > 0,
                name + ' is written but is not a field of ADIF 3.1.6');
      end;
end;

(* THE SHAPES THE EXPORT CHECKS BEFORE IT WRITES (NY4I, 2026-10-23: the ADIF
  specification governs). *)
procedure TADIFHelperTests.Test_ValueShapes;
begin
   BeginTest('Test_ValueShapes');
   CheckTrue(IsADIFNumber('100'), 'number 100');
   CheckTrue(IsADIFNumber('1.5'), 'number 1.5');
   CheckTrue(IsADIFNumber('-3'), 'number -3');
   CheckFalse(IsADIFNumber('K'), 'K is not a number');
   CheckFalse(IsADIFNumber('KW'), 'KW is not a number');
   CheckFalse(IsADIFNumber(''), 'empty is not a number');
   CheckFalse(IsADIFNumber('1.'), '1. is not a number');
   CheckFalse(IsADIFNumber('1.2.3'), '1.2.3 is not a number');

   CheckTrue(IsADIFGridSquare('FN'), 'grid 2');
   CheckTrue(IsADIFGridSquare('FN31'), 'grid 4');
   CheckTrue(IsADIFGridSquare('fn31pr'), 'grid 6, any case');
   CheckTrue(IsADIFGridSquare('FN31PR12'), 'grid 8');
   CheckFalse(IsADIFGridSquare('CT'), 'CT is not a grid (C-T: T is past R)');
   CheckFalse(IsADIFGridSquare('FN3'), 'grid 3 characters');
   CheckFalse(IsADIFGridSquare('FN31P'), 'grid 5 characters');
   CheckFalse(IsADIFGridSquare('FN31ZZ'), 'subsquare past X');
   CheckFalse(IsADIFGridSquare('SS31'), 'S is past R');
   CheckFalse(IsADIFGridSquare(''), 'empty');

   CheckTrue(IsADIFIOTARef('EU-005'), 'IOTA');
   CheckFalse(IsADIFIOTARef('CT'), 'CT is not an IOTA');
   CheckFalse(IsADIFIOTARef('EU005'), 'IOTA without the hyphen');
   CheckFalse(IsADIFIOTARef('EU-05'), 'IOTA with two digits');

   CheckTrue(ADIFZoneInRange(1, 40), 'CQ zone 1');
   CheckTrue(ADIFZoneInRange(40, 40), 'CQ zone 40');
   CheckFalse(ADIFZoneInRange(0, 40), 'zone 0');
   CheckFalse(ADIFZoneInRange(41, 40), 'CQ zone 41');
   CheckTrue(ADIFZoneInRange(90, 90), 'ITU zone 90');
   CheckFalse(ADIFZoneInRange(91, 90), 'ITU zone 91');
   CheckEquals('', ADIFZoneField('CQZ', 0, 40), 'no CQZ for zone 0');
   CheckEquals('<CQZ:2>05 ', ADIFZoneField('CQZ', 5, 40), 'CQZ stays two digits');
   CheckEquals('<ITUZ:2>27 ', ADIFZoneField('ITUZ', 27, 90), 'ITUZ');

   // The 3.1.6 Section enumeration, including the codes added after 2022.
   CheckTrue(IsADIFARRLSection('GH'), 'GH (2023)');
   CheckTrue(IsADIFARRLSection('NB'), 'NB (2023)');
   CheckTrue(IsADIFARRLSection('NS'), 'NS (2023)');
   CheckTrue(IsADIFARRLSection('PE'), 'PE (2020)');
   CheckTrue(IsADIFARRLSection('TER'), 'TER (2023)');
   CheckTrue(IsADIFARRLSection('mdc'), 'MDC, any case');
   CheckTrue(IsADIFARRLSection('ON'), 'ON: deleted, still in the enumeration');
   CheckFalse(IsADIFARRLSection('DX'), 'DX is not a section');
   CheckFalse(IsADIFARRLSection('MD'), 'MD is an alias of MDC');
   CheckFalse(IsADIFARRLSection('NY'), 'NY is a state, not a section');
   CheckFalse(IsADIFARRLSection(''), 'empty');
end;

procedure TADIFHelperTests.Test_InvalidValuesAreNotWritten;
var
   qso   : ContestExchange;
   facts : TQsoMyFacts;
   text  : string;

   function Q(aContest: ContestType; const aQTH, aKey: string): ContestExchange;
   begin
      Result := Default(ContestExchange);
      Result.ceContest := ContestHandleOf(aContest);
      Result.QTHString := ShortString(aQTH);
      Result.DomesticQTH := ShortString(aKey);
   end;

begin
   BeginTest('Test_InvalidValuesAreNotWritten');

   // ARRL_SECT: a section ADIF has, or nothing.
   CheckEquals('', ContestIdentity(ARRLSSCW).EmitADIFContestFields(Q(ARRLSSCW, 'DX', '')),
               'SS: DX writes no ARRL_SECT');
   CheckEquals('<ARRL_SECT:3>MDC ',
               ContestIdentity(ARRLSSCW).EmitADIFContestFields(Q(ARRLSSCW, 'MD', 'Mdc')),
               'SS: the alias MD is written as its section MDC');
   CheckEquals('', ContestIdentity(ARRLSSCW).EmitADIFContestFields(Q(ARRLSSCW, 'NY', '')),
               'SS: NY is no section');
   qso := Q(ARRLFIELDDAY, 'HI', '');
   qso.QTH.CountryID := 'KH6';
   CheckFalse(Pos('<ARRL_SECT', ContestIdentity(ARRLFIELDDAY).EmitADIFContestFields(qso)) > 0,
              'Field Day: HI is no section');
   qso := Q(WINTERFIELDDAY, 'FL', '');
   qso.QTH.CountryID := 'K';
   CheckFalse(Pos('<ARRL_SECT', ContestIdentity(WINTERFIELDDAY).EmitADIFContestFields(qso)) > 0,
              'Winter Field Day: FL is no section');
   qso := Q(WINTERFIELDDAY, 'EPA', 'EPA');
   qso.QTH.CountryID := 'K';
   CheckTrue(Pos('<ARRL_SECT:3>EPA', ContestIdentity(WINTERFIELDDAY).EmitADIFContestFields(qso)) > 0,
             'Winter Field Day: EPA is written');

   // GRIDSQUARE: a well-formed locator, or nothing.
   CheckEquals('', ContestIdentity(WWDIGI).EmitADIFContestFields(Q(WWDIGI, 'CT', '')),
               'WW Digi: CT is no grid');
   CheckEquals('', ContestIdentity(ARRLDIGI).EmitADIFContestFields(Q(ARRLDIGI, 'CT', '')),
               'ARRL Digi: CT is no grid');
   CheckEquals('', ContestIdentity(BATAVIA_FT8).EmitADIFContestFields(Q(BATAVIA_FT8, 'CT', '')),
               'Batavia: CT is no grid');
   CheckEquals('<GRIDSQUARE:4>FN31 ',
               ContestIdentity(WWDIGI).EmitADIFContestFields(Q(WWDIGI, 'FN31', '')),
               'WW Digi: FN31 is written');

   // IOTA: a reference, or nothing.
   CheckEquals('', ContestIdentity(IOTA).EmitADIFContestFields(Q(IOTA, 'CT', 'CT')),
               'IOTA contest: CT is no island');

   // (CQZ / ITUZ of the record are written by PostUnit through
   // ADIFZoneField, which Test_ValueShapes pins.)

   // Our station: only values ADIF allows.
   facts := NotCapturedMyFacts;
   facts.Source := mfsLogged;
   facts.Call := 'K1ABC';
   facts.Grid := 'CT';
   facts.Section := 'DX';
   facts.Iota := 'CT';
   facts.CQZone := 0;
   facts.ITUZone := 99;
   facts.Park := 'XX';
   facts.State := 'NE';
   qso := Q(CQWWCW, 'CT', '');
   text := EmitADIFMyStationFields(qso, facts, '');
   CheckTrue(Pos('<MY_GRIDSQUARE', text) = 0, 'MY_GRIDSQUARE CT: ' + text);
   CheckTrue(Pos('<MY_ARRL_SECT', text) = 0, 'MY_ARRL_SECT DX: ' + text);
   CheckTrue(Pos('<MY_IOTA', text) = 0, 'MY_IOTA CT: ' + text);
   CheckTrue(Pos('<MY_CQ_ZONE', text) = 0, 'MY_CQ_ZONE 0: ' + text);
   CheckTrue(Pos('<MY_ITU_ZONE', text) = 0, 'MY_ITU_ZONE 99: ' + text);
   CheckTrue(Pos('<MY_POTA_REF', text) = 0, 'MY_POTA_REF XX: ' + text);
   CheckTrue(Pos('<MY_SIG_INFO:2>XX', text) > 0, 'the text park stays in MY_SIG_INFO: ' + text);
   CheckTrue(Pos('<MY_STATE:2>NE', text) > 0, 'a valid fact is still written: ' + text);

   facts.Grid := 'FN31pr';
   facts.Section := 'ENY';
   facts.Iota := 'NA-001';
   facts.CQZone := 5;
   facts.ITUZone := 8;
   facts.Park := 'US-1234';
   text := EmitADIFMyStationFields(qso, facts, '');
   CheckTrue(Pos('<MY_GRIDSQUARE:6>FN31pr', text) > 0, 'a good grid: ' + text);
   CheckTrue(Pos('<MY_ARRL_SECT:3>ENY', text) > 0, 'a good section: ' + text);
   CheckTrue(Pos('<MY_IOTA:6>NA-001', text) > 0, 'a good IOTA: ' + text);
   CheckTrue(Pos('<MY_CQ_ZONE:1>5', text) > 0, 'a good CQ zone: ' + text);
   CheckTrue(Pos('<MY_ITU_ZONE:1>8', text) > 0, 'a good ITU zone: ' + text);
   CheckTrue(Pos('<MY_POTA_REF:7>US-1234', text) > 0, 'a good park: ' + text);
end;

procedure TADIFHelperTests.Test_OldDOKAndFOCNamesStillImport;
var
   fields : TADIFFieldList;
   exch   : ContestExchange;
   temps  : TADIFRecordTemps;

   procedure ReadTags(const aTags: string);
   begin
      CheckTrue(ParseADIFFieldsList(aTags, fields), 'parsed ' + aTags);
      InitContestExchangeForParse(exch);
      ApplyADIFFieldsToExchange(fields, exch, temps);
   end;

begin
   BeginTest('Test_OldDOKAndFOCNamesStillImport');
   // Written since 2026-10-23.
   ReadTags('<CALL:4>DL1A <DARC_DOK:3>B01 <EOR>');
   CheckEquals('B01', temps.DOK, 'DARC_DOK');
   ReadTags('<CALL:4>G3AB <APP_TR4W_FOC_NUM:4>1234 <EOR>');
   CheckEquals('1234', temps.FOC_Num, 'APP_TR4W_FOC_NUM');
   // Written before it, and still read.
   ReadTags('<CALL:4>DL1A <DOK:3>B01 <EOR>');
   CheckEquals('B01', temps.DOK, 'the old DOK');
   ReadTags('<CALL:4>G3AB <FOC_NUM:4>1234 <EOR>');
   CheckEquals('1234', temps.FOC_Num, 'the old FOC_NUM');
end;

procedure TADIFHelperTests.Test_GenericDataMode_SaysSoInTheFile;
var
   rec     : ContestExchange;
   s       : string;
   records : TContestExchangeArray;
   none    : TContestExchangeArray;
   e       : ExtendedModeType;
begin
   BeginTest('Test_GenericDataMode_SaysSoInTheFile');
   for e := Succ(Low(ExtendedModeType)) to High(ExtendedModeType) do
      begin
      rec := Default(ContestExchange);
      rec.Callsign := 'KG1S';
      rec.Band     := Band20;
      rec.Mode     := Digital;
      rec.ExtMode  := e;
      s := EmitADIFRecord(rec);
      // The per-record field is there for the generic data modes only.
      CheckTrue((e in [eData, eData_R, eData_FM]) =
                (Pos('<APP_TR4W_MODE_ASSUMED:1>Y', s) > 0),
                ExtendedModeStringArray[e] + ' MODE_ASSUMED flag');
      end;

   // Round trip: export, import -> the data mode comes back, not RTTY.
   rec := Default(ContestExchange);
   rec.Callsign := 'KG1S';
   rec.Band     := Band20;
   rec.Mode     := Digital;
   rec.ExtMode  := eData;
   s := EmitADIFRecord(rec) + '<EOR>';
   CheckTrue(Pos('<MODE:4>RTTY', s) > 0, 'exported as MODE RTTY');
   CheckEquals(1, ImportADIFFromString(s, records), 'one record read back');
   CheckEquals(Integer(eData), Integer(records[0].ExtMode),
               'eData restored by the flag');

   // A real RTTY QSO (no flag) stays RTTY.
   rec.ExtMode := eRTTY;
   s := EmitADIFRecord(rec) + '<EOR>';
   CheckEquals(1, ImportADIFFromString(s, records), 'RTTY read back');
   CheckEquals(Integer(eRTTY), Integer(records[0].ExtMode), 'RTTY stays RTTY');

   // The flag may precede the MODE in a file.
   CheckEquals(1, ImportADIFFromString(
      '<CALL:4>KG1S <APP_TR4W_MODE_ASSUMED:1>Y <MODE:4>RTTY <EOR>', records),
      'flag before MODE');
   CheckEquals(Integer(eData), Integer(records[0].ExtMode), 'order-independent');

   // The header line: only when there are such records, with the count.
   SetLength(none, 2);
   none[0] := Default(ContestExchange);
   none[1] := Default(ContestExchange);
   none[0].ExtMode := eRTTY;
   none[1].ExtMode := eCW_R;
   CheckEquals(0, CountGenericDataModeQSOs(none), 'no generic data records');
   CheckEquals('', ADIFGenericDataModeNote(0), 'no note for none');
   none[0].ExtMode := eData_R;
   none[1].ExtMode := eData_FM;
   CheckEquals(2, CountGenericDataModeQSOs(none), 'two generic data records');
   CheckEquals('2 QSO(s) logged in an unspecified DATA mode are exported ' +
               'as MODE RTTY.', ADIFGenericDataModeNote(2), 'the note');
   CheckTrue(Pos('<', ADIFGenericDataModeNote(2)) = 0,
             'header text must hold no "<"');
end;

procedure TADIFHelperTests.Test_OldTR4WSpellingsStillImport;
var
   m : ModeAndExtendedModeType;
begin
   BeginTest('Test_OldTR4WSpellingsStillImport');
   // Files TR4W wrote before 2026-10-23 carry its own names in MODE.
   m := GetADIFMode('DATA');
   CheckEquals(Integer(eData),   Integer(m.msmExtendedMode), 'DATA');
   m := GetADIFMode('CW-R');
   CheckEquals(Integer(eCW_R),   Integer(m.msmExtendedMode), 'CW-R');
   m := GetADIFMode('RTTY-R');
   CheckEquals(Integer(eRTTY_R), Integer(m.msmExtendedMode), 'RTTY-R');
   m := GetADIFMode('DATA-R');
   CheckEquals(Integer(eData_R), Integer(m.msmExtendedMode), 'DATA-R');
   m := GetADIFMode('FM-N');
   CheckEquals(Integer(eFM_N),   Integer(m.msmExtendedMode), 'FM-N');
   m := GetADIFMode('D-STAR');
   CheckEquals(Integer(eDStar),  Integer(m.msmExtendedMode), 'D-STAR');
   // and the submodes the new export writes.
   m := GetADIFSubMode('PSK63');
   CheckEquals(Integer(ePSK63),  Integer(m.msmExtendedMode), 'PSK63 sub');
   m := GetADIFSubMode('C4FM');
   CheckEquals(Integer(eC4FM),   Integer(m.msmExtendedMode), 'C4FM sub');
   m := GetADIFSubMode('DSTAR');
   CheckEquals(Integer(eDStar),  Integer(m.msmExtendedMode), 'DSTAR sub');
end;

// ---------------------------------------------------------------------------
// ADIFDateStringToQSOTime
// ---------------------------------------------------------------------------

procedure TADIFHelperTests.Test_ADIFDateStringToQSOTime_Valid;
var
   t : TQSOTime;
begin
   BeginTest('Test_ADIFDateStringToQSOTime_Valid');
   FillChar(t, SizeOf(t), 0);
   CheckTrue(ADIFDateStringToQSOTime('20260510', t),
             'YYYYMMDD parses OK');
   // Year is stored as YY (2-digit), so 2026 -> 26.
   CheckEquals(26, Integer(t.qtYear),  'qtYear (2-digit)');
   CheckEquals(5,  Integer(t.qtMonth), 'qtMonth');
   CheckEquals(10, Integer(t.qtDay),   'qtDay');
end;

procedure TADIFHelperTests.Test_ADIFDateStringToQSOTime_InvalidLength;
var
   t : TQSOTime;
begin
   BeginTest('Test_ADIFDateStringToQSOTime_InvalidLength');
   FillChar(t, SizeOf(t), 0);
   CheckFalse(ADIFDateStringToQSOTime('2026', t), 'too short');
   CheckFalse(ADIFDateStringToQSOTime('202605101', t), 'too long');
   CheckFalse(ADIFDateStringToQSOTime('', t), 'empty');
end;

procedure TADIFHelperTests.Test_ADIFDateStringToQSOTime_NonNumeric;
var
   t : TQSOTime;
begin
   BeginTest('Test_ADIFDateStringToQSOTime_NonNumeric');
   FillChar(t, SizeOf(t), 0);
   CheckFalse(ADIFDateStringToQSOTime('2026XX10', t),
              'non-numeric chars rejected');
end;

// ---------------------------------------------------------------------------
// ADIFTimeStringToQSOTime
// ---------------------------------------------------------------------------

procedure TADIFHelperTests.Test_ADIFTimeStringToQSOTime_HHMM;
var
   t : TQSOTime;
begin
   BeginTest('Test_ADIFTimeStringToQSOTime_HHMM');
   FillChar(t, SizeOf(t), 0);
   CheckTrue(ADIFTimeStringToQSOTime('1547', t), '4-digit HHMM parses');
   CheckEquals(15, Integer(t.qtHour),   'qtHour');
   CheckEquals(47, Integer(t.qtMinute), 'qtMinute');
   CheckEquals(0,  Integer(t.qtSecond), 'qtSecond defaults to 0');
end;

procedure TADIFHelperTests.Test_ADIFTimeStringToQSOTime_HHMMSS;
var
   t : TQSOTime;
begin
   BeginTest('Test_ADIFTimeStringToQSOTime_HHMMSS');
   FillChar(t, SizeOf(t), 0);
   CheckTrue(ADIFTimeStringToQSOTime('154729', t),
             '6-digit HHMMSS parses');
   CheckEquals(15, Integer(t.qtHour),   'qtHour');
   CheckEquals(47, Integer(t.qtMinute), 'qtMinute');
   CheckEquals(29, Integer(t.qtSecond), 'qtSecond');
end;

procedure TADIFHelperTests.Test_ADIFTimeStringToQSOTime_InvalidLength;
var
   t : TQSOTime;
begin
   BeginTest('Test_ADIFTimeStringToQSOTime_InvalidLength');
   FillChar(t, SizeOf(t), 0);
   CheckFalse(ADIFTimeStringToQSOTime('154',     t), '3 digits');
   CheckFalse(ADIFTimeStringToQSOTime('15473',   t), '5 digits');
   CheckFalse(ADIFTimeStringToQSOTime('1547290', t), '7 digits');
   CheckFalse(ADIFTimeStringToQSOTime('',        t), 'empty');
end;

procedure TADIFHelperTests.Test_ADIFTimeStringToQSOTime_NonNumeric;
var
   t : TQSOTime;
begin
   BeginTest('Test_ADIFTimeStringToQSOTime_NonNumeric');
   FillChar(t, SizeOf(t), 0);
   CheckFalse(ADIFTimeStringToQSOTime('15XX', t),
              'non-numeric chars rejected');
end;

// ---------------------------------------------------------------------------
// IsValidGUID
// ---------------------------------------------------------------------------

procedure TADIFHelperTests.Test_IsValidGUID_Hyphenated;
begin
   BeginTest('Test_IsValidGUID_Hyphenated');
   CheckTrue(IsValidGUID('3deea564-2f91-4449-ae14-2525b2a1518d'),
             'lowercase hyphenated');
   CheckTrue(IsValidGUID('3DEEA564-2F91-4449-AE14-2525B2A1518D'),
             'uppercase hyphenated');
   CheckTrue(IsValidGUID('3DeEa564-2F91-4449-Ae14-2525b2a1518D'),
             'mixed case hyphenated');
end;

procedure TADIFHelperTests.Test_IsValidGUID_Unhyphenated;
begin
   BeginTest('Test_IsValidGUID_Unhyphenated');
   CheckTrue(IsValidGUID('3deea56f2c1840c589cd117d3374905e'),
             'lowercase 32-hex');
   CheckTrue(IsValidGUID('3DEEA56F2C1840C589CD117D3374905E'),
             'uppercase 32-hex');
end;

procedure TADIFHelperTests.Test_IsValidGUID_Braced;
begin
   BeginTest('Test_IsValidGUID_Braced');
   CheckTrue(IsValidGUID('{3deea564-2f91-4449-ae14-2525b2a1518d}'),
             'hyphenated with braces');
   CheckTrue(IsValidGUID('{3deea56f2c1840c589cd117d3374905e}'),
             'unhyphenated with braces');
end;

procedure TADIFHelperTests.Test_IsValidGUID_RejectsShort;
begin
   BeginTest('Test_IsValidGUID_RejectsShort');
   CheckFalse(IsValidGUID('3deea56f'),              '8 hex chars');
   CheckFalse(IsValidGUID('3deea56f2c1840c589cd117d3374'),
                                                    '28 hex chars');
end;

procedure TADIFHelperTests.Test_IsValidGUID_RejectsNonHex;
begin
   BeginTest('Test_IsValidGUID_RejectsNonHex');
   CheckFalse(IsValidGUID('3deea56f2c1840c589cd117d337490ZZ'),
              'Z is not hex');
   CheckFalse(IsValidGUID('3deea564-2f91-4449-ae14-2525b2a1518G'),
              'G in hyphenated form');
end;

procedure TADIFHelperTests.Test_IsValidGUID_RejectsEmpty;
begin
   BeginTest('Test_IsValidGUID_RejectsEmpty');
   CheckFalse(IsValidGUID(''), 'empty string');
end;

procedure TADIFHelperTests.Test_IsValidGUID_RejectsMisplacedHyphens;
begin
   BeginTest('Test_IsValidGUID_RejectsMisplacedHyphens');
   // Total of 36 chars but hyphens in wrong positions
   CheckFalse(IsValidGUID('3deea5642f-91-4449-ae14-2525b2a1518d'),
              'hyphen at wrong position');
end;

(* THE INVERSE OF ResolveSRXString, which prepends the received RST so the
  field is symmetric with STX_STRING. Nothing took it off again until an
  imported log was re-exported and NY4I's IARU QSOs came back carrying a QTH
  of '59 8' -- the RST and the zone, stored as though they were a location. *)
procedure TADIFHelperTests.Test_ExchangeFromSRX_StripsTheReceivedRST;
begin
   BeginTest('the received RST comes off an SRX_STRING');
   CheckEquals('8', ExchangeFromSRXString('59 8', 59), 'a zone');
   CheckEquals('PIN', ExchangeFromSRXString('599 PIN', 599), 'a county');
   CheckEquals('ARRL', ExchangeFromSRXString('59 ARRL', 59), 'an IARU society');
   (* Extra spacing is the operator's, not the format's. *)
   CheckEquals('MD', ExchangeFromSRXString('599   MD  ', 599), 'padded');
end;

(* Field Day sends '1A EPA' and no RST at all. Stripping "the first token if it
  looks numeric" would eat the class; matching the RST cannot. *)
procedure TADIFHelperTests.Test_ExchangeFromSRX_LeavesAnExchangeWithNoRST;
begin
   BeginTest('an exchange that carries no RST is left alone');
   CheckEquals('1A EPA', ExchangeFromSRXString('1A EPA', 59), 'Field Day');
   CheckEquals('3I WCF', ExchangeFromSRXString('3I WCF', 599), 'Winter Field Day');
   CheckEquals('', ExchangeFromSRXString('', 59), 'nothing at all');
end;

(* A leading number that is NOT the received RST is part of the exchange -- a
  serial number, a zone sent without one. Only the RST comes off. *)
procedure TADIFHelperTests.Test_ExchangeFromSRX_LeavesAnRSTThatIsNotTheReceivedOne;
begin
   BeginTest('only the RST this QSO received is removed');
   CheckEquals('599 PIN', ExchangeFromSRXString('599 PIN', 59),
               'the RST received was 59, so 599 is exchange text');
   CheckEquals('001 NY', ExchangeFromSRXString('001 NY', 599), 'a serial number');
end;

(* THE ROUND TRIP HAS TO CLOSE. ResolveSRXString writes the bare RST when a QSO
  carried no exchange at all, so reading that back as an exchange of '59' made
  the field grow a token on every export -- '59' became '59 59'. Fourteen
  GENERAL QSO contacts in the corpus did exactly that. *)
procedure TADIFHelperTests.Test_ExchangeFromSRX_AnRSTOnItsOwnIsNoExchange;
begin
   BeginTest('an SRX_STRING that is only the RST carries no exchange');
   CheckEquals('', ExchangeFromSRXString('59', 59), 'a bare 59');
   CheckEquals('', ExchangeFromSRXString('599', 599), 'a bare 599');
   CheckEquals('', ExchangeFromSRXString('  59  ', 59), 'padded');
   (* A number that is NOT this QSO's RST is exchange text, as ever. *)
   CheckEquals('599', ExchangeFromSRXString('599', 59), 'not the received RST');
end;



procedure TADIFHelperTests.RunAllTests;
begin
   Test_GetADIFBand_KnownBands;
   Test_GetADIFBand_UnknownBand;
   Test_GetADIFBand_CaseInsensitive;

   Test_GetADIFMode_KnownModes;
   Test_GetADIFMode_UnknownMode;

   Test_GetADIFSubMode_KnownSubModes;
   Test_GetADIFSubMode_UnknownSubMode;

   Test_ExtMode_ExportsAnADIFMode_Exhaustive;
   Test_ExtMode_ExportPairs;
   Test_EmittedTagsAreADIF316Fields;
   Test_ValueShapes;
   Test_InvalidValuesAreNotWritten;
   Test_OldDOKAndFOCNamesStillImport;
   Test_GenericDataMode_SaysSoInTheFile;
   Test_OldTR4WSpellingsStillImport;

   Test_ADIFDateStringToQSOTime_Valid;
   Test_ADIFDateStringToQSOTime_InvalidLength;
   Test_ADIFDateStringToQSOTime_NonNumeric;

   Test_ADIFTimeStringToQSOTime_HHMM;
   Test_ADIFTimeStringToQSOTime_HHMMSS;
   Test_ADIFTimeStringToQSOTime_InvalidLength;
   Test_ADIFTimeStringToQSOTime_NonNumeric;

   Test_IsValidGUID_Hyphenated;
   Test_IsValidGUID_Unhyphenated;
   Test_IsValidGUID_Braced;
   Test_IsValidGUID_RejectsShort;
   Test_IsValidGUID_RejectsNonHex;
   Test_IsValidGUID_RejectsEmpty;
   Test_IsValidGUID_RejectsMisplacedHyphens;
   Test_ExchangeFromSRX_StripsTheReceivedRST;
   Test_ExchangeFromSRX_LeavesAnExchangeWithNoRST;
   Test_ExchangeFromSRX_LeavesAnRSTThatIsNotTheReceivedOne;
   Test_ExchangeFromSRX_AnRSTOnItsOwnIsNoExchange;
end;

end.
