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

(* THE RU3AX MEMORIAL -- THE RUSSIAN 160-METER DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'russian';  WA7BNM: 202;  QRZRUID: 90;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: DomesticFile;  P: 0;
   AE: RSTDomesticQTHOrQSONumberExchange;  XM: ARRLDXCC;  QP: RussianDXQSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: 'Russian 160-Meter DX Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'RU3AX MEMORIAL'.

  WHY IT HAS A CLASS NOW. M5b (2026-10-02): this contest's initial-exchange
  rule was a test of ActiveQSOPointMethod in ZoneCont.GetVEInitialExchange --
  which an operator's QSO POINT METHOD line reached in any contest. A class to
  hold that rule needed the whole row and the scoring arm with it, because
  registering a class makes the class this contest's scorer too. Both are
  transcribed exactly; Test_MovedRowValuesStillMatchTheArray holds the row,
  and the contest matrix the rest -- every line of its record but
  `contest.class` is unchanged, which is the proof.

  A COPY OF THE RUSSIAN DX CONTEST'S CLASS, AND DELIBERATELY SO (design 1.4). They
  shared one scoring arm, which doubled phone for the RU3AX Memorial by
  asking `if Contest = RU3AXMEMORIAL` inside it; each contest now states its
  own rule and that test is not needed by either.

  SCORING, transcribed from RussianDXQSOPointMethod. A Russian station
  scores 5 for another continent, 3 for another country of its own continent
  and 2 for its own country. Anybody else scores 10 for a Russian station,
  then 5, 3 and 2 the same way. A phone QSO scores double -- the line the
  shared arm asked `if Contest = RU3AXMEMORIAL` for.
  ITS INITIAL EXCHANGE: a Russian station's oblast, from its call. *)
unit uContestRU3AXMemorial;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRU3AXMemorial = class(TContestBase)
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
      (* A RUSSIAN STATION'S OBLAST -- see the header. *)
      function InitialExchangeFromCall(const aStandardCall: string;
                                       const aCountryID: string;
                                       out aExchange: string): boolean; override;
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
   protected
      (* THE TOTALS WINDOW -- see TContestBase.TotalsDisplay (M9a). *)
      function GetTotalsDisplay: TTotalsDisplay; override;
   protected
      (* THE HOUR-BY-HOUR REPORT -- see TContestBase.ReportsRunningScore (M9a). *)
      function GetReportsRunningScore: boolean; override;
   end;

implementation

uses
   uContestRegistry,
   (* RussianID, GetRussiaOblastID -- the leaves the arm and ZoneCont asked. *)
   uCallSignRoutines,
   uTR4WStrings;

procedure TContestRU3AXMemorial.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if RussianID(Station.MyCountry) then
      begin
      if aQso.QTH.Continent <> Station.MyContinent then
         begin
         aQso.QSOPoints := 5;
         end
      else if rxCty <> Station.MyCountry then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      end
   else if RussianID(rxCty) then
      begin
      aQso.QSOPoints := 10;
      end
   else if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 5;
      end
   else if rxCty <> Station.MyCountry then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;

   if aQso.Mode = Phone then
      begin
      aQso.QSOPoints := aQso.QSOPoints * 2;
      end;
end;

function TContestRU3AXMemorial.InitialExchangeFromCall(const aStandardCall: string;
                                                   const aCountryID: string;
                                                   out aExchange: string): boolean;
begin
   aExchange := '';
   Result := (Copy(aCountryID, 1, 1) = 'U') and (Copy(aCountryID, 2, 1) = 'A');
   if Result then
      begin
      aExchange := GetRussiaOblastID(aStandardCall);
      end;
end;

function TContestRU3AXMemorial.GetDisplayName: string;
begin
   Result := 'Russian 160-Meter DX Contest';
end;

function TContestRU3AXMemorial.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'RU3AX MEMORIAL';
end;

function TContestRU3AXMemorial.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'RU3AX MEMORIAL';
end;

function TContestRU3AXMemorial.GetWA7BNMId: integer;
begin
   Result := 202;
end;

function TContestRU3AXMemorial.GetQRZRUId: integer;
begin
   Result := 90;
end;

function TContestRU3AXMemorial.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRU3AXMemorial.GetDomesticFileName: string;
begin
   Result := 'russian';
end;

function TContestRU3AXMemorial.GetFriendlyName: string;
begin
   Result := 'Russian 160-Meter DX Contest';
end;

function TContestRU3AXMemorial.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRU3AXMemorial.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestRU3AXMemorial.GetDXMultiplierType: DXMultType;
begin
   Result := ARRLDXCC;
end;

function TContestRU3AXMemorial.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestRU3AXMemorial.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRU3AXMemorial.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHOrQSONumberExchange;
end;

function TContestRU3AXMemorial.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := RussianDXQSOPointMethod;
end;

function TContestRU3AXMemorial.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named RUSSIANDX, RU3AXMEMORIAL; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestRU3AXMemorial.DescribeSession(const aStation: TStationContext;
                                                aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountries(DomesticCountriesRussia);
   aSession.AddDomesticCountry('CE9');
   if not RussianID(string(aStation.MyCountry)) then
      begin
      aSession.SentState := '';
      end;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestRU3AXMemorial.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' 5NN # ' + aStation.MyState;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for RDA, RUSSIANDX.
   The same steps on ticking the box stood for CIS, RUSSIANDX, UKRAINIAN,
   UNDX.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestRU3AXMemorial.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_RUSSIA);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOUROBLASTID, ncfMyState);
end;

(* THE TOTALS WINDOW LABELS THE DOMESTIC MULTIPLIERS AS OBLASTS -- uTotal's
   arm, moved here at M9a (2026-10-02). It named RUSSIANDX and RU3AXMEMORIAL;
   each holds its own copy (design 1.4). Per mode the labels are the
   default ones, as they always were. *)
function TContestRU3AXMemorial.GetTotalsDisplay: TTotalsDisplay;
begin
   Result := inherited GetTotalsDisplay;
   Result.DomesticMultsCaption := TC_OBLASTS;
end;

(* THE HOUR-BY-HOUR REPORT CARRIES NO RUNNING SCORE -- PostUnit.PrintHourTotals
   named this contest among the seven whose score is not points times
   multipliers hour by hour (M9a, 2026-10-02). Each of the seven holds its own copy (design 1.4). *)
function TContestRU3AXMemorial.GetReportsRunningScore: boolean;
begin
   Result := False;
end;

initialization
   RegisterContest(RU3AXMEMORIAL, TContestRU3AXMemorial);

end.
