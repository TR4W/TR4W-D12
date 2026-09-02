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

(* North American Sprint - CW.

  OnePointPerQSO. A sprint's character is its QSY rule and its exchange, not its scoring. *)
unit uContestNASprintCW;

{$I tr4w.inc}

interface

uses
   VC, uContestFixedPoints;

type
   TContestNASprintCW = class(TContestFixedPoints)
   public
      constructor Create(aContest: ContestType); override;
      function DisplayName: string; override;
   end;

implementation

uses
   uContestRegistry;

constructor TContestNASprintCW.Create(aContest: ContestType);
begin
   inherited Create(aContest);
   SetPoints(1, 1);
end;

function TContestNASprintCW.DisplayName: string;
begin
   Result := 'North American Sprint - CW';
end;

initialization
   RegisterContest(NASPRINTCW, TContestNASprintCW);

end.
