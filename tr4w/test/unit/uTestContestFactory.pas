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
   SysUtils,
   (* Ceil and GetDistanceBetweenGrids -- the ARRL Digital distance rule is
      checked against the same geodesic the class uses, so the assertion pins
      the RULE rather than the geodesic's constants. *)
   Math, LogGrid,
   uTR4WTestFramework, VC, uContestBase, uContestRegistry,
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
      procedure Test_ArktikaSpringScoresOnTheDomesticMultiplierQTH;
      procedure Test_ArktikaSpringOwnsTheNarrowCabrilloLine;
      procedure Test_ARRLDigiScoresByGridDistance;
      procedure Test_ARRLDigiScoresNothingWithoutBothGrids;
      procedure Test_TenStatePartiesScoreTheirLegacyArms;
      procedure Test_TenStatePartiesCountyLineMaxima;
      procedure Test_MovedRowValuesStillMatchTheArray;
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
   why it is worth asserting: if somebody makes it virtual again, this fails.

   IT WALKS THE STATE QSO PARTIES AND NOT EVERY CONTEST, since 2026-09-29. The
   two accessors moved off TContestBase onto TContestStateQSOPartyBase, so the
   loop below no longer COMPILES for a contest that is not a party -- which is
   the guard, not an inconvenience. NY4I: "Arktika Spring is clearly not a qso
   party so I am not sure why that would be in the conversation of two
   counties." *)
procedure TContestFactoryTests.Test_CountyLineAllowedIsDerivedEverywhere;
var
   c: ContestType;
   obj: TContestBase;
   party: TContestStateQSOPartyBase;
   checked: integer;
begin
   BeginTest('Test_CountyLineAllowedIsDerivedEverywhere');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := MakeContest(c);
      if obj = nil then
         begin
         Continue;
         end;
      try
         if not (obj is TContestStateQSOPartyBase) then
            begin
            Continue;
            end;
         party := TContestStateQSOPartyBase(obj);
         inc(checked);
         CheckTrue(party.CountyLineAllowed = (party.CountyLineCountiesMax > 0),
                   string(ContestTypeSA[c])
                   + ': CountyLineAllowed disagrees with the count');
      finally
         obj.Free;
         end;
      end;

   (* A FLOOR: a loop that checked nothing would pass silently. *)
   CheckTrue(checked >= 2,
             'expected at least Florida and Michigan, checked '
             + IntToStr(checked));
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
         each county."

         READ THROUGH THE PARTY BASE, because that is where the county-line
         accessors live -- a plain TContestBase reference cannot ask. *)
      CheckEquals(2, TContestStateQSOPartyBase(obj).CountyLineCountiesMax,
                  'Florida allows two counties');
      CheckTrue(TContestStateQSOPartyBase(obj).CountyLineAllowed,
                'Florida allows county-line operation');
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
      CheckEquals(0, TContestStateQSOPartyBase(obj).CountyLineCountiesMax,
                  'Michigan forbids simultaneous operation in two counties');
      CheckFalse(TContestStateQSOPartyBase(obj).CountyLineAllowed,
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
   is the test that would have to change first if anybody widened the seam.

   IT IS CALLED ValidateQTHCount NOW, on TContestBase, because LOGSTUFF asks it
   about every contest and most contests have no counties. Only a state QSO
   party overrides it, and only a state QSO party can refuse. *)
procedure TContestFactoryTests.Test_CountyCountValidationByContest;
var
   obj: TContestBase;
   msg: string;
begin
   BeginTest('Test_CountyCountValidationByContest');

   obj := MakeContest(FLORIDAQSOPARTY);
   try
      CheckTrue(obj.ValidateQTHCount(1, msg), 'Florida: one county');
      CheckEquals('', msg, 'Florida: no message when accepted');
      CheckTrue(obj.ValidateQTHCount(2, msg),
                'Florida: a county line is two');
      CheckFalse(obj.ValidateQTHCount(3, msg),
                 'Florida: three counties is too many');
      CheckTrue(msg <> '', 'Florida: a refusal must say why');
   finally
      obj.Free;
      end;

   obj := MakeContest(MICHQSOPARTY);
   try
      (* ZERO MEANS NO COUNTY LINE, NOT NO COUNTY. Every domestic exchange
         names one, so one must always pass even where the maximum is zero. *)
      CheckTrue(obj.ValidateQTHCount(1, msg),
                'Michigan: one county is the normal case');
      CheckFalse(obj.ValidateQTHCount(2, msg),
                 'Michigan: no simultaneous operation in two counties');
      CheckTrue(msg <> '', 'Michigan: a refusal must say why');
   finally
      obj.Free;
      end;
