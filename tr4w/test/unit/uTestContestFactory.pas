unit uTestContestFactory;
{$I ..\..\src\tr4w.inc}

(*
  THE CONTEST FACTORY HAD NO UNIT COVERAGE OF ANY KIND BEFORE THIS FILE.
  Twenty-odd classes, and not one uContest unit in tr4w_unit_tests.lpr -- so
  the only thing that had ever looked at a contest class was
  test-contest-factory.sh, which compares the factory against the legacy case
  and therefore cannot see anything the legacy case never did.

  THAT MATTERS MOST FOR THE ACCESSORS, because of the failure mode CLAUDE.md
  note 9 describes: a getter nobody overrode returns a legal empty string, and
  an empty ADIF STATE field is indistinguishable from a contest that has none.
  The exhaustive pins below are what make a forgotten override a test failure
  rather than a quiet blank.

  IT CONSTRUCTS CLASSES THROUGH uContestRegistry AND NOT uContestFactory, on
  purpose. uContestFactory reads the program's globals -- LOGWIND's MyContinent
  and the settings model -- which is exactly the dependency uContestBase was
  built to keep out of a contest class. Going through the registry proves that
  property still holds: every class here is constructed and interrogated with
  no part of TR4W running.
*)

interface

uses
   SysUtils, uTR4WTestFramework, VC, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase;

type
   TContestFactoryTests = class(TTestCase)
   protected
      procedure Test_EveryRegisteredContestConstructs;
      procedure Test_EveryStatePartyNamesItsState;
      procedure Test_CountyLineAllowedIsDerivedEverywhere;
      procedure Test_HostStateDerivationIsTheOneTable;
      procedure Test_FloridaIsAStatePartyWithATwoCountyLimit;
      procedure Test_MichiganForbidsCountyLineAgainstTheArray;
      procedure Test_BothPartiesScoreOnePhoneTwoCW;
      procedure Test_CountyCountValidationByContest;
      procedure Test_CountyCountIsInertWhereNoLimitIsKnown;
   public
      procedure RunAllTests; override;
   end;

implementation

