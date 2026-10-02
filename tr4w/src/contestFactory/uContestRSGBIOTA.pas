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

(* THE RSGB ISLANDS ON THE AIR CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 75;  QRZRUID: 29;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: IOTADomestic;  P: 0;  AE: RSTQSONumberAndPossibleDomesticQTHExchange;
   XM: NoDXMults;  QP: IOTAQSOPointMethod;  ADIFName: '';
   CABName: '';  FriendlyName: 'RSGB IOTA Contest'

  Blank ADIFName and CABName are the enum's spelling, 'RSGB-IOTA'.

  WHY IT HAS A CLASS NOW. M4 (2026-10-01) made every contest format its own
  export, and this contest's rule was a `Contest = IOTA` test inside a shared
  exporter -- which the base may never contain. A class to hold that rule
  needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record
  but `contest.class` is unchanged, which is the proof. EXCHANGE PARSING
  (M5b) and set-up (M7a) have moved since.

  SCORING IS IOTAQSOPointMethod. A station that states no MY STATE (no
  island): 15 for an island QSO, 2 otherwise. An island station: 15 for a
  DIFFERENT island, 5 for its own island or a non-island station. The arm
  computes the island station's answer twice -- once only when MY STATE holds
  a '-', then again unconditionally -- and the second always wins; the first
  gives the same answer wherever it applies, so the rule is stated once here.
  DomesticQTH is the worked island, the corrected reference (AF1 -> AF-001).

  TWO EXPORT RULES WERE `Contest = IOTA` TESTS. Cabrillo: a QSO with no
  island gets '------' in the received QTH column (this class sets it; the
  shared RSTQSONumberAndPossibleDomesticQTHExchange arm lays out the line).
  ADIF: the worked island goes to the IOTA tag. Import does not read IOTA
  back yet (uADIF has the tag name and no arm) -- M5's. *)
unit uContestRSGBIOTA;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRSGBIOTA = class(TContestBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the properties,
         descendants override the getters. Every getter below states
         the ContestsArray row quoted above. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetWA7BNMId: integer; override;
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetFriendlyName: string; override;
      function GetPrefixMultiplierType: PrefixMultType; override;
      function GetZoneMultiplierType: ZoneMultType; override;
      function GetDXMultiplierType: DXMultType; override;
      function GetDomesticMultiplierType: DomesticMultType; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetQSOPointMethod: QSOPointMethodType; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string; override;
      function EmitADIFContestFields(const aQso: ContestExchange): string; override;
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
   public
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   end;

implementation

uses
   SysUtils, uContestRegistry,
   (* EmitADIFField -- the tag spellings are ADIF's. *)
   uADIF;

procedure TContestRSGBIOTA.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if Station.MyState = '' then
      begin
      if aQso.DomesticQTH <> '' then
         begin
         aQso.QSOPoints := 15;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      Exit;
      end;

   if (aQso.DomesticQTH <> '')                                and
      (Station.MyState <> string(aQso.DomesticQTH)) then
      begin
      aQso.QSOPoints := 15;
      end
   else
      begin
      aQso.QSOPoints := 5;
      end;
end;

function TContestRSGBIOTA.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                         const aQso: ContestExchange;
                                                         const aCtx: TCabrilloQSOContext): string;
var
   ctx: TCabrilloQSOContext;
begin
   ctx := aCtx;
   if ctx.HisQTH = '' then
      begin
      ctx.HisQTH := '------';
      end;
   Result := inherited FormatCabrilloReceivedExchange(aMy, aQso, ctx);
end;

(* THE WORKED ISLAND, as its corrected reference. *)
function TContestRSGBIOTA.EmitADIFContestFields(const aQso: ContestExchange): string;
begin
   Result := EmitADIFField('IOTA', string(aQso.DomesticQTH));
end;

function TContestRSGBIOTA.GetDisplayName: string;
begin
   Result := 'RSGB IOTA Contest';
end;

function TContestRSGBIOTA.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'RSGB-IOTA';
end;

function TContestRSGBIOTA.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'RSGB-IOTA';
end;

function TContestRSGBIOTA.GetWA7BNMId: integer;
begin
   Result := 75;
end;

function TContestRSGBIOTA.GetQRZRUId: integer;
begin
   Result := 29;
end;

function TContestRSGBIOTA.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRSGBIOTA.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestRSGBIOTA.GetFriendlyName: string;
begin
   Result := 'RSGB IOTA Contest';
end;

function TContestRSGBIOTA.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRSGBIOTA.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestRSGBIOTA.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestRSGBIOTA.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := IOTADomestic;
end;

function TContestRSGBIOTA.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRSGBIOTA.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndPossibleDomesticQTHExchange;
end;

function TContestRSGBIOTA.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := IOTAQSOPointMethod;
end;

function TContestRSGBIOTA.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* THE ISLAND COMES BACK FROM THE IOTA TAG (M5a). Export writes the QSO's
   DomesticQTH as IOTA (EmitADIFContestFields); a record from another logger has
   no such tag and is read as every contest without a rule of its own is. *)
procedure TContestRSGBIOTA.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                           const aSession: TADIFImportSession;
                                           var aExch: ContestExchange);
begin
   inherited ApplyADIFImport(aTemps, aSession, aExch);
   if aTemps.IOTA <> '' then
      begin
      aExch.DomesticQTH := ShortString(aTemps.IOTA);
      end;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestRSGBIOTA.CQExchangeDefault(const aStation: TStationContext): string;
begin
   if aStation.MyState <> '' then
      begin
      Result := ' 5NN # ' + aStation.MyState;
      end
   else
      begin
      Result := ' 5NN #';
      end;
end;

initialization
   RegisterContest(IOTA, TContestRSGBIOTA);

end.
