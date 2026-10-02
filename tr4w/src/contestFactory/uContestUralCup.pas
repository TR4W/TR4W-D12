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

(* THE URAL CUP.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'grids';  WA7BNM: 0;  QRZRUID: 112;
   Pxm: CallSignPrefix;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: QSONumberDomesticQTHExchange;
   XM: NoDXMults;  QP: OnePointPerQSO;  ADIFName: '';
   CABName: '';  FriendlyName: ''

  Blank ADIFName, CABName and FriendlyName are the enum's spelling,
  'URAL-CUP'.

  WHY IT HAS A CLASS NOW. M4 (2026-10-01) made every contest format its own
  export, and this contest's rule was a `Contest = CUPURAL` test inside a shared
  exporter -- which the base may never contain. A class to hold that rule
  needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record
  but `contest.class` is unchanged, which is the proof. EXCHANGE PARSING
  (M5) and set-up (M7) are not moved.

  SCORING IS OnePointPerQSO, one arm of LOGSTUFF.CalculateQSOPoints, stated
  through the FixedModePoints helper:

      OnePointPerQSO: RXData.QSOPoints := 1;

  THE QTH COMES FIRST ON ITS CABRILLO LINE. This contest runs
  QSONumberDomesticQTHExchange, whose shared arm writes the serial first and
  the QTH second; the legacy arm tested `(Contest = UKRAINECHAMPIONSHIP) or
  (Contest = CUPURAL)` and swapped them, with a zero-padded serial. That swap
  is this class's own Cabrillo pair now. Its ADIF STX_STRING was never
  swapped, so it is the base's default. The Ukraine Championship and the
  Ural Cup carry the same pair as two copies (design 1.4): two sponsors. *)
unit uContestUralCup;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestUralCup = class(TContestBase)
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
   end;

implementation

uses
   SysUtils, uContestRegistry, uContestFixedPoints;

procedure TContestUralCup.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

(* THE PREFIXES ARE NOT MULTIPLIERS BUT TEN POINTS EACH, ADDED AFTER THE
   MULTIPLICATION. Transcribed from the two `Contest = CUPURAL` arms of
   LogEdit.TotalScore (M6): on all bands the prefix count comes out of the
   multiplier sum; a single-band entry's sum keeps it, as TotalScore's
   single-band arm did; and the ten per prefix is always the all-band count. *)
function TContestUralCup.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
var
   mults: longint;
begin
   mults := SummedMultipliers(aTotals);
   if aTotals.ScoredBand = AllBands then
      begin
      mults := mults - aTotals.Mults[AllBands, Both, rmPrefix];
      end;

   Result := ContestPoints(aTotals) * mults;
   Result := Result + 10 * aTotals.Mults[AllBands, Both, rmPrefix];
end;

function TContestUralCup.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-4s %-6.4d', [aMy.MyState, aQso.NumberSent]);
end;

function TContestUralCup.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-4s %-6.4u', [aCtx.HisQTH, aQso.NumberReceived]);
end;

function TContestUralCup.GetDisplayName: string;
begin
   Result := 'URAL-CUP';
end;

function TContestUralCup.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'URAL-CUP';
end;

function TContestUralCup.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'URAL-CUP';
end;

function TContestUralCup.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestUralCup.GetQRZRUId: integer;
begin
   Result := 112;
end;

function TContestUralCup.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestUralCup.GetDomesticFileName: string;
begin
   Result := 'grids';
end;

function TContestUralCup.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; it resolves to the enum's
      spelling. *)
   Result := 'URAL-CUP';
end;

function TContestUralCup.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := CallSignPrefix;
end;

function TContestUralCup.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestUralCup.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestUralCup.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestUralCup.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestUralCup.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberDomesticQTHExchange;
end;

function TContestUralCup.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestUralCup.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(CUPURAL, TContestUralCup);

end.
