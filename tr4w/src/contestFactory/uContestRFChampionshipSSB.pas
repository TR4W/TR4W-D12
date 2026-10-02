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

(* THE RUSSIAN CHAMPIONSHIP (RF CHAMP), SSB.

  The ContestsArray row this class states, verbatim:

   Email: 'champ@srr.ru';  DF: 'russian';  WA7BNM: 0;  QRZRUID: 28;
   Pxm: NoPrefixMults;  ZnM: RFChampionchipZones;  AIE: ZoneInitialExchange;  DM: DomesticFile;  P: 0;
   AE: QSONumberAndZone;  XM: NoDXMults;  QP: ChampionshipRFMethod;
   ADIFName: '';  CABName: '';  FriendlyName: ''

  Blank ADIFName, CABName and FriendlyName resolve to the enum's spelling,
  'RF-CHAMP-SSB'.

  WHY IT HAS A CLASS NOW. M6 (2026-10-02) moved the final score onto the
  contest, and this contest's formula was LogEdit.TotalScore's
  `ActiveQSOPointMethod = ChampionshipRFMethod` test -- the session's POINT METHOD, so an
  operator's QSO POINT METHOD line reached it in any contest. A class to hold
  that formula needed the whole row and the scoring arm with it, because
  registering a class makes the class this contest's scorer too. Both are
  transcribed exactly; Test_MovedRowValuesStillMatchTheArray holds the row,
  and the contest matrix the rest -- every line of its record but
  `contest.class` is unchanged, its totals included, which is the proof.

  A SIBLING OF THE CW RUNNING, NOT A FAMILY (design 1.5, Q7). NY4I's ruling that a
  two-mode contest gets a base names NRAU-Baltic only, and extending it to
  every pair is his open Q7 -- so, as with the SAC pair, the runnings are
  siblings and each owns its copy (design 1.4).

  ITS FINAL SCORE: the points PLUS 50 for each multiplier, not times --
  LogEdit.TotalScore's ChampionshipRFMethod arm, moved at M6.

  SCORING, transcribed from ChampionshipRFMethod: a Russian station's oblast
  is the domestic multiplier, and the points are the Championship's table
  (uRFChampionshipPoints, lifted out of LOGSTUFF so this class and the arm
  read one table) by the two zones; anybody else scores 0. *)
unit uContestRFChampionshipSSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRFChampionshipSSB = class(TContestBase)
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

      (* A RUSSIAN CALL'S OBLAST, FOR THE NEED-MULTIPLIER HINT -- the arm
         LOGEDIT.GetMultArray held for this contest beside the Russian DX
         contest and the CW running, moved here at M8 and transcribed
         exactly: RussianID of the CALL (not of its country), and its
         oblast from GetRussiaOblastID. *)
      function DomesticMultiplierFromCall(const aCall: string;
                                          const aLookups: TMultiplierHintLookups): string; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   protected
      (* THE HOUR-BY-HOUR REPORT -- see TContestBase.ReportsRunningScore (M9a). *)
      function GetReportsRunningScore: boolean; override;
   end;

implementation

uses
   uContestRegistry,
   (* RussianID, GetRussiaOblastID -- the leaves the arm asked. *)
   uCallSignRoutines,
   (* The Championship's points table, one copy for both runnings. *)
   uRFChampionshipPoints,
   uTR4WStrings;

function TContestRFChampionshipSSB.DomesticMultiplierFromCall(const aCall: string;
                                                              const aLookups: TMultiplierHintLookups): string;
begin
   Result := '';
   if RussianID(aCall) then
      begin
      Result := GetRussiaOblastID(aCall);
      end;
end;

(* ChampionshipRFMethod, transcribed. A Russian station's oblast is its
   domestic multiplier, and the points come from the Championship's table --
   row the station's own zone (MY STATE's first digit, 1 to 7), column the
   worked station's zone. Anything else scores 0, the oblast still set.

   THE DIGIT TEST IS WRITTEN AS TWO COMPARISONS, not a set test: MY STATE is
   a UnicodeString here, and a set test on a wide character is the shape FPC
   warns about; the comparisons say the same thing. *)
procedure TContestRFChampionshipSSB.CalculateQSOPoints(var aQso: ContestExchange);
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

function TContestRFChampionshipSSB.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := ContestPoints(aTotals) + 50 * SummedMultipliers(aTotals);
end;

function TContestRFChampionshipSSB.GetDisplayName: string;
begin
   Result := 'RF-CHAMP-SSB';
end;

function TContestRFChampionshipSSB.GetCabrilloName: string;
begin
   (* The row's CABName is blank; the Cabrillo header writes the enum's spelling. *)
   Result := 'RF-CHAMP-SSB';
end;

function TContestRFChampionshipSSB.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'RF-CHAMP-SSB';
end;

function TContestRFChampionshipSSB.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestRFChampionshipSSB.GetQRZRUId: integer;
begin
   Result := 28;
end;

function TContestRFChampionshipSSB.GetSubmissionEmail: string;
begin
   Result := 'champ@srr.ru';
end;

function TContestRFChampionshipSSB.GetDomesticFileName: string;
begin
   Result := 'russian';
end;

function TContestRFChampionshipSSB.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank, which means the enum's spelling. *)
   Result := 'RF-CHAMP-SSB';
end;

function TContestRFChampionshipSSB.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRFChampionshipSSB.GetZoneMultiplierType: ZoneMultType;
begin
   Result := RFChampionchipZones;
end;

function TContestRFChampionshipSSB.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestRFChampionshipSSB.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestRFChampionshipSSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestRFChampionshipSSB.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberAndZone;
end;

function TContestRFChampionshipSSB.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := ChampionshipRFMethod;
end;

function TContestRFChampionshipSSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestRFChampionshipSSB.DescribeSession(const aStation: TStationContext;
                                                    aSession: TSessionDefaults);
begin
   aSession.Mode := Phone;
   aSession.DomesticMultByBand := dmbbAllBand;
   aSession.InitialExchangeOverwrite := True;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestRFChampionshipSSB.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' ' + aStation.MyState + '#';
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for RFCHAMPIONSHIPCW.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestRFChampionshipSSB.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURZONE, ncfMyState);
end;

(* THE HOUR-BY-HOUR REPORT CARRIES NO RUNNING SCORE -- PostUnit.PrintHourTotals
   named this contest among the seven whose score is not points times
   multipliers hour by hour (M9a, 2026-10-02). Each of the seven holds its own copy (design 1.4). *)
function TContestRFChampionshipSSB.GetReportsRunningScore: boolean;
begin
   Result := False;
end;

initialization
   RegisterContest(RFCHAMPIONSHIPSSB, TContestRFChampionshipSSB);

end.
