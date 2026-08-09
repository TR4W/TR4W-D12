unit uTestTCIProtocol;

{
  Pins uTCIProtocol -- the TCI grammar.

  THE CENTRAL ASSERTION IN THIS SUITE is that arity is decided PER COMMAND.
  The reference server (AetherSDR, TciProtocol.cpp:455) uses one global rule,
  `isSet = args.size() >= 2`, and it is wrong for every command whose SET
  carries a single argument: `cw_macros_speed:20;` is answered as a GET with
  the current speed, so the command cannot be used at all.  The reference has
  three commands special-cased at the dispatch site because of it.  We use a
  table instead, and Test_Classify_OneArgumentSet_IsASet is the test that
  would fail if anyone reintroduced the global rule.

  The other tests here are the wire-compatibility rules that real clients
  depend on -- each one traceable to a client that broke without it.
}

interface

uses
   SysUtils, Classes, uTR4WTestFramework, uTCIProtocol;

type
   TTCIProtocolTests = class(TTestCase)
   protected
      procedure CheckKind(const Cmd: string; Expected: TTCIRequestKind; const Why: string);

      // Framing
      procedure Test_Framer_SingleCommand;
      procedure Test_Framer_SeveralInOneFrame;
      procedure Test_Framer_CommandSplitAcrossFrames;
      procedure Test_Framer_TrimsWhitespace;
      procedure Test_Framer_NoTerminatorYieldsNothing;
      procedure Test_Framer_OverflowIsReported;
      procedure Test_Framer_ResetClearsState;

      // Parsing
      procedure Test_Parse_NameIsLowercased;
      procedure Test_Parse_NoArguments;
      procedure Test_Parse_ArgumentsAreTrimmed;
      procedure Test_Parse_ArgumentsKeepTheirCase;
      procedure Test_Parse_EmptyArgumentListIsZeroArgs;
      procedure Test_Parse_MissingArgumentReadsEmpty;
      procedure Test_Parse_ArgIntDefault;
      procedure Test_Parse_ArgBoolIsStrict;

      // Classification -- the arity table
      procedure Test_Classify_OneArgumentSet_IsASet;
      procedure Test_Classify_GlobalGetWithNoArgs;
      procedure Test_Classify_Vfo;
      procedure Test_Classify_Trx;
      procedure Test_Classify_Drive_BothGetForms;
      procedure Test_Classify_RxFilterBand_NeedsThree;
      procedure Test_Classify_TxEnable_IsNotificationOnly;
      procedure Test_Classify_Unknown;
      procedure Test_Classify_Malformed;
      procedure Test_Classify_StartStopTakeNoArguments;
      procedure Test_Classify_IsCaseInsensitive;

      // Formatting and sanitizing
      procedure Test_Msg_Shapes;
      procedure Test_Msg_NameIsLowercased;
      procedure Test_Msg_SanitizesSeparators;
      procedure Test_Msg_SanitizesNewlines;
      procedure Test_FreeText_KeepsCommasButNotSemicolons;
      procedure Test_CommaBearingIdentityValuesNeedFreeText;
      procedure Test_Bool_IsLowercaseLiteral;

      // Identity constants that clients parse
      procedure Test_Identity_ProtocolAnnouncesExpertSDR3;
      procedure Test_Identity_DeviceIsNotASunSDR;
      procedure Test_Identity_ModulationsAreLowercaseAndSettable;
      procedure Test_Identity_LimitsAreSelfConsistent;

   public
      procedure RunAllTests; override;
   end;

implementation

procedure TTCIProtocolTests.CheckKind(const Cmd: string; Expected: TTCIRequestKind;
                                      const Why: string);
const
   NAMES: array[TTCIRequestKind] of string =
      ('Unknown', 'Get', 'Set', 'Malformed', 'Ignored');
var
   got: TTCIRequestKind;
