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
unit uDXLabCommanderProtocol;
{$I ..\tr4w.inc}

(* DXLAB COMMANDER'S TCP/IP MESSAGES -- THE WIRE FORMAT, AND NOTHING ELSE.

  A pure leaf: no socket, no thread, no radio object, no logger.  The driver
  (uRadioDXLabCommander) owns the transport and the state; this unit only turns
  values into bytes and bytes into values, so every rule here is pinned by
  uTestDXLabCommanderProtocol without a network.

  THE SOURCE IS DXLAB'S OWN DOCUMENT, "Commander TCP/IP Messages" (dated
  2019-07-11), attached by NY4I to issue 172 on 2026-11-16.  Nothing here is
  from memory.  What the document says, and this unit relies on:

    - A message is TWO ADIF-syntax fields: a command and its parameters.
          <command:10>CmdSetFreq<parameters:17><xcvrfreq:5>21230
      The parameters field carries zero or more ADIF fields of its own.
    - A query is answered with ONE ADIF field:
          <CmdFreq:10>14,010.500
    - CmdGetFreq / CmdGetTXFreq answer in kHz with a COMMA thousands separator
      and a PERIOD decimal separator, whatever the locale.  (CmdSendFreq /
      CmdSendTXFreq answer in the LOCALE's separators -- this unit never asks
      for those.)  A rig that has not reported answers ".000".
    - Frequencies SENT to Commander are kHz "using the locally-defined decimal
      separator" -- so the separator is a parameter here, chosen by the driver.
    - Modes are AM, CW, CW-R, DATA-L, DATA-U, FM, LSB, USB, RTTY, RTTY-R, WBFM.
      A rig that has not reported its mode answers <CmdMode:0>.

  WHAT THE DOCUMENT DOES NOT SAY, and so this unit does not assume:
    - whether a message must be followed by a terminator (none is shown);
    - whether Commander keeps a connection open after it answers;
    - whether a SET command draws a reply.
  Each is a bench question (docs/BENCH_QUEUE.md), and the driver is written to
  survive either answer.

  ONE OF THE DOCUMENT'S OWN EXAMPLES IS MISCOUNTED.  Its CmdSetFreqMode example
  says <parameters:56>, but the three fields it carries are 17 + 16 + 25 = 58
  characters.  Every other example counts correctly.  The encoder COMPUTES each
  length, and the test pins 58 -- do not "fix" either to match the document. *)

interface

uses
   uFactoryRadioBase;

const
   (* "Commander responds to messages received via the third port in the
     block (default: 52002)" -- the block's base is 52000 unless the operator
     moves it with Net Serv. *)
   COMMANDER_DEFAULT_PORT = 52002;

   (* WHAT FOLLOWS A MESSAGE ON THE WIRE.  The document shows none, and an ADIF
     field carries its own length, so none is needed.  One constant, so the
     bench answer changes one line.  (TR4W's DXKeeper client appends CR/LF; that
     is a different program and is not evidence about this one.) *)
   COMMANDER_MESSAGE_TERMINATOR = '';

   (* The reply fields, as the document spells them.  Compared without regard
     to case: ADIF field names are case-insensitive. *)
   COMMANDER_FIELD_FREQ   = 'CmdFreq';
   COMMANDER_FIELD_TXFREQ = 'CmdTXFreq';
   COMMANDER_FIELD_MODE   = 'CmdMode';
   COMMANDER_FIELD_SPLIT  = 'CmdSplit';
   COMMANDER_FIELD_TX     = 'CmdTX';

(* One ADIF field: <name:length>value.  The length is the value's character
  count, computed here, never passed in. *)
function CommanderField(const aName, aValue: string): string;

(* A whole message: <command:N>aCommand<parameters:M>aParameters.  aParameters
  is the concatenation of zero or more CommanderField values (or '' for none,
  which the document writes <parameters:0>). *)
function CommanderMessage(const aCommand, aParameters: string): string;

