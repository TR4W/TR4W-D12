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

(* THE UKRAINE CHAMPIONSHIP.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'ukraine';  WA7BNM: 0;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: QSONumberDomesticQTHExchange;
   XM: NoDXMults;  QP: ChampionshipUkrMethod;  ADIFName: '';
   CABName: '';  FriendlyName: ''

  Blank ADIFName, CABName and FriendlyName are the enum's spelling,
  'UKRAINE CHAMPIONSHIP'.

  WHY IT HAS A CLASS NOW. M4 (2026-10-01) made every contest format its own
  export, and this contest's rule was a `Contest = UKRAINECHAMPIONSHIP` test inside a shared
  exporter -- which the base may never contain. A class to hold that rule
  needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record
  but `contest.class` is unchanged, which is the proof. EXCHANGE PARSING
  (M5b) and set-up (M7a) have moved since.

  SCORING IS ChampionshipUkrMethod, transcribed exactly: a QSO with a station
  outside Ukraine (CTY country UR) scores nothing, every other QSO scores 2 --

      if RXCty <> 'UR' then Exit;
      RXData.QSOPoints := 2;

  THE QTH COMES FIRST ON ITS CABRILLO LINE. This contest runs
  QSONumberDomesticQTHExchange, whose shared arm writes the serial first and
  the QTH second; the legacy arm tested `(Contest = UKRAINECHAMPIONSHIP) or
  (Contest = CUPURAL)` and swapped them, with a zero-padded serial. That swap
  is this class's own Cabrillo pair now. Its ADIF STX_STRING was never
  swapped, so it is the base's default. The Ukraine Championship and the
  Ural Cup carry the same pair as two copies (design 1.4): two sponsors. *)
unit uContestUkraineChampionship;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestUkraineChampionship = class(TContestBase)
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

      (* THE FINAL SCORE -- see the implementation. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      function FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aCtx: TCabrilloQSOContext): string; override;
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string; override;
   public
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   end;

implementation

uses
   SysUtils, uContestRegistry;

procedure TContestUkraineChampionship.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.QTH.CountryID <> 'UR' then
      begin
      Exit;
      end;
   aQso.QSOPoints := 2;
end;

(* THE POINTS PLUS TEN FOR EACH MULTIPLIER -- added, not multiplied.
   LogEdit.TotalScore's `Contest in [UKRAINECHAMPIONSHIP]` arm, moved at M6. *)
function TContestUkraineChampionship.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := ContestPoints(aTotals) + 10 * SummedMultipliers(aTotals);
end;

function TContestUkraineChampionship.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                                const aQso: ContestExchange;
                                                                const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-4s %-6.4d', [aMy.MyState, aQso.NumberSent]);
end;

function TContestUkraineChampionship.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                                    const aQso: ContestExchange;
                                                                    const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-4s %-6.4u', [aCtx.HisQTH, aQso.NumberReceived]);
end;

function TContestUkraineChampionship.GetDisplayName: string;
begin
   Result := 'UKRAINE CHAMPIONSHIP';
end;

function TContestUkraineChampionship.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'UKRAINE CHAMPIONSHIP';
end;

function TContestUkraineChampionship.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'UKRAINE CHAMPIONSHIP';
end;

function TContestUkraineChampionship.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestUkraineChampionship.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestUkraineChampionship.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestUkraineChampionship.GetDomesticFileName: string;
begin
   Result := 'ukraine';
end;

function TContestUkraineChampionship.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; it resolves to the enum's
      spelling. *)
   Result := 'UKRAINE CHAMPIONSHIP';
end;

function TContestUkraineChampionship.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestUkraineChampionship.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestUkraineChampionship.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestUkraineChampionship.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestUkraineChampionship.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestUkraineChampionship.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberDomesticQTHExchange;
end;

function TContestUkraineChampionship.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := ChampionshipUkrMethod;
end;

function TContestUkraineChampionship.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestUkraineChampionship.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' ' + aStation.MyState + '#';
end;

initialization
   RegisterContest(UKRAINECHAMPIONSHIP, TContestUkraineChampionship);

end.
