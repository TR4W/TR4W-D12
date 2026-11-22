unit uTestFLRigXmlRpc;
{$I ..\..\src\tr4w.inc}

(*
  THE FLRIG XML-RPC WIRE FORMAT (issue 5), pure: no socket, no FLRig.

  THE CANNED RESPONSES ARE CONSTRUCTED, NOT CAPTURED.  They are built from the
  XML-RPC specification and from what Hamlib's FLRig backend
  (rigs/dummy/flrig.c) parses out of real FLRig answers: frequencies as text
  or a double, PTT and split as integers, get_AB as "A"/"B", get_modes as an
  array, a fault as a struct with faultCode and faultString.  A capture from
  FLRig driving NY4I's K4 is on docs/BENCH_QUEUE.md; when it exists, add it
  here verbatim beside these.

  The method names used by the driver were read from the flrig 2.0.12 binary,
  and the call shapes (a <double> frequency with no decimal part, an <i4> PTT,
  an untyped mode string) are Hamlib's.
*)

interface

uses
   SysUtils, Classes, uTR4WTestFramework, uFactoryRadioBase, uFLRigXmlRpc;

type
   TFLRigXmlRpcTests = class(TTestCase)
   protected
      procedure Test_MethodCallShapes;
      procedure Test_EscapeAndUnescape;
      procedure Test_DecodeScalars;
      procedure Test_DecodeArray;
      procedure Test_DecodeEmptyAndVoid;
      procedure Test_DecodeFault;
      procedure Test_DecodeMalformed;
      procedure Test_Hz;
      procedure Test_Flag;
      procedure Test_ModeNamesRead;
      procedure Test_ModeNameForWriteFollowsTheRigList;
      procedure Test_ModeNameForWriteWithoutARigList;
   public
      procedure RunAllTests; override;
   end;

implementation

function Response(const aValueXml: string): string;
begin
   Result := '<?xml version="1.0"?>' + #13#10 +
             '<methodResponse><params><param>' + #13#10 +
             aValueXml + #13#10 +
             '</param></params></methodResponse>' + #13#10;
end;

(* Decode and answer the values as one '|'-joined string, so a failure shows
  the whole list. *)
function DecodeJoined(const aXml: string; out aOutcome: TXmlRpcOutcome; out aFault: string): string;
var
   values: TStringList;
   i: integer;
begin
   Result := '';
   values := TStringList.Create;
   try
      aOutcome := XmlRpcDecodeResponse(aXml, values, aFault);
      for i := 0 to values.Count - 1 do
         begin
         if i > 0 then
            begin
            Result := Result + '|';
            end;
         Result := Result + values[i];
         end;
   finally
      values.Free;
   end;
end;

procedure TFLRigXmlRpcTests.Test_MethodCallShapes;
var
   call: string;
