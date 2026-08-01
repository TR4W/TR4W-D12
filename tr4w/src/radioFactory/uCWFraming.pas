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
      // Safety factor on the CW-busy window (tmrCWByCAT).  The window is an
      // ESTIMATE -- elements x dot time -- and if it expires early the poll
      // thread resumes and can step on CW still being keyed.  LOGRADIO used
      // 1.0 for the KY radios and 1.25 for Icom, whose rate-limited CI-V send
      // queue makes the estimate optimistic.  Per-model data, so it lives with
      // the other per-model data rather than as a conditional at the call site.
      busyFactor: double;
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

type
   // Which CW dialect a radio speaks.  Three real ones, not two: Elecraft and
   // Kenwood substitute a single character per prosign but disagree on which,
   // and Icom uses NAMED prosigns ('^AR').  Exposed so callers can be tested
   // against the classification rather than re-deriving it from model lists.
   TCWVendor = (cvElecraft, cvKenwood, cvIcom);

   // What a radio should key for one of TR4W's prosign tokens.
   TCWProsign = record
      handled: boolean;   // True: this token IS a prosign; do not treat it as text
      text: string;       // what to append ('' = token consumed, key nothing)
   end;

// Translate one TR4W prosign token for a model.  The tokens are TR4W's own
// notation (^ half-space, ! SN, + AR, < SK, = BT); Elecraft and Kenwood spell
// the same prosigns with different characters in a KY string, which is why this
// is per-model DATA rather than protocol.
//
// `handled` and `text` are separate on purpose: Elecraft has no SN, so '!' is
// consumed and keys NOTHING -- which is not the same as an unrecognised token
// the caller should pass through as literal text.
function CWProsignFor(model: InterfacedRadioType; const token: string): TCWProsign;

// Which dialect a model speaks.  Public so the mapping itself is testable.
function CWVendorOf(model: InterfacedRadioType): TCWVendor;

// The Kenwood-protocol KY command carrying one chunk of CW text.  Identical on
// Elecraft, Kenwood and Flex-over-CAT, which is why it lives here instead of
// being written out in each of those three drivers.
//
// `immediate` selects the KYW form.  LOGRADIO used it only when a speed change
// (Ctrl-F / Ctrl-S) forced the buffer out mid-message.  Preserved verbatim
// rather than reasoned about: it is not in the K3 command reference, so its
// behaviour on real hardware is not something to infer from documentation.
function CWKYCommand(const text: string; immediate: boolean): string;

implementation

uses
   Math;

function CWFrameRuleFor(model: InterfacedRadioType; network: boolean): TCWFrameRule;
begin
   Result.maxLen := 0;      // "no limit / not a CW-by-CAT radio"
   Result.pad := False;
   Result.busyFactor := 1.0;
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
      IC78..IC9700:
         begin
         // From LOGRADIO.SendCW's rtIcom arm: `len := Min(msgLen, 28)`.  Note
         // the legacy code TRUNCATED at 28 and dropped the rest -- it never
         // looped -- so a longer message lost its tail silently.  Expressing it
         // as a frame rule means CWChunkCount/CWChunk now split it instead,
         // which is the behaviour the comment there asked for ("TODO Optimally,
         // this should be sent in multiple batches").
         Result.maxLen := 28;
         Result.pad := False;
         // 1.25 from LOGRADIO's rtIcom arm.  The CI-V send queue is rate
         // limited (~25 ms a command), so a purely element-based estimate runs
         // short on this family.
         Result.busyFactor := 1.25;
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

function CWKYCommand(const text: string; immediate: boolean): string;
begin
   // Note the space in the normal form ('KY ') and its ABSENCE in the immediate
   // one ('KYW') -- that is how LOGRADIO built them, and on the K3 the space is
   // the P1 field, so it is load-bearing rather than cosmetic.
   if immediate then
      begin
      Result := 'KYW' + text + ';';
      end
   else
      begin
      Result := 'KY ' + text + ';';
      end;
end;

function CWVendorOf(model: InterfacedRadioType): TCWVendor;
begin
   case model of
      // DELIBERATE DIVERGENCE FROM LEGACY: LOGRADIO.SendCW tested
      // `RadioModel in [K2, K3, K4]`, omitting the KX3 -- so a KX3 was given the
      // KENWOOD spellings and keyed the wrong characters for AR, SK, BT and SN.
      // The KX3 shares the K3's CAT command set (see uRadioElecraftKX3) and
      // CWFrameRuleFor already groups K3/KX3/K4, so the omission is a gap, not a
      // decision.  Unverified on hardware -- NY4I has no KX3.
      K2, K3, KX3, K4:
         begin
         Result := cvElecraft;
         end;
      IC78..IC9700:
         begin
         Result := cvIcom;
         end;
   else
      // Kenwood is the DEFAULT because that is what the legacy code did: the
      // prosign chain lived inside the rtKenwood arm and treated "not Elecraft"
      // as Kenwood.  Radios with no CW-by-CAT at all (the Yaesus) never reach
      // here, so the fall-through costs nothing.
      Result := cvKenwood;
   end;
end;

function CWProsignFor(model: InterfacedRadioType; const token: string): TCWProsign;
var
   vendor: TCWVendor;
begin
   Result.handled := False;
   Result.text := '';
   vendor := CWVendorOf(model);

   // The Icom spellings are NAMED prosigns ('^AR'), not single substitute
   // characters, and Icom has an SN where Elecraft does not -- a third dialect,
   // taken from LOGRADIO.SendCW's rtIcom arm.
   if vendor = cvIcom then
      begin
      if token = '^' then
         begin
         Result.handled := True;
         Result.text := ' ';    // no half space in an Icom CW string either
         end
      else if token = '!' then
         begin
         Result.handled := True;
         Result.text := '^SN';
         end
      else if token = '+' then
         begin
         Result.handled := True;
         Result.text := '^AR';
         end
      else if token = '<' then
         begin
         Result.handled := True;
         Result.text := '^SK';
         end
      else if token = '=' then
         begin
         Result.handled := True;
         Result.text := '^BT';
         end;
      Exit;
      end;

   if token = '^' then
      begin
      // Neither vendor's KY string has a half space; use a whole one.
      Result.handled := True;
      Result.text := ' ';
      end
   else if token = '!' then        // SN
      begin
      Result.handled := True;
      if vendor <> cvElecraft then
         begin
         Result.text := '%';
         end;
      // Elecraft: no SN.  Consumed, keys nothing (legacy behaviour).
      end
   else if token = '+' then        // AR
      begin
      Result.handled := True;
      if vendor = cvElecraft then
         begin
         Result.text := '+';
         end
      else
         begin
         Result.text := '_';
         end;
      end
   else if token = '<' then        // SK
      begin
      Result.handled := True;
      if vendor = cvElecraft then
         begin
         Result.text := '*';
         end
      else
         begin
         Result.text := '>';
         end;
      end
   else if token = '=' then        // BT
      begin
      Result.handled := True;
      if vendor = cvElecraft then
         begin
         Result.text := '=';
         end
      else
         begin
         Result.text := '[';
         end;
      end;

   // NOT handled, deliberately: '&' (AS).  LOGRADIO carried a commented-out arm
   // mapping it to '%' on Elecraft and '<' on Kenwood, disabled because in TR4W
   // '&' is really MYSTATE and only documented as AS.  Recorded here so the
   // spellings are not lost if AS is ever given its own token; do not enable it
   // without deciding what '&' means first.
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
