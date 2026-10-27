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

(* THE QUEBEC QSO PARTY -- a NEW contest, registered BY ID (2026-10-26,
  issue #128).

  ITS ID IS QC-QSO-PARTY AND IT IS STORED DATA FROM THE FIRST LOG MADE WITH
  IT: never give it to another contest. There is no ContestType member -- the
  enum is frozen (Lint-FrozenContestNumbers) -- so the contest is refused on
  the multi-op network and its UDP contest number is derived from its id
  (both the registry's, nothing here).

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE, THOUGH ITS HOST IS A PROVINCE:
  one host area ("VE2 is used here for any station operating within the
  physical boundary of the province of Quebec"), its 17 administrative
  regions as the subdivisions (Appendix I), and "Non-VE2 stations obtain
  points for contacts for VE2 stations only" -- the base's host-area rule.
  British Columbia and Ontario are the precedents for a Canadian host on
  this base. Copied from uContestGeorgiaQP (ADDING_A_CONTEST's template); a
  copy it owns. D7 never had this contest.

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor   docs/ContestRules/QSOParties/Quebec/ -- Club Radio Amateur
                  de l'Outaouais (CRAO), the 2026 rules in English
                  (QC-QSO-PARTY-Rules-EN.txt) and in French
                  (QC-QSO-PARTY-Rules-FR.txt), fetched 2026-10-26. The
                  sponsor publishes both and says neither governs.
    NY4I          his decisions on GitHub #128, 2026-10-26
    WA7BNM        ref 53 (named in the rules); ADIF 3.1.7 Contest_ID
                  QC-QSO-PARTY

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- "Sunday April 19th, 2026, from 13:00 to 24:00 UTC"; "the Sunday
    of the third full weekend of April". Contest schedules are not built
    (design Q99); recorded only.

  BANDS -- "All amateur bands between 80 et 2 m, excepted WARC bands": 80,
    40, 20, 15, 10, 6 and 2 m. NO 160 m (NY4I: DXLog lists it, wrongly). 60 m
    lies in that range and is not WARC, but TR4W has no 60 m band. UsesBand;
    cfVHFBandsEnabled so 6 m and 2 m can be reached. An off-band QSO is an
    automatic X-QSO.

  MODES -- "Phone (SSB or FM) and Morse code (CW)." UsesMode credits CW,
    Phone and FM; a digital QSO is an automatic X-QSO. "operators cannot use
    repeaters" is operator conduct, not a log rule.

  QSO POINTS -- "1 point per QSO on phone on each frequency band / 2 points
    per QSO on CW on each frequency band", the same for every entrant.

  DUPES -- "A station can be contacted twice per band, once on phone and
    once on CW": cfQSOByBand, cfQSOByMode. FM shares phone's dupe bits in the
    engine (uSortedStringList.DupeSlot), so SSB and FM on one band are one
    phone contact and no DupeModeOf is stated. A worked mobile in a new
    region is a new QSO -- the party base's received-QTH dupe key (Q118).

  OUT-OF-PROVINCE ENTRANTS -- "Non-VE2 stations obtain points for contacts
    for VE2 stations only": the party base's host-area rule (Q107), refused
    when typed and an automatic X-QSO when logged any other way. Nothing
    here.

  MULTIPLIERS -- "For all stations, one multiplier point is given for each
    first contact made in each administrative region, on each frequency band
    worked on these regions. No additional multipliers are given for working
    multiple modes." "Additionally, a VE2 station is given one multiplier
    point for each first contact with a province or Canadian territory, US
    state or DX, for each band worked with these territories. Only one DX
    multiplier is given for entities worked outside of Canada or USA." PER
    BAND: cfMultByBand, not cfMultByMode.
      Out of province  quebec_cty.dom: the 17 regions, each its own
                       multiplier (FCONTEST sets MultipliersIsCounties).
      In province      quebec.dom: the 17 regions (each still its own -- "for
                       all stations", so no '> Qc' mapping), S51.DOM (the 50
                       states and DC), the 12 other provinces and territories
                       written in the file -- NF and LB TWO multipliers (the
                       rules' Appendix II; NY4I), NT and NWT ONE (the same
                       territory listed twice; NY4I) -- and ONE Dx entry,
                       per band (NY4I). "the Province of Quebec (QC) is not
                       a valid territory entry": QC is in no file, so it
                       never counts and no DomesticMultiplierIsHostState is
                       needed. P12/P13 are NOT included (NY4I): they give
                       Quebec the alias QUE -- Capitale-Nationale's region
                       code -- and VE2, which would make the rover strip take
                       "W2ABC/VE2" (the rules' own example of an outsider in
                       Quebec) as a region. The region file loads first.
                       THE DX MULTIPLIER IS THE DOMESTIC Dx ENTRY (the NC /
                       Missouri / Michigan mechanism), so HasDXMultiplier is
                       False -- "Other DXCC entities must be logged as DX".
    No zone or prefix multiplier.

  EXCHANGE -- "VE2 stations: Must send a signal report and their
    administrative region abbreviation ... They must log the received signal
    report as well as the province, US state or DX for other entities";
    "Non-VE2 stations: Must send a signal report and their province, US state
    or DX for other entities ... They must log the received signal report as
    well as the administrative region". RSTDomesticQTHExchange, as NC and
    Missouri: EVERY received QTH is looked up in the session's table, so an
    in-province entrant's "DX" is the Dx multiplier. (Georgia's
    RSTDomesticOrDXQTHExchange sends a DX call to the free-text DX branch,
    which never looks DX up -- no DX multiplier.) A DX ENTRANT SENDS "DX", not
    its country: so NOT the party base's SentLocation (North Dakota,
    Oklahoma, New Mexico, Ontario) -- the StateOrDX Cabrillo helper writes DX
    when MY STATE is empty, and the CQ exchange says DX, as Georgia's do.
    The ADIF STX_STRING is ADIFSentRSTStateOrDX, so it says DX too (it is the
    information transmitted; 2026-10-27) -- as Georgia's, NC's and Missouri's
    do.

  SCORE -- "QSO-score = (Total of the QSO points) * (Total of the multiplier
    points)": the base's CombineWithMultipliers. No power multiplier (QRP 5
    W, Low 100 W and High are categories; the x1 / x2 power factor of "20.
    Awards per club" scores the club award only).

  BONUSES -- "Starting in 2026, there is no bonus station(s)": no
    GetBonusStations. The mobile bonus is NOT BUILT (below).

  REGION LINES -- English: "If a mobile station is on a boundary between 2 or
    more administrative regions, a separate QSO and complete exchange must be
    made and logged for each"; French: "Une station mobile sur une limite
    entre deux zones de multiplicateurs" (two zones). NY4I: built as 2,
    GetCountyLineCountiesMax = 2. WHICH TEXT GOVERNS IS STILL AN OPEN QUESTION
    ON #128 -- if the English does, this becomes CountyLineCountiesUnlimited.
    "Mobile stations are encouraged to sign '/ <region code>'" ("VE2xxx/MTL"):
    the rover strip and its ADIF split are the base's.

  CABRILLO -- CONTEST: QC-QSO-PARTY (WA7BNM 53, ADIF 3.1.7; the sponsor
    states none). The rules give no example line; the fields are RST and the
    sent region, province, state or DX, then RST and the received one (the
    French text's sample: "You are Five-Nine from region Oscar Tango Sierra"
    / "please take my Four Nine from New-York, November Yankee"). LOCATION is
    not asked for. Logs go by the sponsor's upload page: no submission
    address.

  ADIF -- CONTEST_ID QC-QSO-PARTY. STATE is the party base's (QC for a region
    code, the station's own province or state otherwise), EXCEPT that NF and
    LB -- two multipliers here -- are both Newfoundland and Labrador, whose
    ADIF code is NL (NY4I): ADIFCountyState answers NL for them. CNTY is NOT
    written (NY4I): ADIF's CNTY enumeration defines nothing for Canada, as for
    British Columbia (Q89) and Ontario.

  THE NEW CONTEST PROMPT -- its own (NY4I): the shared one says "if you are
    in QC state", and a Quebec entrant's MY STATE is its region code
    (SNewContestQuebecQPRegionOrLocation).

  NOT BUILT -- issue #133, recorded here so the claimed score is understood:
    * "Mobile stations are allowed to contact stations already contacted when
      calling from a new administrative region" -- the dupe sheet does not
      key on the ENTRANT's own region, so such a re-work is a dupe;
    * "Mobile stations are given the total of the multiplication points made
      in each administrative region activated" -- the multiplier sheet is one
      per log;
    * "Mobile stations add 300 bonus points for each Quebec administrative
      region activated ... at least three contacts with three different
      stations from the multiplier area".
    Until #133 a mobile scores as a fixed station: points x multipliers, one
    sheet, no bonus. *)
unit uContestQuebecQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   (* ITS ID -- stored data; see the header. *)
   QC_QSO_PARTY_CONTEST_ID = 'QC-QSO-PARTY';

type
   TContestQuebecQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE PROVINCE WHOSE REGIONS THIS CONTEST'S EXCHANGE NAMES. *)
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

      (* A region line is two regions -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;

      (* Phone 1, CW 2 -- see the header. Protected, as on TContestBase:
         ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* 80-10 m without WARC, 6 m and 2 m; no 160 m -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* CW and phone (FM is phone); no digital -- the header. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* ' 5NN ' and the region, state or province this station sends; DX
         when it sends none. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;

      (* THE MULTIPLIERS -- regions, or regions, states, DC, provinces and
         one DX, from the domestic file (the party base's UsesDomesticFile);
         no DX, zone or prefix multiplier of the engine's kinds. *)
      function HasDXMultiplier: boolean; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;

      (* WHAT THE EXCHANGE CARRIES -- a domestic QTH (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;

      (* ADIF STATE NL FOR NF AND LB; NO ADIF CNTY -- the header. *)
      function ADIFCountyState(const aQso: ContestExchange): string; override;
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
   (* ADIFPartyQTHKey -- the QTH key the NF and LB test reads. *)
   uADIF,
   (* SNewContestQuebecQPRegionOrLocation. *)
   uAppStrings,
   uContestRegistry;

function TContestQuebecQP.GetDisplayName: string;
begin
   Result := 'Quebec QSO Party';
end;

function TContestQuebecQP.GetHostState: string;
begin
   (* The Canadian postal code -- ADIF's STATE for Quebec. Not VE2: that is
      the area's name in the rules, not a subdivision code. *)
   Result := 'QC';
end;

function TContestQuebecQP.GetCabrilloName: string;
begin
   (* The sponsor states no CONTEST: value; WA7BNM 53 and the ADIF
      Contest_ID both say QC-QSO-PARTY. *)
   Result := 'QC-QSO-PARTY';
end;

function TContestQuebecQP.GetADIFContestId: string;
begin
   (* ADIF 3.1.7's Contest_ID enumeration; export writes it, import matches
      it. *)
   Result := QC_QSO_PARTY_CONTEST_ID;
end;

function TContestQuebecQP.GetWA7BNMId: integer;
begin
   Result := 53;
end;

function TContestQuebecQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestQuebecQP.GetSubmissionEmail: string;
begin
   (* "Log entries shall be submitted in Cabrillo format at
      https://quebecqsoparty.org/soumission-qso-qso-download/" -- no e-mail
      route. *)
   Result := '';
end;

function TContestQuebecQP.GetDomesticFileName: string;
begin
   (* The region file. FCONTEST.FoundMyStateInDomFile reads it to decide
      whether MY STATE is a Quebec region code, and then loads quebec.dom
      or this file. *)
   Result := 'quebec_cty';
end;

function TContestQuebecQP.GetFriendlyName: string;
begin
   Result := 'Quebec QSO Party';
end;

function TContestQuebecQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestQuebecQP.GetExchangeKind: ExchangeType;
begin
   (* Every QTH from the session's table, "DX" included -- the header. *)
   Result := RSTDomesticQTHExchange;
end;

function TContestQuebecQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   (* RST and a QTH; no serial. Also the ADIF export's received tags. *)
   Result := ExchangeFieldsRSTQTH;
end;

function TContestQuebecQP.ParseReceivedExchangeFormat(const aText: string;
                                                      aParsers: TExchangeParsers;
                                                      var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTH(aText, aExch);
end;

function TContestQuebecQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestQuebecQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestQuebecQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                  const aQso: ContestExchange;
                                                  const aCtx: TCabrilloQSOContext): string;
begin
   (* A DX entrant sends "DX" -- the header. *)
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestQuebecQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                      const aQso: ContestExchange;
                                                      const aCtx: TCabrilloQSOContext): string;
begin
   (* "Other DXCC entities must be logged as DX": a DX station's column is
      DX, whether it was typed or not. *)
   Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
end;

function TContestQuebecQP.GetInStateDomesticFileName: string;
begin
   Result := 'quebec';
end;

function TContestQuebecQP.GetFlags: TContestFlags;
begin
   (* Dupes per band and per mode (CW, phone); multipliers ONCE PER BAND,
      not per mode; 6 m and 2 m are credited. *)
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand, cfVHFBandsEnabled];
end;

function TContestQuebecQP.GetCountyLineCountiesMax: integer;
begin
   (* The French "deux zones"; the English "2 or more" -- NY4I: 2, the
      question open on #128. See the header. *)
   Result := 2;
end;

(* PHONE 1, CW 2. FM is phone. A digital QSO never reaches here (UsesMode),
   nor an off-band one (UsesBand), nor a station an out-of-province entrant
   may not credit (CreditsWorkedStation). Both and NoMode are not modes a
   contact is made in. *)
procedure TContestQuebecQP.CalculateQSOPoints(var aQso: ContestExchange);
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
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestQuebecQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band80, Band40, Band20, Band15, Band10, Band6, Band2];
end;

(* "Phone (SSB or FM) and Morse code (CW)." Any submode of CW, Phone or FM
   is credited -- eNoMode and eData included, as the contract asks -- and no
   submode of Digital is. An identity fact: no station is asked. *)
function TContestQuebecQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM];
end;

function TContestQuebecQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is the state the session SENDS (design 7.11/7.12): a
      Quebec station's region code, anyone else's state or province; a DX
      entrant sends DX. *)
   if Trim(aStation.MyState) = '' then
      begin
      Result := ' 5NN DX';
      end
   else
      begin
      Result := ' 5NN ' + aStation.MyState;
      end;
end;

function TContestQuebecQP.HasDXMultiplier: boolean;
begin
   (* The one DX multiplier is quebec.dom's Dx entry -- a domestic one. *)
   Result := False;
end;

function TContestQuebecQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestQuebecQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

(* NEWFOUNDLAND AND LABRADOR ARE TWO MULTIPLIERS HERE AND ONE ADIF STATE --
   NY4I: "NF and LB export ADIF STATE NL". ADIF's Canadian list has NL and
   neither NF nor LB, so the base would write no STATE for them. Every other
   key is the party base's answer (QC for a region). *)
function TContestQuebecQP.ADIFCountyState(const aQso: ContestExchange): string;
var
   key: string;
begin
   key := UpperCase(ADIFPartyQTHKey(aQso));
   if (key = 'NF') or
      (key = 'LB') then
      begin
      Result := 'NL';
      end
   else
      begin
      Result := inherited ADIFCountyState(aQso);
      end;
end;

(* ADIF's CNTY enumeration (3.1.6 III.B.22) defines nothing for Canada
   (DXCC 1): a Quebec region code written as CNTY would be a value the
   specification does not allow (NY4I: not written; BC's Q89). *)
function TContestQuebecQP.WritesADIFCounty: boolean;
begin
   Result := False;
end;

(* THE NEW CONTEST DIALOG ASKS FOR MY STATE in Quebec's words -- the
   header. *)
procedure TContestQuebecQP.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(SNewContestQuebecQPRegionOrLocation, ncfMyState);
end;

initialization
   RegisterContestById(QC_QSO_PARTY_CONTEST_ID, TContestQuebecQP);

end.