end;

(* THE REGRESSION THIS TEST NOW EXISTS TO PREVENT, AND IT IS NOT HYPOTHETICAL.

   While the county-line rule lived on TContestBase, the inherited maximum read
   ContestsArray's CountyLineAllowed boolean -- and a row without that field
   answered ZERO, which REFUSES a second QTH. So the moment a contest acquired a
   class of any kind, LOGSTUFF.ApplyFirstQTHAndQueueRest started rejecting a
   two-QTH exchange for it, for a contest that has nothing to do with counties.
   Arktika Spring hit exactly that on the day it was moved, and the comment at
   the LOGSTUFF call site claimed the opposite in terms.

   THE BASE NOW ALWAYS PASSES, so all three of these are the same answer:
   a contest with no class, a contest with a class that is not a QSO party, and
   TR4W before the factory existed.

   THIS ALSO USED TO ASSERT CALIFORNIA'S UNLIMITED COUNT THROUGH A PLAIN
   TContestBase, which no longer compiles -- the accessors are on the party
   base. That assertion moved to the party base's own default, exercised by
   Florida and Michigan above and by the unlimited-by-default rule they
   override. *)
procedure TContestFactoryTests.Test_CountyCountIsInertWhereNoLimitIsKnown;
var
   obj: TContestBase;
   msg: string;
begin
   BeginTest('Test_CountyCountIsInertWhereNoLimitIsKnown');

   (* A CONTEST WITH NO CLASS AT ALL -- what the program does for most of the
      table. TContestBase stands in for it here exactly as it does at run time.

      IT USED TO BE CALQSOPARTY AND CANNOT BE ANY MORE: California acquired a
      class on 2026-09-29, and a state party with a stated maximum is the one
      kind of contest that CAN refuse. The New York QSO Party is a genuine
      single-state party with no class yet, so it is what the program still
      does for the majority of the table. Its four-county assertion is the same
      one, made where it is still true. *)
   obj := TContestBase.Create(NYQP);
   try
      CheckTrue(obj.ValidateQTHCount(3, msg), 'no class: three QTHs pass');
      CheckTrue(obj.ValidateQTHCount(4, msg),
                'no class: a four-county junction passes');
      CheckEquals('', msg, 'nothing is refused, so nothing is said');
   finally
      obj.Free;
      end;

   obj := TContestBase.Create(CQWWCW);
   try
      CheckTrue(obj.ValidateQTHCount(1, msg), 'one QTH is always fine');
      CheckTrue(obj.ValidateQTHCount(2, msg),
                'CQ WW has no QTH-count rule, so it states none');
   finally
      obj.Free;
      end;

   (* AND THE TWO CONTESTS THE DEFECT WAS FOUND ON. Both have classes, neither
      is a QSO party, and both must accept what TR4W accepted before they were
      moved. *)
   obj := MakeContest(ARKTIKA_SPRING);
   CheckTrue(obj <> nil, 'Arktika Spring has no registered class');
   try
      CheckTrue(obj.ValidateQTHCount(2, msg),
                'Arktika Spring must still accept a two-QTH exchange');
      CheckEquals('', msg, 'Arktika Spring: nothing refused, nothing said');
      CheckFalse(obj is TContestStateQSOPartyBase,
                 'Arktika Spring is not a QSO party and must not be one');
   finally
      obj.Free;
      end;

   obj := MakeContest(ARRLDIGI);
   try
      CheckTrue(obj.ValidateQTHCount(2, msg),
                'ARRL Digital must still accept a two-QTH exchange');
      CheckFalse(obj is TContestStateQSOPartyBase,
                 'ARRL Digital is not a QSO party and must not be one');
   finally
      obj.Free;
      end;

   (* Field Day likewise -- it lost a county override in the same change. *)
   obj := MakeContest(ARRLFIELDDAY);
   try
      CheckTrue(obj.ValidateQTHCount(2, msg),
                'ARRL Field Day has no QTH-count rule either');
   finally
      obj.Free;
      end;
end;

(* ---------------------------------------------------------------------------
   ARKTIKA SPRING
   ------------------------------------------------------------------------ *)

