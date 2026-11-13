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

(* WEST VIRGINIA QSO PARTY -- #131, sponsor 2026 rules and county PDF.
  Sources: docs/ContestRules/QSOParties/WestVirginia/.
  80/40/20/15/10 m; phone (FM included) one point, CW and digital two.
  All non-CW digital submodes share a contact group. RST plus county for WV;
  others send state/province/DXCC prefix. Dupes per band/mode/received county.
  Two-county contacts produce separate records through the existing queue.

  Multipliers once OVERALL: counties (55); WV entrants also count 50 states
  (WV counts separately beside its county, DC as Maryland), 13 provinces
  and ARRL DXCC entities except USA/Canada/Hawaii/Alaska. NY4I #131,
  comment 6857387343: once per contest, no repetition by mode, resolving
  the sponsor's conflicting provinces-per-band wording. The additional WV
  state key uses the existing string sheet and CountyStateMultiplierKey,
  also used by Alabama. This class finalizes it after inherited parsing;
  rescore calls the same PrefixMultiplierKey policy. Shared entry unchanged.

  W8WVA earns 100 once per band/mode, after multiplying; dupes and X-QSOs
  excluded. The existing bonus helper matches the logged call exactly:
  a county-suffixed W8WVA call is not paid (shared gap #111, also recorded
  by New Mexico). Fix that in the shared bonus-call matcher, not by copying
  a bonus scanner into each new party. No power factor.
  Entrant-mobile reworks, own county-line sending
  and the mobile activated-county bonus remain engine gaps #133/#87;
  received rover county reworks and county-line records are supported.

  Cabrillo WV-QSO-PARTY: DXLog WVQP.txt CABRILLO_CONTEST_NAME, as directed
  by NY4I. ADIF WV-QSO-PARTY; WA7BNM 49. Rules do not specify Cabrillo layout;
  report/location helpers state the full exchange. 3830 form needs bench QA.
*)
unit uContestWestVirginiaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   WV_QSO_PARTY_CONTEST_ID = 'WV-QSO-PARTY';

type
   TContestWestVirginiaQP = class(TContestStateQSOPartyBase)
   private
      function CountsDXMultiplier: boolean;
   protected
      function GetTotalsDisplay: TTotalsDisplay; override;
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
      function GetBonusStations: TBonusStationList; override;
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
      function ParseReceivedExchange(const aText: string;
         const aSession: TReceivedExchangeSession; var aExch: ContestExchange;
         out aErrorMessage: string): boolean; override;
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      function CQExchangeDefault(const aStation: TStationContext): string; override;
      function HasDXMultiplier: boolean; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;
      function ExchangeCarriesDomesticQTH: boolean; override;
      function PrefixMultiplierKey(const aQso: ContestExchange;
         out aKey: PrefixMultiplierString): boolean; override;
      function DXMultiplierKey(const aQso: ContestExchange;
         out aKey: DXMultiplierString): boolean; override;
      function CountryMode: CountryModeType; override;
      function CountsTowardBonus(const aQso: ContestExchange): boolean; override;
   end;

implementation

uses
   SysUtils, uExchangeFields, uCabrilloExchange,
   uADIFExchange, uDXMultiplierKey, uContestRegistry;

function TContestWestVirginiaQP.GetDisplayName: string;
begin
   Result := 'West Virginia QSO Party';
end;

function TContestWestVirginiaQP.GetFriendlyName: string;
begin
   Result := 'West Virginia QSO Party';
end;

function TContestWestVirginiaQP.GetHostState: string;
begin
   Result := 'WV';
end;

function TContestWestVirginiaQP.GetCabrilloName: string;
begin
   Result := 'WV-QSO-PARTY';
end;

function TContestWestVirginiaQP.GetADIFContestId: string;
begin
   Result := WV_QSO_PARTY_CONTEST_ID;
end;

function TContestWestVirginiaQP.GetWA7BNMId: integer;
begin
   Result := 49;
end;

function TContestWestVirginiaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestWestVirginiaQP.GetSubmissionEmail: string;
begin
   Result := 'wvqplogs@gmail.com';
end;

function TContestWestVirginiaQP.GetDomesticFileName: string;
begin
   Result := 'westvirginia_cty';
end;

function TContestWestVirginiaQP.GetInStateDomesticFileName: string;
begin
   Result := 'westvirginia';
end;

function TContestWestVirginiaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestWestVirginiaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestWestVirginiaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestWestVirginiaQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode];
end;

function TContestWestVirginiaQP.GetBonusStations: TBonusStationList;
begin
   Result := nil;
   SetLength(Result, 1);
   Result[0].Call := 'W8WVA';
   Result[0].Points := 100;
   Result[0].Scope := bsOncePerBandAndMode;
end;

function TContestWestVirginiaQP.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   Result := IsCreditedContact(aQso);
end;

function TContestWestVirginiaQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

function TContestWestVirginiaQP.ParseReceivedExchangeFormat(const aText: string;
   aParsers: TExchangeParsers; var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestWestVirginiaQP.ParseReceivedExchange(const aText: string;
   const aSession: TReceivedExchangeSession; var aExch: ContestExchange;
   out aErrorMessage: string): boolean;
var
   key: PrefixMultiplierString;
begin
   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
   if Result and PrefixMultiplierKey(aExch, key) then
      begin
      aExch.Prefix := key;
      end;
end;

function TContestWestVirginiaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(SentLocation(aMy), aQso);
end;

function TContestWestVirginiaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTState(SentLocation(aMy), aQso, aCtx);
end;

function TContestWestVirginiaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHOrDXQTH(aMy, aQso, aCtx);
end;

procedure TContestWestVirginiaQP.CalculateQSOPoints(var aQso: ContestExchange);
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

function TContestWestVirginiaQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band80, Band40, Band20, Band15, Band10];
end;

function TContestWestVirginiaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM, Digital];
end;

function TContestWestVirginiaQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' 5NN ' + LocationOrOwnCountry(aStation.MyState, aStation.MyCountry);
end;

function TContestWestVirginiaQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

function TContestWestVirginiaQP.DXMultiplierKey(const aQso: ContestExchange;
   out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

function TContestWestVirginiaQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;

function TContestWestVirginiaQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

function TContestWestVirginiaQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestWestVirginiaQP.HasPrefixMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

function TContestWestVirginiaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestWestVirginiaQP.PrefixMultiplierKey(const aQso: ContestExchange;
   out aKey: PrefixMultiplierString): boolean;
begin
   aKey := '';
   Result := HasPrefixMultiplier;
   if Result then
      begin
      aKey := PrefixMultiplierString(CountyStateMultiplierKey(aQso));
      end;
end;

function TContestWestVirginiaQP.GetTotalsDisplay: TTotalsDisplay;
begin
   Result := inherited GetTotalsDisplay;
   if HasPrefixMultiplier then
      begin
      Result.PrefixMultsCaption := 'WV';
      Result.PrefixMultsCaptionCW := 'CW WV';
      Result.PrefixMultsCaptionPhone := 'Ph WV';
      end;
end;

initialization
   RegisterContestById(WV_QSO_PARTY_CONTEST_ID, TContestWestVirginiaQP);

end.
