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

(* THE ARI INTERNATIONAL DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'ari';  WA7BNM: 9;  QRZRUID: 85;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTAndQSONumberOrDomesticQTHExchange;
   XM: ARRLDXCCWithNoIOrIS0;  QP: ARIQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'ARI International DX Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'ARI-DX'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: ARIQSOPointMethod -- an Italian station (I, IS, *IT9) 10; else
  another continent 3; else another country 1; else 0.

  SET-UP: I, IS and *IT9 are the domestic countries, in that order. *)
unit uContestARIDX;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestARIDX = class(TContestBase)
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
   uContestRegistry;

procedure TContestARIDX.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if (rxCty = 'I')  or
      (rxCty = 'IS') or
      (rxCty = '*IT9') then
      begin
      aQso.QSOPoints := 10;
      end
   else if aQso.QTH.Continent <> Station.MyContinent then
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
end;

function TContestARIDX.GetDisplayName: string;
begin
   Result := 'ARI-DX';
end;

function TContestARIDX.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'ARI-DX';
end;

function TContestARIDX.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'ARI-DX';
end;

function TContestARIDX.GetWA7BNMId: integer;
begin
   Result := 9;
end;

function TContestARIDX.GetQRZRUId: integer;
begin
   Result := 85;
end;

function TContestARIDX.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestARIDX.GetDomesticFileName: string;
begin
   Result := 'ari';
end;

function TContestARIDX.GetFriendlyName: string;
begin
   Result := 'ARI International DX Contest';
end;

function TContestARIDX.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestARIDX.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestARIDX.GetDXMultiplierType: DXMultType;
begin
   Result := ARRLDXCCWithNoIOrIS0;
end;

function TContestARIDX.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestARIDX.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestARIDX.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndQSONumberOrDomesticQTHExchange;
end;

function TContestARIDX.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := ARIQSOPointMethod;
end;

function TContestARIDX.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestARIDX.DescribeSession(const aStation: TStationContext;
                                        aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountry('I');
   aSession.AddDomesticCountry('IS');
   aSession.AddDomesticCountry('*IT9');
end;

initialization
   RegisterContest(ARI_DX, TContestARIDX);

end.
