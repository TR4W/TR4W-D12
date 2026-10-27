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

(* THE ONTARIO QSO PARTY -- a NEW contest, registered BY ID (2026-10-26,
  issue #127).

  ITS ID IS ON-QSO-PARTY AND IT IS STORED DATA FROM THE FIRST LOG MADE WITH
  IT: never give it to another contest. There is no ContestType member -- the
  enum is frozen (Lint-FrozenContestNumbers) -- so the contest is refused on
  the multi-op network and its UDP contest number is derived from its id
  (both the registry's, nothing here).

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE, THOUGH ITS HOST IS A PROVINCE:
  one host area, county multipliers for everyone outside it, and "Non-Ontario
  stations work Ontario stations only" -- the base's host-area rule. The
  British Columbia QSO Party is the precedent for a Canadian host on this
  base. Copied from uContestGeorgiaQP (ADDING_A_CONTEST's template); a copy it
  owns. D7 had no Ontario contest: its OQPQSOPointMethod (4.70.7) was reached
  only through an operator's QSO POINT METHOD, and the 2026 rules overturn it
  (phone 2, not 1; VE3RHQ added; exact calls, not a '3CCO' substring).

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor   docs/ContestRules/QSOParties/Ontario/ -- Contest Club
                  Ontario's "2026 Ontario QSO Party Rules" (the PDF "Updated
                  01 March, 2026" and the web page "revised 01 March 2026",
                  ON-QSO-PARTY-Rules.txt), the multiplier list "Effective
                  01Jan2023" (ON-QSO-PARTY-Multipliers.txt) and the set-up
                  page (ON-QSO-PARTY-Setup.txt); fetched 2026-10-26
    NY4I          his decisions on GitHub #127, 2026-10-26
    WA7BNM        ref 357; ADIF 3.1.6/3.1.7 Contest_ID ON-QSO-PARTY

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- "the third full weekend of April"; for 2026 "April 18th 1800Z to
    Apr 19 0300Z, and April 19th - 1200Z to 2000Z". Contest schedules are not
    built (design Q99); recorded only.

  BANDS -- "All Bands 160-2 meters with the exception of the WARC bands":
    160, 80, 40, 20, 15, 10, 6 and 2 m (TR4W has no 60 m or 4 m band, and
    222 MHz is above 2 m). UsesBand; cfVHFBandsEnabled so 6 m and 2 m can be
    reached. An off-band QSO is an automatic X-QSO.

  MODES -- "You may work a station TWICE per band: once on phone and once on
    CW"; "VHF/UHF FM: 52.540, 146.550". CW and phone, FM being phone; no
    digital mode is named anywhere, so UsesMode credits CW, Phone and FM and
    a digital QSO is an automatic X-QSO.

  QSO POINTS -- "Score 2 QSO points for each station worked on phone per
    band. Score 2 QSO points for each station worked on CW per band." "Score
    10 QSO points for each contact made with CCO club stations VA3CCO &
    VE3CCO, ODXA club station VE3ODX, and RAC stations VE3RHQ and VA3RAC."
    NY4I: 10 INSTEAD OF 2 (not 2 + 10), a per-QSO point value and not a
    bonus -- so it is multiplied, and lives in CalculateQSOPoints, not
    GetBonusStations. The call is matched EXACTLY after the rover strip
    (IsClubStationCall): VE3CCO/TOR is VE3CCO, VE3CCOX is not.

  DUPES -- "once on phone and once on CW" per band: cfQSOByBand,
    cfQSOByMode. FM shares phone's dupe bits in the engine
    (uSortedStringList.DupeSlot), so no DupeModeOf is stated. "Mobile/Rover
    stations may be worked again when they change multiplier areas" -- the
    party base's received-QTH dupe key (Q118).

  OUT-OF-PROVINCE ENTRANTS -- "Non-Ontario stations work Ontario stations
    only": the party base's host-area rule (Q107), refused when typed and an
    automatic X-QSO when logged any other way. Nothing here.

  MULTIPLIERS -- "All Stations claim 1 multiplier point for each Ontario
    county worked on each band"; "Ontario stations also claim 1 multiplier
    point for each Canadian province/territory, U.S. state (plus District of
    Columbia) and DXCC country worked on each band." PER BAND: cfMultByBand,
    not cfMultByMode.
      Out of province  ontario_cty.dom: the sponsor's 50 county/district
                       codes, each its own multiplier (FCONTEST sets
                       MultipliersIsCounties). No DX multiplier.
      In province      ontario.dom: the 50 codes (each still its own
                       multiplier, no '> On' mapping), S50.DOM, DC.DOM -- DC
                       its OWN multiplier ("plus District of Columbia",
                       NY4I) -- and the 12 OTHER provinces and territories
                       written in the file, NF and LB being one
                       Newfoundland and Labrador. Ontario is no province
                       multiplier for an Ontario entrant (it sends a county).
                       THE COUNTY FILE LOADS FIRST and P13.DOM is not
                       included: Manitoulin's code MAN is also Manitoba's
                       alias in P12/P13, and the first alias added wins.
                       DXCC countries other than K, VE, KH6 and KL (those
                       are states and provinces here): the DX multiplier,
                       IN PROVINCE ONLY, on the DXCC (ARRL) list, keyed by
                       the worked station's CTY country -- one private
                       predicate, CountsDXMultiplier, asked by
                       HasDXMultiplier, DXMultiplierKey and CountryMode; the
                       key and the list are the party base's shared
                       DXCCKeyExceptUSACanadaHawaiiAlaska and DXCCCountryMode.

  SCORE -- "Total Score = Total QSO points x total multiplier points": the
    base's CombineWithMultipliers. No power multiplier (QRP 5 W, LOW 100 W
    and HIGH are categories only).

  COUNTY LINES -- "If a mobile or a rover station is on a county line or
    junction between 2 or more counties ... a separate QSO and complete
    exchange must be made and logged for each county worked"; the fixed
    county-line station the same. No maximum: GetCountyLineCountiesMax is
    CountyLineCountiesUnlimited, STATED (the base's value, quoted here). The
    rover strip and its ADIF split are the base's. Rovers log "using your
    CALL without /QTH appended" (setup page) -- the export split.

  EXCHANGE -- "Ontario stations send signal report and their county
    abbreviation"; "Non-Ontario stations send signal report and province,
    state, or DXCC country or abbreviation"; an Ontario station logs
    "county, province, state, or DXCC country abbreviation (the abbreviation
    "DX" is also acceptable". RSTDomesticOrDXQTHExchange. A DX entrant SENDS
    ITS COUNTRY PREFIX (NY4I) -- the party base's SentLocation /
    LocationOrOwnCountry, in the CQ exchange, the Cabrillo and the ADIF;
    the received column is what the DX station sent
    (CabrilloReceivedRSTQTHOrDXQTH).

  CABRILLO -- CONTEST: ON-QSO-PARTY (WA7BNM 357; the sponsor states none).
    The rules give no example line: the fields are RST and the sent QTH, RST
    and the received QTH ("The exchange for OQP requires the sent and
    received QTH, not a serial number"). "please fill in the ARRL-SECTION:
    field. This field determines how your log is scored as in-Province or
    Out-of-Province" -- NY4I: LOCATION / ARRL-SECTION required, so
    RequiresCabrilloLocation is True (Delaware's answer); the value is the
    operator's. Logs go by the web page, so no submission address.

  ADIF -- CONTEST_ID ON-QSO-PARTY. STATE is the party base's (ON for a
    county code, the station's own province or state otherwise). CNTY is NOT
    written (NY4I): ADIF's CNTY enumeration defines nothing for Canada, as
    for British Columbia (Q89).

  THE NEW CONTEST PROMPT -- its own (NY4I): the shared one says "if you are
    in ON state", and an Ontario entrant's MY STATE is its county code
    (SNewContestOntarioQPCountyOrLocation).

  NOT BUILT -- issue #133, recorded here so the claimed score is understood:
    * "Rover/Mobile stations claim the sum of multipliers worked from each
      different Ontario multiplier location" -- the multiplier sheet is one
      per log; the sponsor splits mobile logs itself ("we do that for you").
    * "Mobile/Rover stations add 300 bonus points for each Ontario
      multiplier activated" (three contacts with three different stations
      from the area, at least three areas, added after the multiplication).
    Both need the entrant's station category in scoring, which
    TStationContext does not carry. Until #133 a rover scores as a fixed
    station: points x multipliers, one sheet, no bonus. *)
unit uContestOntarioQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   (* ITS ID -- stored data; see the header. *)
   ON_QSO_PARTY_CONTEST_ID = 'ON-QSO-PARTY';

   (* "CCO club stations VA3CCO & VE3CCO, ODXA club station VE3ODX, and RAC
      stations VE3RHQ and VA3RAC" -- 10 QSO points each, as the rules spell
      them. *)
   ON_CLUB_STATIONS: array[0..4] of string = (
      'VA3CCO', 'VE3CCO', 'VE3ODX', 'VE3RHQ', 'VA3RAC');

type
   TContestOntarioQP = class(TContestStateQSOPartyBase)
   private
      (* THE ONE PREDICATE for the DX multiplier -- an Ontario entrant counts
         DXCC countries; nobody else does. HasDXMultiplier, the key and the
         country list ask it, so the answers cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;

      (* IS THIS THE CALL OF ONE OF THE FIVE 10-POINT STATIONS? -- exactly,
         after the rover strip. See the implementation. *)
      function IsClubStationCall(const aCall: string): boolean;
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE PROVINCE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES. *)
      function GetHostState: string; override;

      (* WHAT THE CONTEST IS -- every value stated, none inherited. *)
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
      function GetInStateDomesticFileName: string; override;
      function GetFlags: TContestFlags; override;

      (* "a separate QSO and complete exchange ... for each county", no
         maximum -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;

      (* LOCATION / ARRL-SECTION is required -- see the header. *)
      function GetRequiresCabrilloLocation: boolean; override;

      (* 2 points, or 10 with a club station -- see the header. Protected,
         as on TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* 160-10 m without WARC, 6 m and 2 m -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* CW and phone (FM is phone); no digital -- the header. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* ' 5NN ' and the county, state or province this station sends; its
         own country prefix when it sends none. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;

      (* THE MULTIPLIERS -- counties, or counties, states, DC and provinces,
         from the domestic file; DXCC countries for an Ontario entrant; no
         zone or prefix multiplier. *)
      function HasDXMultiplier: boolean; override;
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      function CountryMode: CountryModeType; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;

      (* WHAT THE EXCHANGE CARRIES -- a domestic QTH (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;

      (* NO ADIF CNTY -- the header. *)
      function WritesADIFCounty: boolean; override;

      (* ITS OWN NEW CONTEST PROMPT -- the header. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   SysUtils,
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   (* SNewContestOntarioQPCountyOrLocation. *)
   uAppStrings,
   uContestRegistry;

function TContestOntarioQP.GetDisplayName: string;
begin
   Result := 'Ontario QSO Party';
end;

function TContestOntarioQP.GetHostState: string;
begin
   (* The Canadian postal code -- ADIF's STATE for Ontario. *)
   Result := 'ON';
end;

function TContestOntarioQP.GetCabrilloName: string;
begin
   (* The sponsor states no CONTEST: value; WA7BNM 357 and the ADIF
      Contest_ID both say ON-QSO-PARTY. *)
   Result := 'ON-QSO-PARTY';
end;

function TContestOntarioQP.GetADIFContestId: string;
begin
   (* ADIF 3.1.6/3.1.7's Contest_ID enumeration; export writes it, import
      matches it. *)
   Result := ON_QSO_PARTY_CONTEST_ID;
end;

function TContestOntarioQP.GetWA7BNMId: integer;
begin
   Result := 357;
end;

function TContestOntarioQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestOntarioQP.GetSubmissionEmail: string;
begin
   (* "Entries should be submitted via the online web page"; oqp@va3cco.com
      is given only for a question about a log. *)
   Result := '';
end;

function TContestOntarioQP.GetDomesticFileName: string;
begin
   (* The county file. FCONTEST.FoundMyStateInDomFile reads it to decide
      whether MY STATE is an Ontario county code, and then loads
      ontario.dom or this file. *)
   Result := 'ontario_cty';
end;

function TContestOntarioQP.GetFriendlyName: string;
begin
   Result := 'Ontario QSO Party';
end;

function TContestOntarioQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestOntarioQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestOntarioQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestOntarioQP.ParseReceivedExchangeFormat(const aText: string;
                                                       aParsers: TExchangeParsers;
                                                       var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestOntarioQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

(* A DX entrant sends its own country prefix (NY4I) -- the party base's
   SentLocation; everyone else the county, state or province it stated. The
   existing helpers are handed that value, so the column format stays
   theirs. *)
function TContestOntarioQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                               const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(SentLocation(aMy), aQso);
end;

function TContestOntarioQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTState(SentLocation(aMy), aQso, aCtx);
end;

function TContestOntarioQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   (* "county, province, state, or DXCC country abbreviation": what the
      station sent; a DX station's DX QTH when nothing was typed. *)
   Result := CabrilloReceivedRSTQTHOrDXQTH(aMy, aQso, aCtx);
end;

function TContestOntarioQP.GetInStateDomesticFileName: string;
begin
   Result := 'ontario';
end;

function TContestOntarioQP.GetFlags: TContestFlags;
begin
   (* Dupes per band and per mode (CW, phone); multipliers ONCE PER BAND,
      not per mode; 6 m and 2 m are credited. *)
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand, cfVHFBandsEnabled];
end;

function TContestOntarioQP.GetCountyLineCountiesMax: integer;
begin
   (* "on a county line or junction between 2 or more counties ... a
      separate QSO and complete exchange must be made and logged for each
      county worked" -- no maximum (NY4I: unlimited). The base's value,
      stated so the rule is read here. *)
   Result := CountyLineCountiesUnlimited;
end;

function TContestOntarioQP.GetRequiresCabrilloLocation: boolean;
begin
   (* "please fill in the ARRL-SECTION: field. This field determines how
      your log is scored as in-Province or Out-of-Province" (NY4I:
      required). *)
   Result := True;
end;

(* THE CALL, EXACTLY, AFTER THE ROVER STRIP (NY4I). The strip is the
   engine's (MainUnit.LocateCallStrippingRoverCounty): a /suffix that the
   session's domestic table knows is a rover's county and comes off; any
   other suffix (/M, /P) stays, as it does there. The table is
   Station.IsDomesticQTH -- the same session table that strip and the
   host-area rule ask; with none (a station-less object) nothing is
   stripped. *)
function TContestOntarioQP.IsClubStationCall(const aCall: string): boolean;
var
   call: string;
   slash: integer;
   i: integer;
begin
   call := Trim(aCall);
   slash := Pos('/', call);
   if (slash > 0) and
      Assigned(Station.IsDomesticQTH) and
      Station.IsDomesticQTH(Copy(call, slash + 1, Length(call) - slash)) then
      begin
      call := Copy(call, 1, slash - 1);
      end;

   Result := False;
   for i := Low(ON_CLUB_STATIONS) to High(ON_CLUB_STATIONS) do
      begin
      if UnicodeSameText(call, ON_CLUB_STATIONS[i]) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(* 2 POINTS ON CW AND ON PHONE (FM is phone); 10 INSTEAD with a club
   station. A digital QSO never reaches here (UsesMode), nor an off-band one
   (UsesBand), nor a station an out-of-province entrant may not credit
   (CreditsWorkedStation). Both and NoMode are not modes a contact is made
   in. *)
procedure TContestOntarioQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW, Phone, FM:
         begin
         if IsClubStationCall(string(aQso.Callsign)) then
            begin
            aQso.QSOPoints := 10;
            end
         else
            begin
            aQso.QSOPoints := 2;
            end;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestOntarioQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10,
                       Band6, Band2];
end;

(* CW and phone, FM being phone. Any submode of CW, Phone or FM is credited
   -- eNoMode and eData included, as the contract asks -- and no submode of
   Digital is. An identity fact: no station is asked. *)
function TContestOntarioQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM];
end;

function TContestOntarioQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is the state the session SENDS (design 7.11/7.12): an
      Ontario station's county code, anyone else's state or province. A DX
      entrant has none and sends its country -- the party base's
      LocationOrOwnCountry. *)
   Result := ' 5NN ' + LocationOrOwnCountry(aStation.MyState, aStation.MyCountry);
end;

function TContestOntarioQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* "Ontario stations also claim 1 multiplier point for each ... DXCC
   country"; an out-of-province entrant works only Ontario stations. *)
function TContestOntarioQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* Every DXCC country but the USA, Canada, Hawaii and Alaska (those are
   states and provinces here, NY4I) for an Ontario entrant; none for anyone
   else. False is "leave the DX QTH as it was". *)
function TContestOntarioQP.DXMultiplierKey(const aQso: ContestExchange;
                                           out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

(* DXCC (the ARRL list) where the entrant counts the DX multiplier; the CQ
   list for anyone else, who counts none. *)
function TContestOntarioQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;

function TContestOntarioQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestOntarioQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

(* ADIF's CNTY enumeration (3.1.6 III.B.22) defines nothing for Canada
   (DXCC 1): an Ontario county code written as CNTY would be a value the
   specification does not allow (NY4I: not written; BC's Q89). *)
function TContestOntarioQP.WritesADIFCounty: boolean;
begin
   Result := False;
end;

(* THE NEW CONTEST DIALOG ASKS FOR MY STATE in Ontario's words -- the
   header. *)
procedure TContestOntarioQP.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(SNewContestOntarioQPCountyOrLocation, ncfMyState);
end;

initialization
   RegisterContestById(ON_QSO_PARTY_CONTEST_ID, TContestOntarioQP);

end.
