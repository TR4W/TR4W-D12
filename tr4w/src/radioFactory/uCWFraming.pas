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
  HOW A CW-BY-CAT MESSAGE IS CUT UP -- chunking and padding, and nothing else.

  This unit knows no radio.  It cannot name a vendor, a command or a protocol,
  and that is the point: everything specific to a radio belongs in the radio
  factory, on the class for that radio.  What is left here is string arithmetic
  -- given a length limit, cut a message into pieces -- which is the same
  operation whatever is being fed.

  WHAT USED TO BE HERE, and where it went:

    * `case model of` tables for the frame rule and the prosign dialect.  Those
      are per-radio DATA and could not describe a string-id radio at all (its
      RadioModel is NoInterfacedRadio by design), so TCI was framed as a
      no-limit radio no matter what it accepted.  -> TRadioCapabilities.CWFrame
      and .CWProsigns, declared by each radio (2026-08-03 / 2026-08-04).

    * `CWKYCommand`, which built 'KY <text>;'.  A radio command in a unit that
      is not supposed to know what a radio is.  -> uRadioKYBase.TKYRadio, the
      base for the five drivers that speak it.

    * `ElecraftProsign` / `KenwoodProsign` / `IcomProsign`.  Same problem in
      more obvious form: a Yaesu gaining CW-by-CAT would have meant adding a
      YaesuProsign here.  -> declared by the family base that speaks each
      grammar (uRadioElecraftBase, uRadioKenwoodBase, uRadioIcomBase), and
      stated directly by the radios that share no grammar with anyone.

  The rule those three moves follow: if a change to ONE radio would edit a
  shared unit, the design is wrong.
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

implementation

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
