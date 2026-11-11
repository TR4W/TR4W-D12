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

(* THE NEW HAMPSHIRE QSO PARTY -- a NEW contest, registered BY ID (2026-11-10,
  GitHub issue #112).

  ITS ID IS NH-QSO-PARTY AND IT IS STORED DATA FROM THE FIRST LOG MADE WITH
  IT: never give it to another contest. There is no ContestType member -- the
  enum is frozen (Lint-FrozenContestNumbers) -- so the contest is refused on
  the multi-op network and its UDP contest number is derived from its id
  (both the registry's, nothing here).

  NOT THE NEW ENGLAND QSO PARTY. That is a different event with its own
  sponsor, dates and rules (uContestNewEnglandQP); nothing here is shared
  with it, and its New Hampshire counties are spelled differently.

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE: one host state, county
  multipliers for everyone outside it, and "Stations outside of NH contact as
  many NH stations as possible" -- the base's host-area rule (design 7.10,
  Q107). Copied from the Georgia template (uContestGeorgiaQP), whose exchange
  is the same shape (a DX station sends "DX"); a copy it owns. Every rule
  below is New Hampshire's. D7 never had this contest.

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor   docs/ContestRules/QSOParties/NewHampshire/NHQP_Rules.pdf --
                  "New Hampshire QSO Party Rules", the 2026 running
                  (September 19-20, 2026); no revision date printed. Saved by
                  NY4I from the sponsor's page,
                  https://w1wqm.org/nh-qso-party/ . NH-QSO-PARTY-Rules.txt
                  beside it is the transcription with the source header.
    ADIF 3.1.6    the Contest_ID enumeration lists NH-QSO-PARTY, "New
                  Hampshire QSO Party".
    DXLog.net     NHQP.txt (updated 2026-09-05): the same 10 county codes and
                  CABRILLO_CONTEST_NAME=NH-QSO-PARTY. A cross-check only;
                  where it and the rules disagree, the rules win (below).

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- "September 19 - 20, 2026 (3rd Weekend in September) / Time: 1600
    UTC Saturday to 0400 UTC Sunday; 1200 UTC to 2200 UTC Sunday (Total
    operating time 22 hours)". The calendar's two rows are these two
    sessions of ONE event, so this is one contest.
    NOT BUILT -- THE CONTEST PERIOD: TR4W has no contest schedule (design
      Q99) and QSOIsOffContest has no time question, so a QSO logged in the
      0400-1200 UTC gap on Sunday, or outside the weekend, scores like any
      other. Not faked as 0 points in CalculateQSOPoints (it would not be an
      X-QSO, and the totals would disagree with the Cabrillo). A gap for
      NY4I.

  BANDS -- "80m through 10m, except WARC bands (12m, 17m, 30m)": 80, 40, 20,
    15 and 10 m. Not 160 m, not 6 m or up. UsesBand; no cfVHFBandsEnabled.
    DXLog lists 50 and 144 MHz too; the rules win.

  MODES -- "CW/Phone". UsesMode credits CW, phone (SSB, AM) and FM (a phone
    mode: DXLog's PHON group is SSB+FM, and the dupe sheet files FM under
    Phone) and refuses Digital, whatever its submode -- a digital QSO is
    logged and is an automatic X-QSO (Q98). DXLog lists RTTY; the rules win.

  EXCHANGE -- "NH: RS(T) + County / non-NH W/VE: RS(T) + (State/Province) /
    DX: RS(T) + "DX"". RSTDomesticOrDXQTHExchange; the county codes are
    newhampshire_cty.dom. Georgia's helper row (ADDING_A_CONTEST A3):
      * A DX ENTRANT SENDS "DX": the CQ exchange is ' 5NN DX', the ADIF
        STX_STRING (what was transmitted) is RST and DX, and so is the
        Cabrillo sent column. A DX entrant's MY STATE is empty, OR 'DX' when
        the New Contest dialog set it up (uNewContestHostArea) -- both send
        "DX" through the same helper (uCabrilloExchange.SentStateOrDX); the
        test pins both spellings.
      * A DX STATION'S RECEIVED COLUMN is "DX", what it sent -- also when its
        entity was typed (CabrilloReceivedRSTDomesticQTHOrDX).

  QSO POINTS -- "1 Point per phone QSO; 2 points per CW QSO". Phone and FM
    1, CW 2. CalculateQSOPoints.

  DUPES -- "Work Stations: Once per band per mode": cfQSOByBand, cfQSOByMode.
    A mobile or portable station "may operate from one or more counties":
    the party base's received-QTH dupe key makes it a new station in a new
    county (and its rover strip and export split) -- inherited, as DXLog's
    DOUBLE_QSO=PER_BAND_MODE_RCVD also says.

  OUT-OF-STATE ENTRANTS -- "Stations outside of NH contact as many NH
    stations as possible": the party base's host-area rule, refused when
    typed and an automatic X-QSO when logged any other way. A DX entrant is
    an out-of-state entrant.

  MULTIPLIERS -- the two kinds of entrant count them differently:
      NH stations       "Each NH county, each state, each Canadian province
                        and up to 10 DXCC country once." ONCE: not per band,
                        not per mode. newhampshire.dom: the 10 counties, each
                        its own multiplier (newhampshire_cty.dom maps none to
                        the state), S50.DOM, P13.DOM (NF and LB read as NL,
                        as DXLog and N1MM do). Alaska and Hawaii are states.
                        DXCC countries are the DX multiplier, IN STATE ONLY,
                        every country but K, VE, KH6 and KL (uDXMultiplierKey;
                        DXLog's MULT3 excludes the same four), on the ARRL
                        list -- one private predicate, CountsDXMultiplier.
                        "up to 10": the score counts at most 10
                        (CombineWithMultipliers); the sheet and the display
                        still show every country worked, as DXLog's own note
                        says of its display.
      Non-NH stations   "Each NH county once per band. Maximum multiplier
                        count: 50 (10 counties per band, 5 bands)".
                        newhampshire_cty.dom, each county its own multiplier
                        (FCONTEST sets MultipliersIsCounties), counted per
                        band and NOT per mode. The 50 is 10 counties x the 5
                        bands UsesBand credits -- nothing more to state. No
                        DX multiplier.
    SO MULT-BY-BAND DEPENDS ON THE ENTRANT: GetFlags states cfMultByBand (an
    out-of-state entrant's, and the identity's) and DescribeSession states
    MultByBand both ways on aStation.InHostState -- False in New Hampshire,
    True outside (Arizona's pattern, design D8). Never cfMultByMode.
    RULING -- NH IS NO STATE MULTIPLIER FOR AN NH ENTRANT: "NH: RS(T) +
      County" -- a New Hampshire station sends its county, never "NH"; DXLog's
      list of states omits NH. S50.DOM lists it, so CountsAsMultiplier
      refuses it in state (DomesticMultiplierIsHostState, the Michigan,
      Texas ... predicate); the QSO keeps its points. The shared file is not
      edited. Unlike Vermont, nothing says a county also earns the state, so
      there is no gap there.
    QUESTION (issue #112) -- DC: the rules count "each state" and are silent
      on the District of Columbia. Built as Maryland (Dc > Md before S50.DOM in
      newhampshire.dom): DXLog's multiplier list names "MD=Maryland DC", and
      the sponsor scores with N1MM+, which takes no DC. One line in the .dom
      to change.

  COUNTY LINES -- QUESTION (issue #112): the rules are silent. Built as 2
    (GetCountyLineCountiesMax): DXLog takes a received county with ONE '/'
    (two counties) and scores "one QSO per county, own and worked"
    (SLASH_MULTIPLE_QSOS=YES). One line to change.

  SCORE -- "Total score = total QSO points x total multipliers", the DXCC
    count capped at 10 (CombineWithMultipliers, SummedMultipliersWithKindCapped
    -- the 7QP's and the Salmon Run's cap). No power multiplier, no bonus.

  NOT BUILT -- MOBILE AND PORTABLE CATEGORIES, issue #133: the entrant's
    station category does not reach scoring. Nothing in these rules scores a
    mobile or portable entrant differently, so only the category itself is
    unrepresented (the Cabrillo CATEGORY-STATION the operator chooses).

  CABRILLO -- CONTEST: NH-QSO-PARTY (DXLog; the rules state none). The rules
    give no example line and name no fields beyond the exchange; DXLog's
    CABRILLO_LINE is the standard one (freq, mode, date, time, my call, sent,
    call, received). The LOCATION tag is not required by the rules.
    ADIF -- CONTEST_ID NH-QSO-PARTY (the ADIF 3.1.6 enumeration).

  SUBMISSION -- "Submit logs at https://w1wqm.org/submit-log.php" -- a web
    form; no e-mail address, so ''.

  WA7BNM -- 0: the calendar's reference was not found, and its terms bar
    automated access (a bench item for NY4I).

  3830 -- the base's one "Mults" column; the form was not checked (a bench
    item). *)
unit uContestNewHampshireQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   (* ITS ID -- stored data; see the header. *)
   NH_QSO_PARTY_CONTEST_ID = 'NH-QSO-PARTY';

   (* "up to 10 DXCC country" -- the most the score counts. *)
   NH_QSO_PARTY_MAXIMUM_DX_MULTIPLIERS = 10;

type
   TContestNewHampshireQP = class(TContestStateQSOPartyBase)
   private
      (* THE ONE PREDICATE for the DX multiplier -- a New Hampshire entrant
         counts DXCC countries; nobody else does. HasDXMultiplier, the key and
         the country list ask it, so the answers cannot disagree (M11 S4). *)
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

      (* A county line of two counties -- a question; see the header. *)
      function GetCountyLineCountiesMax: integer; override;

      (* Phone 1, CW 2 -- see the header. Protected, as on TContestBase:
         ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* POINTS x MULTIPLIERS, at most 10 of them DXCC -- the header. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      (* 80, 40, 20, 15 and 10 m -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* CW and phone (FM is phone); no digital -- the header. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* SET-UP -- see TContestBase.DescribeSession. Only MultByBand, stated
         both ways: once in New Hampshire, per band outside it. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;

      (* ' 5NN ' and the county, state or province this station sends; DX
         when it states none. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;

      (* An NH entrant's QSO whose domestic multiplier is NH itself earns no
         multiplier -- the header's ruling. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;

      (* THE MULTIPLIERS -- counties, or counties, states and provinces, from
         the domestic file; DXCC countries for a New Hampshire entrant; no
         zone or prefix multiplier. *)
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
   (* Trim -- CQExchangeDefault. *)
   SysUtils,
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   (* DXCCKeyExceptUSACanadaHawaiiAlaska, DXCCCountryMode -- issue #136. *)
   uDXMultiplierKey,
   uContestRegistry;

function TContestNewHampshireQP.GetDisplayName: string;
begin
   Result := 'New Hampshire QSO Party';
end;

function TContestNewHampshireQP.GetHostState: string;
begin
   Result := 'NH';
end;

function TContestNewHampshireQP.GetCabrilloName: string;
begin
   (* The rules state none; DXLog's CABRILLO_CONTEST_NAME=NH-QSO-PARTY. *)
   Result := 'NH-QSO-PARTY';
end;

function TContestNewHampshireQP.GetADIFContestId: string;
begin
   (* The ADIF 3.1.6 Contest_ID enumeration's NH-QSO-PARTY. Export writes
      it, import matches it. *)
   Result := NH_QSO_PARTY_CONTEST_ID;
end;

function TContestNewHampshireQP.GetWA7BNMId: integer;
begin
   (* Not found; the calendar bars automated access -- a bench item. *)
   Result := 0;
end;

function TContestNewHampshireQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNewHampshireQP.GetSubmissionEmail: string;
begin
   (* "Submit logs at https://w1wqm.org/submit-log.php" -- a web form. *)
   Result := '';
end;

function TContestNewHampshireQP.GetDomesticFileName: string;
begin
   (* The county file. FCONTEST.FoundMyStateInDomFile reads it to decide
      whether MY STATE is a New Hampshire county, and then loads
      newhampshire.dom or this file. Lower case: the file's own name, which
      matters off Windows. *)
   Result := 'newhampshire_cty';
end;

function TContestNewHampshireQP.GetFriendlyName: string;
begin
   Result := 'New Hampshire QSO Party';
end;

function TContestNewHampshireQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestNewHampshireQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestNewHampshireQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestNewHampshireQP.ParseReceivedExchangeFormat(const aText: string;
                                                            aParsers: TExchangeParsers;
                                                            var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestNewHampshireQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

(* WHAT WAS TRANSMITTED: "DX: RS(T) + "DX"" -- the same SentStateOrDX the
   Cabrillo column asks, so the two cannot spell it differently. *)
function TContestNewHampshireQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestNewHampshireQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   (* A DX entrant sends "DX" -- the header. *)
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestNewHampshireQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                            const aQso: ContestExchange;
                                                            const aCtx: TCabrilloQSOContext): string;
begin
   (* A DX station's column is "DX", what it sent -- also when its entity was
      TYPED: the DX branch keeps that text in QTHString and the table
      resolves nothing, so the record has no DomesticQTH.
      CabrilloReceivedRSTQTHDX tests QTHString and would leave the column
      empty. *)
   Result := CabrilloReceivedRSTDomesticQTHOrDX(aMy, aQso, aCtx);
end;

function TContestNewHampshireQP.GetInStateDomesticFileName: string;
begin
   Result := 'newhampshire';
end;

function TContestNewHampshireQP.GetFlags: TContestFlags;
begin
   (* "Once per band per mode"; an out-of-state entrant's counties "once per
      band" (cfMultByBand -- DescribeSession states it False in New
      Hampshire); never per mode. No band above 10 m. *)
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand];
end;

function TContestNewHampshireQP.GetCountyLineCountiesMax: integer;
begin
   (* QUESTION (issue #112): the rules are silent; DXLog takes two counties
      and scores one QSO per county. *)
   Result := 2;
end;

(* PHONE 1, CW 2. FM is phone. A digital QSO never reaches here (UsesMode),
   nor an off-band one (UsesBand), nor a station an out-of-state entrant may
   not credit (CreditsWorkedStation). Both and NoMode are not modes a contact
   is made in. *)
procedure TContestNewHampshireQP.CalculateQSOPoints(var aQso: ContestExchange);
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

(* THE DXCC CAP. Outside New Hampshire there is no DX multiplier, so the DX
   count is 0 and the cap never bites. *)
function TContestNewHampshireQP.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := ContestPoints(aTotals) *
             SummedMultipliersWithKindCapped(aTotals, rmDX, NH_QSO_PARTY_MAXIMUM_DX_MULTIPLIERS);
end;

function TContestNewHampshireQP.UsesBand(aBand: BandType): boolean;
begin
   (* "80m through 10m, except WARC bands (12m, 17m, 30m)". *)
   Result := aBand in [Band80, Band40, Band20, Band15, Band10];
end;

(* "Modes: CW/Phone". An identity fact: no station is asked. *)
function TContestNewHampshireQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM];
end;

(* "NH Stations: Each NH county, each state, each Canadian province and up
   to 10 DXCC country once. Non-NH Stations: Each NH county once per band."
   Stated both ways (design D8). *)
procedure TContestNewHampshireQP.DescribeSession(const aStation: TStationContext;
                                                 aSession: TSessionDefaults);
begin
   if aStation.InHostState then
      begin
      aSession.MultByBand := False;
      end
   else
      begin
      aSession.MultByBand := True;
      end;
end;

function TContestNewHampshireQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is the state the session SENDS (design 7.11/7.12): a
      New Hampshire station's county, anyone else's state or province. A DX
      entrant has none (or the dialog's DX) and sends DX. *)
   if Trim(aStation.MyState) = '' then
      begin
      Result := ' 5NN DX';
      end
   else
      begin
      Result := ' 5NN ' + aStation.MyState;
      end;
end;

function TContestNewHampshireQP.CountsAsMultiplier(const aQso: ContestExchange;
                                                   aKind: RemainingMultiplierType): boolean;
begin
   Result := not ((aKind = rmDomestic) and
                  Station.InHostState and
                  DomesticMultiplierIsHostState(string(aQso.DomMultQTH), HostState));
end;

function TContestNewHampshireQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* "NH Stations: ... up to 10 DXCC country"; none outside, where an entrant
   works only New Hampshire stations. *)
function TContestNewHampshireQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* Every DXCC country but the USA, Canada, Hawaii and Alaska: the states and
   provinces are multipliers of their own. False is "leave the DX QTH as it
   was". *)
function TContestNewHampshireQP.DXMultiplierKey(const aQso: ContestExchange;
                                                out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

(* The ARRL DXCC list where the entrant counts the DX multiplier; the CQ list
   for anyone else, who counts none. *)
function TContestNewHampshireQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;

function TContestNewHampshireQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestNewHampshireQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

initialization
   RegisterContestById(NH_QSO_PARTY_CONTEST_ID, TContestNewHampshireQP);

end.
