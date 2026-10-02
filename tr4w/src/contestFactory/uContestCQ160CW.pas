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

(* THE CQ 160-METER CONTEST, CW.

  The ContestsArray row this class states, verbatim:

   Email: '160CW@kkn.net';  DF: 's48p14dc';  WA7BNM: 232;  QRZRUID: 311;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: ZoneInitialExchange;  DM: DomesticFile;  P: 0;
   AE: RSTZoneOrDomesticQTH;  XM: CQDXCCWithNoUSAOrCanada;  QP: CQ160QSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: 'CQ 160-Meter Contest, CW'

  Blank CABName and ADIFName resolve to the enum's spelling, 'CQ-160-CW'.

  WHY IT HAS A CLASS NOW. M5a (2026-10-01) moved ADIF import interpretation
  onto the contest, and this contest's rule was an arm of a `case ceContest`
  in the main unit -- which a base may never contain. A class to hold that
  rule needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record but
  `contest.class` is unchanged, which is the proof. EXCHANGE PARSING (M5b) and
  set-up (M7a) have moved since.

  SCORING, transcribed from CQ160QSOPointMethod (4.77.6):

      same country 2, else same continent 5, else 10.
  ITS IMPORT: SRX_STRING is the domestic QTH. (The arm it came from named five
  contests, CQ 160 CW and SSB, UBA CW and SSB and ARRL 160; each owns its own
  copy of the body -- design 1.4.) *)
unit uContestCQ160CW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCQ160CW = class(TContestBase)
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
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
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
   public
      (* THE CANONICAL RECEIVED EXCHANGE -- see
         TContestBase.CanonicalReceivedExchange (M9a). *)
      function CanonicalReceivedExchange(const aQso: ContestExchange): string; override;
   end;

implementation

uses
   SysUtils, uContestRegistry,
   uTR4WStrings,
   uCanonicalExchange;

procedure TContestCQ160CW.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if rxCty = Station.MyCountry then
      begin
      aQso.QSOPoints := 2;
      end
   else if (rxCty <> Station.MyCountry) and
           (aQso.QTH.Continent = Station.MyContinent) then
      begin
      aQso.QSOPoints := 5;
      end
   else
      begin
      aQso.QSOPoints := 10;
      end;
end;

procedure TContestCQ160CW.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                          const aSession: TADIFImportSession;
                                          var aExch: ContestExchange);
begin
   aExch.DomesticQTH := ShortString(aTemps.SRX_String);
end;

function TContestCQ160CW.GetDisplayName: string;
begin
   Result := 'CQ 160-Meter Contest, CW';
end;

function TContestCQ160CW.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'CQ-160-CW';
end;

function TContestCQ160CW.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'CQ-160-CW';
end;

function TContestCQ160CW.GetWA7BNMId: integer;
begin
   Result := 232;
end;

function TContestCQ160CW.GetQRZRUId: integer;
begin
   Result := 311;
end;

function TContestCQ160CW.GetSubmissionEmail: string;
begin
   Result := '160CW@kkn.net';
end;

function TContestCQ160CW.GetDomesticFileName: string;
begin
   Result := 's48p14dc';
end;

function TContestCQ160CW.GetFriendlyName: string;
begin
   Result := 'CQ 160-Meter Contest, CW';
end;

function TContestCQ160CW.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestCQ160CW.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestCQ160CW.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCCWithNoUSAOrCanada;
end;

function TContestCQ160CW.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestCQ160CW.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestCQ160CW.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneOrDomesticQTH;
end;

function TContestCQ160CW.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := CQ160QSOPointMethod;
end;

function TContestCQ160CW.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named CQ160SSB, CQ160CW; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestCQ160CW.DescribeSession(const aStation: TStationContext;
                                          aSession: TSessionDefaults);
begin
   aSession.MultipleBands := False;
   aSession.AddDomesticCountries(DomesticCountriesKVE);
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestCQ160CW.CQExchangeDefault(const aStation: TStationContext): string;
begin
   if aStation.MyState <> '' then
      begin
      Result := ' 5NN ' + aStation.MyState;
      end
   else
      begin
      Result := ' 5NN ' + aStation.MyZoneText;
      end;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ARRL10, ARRL160,
   ARRL_RTTY_ROUNDUP, CQ160SSB, CQWWRTTY.
   The same steps on ticking the box stood for CQ160SSB, CQWWRTTY.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestCQ160CW.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_NORTHAMERICA);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERSTATEFORUSPROVINCEFORCANADA, ncfMyState);
end;

(* THE CANONICAL RECEIVED EXCHANGE -- uExchangeBuilder's arm for this
   contest, moved here at M9a (2026-10-02): the RST and the state or
   section. The SSB running was never named there, and is not here. See
   TContestBase.CanonicalReceivedExchange; the caller collapses the
   whitespace. *)
function TContestCQ160CW.CanonicalReceivedExchange(const aQso: ContestExchange): string;
begin
   Result := RSTReceivedText(aQso) + ' ' + Trim(string(aQso.QTHString));
end;

initialization
   RegisterContest(CQ160CW, TContestCQ160CW);

end.
