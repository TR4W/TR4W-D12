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

(* FLORIDA QSO PARTY.

  THE 2026 RULES, CHECKED AGAINST THE SPONSOR (#88, 2026-10-26). The texts are
  docs/ContestRules/QSOParties/Florida/ (the rules page, the state and
  province list, the county list and the Cabrillo specification).

  POINTS -- "Each complete non-duplicate Phone contact is worth 1 point per
    band. Each complete non-duplicate CW contact is worth 2 points per band."
    FM is phone.

  MODES -- "No digital QSOs are allowed in the FQP". UsesMode credits CW,
    phone and FM; a digital QSO is an automatic X-QSO. Until #88 the legacy
    OnePhoneTwoCW arm scored it the phone value, 1.

  BANDS -- "No 160 or 80 meters, WARC or VHF bands." 40, 20, 15 and 10 m.

  POWER -- "Calculate the Power Multiplier after you have calculated your QSO
    Points times Multiplier": QRP (5 W or less) x3, LOW (under 100 W) x2,
    HIGH x1, and "If no power is indicated ... it will default to High
    Power." CombineWithMultipliers, from Station.MyPower (the entrant's
    CATEGORY-POWER); FloridaPowerMultiplier is the mapping.

  MULTIPLIERS -- "A multiplier is counted once per mode, regardless of the
    number of bands" (cfMultByMode). For a Florida entrant: "50 States
    (including Florida); District of Columbia (DC); 13 Canadian Provinces ...;
    DXCC Countries (outside the US and Canada); Maritime Mobile (ITU Regions
    R1, R2, R3). There is no in-state County multiplier." florida.dom holds the
    states, DC and the provinces, each county mapped to Fl; the DXCC country is
    the DX multiplier (DXMultiplierKey), which leaves out KH6 and KL7 because
    "US (including KH6/KL7) operators send State" -- they count once, as the
    states HI and AK. For an entrant outside Florida: the 67 counties
    (florida_cty.dom).

  NOT BUILT -- each needs a fact scoring does not have, listed on #88:
    * MARITIME MOBILE R1/R2/R3. A /MM station is not a domestic call, so its
      exchange goes to the DX parser, which takes the QTH as text and asks no
      table; a .dom entry for R1-R3 would never be read. It needs a rule of
      its own (a /MM call's DX key from its region) and a ruling.
    * "Mobile and Expedition scores are based on cumulative QSOs and
      multipliers counted once overall" and "Special 1x1 stations have no
      multiplier": both depend on the entrant's CATEGORY-STATION, which does
      not reach scoring.

  CABRILLO -- CONTEST: FCG-FQP, the sponsor's Cabrillo specification. *)
unit uContestFloridaQP;

{$I tr4w.inc}

interface

uses
   (* cpLOW / cpQRP -- the entrant's CATEGORY-POWER, as TStationContext
      carries it. First, so VC's names win wherever the two overlap. *)
   uSettingsModel,
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestFloridaQP = class(TContestStateQSOPartyBase)
   protected

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'FL' -- but the base makes it abstract
         for state parties precisely so that answer is never an accident, and
         three separate places in this tree used to hand-type it. *)
      function GetHostState: string; override;

      (* TWO, FROM THE PUBLISHED RULES: "Florida stations on a county line
         (maximum of two counties) may be claimed as a separate QSO and
         multiplier from each county."

         THIS IS NEW BEHAVIOUR AND WAS CHOSEN, NOT MOVED. TR4W has never
         enforced any limit -- LOGSTUFF.ApplyFirstQTHAndQueueRest queues every
         valid county the operator typed -- and NY4I, 2026-09-28: "It has not
         enforced a limit. It relied upon participants not being given more
         than the ones allowed. But knowing and setting a limit makes our edit
         checking of the exchange more robust."

         So Florida is the first contest whose exchange is actually bounded,
         and it is bounded because its number is KNOWN. Michigan's is not, and
         is deliberately left unlimited rather than inferred from this one. *)
      function GetCountyLineCountiesMax: integer; override;
      (* THE GETTERS BEHIND TContestBase's PROPERTIES.

         PROTECTED, MATCHING THE BASE. Left public -- which is what the first
         conversion did, because a class body with no section defaults to
         public -- BOTH X.CabrilloName and X.GetCabrilloName are callable on
         this object. Two ways to ask the same question is exactly the
         ambiguity a property removes, so the getter is not part of the
         surface: callers use the property, descendants override the getter. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetFriendlyName: string; override;

      (* STATED AT M10 S5, transcribed from the rows the base read until
         then (ContestsArray, QSOParties, ContestsBooleanArray). The
         flags: see TContestBase.GetFlags. *)
      function GetWA7BNMId: integer; override;
      function GetDomesticFileName: string; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function ParseReceivedExchangeFormat(const aText: string;
                                           aParsers: TExchangeParsers;
                                           var aExch: ContestExchange): boolean; override;
      function GetInStateDomesticFileName: string; override;
      function GetFlags: TContestFlags; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* Points times the multipliers, then times the power multiplier -- the
         header. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      constructor Create(aContest: TContestHandle); override;

      (* 40, 20, 15 and 10 m -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* CW and phone (FM is phone); no digital -- the header. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;
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
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

(* THE POWER MULTIPLIER FOR A CATEGORY-POWER -- QRP x3, LOW x2, anything else
   (HIGH, or none stated) x1. Public so the tests assert the mapping itself,
   not only a product. *)
function FloridaPowerMultiplier(aPower: tCategoryPower): longint;

implementation

uses
   uCabrilloExchange,
   uExchangeFields,
   uDXMultiplierKey,
   SysUtils, uContestRegistry;

function FloridaPowerMultiplier(aPower: tCategoryPower): longint;
begin
   case aPower of
      cpLOW:
         begin
         Result := 2;
         end;
      cpQRP:
         begin
         Result := 3;
         end;
      else
         begin
         (* "If no power is indicated ... it will default to High Power." *)
         Result := 1;
         end;
      end;
end;

constructor TContestFloridaQP.Create(aContest: TContestHandle);
begin
   inherited Create(aContest);
end;

(* CW 2, PHONE 1 -- the header. FM is phone. A digital QSO never reaches here
   (UsesMode), nor an off-band one (UsesBand), nor a station an out-of-state
   entrant may not credit (CreditsWorkedStation). Both and NoMode are not
   modes a contact is made in. *)
procedure TContestFloridaQP.CalculateQSOPoints(var aQso: ContestExchange);
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

function TContestFloridaQP.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := inherited CombineWithMultipliers(aTotals) *
             FloridaPowerMultiplier(Station.MyPower);
end;

function TContestFloridaQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band40, Band20, Band15, Band10];
end;

(* "No digital QSOs are allowed in the FQP". Any submode of CW, Phone or FM is
   credited -- eNoMode and eData included, as the contract asks -- and no
   submode of Digital is. An identity fact: no station is asked. *)
function TContestFloridaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM];
end;

function TContestFloridaQP.GetDisplayName: string;
begin
   Result := 'Florida QSO Party';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestFloridaQP.GetCabrilloName: string;
begin
   Result := 'FCG-FQP';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestFloridaQP.GetADIFContestId: string;
begin
   Result := 'FL-QSO-PARTY';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestFloridaQP.GetFriendlyName: string;
begin
   Result := 'Florida QSO Party';
end;

function TContestFloridaQP.GetWA7BNMId: integer;
begin
   Result := 325;
end;

function TContestFloridaQP.GetDomesticFileName: string;
begin
   Result := 'florida_cty';
end;

function TContestFloridaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestFloridaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestFloridaQP.ParseReceivedExchangeFormat(const aText: string;
                                                       aParsers: TExchangeParsers;
                                                       var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestFloridaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestFloridaQP.GetInStateDomesticFileName: string;
begin
   Result := 'florida';
end;

function TContestFloridaQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByMode];
end;

function TContestFloridaQP.GetHostState: string;
begin
   Result := 'FL';
end;

function TContestFloridaQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

(* THE EXCHANGE IS RST AND A COUNTY, OR RST AND A COUNTRY PREFIX.

   THE RECEIVED SIDE CARRIES THE ONE RULE THAT IS ACTUALLY FLORIDA'S, and it was
   sitting in a shared arm as two `if Contest = FLORIDAQSOPARTY` tests. A
   station outside Florida is identified by its DXCC PREFIX rather than by the
   DXQTH text every other contest on that arm uses, and the test is made twice
   because a non-Florida station reaches it two ways: with no QTH string at all,
   or with the literal 'DX'.

   THAT IS EXACTLY THE SHAPE THIS FACTORY EXISTS TO REMOVE -- a contest's rule
   written where the contest's name has to be asked for. It is expressed here as
   behaviour instead.

   THE LEGACY FLORIDA-NAMED TESTS WERE DELETED ON 2026-09-29: this class's
   override is the only route, so a branch testing for Florida BY NAME could
   only ever be reached by Florida. The SENT column is the plain RST-and-state
   helper (M11 S9c); the received one is Florida's own. *)
function TContestFloridaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTState(aMy, aQso, aCtx);
end;

function TContestFloridaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   (* Reproduces the legacy decision tree exactly.  aCtx.HisQTH is what the
      exporter resolved from rx.QTHString, so the '' and 'DX' cases below are
      the same two the legacy arm tests. *)
   if aQso.QTHString = '' then
      begin
      if aQso.DXQTH = '' then
         begin
         Result := Format('%-3s %-7s', [aCtx.RSTReceived, 'DX']);
         end
      else
         begin
         Result := Format('%-3s %-7s', [aCtx.RSTReceived, string(aQso.QTH.Prefix)]);
         end;
      end
   else if aQso.QTHString = 'DX' then
      begin
      Result := Format('%-3s %-7s', [aCtx.RSTReceived, string(aQso.QTH.Prefix)]);
      end
   else
      begin
      Result := Format('%-3s %-7s', [aCtx.RSTReceived, aCtx.HisQTH]);
      end;
end;

function TContestFloridaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                               const aQso: ContestExchange): string;
begin
   Result := Format('%-3d %-7s', [aQso.RSTSent, aMy.MyState]);
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`ARRLDXCCWithNoUSAOrCanada`) until the kind was
   deleted. *)
function TContestFloridaQP.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   "DXCC Countries (outside the US and Canada)", where "US (including
   KH6/KL7) operators send State": Hawaii and Alaska are the states HI and AK
   in florida.dom, so they are not also a DXCC multiplier (#88, 2026-10-26;
   until then this was every country but the USA and Canada, and only the
   session's domestic-country list kept KH6 and KL from counting twice). *)
function TContestFloridaQP.DXMultiplierKey(const aQso: ContestExchange;
                                           out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if not IsUSACanadaHawaiiOrAlaskaCountry(aQso.QTH.CountryID) then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only, at every station. *)
function TContestFloridaQP.CountryMode: CountryModeType;
begin
   Result := ARRLCountryMode;
end;

initialization
   RegisterContest(FLORIDAQSOPARTY, TContestFloridaQP);

end.