begin
   got := TCIClassify(TCIParse(Cmd));
   if got = Expected then
      begin
      Check(True, Cmd);
      end
   else
      begin
      Check(False, Format('"%s" classified %s, expected %s -- %s',
                          [Cmd, NAMES[got], NAMES[Expected], Why]));
      end;
end;

{ ------------------------------------------------------------------ framing -- }

procedure TTCIProtocolTests.Test_Framer_SingleCommand;
var
   f: TTCIFramer;
   c: string;
begin
   BeginTest('Test_Framer_SingleCommand');
   f := TTCIFramer.Create;
   try
      f.Append('vfo:0,0,14025000;');
      CheckTrue(f.NextCommand(c), 'one complete command');
      CheckEquals('vfo:0,0,14025000', c, 'the terminator is stripped');
      CheckFalse(f.NextCommand(c), 'and nothing is left');
   finally
      f.Free;
   end;
end;

procedure TTCIProtocolTests.Test_Framer_SeveralInOneFrame;
var
   f: TTCIFramer;
   c: string;
begin
   BeginTest('Test_Framer_SeveralInOneFrame');
   // The init burst is sent one command per frame, but nothing REQUIRES a
   // client to do that, and real ones batch.
   f := TTCIFramer.Create;
   try
      f.Append('start;stop;trx:0;');
      CheckTrue(f.NextCommand(c), ''); CheckEquals('start', c, '');
      CheckTrue(f.NextCommand(c), ''); CheckEquals('stop', c, '');
      CheckTrue(f.NextCommand(c), ''); CheckEquals('trx:0', c, '');
      CheckFalse(f.NextCommand(c), '');
   finally
      f.Free;
   end;
end;

procedure TTCIProtocolTests.Test_Framer_CommandSplitAcrossFrames;
var
   f: TTCIFramer;
   c: string;
begin
   BeginTest('Test_Framer_CommandSplitAcrossFrames');
   // TCP does not respect our command boundaries.  Half a command must be
   // held, not dispatched.
   f := TTCIFramer.Create;
   try
      f.Append('vfo:0,');
      CheckFalse(f.NextCommand(c), 'half a command is not a command');
      f.Append('0,14025000;');
      CheckTrue(f.NextCommand(c), 'completed by the next frame');
      CheckEquals('vfo:0,0,14025000', c, 'and rejoined correctly');
   finally
      f.Free;
   end;
end;

procedure TTCIProtocolTests.Test_Framer_TrimsWhitespace;
var
   f: TTCIFramer;
   c: string;
