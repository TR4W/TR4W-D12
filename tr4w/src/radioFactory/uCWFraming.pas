{
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
}
unit uCWFraming;

{
  HOW A CW-BY-CAT MESSAGE IS CUT UP FOR A GIVEN RADIO -- the per-model length
  limit and padding rule, and the chunking that follows from them.

  WHY THIS UNIT EXISTS.  These rules were embedded in the middle of
  LOGRADIO.RadioObject.SendCW's `case rt of`, which is legacy radio-driver code
  scheduled for deletion.  They are NOT protocol framing that dies with it --
  they are hard-won facts about real radios (see the K3/K4 note below), and the
  factory drivers need exactly the same facts when CW-by-CAT is repointed at
  them (docs/CW_Keyer_Factory_Plan.md, "CAT repoint").  Extracting them here:

    * gives both paths ONE source of truth, so they cannot drift apart while
      the migration is half-done;
    * makes them UNIT-TESTABLE.  This is pure string manipulation -- no port,
      no radio, no timing -- so the rules can be pinned offline instead of
      re-discovered on a bench.  uTestCWFraming does exactly that.

  Nothing here talks to a radio.  Deciding WHETHER to send, and actually
  sending, stay with the caller.
}

interface

uses
   VC;   // InterfacedRadioType

type
   // What one radio needs done to a CW message before it goes out.
   TCWFrameRule = record
      maxLen: integer;    // longest text the radio accepts in one command
      pad: boolean;       // pad the last chunk out to maxLen with spaces?
   end;

// The rule for a model.  `network` distinguishes the two Flex transports (the
// SmartSDR Ethernet API's cwx send has no limit and needs no padding; the Flex
// CAT/serial KY path behaves like a Kenwood).  Radios with no CW-by-CAT get
// maxLen 0, which CWChunkCount/CWChunk treat as "send it whole".
function CWFrameRuleFor(model: InterfacedRadioType; network: boolean): TCWFrameRule;

// How many commands `text` will take under `rule`.  0 for empty text.
function CWChunkCount(const text: string; const rule: TCWFrameRule): integer;

// Chunk `index` (1-based) of `text` under `rule`, padded if the rule says so.
// Returns '' when index is out of range.
function CWChunk(const text: string; const rule: TCWFrameRule; index: integer): string;

// The chunk's REAL text, before padding -- what the caller must count elements
// on.  The radio trims trailing pad spaces instead of keying them, so counting
// the padded form inflates the busy timer (a 1-char '?' padded to 22 counted as
// 165 elements gave a bogus ~8 s CWByCAT_Sending window).  Issue 153.
function CWChunkUnpadded(const text: string; const rule: TCWFrameRule; index: integer): string;

implementation

uses
   Math;

function CWFrameRuleFor(model: InterfacedRadioType; network: boolean): TCWFrameRule;
begin
   Result.maxLen := 0;      // "no limit / not a CW-by-CAT radio"
   Result.pad := False;
   case model of
      TS890:
         begin
         // The TS-890 accepts the space-prefixed KY form with a VARIABLE-length
         // P2 (KY <space><text>;), so no 24-byte fill -- and never KY2, since
         // P1='2' would key the fill spaces as dead air.  The other Kenwoods
         // reject a short P2 under P1=space, so they keep the fixed-24 fill.
         Result.maxLen := 24;
         Result.pad := False;
         end;
      TS480, TS570, TS590, TS950, TS990, TS2000:
         begin
         Result.maxLen := 24;
         Result.pad := True;
         end;
      FLEX:
         begin
         // Ethernet API (cwx): no length limit, no padding.  Serial CAT (KY):
         // behaves like a Kenwood.
         Result.maxLen := 24;
         Result.pad := not network;
         end;
      K2:
         begin
         Result.maxLen := 22;
         Result.pad := False;
         end;
      K3, KX3, K4:
         begin
         Result.maxLen := 22;
         // A short KY fails on the K3/KX3/K4 ONLY when it follows the keyer
         // abort TR4W sends before every message ('KY <04>;RX;', from
         // StopSendingCW): the abort/RX transition swallows a short following
         // message, while >= 8 chars survives it.  (tr4w.log 2026-06-18:
         // 'KY AGN4567;' silent, 'KY AGN45678;' keys; a standalone 'KY ?;' from
         // the K3 utility keys fine -- so this is the ABORT WINDOW, not a radio
         // length floor.)  Padding to maxLen gives every message enough runway
         // to survive the abort; under P1=space the radio trims the trailing
         // fill instead of keying it.
         Result.pad := True;
         end;
   end;
end;

function CWChunkCount(const text: string; const rule: TCWFrameRule): integer;
begin
   if text = '' then
      begin
      Result := 0;
      end
   else if rule.maxLen <= 0 then
      begin
      Result := 1;   // no limit -- one command carries the lot
      end
   else
      begin
      Result := (Length(text) + rule.maxLen - 1) div rule.maxLen;
      end;
end;

function CWChunkUnpadded(const text: string; const rule: TCWFrameRule;
                         index: integer): string;
var
   startPos: integer;
begin
   Result := '';
   if (index < 1) or (index > CWChunkCount(text, rule)) then
      begin
      Exit;
      end;
   if rule.maxLen <= 0 then
      begin
      Result := text;
      Exit;
      end;
   startPos := ((index - 1) * rule.maxLen) + 1;
   Result := Copy(text, startPos, rule.maxLen);
end;

function CWChunk(const text: string; const rule: TCWFrameRule;
                 index: integer): string;
begin
   Result := CWChunkUnpadded(text, rule, index);
   if (Result <> '') and rule.pad then
      begin
      while Length(Result) < rule.maxLen do
         begin
         Result := Result + ' ';
         end;
      end;
end;

end.
