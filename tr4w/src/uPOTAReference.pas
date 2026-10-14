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

(* WHAT A POTA EXCHANGE CARRIES, RECOGNISED -- a leaf, lifted 2026-10-13 when
  POTA gained its class (design Q6, section 6).

  WHY A LEAF. TContestPOTA writes its own ADIF and reads its own import, and a
  contest class reads no TRDOS unit (design 1.3: "a TRDOS helper is lifted
  before a class may call it"). The three answers it needs lived there:

    IsValidPOTAPark          LOGSTUFF  -- with the two character tests it
                                          alone used
    ResolvePOTAParkFromADIF  LOGSTUFF  -- D5's fix, 3f9e3f28
    LooksLikeAState          Tree      -- every caller was a POTA site

  Each is moved line for line and its original is deleted; LOGSTUFF's POTA
  exchange shape (ProcessRSTAndPOTAPark) reaches them here too, so there is
  one copy of each. Tree's LooksLikeAPOTAPark, a one-line alias of
  IsValidPOTAPark with PostUnit's two POTA tests as its only callers, is
  deleted with them.

  PURE: no globals, and the same answer for the same text. The ONE change is
  that IsValidPOTAPark no longer writes two debug lines per call -- a leaf
  does not reach the program's logger, and nothing read them.

  THIS IS NOT uPOTAParks. That unit is POTA DATA -- the downloaded park list,
  its threads and the n-fer queue -- and is the engine's. This is the shape of
  a reference, which no list is needed to answer. *)
unit uPOTAReference;

{$I tr4w.inc}

interface

(* Two letters, a hyphen, then four or five digits and nothing else -- 'US-1234',
  'CA-0001', 'us-12345'. Deliberately tight: a park reference and an RST report
  arrive in the same exchange field, so '59' and '599' must not look like
  parks. *)
function IsValidPOTAPark(const park: string): boolean;

(* The park an imported ADIF record names, or '' when it names none.

  POTA_REF wins when it is a valid park.  Failing that, a record written by
  a logger that only knows the generic SIG / SIG_INFO pair carries the park
  there, and it counts only when SIG says POTA -- a WWFF or SOTA reference
  in SIG_INFO is not a park.  The caller falls back to the state otherwise. *)
function ResolvePOTAParkFromADIF(const aPOTARef, aSIG, aSIGInfo: string): string;

(* A US state, DC or a Canadian province, as its two upper-case letters --
  what a POTA hunter sends when he is not in a park. CASE-SENSITIVE, as Tree's
  copy always was: a caller that wants 'pa' to count upper-cases it first. *)
function LooksLikeAState(state: string): boolean;

implementation

uses
   SysUtils;

const
   (* Tree's list, in Tree's order -- TX stood in it twice, which a list
     lookup makes harmless rather than wrong. *)
   STATES_AND_PROVINCES: array[0 .. 64] of string = (
      'CA', 'TX', 'NY', 'FL', 'TX', 'PA', 'MA', 'NJ',
      'WA', 'MD', 'DC',
      'AK', 'AL', 'AR',
      'AZ', 'CO', 'CT',
      'DE', 'GA', 'IA',
      'ID', 'IN', 'IL',
      'KS', 'KY', 'LA',
      'ME', 'MI', 'MN',
      'MO', 'MS', 'MT',
      'NC', 'ND', 'NE',
      'NH', 'NM', 'NV',
      'OH', 'OK', 'OR',
      'RI', 'SD', 'TN',
      'UT', 'VA', 'VT',
      'WI', 'WV', 'WY',
      'SC', 'HI',
      'NS', 'QC', 'ON', 'MB',
      'SK', 'AB', 'BC', 'NT',
      'NB', 'NL', 'YT', 'PE', 'NU');

(* RANGE COMPARISONS, NOT `in ['0'..'9']`: this unit's `string` is a
  UnicodeString, so its elements are WideChar, and a WideChar tested against
  an AnsiChar set is the silent size-mismatch this tree has paid for before.
  (LOGSTUFF's note, moved with the functions.) *)
function IsAsciiDigit(aCh: Char): boolean;
begin
   Result := (aCh >= '0') and (aCh <= '9');
end;

function IsAsciiLetter(aCh: Char): boolean;
begin
   Result := ((aCh >= 'A') and (aCh <= 'Z')) or
             ((aCh >= 'a') and (aCh <= 'z'));
end;

function IsValidPOTAPark(const park: string): boolean;
var
   i: integer;
begin
   Result := False;

   (* Length first, so the character tests below need no bounds checks: 7 is
     the four-digit form and 8 the five-digit one. *)
   if (Length(park) <> 7) and (Length(park) <> 8) then
      begin
      Exit;
      end;

   if not (IsAsciiLetter(park[1]) and IsAsciiLetter(park[2])) then
      begin
      Exit;
      end;

   if park[3] <> '-' then
      begin
      Exit;
      end;

   for i := 4 to Length(park) do
      begin
      if not IsAsciiDigit(park[i]) then
         begin
         Exit;
         end;
      end;

   Result := True;
end;

function ResolvePOTAParkFromADIF(const aPOTARef, aSIG, aSIGInfo: string): string;
begin
   Result := '';

   if IsValidPOTAPark(aPOTARef) then
      begin
      Result := aPOTARef;
      end
   else
      begin
      (* UpperCase, not LOGSTUFF's AnsiUpperCase: the same answer for any
        text that could equal 'POTA' -- no non-ASCII letter upper-cases to
        P, O, T or A -- without narrowing the tag through an AnsiString. *)
      if (UpperCase(aSIG) = 'POTA') and
         (IsValidPOTAPark(aSIGInfo))    then
         begin
         Result := aSIGInfo;
         end;
      end;
end;

function LooksLikeAState(state: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(STATES_AND_PROVINCES) to High(STATES_AND_PROVINCES) do
      begin
      if state = STATES_AND_PROVINCES[i] then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

end.
