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

(* ALABAMA QSO PARTY -- #114, sponsor's 2026 rules.
  Sources and county table: docs/ContestRules/QSOParties/Alabama/.
  80/40/20/15/10 m, CW and phone (FM included), two points per QSO.
  RST and county/state/province/country prefix; DX sends its own prefix.
  Dupes per band/mode/received county; county-line sitting forbidden.
  Multipliers once PER MODE: outside AL, its 67 counties; inside AL,
  the counties, 50 states (DC is Maryland), 13 provinces, and DXCC entities
  except USA/Canada/Hawaii/Alaska. No power factor or bonus.

  NY4I on #114, 2026-11-13: "AL would get credit for working that AL
  station." A county earns BOTH its county and the AL state multiplier.
  The counties and 49 other states use the domestic sheet; the additional
  AL key uses the existing arbitrary string-key sheet (PrefixMultiplierKey,
  as CW Open uses it for callsigns). Its totals row is labelled AL. This
  keeps both keys independently scoped per mode, with no new stored fields,
  lookup table or contest-name test in shared code. This class finalizes the
  string key after its inherited parser has validated the county.
  AL is absent from the received table because the rules forbid sending AL
  instead of the county. The table's only keys longer than two letters are
  counties, so a resolved county earns the extra state credit. The same
  predicate works for an imported county or a received rover suffix.
  DXCC and prefix keys are still subject to the engine's ordinary dupe and
  X-QSO exclusion and are rebuilt on rescore, just like every multiplier.

  Cabrillo AL-QSO-PARTY verified at WA7BNM ref 134; ADIF independently
  verified in ADIF 3.1.7. No sponsor Cabrillo example: tests pin required
  report/location columns. Entrant mobile reworks remain gap #133; received
  rover county changes are supported. 3830 layout needs a manual check.
*)
unit uContestAlabamaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   AL_QSO_PARTY_CONTEST_ID = 'AL-QSO-PARTY';

type
   TContestAlabamaQP = class(TContestStateQSOPartyBase)
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
   end;

implementation

uses
   SysUtils, uExchangeFields, uCabrilloExchange,
   uADIFExchange, uDXMultiplierKey, uContestRegistry;

function TContestAlabamaQP.GetDisplayName: string;
begin
   Result := 'Alabama QSO Party';
end;

function TContestAlabamaQP.GetFriendlyName: string;
begin
   Result := 'Alabama QSO Party';
end;

function TContestAlabamaQP.GetHostState: string;
begin
   Result := 'AL';
end;

function TContestAlabamaQP.GetCabrilloName: string;
begin
   Result := 'AL-QSO-PARTY';
end;

function TContestAlabamaQP.GetADIFContestId: string;
begin
   Result := AL_QSO_PARTY_CONTEST_ID;
end;

function TContestAlabamaQP.GetWA7BNMId: integer;
begin
   Result := 134;
end;

function TContestAlabamaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestAlabamaQP.GetSubmissionEmail: string;
begin
   Result := 'logs@alabamaqsoparty.org';
end;

function TContestAlabamaQP.GetDomesticFileName: string;
begin
   Result := 'alabama_cty';
end;

function TContestAlabamaQP.GetInStateDomesticFileName: string;
begin
   Result := 'alabama';
end;

function TContestAlabamaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestAlabamaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestAlabamaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestAlabamaQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByMode];
end;

function TContestAlabamaQP.GetCountyLineCountiesMax: integer;
begin
   Result := 0;
end;

function TContestAlabamaQP.ParseReceivedExchangeFormat(const aText: string;
   aParsers: TExchangeParsers; var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestAlabamaQP.ParseReceivedExchange(const aText: string;
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

function TContestAlabamaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(SentLocation(aMy), aQso);
end;

function TContestAlabamaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTState(SentLocation(aMy), aQso, aCtx);
end;

function TContestAlabamaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHOrDXQTH(aMy, aQso, aCtx);
end;

procedure TContestAlabamaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW, Phone, FM:
         begin
         aQso.QSOPoints := 2;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestAlabamaQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band80, Band40, Band20, Band15, Band10];
end;

function TContestAlabamaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM];
end;

function TContestAlabamaQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' 5NN ' + LocationOrOwnCountry(aStation.MyState, aStation.MyCountry);
end;

function TContestAlabamaQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

function TContestAlabamaQP.DXMultiplierKey(const aQso: ContestExchange;
   out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

function TContestAlabamaQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;

function TContestAlabamaQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

function TContestAlabamaQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestAlabamaQP.HasPrefixMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

function TContestAlabamaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestAlabamaQP.PrefixMultiplierKey(const aQso: ContestExchange;
   out aKey: PrefixMultiplierString): boolean;
var
   county: string;
begin
   aKey := '';
   Result := HasPrefixMultiplier;
   if not Result then
      begin
      Exit;
      end;
   county := UpperCase(Trim(string(aQso.DomesticQTH)));
   if county = '' then
      begin
      county := UpperCase(Trim(string(aQso.QTHString)));
      end;
   (* The engine accepts XXX as unknown QTH, with no multiplier key. *)
   if (Length(county) > 2) and (county <> 'XXX') and
      Assigned(Station.IsDomesticQTH) and
      Station.IsDomesticQTH(county) then
      begin
      aKey := 'AL';
      end;
end;

function TContestAlabamaQP.GetTotalsDisplay: TTotalsDisplay;
begin
   Result := inherited GetTotalsDisplay;
   if HasPrefixMultiplier then
      begin
      Result.PrefixMultsCaption := 'AL';
      Result.PrefixMultsCaptionCW := 'CW AL';
      Result.PrefixMultsCaptionPhone := 'Ph AL';
      end;
end;

initialization
   RegisterContestById(AL_QSO_PARTY_CONTEST_ID, TContestAlabamaQP);

end.