(* THE CW MESSAGE, item 20: "Direct the primary transceiver to transmit
  specified text in CW".  The document's example is
      <command:7>cwchars<parameters:16>testing de aa6yq
  -- the parameters field carries the RAW TEXT, not an ADIF sub-field as every
  other set does (<1:2>CW, <xcvrfreq:5>21230).  Named here so that exception is
  stated once and pinned by uTestDXLabCommanderProtocol.  The document states
  no maximum length, no speed, no prosigns and no way to stop. *)
function CommanderCWCharsMessage(const aText: string): string;

(* The text between '<' and '>' of a field header -- "CmdFreq:10", or with an
  ADIF type indicator "CmdFreq:10:N".  Anything before the LAST '<' is ignored,
  so a stray CR/LF or a partial line ahead of a header does not hide it.
  False for no name, no length, a length that is not all digits, or one that
  will not fit an integer. *)
function TryParseCommanderFieldHeader(const aHeader: string;
                                      out aName: string;
                                      out aLength: integer): boolean;

(* A complete field, header and value: '<CmdFreq:10>14,010.500'.  The value is
  exactly aLength characters; characters after it are ignored.  False when the
  header is malformed or the value is shorter than its declared length. *)
function TryParseCommanderField(const aText: string;
                                out aName: string;
                                out aValue: string): boolean;

(* Is aText EXACTLY ONE well-formed message -- a non-empty command field
  followed by a parameters field, every length right, nothing before or
  after?  For the
  operator's free-text startup command, which goes out raw: a K3's 'KY <;'
  left configured must not reach a peer that parses by length.  One message,
  not several: a peer that serves one message per connection would drop the
  rest. *)
function IsOneCommanderMessage(const aText: string): boolean;

(* The CmdGetFreq / CmdGetTXFreq answer, kHz with ',' thousands and '.'
  decimal, to Hz.  Integer arithmetic only -- no float, no locale.
  False for anything that is not a frequency TR4W can hold, AND FOR ".000"
  (and any other zero), which is Commander saying the rig has not reported:
  the caller must keep what it had rather than store a zero. *)
function TryCommanderKHzToHz(const aText: string; out aHz: LongInt): boolean;

(* Hz to the kHz text a SET command carries, with no thousands separator.
  Whole kHz is written as an integer ("21230") -- the form every example in
  the document uses, and one no locale can misread.  Anything finer is written
  to the Hz with aDecimalSeparator ("14010.500" or "14010,500"). *)
function CommanderHzToKHz(aHz: LongInt; aDecimalSeparator: Char): string;

(* A Commander mode name to TR4W's mode.  False for '' (the rig has not
  reported) and for a name the document does not list. *)
function TryCommanderModeToRadioMode(const aText: string;
                                     out aMode: TRadioMode): boolean;

(* TR4W's mode to the Commander mode name a CmdSetMode carries; '' when the
  document lists nothing that means it (rmNone, rmDV). *)
function RadioModeToCommanderMode(aMode: TRadioMode): string;

implementation

uses
   SysUtils, utils_text;

function CommanderField(const aName, aValue: string): string;
begin
   Result := '<' + aName + ':' + IntToStr(Length(aValue)) + '>' + aValue;
end;

function CommanderMessage(const aCommand, aParameters: string): string;
begin
   Result := CommanderField('command', aCommand) +
             CommanderField('parameters', aParameters);
end;

function CommanderCWCharsMessage(const aText: string): string;
begin
   Result := CommanderMessage('cwchars', aText);
end;

function AllDigits(const s: string): boolean;
var
   i: integer;
begin
   Result := Length(s) > 0;
   for i := 1 to Length(s) do
      begin
      if not CharInSet(s[i], ['0'..'9']) then
         begin
         Result := False;
         Exit;
         end;
      end;
end;

function TryParseCommanderFieldHeader(const aHeader: string;
                                      out aName: string;
                                      out aLength: integer): boolean;
var
   body: string;
   p: integer;
   lengthText: string;
   value: LongInt;
   code: integer;
