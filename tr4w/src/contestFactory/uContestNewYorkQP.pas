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

(* NEW YORK QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'newyork_cty';  WA7BNM: 473;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 3;  AE: RSTDomesticQTHExchange;
   XM: NoDXMults;  QP: OnePhoneTwoCW;  ADIFName: 'NY-QSO-PARTY';
   CABName: '';  FriendlyName: 'New York QSO Party'

  TWO COUNTIES ON A COUNTY LINE -- NY4I, 2026-09-29: "NY allows up to 2
  counties on a county line."

  So GetCountyLineCountiesMax returns 2, the way North Carolina's and
  Indiana's do. THE ROW CARRIES NO CountyLineAllowed FIELD AT ALL, so the
  array boolean reads False -- which only ever meant UNKNOWN -- and the number
  was never going to come from it. Until this ruling the class inherited
  CountyLineCountiesUnlimited; a third county on one exchange is now refused.

  CABName IS BLANK, AND BLANK MEANS "THE ENUM'S SPELLING", which for this
  contest is 'NY-QSO-PARTY' (ContestTypeSA). GetCabrilloName states that
  resolved value, not the empty string.

  ONE NEW YORK RULE STILL LIVES IN SHARED CODE AND IS NOT MOVED HERE.
  logdupe.pas: "if (Contest = NYQP) and (RXData.DomMultQTH = 'DX') then exit"
  -- a DX station is no domestic multiplier. That is multiplier logic, which no
  contest class owns yet; British Columbia and Indiana have the same shape in
  the same routine and were left there too. It is the same in D7.

  FCONTEST's NYQP arm set ActiveDomesticMult := DomesticFile, which is what
  the row already said. It was DescribeSession from M7a, stated so that it
  overwrote a DOMESTIC MULTIPLIER line before CONTEST; that setting retired
  at M10 S2, and the restatement -- the whole of DescribeSession -- went at
  M11 S2 (plan 1.3). The trait is the one statement.

  ---------------------------------------------------------------------------
  THE 2026 RULES, CHECKED AGAINST THE SPONSOR (#88, 2026-11-19). The text is
  docs/ContestRules/QSOParties/NewYork/NY-QSO-PARTY-Rules-2026-v1.1.md (v1.1,
  2026-09-25, supplied by NY4I).

  POINTS -- "Phone contact is worth 1 point per band ... CW contact is worth
    2 points per band ... RTTY (or other valid digital mode) contact is worth
    3 points per band." Phone is "SSB, FM, AM", so FM is phone. Digital was 1
    until then: the legacy OnePhoneTwoCW tested CW-versus-not.

  BANDS -- "All FCC allocated amateur frequencies (excluding the 30, 17, and
    12 meter bands)". UsesBand; a WARC QSO is an automatic X-QSO.

  MULTIPLIERS ONCE, OVERALL -- a New York entrant counts "US states (50), New
    York Counties (62) and Canadian provinces (13) ... Maximum of 125
    multipliers"; anyone else counts "New York counties for a maximum of 62
    multipliers". A maximum equal to the size of the list is a count made once
    in the contest, so GetFlags states no cfMultByBand or cfMultByMode (both
    were set until then). A QSO still counts once on each band in each mode.

  THE STATES AND THE 13 PROVINCES -- "US states (50) ... Canadian provinces
    (13): AB, BC, MB, NB, NL, NT, NS, NU, ON, PE, QC, SK, YT". No DC. NY4I
    (#88, 2026-11-19): the file for "50 states, no DC, 13 provinces" is
    s50p13.dom (s50p13dc.dom is the one with DC). newyork.dom is the 62
    counties FIRST, then s50p13.dom, then DX: the counties come first so
    ALB stays Albany, not Alberta's alias. prov12.dom, which held the
    provinces and to which NT was added the same day, is prov13.dom, and
    s50p13.dom includes it (its inline list, with NF where the sponsor says
    NL, went with it).

  NEW YORK COUNTS AS A STATE FOR A NEW YORK ENTRANT -- "The first valid New
    York county logged will count as the multiplier for New York." NY4I
    (#88, 2026-11-19): "it would be a double mult (county and state (NY))".
    AdditionalDomesticMultiplierKey (#317): an in-state entrant's county QSO
    also earns NY, once overall like every multiplier here, so the in-state
    maximum is the sponsor's 125 (62 + 50 + 13).

  CABRILLO -- "Only these values are valid in the Overlay field: Rookie,
    Youth12, Youth17, YL" (CabrilloOverlayCategories; ROOKIE and YL are on
    the standard list already). The LOCATION header is specified (a county,
    a state or province abbreviation, or DX): RequiresCabrilloLocation, NY4I
    (#88): "Yes to locationHeader".

  STATED AS THE RULES SAY, UNCHANGED: two counties on a county line, no bonus
    station, DX earns points but no multiplier (CountsAsMultiplier), the 62
    county codes of newyork_cty.dom, the schedule, NY-QSO-PARTY.

  BANDS, AGAIN -- NY4I (#88): every band but 30, 17 and 12 m, BandLight
    included. 60 m is within the rules text, but TR4W's BandType has no 60 m
    band (Band60 is commented out of VC), so there is nothing to state.

  NO CATEGORY RULE -- "RTTY and digital modes are permitted in the Mixed
    category only" is not built: NY4I (#88) would rather the allowed modes
    dictate it than force a category up front.

  MODES -- "Only digital modes that natively support the NYQP exchange are
    permitted". NY4I (#88, 2026-11-19): "NOT FT8, FT4 or FT2". UsesMode.
 *)
unit uContestNewYorkQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestNewYorkQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;
      function GetSchedule: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'NY' -- but the base makes it abstract
         for state parties precisely so that answer is never an accident. *)
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
      procedure WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters); override;
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

      (* The county-line maximum, from NY4I's ruling -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;

      (* The sponsor's CATEGORY-OVERLAY values and its LOCATION header --
         see the header. *)
      function GetCabrilloOverlayCategories: TArray<string>; override;
      function GetRequiresCabrilloLocation: boolean; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* Every band but 30, 17 and 12 m -- see the body. *)
      function UsesBand(aBand: BandType): boolean; override;
      (* CW, phone, FM and every digital submode but FT8, FT4 and FT2 --
         see the body. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* A DX STATION EARNS NO MULTIPLIER -- logdupe's SetMultFlags rule for
         this contest (4.116.5), moved here at M8: a multiplier QTH of 'DX'
         earns no multiplier of any kind -- in any case since Q84 (NY4I,
         2026-10-15: "ignore case"), through uContestBase.DomesticMultiplierIsDX,
         the one test Indiana and British Columbia ask too. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;
      (* AN IN-STATE COUNTY QSO ALSO EARNS NY -- #317, see the header. *)
      function AdditionalDomesticMultiplierKey(const aQso: ContestExchange;
                                               out aKey: string): boolean; override;
      (* SEVERAL QTHs FROM ONE ENTRY -- see TContestBase.LogsSeveralQTHsFromOneEntry (M11 S7). *)
      function LogsSeveralQTHsFromOneEntry: boolean; override;
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
   uContestRegistry;

function TContestNewYorkQP.CountsAsMultiplier(const aQso: ContestExchange;
                                              aKind: RemainingMultiplierType): boolean;
begin
   (* Every kind: the legacy rule returned before any flag was set. *)
   Result := not DomesticMultiplierIsDX(string(aQso.DomMultQTH));
end;

function TContestNewYorkQP.AdditionalDomesticMultiplierKey(const aQso: ContestExchange;
                                                           out aKey: string): boolean;
begin
   (* "The first valid New York county logged will count as the multiplier
      for New York" -- a county also earns NY, in state (#317). Every key of
      newyork.dom longer than two characters is a county: the states and the
      provinces are two letters. *)
   Result := InStateCountyEarnsHostState(aQso, aKey);
end;

(* "Only these values are valid in the Overlay field: Rookie, Youth12,
   Youth17, YL" -- in the sponsor's spelling; the summary window's merge
   (uCbrSum.OverlayValuesWith) keeps the standard list's ROOKIE and YL and
   adds the two it lacks. *)
function TContestNewYorkQP.GetCabrilloOverlayCategories: TArray<string>;
begin
   Result := nil;
   SetLength(Result, 4);
   Result[0] := 'Rookie';
   Result[1] := 'Youth12';
   Result[2] := 'Youth17';
   Result[3] := 'YL';
end;

(* "LOCATION field: For fixed stations outside New York, use your state
   abbreviation, Canadian province abbreviation, or DX. For fixed stations in
   New York, use your NYQP-approved three-letter county abbreviation." *)
function TContestNewYorkQP.GetRequiresCabrilloLocation: boolean;
begin
   Result := True;
end;

function TContestNewYorkQP.GetDisplayName: string;
begin
   Result := 'New York QSO Party';
end;

(* WHEN IT RUNS -- Q99 (docs/CONTEST_SCHEDULES.csv, applied 2026-11-16). CSV
   row NY-QSO-PARTY: status verified (2026-11-19) against the sponsor's
   2026 rules (header): "Third Saturday in October: October 17, 2026 1400
   UTC ... 12 Hours", "from 14:00 UTC through 01:59 UTC". *)
function TContestNewYorkQP.GetSchedule: string;
begin
   Result := '3rd Saturday of October at 14:00 UTC for 12h';
end;

function TContestNewYorkQP.GetHostState: string;
begin
   Result := 'NY';
end;

function TContestNewYorkQP.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'NY-QSO-PARTY';
end;

function TContestNewYorkQP.GetADIFContestId: string;
begin
   (* Matches ADIF 3.1.7's Contest_ID enumeration, "NY-QSO-PARTY -- New York
      QSO Party", checked against the published table on 2026-09-29. *)
   Result := 'NY-QSO-PARTY';
end;

function TContestNewYorkQP.GetWA7BNMId: integer;
begin
   Result := 473;
end;

function TContestNewYorkQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNewYorkQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestNewYorkQP.GetDomesticFileName: string;
begin
   Result := 'newyork_cty';
end;

function TContestNewYorkQP.GetFriendlyName: string;
begin
   Result := 'New York QSO Party';
end;

function TContestNewYorkQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestNewYorkQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestNewYorkQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestNewYorkQP.ParseReceivedExchangeFormat(const aText: string;
                                                       aParsers: TExchangeParsers;
                                                       var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTH(aText, aExch);
end;

procedure TContestNewYorkQP.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTStateOrQSONumber;
end;

function TContestNewYorkQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestNewYorkQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                               const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestNewYorkQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestNewYorkQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
end;

function TContestNewYorkQP.GetInStateDomesticFileName: string;
begin
   Result := 'newyork';
end;

function TContestNewYorkQP.GetFlags: TContestFlags;
begin
   (* A QSO per band and mode; the multipliers ONCE, overall -- the header. *)
   Result := [cfQSOByBand, cfQSOByMode];
end;

(* "If the portable or mobile station is operating from the intersection of
   three or more NY counties, only two counties at a time may be counted for
   the same contact" -- the 2026 rules agree with NY4I's ruling (header). *)
function TContestNewYorkQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

(* PHONE 1, CW 2, RTTY/DIGITAL 3 -- the 2026 rules (header). FM is phone
   ("Phone only (SSB, FM, AM)"), so it is stated beside Phone: the shared
   FixedModePoints gives FM the "other" value, which here is digital's 3.
   An off-band QSO never reaches here (UsesBand). Both and NoMode are not
   modes a contact is made in. *)
procedure TContestNewYorkQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW:
         begin
         aQso.QSOPoints := 2;
         end;
      Phone, FM:
         begin
         aQso.QSOPoints := 1;
         end;
      Digital:
         begin
         aQso.QSOPoints := 3;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

(* "All FCC allocated amateur frequencies (excluding the 30, 17, and 12 meter
   bands) are available for QSO credit." Every band TR4W names but the three
   WARC bands -- BandLight included, as the text excludes only those three. *)
function TContestNewYorkQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10,
                       Band6, Band2, Band222, Band432, Band902, Band1296,
                       Band2304, Band3456, Band5760, Band10G, Band24G,
                       BandLight];
end;

(* "Only digital modes that natively support the NYQP exchange are permitted
   for contest credit." NY4I, issue 88, 2026-11-19: "Same as other QSO
   parties. This functionally means specifically NOT FT8, FT4 or FT2." So
   every digital submode is credited but those three, which are an automatic
   X-QSO (uContestBase.DigitalSubmodeAllowed over EVERY_SUBMODE -
   FT_SUBMODES, which also keeps eNoMode and the generic data modes, "some
   submode", credited). CW, phone and FM are credited whole -- "Phone only
   (SSB, FM, AM)"; C4FM and D-STAR are FM in TR4W and count as phone. No
   category is forced (NY4I: the allowed modes dictate it). An identity
   fact: no station is asked. *)
function TContestNewYorkQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   case aMode of
      CW, Phone, FM:
         begin
         Result := True;
         end;
      Digital:
         begin
         Result := DigitalSubmodeAllowed(aExtMode, EVERY_SUBMODE - FT_SUBMODES);
         end;
      else
         begin
         Result := False;
         end;
      end;
end;

(* ONE SEARCH-AND-POUNCE ENTRY MAY CARRY SEVERAL QTHs, at every station --
   M11 S7, 2026-10-14. It was the session's RSTDomesticQTH shape; see
   TContestBase.LogsSeveralQTHsFromOneEntry. *)
function TContestNewYorkQP.LogsSeveralQTHsFromOneEntry: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(NYQP, TContestNewYorkQP);

end.
