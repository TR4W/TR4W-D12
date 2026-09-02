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

(* CQ World Wide DX - SSB.

  Scoring is TContestCQWWBase's. *)
unit uContestCQWWSSB;

{$I tr4w.inc}

interface

uses
   uContestCQWWBase;

type
   TContestCQWWSSB = class(TContestCQWWBase)
   protected
      (* THE GETTERS BEHIND TContestBase's PROPERTIES.

         PROTECTED, MATCHING THE BASE. Left public -- which is what the first
         conversion did, because a class body with no section defaults to
         public -- BOTH X.CabrilloName and X.GetCabrilloName are callable on
         this object. Two ways to ask the same question is exactly the
         ambiguity a property removes, so the getter is not part of the
         surface: callers use the property, descendants override the getter. *)
      function GetDisplayName: string; override;
   public
   end;

implementation

uses
   VC, uContestRegistry;

function TContestCQWWSSB.GetDisplayName: string;
begin
   Result := 'CQ World Wide DX - SSB';
end;

initialization
   RegisterContest(CQWWSSB, TContestCQWWSSB);

end.
