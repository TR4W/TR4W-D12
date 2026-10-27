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

(* THE OKLAHOMA QSO PARTY -- a NEW contest, registered BY ID (2026-10-26,
  GitHub issue #126).

  ITS ID IS OK-QSO-PARTY AND IT IS STORED DATA FROM THE FIRST LOG MADE WITH
  IT: never give it to another contest. There is no ContestType member -- the
  enum is frozen (Lint-FrozenContestNumbers) -- so the contest is refused on
  the multi-op network and its UDP contest number is derived from its id
  (both the registry's, nothing here).

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE: one host state, county
  multipliers for everyone outside it, and "Non Oklahoma stations work only
  Oklahoma stations" -- the base's host-area rule (design 7.10, Q107).
  Copied from uContestGeorgiaQP (ADDING_A_CONTEST's template), not from a
  nearby party; a copy it owns. D7 never had this contest.

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor   docs/ContestRules/QSOParties/Oklahoma/
                  OK-QSO-PARTY-Rules.txt -- "The 2026 Oklahoma QSO Party",
                  http://k5cm.com/okqp2026rules.pdf (K5CM), fetched 2026-10-26;
                  OK-QSO-PARTY-Overview.txt -- the sponsor's overview page,
                  the same year; OK-QSO-PARTY-Counties.txt -- the sponsor's
                  county table (the PDF has none).
    ADIF 3.1.6/7  Contest_ID OK-QSO-PARTY
    NY4I          his decisions on #126 (2026-10-26), quoted below.

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- "Saturday March 14 1400 to 0200 UTC / Sunday March 15 1400 to 2200
    UTC" -- one event, one log ("Everyone may operate the entire 19 hour
    period"; the two sessions add to 20 h, stale text in the rules, no
    effect). Contest schedules are not built (design Q99); recorded only.

  BANDS -- "Operate only the 3.5, 7, 14, 21, 28, 50, and 144 MHz bands": 80,
    40, 20, 15, 10, 6 and 2 m. No 160 m, no WARC. UsesBand; cfVHFBandsEnabled
    so 6 m and 2 m can be reached. NY4I: 2 m is credited although WA7BNM and
    DXLog omit it, because the rules list it.

  MODES -- "Mixed mode (Phone, CW, Digital (NO FT8 allowed)" and "No
    FT8/FT4"; the overview: "Only PSK, RTTY and JS8Call are allowed as
    digital contacts." NY4I: digital is RTTY, PSK and JS8 only (the overview
    narrows the PDF, so this satisfies both). Every other digital submode
    (FT8, FT4, JT65, MFSK, ...) is an automatic X-QSO. FM is phone (the
    rules' modes are Phone, CW and Digital). UsesMode.

  EXCHANGE -- "Oklahoma stations send signal report and county. W/VE stations
    (including KH6/KL7) send signal report and state or province. DX stations
    (including KH2/KP4) send signal report and DXCC prefix."
    RSTDomesticOrDXQTHExchange; the three-letter county codes are
    oklahoma_cty.dom. A DX ENTRANT SENDS ITS OWN PREFIX, NOT "DX" (NY4I): the
    party base's SentLocation / LocationOrOwnCountry, used by the CQ
    exchange, Cabrillo and ADIF -- lifted there from the North Dakota QSO
    Party, its first user. A DX station's received column is its prefix as
    sent (CabrilloReceivedRSTQTHOrDXQTH).

  QSO POINTS -- "Count two points per phone QSO ... Count three points per
    CW QSO ... Count three points per Digital QSO (No FT8/FT4)", the same for
    an Oklahoma entrant and for anyone else. Phone 2 (FM is phone), CW 3,
    digital 3. CalculateQSOPoints.

  DUPES -- "Stations may be worked again on each band and mode": cfQSOByBand,
    cfQSOByMode; the overview: "CW and Digital contacts will be scored
    separately" -- Digital is its own dupe mode, which the base's DupeModeOf
    (identity) already gives. "Oklahoma mobile stations that change counties
    are considered to be a new station and may be worked again for QSO and
    multiplier credit" -- the party base's received-QTH dupe key and rover
    strip/split, inherited.

  OUT-OF-STATE ENTRANTS -- "Non Oklahoma stations work only Oklahoma
    stations": the party base's host-area rule, refused when typed and an
    automatic X-QSO when logged any other way. Nothing here.

  MULTIPLIERS -- "A Multiplier counts once, regardless of the number bands
    or modes it is worked on": neither cfMultByBand nor cfMultByMode.
      Oklahoma stations   oklahoma.dom: "The 77 Oklahoma counties" (each its
                          own multiplier -- oklahoma_cty.dom maps none to
                          Ok), "The 50 states (DC counts as Maryland)" (the
                          file's Dc > Md, before S50.DOM), "The 13 Canadian
                          Provinces/Territories" (P13.DOM; NF and LB read as
                          NL). NY4I: "OK stays in the state list ('The 50
                          states'); it is harmless, since an OK station sends
                          a county" -- so no CountsAsMultiplier override.
                          "DXCC countries* (excluding US, Canada, KH6 and
                          KL7)": the DX multiplier, IN STATE ONLY, every
                          country but K, VE, KH6 and KL
                          (uDXMultiplierKey.DXCCKeyExceptUSACanadaHawaiiAlaska),
                          on the DXCC (ARRL) list (DXCCCountryMode) -- one
                          private predicate CountsDXMultiplier asked by
                          HasDXMultiplier, DXMultiplierKey and CountryMode.
      Non Oklahoma        oklahoma_cty.dom: "The 77 Oklahoma counties", each
                          its own multiplier (FCONTEST sets
                          MultipliersIsCounties). No DX multiplier.

  COUNTY LINES -- "Oklahoma mobile stations operating on a 2, 3, or 4 county
    line may be counted as 2, 3, or 4 QSO and multipliers. Separate log
    entries must be entered for each county/QSO": GetCountyLineCountiesMax =
    4; TR4W's county-line entry already logs one QSO per county.

  SCORE -- "Multiply total QSO Points by total Multipliers": the base's
    CombineWithMultipliers. No power multiplier.

  NOT BUILT -- THE MOBILE BONUS, issue #133: "Oklahoma Mobile stations can
    earn 500 points per county by making at least 10 QSO in the county"
    (added after multiplying -- the sponsor's 2026 results). It needs the
    entrant's station category in scoring, which TStationContext does not
    carry. Until #133 the score is points x multipliers only.

  NOT REPRESENTABLE, CONDUCT RULES ONLY -- "Two mobiles traveling together
    may work each other one time from each county combination"; "Pack
    Roving / California train operation is absolutely not allowed";
    "Contacts through repeaters, digipeaters, internet, or gateways are not
    permitted". Nothing built.

  CABRILLO -- CONTEST: OK-QSO-PARTY, the rules' own example header. The
    rules' example line "QSO: 7042 CW 2014-03-22 1301 K5CM 599 MUS K4AMC 599
    TN": RST and the sent county or state, RST and the received QTH -- the
    standard QSO line. LOCATION: OK appears in the example header but is not
    required, so it is not demanded (as Georgia). "remove all the /M and /CTY
    from the calls of the mobile station" -- the base's rover split. The
    rules' custom "CATEGORY: OKLAHOMA MOBILE ..." lines are not written; TR4W
    writes CATEGORY-* tags (a bench item, NY4I). ADIF -- CONTEST_ID
    OK-QSO-PARTY (ADIF's own enumeration).

  SUBMISSION -- "Submit logs: https://okqp.contesting.com/"; the rules
    mention e-mail but give no address (NY4I: none), so ''.

  3830 -- 3830scores.com's Oklahoma QSO Party breakdown (2026, fetched
    2026-10-26) has one "Mults" column, the base's default: no
    Get3830Summary override. *)
unit uContestOklahomaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   (* ITS ID -- stored data; see the header. *)
   OK_QSO_PARTY_CONTEST_ID = 'OK-QSO-PARTY';

type
   TContestOklahomaQP = class(TContestStateQSOPartyBase)
   private
      (* THE ONE PREDICATE for the DX multiplier -- an Oklahoma entrant counts
         DXCC countries; nobody else does. HasDXMultiplier, the key and the
         country list ask it, so the answers cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES. *)
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

      (* A county line of up to four counties -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;

      (* Phone 2, CW 3, digital 3 -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* 80, 40, 20, 15, 10, 6 and 2 m -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* CW, phone (FM is phone), and digital as RTTY, PSK or JS8 -- the
         header. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* ' 5NN ' and the county, state or province this station sends; its
         own country when it sends none. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;

      (* THE MULTIPLIERS -- counties, or states, provinces and counties, from
         the domestic file; DXCC countries for an Oklahoma entrant; no zone
         or prefix multiplier. *)
      function HasDXMultiplier: boolean; override;
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      function CountryMode: CountryModeType; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;

      (* WHAT THE EXCHANGE CARRIES -- a domestic QTH (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   (* DXCCKeyExceptUSACanadaHawaiiAlaska, DXCCCountryMode -- issue #136. *)
   uDXMultiplierKey,
   uContestRegistry;

function TContestOklahomaQP.GetDisplayName: string;
begin
   Result := 'Oklahoma QSO Party';
end;

function TContestOklahomaQP.GetHostState: string;
begin
   Result := 'OK';
end;

function TContestOklahomaQP.GetCabrilloName: string;
begin
   (* The rules' example header: "CONTEST: OK-QSO-PARTY". *)
   Result := 'OK-QSO-PARTY';
end;

function TContestOklahomaQP.GetADIFContestId: string;
begin
   (* ADIF 3.1.6 and 3.1.7's Contest_ID enumeration; export writes it,
      import matches it. *)
   Result := OK_QSO_PARTY_CONTEST_ID;
end;

function TContestOklahomaQP.GetWA7BNMId: integer;
begin
   (* contestcalendar.com contestdetails.php?ref=293, "Oklahoma QSO Party". *)
   Result := 293;
end;

function TContestOklahomaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestOklahomaQP.GetSubmissionEmail: string;
begin
   (* "Submit logs: https://okqp.contesting.com/". The rules mention e-mail
      but give no address (NY4I: none). *)
   Result := '';
end;

function TContestOklahomaQP.GetDomesticFileName: string;
begin
   (* The county file. FCONTEST.FoundMyStateInDomFile reads it to decide
      whether MY STATE is an Oklahoma county, and then loads oklahoma.dom or
      this file. Lower case: the file's own name, which matters off
      Windows. *)
   Result := 'oklahoma_cty';
end;

function TContestOklahomaQP.GetFriendlyName: string;
begin
   Result := 'Oklahoma QSO Party';
end;

function TContestOklahomaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestOklahomaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestOklahomaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestOklahomaQP.ParseReceivedExchangeFormat(const aText: string;
                                                        aParsers: TExchangeParsers;
                                                        var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestOklahomaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

(* "DX stations (including KH2/KP4) send signal report and DXCC prefix"
   (NY4I: their own prefix). The party base's SentLocation: a DX entrant has
   no MY STATE, so it sends its own country; anyone else the county, state
   or province it stated. The column helpers are handed that value, so the
   format stays theirs. *)
function TContestOklahomaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(SentLocation(aMy), aQso);
end;

function TContestOklahomaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTState(SentLocation(aMy), aQso, aCtx);
end;

function TContestOklahomaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   (* A DX station sent its DXCC prefix: the received column is that. *)
   Result := CabrilloReceivedRSTQTHOrDXQTH(aMy, aQso, aCtx);
end;

function TContestOklahomaQP.GetInStateDomesticFileName: string;
begin
   Result := 'oklahoma';
end;

function TContestOklahomaQP.GetFlags: TContestFlags;
begin
   (* Dupes per band and per mode; multipliers ONCE OVERALL (neither
      cfMultByBand nor cfMultByMode); 6 m and 2 m are credited. *)
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

function TContestOklahomaQP.GetCountyLineCountiesMax: integer;
begin
   (* "operating on a 2, 3, or 4 county line may be counted as 2, 3, or 4 QSO
      and multipliers". *)
   Result := 4;
end;

(* PHONE 2, CW 3, DIGITAL 3. FM is phone. An off-band QSO (UsesBand), a
   digital QSO that is not RTTY, PSK or JS8 (UsesMode) and a station an
   out-of-state entrant may not credit (CreditsWorkedStation) never reach
   here. Both and NoMode are not modes a contact is made in. *)
procedure TContestOklahomaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW, Digital:
         begin
         aQso.QSOPoints := 3;
         end;
      Phone, FM:
         begin
         aQso.QSOPoints := 2;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestOklahomaQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band80, Band40, Band20, Band15, Band10, Band6, Band2];
end;

(* "Only PSK, RTTY and JS8Call are allowed as digital contacts" (NY4I's
   decision on #126). eNoMode and eData mean "some submode of Digital" (the
   contract) and are credited; reversed RTTY and PSK are still RTTY and PSK.
   CW, phone and FM are credited. An identity fact: no station is asked. *)
function TContestOklahomaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   case aMode of
      CW, Phone, FM:
         begin
         Result := True;
         end;
      Digital:
         begin
         Result := aExtMode in [eNoMode, eData, eRTTY, eRTTY_R,
                                ePSK31, ePSK63, ePSK_R, eJS8];
         end;
      else
         begin
         Result := False;
         end;
      end;
end;

function TContestOklahomaQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is the state the session SENDS (design 7.11/7.12): an
      Oklahoma station's county, anyone else's state or province. A DX
      entrant has none and sends its country -- the party base's
      LocationOrOwnCountry. *)
   Result := ' 5NN ' + LocationOrOwnCountry(aStation.MyState, aStation.MyCountry);
end;

function TContestOklahomaQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* "Oklahoma stations: ... DXCC countries" -- yes inside Oklahoma; none
   outside, where an entrant works only Oklahoma stations. *)
function TContestOklahomaQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* "DXCC countries* (excluding US, Canada, KH6 and KL7)" -- every country but
   the USA, Canada, Hawaii and Alaska (those are states and provinces here)
   for an Oklahoma entrant; none for anyone else. False is "leave the DX QTH
   as it was". *)
function TContestOklahomaQP.DXMultiplierKey(const aQso: ContestExchange;
                                            out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

(* DXCC (the ARRL list) where the entrant counts the DX multiplier; the CQ
   list for anyone else, who counts none. *)
function TContestOklahomaQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;

function TContestOklahomaQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestOklahomaQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

initialization
   RegisterContestById(OK_QSO_PARTY_CONTEST_ID, TContestOklahomaQP);

end.
