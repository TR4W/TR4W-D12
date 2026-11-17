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

(* SOUTH CAROLINA QSO PARTY -- issue 111 (113 was its duplicate), the
  sponsor's rules rev. 2.2.26 (docs/ContestRules/QSOParties/SouthCarolina/,
  fetched 2026-11-15). Section numbers below are the rules'.

  3: 160, 80, 40, 20, 15, 10, 6 and 2 m. 4: phone, CW and digital; "FT8,
  FT4, PSK, RTTY, JT65 or other digital modes shall be considered
  equivalent" (9.1.2) -- one digital dupe mode, which the base's dupe slots
  already are. 4.1 logs phone as PH, so FM is PH; digital is RY
  (FormatCabrilloModeDigitalAsRY, Delaware's and New Mexico's).

  9.1 POINTS, decided from the received QTH (never the call):
    an SC entrant: 2 with another SC station (a host county), 4 with anyone
      outside SC (a state, province or DX), in every mode;
    an out-of-state entrant: 2, with SC stations only (9.5; the base's
      host-area rule refuses anyone else).
  "Host county" is the party base's one statement, QSOCreditsHostCounty --
  the same test that earns the host state below.

  9.2 MULTIPLIERS "ONCE PER MODE PER BAND".
    Out of state: the 46 counties.
    In state: the counties; "Each USA state including South Carolina and
      Washington, D.C." -- a county QSO also earns SC through issue 317's
      second domestic key (InStateCountyEarnsHostState), in the county's
      scope; "enter the SC County as the exchange (not SC)", so the Sc line
      in southcarolina.dom has no alias and a typed SC is refused; DC is its
      own multiplier (5.2); the 13 provinces. "DX contacts count for QSO
      points only" -- RSTDomesticOrDXQTHExchange, no DX entry.
  9.3 BONUS STATIONS, once per band per mode, after multiplying, dupes and
    X-QSOs excluded: W4CAE 350, WW4SF 250, K4YTZ 250. 9.3's own example,
    WW4SF/CHAR, pays through the party base's county-suffix matcher.
  12: county lines are separate contacts; the rules give no number, and the
    research of 2026-10-26 posted 2 on the issue (NY4I's North Dakota
    ruling), so 2.
  NOT BUILT (issue 133, the entrant's station category): the
  Mobile/Expedition "each SC county activated" multiplier (6.2.3 and 9.2.2
  disagree on who earns it; asked on the issue), and an expedition
  re-working everyone after moving county.
  Cabrillo SC-QSO-PARTY (the rules' own example, DXLog SCQP.txt). Logs go
  through the sponsor's web page, so no e-mail. WA7BNM 123 (research of
  2026-10-26). *)
unit uContestSouthCarolinaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   SC_QSO_PARTY_CONTEST_ID = 'SC-QSO-PARTY';

type
   TContestSouthCarolinaQP = class(TContestStateQSOPartyBase)
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
      function GetCountyLineCountiesMax: integer; override;
      function ParseReceivedExchangeFormat(const aText: string;
         aParsers: TExchangeParsers; var aExch: ContestExchange): boolean; override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
      function GetBonusStations: TBonusStationList; override;
      function CountsTowardBonus(const aQso: ContestExchange): boolean; override;
   public
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      function CQExchangeDefault(const aStation: TStationContext): string; override;
      function CabrilloModeString(aMode: ModeType;
                                  aExtMode: ExtendedModeType): string; override;
      function HasDXMultiplier: boolean; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;
      function ExchangeCarriesDomesticQTH: boolean; override;
      function AdditionalDomesticMultiplierKey(const aQso: ContestExchange;
         out aKey: string): boolean; override;
   end;

implementation

uses
   SysUtils, uExchangeFields, uCabrilloExchange, uADIFExchange,
   uCabrilloFormat,   (* FormatCabrilloModeDigitalAsRY *)
   uContestRegistry;

function TContestSouthCarolinaQP.GetDisplayName: string;
begin
   Result := 'South Carolina QSO Party';
end;

(* WHEN IT RUNS -- Q99 (docs/CONTEST_SCHEDULES.csv, applied 2026-11-16). CSV
   row SC-QSO-PARTY: status verified; rules
   https://scqso.com/wp-content/uploads/2026/02/SCQPRULES2024_0126.pdf;
   rules year 2026. *)
function TContestSouthCarolinaQP.GetSchedule: string;
begin
   Result := '4th Saturday of February at 15:00 UTC for 11h';
