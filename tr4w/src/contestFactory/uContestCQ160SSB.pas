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

(* THE CQ 160-METER CONTEST, SSB.

  The ContestsArray row this class states, verbatim:

   Email: '160SSB@kkn.net';  DF: 's48p14dc';  WA7BNM: 259;  QRZRUID: 312;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: ZoneInitialExchange;  DM: DomesticFile;  P: 0;
   AE: RSTZoneOrDomesticQTH;  XM: CQDXCCWithNoUSAOrCanada;  QP: CQ160QSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: 'CQ 160-Meter Contest, SSB'

  Blank CABName and ADIFName resolve to the enum's spelling, 'CQ-160-SSB'.

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
unit uContestCQ160SSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCQ160SSB = class(TContestBase)
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
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function ParseReceivedExchangeFormat(const aText: string;
                                           aParsers: TExchangeParsers;
                                           var aExch: ContestExchange): boolean; override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
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
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
   public
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
      function ExchangeCarriesZone: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uDXMultiplierKey,
   SysUtils, uContestRegistry,
   uTR4WStrings;

procedure TContestCQ160SSB.CalculateQSOPoints(var aQso: ContestExchange);
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

procedure TContestCQ160SSB.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                           const aSession: TADIFImportSession;
                                           var aExch: ContestExchange);
begin
   aExch.DomesticQTH := ShortString(aTemps.SRX_String);
end;

function TContestCQ160SSB.GetDisplayName: string;
begin
   Result := 'CQ 160-Meter Contest, SSB';
end;

function TContestCQ160SSB.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'CQ-160-SSB';
end;

function TContestCQ160SSB.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'CQ-160-SSB';
end;

function TContestCQ160SSB.GetWA7BNMId: integer;
begin
   Result := 259;
end;

function TContestCQ160SSB.GetQRZRUId: integer;
begin
   Result := 312;
end;

function TContestCQ160SSB.GetSubmissionEmail: string;
begin
   Result := '160SSB@kkn.net';
end;

function TContestCQ160SSB.GetDomesticFileName: string;
begin
   Result := 's48p14dc';
end;

function TContestCQ160SSB.GetFriendlyName: string;
begin
   Result := 'CQ 160-Meter Contest, SSB';
end;

function TContestCQ160SSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestCQ160SSB.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneOrDomesticQTH;
end;

function TContestCQ160SSB.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTZoneQTH;
end;

function TContestCQ160SSB.ParseReceivedExchangeFormat(const aText: string;
                                                      aParsers: TExchangeParsers;
                                                      var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTZoneOrDomesticQTH(aText, aExch);
end;

function TContestCQ160SSB.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestCQ160SSB.ExchangeCarriesZone: boolean;
begin
   Result := True;
end;

function TContestCQ160SSB.GetADIFSentExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTZoneOrState(aMy, aQso);
end;

function TContestCQ160SSB.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                  const aQso: ContestExchange;
                                                  const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrZone(aMy, aQso, aCtx);
end;

function TContestCQ160SSB.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                      const aQso: ContestExchange;
                                                      const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHOrZone(aMy, aQso, aCtx);
end;

function TContestCQ160SSB.GetFlags: TContestFlags;
begin
   Result := [cfCQZoneMode];
end;

function TContestCQ160SSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named CQ160SSB, CQ160CW; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestCQ160SSB.DescribeSession(const aStation: TStationContext;
                                           aSession: TSessionDefaults);
begin
   aSession.MultipleBands := False;
   aSession.AddDomesticCountries(DomesticCountriesKVE);
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestCQ160SSB.CQExchangeDefault(const aStation: TStationContext): string;
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
   ARRL_RTTY_ROUNDUP, CQ160CW, CQWWRTTY.
   The same steps on ticking the box stood for CQ160CW, CQWWRTTY.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestCQ160SSB.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_NORTHAMERICA);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERSTATEFORUSPROVINCEFORCANADA, ncfMyState);
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`CQDXCCWithNoUSAOrCanada`) until the kind was deleted. *)
function TContestCQ160SSB.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country but the USA and Canada -- the CQDXCCWithNoUSAOrCanada arm. *)
function TContestCQ160SSB.DXMultiplierKey(const aQso: ContestExchange;
                                          out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if not IsUSAOrCanadaCountry(aQso.QTH.CountryID) then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestCQ160SSB.UsesDomesticFile: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(CQ160SSB, TContestCQ160SSB);

end.
