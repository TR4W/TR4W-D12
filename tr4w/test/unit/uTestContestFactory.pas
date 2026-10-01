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
   uContestStateQSOPartyBase, uContestFixedPoints;

const
   (* THE TEN "RAREST OF NC" COUNTIES, TRANSCRIBED A SECOND TIME ON PURPOSE.

      A test that read NCRareCounties out of the class would assert that the
      class agrees with itself. These are typed from the sponsor's list at
      https://ncqsoparty.org/rules/ and each was checked against
      target\dom\nc_cty.dom.

      GRAHAM IS 'GRM'. 'GRA' is a different county, also in that file, and is
      asserted NOT rare below. *)
   NCRareCountyCodes: array[0..9] of string =
      ('CAB', 'GRM', 'VAN', 'MAC', 'DAV', 'CUR', 'PAM', 'ALL', 'PER', 'CAS');

type
   TContestFactoryTests = class(TTestCase)
   private
      procedure CheckCountyLineMaximum(aContest: ContestType; const aWhat: string;
                                       aMax: integer);
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
      procedure Test_FourBespokeArmsScoreTheirLegacyShape;
      procedure Test_VirginiaScoresMarineAndAirMobileAtThree;
      procedure Test_NorthCarolinaBonusIsTheCurrentRules;
      procedure Test_NorthCarolinaAllowsTwoCounties;
      procedure Test_FourBespokeArmsCountyLineMaxima;
      procedure Test_NewYorkTranscribesItsArm;
      procedure Test_SalmonRunScoresTheCurrentRules;
      procedure Test_IdahoOwnsItsRules;
      procedure Test_FixedPointContestsTranscribeTheirArms;
      procedure Test_MovedRowValuesStillMatchTheArray;
      procedure Test_ADIFIdsResolveOldAndNew;
      procedure Test_NoADIFIdIsClaimedTwice;
      procedure Test_NRAUAndJockWhiteRowsAreNotShifted;
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

(* THE FOUR PARTIES WITH A POINT METHOD OF THEIR OWN, MOVED 2026-09-29.

   EVERY ONE OF THEM TESTS PHONE-VERSUS-NOT, WHICH IS THE INVERTED SHAPE. The
   ten parties moved before these mostly test CW-versus-not, so their digital
   QSOs score the PHONE number. Here digital scores the CW number -- 4 for
   British Columbia, 2 for Pennsylvania, 5 for North Carolina's own three-way
   split, 2 for Virginia.

   SO THE DIGITAL ASSERTION IS THE ONE THAT EARNS ITS KEEP. A class written
   from the habit of the previous batch reproduces the phone and CW arms
   perfectly and is silently wrong about every digital contact -- and no other
   gate in this tree would see it: the golden corpus is blind to scoring, and
   test-contest-factory.sh only rescores logs that happen to contain a digital
   QSO in one of these four contests. *)
procedure TContestFactoryTests.Test_FourBespokeArmsScoreTheirLegacyShape;

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
                     aWhat + ' digital -- takes the CW value, not the phone one');
      finally
         obj.Free;
         end;
   end;

begin
   BeginTest('Test_FourBespokeArmsScoreTheirLegacyShape');

   (* BCQPQSOPointMethod: if Mode = PHONE then 2 else 4. *)
   CheckPoints(BCQP, 'British Columbia', 4, 2, 4);

   (* PAQSOPointMethod: if Mode = PHONE then 1 else 2. *)
   CheckPoints(PAQSOPARTY, 'Pennsylvania', 2, 1, 2);

   (* NCQSOPointMethod: phone 2, CW 3, digital 5 -- three distinct numbers,
      before any bonus. PointsFor zeroes the whole exchange, so the callsign
      and the DomesticQTH are blank and neither bonus fires. *)
   CheckPoints(NCQSOPARTY, 'North Carolina', 3, 2, 5);

   (* VAQSOPointMethod: phone 1, else marine/air mobile 3, else 2. A blank
      callsign is not marine, so this is the plain case. *)
   CheckPoints(VAQP, 'Virginia', 2, 1, 2);
end;

(* VIRGINIA'S THIRD ARM, IN BOTH DIRECTIONS.

   The legacy chain is `if PHONE then 1 else if MarineOrAirMobileStation then 3
   else 2`, and THE ORDER IS THE ASSERTION THAT MATTERS: a maritime-mobile
   station worked on PHONE scores ONE, not three, because the phone test comes
   first and returns. A class that tested the callsign first would look more
   natural and would change a score.

   MarineOrAirMobileStation was lifted from LOGSTUFF into uCallSignRoutines for
   this class. It is case-SENSITIVE and that is faithful, not an oversight, so
   the lower-case case is pinned too -- anybody who "fixes" it with an
   UpperCase will be told they changed a score. *)
procedure TContestFactoryTests.Test_VirginiaScoresMarineAndAirMobileAtThree;
var
   obj: TContestBase;

   function PointsForCall(const aCall: string; aMode: ModeType): integer;
   var
      qso: ContestExchange;
   begin
      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := aMode;
      qso.Callsign := aCall;
      obj.CalculateQSOPoints(qso);
      Result := qso.QSOPoints;
   end;

