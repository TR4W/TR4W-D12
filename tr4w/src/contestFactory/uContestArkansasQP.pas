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

(* ARKANSAS QSO PARTY -- #115, current sponsor rules fetched 2026-11-13.
  Sources/transcription: docs/ContestRules/QSOParties/Arkansas/.
  160/80/40/20/15/10/6/2 m; CW/phone/digital with full report/location.
  Fixed entrants earn one point in every mode. Dupes per band/mode/county;
  digital submodes share a group, FM is phone. No repeater contacts.
  Multipliers overall: outside AR, 75 counties; inside, 75 counties plus
  49 other states (NOT AR), 13 provinces and ONE DX, maximum 138. DC sends
  MD. No separate host-state credit or #317 dependency. Counties first in
  DOM; no ambiguous state/province long aliases. DX is a domestic-table key.
  WR5P earns 200 for EACH valid QSO, after multiplying. The common bonus
  mechanism counts credited contacts and removes verified county suffixes;
  different rover counties on one band/mode may each earn this bonus.
  Received county-line QSOs use separate records. The rules limit the
  physical radius, not a number of counties; no invented numeric cap.
  NOT BUILT: category-dependent mobile/portable/rover two-point QSOs,
  own-county reworks and county-activation bonus (#133/#87). The existing
  station context does not carry that category; do not read UI globals here.
  Live-stream 500-point bonus requires proof/eligibility outside this log.
  No power factor. Online-only submission; no submission email.
  Cabrillo from DXLog ARQP.txt, independently ADIF 3.1.7; WA7BNM 132.
  Screen/3830 comparison remains bench work.
*)
unit uContestArkansasQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   AR_QSO_PARTY_CONTEST_ID = 'AR-QSO-PARTY';

type
   TContestArkansasQP = class(TContestStateQSOPartyBase)
   protected
      function GetDisplayName: string; override;
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
   end;

implementation

uses
   SysUtils, uExchangeFields, uCabrilloExchange,
   uADIFExchange, uADIF, uContestRegistry;

function TContestArkansasQP.GetDisplayName: string;
begin
   Result := 'Arkansas QSO Party';
end;

function TContestArkansasQP.GetFriendlyName: string;
begin
   Result := 'Arkansas QSO Party';
end;

function TContestArkansasQP.GetHostState: string;
begin
   Result := 'AR';
end;

function TContestArkansasQP.GetCabrilloName: string;
begin
   Result := 'AR-QSO-PARTY';
end;

function TContestArkansasQP.GetADIFContestId: string;
begin
   Result := AR_QSO_PARTY_CONTEST_ID;
end;

function TContestArkansasQP.GetWA7BNMId: integer;
begin
   Result := 132;
end;

function TContestArkansasQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestArkansasQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestArkansasQP.GetDomesticFileName: string;
begin
   Result := 'arkansas_cty';
end;

function TContestArkansasQP.GetInStateDomesticFileName: string;
begin
   Result := 'arkansas';
end;

function TContestArkansasQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestArkansasQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestArkansasQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestArkansasQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

function TContestArkansasQP.GetCountyLineCountiesMax: integer;
begin
   Result := CountyLineCountiesUnlimited;
end;

function TContestArkansasQP.ParseReceivedExchangeFormat(const aText: string;
   aParsers: TExchangeParsers; var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTH(aText, aExch);
end;

function TContestArkansasQP.GetADIFSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestArkansasQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestArkansasQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
end;

procedure TContestArkansasQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.Mode in [CW, Phone, FM, Digital] then
      begin
      aQso.QSOPoints := 1;
      end
   else
      begin
      aQso.QSOPoints := 0;
      end;
end;

function TContestArkansasQP.GetBonusStations: TBonusStationList;
begin
   Result := nil;
   SetLength(Result, 1);
   Result[0].Call := 'WR5P';
   Result[0].Points := 200;
   Result[0].Scope := bsPerQSO;
end;

function TContestArkansasQP.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   Result := IsCreditedContact(aQso);
end;

function TContestArkansasQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2];
end;

function TContestArkansasQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM, Digital];
end;

function TContestArkansasQP.CQExchangeDefault(const aStation: TStationContext): string;
var
   my: TMyStationExchange;
begin
   my := Default(TMyStationExchange);
   my.MyState := aStation.MyState;
   Result := ' 5NN ' + SentStateOrDX(my);
end;

function TContestArkansasQP.HasDXMultiplier: boolean;
begin
   Result := False;
end;

function TContestArkansasQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestArkansasQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

function TContestArkansasQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

initialization
   RegisterContestById(AR_QSO_PARTY_CONTEST_ID, TContestArkansasQP);

end.