begin
   Result := False;
   aName := '';
   aLength := 0;

   (* From the LAST '<', and with it removed.  A loop, not LastDelimiter,
     which takes an AnsiString in FPC 3.2.2 and would narrow. *)
   body := aHeader;
   p := Length(body);
   while (p > 0) and (body[p] <> '<') do
      begin
      Dec(p);
      end;
   if p > 0 then
      begin
      body := Copy(body, p + 1, Length(body));
      end;

   p := Pos(':', body);
   if p <= 1 then
      begin
      Exit;
      end;
   aName := Trim(Copy(body, 1, p - 1));
   lengthText := Copy(body, p + 1, Length(body));

   (* An ADIF type indicator follows a second colon; it says nothing the
     length does not. *)
   p := Pos(':', lengthText);
   if p > 0 then
      begin
      lengthText := Copy(lengthText, 1, p - 1);
      end;
   lengthText := Trim(lengthText);

   if (aName = '') or (not AllDigits(lengthText)) or (Length(lengthText) > 9) then
      begin
      aName := '';
      Exit;
      end;

   ValChecked(lengthText, value, code);
   if code <> 0 then
      begin
      aName := '';
      Exit;
      end;

   aLength := value;
   Result := True;
end;

function TryParseCommanderField(const aText: string;
                                out aName: string;
                                out aValue: string): boolean;
var
   closePos: integer;
   fieldLength: integer;
   rest: string;
begin
   Result := False;
   aName := '';
   aValue := '';

   closePos := Pos('>', aText);
   if closePos = 0 then
      begin
      Exit;
      end;

   if not TryParseCommanderFieldHeader(Copy(aText, 1, closePos - 1), aName, fieldLength) then
      begin
      Exit;
      end;

   rest := Copy(aText, closePos + 1, Length(aText));
   if Length(rest) < fieldLength then
      begin
      aName := '';
      Exit;
      end;

   aValue := Copy(rest, 1, fieldLength);
   Result := True;
end;

(* One field starting AT aPos (which must be its '<'); on success aPos moves
  past the value. *)
function TryTakeField(const aText: string; var aPos: integer;
                      out aName: string; out aValue: string): boolean;
var
   closePos: integer;
   fieldLength: integer;
begin
   Result := False;
   aName := '';
   aValue := '';
   if (aPos > Length(aText)) or (aText[aPos] <> '<') then
      begin
      Exit;
      end;
   closePos := aPos + 1;
   while (closePos <= Length(aText)) and (aText[closePos] <> '>') do
      begin
      if aText[closePos] = '<' then
         begin
         Exit;   // a header never holds a second '<'
         end;
      Inc(closePos);
      end;
   if closePos > Length(aText) then
      begin
      Exit;
      end;
   if not TryParseCommanderFieldHeader(Copy(aText, aPos + 1, closePos - aPos - 1), aName, fieldLength) then
      begin
      Exit;
      end;
   if closePos + fieldLength > Length(aText) then
      begin
      aName := '';
      Exit;
      end;
   aValue := Copy(aText, closePos + 1, fieldLength);
   aPos := closePos + 1 + fieldLength;
   Result := True;
end;

function IsOneCommanderMessage(const aText: string): boolean;
var
   p: integer;
   name: string;
   value: string;
begin
   Result := False;
   p := 1;
   if not TryTakeField(aText, p, name, value) then
      begin
      Exit;
      end;
   if (not UnicodeSameText(name, 'command')) or (value = '') then
      begin
      Exit;
      end;
   if not TryTakeField(aText, p, name, value) then
      begin
      Exit;
      end;
   if not UnicodeSameText(name, 'parameters') then
      begin
      Exit;
      end;
   Result := p = Length(aText) + 1;
end;

function TryCommanderKHzToHz(const aText: string; out aHz: LongInt): boolean;
var
   s: string;
   dotPos: integer;
   wholeText: string;
   fracText: string;
   wholeKHz: Int64;
   fracHz: Int64;
   total: Int64;
   code: integer;
