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

(* NORTH DAKOTA QSO PARTY -- a NEW contest, registered BY ID (2026-10-26).

  ITS ID IS ND-QSO-PARTY AND IT IS STORED DATA FROM THE FIRST LOG MADE WITH
  IT: never give it to another contest. There is no ContestType member -- the
  enum is frozen (Lint-FrozenContestNumbers) -- so, like Georgia, the contest
  is refused on the multi-op network and its UDP contest number is derived
  from its id.

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE: one host state, county
  multipliers for everyone outside it, and an out-of-state station may work
  only North Dakota stations -- the base's out-of-state refusal (design 7.10).
  Modelled on uContestGeorgiaQP (ADDING_A_CONTEST's template); a copy it owns.

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor   docs/ContestRules/QSOParties/NorthDakota/
                  2026_nd_qsp_party_rules.pdf -- "2026 ND QSO Party Rules",
                  ARRL ND Section Manager N0RDF and ASM K0YL, revised
                  January 2026
    ADIF 3.1.7    Contest_ID ND-QSO-PARTY

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- 1800Z April 11 to 1800Z April 12, 2026 (the sponsor's UTC).

  BANDS -- "160 through 10 meters, 6 & 2 meters, (Excluding the WARC Bands)".
    UsesBand.

  MODES -- "Phone= (SSB/FM both counts as Phone); CW= (CW counts as CW) and
    Digital = (RTTY/PSK), NO FT8". NY4I, 2026-10-26: only RTTY and PSK count
    as digital, so every other digital submode (FT8, FT4, JT65, JS8, MFSK...)
    is an X-QSO. UsesMode.

  EXCHANGE -- "ND stations give RST and County. U.S. and Canadian stations
    give RST and State, Province or Territories DX Stations give RST and DX
    country." RSTDomesticOrDXQTHExchange; the three-letter county codes are
    northdakota_cty.dom. A DX entrant sends its own country prefix (NY4I,
    2026-10-26) -- the party base's SentLocation / LocationOrOwnCountry
    (lifted there when Oklahoma became the second user), used by the CQ
    exchange, Cabrillo and ADIF.

  QSO POINTS -- "All contacts count as 1 point per non-duplicated phone, CW or
    Digital contact on each band." FM is phone.

  DUPES -- "Stations may be worked once per band and mode, and once per
    band/mode/county for ND stations": QSOByBand and QSOByMode, and "Mobile ND
    stations that change counties are considered to be a new station in each
    new county" is the state-party base's received-QTH dupe key.

  MULTIPLIERS -- "Multipliers count once overall, not once per band or mode"
    (no MultByBand, no MultByMode).
      out of state  northdakota_cty.dom: the 53 counties, each its own
                    multiplier.
      in state      northdakota.dom: the 53 counties, then S50P13DC (the
                    states, DC and the 13 Canadian provinces and territories).
                    "49 states excluding North Dakota + DC": ND itself is
                    refused in CountsAsMultiplier, not by editing the shared S50.
                    "North Dakota stations may work DXCC countries for points
                    only - no multipliers": HasDXMultiplier is False.

  POWER -- "There are no power limitations in this contest, within legal
    limit." No power multiplier: the score is the base's points x multipliers.

  COUNTY LINES -- "Mobile stations may park on a county line but each county
    must be worked in a separate contact". NY4I, 2026-10-26: a county-line
    entry (CSS/BUR) already logs one QSO per county, which is that separate
    contact, so GetCountyLineCountiesMax = 2.

  CABRILLO -- CONTEST: ND-QSO-PARTY (the rules state none; it is the ADIF
    Contest_ID). Logs go to "fettigrd@gmail.com" ("submit their log Cabrillo
    file via email ... Email your results to fettigrd@gmail.com"); the other
    address in the rules is for the paper summary. *)
unit uContestNorthDakotaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   (* ITS ID -- stored data; see the header. *)
   ND_QSO_PARTY_CONTEST_ID = 'ND-QSO-PARTY';

type
   TContestNorthDakotaQP = class(TContestStateQSOPartyBase)
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

      (* County lines of up to two counties (NY4I) -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;

      (* 1 point in every mode -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* 160-10 m without WARC, 6 m and 2 m -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* CW, phone (FM is phone) and digital but FT8/FT4 -- the header. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* ' 5NN ' and the county, state or province this station sends; DX
         when it sends none. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;

      (* THE MULTIPLIERS -- counties, or states and provinces, from the
         domestic file; no DX, zone or prefix multiplier for any entrant. *)
      function HasDXMultiplier: boolean; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;

      (* NORTH DAKOTA IS NOT A STATE MULTIPLIER FOR A NORTH DAKOTA ENTRANT --
         the header. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;

      (* WHAT THE EXCHANGE CARRIES -- a domestic QTH (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry;

function TContestNorthDakotaQP.GetDisplayName: string;
begin
   Result := 'North Dakota QSO Party';
end;

function TContestNorthDakotaQP.GetHostState: string;
begin
   Result := 'ND';
end;

function TContestNorthDakotaQP.GetCabrilloName: string;
begin
   (* The rules state no CONTEST: name; this is the ADIF Contest_ID. *)
   Result := 'ND-QSO-PARTY';
end;

function TContestNorthDakotaQP.GetADIFContestId: string;
begin
   (* ADIF 3.1.7's Contest_ID enumeration; export writes it, import matches
      it. *)
   Result := ND_QSO_PARTY_CONTEST_ID;
end;

function TContestNorthDakotaQP.GetWA7BNMId: integer;
begin
   (* NY4I's value, not re-checked against WA7BNM. *)
   Result := 468;
end;

function TContestNorthDakotaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNorthDakotaQP.GetSubmissionEmail: string;
begin
   (* "submit their log Cabrillo file via email ... Email your results to
      fettigrd@gmail.com". nancyyoshida50@gmail.com is for the paper
      summary. *)
   Result := 'fettigrd@gmail.com';
end;

function TContestNorthDakotaQP.GetDomesticFileName: string;
begin
   (* The county file. FCONTEST.FoundMyStateInDomFile reads it to decide
      whether MY STATE is a North Dakota county, and then loads
      northdakota.dom or this file. Lower case: the file's own name, which
      matters off Windows. *)
   Result := 'northdakota_cty';
end;

function TContestNorthDakotaQP.GetFriendlyName: string;
begin
   Result := 'North Dakota QSO Party';
end;

function TContestNorthDakotaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestNorthDakotaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestNorthDakotaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestNorthDakotaQP.ParseReceivedExchangeFormat(const aText: string;
                                                           aParsers: TExchangeParsers;
                                                           var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestNorthDakotaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

(* "DX Stations give RST and DX country" (NY4I, 2026-10-26: their country
   prefix). A DX entrant has no MY STATE, so the exchange it sends is its own
   country; anyone else sends the state, province or county it stated --
   the party base's SentLocation, which the Oklahoma QSO Party shares. The
   existing helpers are handed that value, so the column format stays theirs. *)
function TContestNorthDakotaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(SentLocation(aMy), aQso);
end;

function TContestNorthDakotaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTState(SentLocation(aMy), aQso, aCtx);
end;

function TContestNorthDakotaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                           const aQso: ContestExchange;
                                                           const aCtx: TCabrilloQSOContext): string;
begin
   (* "DX Stations give RST and DX country": the received column is the
      country a DX station sent. *)
   Result := CabrilloReceivedRSTQTHOrDXQTH(aMy, aQso, aCtx);
end;

function TContestNorthDakotaQP.GetInStateDomesticFileName: string;
begin
   Result := 'northdakota';
end;

function TContestNorthDakotaQP.GetFlags: TContestFlags;
begin
   (* Dupes per band and per mode; multipliers ONCE OVERALL (neither
      cfMultByBand nor cfMultByMode); 6 m and 2 m are credited. *)
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

function TContestNorthDakotaQP.GetCountyLineCountiesMax: integer;
begin
   (* Two (NY4I, 2026-10-26): "Mobile stations may park on a county line but
      each county must be worked in a separate contact" -- and a county-line
      entry (CSS/BUR) already logs ONE QSO PER COUNTY, which is the separate
      contact the rule asks for. *)
   Result := 2;
end;

(* 1 POINT IN EVERY MODE. FM is phone. An FT8 or FT4 QSO never reaches here
   (UsesMode), nor an off-band one (UsesBand); Both and NoMode are not modes a
   contact is made in. *)
procedure TContestNorthDakotaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW, Phone, FM, Digital:
         begin
         aQso.QSOPoints := 1;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestNorthDakotaQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10,
                       Band6, Band2];
end;

(* "Digital = (RTTY/PSK), NO FT8" -- NY4I, 2026-10-26: only RTTY and PSK
   count, so FT8, FT4, JT65, JS8, MFSK and the rest are X-QSOs. eNoMode and
   eData mean "some submode of Digital" (the contract) and are credited;
   reversed RTTY and PSK are still RTTY and PSK. CW, phone and FM are
   credited. An identity fact: no station is asked. *)
function TContestNorthDakotaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   case aMode of
      CW, Phone, FM:
         begin
         Result := True;
         end;
      Digital:
         begin
         Result := aExtMode in [eNoMode, eData, eRTTY, eRTTY_R,
                                ePSK31, ePSK63, ePSK_R];
         end;
      else
         begin
         Result := False;
         end;
      end;
end;

function TContestNorthDakotaQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is the state the session SENDS (design 7.11/7.12): a
      North Dakota station's county, anyone else's state or province. A DX
      entrant has none and sends its country -- the party base's
      LocationOrOwnCountry, the rule SentLocation states for the exports. *)
   Result := ' 5NN ' + LocationOrOwnCountry(aStation.MyState, aStation.MyCountry);
end;

function TContestNorthDakotaQP.HasDXMultiplier: boolean;
begin
   (* "North Dakota stations may work DXCC countries for points only - no
      multipliers"; an out-of-state entrant works only North Dakota. *)
   Result := False;
end;

function TContestNorthDakotaQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestNorthDakotaQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

(* "49 states excluding North Dakota + DC": northdakota.dom includes the
   shared S50P13DC.DOM, which holds Nd, so an in-state entrant's QSO whose
   domestic multiplier is the host state earns no multiplier. The shared file
   is left alone. *)
function TContestNorthDakotaQP.CountsAsMultiplier(const aQso: ContestExchange;
                                                  aKind: RemainingMultiplierType): boolean;
begin
   Result := not (Station.InHostState and
                  DomesticMultiplierIsHostState(string(aQso.DomMultQTH), HostState));
end;

initialization
   RegisterContestById(ND_QSO_PARTY_CONTEST_ID, TContestNorthDakotaQP);

end.
