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

(* THE ARCI QRP CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 's50p12';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTPossibleDomesticQTHAndPower;
   XM: ARRLDXCCWithNoUSACanadaKH6OrKL7;  QP: ARCIQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'ARCI'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: ARCIQSOPointMethod -- a member (an all-digit number where the
  power goes) 5; else our own continent 2; else 4.

  SET-UP: K, VE, KH6 and KL are the domestic countries. *)
unit uContestARCI;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestARCI = class(TContestBase)
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
   (* StringIsAllNumbers -- the leaf the arm asked. *)
   utils_text;

procedure TContestARCI.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if StringIsAllNumbers(string(aQso.Power)) then
      begin
      aQso.QSOPoints := 5;
      end
   else if Station.MyContinent = aQso.QTH.Continent then
      begin
      aQso.QSOPoints := 2;
      end
   else
      begin
      aQso.QSOPoints := 4;
      end;
end;

function TContestARCI.GetDisplayName: string;
begin
   Result := 'ARCI';
end;

function TContestARCI.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'ARCI';
end;

function TContestARCI.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'ARCI';
end;

function TContestARCI.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestARCI.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestARCI.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestARCI.GetDomesticFileName: string;
begin
   Result := 's50p12';
end;

function TContestARCI.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'ARCI';
end;

function TContestARCI.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestARCI.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestARCI.GetDXMultiplierType: DXMultType;
begin
   Result := ARRLDXCCWithNoUSACanadaKH6OrKL7;
end;

function TContestARCI.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestARCI.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestARCI.GetExchangeKind: ExchangeType;
begin
   Result := RSTPossibleDomesticQTHAndPower;
end;

function TContestARCI.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := ARCIQSOPointMethod;
end;

function TContestARCI.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestARCI.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountries(DomesticCountriesKVEKH6KL);
end;

initialization
   RegisterContest(ARCI, TContestARCI);

end.
