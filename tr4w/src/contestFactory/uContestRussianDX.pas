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

(* THE RUSSIAN DX CONTEST (RDXC).

  The ContestsArray row this class states, verbatim:

   Email: 'logs@rdxc.org';  DF: 'russian';  WA7BNM: 310;  QRZRUID: 7;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: DomesticFile;  P: 0;
   AE: RSTDomesticQTHOrQSONumberExchange;  XM: ARRLDXCC;  QP: RussianDXQSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: 'Russian DX Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'RDXC'.

  WHY IT HAS A CLASS NOW. M5b (2026-10-02): this contest's initial-exchange
  rule was a test of ActiveQSOPointMethod in ZoneCont.GetVEInitialExchange --
  which an operator's QSO POINT METHOD line reached in any contest. A class to
  hold that rule needed the whole row and the scoring arm with it, because
  registering a class makes the class this contest's scorer too. Both are
  transcribed exactly; Test_MovedRowValuesStillMatchTheArray holds the row,
  and the contest matrix the rest -- every line of its record but
  `contest.class` is unchanged, which is the proof.

  A COPY OF THE RU3AX MEMORIAL'S CLASS, AND DELIBERATELY SO (design 1.4). They
  shared one scoring arm, which doubled phone for the RU3AX Memorial by
  asking `if Contest = RU3AXMEMORIAL` inside it; each contest now states its
  own rule and that test is not needed by either.

  SCORING, transcribed from RussianDXQSOPointMethod. A Russian station
  scores 5 for another continent, 3 for another country of its own continent
  and 2 for its own country. Anybody else scores 10 for a Russian station,
  then 5, 3 and 2 the same way.
  ITS INITIAL EXCHANGE AND ITS NEED-MULTIPLIER HINT: a Russian station's
  oblast, from its call -- uCallSignRoutines.RussianStationOblast, the one
  rule NY4I ruled on Q50 (2026-10-15): RussianID of the CTY.DAT country
  decides, and GetRussiaOblastID of the call answers. LOGEDIT's
  InitialExchangeEntry asks it once nothing else has filled the exchange. *)
