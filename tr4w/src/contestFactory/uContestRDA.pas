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

(* THE RUSSIAN DISTRICT AWARD CONTEST (RDAC).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 94;  QRZRUID: 386;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: RDADistrict;  P: 0;  AE: RSTDomesticQTHOrQSONumberExchange;
   XM: ARRLDXCC;  QP: RDAQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'Russian District Award Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'RDAC'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: RDAQSOPointMethod -- a Russian station: another Russian 1 (2 on
  another continent), or 10 for a portable one (a call ending /P); anyone
  else 3 on our continent and 5 off it. Anyone else: a Russian station 10,
  everything else 0.

  SET-UP: the Russian domestic countries, domestic multipliers counted
  over all bands, and -- for a station outside Russia only -- no DX
  multiplier. The Russian station's DX multiplier is left as the head set
  it, as the arm left it.

  NOT MOVED, ON PURPOSE: LOGEDIT names this contest twice -- in the
  new-multiplier check that reads the initial exchange of a Russian call,
  and in the initial exchange's oblast fallback beside the Russian DX
  contests. Both are seams not built yet (M8, the multiplier sheet; the
  Russian DX contests, registered since M5b, are still named in the same
  routines). *)
unit uContestRDA;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRDA = class(TContestBase)
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
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;

      (* THE DISTRICT THE LOG REMEMBERS FOR A RUSSIAN CALL, FOR THE
         NEED-MULTIPLIER HINT -- the arm LOGEDIT.GetMultArray held for this
         contest, moved here at M8 and transcribed exactly: RussianID of the
         CALL, then the initial exchange the session holds for it
         (CallsignsList, through aLookups.InitialExchangeOf). *)
      function DomesticMultiplierFromCall(const aCall: string;
                                          const aLookups: TMultiplierHintLookups): string; override;
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
      (* THE DOMESTIC QTH -- see TContestBase.DomesticMultiplierFromQTH
         (M11 S6). *)
      function DomesticMultiplierFromQTH(const aText: Str20;
                                         var aMultiplier: Str10;
                                         var aQTH: Str10;
                                         var aFound: boolean): TDomesticQTHAnswer; override;
      (* THE NEED-MULTIPLIER HINT -- see
         TContestBase.DomesticMultiplierHint (M11 S6). *)
      function DomesticMultiplierHint(const aText: Str14): string; override;
      (* see TContestBase.DomesticQTHIsNeverAGrid (M11 S6). *)
      function DomesticQTHIsNeverAGrid: boolean; override;
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
   (* RDADistrictKey, DOKKey, GridSquareKey, GridFieldKey -- the shared
      domestic-QTH shapes (M11 S6). *)
   uDomesticKey,
   uContestRegistry,
   uCallSignRoutines,
   uTR4WStrings;

function TContestRDA.DomesticMultiplierFromCall(const aCall: string;
                                                const aLookups: TMultiplierHintLookups): string;
begin
   Result := '';
   if RussianID(aCall) and Assigned(aLookups.InitialExchangeOf) then
      begin
      Result := aLookups.InitialExchangeOf(aCall);
      end;
end;

(* RDAQSOPointMethod -- the legacy LOGSTUFF arm for this
   contest's point method, moved here as it stood (M7b batch 2). The arm
   was deleted at M10 S3; see git history or the D7 tree. *)
procedure TContestRDA.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   aQso.QSOPoints := 0;
   if RussianID(Station.MyCountry) then
      begin
      if RussianID(rxCty) then
         begin
         if Pos('/P', aQso.Callsign) = Length(aQso.Callsign) - 1 then
            begin
            aQso.QSOPoints := 10;
            Exit;
            end;
         aQso.QSOPoints := 1;
         if aQso.QTH.Continent <> Station.MyContinent then
            begin
            aQso.QSOPoints := 2;
            end;
         Exit;
         end;
      if aQso.QTH.Continent = Station.MyContinent then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 5;
         end;
      end
   else if RussianID(rxCty) then
      begin
      aQso.QSOPoints := 10;
      end;
end;

function TContestRDA.GetDisplayName: string;
begin
   Result := 'Russian District Award Contest';
