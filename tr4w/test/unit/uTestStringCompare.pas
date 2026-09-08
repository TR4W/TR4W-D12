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
unit uTestStringCompare;
{$I ..\..\src\tr4w.inc}

(* THE TESTS THAT HAVE TO EXIST BEFORE THE REPOINT.

  NY4I, 2026-09-07: "Save repointing it for now and ensure we have unit tests
  for every case to check the refactor for when it's done."

  uStringCompare is the destination for THREE hand-written comparators that
  have already drifted -- uSortedStringList's CompareText, uCallsigns' Win32
  CompareStringA, and uSpots' hand-rolled Ord() loop. Each is the ordering key
  for a binary search over its own array and each class uses its own copy for
  BOTH insertion and lookup, so each is self-consistent today and the drift is
  invisible.

  THAT IS WHY THESE TESTS COME FIRST. A comparator change is not visible as a
  wrong answer: it is visible as a binary search that quietly fails to find a
  callsign that is in the list. There is no exception and no log line. The
  only way to make the repoint safe is to pin the ORDER these functions
  produce, exhaustively, over the alphabet the keys actually use.

  WHAT IS DELIBERATELY NOT TESTED HERE: that CompareKeyIgnoreCase agrees with
  Win32's CompareStringA. It does not, in general, and that is the point --
  the Win32 call is locale-dependent, so it gives the operator's local answer
  rather than a fixed one. The tests below pin the ordinal answer, which is
  the same on every machine. See the unit header for the argument. *)

interface

uses
   uTR4WTestFramework;

type
   TStringCompareTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_SignNotDifference;
      procedure Test_IgnoreCase_IsCaseInsensitive;
      procedure Test_CaseSensitive_IsCaseSensitive;
      procedure Test_Empty;
      procedure Test_PrefixSortsBeforeLonger;
      procedure Test_CallsignAlphabetOrdering;
      procedure Test_SlashSortsBeforeDigitsAndLetters;
      procedure Test_Antisymmetry;
      procedure Test_Transitivity;
      procedure Test_RealCallsignsSortStably;
   end;

implementation

uses
   SysUtils,
   uStringCompare;

(* The alphabet these keys are actually drawn from: callsigns, prefixes and
  multiplier abbreviations. Ordering only has to be right and STABLE over
  this set -- the unit header explains why it is ordinal and not linguistic. *)
const
   KEY_ALPHABET = '/0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

procedure TStringCompareTests.RunAllTests;
begin
   Test_SignNotDifference;
   Test_IgnoreCase_IsCaseInsensitive;
   Test_CaseSensitive_IsCaseSensitive;
   Test_Empty;
   Test_PrefixSortsBeforeLonger;
   Test_CallsignAlphabetOrdering;
   Test_SlashSortsBeforeDigitsAndLetters;
   Test_Antisymmetry;
   Test_Transitivity;
   Test_RealCallsignsSortStably;
end;

// ---------------------------------------------------------------------------
// The contract: a SIGN, never a difference.
//
// All three comparators being replaced happen to return -1/0/1, and a caller
// that subtracted or indexed with the result would keep working by accident.
// CompareText's own magnitude is unspecified and differs between FPC versions,
// so this pins the normalisation rather than the accident.
// ---------------------------------------------------------------------------

procedure TStringCompareTests.Test_SignNotDifference;
begin
   BeginTest('Test_SignNotDifference');

   { 'A' and 'Z' are 25 apart. A comparator returning the DIFFERENCE would say
     -25 here, and that is exactly the shape a caller must not come to rely
     on. }
   CheckEquals(-1, CompareKeyIgnoreCase('A', 'Z'), 'far apart still returns -1');
   CheckEquals(1, CompareKeyIgnoreCase('Z', 'A'), 'and 1 the other way');
   CheckEquals(-1, CompareKey('A', 'Z'), 'case-sensitive: -1');
   CheckEquals(1, CompareKey('Z', 'A'), 'case-sensitive: 1');

   CheckEquals(0, CompareKeyIgnoreCase('K4XYZ', 'K4XYZ'), 'equal is 0');
   CheckEquals(0, CompareKey('K4XYZ', 'K4XYZ'), 'equal is 0, case-sensitive');
end;

