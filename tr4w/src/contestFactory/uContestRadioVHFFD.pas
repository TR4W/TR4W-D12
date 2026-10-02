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

(* THE RADIO VHF FIELD DAY (RF-VHF-FD).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 180;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTQSONumberAndGridSquareExchange;
   XM: NoDXMults;  QP: RadioVHFFDQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'RF-VHF-FD'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: RadioVHFFDQSOPointMethod -- with MY GRID set, the distance to
  the worked station's grid (its DomesticQTH) in kilometres, times 1 on
  2 m, 2 on 70 cm, 4 on 23 cm and 6 on 13 cm and above (2304 MHz to light);
  0 on any other band. With no MY GRID, 0.

  SET-UP: HF off, 2 m, digital off, the contest name 'RF-VHF-FD', QSOs by
  band and not by mode, QSO numbers by band. LogCfg's CQ exchange: 5NN, the
  serial and MY GRID.

  DESIGN Q37 REACHES THIS CONTEST. LOGGRID.GetDistanceBetweenGrids pads a
  grid that is not six characters with 'LL', and ConvertGridToLatLon reads
  four characters of it: a grid shorter than four is read past its end, and
  such a QSO's points follow the heap. Q37 is open; the grid handling is
  transcribed untouched. An empty DomesticQTH is
  the common case here: it is padded to 'LL' and read the same way. *)
unit uContestRadioVHFFD;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRadioVHFFD = class(TContestBase)
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
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   end;

implementation

uses
   uContestRegistry,
   LOGGRID;

(* RadioVHFFDQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestRadioVHFFD.CalculateQSOPoints(var aQso: ContestExchange);
var
   points: integer;
begin
   if Station.MyGrid <> '' then
      begin
      points := GetDistanceBetweenGrids(Station.MyGrid, aQso.DomesticQTH);
      if aQso.Band = Band2 then
         begin
         aQso.QSOPoints := points * 1;
         end
      else if aQso.Band = Band432 then
         begin
         aQso.QSOPoints := points * 2;
         end
      else if aQso.Band = Band1296 then
         begin
         aQso.QSOPoints := points * 4;
         end
      else if aQso.Band in [Band2304, Band3456, Band5760, Band10G,
                            Band24G, BandLight] then
         begin
         aQso.QSOPoints := points * 6;
         end
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestRadioVHFFD.GetDisplayName: string;
begin
   Result := 'RF-VHF-FD';
end;

function TContestRadioVHFFD.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'RF-VHF-FD';
end;

function TContestRadioVHFFD.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'RF-VHF-FD';
end;

function TContestRadioVHFFD.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestRadioVHFFD.GetQRZRUId: integer;
begin
   Result := 180;
end;

function TContestRadioVHFFD.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRadioVHFFD.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestRadioVHFFD.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'RF-VHF-FD';
end;

function TContestRadioVHFFD.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRadioVHFFD.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestRadioVHFFD.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestRadioVHFFD.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestRadioVHFFD.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRadioVHFFD.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndGridSquareExchange;
end;

function TContestRadioVHFFD.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := RadioVHFFDQSOPointMethod;
end;

function TContestRadioVHFFD.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestRadioVHFFD.DescribeSession(const aStation: TStationContext;
                                             aSession: TSessionDefaults);
begin
   aSession.HFEnabled := False;
   aSession.Band := Band2;
   aSession.DigitalModeEnable := False;
   aSession.ContestName := 'RF-VHF-FD';
   aSession.QSOByMode := False;
   aSession.QSOByBand := True;
   aSession.QSONumberByBand := True;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved here as it
   stood (M7b batch 2). See TContestBase.CQExchangeDefault. *)
function TContestRadioVHFFD.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' 5NN # ' + aStation.MyGrid;
end;

initialization
   RegisterContest(RADIOVHFFD, TContestRadioVHFFD);

end.
