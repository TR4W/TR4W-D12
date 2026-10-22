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

(* A GRID CONTEST STATES THAT ITS EXCHANGE REQUIRES THE GRID -- Q115 (NY4I,
  2026-10-18: "The contest class should be stating what is required. Some
  contests could allow just rst but most require more data.").

  THE FINDING. The RST-and/or-grid parser (the ARRL January, June and
  September VHF contests, CQ VHF and the Stew Perry) skipped a word that was
  neither a grid nor a number, so '599 FN3' -- a grid one character short --
  logged a QSO with no grid and said nothing. All five sponsors require the
  grid and make the signal report optional:
    * ARRL Jan-Jun-Sep VHF Contest Rules v1.2, rule 4: "the required exchange
      consists of: 4.1 4-character Maidenhead grid-square locator ... 4.2 A
      signal report is optional."
    * cqww-vhf.com/rules.htm IV: "Callsign and Maidenhead grid locator ...
      Signal reports are not required."
    * kkn.net/stew/stew_rules.html: "Four character grid square (i.e. CN85).
      RST is optional."
  So none of the five accepts a signal report alone.

  THROUGH THE REAL ENGINE. Every exchange here goes through
  LOGSTUFF.ProcessExchange with the contest selected -- the class's
  ParseReceivedExchange and the engine's own parser, which
  uTestExchangeParse stubs on purpose. That is the path a typed exchange
  takes from ParametersOkay, and what the operator sees is
  ExchangeErrorMessage and the caret token, ExchangeErrorToken.

  WHAT IS PINNED
    * '599 FN31', 'FN31' and '599 FN31PR' are taken, with the grid;
    * '599 FN3' is refused and names FN3; so is FN3 beside a good grid --
      a bad word is never dropped -- and the leftmost bad word is the one
      named;
    * '599' alone is refused: the grid is required;
    * a grid word is never taken for the worked station's call, which is
      what logged '599 FN31PR' as a QSO with the CALL FN31PR. *)
unit uTestGridExchange;

{$I ..\..\src\tr4w.inc}

interface

uses
   VC,
   uTR4WTestFramework;

type
   TGridExchangeTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_RSTAndGridIsTaken;
      procedure Test_GridAloneIsTaken;
      procedure Test_SixCharacterGridIsTaken;
      procedure Test_ABadGridIsRefusedAndNamed;
      procedure Test_ABadWordIsNeverDropped;
      procedure Test_TheLeftmostBadWordIsNamed;
      procedure Test_RSTAloneIsRefused;
      procedure Test_AGridWordIsNeverACall;
   end;

implementation

uses
   SysUtils,
   uContestBase,
   uContestRegistry,
   uAppStrings,
   LogStuff,
   LogWind,
   PostUnit;

const
   (* The five contests whose class requires the grid -- every user of the
     RST-and/or-grid parser. *)
   GRID_CONTESTS: array[0..4] of ContestType =
      (ARRLVHFJAN, ARRLVHFJUN, ARRLVHFSEP, CQVHF, STEWPERRY);

type
   (* One typed exchange's outcome, as live entry would show it. *)
   TTypedOutcome = record
      Accepted: boolean;
      Exch: ContestExchange;
      Message: string;
      Token: string;
   end;

(* aText typed in aContest on 2 m CW, through LOGSTUFF.ProcessExchange -- the
  engine's own parse, with every global it reads put back. *)
function Typed(aContest: ContestType; const aText: string): TTypedOutcome;
var
   savedContest: TContestHandle;
   savedMode: ModeType;
begin
   Result := Default(TTypedOutcome);
   savedContest := Contest;
   savedMode := ActiveMode;
   try
      Contest := ContestHandleOf(aContest);
      ActiveMode := CW;
      ExchangeErrorMessage := '';
      ExchangeErrorToken := '';
      Result.Exch.Callsign := 'W1AW';
      Result.Exch.Band := Band2;
      Result.Exch.Mode := CW;
      (* The cast is a typed exchange going into the width the engine reads. *)
      Result.Accepted := ProcessExchange(ShortString(aText), Result.Exch);
      Result.Message := ExchangeErrorMessage;
      Result.Token := string(ExchangeErrorToken);
   finally
      ExchangeErrorMessage := '';
      ExchangeErrorToken := '';
      Contest := savedContest;
      ActiveMode := savedMode;
   end;
end;

function Who(aContest: ContestType; const aText: string): string;
begin
   Result := string(ContestTypeSA[aContest]) + ' "' + aText + '"';
end;

procedure TGridExchangeTests.Test_RSTAndGridIsTaken;
var
   i: integer;
   o: TTypedOutcome;
begin
   BeginTest('Test_RSTAndGridIsTaken');
   for i := Low(GRID_CONTESTS) to High(GRID_CONTESTS) do
      begin
      o := Typed(GRID_CONTESTS[i], '599 FN31');
      CheckTrue(o.Accepted, Who(GRID_CONTESTS[i], '599 FN31') + ' is taken');
      CheckEquals('FN31', string(o.Exch.DomesticQTH), Who(GRID_CONTESTS[i], '599 FN31') + ' grid');
      CheckEquals(599, Integer(o.Exch.RSTReceived), Who(GRID_CONTESTS[i], '599 FN31') + ' RST');
      CheckEquals('', o.Message, Who(GRID_CONTESTS[i], '599 FN31') + ' says nothing');
      end;
end;

procedure TGridExchangeTests.Test_GridAloneIsTaken;
var
   i: integer;
   o: TTypedOutcome;
begin
   BeginTest('Test_GridAloneIsTaken');
   for i := Low(GRID_CONTESTS) to High(GRID_CONTESTS) do
      begin
      o := Typed(GRID_CONTESTS[i], 'FN31');
      CheckTrue(o.Accepted, Who(GRID_CONTESTS[i], 'FN31') + ' is taken: the report is optional');
      CheckEquals('FN31', string(o.Exch.DomesticQTH), Who(GRID_CONTESTS[i], 'FN31') + ' grid');
      (* The RST the parser has always defaulted on CW. *)
      CheckEquals(599, Integer(o.Exch.RSTReceived), Who(GRID_CONTESTS[i], 'FN31') + ' default RST');
      end;
end;

procedure TGridExchangeTests.Test_SixCharacterGridIsTaken;
var
   i: integer;
   o: TTypedOutcome;
begin
   BeginTest('Test_SixCharacterGridIsTaken');
   for i := Low(GRID_CONTESTS) to High(GRID_CONTESTS) do
      begin
      o := Typed(GRID_CONTESTS[i], '599 FN31PR');
      CheckTrue(o.Accepted, Who(GRID_CONTESTS[i], '599 FN31PR') + ' is taken');
      CheckEquals('FN31PR', string(o.Exch.DomesticQTH), Who(GRID_CONTESTS[i], '599 FN31PR') + ' grid');
      end;
end;

procedure TGridExchangeTests.Test_ABadGridIsRefusedAndNamed;
var
   i: integer;
   o: TTypedOutcome;
begin
   BeginTest('Test_ABadGridIsRefusedAndNamed');
   for i := Low(GRID_CONTESTS) to High(GRID_CONTESTS) do
      begin
      o := Typed(GRID_CONTESTS[i], '599 FN3');
      CheckFalse(o.Accepted, Who(GRID_CONTESTS[i], '599 FN3') + ' is refused');
      CheckEquals(Format(SExchangeNotAGridOrReport, ['FN3']), o.Message,
                  Who(GRID_CONTESTS[i], '599 FN3') + ' names the word');
      CheckEquals('FN3', o.Token, Who(GRID_CONTESTS[i], '599 FN3') + ' caret token');
      CheckEquals('', string(o.Exch.DomesticQTH), Who(GRID_CONTESTS[i], '599 FN3') + ' no grid kept');
      end;
end;

procedure TGridExchangeTests.Test_ABadWordIsNeverDropped;
var
   i: integer;
   o: TTypedOutcome;
begin
   BeginTest('Test_ABadWordIsNeverDropped');
   (* The old parser kept FN31 and skipped FN3: a good grid beside a bad word
     does not excuse it. *)
   for i := Low(GRID_CONTESTS) to High(GRID_CONTESTS) do
      begin
      o := Typed(GRID_CONTESTS[i], '599 FN3 FN31');
      CheckFalse(o.Accepted, Who(GRID_CONTESTS[i], '599 FN3 FN31') + ' is refused');
      CheckEquals('FN3', o.Token, Who(GRID_CONTESTS[i], '599 FN3 FN31') + ' names FN3');
      end;
end;

procedure TGridExchangeTests.Test_TheLeftmostBadWordIsNamed;
var
   i: integer;
   o: TTypedOutcome;
begin
   BeginTest('Test_TheLeftmostBadWordIsNamed');
   for i := Low(GRID_CONTESTS) to High(GRID_CONTESTS) do
      begin
      o := Typed(GRID_CONTESTS[i], 'XX 599 YY FN31');
      CheckFalse(o.Accepted, Who(GRID_CONTESTS[i], 'XX 599 YY FN31') + ' is refused');
      CheckEquals('XX', o.Token, Who(GRID_CONTESTS[i], 'XX 599 YY FN31') + ' names the first typed');
      end;
end;

procedure TGridExchangeTests.Test_RSTAloneIsRefused;
var
   i: integer;
   o: TTypedOutcome;
begin
   BeginTest('Test_RSTAloneIsRefused');
   for i := Low(GRID_CONTESTS) to High(GRID_CONTESTS) do
      begin
      o := Typed(GRID_CONTESTS[i], '599');
      CheckFalse(o.Accepted, Who(GRID_CONTESTS[i], '599') + ' is refused: the grid is required');
      CheckEquals(SExchangeGridRequired, o.Message, Who(GRID_CONTESTS[i], '599') + ' says so');
      end;
end;

procedure TGridExchangeTests.Test_AGridWordIsNeverACall;
var
   i: integer;
   savedContest: TContestHandle;
begin
   BeginTest('Test_AGridWordIsNeverACall');
   for i := Low(GRID_CONTESTS) to High(GRID_CONTESTS) do
      begin
      CheckFalse(ContestIdentity(GRID_CONTESTS[i]).MayBeACallsign('FN31PR'),
                 string(ContestTypeSA[GRID_CONTESTS[i]]) + ': FN31PR is a grid, not a call');
      CheckTrue(ContestIdentity(GRID_CONTESTS[i]).MayBeACallsign('W1AW'),
                string(ContestTypeSA[GRID_CONTESTS[i]]) + ': a call is still a call');
      end;

   (* THE ENGINE'S QUESTION, which is what the call window asks. The control:
     in a contest with no grid, FN31PR has a call's shape -- which is how it
     became the call. *)
   savedContest := Contest;
   try
      Contest := ContestHandleOf(ARRLVHFJAN);
      CheckFalse(LooksLikeACallSign('FN31PR'), 'ARRL-VHF-JAN: the engine reads FN31PR as no call');
      Contest := ContestHandleOf(CQWWCW);
      CheckTrue(LooksLikeACallSign('FN31PR'), 'CQ-WW-CW: FN31PR has a call''s shape (the control)');
   finally
      Contest := savedContest;
   end;
end;

procedure TGridExchangeTests.RunAllTests;
begin
   Test_RSTAndGridIsTaken;
   Test_GridAloneIsTaken;
   Test_SixCharacterGridIsTaken;
   Test_ABadGridIsRefusedAndNamed;
   Test_ABadWordIsNeverDropped;
   Test_TheLeftmostBadWordIsNamed;
   Test_RSTAloneIsRefused;
   Test_AGridWordIsNeverACall;
end;

end.
