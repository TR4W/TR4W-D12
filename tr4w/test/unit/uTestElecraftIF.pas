unit uTestElecraftIF;

{
  Tests for uElecraftIF -- the shared Elecraft IF decode.

  The point of extracting the parser was that it could not be tested while it
  lived twice inside two radio classes, each needing a live serial port and a
  booted TR4W to reach.  As a pure function over a string it needs neither.

  The first test is the one that matters most: a REAL response captured from
  NY4I's K3 on 2026-08-01, taken from tr4w.log rather than composed by hand.
}

interface

uses
   SysUtils, uTR4WTestFramework, uElecraftIF, uFactoryRadioBase;

type
   TElecraftIFTests = class(TTestCase)
   protected
      procedure Test_RealCapturedK3Response;
      procedure Test_SignedOffsetAndFlags;
      procedure Test_VFOAndSplitAndTransmit;
      procedure Test_LengthGuard;
      procedure Test_MalformedNumericFields;
      procedure Test_AcceptsOptionalIFPrefix;
      procedure Test_ModeMapping;
   public
      procedure RunAllTests; override;
   end;

implementation

// Build an IF payload (WITHOUT the leading 'IF', which ProcessMessage strips)
// from its positional fields.  Mirrors the format documented in uElecraftIF.
function MakeIF(const freq: string; sign: Char; const offset: string;
                r, x, t, v, s, p, b, d: Char): string;
begin
   Result := freq + '     ' + sign + offset + r + x + ' ' + '00' + t + '3' + v + s + p + b + d;
end;

procedure TElecraftIFTests.Test_RealCapturedK3Response;
var
   info: TElecraftIF;
   err: TElecraftIFError;
   cmd: string;
begin
   BeginTest('a real K3 IF response captured from tr4w.log decodes correctly');
   // 01 Aug 2026 23:28:10 -- K3 on 40m CW, no RIT/XIT, not split, VFO A.
   // This is sData: ProcessMessage has already removed the leading 'IF'.
   cmd := '00007045600     -000000 0003000001 ';
   CheckEquals(35, Length(cmd), 'captured payload is 35 chars (33 parsed + trailing "1 ")');

   err := ParseElecraftIF(cmd, info);
   CheckTrue(err = ifeNone, 'the real response parses');
   CheckEquals(7045600, info.FrequencyHz, 'frequency');
   CheckEquals(0, info.RITXITOffsetHz, 'offset');
   CheckFalse(info.RITOn, 'RIT off');
   CheckFalse(info.XITOn, 'XIT off');
   CheckFalse(info.Transmitting, 'receiving');
   CheckFalse(info.SplitOn, 'not split');
   CheckFalse(info.RXVFOIsB, 'operating on VFO A');
   CheckEquals('3', info.ModeChar, 'mode char is CW');
end;

procedure TElecraftIFTests.Test_SignedOffsetAndFlags;
var
   info: TElecraftIF;
begin
   BeginTest('the +/- field signs the RIT/XIT offset, and r/x are independent');

   CheckTrue(ParseElecraftIF(MakeIF('00014025000', '-', '0250',
                                    '1', '0', '0', '0', '0', '0', '0', '0'), info) = ifeNone, 'parses');
   CheckEquals(-250, info.RITXITOffsetHz, 'minus sign applied');
   CheckTrue(info.RITOn, 'RIT on');
   CheckFalse(info.XITOn, 'XIT off');

   CheckTrue(ParseElecraftIF(MakeIF('00014025000', '+', '0250',
                                    '0', '1', '0', '0', '0', '0', '0', '0'), info) = ifeNone, 'parses');
   CheckEquals(250, info.RITXITOffsetHz, 'plus sign applied');
   CheckFalse(info.RITOn, 'RIT off');
   CheckTrue(info.XITOn, 'XIT on');

   // The drivers treated anything that is not '-' as positive; keep that.
   CheckTrue(ParseElecraftIF(MakeIF('00014025000', ' ', '0100',
                                    '0', '0', '0', '0', '0', '0', '0', '0'), info) = ifeNone, 'parses');
   CheckEquals(100, info.RITXITOffsetHz, 'a non-minus sign character is treated as positive');
end;

procedure TElecraftIFTests.Test_VFOAndSplitAndTransmit;
var
   info: TElecraftIF;
begin
   BeginTest('the v, p and t fields are read from the right positions');

   CheckTrue(ParseElecraftIF(MakeIF('00007025000', '+', '0000',
                                    '0', '0', '1', '1', '0', '1', '0', '2'), info) = ifeNone, 'parses');
   CheckTrue(info.Transmitting, 'transmitting');
   CheckTrue(info.RXVFOIsB, 'operating on VFO B');
   CheckTrue(info.SplitOn, 'split on');
   CheckEquals('2', info.DataModeChar, 'data sub-mode char');

   // Scan ('s') and the band-change flag ('b') are consumed and discarded --
   // setting them must not disturb the fields on either side.
   CheckTrue(ParseElecraftIF(MakeIF('00007025000', '+', '0000',
                                    '0', '0', '0', '0', '1', '1', '1', '0'), info) = ifeNone, 'parses');
   CheckFalse(info.RXVFOIsB, 'VFO A even with scan set');
   CheckTrue(info.SplitOn, 'split still read correctly past the scan flag');
end;

procedure TElecraftIFTests.Test_LengthGuard;
var
   info: TElecraftIF;
   exact: string;