(* THREE POINTS FOR A DOMESTIC MULTIPLIER QTH, ONE FOR EVERYTHING ELSE.

   THE FIELD IS DomMultQTH AND NOT DomesticQTH, and that is what this pins. The
   two are separate fields on ContestExchange and the legacy arm reads the
   multiplier one; a class that reached for the more familiar DomesticQTH would
   score every QSO of a log the same way as long as the two happened to agree,
   and nothing in the corpus would say otherwise. So the second case below sets
   DomesticQTH WITHOUT DomMultQTH and requires one point -- it is the assertion
   that fails if the wrong field is read. *)
procedure TContestFactoryTests.Test_ArktikaSpringScoresOnTheDomesticMultiplierQTH;
var
   obj: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('Test_ArktikaSpringScoresOnTheDomesticMultiplierQTH');
   obj := MakeContest(ARKTIKA_SPRING);
   CheckTrue(obj <> nil, 'Arktika Spring has no registered class');
   try
      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := CW;
      qso.DomMultQTH := 'AR';
      obj.CalculateQSOPoints(qso);
      CheckEquals(3, qso.QSOPoints, 'a domestic multiplier QTH is three points');

      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := CW;
      qso.DomesticQTH := 'AR';
      obj.CalculateQSOPoints(qso);
      CheckEquals(1, qso.QSOPoints,
                  'the rule reads DomMultQTH, not DomesticQTH');

      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := Phone;
      obj.CalculateQSOPoints(qso);
      CheckEquals(1, qso.QSOPoints, 'no domestic multiplier QTH is one point');

      (* MODE DOES NOT ENTER INTO IT, which is worth pinning because most of
         the arms around this one are mode-shaped. *)
      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := Digital;
      qso.DomMultQTH := 'AR';
      obj.CalculateQSOPoints(qso);
      CheckEquals(3, qso.QSOPoints, 'digital scores the same three points');
   finally
      obj.Free;
      end;
end;

(* THE NARROWER CABRILLO QSO LINE, which used to be an `if Contest =
   ARKTIKA_SPRING` in PostUnit. Every other contest -- class or no class --
   must still get the default, so both halves are asserted: a base object
   standing in for a contest nobody has moved, and a moved contest that does
   not override. *)
procedure TContestFactoryTests.Test_ArktikaSpringOwnsTheNarrowCabrilloLine;
var
   obj: TContestBase;
begin
   BeginTest('Test_ArktikaSpringOwnsTheNarrowCabrilloLine');
   obj := MakeContest(ARKTIKA_SPRING);
   try
      CheckEquals('%s%-12s%-10s%-10s' + #13#10, obj.CabrilloQSOLineFormat,
                  'Arktika Spring uses the four-argument layout');
   finally
      obj.Free;
      end;

   obj := TContestBase.Create(CQWWCW);
   try
      CheckEquals(CabrilloQSOLineFormatDefault, obj.CabrilloQSOLineFormat,
                  'the base answers the default layout');
   finally
      obj.Free;
      end;

   obj := MakeContest(FLORIDAQSOPARTY);
   try
      CheckEquals(CabrilloQSOLineFormatDefault, obj.CabrilloQSOLineFormat,
                  'a moved contest that does not override keeps the default');
   finally
      obj.Free;
      end;
end;

(* ---------------------------------------------------------------------------
   ARRL INTERNATIONAL DIGITAL
   ------------------------------------------------------------------------ *)

(* ONE POINT PER 500 KM BEGUN, PLUS ONE; TWO FOR THE SAME GRID.

   THE KNOWN DISTANCE IS COMPUTED, NOT TYPED. Hardcoding "EL88 to CM87 is N
   points" would pin this test to LOGGRID.GetDistanceBetweenGrids's exact
   geodesic, and the point of the assertion is the RULE -- Ceil(km/500)+1 --
   not the geodesic's constants. So the expected value is derived from the same
   function the class calls, and what is really being pinned is that the class
   applies the rule to the distance rather than, say, dividing by 1000 or
   truncating instead of rounding up.

   THE SAME-GRID CASE IS THE ONE THE LEGACY ARM SPECIAL-CASES:
   GetDistanceBetweenGrids returns 0 for two equal grids, so the general rule
   would give Ceil(0)+1 = 1, and the contest says 2. A class that dropped the
   special case would be wrong by exactly one point on every in-grid QSO and
   would still look arithmetically sane. *)
