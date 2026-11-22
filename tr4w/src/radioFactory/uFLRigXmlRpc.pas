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
unit uFLRigXmlRpc;
{$I ..\tr4w.inc}

(* THE FLRIG WIRE FORMAT: XML-RPC, ENCODED AND DECODED.  Pure -- no socket, no
  radio object, no logger -- so every byte this unit produces or accepts is
  pinned by uTestFLRigXmlRpc without FLRig running.

  WHERE THE FACTS COME FROM.
    - The XML-RPC envelope (methodCall / methodResponse / params / fault, the
      scalar types i4, int, double, string, boolean, and an untyped <value>
      being a string) is the XML-RPC specification.
    - Which METHODS exist was read from the flrig 2.0.12 binary on NY4I's
      station (C:\radio\flrig-2.0.12\flrig.exe, its string table), not from
      memory.  The driver uses only names found there.
    - The argument TYPES and the shape of FLRig's answers were read from
      Hamlib's FLRig backend (rigs/dummy/flrig.c), which is driven against
      real FLRig every day: frequencies are sent as <double> with no decimal
      part, PTT and split as <i4>, a mode as an untyped <value>; get_vfoA/B
      come back as text that atof() reads, get_ptt/get_split as integers,
      get_AB as "A" or "B", and get_modes as an array.
    - The mode NAMES are Hamlib's list of every name FLRig is known to report
      (flrig.c, the rig.get_modes switch).  They are rig-specific -- FLRig
      passes the rig's own spelling through -- so nothing here hard-codes ONE
      rig's list: the driver asks rig.get_modes and this table only says what
      each name MEANS.

  NOTHING HERE IS A CAPTURE.  The canned responses in the test are built from
  the specification and Hamlib's parser.  docs/BENCH_QUEUE.md asks for a real
  capture from FLRig driving a K4. *)

interface

uses
   SysUtils, Classes, uFactoryRadioBase;

const
   (* FLRig's default XML-RPC server port. *)
   FLRIG_DEFAULT_PORT = 12345;

   (* The path XML-RPC clients conventionally post to.  FLRig's server (an
     XmlRpc++ derivative) does not route on it; Hamlib sends /RPC2. *)
   FLRIG_RPC_PATH = '/RPC2';

type
   (* What a response turned out to be. *)
   TXmlRpcOutcome = (
      xoValue,      // a methodResponse with params (possibly none)
      xoFault,      // a methodResponse carrying a fault
      xoMalformed   // not a methodResponse this decoder can read
   );