end;

function TContestRDA.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'RDAC';
end;

function TContestRDA.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'RDAC';
end;

function TContestRDA.GetWA7BNMId: integer;
begin
   Result := 94;
end;

function TContestRDA.GetQRZRUId: integer;
begin
   Result := 386;
end;

function TContestRDA.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRDA.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestRDA.GetFriendlyName: string;
begin
   Result := 'Russian District Award Contest';
end;

function TContestRDA.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRDA.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHOrQSONumberExchange;
end;

function TContestRDA.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestRDA.ParseReceivedExchangeFormat(const aText: string;
                                                 aParsers: TExchangeParsers;
                                                 var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTHOrQSONumber(aText, aExch);
end;

procedure TContestRDA.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTStateOrQSONumber;
end;

function TContestRDA.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestRDA.GetADIFSentExchange(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrQSONumber(aMy, aQso);
end;

function TContestRDA.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange;
                                             const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrQSONumber(aMy, aQso, aCtx);
end;

function TContestRDA.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange;
                                                 const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHOrQSONumber(aMy, aQso, aCtx);
end;

function TContestRDA.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand,
              cfQSOByMode,
              cfMultByBand,
              cfErmakSpecification,
              cfCountsDomesticCountries];
end;

function TContestRDA.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestRDA.DescribeSession(const aStation: TStationContext;
                                      aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountries(DomesticCountriesRussia);
   aSession.DomesticMultByBand := dmbbAllBand;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for RU3AXMEMORIAL, RUSSIANDX.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestRDA.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_RUSSIA);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOURRDAID, ncfMyState);
end;

(* THE STATION TEST -- DescribeSession's, asked of Station. See the declaration. *)
function TContestRDA.CountsDXMultiplier: boolean;
begin
   Result := RussianID(string(Station.MyCountry));
end;

(* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- M11 S4 part 2,
   2026-10-14. Yes for a Russian entrant; none for anyone else. This is the
   station test the session's DX kind was chosen by (the trait, then
   DescribeSession) until that kind was deleted; DXMultiplierKey and the
   country list ask the same predicate, so the answers cannot disagree. *)
function TContestRDA.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country, for a Russian entrant (ARRLDXCC, the trait); none for anyone else, whose
   DescribeSession stated NoDXMults. *)
function TContestRDA.DXMultiplierKey(const aQso: ContestExchange;
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
   DXCC only for a Russian entrant; the CQ list for anyone else, who
   counts no DX multiplier. *)
function TContestRDA.CountryMode: CountryModeType;
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


(* THE DOMESTIC QTH -- M11 S6 part 1, 2026-10-14, moved from LOGDOM.GetDomQTH's
   RDADistrict arm (the trait): an RDA district is the multiplier and the
   QTH; anything else is not found, and the domestic file is never
   consulted. *)
function TContestRDA.DomesticMultiplierFromQTH(const aText: Str20;
                                               var aMultiplier: Str10;
                                               var aQTH: Str10;
                                               var aFound: boolean): TDomesticQTHAnswer;
var
   key: ShortString;
begin
   if RDADistrictKey(aText, key) then
      begin
      aMultiplier := key;
      aQTH := key;
      aFound := True;
      end;
   Result := dqaDecided;
end;

(* THE NEED-MULTIPLIER HINT -- M11 S6 part 1, moved from LOGSTUFF.
   DomStringParse's RDADistrict arm: the district, or '' for a text that is
   not one. *)
function TContestRDA.DomesticMultiplierHint(const aText: Str14): string;
var
   key: ShortString;
begin
   if RDADistrictKey(aText, key) then
      begin
      Result := string(key);
      end
   else
      begin
      Result := '';
      end;
end;

(* AN RDA DISTRICT IS NOT A GRID, though it has a grid square's shape --
   M11 S6 part 1, moved from POSTUNIT's `<> RDADistrict`. See
   TContestBase.DomesticQTHIsNeverAGrid. *)
function TContestRDA.DomesticQTHIsNeverAGrid: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(RDA, TContestRDA);

end.
