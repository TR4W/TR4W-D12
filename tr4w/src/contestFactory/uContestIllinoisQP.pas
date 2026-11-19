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

(* THE ILLINOIS QSO PARTY -- a NEW contest, registered BY ID (2026-11-18,
  GitHub issue #119).

  ITS ID IS IL-QSO-PARTY AND IT IS STORED DATA FROM THE FIRST LOG MADE WITH
  IT: never give it to another contest. There is no ContestType member -- the
  enum is frozen -- so its UDP contest number is derived from its id.

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE: one host state, county
  multipliers for everyone outside it, and an out-of-state entrant works
  only Illinois stations (the base's host-area rule, design 7.10, Q107).
  Its skeleton is the South Dakota class's with every grid rule taken out;
  its exchange is Oklahoma's row (a DX entrant sends its country; DXCC is an
  in-state multiplier); its DXCC cap is New Hampshire's form.

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor   docs/ContestRules/QSOParties/Illinois/ -- the Western
                  Illinois Amateur Radio Club's "Announcing the 2026 Illinois
                  QSO Party" (w9awe.org, fetched 2026-11-15) and its text
                  IL-QSO-PARTY-Rules.txt; the county chart
                  ILQP-Counties-Abbreviations.pdf (N9CDX, 2014), transcribed
                  as IL-QSO-PARTY-Counties.txt, which the .dom is checked
                  against. ILQP-Summary-Sheet.pdf is the 2007 sheet: where it
                  disagrees with the 2026 rules (it counts W/K and VE as
                  DXCC), the 2026 rules govern.
    NY4I          issue 119, first rulings: (1) an Illinois entrant's QSO
                  with an Illinois county also earns IL as a state (#317) --
                  WITHDRAWN 2026-11-19, see the RULING below; (2) DC counts
                  as Maryland. Second rulings (2026-11-18, his
                  numbers 1-7): the third full weekend of October; the
                  names as written; a non-IL station works only IL
                  stations; the W9AWE/W9OAB bonus points every year;
                  standard RY or DG; county codes only (Lee is LEE, three
                  letters, every other county four -- the chart); FM is
                  phone, 1 point.
    DXLog.net     ILQP.txt (updated 2026-09-07). A cross-check only; where it
                  and the rules disagree, the rules win (below).
    ADIF          "IL QSO PARTY" (blanks, not hyphens) is the ADIF 3.1.8
                  Contest_ID enumeration's value; adifmt v0.1.23 refuses
                  IL-QSO-PARTY (2026-11-18).

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- "1700 UTC October 18, 2026 to 0100 UTC October 19, 2026", the
    Sunday of the third full weekend of October -- NY4I's recurrence rule
    (issue 119, 2026-11-18). GetSchedule: '3rd full weekend of October +1d',
    1700 UTC for 8 hours. 2027: October 17; 2028: October 22 (October 1 is a
    Sunday, so this is NOT the third Sunday, the 15th).

  BANDS -- "160 through 2 meters, excluding WARC bands (60, 30, 17 and 12
    meters)": 160, 80, 40, 20, 15, 10, 6 and 2 m. UsesBand; cfVHFBandsEnabled.
    The same list as DXLog's.

  MODES -- phone, CW and digital; "FT4 and FT8 contacts will receive no
    contact credit. Other digital modes are encouraged." UsesMode credits CW,
    phone, FM and every digital submode but FT8 and FT4 (Nebraska's form), so
    an FT8 or FT4 QSO is logged and is an automatic X-QSO (Q98). "No repeater
    QSOs": a repeater QSO cannot be told from a simplex one in the log; not
    enforced.

  DUPES -- "Stations may be worked once per band and mode (phone and
    CW/digital) and once per band/mode/county for IL Mobile and Rover
    stations". cfQSOByBand and cfQSOByMode; DupeModeOf files Digital under CW
    (New England's seam), so an RTTY QSO after a CW QSO on the same band is a
    dupe; FM is already phone on the dupe sheet. The rover clause is the
    party base's received-QTH dupe key. DXLog's MODE_GROUP says the same.

  EXCHANGE -- "IL stations give RS/T and county; others give RS/T and state,
    province or country". RSTDomesticOrDXQTHExchange, Oklahoma's helper row
    (ADDING_A_CONTEST A3): a DX entrant SENDS its own country prefix (the
    party base's SentLocation / LocationOrOwnCountry; DXLog's "DX stations
    send DXCC prefix"); the received column of a DX station is its DXCC key,
    else what it sent (CabrilloReceivedRSTDomesticQTHOrDXQTH, review H4).

  QSO POINTS -- "Phone QSO: 1 point; CW/digital QSO 2 points." CW 2, every
    digital submode credited 2, Phone and FM 1. DXLog gives FM 2 (only SSB
    scores 1 there); NY4I (issue 119): "FM is phone so 1 point".

  OUT-OF-STATE ENTRANTS -- "Non-IL stations multiply points by the number of
    IL counties worked": the party base's host-area rule, refused when typed
    and an automatic X-QSO when logged any other way. NY4I (issue 119):
    "Non-IL stations only work IL stations." DXLog refuses the same QSOs.

  MULTIPLIERS -- "IL stations multiply points by the sum of IL counties, US
    states, VE provinces and DXCC countries (maximum 5) worked. Canada, KH6
    and KL7 do not count as DX entities. Additional DX contacts count for
    points but not multipliers. Non-IL stations multiply points by the number
    of IL counties worked." ONCE OVERALL for every kind (neither cfMultByBand
    nor cfMultByMode; the summary sheet counts each once).
      Outside IL        illinois_cty.dom: the 102 counties, each its own
                        multiplier. No DX multiplier.
      Inside IL         illinois.dom: the counties (each its own), DC as
                        Maryland (NY4I's ruling 2), s50.dom, p13.dom (NF and
                        LB read as NL). Alaska and Hawaii are states (the
                        summary sheet lists them). DXCC countries are the DX
                        multiplier, IN STATE ONLY, every entity but K, VE, KH6
                        and KL (uDXMultiplierKey; DXLog's MULT2 excludes the
                        same four), on the ARRL list (DXLog's
                        DXCC_DB_USE_ARRL_LIST) -- one private predicate,
                        CountsDXMultiplier. "maximum 5": the score counts at
                        most 5 (CombineWithMultipliers); the sheet and the
                        display still show every country worked, as DXLog's
                        own note says of its display.
    RULING (NY4I, issue 119, 2026-11-19) -- AN ILLINOIS ENTRANT'S QSO WITH
      AN ILLINOIS COUNTY EARNS THE COUNTY ONLY, NOT IL AS A STATE: "Unknown
      so assume no for now as to not inflate the score." The 2026 rules are
      silent; the only evidence for IL-as-a-state is the 2007 summary sheet
      (Rev A, June 2006), which lists Illinois among the states for an
      Illinois station. That reversed his 2026-11-18 ruling, which the
      5.0.43 build carried (#317's opt-in). DXLog counts the county only, as
      now. So the class does NOT override AdditionalDomesticMultiplierKey;
      if the sponsor says IL counts, the restore is the one line Alabama
      states (Result := InStateCountyEarnsHostState(aQso, aKey)) plus its
      row in uTestAdditionalDomesticMultiplier's PartyCase --
      illinois.dom's only keys longer than two letters are the counties,
      the helper's table rule. A station that sends IL itself IS the IL
      multiplier: s50.dom lists it and nothing refuses it (no
      CountsAsMultiplier override); the ruling is about the county QSO
      only. Outside Illinois a county earns the county only.

  COUNTY LINES -- "Contacts with/by stations at the border of 2/3/4 counties
    count as 2/3/4 counties and 2/3/4 QSOs": GetCountyLineCountiesMax 4.
    "County lines established by waterways may not be activated": not
    knowable from the log; not enforced.

  SCORE -- points x (counties + states + provinces + at most 5 DXCC), plus
    the bonus. No power multiplier.

  BONUS -- "any entrant contacting these stations will have a 100 point
    bonus added to the final score. Total of 200 points possible": W9AWE and
    W9OAB, 100 points each, bsOnce each, added after multiplication, a
    credited contact only (no dupe, no X-QSO). The rules call them "new for
    2025/2026"; NY4I (issue 119): assume they are bonus stations in 2027
    too, so the list is not tied to a year. DXLog states no bonus: the
    rules win.

  NOT BUILT -- MOBILE, ROVER AND PORTABLE CATEGORIES, issue #133: the
    entrant's own category and county changes do not reach scoring. A
    county-line ENTRANT (portable) logging one QSO per county it activates
    is the operator's, as for every party.

  CABRILLO -- CONTEST: IL-QSO-PARTY (DXLog's CABRILLO_CONTEST_NAME; the rules
    state none). The standard line; the rules name its fields ("the RS(T)
    sent; the location of your station; the call sign of the station
    contacted; the RS(T) received; and the location of the station
    contacted") but print no example. MODES: the base's CW, PH, FM, RY for
    RTTY and DG for any other digital submode -- NY4I (issue 119): "Use the
    standard RY or DG" (DXLog writes RY for every digital mode).
    CONTEST: IL-QSO-PARTY with dashes, the ADIF id with blanks: NY4I
    confirmed both spellings as written.

  COUNTIES -- the sponsor's codes only, not full county names (NY4I, issue
    119, quoting the rules: "Each Illinois county has an established 4
    letter abbreviation (Lee County excepted)"). Lee is LEE, three letters.

  ADIF -- CONTEST_ID "IL QSO PARTY", the enumeration's spelling. STATE: IL
    for a county (the party base's ADIFCountyState), the worked station's
    state or province otherwise. CNTY: the .dom display name, which the ADIF
    validator reads as the enumeration's county name for all 102 (it drops
    blanks and spells "St." as Saint: Rock Island, St. Clair, JoDaviess).
    An ADIF file that writes "IL-QSO-PARTY" (DXLog's Cabrillo spelling) does
    not match on import; NY4I's answer confirmed the names but not this, so
    it is still open (issue 119).

  SUBMISSION -- "Electronic logs should be sent as attachments to
    n9jf@arrl.net."

  WA7BNM -- 0: the calendar's terms bar automated access (a bench item).

  3830 -- the base's one "Mults" column; the form was not checked. *)
unit uContestIllinoisQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   (* ITS ID -- stored data; see the header. *)
   IL_QSO_PARTY_CONTEST_ID = 'IL-QSO-PARTY';

   (* "DXCC countries (maximum 5)" -- the most the score counts. *)
   IL_QSO_PARTY_MAXIMUM_DX_MULTIPLIERS = 5;

type
   TContestIllinoisQP = class(TContestStateQSOPartyBase)
   private
      (* THE ONE PREDICATE for the DX multiplier -- an Illinois entrant
         counts DXCC countries; nobody else does. HasDXMultiplier, the key and
         the country list ask it, so the answers cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;
   protected
      function GetDisplayName: string; override;
      function GetSchedule: string; override;
      function GetFriendlyName: string; override;
      function GetHostState: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetWA7BNMId: integer; override;
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetInStateDomesticFileName: string; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function GetFlags: TContestFlags; override;
      (* "the border of 2/3/4 counties" -- four at most. *)
      function GetCountyLineCountiesMax: integer; override;
      function ParseReceivedExchangeFormat(const aText: string;
         aParsers: TExchangeParsers; var aExch: ContestExchange): boolean; override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string; override;
      (* CW and digital 2, phone and FM 1 -- the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
      (* POINTS x MULTIPLIERS, at most 5 of them DXCC -- the header. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
      function GetBonusStations: TBonusStationList; override;
      function CountsTowardBonus(const aQso: ContestExchange): boolean; override;
   public
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      (* "once per band and mode (phone and CW/digital)": Digital is CW. *)
      function DupeModeOf(aMode: ModeType): ModeType; override;
      function CQExchangeDefault(const aStation: TStationContext): string; override;
      function HasDXMultiplier: boolean; override;
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      function CountryMode: CountryModeType; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;
      function ExchangeCarriesDomesticQTH: boolean; override;
      (* NO AdditionalDomesticMultiplierKey: a county does not also earn IL
         (NY4I, 2026-11-19) -- the header's RULING. *)
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   (* DXCCKeyExceptUSACanadaHawaiiAlaska, DXCCCountryMode -- issue #136. *)
   uDXMultiplierKey,
   uContestRegistry;

function TContestIllinoisQP.GetDisplayName: string;
begin
   Result := 'Illinois QSO Party';
end;

(* WHEN IT RUNS -- https://w9awe.org/ilqp/, "Announcing the 2026 Illinois QSO
   Party": "1700 UTC October 18, 2026 to 0100 UTC October 19, 2026", the
   Sunday of the third full weekend of October (NY4I, issue 119,
   2026-11-18). '+1d' is the Sunday after that weekend's Saturday. *)
function TContestIllinoisQP.GetSchedule: string;
begin
   Result := '3rd full weekend of October +1d at 17:00 UTC for 8h';
end;

function TContestIllinoisQP.GetFriendlyName: string;
begin
   Result := 'Illinois QSO Party';
end;

function TContestIllinoisQP.GetHostState: string;
begin
   Result := 'IL';
end;

function TContestIllinoisQP.GetCabrilloName: string;
begin
   (* The rules state none; DXLog's CABRILLO_CONTEST_NAME=IL-QSO-PARTY. *)
   Result := 'IL-QSO-PARTY';
end;

function TContestIllinoisQP.GetADIFContestId: string;
begin
   (* The ADIF Contest_ID enumeration's spelling, with blanks -- not the
      contest's id. Export writes it, import matches it. *)
   Result := 'IL QSO PARTY';
end;

function TContestIllinoisQP.GetWA7BNMId: integer;
begin
   (* Not looked up: the calendar bars automated access -- a bench item. *)
   Result := 0;
end;

function TContestIllinoisQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestIllinoisQP.GetSubmissionEmail: string;
begin
   (* "Electronic logs should be sent as attachments to n9jf@arrl.net." *)
   Result := 'n9jf@arrl.net';
end;

function TContestIllinoisQP.GetDomesticFileName: string;
begin
   Result := 'illinois_cty';
end;

function TContestIllinoisQP.GetInStateDomesticFileName: string;
begin
   Result := 'illinois';
end;

function TContestIllinoisQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestIllinoisQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestIllinoisQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestIllinoisQP.GetFlags: TContestFlags;
begin
   (* "once per band and mode"; multipliers ONCE OVERALL (neither
      cfMultByBand nor cfMultByMode); 6 m and 2 m credited. *)
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

function TContestIllinoisQP.GetCountyLineCountiesMax: integer;
begin
   (* "Contacts with/by stations at the border of 2/3/4 counties count as
      2/3/4 counties and 2/3/4 QSOs." *)
   Result := 4;
end;

function TContestIllinoisQP.ParseReceivedExchangeFormat(const aText: string;
   aParsers: TExchangeParsers; var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

(* "others give RS/T and state, province or country" -- the party base's
   SentLocation: a DX entrant with no MY STATE sends its own country. *)
function TContestIllinoisQP.GetADIFSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(SentLocation(aMy), aQso);
end;

function TContestIllinoisQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTState(SentLocation(aMy), aQso, aCtx);
end;

function TContestIllinoisQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   (* A DX station sent its country: the received column is its DX QTH,
      else what it sent (review H4). *)
   Result := CabrilloReceivedRSTDomesticQTHOrDXQTH(aMy, aQso, aCtx);
end;

(* CW AND DIGITAL 2, PHONE AND FM 1. An off-band or off-mode QSO (FT8, FT4)
   never reaches here, nor a station this entrant may not credit. *)
procedure TContestIllinoisQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW, Digital:
         begin
         aQso.QSOPoints := 2;
         end;
      Phone, FM:
         begin
         aQso.QSOPoints := 1;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

(* THE DXCC CAP. Outside Illinois there is no DX multiplier, so the DX count
   is 0 and the cap never bites. *)
function TContestIllinoisQP.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := ContestPoints(aTotals) *
             SummedMultipliersWithKindCapped(aTotals, rmDX, IL_QSO_PARTY_MAXIMUM_DX_MULTIPLIERS);
end;

function TContestIllinoisQP.GetBonusStations: TBonusStationList;
begin
   (* "W9AWE ... and W9OAB ... any entrant contacting these stations will
      have a 100 point bonus added to the final score. Total of 200 points
      possible." -- once each. *)
   Result := nil;
   SetLength(Result, 2);
   Result[0].Call := 'W9AWE';
   Result[0].Points := 100;
   Result[0].Scope := bsOnce;
   Result[1].Call := 'W9OAB';
   Result[1].Points := 100;
   Result[1].Scope := bsOnce;
end;

function TContestIllinoisQP.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   Result := IsCreditedContact(aQso);
end;

function TContestIllinoisQP.UsesBand(aBand: BandType): boolean;
begin
   (* "160 through 2 meters, excluding WARC bands". *)
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10,
                       Band6, Band2];
end;

(* PHONE, CW AND DIGITAL BUT FT4 AND FT8 -- "FT4 and FT8 contacts will receive
   no contact credit". eNoMode and eData mean "some submode", so an old
   record is never proven off-mode. An identity fact: no station is asked. *)
function TContestIllinoisQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   case aMode of
      CW, Phone, FM:
         begin
         Result := True;
         end;
      Digital:
         begin
         Result := not (aExtMode in [eFT8, eFT4]);
         end;
      else
         begin
         Result := False;
         end;
      end;
end;

function TContestIllinoisQP.DupeModeOf(aMode: ModeType): ModeType;
begin
   if aMode = Digital then
      begin
      Result := CW;
      end
   else
      begin
      Result := aMode;
      end;
end;

function TContestIllinoisQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is what the session SENDS (design 7.11/7.12): an
      Illinois station's county, anyone else's state or province. A DX
      entrant has none and sends its country. *)
   Result := ' 5NN ' + LocationOrOwnCountry(aStation.MyState, aStation.MyCountry);
end;

function TContestIllinoisQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* "IL stations multiply points by the sum of ... DXCC countries (maximum
   5)"; none outside, where an entrant works only Illinois stations. *)
function TContestIllinoisQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* "Canada, KH6 and KL7 do not count as DX entities" -- and the USA is the
   states. False is "leave the DX QTH as it was". *)
function TContestIllinoisQP.DXMultiplierKey(const aQso: ContestExchange;
                                            out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

function TContestIllinoisQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;

function TContestIllinoisQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestIllinoisQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

function TContestIllinoisQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

initialization
   RegisterContestById(IL_QSO_PARTY_CONTEST_ID, TContestIllinoisQP);

end.
