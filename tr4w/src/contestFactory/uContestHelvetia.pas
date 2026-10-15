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
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   private
      (* DOES THIS ENTRANT COUNT A DX MULTIPLIER? -- the station test
         DescribeSession stated the DX kind under (deleted at M11 S4 part 2);
         HasDXMultiplier, the key and the country list ask it, so the answers
         cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      (* THE CTY COUNTRY LIST -- see TContestBase.CountryMode (M11 S4). *)
      function CountryMode: CountryModeType; override;
   public
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry,
   uTR4WStrings;

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
   Result := 'Helvetia Contest';
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

function TContestHelvetia.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestHelvetia.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHOrQSONumberExchange;
end;

function TContestHelvetia.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestHelvetia.ParseReceivedExchangeFormat(const aText: string;
                                                      aParsers: TExchangeParsers;
                                                      var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTHOrQSONumber(aText, aExch);
end;

function TContestHelvetia.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestHelvetia.GetADIFSentExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrQSONumber(aMy, aQso);
end;

function TContestHelvetia.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                  const aQso: ContestExchange;
                                                  const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrQSONumber(aMy, aQso, aCtx);
end;

function TContestHelvetia.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                      const aQso: ContestExchange;
                                                      const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHOrQSONumber(aMy, aQso, aCtx);
end;

function TContestHelvetia.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand,
              cfQSOByMode,
              cfMultByBand,
              cfCountsDomesticCountries,
              cfRTCCapable];
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

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on ticking the box stood for ARI_DX, CANADA_DAY,
   CANADA_WINTER, KINGOFSPAINCW, KINGOFSPAINSSB, PACC, UBACW, UBASSB.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestHelvetia.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_SWITZERLAND);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOURPROVINCEID, ncfMyState);
end;

(* THE STATION TEST -- DescribeSession's, asked of Station. See the declaration. *)
function TContestHelvetia.CountsDXMultiplier: boolean;
begin
   Result := Station.MyCountry = 'HB';
end;

(* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- M11 S4 part 2,
   2026-10-14. Yes for a Swiss entrant; none for anyone else. This is the
   station test the session's DX kind was chosen by (the trait, then
   DescribeSession) until that kind was deleted; DXMultiplierKey and the
   country list ask the same predicate, so the answers cannot disagree. *)
function TContestHelvetia.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country, for a Swiss entrant (ARRLDXCC, which DescribeSession stated for HB);
   none for anyone else, whose session ran the trait's NoDXMults. *)
function TContestHelvetia.DXMultiplierKey(const aQso: ContestExchange;
                                          out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if CountsDXMultiplier then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only for a Swiss entrant; the CQ list for anyone else, who counts
   no DX multiplier. *)
function TContestHelvetia.CountryMode: CountryModeType;
begin
   if CountsDXMultiplier then
      begin
      Result := ARRLCountryMode;
      end
   else
      begin
      Result := CQCountryMode;
      end;
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestHelvetia.UsesDomesticFile: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(HELVETIA, TContestHelvetia);

end.