procedure TStringCompareTests.Test_IgnoreCase_IsCaseInsensitive;
begin
   BeginTest('Test_IgnoreCase_IsCaseInsensitive');

   CheckEquals(0, CompareKeyIgnoreCase('ny4i', 'NY4I'), 'lower = upper');
   CheckEquals(0, CompareKeyIgnoreCase('Ny4I', 'nY4i'), 'mixed = mixed');

   { The one that matters for a callsign list: case must not change ORDER, or
     an entry inserted as 'k4abc' becomes unfindable as 'K4ABC'. }
   CheckEquals(CompareKeyIgnoreCase('K4ABC', 'K4ABD'),
               CompareKeyIgnoreCase('k4abc', 'K4ABD'),
               'case does not change the ordering of two different keys');
end;

procedure TStringCompareTests.Test_CaseSensitive_IsCaseSensitive;
begin
   BeginTest('Test_CaseSensitive_IsCaseSensitive');

   { uSpots' comparator is case-SENSITIVE, which is why repointing it is a
     DECISION and not a swap. This pins that the two functions genuinely
     differ, so nobody can substitute one for the other by accident. }
   CheckTrue(CompareKey('ny4i', 'NY4I') <> 0,
             'case-sensitive: lower and upper are NOT equal');
   CheckEquals(0, CompareKeyIgnoreCase('ny4i', 'NY4I'),
               'and the insensitive one says they are -- the two differ');

   { ASCII puts every upper-case letter before every lower-case one. }
   CheckEquals(1, CompareKey('a', 'A'), 'lower sorts after upper');
end;

procedure TStringCompareTests.Test_Empty;
begin
   BeginTest('Test_Empty');

   CheckEquals(0, CompareKeyIgnoreCase('', ''), 'empty = empty');
   CheckEquals(0, CompareKey('', ''), 'empty = empty, case-sensitive');
   CheckEquals(-1, CompareKeyIgnoreCase('', 'A'), 'empty sorts first');
   CheckEquals(1, CompareKeyIgnoreCase('A', ''), 'and the reverse');
   CheckEquals(-1, CompareKey('', 'A'), 'case-sensitive: empty sorts first');
end;

procedure TStringCompareTests.Test_PrefixSortsBeforeLonger;
begin
   BeginTest('Test_PrefixSortsBeforeLonger');

   { A binary search over prefixes depends on this: 'K4' must sort before
     'K4A', or a prefix lookup walks past its own entry. }
   CheckEquals(-1, CompareKeyIgnoreCase('K4', 'K4A'), 'prefix before longer');
   CheckEquals(1, CompareKeyIgnoreCase('K4A', 'K4'), 'and the reverse');
   CheckEquals(-1, CompareKey('K4', 'K4A'), 'case-sensitive too');
end;

procedure TStringCompareTests.Test_CallsignAlphabetOrdering;
var
   i:    integer;
   a, b: ShortString;
begin
   BeginTest('Test_CallsignAlphabetOrdering');

   { EVERY ADJACENT PAIR in the alphabet these keys use, in both directions.
     This is the exhaustive part NY4I asked for: if the repoint ever changes
     the relative order of two characters, one of these fails. }
   for i := 1 to Length(KEY_ALPHABET) - 1 do
      begin
      a := KEY_ALPHABET[i];
      b := KEY_ALPHABET[i + 1];
      CheckEquals(-1, CompareKeyIgnoreCase(a, b),
                  Format('%s sorts before %s', [a, b]));
      CheckEquals(1, CompareKeyIgnoreCase(b, a),
                  Format('%s sorts after %s', [b, a]));
      CheckEquals(-1, CompareKey(a, b),
                  Format('%s before %s (case-sensitive)', [a, b]));
      end;
end;

procedure TStringCompareTests.Test_SlashSortsBeforeDigitsAndLetters;
begin
   BeginTest('Test_SlashSortsBeforeDigitsAndLetters');

   { '/' is 47, the digits are 48-57, the letters 65-90. The unit header
     claims the Windows word sort agrees with ordinal on this set AND does not
     treat '/' as ignorable -- these pin our half of that claim, which is the
     half we control. }
   CheckEquals(-1, CompareKeyIgnoreCase('/', '0'), 'slash before digits');
   CheckEquals(-1, CompareKeyIgnoreCase('/', 'A'), 'slash before letters');
   CheckEquals(-1, CompareKeyIgnoreCase('9', 'A'), 'digits before letters');

   { A portable callsign is where this bites: DL/NY4I and DL0NY4I must have a
     defined, stable relative order. }
   CheckEquals(-1, CompareKeyIgnoreCase('DL/NY4I', 'DL0NY4I'),
               'the slash form sorts before the digit form');
