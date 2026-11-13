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

(* NEW JERSEY QSO PARTY -- #124, 2026 rules rev0.5.
  Sources and transcribed tables: docs/ContestRules/QSOParties/NewJersey/.
  Modelled on Georgia's class, directly on the state-party mechanism base.
  A new stored id: no legacy enum or CFG.

  80/40/20/15/10 m; CW/digital 2 points, phone (FM included) 1.
  The sponsor FAQ explicitly excludes FT8; other digital QSOs must carry
  the full RST/location exchange. UsesMode excludes FT8, without inventing
  restrictions on other submodes. Off-band/off-mode contacts are X-QSOs.
  Dupes per band/mode/received location; no simultaneous county operation.
  Multipliers ONCE OVERALL: outside NJ, its 21 counties; inside NJ, those
  counties plus 49 other states, 13 provinces and ONE DX (84 maximum).
  Every QTH, including DX, goes through the domestic parser and table.
  DX sends DX; NF is the sponsor's Newfoundland code, ADIF STATE is NL.
  Final score: QSO points x multipliers x stated CATEGORY-POWER factor:
  HIGH 1, LOW 2, QRP 4. PowerCategories.png gives the wattage thresholds;
  the class uses the operator's stated category, as Florida does. No bonus.
  County/state/province entries copied from the sponsor table, DC absent.
  NY4I on #124, 2026-11-13: "You will never receive DC"; the rules' maximum
  is 84 multipliers. DC is therefore neither a received entry nor an alias
  for Maryland. The class follows that table without adding an 85th key.
  Cabrillo name confirmed separately on the sponsor's Cabrillo page;
  ADIF Contest_ID confirmed in ADIF 3.1.7. The sponsor's generic Cabrillo
  example uses grids from another event; fixtures use NJ's own exchange.
  Entrant mobile county reworks remain the existing engine gap #133;
  received rover counties are supported by the party base.
  3830 form fetch was refused by Cloudflare; use the base Mults column
  pending manual confirmation (BENCH_QUEUE).
*)
unit uContestNewJerseyQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   NJ_QSO_PARTY_CONTEST_ID = 'NJ-QSO-PARTY';

type
   TContestNewJerseyQP = class(TContestStateQSOPartyBase)
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
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      function CQExchangeDefault(const aStation: TStationContext): string; override;
      function HasDXMultiplier: boolean; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;
      function ExchangeCarriesDomesticQTH: boolean; override;
      function ADIFCountyState(const aQso: ContestExchange): string; override;
   end;

implementation

uses
   SysUtils, uSettingsModel, uExchangeFields, uCabrilloExchange,
   uADIFExchange, uADIF, uContestRegistry;

function TContestNewJerseyQP.GetDisplayName: string;
begin
   Result := 'New Jersey QSO Party';
end;

function TContestNewJerseyQP.GetFriendlyName: string;
begin
   Result := 'New Jersey QSO Party';
end;

function TContestNewJerseyQP.GetHostState: string;
begin
   Result := 'NJ';
end;

function TContestNewJerseyQP.GetCabrilloName: string;
begin
   Result := 'NJ-QSO-PARTY';
end;

function TContestNewJerseyQP.GetADIFContestId: string;
begin
   Result := NJ_QSO_PARTY_CONTEST_ID;
end;

function TContestNewJerseyQP.GetWA7BNMId: integer;
begin
   Result := 92;
end;

function TContestNewJerseyQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNewJerseyQP.GetSubmissionEmail: string;
begin
   Result := 'NewJerseyQSOParty@gmail.com';
end;

function TContestNewJerseyQP.GetDomesticFileName: string;
begin
   Result := 'newjersey_cty';
end;

function TContestNewJerseyQP.GetInStateDomesticFileName: string;
begin
   Result := 'newjersey';
end;

function TContestNewJerseyQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestNewJerseyQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestNewJerseyQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestNewJerseyQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode];
end;

function TContestNewJerseyQP.GetCountyLineCountiesMax: integer;
begin
   Result := 0;
end;

function TContestNewJerseyQP.ParseReceivedExchangeFormat(const aText: string;
   aParsers: TExchangeParsers; var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTH(aText, aExch);
end;

function TContestNewJerseyQP.GetADIFSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestNewJerseyQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestNewJerseyQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
end;

procedure TContestNewJerseyQP.CalculateQSOPoints(var aQso: ContestExchange);
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

function TContestNewJerseyQP.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
var
   factor: integer;
begin
   case Station.MyPower of
      cpLOW:
         begin
         factor := 2;
         end;
      cpQRP:
         begin
         factor := 4;
         end;
      else
         begin
         factor := 1;
         end;
      end;
   Result := inherited CombineWithMultipliers(aTotals) * factor;
end;

function TContestNewJerseyQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band80, Band40, Band20, Band15, Band10];
end;

function TContestNewJerseyQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := (aMode in [CW, Phone, FM, Digital]) and
      ((aMode <> Digital) or (aExtMode <> eFT8));
end;

function TContestNewJerseyQP.CQExchangeDefault(const aStation: TStationContext): string;
var
   my: TMyStationExchange;
begin
   my := Default(TMyStationExchange);
   my.MyState := aStation.MyState;
   Result := ' 5NN ' + SentStateOrDX(my);
end;

function TContestNewJerseyQP.HasDXMultiplier: boolean;
begin
   Result := False;
end;

function TContestNewJerseyQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestNewJerseyQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

function TContestNewJerseyQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestNewJerseyQP.ADIFCountyState(const aQso: ContestExchange): string;
begin
   if UpperCase(ADIFPartyQTHKey(aQso)) = 'NF' then
      begin
      Result := 'NL';
      end
   else
      begin
      Result := inherited ADIFCountyState(aQso);
      end;
end;

initialization
   RegisterContestById(NJ_QSO_PARTY_CONTEST_ID, TContestNewJerseyQP);

end.
