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
  InitialExchangeEntry asks it once nothing else has filled the exchange.

  THE 2027 RULES (SRR, the Russian-language "RUSSIAN DX CONTEST 2027" rules, rdxc.org,
  read 2026-10-22; built under NY4I's standing ruling of that day, "if the
  rules say to do something, then we can abide by it"). Each is stated
  below, where it acts:

    7.3  Kaliningrad (UA2F), Franz Josef Land (RI1FJ...) and the Russian
         stations in Antarctica (RI1AN...) are each a separate DXCC territory
         AND a separate oblast -- a double multiplier -- and score "as
         European Russia". (Q97, Q132)
    7.4  A /MM station scores 5 for everybody and is not a multiplier. (Q133)
    7.6  Countries and continents for POINTS are by the DXCC list.
    9    The multiplier is the territories (the DXCC list PLUS the WAE
         multiplier list) plus the Russian oblasts, FJ and AN among them.
         (Q131)
    11.5 Logs only through https://ua9qcq.ru/submit_log.php; questions to
         rdxc@srr.ru or mail@rdxc.org (14.2). (Q135)

  The 89 subjects of the appendix (Q134) are target/dom/russian.dom; the
  four it lacked -- DO, HE, LU, ZP -- were added with their codes from
  rdxc.org/info (Wayback snapshot 2025-11-16).

  NOT BUILT, REPORTED: rule 11.4 makes LOCATION: <oblast> mandatory in a
  Russian station's Cabrillo header. TR4W writes LOCATION only from the
  Cabrillo summary window, and RequiresCabrilloLocation is a station-blind
  answer asked of ContestIdentity, so it cannot say "for a Russian station
  only". *)
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
      (* RULE 7.4: A /MM STATION IS NOT A MULTIPLIER -- see
         TContestBase.CountsAsMultiplier (M8). *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;
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
   uTR4WStrings,
   SysUtils;

type
   (* RULE 7.3'S THREE TERRITORIES -- each its own DXCC territory and its own
      oblast, each scored as European Russia. *)
   TRDXCTerritory = (rdxcNone, rdxcKaliningrad, rdxcFranzJosefLand, rdxcRussianAntarctica);

   (* RULE 7.6 AGAINST RULE 9: the CTY country list is DXCC + WAE (rule 9's
      multiplier), so a WAE-only entity arrives as its own '*' CTY entity --
      but POINTS are by the DXCC list. Each row names a WAE-only entity and
      the DXCC country and continent CTY.DAT gives the same call under the
      DXCC list (ARRLCountryMode), which is what this contest scored it as
      before Q131. *)
   TWAEParent = record
      WAEEntity: string;
      DXCCCountry: string;
      DXCCContinent: ContinentType;
   end;

const
   (* CTY.DAT's ids for rule 7.3's two non-CTY-entity territories: Franz Josef
      Land's entity, and Antarctica's -- RI1AN... is "a separate DXCC territory",
      and Antarctica is the DXCC entity it stands in. Both are already this
      contest's domestic countries (DescribeSession). *)
   FRANZ_JOSEF_LAND_ENTITY = 'R1FJ';
   ANTARCTICA_ENTITY       = 'CE9';
   KALININGRAD_ENTITY      = 'UA2';

   (* The DARC WAE list's entities that are not DXCC entities, as CTY.DAT
      marks them ('*'), with their DXCC parents. *)
   WAE_PARENTS: array[0..5] of TWAEParent = (
      (WAEEntity: '*IT9';  DXCCCountry: 'I';  DXCCContinent: Europe),
      (WAEEntity: '*IG9';  DXCCCountry: 'I';  DXCCContinent: Europe),
      (WAEEntity: '*GM/s'; DXCCCountry: 'GM'; DXCCContinent: Europe),
      (WAEEntity: '*JW/b'; DXCCCountry: 'JW'; DXCCContinent: Europe),
      (WAEEntity: '*4U1V'; DXCCCountry: 'OE'; DXCCContinent: Europe),
      (WAEEntity: '*TA1';  DXCCCountry: 'TA'; DXCCContinent: Asia));

(* WHICH OF RULE 7.3'S TERRITORIES, IF ANY. The rule names RI1FJ... and RI1AN...
   by CALL, so the call decides for those two -- whatever CTY.DAT resolves it
   to. MEASURED 2026-10-22 with the shipped CTY.DAT, in both country modes:
   RI1FJA, RI1FJL, R1FJL and RI1ANA all resolve to UA (ctyLocateCall rewrites
   R[B-Z] to RA before its prefix walk, so CTY's RI1F and RI1AN prefixes are
   never reached); only the exact =RI1ANC/=RI1ANI/=RI1ANY reach CE9.
   Kaliningrad is a CTY.DAT entity of its own, so the country decides; so
   does Franz Josef Land's entity for a call CTY.DAT files there. *)
function RDXCTerritoryOf(const aCall: string; const aCountryID: string): TRDXCTerritory;
var
   call: string;
begin
   call := UpperCase(Trim(aCall));
   if Copy(call, 1, 5) = 'RI1AN' then
      begin
      Result := rdxcRussianAntarctica;
      end
   else if (Copy(call, 1, 5) = 'RI1FJ') or (aCountryID = FRANZ_JOSEF_LAND_ENTITY) then
      begin
      Result := rdxcFranzJosefLand;
      end
   else if aCountryID = KALININGRAD_ENTITY then
      begin
      Result := rdxcKaliningrad;
      end
   else
      begin
      Result := rdxcNone;
      end;
end;

(* THE COUNTRY AND CONTINENT A STATION SCORES AS -- rules 7.3 and 7.6. A
   rule 7.3 territory is European Russia; a WAE-only entity is its DXCC
   parent; anything else is what CTY.DAT said. Asked of both ends of the
   QSO, so a Kaliningrad entrant working UA is "own country" (2), as the
   rule says. An unknown '*' entity (a WAE row CTY.DAT adds later) is left
   as CTY.DAT gave it. *)
procedure RDXCPointsCountry(const aCall: string;
                            const aCountryID: string;
                            aContinent: ContinentType;
                            out aCountry: string;
                            out aPointsContinent: ContinentType);
var
   i: integer;
begin
   aCountry := aCountryID;
   aPointsContinent := aContinent;
   if RDXCTerritoryOf(aCall, aCountryID) <> rdxcNone then
      begin
      aCountry := 'UA';
      aPointsContinent := Europe;
      Exit;
      end;
   for i := Low(WAE_PARENTS) to High(WAE_PARENTS) do
      begin
      if aCountryID = WAE_PARENTS[i].WAEEntity then
         begin
         aCountry := WAE_PARENTS[i].DXCCCountry;
         aPointsContinent := WAE_PARENTS[i].DXCCContinent;
         Exit;
         end;
      end;
end;

(* A STATION'S OBLAST FROM ITS CALL, FOR THIS CONTEST: rule 7.3's FJ and AN,
   then the one rule (Q50), uCallSignRoutines.RussianStationOblast -- which
   reads R1FJ's '1F' as St Petersburg and knows nothing of RI1AN. *)
function RDXCOblastFromCall(const aCall: string; const aCountryID: string): string;
begin
   case RDXCTerritoryOf(aCall, aCountryID) of
      rdxcRussianAntarctica:
         begin
         Result := 'AN';
         end;
      rdxcFranzJosefLand:
         begin
         Result := 'FJ';
         end;
   else
      begin
      Result := RussianStationOblast(aCall, aCountryID);
      end;
   end;
end;

(* RULES 7.1-7.4 (2027). A Russian station: another continent 5 (Russia of
   another continent included), another country of its own continent 3, its
   own country 2. Anybody else: a Russian station 10, another continent 5,
   another country 3, its own 2. Both ends are scored as RDXCPointsCountry
   says (7.3, 7.6), and a /MM station is 5 for everybody (7.4). *)
procedure TContestRussianDX.CalculateQSOPoints(var aQso: ContestExchange);
var
   myCountry: string;
   myContinent: ContinentType;
   rxCountry: string;
   rxContinent: ContinentType;
begin
   if MaritimeMobileStation(string(aQso.Callsign)) then
      begin
      aQso.QSOPoints := 5;
      Exit;
      end;

   RDXCPointsCountry(Station.MyCall, string(Station.MyCountry), Station.MyContinent,
                     myCountry, myContinent);
   RDXCPointsCountry(string(aQso.Callsign), string(aQso.QTH.CountryID), aQso.QTH.Continent,
                     rxCountry, rxContinent);

   if RussianID(myCountry) then
      begin
      if rxContinent <> myContinent then
         begin
         aQso.QSOPoints := 5;
         end
      else if rxCountry <> myCountry then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      end
   else if RussianID(rxCountry) then
      begin
      aQso.QSOPoints := 10;
      end
   else if rxContinent <> myContinent then
      begin
      aQso.QSOPoints := 5;
      end
   else if rxCountry <> myCountry then
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
   'UA' alone as the M5b transcription of ZoneCont's dead arm said. Rule 7.3
   (Q97, 2026-10-22): a Franz Josef Land call answers FJ and an RI1AN... call
   AN -- RI1AN is a Russian station whatever CTY.DAT files it under. *)
function TContestRussianDX.InitialExchangeFromCall(const aCall: string;
                                                   const aCountryID: string;
                                                   out aExchange: string): boolean;
begin
   Result := RussianID(aCountryID) or
             (RDXCTerritoryOf(aCall, aCountryID) <> rdxcNone);
   aExchange := RDXCOblastFromCall(aCall, aCountryID);
end;

function TContestRussianDX.DomesticMultiplierFromCall(const aCall: string;
                                                      const aLookups: TMultiplierHintLookups): string;
begin
   Result := '';
   if Assigned(aLookups.CountryOfCall) then
      begin
      Result := RDXCOblastFromCall(aCall, aLookups.CountryOfCall(aCall));
      end;
end;

(* RULE 7.4 (2027): contacts with any "/MM" station "are not a multiplier" --
   a /MM station earns no multiplier of any kind. *)
function TContestRussianDX.CountsAsMultiplier(const aQso: ContestExchange;
                                              aKind: RemainingMultiplierType): boolean;
begin
   Result := not MaritimeMobileStation(string(aQso.Callsign));
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
   (* NO E-MAIL SUBMISSION -- rule 11.5 (2027): logs "are accepted in
      electronic form only through the web interface:
      https://ua9qcq.ru/submit_log.php". Questions go to rdxc@srr.ru or
      mail@rdxc.org (rule 14.2), which is not where a log goes. The row said
      'logs@rdxc.org' (Q135, 2026-10-22). *)
   Result := '';
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
   Every territory counts: the key is the CTY country, from the DXCC + WAE
   list (CountryMode, rule 9) -- except rule 7.3's Franz Josef Land and
   RI1AN..., which are each "a separate DXCC territory" whatever CTY.DAT files
   the call under (Q97, 2026-10-22). Kaliningrad is CTY.DAT's own UA2. *)
function TContestRussianDX.DXMultiplierKey(const aQso: ContestExchange;
                                           out aKey: DXMultiplierString): boolean;
begin
   case RDXCTerritoryOf(string(aQso.Callsign), string(aQso.QTH.CountryID)) of
      rdxcFranzJosefLand:
         begin
         aKey := FRANZ_JOSEF_LAND_ENTITY;
         end;
      rdxcRussianAntarctica:
         begin
         aKey := ANTARCTICA_ENTITY;
         end;
   else
      begin
      aKey := aQso.QTH.CountryID;
      end;
   end;
   Result := True;
end;

(* THE CTY COUNTRY LIST -- rule 9 (2027): "the number of territories (the
   DXCC list + the WAE multiplier list)". CQCountryMode is CTY.DAT's DXCC + WAE list, the
   one CQ WW counts (Q131, 2026-10-22). It was ARRLCountryMode, DXCC only,
   since D7. Points stay on the DXCC list (rule 7.6): RDXCPointsCountry maps
   a WAE-only entity back to its DXCC parent. *)
function TContestRussianDX.CountryMode: CountryModeType;
begin
   Result := CQCountryMode;
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