end;

procedure TStringCompareTests.Test_Antisymmetry;
const
   SAMPLES: array[0..7] of ShortString =
      ('', 'A', 'K4', 'K4ABC', 'NY4I', 'DL/NY4I', 'W1AW/4', '9A1A');
var
   i, j, r: integer;
begin
   BeginTest('Test_Antisymmetry');

   { compare(a,b) = -compare(b,a), for every pair. A comparator that violates
     this makes a binary search's behaviour depend on insertion order, which
     is the kind of bug that shows up as one missing callsign months later. }
   for i := Low(SAMPLES) to High(SAMPLES) do
      begin
      for j := Low(SAMPLES) to High(SAMPLES) do
         begin
         r := CompareKeyIgnoreCase(SAMPLES[i], SAMPLES[j]);
         CheckEquals(-r, CompareKeyIgnoreCase(SAMPLES[j], SAMPLES[i]),
                     Format('antisymmetry: %s vs %s',
                            [SAMPLES[i], SAMPLES[j]]));
         r := CompareKey(SAMPLES[i], SAMPLES[j]);
         CheckEquals(-r, CompareKey(SAMPLES[j], SAMPLES[i]),
                     Format('antisymmetry (case-sensitive): %s vs %s',
                            [SAMPLES[i], SAMPLES[j]]));
         end;
      end;
end;

procedure TStringCompareTests.Test_Transitivity;
const
   SAMPLES: array[0..7] of ShortString =
      ('', '/', '0', '9', 'A', 'K4ABC', 'NY4I', 'ZZ9ZZ');
var
   i, j, k: integer;
begin
   BeginTest('Test_Transitivity');

   { a < b and b < c implies a < c. Sorted-array insertion is only correct if
     the comparator is a total order; this is the property a hand-rolled loop
     is most likely to break. }
   for i := Low(SAMPLES) to High(SAMPLES) do
      begin
      for j := Low(SAMPLES) to High(SAMPLES) do
         begin
         for k := Low(SAMPLES) to High(SAMPLES) do
            begin
            if (CompareKeyIgnoreCase(SAMPLES[i], SAMPLES[j]) < 0) and
               (CompareKeyIgnoreCase(SAMPLES[j], SAMPLES[k]) < 0) then
               begin
               CheckTrue(CompareKeyIgnoreCase(SAMPLES[i], SAMPLES[k]) < 0,
                         Format('transitivity: %s < %s < %s',
                                [SAMPLES[i], SAMPLES[j], SAMPLES[k]]));
               end;
            end;
         end;
      end;
end;

procedure TStringCompareTests.Test_RealCallsignsSortStably;
const
   { Deliberately mixed case, portable prefixes and suffixes -- the shapes a
     contest log actually contains. }
   CALLS: array[0..9] of ShortString =
      ('NY4I', 'ny4i', 'K4ABC', 'W1AW/4', 'DL/NY4I', '9A1A',
       'ZS6ABC', 'JA1XYZ', 'VK9/W1AW', 'K4ABD');
var
   i, j: integer;
begin
   BeginTest('Test_RealCallsignsSortStably');

   { Every pair, both directions, on the case-insensitive comparator: the
     answers must be consistent, and equal-ignoring-case entries must compare
     equal. This is the property TCallsignsList's binary search depends on. }
   for i := Low(CALLS) to High(CALLS) do
      begin
      for j := Low(CALLS) to High(CALLS) do
         begin
         if UpperCase(string(CALLS[i])) = UpperCase(string(CALLS[j])) then
            begin
            CheckEquals(0, CompareKeyIgnoreCase(CALLS[i], CALLS[j]),
                        Format('%s and %s differ only in case',
                               [CALLS[i], CALLS[j]]));
            end
         else
            begin
            CheckTrue(CompareKeyIgnoreCase(CALLS[i], CALLS[j]) <> 0,
                      Format('%s and %s are different keys',
                             [CALLS[i], CALLS[j]]));
            end;
         end;
      end;
end;

end.
