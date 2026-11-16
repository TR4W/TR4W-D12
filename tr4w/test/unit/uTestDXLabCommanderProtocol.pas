unit uTestDXLabCommanderProtocol;
{$I ..\..\src\tr4w.inc}

(*
  THE COMMANDER WIRE FORMAT, AGAINST DXLAB'S OWN DOCUMENT.

  The golden strings below are copied from "Commander TCP/IP Messages"
  (2019-07-11, attached to issue 172).  They are the independent half of this
  test: the encoder computes every length, and the document wrote them by hand.

  ONE EXAMPLE IN THE DOCUMENT IS MISCOUNTED and is deliberately NOT a golden
  string: its CmdSetFreqMode says <parameters:56> for 58 characters of
  parameters.  Test_DocumentMiscountIsNotCopied pins the true 58 so nobody
  "fixes" the encoder to match the misprint.

  Pure: no socket, no radio object.  The driver's transport is tested against a
  fake peer in uTestRadioDXLabCommander.
*)

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uDXLabCommanderProtocol;

type
   TDXLabCommanderProtocolTests = class(TTestCase)
   protected
      procedure Test_EncoderMatchesTheDocumentExamples;
      procedure Test_DocumentMiscountIsNotCopied;
      procedure Test_HeaderParse;
      procedure Test_HeaderParseRejectsWhatIsNotAHeader;
      procedure Test_FieldParse;
      procedure Test_IsOneCommanderMessage;
      procedure Test_KHzToHz;
      procedure Test_KHzToHzRefusesUnknownAndMalformed;
      procedure Test_HzToKHzBothSeparators;
      procedure Test_EveryDocumentModeIsRead;
      procedure Test_ModeWriteMapping;
   public
      procedure RunAllTests; override;
   end;

implementation

procedure TDXLabCommanderProtocolTests.Test_EncoderMatchesTheDocumentExamples;
begin
   BeginTest('Test_EncoderMatchesTheDocumentExamples');

   CheckEquals('<command:10>CmdSetFreq<parameters:17><xcvrfreq:5>21230',
               CommanderMessage('CmdSetFreq', CommanderField('xcvrfreq', '21230')),
               'item 3, set RX frequency');
   CheckEquals('<command:12>CmdSetTXFreq<parameters:17><xcvrfreq:5>21231',
               CommanderMessage('CmdSetTXFreq', CommanderField('xcvrfreq', '21231')),
               'item 4, set TX frequency');
   CheckEquals('<command:10>CmdSetMode<parameters:7><1:2>CW',
               CommanderMessage('CmdSetMode', CommanderField('1', 'CW')),
               'item 5, set mode');
   CheckEquals('<command:8>CmdSplit<parameters:7><1:2>on',
               CommanderMessage('CmdSplit', CommanderField('1', 'on')),
               'item 6, split on');
   CheckEquals('<command:8>CmdSplit<parameters:8><1:3>off',
               CommanderMessage('CmdSplit', CommanderField('1', 'off')),
               'item 6, split off -- one character longer');
   CheckEquals('<command:5>CmdTX<parameters:0>', CommanderMessage('CmdTX', ''), 'item 7, transmit');
   CheckEquals('<command:5>CmdRX<parameters:0>', CommanderMessage('CmdRX', ''), 'item 9, receive');
   CheckEquals('<command:10>CmdGetFreq<parameters:0>', CommanderMessage('CmdGetFreq', ''), 'item 10');
   CheckEquals('<command:12>CmdGetTXFreq<parameters:0>', CommanderMessage('CmdGetTXFreq', ''), 'item 11');
   CheckEquals('<command:11>CmdSendMode<parameters:0>', CommanderMessage('CmdSendMode', ''), 'item 14');
   CheckEquals('<command:12>CmdSendSplit<parameters:0>', CommanderMessage('CmdSendSplit', ''), 'item 15');
   CheckEquals('<command:9>CmdSendTX<parameters:0>', CommanderMessage('CmdSendTX', ''), 'item 16');
   CheckEquals('<command:11>CmdQSXSplit<parameters:57><xcvrfreq:5>14085<SuppressDual:1>N<SuppressModeChange:1>N',
               CommanderMessage('CmdQSXSplit',
                                CommanderField('xcvrfreq', '14085') +
                                CommanderField('SuppressDual', 'N') +
                                CommanderField('SuppressModeChange', 'N')),
               'item 2, QSX split');
