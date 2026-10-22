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

(* THE DOMESTIC-QTH SHAPES MORE THAN ONE CONTEST READS -- HELPERS, NOT A
  RULE. M11 S6 part 1, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S6).

  Each contest's domestic multiplier is its class's own rule now
  (TContestBase.DomesticMultiplierFromQTH and DomesticMultiplierHint).
  Until S6 the rule was two copies of one `if ContestSession.DomesticMult =`
  ladder -- LOGDOM.GetDomQTH for a received QTH and LOGSTUFF.DomStringParse
  for the need-multiplier hint (plan F6) -- choosing a shape FOR the
  contest. What is left here is the shapes several sponsors happen to
  share: an RDA district (RDA, the ALRS cup), a DOK (WAG, the DARC 10 m), a
  grid square (the six VHF contests) and a grid field (five contests). The
  design's definition of a helper (CONTEST_OWNERSHIP_DESIGN.md 1.3):
  called BY the class's own code, never selected for it, and holding no
  rule identity.

  EACH BODY IS ITS ARM'S TEST, AS IT STOOD -- in both copies, which agreed
  on every one of these four. Each answers whether the text has the shape,
  and the key it gives when it does; what a contest does with "no" is the
  contest's (GetDomQTH's DOK arm kept the QTH, its grid arms did not), so
  the class's own code says so.

  F6 IS NOT FIXED HERE. The two copies differed in control flow, not in
  these tests: GetDomQTH's IOTA arm falls through to the domestic file and
  DomStringParse's DOK arm returns an unassigned local. Both are
  transcribed where they stood -- the RSGB IOTA's and the DOK contests'
  classes -- and recorded there.

  WHAT IS DELIBERATELY NOT A HELPER. WYSIWYG (the text is the key) and the
  IOTA reference (the RSGB IOTA's alone): a helper would hold nothing but
  one contest's choice (design 1.3, 1.4). *)
unit uDomesticKey;

{$I tr4w.inc}

interface

(* AN RDA DISTRICT -- two letters, two digits, exactly ('MO12'). The key is
   the text. *)
function RDADistrictKey(const aText: ShortString; out aKey: ShortString): boolean;

(* A DOK -- the key is the text's FIRST LETTER ('B01' gives 'B'). False, aKey
   empty, when the text has no letter. *)
function DOKKey(const aText: ShortString; out aKey: ShortString): boolean;

(* A GRID SQUARE -- four or six characters, field letters A..R, square
   digits, and for six a subsquare of any two letters. The key is the
   four-character square ('FN20AB' gives 'FN20'). *)
function GridSquareKey(const aText: ShortString; out aKey: ShortString): boolean;

(* A GRID FIELD -- a four-character grid square, exactly. The key is its
   two-letter field ('FN20' gives 'FN'). *)
function GridFieldKey(const aText: ShortString; out aKey: ShortString): boolean;

implementation

(* A field letter, A..R, and a square digit -- the arms' own two tests. *)
function IsFieldLetter(aChar: AnsiChar): boolean;
begin
   Result := (aChar >= 'A') and (aChar <= 'R');
end;

function IsSquareDigit(aChar: AnsiChar): boolean;
begin
   Result := (aChar >= '0') and (aChar <= '9');
end;

(* THE FOUR CHARACTERS OF A GRID SQUARE -- both grid arms opened with this
   test, written out once in each. *)
function HasGridSquareHead(const aText: ShortString): boolean;
begin
   Result := IsFieldLetter(aText[1]) and
             IsFieldLetter(aText[2]) and
             IsSquareDigit(aText[3]) and
             IsSquareDigit(aText[4]);
end;

function RDADistrictKey(const aText: ShortString; out aKey: ShortString): boolean;
begin
   aKey := '';
   Result := False;
   if (Length(aText) = 4)        and
      (aText[1] in ['A'..'Z']) and
      (aText[2] in ['A'..'Z']) and
      (aText[3] in ['0'..'9']) and
      (aText[4] in ['0'..'9'])  then
      begin
      aKey := aText;
      Result := True;
      end;
end;

function DOKKey(const aText: ShortString; out aKey: ShortString): boolean;
var
   index: integer;
begin
   aKey := '';
   for index := 1 to Length(aText) do
      begin
      if aText[index] in ['A'..'Z'] then
         begin
         aKey := Copy(aText, index, 1);
         Break;
         end;
      end;
   Result := aKey <> '';
end;

function GridSquareKey(const aText: ShortString; out aKey: ShortString): boolean;
begin
   aKey := '';
   Result := False;
   if (Length(aText) <> 4) and (Length(aText) <> 6) then
      begin
      Exit;
      end;

   if not HasGridSquareHead(aText) then
      begin
      Exit;
      end;

   if Length(aText) = 6 then
      begin
      if (aText[5] < 'A') or (aText[5] > 'Z') or
         (aText[6] < 'A') or (aText[6] > 'Z') then
         begin
         Exit;
         end;
      end;

   aKey := Copy(aText, 1, 4);
   Result := True;
end;

function GridFieldKey(const aText: ShortString; out aKey: ShortString): boolean;
begin
   aKey := '';
   Result := False;
   if (Length(aText) = 4) and HasGridSquareHead(aText) then
      begin
      aKey := Copy(aText, 1, 2);
      Result := True;
      end;
end;

end.
