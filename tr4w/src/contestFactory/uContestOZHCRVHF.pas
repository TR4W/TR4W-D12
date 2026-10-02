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

(* THE OZ HAM CONTEST RADIO VHF (OZHCR-VHF).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0;  QRZRUID: 203;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: GridSquares;  P: 0;
   AE: RSTQSONumberAndGridSquareExchange;  XM: NoDXMults;  QP: OZHCRVHFQSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: ''

  Blank ADIFName, CABName and FriendlyName resolve to the enum's spelling,
  'OZHCR-VHF'.

  WHY IT HAS A CLASS NOW. M6 (2026-10-02) moved the final score onto the
  contest, and this contest's formula was LogEdit.TotalScore's
  `ActiveQSOPointMethod = OZHCRVHFQSOPointMethod` test -- the session's POINT METHOD, so an
  operator's QSO POINT METHOD line reached it in any contest. A class to hold
  that formula needed the whole row and the scoring arm with it, because
  registering a class makes the class this contest's scorer too. Both are
  transcribed exactly; Test_MovedRowValuesStillMatchTheArray holds the row,
  and the contest matrix the rest -- every line of its record but
  `contest.class` is unchanged, its totals included, which is the proof.

  ITS FINAL SCORE: the points PLUS 1000 for each multiplier, not times --
  LogEdit.TotalScore's OZHCRVHFQSOPointMethod arm, moved at M6.

  SCORING, transcribed from OZHCRVHFQSOPointMethod: the distance in km
  between the two grids, weighted by band. *)
unit uContestOZHCRVHF;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestOZHCRVHF = class(TContestBase)
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
   (* GetDistanceBetweenGrids -- the arm's own geodesic; see
      uContestARRLDigi for why it is the TRDOS unit. *)
   LOGGRID;

(* OZHCRVHFQSOPointMethod, transcribed. With our grid known, the distance to
   the worked grid (the domestic QTH, as the arm read it) is the points on
   2 m, doubled on 70 cm, four times on 23 cm and six times above; any other
   band, or no grid of ours, scores 0. *)
procedure TContestOZHCRVHF.CalculateQSOPoints(var aQso: ContestExchange);
var
   points: integer;
begin
   if Station.MyGrid <> '' then
      begin
      points := GetDistanceBetweenGrids(Station.MyGrid, string(aQso.DomesticQTH));
      if aQso.Band = Band2 then
         begin
         aQso.QSOPoints := points;
         end;
      if aQso.Band = Band432 then
         begin
         aQso.QSOPoints := points * 2;
         end;
      if aQso.Band = Band1296 then
         begin
         aQso.QSOPoints := points * 4;
         end;
      if aQso.Band > Band1296 then
         begin
         aQso.QSOPoints := points * 6;
         end;
      end;
end;

function TContestOZHCRVHF.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := ContestPoints(aTotals) + 1000 * SummedMultipliers(aTotals);
end;

function TContestOZHCRVHF.GetDisplayName: string;
begin
   Result := 'OZHCR-VHF';
end;

function TContestOZHCRVHF.GetCabrilloName: string;
begin
   (* The row's CABName is blank; the Cabrillo header writes the enum's spelling. *)
   Result := 'OZHCR-VHF';
end;

function TContestOZHCRVHF.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'OZHCR-VHF';
end;

function TContestOZHCRVHF.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestOZHCRVHF.GetQRZRUId: integer;
begin
   Result := 203;
end;

function TContestOZHCRVHF.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestOZHCRVHF.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestOZHCRVHF.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank, which means the enum's spelling. *)
   Result := 'OZHCR-VHF';
end;

function TContestOZHCRVHF.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestOZHCRVHF.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestOZHCRVHF.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestOZHCRVHF.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := GridSquares;
end;

function TContestOZHCRVHF.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestOZHCRVHF.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndGridSquareExchange;
end;

function TContestOZHCRVHF.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OZHCRVHFQSOPointMethod;
end;

function TContestOZHCRVHF.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(OZHCRVHF, TContestOZHCRVHF);

end.
