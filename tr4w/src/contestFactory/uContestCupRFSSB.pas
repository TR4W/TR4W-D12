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

(* THE RUSSIAN CUP (RF CUP), SSB.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: (commented out -- blank);  WA7BNM: 0;  QRZRUID: 24;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: GridFields;  P: 0;
   AE: QSONumberAndGridSquare;  XM: NoDXMults;  QP: CupRFMethod;
   ADIFName: '';  CABName: '';  FriendlyName: ''

  Blank ADIFName, CABName and FriendlyName resolve to the enum's spelling,
  'RF-CUP-SSB'.

  WHY IT HAS A CLASS NOW. M6 (2026-10-02) moved the final score onto the
  contest, and this contest's formula was LogEdit.TotalScore's
  `ActiveQSOPointMethod = CupRFMethod` test -- the session's POINT METHOD, so an
  operator's QSO POINT METHOD line reached it in any contest. A class to hold
  that formula needed the whole row and the scoring arm with it, because
  registering a class makes the class this contest's scorer too. Both are
  transcribed exactly; Test_MovedRowValuesStillMatchTheArray holds the row,
  and the contest matrix the rest -- every line of its record but
  `contest.class` is unchanged, its totals included, which is the proof.

  A SIBLING OF THE CW AND DIGITAL RUNNINGS, NOT A FAMILY (design 1.5, Q7). NY4I's ruling that a
  two-mode contest gets a base names NRAU-Baltic only, and extending it to
  every pair is his open Q7 -- so, as with the SAC pair, the runnings are
  siblings and each owns its copy (design 1.4).

  ITS FINAL SCORE: the points PLUS 100 for each multiplier, not times --
  LogEdit.TotalScore's CupRFMethod arm, moved at M6.

  SCORING, transcribed from CupRFMethod: by the distance between the two
  grids (LOGGRID.GetDistanceBetweenGrids, the geodesic ARRL-DIGI also calls),
  35 to 62 points, or 1 without both grids. *)
unit uContestCupRFSSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCupRFSSB = class(TContestBase)
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

(* CupRFMethod, transcribed. With both grids known, the points rise with the
   distance between them -- 35 up to 2000 km, then 38, 42, 47, 52 and 57 by
   each further 1000 km, and 62 beyond 7000; without them, 1. The received
   grid is the QTH as typed (QTHString), as the arm read it. *)
procedure TContestCupRFSSB.CalculateQSOPoints(var aQso: ContestExchange);
var
   distance: longint;
begin
   if (Station.MyGrid <> '') and (aQso.QTHString <> '') then
      begin
      distance := GetDistanceBetweenGrids(Station.MyGrid, string(aQso.QTHString));

      if distance > 7000 then
         begin
         aQso.QSOPoints := 62;
         end;
      if distance <= 7000 then
         begin
         aQso.QSOPoints := 57;
         end;
      if distance <= 6000 then
         begin
         aQso.QSOPoints := 52;
         end;
      if distance <= 5000 then
         begin
         aQso.QSOPoints := 47;
         end;
      if distance <= 4000 then
         begin
         aQso.QSOPoints := 42;
         end;
      if distance <= 3000 then
         begin
         aQso.QSOPoints := 38;
         end;
      if distance <= 2000 then
         begin
         aQso.QSOPoints := 35;
         end;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;
end;

function TContestCupRFSSB.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := ContestPoints(aTotals) + 100 * SummedMultipliers(aTotals);
end;

function TContestCupRFSSB.GetDisplayName: string;
begin
   Result := 'RF-CUP-SSB';
end;

function TContestCupRFSSB.GetCabrilloName: string;
begin
   (* The row's CABName is blank; the Cabrillo header writes the enum's spelling. *)
   Result := 'RF-CUP-SSB';
end;

function TContestCupRFSSB.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'RF-CUP-SSB';
end;

function TContestCupRFSSB.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestCupRFSSB.GetQRZRUId: integer;
begin
   Result := 24;
end;

function TContestCupRFSSB.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestCupRFSSB.GetDomesticFileName: string;
begin
   (* The row's DF is commented out in VC.pas (it reads DF: 'grids' inside a comment), so it is blank. *)
   Result := '';
end;

function TContestCupRFSSB.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank, which means the enum's spelling. *)
   Result := 'RF-CUP-SSB';
end;

function TContestCupRFSSB.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestCupRFSSB.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestCupRFSSB.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestCupRFSSB.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := GridFields;
end;

function TContestCupRFSSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestCupRFSSB.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberAndGridSquare;
end;

function TContestCupRFSSB.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := CupRFMethod;
end;

function TContestCupRFSSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(CUPRFSSB, TContestCupRFSSB);

end.