begin
   BeginTest('Test_MethodCallShapes');

   call := XmlRpcMethodCall('rig.get_vfoA', []);
   CheckTrue(Pos('<methodName>rig.get_vfoA</methodName>', call) > 0, 'method name: ' + call);
   CheckTrue(Pos('<params>', call) = 0, 'a getter carries no params: ' + call);
   CheckTrue(Pos('<?xml version="1.0"?>', call) = 1, 'starts with the XML declaration');
   CheckTrue(Pos('</methodCall>', call) > 0, 'closed');

   (* Hamlib's flrig_set_freq: <double>%.0f</double> -- no decimal part. *)
   CheckEquals('<value><double>14025000</double></value>', XmlRpcHzParam(14025000), 'frequency param');
   (* Hamlib's flrig_set_ptt / set_split: <i4>. *)
   CheckEquals('<value><i4>1</i4></value>', XmlRpcIntParam(1), 'ptt on');
   CheckEquals('<value><i4>0</i4></value>', XmlRpcIntParam(0), 'ptt off');
   (* Hamlib's flrig_set_mode: an untyped value. *)
   CheckEquals('<value>CW-R</value>', XmlRpcStringParam('CW-R'), 'mode param');

   call := XmlRpcMethodCall('rig.set_vfoA', [XmlRpcHzParam(7030000)]);
   CheckTrue(Pos('<params><param><value><double>7030000</double></value></param></params>', call) > 0,
             'one param, wrapped: ' + call);
   CheckEquals('rig.set_vfoA', XmlRpcMethodNameOf(call), 'method name read back');
   CheckEquals('', XmlRpcMethodNameOf('not a call'), 'no method name');
end;

procedure TFLRigXmlRpcTests.Test_EscapeAndUnescape;
begin
   BeginTest('Test_EscapeAndUnescape');
   CheckEquals('a&amp;b&lt;c&gt;d&quot;e&apos;f', XmlRpcEscape('a&b<c>d"e''f'), 'escape all five');
   CheckEquals('a&b<c>d"e''f', XmlRpcUnescape('a&amp;b&lt;c&gt;d&quot;e&apos;f'), 'unescape all five');
   CheckEquals('A', XmlRpcUnescape('&#65;'), 'decimal reference');
   CheckEquals('A', XmlRpcUnescape('&#x41;'), 'hex reference');
   CheckEquals('&unknown;', XmlRpcUnescape('&unknown;'), 'an unknown entity is left as written');
   CheckEquals('a & b', XmlRpcUnescape('a & b'), 'a bare ampersand is left as written');
end;

procedure TFLRigXmlRpcTests.Test_DecodeScalars;
var
   outcome: TXmlRpcOutcome;
   fault: string;
begin
   BeginTest('Test_DecodeScalars');

   CheckEquals('14025000', DecodeJoined(Response('<value>14025000</value>'), outcome, fault),
               'get_vfoA as untyped text');
   CheckTrue(outcome = xoValue, 'untyped is a value');

   CheckEquals('14025000.000000',
               DecodeJoined(Response('<value><double>14025000.000000</double></value>'), outcome, fault),
               'get_vfoA as a double');
   CheckEquals('1', DecodeJoined(Response('<value><i4>1</i4></value>'), outcome, fault), 'get_ptt as i4');
   CheckEquals('0', DecodeJoined(Response('<value><int> 0 </int></value>'), outcome, fault),
               'int, trimmed');
   CheckEquals('USB', DecodeJoined(Response('<value><string>USB</string></value>'), outcome, fault),
               'get_modeA as a string');
   CheckEquals('A', DecodeJoined(Response('<value>A</value>'), outcome, fault), 'get_AB');
   CheckEquals('Elecraft K4', DecodeJoined(Response('<value>Elecraft K4</value>'), outcome, fault),
               'get_xcvr keeps its space');
   CheckEquals('R&D', DecodeJoined(Response('<value><string>R&amp;D</string></value>'), outcome, fault),
               'string unescaped');
   CheckTrue(outcome = xoValue, 'still a value');
   CheckEquals('', fault, 'no fault text on a value');
end;

procedure TFLRigXmlRpcTests.Test_DecodeArray;
var
   outcome: TXmlRpcOutcome;
   fault: string;
   xml: string;
begin
   BeginTest('Test_DecodeArray');
   (* rig.get_modes for a K4-like rig, as an XML-RPC array of strings. *)
   xml := Response('<value><array><data>' + #13#10 +
                   '<value>LSB</value><value>USB</value><value>CW</value>' +
                   '<value><string>FM</string></value><value>AM</value>' +
                   '<value>DATA</value><value>CW-R</value><value>DATA-R</value>' + #13#10 +
                   '</data></array></value>');
   CheckEquals('LSB|USB|CW|FM|AM|DATA|CW-R|DATA-R', DecodeJoined(xml, outcome, fault), 'array members in order');
   CheckTrue(outcome = xoValue, 'an array is a value');
end;

procedure TFLRigXmlRpcTests.Test_DecodeEmptyAndVoid;
var
   outcome: TXmlRpcOutcome;
   fault: string;
begin
   BeginTest('Test_DecodeEmptyAndVoid');
   CheckEquals('', DecodeJoined(Response('<value></value>'), outcome, fault), 'empty untyped');
   CheckTrue(outcome = xoValue, 'empty untyped is a value');
   CheckEquals('', DecodeJoined(Response('<value><string/></value>'), outcome, fault), 'empty typed');
   CheckTrue(outcome = xoValue, 'empty typed is a value');
   CheckEquals('', DecodeJoined('<?xml version="1.0"?><methodResponse><params/></methodResponse>',
                                outcome, fault), 'void answer');
   CheckTrue(outcome = xoValue, 'a void answer to a set is a value');
end;

procedure TFLRigXmlRpcTests.Test_DecodeFault;
var
   outcome: TXmlRpcOutcome;
   fault: string;
   xml: string;
begin
   BeginTest('Test_DecodeFault');
   xml := '<?xml version="1.0"?>' + #13#10 +
          '<methodResponse><fault><value><struct>' +
          '<member><name>faultCode</name><value><int>-1</int></value></member>' +
          '<member><name>faultString</name><value>rig.get_modeB: unknown method name</value></member>' +
          '</struct></value></fault></methodResponse>';
   CheckEquals('', DecodeJoined(xml, outcome, fault), 'a fault carries no values');
   CheckTrue(outcome = xoFault, 'fault recognised');
   CheckEquals('-1: rig.get_modeB: unknown method name', fault, 'code and string');
end;

procedure TFLRigXmlRpcTests.Test_DecodeMalformed;
var
   outcome: TXmlRpcOutcome;
   fault: string;
begin
   BeginTest('Test_DecodeMalformed');
   DecodeJoined('', outcome, fault);
   CheckTrue(outcome = xoMalformed, 'empty text');
   DecodeJoined('<html><body>404</body></html>', outcome, fault);
   CheckTrue(outcome = xoMalformed, 'not a methodResponse');
   DecodeJoined('<methodResponse><params><param><value><i4>1</param></params></methodResponse>', outcome, fault);
   CheckTrue(outcome = xoMalformed, 'unterminated i4');
   DecodeJoined('<methodResponse><params><param><value>1', outcome, fault);
   CheckTrue(outcome = xoMalformed, 'truncated');
end;

procedure TFLRigXmlRpcTests.Test_Hz;
var
   hz: LongInt;
begin
   BeginTest('Test_Hz');
   CheckTrue(TryFLRigHz('14025000', hz) and (hz = 14025000), 'integer text');
   CheckTrue(TryFLRigHz('14025000.000000', hz) and (hz = 14025000), 'double text');
   CheckTrue(TryFLRigHz(' 7030000 ', hz) and (hz = 7030000), 'trimmed');
   CheckTrue(TryFLRigHz('0', hz) and (hz = 0), 'zero is a number -- no rig behind FLRig');
   CheckFalse(TryFLRigHz('', hz), 'empty');
   CheckFalse(TryFLRigHz('14,025,000', hz), 'thousands separators are not FLRig''s');
   CheckFalse(TryFLRigHz('-5', hz), 'negative');
   CheckFalse(TryFLRigHz('99999999999', hz), 'larger than a LongInt');
   CheckFalse(TryFLRigHz('USB', hz), 'not a number');
end;

procedure TFLRigXmlRpcTests.Test_Flag;
var
   isOn: boolean;
begin
   BeginTest('Test_Flag');
   CheckTrue(TryFLRigFlag('1', isOn) and isOn, '1 is on');
   CheckTrue(TryFLRigFlag('0', isOn) and (not isOn), '0 is off');
   CheckTrue(TryFLRigFlag('true', isOn) and isOn, 'true');
   CheckTrue(TryFLRigFlag('false', isOn) and (not isOn), 'false');
   CheckFalse(TryFLRigFlag('', isOn), 'empty');
   CheckFalse(TryFLRigFlag('maybe', isOn), 'not a flag');
end;

procedure TFLRigXmlRpcTests.Test_ModeNamesRead;

   procedure Expect(const aName: string; aWant: TRadioMode);
   var
      got: TRadioMode;
   begin
      CheckTrue(FLRigModeToRadioMode(aName, got), aName + ' is known');
      CheckTrue(got = aWant, aName + ' reads as the wanted mode');
   end;

var
   got: TRadioMode;
begin
   BeginTest('Test_ModeNamesRead');
   Expect('USB', rmUSB);
   Expect('LSB', rmLSB);
   Expect('CW', rmCW);
   Expect('CW-R', rmCWRev);
   Expect('CW-U', rmCW);
   Expect('CWL', rmCWRev);
   Expect('DATA', rmData);
   Expect('DATA-R', rmDataRev);
   Expect('DATA-U', rmData);
   Expect('PKT-L', rmDataRev);
   Expect('RTTY', rmFSK);
   Expect('RTTY-R', rmFSKRev);
   Expect('FSK-R', rmFSKRev);
   Expect('PSK-R', rmPSKRev);
   Expect('FM', rmFM);
   Expect('NFM', rmFM);
   Expect('AM', rmAM);
   Expect('usb', rmUSB);
   CheckFalse(FLRigModeToRadioMode('DATA-FM', got), 'data over FM has no TRadioMode -- unknown, not USB data');
   CheckFalse(FLRigModeToRadioMode('C4FM', got), 'C4FM unknown');
   CheckFalse(FLRigModeToRadioMode('', got), 'empty unknown');
end;

procedure TFLRigXmlRpcTests.Test_ModeNameForWriteFollowsTheRigList;
var
   k4: TStringList;
   ic: TStringList;
begin
   BeginTest('Test_ModeNameForWriteFollowsTheRigList');
   k4 := TStringList.Create;
   ic := TStringList.Create;
   try
      k4.CommaText := 'LSB,USB,CW,FM,AM,DATA,CW-R,DATA-R';
      CheckEquals('CW', FLRigModeNameFor(rmCW, k4), 'K4-like: CW');
      CheckEquals('CW-R', FLRigModeNameFor(rmCWRev, k4), 'K4-like: CW reverse');
      CheckEquals('DATA', FLRigModeNameFor(rmData, k4), 'K4-like: data');
      CheckEquals('DATA-R', FLRigModeNameFor(rmDataRev, k4), 'K4-like: data reverse');
      CheckEquals('', FLRigModeNameFor(rmFSK, k4), 'the rig lists no RTTY name -- nothing is invented');

      (* A rig that spells the same modes differently gets its own spelling. *)
      ic.CommaText := 'LSB,USB,AM,CW,RTTY,FM,CW-R,RTTY-R,LSB-D,USB-D';
      CheckEquals('USB-D', FLRigModeNameFor(rmData, ic), 'Icom-like: data is USB-D');
      CheckEquals('LSB-D', FLRigModeNameFor(rmDataRev, ic), 'Icom-like: data reverse is LSB-D');
      CheckEquals('RTTY', FLRigModeNameFor(rmFSK, ic), 'Icom-like: RTTY');
      CheckEquals('', FLRigModeNameFor(rmNone, ic), 'rmNone is never sent');
   finally
      k4.Free;
      ic.Free;
   end;
end;

procedure TFLRigXmlRpcTests.Test_ModeNameForWriteWithoutARigList;
begin
   BeginTest('Test_ModeNameForWriteWithoutARigList');
   CheckEquals('USB', FLRigModeNameFor(rmUSB, nil), 'no list: USB');
   CheckEquals('CW', FLRigModeNameFor(rmCW, nil), 'no list: the plain CW name first');
   CheckEquals('DATA', FLRigModeNameFor(rmData, nil), 'no list: DATA');
   CheckEquals('RTTY', FLRigModeNameFor(rmFSK, nil), 'no list: RTTY');
end;

procedure TFLRigXmlRpcTests.RunAllTests;
begin
   Test_MethodCallShapes;
   Test_EscapeAndUnescape;
   Test_DecodeScalars;
   Test_DecodeArray;
   Test_DecodeEmptyAndVoid;
   Test_DecodeFault;
   Test_DecodeMalformed;
   Test_Hz;
   Test_Flag;
   Test_ModeNamesRead;
   Test_ModeNameForWriteFollowsTheRigList;
   Test_ModeNameForWriteWithoutARigList;
end;

end.
