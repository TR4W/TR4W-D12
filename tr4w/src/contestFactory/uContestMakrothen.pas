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

(* THE MAKROTHEN RTTY CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 159;  QRZRUID: 515;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: GridInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: GridExchange;
   XM: NoDXMults;  QP: MakrothenQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'Makrothen RTTY Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'MAKROTHEN-RTTY'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: MakrothenQSOPointMethod -- with MY GRID: 100 for a station in
  our own four-character square; otherwise the distance to its grid,
  times 1.5 (rounded) on 40 m and 2 on 80 m. With no MY GRID, 0.

  SET-UP: nothing in FoundContest. LogCfg's CQ exchange: the first four
  characters of MY GRID, twice.

  DESIGN Q37 REACHES THIS CONTEST. LOGGRID.GetDistanceBetweenGrids pads a
  grid that is not six characters with 'LL', and ConvertGridToLatLon reads
  four characters of it: a grid shorter than four is read past its end, and
  such a QSO's points follow the heap. Q37 is open; the grid handling is
  transcribed untouched. An empty received grid
  reaches it whenever MY GRID is set. *)
unit uContestMakrothen;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestMakrothen = class(TContestBase)
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

(* MakrothenQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestMakrothen.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if Station.MyGrid <> '' then
      begin
      if Copy(Station.MyGrid, 1, 4) = Copy(aQso.DomesticQTH, 1, 4) then
         begin
         aQso.QSOPoints := 100;
         end
      else
         begin
         aQso.QSOPoints := GetDistanceBetweenGrids(Station.MyGrid,
                                                   aQso.DomesticQTH);
         if aQso.Band = Band40 then
            begin
            aQso.QSOPoints := Round(aQso.QSOPoints * 1.5);
            end;

         if aQso.Band = Band80 then
            begin
            aQso.QSOPoints := aQso.QSOPoints * 2;
            end;
         end;
      end;
end;

function TContestMakrothen.GetDisplayName: string;
begin
   Result := 'Makrothen RTTY Contest';
end;

function TContestMakrothen.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'MAKROTHEN-RTTY';
end;

function TContestMakrothen.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'MAKROTHEN-RTTY';
end;

function TContestMakrothen.GetWA7BNMId: integer;
begin
   Result := 159;
end;

function TContestMakrothen.GetQRZRUId: integer;
begin
   Result := 515;
end;

function TContestMakrothen.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestMakrothen.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestMakrothen.GetFriendlyName: string;
begin
   Result := 'Makrothen RTTY Contest';
end;

function TContestMakrothen.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestMakrothen.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestMakrothen.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestMakrothen.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestMakrothen.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := GridInitialExchange;
end;

function TContestMakrothen.GetExchangeKind: ExchangeType;
begin
   Result := GridExchange;
end;

function TContestMakrothen.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := MakrothenQSOPointMethod;
end;

function TContestMakrothen.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved here as it
   stood (M7b batch 2). See TContestBase.CQExchangeDefault. *)
function TContestMakrothen.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' ' + Copy(aStation.MyGrid, 1, 4) + ' ' + Copy(aStation.MyGrid, 1, 4);
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ARRLDIGI, ARRLVHFJAN, ARRLVHFJUN,
   ARRLVHFSEP, BATAVIA_FT8, CQVHF, CUPRFCW, CUPRFDIG, CUPRFSSB, RTC,
   STEWPERRY, TESLA, WWDIGI.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestMakrothen.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
end;

initialization
   RegisterContest(MAKROTHEN, TContestMakrothen);

end.
