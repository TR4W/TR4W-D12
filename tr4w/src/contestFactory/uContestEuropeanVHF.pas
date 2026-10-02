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

(* THE EUROPEAN VHF CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTQSONumberAndGridSquareExchange;
   XM: NoDXMults;  QP: EuropeanVHFQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'EUROPEAN VHF'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: EuropeanVHFQSOPointMethod -- the distance from our grid to the
  QSO's domestic QTH (its whole QTH when the session's contest name is
  'EURASIA', an event with no ContestType of its own -- inventory D7, design
  Q8; the name arrives as TStationContext.ContestName, M7b). A 9A station's
  points are then multiplied by band: 5 on 432, 10 on 1296, 20 on 2304, 30
  on 3456/5760/10G, 100 on 24G.

  A GRID SHORTER THAN FOUR CHARACTERS is read past its end by
  LOGGRID.ConvertGridToLatLon (design Q37), so such a QSO's points follow
  the heap -- the same function as the arm, called from another frame.

  SET-UP: 6 m, and the HF bands off. *)
unit uContestEuropeanVHF;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestEuropeanVHF = class(TContestBase)
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
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uContestRegistry,
   (* GetDistanceBetweenGrids -- the arm's own geodesic; see
      uContestARRLDigi for why it is the TRDOS unit. *)
   LOGGRID,
   uTR4WStrings;

procedure TContestEuropeanVHF.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if Station.ContestName = 'EURASIA' then
      begin
      aQso.QSOPoints := GetDistanceBetweenGrids(Station.MyGrid, string(aQso.QTHString));
      end
   else
      begin
      aQso.QSOPoints := GetDistanceBetweenGrids(Station.MyGrid, string(aQso.DomesticQTH));
      end;

   if Station.MyCountry = '9A' then
      begin
      if aQso.Band = Band432 then
         begin
         aQso.QSOPoints := aQso.QSOPoints * 5;
         end;
      if aQso.Band = Band1296 then
         begin
         aQso.QSOPoints := aQso.QSOPoints * 10;
         end;
      if aQso.Band = Band2304 then
         begin
         aQso.QSOPoints := aQso.QSOPoints * 20;
         end;
      if aQso.Band in [Band3456, Band5760, Band10G] then
         begin
         aQso.QSOPoints := aQso.QSOPoints * 30;
         end;
      if aQso.Band = Band24G then
         begin
         aQso.QSOPoints := aQso.QSOPoints * 100;
         end;
      end;
end;

function TContestEuropeanVHF.GetDisplayName: string;
begin
   Result := 'EUROPEAN VHF';
end;

function TContestEuropeanVHF.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'EUROPEAN VHF';
end;

function TContestEuropeanVHF.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'EUROPEAN VHF';
end;

function TContestEuropeanVHF.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestEuropeanVHF.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestEuropeanVHF.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestEuropeanVHF.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestEuropeanVHF.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'EUROPEAN VHF';
end;

function TContestEuropeanVHF.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestEuropeanVHF.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestEuropeanVHF.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestEuropeanVHF.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestEuropeanVHF.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestEuropeanVHF.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndGridSquareExchange;
end;

function TContestEuropeanVHF.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := EuropeanVHFQSOPointMethod;
end;

function TContestEuropeanVHF.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestEuropeanVHF.DescribeSession(const aStation: TStationContext;
                                              aSession: TSessionDefaults);
begin
   aSession.Band := Band6;
   aSession.HFEnabled := False;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for OZHCRVHF, RADIOVHFFD.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestEuropeanVHF.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURSIXDIGITGRIDSQUARE, ncfMyGrid);
end;

initialization
   RegisterContest(EUROPEANVHF, TContestEuropeanVHF);

end.