(* & < > " ' as entities, for text placed inside an element. *)
function XmlRpcEscape(const s: string): string;

(* The five predefined entities back to characters, plus decimal and hex
  character references.  An entity this does not know is left as written. *)
function XmlRpcUnescape(const s: string): string;

(* ONE <param>'s <value>, ready for XmlRpcMethodCall. *)
function XmlRpcIntParam(v: integer): string;
(* A frequency, as Hamlib sends it to FLRig: a <double> with no decimal part.
  Written from the integer, so no locale and no float formatting is involved. *)
function XmlRpcHzParam(hz: LongInt): string;
(* An UNTYPED value, which XML-RPC defines as a string -- the form Hamlib
  sends FLRig's set_mode. *)
function XmlRpcStringParam(const s: string): string;

(* A whole <methodCall> document.  aParams are values from the three
  functions above, each wrapped in its own <param>. *)
function XmlRpcMethodCall(const aMethod: string; const aParams: array of string): string;

(* The <methodName> of a <methodCall> document, unescaped; '' when there is
  none.  For log lines about a queued call. *)
function XmlRpcMethodNameOf(const aCall: string): string;

(* DECODE A <methodResponse>.  For xoValue, aValues holds every scalar value in
  document order, unescaped; an array contributes each of its members, so
  rig.get_modes arrives as one name per line.  For xoFault, aFault is
  "<faultCode>: <faultString>" (either may be empty).  aValues is cleared
  first, whatever the outcome. *)
function XmlRpcDecodeResponse(const aXml: string; aValues: TStrings;
                              out aFault: string): TXmlRpcOutcome;

(* A frequency as FLRig reports it -- "14070000", or "14070000.000000" when the
  server answers a double.  False for anything that is not a non-negative
  number of Hz that fits a LongInt.  Zero is accepted: FLRig answers 0 when no
  rig is connected to it, and the driver says so rather than calling it a
  parse failure. *)
function TryFLRigHz(const s: string; out hz: LongInt): boolean;

(* "0" / "1" (and the XML-RPC boolean spellings), as get_ptt and get_split
  answer.  Any non-zero integer is on. *)
function TryFLRigFlag(const s: string; out isOn: boolean): boolean;

(* What an FLRig mode name means, as a TR4W TRadioMode -- the ACTUAL mode
  level (rmUSB, rmData...), not the ModeType roll-up.  False for a name the
  table does not know; the caller keeps what it had. *)
function FLRigModeToRadioMode(const aName: string; out aMode: TRadioMode): boolean;

(* THE NAME TO SEND for aMode.  The first entry of aRigModes (the rig's own
  list, from rig.get_modes, in its order) that means aMode.  When aRigModes is
  nil or empty -- get_modes failed or was never asked -- the first name in
  this unit's table that means aMode.  '' when nothing can express it. *)
function FLRigModeNameFor(aMode: TRadioMode; aRigModes: TStrings): string;

implementation

uses
   utils_text;

type
   TFLRigModeName = record
      name: string;
      mode: TRadioMode;
   end;

const
   (* EVERY NAME HAMLIB KNOWS FLRIG TO REPORT, and what it is in TR4W.  Source:
     Hamlib rigs/dummy/flrig.c, the rig.get_modes switch.  For a write with no
     rig list, the FIRST row for a mode is the name sent, so the plain names
     come first.

     Left out on purpose, so they read as "unknown" and the mode is kept:
       AM-D, DATA-FM, DATA-FMN, FM-D, PKT-FM -- data over AM/FM has no
         TRadioMode, and calling it USB data would be wrong;
       DSB, SAH, SAL, SAM, C4FM, SPEC, DRM -- no TR4W counterpart. *)
   FLRIG_MODE_NAMES: array[0..60] of TFLRigModeName = (
      (name: 'USB';      mode: rmUSB),
      (name: 'LSB';      mode: rmLSB),
      (name: 'CW';       mode: rmCW),
      (name: 'CW-R';     mode: rmCWRev),
      (name: 'FM';       mode: rmFM),
      (name: 'AM';       mode: rmAM),
      (name: 'DATA';     mode: rmData),
      (name: 'DATA-R';   mode: rmDataRev),
      (name: 'RTTY';     mode: rmFSK),
      (name: 'RTTY-R';   mode: rmFSKRev),
      (name: 'PSK';      mode: rmPSK),
      (name: 'PSK-R';    mode: rmPSKRev),
      (name: 'DV';       mode: rmDV),

      (name: 'CW-U';     mode: rmCW),
      (name: 'CW-USB';   mode: rmCW),
      (name: 'CWU';      mode: rmCW),
      (name: 'UCW';      mode: rmCW),
      (name: 'CW-L';     mode: rmCWRev),
      (name: 'CW-LSB';   mode: rmCWRev),
      (name: 'CWL';      mode: rmCWRev),
      (name: 'LCW';      mode: rmCWRev),

      (name: 'DATA-U';   mode: rmData),
      (name: 'DATA-USB'; mode: rmData),
      (name: 'D-USB';    mode: rmData),
      (name: 'USB-D';    mode: rmData),
      (name: 'USB-D1';   mode: rmData),
      (name: 'USB-D2';   mode: rmData),
      (name: 'USB-D3';   mode: rmData),
      (name: 'DIG';      mode: rmData),
      (name: 'DIGI';     mode: rmData),
      (name: 'DIGU';     mode: rmData),
      (name: 'DIGI-U';   mode: rmData),
      (name: 'PKT';      mode: rmData),
      (name: 'PKT-U';    mode: rmData),
      (name: 'PKT(U)';   mode: rmData),
      (name: 'USER-U';   mode: rmData),

      (name: 'DATA-L';   mode: rmDataRev),
      (name: 'DATA-LSB'; mode: rmDataRev),
      (name: 'D-LSB';    mode: rmDataRev),
      (name: 'LSB-D';    mode: rmDataRev),
      (name: 'LSB-D1';   mode: rmDataRev),
      (name: 'LSB-D2';   mode: rmDataRev),
      (name: 'LSB-D3';   mode: rmDataRev),
      (name: 'DIGL';     mode: rmDataRev),
      (name: 'DIGI-L';   mode: rmDataRev),
      (name: 'PKT-L';    mode: rmDataRev),
      (name: 'PKT(L)';   mode: rmDataRev),
      (name: 'USER-L';   mode: rmDataRev),

      (name: 'FSK';      mode: rmFSK),
      (name: 'RTTY-U';   mode: rmFSK),
      (name: 'RTTY(U)';  mode: rmFSK),
      (name: 'FSK-R';    mode: rmFSKRev),
      (name: 'RTTY-L';   mode: rmFSKRev),
      (name: 'PSK-U';    mode: rmPSK),
      (name: 'PSK-L';    mode: rmPSKRev),

      (name: 'FMN';      mode: rmFM),
      (name: 'FM-N';     mode: rmFM),
      (name: 'NFM';      mode: rmFM),
      (name: 'AM-N';     mode: rmAM),
      (name: 'AMN';      mode: rmAM),
      (name: 'WFM';      mode: rmFM)
   );

(* ---------------------------------------------------------------- text -- *)

function XmlRpcEscape(const s: string): string;
var
   i: integer;
begin
   Result := '';
   for i := 1 to Length(s) do
      begin
      case s[i] of
         '&':
            begin
            Result := Result + '&amp;';
            end;
         '<':
            begin
            Result := Result + '&lt;';
            end;
         '>':
            begin
            Result := Result + '&gt;';
            end;
         '"':
            begin
            Result := Result + '&quot;';
            end;
         '''':
            begin
            Result := Result + '&apos;';
            end;
         else
            begin
            Result := Result + s[i];
            end;
      end;
      end;
end;

(* One entity body (between '&' and ';') to its character; False when it is
  not one this decoder knows. *)
function DecodeEntity(const aBody: string; out aChar: string): boolean;
var
   code: integer;
   number: LongInt;
begin
   Result := True;
   aChar := '';
   if aBody = 'amp' then
      begin
      aChar := '&';
      end
   else if aBody = 'lt' then
      begin
      aChar := '<';
      end
   else if aBody = 'gt' then
      begin
      aChar := '>';
      end
   else if aBody = 'quot' then
      begin
      aChar := '"';
      end
   else if aBody = 'apos' then
      begin
      aChar := '''';
      end
   else if (Length(aBody) >= 2) and (aBody[1] = '#') then
      begin
      if (aBody[2] = 'x') or (aBody[2] = 'X') then
         begin
         ValChecked('$' + Copy(aBody, 3, MaxInt), number, code);
         end
      else
         begin
         ValChecked(Copy(aBody, 2, MaxInt), number, code);
         end;
      if (code <> 0) or (number <= 0) or (number > $FFFF) then
         begin
         Result := False;
         Exit;
         end;
      aChar := string(WideChar(number));
      end
   else
      begin
      Result := False;
      end;
end;

function XmlRpcUnescape(const s: string): string;
var
   i: integer;
   semi: integer;
   decoded: string;
begin
   Result := '';
   i := 1;
   while i <= Length(s) do
      begin
      if s[i] = '&' then
         begin
         semi := i + 1;
         while (semi <= Length(s)) and (s[semi] <> ';') and (semi - i <= 10) do
            begin
            Inc(semi);
            end;
         if (semi <= Length(s)) and (s[semi] = ';') and
            DecodeEntity(Copy(s, i + 1, semi - i - 1), decoded) then
            begin
            Result := Result + decoded;
            i := semi + 1;
            Continue;
            end;
         end;
      Result := Result + s[i];
      Inc(i);
      end;
end;

(* ------------------------------------------------------------- encoding -- *)

function XmlRpcIntParam(v: integer): string;
begin
   Result := '<value><i4>' + IntToStr(v) + '</i4></value>';
end;

function XmlRpcHzParam(hz: LongInt): string;
begin
   Result := '<value><double>' + IntToStr(hz) + '</double></value>';
end;

function XmlRpcStringParam(const s: string): string;
begin
   Result := '<value>' + XmlRpcEscape(s) + '</value>';
end;

function XmlRpcMethodCall(const aMethod: string; const aParams: array of string): string;
var
   i: integer;
begin
   Result := '<?xml version="1.0"?>' + #13#10 +
             '<methodCall><methodName>' + XmlRpcEscape(aMethod) + '</methodName>' + #13#10;
   if Length(aParams) > 0 then
      begin
      Result := Result + '<params>';
      for i := Low(aParams) to High(aParams) do
         begin
         Result := Result + '<param>' + aParams[i] + '</param>';
         end;
      Result := Result + '</params>' + #13#10;
      end;
   Result := Result + '</methodCall>' + #13#10;
end;

(* ------------------------------------------------------------- decoding -- *)

function XmlRpcMethodNameOf(const aCall: string): string;
var
   startAt: integer;
   endAt: integer;
begin
   Result := '';
   startAt := Pos('<methodName>', aCall);
   if startAt = 0 then
      begin
      Exit;
      end;
   startAt := startAt + Length('<methodName>');
   endAt := Pos('</methodName>', aCall);
   if endAt < startAt then
      begin
      Exit;
      end;
   Result := XmlRpcUnescape(Copy(aCall, startAt, endAt - startAt));
end;

(* Position of aNeedle in aText at or after aFrom; 0 when absent. *)
function PosFrom(const aNeedle, aText: string; aFrom: integer): integer;
var
   found: integer;
begin
   Result := 0;
   if aFrom < 1 then
      begin
      aFrom := 1;
      end;
   if aFrom > Length(aText) then
      begin
      Exit;
      end;
   found := Pos(aNeedle, Copy(aText, aFrom, MaxInt));
   if found > 0 then
      begin
      Result := aFrom + found - 1;
      end;
end;

function IsXmlSpace(c: Char): boolean;
begin
   Result := (c = ' ') or (c = #9) or (c = #10) or (c = #13);
end;

type
   (* What one <value> turned out to hold. *)
   TValueKind = (vkScalar, vkContainer, vkBroken);

(* READ THE VALUE WHOSE CONTENT STARTS AT aPos (just past '<value>').
  vkScalar: aText is the unescaped scalar.  vkContainer: an array or struct,
  whose member values the caller finds by carrying on scanning.  vkBroken: an
  unterminated element. *)
function ReadValueAt(const aXml: string; aPos: integer; out aText: string): TValueKind;
var
   p: integer;
   tagEnd: integer;
   tag: string;
   closeAt: integer;
begin
   aText := '';
   Result := vkBroken;

   (* Whitespace before a child element is formatting; before plain text it
     is part of an untyped string, so look ahead without consuming it. *)
   p := aPos;
   while (p <= Length(aXml)) and IsXmlSpace(aXml[p]) do
      begin
      Inc(p);
      end;

   if (p <= Length(aXml)) and (aXml[p] = '<') then
      begin
      if Copy(aXml, p, 8) = '</value>' then
         begin
         (* <value></value>: an empty untyped string. *)
         aText := XmlRpcUnescape(Copy(aXml, aPos, p - aPos));
         Result := vkScalar;
         Exit;
         end;

      tagEnd := PosFrom('>', aXml, p);
      if tagEnd = 0 then
         begin
         Exit;
         end;
      tag := Copy(aXml, p + 1, tagEnd - p - 1);

      if (tag <> '') and (tag[Length(tag)] = '/') then
         begin
         (* <string/>: an empty typed scalar. *)
         Result := vkScalar;
         Exit;
         end;

      if (tag = 'array') or (tag = 'struct') then
         begin
         Result := vkContainer;
         Exit;
         end;

      closeAt := PosFrom('</' + tag + '>', aXml, tagEnd + 1);
      if closeAt = 0 then
         begin
         Exit;
         end;
      aText := XmlRpcUnescape(Copy(aXml, tagEnd + 1, closeAt - tagEnd - 1));
      if (tag = 'i4') or (tag = 'int') or (tag = 'double') or (tag = 'boolean') then
         begin
         aText := Trim(aText);
         end;
      Result := vkScalar;
      Exit;
      end;

   (* Untyped: everything up to </value> is the string. *)
   closeAt := PosFrom('</value>', aXml, aPos);
   if closeAt = 0 then
      begin
      Exit;
      end;
   aText := XmlRpcUnescape(Copy(aXml, aPos, closeAt - aPos));
   Result := vkScalar;
end;

(* The scalar value of the struct member named aName, searched from aFrom. *)
function MemberValue(const aXml, aName: string; aFrom: integer): string;
var
   at: integer;
   valueAt: integer;
begin
   Result := '';
   at := PosFrom('<name>' + aName + '</name>', aXml, aFrom);
   if at = 0 then
      begin
      Exit;
      end;
   valueAt := PosFrom('<value>', aXml, at);
   if valueAt = 0 then
      begin
      Exit;
      end;
   if ReadValueAt(aXml, valueAt + Length('<value>'), Result) <> vkScalar then
      begin
      Result := '';
      end;
end;

function XmlRpcDecodeResponse(const aXml: string; aValues: TStrings;
                              out aFault: string): TXmlRpcOutcome;
var
   responseAt: integer;
   faultAt: integer;
   paramsAt: integer;
   paramsEnd: integer;
   p: integer;
   scalar: string;
   kind: TValueKind;
   faultCode: string;
   faultString: string;
begin
   aFault := '';
   aValues.Clear;
   Result := xoMalformed;

   responseAt := Pos('<methodResponse>', aXml);
   if (responseAt = 0) or (PosFrom('</methodResponse>', aXml, responseAt) = 0) then
      begin
      Exit;
      end;

   faultAt := PosFrom('<fault>', aXml, responseAt);
   if faultAt > 0 then
      begin
      faultCode := Trim(MemberValue(aXml, 'faultCode', faultAt));
      faultString := MemberValue(aXml, 'faultString', faultAt);
      aFault := faultCode + ': ' + faultString;
      Result := xoFault;
      Exit;
      end;

   paramsAt := PosFrom('<params>', aXml, responseAt);
   if paramsAt = 0 then
      begin
      (* <params/> or no params at all: a void answer.  Legal, and what a SET
        may return. *)
      if (PosFrom('<params/>', aXml, responseAt) > 0) or
         (PosFrom('<param', aXml, responseAt) = 0) then
         begin
         Result := xoValue;
         end;
      Exit;
      end;
   paramsEnd := PosFrom('</params>', aXml, paramsAt);
   if paramsEnd = 0 then
      begin
      Exit;
      end;

   p := PosFrom('<value>', aXml, paramsAt);
   while (p > 0) and (p < paramsEnd) do
      begin
      kind := ReadValueAt(aXml, p + Length('<value>'), scalar);
      case kind of
         vkScalar:
            begin
            aValues.Add(AnsiString(scalar));
            end;
         vkContainer:
            begin
            (* Its members are the next <value>s; nothing to add for it. *)
            end;
         vkBroken:
            begin
            aValues.Clear;
            Exit;
            end;
      end;
      p := PosFrom('<value>', aXml, p + Length('<value>'));
      end;
   Result := xoValue;
end;

(* ------------------------------------------------------------- numbers -- *)

function TryFLRigHz(const s: string; out hz: LongInt): boolean;
var
   trimmed: string;
   value: Double;
   code: integer;
begin
   Result := False;
   hz := 0;
   trimmed := Trim(s);
   if trimmed = '' then
      begin
      Exit;
      end;
   (* Val, through ValChecked, always reads '.' as the decimal point -- the
     locale is never consulted, which is what a wire number wants. *)
   ValChecked(trimmed, value, code);
   if code <> 0 then
      begin
      Exit;
      end;
   if (value < 0) or (value > High(LongInt)) then
      begin
      Exit;
      end;
   hz := Round(value);
   Result := True;
end;

function TryFLRigFlag(const s: string; out isOn: boolean): boolean;
var
   trimmed: string;
   value: LongInt;
   code: integer;
begin
   Result := False;
   isOn := False;
   trimmed := Trim(s);
   if trimmed = '' then
      begin
      Exit;
      end;
   if UnicodeSameText(trimmed, 'true') then
      begin
      isOn := True;
      Result := True;
      Exit;
      end;
   if UnicodeSameText(trimmed, 'false') then
      begin
      Result := True;
      Exit;
      end;
   ValChecked(trimmed, value, code);
   if code <> 0 then
      begin
      Exit;
      end;
   isOn := value <> 0;
   Result := True;
end;

(* --------------------------------------------------------------- modes -- *)

function FLRigModeToRadioMode(const aName: string; out aMode: TRadioMode): boolean;
var
   i: integer;
   name: string;
begin
   Result := False;
   aMode := rmNone;
   name := Trim(aName);
   for i := Low(FLRIG_MODE_NAMES) to High(FLRIG_MODE_NAMES) do
      begin
      if UnicodeSameText(FLRIG_MODE_NAMES[i].name, name) then
         begin
         aMode := FLRIG_MODE_NAMES[i].mode;
         Result := True;
         Exit;
         end;
      end;
end;

function FLRigModeNameFor(aMode: TRadioMode; aRigModes: TStrings): string;
var
   i: integer;
   meaning: TRadioMode;
begin
   Result := '';
   if aMode = rmNone then
      begin
      Exit;
      end;

   if (aRigModes <> nil) and (aRigModes.Count > 0) then
      begin
      for i := 0 to aRigModes.Count - 1 do
         begin
         if FLRigModeToRadioMode(aRigModes[i], meaning) and (meaning = aMode) then
            begin
            Result := Trim(aRigModes[i]);
            Exit;
            end;
         end;
      Exit;
      end;

   for i := Low(FLRIG_MODE_NAMES) to High(FLRIG_MODE_NAMES) do
      begin
      if FLRIG_MODE_NAMES[i].mode = aMode then
         begin
         Result := FLRIG_MODE_NAMES[i].name;
         Exit;
         end;
      end;
end;

end.