begin
   Result := False;
   aHz := 0;

   s := UnicodeStringReplace(Trim(aText), ',', '', [rfReplaceAll]);
   if s = '' then
      begin
      Exit;
      end;

   dotPos := Pos('.', s);
   if dotPos > 0 then
      begin
      wholeText := Copy(s, 1, dotPos - 1);
      fracText := Copy(s, dotPos + 1, Length(s));
      end
   else
      begin
      wholeText := s;
      fracText := '';
      end;

   (* ".000" has no whole part at all: that is zero kHz, not malformed. *)
   if wholeText = '' then
      begin
      wholeText := '0';
      end;

   (* Hz resolution is three places; a fourth would be a sub-Hz digit TR4W
     cannot hold, and nothing in the document produces one. *)
   if (not AllDigits(wholeText)) or (Length(wholeText) > 9) or
      (Length(fracText) > 3) or
      ((fracText <> '') and (not AllDigits(fracText))) then
      begin
      Exit;
      end;

   while Length(fracText) < 3 do
      begin
      fracText := fracText + '0';
      end;

   ValChecked(wholeText, wholeKHz, code);
   if code <> 0 then
      begin
      Exit;
      end;
   ValChecked(fracText, fracHz, code);
   if code <> 0 then
      begin
      Exit;
      end;

   total := wholeKHz * 1000 + fracHz;
   if (total <= 0) or (total > High(LongInt)) then
      begin
      Exit;
      end;

   aHz := LongInt(total);
   Result := True;
end;

function CommanderHzToKHz(aHz: LongInt; aDecimalSeparator: Char): string;
var
   wholeKHz: LongInt;
   fracHz: LongInt;
   fracText: string;
begin
   if aHz < 0 then
      begin
      aHz := 0;
      end;
   wholeKHz := aHz div 1000;
   fracHz := aHz mod 1000;
   if fracHz = 0 then
      begin
      Result := IntToStr(wholeKHz);
      Exit;
      end;
   fracText := IntToStr(fracHz);
   while Length(fracText) < 3 do
      begin
      fracText := '0' + fracText;
      end;
   Result := IntToStr(wholeKHz) + aDecimalSeparator + fracText;
end;

function TryCommanderModeToRadioMode(const aText: string;
                                     out aMode: TRadioMode): boolean;
var
   m: string;
begin
   Result := True;
   aMode := rmNone;
   m := UpperCase(Trim(aText));
   if m = 'AM' then
      begin
      aMode := rmAM;
      end
   else if m = 'CW' then
      begin
      aMode := rmCW;
      end
   else if m = 'CW-R' then
      begin
      aMode := rmCWRev;
      end
   else if m = 'DATA-L' then
      begin
      aMode := rmDataRev;
      end
   else if m = 'DATA-U' then
      begin
      aMode := rmData;
      end
   else if (m = 'FM') or (m = 'WBFM') then
      begin
      (* TR4W has one FM.  Wide FM is still FM to the log. *)
      aMode := rmFM;
      end
   else if m = 'LSB' then
      begin
      aMode := rmLSB;
      end
   else if m = 'USB' then
      begin
      aMode := rmUSB;
      end
   else if m = 'RTTY' then
      begin
      aMode := rmFSK;
      end
   else if m = 'RTTY-R' then
      begin
      aMode := rmFSKRev;
      end
   else
      begin
      Result := False;
      end;
end;

function RadioModeToCommanderMode(aMode: TRadioMode): string;
begin
   case aMode of
      rmCW:
         begin
         Result := 'CW';
         end;
      rmCWRev:
         begin
         Result := 'CW-R';
         end;
      rmLSB:
         begin
         Result := 'LSB';
         end;
      rmUSB:
         begin
         Result := 'USB';
         end;
      rmFM:
         begin
         Result := 'FM';
         end;
      rmAM:
         begin
         Result := 'AM';
         end;
      rmData, rmPSK, rmAFSK:
         begin
         (* Sound-card data on the upper sideband, as HamLib maps PSK and
           AFSK (PKTUSB). *)
         Result := 'DATA-U';
         end;
      rmDataRev, rmPSKRev, rmAFSKRev:
         begin
         Result := 'DATA-L';
         end;
      rmFSK:
         begin
         Result := 'RTTY';
         end;
      rmFSKRev:
         begin
         Result := 'RTTY-R';
         end;
   else
      begin
      (* rmNone, rmDV: nothing in the document's list means either. *)
      Result := '';
      end;
   end;
end;

end.
