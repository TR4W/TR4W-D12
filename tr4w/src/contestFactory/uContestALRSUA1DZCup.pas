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

(* THE ALRS UA1DZ CUP.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'russian';  WA7BNM: 0;  QRZRUID: 543;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: WYSIWYGDomestic;  P: 0;
   AE: RSTDomesticQTHExchange;  XM: CQDXCC;  QP: ALRSUA1DZCupQSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: ''

  Blank ADIFName, CABName and FriendlyName resolve to the enum's spelling,
  'ALRS-UA1DZ-CUP'.

  WHY IT HAS A CLASS NOW. M6 (2026-10-02) moved the final score onto the
  contest, and this contest's formula was LogEdit.TotalScore's
  `ActiveQSOPointMethod = ALRSUA1DZCupQSOPointMethod` test -- the session's POINT METHOD, so an
  operator's QSO POINT METHOD line reached it in any contest. A class to hold
  that formula needed the whole row and the scoring arm with it, because
  registering a class makes the class this contest's scorer too. Both are
  transcribed exactly; Test_MovedRowValuesStillMatchTheArray holds the row,
  and the contest matrix the rest -- every line of its record but
  `contest.class` is unchanged, its totals included, which is the proof.

  ITS FINAL SCORE: the points PLUS 300 for each multiplier, not times --
  LogEdit.TotalScore's ALRSUA1DZCupQSOPointMethod arm, moved at M6.

  SCORING, transcribed from ALRSUA1DZCupQSOPointMethod: by the distance
  between the two grids, KO59 standing for St Petersburg and its oblast, with
  50 more for a contact into them from outside. *)
unit uContestALRSUA1DZCup;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestALRSUA1DZCup = class(TContestBase)
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
      (* THE SPONSOR'S FORMULA -- see the header. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   end;

implementation

uses
   uContestRegistry,
   (* RussianID, GetOblast -- the leaves the arm asked. *)
   uCallSignRoutines,
   (* RussianRegionType, GetRussiaOblastByTwoChars. *)
   uRussiaOblasts,
   (* GetDistanceBetweenGrids -- the arm's own geodesic; see
      uContestARRLDigi for why it is the TRDOS unit. *)
   LOGGRID;

(* ALRSUA1DZCupQSOPointMethod, transcribed line for line, quirks kept.

   Each side's grid: KO59 for a station in UA1A or UA1C (St Petersburg and its
   oblast), else our MY STATE and the worked station's QTH as typed. The same
   field (first two characters) scores 5, anything else ten times the decimal
   log of the distance between the two; and a station outside UA1A/UA1C
   working one inside adds 50.

   THE QUIRKS ARE THE ARM'S, NOT THIS CLASS'S: RussianID is asked of the
   worked station's CALLSIGN (the routine takes a country id), and a QTH that
   is not a grid is handed to the distance as if it were one -- which is why
   the matrix's parse section records no points (design 8.2g). Both grids are
   zero-filled first, as the arm did, so the field test reads zeros past a
   short value. *)
procedure TContestALRSUA1DZCup.CalculateQSOPoints(var aQso: ContestExchange);
var
   grid1, grid2: GridString;
   region1, region2: RussianRegionType;
   oblast: string[2];
   distance: longint;
begin
   FillChar(grid1, SizeOf(grid1), 0);
   FillChar(grid2, SizeOf(grid2), 0);

   region1 := rtUnknownRegion;
   region2 := rtUnknownRegion;

   FillChar(oblast, SizeOf(oblast), 0);
   if RussianID(string(Station.MyCountry)) then
      begin
      oblast := ShortString(GetOblast(Station.MyCall));
      region1 := GetRussiaOblastByTwoChars(Char(oblast[1]), Char(oblast[2]));
      end;

   FillChar(oblast, SizeOf(oblast), 0);
   if RussianID(string(aQso.Callsign)) then
      begin
      oblast := ShortString(GetOblast(string(aQso.Callsign)));
      region2 := GetRussiaOblastByTwoChars(Char(oblast[1]), Char(oblast[2]));
      end;

   if region1 in [rtUA1A, rtUA1C] then
      begin
      grid1 := 'KO59';
      end
   else
      begin
      grid1 := ShortString(Station.MyState);
      end;

   if region2 in [rtUA1A, rtUA1C] then
      begin
      grid2 := 'KO59';
      end
   else
      begin
      grid2 := aQso.QTHString;
      end;

   if (grid1[1] = grid2[1]) and (grid1[2] = grid2[2]) then
      begin
      aQso.QSOPoints := 5;
      end
   else
      begin
      distance := GetDistanceBetweenGrids(string(grid1), string(grid2));
      aQso.QSOPoints := round(10 * ln(distance) / ln(10));
      end;

   if not (region1 in [rtUA1A, rtUA1C]) then
      begin
      if region2 in [rtUA1A, rtUA1C] then
         begin
         aQso.QSOPoints := aQso.QSOPoints + 50;
         end;
      end;
end;

function TContestALRSUA1DZCup.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := ContestPoints(aTotals) + 300 * SummedMultipliers(aTotals);
end;

function TContestALRSUA1DZCup.GetDisplayName: string;
begin
   Result := 'ALRS-UA1DZ-CUP';
end;

function TContestALRSUA1DZCup.GetCabrilloName: string;
begin
   (* The row's CABName is blank; the Cabrillo header writes the enum's spelling. *)
   Result := 'ALRS-UA1DZ-CUP';
end;

function TContestALRSUA1DZCup.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'ALRS-UA1DZ-CUP';
end;

function TContestALRSUA1DZCup.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestALRSUA1DZCup.GetQRZRUId: integer;
begin
   Result := 543;
end;

function TContestALRSUA1DZCup.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestALRSUA1DZCup.GetDomesticFileName: string;
begin
   Result := 'russian';
end;

function TContestALRSUA1DZCup.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank, which means the enum's spelling. *)
   Result := 'ALRS-UA1DZ-CUP';
end;

function TContestALRSUA1DZCup.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestALRSUA1DZCup.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestALRSUA1DZCup.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestALRSUA1DZCup.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := WYSIWYGDomestic;
end;

function TContestALRSUA1DZCup.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestALRSUA1DZCup.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestALRSUA1DZCup.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := ALRSUA1DZCupQSOPointMethod;
end;

function TContestALRSUA1DZCup.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(ALRS_UA1DZ_CUP, TContestALRSUA1DZCup);

end.