procedure TContestFactoryTests.Test_ARRLDigiScoresByGridDistance;
var
   obj: TContestBase;
   station: TStationContext;
   qso: ContestExchange;
   km : integer;
begin
   BeginTest('Test_ARRLDigiScoresByGridDistance');
   obj := MakeContest(ARRLDIGI);
   CheckTrue(obj <> nil, 'ARRL Digital has no registered class');
   try
      FillChar(station, SizeOf(station), 0);
      station.MyGrid := 'EL88';
      obj.SetStation(station);

      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := Digital;
      qso.QTHString := 'EL88';
      qso.DomesticQTH := 'EL88';
      obj.CalculateQSOPoints(qso);
      CheckEquals(2, qso.QSOPoints, 'a station in our own grid is two points');

      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := Digital;
      qso.QTHString := 'CM87';
      qso.DomesticQTH := 'CM87';
      obj.CalculateQSOPoints(qso);
      km := GetDistanceBetweenGrids('EL88', 'CM87');
      CheckTrue(km > 3000, 'EL88 to CM87 should be a transcontinental hop');
      CheckEquals(Ceil(km / 500) + 1, qso.QSOPoints,
                  'one point per 500 km begun, plus one');

      (* A SHORT HOP IS THE OTHER END OF THE SAME RULE: under 500 km scores the
         plus-one alone, which is 2 -- the same number as the same-grid case
         and arrived at a different way. *)
      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := Digital;
      qso.QTHString := 'EL98';
      qso.DomesticQTH := 'EL98';
      obj.CalculateQSOPoints(qso);
      km := GetDistanceBetweenGrids('EL88', 'EL98');
      CheckTrue(km > 0, 'EL88 and EL98 are different grids');
      CheckTrue(km < 500, 'EL88 to EL98 is one grid square east');
      CheckEquals(2, qso.QSOPoints, 'under 500 km is the plus-one alone');
   finally
      obj.Free;
      end;
end;

(* THE GUARD, AND IT SCORES ZERO RATHER THAN FALLING THROUGH.

   The legacy arm has NO else: CalculateQSOPoints zeroes QSOPoints on entry and
   the arm simply does not run. That is easy to reproduce by accident and easy
   to break by accident -- a class that left the record alone would hand back
   whatever the caller had in it, which is why the record below arrives holding
   99. Both guards are pinned: no grid of ours, and no domestic QTH of
   theirs. *)
procedure TContestFactoryTests.Test_ARRLDigiScoresNothingWithoutBothGrids;
var
   obj: TContestBase;
   station: TStationContext;
   qso: ContestExchange;
begin
   BeginTest('Test_ARRLDigiScoresNothingWithoutBothGrids');
   obj := MakeContest(ARRLDIGI);
   try
      (* OUR grid missing. *)
      FillChar(station, SizeOf(station), 0);
      station.MyGrid := '';
      obj.SetStation(station);

      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := Digital;
      qso.QTHString := 'CM87';
      qso.DomesticQTH := 'CM87';
      qso.QSOPoints := 99;
      obj.CalculateQSOPoints(qso);
      CheckEquals(0, qso.QSOPoints, 'no grid of ours scores zero, not 99');

      (* THEIR domestic QTH missing, ours present. *)
      FillChar(station, SizeOf(station), 0);
      station.MyGrid := 'EL88';
      obj.SetStation(station);

      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := Digital;
      qso.QTHString := 'CM87';
      qso.QSOPoints := 99;
      obj.CalculateQSOPoints(qso);
      CheckEquals(0, qso.QSOPoints,
                  'the guard is on DomesticQTH, and it scores zero');
   finally
      obj.Free;
      end;
end;

(* ---------------------------------------------------------------------------
   THE ROW, MOVED INTO THE CLASS
   ------------------------------------------------------------------------ *)

(* A TRANSCRIPTION GUARD, AND IT IS NOT A TAUTOLOGY.

   NY4I, 2026-09-29: "all the info in [the ContestsArray row] should go into the
   contest class."  A class that states its row as literals has copied fourteen
   values by hand, and a mistyped one is a legal value in the right type --
   CLAUDE.md note 9 exactly. Nothing else in this tree would notice: no gate
   reads WA7BNMId, SubmissionEmail or InitialExchangeKind.

   SO THE EXPECTED SIDE IS A PLAIN TContestBase ON THE SAME ContestType, which
   still reads the array. It compares the literal against the value it was
   copied from, through the same accessor, including the two-step Cabrillo
   fallback -- so it also pins that a blank CABName still yields the enum's
   spelling rather than a blank CONTEST: line.

   IT STOPS BEING USEFUL THE DAY ContestsArray GOES, and that is correct: at
   that point the class IS the definition and there is nothing left to compare
   against. Delete it then, not before. *)
