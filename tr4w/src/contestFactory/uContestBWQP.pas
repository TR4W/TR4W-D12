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

(* THE BWQP.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTNameAndQTHExchange;
   XM: NoDXMults;  QP: BWQPQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'BWQP'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: BWQPQSOPointMethod -- 1 when the received QTH is all digits,
  else 0.

  SET-UP: none (FoundContest's arm for it was commented out in D7). *)
unit uContestBWQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestBWQP = class(TContestBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the properties,
         descendants override the getters. Every getter below states
         the ContestsArray row quoted above. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetWA7BNMId: integer; override;
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetFriendlyName: string; override;
      function GetPrefixMultiplierType: PrefixMultType; override;
      function GetZoneMultiplierType: ZoneMultType; override;
      function GetDXMultiplierType: DXMultType; override;
      function GetDomesticMultiplierType: DomesticMultType; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetQSOPointMethod: QSOPointMethodType; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   end;

implementation

uses
   uContestRegistry,
   (* StringIsAllNumbers -- the leaf the arm asked. *)
   utils_text;

procedure TContestBWQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if StringIsAllNumbers(string(aQso.QTHString)) then
      begin
      aQso.QSOPoints := 1;
      end
   else
      begin
      aQso.QSOPoints := 0;
      end;
end;

function TContestBWQP.GetDisplayName: string;
begin
   Result := 'BWQP';
end;

function TContestBWQP.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'BWQP';
end;

function TContestBWQP.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'BWQP';
end;

function TContestBWQP.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestBWQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestBWQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestBWQP.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestBWQP.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'BWQP';
end;

function TContestBWQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestBWQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestBWQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestBWQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestBWQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestBWQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTNameAndQTHExchange;
end;

function TContestBWQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := BWQPQSOPointMethod;
end;

function TContestBWQP.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(BWQP, TContestBWQP);

end.
