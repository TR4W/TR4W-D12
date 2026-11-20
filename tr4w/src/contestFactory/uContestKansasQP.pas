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

(* KANSAS QSO PARTY -- issue 121, the sponsor's 2026 rules
  (docs/ContestRules/QSOParties/Kansas/KSQPRules2026.pdf, fetched 2026-11-15).

  80/40/20/15/10/6 m; no WARC, repeaters or 2 m. Phone (FM is phone) 2
  points, CW and RTTY 3. "Stations may be worked once on Phone, once on CW
  and once on RTTY per band/mode": the three modes are the dupe modes, which
  the base's dupe slots already are. FT4/FT8 is a SEPARATE log with its own
  winners and no multipliers ("Don't include FT4/8 contacts in your regular
  KSQP log"), so here it is off-mode -- an automatic X-QSO -- as is every
  other digital submode but RTTY.

  Received: RST plus county (Kansas station) or state/province/"DX".
  Multipliers "are counted only once" -- overall, no band or mode repeat.
    Outside Kansas: the 105 counties (kansas_cty.dom; FCONTEST's
      MultipliersIsCounties makes each its own multiplier).
    In Kansas: 50 states -- "the first Kansas county logged counts as the
      Kansas multiplier", so every county line maps `> Ks` -- 13 provinces
      and one DX: 64 in all. "The KS abbreviation is not used": the Ks line
      in kansas.dom has no alias, so a typed KS is refused. DC is not listed
      (the rules count 50 states; DXLog KSQP.txt and N1MM refuse it too).
    The DX multiplier is ONE domestic entry (`Dx = DX`), so the exchange is
      RSTDomesticQTHExchange -- the Missouri/Quebec pattern; under
      DomesticOrDX a Dx row would never count.
  DXLog KSQP.txt's comment "the first KS county counts as two multipliers
  for in-state stations" is NOT followed: the sponsor's 64 maximum is 50 +
  13 + 1, which leaves no room for county multipliers in state.

  Score = QSO points x multipliers + 100 for KS0KS, once ("a one-time bonus
  of 100 points ... maximum 100"). No power factor.
  A Kansas station that changes county is a new station (the base's
  received-QTH dupe key). County lines: one QSO per county, no stated limit.
  Own-mobile/rover entrants (their own county changes) are issues 133/87.
  Cabrillo KS-QSO-PARTY (DXLog KSQP.txt). Logs are uploaded; no e-mail
  address is for logs. WA7BNM ref not looked up (no automated access). *)
unit uContestKansasQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase,
   (* TCallHistoryFields, chf... -- CallHistoryFields. *)
   uCallHistory;

const
   KS_QSO_PARTY_CONTEST_ID = 'KS-QSO-PARTY';

type
   TContestKansasQP = class(TContestStateQSOPartyBase)
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
      function HasDXMultiplier: boolean; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;
      function ExchangeCarriesDomesticQTH: boolean; override;
   public
      (* WHAT THE CALL HISTORY FILE PREFILLS --
         THE COUNTY OR STATE -- the site file QSOP_KS carries Call, Exch1, UserText
         (read 2026-11-20): the QTH the station sent (a county code, a state
         or a DX prefix). This party remembers the QTH alone (its received
         fields carry no name). 53 of 53 non-state rows are county keys of its
         own county file; the rest are DX prefixes and a few spellings it lacks.
         See TContestBase.CallHistoryFields. *)
      function CallHistoryFields: TCallHistoryFields; override;

      (* THE SITE'S FILE STEM. See TContestBase.CallHistorySiteName. *)
      function CallHistorySiteName: string; override;
   end;

implementation

uses
   SysUtils, uExchangeFields, uCabrilloExchange, uADIFExchange, uContestRegistry;

function TContestKansasQP.GetDisplayName: string;
begin
   Result := 'Kansas QSO Party';
end;

(* WHEN IT RUNS -- NY4I's dates (2026-11-20; the sponsor states no
   recurrence): two sessions, 1400Z Saturday to 0200Z Sunday and 1400Z to
   2000Z Sunday, for 2026 to 2031 --
     Aug 29-30 2026, Aug 28-29 2027, Aug 26-27 2028, Aug 25-26 2029,
     Aug 24-25 2030, Aug 30-31 2031.
   A DATE LIST, NOT A RULE: after 2031 the contest is undated until the
   next dates are added here. *)
function TContestKansasQP.GetSchedule: string;
begin
   Result := '2026-08-29 at 14:00 UTC for 12h; 2026-08-30 at 14:00 UTC for 6h; ' +
             '2027-08-28 at 14:00 UTC for 12h; 2027-08-29 at 14:00 UTC for 6h; ' +
             '2028-08-26 at 14:00 UTC for 12h; 2028-08-27 at 14:00 UTC for 6h; ' +
             '2029-08-25 at 14:00 UTC for 12h; 2029-08-26 at 14:00 UTC for 6h; ' +
             '2030-08-24 at 14:00 UTC for 12h; 2030-08-25 at 14:00 UTC for 6h; ' +
             '2031-08-30 at 14:00 UTC for 12h; 2031-08-31 at 14:00 UTC for 6h';
end;

function TContestKansasQP.GetFriendlyName: string;
begin
   Result := 'Kansas QSO Party';
end;

function TContestKansasQP.GetHostState: string;
begin
   Result := 'KS';
end;

function TContestKansasQP.GetCabrilloName: string;
begin
   Result := 'KS-QSO-PARTY';
end;

function TContestKansasQP.GetADIFContestId: string;
begin
   Result := KS_QSO_PARTY_CONTEST_ID;
end;

function TContestKansasQP.GetWA7BNMId: integer;
begin
   (* Not looked up: WA7BNM's calendar allows no automated access. *)
   Result := 0;
end;

function TContestKansasQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestKansasQP.GetSubmissionEmail: string;
begin
   (* Logs go to ksqp.contesting.com; logs@ksqsoparty.org is for the
      separate FT4/FT8 log only. *)
   Result := '';
end;

function TContestKansasQP.GetDomesticFileName: string;
begin
   Result := 'kansas_cty';
end;

function TContestKansasQP.GetInStateDomesticFileName: string;
begin
   Result := 'kansas';
end;

function TContestKansasQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestKansasQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestKansasQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestKansasQP.GetFlags: TContestFlags;
begin
   (* Dupes per band and mode; multipliers once overall; 6 m is a band. *)
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

function TContestKansasQP.GetCountyLineCountiesMax: integer;
begin
   (* "A separate QSO must be logged for each county" -- no number given. *)
   Result := CountyLineCountiesUnlimited;
end;

function TContestKansasQP.ParseReceivedExchangeFormat(const aText: string;
   aParsers: TExchangeParsers; var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTH(aText, aExch);
end;

function TContestKansasQP.GetADIFSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestKansasQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestKansasQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
end;

procedure TContestKansasQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   (* UsesMode has already refused every digital submode but RTTY. *)
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

function TContestKansasQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band80, Band40, Band20, Band15, Band10, Band6];
end;

function TContestKansasQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   (* Digital is RTTY only; eNoMode/eData mean "some submode", so an old
      record is never proven off-mode (Q98 S1). *)
   Result := (aMode in [CW, Phone, FM]) or
             ((aMode = Digital) and
              (aExtMode in [eNoMode, eData, eData_R, eRTTY, eRTTY_R]));
end;

function TContestKansasQP.CQExchangeDefault(const aStation: TStationContext): string;
var
   my: TMyStationExchange;
begin
   my := Default(TMyStationExchange);
   my.MyState := aStation.MyState;
   Result := ' 5NN ' + SentStateOrDX(my);
end;

function TContestKansasQP.HasDXMultiplier: boolean;
begin
   (* The in-state DX multiplier is the one domestic `Dx` entry. *)
   Result := False;
end;

function TContestKansasQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestKansasQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

function TContestKansasQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestKansasQP.GetBonusStations: TBonusStationList;
begin
   Result := nil;
   SetLength(Result, 1);
   Result[0].Call := 'KS0KS';
   Result[0].Points := 100;
   Result[0].Scope := bsOnce;
end;

function TContestKansasQP.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   Result := IsCreditedContact(aQso);
end;

function TContestKansasQP.CallHistoryFields: TCallHistoryFields;
begin
   Result := CallHistoryFieldList([chfExch1]);
end;

function TContestKansasQP.CallHistorySiteName: string;
begin
   Result := 'QSOP_KS';
end;

initialization
   RegisterContestById(KS_QSO_PARTY_CONTEST_ID, TContestKansasQP);

end.
