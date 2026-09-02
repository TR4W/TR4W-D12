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

(* ARRL SWEEPSTAKES -- what CW and Phone share.

  TWO POINTS A QSO, EITHER MODE. Sweepstakes puts all of its difficulty in the
  exchange -- serial, precedence, check, section, in one string -- and none of
  it in the scoring.

  A BASE FOR TWO NUMBERS LOOKS LIKE CEREMONY AND IS NOT. TR4QT has ARRLSSBase
  for the same pair, and the reason shows the moment anything beyond scoring
  moves in: the exchange parser, the section list, the "you may work a station
  once per contest regardless of band" rule. Those belong to Sweepstakes, not to
  the CW running of it, and they will land here. Writing SetPoints(2, 2) twice
  in two unrelated classes would leave nowhere for them to go. *)
unit uContestARRLSSBase;

{$I tr4w.inc}

interface

uses
   VC, uContestFixedPoints;

type
   TContestARRLSSBase = class(TContestFixedPoints)
   public
      constructor Create(aContest: ContestType); override;
   end;

implementation

constructor TContestARRLSSBase.Create(aContest: ContestType);
begin
   inherited Create(aContest);
   SetPoints(2, 2);
end;

end.
