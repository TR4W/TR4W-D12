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

(* WINTER FIELD DAY -- January.

  One point for phone, two for everything else, with FM counted as phone --
  the same rule ARRL Field Day uses THIS YEAR.

  THIS SCORING IS DELIBERATELY NOT SHARED WITH WINTER FIELD DAY, even though
  the two rules are identical today and a base class was written for them and
  then deleted.

  NY4I, 2026-09-02: "I would diverge winter field day and arrl field day. They
  keep diverging with rule changes each year."

  That is an operational argument and it beats the tidiness one. These are two
  contests run by different organisations that revise their rules
  independently, and a shared base makes every future divergence a REFACTOR --
  extract the difference, push it down, re-test both -- at the exact moment
  somebody is trying to make a small change before a contest weekend. Two
  classes that happen to agree cost one duplicated `if` and make next year's
  change a three-line edit to one file that cannot affect the other.

  TR4QT reaches the same conclusion: ARRLFieldDayContest and
  WinterFieldDayContest are separate there too, with no FieldDayBase between
  them, despite scoring identically.

  SO THE DUPLICATION HERE IS INTENDED. It is not an extraction somebody has not
  got round to, and it should not be "fixed" -- the identical code in
  uContestWinterFieldDay is a coincidence of this year's rules, not a shared
  rule.

  WFD ALREADY DIFFERS ELSEWHERE, which is the point: it disallows FT8 and FT4,
  and its exchange carries a different class format. Those differences are not
  in TR4W yet -- when they arrive they arrive HERE, in a file that ARRL Field
  Day cannot be broken by. *)
unit uContestWinterFieldDay;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestWinterFieldDay = class(TContestBase)
   public
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
      function ValidateClass(const aClass: string;
                             out aErrorMessage: string): boolean; override;
      function ValidateDXQTH(const aQTH: string;
                             out aResolved: string;
                             out aErrorMessage: string): boolean; override;
      function DisplayName: string; override;
   end;

implementation

uses
   uTR4WStrings, uContestRegistry;

procedure TContestWinterFieldDay.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.Mode in [Phone, FM] then
      begin
      aQso.QSOPoints := 1;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;
end;

(* I, O, H and M -- Indoor, Outdoor, Home and Mobile. A DIFFERENT set from ARRL Field Day, which is the clearest evidence that these two belong in separate classes.

   The COUNT-then-LETTER parsing is TContestBase's -- it is mechanism, and
   identical for any contest with a class. What is this contest's is the
   letter set and the message. *)
function TContestWinterFieldDay.ValidateClass(const aClass: string;
                          out aErrorMessage: string): boolean;
begin
   Result := ValidateCountAndLetterClass(aClass, 'IOHM',
                                         TC_IMPROPERWINTERFIELDDAYCLASS, aErrorMessage);
end;

(* DX, or MX. Winter Field Day accepts MX where ARRL Field Day does not -- the second place these two differ today, after the class letters. *)
function TContestWinterFieldDay.ValidateDXQTH(const aQTH: string;
                          out aResolved: string;
                          out aErrorMessage: string): boolean;
begin
   Result := ValidateDXQTHAllowing(aQTH, 'MX', aResolved, aErrorMessage);
end;

function TContestWinterFieldDay.DisplayName: string;
begin
   Result := 'Winter Field Day';
end;

initialization
   RegisterContest(WINTERFIELDDAY, TContestWinterFieldDay);

end.
