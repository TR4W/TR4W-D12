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

(* CQ WPX - CW.

  Scoring is TContestCQWPXBase's. The RTTY running uses a different method and is not this class. *)
unit uContestCQWPXCW;

{$I tr4w.inc}

interface

uses
   (* VC: the kind enums the transcribed row getters return (M10 S5). *)
   VC,
   (* uContestBase: TExchangeParsers, which the format's signature
      names (M11 S9d). *)
   uContestBase,
   uContestCQWPXBase;

type
   TContestCQWPXCW = class(TContestCQWPXBase)
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
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function ParseReceivedExchangeFormat(const aText: string;
                                           aParsers: TExchangeParsers;
                                           var aExch: ContestExchange): boolean; override;
   public
   end;

implementation

uses
   uExchangeFields,
   uContestRegistry;

function TContestCQWPXCW.GetDisplayName: string;
begin
   Result := 'CQ WW WPX Contest, CW';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestCQWPXCW.GetCabrilloName: string;
begin
   Result := 'CQ-WPX-CW';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestCQWPXCW.GetADIFContestId: string;
begin
   Result := 'CQ-WPX-CW';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestCQWPXCW.GetFriendlyName: string;
begin
   Result := 'CQ WW WPX Contest, CW';
end;

function TContestCQWPXCW.GetWA7BNMId: integer;
begin
   Result := 29;
end;

function TContestCQWPXCW.GetQRZRUId: integer;
begin
   Result := 18;
end;

function TContestCQWPXCW.GetSubmissionEmail: string;
begin
   Result := 'cw@cqwpx.com';
end;

function TContestCQWPXCW.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestCQWPXCW.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumber;
end;

function TContestCQWPXCW.ParseReceivedExchangeFormat(const aText: string;
                                                     aParsers: TExchangeParsers;
                                                     var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTQSONumber(aText, aExch);
end;

initialization
   RegisterContest(CQWPXCW, TContestCQWPXCW);

end.
