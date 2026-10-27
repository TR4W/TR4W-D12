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

(* WISCONSIN QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'wisconsin_cty';  WA7BNM: 330;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 7;  AE: RSTDomesticQTHExchange;
   XM: NoDXMults;  QP: OnePhoneTwoCW;  ADIFName: 'WI-QSO-PARTY';
   CABName: 'WIQP';  CountyLineAllowed: True;
   FriendlyName: 'Wisconsin QSO Party'

  ---------------------------------------------------------------------------
  THE 2026 RULES, CHECKED AGAINST THE SPONSOR (#88, 2026-10-26). The texts are
  docs/ContestRules/QSOParties/Wisconsin/ (the rules, the Cabrillo page and
  the multiplier list).

  POINTS -- "Phone contacts count 1 point; CW and Digital contacts count 2
    points." FM is phone. Until #88 the legacy OnePhoneTwoCW arm scored
    digital the phone value, 1.

  MODES -- "CW, Phone and Digital (RTTY, PSK, Olivia, Feld-Hell). FT8/FT4
    QSO's are not accepted." UsesMode refuses FT8 and FT4 -- only the two the
    sponsor names (Missouri's "or similar" also refuses JT65; each states its
    own list) -- so such a QSO is an automatic X-QSO.

  BANDS -- "All amateur bands and modes not prohibited for contesting may be
    used." Read as every band but the WARC bands (30, 17 and 12 m), where
    contesting is prohibited by band-plan convention (60 m has no BandType).
    The VHF bands are credited, so cfVHFBandsEnabled is stated.

  COUNTY LINES -- "Mobiles or portables may not sit on a county line", and a
    fixed station has one location: GetCountyLineCountiesMax is 0, as
    Michigan's. A rover is still not a county line.

  W9FK -- "Add 100 points for each time you work W9FK on each band and mode
    below 50Mhz", added after multiplying: a declared bonus station paid
    once on each band in each mode (bsOncePerBandAndMode), by a contact that
    is neither a dupe nor an X-QSO and is below 6 m (CountsTowardBonus).

  CABRILLO -- "CONTEST: WI-QSO-PARTY", and the QSO columns are the location
    alone: "RST columns are not needed"; "The received exchange for QSO's with
    stations outside the U.S. states and Canadian provinces should show 'DX'."
    The Cabrillo name is write-only; the stored id (WISCONSIN QSO PARTY) and
    the ADIF id (WI-QSO-PARTY) do not move.

  NOT BUILT, listed on #88:
    * THE POWER MULTIPLIER (QRP x2, LOW x1.5): NY4I has not ruled how a
      fractional score rounds.
    * THE MOBILE/PORTABLE 500-POINT COUNTY BONUS: it needs the entrant's
      CATEGORY-STATION and home county, which do not reach scoring.
    * A WISCONSIN ENTRANT'S DX QSO: "DX countries worked count for QSO points
      but not as multipliers", but the exchange is domestic-only
      (RSTDomesticQTH) and wisconsin.dom has no DX entry, so a typed "599 DX"
      is refused as an improper QTH. A DX QSO that is logged (import, peer)
      scores its points and no multiplier. Reported, not changed.
 *)
unit uContestWisconsinQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestWisconsinQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'WI' -- but the base makes it abstract
         for state parties precisely so that answer is never an accident. *)
      function GetHostState: string; override;

      (* THE WHOLE ContestsArray ROW, STATED HERE.

         NY4I, 2026-09-29: "all the info in [the row] should go into the contest
         class." Every getter below returns what the array holds today, so this
         changes no behaviour -- it moves the ANSWER, so that reading this one
         file tells you what the contest is without cross-referencing a 185-row
         table by enum position.

         THE ROW IS NOT DELETED AND MUST NOT BE. It still answers for every
         contest that has no class, and for every accessor a class does not
         override. *)
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
      procedure WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters); override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;

      (* STATED AT M10 S5, transcribed from the rows the base read until
         then (ContestsArray, QSOParties, ContestsBooleanArray). The
         flags: see TContestBase.GetFlags. *)
      function GetInStateDomesticFileName: string; override;
      function GetFlags: TContestFlags; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* No county line -- the header. *)
      function GetCountyLineCountiesMax: integer; override;

      (* W9FK, 100 once on each band in each mode below 50 MHz -- the header. *)
      function GetBonusStations: TBonusStationList; override;

      (* A W9FK contact pays only if it is neither a dupe nor an X-QSO and is
         below 50 MHz -- the header. *)
      function CountsTowardBonus(const aQso: ContestExchange): boolean; override;
   public
      (* Every band but WARC -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* CW, phone (FM is phone) and digital but FT8 and FT4 -- the header. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
      (* SEVERAL QTHs FROM ONE ENTRY -- see TContestBase.LogsSeveralQTHsFromOneEntry (M11 S7). *)
      function LogsSeveralQTHsFromOneEntry: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry;

function TContestWisconsinQP.GetDisplayName: string;
begin
   Result := 'Wisconsin QSO Party';
end;

function TContestWisconsinQP.GetHostState: string;
begin
   Result := 'WI';
end;

function TContestWisconsinQP.GetCabrilloName: string;
begin
   (* The sponsor's Cabrillo page: "CONTEST: WI-QSO-PARTY" (#88). TR4W wrote
      'WIQP' until then. Write-only, so the old name needs no read alias. *)
   Result := 'WI-QSO-PARTY';
end;

function TContestWisconsinQP.GetADIFContestId: string;
begin
   Result := 'WI-QSO-PARTY';
end;

function TContestWisconsinQP.GetWA7BNMId: integer;
begin
   Result := 330;
end;

function TContestWisconsinQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestWisconsinQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestWisconsinQP.GetDomesticFileName: string;
begin
   Result := 'wisconsin_cty';
end;

function TContestWisconsinQP.GetFriendlyName: string;
begin
   Result := 'Wisconsin QSO Party';
end;

function TContestWisconsinQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestWisconsinQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestWisconsinQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestWisconsinQP.ParseReceivedExchangeFormat(const aText: string;
                                                         aParsers: TExchangeParsers;
                                                         var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTH(aText, aExch);
end;

procedure TContestWisconsinQP.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTStateOrQSONumber;
end;

function TContestWisconsinQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestWisconsinQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestWisconsinQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
begin
   (* The location alone -- "RST columns are not needed". *)
   Result := CabrilloSentStateOrDX(aMy, aQso, aCtx);
end;

function TContestWisconsinQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                         const aQso: ContestExchange;
                                                         const aCtx: TCabrilloQSOContext): string;
begin
   (* The location alone, 'DX' for a station outside the US and Canada. *)
   Result := CabrilloReceivedQTHDX(aMy, aQso, aCtx);
end;

function TContestWisconsinQP.GetInStateDomesticFileName: string;
begin
   Result := 'wisconsin';
end;

function TContestWisconsinQP.GetFlags: TContestFlags;
begin
   (* The VHF bands are credited -- the header. *)
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

(* CW 2, DIGITAL 2, PHONE 1 -- the header. FM is phone. A QSO off the bands
   or modes never reaches here (UsesBand, UsesMode), nor one an out-of-state
   entrant may not credit (CreditsWorkedStation). Both and NoMode are not
   modes a contact is made in. *)
procedure TContestWisconsinQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW, Digital:
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

function TContestWisconsinQP.GetCountyLineCountiesMax: integer;
begin
   (* "Mobiles or portables may not sit on a county line." Zero, so the
      derived CountyLineAllowed reads False, as Michigan's. *)
   Result := 0;
end;

function TContestWisconsinQP.GetBonusStations: TBonusStationList;
begin
   Result := nil;
   SetLength(Result, 1);
   Result[0].Call := 'W9FK';
   Result[0].Points := 100;
   Result[0].Scope := bsOncePerBandAndMode;
end;

(* "on each band and mode below 50Mhz": a credited contact (not a dupe, not
   an X-QSO) on 160-10 m. *)
function TContestWisconsinQP.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   Result := IsCreditedContact(aQso) and
             (aQso.Band in [Band160, Band80, Band40, Band20, Band15, Band10]);
end;

(* "All amateur bands and modes not prohibited for contesting may be used":
   every band but the WARC bands, where contesting is prohibited by band-plan
   convention. *)
function TContestWisconsinQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10,
                       Band6, Band2, Band222, Band432, Band902, Band1296,
                       Band2304, Band3456, Band5760, Band10G, Band24G,
                       BandLight];
end;

(* "FT8/FT4 QSO's are not accepted." The submode is tested only to EXCLUDE
   the two named: eNoMode and eData mean "some digital submode" and are
   credited, as the contract asks (ADDING_A_CONTEST, UsesMode). An identity
   fact: no station is asked. *)
function TContestWisconsinQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   case aMode of
      CW, Phone, FM:
         begin
         Result := True;
         end;
      Digital:
         begin
         Result := not (aExtMode in [eFT8, eFT4]);
         end;
      else
         begin
         Result := False;
         end;
      end;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestWisconsinQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' ' + aStation.MyState;
end;

(* ONE SEARCH-AND-POUNCE ENTRY MAY CARRY SEVERAL QTHs, at every station --
   M11 S7, 2026-10-14. It was the session's RSTDomesticQTH shape; see
   TContestBase.LogsSeveralQTHsFromOneEntry. *)
function TContestWisconsinQP.LogsSeveralQTHsFromOneEntry: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(WISCONSINQSOPARTY, TContestWisconsinQP);

end.
