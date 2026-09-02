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

(* General QSO.

  OnePointPerQSO -- the plainest rule there is, and the default for 31 contests. GENERAL QSO is TR4W's everyday non-contest logging mode, so this is the one that runs when nothing else does. *)
unit uContestGeneralQSO;

{$I tr4w.inc}

interface

uses
   VC, uContestFixedPoints;

type
   TContestGeneralQSO = class(TContestFixedPoints)
   public
      constructor Create(aContest: ContestType); override;
      function DisplayName: string; override;
   end;

implementation

uses
   uContestRegistry;

constructor TContestGeneralQSO.Create(aContest: ContestType);
begin
   inherited Create(aContest);
   SetPoints(1, 1);
end;

function TContestGeneralQSO.DisplayName: string;
begin
   Result := 'General QSO';
end;

initialization
   RegisterContest(GENERALQSO, TContestGeneralQSO);

end.
