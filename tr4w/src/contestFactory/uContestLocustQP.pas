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

(* THE LOCUST QSO PARTY -- K6VVA's EVENT, AND NOT A STATE QSO PARTY.

  A QSO party by NAME only: P is 0 in its row, it has no host state and no
  counties, so it sits on TContestBase and NOT on TContestStateQSOPartyBase
  (whose header listed it as a single-state party until M3; corrected the
  same day). Inactive since about 2015 (contest calendar entry 446). NY4I,
  2026-10-01: inactive contests stay in the factory, for old logs.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'naqp';  WA7BNM: 446;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NameQTHInitialExchange;
   DM: DomesticFile;  P: 0;
   AE: NameAndDomesticOrDXQTHExchange
       (a commented-out QSONumberNameDomesticOrDXQTHExchange beside it);
   XM: NoDXMults;  QP: LQPQSOPointMethod;  ADIFName: '';  CABName: '';
   FriendlyName: 'Locust QSO Party'

  Blank ADIFName and CABName are the enum's spelling, 'LOCUST QSO PARTY'.

  SCORING IS LQPQSOPointMethod, one arm of LOGSTUFF.CalculateQSOPoints,
  transcribed exactly:

      RXData.QSOPoints := 1000;
      if (RXData.Name = 'LOCUST') or (RXData.Callsign = 'K6VVA') then
         begin
         RXData.QSOPoints := 5000;
         end;

  Every mode and every band, as the arm does. WHAT THE CALENDAR SAYS AND THE
  CODE DOES NOT -- recorded as questions for NY4I, not acted on, because a
  class that changes behaviour as it arrives is not a transcription:
    - CW only, 80 and 40 m: the arm scores every mode and band. Stating it
      would be a UsesBand override (an off-band QSO then scores 0).
    - No multipliers: the row has DM: DomesticFile on 'naqp', so TR4W
      counts states/provinces as domestic multipliers.

  EXCHANGE PARSING AND EXPORT COLUMNS ARE NOT MOVED (M4/M5); FormatsExchange
  is inherited False. FCONTEST, LOGCFG and uNewContest name it for set-up
  (M7). *)
unit uContestLocustQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestLocustQP = class(TContestBase)
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

const
   (* THE SPONSOR'S STATION AND THE SPONSOR'S NAME -- a contact with either
      is worth five times an ordinary one. *)
   LocustBonusCallsign = 'K6VVA';
   LocustBonusName = 'LOCUST';
   LocustQSOPoints = 1000;
   LocustBonusQSOPoints = 5000;

procedure TContestLocustQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := LocustQSOPoints;
   if (aQso.Name = LocustBonusName) or (aQso.Callsign = LocustBonusCallsign) then
      begin
      aQso.QSOPoints := LocustBonusQSOPoints;
      end;
end;

function TContestLocustQP.GetDisplayName: string;
begin
   Result := 'Locust QSO Party';
end;

function TContestLocustQP.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'LOCUST QSO PARTY';
end;

function TContestLocustQP.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'LOCUST QSO PARTY';
end;

function TContestLocustQP.GetWA7BNMId: integer;
begin
   Result := 446;
end;

function TContestLocustQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestLocustQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestLocustQP.GetDomesticFileName: string;
begin
   Result := 'naqp';
end;

function TContestLocustQP.GetFriendlyName: string;
begin
   Result := 'Locust QSO Party';
end;

function TContestLocustQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestLocustQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestLocustQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestLocustQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestLocustQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NameQTHInitialExchange;
end;

function TContestLocustQP.GetExchangeKind: ExchangeType;
begin
   Result := NameAndDomesticOrDXQTHExchange;
end;

function TContestLocustQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := LQPQSOPointMethod;
end;

function TContestLocustQP.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- a QSO party by name only; see the header. *)
   Result := False;
end;

initialization
   RegisterContest(LQP, TContestLocustQP);

end.
