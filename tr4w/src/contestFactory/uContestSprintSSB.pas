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

(* THE SSB SPRINT -- ITS OWN CONTEST, NOT AN NA SPRINT.

  NY4I, 2026-10-01: "a different contest with a different sponsor so keep it
  separate" (rules: https://ssbsprint.com/rules/). So this class sits on
  TContestBase, not beside or beneath the NCJ's NA Sprint classes, even though
  today it scores, parses and exports exactly as they do. Any resemblance is a
  starting point this class owns (CONTEST_OWNERSHIP_DESIGN.md 1.4).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'naqp';  WA7BNM: 242;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NameQTHInitialExchange;
   DM: DomesticFile;  P: 0;  AE: QSONumberNameDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: OnePointPerQSO;  ADIFName: 'NA-SPRINT-SSB';
   CABName: 'NA-SPRINT-SSB';  FriendlyName: 'North American Sprint, SSB'

  Its enum spelling is SSB-SPRINT; the ADIF and Cabrillo names are stated in
  the row and are NOT the spelling. Its names still say "North American
  Sprint" -- transcribed unchanged; whether they should is a question for
  NY4I, recorded with M3 in the design doc.

  SCORING IS OnePointPerQSO, one arm of LOGSTUFF.CalculateQSOPoints:

      OnePointPerQSO: RXData.QSOPoints := 1;

  stated here through the FixedModePoints helper.

  EXCHANGE PARSING IS NOT MOVED (M5). EXPORT IS THE BASE'S DEFAULT (M4): the
  shared QSONumberNameDomesticOrDXQTHExchange arm, the same one the NA Sprint
  CW class reproduces for itself. postunit's no-op arm that named this
  contest beside the NA Sprints (inventory D6) was deleted at M4. FCONTEST,
  uNewContest and LOGCFG name it for set-up (M7). *)
unit uContestSprintSSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestSprintSSB = class(TContestBase)
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
   uContestRegistry, uContestFixedPoints;

procedure TContestSprintSSB.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestSprintSSB.GetDisplayName: string;
begin
   Result := 'North American Sprint, SSB';
end;

function TContestSprintSSB.GetCabrilloName: string;
begin
   Result := 'NA-SPRINT-SSB';
end;

function TContestSprintSSB.GetADIFContestId: string;
begin
   Result := 'NA-SPRINT-SSB';
end;

function TContestSprintSSB.GetWA7BNMId: integer;
begin
   Result := 242;
end;

function TContestSprintSSB.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestSprintSSB.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestSprintSSB.GetDomesticFileName: string;
begin
   Result := 'naqp';
end;

function TContestSprintSSB.GetFriendlyName: string;
begin
   Result := 'North American Sprint, SSB';
end;

function TContestSprintSSB.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestSprintSSB.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestSprintSSB.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestSprintSSB.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestSprintSSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NameQTHInitialExchange;
end;

function TContestSprintSSB.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberNameDomesticOrDXQTHExchange;
end;

function TContestSprintSSB.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestSprintSSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(SPRINTSSB, TContestSprintSSB);

end.
