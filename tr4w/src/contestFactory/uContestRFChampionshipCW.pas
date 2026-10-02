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

(* THE RUSSIAN CHAMPIONSHIP (RF CHAMP), CW.

  The ContestsArray row this class states, verbatim:

   Email: 'champ@srr.ru';  DF: 'russian';  WA7BNM: 0;  QRZRUID: 30;
   Pxm: NoPrefixMults;  ZnM: RFChampionchipZones;  AIE: ZoneInitialExchange;  DM: DomesticFile;  P: 0;
   AE: QSONumberAndZone;  XM: NoDXMults;  QP: ChampionshipRFMethod;
   ADIFName: '';  CABName: '';  FriendlyName: ''

  Blank ADIFName, CABName and FriendlyName resolve to the enum's spelling,
  'RF-CHAMP-CW'.

  WHY IT HAS A CLASS NOW. M6 (2026-10-02) moved the final score onto the
  contest, and this contest's formula was LogEdit.TotalScore's
  `ActiveQSOPointMethod = ChampionshipRFMethod` test -- the session's POINT METHOD, so an
  operator's QSO POINT METHOD line reached it in any contest. A class to hold
  that formula needed the whole row and the scoring arm with it, because
  registering a class makes the class this contest's scorer too. Both are
  transcribed exactly; Test_MovedRowValuesStillMatchTheArray holds the row,
  and the contest matrix the rest -- every line of its record but
  `contest.class` is unchanged, its totals included, which is the proof.

  A SIBLING OF THE SSB RUNNING, NOT A FAMILY (design 1.5, Q7). NY4I's ruling that a
  two-mode contest gets a base names NRAU-Baltic only, and extending it to
  every pair is his open Q7 -- so, as with the SAC pair, the runnings are
  siblings and each owns its copy (design 1.4).

  ITS FINAL SCORE: the points PLUS 50 for each multiplier, not times --
  LogEdit.TotalScore's ChampionshipRFMethod arm, moved at M6.

  SCORING, transcribed from ChampionshipRFMethod: a Russian station's oblast
  is the domestic multiplier, and the points are the Championship's table
  (uRFChampionshipPoints, lifted out of LOGSTUFF so this class and the arm
  read one table) by the two zones; anybody else scores 0. *)
unit uContestRFChampionshipCW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRFChampionshipCW = class(TContestBase)
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
   (* RussianID, GetRussiaOblastID -- the leaves the arm asked. *)
   uCallSignRoutines,
   (* The Championship's points table, one copy for both runnings. *)
   uRFChampionshipPoints;

(* ChampionshipRFMethod, transcribed. A Russian station's oblast is its
   domestic multiplier, and the points come from the Championship's table --
   row the station's own zone (MY STATE's first digit, 1 to 7), column the
   worked station's zone. Anything else scores 0, the oblast still set.

   THE DIGIT TEST IS WRITTEN AS TWO COMPARISONS, not a set test: MY STATE is
   a UnicodeString here, and a set test on a wide character is the shape FPC
   warns about; the comparisons say the same thing. *)
procedure TContestRFChampionshipCW.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if RussianID(string(aQso.QTH.CountryID)) then
      begin
      aQso.DomMultQTH := ShortString(GetRussiaOblastID(string(aQso.Callsign)));
      if Station.MyState = '' then
         begin
         Exit;
         end;
      if not ((Station.MyState[1] >= '1') and (Station.MyState[1] <= '7')) then
         begin
         Exit;
         end;
      if not (aQso.Zone in [1..7]) then
         begin
         Exit;
         end;
      aQso.QSOPoints := RFChampionshipPoints[Ord(Station.MyState[1]) - 48 +
                                              (aQso.Zone - 1) * 7];
      end;
end;

function TContestRFChampionshipCW.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := ContestPoints(aTotals) + 50 * SummedMultipliers(aTotals);
end;

function TContestRFChampionshipCW.GetDisplayName: string;
begin
   Result := 'RF-CHAMP-CW';
end;

function TContestRFChampionshipCW.GetCabrilloName: string;
begin
   (* The row's CABName is blank; the Cabrillo header writes the enum's spelling. *)
   Result := 'RF-CHAMP-CW';
end;

function TContestRFChampionshipCW.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'RF-CHAMP-CW';
end;

function TContestRFChampionshipCW.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestRFChampionshipCW.GetQRZRUId: integer;
begin
   Result := 30;
end;

function TContestRFChampionshipCW.GetSubmissionEmail: string;
begin
   Result := 'champ@srr.ru';
end;

function TContestRFChampionshipCW.GetDomesticFileName: string;
begin
   Result := 'russian';
end;

function TContestRFChampionshipCW.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank, which means the enum's spelling. *)
   Result := 'RF-CHAMP-CW';
end;

function TContestRFChampionshipCW.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRFChampionshipCW.GetZoneMultiplierType: ZoneMultType;
begin
   Result := RFChampionchipZones;
end;

function TContestRFChampionshipCW.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestRFChampionshipCW.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestRFChampionshipCW.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestRFChampionshipCW.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberAndZone;
end;

function TContestRFChampionshipCW.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := ChampionshipRFMethod;
end;

function TContestRFChampionshipCW.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestRFChampionshipCW.DescribeSession(const aStation: TStationContext;
                                                   aSession: TSessionDefaults);
begin
   aSession.Mode := CW;
   aSession.DomesticMultByBand := dmbbAllBand;
   aSession.InitialExchangeOverwrite := True;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestRFChampionshipCW.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' ' + aStation.MyState + '#';
end;

initialization
   RegisterContest(RFCHAMPIONSHIPCW, TContestRFChampionshipCW);

end.
