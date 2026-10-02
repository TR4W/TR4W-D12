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

(* THE MONGOLIAN (JT) DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: MongolianCallSignPrefix;  ZnM: NoZoneMults;  AIE: ZoneInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTZoneExchange;
   XM: ARRLDXCCWithNoJT;  QP: JTDXQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'MONGOLIAN DX'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: JTDXQSOPointMethod -- another continent 3, another country 2,
  our own 1; a JT station working JT 0.

  SET-UP: a zone initial exchange, and Mongolian call-sign prefixes as the
  prefix multiplier -- both the row's own values, restated as the arm did,
  so a statement made before the CONTEST line is still overwritten. *)
unit uContestJTDX;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestJTDX = class(TContestBase)
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

procedure TContestJTDX.CalculateQSOPoints(var aQso: ContestExchange);
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
      aQso.QSOPoints := 2;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;

   if rxCty = 'JT' then
      begin
      if Station.MyCountry = 'JT' then
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestJTDX.GetDisplayName: string;
begin
   Result := 'MONGOLIAN DX';
end;

function TContestJTDX.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'MONGOLIAN DX';
end;

function TContestJTDX.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'MONGOLIAN DX';
end;

function TContestJTDX.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestJTDX.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestJTDX.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestJTDX.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestJTDX.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'MONGOLIAN DX';
end;

function TContestJTDX.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := MongolianCallSignPrefix;
end;

function TContestJTDX.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestJTDX.GetDXMultiplierType: DXMultType;
begin
   Result := ARRLDXCCWithNoJT;
end;

function TContestJTDX.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestJTDX.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestJTDX.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneExchange;
end;

function TContestJTDX.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := JTDXQSOPointMethod;
end;

function TContestJTDX.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestJTDX.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.InitialExchange := ZoneInitialExchange;
   aSession.PrefixMult := MongolianCallSignPrefix;
end;

initialization
   RegisterContest(JTDX, TContestJTDX);

end.
