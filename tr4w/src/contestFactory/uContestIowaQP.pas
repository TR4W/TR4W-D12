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

(* IOWA QSO PARTY -- issue 120, the sponsor's 2026 rules ("There are no rule
  changes for 2026"), w0yl.com/IAQP, saved with the county and state lists in
  docs/ContestRules/QSOParties/Iowa/ (fetched 2026-11-15).

  "Any amateur band EXCEPT the 60m, 30m, 17m, and 12m bands": 160-10 m and
  6 m through 24 GHz, at face value (the rules' frequency table stops at
  70 cm, but only suggests frequencies).
  Phone 1 point ("Phone (includes digital phone)"), CW 2, digital 2.
  Digital: "FT modes are allowed as long as the FULL Iowa QSO Party exchange
  is completed by BOTH parties ... WSJT-x (FT8 and FT4) will NOT work".
  NY4I, issue 120, 2026-11-18, answering whether the WSJT-X modes should
  stay refused: "That only mode that could be accepted is JTTY ... we need
  to add that as a new sub-mode." JTTY is WSJT-X 3.3's keyboard mode
  (eJTTY), which carries free text, so the full exchange can be sent.
  NY4I, issue 120, 2026-11-19, correcting that reading: "the only WSJTX
  mode that would be accepted is JTTY", and "JS8CALL is allowed too since it
  supports a free-form exchange"; the rules' "other digital modes" stand.
  So the class states its ALLOWED digital submodes (issue 122's ruling,
  uContestBase.DigitalSubmodeAllowed): RTTY (and reversed RTTY), PSK31,
  PSK63 (and reversed PSK), JS8 and JTTY. FT8, FT4, JT65, FST4, FST4W,
  MFSK and any submode added later are off-mode -- an automatic X-QSO.
  eNoMode and the generic data modes (eData, eData_R, eData_FM) stay
  accepted because they mean "some submode", so an old or untyped record --
  or a radio in DATA-R -- is never proven off-mode (Q98 S1).
  "Phone (includes digital phone)": a C4FM or D-STAR QSO is logged as phone
  to score and dupe as phone; a record logged as Digital is digital, since
  the dupe slot (DupeModeOf) sees only the mode, not the submode.
  Dupes: "ONCE per MODE per BAND per COUNTY" -- the base's received-QTH key.

  Received: RST plus county, state/province, or "DX".
  Multipliers "one time only, NOT per Band, and NOT per Mode".
    Outside Iowa: the 99 counties.
    In Iowa: the 99 counties, "each state (including Iowa)" and the 13
      provinces. An Iowa station sends its county, so a county QSO also earns
      IA: the second DOMESTIC key of issue 317 (InStateCountyEarnsHostState),
      with the county's scope (overall). iowa.dom names `Ia = ^Iowa` with no
      alias, so IA is never received instead of a county.
    The sponsor's state list reads "MD Maryland and DC": DC is an alias of
      Md (DXLog refuses DC; the sponsor wins).
    "No multiplier for working DX stations": DX is points only, so the
      exchange is RSTDomesticOrDXQTHExchange (Kentucky's).
  Score = QSO points x multipliers. No power factor, no bonus station.
  County lines: "all intersecting counties may be worked in a single
  exchange" -- no number is given, so no limit.
  Own-mobile entrants (their own county changes) are issues 133/87.
  Cabrillo IA-QSO-PARTY (DXLog IAQP.txt). Logs are uploaded to
  iaqp.contesting.com. WA7BNM ref not looked up (no automated access). *)
unit uContestIowaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase,
   (* TCallHistoryFields, chf... -- CallHistoryFields. *)
   uCallHistory;

const
   IA_QSO_PARTY_CONTEST_ID = 'IA-QSO-PARTY';

type
   TContestIowaQP = class(TContestStateQSOPartyBase)
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
   public
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      function CQExchangeDefault(const aStation: TStationContext): string; override;
      function HasDXMultiplier: boolean; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;
      function ExchangeCarriesDomesticQTH: boolean; override;
      function AdditionalDomesticMultiplierKey(const aQso: ContestExchange;
         out aKey: string): boolean; override;
   public
      (* WHAT THE CALL HISTORY FILE PREFILLS --
         THE COUNTY OR STATE -- the site file QSOP_IA carries Call, Exch1, UserText
         (read 2026-11-20): the QTH the station sent (a county code, a state
         or a DX prefix). This party remembers the QTH alone (its received
         fields carry no name). 20 of 20 non-state rows are county keys of its
         own county file (Pennsylvania: its in-state file pa.dom, which holds the ARRL sections); the rest are DX prefixes and a few spellings it lacks.
         See TContestBase.CallHistoryFields. *)
      function CallHistoryFields: TCallHistoryFields; override;

      (* THE SITE'S FILE STEM. See TContestBase.CallHistorySiteName. *)
      function CallHistorySiteName: string; override;
   end;

implementation

uses
   SysUtils, uExchangeFields, uCabrilloExchange, uADIFExchange, uContestRegistry;

function TContestIowaQP.GetDisplayName: string;
begin
   Result := 'Iowa QSO Party';
end;

(* WHEN IT RUNS -- Q99 (docs/CONTEST_SCHEDULES.csv, applied 2026-11-16). CSV
   row IA-QSO-PARTY: status candidate; rules https://w0yl.com/IAQP/; rules
   year 2026. CANDIDATE: date from a calendar, not yet checked against the
   sponsor's rules. *)
function TContestIowaQP.GetSchedule: string;
begin
   Result := '3rd Saturday of September at 14:00 UTC for 12h';
end;

function TContestIowaQP.GetFriendlyName: string;
begin
   Result := 'Iowa QSO Party';
end;

function TContestIowaQP.GetHostState: string;
begin
   Result := 'IA';
end;

function TContestIowaQP.GetCabrilloName: string;
begin
   Result := 'IA-QSO-PARTY';
end;

function TContestIowaQP.GetADIFContestId: string;
begin
   Result := IA_QSO_PARTY_CONTEST_ID;
end;

function TContestIowaQP.GetWA7BNMId: integer;
begin
   (* Not looked up: WA7BNM's calendar allows no automated access. *)
   Result := 0;
end;

function TContestIowaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestIowaQP.GetSubmissionEmail: string;
begin
   (* Logs are uploaded; iowaqsoparty@hotmail.com is for questions. *)
   Result := '';
end;

function TContestIowaQP.GetDomesticFileName: string;
begin
   Result := 'iowa_cty';
end;

function TContestIowaQP.GetInStateDomesticFileName: string;
begin
   Result := 'iowa';
end;

function TContestIowaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestIowaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestIowaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestIowaQP.GetFlags: TContestFlags;
begin
   (* Dupes per band and mode; multipliers once overall; VHF/UHF bands. *)
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

function TContestIowaQP.GetCountyLineCountiesMax: integer;
begin
   Result := CountyLineCountiesUnlimited;
end;

function TContestIowaQP.ParseReceivedExchangeFormat(const aText: string;
   aParsers: TExchangeParsers; var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestIowaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestIowaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestIowaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   (* "DX Stations ... send RS/T and DX". A typed "599 DX" keeps its text in
      QTHString and resolves no DomesticQTH, so CabrilloReceivedRSTQTHDX
      (which tests QTHString) printed an EMPTY column; this helper prints DX
      whenever the record holds no domestic QTH -- Georgia's (review H4,
      2026-11-16). *)
   Result := CabrilloReceivedRSTDomesticQTHOrDX(aMy, aQso, aCtx);
end;

procedure TContestIowaQP.CalculateQSOPoints(var aQso: ContestExchange);
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
      Digital:
         begin
         aQso.QSOPoints := 2;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestIowaQP.UsesBand(aBand: BandType): boolean;
begin
   (* "Any amateur band EXCEPT the 60m, 30m, 17m, and 12m bands" -- read at
      face value, 160 m through 24 GHz. BandLight is no amateur allocation;
      AllBands and NoBand are not bands. *)
   Result := (aBand in [Band160..Band24G]) and
             not (aBand in [Band30, Band17, Band12]);
end;

function TContestIowaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   case aMode of
      CW, Phone, FM:
         begin
         Result := True;
         end;
      Digital:
         begin
         (* The free-form modes that can pass the full exchange (NY4I,
            2026-11-19 -- the header). *)
         Result := DigitalSubmodeAllowed(aExtMode,
                      RTTY_SUBMODES + [ePSK31, ePSK63, ePSK_R, eJS8, eJTTY]);
         end;
      else
         begin
         Result := False;
         end;
      end;
end;

function TContestIowaQP.CQExchangeDefault(const aStation: TStationContext): string;
var
   my: TMyStationExchange;
begin
   my := Default(TMyStationExchange);
   my.MyState := aStation.MyState;
   Result := ' 5NN ' + SentStateOrDX(my);
end;

function TContestIowaQP.HasDXMultiplier: boolean;
begin
   Result := False;
end;

function TContestIowaQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestIowaQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

function TContestIowaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestIowaQP.AdditionalDomesticMultiplierKey(const aQso: ContestExchange;
   out aKey: string): boolean;
begin
   (* A county also earns IA, in state -- the header (issue 317). *)
   Result := InStateCountyEarnsHostState(aQso, aKey);
end;

function TContestIowaQP.CallHistoryFields: TCallHistoryFields;
begin
   Result := CallHistoryFieldList([chfExch1]);
end;

function TContestIowaQP.CallHistorySiteName: string;
begin
   Result := 'QSOP_IA';
end;

initialization
   RegisterContestById(IA_QSO_PARTY_CONTEST_ID, TContestIowaQP);

end.
