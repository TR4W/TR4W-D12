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

(* EVERY CONTEST STATES ITS RULES -- Q108 S1, 2026-10-16
  (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u).

  A CONTEST RULE HAS NO INHERITED DEFAULT (NY4I): each contest states its
  Cabrillo columns, its STX_STRING, its parse format, its received-exchange
  fields, its set-up flags and its scoring. The base's answer for each is
  neutral -- the error marker, a raise, nothing parsed, nothing marked, the
  empty set, no points -- so a class that FORGETS one is not a compile error
  and not a crash: it is a legal-looking blank (CLAUDE.md note 9).

  THE PIN TABLES CANNOT SEE A NEW CONTEST. uTestCabrilloColumns,
  uTestADIFSentExchange, uTestExchangeParse and uTestExchangeFields freeze
  what each LEGACY contest answers, keyed by ContestType; a contest that
  registers by its string id (Q108 S3) has no member and no row there. So
  this suite asks every REGISTERED contest the one question that needs no
  expected value: does something above TContestBase state the rule -- its
  class or its family base? (uTestRegisteredContests.ClassOverridesTheBase,
  the comparison Test_EveryClassStatesItsIdentity made first.)

  THERE ARE NO EXCEPTIONS, MEASURED. When this suite was written every one
  of the registered contests stated all seven rules (a contest whose
  Cabrillo columns print the error marker calls uCabrilloExchange's
  CabrilloSentNotHandled / CabrilloReceivedNotHandled by name, which is a
  statement). So a contest that answers with the base's code for any of
  them fails here, by name -- a new contest above all. *)
unit uTestContestStatesItsRules;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework, uTestRegisteredContests;

type
   TContestStatesItsRulesTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure CheckEveryContestStates(const aRule: string; aCodeOf: TContestMethodCode);
      procedure Test_EveryContestStatesItsCabrilloSentColumn;
      procedure Test_EveryContestStatesItsCabrilloReceivedColumn;
      procedure Test_EveryContestStatesItsADIFSentExchange;
      procedure Test_EveryContestStatesItsParseFormat;
      procedure Test_EveryContestStatesItsReceivedFields;
      procedure Test_EveryContestStatesItsFlags;
      procedure Test_EveryContestStatesItsScoring;
      procedure Test_TheCheckSeesTheBase;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry;

type
   (* THE PROTECTED RULES, REACHED THE WAY A DESCENDANT REACHES THEM. *)
   TRuleCracker = class(TContestBase);

   TCabrilloColumnGetter = function(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange;
                                    const aCtx: TCabrilloQSOContext): string of object;
   TADIFSentGetter = function(const aMy: TMyStationExchange;
                              const aQso: ContestExchange): string of object;
   TParseFormatter = function(const aText: string; aParsers: TExchangeParsers;
                              var aExch: ContestExchange): boolean of object;
   TFieldsGetter = function: ExchangeInformationRecord of object;
   TFlagsGetter = function: TContestFlags of object;
   TPointsScorer = procedure(var aQso: ContestExchange) of object;

function CabrilloSentCode(aObj: TContestBase): CodePointer;
var
   m: TCabrilloColumnGetter;
begin
   m := TRuleCracker(aObj).GetCabrilloSentExchange;
   Result := TMethod(m).Code;
end;

function CabrilloReceivedCode(aObj: TContestBase): CodePointer;
var
   m: TCabrilloColumnGetter;
begin
   m := TRuleCracker(aObj).GetCabrilloReceivedExchange;
   Result := TMethod(m).Code;
end;

function ADIFSentCode(aObj: TContestBase): CodePointer;
var
   m: TADIFSentGetter;
begin
   m := TRuleCracker(aObj).GetADIFSentExchange;
   Result := TMethod(m).Code;
end;

function ParseFormatCode(aObj: TContestBase): CodePointer;
var
   m: TParseFormatter;
begin
   m := TRuleCracker(aObj).ParseReceivedExchangeFormat;
   Result := TMethod(m).Code;
end;

function ReceivedFieldsCode(aObj: TContestBase): CodePointer;
var
   m: TFieldsGetter;
begin
   m := TRuleCracker(aObj).GetReceivedExchangeFields;
   Result := TMethod(m).Code;
end;

function FlagsCode(aObj: TContestBase): CodePointer;
var
   m: TFlagsGetter;
begin
   m := TRuleCracker(aObj).GetFlags;
   Result := TMethod(m).Code;
end;

function ScoringCode(aObj: TContestBase): CodePointer;
var
   m: TPointsScorer;
begin
   m := TRuleCracker(aObj).CalculateQSOPoints;
   Result := TMethod(m).Code;
end;

(* ------------------------------------------------------------------------ *)

procedure TContestStatesItsRulesTests.CheckEveryContestStates(const aRule: string;
                                                             aCodeOf: TContestMethodCode);
var
   contests: TContestIdentityList;
   k: integer;
begin
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      CheckTrue(ClassOverridesTheBase(contests[k], aCodeOf),
                ContestWho(contests[k]) + ' states its ' + aRule +
                ' (on its class or its family base)');
      end;
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsCabrilloSentColumn;
begin
   BeginTest('Test_EveryContestStatesItsCabrilloSentColumn');
   CheckEveryContestStates('Cabrillo sent column', CabrilloSentCode);
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsCabrilloReceivedColumn;
begin
   BeginTest('Test_EveryContestStatesItsCabrilloReceivedColumn');
   CheckEveryContestStates('Cabrillo received column', CabrilloReceivedCode);
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsADIFSentExchange;
begin
   BeginTest('Test_EveryContestStatesItsADIFSentExchange');
   CheckEveryContestStates('ADIF STX_STRING', ADIFSentCode);
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsParseFormat;
begin
   BeginTest('Test_EveryContestStatesItsParseFormat');
   CheckEveryContestStates('exchange parse format', ParseFormatCode);
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsReceivedFields;
begin
   BeginTest('Test_EveryContestStatesItsReceivedFields');
   CheckEveryContestStates('received-exchange fields', ReceivedFieldsCode);
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsFlags;
begin
   BeginTest('Test_EveryContestStatesItsFlags');
   CheckEveryContestStates('set-up flags', FlagsCode);
end;

procedure TContestStatesItsRulesTests.Test_EveryContestStatesItsScoring;
begin
   BeginTest('Test_EveryContestStatesItsScoring');
   CheckEveryContestStates('scoring (CalculateQSOPoints)', ScoringCode);
end;

(* THE CHECK CAN FAIL -- a negative control: a plain TContestBase states
   none of these, and is seen not to. *)
procedure TContestStatesItsRulesTests.Test_TheCheckSeesTheBase;
var
   base: TContestBase;
begin
   BeginTest('Test_TheCheckSeesTheBase');
   base := TContestBase.Create(NoContest);
   try
      CheckFalse(ClassOverridesTheBase(base, CabrilloSentCode), 'the base states no Cabrillo column');
      CheckFalse(ClassOverridesTheBase(base, ScoringCode), 'the base states no scoring');
   finally
      base.Free;
      end;
end;

procedure TContestStatesItsRulesTests.RunAllTests;
begin
   Test_EveryContestStatesItsCabrilloSentColumn;
   Test_EveryContestStatesItsCabrilloReceivedColumn;
   Test_EveryContestStatesItsADIFSentExchange;
   Test_EveryContestStatesItsParseFormat;
   Test_EveryContestStatesItsReceivedFields;
   Test_EveryContestStatesItsFlags;
   Test_EveryContestStatesItsScoring;
   Test_TheCheckSeesTheBase;
end;

end.
