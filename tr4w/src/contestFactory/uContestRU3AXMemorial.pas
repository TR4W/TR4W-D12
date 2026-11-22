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

(* THE RU3AX MEMORIAL -- THE RUSSIAN 160-METER DX CONTEST.

  REBUILT TO THE 2025 RULES (issue 57, 2026-11-22): "RUSSIAN 160m DX Contest
  - RU3AX Memorial RULES'25", docs/ContestRules/Russian 160/rules russian
  160.txt, sponsored by the "Radio" Magazine, TopBand DX Club and the Russian
  Contest Club. The class it replaces was a copy of the Russian DX Contest's
  (country and continent points, an oblast or serial exchange); every rule
  below is quoted from the 2025 text, by its number.

  THE ID, THE NAMES AND THE NUMBERS ARE UNCHANGED, so a log or profile made
  before keeps opening as this contest: the legacy member RU3AXMEMORIAL, the
  ADIF id 'RU3AX MEMORIAL', the Cabrillo CONTEST: RADIO-160 (WA7BNM 202,
  NY4I 2026-10-19), QRZ.RU 90, the domestic file 'russian'.

  1. "on 1.8 MHz amateur band ONLY. Modes: CW and SSB." -- UsesBand,
     UsesMode. "The 1st round from 17:00 to 18:59 UTC / The 2nd round from
     19:00 to 20:59 UTC" -- RU3AXRoundOf.

  4. "All participants send RS(T) + Four character grid square (QTH
     locator) Example: 599 KO85". THE RECEIVED GRID IS QTHString, cut to its
     four characters; the RST-and/or-grid parser reads it and this class
     requires the grid (ParseReceivedExchange). Nobody sends an oblast any
     more -- so THE OBLAST MULTIPLIER COMES FROM THE CALL (rule 7.1 still
     counts oblasts): DomesticQTH / DomMultQTH carry the Russian station's
     oblast, from uRussianTerritories.RDXCOblastFromCall, resolved through the
     russian.dom table; both are empty for anybody else. THE GRID IS NEVER
     DomesticQTH: SetMultFlags keys the domestic multiplier from it, and every
     grid would be an "oblast".

  5.1 "QSO points depend on the distance between participants, which is
     defined as the distance between the centers of their grid squares (QTH
     locators). Minimum number of QSO points is 10. Thereafter, one point is
     added for each 500 km. For example: QSO at distance up to 500 km is 10
     points, from 500 to 1000 km - 11 points, from 1000 to 1500 km - 12
     points" -- RU3AXPointsForDistance: 10 + Trunc(km / 500). The distance is
     uGridDistance.GridHaversineKm, which measures between the geometric
     CENTRES of the two four-character squares -- the rule's words; NOT
     LOGGRID.GetDistanceBetweenGrids, which pads with 'LL' (not the centre).
     A grid that is not one on either end scores 0 (Q37: a malformed grid is
     never measured; the ARRL Digi's guard).
  5.2 "SSB points are multiplied by factor 2."

  6.1 "Dupes are QSOs made in the same mode and in the same round." /
  6.3 "dupe QSOs in different rounds and different modes are allowed." --
     cfQSOByMode, and DupeKeyTour names the round. One band, so by band or not
     is the same thing.

  7.1 "Multiplier is number of territories (DXCC + WAE) plus Russian Oblasts
     number. Separate Russian Oblasts are Franz Joseph (R1FJ) and Russian
     stations in Antarctica (R1AN)." -- the DX key is the CTY country on the
     DXCC + WAE list (CountryMode = CQCountryMode); the oblast as above, with
     FJ and AN by call (uRussianTerritories).
  7.2 "Kaliningrad stations (UA2F) count two mults, - as DXCC and Oblast." --
     falls out: the DX key UA2 and the oblast KA.
  7.3 "Mults are counted separately for CW and SSB, and then summarized." --
     cfMultByMode; the sheet's Both column then counts a multiplier once per
     mode (uMults.IncrementTotals), so the base's sum is the rule's sum.
  7.4 "One multiplier counts only once, regardless of rounds." -- the sheet
     is not keyed on the round.
  8. "Final score is product of summary points by total multiplier." -- the
     base CombineWithMultipliers.

  NOT MODELLED: 2.1's location groups (EU RUS, AS RUS, AS & OC, WORLD -- the
  introduction says three groups, 2.1 lists four) are a results grouping,
  not a scoring rule. 9.7's six-character GRID-LOCATOR header is the station's
  MY GRID, written by the Cabrillo writer for any contest that has one. *)
unit uContestRU3AXMemorial;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

