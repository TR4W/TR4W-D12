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
  HOW A CW-BY-CAT MESSAGE IS CUT UP -- the chunking and padding MECHANISM, and
  the prosign spellings for each CW dialect.

  WHAT IS NOT HERE ANY MORE.  Until 2026-08-03 this unit also held two tables
  keyed on InterfacedRadioType: which frame rule each model wants, and which
  dialect each model speaks.  Those are per-radio DATA, and a table keyed on the
  enum cannot describe a string-id factory radio at all (its RadioModel is
  NoInterfacedRadio by design), so TCI was framed as a no-limit radio no matter
  what it actually accepts.  The data now lives on the radio object, in
  TRadioCapabilities.CWFrame, declared by the family base and overridden per
  model -- the same place CWSpeedMin/Max already lived.  The per-radio COMMENTS
  moved with the data; look in the driver, not here.

  The prosign dialect followed on 2026-08-04 and went one step further: it is
  not a capability FIELD either, but a method the radio answers
  (TFactoryRadioBase.CWProsign).  An enum naming the dialect was still the model
  table in disguise, and the groups do not match the class graph anyway -- five
  unrelated classes speak the Kenwood spellings.  The spellings stay here as
  three pure functions; the CHOICE belongs to the radio.

  What remains is the mechanism, which is genuinely shared: given a rule, cut a
  string up; given a dialect, spell a prosign.  It is pure string manipulation
  -- no port, no radio, no timing -- so it stays unit-testable offline
  (uTestCWFraming), and it no longer needs to know what a radio model is.

  Nothing here talks to a radio.  Deciding WHETHER to send, and actually
  sending, stay with the caller.
}

interface

type
   // What one radio needs done to a CW message before it goes out.  DECLARED BY
   // THE RADIO (TRadioCapabilities.CWFrame), not looked up by model.
   TCWFrameRule = record
      maxLen: integer;    // longest text the radio accepts in one command; 0 = no limit
      pad: boolean;       // pad the last chunk out to maxLen with spaces?
      // Safety factor on the CW-busy window (tmrCWByCAT).  The window is an
      // ESTIMATE -- elements x dot time -- and if it expires early the poll
      // thread resumes and can step on CW still being keyed.  1.0 for the KY
      // radios and 1.25 for Icom, whose rate-limited CI-V send queue makes the
      // estimate optimistic.  Per-radio data, so it travels with the rest.
      busyFactor: double;
   end;

// Reads as CWFrameRule(24, True) at each declaration.  busyFactor defaults to
// 1.0 because only the Icom family needs anything else.
//
// A radio that declares NOTHING gets maxLen 0 -- "send it whole" -- which is
// also what a zeroed record gives.  That is deliberate for the radios with no
// CW-by-CAT at all, but it is the trap to watch on the ones that DO key: a
// family base that forgets to declare its rule compiles clean and silently
// stops chunking.  test/unit/uTestCWFraming pins every keying radio's rule for
// exactly that reason.
function CWFrameRule(maxLen: integer; pad: boolean;
                     busyFactor: double = 1.0): TCWFrameRule;

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
   // What a radio should key for one of TR4W's prosign tokens.
   TCWProsign = record
      handled: boolean;   // True: this token IS a prosign; do not treat it as text
      text: string;       // what to append ('' = token consumed, key nothing)
   end;

{
  THE SPELLINGS, and who chooses between them.

  TR4W's own notation for the prosigns is ^ half space, ! SN, + AR, < SK, = BT
  (see TC_CWMENU).  Each of the three CW grammars below spells those differently.

  WHICH ONE A RADIO SPEAKS IS THE RADIO'S ANSWER, not a lookup here: every
  driver overrides TFactoryRadioBase.CWProsign and delegates to the function it
  speaks.  A `TCWProsignDialect` enum used to live here and this unit switched
  on it -- which was the last model-keyed table in a unit whose whole point is
  that it does not know what a radio is.  The functions stay because the
  SPELLINGS are genuinely shared: five unrelated classes speak the Kenwood one
  (Kenwood serial and LAN, Flex CAT and API, TenTec Orion), and one definition
  beats five copies.

  `handled` and `text` are separate on purpose: Elecraft has no SN, so '!' is
  consumed and keys NOTHING -- which is not the same as an unrecognised token
  the caller should pass through as literal text.
}

// Elecraft KY grammar: one substitute character per prosign.
function ElecraftProsign(const token: string): TCWProsign;

