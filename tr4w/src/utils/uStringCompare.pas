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
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uStringCompare;
{$I ..\tr4w.inc}

(* THE SORT-KEY COMPARATOR, IN ONE PLACE.

  WHY THIS UNIT EXISTS. `CompareStrings` is written THREE times in this tree,
  once inside each of the hand-maintained sorted arrays, and the copies have
  already drifted:

    uSortedStringList  TSortedStringList  SysUtils.CompareText   ordinal, case-INSENSITIVE
    uCallsigns         TCallsignsList     Win32 CompareStringA   linguistic, case-INSENSITIVE
    uSpots             TDXSpotsList       hand-rolled Ord() loop ordinal, case-SENSITIVE

  Each is the ordering key for a binary search over its own array, and each
  class uses its own copy for BOTH insertion and lookup -- so each is
  self-consistent today, and the drift is invisible. That is exactly the shape
  CLAUDE.md warns about: "copies drift, and the drift is invisible."

  THE REPOINT IS DELIBERATELY NOT DONE YET (NY4I, 2026-09-07): "Save repointing
  it for now and ensure we have unit tests for every case to check the refactor
  for when it's done."

  So this unit is the DESTINATION, tested exhaustively before anything moves.
  `uSortedStringList` is repointed here now because that is a no-op -- it
  already called CompareText -- which gives the unit a live caller rather than
  leaving it as untested scaffolding. The other two move later:

    uCallsigns  is a straight swap to CompareKeyIgnoreCase. Its Win32 call is
                LOCALE-DEPENDENT (LOCALE_SYSTEM_DEFAULT), so the same callsign
                list can order differently on two operators' machines. That is
                a defect, not a behaviour to preserve.
    uSpots      is NOT a straight swap: it is case-SENSITIVE. Repointing it to
                CompareKeyIgnoreCase changes spot ordering, which is a decision
                about behaviour and NY4I's to make. CompareKey is here so that
                the decision is a choice between two tested functions rather
                than a rewrite.

  ORDINAL, NOT LINGUISTIC, AND THAT IS THE POINT. These keys are callsigns,
  prefixes and multiplier abbreviations -- A-Z, 0-9 and '/'. An ordinal compare
  gives the same answer on every machine; the Win32 linguistic one gives the
  answer the operator's locale happens to prefer. A log is a record, and a
  record should not sort differently depending on who opens it.

  For that alphabet the two orders agree anyway: ordinal puts '/' (47) before
  the digits (48-57) before the letters (65-90), and the Windows word sort
  orders that set the same way and does not treat '/' as ignorable.

  THE RETURN VALUE IS A SIGN, NOT A DIFFERENCE. Negative, zero or positive --
  the magnitude carries no meaning and callers must not read one into it. All
  three existing copies happen to return -1/0/1, so that is what these return;
  the contract is only the sign. *)

interface

(* Case-INSENSITIVE ordinal compare. What TSortedStringList uses, and what
  TCallsignsList should use. *)
function CompareKeyIgnoreCase(const s1, s2: ShortString): integer;

(* Case-SENSITIVE ordinal compare. What TDXSpotsList does by hand today. *)
function CompareKey(const s1, s2: ShortString): integer;

implementation

uses
   SysUtils;   (* CompareText / CompareStr -- both ordinal, both portable *)

(* Sign, not difference: CompareText's magnitude is unspecified and differs
  between FPC versions and platforms, so it is normalised here rather than
  leaking to a caller that might subtract or index with it. *)
function Sign(aValue: integer): integer;
begin
   if aValue < 0 then
      begin
      Result := -1;
      end
   else if aValue > 0 then
      begin
      Result := 1;
      end
   else
      begin
      Result := 0;
      end;
end;

function CompareKeyIgnoreCase(const s1, s2: ShortString): integer;
begin
   Result := Sign(CompareText(s1, s2));
end;

function CompareKey(const s1, s2: ShortString): integer;
begin
   Result := Sign(CompareStr(s1, s2));
end;

end.
