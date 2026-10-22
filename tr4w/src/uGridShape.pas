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

  PURE: no globals, no logging. *)
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

implementation

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
