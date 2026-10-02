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

(* THE NRAU-BALTIC CONTEST -- what the CW and SSB runnings share.

  A FAMILY BASE BY NY4I's RULING, 2026-10-01 -- in his words, "a NRAU_Baltic
  base class then the derived SSB and CW respectively." And on why a base for two runnings
  that differ only in mode: "There do not seem to be many differences except
  the mode but that makes it flexible in case they ever decide to change
  points per mode." So the CONTEST lives here and each mode class states only
  its identity -- the shape docs/CONTEST_OWNERSHIP_DESIGN.md 1.5 gives every
  two-mode pair under this ruling.

  The two ContestsArray rows, verbatim -- identical but for the friendly name
  and the WA7BNM id, which bf395987 un-shifted (220 CW, 222 SSB, verified on
  contestcalendar.com):

   NRAU-BALTIC-CW:  Email: '';  DF: 'nrau';  WA7BNM: 220;  QRZRUID: 0;
     Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
     DM: DomesticFile;  P: 0;  AE: RSTQSONumberAndDomesticQTHExchange;
     XM: NoDXMults;  QP: TwoPointsPerQSO;  ADIFName: '';  CABName: '';
     FriendlyName: 'NRAU-Baltic Contest, CW'
   NRAU-BALTIC-SSB: the same, WA7BNM: 222,
     FriendlyName: 'NRAU-Baltic Contest, SSB'

  THE SHARED FIELDS ARE STATED HERE; the four that differ (display, Cabrillo
  and ADIF names, WA7BNM id, friendly name) are stated by each mode class.

  SCORING IS TwoPointsPerQSO, one arm of LOGSTUFF.CalculateQSOPoints:

      TwoPointsPerQSO: RXData.QSOPoints := 2;

  -- two on every mode, digital and FM included. Written as FixedModePoints
  with three equal numbers so that "change points per mode" is a change of
  numbers here, or an override in one mode class, and nothing else.

  SET-UP IS THE FAMILY'S (M7a): FCONTEST's arm and LOGCFG's CQ exchange
  (' 5NN # ' + MY STATE) named both runnings together, so this base holds
  them once, as DescribeSession and CQExchangeDefault. uNewContest's
  province prompt moves at M9. EXCHANGE PARSING IS NOT MOVED (M5); EXPORT IS THE BASE'S
  DEFAULT (M4), the shared RSTQSONumberAndDomesticQTHExchange arm. *)
unit uContestNRAUBalticBase;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestNRAUBalticBase = class(TContestBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the properties,
         descendants override the getters. The rows' shared fields. *)
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
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
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uContestFixedPoints,
   uTR4WStrings;

procedure TContestNRAUBalticBase.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 2, 2);
end;

function TContestNRAUBalticBase.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNRAUBalticBase.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestNRAUBalticBase.GetDomesticFileName: string;
begin
   Result := 'nrau';
end;

function TContestNRAUBalticBase.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestNRAUBalticBase.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestNRAUBalticBase.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestNRAUBalticBase.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestNRAUBalticBase.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestNRAUBalticBase.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndDomesticQTHExchange;
end;

function TContestNRAUBalticBase.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := TwoPointsPerQSO;
end;

function TContestNRAUBalticBase.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named NRAUBALTICCW, NRAUBALTICSSB, one contest in two
   modes, so the family base holds it once. *)
procedure TContestNRAUBalticBase.DescribeSession(const aStation: TStationContext;
                                                 aSession: TSessionDefaults);
begin
   aSession.Band := Band80;
   aSession.AddDomesticCountry('ES');
   aSession.AddDomesticCountry('JW');
   aSession.AddDomesticCountry('JX');
   aSession.AddDomesticCountry('LA');
   aSession.AddDomesticCountry('LY');
   aSession.AddDomesticCountry('OH');
   aSession.AddDomesticCountry('OH0');
   aSession.AddDomesticCountry('OX');
   aSession.AddDomesticCountry('OY');
   aSession.AddDomesticCountry('OZ');
   aSession.AddDomesticCountry('SM');
   aSession.AddDomesticCountry('TF');
   aSession.AddDomesticCountry('YL');
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestNRAUBalticBase.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' 5NN # ' + aStation.MyState;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   NRAUBALTICCW and NRAUBALTICSSB ran the same arms; they are
   one family under one rule, so the prompts are the family's. *)
procedure TContestNRAUBalticBase.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURPROVINCEID, ncfMyState);
end;

end.