(* ---------------------------------------------------------------------------
   THE TEN STATE QSO PARTIES MOVED ON 2026-09-29
   ------------------------------------------------------------------------ *)

(* EVERY ONE OF THEM IS PINNED IN DIGITAL, AND THAT IS THE POINT OF THE TEST.

   All four point methods these ten use are written in LOGSTUFF as either a
   bare assignment or `if Mode = CW then X else Y`. The two-branch shape gives
   DIGITAL the PHONE value -- checked arm by arm in logstuff.pas, because some
   arms elsewhere in that case are written `if Mode = PHONE then X else Y` and
   hand digital the CW value instead. Nothing distinguishes the two by
   inspection of the class, so the digital case is asserted for all ten rather
   than for the ones that look interesting.

   THE FLAT METHODS ARE ASSERTED IN DIGITAL TOO. ThreePointsPerQSO and
   TwoPointsPerQSO cannot get it wrong today, and the assertion is what would
   catch somebody "tidying" three equal numbers into a mode test later. *)
procedure TContestFactoryTests.Test_TenStatePartiesScoreTheirLegacyArms;

   procedure CheckPoints(aContest: ContestType; const aWhat: string;
                         aCW, aPhone, aDigital: integer);
   var
      obj: TContestBase;
   begin
      obj := MakeContest(aContest);
      CheckTrue(obj <> nil, aWhat + ' has no registered class');
      if obj = nil then
         begin
         Exit;
         end;
      try
         CheckEquals(aCW, PointsFor(obj, CW), aWhat + ' CW');
         CheckEquals(aPhone, PointsFor(obj, Phone), aWhat + ' phone');
         CheckEquals(aDigital, PointsFor(obj, Digital),
                     aWhat + ' digital -- the third argument to FixedModePoints');
      finally
         obj.Free;
         end;
   end;

begin
   BeginTest('Test_TenStatePartiesScoreTheirLegacyArms');

   (* ThreePointsPerQSO: RXData.QSOPoints := 3, whatever the mode. *)
   CheckPoints(CALQSOPARTY, 'California', 3, 3, 3);

   (* TwoPointsPerQSO: RXData.QSOPoints := 2, whatever the mode. *)
   CheckPoints(INQSOPARTY, 'Indiana', 2, 2, 2);
   CheckPoints(COLORADOQSOPARTY, 'Colorado', 2, 2, 2);
   CheckPoints(MINNQSOPARTY, 'Minnesota', 2, 2, 2);

   (* OnePhoneTwoCW: if Mode = CW then 2 else 1 -- digital takes the 1. *)
   CheckPoints(MOQSOPARTY, 'Missouri', 2, 1, 1);
   CheckPoints(OHIOQSOPARTY, 'Ohio', 2, 1, 1);
   CheckPoints(WISCONSINQSOPARTY, 'Wisconsin', 2, 1, 1);
   CheckPoints(ArizonaQsoParty, 'Arizona', 2, 1, 1);

   (* TwoPhoneThreeCW: if Mode = CW then 3 else 2 -- digital takes the 2. *)
   CheckPoints(TENNESSEEQSOPARTY, 'Tennessee', 3, 2, 2);
   CheckPoints(TEXASQSOPARTY, 'Texas', 3, 2, 2);
end;

(* THE COUNTY-LINE RULE FOR THE TEN, AND THE ASYMMETRY IS DELIBERATE.

   EXACTLY TWO OF THEM HAVE A NUMBER, because exactly two have been looked up
   in a sponsor's published rules: California four and Indiana two. The other
   eight inherit CountyLineCountiesUnlimited, which is what TR4W does today --
   nothing in the program has ever counted the queued counties.

   SO THE EIGHT ARE ASSERTED AS *UNCHANGED BEHAVIOUR*, not as a decision. A
   number must never be derived from ContestsArray's CountyLineAllowed boolean:
   it carries no limit, and reading its False arm as zero is the defect that
   made a contest start refusing a two-QTH exchange the moment it got a class.
   Arizona is the sharp case -- its row has no such field at all, so the flag
   reads False, and that means UNKNOWN rather than none. *)
