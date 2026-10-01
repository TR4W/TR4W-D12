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

(* "A NUMBER PER MODE" -- A HELPER, NOT A BASE. TContestFixedPoints RETIRED AT M3.

  TEN OF THE 127 LEGACY SCORING ARMS ARE THIS SHAPE and they cover more
  contests than the other 117 combined -- OnePointPerQSO alone is 31 contests,
  OnePhoneTwoCW 11, TwoPointsPerQSO 7. Every one of them is a constant, or a
  constant chosen by mode:

      OnePointPerQSO            RXData.QSOPoints := 1;
      TwoPointsPerQSO           RXData.QSOPoints := 2;
      OnePhoneTwoCW             if Mode = CW then 2 else 1;
      ThreePhoneFiveCWFourRTTY  case Mode of CW: 5; Phone: 3; else 4; end;

  THIS UNIT HELD A BASE CLASS FOR THAT, TContestFixedPoints, UNTIL M3
  (2026-10-01), AND IT WAS RETIRED ON PURPOSE. NY4I's ownership ruling
  (docs/CONTEST_OWNERSHIP_DESIGN.md 1.5): a base class is for a FAMILY --
  contests under one rule, where a rule change reaches every member by
  definition. "Contests that happen to score by a number per mode" is a
  MECHANISM, run by some twenty-five unrelated sponsors, and a mechanism base
  spends the one base class Object Pascal gives. Florida had already left it
  for that reason. So every former subclass now sits on TContestBase (or its
  real family base) and states its own numbers in its own CalculateQSOPoints,
  calling this function:

      aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 1);

  THE THREE NUMBERS ARE THE CONTEST'S RULE; this function is only arithmetic
  over them. That is the design's definition of a helper (1.3): called BY the
  class's own code, never selected for it, and the class may stop calling it
  the day its sponsor writes a rule three numbers cannot say.

  A RULE THAT DOES NOT FIT THREE NUMBERS GETS ITS OWN BODY. Do not widen this
  function to absorb one. Field Day is the recorded example: FM scores with
  phone and digital scores two, which "CW / Phone / everything else" cannot
  express.

  THE THIRD NUMBER IS NOT REDUNDANT, and getting it wrong would be silent. The
  two-branch arms are written `if Mode = CW then X else Y`, so DIGITAL scores
  the phone value; only ThreePhoneFiveCWFourRTTY gives digital a number of its
  own. A caller transcribing a two-branch arm passes the phone value twice. *)
unit uContestFixedPoints;

{$I tr4w.inc}

interface

uses
   VC;

(* aCW for CW, aPhone for Phone, aOther for every other mode -- FM and digital
   included. *)
function FixedModePoints(aMode: ModeType; aCW, aPhone, aOther: integer): integer;

implementation

function FixedModePoints(aMode: ModeType; aCW, aPhone, aOther: integer): integer;
begin
   (* The legacy shape exactly: CW, then Phone, then everything else. FM is not
      folded into Phone here and must not be -- the arms this replaces do not
      fold it either, and the routine that DOES fold FM into Phone
      (LoadinLog's totals) is a different question about which column a QSO
      counts in, not what it scores. *)
   case aMode of
      CW:
         begin
         Result := aCW;
         end;
      Phone:
         begin
         Result := aPhone;
         end;
      else
         begin
         Result := aOther;
         end;
      end;
end;

end.
