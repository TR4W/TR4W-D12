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

(* THE STEW PERRY TOPBAND DISTANCE CHALLENGE.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 207;  QRZRUID: 46;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTAndOrGridExchange;
   XM: NoDXMults;  QP: StewPerryQSOPointMethod;
   ADIFName: 'STEW-PERRY';  CABName: '';
   FriendlyName: 'Stew Perry Topband Challenge'

  Blank CABName resolves to the enum's spelling, 'STEW-PERRY'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: StewPerryQSOPointMethod -- with MY GRID and the received grid:
  one point per 500 km begun (distance div 500, plus 1), times 3 for a QRP
  entrant and 1.5 (rounded) for a low-power one -- the entrant's
  CATEGORY-POWER, Station.MyPower, the setting the arm read. Without both
  grids, 1.

  SET-UP: the contest name 'STEW-PERRY', the CQ and S&P exchanges as MY
  GRID, 160 m.

  DESIGN Q37 REACHES THIS CONTEST. LOGGRID.GetDistanceBetweenGrids pads a
  grid that is not six characters with 'LL', and ConvertGridToLatLon reads
  four characters of it: a grid shorter than four is read past its end, and
  such a QSO's points follow the heap. Q37 is open; the grid handling is
  transcribed untouched. Only a received grid
  that is non-empty and shorter than four characters reaches it. *)
unit uContestStewPerry;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestStewPerry = class(TContestBase)
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
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   end;

implementation

uses
   uSettingsModel,
   uContestRegistry,
   LOGGRID;

(* StewPerryQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestStewPerry.CalculateQSOPoints(var aQso: ContestExchange);
var
   distance: longint;
begin
   if (Station.MyGrid <> '') and (aQso.DomesticQTH <> '') then
      begin
      distance := GetDistanceBetweenGrids(Station.MyGrid, aQso.DomesticQTH);
      aQso.QSOPoints := (distance div 500) + 1;
      if Station.MyPower = cpQRP then
         begin
         aQso.QSOPoints := aQso.QSOPoints * 3;
         end;
      if Station.MyPower = cpLOW then
         begin
         aQso.QSOPoints := Round(aQso.QSOPoints * 1.5);
         end;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;
end;

function TContestStewPerry.GetDisplayName: string;
begin
   Result := 'STEW-PERRY';
end;

function TContestStewPerry.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'STEW-PERRY';
end;

function TContestStewPerry.GetADIFContestId: string;
begin
   Result := 'STEW-PERRY';
end;

function TContestStewPerry.GetWA7BNMId: integer;
begin
   Result := 207;
end;

function TContestStewPerry.GetQRZRUId: integer;
begin
   Result := 46;
end;

function TContestStewPerry.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestStewPerry.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestStewPerry.GetFriendlyName: string;
begin
   Result := 'Stew Perry Topband Challenge';
end;

function TContestStewPerry.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestStewPerry.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestStewPerry.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestStewPerry.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestStewPerry.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestStewPerry.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndOrGridExchange;
end;

function TContestStewPerry.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := StewPerryQSOPointMethod;
end;

function TContestStewPerry.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestStewPerry.DescribeSession(const aStation: TStationContext;
                                            aSession: TSessionDefaults);
begin
   aSession.ContestName := 'STEW-PERRY';
   aSession.CQExchangeCW := ' ' + aStation.MyGrid;
   aSession.SPExchangeCW := aStation.MyGrid;
   aSession.Band := Band160;
end;

initialization
   RegisterContest(STEWPERRY, TContestStewPerry);

end.