// Kenwood KY grammar: same idea, different characters.  Shared by Kenwood,
// Flex-over-CAT, Flex API and the TenTec Orion.
function KenwoodProsign(const token: string): TCWProsign;

// Icom $17 grammar, which is NOT a prosign alphabet at all.
//
// The radio takes plain ASCII (the table in the manual is 20, 27-3F, 41-7A) plus
// ONE modifier: '^' (0x5E) means "send the following characters with no
// inter-character space".  So '^SK' is not a named prosign -- it is the letters
// S and K keyed run together, which IS the SK prosign.  Same for ^AR, ^BT, ^SN.
//
// This matters beyond wording: the substitute characters the other two grammars
// use -- % _ * > [ -- are all OUTSIDE the set Icom documents for this command,
// so an Icom sharing either of those spellings would be sent bytes it has no
// meaning for.
function IcomProsign(const token: string): TCWProsign;

// The Kenwood-protocol KY command carrying one chunk of CW text.  Identical on
// Elecraft, Kenwood and Flex-over-CAT, which is why it lives here instead of
// being written out in each of those three drivers.
//
// `immediate` selects the KYW form, which IS documented (K3 command reference,
// KY): the SET format is KY*[text] where * is normally a blank, and a 'W' there
// means WAIT -- processing of any following host commands is delayed until the
// current message has been sent.  LOGRADIO used it when a speed change
// (Ctrl-F / Ctrl-S) forced the buffer out mid-message, which is consistent: the
// KS that follows must not be acted on until the text has gone.
//
// (An earlier version of this comment said KYW was undocumented.  It is not --
// NY4I supplied the manual page 2026-08-01.)
function CWKYCommand(const text: string; immediate: boolean): string;

implementation

uses
   Math;

function CWFrameRule(maxLen: integer; pad: boolean;
                     busyFactor: double = 1.0): TCWFrameRule;
begin
   Result.maxLen := maxLen;
   Result.pad := pad;
   Result.busyFactor := busyFactor;
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

function ElecraftProsign(const token: string): TCWProsign;
begin
   Result.handled := True;
   if token = '^' then
      begin
      Result.text := ' ';    // no half space in a KY string; use a whole one
      end
   else if token = '!' then
      begin
      Result.text := '';     // Elecraft has no SN: consumed, keys nothing
      end
   else if token = '+' then
      begin
      Result.text := '+';    // AR
      end
   else if token = '<' then
      begin
      Result.text := '*';    // SK
      end
   else if token = '=' then
      begin
      Result.text := '=';    // BT
      end
   else
      begin
      Result.handled := False;
      Result.text := '';
      end;
end;

function KenwoodProsign(const token: string): TCWProsign;
begin
   Result.handled := True;
   if token = '^' then
      begin
      Result.text := ' ';    // no half space in a KY string; use a whole one
      end
   else if token = '!' then
      begin
      Result.text := '%';    // SN
      end
   else if token = '+' then
      begin
      Result.text := '_';    // AR
      end
   else if token = '<' then
      begin
      Result.text := '>';    // SK
      end
   else if token = '=' then
      begin
      Result.text := '[';    // BT
      end
   else
      begin
      Result.handled := False;
      Result.text := '';
      end;
end;

function IcomProsign(const token: string): TCWProsign;
begin
   Result.handled := True;
   if token = '^' then
      begin
      // TR4W's '^' is a HALF space; Icom's '^' is the no-inter-character-space
      // modifier, a different thing entirely.  There is no half space in the
      // Icom character set, so key a whole one -- and do NOT pass '^' through,
      // which would run the next two characters together.
      Result.text := ' ';
      end
   else if token = '!' then
      begin
      Result.text := '^SN';
      end
   else if token = '+' then
      begin
      Result.text := '^AR';
      end
   else if token = '<' then
      begin
      Result.text := '^SK';
      end
   else if token = '=' then
      begin
      Result.text := '^BT';
      end
   else
      begin
      Result.handled := False;
      Result.text := '';
      end;
end;

// NOT handled by any of the three, deliberately: '&' (AS).  LOGRADIO carried a
// commented-out arm mapping it to '%' on Elecraft and '<' on Kenwood, disabled
// because in TR4W '&' is really MYSTATE and only documented as AS.  Recorded
// here so the spellings are not lost if AS is ever given its own token; do not
// enable it without deciding what '&' means first.

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
