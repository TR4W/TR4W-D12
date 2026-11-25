unit uTestWSJTXExchangeText;
{$I ..\..\src\tr4w.inc}

(*
   A DECODE ADDRESSED TO US, AS THE EXCHANGE WINDOW'S TEXT (2026-11-25).

   uWSJTXExchangeText reads 'NY4I F6HUK -15' and the like and says what the
   contest's own fields would hold. A pure function over strings and the
   class's field list, so the whole table is checked here without a window.

   WRITTEN WITHOUT BEING RUN (NY4I was testing live; no test binary was built).
*)

interface

uses
   SysUtils,
   uTR4WTestFramework;

type
   TWSJTXExchangeTextTests = class(TTestCase)
   private
      procedure Test_AReportToUsGivesTheRST;
      procedure Test_ARepeatedReportGivesTheSameText;
      procedure Test_RRR_RR73_And_73_CarryNothing;
      procedure Test_AMessageNotToUsOrNotFromTheDXGivesNothing;
      procedure Test_HashedAndPortableCallsAreComparedByBaseCall;
      procedure Test_GarbageGivesNothing;
      procedure Test_RSTAndQTHTakesTheReportThenTheGrid;
      procedure Test_MessagesAccumulateWithinOneQSO;
      procedure Test_GeneralQSOGetsTheReportAlone;
      procedure Test_GeneralQSODigitalGetsSignedReportAndGrid;
      procedure Test_TheLoggedCallIsNotPutBack;
      procedure Test_OnlyAnOpeningMessageEndsTheSuppression;
      procedure Test_FieldDayGetsTheClassAndSection;
      procedure Test_AClassWithASerialGetsNothing;
      procedure Test_AGridOnlyClassGetsTheGrid;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   VC,
   uExchangeFields,
   uWSJTXReport,
   uWSJTXExchangeText;

const
   ME = 'NY4I';
   DX = 'F6HUK';

function Decode(const aFields: ExchangeInformationRecord;
                const aMessage: string; out aText: string): boolean;
begin
   Result := WSJTXDecodeToExchangeText(aFields, aMessage, ME, DX, aText);
end;

procedure TWSJTXExchangeTextTests.Test_AReportToUsGivesTheRST;
var
   text: string;
