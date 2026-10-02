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

(* THE DUTCH PACC CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'pacc';  WA7BNM: 249;  QRZRUID: 66;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTAndQSONumberOrDomesticQTHExchange;
   XM: NoDXMults;  QP: OnePointPerQSO;  ADIFName: '';
   CABName: '';  FriendlyName: 'Dutch PACC Contest'

  Blank ADIFName and CABName are the enum's spelling, 'PACC'.

  WHY IT HAS A CLASS NOW. M4 (2026-10-01) made every contest format its own
  export, and this contest's rule was a `Contest = PACC` test inside a shared
  exporter -- which the base may never contain. A class to hold that rule
  needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record
  but `contest.class` is unchanged, which is the proof. EXCHANGE PARSING
  (M5b) and set-up (M7a) have moved since.

  SCORING IS OnePointPerQSO, stated through the FixedModePoints helper:

      OnePointPerQSO: RXData.QSOPoints := 1;

  THE SESSION RUNS A DIFFERENT EXCHANGE FROM THE ROW, and the export rule
  lives there. FCONTEST's PACC arm sets ActiveExchange to
  RSTDomesticQTHExchange for every station (the contest matrix shows nothing
  else), and inside that shared arm `if Contest in [SPDX, PACC]` put OUR
  SERIAL in the state column. That is this class's sent side now, Cabrillo
  and ADIF alike; the received column is the shared arm's. (SP DX's half of
  that test was dead -- SP DX never runs that exchange -- and went with it.)
  The row's own AE is transcribed unchanged. M7a moved the arm into
  DescribeSession as it stood: a PA station runs the row's exchange and
  everyone else RSTDomesticQTHExchange -- the matrix has no PA variant, so
  only the second is pinned there. *)
unit uContestPACC;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestPACC = class(TContestBase)
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
      function FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aCtx: TCabrilloQSOContext): string; override;
      function FormatADIFSentExchange(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      aSessionExchange: ExchangeType): string; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   SysUtils, uContestRegistry, uContestFixedPoints,
   uTR4WStrings;

procedure TContestPACC.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

(* RST AND OUR SERIAL, in RSTDomesticQTHExchange's state column. *)
function TContestPACC.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange;
                                                 const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %-7s', [aCtx.RSTSent, IntToStr(aQso.NumberSent)]);
end;

function TContestPACC.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange;
                                             aSessionExchange: ExchangeType): string;
begin
   Result := Format('%-3d %-7s', [aQso.RSTSent, IntToStr(aQso.NumberSent)]);
end;

function TContestPACC.GetDisplayName: string;
begin
   Result := 'Dutch PACC Contest';
end;

function TContestPACC.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'PACC';
end;

function TContestPACC.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'PACC';
end;

function TContestPACC.GetWA7BNMId: integer;
begin
   Result := 249;
end;

function TContestPACC.GetQRZRUId: integer;
begin
   Result := 66;
end;

function TContestPACC.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestPACC.GetDomesticFileName: string;
begin
   Result := 'pacc';
end;

function TContestPACC.GetFriendlyName: string;
begin
   Result := 'Dutch PACC Contest';
end;

function TContestPACC.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestPACC.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestPACC.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestPACC.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestPACC.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestPACC.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndQSONumberOrDomesticQTHExchange;
end;

function TContestPACC.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestPACC.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestPACC.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   if aStation.MyCountry = 'PA' then
      begin
      aSession.DXMult := PACCCountriesAndPrefixes;
      aSession.Exchange := RSTAndQSONumberOrDomesticQTHExchange;
      aSession.AddDomesticCountry('PA');
      aSession.DomesticFile := 'PACCPA';
      aSession.LiteralDomesticQTH := True;
      end
   else
      begin
      aSession.Exchange := RSTDomesticQTHExchange;
      aSession.DomesticFile := 'PACC';
      end;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on ticking the box stood for ARI_DX, CANADA_DAY,
   CANADA_WINTER, HELVETIA, KINGOFSPAINCW, KINGOFSPAINSSB, UBACW, UBASSB.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestPACC.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_NETHERLANDS);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOURPROVINCEID, ncfMyState);
end;

initialization
   RegisterContest(PACC, TContestPACC);

end.
