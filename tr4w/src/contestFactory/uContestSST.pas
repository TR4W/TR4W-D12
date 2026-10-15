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

(* THE K1USN SLOW SPEED TEST.

  The ContestsArray row this class states, verbatim:

   Email: 'k1usn.radioclub.sst@gmail.com';  DF: 'naqp';  WA7BNM: 681;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NameQTHInitialExchange;
   DM: DomesticFile;  P: 0;  AE: NameAndDomesticOrDXQTHExchange;
   XM: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7;  QP: OnePointPerQSO;
   ADIFName: 'K1USN-SST';  CABName: 'K1USNSST';
   FriendlyName: 'K1USN Slow Speed Test'

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: OnePointPerQSO -- 1 in every mode.

  SET-UP: the contest name 'Slow Speed Test', domestic multipliers from
  the file, K and VE as domestic countries, and the CQ and S&P exchanges as
  MY NAME and MY STATE.

  NOT MOVED, ON PURPOSE: uExchangeBuilder's HamScore received exchange
  (name and state) names it beside the NAQP runnings, which have had
  classes since M5a -- a seam not built yet (M9). *)
unit uContestSST;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestSST = class(TContestBase)
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
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* THE CANONICAL RECEIVED EXCHANGE -- see
         TContestBase.CanonicalReceivedExchange (M9a). *)
      function CanonicalReceivedExchange(const aQso: ContestExchange): string; override;
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
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uDXMultiplierKey,
   uContestRegistry,
   uContestFixedPoints,
   uTR4WStrings,
   SysUtils,
   uCanonicalExchange;

(* OnePointPerQSO -- the legacy LOGSTUFF arm for this
   contest's point method, moved here as it stood (M7b batch 2). The arm
   was deleted at M10 S3; see git history or the D7 tree. *)
procedure TContestSST.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestSST.GetDisplayName: string;
begin
   Result := 'K1USN Slow Speed Test';
end;

function TContestSST.GetCabrilloName: string;
begin
   Result := 'K1USNSST';
end;

function TContestSST.GetADIFContestId: string;
begin
   Result := 'K1USN-SST';
end;

function TContestSST.GetWA7BNMId: integer;
begin
   Result := 681;
end;

function TContestSST.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestSST.GetSubmissionEmail: string;
begin
   Result := 'k1usn.radioclub.sst@gmail.com';
end;

function TContestSST.GetDomesticFileName: string;
begin
   Result := 'naqp';
end;

function TContestSST.GetFriendlyName: string;
begin
   Result := 'K1USN Slow Speed Test';
end;

function TContestSST.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NameQTHInitialExchange;
end;

function TContestSST.GetExchangeKind: ExchangeType;
begin
   Result := NameAndDomesticOrDXQTHExchange;
end;

function TContestSST.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNameQTH;
end;

function TContestSST.ParseReceivedExchangeFormat(const aText: string;
                                                 aParsers: TExchangeParsers;
                                                 var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseNameAndDomesticOrDXQTH(aText, aExch);
end;

function TContestSST.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestSST.GetADIFSentExchange(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange): string;
begin
   Result := ADIFSentNameState(aMy, aQso);
end;

function TContestSST.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange;
                                             const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentNameState(aMy, aQso, aCtx);
end;

function TContestSST.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange;
                                                 const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedNameQTH(aMy, aQso, aCtx);
end;

function TContestSST.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfMultByBand, cfRTCCapable];
end;

function TContestSST.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestSST.DescribeSession(const aStation: TStationContext;
                                      aSession: TSessionDefaults);
begin
   aSession.ContestName := 'Slow Speed Test';
   (* DomesticFile is the trait's, which this restated until M11 S2. *)
   aSession.AddDomesticCountries(DomesticCountriesKVE);
   aSession.CQExchangeCW := ' ' + aStation.MyName + ' ' + aStation.MyState;
   aSession.SPExchangeCW := aStation.MyName + ' ' + aStation.MyState;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for NAQSOCW, NAQSORTTY, NAQSOSSB.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestSST.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURNAMEANDSTATE, ncfMyState);
   aPrompts.AskField(ncfMyName);
end;

(* THE CANONICAL RECEIVED EXCHANGE -- uExchangeBuilder's arm for this
   contest, moved here at M9a (2026-10-02): the name and the state (or
   DX), rebuilt from the fields so an edit to either reaches the
   scoreboard (2026-05-28). The arm named SST and the three NAQP runnings;
   each holds its own copy (design 1.4). See
   TContestBase.CanonicalReceivedExchange; the caller collapses the
   whitespace. *)
function TContestSST.CanonicalReceivedExchange(const aQso: ContestExchange): string;
begin
   Result := Trim(string(aQso.Name)) + ' ' + Trim(string(aQso.QTHString));
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`NorthAmericanARRLDXCCWithNoUSACanadaOrkL7`) until the
   kind was deleted. *)
function TContestSST.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   North American countries other than the USA, Canada and Alaska -- the
   NorthAmericanARRLDXCCWithNoUSACanadaOrkL7 arm. The CQ list, whatever the
   kind's name: the country-mode set never held it. *)
function TContestSST.DXMultiplierKey(const aQso: ContestExchange;
                                     out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if IsNorthAmericanDXCountry(aQso.QTH.CountryID, aQso.QTH.Continent) then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestSST.UsesDomesticFile: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(SST, TContestSST);

end.