begin
   BeginTest('Test_VirginiaScoresMarineAndAirMobileAtThree');
   obj := MakeContest(VAQP);
   CheckTrue(obj <> nil, 'Virginia QSO Party has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(3, PointsForCall('K4ABC/MM', CW),
                  'maritime mobile on CW');
      CheckEquals(3, PointsForCall('K4ABC/AM', CW),
                  'air mobile on CW');
      CheckEquals(3, PointsForCall('K4ABC/MM', Digital),
                  'maritime mobile on digital -- not a phone contact');

      CheckEquals(2, PointsForCall('K4ABC', CW),
                  'a plain callsign on CW');
      CheckEquals(2, PointsForCall('K4ABC/M', CW),
                  'land mobile is NOT marine or air mobile');
      CheckEquals(2, PointsForCall('K4ABC/P', CW),
                  'portable is not either');

      (* THE ORDER OF THE CHAIN. *)
      CheckEquals(1, PointsForCall('K4ABC/MM', Phone),
                  'phone is tested FIRST -- a /MM phone contact scores one');

      (* Faithful case sensitivity, and the length floor: the legacy routine
         refuses anything shorter than four characters, so a bare suffix is
         not a marine station. *)
      CheckEquals(2, PointsForCall('k4abc/mm', CW),
                  'the legacy test is case-sensitive and must stay so');
      CheckEquals(2, PointsForCall('/MM', CW),
                  'fewer than four characters is refused');
   finally
      obj.Free;
      end;
end;

(* NORTH CAROLINA'S CURRENT PUBLISHED SCORING -- AND THIS IS THE ONE CONTEST IN
   THE MIGRATION WHOSE SCORE DELIBERATELY CHANGED.

   NY4I, 2026-09-29: "the rules given are it. tarheel was back in 2020 so go
   with the current rules." So the 2020 TARHEEL callsign bonuses and the flat
   +50 for DomesticQTH in ('ALL','COL') are GONE, and https://ncqsoparty.org/rules/
   is implemented instead: base phone 2 / CW 3 / digital 5, multiplied by ten
   for a QSO with a station in one of ten "Rarest of NC" counties.

   THIS TEST IS THE ONLY THING THAT CAN SEE ANY OF IT. The golden corpus is
   blind to scoring; test-contest-factory.sh compares against TR4W's own former
   output and NO CORPUS LOG IS AN NC QSO PARTY LOG, so it cannot move either
   way. An approved scoring change with no assertion behind it is an unverified
   change.

   THE NEAR-MISS GUARD IS THE ASSERTION THAT MATTERS MOST. Graham is 'GRM';
   'GRA' is a DIFFERENT county and is also in nc_cty.dom, so a three-letter
   slip pays ten times the points to the wrong county and fails nothing. *)
procedure TContestFactoryTests.Test_NorthCarolinaBonusIsTheCurrentRules;
var
   obj: TContestBase;
   i: integer;

   function PointsForQSO(const aCall: string; const aQTH: string;
                         aMode: ModeType): integer;
   var
      qso: ContestExchange;
   begin
      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := aMode;
      qso.Callsign := aCall;
      qso.DomesticQTH := aQTH;
      obj.CalculateQSOPoints(qso);
      Result := qso.QSOPoints;
   end;

