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

(* NEBRASKA QSO PARTY -- a NEW ContestType, NEBRASKAQSO (2026-10-16).

  NY4I, design Q105: "It will have a NE qso party as I do want to implement
  all qso parties eventually." TR4W had none. Its names are NE-QSO-PARTY
  everywhere -- ContestTypeSA, Cabrillo and ADIF 3.1.7 alike -- and it is
  NOT 'NEQP': that spelling is the NEW ENGLAND QSO Party's, stored in every
  older New England log, and stays a read alias for it for good
  (uContestNames). DXLog's NEQP.txt IS Nebraska despite its name; its New
  England file is NEWEQP.txt.

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE: one host state, county
  multipliers for everyone outside it, and an out-of-state station may work
  only Nebraska stations -- the base's out-of-state refusal (design 7.10).
  Modelled on uContestDelawareQP, the nearest party (a power multiplier, a
  per-contest bonus); a copy it owns, not a shared base (design 1.4).

  ---------------------------------------------------------------------------
  SOURCES -- the sponsor wins where DXLog differs

    the sponsor     https://nebraskaqsoparty.com -- "Rules for 2026 Nebraska
                    QSO Party", as summarised by NY4I's coordinator,
                    2026-10-16 (the page renders its rules client-side and
                    was not re-read here)
    WA7BNM          ref 336: 1300Z Apr 25 to 0100Z Apr 27, 2026
    DXLog.net       Contest\NEQP.txt (updated 2026-06-04): the 93 county
                    abbreviations, the bonus calls, NF/LB written as NL
    ADIF 3.1.7      Contest_ID NE-QSO-PARTY

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- Saturday 25 April 2026 to Sunday 26 April. The sponsor writes
    "1400 UTC (8:00 AM CDT)", but 8 AM CDT is 1300 UTC, which is what WA7BNM
    gives. Contest schedules are not built yet (design Q99); recorded only.

  MODES -- CW; phone (SSB, AM, FM); digital (RTTY, PSK and other digital
    modes) but NOT FT8 or FT4: "FT8/FT4 is a SEPARATE competition with a
    separate log". An FT8 or FT4 QSO is OFF-MODE here (open questions Q98):
    logged, scores 0 (CalculateQSOPoints), earns no multiplier
    (CountsAsMultiplier) and pays no bonus (BonusPoints). Which digital mode
    a QSO was is its ExtMode.

  BANDS -- "160, 80, 40, 20, 15, 10 m; WARC contacts do not count; all
    VHF/UHF bands are allowed". UsesBand: those six and every band from 6 m
    up, light included; VHFBandsEnabled. DXLog lists only 50 MHz above 10 m;
    the sponsor wins. 60 m has no BandType.

  EXCHANGE -- out-of-state stations send their state, Canadian province or
    "DX"; Nebraska stations send their county (four-letter abbreviation).
    Signal report optional. RSTDomesticOrDXQTHExchange, as Delaware: the
    shape takes a county, state or province through the session's domestic
    table and a DX QTH otherwise; for an out-of-state entrant that table is
    the 93 counties, so the base's refusal does the rest.

  QSO POINTS -- digital 1, phone 2, CW 3 (FM is phone). Satellite QSOs are
    4 points, but TR4W has no notion of a satellite QSO -- NOT BUILT (Q106).

  DUPES -- "the same station counts again on another band, or another mode
    on the same band": QSOByBand and QSOByMode. "A mobile in a new county is
    a new station" is a dupe-KEY rule and there is no dupe-key seam (M8,
    design 8.2l) -- the same gap as Delaware's (design Q73).

  MULTIPLIERS -- counted ONCE PER CONTEST, not per band or mode (no
    MultByBand, no MultByMode).
      out of state  nebraska_cty.dom: the 93 counties, each its own
                    multiplier (FCONTEST sets MultipliersIsCounties). No DX
                    multiplier: such an entrant works only Nebraska.
      in state      nebraska.dom: the counties (each its OWN multiplier --
                    the county file maps none of them to Ne), the 50 states
                    (S50) and the 13 provinces (P13, NF and LB read as NL),
                    and DXCC entities but the USA, Canada, Alaska and Hawaii
                    as the DX multiplier (Alaska and Hawaii are states in
                    S50). OPEN: whether a Nebraska entrant's NE counts as a
                    STATE as well as its counties -- a QSO carries one
                    domestic multiplier, and a Nebraska station sends its
                    county, so S50's Ne is never reached. DXLog instead maps
                    every county to Nebraska; the sponsor's "NE counties +
                    US states" is what is built.

  POWER -- ONE multiplier on the whole score: every QSO at 5 W or less x5,
    under 100 W x2, otherwise x1. CATEGORY-POWER is the one value (design
    7.6), Station.MyPower: QRP x5, LOW x2, HIGH x1 -- CombineWithMultipliers,
    as Delaware's. LOW is "100 W or less" in Cabrillo, the sponsor's x2 is
    "under 100 W": exactly 100 W cannot be told apart, and scores x2. DXLog
    applies power per QSO; the sponsor's one multiplier is what is built.

  SCORE -- QSO points x power multiplier x multipliers, + bonus points.

  BONUS -- 100 points for a QSO with KA0BOJ (the sponsor writes it with a slashed zero), 50
    for a QSO with each of K0SMM, K0RPT, K0NEB, NF0N, N0FER and KE0XQ, PER
    QSO: every QSO with one of them that counts -- not a dupe, on a credited
    band, not FT8/FT4 -- pays. That is DXLog's per-band-and-mode count, since
    the dupe rule allows one QSO per band and mode. NEBRASKA_BONUS_STATIONS
    below; THE LIST CHANGES EVERY YEAR.

  COUNTY LINES AND MOBILES -- mobiles sign call/county; a county line is
    limited to TWO counties: GetCountyLineCountiesMax = 2. The rover strip
    and its ADIF split are the base's, as for every QSO party.

  MULTI-TRANSMITTER -- one combined log; nothing for TR4W to do.

  NOT BUILT (open question Q106): the rare-grid bonus (DN91CE, DN91DE and
    DN91EE activators), satellite points, and the separate FT8/FT4
    grid-square competition.

  CABRILLO -- CONTEST: NE-QSO-PARTY, the sponsor's and DXLog's. The QSO line
    is RST and the sent state or county, RST and the received QTH or DX, as
    DXLog writes it ("RST is optional but N1MM includes it so we do too").
    The mode column is the base's. ADIF -- CONTEST_ID NE-QSO-PARTY; export
    and import are the base's. *)
