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

(* THE RAEM ERNST KRENKEL MEMORIAL CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 209;  QRZRUID: 88;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: QSONumberAndGeoCoordinates;
   XM: NoDXMults;  QP: RAEMQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'RAEM Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'RAEM'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: RAEMQSOPointMethod -- when MY STATE and the received QTH both
  read as geographic coordinates (LOGGRID.LooksLikeAGeoCoordinates): 50,
  plus the latitude difference, plus the longitude difference taken the
  short way round; +300 for working RAEM itself, +100 when the worked
  station is above 65 degrees north, and the whole times 1.1 (rounded) when
  we are. Otherwise 0.

  SET-UP: 80 m, the contest name, and the initial exchange's cursor at
  the start (TSessionDefaults.InitialExchangeCursorAtStart, M7b batch 2).
  LogCfg's CQ exchange: the serial and MY STATE.

  THE 'RAEM' IN uCallSignRoutines.IsAGoodCall IS NOT THIS CONTEST: it is
  the special callsign RAEM, accepted as a call; it stays where it is. *)
unit uContestRAEM;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRAEM = class(TContestBase)
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
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uContestRegistry,
   LOGGRID,
   uTR4WStrings;

(* RAEMQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestRAEM.CalculateQSOPoints(var aQso: ContestExchange);
var
   la1, la2, lo1, lo2: integer;
   distance: longint;
begin
   if LooksLikeAGeoCoordinates(UTF8Encode(Station.MyState), la1, lo1) then
      begin
      if LooksLikeAGeoCoordinates(aQso.QTHString, la2, lo2) then
         begin
         distance := Abs(lo1 - lo2);
         if distance > 180 then
            begin
            distance := 360 - distance;
            end;
         aQso.QSOPoints := 50 + Abs(la2 - la1) + distance;
         if aQso.Callsign = 'RAEM' then
            begin
            aQso.QSOPoints := aQso.QSOPoints + 300;
            end;
         if la2 > 65 + 90 then
            begin
            aQso.QSOPoints := aQso.QSOPoints + 100;
            end;
         if la1 > 65 + 90 then
            begin
            aQso.QSOPoints := Round(aQso.QSOPoints * 1.1);
            end;
         end;
      end;
end;

function TContestRAEM.GetDisplayName: string;
begin
   Result := 'RAEM Contest';
end;

function TContestRAEM.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'RAEM';
end;

function TContestRAEM.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'RAEM';
end;

function TContestRAEM.GetWA7BNMId: integer;
begin
   Result := 209;
end;

function TContestRAEM.GetQRZRUId: integer;
begin
   Result := 88;
end;

function TContestRAEM.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRAEM.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestRAEM.GetFriendlyName: string;
begin
   Result := 'RAEM Contest';
end;

function TContestRAEM.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRAEM.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestRAEM.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestRAEM.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestRAEM.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRAEM.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberAndGeoCoordinates;
end;

function TContestRAEM.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := RAEMQSOPointMethod;
end;

function TContestRAEM.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestRAEM.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.Band := Band80;
   aSession.ContestName := 'RAEM Ernst Krenkel Memorial Contest';
   aSession.InitialExchangeCursorAtStart := True;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved here as it
   stood (M7b batch 2). See TContestBase.CQExchangeDefault. *)
function TContestRAEM.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' # ' + aStation.MyState;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts. *)
procedure TContestRAEM.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURGEOGRAPHICALCOORDINATES, ncfMyQTH);
end;

initialization
   RegisterContest(RAEM, TContestRAEM);

end.