end;

procedure TDXLabCommanderProtocolTests.Test_DocumentMiscountIsNotCopied;
var
   params: string;
begin
   BeginTest('Test_DocumentMiscountIsNotCopied');
   params := CommanderField('xcvrfreq', '14080') +
             CommanderField('xcvrmode', 'RTTY') +
             CommanderField('preservesplitanddual', 'N');
   (* 17 + 16 + 25.  The document's example says 56. *)
   CheckEquals(58, Length(params), 'the three fields are 58 characters');
   CheckEquals('<command:14>CmdSetFreqMode<parameters:58>' + params,
               CommanderMessage('CmdSetFreqMode', params),
               'the encoder counts; it does not copy the misprint');
end;

procedure TDXLabCommanderProtocolTests.Test_HeaderParse;
var
   name: string;
   len: integer;
begin
   BeginTest('Test_HeaderParse');

   CheckTrue(TryParseCommanderFieldHeader('<CmdFreq:10', name, len), 'with its bracket');
   CheckEquals('CmdFreq', name, 'name');
   CheckEquals(10, len, 'length');

   CheckTrue(TryParseCommanderFieldHeader('CmdMode:0', name, len), 'without its bracket, length 0');
   CheckEquals('CmdMode', name, '');
   CheckEquals(0, len, 'an empty value is a field');

   CheckTrue(TryParseCommanderFieldHeader('<CmdFreq:10:N', name, len), 'an ADIF type indicator');
   CheckEquals(10, len, 'the type does not change the length');

   CheckTrue(TryParseCommanderFieldHeader(#13#10'<CmdSplit:3', name, len), 'CR/LF ahead of the field');
   CheckEquals('CmdSplit', name, 'skipped');

   CheckTrue(TryParseCommanderFieldHeader('junk<x<CmdTX:2', name, len), 'from the LAST bracket');
   CheckEquals('CmdTX', name, '');
   CheckEquals(2, len, '');
end;

procedure TDXLabCommanderProtocolTests.Test_HeaderParseRejectsWhatIsNotAHeader;
var
   name: string;
   len: integer;
begin
   BeginTest('Test_HeaderParseRejectsWhatIsNotAHeader');
   CheckFalse(TryParseCommanderFieldHeader('<CmdFreq', name, len), 'no length');
   CheckFalse(TryParseCommanderFieldHeader('<:10', name, len), 'no name');
   CheckFalse(TryParseCommanderFieldHeader('<CmdFreq:', name, len), 'empty length');
   CheckFalse(TryParseCommanderFieldHeader('<CmdFreq:1x', name, len), 'not digits');
   CheckFalse(TryParseCommanderFieldHeader('<CmdFreq:-1', name, len), 'negative');
   CheckFalse(TryParseCommanderFieldHeader('<CmdFreq:99999999999', name, len), 'too long to hold');
   CheckFalse(TryParseCommanderFieldHeader('', name, len), 'nothing');
end;

procedure TDXLabCommanderProtocolTests.Test_FieldParse;
var
   name: string;
   value: string;
begin
   BeginTest('Test_FieldParse');

   CheckTrue(TryParseCommanderField('<CmdFreq:10>14,010.500', name, value), 'item 10 reply');
   CheckEquals('CmdFreq', name, '');
   CheckEquals('14,010.500', value, '');

   CheckTrue(TryParseCommanderField('<CmdMode:0>', name, value), 'item 14, rig not reported');
   CheckEquals('', value, 'empty value');

   CheckTrue(TryParseCommanderField('<CmdSplit:3>OFF'#13#10, name, value), 'trailing CR/LF ignored');
   CheckEquals('OFF', value, 'exactly the declared length');

   CheckFalse(TryParseCommanderField('<CmdFreq:10>14,010', name, value), 'value shorter than declared');
   CheckFalse(TryParseCommanderField('CmdFreq 14010', name, value), 'not a field');
end;

procedure TDXLabCommanderProtocolTests.Test_IsOneCommanderMessage;
begin
   BeginTest('Test_IsOneCommanderMessage');
   CheckTrue(IsOneCommanderMessage('<command:10>CmdSetFreq<parameters:17><xcvrfreq:5>21230'),
             'the document''s example');
   CheckTrue(IsOneCommanderMessage('<command:5>CmdTX<parameters:0>'), 'no parameters');
   CheckFalse(IsOneCommanderMessage('KY <;'), 'a K3 command');
   CheckFalse(IsOneCommanderMessage(''), 'nothing');
   CheckFalse(IsOneCommanderMessage('<command:5>CmdTX'), 'no parameters field');
   CheckFalse(IsOneCommanderMessage('<command:6>CmdTX<parameters:0>'), 'a wrong length');
   CheckFalse(IsOneCommanderMessage('<command:0><parameters:0>'), 'no command');
   CheckFalse(IsOneCommanderMessage('<parameters:0><command:5>CmdTX'), 'fields the wrong way round');
   CheckFalse(IsOneCommanderMessage('<command:5>CmdTX<parameters:0><command:5>CmdRX<parameters:0>'),
              'two messages: a per-connection peer would drop the second');
   CheckFalse(IsOneCommanderMessage('<command:5>CmdTX<parameters:0>'#13#10), 'trailing bytes');
end;

procedure TDXLabCommanderProtocolTests.Test_KHzToHz;
var
   hz: LongInt;
begin
   BeginTest('Test_KHzToHz');
   CheckTrue(TryCommanderKHzToHz('14,010.500', hz), 'the document example');
   CheckEquals(14010500, hz, '');
   CheckTrue(TryCommanderKHzToHz('475.500', hz), '630 m, no thousands separator');
   CheckEquals(475500, hz, '');
   CheckTrue(TryCommanderKHzToHz('432,100.000', hz), '70 cm');
   CheckEquals(432100000, hz, '');
   CheckTrue(TryCommanderKHzToHz('1,296,100.000', hz), '23 cm, two separators');
   CheckEquals(1296100000, hz, '');
   CheckTrue(TryCommanderKHzToHz('7,025.5', hz), 'one decimal place');
   CheckEquals(7025500, hz, 'padded to Hz');
   CheckTrue(TryCommanderKHzToHz('3500', hz), 'no decimal point');
   CheckEquals(3500000, hz, '');
end;

procedure TDXLabCommanderProtocolTests.Test_KHzToHzRefusesUnknownAndMalformed;
var
   hz: LongInt;
begin
   BeginTest('Test_KHzToHzRefusesUnknownAndMalformed');
   CheckFalse(TryCommanderKHzToHz('.000', hz), 'the document''s "has not reported"');
   CheckFalse(TryCommanderKHzToHz('', hz), 'empty');
   CheckFalse(TryCommanderKHzToHz('0', hz), 'zero');
   CheckFalse(TryCommanderKHzToHz('14,010.5000', hz), 'below one Hz');
   CheckFalse(TryCommanderKHzToHz('14.010,500', hz), 'locale separators are not this reply');
   CheckFalse(TryCommanderKHzToHz('abc', hz), 'not a number');
   CheckFalse(TryCommanderKHzToHz('10,000,000.000', hz), '10 GHz does not fit a LongInt of Hz');
end;

procedure TDXLabCommanderProtocolTests.Test_HzToKHzBothSeparators;
begin
   BeginTest('Test_HzToKHzBothSeparators');
   CheckEquals('21230', CommanderHzToKHz(21230000, '.'), 'whole kHz carries no separator');
   CheckEquals('21230', CommanderHzToKHz(21230000, ','), '... in either locale');
   CheckEquals('14010.500', CommanderHzToKHz(14010500, '.'), 'period locale');
   CheckEquals('14010,500', CommanderHzToKHz(14010500, ','), 'comma locale');
   CheckEquals('7025.050', CommanderHzToKHz(7025050, '.'), 'leading zero kept');
   CheckEquals('1296100', CommanderHzToKHz(1296100000, '.'), 'no thousands separator');
end;

procedure TDXLabCommanderProtocolTests.Test_EveryDocumentModeIsRead;
const
   (* The document's list, in its order. *)
   NAMES: array[0..10] of string = ('AM', 'CW', 'CW-R', 'DATA-L', 'DATA-U', 'FM',
                                    'LSB', 'USB', 'RTTY', 'RTTY-R', 'WBFM');
   MODES: array[0..10] of TRadioMode = (rmAM, rmCW, rmCWRev, rmDataRev, rmData, rmFM,
                                        rmLSB, rmUSB, rmFSK, rmFSKRev, rmFM);
var
   i: integer;
   m: TRadioMode;
begin
   BeginTest('Test_EveryDocumentModeIsRead');
   for i := Low(NAMES) to High(NAMES) do
      begin
      CheckTrue(TryCommanderModeToRadioMode(NAMES[i], m), NAMES[i] + ' is read');
      CheckEquals(Ord(MODES[i]), Ord(m), NAMES[i] + ' maps as expected');
      end;
   CheckTrue(TryCommanderModeToRadioMode('cw-r', m), 'case does not matter');
   CheckEquals(Ord(rmCWRev), Ord(m), '');
   CheckFalse(TryCommanderModeToRadioMode('', m), 'the rig has not reported');
   CheckFalse(TryCommanderModeToRadioMode('PSK31', m), 'not in the document');
end;

procedure TDXLabCommanderProtocolTests.Test_ModeWriteMapping;
var
   m: TRadioMode;
   back: TRadioMode;
begin
   BeginTest('Test_ModeWriteMapping');
   CheckEquals('', RadioModeToCommanderMode(rmNone), 'nothing for no mode');
   CheckEquals('', RadioModeToCommanderMode(rmDV), 'nothing for DV');
   CheckEquals('DATA-U', RadioModeToCommanderMode(rmPSK), 'PSK on the upper sideband');
   CheckEquals('DATA-L', RadioModeToCommanderMode(rmAFSKRev), 'reverse AFSK on the lower');

   (* Every mode that has a name reads back as a mode that writes the SAME
     name -- the two directions cannot drift apart. *)
   for m := Low(TRadioMode) to High(TRadioMode) do
      begin
      if RadioModeToCommanderMode(m) = '' then
         begin
         Continue;
         end;
      CheckTrue(TryCommanderModeToRadioMode(RadioModeToCommanderMode(m), back),
                'the name written for mode ' + IntToStr(Ord(m)) + ' is one the reader knows');
      CheckEquals(RadioModeToCommanderMode(m), RadioModeToCommanderMode(back),
                  'round trip for mode ' + IntToStr(Ord(m)));
      end;
end;

procedure TDXLabCommanderProtocolTests.RunAllTests;
begin
   Test_EncoderMatchesTheDocumentExamples;
   Test_DocumentMiscountIsNotCopied;
   Test_HeaderParse;
   Test_HeaderParseRejectsWhatIsNotAHeader;
   Test_FieldParse;
   Test_IsOneCommanderMessage;
   Test_KHzToHz;
   Test_KHzToHzRefusesUnknownAndMalformed;
   Test_HzToKHzBothSeparators;
   Test_EveryDocumentModeIsRead;
   Test_ModeWriteMapping;
end;

end.
