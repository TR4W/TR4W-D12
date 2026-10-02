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

(* THE WWL CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: GridFields;  P: 0;  AE: RSTAndGridExchange;
   XM: NoDXMults;  QP: WWLQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'WWL'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: WWLQSOPointMethod -- with MY GRID and the received grid: one
  point per 500 km begun, doubled on 80 m and quadrupled on 160 m; without
  both grids, 1.

  SET-UP: nothing -- no FoundContest or LogCfg arm named it.

  DESIGN Q37 REACHES THIS CONTEST. LOGGRID.GetDistanceBetweenGrids pads a
  grid that is not six characters with 'LL', and ConvertGridToLatLon reads
  four characters of it: a grid shorter than four is read past its end, and
  such a QSO's points follow the heap. Q37 is open; the grid handling is
  transcribed untouched. Only a received grid
  that is non-empty and shorter than four characters reaches it. *)
unit uContestWWL;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestWWL = class(TContestBase)
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
   end;

implementation

uses
   uContestRegistry,
   LOGGRID;

(* WWLQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestWWL.CalculateQSOPoints(var aQso: ContestExchange);
var
   distance: longint;
begin
   if (Station.MyGrid <> '') and (aQso.DomesticQTH <> '') then
      begin
      distance := GetDistanceBetweenGrids(Station.MyGrid, aQso.DomesticQTH);
      aQso.QSOPoints := (distance div 500) + 1;

      if (aQso.Band = Band80) or (aQso.Band = Band160) then
         begin
         aQso.QSOPoints := aQso.QSOPoints + aQso.QSOPoints;
         end;

      if aQso.Band = Band160 then
         begin
         aQso.QSOPoints := aQso.QSOPoints + aQso.QSOPoints;
         end;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;
end;

function TContestWWL.GetDisplayName: string;
begin
   Result := 'WWL';
end;

function TContestWWL.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'WWL';
end;

function TContestWWL.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'WWL';
end;

function TContestWWL.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestWWL.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestWWL.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestWWL.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestWWL.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'WWL';
end;

function TContestWWL.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestWWL.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestWWL.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestWWL.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := GridFields;
end;

function TContestWWL.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestWWL.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndGridExchange;
end;

function TContestWWL.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := WWLQSOPointMethod;
end;

function TContestWWL.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(WWL, TContestWWL);

end.
