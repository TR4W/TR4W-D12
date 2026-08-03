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
  TRadioCapabilities.CWFrame / .CWProsignDialect, declared by the family base and
  overridden per model -- the same place CWSpeedMin/Max already lived.  The
  per-radio COMMENTS moved with the data; look in the driver, not here.

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
   // Which CW dialect a radio speaks.  DECLARED BY THE RADIO
   // (TRadioCapabilities.CWProsignDialect).  Three real ones, not two: Elecraft and
   // Kenwood substitute a single character per prosign but disagree on which,
   // and Icom uses NAMED prosigns ('^AR').
   //
   // pdNone is the fourth, and it is not a dialect: it means "this radio's CW
   // grammar is not one of the three, so do not substitute anything".  Every
   // token then passes through as literal text.  TCI uses it -- its cw_macros
   // takes plain text and nobody has established what it does with a prosign,
   // so keying a Kenwood '_' at it would be a guess dressed up as a fact.
   TCWProsignDialect = (pdNone, pdElecraft, pdKenwood, pdIcom);

   // What a radio should key for one of TR4W's prosign tokens.
   TCWProsign = record
      handled: boolean;   // True: this token IS a prosign; do not treat it as text
      text: string;       // what to append ('' = token consumed, key nothing)
   end;

// Translate one TR4W prosign token into a dialect.  The tokens are TR4W's own
// notation (^ half-space, ! SN, + AR, < SK, = BT); Elecraft and Kenwood spell
// the same prosigns with different characters in a KY string.
//
// `handled` and `text` are separate on purpose: Elecraft has no SN, so '!' is
// consumed and keys NOTHING -- which is not the same as an unrecognised token
// the caller should pass through as literal text.
function CWProsignFor(dialect: TCWProsignDialect; const token: string): TCWProsign;

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

function CWProsignFor(dialect: TCWProsignDialect; const token: string): TCWProsign;
begin
   Result.handled := False;
   Result.text := '';

   // pdNone: an unclassified CW grammar.  Substituting a Kenwood or Elecraft
   // character here would be inventing a fact about the radio, so every token
   // falls through unhandled and the caller keys it literally.
   if dialect = pdNone then
      begin
      Exit;
      end;

   // The Icom spellings are NAMED prosigns ('^AR'), not single substitute
   // characters, and Icom has an SN where Elecraft does not -- a third dialect,
   // taken from LOGRADIO.SendCW's rtIcom arm.
   if dialect = pdIcom then
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
      // Neither dialect's KY string has a half space; use a whole one.
      Result.handled := True;
      Result.text := ' ';
      end
   else if token = '!' then        // SN
      begin
      Result.handled := True;
      if dialect <> pdElecraft then
         begin
         Result.text := '%';
         end;
      // Elecraft: no SN.  Consumed, keys nothing (legacy behaviour).
      end
   else if token = '+' then        // AR
      begin
      Result.handled := True;
      if dialect = pdElecraft then
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
      if dialect = pdElecraft then
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
      if dialect = pdElecraft then
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
