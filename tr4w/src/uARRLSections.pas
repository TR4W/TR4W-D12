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

(* WHICH STATE OR PROVINCE AN ARRL SECTION IS IN -- a leaf, lifted at M4
  (2026-10-01).

  WHY A LEAF. The Field Day classes write ADIF STATE from the worked station's
  section, and a contest class reads no TRDOS unit (design 1.3: "a TRDOS
  helper is lifted before a class may call it"). The answer lived in TWO
  layered copies: PostUnit.GetStateFromSection (the modern section names --
  EMA, ENY, NFL, the Canadian sections) falling back to
  Tree.GetStateFromSection (the plain states and the older two-letter names
  -- EM, EN, NF). Nothing else called either. Both are here now as one
  function, in their original order, and both originals are deleted.

  PURE: no globals, no logging, and the same answer for the same section. The
  case is folded first, as both copies did. *)
unit uARRLSections;

{$I tr4w.inc}

interface

(* The two-letter state or province code for an ARRL/RAC section, or '' when
  the section is not one this table knows. A section that is already a state
  (KS, OH) answers itself. *)
function StateFromARRLSection(const aSection: string): string;

implementation

uses
   SysUtils;

const
   (* THE SECTIONS WHOSE STATE IS NOT THEIR OWN NAME, in PostUnit's order --
      the index is what the case below reads, so the order is load-bearing. *)
   NAMED_SECTIONS: array[0 .. 32] of string =
      ('EMA', 'WMA',                       (* 0..1 *)
       'ENY', 'NLI', 'NNY', 'WNY',         (* 2..5 *)
       'NNJ', 'SNJ',                       (* 6..7 *)
       'EPA', 'WPA',                       (* 8..9 *)
       'NFL', 'SFL', 'WCF',                (* 10..12 *)
       'NTX', 'WTX', 'STX', 'EB', 'LAX', 'ORG', 'SB', 'SCV', 'SDG', 'SF',
       'SJV', 'SV', 'PAC', 'EWA', 'WWA', 'GTA', 'ONE', 'ONN', 'ONS',
       'MAR');

(* Index of aSection in NAMED_SECTIONS, -1 when it is not there. The case is
   folded first, as AnsiIndexText did -- a native string compare rather than
   StrUtils', whose AnsiString parameters narrowed every call. *)
function NamedSectionIndex(const aSection: string): integer;
var
   section: string;
   i: integer;
begin
   Result := -1;
   section := UpperCase(aSection);
   for i := Low(NAMED_SECTIONS) to High(NAMED_SECTIONS) do
      begin
      if NAMED_SECTIONS[i] = section then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

(* Tree.GetStateFromSection, moved verbatim but for its ShortString
  parameter: every section it compares is three characters or fewer, so the
  Str20 truncation it applied could never change an answer. *)
function StateFromPlainSection(const aSection: string): string;
var
   section: string;
begin
   section := UpperCase(aSection);

   if (section = 'AK') or (section = 'AL') or (section = 'AR') or
      (section = 'AZ') or (section = 'CO') or (section = 'CT') or
      (section = 'DE') or (section = 'GA') or (section = 'IA') or
      (section = 'ID') or (section = 'IN') or (section = 'IL') or
      (section = 'KS') or (section = 'KY') or (section = 'LA') or
      (section = 'ME') or (section = 'MI') or (section = 'MN') or
      (section = 'MO') or (section = 'MS') or (section = 'MT') or
      (section = 'NC') or (section = 'ND') or (section = 'NE') or
      (section = 'NH') or (section = 'NM') or (section = 'NV') or
      (section = 'OH') or (section = 'OK') or (section = 'OR') or
      (section = 'RI') or (section = 'SD') or (section = 'TN') or
      (section = 'UT') or (section = 'VA') or (section = 'VT') or
      (section = 'WI') or (section = 'WV') or (section = 'WY') or
      (section = 'SC') then
      begin
      Result := section;
      Exit;
      end;

   if (section = 'EB') or (section = 'LAX') or (section = 'ORG') or
      (section = 'SB') or (section = 'SCV') or (section = 'SDG') or
      (section = 'SF') or (section = 'SJV') or (section = 'SV') then
      begin
      Result := 'CA';
      Exit;
      end;

   if (section = 'EM') or (section = 'WM') then
      begin
      Result := 'MA';
      Exit;
      end;

   if (section = 'EN') or (section = 'WNY') or (section = 'NNY') or
      (section = 'ENY') or (section = 'NLI') then
      begin
      Result := 'NY';
      Exit;
      end;

   if (section = 'EP') or (section = 'WP') then
      begin
      Result := 'PA';
      Exit;
      end;

   if (section = 'EW') or (section = 'WWA') or (section = 'EWA') then
      begin
      Result := 'WA';
      Exit;
      end;

   (* 'SF' never arrives here -- the California test above takes it first.
      Kept, as Tree had it (ny4i 4.44.9). *)
   if (section = 'NF') or (section = 'SF') or (section = 'WCF') then
      begin
      Result := 'FL';
      Exit;
      end;

   if (section = 'NNJ') or (section = 'SNJ') then
      begin
      Result := 'NJ';
      Exit;
      end;

   if (section = 'NTX') or (section = 'STX') or (section = 'WTX') then
      begin
      Result := 'TX';
      Exit;
      end;

   Result := '';
end;

function StateFromARRLSection(const aSection: string): string;
begin
   (* PostUnit.GetStateFromSection, moved but for its two debug log lines and
      its AnsiIndexText lookup (NamedSectionIndex: the same table, the same
      case folding). The sections whose state is not their own name, then the
      plain table for everything else. *)
   case NamedSectionIndex(aSection) of
      0 .. 1:
         begin
         Result := 'MA';
         end;
      2 .. 5:
         begin
         Result := 'NY';
         end;
      6 .. 7:
         begin
         Result := 'NJ';
         end;
      8 .. 9:
         begin
         Result := 'PA';
         end;
      10 .. 12:
         begin
         Result := 'FL';
         end;
      13 .. 15:
         begin
         Result := 'TX';
         end;
      16 .. 24:
         begin
         Result := 'CA';
         end;
      25:
         begin
         Result := 'HI';
         end;
      26 .. 27:
         begin
         Result := 'WA';
         end;
      28 .. 31:
         begin
         Result := 'ON';
         end;
      32:
         begin
         Result := 'NS';
         end;
      else
         begin
         Result := StateFromPlainSection(aSection);
         end;
   end;
end;

end.
