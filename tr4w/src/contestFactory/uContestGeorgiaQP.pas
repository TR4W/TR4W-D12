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

(* THE GEORGIA QSO PARTY -- added 2026-10-23.

  THE SOURCE. The sponsor's rules as NY4I saved them,
  docs/ContestRules/QSOParties/Georgia/GA-QSO-PARTY-Rules.txt (SECC and
  SEDXC; WA7BNM ref 328). Nothing here comes from D7, which never had this
  contest.

  A NEW CONTEST, SO IT REGISTERS BY ITS ID (Q108 S3/S4): no ContestType
  member, no legacy number, no VC.pas entry. Its id 'GA-QSO-PARTY' is STORED
  DATA from today (every log's contest row) and is never given to another
  contest. The multi-op network refuses it and its UDP <contestnr> is
  derived from the id -- both the registry's, nothing here.

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE: one host state, county
  multipliers for everyone outside it, and an out-of-state station may work
  only Georgia stations. A copy of the nearest party (Nebraska, Delaware) it
  owns, not a shared rule (design 1.4).

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- the 2nd full weekend of April, 1800Z Saturday to 0359Z Sunday and
    1400Z to 2359Z Sunday. Contest schedules are not built (design Q99);
    recorded only.

  MODES -- "Digital contacts aren't allowed". CW and SSB. FM is phone here,
    as in every party: the rules' mode categories are "CW" and "SSB -- Phone
    only contacts". UsesMode credits CW, Phone and FM and refuses Digital,
    whatever its submode, so a digital QSO is logged and is an automatic
    X-QSO (Q98, QSOIsXQSO): 0 points, no multiplier, no dupe. Neither
    CalculateQSOPoints nor the multiplier sheet ever sees one.

  BANDS -- the rules' frequency list: 160, 80, 40, 20, 15, 10 and 6 m. No
    WARC. UsesBand; cfVHFBandsEnabled so 6 m can be reached.

  EXCHANGE -- RST and a Georgia county (Georgia stations), a state (US), a
    province (VE) or "DX". RSTDomesticOrDXQTHExchange, as every party with a
    DX branch: the session's domestic table takes a county, state or
    province, and a DX QTH otherwise. A DX entrant SENDS "DX": the sent
    columns are the StateOrDX helpers, which write DX when MY STATE is
    empty.

  QSO POINTS -- "Each completed SSB contact counts one point. Each completed
    CW contact counts two points."

  DUPES -- "once per band and mode": cfQSOByBand, cfQSOByMode. "GEORGIA
    ROVER stations may be worked once per county, per mode, per band" -- the
    party base's DupeKeyIncludesReceivedQTH (Q118): the same call on the
    same band and mode is a new QSO when it sent a different county.

  OUT-OF-STATE ENTRANTS -- "may not count contacts with non-Georgia or DX
    stations": the party base's host-area rule (Q107, HostAreaRuleCredits),
    refused when typed and 0 points / no multiplier when logged any other
    way. Nothing here.

  MULTIPLIERS -- "Each multiplier may be counted once per mode. (Not per
    band)": cfMultByMode, not cfMultByBand.
      Georgia stations   georgia.dom: the 50 states including Georgia, DC
                         and the 13 Canadian provinces (51 + 13). The 159
                         counties count as Ga (georgia_cty.dom maps each to
                         Ga). "DX counts for QSO points only, there are no
                         country multipliers": no DX multiplier.
      Non-Georgia        georgia_cty.dom: the 159 counties, each its own
                         multiplier (FCONTEST sets MultipliersIsCounties).

  SCORE -- "Multiply total QSO points by total multipliers": the base's
    CombineWithMultipliers. No power multiplier, no bonus.

  COUNTY LINES -- "KU8E/HARR/MUSC if operating from the Harris/Muscogee
    county line", logged "as two separate contacts": two counties,
    GetCountyLineCountiesMax = 2. The rover strip and its ADIF split are the
    base's, as for every QSO party.

  CABRILLO -- CONTEST: GA-QSO-PARTY. The rules' example line,
    "QSO: 14000 CW 2016-04-09 1805 KU8E 599 HARR AA3B 599 PA": RST and the
    sent county or state, RST and the received QTH. LOCATION: appears in the
    rules' example header but is not required, so it is not demanded. ADIF --
    CONTEST_ID GA-QSO-PARTY (ADIF's own enumeration). *)
unit uContestGeorgiaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   (* ITS ID -- stored data; see the header. *)
   GA_QSO_PARTY_CONTEST_ID = 'GA-QSO-PARTY';

type
   TContestGeorgiaQP = class(TContestStateQSOPartyBase)
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

      (* SSB 1, CW 2 -- see the header. Protected, as on TContestBase:
         ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* 160, 80, 40, 20, 15, 10 and 6 m -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* CW and phone (FM is phone); no digital -- the header. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* ' 5NN ' and the county, state or province this station sends; DX
         when it sends none. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;

      (* THE MULTIPLIERS -- counties or states and provinces from the
         domestic file (the party base's UsesDomesticFile); no DX, zone or
         prefix multiplier for any entrant. *)
      function HasDXMultiplier: boolean; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;

      (* WHAT THE EXCHANGE CARRIES -- a domestic QTH (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

implementation

uses
   SysUtils,
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry;

function TContestGeorgiaQP.GetDisplayName: string;
begin
   Result := 'Georgia QSO Party';
end;

function TContestGeorgiaQP.GetHostState: string;
begin
   Result := 'GA';
end;

function TContestGeorgiaQP.GetCabrilloName: string;
begin
   (* The rules' CABRILLO FILE SPECIFICATION: CONTEST: GA-QSO-PARTY. *)
   Result := 'GA-QSO-PARTY';
end;

function TContestGeorgiaQP.GetADIFContestId: string;
begin
   (* The rules' "ADIF Name: GA-QSO-PARTY"; export writes it, import
      matches it. *)
   Result := GA_QSO_PARTY_CONTEST_ID;
end;

function TContestGeorgiaQP.GetWA7BNMId: integer;
begin
   Result := 328;
end;

function TContestGeorgiaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestGeorgiaQP.GetSubmissionEmail: string;
begin
   (* Logs go through the sponsor's submission page. The rules name
      gqplogs@gaqsoparty.com only for an entrant whose upload FAILED, so it is
      not the submission route -- '' as URC does for the same case. *)
   Result := '';
end;

function TContestGeorgiaQP.GetDomesticFileName: string;
begin
   (* The county file. FCONTEST.FoundMyStateInDomFile reads it to decide
      whether MY STATE is a Georgia county, and then loads georgia.dom or
      this file. *)
   Result := 'georgia_cty';
end;

function TContestGeorgiaQP.GetFriendlyName: string;
begin
   Result := 'Georgia QSO Party';
end;

function TContestGeorgiaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestGeorgiaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestGeorgiaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestGeorgiaQP.ParseReceivedExchangeFormat(const aText: string;
                                                       aParsers: TExchangeParsers;
                                                       var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestGeorgiaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestGeorgiaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                               const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(aMy, aQso);
end;

function TContestGeorgiaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   const aCtx: TCabrilloQSOContext): string;
begin
   (* A DX entrant sends "DX" -- the header. *)
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestGeorgiaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   (* A DX station's column is "DX", what it sent. *)
   Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
end;

function TContestGeorgiaQP.GetInStateDomesticFileName: string;
begin
   Result := 'georgia';
end;

function TContestGeorgiaQP.GetFlags: TContestFlags;
begin
   (* Dupes per band and per mode; multipliers ONCE PER MODE, not per band;
      6 m is credited. *)
   Result := [cfQSOByBand, cfQSOByMode, cfMultByMode, cfVHFBandsEnabled];
end;

function TContestGeorgiaQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

(* SSB 1, CW 2. FM is phone. A digital QSO never reaches here (UsesMode),
   nor an off-band one (UsesBand), nor a station an out-of-state entrant may
   not credit (CreditsWorkedStation). Both and NoMode are not modes a contact
   is made in. *)
procedure TContestGeorgiaQP.CalculateQSOPoints(var aQso: ContestExchange);
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

function TContestGeorgiaQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10, Band6];
end;

(* "Digital contacts aren't allowed"; "SSB -- Phone only contacts", so FM is
   phone. Any submode of CW, Phone or FM is credited -- eNoMode and eData
   included, as the contract asks -- and no submode of Digital is. An
   identity fact: no station is asked. *)
function TContestGeorgiaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM];
end;

function TContestGeorgiaQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is the state the session SENDS (design 7.11/7.12): a
      Georgia station's county, anyone else's state or province. *)
   if Trim(aStation.MyState) = '' then
      begin
      Result := ' 5NN DX';
      end
   else
      begin
      Result := ' 5NN ' + aStation.MyState;
      end;
end;

function TContestGeorgiaQP.HasDXMultiplier: boolean;
begin
   Result := False;
end;

function TContestGeorgiaQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestGeorgiaQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

initialization
   RegisterContestById(GA_QSO_PARTY_CONTEST_ID, TContestGeorgiaQP);

end.