begin
   BeginTest('the guard tests what the parse CONSUMES, not the wire length');

   exact := MakeIF('00007025000', '+', '0000', '0', '0', '0', '0', '0', '0', '0', '0');
   CheckEquals(IF_PARSED_LENGTH, Length(exact), 'the constructed payload is exactly the parsed length');
   CheckTrue(ParseElecraftIF(exact, info) = ifeNone,
             'a payload with the trailing "1 " absent still parses -- 33 is all we read');

   CheckTrue(ParseElecraftIF(Copy(exact, 1, IF_PARSED_LENGTH - 1), info) = ifeTooShort,
             'one character short is rejected');
   CheckTrue(ParseElecraftIF('', info) = ifeTooShort, 'empty is rejected');
   CheckTrue(ParseElecraftIF('IF', info) = ifeTooShort, 'the command letters alone are rejected');

   // Longer is deliberately tolerated: fields are read from the front, so a
   // firmware that APPENDS must not break a working radio.
   CheckTrue(ParseElecraftIF(exact + 'EXTRA', info) = ifeNone, 'trailing extra data is ignored');
   CheckEquals(7025000, info.FrequencyHz, 'and the fields are still right');
end;

procedure TElecraftIFTests.Test_MalformedNumericFields;
var
   info: TElecraftIF;
begin
   BeginTest('non-numeric frequency and offset are reported, not silently accepted');

   CheckTrue(ParseElecraftIF(MakeIF('ABCDEFGHIJK', '+', '0000',
                                    '0', '0', '0', '0', '0', '0', '0', '0'), info) = ifeBadFrequency,
             'garbage frequency');
   CheckTrue(ParseElecraftIF(MakeIF('00007025000', '+', 'WXYZ',
                                    '0', '0', '0', '0', '0', '0', '0', '0'), info) = ifeBadRITOffset,
             'garbage RIT offset');

   CheckTrue(ElecraftIFErrorText(ifeTooShort, 'x') <> '', 'a too-short error has text to log');
   CheckEquals('', ElecraftIFErrorText(ifeNone, 'x'), 'success has no error text');
end;

procedure TElecraftIFTests.Test_AcceptsOptionalIFPrefix;
var
   withPrefix: TElecraftIF;
   without: TElecraftIF;
   payload: string;
begin
   BeginTest('the leading "IF" is optional -- both drivers strip it, but the parser tolerates it');
   payload := MakeIF('00021030000', '-', '1234', '1', '1', '0', '1', '0', '1', '0', '3');

   CheckTrue(ParseElecraftIF(payload, without) = ifeNone, 'without prefix');
   CheckTrue(ParseElecraftIF('IF' + payload, withPrefix) = ifeNone, 'with prefix');

   CheckEquals(without.FrequencyHz, withPrefix.FrequencyHz, 'same frequency either way');
   CheckEquals(without.RITXITOffsetHz, withPrefix.RITXITOffsetHz, 'same offset either way');
   CheckEquals(-1234, without.RITXITOffsetHz, 'and the offset is the signed value');
end;

procedure TElecraftIFTests.Test_ModeMapping;
var
   problem: string;
begin
   BeginTest('MD byte and DT sub-mode map to TRadioMode, with the old lenient fallbacks');

   CheckTrue(ElecraftModeToRadioMode('3', '0', problem) = rmCW, 'MD3 is CW');
   CheckEquals('', problem, 'no problem reported for a good mode');
   CheckTrue(ElecraftModeToRadioMode('1', '0', problem) = rmLSB, 'MD1 is LSB');
   CheckTrue(ElecraftModeToRadioMode('2', '0', problem) = rmUSB, 'MD2 is USB');
   CheckTrue(ElecraftModeToRadioMode('7', '0', problem) = rmCWRev, 'MD7 is CW reverse');
   CheckTrue(ElecraftModeToRadioMode('9', '0', problem) = rmDataRev, 'MD9 is DATA reverse');

   // Mode 6 is DATA; the sub-mode byte decides which.
   CheckTrue(ElecraftModeToRadioMode('6', '0', problem) = rmData, 'DATA A');
   CheckTrue(ElecraftModeToRadioMode('6', '1', problem) = rmAFSK, 'AFSK A');
   CheckTrue(ElecraftModeToRadioMode('6', '2', problem) = rmFSK, 'FSK D');
   CheckTrue(ElecraftModeToRadioMode('6', '3', problem) = rmPSK, 'PSK D');
   CheckEquals('', problem, 'no problem reported for a good sub-mode');

   // Fallbacks: these are the behaviours both drivers already had, preserved
   // deliberately -- a garbled byte must not throw during polling.
   CheckTrue(ElecraftModeToRadioMode('6', 'Z', problem) = rmData, 'bad sub-mode falls back to DATA');
   CheckTrue(problem <> '', 'and reports a problem for the caller to log');

   CheckTrue(ElecraftModeToRadioMode('Z', '0', problem) = rmNone, 'non-numeric mode falls back to none');
   CheckTrue(problem <> '', 'and reports a problem');

   CheckTrue(ElecraftModeToRadioMode('8', '0', problem) = rmNone, 'undefined mode falls back to none');
   CheckTrue(problem <> '', 'and reports a problem');
end;

procedure TElecraftIFTests.RunAllTests;
begin
   Test_RealCapturedK3Response;
   Test_SignedOffsetAndFlags;
   Test_VFOAndSplitAndTransmit;
   Test_LengthGuard;
   Test_MalformedNumericFields;
   Test_AcceptsOptionalIFPrefix;
   Test_ModeMapping;
end;

end.