begin
   BeginTest('Test_Framer_TrimsWhitespace');
   f := TTCIFramer.Create;
   try
      f.Append('  trx:0  ; '#13#10'stop;');
      CheckTrue(f.NextCommand(c), ''); CheckEquals('trx:0', c, 'leading/trailing space gone');
      CheckTrue(f.NextCommand(c), ''); CheckEquals('stop', c, 'and a CRLF between commands too');
   finally
      f.Free;
   end;
end;

procedure TTCIProtocolTests.Test_Framer_NoTerminatorYieldsNothing;
var
   f: TTCIFramer;
   c: string;
begin
   BeginTest('Test_Framer_NoTerminatorYieldsNothing');
   f := TTCIFramer.Create;
   try
      f.Append('this is not a command');
      CheckFalse(f.NextCommand(c), 'no ; means nothing to dispatch');
      CheckFalse(f.Overflowed, 'and it is not an overflow either');
   finally
      f.Free;
   end;
end;

procedure TTCIProtocolTests.Test_Framer_OverflowIsReported;
var
   f: TTCIFramer;
   i: integer;
begin
   BeginTest('Test_Framer_OverflowIsReported');
   // A peer that opens a socket and never sends ';' must not be able to make
   // us grow without bound.
   f := TTCIFramer.Create(64);
   try
      for i := 1 to 10 do
         begin
         f.Append('0123456789');
         end;
      CheckTrue(f.Overflowed, 'the caller is told, so it can close the session');
   finally
      f.Free;
   end;
end;

procedure TTCIProtocolTests.Test_Framer_ResetClearsState;
var
   f: TTCIFramer;
   c: string;
begin
   BeginTest('Test_Framer_ResetClearsState');
   f := TTCIFramer.Create(32);
   try
      f.Append('leftover fragment with no terminator at all here');
      CheckTrue(f.Overflowed, '');
      f.Reset;
      CheckFalse(f.Overflowed, 'reset clears the overflow flag');
      f.Append('stop;');
      CheckTrue(f.NextCommand(c), '');
      CheckEquals('stop', c, 'and no stale fragment is prepended');
   finally
      f.Free;
   end;
end;

{ ------------------------------------------------------------------ parsing -- }

procedure TTCIProtocolTests.Test_Parse_NameIsLowercased;
var
   c: TTCICommand;
begin
   BeginTest('Test_Parse_NameIsLowercased');
   // Clients are not consistent about case in the command name.
   c := TCIParse('VFO:0,0,14025000');
   CheckEquals('vfo', c.Name, '');
   c := TCIParse('Split_Enable:0,true');
   CheckEquals('split_enable', c.Name, '');
end;

procedure TTCIProtocolTests.Test_Parse_NoArguments;
var
   c: TTCICommand;
begin
   BeginTest('Test_Parse_NoArguments');
   c := TCIParse('start');
   CheckEquals('start', c.Name, '');
   CheckEquals(0, c.ArgCount, 'no colon means no arguments');
end;

procedure TTCIProtocolTests.Test_Parse_ArgumentsAreTrimmed;
var
   c: TTCICommand;
begin
   BeginTest('Test_Parse_ArgumentsAreTrimmed');
   c := TCIParse('vfo: 0 , 0 , 14025000 ');
   CheckEquals(3, c.ArgCount, '');
   CheckEquals('0', c.Arg(0), '');
   CheckEquals('14025000', c.Arg(2), 'a padded argument still parses as a number');
   CheckEquals(14025000, c.ArgInt(2, -1), '');
end;

procedure TTCIProtocolTests.Test_Parse_ArgumentsKeepTheirCase;
var
   c: TTCICommand;
begin
   BeginTest('Test_Parse_ArgumentsKeepTheirCase');
   // cw_msg text and spot callsigns are case-carrying payloads.  Only the
   // handlers that need a folded value ask for one.
   c := TCIParse('cw_msg:CQ TEST NY4I');
   CheckEquals('CQ TEST NY4I', c.Arg(0), 'the message is not mangled to lowercase');
end;

procedure TTCIProtocolTests.Test_Parse_EmptyArgumentListIsZeroArgs;
var
   c: TTCICommand;
begin
   BeginTest('Test_Parse_EmptyArgumentListIsZeroArgs');
   // 'trx:;' is a GET with a stray colon, not a SET with one empty argument.
   // Reading it the other way turns a harmless read into a malformed write.
   c := TCIParse('trx:');
   CheckEquals('trx', c.Name, '');
   CheckEquals(0, c.ArgCount, '');
   CheckKind('trx:', tcrMalformed, 'trx GET needs its receiver index');
end;

procedure TTCIProtocolTests.Test_Parse_MissingArgumentReadsEmpty;
var
   c: TTCICommand;
begin
   BeginTest('Test_Parse_MissingArgumentReadsEmpty');
   // Every handler would otherwise need the same range guard, and the one
   // that forgot it would fault on a truncated command from the wire.
   c := TCIParse('trx:0');
   CheckEquals('', c.Arg(5), 'an absent argument reads empty, it does not raise');
   CheckEquals('', c.Arg(-1), 'and neither does a negative index');
end;

procedure TTCIProtocolTests.Test_Parse_ArgIntDefault;
var
   c: TTCICommand;
begin
   BeginTest('Test_Parse_ArgIntDefault');
   c := TCIParse('vfo:0,0,notanumber');
   CheckEquals(-1, c.ArgInt(2, -1), 'garbage yields the sentinel, not 0');
   CheckEquals(-1, c.ArgInt(9, -1), 'and so does an absent argument');
end;

procedure TTCIProtocolTests.Test_Parse_ArgBoolIsStrict;
var
   c: TTCICommand;
   b: boolean;
begin
   BeginTest('Test_Parse_ArgBoolIsStrict');
   c := TCIParse('split_enable:0,TRUE');
   CheckTrue(c.ArgBool(1, b), 'case-insensitive true');
   CheckTrue(b, '');

   c := TCIParse('split_enable:0,false');
   CheckTrue(c.ArgBool(1, b), '');
   CheckFalse(b, '');

   // The reference reads "anything that is not 'true'" as false, so a typo
   // becomes a working OFF command.  Refusing it means the caller answers
   // with silence instead of quietly turning something off.
   c := TCIParse('split_enable:0,yes');
   CheckFalse(c.ArgBool(1, b), '"yes" is not a boolean and must not read as false');
   c := TCIParse('split_enable:0');
   CheckFalse(c.ArgBool(1, b), 'a missing argument is not a boolean either');
end;

{ ----------------------------------------------------------- classification -- }

procedure TTCIProtocolTests.Test_Classify_OneArgumentSet_IsASet;
begin
   BeginTest('Test_Classify_OneArgumentSet_IsASet');
   // THE REGRESSION GUARD.  With the reference server's global
   // `isSet = argc >= 2`, this line classifies as a GET and the keyer speed
   // can never be set at all.
   CheckKind('cw_macros_speed:20', tcrSet,
             'a one-argument SET must not be read as a GET');
   CheckKind('cw_macros_speed', tcrGet, 'and the bare form is still the GET');
   CheckKind('cw_msg:CQ TEST', tcrSet, 'cw_msg is settable with one argument');
end;

procedure TTCIProtocolTests.Test_Classify_GlobalGetWithNoArgs;
begin
   BeginTest('Test_Classify_GlobalGetWithNoArgs');
   CheckKind('drive', tcrGet, 'the bare global read');
   CheckKind('rx_sensors_enable', tcrGet, '');
   CheckKind('rx_sensors_enable:true', tcrSet, '');
end;

procedure TTCIProtocolTests.Test_Classify_Vfo;
begin
   BeginTest('Test_Classify_Vfo');
   CheckKind('vfo:0,0', tcrGet, 'trx + channel is a read');
   CheckKind('vfo:0,0,14025000', tcrSet, 'trx + channel + hz is a write');
   CheckKind('vfo:0', tcrMalformed, 'a channel is required, even to read');
end;

procedure TTCIProtocolTests.Test_Classify_Trx;
begin
   BeginTest('Test_Classify_Trx');
   CheckKind('trx:0', tcrGet, '');
   CheckKind('trx:0,true', tcrSet, 'this is PTT -- the most consequential SET there is');
   // WSJT-X sends a third 'source' argument (dax/tci) on some builds; it
   // must still be a SET, not fall through to malformed and be ignored.
   CheckKind('trx:0,true,tci', tcrSet, 'a trailing source argument is still a SET');
end;

procedure TTCIProtocolTests.Test_Classify_Drive_BothGetForms;
begin
   BeginTest('Test_Classify_Drive_BothGetForms');
   // Both forms are in the wild: a bare global read and a per-receiver read.
   CheckKind('drive', tcrGet, 'global form');
   CheckKind('drive:0', tcrGet, 'per-receiver form');
   CheckKind('drive:0,50', tcrSet, '');
   CheckKind('tune_drive:0,20', tcrSet, '');
end;

procedure TTCIProtocolTests.Test_Classify_RxFilterBand_NeedsThree;
begin
   BeginTest('Test_Classify_RxFilterBand_NeedsThree');
   CheckKind('rx_filter_band:0', tcrGet, '');
   CheckKind('rx_filter_band:0,-2700,-300', tcrSet, 'low and high edge');
   // Two arguments satisfies a global "2 or more means SET" rule and then
   // fails the handler's own check, which in the reference produces total
   // silence.  Naming it malformed is at least diagnosable.
   CheckKind('rx_filter_band:0,-2700', tcrMalformed,
             'a filter needs both edges; two arguments is neither form');
end;

procedure TTCIProtocolTests.Test_Classify_TxEnable_IsNotificationOnly;
begin
   BeginTest('Test_Classify_TxEnable_IsNotificationOnly');
   // TCI 2.0 and Thetis both define these as server-to-client state.  An
   // inbound one must mutate nothing and answer nothing -- but it is
   // RECOGNISED, so "we ignore this on purpose" is distinguishable from
   // "we have never heard of it".
   CheckKind('tx_enable:0,true', tcrIgnored, '');
   CheckKind('rx_enable:0,true', tcrIgnored, '');
   CheckKind('rx_smeter:0,-73', tcrIgnored, 'telemetry we emit, never accept');
end;

procedure TTCIProtocolTests.Test_Classify_Unknown;
begin
   BeginTest('Test_Classify_Unknown');
   // Unknown is answered with silence, per the protocol.  Note the SDR-only
   // surface we deliberately do not implement lands here.
   CheckKind('rx_nb_enable:0,true', tcrUnknown, 'a noise blanker on a bridge to a rig');
   CheckKind('completely_made_up:1,2,3', tcrUnknown, '');
   CheckKind('', tcrUnknown, 'the empty command');
end;

procedure TTCIProtocolTests.Test_Classify_Malformed;
begin
   BeginTest('Test_Classify_Malformed');
   CheckKind('modulation', tcrMalformed, 'modulation always needs a receiver');
   CheckKind('split_enable', tcrMalformed, '');
end;

procedure TTCIProtocolTests.Test_Classify_StartStopTakeNoArguments;
begin
   BeginTest('Test_Classify_StartStopTakeNoArguments');
   CheckKind('start', tcrGet, '');
   CheckKind('stop', tcrGet, '');
   CheckKind('start:1', tcrMalformed, 'start takes nothing');
end;

procedure TTCIProtocolTests.Test_Classify_IsCaseInsensitive;
begin
   BeginTest('Test_Classify_IsCaseInsensitive');
   CheckKind('VFO:0,0,14025000', tcrSet, 'an uppercase command name still dispatches');
   CheckKind('Trx:0,TRUE', tcrSet, '');
end;

{ ------------------------------------------------------ formatting / safety -- }

procedure TTCIProtocolTests.Test_Msg_Shapes;
begin
   BeginTest('Test_Msg_Shapes');
   CheckEquals('ready;', TCIMsg('ready'), '');
   CheckEquals('trx_count:2;', TCIMsg('trx_count', TCIInt(2)), '');
   CheckEquals('trx:0,false;', TCIMsg('trx', TCIInt(0), TCIBool(False)), '');
   CheckEquals('vfo:0,1,14025000;',
               TCIMsg('vfo', TCIInt(0), TCIInt(1), TCIInt(14025000)), '');
   CheckEquals('rx_filter_band:0,-2700,-300;',
               TCIMsg('rx_filter_band', TCIInt(0), TCIInt(-2700), TCIInt(-300)), '');
end;

procedure TTCIProtocolTests.Test_Msg_NameIsLowercased;
begin
   BeginTest('Test_Msg_NameIsLowercased');
   // Outbound is always lowercase; some client parsers compare without
   // folding case, so an accidental capital makes the command invisible.
   CheckEquals('ready;', TCIMsg('READY'), '');
   CheckEquals('split_enable:0,true;',
               TCIMsg('Split_Enable', TCIInt(0), TCIBool(True)), '');
end;

procedure TTCIProtocolTests.Test_Msg_SanitizesSeparators;
begin
   BeginTest('Test_Msg_SanitizesSeparators');
   // A value carrying ';' or ',' re-frames the stream for EVERY client on
   // the socket, not just the one that asked.  Ours are numeric today, but
   // the guard lives in the formatter so it cannot be forgotten when a
   // radio-supplied name eventually goes out.
   CheckEquals('device:TR_4W;', TCIMsg('device', 'TR;4W'), 'a semicolon cannot end the command early');
   CheckEquals('device:TR_4W;', TCIMsg('device', 'TR,4W'), 'and a comma cannot add an argument');
end;

procedure TTCIProtocolTests.Test_Msg_SanitizesNewlines;
begin
   BeginTest('Test_Msg_SanitizesNewlines');
   CheckEquals('device:a__b;', TCIMsg('device', 'a'#13#10'b'),
               'CR/LF survive a TEXT frame and confuse line-oriented clients');
end;

procedure TTCIProtocolTests.Test_FreeText_KeepsCommasButNotSemicolons;
begin
   BeginTest('Test_FreeText_KeepsCommasButNotSemicolons');
   // A CW message legitimately contains commas -- they are payload, not
   // framing -- but a ';' would still end the command early.
   CheckEquals('cw_msg:CQ TEST, CQ TEST DE NY4I;',
               TCIMsgFreeText('cw_msg', 'CQ TEST, CQ TEST DE NY4I'), '');
   CheckEquals('cw_msg:CQ_TEST;',
               TCIMsgFreeText('cw_msg', 'CQ;TEST'), '');
end;

procedure TTCIProtocolTests.Test_CommaBearingIdentityValuesNeedFreeText;
begin
   BeginTest('Test_CommaBearingIdentityValuesNeedFreeText');
   // A REAL BUG THIS SUITE CAUGHT.  Two identity values are legitimately
   // comma-bearing: modulations_list IS a comma-separated list, and
   // 'ExpertSDR3,1.5' is a two-field value.  Formatting them with TCIMsg
   // scrubs the comma to '_', and 'protocol:expertsdr3_1.5;' is exactly the
   // string WSJT-X fails to match before it halves transmit amplitude.
   //
   // Both directions are asserted, so neither the scrub nor the exemption
   // can be removed silently.
   CheckEquals('protocol:ExpertSDR3_1.5;', TCIMsg('protocol', TCI_PROTOCOL_ID),
               'TCIMsg scrubs the comma -- which is why it must NOT be used here');
   CheckEquals('protocol:ExpertSDR3,1.5;', TCIMsgFreeText('protocol', TCI_PROTOCOL_ID),
               'TCIMsgFreeText preserves it');
   CheckTrue(Pos(',', TCIMsgFreeText('modulations_list', TCI_MODULATIONS)) > 0,
             'the modulation list keeps its separators');
   CheckEquals('modulations_list:' + TCI_MODULATIONS + ';',
               TCIMsgFreeText('modulations_list', TCI_MODULATIONS), '');
end;

procedure TTCIProtocolTests.Test_Bool_IsLowercaseLiteral;
begin
   BeginTest('Test_Bool_IsLowercaseLiteral');
   CheckEquals('true', TCIBool(True), '');
   CheckEquals('false', TCIBool(False), '');
end;

{ -------------------------------------------------------------- identity -- }

procedure TTCIProtocolTests.Test_Identity_ProtocolAnnouncesExpertSDR3;
begin
   BeginTest('Test_Identity_ProtocolAnnouncesExpertSDR3');
   // Not cosmetic.  WSJT-X's TCITransceiver halves transmit sample amplitude
   // (about -6 dB) unless the protocol string starts with 'ExpertSDR3'; the
   // same flag also selects the command formats we implement.
   CheckEquals('ExpertSDR3', Copy(TCI_PROTOCOL_ID, 1, 10),
               'the protocol string must START with ExpertSDR3');
end;

procedure TTCIProtocolTests.Test_Identity_DeviceIsNotASunSDR;
begin
   BeginTest('Test_Identity_DeviceIsNotASunSDR');
   // The gain-reduction path in WSJT-X triggers on a SunSDR device name.
   CheckTrue(Pos('SunSDR', TCI_DEVICE_NAME) = 0, 'the device name must not name a SunSDR');
   CheckTrue(Trim(TCI_DEVICE_NAME) = TCI_DEVICE_NAME,
             'no leading or trailing space -- clients have tripped on that');
   CheckTrue(TCI_DEVICE_NAME <> '', '');
end;

procedure TTCIProtocolTests.Test_Identity_ModulationsAreLowercaseAndSettable;
begin
   BeginTest('Test_Identity_ModulationsAreLowercaseAndSettable');
   CheckEquals(LowerCase(TCI_MODULATIONS), TCI_MODULATIONS, 'wire values are lowercase');
   CheckTrue(Pos('cw', TCI_MODULATIONS) > 0, 'a contest logger that cannot say CW is useless');
   CheckTrue(Pos('cwr', TCI_MODULATIONS) > 0, 'CW-reverse is a distinct TCI mode');
   CheckTrue(Pos('usb', TCI_MODULATIONS) > 0, '');
   CheckTrue(Pos('lsb', TCI_MODULATIONS) > 0, '');
   CheckTrue(Pos(';', TCI_MODULATIONS) = 0, 'a semicolon here would truncate the burst');
end;

procedure TTCIProtocolTests.Test_Identity_LimitsAreSelfConsistent;
begin
   BeginTest('Test_Identity_LimitsAreSelfConsistent');
   // The reference server answers DIFFERENT limits on request than it sends
   // in its init burst, which is a defect rather than a convention.  Single
   // constants make the two impossible to disagree.
   CheckTrue(TCI_VFO_LIMIT_LOW < TCI_VFO_LIMIT_HIGH, 'vfo limits are ordered');
   CheckTrue(TCI_IF_LIMIT_LOW < TCI_IF_LIMIT_HIGH, 'if limits are ordered');
   CheckTrue(TCI_VFO_LIMIT_LOW > 0, '');
   CheckEquals(2, TCI_CHANNELS_COUNT, 'two channels: RX and TX per receiver');
end;

procedure TTCIProtocolTests.RunAllTests;
begin
   Test_Framer_SingleCommand;
   Test_Framer_SeveralInOneFrame;
   Test_Framer_CommandSplitAcrossFrames;
   Test_Framer_TrimsWhitespace;
   Test_Framer_NoTerminatorYieldsNothing;
   Test_Framer_OverflowIsReported;
   Test_Framer_ResetClearsState;

   Test_Parse_NameIsLowercased;
   Test_Parse_NoArguments;
   Test_Parse_ArgumentsAreTrimmed;
   Test_Parse_ArgumentsKeepTheirCase;
   Test_Parse_EmptyArgumentListIsZeroArgs;
   Test_Parse_MissingArgumentReadsEmpty;
   Test_Parse_ArgIntDefault;
   Test_Parse_ArgBoolIsStrict;

   Test_Classify_OneArgumentSet_IsASet;
   Test_Classify_GlobalGetWithNoArgs;
   Test_Classify_Vfo;
   Test_Classify_Trx;
   Test_Classify_Drive_BothGetForms;
   Test_Classify_RxFilterBand_NeedsThree;
   Test_Classify_TxEnable_IsNotificationOnly;
   Test_Classify_Unknown;
   Test_Classify_Malformed;
   Test_Classify_StartStopTakeNoArguments;
   Test_Classify_IsCaseInsensitive;

   Test_Msg_Shapes;
   Test_Msg_NameIsLowercased;
   Test_Msg_SanitizesSeparators;
   Test_Msg_SanitizesNewlines;
   Test_FreeText_KeepsCommasButNotSemicolons;
   Test_CommaBearingIdentityValuesNeedFreeText;
   Test_Bool_IsLowercaseLiteral;

   Test_Identity_ProtocolAnnouncesExpertSDR3;
   Test_Identity_DeviceIsNotASunSDR;
   Test_Identity_ModulationsAreLowercaseAndSettable;
   Test_Identity_LimitsAreSelfConsistent;
end;

end.
