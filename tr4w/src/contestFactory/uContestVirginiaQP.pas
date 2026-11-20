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

(* VIRGINIA QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'va_cty';  WA7BNM: 302;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 17;  AE: QSONumberDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: VAQSOPointMethod;  ADIFName: 'VA-QSO-PARTY';
   CABName: 'VA-QSO-PARTY';  FriendlyName: 'Virginia QSO Party'

  THE ENUM IS MIXED CASE AND THE LEGACY ARM IS NOT. VC.pas declares
  VAQSOPointMethod; LOGSTUFF spelled the same identifier VAQSOPOINTMETHOD at
  its case arm (deleted at M10 S3; the D7 tree still has it). Pascal identifiers are case-insensitive so both are the one value,
  but a case-sensitive search for the enum's spelling finds no arm and invites
  the conclusion that the contest is unscored. Search case-insensitively.

  THE ONLY ONE OF THESE FOUR WHOSE POINTS DEPEND ON THE CALLSIGN'S SHAPE -- see
  the note on CalculateQSOPoints.

  ---------------------------------------------------------------------------
  THE 2026 RULES, CHECKED AGAINST THE SPONSOR (2026-11-20; the text is
  docs/ContestRules/QSOParties/Virginia/VA-QSO-PARTY-Rules.txt):

  COUNTY LINES -- "Stations on County or Independent City lines count as one
    QSO and one County/Independent City multiplier." One QSO is one county,
    so GetCountyLineCountiesMax is 0 (Wisconsin's and Michigan's form): an
    entry naming two counties is refused. NY4I, 2026-11-20: "VAQP does not
    allow county line operations where you get credit for 2 counties." The row's CountyLineAllowed boolean
    was never the source of a number.

  BANDS -- "160 meters and up, except no WARC band QSO's permitted."
    UsesBand; cfVHFBandsEnabled (the suggested frequencies include 6 m to
    70 cm).

  MODES -- "Phone, CW, Digital" with no exception: UsesMode credits them all,
    FM as phone.

  MULTIPLIERS (once overall) -- a Virginia entrant counts the counties and
    cities, the states but Virginia, the provinces and "DX entities. No extra
    DX multiplier for U.S. (including Alaska and Hawaii), Virginia, and
    Canada": the DX multiplier, in state only, every entity but K, VE, KH6
    and KL. An entrant elsewhere counts the counties and cities alone.

  POINTS -- "1 point per Phone, 2 points per CW, 2 points per digital mode
    ..., and 3 points per contact made with a Virginia Mobile, Expedition,
    or Rover." FM is phone. BUILT AS WRITTEN (NY4I, 2026-11-20: "Check
    rules"): THREE POINTS IN ANY MODE for a station that is (1) in
    Virginia -- its credited QTH is a Virginia county or city
    (QSOCreditsHostCounty, the party base's one statement) -- and (2) a
    mobile or rover by its call -- "Mobile, Rover, and Expedition stations
    must use appropriate suffix in call sign": /M or /R
    (uCallSignRoutines.MobileCall / RoverCall), read after any rover county
    the engine strips (CallWithoutRoverCounty). Phone, CW and digital alike:
    the 3 replaces the mode's points. The air- and maritime-mobile arm the
    class carried from D7 (/AM, /MM scored 3 on CW and digital) is GONE: the
    sponsor names no such rule. NOT BUILT: an EXPEDITION's suffix -- the
    sponsor names none and no helper exists; an expedition signing /M or /R
    is paid, one signing anything else scores by mode.

  THE RECEIVED COLUMN -- "QTH (Virginia County or Independent City for VA
    stations; State, Province or "DX" for others)": a DX station typed as its
    country exports DX (CabrilloReceivedQSONumberDomesticQTHOrDX); the plain
    helper printed the exporter's HisQTH, empty for it.

  NOT BUILT: the 100 points per county or city of a Virginia mobile, rover
    or expedition and its expedition multiplier (the entrant's category and
    county do not reach scoring, #133), and the one-time 50 points of each
    "VA QSO Party Bonus Station" (the list is on the sponsor's web site, not
    in the rules).
 *)
unit uContestVirginiaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase,
   (* TCallHistoryFields, chf... -- CallHistoryFields. *)
   uCallHistory;

type
   TContestVirginiaQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;
      function GetSchedule: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same answer -- but the base makes it
         abstract for state parties precisely so that answer is never an
         accident. *)
      function GetHostState: string; override;

      (* THE WHOLE ContestsArray ROW, STATED HERE.

         NY4I, 2026-09-29: "all the info in [the row] should go into the contest
         class." Every getter below returns what the array holds today, so this
         changes no behaviour -- it moves the ANSWER, so that reading this one
         file tells you what the contest is without cross-referencing a 185-row
         table by enum position.

         THE ROW IS NOT DELETED AND MUST NOT BE. It still answers for every
         contest that has no class, and for every accessor a class does not
         override. *)
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

      (* STATED AT M10 S5, transcribed from the rows the base read until
         then (ContestsArray, QSOParties, ContestsBooleanArray). The
         flags: see TContestBase.GetFlags. *)
      function GetInStateDomesticFileName: string; override;
      function GetFlags: TContestFlags; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* "count as one QSO" -- no county line; the header. *)
      function GetCountyLineCountiesMax: integer; override;
   public
      (* A VIRGINIA MOBILE OR ROVER -- the three-point station; the header. *)
      function IsVirginiaMobileOrRover(const aQso: ContestExchange): boolean;

      (* Every band but the WARC bands; every mode -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE DX MULTIPLIER, IN STATE ONLY -- the header. *)
      function HasDXMultiplier: boolean; override;
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      function CountryMode: CountryModeType; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
      function PerQSOExchangeLeadsWithSerial: boolean; override;
   public
      (* VIRGINIA IS NOT A STATE MULTIPLIER FOR A VIRGINIA ENTRANT --
         #88 round 3 (2026-10-26). See the implementation. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;
   public
      (* WHAT THE CALL HISTORY FILE PREFILLS --
         THE COUNTY OR STATE -- the site file QSOP_VA carries Call, Exch1, UserText
         (read 2026-11-20): the QTH the station sent (a county code, a state
         or a DX prefix). This party remembers the QTH alone (its received
         fields carry no name). 363 of 363 non-state rows are county keys of its
         own county file; the rest are DX prefixes and a few spellings it lacks.
         See TContestBase.CallHistoryFields. *)
      function CallHistoryFields: TCallHistoryFields; override;

      (* THE SITE'S FILE STEM. See TContestBase.CallHistorySiteName. *)
      function CallHistorySiteName: string; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   (* DXCCKeyExceptUSACanadaHawaiiAlaska, DXCCCountryMode -- issue #136. *)
   uDXMultiplierKey,
   (* MobileCall, RoverCall -- the /M and /R suffix tests of the three-point
      rule. A leaf callsign unit, so a contest class can still be asked to
      score a QSO with no part of the program running. (Until 2026-11-20 it
      was MarineOrAirMobileStation, D7's /AM and /MM arm.) *)
   uCallSignRoutines,
   uContestRegistry;

function TContestVirginiaQP.GetDisplayName: string;
begin
   Result := 'Virginia QSO Party';
end;

(* WHEN IT RUNS -- Q99 (docs/CONTEST_SCHEDULES.csv, applied 2026-11-16). CSV
   row VAQP: status candidate; rules
   https://www.qsl.net/sterling/VA_QSO_Party/2027_VQP/2027_VQP_Main.html;
   rules year 2026/2027. CANDIDATE: date from a calendar, not yet checked
   against the sponsor's rules. *)
function TContestVirginiaQP.GetSchedule: string;
begin
   Result := '3rd full weekend of March at 14:00 UTC for 14h; ' +
             '3rd full weekend of March +1d at 12:00 UTC for 12h';
end;

function TContestVirginiaQP.GetHostState: string;
begin
   Result := 'VA';
end;

function TContestVirginiaQP.GetCabrilloName: string;
begin
   Result := 'VA-QSO-PARTY';
end;

function TContestVirginiaQP.GetADIFContestId: string;
begin
   Result := 'VA-QSO-PARTY';
end;

function TContestVirginiaQP.GetWA7BNMId: integer;
begin
   Result := 302;
end;

function TContestVirginiaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestVirginiaQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestVirginiaQP.GetDomesticFileName: string;
begin
   Result := 'va_cty';
end;

function TContestVirginiaQP.GetFriendlyName: string;
begin
   Result := 'Virginia QSO Party';
end;

function TContestVirginiaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestVirginiaQP.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberDomesticOrDXQTHExchange;
end;

function TContestVirginiaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsQSONumberQTH;
end;

function TContestVirginiaQP.ParseReceivedExchangeFormat(const aText: string;
                                                        aParsers: TExchangeParsers;
                                                        var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseQSONumberDomesticOrDXQTH(aText, aExch);
end;

function TContestVirginiaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestVirginiaQP.PerQSOExchangeLeadsWithSerial: boolean;
begin
   Result := True;
end;

function TContestVirginiaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange): string;
begin
   Result := ADIFSentStateThenQSONumber(aMy, aQso);
end;

function TContestVirginiaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentQSONumberState(aMy, aQso, aCtx);
end;

function TContestVirginiaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   (* In state a DX station's typed country is written as DX; an entrant
      elsewhere works Virginia stations only. *)
   if Station.InHostState then
      begin
      Result := CabrilloReceivedQSONumberDomesticQTHOrDX(aMy, aQso, aCtx);
      end
   else
      begin
      Result := CabrilloReceivedQSONumberQTH(aMy, aQso, aCtx);
      end;
end;

function TContestVirginiaQP.GetInStateDomesticFileName: string;
begin
   Result := 'va';
end;

function TContestVirginiaQP.GetFlags: TContestFlags;
begin
   (* The VHF bands are credited -- the header. *)
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

function TContestVirginiaQP.GetCountyLineCountiesMax: integer;
begin
   Result := 0;
end;

(* "160 meters and up, except no WARC band QSO's permitted." *)
function TContestVirginiaQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10,
                       Band6, Band2, Band222, Band432, Band902, Band1296,
                       Band2304, Band3456, Band5760, Band10G, Band24G,
                       BandLight];
end;

(* "Phone, CW, Digital": every submode of each; FM is phone. *)
function TContestVirginiaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM, Digital];
end;

(* THE DX MULTIPLIER -- a Virginia entrant's only. *)
function TContestVirginiaQP.HasDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

function TContestVirginiaQP.DXMultiplierKey(const aQso: ContestExchange;
                                            out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(HasDXMultiplier, aQso, aKey);
end;

function TContestVirginiaQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(HasDXMultiplier);
end;

(* "3 points per contact made with a Virginia Mobile, Expedition, or Rover"
   -- the header. One predicate, asked by CalculateQSOPoints and pinned by
   the tests: the worked station is in Virginia (its credited QTH is a
   Virginia county or city) and signs /M or /R once any rover county the
   engine strips is gone. MobileCall and RoverCall are case-blind. *)
function TContestVirginiaQP.IsVirginiaMobileOrRover(const aQso: ContestExchange): boolean;
var
   call: string;
begin
   call := CallWithoutRoverCounty(string(aQso.Callsign));
   Result := (MobileCall(call) or RoverCall(call)) and
             QSOCreditsHostCounty(aQso);
end;

(* PHONE ONE, CW TWO, DIGITAL TWO -- and THREE, in any mode, for a Virginia
   mobile or rover (IsVirginiaMobileOrRover). FM is phone; anything that is
   not phone scores two, as the chain below always did. Until 2026-11-20 this was D7's VAQSOPointMethod chain
   (phone 1, else /AM or /MM 3, else 2), which the sponsor's rules do not
   state -- the header. *)
procedure TContestVirginiaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if IsVirginiaMobileOrRover(aQso) then
      begin
      aQso.QSOPoints := 3;
      end
   else if aQso.Mode in [Phone, FM] then
      begin
      aQso.QSOPoints := 1;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestVirginiaQP.DescribeSession(const aStation: TStationContext;
                                             aSession: TSessionDefaults);
begin
   aSession.AllowDupeQSOs := True;
end;

(* VIRGINIA IS NOT A STATE MULTIPLIER FOR A VIRGINIA ENTRANT -- #88
   round 3 (2026-10-26), the sponsor's 2026 rules:
   "Virginia Mobile, Rover, Expedition, and Fixed Station multipliers are
   the total number of Virginia counties, Virginia Independent cities, U. S.
   States (except Virginia)".
   va.dom includes the shared S50.DOM, which holds Va; an
   in-state entrant's QSO whose domestic multiplier is the host state
   itself earns no multiplier and keeps its points. Outside Virginia the
   multipliers are the counties, and none is spelled as the state. The
   shared file is never edited for this: other contests read it. *)
function TContestVirginiaQP.CountsAsMultiplier(const aQso: ContestExchange;
                                               aKind: RemainingMultiplierType): boolean;
begin
   Result := not (Station.InHostState and
                  DomesticMultiplierIsHostState(string(aQso.DomMultQTH), HostState));
end;

function TContestVirginiaQP.CallHistoryFields: TCallHistoryFields;
begin
   Result := CallHistoryFieldList([chfExch1]);
end;

function TContestVirginiaQP.CallHistorySiteName: string;
begin
   Result := 'QSOP_VA';
end;

initialization
   RegisterContest(VAQP, TContestVirginiaQP);

end.
