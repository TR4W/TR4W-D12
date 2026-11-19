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

(* DOES THIS TEXT LOOK LIKE A MAIDENHEAD GRID? -- a leaf, lifted from Tree on
  2026-10-13 when POTA gained its class (design Q6, section 6).

  WHY A LEAF. Tree.LooksLikeAGrid asked two questions in one function and
  read a global for the first: does the SESSION's exchange carry a grid at
  all (ActiveExchange), and does this text have a grid's shape. A contest
  class reads no global and no TRDOS unit, so TContestPOTA, whose ADIF export
  writes GRIDSQUARE for a hunter who sent one, could not ask it. The two
  questions are separate here; the first is the contest's own answer since
  M11 S9e part 1 (TContestBase.ExchangeTextMayHoldGridSquare).

  ONE COPY OF THE SHAPE. Tree's LooksLikeAGrid and LooksLikeAGridIgnoreAE
  each held the same character walk; both call this now and keep only what
  differs -- whether the exchange is asked, and the case fix-up their var
  parameter carries back.

  PURE: no globals, no logging. Its implementation uses utils_text (and so
  VC) since issue 129, for ValChecked in TryParseReportAndGrid -- whose
  UpperCase is therefore utils_text's ASCII one, which is all a grid needs. *)
unit uGridShape;

{$I tr4w.inc}

interface

(* ~~GRID_CARRYING_EXCHANGES~~ stood here -- the exchange SHAPES Tree's
  LooksLikeAGrid asked about before looking at the text. It went at M11
  S9e part 1 (2026-10-15): each contest answers that question itself,
  TContestBase.ExchangeTextMayHoldGridSquare, and the unit test that pins
  it keeps a frozen copy of the set as its cross-check. So this unit no
  longer uses VC. *)

(* Four or six characters: two letters A..R in either case, then two digits.
  What follows the first four in a six-character grid is not examined --
  Tree's test never did. *)
function LooksLikeGridSquare(const aText: string): boolean;

(* IS THIS A GRID SQUARE THE PROGRAM MAY LOG AND MEASURE? -- Q37 (NY4I,
  2026-10-15: "a malformed grid should never have been logged").

  LooksLikeGridSquare, and in a six-character grid characters 5 and 6 are
  letters A..Z in either case. This is Tree.GoodLookingGrid's rule, LIFTED
  here on 2026-10-17 when it gained its second user: the grid exchange
  parsers refuse a typed grid that fails it, and LOGGRID's distance, heading
  and lat/lon refuse to read one -- so "may it be logged" and "may it be
  measured" are one predicate and cannot disagree. Tree.GoodLookingGrid calls
  this. *)
function IsGoodLookingGrid(const aText: string): boolean;

type
   (* Which words a caller takes for a grid -- see TryParseReportAndGrid. *)
   TGridTextTest = function(const aText: string): boolean;

(* "[report] GRID" -- the received exchange of a digital QSO that logs the
  other station's grid (the standard FT8/FT4 exchange). One word, the grid;
  or two, a signed whole-number report that fits a SmallInt, then the grid.
  aIsGrid decides what a grid is, because the callers differ: the Hawaii QSO
  Party takes any two letters and two digits (ZZ00 is its sponsor's "no
  grid"), the South Dakota QSO Party a real square (IsGoodLookingGrid).
  aGrid is the grid word upper-cased; aHasReport says whether a report was
  given. Lifted from uContestHawaiiQP when South Dakota became its second
  user (issue 129, 2026-11-18). *)
function TryParseReportAndGrid(const aText: string; aIsGrid: TGridTextTest;
                               out aGrid: string; out aHasReport: boolean;
                               out aReport: integer): boolean;

(* THE FOUR-CHARACTER GRID SQUARE aText NAMES -- its first four characters,
  upper case, when aText (blanks trimmed) is a grid IsGoodLookingGrid allows
  (four or six characters); '' when it is none. Lifted from
  uContestSouthDakotaQP (SouthDakotaQPGridOf) when the Mississippi QSO Party
  became its second user (issue 123, 2026-11-18): both key their digital grid
  multiplier on the four-character square. *)
function FourCharacterGridSquareOf(const aText: string): string;

implementation

uses
   SysUtils,
   (* ValChecked -- the range-checked text-to-number conversion. *)
   utils_text;

function TryParseReportAndGrid(const aText: string; aIsGrid: TGridTextTest;
                               out aGrid: string; out aHasReport: boolean;
                               out aReport: integer): boolean;
var
   text, first, rest: string;
   blank: integer;
   report: SmallInt;
   code: integer;
begin
   Result := False;
   aGrid := '';
   aHasReport := False;
   aReport := 0;

   text := Trim(aText);
   blank := Pos(' ', text);
   if blank = 0 then
      begin
      first := '';
      rest := text;
      end
   else
      begin
      first := Copy(text, 1, blank - 1);
      rest := Trim(Copy(text, blank + 1, Length(text)));
      end;

   (* Nothing, or a third word. *)
   if (rest = '') or (Pos(' ', rest) > 0) then
      begin
      Exit;
      end;
   if not aIsGrid(rest) then
      begin
      Exit;
      end;

   if first <> '' then
      begin
      (* ValChecked, not TryStrToInt: on Win64 the RTL's conversion is not
         range-checked (CLAUDE.md), so '4294967297' would read as 1. *)
      report := 0;
      code := 0;
      ValChecked(first, report, code);
      if code <> 0 then
         begin
         Exit;
         end;
      aReport := report;
      aHasReport := True;
      end;

   aGrid := UpperCase(rest);
   Result := True;
end;

function FourCharacterGridSquareOf(const aText: string): string;
var
   text: string;
begin
   text := Trim(aText);
   if IsGoodLookingGrid(text) then
      begin
      Result := UpperCase(Copy(text, 1, 4));
      end
   else
      begin
      Result := '';
      end;
end;

function LooksLikeGridSquare(const aText: string): boolean;
var
   i: integer;
   ch: Char;
begin
   Result := False;

   if (Length(aText) <> 4) and (Length(aText) <> 6) then
      begin
      Exit;
      end;

   (* Upper-cased one character at a time, as utils_text.UpperCase did to the
     whole string: ASCII a..z only. *)
   for i := 1 to 2 do
      begin
      ch := aText[i];
      if (ch >= 'a') and (ch <= 'z') then
         begin
         ch := Char(Ord(ch) - 32);
         end;
      if (ch < 'A') or (ch > 'R') then
         begin
         Exit;
         end;
      end;

   for i := 3 to 4 do
      begin
      if (aText[i] < '0') or (aText[i] > '9') then
         begin
         Exit;
         end;
      end;

   Result := True;
end;

function IsGoodLookingGrid(const aText: string): boolean;
var
   i: integer;
   ch: Char;
begin
   Result := LooksLikeGridSquare(aText);
   if (not Result) or (Length(aText) <> 6) then
      begin
      Exit;
      end;

   for i := 5 to 6 do
      begin
      ch := aText[i];
      if (ch >= 'a') and (ch <= 'z') then
         begin
         ch := Char(Ord(ch) - 32);
         end;
      if (ch < 'A') or (ch > 'Z') then
         begin
         Result := False;
         Exit;
         end;
      end;
end;

end.
