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

(* THE HELVETIA CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'swiss';  WA7BNM: 326;  QRZRUID: 157;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTDomesticQTHOrQSONumberExchange;
   XM: NoDXMults;  QP: HelvetiaQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'Helvetia Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'HELVETIA'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: HelvetiaQSOPointMethod -- a Swiss station 10; else our own
  continent 1, else 3.

  SET-UP: a Swiss station counts DXCC; HB is the domestic country. LogCfg's
  CQ exchange: 5NN, the serial and MY STATE, or 5NN and the serial with no
  state. *)
unit uContestHelvetia;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestHelvetia = class(TContestBase)
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
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   end;

implementation

uses
   uContestRegistry;

procedure TContestHelvetia.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if rxCty = 'HB' then
      begin
      aQso.QSOPoints := 10;
      end
   else if aQso.QTH.Continent = Station.MyContinent then
      begin
      aQso.QSOPoints := 1;
      end
   else
      begin
      aQso.QSOPoints := 3;
      end;
end;

function TContestHelvetia.GetDisplayName: string;
begin
   Result := 'HELVETIA';
end;

function TContestHelvetia.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'HELVETIA';
end;

function TContestHelvetia.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'HELVETIA';
end;

function TContestHelvetia.GetWA7BNMId: integer;
begin
   Result := 326;
end;

function TContestHelvetia.GetQRZRUId: integer;
begin
   Result := 157;
end;

function TContestHelvetia.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestHelvetia.GetDomesticFileName: string;
begin
   Result := 'swiss';
end;

function TContestHelvetia.GetFriendlyName: string;
begin
   Result := 'Helvetia Contest';
end;

function TContestHelvetia.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestHelvetia.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestHelvetia.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestHelvetia.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestHelvetia.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestHelvetia.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHOrQSONumberExchange;
end;

function TContestHelvetia.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := HelvetiaQSOPointMethod;
end;

function TContestHelvetia.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestHelvetia.DescribeSession(const aStation: TStationContext;
                                           aSession: TSessionDefaults);
begin
   if aStation.MyCountry = 'HB' then
      begin
      aSession.DXMult := ARRLDXCC;
      end;
   aSession.AddDomesticCountry('HB');
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved at M7b -- see
   TContestBase.CQExchangeDefault. *)
function TContestHelvetia.CQExchangeDefault(const aStation: TStationContext): string;
begin
   if aStation.MyState <> '' then
      begin
      Result := ' 5NN # ' + aStation.MyState;
      end
   else
      begin
      Result := ' 5NN #';
      end;
end;

initialization
   RegisterContest(HELVETIA, TContestHelvetia);

end.
