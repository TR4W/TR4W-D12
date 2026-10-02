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

(* THE TESLA MEMORIAL HF CW CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 566;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTQSONumberAndGridSquareExchange;
   XM: NoDXMults;  QP: TeslaQSOPointMethod;
   ADIFName: '';  CABName: 'HF-TESLA';
   FriendlyName: 'TESLA Memorial HF CW Contest'

  A blank ADIFName resolves to the enum's spelling, 'HF-TESLA'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: TeslaQSOPointMethod (2019 rules) -- by the distance from our
  grid to the QSO's domestic QTH: to 600 km 10, 1200 13, 1800 16, 2400 20,
  3600 24, 4800 28, 6000 32, 7200 36, 8400 40, beyond 45.

  ONE LINE OF THE ARM IS NOT HERE, ON PURPOSE: it ended in
  LOGWIND.DisplayTotalScore, a repaint of the main window's score panel
  from inside the scoring routine. That is display, not a rule; a class
  may not reach the display layer, and every path that logs a QSO repaints
  the score after it is scored. Nothing the program records depends on it.

  A grid shorter than four characters is read past its end -- design Q37,
  as for the European VHF contest. *)
unit uContestTesla;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestTesla = class(TContestBase)
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
   (* GetDistanceBetweenGrids -- the arm's own geodesic; see
      uContestARRLDigi for why it is the TRDOS unit. *)
   LOGGRID;

procedure TContestTesla.CalculateQSOPoints(var aQso: ContestExchange);
var
   distance: integer;
begin
   distance := GetDistanceBetweenGrids(Station.MyGrid, string(aQso.DomesticQTH));
   case distance of
      0..600:
         begin
         aQso.QSOPoints := 10;
         end;
      601..1200:
         begin
         aQso.QSOPoints := 13;
         end;
      1201..1800:
         begin
         aQso.QSOPoints := 16;
         end;
      1801..2400:
         begin
         aQso.QSOPoints := 20;
         end;
      2401..3600:
         begin
         aQso.QSOPoints := 24;
         end;
      3601..4800:
         begin
         aQso.QSOPoints := 28;
         end;
      4801..6000:
         begin
         aQso.QSOPoints := 32;
         end;
      6001..7200:
         begin
         aQso.QSOPoints := 36;
         end;
      7201..8400:
         begin
         aQso.QSOPoints := 40;
         end;
      else
         begin
         aQso.QSOPoints := 45;
         end;
      end;
end;

function TContestTesla.GetDisplayName: string;
begin
   Result := 'HF-TESLA';
end;

function TContestTesla.GetCabrilloName: string;
begin
   Result := 'HF-TESLA';
end;

function TContestTesla.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'HF-TESLA';
end;

function TContestTesla.GetWA7BNMId: integer;
begin
   Result := 566;
end;

function TContestTesla.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestTesla.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestTesla.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestTesla.GetFriendlyName: string;
begin
   Result := 'TESLA Memorial HF CW Contest';
end;

function TContestTesla.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestTesla.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestTesla.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestTesla.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestTesla.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestTesla.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndGridSquareExchange;
end;

function TContestTesla.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := TeslaQSOPointMethod;
end;

function TContestTesla.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(TESLA, TContestTesla);

end.
