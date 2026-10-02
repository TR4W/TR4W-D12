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

(* THE CWOPS CW OPEN.

  The ContestsArray row this class states, verbatim:

   Email: 'cwo@cwops.org';  DF: '';  WA7BNM: 532;  QRZRUID: 0;
   Pxm: CallSignPrefix;  ZnM: CQZones;  AIE: NameInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: QSONumberAndNameExchange;
   XM: NoDXMults;  QP: OnePointPerQSO;
   ADIFName: 'CWOPS-CW-OPEN';  CABName: 'CW-OPEN';
   FriendlyName: 'CWOps CW Open'

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: OnePointPerQSO -- 1 in every mode.

  SET-UP: nothing in FoundContest. LogCfg's CQ exchange: the serial and
  MY NAME.

  NOT MOVED, ON PURPOSE: uExchangeBuilder's HamScore received exchange
  (serial and name) names it, beside registered contests -- a seam not
  built yet (M9), as All Asian's arm there was left at batch 1. *)
unit uContestCWOpen;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCWOpen = class(TContestBase)
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
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   end;

implementation

uses
   uContestRegistry,
   uContestFixedPoints;

(* OnePointPerQSO -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestCWOpen.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestCWOpen.GetDisplayName: string;
begin
   Result := 'CWOPEN';
end;

function TContestCWOpen.GetCabrilloName: string;
begin
   Result := 'CW-OPEN';
end;

function TContestCWOpen.GetADIFContestId: string;
begin
   Result := 'CWOPS-CW-OPEN';
end;

function TContestCWOpen.GetWA7BNMId: integer;
begin
   Result := 532;
end;

function TContestCWOpen.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestCWOpen.GetSubmissionEmail: string;
begin
   Result := 'cwo@cwops.org';
end;

function TContestCWOpen.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestCWOpen.GetFriendlyName: string;
begin
   Result := 'CWOps CW Open';
end;

function TContestCWOpen.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := CallSignPrefix;
end;

function TContestCWOpen.GetZoneMultiplierType: ZoneMultType;
begin
   Result := CQZones;
end;

function TContestCWOpen.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestCWOpen.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestCWOpen.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NameInitialExchange;
end;

function TContestCWOpen.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberAndNameExchange;
end;

function TContestCWOpen.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestCWOpen.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved here as it
   stood (M7b batch 2). See TContestBase.CQExchangeDefault. *)
function TContestCWOpen.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' # ' + aStation.MyName;
end;

initialization
   RegisterContest(CWOPEN, TContestCWOpen);

end.
