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

(* THE GACW WWSA CW DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 45;  QRZRUID: 321;
   Pxm: NoPrefixMults;  ZnM: CQZones;  AIE: ZoneInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTZoneExchange;
   XM: CQDXCC;  QP: GACWWWSACWQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'GACW WWSA CW DX Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'GACW-WWSA-CW'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: GACWWWSACWQSOPointMethod -- another continent 3, another country
  1, our own country 0; then a South American station 5. *)
unit uContestGACWWWSACW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestGACWWWSACW = class(TContestBase)
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
   uContestRegistry;

procedure TContestGACWWWSACW.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 3;
      end
   else if rxCty <> Station.MyCountry then
      begin
      aQso.QSOPoints := 1;
      end
   else
      begin
      aQso.QSOPoints := 0;
      end;

   if aQso.QTH.Continent = SouthAmerica then
      begin
      aQso.QSOPoints := 5;
      end;
end;

function TContestGACWWWSACW.GetDisplayName: string;
begin
   Result := 'GACW WWSA CW DX Contest';
end;

function TContestGACWWWSACW.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'GACW-WWSA-CW';
end;

function TContestGACWWWSACW.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'GACW-WWSA-CW';
end;

function TContestGACWWWSACW.GetWA7BNMId: integer;
begin
   Result := 45;
end;

function TContestGACWWWSACW.GetQRZRUId: integer;
begin
   Result := 321;
end;

function TContestGACWWWSACW.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestGACWWWSACW.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestGACWWWSACW.GetFriendlyName: string;
begin
   Result := 'GACW WWSA CW DX Contest';
end;

function TContestGACWWWSACW.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestGACWWWSACW.GetZoneMultiplierType: ZoneMultType;
begin
   Result := CQZones;
end;

function TContestGACWWWSACW.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestGACWWWSACW.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestGACWWWSACW.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestGACWWWSACW.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneExchange;
end;

function TContestGACWWWSACW.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := GACWWWSACWQSOPointMethod;
end;

function TContestGACWWWSACW.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(GACWWWSACW, TContestGACWWWSACW);

end.