begin
   BeginTest('Test_AReportToUsGivesTheRST');
   (* -15 is in the 519 band (WSJTXSnrToRST: below -14, at or above -20). *)
   CheckTrue(Decode(ExchangeFieldsRSTQTH, 'NY4I F6HUK -15', text), '-15');
   CheckEquals('519', text, '-15 as an RST');
   CheckTrue(Decode(ExchangeFieldsRSTQTH, 'NY4I F6HUK R-18', text), 'R-18');
   CheckEquals('519', text, 'R-18 as an RST');
   CheckTrue(Decode(ExchangeFieldsRSTQTH, 'NY4I F6HUK +03', text), '+03');
   CheckEquals('549', text, '+03 as an RST');
   CheckTrue(Decode(ExchangeFieldsRSTQTH, 'NY4I F6HUK R+03', text), 'R+03');
   CheckEquals('549', text, 'R+03 as an RST');
   (* WSJT-X's low-confidence annotations are not part of the message. *)
   CheckTrue(Decode(ExchangeFieldsRSTQTH, 'NY4I F6HUK -15            a7', text),
             'a7');
   CheckEquals('519', text, 'a7 is dropped');
end;

procedure TWSJTXExchangeTextTests.Test_ARepeatedReportGivesTheSameText;
var
   a, b: string;
begin
   BeginTest('Test_ARepeatedReportGivesTheSameText');
   (* 06:02:56 and 06:03:27 both carried 'NY4I F6HUK -15': the same text, so
     the window is not rewritten. *)
   CheckTrue(Decode(ExchangeFieldsRSTQTH, 'NY4I F6HUK -15', a), 'first');
   CheckTrue(Decode(ExchangeFieldsRSTQTH, 'NY4I F6HUK -15', b), 'second');
   CheckEquals(a, b, 'identical');
end;

procedure TWSJTXExchangeTextTests.Test_RRR_RR73_And_73_CarryNothing;
var
   text: string;
begin
   BeginTest('Test_RRR_RR73_And_73_CarryNothing');
   CheckFalse(Decode(ExchangeFieldsRSTQTH, 'NY4I F6HUK RR73', text), 'RR73');
   CheckEquals('', text, 'RR73 text');
   CheckFalse(Decode(ExchangeFieldsRSTQTH, 'NY4I F6HUK RRR', text), 'RRR');
   CheckFalse(Decode(ExchangeFieldsRSTQTH, 'NY4I F6HUK 73', text), '73');
end;

procedure TWSJTXExchangeTextTests.Test_AMessageNotToUsOrNotFromTheDXGivesNothing;
var
   text: string;
begin
   BeginTest('Test_AMessageNotToUsOrNotFromTheDXGivesNothing');
   CheckFalse(Decode(ExchangeFieldsRSTQTH, 'CQ F6HUK JN06', text),
              'a CQ is not addressed to us');
   CheckFalse(Decode(ExchangeFieldsRSTQTH, 'K1ABC F6HUK -15', text),
              'addressed to somebody else');
   CheckFalse(Decode(ExchangeFieldsRSTQTH, 'NY4I K1ABC -15', text),
              'from a station that is not the DX call');
   CheckFalse(Decode(ExchangeFieldsRSTQTH, 'F6HUK NY4I -15', text),
              'our own transmission, reversed');
end;

procedure TWSJTXExchangeTextTests.Test_HashedAndPortableCallsAreComparedByBaseCall;
var
   text: string;
begin
   BeginTest('Test_HashedAndPortableCallsAreComparedByBaseCall');
   CheckTrue(Decode(ExchangeFieldsRSTQTH, '<NY4I> F6HUK +03', text),
             'hashed call to us');
   CheckEquals('549', text, 'hashed');
   CheckTrue(Decode(ExchangeFieldsRSTQTH, 'NY4I F6HUK/P -15', text),
             'portable DX');
   CheckEquals('519', text, 'portable');
   CheckTrue(Decode(ExchangeFieldsRSTQTH, 'NY4I DL/F6HUK -15', text),
             'prefix DX');
   CheckEquals('F6HUK', WSJTXBaseCall('<F6HUK/P>'), 'base call, hash and suffix');
   CheckEquals('F6HUK', WSJTXBaseCall('DL/F6HUK'), 'base call, prefix');
   CheckEquals('F6HUK', WSJTXBaseCall('f6huk'), 'base call, case');
end;

procedure TWSJTXExchangeTextTests.Test_GarbageGivesNothing;
var
   text: string;
begin
   BeginTest('Test_GarbageGivesNothing');
   CheckFalse(Decode(ExchangeFieldsRSTQTH, '', text), 'empty');
   CheckFalse(Decode(ExchangeFieldsRSTQTH, 'NY4I', text), 'one word');
   CheckFalse(Decode(ExchangeFieldsRSTQTH, 'NY4I F6HUK', text), 'two words');
   CheckFalse(Decode(ExchangeFieldsRSTQTH, 'NY4I F6HUK ZZZZZZZZ', text),
              'no exchange in the tail');
   CheckFalse(Decode(ExchangeFieldsRSTQTH, '   ', text), 'blanks');
   CheckFalse(WSJTXDecodeToExchangeText(ExchangeFieldsRSTQTH, 'NY4I F6HUK -15',
                                        '', DX, text), 'no operator call');
end;

procedure TWSJTXExchangeTextTests.Test_RSTAndQTHTakesTheReportThenTheGrid;
var
   text: string;
begin
   BeginTest('Test_RSTAndQTHTakesTheReportThenTheGrid');
   CheckTrue(Decode(ExchangeFieldsRSTQTH, 'NY4I F6HUK JN06', text), 'a grid');
   CheckEquals('JN06', text, 'the grid alone, no report yet');
end;

procedure TWSJTXExchangeTextTests.Test_MessagesAccumulateWithinOneQSO;
var
   parts: TWSJTXReceivedParts;
   text: string;
begin
   BeginTest('Test_MessagesAccumulateWithinOneQSO');
   parts := TWSJTXReceivedParts.Create;
   try
      parts.Clear;
      CheckTrue(WSJTXParseAddressedMessage('NY4I F6HUK JN06', ME, DX, parts),
                'the first reply carries the grid');
      CheckTrue(WSJTXParseAddressedMessage('NY4I F6HUK R-18', ME, DX, parts),
                'the next carries the report');
      CheckTrue(WSJTXExchangeFromParts(ExchangeFieldsRSTQTH, parts, text),
                'composed');
      CheckEquals('519 JN06', text, 'report then grid: what was said in both');
      (* The sign-off adds nothing and takes nothing away. *)
      CheckFalse(WSJTXParseAddressedMessage('NY4I F6HUK RR73', ME, DX, parts),
                 'RR73');
      CheckTrue(WSJTXExchangeFromParts(ExchangeFieldsRSTQTH, parts, text),
                'still composed');
      CheckEquals('519 JN06', text, 'unchanged');
      parts.Clear;
      CheckFalse(WSJTXExchangeFromParts(ExchangeFieldsRSTQTH, parts, text),
                 'cleared: nothing');
   finally
      parts.Free;
   end;
end;

procedure TWSJTXExchangeTextTests.Test_GeneralQSOGetsTheReportAlone;
var
   text: string;
begin
   BeginTest('Test_GeneralQSOGetsTheReportAlone');
   (* RST, name and QTH: the typed form reads a second word as the NAME, so
     only the leading RST is safe; the grid arrives with the logged record. *)
   CheckTrue(Decode(ExchangeFieldsRSTNameQTH, 'NY4I F6HUK -15', text), 'report');
   CheckEquals('519', text, 'the report alone');
   CheckFalse(Decode(ExchangeFieldsRSTNameQTH, 'NY4I F6HUK JN06', text),
              'a grid alone gives General QSO nothing');
end;

(* ON A DIGITAL QSO General QSO gets the report as WSJT-X sent it, then the
   grid, accumulated across messages (NY4I, 2026-11-25). *)
procedure TWSJTXExchangeTextTests.Test_GeneralQSODigitalGetsSignedReportAndGrid;
var
   parts: TWSJTXReceivedParts;
   text: string;
begin
   BeginTest('Test_GeneralQSODigitalGetsSignedReportAndGrid');
   parts := TWSJTXReceivedParts.Create;
   try
      parts.Clear;
      CheckTrue(WSJTXParseAddressedMessage('NY4I KA1MXL FN41', ME, 'KA1MXL', parts),
                'grid');
      CheckTrue(WSJTXExchangeForMode(ExchangeFieldsRSTNameQTH, parts, True, text),
                'grid alone');
      CheckEquals('FN41', text, 'the grid alone');
      CheckTrue(WSJTXParseAddressedMessage('NY4I KA1MXL R-08', ME, 'KA1MXL', parts),
                'report');
      CheckTrue(WSJTXExchangeForMode(ExchangeFieldsRSTNameQTH, parts, True, text),
                'both');
      CheckEquals('-08 FN41', text, 'signed report then grid');
      CheckTrue(WSJTXParseAddressedMessage('NY4I KA1MXL +03', ME, 'KA1MXL', parts),
                'positive');
      CheckTrue(WSJTXExchangeForMode(ExchangeFieldsRSTNameQTH, parts, True, text),
                'positive composed');
      CheckEquals('+03 FN41', text, 'plus sign kept');
      (* Not digital: the converted report alone, as before. *)
      CheckTrue(WSJTXExchangeForMode(ExchangeFieldsRSTNameQTH, parts, False, text),
                'not digital');
      CheckEquals('549', text, 'report alone off digital');
      (* Another shape is untouched by the flag. *)
      CheckTrue(WSJTXExchangeForMode(ExchangeFieldsRSTQTH, parts, True, text),
                'RST and QTH');
      CheckEquals('549 FN41', text, 'RST and QTH is as before');
   finally
      parts.Free;
   end;
   CheckEquals('-08', WSJTXFormatDBReport(-8), 'format -8');
   CheckEquals('+00', WSJTXFormatDBReport(0), 'format 0');
   CheckEquals('-18', WSJTXFormatDBReport(-18), 'format -18');
end;

(* THE LOGGED CALL IS NOT PUT BACK (tr4w.log 2026-11-25 07:47: KA1MXL came back
   flagged a dupe every 30 s). *)
procedure TWSJTXExchangeTextTests.Test_TheLoggedCallIsNotPutBack;
begin
   BeginTest('Test_TheLoggedCallIsNotPutBack');
   CheckTrue(WSJTXIsTheLoggedCall('KA1MXL', 'KA1MXL'), 'same call');
   CheckTrue(WSJTXIsTheLoggedCall('KA1MXL/P', 'ka1mxl'), 'base call, case');
   CheckFalse(WSJTXIsTheLoggedCall('F6HUK', 'KA1MXL'), 'another call ends it');
   CheckFalse(WSJTXIsTheLoggedCall('', 'KA1MXL'), 'no DX call ends it');
   CheckFalse(WSJTXIsTheLoggedCall('KA1MXL', ''), 'nothing logged: nothing held');
   (* The restore: empty window, call not escaped, not the logged one. *)
   CheckTrue(WSJTXShouldRestoreCall('F6HUK', '', '', True), 'restore');
   CheckFalse(WSJTXShouldRestoreCall('F6HUK', '', '', False), 'window not empty');
   CheckFalse(WSJTXShouldRestoreCall('', '', '', True), 'no call');
   CheckFalse(WSJTXShouldRestoreCall('F6HUK', 'F6HUK', '', True), 'escaped');
   CheckFalse(WSJTXShouldRestoreCall('KA1MXL', '', 'KA1MXL', True),
              'logged: no timer, held until the DX call changes');
   CheckTrue(WSJTXShouldRestoreCall('F6HUK', '', 'KA1MXL', True),
             'another call than the logged one');
end;

(* THE ESCAPE: a message that opens a new QSO, never an acknowledgement. *)
procedure TWSJTXExchangeTextTests.Test_OnlyAnOpeningMessageEndsTheSuppression;
begin
   BeginTest('Test_OnlyAnOpeningMessageEndsTheSuppression');
   CheckTrue(WSJTXOpensANewQso('NY4I KA1MXL FN41', ME, 'KA1MXL'), 'grid opens');
   CheckTrue(WSJTXOpensANewQso('NY4I KA1MXL -08', ME, 'KA1MXL'), 'plain report opens');
   CheckFalse(WSJTXOpensANewQso('NY4I KA1MXL R-08', ME, 'KA1MXL'),
              'R-report is a repeat of an answer');
   CheckFalse(WSJTXOpensANewQso('NY4I KA1MXL RR73', ME, 'KA1MXL'), 'RR73');
   CheckFalse(WSJTXOpensANewQso('NY4I KA1MXL 73', ME, 'KA1MXL'), '73');
   CheckFalse(WSJTXOpensANewQso('K1ABC KA1MXL FN41', ME, 'KA1MXL'), 'not to us');
   CheckFalse(WSJTXOpensANewQso('NY4I F6HUK FN41', ME, 'KA1MXL'), 'not from the DX');
end;

procedure TWSJTXExchangeTextTests.Test_FieldDayGetsTheClassAndSection;
var
   text: string;
begin
   BeginTest('Test_FieldDayGetsTheClassAndSection');
   CheckTrue(Decode(ExchangeFieldsClassQTH, 'NY4I F6HUK R 3A ENY', text),
             'with the R');
   CheckEquals('3A ENY', text, 'class then section');
   CheckTrue(Decode(ExchangeFieldsClassQTH, 'NY4I F6HUK 12B DX', text),
             'without the R, two-digit class');
   CheckEquals('12B DX', text, 'class then section');
   (* A Field Day exchange has no RST or grid: a report gives nothing. *)
   CheckFalse(Decode(ExchangeFieldsClassQTH, 'NY4I F6HUK -15', text),
              'no listed field is carried');
end;

procedure TWSJTXExchangeTextTests.Test_AClassWithASerialGetsNothing;
var
   text: string;
begin
   BeginTest('Test_AClassWithASerialGetsNothing');
   (* A lone '519' for an RST-and-serial class would be read as the serial. *)
   CheckFalse(Decode(ExchangeFieldsRSTQSONumber, 'NY4I F6HUK -15', text),
              'RST and serial');
   CheckEquals('', text, 'no text');
   CheckFalse(Decode(ExchangeFieldsQSONumberQTH, 'NY4I F6HUK JN06', text),
              'serial and QTH');
end;

procedure TWSJTXExchangeTextTests.Test_AGridOnlyClassGetsTheGrid;
var
   text: string;
begin
   BeginTest('Test_AGridOnlyClassGetsTheGrid');
   CheckTrue(Decode(ExchangeFieldsQTH, 'NY4I F6HUK JN06', text), 'grid');
   CheckEquals('JN06', text, 'the grid');
   CheckFalse(Decode(ExchangeFieldsQTH, 'NY4I F6HUK -15', text),
              'a report only: no listed field');
end;

procedure TWSJTXExchangeTextTests.RunAllTests;
begin
   Test_AReportToUsGivesTheRST;
   Test_ARepeatedReportGivesTheSameText;
   Test_RRR_RR73_And_73_CarryNothing;
   Test_AMessageNotToUsOrNotFromTheDXGivesNothing;
   Test_HashedAndPortableCallsAreComparedByBaseCall;
   Test_GarbageGivesNothing;
   Test_RSTAndQTHTakesTheReportThenTheGrid;
   Test_MessagesAccumulateWithinOneQSO;
   Test_GeneralQSOGetsTheReportAlone;
   Test_GeneralQSODigitalGetsSignedReportAndGrid;
   Test_TheLoggedCallIsNotPutBack;
   Test_OnlyAnOpeningMessageEndsTheSuppression;
   Test_FieldDayGetsTheClassAndSection;
   Test_AClassWithASerialGetsNothing;
   Test_AGridOnlyClassGetsTheGrid;
end;

end.