begin
   BeginTest('Test_NorthCarolinaBonusIsTheCurrentRules');
   obj := MakeContest(NCQSOPARTY);
   CheckTrue(obj <> nil, 'North Carolina QSO Party has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      (* BASE POINTS, on a county that is not rare. *)
      CheckEquals(3, PointsForQSO('K4ABC', 'WAK', CW), 'a plain CW QSO');
      CheckEquals(2, PointsForQSO('K4ABC', 'WAK', Phone), 'a plain phone QSO');
      CheckEquals(5, PointsForQSO('K4ABC', 'WAK', Digital),
                  'a plain digital QSO');

      (* TEN TIMES, on a rare one. The sponsor writes these three numbers out
         -- "Phone - 20 points each CW - 30 points each Digital - 50 points
         each" -- so they are asserted as literals here even though the class
         derives them, which is what makes the multiplier form provable. *)
      CheckEquals(30, PointsForQSO('K4ABC', 'CAB', CW), 'rare county, CW');
      CheckEquals(20, PointsForQSO('K4ABC', 'CAB', Phone), 'rare county, phone');
      CheckEquals(50, PointsForQSO('K4ABC', 'CAB', Digital),
                  'rare county, digital');

      (* ALL TEN, not a sample -- each abbreviation is an independent chance to
         have mistyped one, and a mistyped one is silent. *)
      for i := Low(NCRareCountyCodes) to High(NCRareCountyCodes) do
         begin
         CheckEquals(30, PointsForQSO('K4ABC', NCRareCountyCodes[i], CW),
                     'rare county ' + NCRareCountyCodes[i] + ' must pay 10x');
         end;

      (* THE NEAR MISS. Graham is GRM; GRA is a different county in the same
         file and must score base points. *)
      CheckEquals(3, PointsForQSO('K4ABC', 'GRA', CW),
                  'GRA is NOT Graham -- Graham is GRM');

      (* THE OLD FLAT +50 IS GONE. COL is Columbus, which the legacy arm paid
         and the current rules do not. *)
      CheckEquals(3, PointsForQSO('K4ABC', 'COL', CW),
                  'COL no longer carries a bonus');
      CheckEquals(2, PointsForQSO('K4ABC', 'COL', Phone),
                  'COL scores base points on phone too');

      (* AND ALL IS PAID ON ITS OWN MERITS NOW -- it is Alleghany, one of the
         ten, so it pays 10x rather than the old flat +50 (which would have
         been 3 + 50 = 53 on CW). *)
      CheckEquals(30, PointsForQSO('K4ABC', 'ALL', CW),
                  'ALL is Alleghany, a rare county -- 10x, not the old +50');

      (* THE TARHEEL CALLSIGN BONUSES ARE DELETED. *)
      CheckEquals(3, PointsForQSO('N4T', 'WAK', CW),
                  'N4T was a 2020 special-event station and gets nothing now');
      CheckEquals(30, PointsForQSO('N4T', 'CAB', CW),
                  'and the county rule is all that is left to pay it');
   finally
      obj.Free;
      end;
end;

(* NORTH CAROLINA ALLOWS TWO COUNTIES, AND THE NUMBER IS THE SPONSOR'S.

   https://ncqsoparty.org/rules/ : "A Mobile (while stationary,) Portable, or
   Expedition may operate on a county line and contacts can be used as credit
   for two counties. A maximum of two counties may be worked simultaneously
   under this provision."

   IT IS NOT DERIVED FROM ContestsArray's BOOLEAN, which says True and carries
   no limit. This is the third party whose number has been read out of a
   rulebook, after Florida's two and California's four. *)
(* A STATE PARTY WHOSE COUNTY-LINE MAXIMUM HAS BEEN READ OUT OF ITS RULES.

   ONE COPY OF THE ASSERTION, for every party with an established number. It
   was written inline for North Carolina and would have been copied for the
   Salmon Run and New York; copies of a check drift exactly as copies of the
   rule do.

   The maximum must be accepted silently and one more refused WITH a reason --
   the refusal is the half that proves the number is a limit and not merely a
   value the class happens to return. *)
procedure TContestFactoryTests.CheckCountyLineMaximum(aContest: ContestType;
                                                      const aWhat: string;
                                                      aMax: integer);
var
   obj: TContestBase;
   party: TContestStateQSOPartyBase;
   msg: string;
begin
   obj := MakeContest(aContest);
   CheckTrue(obj <> nil, aWhat + ' has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckTrue(obj is TContestStateQSOPartyBase,
                aWhat + ' is not on the state-party base');
      if not (obj is TContestStateQSOPartyBase) then
         begin
         Exit;
         end;
      party := TContestStateQSOPartyBase(obj);
      CheckEquals(aMax, party.CountyLineCountiesMax,
                  aWhat + ' allows ' + IntToStr(aMax) + ' counties');
      CheckTrue(party.CountyLineAllowed,
                aWhat + ' allows county-line operation');
      msg := '';
      CheckTrue(party.ValidateQTHCount(aMax, msg),
                aWhat + ': ' + IntToStr(aMax) + ' counties at once');
      CheckEquals('', msg, aWhat + ': the maximum is accepted silently');
      CheckFalse(party.ValidateQTHCount(aMax + 1, msg),
                 aWhat + ': ' + IntToStr(aMax + 1) + ' counties is too many');
      CheckTrue(msg <> '', aWhat + ': a refusal must say why');
   finally
      obj.Free;
      end;
end;

procedure TContestFactoryTests.Test_NorthCarolinaAllowsTwoCounties;
begin
   BeginTest('Test_NorthCarolinaAllowsTwoCounties');
   CheckCountyLineMaximum(NCQSOPARTY, 'North Carolina', 2);
end;

(* THE OTHER THREE HAVE NO ESTABLISHED NUMBER, AND THAT IS THE UNCHANGED
   BEHAVIOUR ASSERTION.

   British Columbia and Virginia carry no CountyLineAllowed field in their rows
   at all, so the array boolean reads False -- which means UNKNOWN, not none.
   Pennsylvania carries True, which means "allowed, number unknown". All three
   answers are the same: inherit CountyLineCountiesUnlimited, and accept any
   count, because nothing in TR4W has ever counted the queued counties.

   FOUR QTHs IS THE ASSERTION BECAUSE FOUR IS THE MOST THAT CAN PHYSICALLY
   MEET. It is also the count that a wrongly-derived zero would refuse, which
   is the defect this pins against. *)
procedure TContestFactoryTests.Test_FourBespokeArmsCountyLineMaxima;

   procedure CheckUnlimited(aContest: ContestType; const aWhat: string);
   var
      obj: TContestBase;
      party: TContestStateQSOPartyBase;
      msg: string;
   begin
      obj := MakeContest(aContest);
      CheckTrue(obj <> nil, aWhat + ' has no registered class');
      if obj = nil then
         begin
         Exit;
         end;
      try
         CheckTrue(obj is TContestStateQSOPartyBase,
                   aWhat + ' is not on the state-party base');
         if not (obj is TContestStateQSOPartyBase) then
            begin
            Exit;
            end;
         party := TContestStateQSOPartyBase(obj);
         CheckEquals(CountyLineCountiesUnlimited, party.CountyLineCountiesMax,
                     aWhat + ' has no established maximum and must inherit'
                     + ' unlimited');
         CheckTrue(party.CountyLineAllowed,
                   aWhat + ': unlimited must read as allowed');
         CheckTrue(party.ValidateQTHCount(4, msg),
                   aWhat + ': a four-county junction must still pass');
         CheckEquals('', msg, aWhat + ': nothing refused, so nothing said');
      finally
         obj.Free;
         end;
   end;

begin
   BeginTest('Test_FourBespokeArmsCountyLineMaxima');
   CheckUnlimited(BCQP, 'British Columbia');
   CheckUnlimited(PAQSOPARTY, 'Pennsylvania');
   CheckUnlimited(VAQP, 'Virginia');
end;

(* NEW YORK, MOVED 2026-09-29.

   OnePhoneTwoCW is `if Mode = CW then 2 else 1`, so digital takes the PHONE
   value -- the digital assertion is the one that would catch the inverted
   shape.

   TWO COUNTIES ON A COUNTY LINE -- NY4I, 2026-09-29: "NY allows up to 2
   counties on a county line." Its row carries no CountyLineAllowed field, so
   the number is the ruling's and not the boolean's; until then it inherited
   unlimited and accepted a four-county junction. *)
procedure TContestFactoryTests.Test_NewYorkTranscribesItsArm;
var
   obj: TContestBase;
begin
   BeginTest('Test_NewYorkTranscribesItsArm');
   obj := MakeContest(NYQP);
   CheckTrue(obj <> nil, 'New York has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(2, PointsFor(obj, CW), 'New York CW');
      CheckEquals(1, PointsFor(obj, Phone), 'New York phone');
      CheckEquals(1, PointsFor(obj, Digital),
                  'New York digital -- takes the phone value');

      CheckTrue(obj is TContestStateQSOPartyBase,
                'New York is not on the state-party base');
      if not (obj is TContestStateQSOPartyBase) then
         begin
         Exit;
         end;
      CheckEquals('NY', obj.HostState, 'New York host state');
      CheckTrue(obj.IsUSQSOParty, 'New York is a US QSO party');
   finally
      obj.Free;
      end;

   CheckCountyLineMaximum(NYQP, 'New York', 2);
end;

(* THE WASHINGTON STATE SALMON RUN SCORES ON ITS SPONSOR'S CURRENT RULES --
   NY4I, 2026-09-29. https://salmonrun.wwdxc.org/rules/ :

      "QSO POINTS  2 points for Phone  3 points for CW"
      "Contest Modes: Phone and CW. We cannot accept WJST modes (e.g.
       FT-8/FT-4) ..."

   THIS IS A DELIBERATE CHANGE OF SCORE. The legacy arm, identical in D7, was
   `if Mode = CW then 4 else 2`, so CW was 4 and digital 2; both assertions
   below would fail against it, and that is their job. Digital scores 0 on
   NY4I's ruling. FM scores as phone -- the class's reading of "Phone", noted
   in its header, and pinned here because FixedModePoints would have filed it
   with digital.

   TWO COUNTIES ON A COUNTY LINE: "only one county line consisting of two
   counties may be run at a time."

   THE SALMON RUN IS A STATE PARTY WITHOUT THE WORDS IN ITS NAME. It has its
   own QSOParties entry (WA), so it was already IsUSQSOParty before it had a
   class; the host-state assertion is what says it landed on the right base.

   NOT COVERED HERE, because nothing implements it: the W7DX bonus, 500 per
   mode added after multiplication. See the class header. *)
procedure TContestFactoryTests.Test_SalmonRunScoresTheCurrentRules;
var
   obj: TContestBase;
begin
   BeginTest('Test_SalmonRunScoresTheCurrentRules');
   obj := MakeContest(SALMONRUN);
   CheckTrue(obj <> nil, 'Salmon Run has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(3, PointsFor(obj, CW), 'Salmon Run CW is 3 -- not the legacy 4');
      CheckEquals(2, PointsFor(obj, Phone), 'Salmon Run phone is 2');
      CheckEquals(2, PointsFor(obj, FM), 'Salmon Run FM is phone, 2');
      CheckEquals(0, PointsFor(obj, Digital),
                  'Salmon Run digital is 0 -- not the legacy 2');

      CheckEquals('WA', obj.HostState, 'Salmon Run host state');
      CheckTrue(obj.IsUSQSOParty, 'Salmon Run is a US QSO party');
   finally
      obj.Free;
      end;

   CheckCountyLineMaximum(SALMONRUN, 'Salmon Run', 2);
end;

(* THE IDAHO QSO PARTY -- A NEW ContestType WITH ITS OWN CLASS, 2026-10-01.

   Until then it was a .cfg borrowing CONTEST = NEQP, whose
   QSO POINT METHOD = ONE PHONE TWO CW the rotated spelling table read as
   TwoPhoneFourCW -- 4 for CW, 2 for phone. The CW and phone assertions below
   are what would fail against that.

   NY4I, 2026-10-01: "1 point phone, 2 points CW or digital", county line at
   most 2. The sponsor (https://www.idahoqsoparty.org/rules.htm) agrees on
   both. FM is a phone mode -- the assertion that would catch FixedModePoints,
   which files FM with digital.

   THE NAMES ARE ADIF 3.1.7's AND WA7BNM's: ID-QSO-PARTY for both. And NO
   FORMER ADIF ID: Idaho logs were exported as NEQP and cannot be told apart
   from NEQP's, so 'NEQP' must keep resolving to NEQP. *)
procedure TContestFactoryTests.Test_IdahoOwnsItsRules;
var
   obj: TContestBase;
   c: ContestType;
begin
   BeginTest('Test_IdahoOwnsItsRules');
   obj := MakeContest(IDAHOQSOPARTY);
   CheckTrue(obj <> nil, 'Idaho QSO Party has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(2, PointsFor(obj, CW), 'Idaho CW is 2 -- not TwoPhoneFourCW''s 4');
      CheckEquals(1, PointsFor(obj, Phone), 'Idaho phone is 1 -- not TwoPhoneFourCW''s 2');
      CheckEquals(2, PointsFor(obj, Digital), 'Idaho digital is 2, with CW');
      CheckEquals(1, PointsFor(obj, FM), 'Idaho FM is phone, 1');

      CheckTrue(obj is TContestStateQSOPartyBase,
                'Idaho is not on the state-party base');
      CheckEquals('ID', obj.HostState, 'Idaho host state');
      CheckTrue(obj.IsUSQSOParty, 'Idaho is a US QSO party');

      CheckEquals('Idaho QSO Party', obj.DisplayName, 'Idaho display name');
      CheckEquals('Idaho QSO Party', obj.FriendlyName, 'Idaho friendly name');
      CheckEquals('ID-QSO-PARTY', obj.CabrilloName, 'Idaho Cabrillo name');
      CheckEquals('ID-QSO-PARTY', obj.ADIFContestId, 'Idaho ADIF CONTEST_ID');
      CheckEquals(0, Length(obj.FormerADIFContestIds),
                  'Idaho claims no former ADIF id -- its old logs say NEQP');
      CheckEquals(305, obj.WA7BNMId, 'Idaho WA7BNM calendar id');
      CheckEquals('idaho_cty', obj.DomesticFileName, 'Idaho county file');
      CheckEquals(Ord(DomesticFile), Ord(obj.DomesticMultiplierType),
                  'Idaho domestic multiplier is the dom file');
      CheckEquals(Ord(ARRLDXCCWithNoUSAOrCanada), Ord(obj.DXMultiplierType),
                  'Idaho stations count DXCC countries');
      CheckEquals(Ord(RSTDomesticOrDXQTHExchange), Ord(obj.ExchangeKind),
                  'Idaho exchange is RST and a domestic or DX QTH');
      CheckFalse(obj.FormatsExchange,
                 'Idaho uses the shared exchange formatter until M4');
   finally
      obj.Free;
      end;

   (* THE P INDEX REACHES THE SAME STATE, so the legacy reader and the class
      agree -- and the row's ordinal place in QSOParties is right. *)
   CheckEquals('ID', USQSOPartyStateName(IDAHOQSOPARTY),
               'Idaho QSOParties entry names ID');
   CheckEquals('IDAHO QSO PARTY', string(ContestTypeSA[IDAHOQSOPARTY]),
               'the spelling a .cfg names');

   CheckCountyLineMaximum(IDAHOQSOPARTY, 'Idaho', 2);

   CheckTrue(FindContestByADIFContestId('ID-QSO-PARTY', c),
             'ID-QSO-PARTY resolves');
   CheckEquals(Ord(IDAHOQSOPARTY), Ord(c), 'ID-QSO-PARTY -> Idaho');
   (* NEQP HAS NO CLASS AND A BLANK ADIFName, so 'NEQP' resolves to nothing
      through the registry today. What matters here is only that it never
      resolves to Idaho. *)
   if FindContestByADIFContestId('NEQP', c) then
      begin
      CheckTrue(c <> IDAHOQSOPARTY, 'NEQP must never resolve to Idaho');
      end;
end;

(* THE FIXED-POINT CONTESTS, MOVED 2026-09-29 IN TWO SLICES.

   Contests whose scoring arm is a constant, or a constant chosen by mode, and
   which nothing outside their ContestsArray row names except SETUP -- FCONTEST,
   uNewContest's prompts, LOGCFG's CQ-exchange defaults. Each is its own class
   on TContestFixedPoints, because none has another family: none is a state QSO
   party, and the three Minitest rows and the two QCWA rows follow the NA
   Sprint precedent of sibling classes with no base between them.

   The second slice is the six the first deferred only for the batch cap; each
   had setup references outside the row and none had a scoring branch.

   THE DIGITAL COLUMN IS THE ONE THAT CATCHES AN INVERTED SHAPE. Every
   two-branch arm is `if Mode = CW then X else Y`, so digital takes the PHONE
   value.

   THE TWO-QTH ASSERTION IS THE TRAP FIXED ONCE ALREADY. A non-party class
   must not start refusing a two-QTH exchange; TContestBase.ValidateQTHCount
   always passes, and County Hunter -- a log whose operators work county
   lines, and which is NOT a QSO party -- is where a regression would bite. *)
procedure TContestFactoryTests.Test_FixedPointContestsTranscribeTheirArms;

   procedure CheckFixed(aContest: ContestType; const aWhat: string;
                        aCW, aPhone, aDigital: integer);
   var
      obj: TContestBase;
      msg: string;
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
         CheckEquals(aDigital, PointsFor(obj, Digital), aWhat + ' digital');
         CheckEquals(aPhone, PointsFor(obj, FM),
                     aWhat + ' FM -- not folded into phone, takes the other value');

         CheckTrue(obj is TContestFixedPoints,
                   aWhat + ' is not on TContestFixedPoints');
         CheckFalse(obj is TContestStateQSOPartyBase,
                    aWhat + ' must not be on the state-party base');
         CheckFalse(obj.IsUSQSOParty, aWhat + ' is not a US QSO party');
         CheckEquals('', obj.HostState, aWhat + ' has no host state');

         msg := '';
         CheckTrue(obj.ValidateQTHCount(2, msg),
                   aWhat + ': a two-QTH exchange must still pass');
         CheckEquals('', msg, aWhat + ': nothing refused, so nothing said');
      finally
         obj.Free;
         end;
   end;

begin
   BeginTest('Test_FixedPointContestsTranscribeTheirArms');

   (* OnePhoneTwoCW: if Mode = CW then 2 else 1. *)
   CheckFixed(QCWA, 'QCWA', 2, 1, 1);
   CheckFixed(QCWAGOLDEN, 'QCWA Golden', 2, 1, 1);

   (* TwoPointsPerQSO. *)
   CheckFixed(XMAS, 'XMAS', 2, 2, 2);

   (* AlwaysOnePointPerQSO -- scores as one point; its "ignores dupes" meaning
      is LOGSUBS2's, read from the global, and not the class's. *)
   CheckFixed(INTERNETSPRINT, 'Internet Sprint', 1, 1, 1);

   (* OnePointPerQSO. *)
   CheckFixed(COUNTYHUNTER, 'County Hunter', 1, 1, 1);
   CheckFixed(GRIDLOC, 'Grid Loc', 1, 1, 1);
   CheckFixed(MARCONIMEMORIAL, 'Marconi Memorial', 1, 1, 1);
   CheckFixed(SASPRINT, 'SA Sprint', 1, 1, 1);
   CheckFixed(ALLJA, 'All JA', 1, 1, 1);
   CheckFixed(APSPRINT, 'AP Sprint', 1, 1, 1);
   CheckFixed(JALONGPREFECT, 'JA Long Prefect', 1, 1, 1);
   CheckFixed(KIDSDAY, 'Kids Day', 1, 1, 1);
   CheckFixed(MINI40, 'Mini-Test 40', 1, 1, 1);
   CheckFixed(MINI80, 'Mini-Test 80', 1, 1, 1);
   CheckFixed(MINITEST, 'Minitest', 1, 1, 1);

   (* THE SECOND SLICE. *)

   (* OnePhoneTwoCW. *)
   CheckFixed(KVP, 'KVP', 2, 1, 1);

   (* TwoPhoneThreeCW: if Mode = CW then 3 else 2 -- the only arm of this
      shape in either slice, so the only check that would notice 3 and 2
      transposed. *)
   CheckFixed(CQIR, 'CQIR', 3, 2, 2);

   (* AlwaysOnePointPerQSO, as Internet Sprint above. *)
   CheckFixed(YOUTHCHAMPIONSHIPRF, 'SRR-JR', 1, 1, 1);

   (* OnePointPerQSO. *)
   CheckFixed(MST, 'MST', 1, 1, 1);
   CheckFixed(EUROPEANHFC, 'European HFC', 1, 1, 1);
   CheckFixed(DARCXMAS, 'DARC Xmas', 1, 1, 1);
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

   (* THE FOUR BESPOKE-SCORING PARTIES MOVED ON 2026-09-29. Two of their rows
      hold a trap the others do not. British Columbia has a BLANK CABName, so
      its Cabrillo name is the enum's own spelling BCQP and not the empty
      string -- and a blank ADIFName, which IS the empty string.

      NORTH CAROLINA'S ADIFName WAS A SENTENCE AND THE ARRAY WAS CORRECTED ON
      2026-09-29. It held 'North Carolina QSO Party' where every other contest
      uses an upper-case token; NY4I confirmed the real name is 'NC-QSO-PARTY'
      and approved changing VC.pas. This assertion compares the class against
      the array, so it holds either way -- what it cannot see is whether the
      value is the RIGHT one, which is why the correction needed him. *)
   CheckAgainstArray(BCQP, 'British Columbia QSO Party');
   CheckAgainstArray(NCQSOPARTY, 'North Carolina QSO Party');
   CheckAgainstArray(PAQSOPARTY, 'Pennsylvania QSO Party');
   CheckAgainstArray(VAQP, 'Virginia QSO Party');

   (* NEW YORK AND THE SALMON RUN, MOVED 2026-09-29. New York has a BLANK
      CABName, which resolves to the enum's spelling, 'NY-QSO-PARTY'. The
      Salmon Run's names were blank too until NY4I ruled them the same day --
      'WA-QSO-PARTY' and 'WA-SALMON-RUN' -- and this is the assertion that the
      class and the row were changed together. *)
   CheckAgainstArray(NYQP, 'New York QSO Party');
   CheckAgainstArray(SALMONRUN, 'Washington State Salmon Run');

   (* IDAHO, ADDED 2026-10-01 -- a new ContestType, so its row was written for
      the class rather than transcribed from it. Its CABName and FriendlyName
      are stated, not blank. *)
   CheckAgainstArray(IDAHOQSOPARTY, 'Idaho QSO Party');

   (* THE FIRST FIXED-POINT SLICE, MOVED 2026-09-29. Most of these rows have a
      BLANK CABName and FriendlyName, both of which resolve to the enum's
      spelling -- 'QCWA GOLDEN', 'GRID LOC', 'SA-SPRINT' -- and a blank
      ADIFName, which IS the empty string. The two Mini-Test rows' names ended
      in a SPACE ('MINITEST-40 ') until NY4I ruled it a typo on 2026-09-29;
      row and class were corrected together, and this is the assertion that
      would notice them disagree. *)
   CheckAgainstArray(QCWA, 'QCWA QSO Party');
   CheckAgainstArray(QCWAGOLDEN, 'QCWA Golden');
   CheckAgainstArray(COUNTYHUNTER, 'County Hunter');
   CheckAgainstArray(GRIDLOC, 'Grid Loc');
   CheckAgainstArray(MARCONIMEMORIAL, 'Marconi Memorial');
   CheckAgainstArray(SASPRINT, 'SA Sprint');
   CheckAgainstArray(XMAS, 'XMAS');
   CheckAgainstArray(INTERNETSPRINT, 'Internet Sprint');
   CheckAgainstArray(ALLJA, 'All JA');
   CheckAgainstArray(APSPRINT, 'AP Sprint');
   CheckAgainstArray(JALONGPREFECT, 'JA Long Prefect');
   CheckAgainstArray(KIDSDAY, 'Kids Day');
   CheckAgainstArray(MINI40, 'Mini-Test 40');
   CheckAgainstArray(MINI80, 'Mini-Test 80');
   CheckAgainstArray(MINITEST, 'Minitest');

   (* THE SECOND FIXED-POINT SLICE, MOVED 2026-09-29. Two traps in these rows.
      YOUTHCHAMPIONSHIPRF's blank CABName and FriendlyName resolve to its enum
      SPELLING, 'SRR-JR', which looks nothing like the identifier. And CQIR's
      row has NO AIE FIELD AT ALL, so its class deliberately does not state
      one; the InitialExchangeKind comparison is what proves that leaving it
      to the array still gives the array's answer. *)
   CheckAgainstArray(KVP, 'KVP');
   CheckAgainstArray(MST, 'ICWC MST');
   CheckAgainstArray(YOUTHCHAMPIONSHIPRF, 'SRR-JR');
   CheckAgainstArray(EUROPEANHFC, 'European HF Championship');
   CheckAgainstArray(CQIR, 'CQIR - Ireland Calling');
   CheckAgainstArray(DARCXMAS, 'DARC Christmas Contest');
end;

(* WHICH CONTEST ANSWERS TO AN ADIF CONTEST_ID -- the rule itself, asked
   directly of uContestRegistry. uTestADIFRegression asks the same through
   ADIF import; this is where a failure names the lookup rather than the
   lexer.

   NY4I, 2026-09-29: "Yes support old spellings." So both the renamed ids and
   what TR4W wrote before the rename must land on the contest. *)
procedure TContestFactoryTests.Test_ADIFIdsResolveOldAndNew;

   procedure CheckFinds(const aId: string; aExpected: ContestType);
   var
      c: ContestType;
   begin
      CheckTrue(FindContestByADIFContestId(aId, c),
                '[' + aId + '] resolves to a contest');
      CheckEquals(Ord(aExpected), Ord(c),
                  '[' + aId + '] -> ' + string(ContestTypeSA[aExpected]));
   end;

var
   c: ContestType;
begin
   BeginTest('Test_ADIFIdsResolveOldAndNew');

   CheckFinds('ICWC-MST', MST);
   CheckFinds('MST', MST);
   CheckFinds('EU-HF', EUROPEANHFC);
   CheckFinds('EUROPEAN HFC', EUROPEANHFC);
   CheckFinds('AP-SPRINT', APSPRINT);
   CheckFinds('WA-QSO-PARTY', SALMONRUN);
   CheckFinds('SALMON RUN', SALMONRUN);
   CheckFinds('MINITEST-40', MINI40);
   CheckFinds('MINITEST-40 ', MINI40);
   CheckFinds('MINITEST-80', MINI80);
   CheckFinds('MINITEST-80 ', MINI80);
   CheckFinds('NC-QSO-PARTY', NCQSOPARTY);
   CheckFinds('North Carolina QSO Party', NCQSOPARTY);
   CheckFinds('CA-QSO-PARTY', CALQSOPARTY);
   CheckFinds('CALIFORNIA QSO PARTY', CALQSOPARTY);
   CheckFinds('OH-QSO-PARTY', OHIOQSOPARTY);
   CheckFinds('OHIO QSO PARTY', OHIOQSOPARTY);
   CheckFinds('BC-QSO-PARTY', BCQP);
   CheckFinds('BCQP', BCQP);
   CheckFinds('NY-QSO-PARTY', NYQP);
   CheckFinds('ID-QSO-PARTY', IDAHOQSOPARTY);

   (* A contest WITH NO CLASS answers by its current id through the same
      lookup -- NZ Field Day's row was renamed and it has no class. *)
   CheckFinds('JW-FD', NZFIELDDAY);

   (* Surrounding whitespace is not part of an id, on either side. *)
   CheckFinds('  ICWC-MST  ', MST);

   (* A BLANK IS NOT AN ID. The old lookup matched it against the first
      contest whose ADIFName was blank. *)
   CheckFalse(FindContestByADIFContestId('', c), 'an empty id matches nothing');
   CheckEquals(Ord(Low(ContestType)), Ord(c), 'no match answers the first contest');
   CheckFalse(FindContestByADIFContestId('   ', c), 'an all-blank id matches nothing');
   CheckFalse(FindContestByADIFContestId('NOT-A-CONTEST', c),
              'an unknown id matches nothing');
end;

(* NO IDENTIFIER MAY NAME TWO CONTESTS THROUGH A FORMER ID.

   A former id that equalled some contest's CURRENT id would be silently
   ignored -- current ids win -- and one that equalled another contest's
   former id would resolve to whichever sits first in the enum. Both are the
   kind of mistake a rename makes without anyone noticing, so every former id
   is checked against every id in the program.

   AND EVERY CURRENT ID IS ALREADY TRIMMED. The lookup trims its input, so an
   id stored with a space could never be matched by anything -- which is what
   the Mini-Test rows were until 2026-09-29.

   CURRENT IDS ARE NOT REQUIRED TO BE UNIQUE, and that is recorded rather than
   hidden: RSGB-ROLO is the id of both the CW and the SSB running. Import
   resolves it to the first, as it always has. *)
procedure TContestFactoryTests.Test_NoADIFIdIsClaimedTwice;
var
   c, d: ContestType;
   a, b: TContestBase;
   former, other: TContestIdList;
   i, j: integer;
   formerCount: integer;
   who: string;

   function Make(aContest: ContestType): TContestBase;
   begin
      Result := MakeContest(aContest);
      if Result = nil then
         begin
         Result := TContestBase.Create(aContest);
         end;
   end;

begin
   BeginTest('Test_NoADIFIdIsClaimedTwice');
   formerCount := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      who := string(ContestTypeSA[c]);
      a := Make(c);
      try
         CheckEquals(Trim(a.ADIFContestId), a.ADIFContestId,
                     who + ': ADIF id carries whitespace');

         former := a.FormerADIFContestIds;
         for i := 0 to High(former) do
            begin
            inc(formerCount);
            CheckTrue(former[i] <> '', who + ': a blank former id');
            CheckEquals(Trim(former[i]), former[i],
                        who + ': former id carries whitespace');

            for d := Low(ContestType) to High(ContestType) do
               begin
               b := Make(d);
               try
                  CheckTrue(former[i] <> b.ADIFContestId,
                            who + ': former id [' + former[i] +
                            '] is the current id of ' + string(ContestTypeSA[d]));
                  if d <> c then
                     begin
                     other := b.FormerADIFContestIds;
                     for j := 0 to High(other) do
                        begin
                        CheckTrue(former[i] <> other[j],
                                  '[' + former[i] + '] is a former id of both ' +
                                  who + ' and ' + string(ContestTypeSA[d]));
                        end;
                     end;
               finally
                  b.Free;
                  end;
               end;
            end;
      finally
         a.Free;
         end;
      end;

   (* A FLOOR, so the loop cannot pass by finding nothing to check. Seven
      classes state a former id as of 2026-09-29 -- MST, European HFC, the
      Salmon Run, North Carolina, California, Ohio, British Columbia. *)
   CheckTrue(formerCount >= 7,
             'expected at least seven former ids, found ' + IntToStr(formerCount));
end;

(* THREE ROWS WERE SHIFTED BY ONE, SINCE D7.

   NRAU-BALTIC-CW had no friendly name, NRAU-BALTIC-SSB carried the CW one,
   and NZ FIELD DAY carried the SSB one -- and their WA7BNM calendar ids were
   shifted the same way, so the calendar menu on NZ Field Day opened the NRAU
   SSB page. Measured against contestcalendar.com on 2026-09-29: ref=220 is
   "NRAU-Baltic Contest, CW", ref=222 is "NRAU-Baltic Contest, SSB", and the
   Jock White Memorial Field Day is not listed at all, so it has no id -- 0,
   which disables the menu item rather than opening a wrong page.

   NZ FIELD DAY IS RENAMED, per NY4I: the event is the Jock White Memorial
   Field Day (https://www.nzart.org.nz/activities/contests/jwfd), ADIF and
   Cabrillo id JW-FD.

   None of the three has a class, so these are asked of a plain TContestBase --
   which reads the row, and is what the program reads. *)
procedure TContestFactoryTests.Test_NRAUAndJockWhiteRowsAreNotShifted;

   procedure CheckRow(aContest: ContestType; const aFriendly: string;
                      aWA7BNM: integer; const aADIF, aCabrillo: string);
   var
      row: TContestBase;
      who: string;
   begin
      who := string(ContestTypeSA[aContest]);
      row := TContestBase.Create(aContest);
      try
         CheckEquals(aFriendly, row.FriendlyName, who + ' friendly name');
         CheckEquals(aWA7BNM, row.WA7BNMId, who + ' WA7BNM id');
         CheckEquals(aADIF, row.ADIFContestId, who + ' ADIF id');
         CheckEquals(aCabrillo, row.CabrilloName, who + ' Cabrillo name');
      finally
         row.Free;
         end;
   end;

begin
   BeginTest('Test_NRAUAndJockWhiteRowsAreNotShifted');
   CheckRow(NRAUBALTICCW, 'NRAU-Baltic Contest, CW', 220, '', 'NRAU-BALTIC-CW');
   CheckRow(NRAUBALTICSSB, 'NRAU-Baltic Contest, SSB', 222, '', 'NRAU-BALTIC-SSB');
   CheckRow(NZFIELDDAY, 'Jock White Memorial Field Day', 0, 'JW-FD', 'JW-FD');
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
   Test_FourBespokeArmsScoreTheirLegacyShape;
   Test_VirginiaScoresMarineAndAirMobileAtThree;
   Test_NorthCarolinaBonusIsTheCurrentRules;
   Test_NorthCarolinaAllowsTwoCounties;
   Test_FourBespokeArmsCountyLineMaxima;
   Test_NewYorkTranscribesItsArm;
   Test_SalmonRunScoresTheCurrentRules;
   Test_IdahoOwnsItsRules;
   Test_FixedPointContestsTranscribeTheirArms;
   Test_MovedRowValuesStillMatchTheArray;
   Test_ADIFIdsResolveOldAndNew;
   Test_NoADIFIdIsClaimedTwice;
   Test_NRAUAndJockWhiteRowsAreNotShifted;
end;

end.
