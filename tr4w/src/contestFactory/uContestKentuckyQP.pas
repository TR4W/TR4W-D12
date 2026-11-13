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

(* KENTUCKY QSO PARTY -- #110, 2027 DRAFT approved by NY4I.
  Sources and decisions: docs/ContestRules/QSOParties/Kentucky/.
  NY4I comment 6857618922: use the draft; update after finalization.
  80/40/20/15/10/6/2 m, CW 2 points, phone/FM 1, no digital or repeaters.
  Received RST plus county/state/province/DX; outside entrants work KY only.
  Dupes per band/mode/received county. Multipliers once OVERALL. DX earns
  points but no multiplier. DC is its own state multiplier, not Maryland.
  KY stations must send county, not KY. NY4I comment 6862605577 confirms
  an in-state county QSO also earns KY state. NOT BUILT: that second domestic
  key belongs to specialist engine work #317, including domestic totals and
  needs displays. Do not introduce another prefix-sheet implementation.
  Current in-state keys: 120 counties + 49 other states + DC + 13 provinces;
  the extra KY state will make 184 after #317, not the current 183.
  Power factors from stated CATEGORY-POWER: HIGH 1, LOW 2, QRP 3.
  K4KCG earns 100 per band/mode, after multiplication, valid QSOs only.
  County suffixes verified by the shared party matcher also pay. Committee
  recalculation must not be interpreted as an additional second bonus.
  Online-submission 100 requires a success fact not present in this log;
  it remains an adjudication adjustment. No submission email.
  Received mobile/expedition county-line QSOs produce separate records.
  No numeric county maximum is stated; fixed sending stations choose one.
  Own-mobile reworks and sent category/county enforcement depend on #133/#87.
  Cabrillo from DXLog KYQP.txt, independently ADIF 3.1.7; WA7BNM 371.
  Screen/3830 comparison remains bench work.
*)
unit uContestKentuckyQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   KY_QSO_PARTY_CONTEST_ID = 'KY-QSO-PARTY';

type
   TContestKentuckyQP = class(TContestStateQSOPartyBase)
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
   SysUtils, uSettingsModel, uExchangeFields, uCabrilloExchange,
   uADIFExchange, uADIF, uContestRegistry;

function TContestKentuckyQP.GetDisplayName: string;
begin
   Result := 'Kentucky QSO Party';
end;

function TContestKentuckyQP.GetFriendlyName: string;
begin
   Result := 'Kentucky QSO Party';
end;

function TContestKentuckyQP.GetHostState: string;
begin
   Result := 'KY';
end;

function TContestKentuckyQP.GetCabrilloName: string;
begin
   Result := 'KY-QSO-PARTY';
end;

function TContestKentuckyQP.GetADIFContestId: string;
begin
   Result := KY_QSO_PARTY_CONTEST_ID;
end;

function TContestKentuckyQP.GetWA7BNMId: integer;
begin
   Result := 371;
end;

function TContestKentuckyQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestKentuckyQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestKentuckyQP.GetDomesticFileName: string;
begin
   Result := 'kentucky_cty';
end;

function TContestKentuckyQP.GetInStateDomesticFileName: string;
begin
   Result := 'kentucky';
end;

function TContestKentuckyQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestKentuckyQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestKentuckyQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestKentuckyQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

function TContestKentuckyQP.GetCountyLineCountiesMax: integer;
begin
   Result := CountyLineCountiesUnlimited;
end;

function TContestKentuckyQP.ParseReceivedExchangeFormat(const aText: string;
   aParsers: TExchangeParsers; var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestKentuckyQP.GetADIFSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestKentuckyQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestKentuckyQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
end;

procedure TContestKentuckyQP.CalculateQSOPoints(var aQso: ContestExchange);
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

function TContestKentuckyQP.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
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
         factor := 3;
         end;
      else
         begin
         factor := 1;
         end;
      end;
   Result := inherited CombineWithMultipliers(aTotals) * factor;
end;

function TContestKentuckyQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band80, Band40, Band20, Band15, Band10, Band6, Band2];
end;

function TContestKentuckyQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM];
end;

function TContestKentuckyQP.CQExchangeDefault(const aStation: TStationContext): string;
var
   my: TMyStationExchange;
begin
   my := Default(TMyStationExchange);
   my.MyState := aStation.MyState;
   Result := ' 5NN ' + SentStateOrDX(my);
end;

function TContestKentuckyQP.HasDXMultiplier: boolean;
begin
   Result := False;
end;

function TContestKentuckyQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestKentuckyQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

function TContestKentuckyQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestKentuckyQP.GetBonusStations: TBonusStationList;
begin
   Result := nil;
   SetLength(Result, 1);
   Result[0].Call := 'K4KCG';
   Result[0].Points := 100;
   Result[0].Scope := bsOncePerBandAndMode;
end;

function TContestKentuckyQP.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   Result := IsCreditedContact(aQso);
end;

initialization
   RegisterContestById(KY_QSO_PARTY_CONTEST_ID, TContestKentuckyQP);

end.
