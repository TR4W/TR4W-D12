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

(* THE YURI GAGARIN INTERNATIONAL DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'GC';  WA7BNM: 367;  QRZRUID: 82;
   Pxm: GCStation;  ZnM: ITUZones;  AIE: ZoneInitialExchange;
   DM: WYSIWYGDomestic;  P: 0;  AE: RSTZoneorDomesticQTH;
   XM: NoDXMults;  QP: GagarinCupQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'Yuri Gagarin International DX Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'GAGARIN-CUP'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: GagarinCupQSOPointMethod -- another continent 4, another country
  3, our own 2; tripled on 160 and 80 m, doubled on 40 m; 100 on 2 m and 50
  on 2304 MHz whatever came before; then doubled on phone.

  SET-UP: the R150S list on, the contest name, QSOs by mode, and initial
  exchange overwrite on. *)
unit uContestGagarinCup;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestGagarinCup = class(TContestBase)
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
   uTR4WStrings;

procedure TContestGagarinCup.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 4;
      end
   else if rxCty <> Station.MyCountry then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;

   if aQso.Band in [Band160, Band80] then
      begin
      aQso.QSOPoints := aQso.QSOPoints * 3;
      end;
   if aQso.Band in [Band40] then
      begin
      aQso.QSOPoints := aQso.QSOPoints * 2;
      end;
   if aQso.Band = Band2 then
      begin
      aQso.QSOPoints := 100;
      end;
   if aQso.Band = Band2304 then
      begin
      aQso.QSOPoints := 50;
      end;
   if aQso.Mode = Phone then
      begin
      aQso.QSOPoints := aQso.QSOPoints * 2;
      end;
end;

function TContestGagarinCup.GetDisplayName: string;
begin
   Result := 'Yuri Gagarin International DX Contest';
end;

function TContestGagarinCup.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'GAGARIN-CUP';
end;

function TContestGagarinCup.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'GAGARIN-CUP';
end;

function TContestGagarinCup.GetWA7BNMId: integer;
begin
   Result := 367;
end;

function TContestGagarinCup.GetQRZRUId: integer;
begin
   Result := 82;
end;

function TContestGagarinCup.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestGagarinCup.GetDomesticFileName: string;
begin
   Result := 'GC';
end;

function TContestGagarinCup.GetFriendlyName: string;
begin
   Result := 'Yuri Gagarin International DX Contest';
end;

function TContestGagarinCup.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := GCStation;
end;

function TContestGagarinCup.GetZoneMultiplierType: ZoneMultType;
begin
   Result := ITUZones;
end;

function TContestGagarinCup.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestGagarinCup.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := WYSIWYGDomestic;
end;

function TContestGagarinCup.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestGagarinCup.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneOrDomesticQTH;
end;

function TContestGagarinCup.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := GagarinCupQSOPointMethod;
end;

function TContestGagarinCup.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestGagarinCup.DescribeSession(const aStation: TStationContext;
                                             aSession: TSessionDefaults);
begin
   aSession.R150SMode := True;
   aSession.ContestName := 'Yuri Gagarin International DX Contest';
   aSession.QSOByMode := True;
   aSession.InitialExchangeOverwrite := True;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts. *)
procedure TContestGagarinCup.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_GC);
   aPrompts.AskFieldWithCommentWhenInside(TC_GAGARIN, ncfMyState);
end;

initialization
   RegisterContest(GAGARINCUP, TContestGagarinCup);

end.