const
   (* Rule 5.1's numbers. *)
   RU3AX_MINIMUM_POINTS = 10;
   RU3AX_KM_PER_POINT   = 500;

(* RULE 5.1, AS ARITHMETIC: 10 points, plus one for each whole 500 km of
   aKm -- 0 to 499.99 km is 10, 500 to 999.99 is 11. A negative distance (none
   is measured) is the minimum. Pure, so the boundaries are pinned without a
   station. *)
function RU3AXPointsForDistance(aKm: Double): integer;

(* RULES 5.1 AND 5.2 FOR ONE QSO: the points between two grids (the first
   four characters of each are the square; a six-character MY GRID is its
   square's centre), doubled on SSB (Phone). 0 when either text is not a
   grid. *)
function RU3AXQSOPoints(const aMyGrid: string;
                        const aHisGrid: string;
                        aMode: ModeType): integer;

(* RULE 1's ROUNDS FROM A UTC TIME: 1 for 17:00-18:59, 2 for 19:00-20:59,
   0 outside the contest. *)
function RU3AXRoundOf(aHour: integer; aMinute: integer): integer;

type
   TContestRU3AXMemorial = class(TContestBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the properties,
         descendants override the getters. *)
      function GetDisplayName: string; override;
      function GetSchedule: string; override;
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
      function GetReceivesGridSquareExchange: boolean; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* RULES 5.1 AND 5.2 -- see the header. Protected, as on TContestBase:
         ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* RULE 1 -- see TContestBase.UsesBand and UsesMode. *)
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      (* RULE 6.1 -- the round a QSO falls in. See TContestBase.DupeKeyTour. *)
      function DupeKeyTour(const aQso: ContestExchange): string; override;
      (* RULE 4 -- the grid is required, and the oblast comes from the call.
         See the header and TContestBase.ParseReceivedExchange. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
      (* A GRID WORD IS NEVER A CALL -- see TContestBase.MayBeACallsign. *)
      function MayBeACallsign(const aWord: string): boolean; override;
      (* THE NEED-MULTIPLIER HINT: a Russian station's oblast from its call --
         see TContestBase.DomesticMultiplierFromCall. *)
      function DomesticMultiplierFromCall(const aCall: string;
                                          const aLookups: TMultiplierHintLookups): string; override;
      (* AN IMPORTED QSO: the grid is QTHString, the oblast from the call --
         see TContestBase.ApplyADIFImport. *)
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
      (* THE NEW CONTEST DIALOG'S PROMPTS -- see
         TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   protected
      (* THE TOTALS WINDOW -- see TContestBase.TotalsDisplay (M9a). *)
      function GetTotalsDisplay: TTotalsDisplay; override;
   protected
      (* THE HOUR-BY-HOUR REPORT -- see TContestBase.ReportsRunningScore (M9a). *)
      function GetReportsRunningScore: boolean; override;
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
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesGridSquare
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesGridSquare: boolean; override;
      function ExchangeTextMayHoldGridSquare: boolean; override;
   end;

implementation

uses
   SysUtils,
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry,
   (* RussianID -- is the entrant Russian (DescribeSession). *)
   uCallSignRoutines,
   (* RDXCOblastFromCall -- a station's oblast from its call, FJ and AN by
      call (rule 7.1). *)
   uRussianTerritories,
   (* GridHaversineKm -- rule 5.1's centre-to-centre distance. *)
   uGridDistance,
   (* IsGoodLookingGrid -- the Q37 rule: what may be measured. *)
   uGridShape,
   (* SExchangeGridRequired -- rule 4's refusal. *)
   uAppStrings,
   uTR4WStrings;

const
   (* Rule 1's rounds, in minutes of the UTC day. *)
   ROUND_ONE_START_MINUTE = 17 * 60;
   ROUND_MINUTES          = 2 * 60;
   ROUND_COUNT            = 2;

(* THE SQUARE OF A GRID TEXT -- its first four characters, upper case. Rule 4
   sends four; a six-character grid (a MY GRID, rule 9.7) names its square's
   subsquare, and the square is what the rule measures. *)
function GridSquareOf(const aGrid: string): string;
begin
   Result := UpperCase(Copy(Trim(aGrid), 1, 4));
end;

function RU3AXPointsForDistance(aKm: Double): integer;
begin
   if aKm <= 0.0 then
      begin
      Result := RU3AX_MINIMUM_POINTS;
      Exit;
      end;
   Result := RU3AX_MINIMUM_POINTS + Trunc(aKm / RU3AX_KM_PER_POINT);
end;

function RU3AXQSOPoints(const aMyGrid: string;
                        const aHisGrid: string;
                        aMode: ModeType): integer;
begin
   Result := 0;
   if (not IsGoodLookingGrid(Trim(aMyGrid))) or
      (not IsGoodLookingGrid(Trim(aHisGrid))) then
      begin
      Exit;
      end;

   Result := RU3AXPointsForDistance(GridHaversineKm(GridSquareOf(aMyGrid),
                                                    GridSquareOf(aHisGrid)));

   if aMode = Phone then
      begin
      Result := Result * 2;
      end;
end;

function RU3AXRoundOf(aHour: integer; aMinute: integer): integer;
var
   minutes: integer;
begin
   Result := 0;
   minutes := aHour * 60 + aMinute - ROUND_ONE_START_MINUTE;
   if (minutes >= 0) and
      (minutes < ROUND_MINUTES * ROUND_COUNT) then
      begin
      Result := minutes div ROUND_MINUTES + 1;
      end;
end;

(* RULES 5.1 AND 5.2. Station.MyGrid is the row's own MY GRID while a logged
   QSO is scored (ScoreQSO's overlay), else the session's. *)
procedure TContestRU3AXMemorial.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := RU3AXQSOPoints(Station.MyGrid, string(aQso.QTHString), aQso.Mode);
end;

function TContestRU3AXMemorial.UsesBand(aBand: BandType): boolean;
begin
   (* Rule 1: "on 1.8 MHz amateur band ONLY". *)
   Result := aBand = Band160;
end;

function TContestRU3AXMemorial.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   (* Rule 1: "Modes: CW and SSB." *)
   Result := aMode in [CW, Phone];
end;

(* Rule 6: a repeat in the other round is a new QSO; the round is read from
   the QSO's own logged (UTC) time. A QSO outside the four hours has no
   round, and its key is the call alone. *)
function TContestRU3AXMemorial.DupeKeyTour(const aQso: ContestExchange): string;
var
   roundNumber: integer;
begin
   Result := '';
   roundNumber := RU3AXRoundOf(aQso.tSysTime.qtHour, aQso.tSysTime.qtMinute);
   if roundNumber > 0 then
      begin
      Result := 'ROUND ' + IntToStr(roundNumber);
      end;
end;

function TContestRU3AXMemorial.ParseReceivedExchangeFormat(const aText: string;
                                                           aParsers: TExchangeParsers;
                                                           var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTAndOrGrid(aText, aExch);
end;

(* RULE 4: "RS(T) + Four character grid square". The format's parse (the
   RST-and/or-grid parser: a word that is neither a grid nor a report is its
   refusal) runs on a COPY, so a refusal writes nothing into the QSO. The
   grid is required -- a report alone is refused with SExchangeGridRequired,
   as the CQ VHF's RequireReceivedGrid says it (that helper tests DomesticQTH,
   which this class keeps for the oblast, so it is not called). Accepted, the
   QSO takes the RS(T), the grid's square as QTHString, and the oblast of a
   Russian call as its domestic QTH and multiplier -- see the header. *)
function TContestRU3AXMemorial.ParseReceivedExchange(const aText: string;
                                                     const aSession: TReceivedExchangeSession;
                                                     var aExch: ContestExchange;
                                                     out aErrorMessage: string): boolean;
var
   parsed: ContestExchange;
   oblast: string;
   domesticQTH: string;
   key: string;
begin
   parsed := aExch;
   Result := inherited ParseReceivedExchange(aText, aSession, parsed, aErrorMessage);
   if not Result then
      begin
      Exit;
      end;

   if not IsGoodLookingGrid(Trim(string(parsed.QTHString))) then
      begin
      aErrorMessage := SExchangeGridRequired;
      Result := False;
      Exit;
      end;

   parsed.QTHString := ShortString(GridSquareOf(string(parsed.QTHString)));
   parsed.DomesticQTH := '';
   parsed.DomMultQTH := '';

   oblast := RDXCOblastFromCall(string(parsed.Callsign), string(parsed.QTH.CountryID));
   if oblast <> '' then
      begin
      if Assigned(aSession.ResolveDomesticQTH) then
         begin
         if aSession.ResolveDomesticQTH(oblast, domesticQTH, key) then
            begin
            parsed.DomesticQTH := ShortString(domesticQTH);
            parsed.DomMultQTH := ShortString(key);
            end;
         end
      else
         begin
         (* No table service: the oblast as the call gives it. *)
         parsed.DomesticQTH := ShortString(oblast);
         end;
      end;

   aExch := parsed;
end;

function TContestRU3AXMemorial.MayBeACallsign(const aWord: string): boolean;
begin
   Result := not IsGoodLookingGrid(aWord);
end;

function TContestRU3AXMemorial.DomesticMultiplierFromCall(const aCall: string;
                                                          const aLookups: TMultiplierHintLookups): string;
begin
   Result := '';
   if Assigned(aLookups.CountryOfCall) then
      begin
      Result := RDXCOblastFromCall(aCall, aLookups.CountryOfCall(aCall));
      end;
end;

(* AN IMPORTED QSO -- the base's grid arm would put the grid in DomesticQTH,
   where the sheet would count it as an oblast. The grid's square is
   QTHString; the oblast is the call's, resolved through the import's table
   as typed entry resolves it. aExch.QTH holds the call's CTY.DAT answer
   (ParseADIFRecord locates the call before the tail). *)
procedure TContestRU3AXMemorial.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                                const aSession: TADIFImportSession;
                                                var aExch: ContestExchange);
var
   oblast: string;
   domesticQTH: string;
   key: string;
begin
   aExch.QTHString := ShortString(GridSquareOf(aTemps.GridSquare));
   aExch.ExchString := ShortString(IntToStr(aExch.RSTReceived) + ' ' +
                                   GridSquareOf(aTemps.GridSquare));
   aExch.DomesticQTH := '';
   aExch.DomMultQTH := '';
   oblast := RDXCOblastFromCall(string(aExch.Callsign), string(aExch.QTH.CountryID));
   if oblast = '' then
      begin
      Exit;
      end;
   if Assigned(aSession.ResolveDomesticQTH) then
      begin
      if aSession.ResolveDomesticQTH(oblast, domesticQTH, key) then
         begin
         aExch.DomesticQTH := ShortString(domesticQTH);
         aExch.DomMultQTH := ShortString(key);
         end;
      end
   else
      begin
      aExch.DomesticQTH := ShortString(oblast);
      end;
end;

function TContestRU3AXMemorial.GetDisplayName: string;
begin
   Result := 'Russian 160-Meter DX Contest';
end;

(* WHEN IT RUNS -- Q99 (docs/CONTEST_SCHEDULES.csv, applied 2026-11-17).
   CSV row RU3AX MEMORIAL: status unscheduled. UNSCHEDULED: no dated events
   (inactive or not a contest); NY4I intake 2026-11-17. The 2025 rules date
   one event, "17.00 UTC to 20.59 UTC, December 19th, 2025" -- a calendar
   entry is NY4I's (issue 57 report). *)
function TContestRU3AXMemorial.GetSchedule: string;
begin
   Result := 'unscheduled';
end;

function TContestRU3AXMemorial.GetCabrilloName: string;
begin
   (* WA7BNM's Cabrillo name (WA7BNM 202), NY4I 2026-10-19: "do the
      cabrillo renames". TR4W wrote 'RU3AX MEMORIAL', which the sponsor's log
      robot accepted neither as the name nor as an alias
      (docs/UDC_CROSSWALK_FINDINGS.md). TR4W reads no Cabrillo CONTEST:
      value back, so the old name needs no read alias. *)
   Result := 'RADIO-160';
end;

function TContestRU3AXMemorial.GetADIFContestId: string;
begin
   (* The enum's spelling: export writes it, and import matches it (M1). *)
   Result := 'RU3AX MEMORIAL';
end;

function TContestRU3AXMemorial.GetWA7BNMId: integer;
begin
   Result := 202;
end;

function TContestRU3AXMemorial.GetQRZRUId: integer;
begin
   Result := 90;
end;

function TContestRU3AXMemorial.GetSubmissionEmail: string;
begin
   (* Rule 9.3: "Log shall uploaded at http://ua9qcq.ru/submit_log.php or it
      shall be sent as attachment to rusdx160@gmail.com". Kept '' as before:
      whether TR4W should offer that address is NY4I's (issue 57 report). *)
   Result := '';
end;

function TContestRU3AXMemorial.GetDomesticFileName: string;
begin
   (* The oblasts (rule 7.1) -- the table the call's oblast is resolved by. *)
   Result := 'russian';
end;

function TContestRU3AXMemorial.GetFriendlyName: string;
begin
   Result := 'Russian 160-Meter DX Contest';
end;

function TContestRU3AXMemorial.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRU3AXMemorial.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndOrGridExchange;
end;

function TContestRU3AXMemorial.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestRU3AXMemorial.ExchangeCarriesGridSquare: boolean;
begin
   Result := True;
end;

function TContestRU3AXMemorial.ExchangeTextMayHoldGridSquare: boolean;
begin
   Result := True;
end;

function TContestRU3AXMemorial.GetReceivesGridSquareExchange: boolean;
begin
   Result := True;
end;

(* THE SENT GRID IS FOUR CHARACTERS (rule 4), whatever length MY GRID is
   stated at (rule 9.7 asks six for the header). *)
function SentFourCharacterGrid(const aMy: TMyStationExchange): TMyStationExchange;
begin
   Result := aMy;
   Result.MyGrid := GridSquareOf(aMy.MyGrid);
end;

function TContestRU3AXMemorial.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTGrid(SentFourCharacterGrid(aMy), aQso);
end;

function TContestRU3AXMemorial.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTGrid(SentFourCharacterGrid(aMy), aQso, aCtx);
end;

(* THE RECEIVED COLUMN IS THE GRID. PostUnit hands a contest with a domestic
   multiplier the DOMESTIC QTH as HisQTH -- here the oblast -- so the context
   is copied with the grid in its place (the WW Digi's way). *)
function TContestRU3AXMemorial.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                           const aQso: ContestExchange;
                                                           const aCtx: TCabrilloQSOContext): string;
var
   ctx: TCabrilloQSOContext;
begin
   ctx := aCtx;
   ctx.HisQTH := string(aQso.QTHString);
   Result := CabrilloReceivedRSTQTH(aMy, aQso, ctx);
end;

function TContestRU3AXMemorial.GetFlags: TContestFlags;
begin
   (* cfQSOByMode -- rule 6.1, dupes per mode. cfMultByMode -- rule 7.3,
      multipliers per mode, summed. cfCountsDomesticCountries -- a Russian
      station's country is a DXCC multiplier too (7.1, 7.2), as before. *)
   Result := [cfQSOByMode,
              cfMultByMode,
              cfCountsDomesticCountries];
end;

function TContestRU3AXMemorial.GetIsUSQSOParty: boolean;
begin
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). The domestic countries are the stations an
   oblast is looked for; CE9 for RI1AN (rule 7.1). A non-Russian entrant
   states no MY STATE for it, as before -- nothing sends one now. *)
procedure TContestRU3AXMemorial.DescribeSession(const aStation: TStationContext;
                                                aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountries(DomesticCountriesRussia);
   aSession.AddDomesticCountry('CE9');
   if not RussianID(string(aStation.MyCountry)) then
      begin
      aSession.SentState := '';
      end;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE -- rule 4:
   the report and the four-character grid. *)
function TContestRU3AXMemorial.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' 5NN ' + GridSquareOf(aStation.MyGrid);
end;

(* THE NEW CONTEST DIALOG ASKS FOR THE GRID (rule 4), not the oblast: the
   oblast is no longer sent. *)
procedure TContestRU3AXMemorial.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
end;

(* THE TOTALS WINDOW LABELS THE DOMESTIC MULTIPLIERS AS OBLASTS. Per mode the
   labels are the default ones. *)
function TContestRU3AXMemorial.GetTotalsDisplay: TTotalsDisplay;
begin
   Result := inherited GetTotalsDisplay;
   Result.DomesticMultsCaption := TC_OBLASTS;
end;

(* THE HOUR-BY-HOUR REPORT CARRIES NO RUNNING SCORE -- PostUnit.PrintHourTotals
   named this contest among the seven whose score is not points times
   multipliers hour by hour (M9a, 2026-10-02). *)
function TContestRU3AXMemorial.GetReportsRunningScore: boolean;
begin
   Result := False;
end;

function TContestRU3AXMemorial.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* RULE 7.1's TERRITORIES: the CTY country, on the DXCC + WAE list. The RDXC's
   remapping of FJL and RI1AN to territories of their own is ITS rule 7.3 and
   is not taken here; the 2025 RU3AX rules name them as OBLASTS. *)
function TContestRU3AXMemorial.DXMultiplierKey(const aQso: ContestExchange;
                                               out aKey: DXMultiplierString): boolean;
begin
   aKey := aQso.QTH.CountryID;
   Result := True;
end;

(* RULE 7.1: "territories (DXCC + WAE)" -- CTY.DAT's CQ list, as the RDXC's
   rule 9 (Q131). It was ARRLCountryMode, DXCC only, since D7. *)
function TContestRU3AXMemorial.CountryMode: CountryModeType;
begin
   Result := CQCountryMode;
end;

function TContestRU3AXMemorial.UsesDomesticFile: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(RU3AXMEMORIAL, TContestRU3AXMemorial);

end.