(* Builds the registered class for aContest, or nil. The caller frees it --
   these are plain objects, not the factory's cached singleton. *)
function MakeContest(aContest: ContestType): TContestBase;
var
   cls: TContestClass;
begin
   Result := nil;
   cls := ContestClassFor(aContest);
   if cls <> nil then
      begin
      Result := cls.Create(aContest);
      end;
end;

function PointsFor(aContest: TContestBase; aMode: ModeType): integer;
var
   qso: ContestExchange;
begin
   FillChar(qso, SizeOf(qso), 0);
   qso.Mode := aMode;
   aContest.CalculateQSOPoints(qso);
   Result := qso.QSOPoints;
end;

(* EVERY CLASS IS BUILT, not a sample. An abstract method somebody forgot to
   override is a run-time abstract-call error, and this is the only place that
   would meet it before an operator did. *)
procedure TContestFactoryTests.Test_EveryRegisteredContestConstructs;
var
   c: ContestType;
   obj: TContestBase;
   built: integer;
begin
   BeginTest('Test_EveryRegisteredContestConstructs');
   built := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := MakeContest(c);
      if obj = nil then
         begin
         Continue;
         end;
      try
         inc(built);
         CheckTrue(obj.DisplayName <> '',
                   'DisplayName is blank for ' + string(ContestTypeSA[c]));
         CheckTrue(obj.CabrilloName <> '',
                   'CabrilloName is blank for ' + string(ContestTypeSA[c]));
      finally
         obj.Free;
         end;
      end;

   (* A FLOOR, BECAUSE A REGISTRY THAT SILENTLY EMPTIED WOULD PASS EVERY LOOP
      IN THIS FILE. CLAUDE.md: a guard that reports "0 found" and passes is not
      a guard. The number is deliberately well below the real count so adding a
      contest never has to edit this line. *)
   CheckTrue(built >= 10,
             'only ' + IntToStr(built) + ' contest classes constructed -- is the'
             + ' registry linked?');
   CheckEquals(built, RegisteredContestCount,
               'constructed count disagrees with RegisteredContestCount');
end;

(* THE NOTE-9 PIN. A state QSO party whose GetHostState was never overridden
   would answer '' and the ADIF exporter would emit no STATE -- a legal-looking
   blank. TContestStateQSOPartyBase makes the getter abstract so that cannot
   compile; this proves the answer is also the right SHAPE, for every party
   present, and that nothing OUTSIDE the hierarchy claims to be one. *)
procedure TContestFactoryTests.Test_EveryStatePartyNamesItsState;
var
   c: ContestType;
   obj: TContestBase;
   parties: integer;
begin
   BeginTest('Test_EveryStatePartyNamesItsState');
   parties := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := MakeContest(c);
      if obj = nil then
         begin
         Continue;
         end;
      try
         if obj is TContestStateQSOPartyBase then
            begin
            inc(parties);
            CheckTrue(obj.IsUSQSOParty,
                      string(ContestTypeSA[c]) + ' is a state party class but'
                      + ' does not say so');
            CheckEquals(2, Length(obj.HostState),
                        string(ContestTypeSA[c]) + ' HostState is not a'
                        + ' two-letter code: ' + obj.HostState);
            end
         else
            begin
            CheckFalse(obj.IsUSQSOParty,
                       string(ContestTypeSA[c]) + ' claims to be a US QSO'
                       + ' party without being on the state-party base');
            end;
      finally
         obj.Free;
         end;
      end;

   CheckTrue(parties >= 2,
             'expected at least Florida and Michigan, found '
             + IntToStr(parties));
end;

(* THE INVARIANT NY4I ASKED FOR: one stored value, two readings. The boolean is
   non-virtual so this cannot be violated by an override -- which is precisely
   why it is worth asserting: if somebody makes it virtual again, this fails. *)
procedure TContestFactoryTests.Test_CountyLineAllowedIsDerivedEverywhere;
var
   c: ContestType;
   obj: TContestBase;
begin
   BeginTest('Test_CountyLineAllowedIsDerivedEverywhere');
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := MakeContest(c);
      if obj = nil then
         begin
         Continue;
         end;
      try
         CheckTrue(obj.CountyLineAllowed = (obj.CountyLineCountiesMax > 0),
                   string(ContestTypeSA[c])
                   + ': CountyLineAllowed disagrees with the count');
      finally
         obj.Free;
         end;
      end;
end;

(* PROVES THE DRIFT FIX. PostUnit and uADIF each carried a hand-typed 13-arm
   case mapping a QSO party to its state, and New York was in neither -- so its
   ADIF export emitted no STATE at all. The derivation reads ContestsArray's P
   index, so NYQP answers whether or not anyone remembered it. *)
procedure TContestFactoryTests.Test_HostStateDerivationIsTheOneTable;
begin
   BeginTest('Test_HostStateDerivationIsTheOneTable');
   CheckEquals('FL', USQSOPartyStateName(FLORIDAQSOPARTY), 'Florida');
   CheckEquals('MI', USQSOPartyStateName(MICHQSOPARTY), 'Michigan');
   CheckEquals('CA', USQSOPartyStateName(CALQSOPARTY), 'California');

   (* Present in QSOParties, absent from BOTH hand-typed copies. *)
   CheckEquals('NY', USQSOPartyStateName(NYQP),
               'New York -- the omission the derivation fixes');

   (* Not a state QSO party at all: P is zero. *)
   CheckEquals('', USQSOPartyStateName(CQWWCW), 'CQ WW CW has no host state');
   CheckEquals('', USQSOPartyStateName(ARRLFIELDDAY), 'Field Day has none');
end;

procedure TContestFactoryTests.Test_FloridaIsAStatePartyWithATwoCountyLimit;
var
   obj: TContestBase;
begin
   BeginTest('Test_FloridaIsAStatePartyWithATwoCountyLimit');
   obj := MakeContest(FLORIDAQSOPARTY);
   CheckTrue(obj <> nil, 'Florida QSO Party has no registered class');
   try
      CheckTrue(obj is TContestStateQSOPartyBase,
                'Florida is not on the state-party base');
      CheckEquals('FL', obj.HostState, 'Florida host state');
      CheckEquals('Florida QSO Party', obj.DisplayName, 'Florida display name');
      CheckEquals('FCG-FQP', obj.CabrilloName, 'Florida Cabrillo name');
      CheckTrue(obj.IsUSQSOParty, 'Florida is a US QSO party');
      CheckTrue(obj.FormatsExchange, 'Florida owns its exchange columns');

      (* From the published rules: "Florida stations on a county line (maximum
         of two counties) may be claimed as a separate QSO and multiplier from
         each county." *)
      CheckEquals(2, obj.CountyLineCountiesMax, 'Florida allows two counties');
      CheckTrue(obj.CountyLineAllowed, 'Florida allows county-line operation');
   finally
      obj.Free;
      end;
end;

(* THE FIRST DEFECT THE FACTORY CAUGHT, PINNED IN BOTH DIRECTIONS.

   Michigan's rules: "No station may claim simultaneous operation in more than
   one county, state, or province." ContestsArray says CountyLineAllowed: True,
   which is wrong -- and the flag is not inert, because ADIF import uses it to
   suppress dupe flagging when a call reappears on the same band and mode with
   a different QTH.

   BOTH VALUES ARE ASSERTED ON PURPOSE. The array's True is pinned so that
   anybody who later corrects VC.pas is told this override became redundant,
   rather than leaving a contradiction nobody remembers making. *)
procedure TContestFactoryTests.Test_MichiganForbidsCountyLineAgainstTheArray;
var
   obj: TContestBase;
begin
   BeginTest('Test_MichiganForbidsCountyLineAgainstTheArray');
   CheckTrue(ContestsArray[MICHQSOPARTY].CountyLineAllowed,
             'ContestsArray no longer says True for Michigan -- if that was '
             + 'deliberate, the override in TContestMichiganQP is now redundant');

   obj := MakeContest(MICHQSOPARTY);
   CheckTrue(obj <> nil, 'Michigan QSO Party has no registered class');
   try
      CheckTrue(obj is TContestStateQSOPartyBase,
                'Michigan is not on the state-party base');
      CheckEquals('MI', obj.HostState, 'Michigan host state');
      CheckEquals('Michigan QSO Party', obj.DisplayName, 'Michigan display name');
      CheckEquals('MI-QSO-PARTY', obj.CabrilloName, 'Michigan Cabrillo name');
      CheckFalse(obj.FormatsExchange,
                 'Michigan must still use the legacy exchange formatter');
      CheckEquals(0, obj.CountyLineCountiesMax,
                  'Michigan forbids simultaneous operation in two counties');
      CheckFalse(obj.CountyLineAllowed,
                 'the derived boolean must follow the count, not the array');
   finally
      obj.Free;
      end;
end;

(* THE THIRD NUMBER IS THE ONE THAT WOULD BE WRONG SILENTLY. The legacy arm is
   `if Mode = CW then 2 else 1`, so DIGITAL scores the PHONE value -- a
   CW-versus-not model reproduces nine arms and quietly breaks the tenth. *)
procedure TContestFactoryTests.Test_BothPartiesScoreOnePhoneTwoCW;
var
   obj: TContestBase;
begin
   BeginTest('Test_BothPartiesScoreOnePhoneTwoCW');
   obj := MakeContest(FLORIDAQSOPARTY);
   try
      CheckEquals(2, PointsFor(obj, CW), 'Florida CW');
      CheckEquals(1, PointsFor(obj, Phone), 'Florida phone');
      CheckEquals(1, PointsFor(obj, Digital),
                  'Florida digital scores the phone value');
   finally
      obj.Free;
      end;

   obj := MakeContest(MICHQSOPARTY);
   try
      CheckEquals(2, PointsFor(obj, CW), 'Michigan CW');
      CheckEquals(1, PointsFor(obj, Phone), 'Michigan phone');
      CheckEquals(1, PointsFor(obj, Digital),
                  'Michigan digital scores the phone value');
   finally
      obj.Free;
      end;
end;

(* THE VALIDATOR TAKES A COUNT, NEVER A LIST. That is the design rule, and this
   is the test that would have to change first if anybody widened the seam. *)
procedure TContestFactoryTests.Test_CountyCountValidationByContest;
var
   obj: TContestBase;
   msg: string;
begin
   BeginTest('Test_CountyCountValidationByContest');

   obj := MakeContest(FLORIDAQSOPARTY);
   try
      CheckTrue(obj.ValidateCountyCount(1, msg), 'Florida: one county');
      CheckEquals('', msg, 'Florida: no message when accepted');
      CheckTrue(obj.ValidateCountyCount(2, msg),
                'Florida: a county line is two');
      CheckFalse(obj.ValidateCountyCount(3, msg),
                 'Florida: three counties is too many');
      CheckTrue(msg <> '', 'Florida: a refusal must say why');
   finally
      obj.Free;
      end;

   obj := MakeContest(MICHQSOPARTY);
   try
      (* ZERO MEANS NO COUNTY LINE, NOT NO COUNTY. Every domestic exchange
         names one, so one must always pass even where the maximum is zero. *)
      CheckTrue(obj.ValidateCountyCount(1, msg),
                'Michigan: one county is the normal case');
      CheckFalse(obj.ValidateCountyCount(2, msg),
                 'Michigan: no simultaneous operation in two counties');
      CheckTrue(msg <> '', 'Michigan: a refusal must say why');
   finally
      obj.Free;
      end;
end;

(* THE PARTIES WHOSE LIMIT NOBODY HAS READ MUST BEHAVE AS TR4W ALWAYS HAS. A
   party wrongly capped at two would reject a valid three-county junction in
   the middle of a contest -- failing only for the operator who is right, which
   is worse than the uniform permissiveness it replaced.

   California is the proof the shape had to be a count rather than a flag: its
   junctions are four. It has no class, so TContestBase stands in for it here --
   which is exactly what the running program does for it too. *)
procedure TContestFactoryTests.Test_CountyCountIsInertWhereNoLimitIsKnown;
var
   obj: TContestBase;
   msg: string;
begin
   BeginTest('Test_CountyCountIsInertWhereNoLimitIsKnown');
   obj := TContestBase.Create(CALQSOPARTY);
   try
      CheckEquals(CountyLineCountiesUnlimited, obj.CountyLineCountiesMax,
                  'California has no established limit in this tree');
      CheckTrue(obj.CountyLineAllowed,
                'California allows county-line operation');
      CheckTrue(obj.ValidateCountyCount(3, msg), 'unlimited accepts three');
      CheckTrue(obj.ValidateCountyCount(4, msg),
                'unlimited accepts a four-county junction');
      CheckEquals('', msg, 'nothing is refused, so nothing is said');
   finally
      obj.Free;
      end;

   (* And a contest with no county line at all refuses two without needing a
      class of its own. *)
   obj := TContestBase.Create(CQWWCW);
   try
      CheckEquals(0, obj.CountyLineCountiesMax, 'CQ WW has no county line');
      CheckFalse(obj.CountyLineAllowed, 'CQ WW CountyLineAllowed');
      CheckTrue(obj.ValidateCountyCount(1, msg), 'one QTH is always fine');
      CheckFalse(obj.ValidateCountyCount(2, msg),
                 'two counties in CQ WW is nonsense');
   finally
      obj.Free;
      end;
end;

procedure TContestFactoryTests.RunAllTests;
begin
   Test_EveryRegisteredContestConstructs;
   Test_EveryStatePartyNamesItsState;
   Test_CountyLineAllowedIsDerivedEverywhere;
   Test_HostStateDerivationIsTheOneTable;
   Test_FloridaIsAStatePartyWithATwoCountyLimit;
   Test_MichiganForbidsCountyLineAgainstTheArray;
   Test_BothPartiesScoreOnePhoneTwoCW;
   Test_CountyCountValidationByContest;
   Test_CountyCountIsInertWhereNoLimitIsKnown;
end;

end.