procedure TContestFactoryTests.Test_TenStatePartiesCountyLineMaxima;
var
   party: TContestStateQSOPartyBase;
   msg: string;

   function PartyFor(aContest: ContestType;
                     const aWhat: string): TContestStateQSOPartyBase;
   var
      obj: TContestBase;
   begin
      Result := nil;
      obj := MakeContest(aContest);
      CheckTrue(obj <> nil, aWhat + ' has no registered class');
      if obj = nil then
         begin
         Exit;
         end;
      CheckTrue(obj is TContestStateQSOPartyBase,
                aWhat + ' is not on the state-party base');
      if not (obj is TContestStateQSOPartyBase) then
         begin
         obj.Free;
         Exit;
         end;
      Result := TContestStateQSOPartyBase(obj);
   end;

   (* The eight with no established number: unlimited, and a four-county
      junction must still be accepted exactly as it was before the move. *)
   procedure CheckUnlimited(aContest: ContestType; const aWhat: string);
   var
      party: TContestStateQSOPartyBase;
      msg: string;
   begin
      party := PartyFor(aContest, aWhat);
      if party = nil then
         begin
         Exit;
         end;
      try
         CheckEquals(CountyLineCountiesUnlimited, party.CountyLineCountiesMax,
                     aWhat + ' has no established maximum and must inherit'
                     + ' unlimited');
         CheckTrue(party.CountyLineAllowed,
                   aWhat + ': unlimited must read as allowed');
         CheckTrue(party.ValidateQTHCount(4, msg),
                   aWhat + ': a four-county junction must still pass');
         CheckEquals('', msg, aWhat + ': nothing refused, so nothing said');
      finally
         party.Free;
         end;
   end;

