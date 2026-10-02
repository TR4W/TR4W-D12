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

(* THE DARC WAE DX CONTEST, CW.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 85;  QRZRUID: 15;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: NoDomesticMults;  P: 0;
   AE: RSTQSONumberExchange;  XM: NoDXMults;  QP: WAEQSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: 'WAE DX Contest, CW'

  Blank ADIFName and CABName resolve to the enum's spelling, 'DARC-WAEDC-CW'. The row
  names no multiplier at all: DescribeSession gives a non-European station
  CQEuropeanCountries and anybody else the WAE prefixes, so the score reads
  the SESSION's DX multiplier, never this row's.

  WHY IT HAS A CLASS NOW. M6 (2026-10-02) moved the final score onto the
  contest, and this contest's formula was LogEdit.TotalScore's
  `ActiveQSOPointMethod = WAEQSOPointMethod` test -- the session's POINT METHOD, so an
  operator's QSO POINT METHOD line reached it in any contest. A class to hold
  that formula needed the whole row and the scoring arm with it, because
  registering a class makes the class this contest's scorer too. Both are
  transcribed exactly; Test_MovedRowValuesStillMatchTheArray holds the row,
  and the contest matrix the rest -- every line of its record but
  `contest.class` is unchanged, its totals included, which is the proof.

  A SIBLING OF THE SSB RUNNING, NOT A FAMILY (design 1.5, Q7). NY4I's ruling that a
  two-mode contest gets a base names NRAU-Baltic only, and extending it to
  every pair is his open Q7 -- so, as with the SAC pair, the runnings are
  siblings and each owns its copy (design 1.4).

  ITS FINAL SCORE: the points (QTCs included, as for every contest that has
  them on) times WEIGHTED multipliers -- four for each on 80 m, three on 40 m
  and two on 20, 15 and 10 m, counting the session's European countries when
  its DX multiplier is CQEuropeanCountries (a non-European station, set by
  DescribeSession) and its WAE prefixes otherwise. A single-band entry counts
  its band's multipliers once each, the general case. LogEdit.TotalScore's
  `ActiveQSOPointMethod = WAEQSOPointMethod` arm, moved at M6.

  SCORING, transcribed from WAEQSOPointMethod: 1 point for a QSO with the
  other side of Europe's border, never on 160 m; otherwise 0. *)
unit uContestDARCWAEDCCW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestDARCWAEDCCW = class(TContestBase)
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
      (* THE SPONSOR'S FORMULA -- see the header. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   protected
      (* THE QTC MENU -- see TContestBase.OffersQTCs (M9a). *)
      function GetOffersQTCs: boolean; override;
   public
      (* THE CANONICAL RECEIVED EXCHANGE -- see
         TContestBase.CanonicalReceivedExchange (M9a). *)
      function CanonicalReceivedExchange(const aQso: ContestExchange): string; override;
   end;

implementation

uses
   uContestRegistry,
   SysUtils,
   uCanonicalExchange;

(* WAEQSOPointMethod, transcribed. A European station scores 1 for a QSO
   outside Europe, and anybody else 1 for a QSO in Europe -- 160 m excepted;
   every other contact scores 0. *)
procedure TContestDARCWAEDCCW.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if Station.MyContinent = Europe then
      begin
      if (aQso.QTH.Continent <> Europe) and (aQso.Band <> Band160) then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end
   else if (aQso.QTH.Continent = Europe) and (aQso.Band <> Band160) then
      begin
      aQso.QSOPoints := 1;
      end
   else
      begin
      aQso.QSOPoints := 0;
      end;
end;

function TContestDARCWAEDCCW.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
var
   kind: RemainingMultiplierType;
   mults: longint;
begin
   if aTotals.ScoredBand <> AllBands then
      begin
      Result := inherited CombineWithMultipliers(aTotals);
      Exit;
      end;

   if aTotals.SessionDXMult = CQEuropeanCountries then
      begin
      kind := rmDX;
      end
   else
      begin
      kind := rmPrefix;
      end;

   mults := aTotals.Mults[Band80, Both, kind] * 4;
   mults := mults + aTotals.Mults[Band40, Both, kind] * 3;
   mults := mults + aTotals.Mults[Band20, Both, kind] * 2;
   mults := mults + aTotals.Mults[Band15, Both, kind] * 2;
   mults := mults + aTotals.Mults[Band10, Both, kind] * 2;
   Result := ContestPoints(aTotals) * mults;
end;

function TContestDARCWAEDCCW.GetDisplayName: string;
begin
   Result := 'WAE DX Contest, CW';
end;

function TContestDARCWAEDCCW.GetCabrilloName: string;
begin
   (* The row's CABName is blank; the Cabrillo header writes the enum's spelling. *)
   Result := 'DARC-WAEDC-CW';
end;

function TContestDARCWAEDCCW.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'DARC-WAEDC-CW';
end;

function TContestDARCWAEDCCW.GetWA7BNMId: integer;
begin
   Result := 85;
end;

function TContestDARCWAEDCCW.GetQRZRUId: integer;
begin
   Result := 15;
end;

function TContestDARCWAEDCCW.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestDARCWAEDCCW.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestDARCWAEDCCW.GetFriendlyName: string;
begin
   Result := 'WAE DX Contest, CW';
end;

function TContestDARCWAEDCCW.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestDARCWAEDCCW.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestDARCWAEDCCW.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestDARCWAEDCCW.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestDARCWAEDCCW.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestDARCWAEDCCW.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestDARCWAEDCCW.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := WAEQSOPointMethod;
end;

function TContestDARCWAEDCCW.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named DARCWAEDCCW, DARCWAEDCSSB; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestDARCWAEDCCW.DescribeSession(const aStation: TStationContext;
                                              aSession: TSessionDefaults);
begin
   if aStation.MyContinent <> Europe then
      begin
      aSession.DXMult := CQEuropeanCountries;
      end
   else
      begin
      aSession.PrefixMult := CQNonEuropeanCountriesAndWAECallRegions;
      end;
   aSession.Band := Band80;
   aSession.ContactsPerPage := 40;
   aSession.QTCEnable := True;
end;

(* THE QTC FUNCTIONS MENU IS OFFERED -- MainUnit.CreateMainWindow greyed it
   for every contest but DARCWAEDCCW..DARCWAEDCSSB, moved here at M9a
   (2026-10-02). Each WAE running holds its own copy (design 1.4). *)
function TContestDARCWAEDCCW.GetOffersQTCs: boolean;
begin
   Result := True;
end;

(* THE CANONICAL RECEIVED EXCHANGE -- uExchangeBuilder's arm for this
   contest, moved here at M9a (2026-10-02): the RST and the serial, the
   arm it shared with CQ WPX. The SSB running was never named there, and
   is not here. See TContestBase.CanonicalReceivedExchange; the caller
   collapses the whitespace. *)
function TContestDARCWAEDCCW.CanonicalReceivedExchange(const aQso: ContestExchange): string;
begin
   Result := RSTReceivedText(aQso) + ' ' + IntToStr(aQso.NumberReceived);
end;

initialization
   RegisterContest(DARCWAEDCCW, TContestDARCWAEDCCW);

end.
