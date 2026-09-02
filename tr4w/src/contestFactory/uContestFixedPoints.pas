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

(* CONTESTS WHOSE SCORING IS A NUMBER PER MODE, AND NOTHING ELSE.

  TEN OF THE 127 SCORING ARMS ARE THIS SHAPE and they cover MORE CONTESTS THAN
  THE OTHER 117 COMBINED -- OnePointPerQSO alone is 31 contests, OnePhoneTwoCW
  11, TwoPointsPerQSO 7. Every one of them is a constant, or a constant chosen
  by mode:

      OnePointPerQSO            RXData.QSOPoints := 1;
      TwoPointsPerQSO           RXData.QSOPoints := 2;
      OnePhoneTwoCW             if Mode = CW then 2 else 1;
      ThreePhoneFiveCWFourRTTY  case Mode of CW: 5; Phone: 3; else 4; end;

  So the family is three numbers, and a contest in it declares them in its
  constructor. That is the whole class -- which is the point: a contest whose
  rule is "two points a QSO" should not need a routine to say so.

  THE THIRD NUMBER IS NOT REDUNDANT, and getting it wrong would be silent. The
  two-branch arms are written `if Mode = CW then X else Y`, so DIGITAL scores
  the phone value; only ThreePhoneFiveCWFourRTTY gives digital a number of its
  own. Modelling this as CW-versus-not would reproduce nine arms and quietly
  break the tenth, in a contest nobody would think to check. The default for
  aOther is the phone value, so a two-branch contest states two numbers and
  gets the legacy behaviour exactly.

  WHY NOT ONE CLASS PER POINT METHOD. Because the unit that exists is a
  CONTEST, not a scoring rule -- see uContestBase. This is a family base in the
  same sense TContestARRLDXBase is: shared behaviour, with each contest still
  its own class and its own registration, so an operator's contest is always
  findable by name. *)
unit uContestFixedPoints;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestFixedPoints = class(TContestBase)
   private
      FCWPoints: integer;
      FPhonePoints: integer;
      FOtherPoints: integer;
   protected
      (* Declares the rule. aOther defaults to aPhone, which is what the
         two-branch legacy arms do for digital. Call from the subclass
         constructor, before anything scores. *)
      procedure SetPoints(aCW, aPhone: integer; aOther: integer = -1);
   public
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   end;

implementation

procedure TContestFixedPoints.SetPoints(aCW, aPhone: integer;
                                        aOther: integer = -1);
begin
   FCWPoints := aCW;
   FPhonePoints := aPhone;
   if aOther < 0 then
      begin
      FOtherPoints := aPhone;
      end
   else
      begin
      FOtherPoints := aOther;
      end;
end;

procedure TContestFixedPoints.CalculateQSOPoints(var aQso: ContestExchange);
begin
   (* The legacy shape exactly: CW, then Phone, then everything else. FM is not
      folded into Phone here and must not be -- the arms this replaces do not
      fold it either, and the routine that DOES fold FM into Phone
      (LoadinLog's totals) is a different question about which column a QSO
      counts in, not what it scores. *)
   case aQso.Mode of
      CW:
         begin
         aQso.QSOPoints := FCWPoints;
         end;
      Phone:
         begin
         aQso.QSOPoints := FPhonePoints;
         end;
      else
         begin
         aQso.QSOPoints := FOtherPoints;
         end;
      end;
end;

end.
