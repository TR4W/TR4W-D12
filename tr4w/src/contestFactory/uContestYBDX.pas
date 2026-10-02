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

(* THE YB ORARI DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 772;  QRZRUID: 175;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTQSONumberExchange;
   XM: NoDXMults;  QP: IndonesianQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'YB ORARI DX Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'YBDX'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: IndonesianQSOPointMethod -- an Indonesian station: another
  Indonesian 0, another continent 10, our continent 5. Anyone else: an
  Indonesian 10, another continent 3, another country of ours 2, our own
  country 1. (uCallSignRoutines.IndonesianCountry.)

  SET-UP: phone, DXCC multipliers, Indonesian district prefixes.

  NOT MOVED, ON PURPOSE: MainUnit.ParametersOkay names this contest in the
  Indonesian-district prefix rule (an Indonesian station's prefix is its
  own). That is a multiplier rule, and the multiplier seam is M8. *)
unit uContestYBDX;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestYBDX = class(TContestBase)
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
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   end;

implementation

uses
   uContestRegistry,
   uCallSignRoutines;

(* IndonesianQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestYBDX.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if IndonesianCountry(Station.MyCountry) then
      begin
      if IndonesianCountry(rxCty) then
         begin
         aQso.QSOPoints := 0;
         end
      else if aQso.QTH.Continent <> Station.MyContinent then
         begin
         aQso.QSOPoints := 10;
         end
      else
         begin
         aQso.QSOPoints := 5;
         end;
      end
   else
      begin
      if IndonesianCountry(rxCty) then
         begin
         aQso.QSOPoints := 10;
         end
      else if aQso.QTH.Continent <> Station.MyContinent then
         begin
         aQso.QSOPoints := 3;
         end
      else if rxCty <> Station.MyCountry then
         begin
         aQso.QSOPoints := 2;
         end
      else
         begin
         aQso.QSOPoints := 1;
         end;
      end;
end;

function TContestYBDX.GetDisplayName: string;
begin
   Result := 'YB ORARI DX Contest';
end;

function TContestYBDX.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'YBDX';
end;

function TContestYBDX.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'YBDX';
end;

function TContestYBDX.GetWA7BNMId: integer;
begin
   Result := 772;
end;

function TContestYBDX.GetQRZRUId: integer;
begin
   Result := 175;
end;

function TContestYBDX.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestYBDX.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestYBDX.GetFriendlyName: string;
begin
   Result := 'YB ORARI DX Contest';
end;

function TContestYBDX.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestYBDX.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestYBDX.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestYBDX.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestYBDX.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestYBDX.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestYBDX.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := IndonesianQSOPointMethod;
end;

function TContestYBDX.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestYBDX.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.Mode := Phone;
   aSession.DXMult := ARRLDXCC;
   aSession.PrefixMult := IndonesianDistricts;
end;

initialization
   RegisterContest(YBDX, TContestYBDX);

end.