end;

function TContestSouthCarolinaQP.GetFriendlyName: string;
begin
   Result := 'South Carolina QSO Party';
end;

function TContestSouthCarolinaQP.GetHostState: string;
begin
   Result := 'SC';
end;

function TContestSouthCarolinaQP.GetCabrilloName: string;
begin
   Result := 'SC-QSO-PARTY';
end;

function TContestSouthCarolinaQP.GetADIFContestId: string;
begin
   Result := SC_QSO_PARTY_CONTEST_ID;
end;

function TContestSouthCarolinaQP.GetWA7BNMId: integer;
begin
   Result := 123;
end;

function TContestSouthCarolinaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestSouthCarolinaQP.GetSubmissionEmail: string;
begin
   (* 13: "The SCQP will only accept log files submitted via our website". *)
   Result := '';
end;

function TContestSouthCarolinaQP.GetDomesticFileName: string;
begin
   Result := 'southcarolina_cty';
end;

function TContestSouthCarolinaQP.GetInStateDomesticFileName: string;
begin
   Result := 'southcarolina';
end;

function TContestSouthCarolinaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestSouthCarolinaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestSouthCarolinaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestSouthCarolinaQP.GetFlags: TContestFlags;
begin
   (* Dupes, multipliers and bonuses all per band per mode; 6 and 2 m. *)
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand, cfMultByMode, cfVHFBandsEnabled];
end;

function TContestSouthCarolinaQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

function TContestSouthCarolinaQP.ParseReceivedExchangeFormat(const aText: string;
   aParsers: TExchangeParsers; var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestSouthCarolinaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestSouthCarolinaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestSouthCarolinaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   (* 5.4: DX stations send "Signal report and DX (not country)". A typed
      "599 DX" keeps its text in QTHString and resolves no DomesticQTH, so
      CabrilloReceivedRSTQTHDX (which tests QTHString) printed an EMPTY
      column; this helper prints DX whenever the record holds no domestic
      QTH -- Georgia's (review H4, 2026-11-16). *)
   Result := CabrilloReceivedRSTDomesticQTHOrDX(aMy, aQso, aCtx);
end;

procedure TContestSouthCarolinaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   (* 9.1: the mode does not change the points; who was worked does. *)
   if Station.InHostState and not QSOCreditsHostCounty(aQso) then
      begin
      aQso.QSOPoints := 4;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;
end;

function TContestSouthCarolinaQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2];
end;

function TContestSouthCarolinaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   (* Every digital mode counts, FT8 and FT4 included (4.3). *)
   Result := aMode in [CW, Phone, FM, Digital];
end;

function TContestSouthCarolinaQP.CQExchangeDefault(const aStation: TStationContext): string;
var
   my: TMyStationExchange;
begin
   my := Default(TMyStationExchange);
   my.MyState := aStation.MyState;
   Result := ' 5NN ' + SentStateOrDX(my);
end;

function TContestSouthCarolinaQP.CabrilloModeString(aMode: ModeType;
                                                    aExtMode: ExtendedModeType): string;
begin
   Result := FormatCabrilloModeDigitalAsRY(aMode, aExtMode);
end;

function TContestSouthCarolinaQP.HasDXMultiplier: boolean;
begin
   Result := False;
end;

function TContestSouthCarolinaQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestSouthCarolinaQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

function TContestSouthCarolinaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestSouthCarolinaQP.AdditionalDomesticMultiplierKey(const aQso: ContestExchange;
   out aKey: string): boolean;
begin
   (* 9.2.1: a county also earns SC, in state -- the header (issue 317). *)
   Result := InStateCountyEarnsHostState(aQso, aKey);
end;

function TContestSouthCarolinaQP.GetBonusStations: TBonusStationList;
begin
   Result := nil;
   SetLength(Result, 3);
   Result[0].Call := 'W4CAE';
   Result[0].Points := 350;
   Result[0].Scope := bsOncePerBandAndMode;
   Result[1].Call := 'WW4SF';
   Result[1].Points := 250;
   Result[1].Scope := bsOncePerBandAndMode;
   Result[2].Call := 'K4YTZ';
   Result[2].Points := 250;
   Result[2].Scope := bsOncePerBandAndMode;
end;

function TContestSouthCarolinaQP.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   Result := IsCreditedContact(aQso);
end;

initialization
   RegisterContestById(SC_QSO_PARTY_CONTEST_ID, TContestSouthCarolinaQP);

end.