unit uContestRussianDX;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRussianDX = class(TContestBase)
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
      procedure WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters); override;
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
      (* A RUSSIAN STATION'S OBLAST -- see the header. *)
      function InitialExchangeFromCall(const aCall: string;
                                       const aCountryID: string;
                                       out aExchange: string): boolean; override;

      (* A RUSSIAN STATION'S OBLAST, FOR THE NEED-MULTIPLIER HINT -- the arm
         LOGEDIT.GetMultArray held for this contest beside the two RF
         Championships, moved here at M8. It asked RussianID of the raw CALL;
         since Q50 was ruled (NY4I, 2026-10-15) it asks the same one rule as
         InitialExchangeFromCall above -- uCallSignRoutines.RussianStationOblast,
         with the call's CTY.DAT country from aLookups.CountryOfCall. No
         country service, no hint. *)
      function DomesticMultiplierFromCall(const aCall: string;
                                          const aLookups: TMultiplierHintLookups): string; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   protected
      (* THE TOTALS WINDOW -- see TContestBase.TotalsDisplay (M9a). *)
      function GetTotalsDisplay: TTotalsDisplay; override;
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
   (* RussianID, RussianStationOblast -- the scoring arm's leaf, and the one
      oblast rule (Q50). *)
   uCallSignRoutines,
   uTR4WStrings;

procedure TContestRussianDX.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if RussianID(Station.MyCountry) then
      begin
      if aQso.QTH.Continent <> Station.MyContinent then
         begin
         aQso.QSOPoints := 5;
         end
      else if rxCty <> Station.MyCountry then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      end
   else if RussianID(rxCty) then
      begin
      aQso.QSOPoints := 10;
      end
   else if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 5;
      end
   else if rxCty <> Station.MyCountry then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;
end;

(* Q50 (NY4I, 2026-10-15): the one rule, RussianStationOblast. True for any
   Russian station, as LOGEDIT's fallback was -- the CTY.DAT country, not
   'UA' alone as the M5b transcription of ZoneCont's dead arm said. *)
function TContestRussianDX.InitialExchangeFromCall(const aCall: string;
                                                   const aCountryID: string;
                                                   out aExchange: string): boolean;
begin
   Result := RussianID(aCountryID);
   aExchange := RussianStationOblast(aCall, aCountryID);
end;

function TContestRussianDX.DomesticMultiplierFromCall(const aCall: string;
                                                      const aLookups: TMultiplierHintLookups): string;
begin
   Result := '';
   if Assigned(aLookups.CountryOfCall) then
      begin
      Result := RussianStationOblast(aCall, aLookups.CountryOfCall(aCall));
      end;
end;

function TContestRussianDX.GetDisplayName: string;
begin
   Result := 'Russian DX Contest';
end;

function TContestRussianDX.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'RDXC';
end;

function TContestRussianDX.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'RDXC';
end;

function TContestRussianDX.GetWA7BNMId: integer;
begin
   Result := 310;
end;

function TContestRussianDX.GetQRZRUId: integer;
begin
   Result := 7;
end;

function TContestRussianDX.GetSubmissionEmail: string;
begin
   Result := 'logs@rdxc.org';
end;

function TContestRussianDX.GetDomesticFileName: string;
begin
   Result := 'russian';
end;

function TContestRussianDX.GetFriendlyName: string;
begin
   Result := 'Russian DX Contest';
end;

function TContestRussianDX.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRussianDX.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHOrQSONumberExchange;
end;

function TContestRussianDX.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestRussianDX.ParseReceivedExchangeFormat(const aText: string;
                                                       aParsers: TExchangeParsers;
                                                       var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTHOrQSONumber(aText, aExch);
end;

procedure TContestRussianDX.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTStateOrQSONumber;
end;

function TContestRussianDX.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestRussianDX.GetADIFSentExchange(const aMy: TMyStationExchange;
                                               const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrQSONumber(aMy, aQso);
end;

function TContestRussianDX.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrQSONumber(aMy, aQso, aCtx);
end;

function TContestRussianDX.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHOrQSONumber(aMy, aQso, aCtx);
end;

function TContestRussianDX.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand,
              cfQSOByMode,
              cfMultByBand,
              cfCountsDomesticCountries];
end;

function TContestRussianDX.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named RUSSIANDX, RU3AXMEMORIAL; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestRussianDX.DescribeSession(const aStation: TStationContext;
                                            aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountries(DomesticCountriesRussia);
   aSession.AddDomesticCountry('CE9');
   if not RussianID(string(aStation.MyCountry)) then
      begin
      aSession.SentState := '';
      end;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for RDA, RU3AXMEMORIAL.
   The same steps on ticking the box stood for CIS, RU3AXMEMORIAL,
   UKRAINIAN, UNDX.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestRussianDX.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_RUSSIA);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOUROBLASTID, ncfMyState);
end;

(* THE TOTALS WINDOW LABELS THE DOMESTIC MULTIPLIERS AS OBLASTS -- uTotal's
   arm, moved here at M9a (2026-10-02). It named RUSSIANDX and RU3AXMEMORIAL;
   each holds its own copy (design 1.4). Per mode the labels are the
   default ones, as they always were. *)
function TContestRussianDX.GetTotalsDisplay: TTotalsDisplay;
begin
   Result := inherited GetTotalsDisplay;
   Result.DomesticMultsCaption := TC_OBLASTS;
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`ARRLDXCC`) until the kind was deleted. *)
function TContestRussianDX.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country counts: the key is the CTY country -- GetDXQTH's `else`
   arm, for the session's ARRLDXCC. *)
function TContestRussianDX.DXMultiplierKey(const aQso: ContestExchange;
                                           out aKey: DXMultiplierString): boolean;
begin
   aKey := aQso.QTH.CountryID;
   Result := True;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only, at every station -- the ARRLDXCC kind was in the ARRL set. *)
function TContestRussianDX.CountryMode: CountryModeType;
begin
   Result := ARRLCountryMode;
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestRussianDX.UsesDomesticFile: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(RUSSIANDX, TContestRussianDX);

end.
