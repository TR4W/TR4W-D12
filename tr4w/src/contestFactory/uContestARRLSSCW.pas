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

(* ARRL Sweepstakes - CW.

  The scoring is TContestARRLSSBase's. This says which running it is. *)
unit uContestARRLSSCW;

{$I tr4w.inc}

interface

uses
   (* VC: the kind enums the transcribed row getters return (M10 S5). *)
   VC,
   uContestARRLSSBase;

type
   TContestARRLSSCW = class(TContestARRLSSBase)
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

      (* STATED AT M10 S5, transcribed from the ContestsArray row the base
         read until then. The flag set is the family's -- see the base. *)
      function GetWA7BNMId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
   public
   end;

implementation

uses
   uContestRegistry;

function TContestARRLSSCW.GetDisplayName: string;
begin
   Result := 'ARRL Sweepstakes Contest, CW';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestARRLSSCW.GetCabrilloName: string;
begin
   Result := 'ARRL-SS-CW';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestARRLSSCW.GetADIFContestId: string;
begin
   Result := 'ARRL-SS-CW';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestARRLSSCW.GetFriendlyName: string;
begin
   Result := 'ARRL Sweepstakes Contest, CW';
end;

function TContestARRLSSCW.GetWA7BNMId: integer;
begin
   Result := 177;
end;

function TContestARRLSSCW.GetSubmissionEmail: string;
begin
   Result := 'SSCW@arrl.org';
end;

function TContestARRLSSCW.GetDomesticFileName: string;
begin
   Result := 'arrlsect';
end;

function TContestARRLSSCW.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := CheckSectionInitialExchange;
end;

function TContestARRLSSCW.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberPrecedenceCheckDomesticQTHExchange;
end;

initialization
   RegisterContest(ARRLSSCW, TContestARRLSSCW);

end.
