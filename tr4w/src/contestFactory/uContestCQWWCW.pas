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

(* CQ World Wide DX - CW.

  Scoring is TContestCQWWBase's. The RTTY running uses a DIFFERENT method and is not this class. *)
unit uContestCQWWCW;

{$I tr4w.inc}

interface

uses
   uContestCQWWBase;

type
   TContestCQWWCW = class(TContestCQWWBase)
   protected
      (* THE GETTERS BEHIND TContestBase's PROPERTIES.

         PROTECTED, MATCHING THE BASE. Left public -- which is what the first
         conversion did, because a class body with no section defaults to
         public -- BOTH X.CabrilloName and X.GetCabrilloName are callable on
         this object. Two ways to ask the same question is exactly the
         ambiguity a property removes, so the getter is not part of the
         surface: callers use the property, descendants override the getter. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetFriendlyName: string; override;
   public
   end;

implementation

uses
   VC, uContestRegistry;

function TContestCQWWCW.GetDisplayName: string;
begin
   Result := 'CQ Worldwide DX Contest, CW';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestCQWWCW.GetCabrilloName: string;
begin
   Result := 'CQ-WW-CW';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestCQWWCW.GetADIFContestId: string;
begin
   Result := 'CQ-WW-CW';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestCQWWCW.GetFriendlyName: string;
begin
   Result := 'CQ Worldwide DX Contest, CW';
end;

initialization
   RegisterContest(CQWWCW, TContestCQWWCW);

end.