begin
   BeginTest('Test_TenStatePartiesCountyLineMaxima');

   (* CALIFORNIA -- FOUR. NY4I, 2026-09-29: "4 since that is the intersection
      of 4 counties with common 90 degree angle borders." *)
   party := PartyFor(CALQSOPARTY, 'California');
   if party <> nil then
      begin
      try
         CheckEquals(4, party.CountyLineCountiesMax, 'California allows four');
         CheckTrue(party.CountyLineAllowed, 'California allows a county line');
         CheckTrue(party.ValidateQTHCount(4, msg),
                   'California: a four-county junction is the rule');
         CheckEquals('', msg, 'California: four is accepted silently');
         CheckFalse(party.ValidateQTHCount(5, msg),
                    'California: five counties cannot meet at a point');
         CheckTrue(msg <> '', 'California: a refusal must say why');
      finally
         party.Free;
         end;
      end;

   (* INDIANA -- TWO. NY4I, 2026-09-29: "Indiana qso party allows 2 counties
      max at once." *)
   party := PartyFor(INQSOPARTY, 'Indiana');
   if party <> nil then
      begin
      try
         CheckEquals(2, party.CountyLineCountiesMax, 'Indiana allows two');
         CheckTrue(party.CountyLineAllowed, 'Indiana allows a county line');
         CheckTrue(party.ValidateQTHCount(2, msg),
                   'Indiana: two counties at once');
         CheckEquals('', msg, 'Indiana: two is accepted silently');
         CheckFalse(party.ValidateQTHCount(3, msg),
                    'Indiana: three counties is too many');
         CheckTrue(msg <> '', 'Indiana: a refusal must say why');
      finally
         party.Free;
         end;
      end;

   (* THE EIGHT WITH NO ESTABLISHED NUMBER -- all of them, not a sample, since
      each one is an independent opportunity to have invented a limit. *)
   CheckUnlimited(COLORADOQSOPARTY, 'Colorado');
   CheckUnlimited(MINNQSOPARTY, 'Minnesota');
   CheckUnlimited(MOQSOPARTY, 'Missouri');
   CheckUnlimited(OHIOQSOPARTY, 'Ohio');
   CheckUnlimited(WISCONSINQSOPARTY, 'Wisconsin');
   CheckUnlimited(TENNESSEEQSOPARTY, 'Tennessee');
   CheckUnlimited(TEXASQSOPARTY, 'Texas');
   CheckUnlimited(ArizonaQsoParty, 'Arizona');
end;

procedure TContestFactoryTests.Test_MovedRowValuesStillMatchTheArray;

   procedure CheckAgainstArray(aContest: ContestType; const aWhat: string);
   var
      cls, row: TContestBase;
   begin
      cls := MakeContest(aContest);
      CheckTrue(cls <> nil, aWhat + ' has no registered class');
      if cls = nil then
         begin
         Exit;
         end;
      row := TContestBase.Create(aContest);
      try
         CheckEquals(row.CabrilloName, cls.CabrilloName, aWhat + ' CabrilloName');
         CheckEquals(row.ADIFContestId, cls.ADIFContestId, aWhat + ' ADIFContestId');
         CheckEquals(row.WA7BNMId, cls.WA7BNMId, aWhat + ' WA7BNMId');
         CheckEquals(row.QRZRUId, cls.QRZRUId, aWhat + ' QRZRUId');
         CheckEquals(row.SubmissionEmail, cls.SubmissionEmail, aWhat + ' SubmissionEmail');
         CheckEquals(row.DomesticFileName, cls.DomesticFileName, aWhat + ' DomesticFileName');
         CheckEquals(row.FriendlyName, cls.FriendlyName, aWhat + ' FriendlyName');
         CheckEquals(Ord(row.PrefixMultiplierType), Ord(cls.PrefixMultiplierType),
                     aWhat + ' PrefixMultiplierType');
         CheckEquals(Ord(row.ZoneMultiplierType), Ord(cls.ZoneMultiplierType),
                     aWhat + ' ZoneMultiplierType');
         CheckEquals(Ord(row.DXMultiplierType), Ord(cls.DXMultiplierType),
                     aWhat + ' DXMultiplierType');
         CheckEquals(Ord(row.DomesticMultiplierType), Ord(cls.DomesticMultiplierType),
                     aWhat + ' DomesticMultiplierType');
         CheckEquals(Ord(row.InitialExchangeKind), Ord(cls.InitialExchangeKind),
                     aWhat + ' InitialExchangeKind');
         CheckEquals(Ord(row.ExchangeKind), Ord(cls.ExchangeKind),
                     aWhat + ' ExchangeKind');
         CheckEquals(Ord(row.QSOPointMethod), Ord(cls.QSOPointMethod),
                     aWhat + ' QSOPointMethod');
         CheckTrue(row.IsUSQSOParty = cls.IsUSQSOParty, aWhat + ' IsUSQSOParty');
      finally
         row.Free;
         cls.Free;
         end;
   end;

begin
   BeginTest('Test_MovedRowValuesStillMatchTheArray');
   CheckAgainstArray(ARKTIKA_SPRING, 'Arktika Spring');
   CheckAgainstArray(ARRLDIGI, 'ARRL Digital');

   (* THE TEN STATE QSO PARTIES MOVED ON 2026-09-29. Each states its whole row
      as literals, and each is an independent chance to have mistyped one -- in
      particular the two-step fallbacks, which is why this compares against a
      plain TContestBase rather than against the record field. California and
      Texas both have a BLANK CABName in the array and neither means the empty
      string; Ohio's ADIFName is blank and that one does. *)
   CheckAgainstArray(CALQSOPARTY, 'California QSO Party');
   CheckAgainstArray(INQSOPARTY, 'Indiana QSO Party');
   CheckAgainstArray(COLORADOQSOPARTY, 'Colorado QSO Party');
   CheckAgainstArray(MINNQSOPARTY, 'Minnesota QSO Party');
   CheckAgainstArray(MOQSOPARTY, 'Missouri QSO Party');
   CheckAgainstArray(OHIOQSOPARTY, 'Ohio QSO Party');
   CheckAgainstArray(WISCONSINQSOPARTY, 'Wisconsin QSO Party');
   CheckAgainstArray(TENNESSEEQSOPARTY, 'Tennessee QSO Party');
   CheckAgainstArray(TEXASQSOPARTY, 'Texas QSO Party');
   CheckAgainstArray(ArizonaQsoParty, 'Arizona QSO Party');
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
   Test_ArktikaSpringScoresOnTheDomesticMultiplierQTH;
   Test_ArktikaSpringOwnsTheNarrowCabrilloLine;
   Test_ARRLDigiScoresByGridDistance;
   Test_ARRLDigiScoresNothingWithoutBothGrids;
   Test_TenStatePartiesScoreTheirLegacyArms;
   Test_TenStatePartiesCountyLineMaxima;
   Test_MovedRowValuesStillMatchTheArray;
end;

end.