unit uContestNebraskaQP;

{$I tr4w.inc}

interface

uses
   (* cpLOW / cpQRP -- the entrant's CATEGORY-POWER, as TStationContext
      carries it. First, so VC's names win wherever the two overlap. *)
   uSettingsModel,
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestNebraskaQP = class(TContestStateQSOPartyBase)
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

      (* A county line is two counties -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;

      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* POINTS x THE POWER MULTIPLIER x MULTIPLIERS -- the header. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      (* 160-10 m without WARC, and 6 m up -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* AN FT8 OR FT4 QSO EARNS NO MULTIPLIER -- off-mode, the header. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;

      (* ' 5NN ' and the state or county this station sends. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;

      (* THE BONUS STATIONS, per QSO -- the header. *)
      function BonusPoints(const aTotals: TScoreTotals;
                           aView: TLoggedQSOView): longint; override;
   private
      (* DOES THIS ENTRANT COUNT A DX MULTIPLIER? -- the one station test
         HasDXMultiplier, the key and the country list ask, so the answers
         cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;
   public
      function HasDXMultiplier: boolean; override;
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      function CountryMode: CountryModeType; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

const
   (* THE 2026 BONUS STATIONS -- THE SPONSOR CHANGES THIS LIST EVERY YEAR.
      TBonusStation's shape, but NOT declared through GetBonusStations: the
      base pays a declared station once (or once per mode), and Nebraska
      pays every counting QSO -- BonusPoints walks this list itself.
      The sponsor writes KA0BOJ with a slashed zero; the call is KA0BOJ. *)
   NEBRASKA_BONUS_STATIONS: array[0..6] of TBonusStation = (
      (Call: 'KA0BOJ'; Points: 100; OncePerMode: False),
      (Call: 'K0SMM';  Points: 50; OncePerMode: False),
      (Call: 'K0RPT';  Points: 50; OncePerMode: False),
      (Call: 'K0NEB';  Points: 50; OncePerMode: False),
      (Call: 'NF0N';   Points: 50; OncePerMode: False),
      (Call: 'N0FER';  Points: 50; OncePerMode: False),
      (Call: 'KE0XQ';  Points: 50; OncePerMode: False)
   );

(* THE POWER MULTIPLIER FOR A CATEGORY-POWER -- HIGH x1, LOW x2, QRP x5.
   Public so the tests assert the mapping itself, not only a product. *)
function NebraskaPowerMultiplier(aPower: tCategoryPower): longint;

(* IS THIS QSO PART OF THE SEPARATE FT8/FT4 COMPETITION? -- off-mode here. *)
function IsNebraskaFTQSO(const aQso: ContestExchange): boolean;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uDXMultiplierKey,
   uContestRegistry;

function NebraskaPowerMultiplier(aPower: tCategoryPower): longint;
begin
   case aPower of
      cpLOW:
         begin
         Result := 2;
         end;
      cpQRP:
         begin
         Result := 5;
         end;
      else
         begin
         Result := 1;
         end;
      end;
end;

function IsNebraskaFTQSO(const aQso: ContestExchange): boolean;
begin
   Result := aQso.ExtMode in [eFT8, eFT4];
end;

function TContestNebraskaQP.GetDisplayName: string;
begin
   Result := 'Nebraska QSO Party';
end;

function TContestNebraskaQP.GetHostState: string;
begin
   Result := 'NE';
end;

function TContestNebraskaQP.GetCabrilloName: string;
begin
   Result := 'NE-QSO-PARTY';
end;

function TContestNebraskaQP.GetADIFContestId: string;
begin
   (* ADIF 3.1.7's Contest_ID enumeration. NOT 'NEQP' -- New England's. *)
   Result := 'NE-QSO-PARTY';
end;

function TContestNebraskaQP.GetWA7BNMId: integer;
begin
   Result := 336;
end;

function TContestNebraskaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNebraskaQP.GetSubmissionEmail: string;
begin
   Result := 'nebraskaqsoparty@gmail.com';
end;

function TContestNebraskaQP.GetDomesticFileName: string;
begin
   (* The county file. FCONTEST.FoundMyStateInDomFile reads it to decide
      whether MY STATE is a Nebraska county, and then loads nebraska.dom or
      this file. *)
   Result := 'nebraska_cty';
end;

function TContestNebraskaQP.GetFriendlyName: string;
begin
   Result := 'Nebraska QSO Party';
end;

function TContestNebraskaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestNebraskaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestNebraskaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestNebraskaQP.ParseReceivedExchangeFormat(const aText: string;
                                                        aParsers: TExchangeParsers;
                                                        var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestNebraskaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestNebraskaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(aMy, aQso);
end;

function TContestNebraskaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTState(aMy, aQso, aCtx);
end;

function TContestNebraskaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHOrDXQTH(aMy, aQso, aCtx);
end;

function TContestNebraskaQP.GetInStateDomesticFileName: string;
begin
   Result := 'nebraska';
end;

function TContestNebraskaQP.GetFlags: TContestFlags;
begin
   (* Dupes per band and per mode; multipliers ONCE PER CONTEST (neither
      cfMultByBand nor cfMultByMode); 6 m and up are credited. *)
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

function TContestNebraskaQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

(* DIGITAL 1, PHONE 2, CW 3. FM is phone. An FT8 or FT4 QSO belongs to the
   separate competition and scores nothing here; Both and NoMode are not
   modes a contact is made in. An off-band QSO never reaches here
   (UsesBand). *)
procedure TContestNebraskaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if IsNebraskaFTQSO(aQso) then
      begin
      aQso.QSOPoints := 0;
      Exit;
      end;

   case aQso.Mode of
      CW:
         begin
         aQso.QSOPoints := 3;
         end;
      Phone, FM:
         begin
         aQso.QSOPoints := 2;
         end;
      Digital:
         begin
         aQso.QSOPoints := 1;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestNebraskaQP.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := inherited CombineWithMultipliers(aTotals) *
             NebraskaPowerMultiplier(Station.MyPower);
end;

function TContestNebraskaQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10,
                       Band6, Band2, Band222, Band432, Band902, Band1296,
                       Band2304, Band3456, Band5760, Band10G, Band24G,
                       BandLight];
end;

function TContestNebraskaQP.CountsAsMultiplier(const aQso: ContestExchange;
                                               aKind: RemainingMultiplierType): boolean;
begin
   Result := (not IsNebraskaFTQSO(aQso)) and
             inherited CountsAsMultiplier(aQso, aKind);
end;

function TContestNebraskaQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is the state the session SENDS (design 7.11/7.12): a
      Nebraska station's county, anyone else's state or province. *)
   Result := ' 5NN ' + aStation.MyState;
end;

(* EVERY COUNTING QSO WITH A BONUS STATION PAYS -- not a dupe, on a band the
   contest credits, not FT8/FT4. Decided from the whole log, never as a QSO
   is logged (design 7.7). *)
function TContestNebraskaQP.BonusPoints(const aTotals: TScoreTotals;
                                        aView: TLoggedQSOView): longint;
var
   i, s: integer;
   qso: ContestExchange;
begin
   Result := inherited BonusPoints(aTotals, aView);
   for i := 0 to aView.Count - 1 do
      begin
      qso := aView.QSO(i);
      if qso.ceDupe                          or
         IsNebraskaFTQSO(qso)                or
         (not ContestCreditsBand(Self, qso.Band)) then
         begin
         Continue;
         end;
      for s := Low(NEBRASKA_BONUS_STATIONS) to High(NEBRASKA_BONUS_STATIONS) do
         begin
         if string(qso.Callsign) = NEBRASKA_BONUS_STATIONS[s].Call then
            begin
            Result := Result + NEBRASKA_BONUS_STATIONS[s].Points;
            Break;
            end;
         end;
      end;
end;

(* THE STATION TEST -- a Nebraska entrant counts DXCC entities. *)
function TContestNebraskaQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* Yes inside Nebraska; none outside, where an entrant works only Nebraska
   stations. *)
function TContestNebraskaQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* Every country but the USA, Canada, Hawaii and Alaska (those are states
   and provinces here), for a Nebraska entrant; none for anyone else. *)
function TContestNebraskaQP.DXMultiplierKey(const aQso: ContestExchange;
                                            out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if CountsDXMultiplier and
      not IsUSACanadaHawaiiOrAlaskaCountry(aQso.QTH.CountryID) then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;

(* DXCC where the entrant counts the DX multiplier; the CQ list for anyone
   else, who counts none. *)
function TContestNebraskaQP.CountryMode: CountryModeType;
begin
   if CountsDXMultiplier then
      begin
      Result := ARRLCountryMode;
      end
   else
      begin
      Result := CQCountryMode;
      end;
end;

initialization
   RegisterContest(NEBRASKAQSO, TContestNebraskaQP);

end.
