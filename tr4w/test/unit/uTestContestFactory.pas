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
   (* cpHIGH / cpLOW / cpQRP -- the entrant's CATEGORY-POWER. Before VC, so
      VC's names win wherever the two overlap. *)
   uSettingsModel,
   uTR4WTestFramework, VC, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase,
   (* THE FAMILY BASES -- the whole list, for
      Test_EveryClassSitsOnTheBaseOrAFamily. *)
   uContestARRLDXBase, uContestARRLSSBase, uContestCQWWBase, uContestCQWPXBase,
   uContestNRAUBalticBase,
   (* M2's in-state detection: the shipped .dom path and the key reader. *)
   Classes, uAppPaths, uDomFileKeys;

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
      procedure Test_IdahoCreditsOnlyItsSixBands;
      procedure Test_IdahoQRPScoresFiveOnEveryMode;
      procedure Test_EveryOtherContestStillCreditsEveryBand;
      procedure Test_FixedPointContestsTranscribeTheirArms;
      procedure Test_MovedRowValuesStillMatchTheArray;
      procedure Test_ADIFIdsResolveOldAndNew;
      procedure Test_NoADIFIdIsClaimedTwice;
      procedure Test_NRAUAndJockWhiteRowsAreNotShifted;
      procedure Test_IdentityIsWhatTheExportersWroteBeforeM1;
      procedure Test_EveryContestResolvesItsOwnADIFId;
      procedure Test_OnlyRSGBRoloSharesACurrentADIFId;
      procedure Test_ZoneModeIsCQOrITUForEveryContest;
      procedure Test_FieldDayHasNoDXMultiplier;
      procedure Test_EveryQSOPartyNamesBothDomesticFiles;
      procedure Test_ShippedDomFilePathHasItsSeparator;
      procedure Test_DomFileKeysAreEnumDOM2sRule;
      procedure Test_AnInStateStationIsFoundInItsCountyFile;
      procedure Test_ScoreQSORunsBandThenOverridesThenTheRule;
      procedure Test_MarksDupesIsTheRowsDupePolicy;
      procedure Test_EveryClassSitsOnTheBaseOrAFamily;
      procedure Test_NRAUBalticIsOneContestInTwoModes;
      procedure Test_SprintSSBIsItsOwnContest;
      procedure Test_LocustScoresItsLegacyArm;
      procedure Test_JockWhiteScoresItsLegacyArm;
      procedure Test_CroatianDoublesByTheQSOsRecordedHour;
      procedure Test_UKEIDoublesByTheQSOsRecordedHour;
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

(* A QSO's points from aContest, through ScoreQSO -- the one public scoring
   entry point, so the band check and the station's overrides run exactly as
   they do for the engine (M3; the PointsOnBand helper that reproduced that
   order here is gone with the reason for it).

   aBand defaults to Band160, the band a FillChar'd record carries, which is
   what every caller that names no band has always scored on. The record
   arrives holding 99 so a path that forgot to write the points cannot pass
   as a zero. *)
function PointsFor(aContest: TContestBase; aMode: ModeType;
                   aBand: BandType = Band160): integer;
var
   qso: ContestExchange;
begin
   FillChar(qso, SizeOf(qso), 0);
   qso.Band := aBand;
   qso.Mode := aMode;
   qso.QSOPoints := 99;
   aContest.ScoreQSO(qso);
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
      obj.ScoreQSO(qso);
      CheckEquals(3, qso.QSOPoints, 'a domestic multiplier QTH is three points');

      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := CW;
      qso.DomesticQTH := 'AR';
      obj.ScoreQSO(qso);
      CheckEquals(1, qso.QSOPoints,
                  'the rule reads DomMultQTH, not DomesticQTH');

      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := Phone;
      obj.ScoreQSO(qso);
      CheckEquals(1, qso.QSOPoints, 'no domestic multiplier QTH is one point');

      (* MODE DOES NOT ENTER INTO IT, which is worth pinning because most of
         the arms around this one are mode-shaped. *)
      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := Digital;
      qso.DomMultQTH := 'AR';
      obj.ScoreQSO(qso);
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
      obj.ScoreQSO(qso);
      CheckEquals(2, qso.QSOPoints, 'a station in our own grid is two points');

      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := Digital;
      qso.QTHString := 'CM87';
      qso.DomesticQTH := 'CM87';
      obj.ScoreQSO(qso);
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
      obj.ScoreQSO(qso);
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
   to break by accident -- a path that left the record alone would hand back
   whatever the caller had in it, which is why the record below arrives holding
   99. Since M3 ScoreQSO zeroes the points before it asks the class, exactly as
   the engine always did, so the 99 now pins that step of the entry point as
   well as the class's guard. Both guards are pinned: no grid of ours, and no
   domestic QTH of theirs. *)
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
      obj.ScoreQSO(qso);
      CheckEquals(0, qso.QSOPoints, 'no grid of ours scores zero, not 99');

      (* THEIR domestic QTH missing, ours present. *)
      FillChar(station, SizeOf(station), 0);
      station.MyGrid := 'EL88';
      obj.SetStation(station);

      FillChar(qso, SizeOf(qso), 0);
      qso.Mode := Digital;
      qso.QTHString := 'CM87';
      qso.QSOPoints := 99;
      obj.ScoreQSO(qso);
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
      obj.ScoreQSO(qso);
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
      obj.ScoreQSO(qso);
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
   (* 'NEQP' IS NEQP'S OWN ID SINCE M1 -- its ADIFName is blank, and the id is
      the enum spelling export writes. So it resolves, and to NEQP: never to
      Idaho, whose pre-2026-10-01 logs were exported under that spelling. *)
   CheckTrue(FindContestByADIFContestId('NEQP', c), 'NEQP resolves');
   CheckEquals(Ord(NEWENGLANDQSO), Ord(c), 'NEQP -> NEWENGLANDQSO, never Idaho');
end;

(* IDAHO'S BANDS -- the sponsor's "160 - 80 - 40 - 20 - 15 - 10 meters", and
   NY4I's ruling of 2026-10-01: a QSO on any other band is logged, scores 0 and
   earns no multiplier.

   ContestCreditsBand IS THE QUESTION BOTH ENGINE SEAMS ASK -- LOGSTUFF for the
   points, LOGDUPE.SetMultFlags for the multipliers -- so asserting it False is
   asserting "no multiplier" in the only form a unit test can reach; the
   contest matrix shows the engine honouring it (IDAHOQSOPARTY's 2 m, 30 m and
   6 m QSOs). *)
procedure TContestFactoryTests.Test_IdahoCreditsOnlyItsSixBands;
var
   obj: TContestBase;
   b: BandType;
   inBand: boolean;
begin
   BeginTest('Test_IdahoCreditsOnlyItsSixBands');
   obj := MakeContest(IDAHOQSOPARTY);
   CheckTrue(obj <> nil, 'Idaho QSO Party has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      (* 20 m, every mode a contact is made in: the in-band rule. *)
      CheckEquals(2, PointsFor(obj, CW, Band20), 'Idaho 20 m CW is 2');
      CheckEquals(1, PointsFor(obj, Phone, Band20), 'Idaho 20 m phone is 1');
      CheckEquals(2, PointsFor(obj, Digital, Band20), 'Idaho 20 m digital is 2');
      CheckEquals(1, PointsFor(obj, FM, Band20), 'Idaho 20 m FM is phone, 1');

      (* THE WARC BANDS: zero points, and no multiplier credit. *)
      CheckEquals(0, PointsFor(obj, CW, Band30), 'Idaho 30 m CW scores 0');
      CheckEquals(0, PointsFor(obj, Phone, Band17), 'Idaho 17 m phone scores 0');
      CheckEquals(0, PointsFor(obj, Digital, Band12), 'Idaho 12 m digital scores 0');
      CheckFalse(ContestCreditsBand(obj, Band30), 'Idaho 30 m earns no multiplier');
      CheckFalse(ContestCreditsBand(obj, Band17), 'Idaho 17 m earns no multiplier');
      CheckFalse(ContestCreditsBand(obj, Band12), 'Idaho 12 m earns no multiplier');

      (* EVERY BAND, so a band added to BandType later is not credited by
         accident -- exactly the six the sponsor names, and nothing else. *)
      for b := Low(BandType) to High(BandType) do
         begin
         inBand := b in [Band160, Band80, Band40, Band20, Band15, Band10];
         CheckTrue(inBand = obj.UsesBand(b),
                   'Idaho UsesBand(' + IntToStr(Ord(b)) + ')');
         end;
   finally
      obj.Free;
      end;
end;

(* QRP IS THE ENTRANT'S CATEGORY-POWER -- NY4I, 2026-10-01: "qrp means our
   power". The sponsor: "ALL QRP QSO's count 5 points. voice, CW, digital".
   Off-band is still 0 for a QRP entrant: the band rule comes first. LOW and
   HIGH are the ordinary 2 / 1 / 2 / 1. *)
procedure TContestFactoryTests.Test_IdahoQRPScoresFiveOnEveryMode;
var
   obj: TContestBase;
   station: TStationContext;

   procedure CheckOrdinary(const aWhat: string);
   begin
      CheckEquals(2, PointsFor(obj, CW, Band20), aWhat + ' CW is 2');
      CheckEquals(1, PointsFor(obj, Phone, Band20), aWhat + ' phone is 1');
      CheckEquals(2, PointsFor(obj, Digital, Band20), aWhat + ' digital is 2');
      CheckEquals(1, PointsFor(obj, FM, Band20), aWhat + ' FM is 1');
   end;

begin
   BeginTest('Test_IdahoQRPScoresFiveOnEveryMode');
   obj := MakeContest(IDAHOQSOPARTY);
   CheckTrue(obj <> nil, 'Idaho QSO Party has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      FillChar(station, SizeOf(station), 0);
      station.MyPower := cpQRP;
      obj.SetStation(station);
      CheckEquals(5, PointsFor(obj, CW, Band20), 'Idaho QRP CW is 5');
      CheckEquals(5, PointsFor(obj, Phone, Band20), 'Idaho QRP phone is 5');
      CheckEquals(5, PointsFor(obj, Digital, Band20), 'Idaho QRP digital is 5');
      CheckEquals(5, PointsFor(obj, FM, Band20), 'Idaho QRP FM is 5');
      CheckEquals(5, PointsFor(obj, CW, Band160), 'Idaho QRP 160 m is 5');
      CheckEquals(0, PointsFor(obj, CW, Band30), 'Idaho QRP 30 m is still 0');
      CheckEquals(0, PointsFor(obj, Phone, Band17), 'Idaho QRP 17 m is still 0');
      CheckEquals(0, PointsFor(obj, Digital, Band12), 'Idaho QRP 12 m is still 0');
      CheckEquals(0, PointsFor(obj, NoMode, Band20),
                  'Idaho QRP NoMode is not a contact mode');

      station.MyPower := cpLOW;
      obj.SetStation(station);
      CheckOrdinary('Idaho LOW');

      station.MyPower := cpHIGH;
      obj.SetStation(station);
      CheckOrdinary('Idaho HIGH');
   finally
      obj.Free;
      end;
end;

(* THE DEFAULT CHANGES NOTHING. TContestBase.UsesBand answers True for every
   band, so a contest that has not stated its bands scores and multiplies a
   30 m QSO exactly as it did before the rule existed -- and a contest with no
   class (nil) is the same.

   EVERY REGISTERED CONTEST BUT IDAHO IS CHECKED, so the exception list below
   is a ratchet: when another contest states its bands, it joins the list in
   the commit that does it, and nothing can narrow its bands by inheriting.

   CQ WW CW is the worked example the other way round: a 30 m QSO with
   Europe from a North American station scores its three points, as on 20 m. *)
procedure TContestFactoryTests.Test_EveryOtherContestStillCreditsEveryBand;
var
   c: ContestType;
   b: BandType;
   obj: TContestBase;
   station: TStationContext;
   qso: ContestExchange;
begin
   BeginTest('Test_EveryOtherContestStillCreditsEveryBand');

   for b := Low(BandType) to High(BandType) do
      begin
      CheckTrue(ContestCreditsBand(nil, b),
                'a classless contest credits band ' + IntToStr(Ord(b)));
      end;

   for c := Low(ContestType) to High(ContestType) do
      begin
      if c = IDAHOQSOPARTY then
         begin
         Continue;
         end;
      obj := MakeContest(c);
      if obj = nil then
         begin
         Continue;
         end;
      try
         for b := Low(BandType) to High(BandType) do
            begin
            CheckTrue(ContestCreditsBand(obj, b),
                      string(ContestTypeSA[c]) + ' credits band ' + IntToStr(Ord(b)));
            end;
      finally
         obj.Free;
         end;
      end;

   obj := MakeContest(CQWWCW);
   CheckTrue(obj <> nil, 'CQ WW CW has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      FillChar(station, SizeOf(station), 0);
      station.MyCountry := 'K';
      station.MyContinent := NorthAmerica;
      obj.SetStation(station);

      FillChar(qso, SizeOf(qso), 0);
      qso.Band := Band30;
      qso.Mode := CW;
      qso.QTH.Continent := Europe;
      qso.QTH.CountryID := 'G';
      CheckTrue(ContestCreditsBand(obj, qso.Band), 'CQ WW CW still credits 30 m');
      obj.ScoreQSO(qso);
      CheckEquals(3, qso.QSOPoints, 'CQ WW CW 30 m QSO with Europe is still 3');
   finally
      obj.Free;
      end;
end;

(* THE FIXED-POINT CONTESTS, MOVED 2026-09-29 IN TWO SLICES.

   Contests whose scoring arm is a constant, or a constant chosen by mode, and
   which nothing outside their ContestsArray row names except SETUP -- FCONTEST,
   uNewContest's prompts, LOGCFG's CQ-exchange defaults. Each is its own class
   with no family: none is a state QSO party, and the three Minitest rows and
   the two QCWA rows follow the NA Sprint precedent of sibling classes with no
   base between them.

   THEY SIT ON TContestBase DIRECTLY SINCE M3 (2026-10-01). They were on
   TContestFixedPoints, a mechanism base that retired then
   (CONTEST_OWNERSHIP_DESIGN.md 1.5); each now states its own numbers in its
   own CalculateQSOPoints through the FixedModePoints helper. So the class
   assertion is now "the parent is TContestBase" -- a contest here that gained
   a base would have to come through Test_EveryClassSitsOnTheBaseOrAFamily.
   The NA Sprint CW and RTTY runnings and General QSO, which used the same
   base, are checked here too.

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

         CheckTrue(obj.ClassParent = TContestBase,
                   aWhat + ' sits on TContestBase directly');
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

   (* THE OTHER THREE THAT WERE ON TContestFixedPoints -- OnePointPerQSO.
      The two NA Sprint runnings are siblings, not a family (no NA Sprint base
      exists; see uContestNASprintCW's header). *)
   CheckFixed(NASPRINTCW, 'NA Sprint CW', 1, 1, 1);
   CheckFixed(NASPRINTRTTY, 'NA Sprint RTTY', 1, 1, 1);
   CheckFixed(GENERALQSO, 'General QSO', 1, 1, 1);
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

   (* THE CONTESTS HELD FROM EARLIER SLICES, MOVED AT M3 (2026-10-01). The
      NRAU-Baltic pair states its shared fields on the family base and its
      names per mode, so this is what proves the split lost nothing. Sprint
      SSB's ADIF and Cabrillo names are STATED in its row and are not its enum
      spelling (SSB-SPRINT); Locust's are blank and ARE its spelling; the Jock
      White Field Day's DomesticFileName is blank and means the empty string. *)
   CheckAgainstArray(NRAUBALTICCW, 'NRAU-Baltic CW');
   CheckAgainstArray(NRAUBALTICSSB, 'NRAU-Baltic SSB');
   CheckAgainstArray(SPRINTSSB, 'Sprint SSB');
   CheckAgainstArray(LQP, 'Locust QSO Party');
   CheckAgainstArray(NZFIELDDAY, 'Jock White Memorial Field Day');

   (* THE CONTESTS THAT GAINED A CLASS AT M4 (2026-10-01), each because an
      exporter named it. Most rows have a BLANK CABName and ADIFName, which
      resolve to the enum's spelling -- 'URAL-CUP', 'RSGB-IOTA', 'DARC-10M'.
      Two traps: WWDIGI and BATAVIA_FT8 STATE a CABName ('WW-DIGI',
      'BATAVIA') that is not their spelling while their ADIF id is; and
      PACC's row says RSTAndQSONumberOrDomesticQTHExchange although every
      PACC session runs RSTDomesticQTHExchange (FCONTEST's arm) -- the class
      transcribes the row, and the export rule follows the session. *)
   CheckAgainstArray(FOCMARATHON, 'FOC Marathon');
   CheckAgainstArray(UKRAINECHAMPIONSHIP, 'Ukraine Championship');
   CheckAgainstArray(CUPURAL, 'Ural Cup');
   CheckAgainstArray(UKEI, 'UK/EI DX');
   CheckAgainstArray(IOTA, 'RSGB IOTA');
   CheckAgainstArray(DARC10M, 'DARC 10 m');
   CheckAgainstArray(PACC, 'PACC');
   CheckAgainstArray(PCC, 'PCC');
   CheckAgainstArray(WAG, 'WAG');
   CheckAgainstArray(WWDIGI, 'WW Digi');
   CheckAgainstArray(BATAVIA_FT8, 'Batavia FT8');

   (* CROATIAN GAINED A CLASS WHEN ITS NIGHT DOUBLING MOVED OFF THE CLOCK
      (design Q21, 2026-10-01). Blank CABName and ADIFName resolve to the
      enum's spelling, 'CROATIAN'. *)
   CheckAgainstArray(CROATIAN, 'Croatian DX');
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

   (* THE JOCK WHITE FIELD DAY, renamed 2026-09-29 while it had NO class, so
      its old export spelling could not be carried then. It gained its class
      at M3 (2026-10-01) and carries it now. *)
   CheckFinds('JW-FD', NZFIELDDAY);
   CheckFinds('NZ FIELD DAY', NZFIELDDAY);

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

   These are asked of a plain TContestBase -- the ROW. All three gained a
   class at M3 (2026-10-01); Test_MovedRowValuesStillMatchTheArray holds each
   class to this row, so the row is what is pinned here. *)
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
   (* The NRAU rows' ADIFName is blank, so their ADIF id is the enum's
      spelling -- what export writes (M1). *)
   CheckRow(NRAUBALTICCW, 'NRAU-Baltic Contest, CW', 220, 'NRAU-BALTIC-CW', 'NRAU-BALTIC-CW');
   CheckRow(NRAUBALTICSSB, 'NRAU-Baltic Contest, SSB', 222, 'NRAU-BALTIC-SSB', 'NRAU-BALTIC-SSB');
   CheckRow(NZFIELDDAY, 'Jock White Memorial Field Day', 0, 'JW-FD', 'JW-FD');
end;

(* M1 -- A CONTEST'S IDENTITY IS ASKED OF THE CONTEST, AND M1 CHANGED NO BYTE.

   Before M1 (2026-10-01) the exporters each spelled the rule themselves --
   "the row's ADIFName, else the enum's spelling" in four places (ADIF export,
   the UDP score broadcast, both score-posting clients), "CABName, else the
   spelling" in two, "FriendlyName, else the spelling" in one -- and read the
   calendar ids straight off the row. They all ask
   uContestRegistry.ContestIdentity now.

   THE SCORE-POSTING IDS HAVE NO OTHER ORACLE. The contest matrix and the
   golden corpus see the Cabrillo CONTEST: line and the ADIF records; nothing
   captures what uGetScores, uHamScore or the UDP broadcasts send. So this pins
   the getters, over EVERY ContestType, to what those copies produced -- each
   expectation below is the old copy's rule, written once more here as the
   frozen reference. A contest whose identity deliberately changes updates
   its row, and this follows.

   AND THE ACCESSOR ITSELF: never nil, one instance per contest however often
   it is asked, and the registered class where there is one -- a plain
   TContestBase only where there is not. *)
procedure TContestFactoryTests.Test_IdentityIsWhatTheExportersWroteBeforeM1;
var
   c: ContestType;
   obj: TContestBase;
   who: string;
   expectADIF: string;
   expectCabrillo: string;
   expectFriendly: string;
   checked: integer;
begin
   BeginTest('Test_IdentityIsWhatTheExportersWroteBeforeM1');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      who := string(ContestTypeSA[c]);
      obj := ContestIdentity(c);
      CheckTrue(obj <> nil, who + ': ContestIdentity answered nil');
      if obj = nil then
         begin
         Continue;
         end;

      CheckTrue(obj = ContestIdentity(c),
                who + ': a second ask built a second object');
      if ContestClassFor(c) <> nil then
         begin
         CheckTrue(obj.ClassType = ContestClassFor(c),
                   who + ' is answered by ' + obj.ClassName +
                   ', not its registered class');
         end
      else
         begin
         CheckTrue(obj.ClassType = TContestBase,
                   who + ' has no class but is answered by ' + obj.ClassName);
         end;

      expectADIF := ContestsArray[c].ADIFName;
      if expectADIF = '' then
         begin
         expectADIF := who;
         end;
      expectCabrillo := ContestsArray[c].CABName;
      if expectCabrillo = '' then
         begin
         expectCabrillo := who;
         end;
      expectFriendly := ContestsArray[c].FriendlyName;
      if expectFriendly = '' then
         begin
         expectFriendly := who;
         end;

      CheckEquals(expectADIF, obj.ADIFContestId, who + ' ADIF CONTEST_ID');
      CheckEquals(expectCabrillo, obj.CabrilloName, who + ' Cabrillo CONTEST:');
      CheckEquals(expectFriendly, obj.FriendlyName, who + ' friendly name');
      CheckEquals(integer(ContestsArray[c].WA7BNM), obj.WA7BNMId,
                  who + ' WA7BNM calendar id');
      CheckEquals(integer(ContestsArray[c].QRZRUID), obj.QRZRUId,
                  who + ' QRZ.RU calendar id');
      inc(checked);
      end;

   CheckEquals(Ord(High(ContestType)) + 1, checked, 'every ContestType checked');
end;

(* EVERY CONTEST'S ADIF ID RESOLVES BACK TO THAT CONTEST -- inventory D9.

   The lookup alone, over every ContestType; uTestADIFRegression asks the same
   through the real emitter and importer. Before M1 the id of a contest with a
   blank ADIFName was '' and a blank matches nothing, so 139 contests failed
   here -- CQ WW, CQ WPX, ARRL DX, Sweepstakes and IARU among them.

   DUMMYCONTEST is "no contest" and is skipped. RSGB_ROPOCO_SSB shares its id
   with the CW running and resolves to it -- see the test below. *)
procedure TContestFactoryTests.Test_EveryContestResolvesItsOwnADIFId;
var
   c: ContestType;
   found: ContestType;
   id: string;
   who: string;
   resolved: integer;
begin
   BeginTest('Test_EveryContestResolvesItsOwnADIFId');
   CheckEquals(Ord(DUMMYCONTEST), Ord(Low(ContestType)),
               'DUMMYCONTEST is the first ContestType');

   resolved := 0;
   for c := Succ(Low(ContestType)) to High(ContestType) do
      begin
      who := string(ContestTypeSA[c]);
      id := ContestIdentity(c).ADIFContestId;
      CheckTrue(id <> '', who + ' has an ADIF id');
      CheckTrue(FindContestByADIFContestId(id, found),
                who + ': its own id [' + id + '] resolves to nothing');

      if c = RSGB_ROPOCO_SSB then
         begin
         CheckEquals(Ord(RSGB_ROPOCO_CW), Ord(found),
                     who + ': the shared RSGB-ROLO resolves to the CW running');
         Continue;
         end;

      CheckEquals(Ord(c), Ord(found),
                  who + ': its own id [' + id + '] resolves to ' +
                  string(ContestTypeSA[found]));
      if found = c then
         begin
         inc(resolved);
         end;
      end;

   (* Every contest except DUMMYCONTEST and RSGB_ROPOCO_SSB. *)
   CheckEquals(Ord(High(ContestType)) + 1 - 2, resolved,
               'contests whose own ADIF id resolves to them');
end;

(* ONE ID, TWO CONTESTS -- AND ONLY ONE SUCH PAIR.

   Making the enum's spelling an id (M1) could have created a collision: a
   spelling equal to another contest's real ADIFName. Measured 2026-10-01,
   none did. The pair that exists predates M1 and is the ROW's: RSGB-ROLO is
   the ADIF id of both the CW and the SSB running, as ADIF defines it, so a
   CONTEST_ID alone cannot tell them apart. Any NEW pair fails here, because
   the second contest of it could never be re-imported. *)
procedure TContestFactoryTests.Test_OnlyRSGBRoloSharesACurrentADIFId;
var
   c, d: ContestType;
   pairs: integer;
   idC: string;
begin
   BeginTest('Test_OnlyRSGBRoloSharesACurrentADIFId');
   pairs := 0;
   (* To Pred(High): Succ of the last member would be out of range. *)
   for c := Low(ContestType) to Pred(High(ContestType)) do
      begin
      idC := ContestIdentity(c).ADIFContestId;
      for d := Succ(c) to High(ContestType) do
         begin
         if idC = ContestIdentity(d).ADIFContestId then
            begin
            inc(pairs);
            CheckTrue((c = RSGB_ROPOCO_CW) and (d = RSGB_ROPOCO_SSB),
                      '[' + idC + '] is the ADIF id of both ' +
                      string(ContestTypeSA[c]) + ' and ' +
                      string(ContestTypeSA[d]));
            end;
         end;
      end;
   CheckEquals(1, pairs, 'contest pairs sharing a current ADIF id');
end;

(* M2 -- DEFECT #2: THE ZONE LIST IS A MEMBER OF ZoneModeType FOR EVERY CONTEST.

   FCONTEST cast a Boolean to ZoneModeType, and FPC produced 255 for 160 of
   185 contests -- neither CQ nor ITU -- so every `case CTY.ctyZoneMode of`
   in uctydat matched nothing and a zone came back 0. The contest states the
   mode now (TContestBase.GetZoneMode). This pins, for EVERY ContestType and
   through the accessor set-up reads, that the answer is a real member and
   that it is the array legend's rule: the bit set is CQ, clear is ITU -- which
   is what D7 did. Then four contests by name, whose zones are their
   exchange. *)
procedure TContestFactoryTests.Test_ZoneModeIsCQOrITUForEveryContest;
var
   c: ContestType;
   mode: ZoneModeType;
   cqBit: boolean;
   cqCount: integer;
begin
   BeginTest('Test_ZoneModeIsCQOrITUForEveryContest');
   cqCount := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      mode := ContestIdentity(c).ZoneMode;
      CheckTrue(Ord(mode) <= Ord(High(ZoneModeType)),
                string(ContestTypeSA[c]) + ' zone mode is out of range: ' +
                IntToStr(Ord(mode)));
      cqBit := (ContestsBooleanArray[c] and (1 shl CQ_ZONE_MODE_BIT)) <> 0;
      CheckTrue((mode = CQZoneMode) = cqBit,
                string(ContestTypeSA[c]) + ' zone mode follows the CQ bit');
      if mode = CQZoneMode then
         begin
         inc(cqCount);
         end;
      end;

   (* A FLOOR, so a table that lost every CQ bit cannot pass as "consistent". *)
   CheckTrue(cqCount >= 10, 'only ' + IntToStr(cqCount) + ' contests use CQ zones');

   CheckTrue(ContestIdentity(CQWWCW).ZoneMode = CQZoneMode, 'CQ WW CW uses CQ zones');
   CheckTrue(ContestIdentity(CQWWSSB).ZoneMode = CQZoneMode, 'CQ WW SSB uses CQ zones');
   CheckTrue(ContestIdentity(CQWPXCW).ZoneMode = CQZoneMode, 'CQ WPX CW uses CQ zones');
   CheckTrue(ContestIdentity(IARU).ZoneMode = ITUZoneMode, 'IARU uses ITU zones');
end;

(* M2 -- Q1, RULED BY NY4I 2026-10-01: ARRL FIELD DAY HAS NO MULTIPLIERS.
   The class said ARRLDXCC, transcribed from the row, while FCONTEST's arm set
   NoDXMults. Class and row were both corrected before set-up began reading
   the class, so the value set-up starts from is the value it ends with. *)
procedure TContestFactoryTests.Test_FieldDayHasNoDXMultiplier;
var
   row: TContestBase;
begin
   BeginTest('Test_FieldDayHasNoDXMultiplier');
   CheckTrue(ContestIdentity(ARRLFIELDDAY).DXMultiplierType = NoDXMults,
             'the Field Day class states no DX multiplier');
   row := TContestBase.Create(ARRLFIELDDAY);
   try
      CheckTrue(row.DXMultiplierType = NoDXMults,
                'and the row agrees with it');
   finally
      row.Free;
      end;
end;

(* The shipped dom directory, from the test binary -- ParamStr(0), never the
   working directory, as the CTY.DAT tests do. *)
function ShippedDomDir: string;
begin
   Result := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
             'target' + PathDelim + 'dom' + PathDelim;
end;

(* M2 -- DEFECT #5 AND THE SHAPE SET-UP RELIES ON.

   A QSO party has TWO domestic files: the host's counties, which every other
   station loads and which in-state detection reads (DomesticFileName), and
   the in-state file (InStateDomesticFileName). Colorado's row had them
   shifted -- Email held 'colorado_cty' and DF was empty -- so its county file
   had no name. For every party, through the accessor set-up reads: both
   names are given, the county file is the in-state name plus _cty, and both
   ship. *)
procedure TContestFactoryTests.Test_EveryQSOPartyNamesBothDomesticFiles;
var
   c: ContestType;
   obj: TContestBase;
   who: string;
   parties: integer;
begin
   BeginTest('Test_EveryQSOPartyNamesBothDomesticFiles');
   parties := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := ContestIdentity(c);
      if not obj.IsUSQSOParty then
         begin
         CheckEquals('', obj.InStateDomesticFileName,
                     string(ContestTypeSA[c]) + ' is no party and has no in-state file');
         Continue;
         end;
      inc(parties);
      who := string(ContestTypeSA[c]);
      CheckTrue(obj.InStateDomesticFileName <> '', who + ' names its in-state file');
      CheckEquals(obj.InStateDomesticFileName + '_cty', obj.DomesticFileName,
                  who + ' county file is the in-state name plus _cty');
      CheckTrue(FileExists(ShippedDomDir + obj.DomesticFileName + '.dom'),
                who + ' county file ' + obj.DomesticFileName + '.dom ships');
      CheckTrue(FileExists(ShippedDomDir + obj.InStateDomesticFileName + '.dom'),
                who + ' in-state file ' + obj.InStateDomesticFileName + '.dom ships');
      end;
   CheckTrue(parties >= 15, 'only ' + IntToStr(parties) + ' QSO parties found');

   CheckEquals('colorado_cty', ContestIdentity(COLORADOQSOPARTY).DomesticFileName,
               'Colorado names its county file');
   CheckEquals('', ContestIdentity(COLORADOQSOPARTY).SubmissionEmail,
               'and a file name is no longer its e-mail address');
end;

(* M2 -- DEFECT #1, THE SEPARATOR ITSELF. FCONTEST built 'DOM' + name and no
   file of that name exists, so no station was ever in state. A name that is
   not on disk comes back unchanged from the case-tolerant lookup, so this
   asserts the composition: the dom directory, the platform's separator, the
   name. *)
procedure TContestFactoryTests.Test_ShippedDomFilePathHasItsSeparator;
var
   path: string;
begin
   BeginTest('Test_ShippedDomFilePathHasItsSeparator');
   path := ShippedDomFilePath('no_such_file_m2.dom');
   CheckEquals(DataFilePath('dom' + PathDelim + 'no_such_file_m2.dom'), path,
               'the shipped dom file is dom, a separator, then the name');
   CheckTrue(Pos('dom' + PathDelim + 'no_such_file_m2.dom', path) > 0,
             'the separator is there');
end;

(* M2 -- THE KEY RULE, EnumDOM2's LINE FOR LINE. Before '=', cut at '>',
   trimmed, compared without case. INCLUDE lines declare nothing, and an empty
   MY STATE is in nobody's state. *)
procedure TContestFactoryTests.Test_DomFileKeysAreEnumDOM2sRule;
var
   lines: TStringList;
begin
   BeginTest('Test_DomFileKeysAreEnumDOM2sRule');
   CheckEquals('APH', DomFileLineKey('APH = Apache'), 'the text before =');
   CheckEquals('APH', DomFileLineKey('  aph>Apache County = APH'),
               'cut at >, trimmed, upper-cased');
   CheckEquals('', DomFileLineKey('INCLUDE FILE S50.DOM'), 'an include declares nothing');
   CheckEquals('', DomFileLineKey(''), 'nor does an empty line');

   lines := TStringList.Create;
   try
      lines.Add('INCLUDE FILE S50.DOM');
      lines.Add('APH = Apache');
      lines.Add('COC>Cochise = COC');
      CheckTrue(DomFileDeclaresKey(lines, 'COC'), 'a key is declared');
      CheckTrue(DomFileDeclaresKey(lines, 'aph'), 'whatever its case');
      CheckFalse(DomFileDeclaresKey(lines, 'KS'), 'a state that is not a key is not');
      CheckFalse(DomFileDeclaresKey(lines, ''), 'an empty MY STATE is never in state');
      CheckFalse(DomFileDeclaresKey(lines, 'S50.DOM'), 'an include is not followed');
   finally
      lines.Free;
      end;
end;

(* M2 -- DEFECT #1 END TO END, OVER THE SHIPPED FILES: for every QSO party, a
   station whose MY STATE is the first key of the party's county file is in
   state -- what the contest matrix's us-host variant states -- and one whose
   MY STATE is not a key is not. Before the fix the first could not be true
   for any party, because the file was never found. *)
procedure TContestFactoryTests.Test_AnInStateStationIsFoundInItsCountyFile;
var
   c: ContestType;
   obj: TContestBase;
   lines: TStringList;
   path, firstKey: string;
   i: integer;
begin
   BeginTest('Test_AnInStateStationIsFoundInItsCountyFile');
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := ContestIdentity(c);
      if not obj.IsUSQSOParty then
         begin
         Continue;
         end;
      path := ShippedDomDir + obj.DomesticFileName + '.dom';
      firstKey := '';
      lines := TStringList.Create;
      try
         if FileExists(path) then
            begin
            lines.LoadFromFile(AnsiString(path));
            end;
         for i := 0 to lines.Count - 1 do
            begin
            firstKey := DomFileLineKey(lines[i]);
            if firstKey <> '' then
               begin
               Break;
               end;
            end;
      finally
         lines.Free;
         end;
      CheckTrue(firstKey <> '', string(ContestTypeSA[c]) + ' county file declares a key');
      CheckTrue(DomFileOnDiskDeclaresKey(path, firstKey),
                string(ContestTypeSA[c]) + ' finds ' + firstKey + ' in state');
      CheckFalse(DomFileOnDiskDeclaresKey(path, 'NOT-A-COUNTY'),
                 string(ContestTypeSA[c]) + ' does not find a non-key in state');
      end;
end;

(* ScoreQSO IS THE ONE PUBLIC SCORING ENTRY POINT, AND ITS ORDER IS THE RULE
   -- M3, 2026-10-01 (docs/CONTEST_OWNERSHIP_DESIGN.md 7.7):

     1. an off-band QSO scores 0, even under a stated override (7.4);
     2. a stated QSO POINTS ... override scores the QSOs it matches, first
        match winning in the engine's order -- domestic CW, DX CW, domestic
        phone, DX phone; FM and digital match none of them;
     3. otherwise the contest's own rule.

   Idaho is the contest because it is the one that states its bands, so all
   three steps are visible in one class: 20 m is in, 30 m is out, and its rule
   (CW 2, phone and FM 1, digital 2) differs from every override value used.

   THE ZERO-VALUE STATION STATES NO OVERRIDE. That is what the Stated flag
   buys over copying the setting's -1: a FillChar'd context scores by the
   contest's rule, not 0. And a stated override OF 0 is a real statement. *)
procedure TContestFactoryTests.Test_ScoreQSORunsBandThenOverridesThenTheRule;
var
   obj: TContestBase;
   station: TStationContext;
   qso: ContestExchange;

   function Score(aBand: BandType; aMode: ModeType;
                  const aDomesticQTH: string): integer;
   var
      rx: ContestExchange;
   begin
      FillChar(rx, SizeOf(rx), 0);
      rx.Band := aBand;
      rx.Mode := aMode;
      rx.DomesticQTH := ShortString(aDomesticQTH);
      rx.QSOPoints := 99;
      obj.ScoreQSO(rx);
      Result := rx.QSOPoints;
   end;

begin
   BeginTest('Test_ScoreQSORunsBandThenOverridesThenTheRule');
   obj := MakeContest(IDAHOQSOPARTY);
   CheckTrue(obj <> nil, 'Idaho QSO Party has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      (* No override stated: the contest's rule. *)
      FillChar(station, SizeOf(station), 0);
      obj.SetStation(station);
      CheckEquals(2, Score(Band20, CW, 'ADA'), 'no override: Idaho CW is 2');
      CheckEquals(1, Score(Band20, Phone, 'ADA'), 'no override: Idaho phone is 1');

      (* Each override, on the QSOs it matches and no others. *)
      station.PointOverrides.DomesticCW.Stated := True;
      station.PointOverrides.DomesticCW.Points := 7;
      obj.SetStation(station);
      CheckEquals(7, Score(Band20, CW, 'ADA'), 'domestic CW override scores a domestic CW QSO');
      CheckEquals(2, Score(Band20, CW, ''), 'domestic CW override leaves a DX CW QSO to the rule');
      CheckEquals(2, Score(Band20, Digital, 'ADA'), 'no override matches digital');
      CheckEquals(0, Score(Band30, CW, 'ADA'), 'the band check runs BEFORE the override');

      station.PointOverrides.DXCW.Stated := True;
      station.PointOverrides.DXCW.Points := 9;
      obj.SetStation(station);
      CheckEquals(9, Score(Band20, CW, ''), 'DX CW override scores a DX CW QSO');
      CheckEquals(7, Score(Band20, CW, 'ADA'), 'domestic CW still wins for a domestic QSO');

      station.PointOverrides.DomesticPhone.Stated := True;
      station.PointOverrides.DomesticPhone.Points := 4;
      station.PointOverrides.DXPhone.Stated := True;
      station.PointOverrides.DXPhone.Points := 6;
      obj.SetStation(station);
      CheckEquals(4, Score(Band20, Phone, 'ADA'), 'domestic phone override');
      CheckEquals(6, Score(Band20, Phone, ''), 'DX phone override');
      CheckEquals(1, Score(Band20, FM, 'ADA'), 'FM is not Phone to the overrides: the rule scores it');
      CheckEquals(0, Score(Band17, Phone, ''), 'off-band phone is 0 under an override too');

      (* A stated ZERO is a statement, not "not stated". *)
      station.PointOverrides.DomesticCW.Points := 0;
      obj.SetStation(station);
      CheckEquals(0, Score(Band20, CW, 'ADA'), 'a stated 0 scores 0');
   finally
      obj.Free;
      end;

   (* THE HELPER ALONE, as the classless engine path calls it: no override
      stated leaves the record untouched and answers False. *)
   FillChar(station, SizeOf(station), 0);
   FillChar(qso, SizeOf(qso), 0);
   qso.Mode := CW;
   qso.QSOPoints := 99;
   CheckFalse(ApplyQSOPointOverride(station.PointOverrides, qso),
              'no override stated answers False');
   CheckEquals(99, qso.QSOPoints, 'and leaves the points alone');
end;

(* THE DUPE POLICY IS THE CONTEST'S -- M3, 2026-10-01.

   LOGSUBS2 used to skip the dupe flag when the GLOBAL point method was
   AlwaysOnePointPerQSO ("ignores dupes"). It asks
   ContestIdentity(Contest).MarksDupes now. With no QSO POINT METHOD stated
   the global was the row's QP, so the class answer must equal
   "row QP <> AlwaysOnePointPerQSO" for EVERY ContestType -- class or not --
   or this move changed a default. The two that ignore dupes are named, so a
   row edit that drops one is caught here and not in a contest. *)
procedure TContestFactoryTests.Test_MarksDupesIsTheRowsDupePolicy;
var
   c: ContestType;
begin
   BeginTest('Test_MarksDupesIsTheRowsDupePolicy');
   for c := Low(ContestType) to High(ContestType) do
      begin
      CheckTrue(ContestIdentity(c).MarksDupes =
                   (ContestsArray[c].QP <> AlwaysOnePointPerQSO),
                string(ContestTypeSA[c]) + ' MarksDupes is its row''s policy');
      end;
   CheckFalse(ContestIdentity(INTERNETSPRINT).MarksDupes,
              'Internet Sprint ignores dupes');
   CheckFalse(ContestIdentity(YOUTHCHAMPIONSHIPRF).MarksDupes,
              'the Youth Championship of Russia ignores dupes');
   CheckTrue(ContestIdentity(CQWWCW).MarksDupes, 'CQ WW CW marks dupes');
end;

(* M3 -- A BASE CLASS IS A FAMILY, AND THE FAMILIES ARE A CLOSED LIST.

   TContestFixedPoints RETIRED AT M3 (2026-10-01). It was a MECHANISM base --
   "contests that score a number per mode", some twenty-five sponsors -- and
   NY4I's ownership ruling allows a base only for a FAMILY, contests under one
   rule (CONTEST_OWNERSHIP_DESIGN.md 1.5). Its subclasses now sit on
   TContestBase and call FixedModePoints as a helper.

   SO EVERY REGISTERED CLASS'S PARENT IS TContestBase OR ONE OF THE FAMILY
   BASES BELOW, AND EVERY FAMILY BASE SITS ON TContestBase ITSELF. The list is
   the ratchet: a new base fails this test until somebody adds it here, which
   is the moment to ask whether it is a family or a convenience. Families are
   NOT invented for resemblance -- a contest that looks like another starts
   as a COPY it owns (1.4).

   NRAU-BALTIC IS THE FAMILY M3 ADDED, by NY4I's ruling. Its two members are
   counted, so a third contest cannot be slipped under it unnoticed. *)
procedure TContestFactoryTests.Test_EveryClassSitsOnTheBaseOrAFamily;
const
   FamilyCount = 6;
var
   families: array[0..FamilyCount - 1] of TClass;
   c: ContestType;
   obj: TContestBase;
   parent: TClass;
   i, direct, nrau: integer;
   known: boolean;
begin
   BeginTest('Test_EveryClassSitsOnTheBaseOrAFamily');

   families[0] := TContestStateQSOPartyBase;
   families[1] := TContestARRLDXBase;
   families[2] := TContestARRLSSBase;
   families[3] := TContestCQWWBase;
   families[4] := TContestCQWPXBase;
   families[5] := TContestNRAUBalticBase;

   for i := 0 to FamilyCount - 1 do
      begin
      CheckTrue(families[i].ClassParent = TContestBase,
                families[i].ClassName + ' sits on TContestBase -- a family is'
                + ' never nested under another base');
      end;

   direct := 0;
   nrau := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := MakeContest(c);
      if obj = nil then
         begin
         Continue;
         end;
      try
         parent := obj.ClassParent;
         known := parent = TContestBase;
         if known then
            begin
            inc(direct);
            end;
         for i := 0 to FamilyCount - 1 do
            begin
            if parent = families[i] then
               begin
               known := True;
               end;
            end;
         if parent = TContestNRAUBalticBase then
            begin
            inc(nrau);
            end;
         CheckTrue(known,
                   string(ContestTypeSA[c]) + ' (' + obj.ClassName + ') sits on '
                   + parent.ClassName + ', which is neither TContestBase nor a'
                   + ' listed family base');
      finally
         obj.Free;
         end;
      end;

   CheckEquals(2, nrau, 'the NRAU-Baltic family is its CW and SSB runnings');

   (* A FLOOR, so the loop cannot pass by finding nothing: the 25 former
      TContestFixedPoints contests alone put more than twenty on the base. *)
   CheckTrue(direct >= 20,
             'only ' + IntToStr(direct) + ' classes sit on TContestBase directly');
end;

(* NRAU-BALTIC -- ONE CONTEST, TWO RUNNINGS (NY4I, 2026-10-01).

   The legacy arm is TwoPointsPerQSO for both rows: 2 on every mode. Asserted
   on all four modes for both runnings, because the reason the family base
   exists is that points per mode may one day differ -- and the day they do,
   this is what has to change, deliberately.

   IDENTITY. The four fields that differ between the two rows are stated per
   mode class; everything else is the family's. The calendar ids are the ones
   bf395987 un-shifted (220 CW, 222 SSB). The Cabrillo names are what TR4W has
   always sent; the calendar's NRAU-CW / NRAU-SSB is a question for NY4I. *)
procedure TContestFactoryTests.Test_NRAUBalticIsOneContestInTwoModes;

   procedure CheckRunning(aContest: ContestType; const aWhat, aName,
                          aFriendly: string; aWA7BNM: integer);
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
         CheckTrue(obj.ClassParent = TContestNRAUBalticBase,
                   aWhat + ' is a member of the NRAU-Baltic family');
         CheckEquals(2, PointsFor(obj, CW), aWhat + ' CW');
         CheckEquals(2, PointsFor(obj, Phone), aWhat + ' phone');
         CheckEquals(2, PointsFor(obj, Digital), aWhat + ' digital');
         CheckEquals(2, PointsFor(obj, FM), aWhat + ' FM');

         CheckEquals(aName, obj.CabrilloName, aWhat + ' Cabrillo name');
         CheckEquals(aName, obj.ADIFContestId, aWhat + ' ADIF id');
         CheckEquals(aFriendly, obj.FriendlyName, aWhat + ' friendly name');
         CheckEquals(aWA7BNM, obj.WA7BNMId, aWhat + ' WA7BNM id');
         CheckEquals('nrau', obj.DomesticFileName, aWhat + ' domestic file');
         CheckEquals(Ord(RSTQSONumberAndDomesticQTHExchange), Ord(obj.ExchangeKind),
                     aWhat + ' exchange');
         CheckEquals(Ord(TwoPointsPerQSO), Ord(obj.QSOPointMethod),
                     aWhat + ' point method');
         CheckFalse(obj.IsUSQSOParty, aWhat + ' is not a US QSO party');
      finally
         obj.Free;
         end;
   end;

begin
   BeginTest('Test_NRAUBalticIsOneContestInTwoModes');
   CheckRunning(NRAUBALTICCW, 'NRAU-Baltic CW', 'NRAU-BALTIC-CW',
                'NRAU-Baltic Contest, CW', 220);
   CheckRunning(NRAUBALTICSSB, 'NRAU-Baltic SSB', 'NRAU-BALTIC-SSB',
                'NRAU-Baltic Contest, SSB', 222);
end;

(* THE SSB SPRINT IS ITS OWN CONTEST (NY4I, 2026-10-01: "a different contest
   with a different sponsor so keep it separate").

   So it sits on TContestBase -- not under, and not beside as a family member
   of, the NCJ's NA Sprint classes -- and states OnePointPerQSO itself. Its
   ADIF and Cabrillo names are the ones its row STATES, NA-SPRINT-SSB, not its
   enum spelling SSB-SPRINT; whether they should still say NA Sprint is a
   question for NY4I, so the assertion pins today's. *)
procedure TContestFactoryTests.Test_SprintSSBIsItsOwnContest;
var
   obj: TContestBase;
begin
   BeginTest('Test_SprintSSBIsItsOwnContest');
   obj := MakeContest(SPRINTSSB);
   CheckTrue(obj <> nil, 'Sprint SSB has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckTrue(obj.ClassParent = TContestBase, 'Sprint SSB sits on TContestBase');
      CheckEquals('TContestSprintSSB', obj.ClassName, 'Sprint SSB is its own class');

      CheckEquals(1, PointsFor(obj, CW), 'Sprint SSB CW');
      CheckEquals(1, PointsFor(obj, Phone), 'Sprint SSB phone');
      CheckEquals(1, PointsFor(obj, Digital), 'Sprint SSB digital');
      CheckEquals(1, PointsFor(obj, FM), 'Sprint SSB FM');

      CheckEquals('NA-SPRINT-SSB', obj.CabrilloName, 'Sprint SSB Cabrillo name');
      CheckEquals('NA-SPRINT-SSB', obj.ADIFContestId, 'Sprint SSB ADIF id');
      CheckEquals('North American Sprint, SSB', obj.FriendlyName,
                  'Sprint SSB friendly name');
      CheckEquals(242, obj.WA7BNMId, 'Sprint SSB WA7BNM id');
   finally
      obj.Free;
      end;
end;

(* A Locust QSO Party contact's points: aCall, aName, on aBand in aMode. *)
function LocustPoints(aContest: TContestBase; aMode: ModeType; aBand: BandType;
                      const aCall, aName: ShortString): integer;
var
   qso: ContestExchange;
begin
   FillChar(qso, SizeOf(qso), 0);
   qso.Band := aBand;
   qso.Mode := aMode;
   qso.Callsign := aCall;
   qso.Name := aName;
   qso.QSOPoints := 99;
   aContest.ScoreQSO(qso);
   Result := qso.QSOPoints;
end;

(* THE LOCUST QSO PARTY -- LQPQSOPointMethod, TRANSCRIBED.

   1000 a contact; 5000 when the name is LOCUST or the call is K6VVA. Every
   mode and every band score, because the legacy arm asks neither: the
   calendar says CW on 80 and 40 m only, and that is a question for NY4I, not
   a rule to slip in with the move. The 20 m and phone cases pin that the
   class did NOT narrow it.

   And it is NOT a state QSO party, which the party base's header claimed
   until M3. *)
procedure TContestFactoryTests.Test_LocustScoresItsLegacyArm;
var
   obj: TContestBase;
begin
   BeginTest('Test_LocustScoresItsLegacyArm');
   obj := MakeContest(LQP);
   CheckTrue(obj <> nil, 'Locust has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckTrue(obj.ClassParent = TContestBase, 'Locust sits on TContestBase');
      CheckFalse(obj is TContestStateQSOPartyBase,
                 'Locust is not on the state-party base');
      CheckFalse(obj.IsUSQSOParty, 'Locust is not a US state QSO party');
      CheckEquals('', obj.HostState, 'Locust has no host state');

      CheckEquals(1000, LocustPoints(obj, CW, Band40, 'W1AW', 'JOE'),
                  'an ordinary contact');
      CheckEquals(5000, LocustPoints(obj, CW, Band40, 'W1AW', 'LOCUST'),
                  'the name LOCUST');
      CheckEquals(5000, LocustPoints(obj, CW, Band80, 'K6VVA', 'RICK'),
                  'the sponsor K6VVA');
      CheckEquals(5000, LocustPoints(obj, CW, Band80, 'K6VVA', 'LOCUST'),
                  'both at once is still 5000, not more');
      CheckEquals(1000, LocustPoints(obj, CW, Band40, 'K6VVA/7', 'JOE'),
                  'the call must match exactly -- K6VVA/7 is not K6VVA');
      CheckEquals(1000, LocustPoints(obj, Phone, Band20, 'W1AW', 'JOE'),
                  'phone on 20 m still scores: the arm asks neither');

      CheckEquals('LOCUST QSO PARTY', obj.CabrilloName, 'Locust Cabrillo name');
      CheckEquals('LOCUST QSO PARTY', obj.ADIFContestId, 'Locust ADIF id');
      CheckEquals('Locust QSO Party', obj.FriendlyName, 'Locust friendly name');
      CheckEquals(446, obj.WA7BNMId, 'Locust WA7BNM id');
   finally
      obj.Free;
      end;
end;

(* THE JOCK WHITE MEMORIAL FIELD DAY -- NZFieldDayQSOPointMethod, TRANSCRIBED.

   A ZL contact is 5 on CW and 3 on everything else; any other country is 10.
   And the arm writes a second field: a contact in OUR branch (zone) earns no
   branch multiplier, so ZoneMult is cleared. The legacy arm compared against
   StrToIntDef(MY ZONE, 0); Station.MyZone is that same number, 0 when MY ZONE
   is unset, so an unset zone still clears a zone-0 contact. *)
procedure TContestFactoryTests.Test_JockWhiteScoresItsLegacyArm;
var
   obj: TContestBase;
   station: TStationContext;

   function Score(aMode: ModeType; const aCountry: ShortString; aZone: byte;
                  out aZoneMult: boolean): integer;
   var
      qso: ContestExchange;
   begin
      FillChar(qso, SizeOf(qso), 0);
      qso.Band := Band40;
      qso.Mode := aMode;
      qso.QTH.CountryID := aCountry;
      qso.Zone := aZone;
      qso.ZoneMult := True;
      qso.QSOPoints := 99;
      obj.ScoreQSO(qso);
      aZoneMult := qso.ZoneMult;
      Result := qso.QSOPoints;
   end;

var
   zoneMult: boolean;
begin
   BeginTest('Test_JockWhiteScoresItsLegacyArm');
   obj := MakeContest(NZFIELDDAY);
   CheckTrue(obj <> nil, 'Jock White Field Day has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckTrue(obj.ClassParent = TContestBase,
                'Jock White Field Day sits on TContestBase');

      FillChar(station, SizeOf(station), 0);
      station.MyCountry := 'ZL';
      station.MyZone := 3;
      station.MyZoneValid := True;
      obj.SetStation(station);

      CheckEquals(5, Score(CW, 'ZL', 4, zoneMult), 'ZL on CW');
      CheckTrue(zoneMult, 'another branch keeps its multiplier');
      CheckEquals(3, Score(Phone, 'ZL', 4, zoneMult), 'ZL on phone');
      CheckEquals(3, Score(Digital, 'ZL', 4, zoneMult), 'ZL on digital scores the phone value');
      CheckEquals(3, Score(FM, 'ZL', 4, zoneMult), 'ZL on FM scores the phone value');
      CheckEquals(10, Score(CW, 'VK', 4, zoneMult), 'outside ZL on CW');
      CheckEquals(10, Score(Phone, 'K', 4, zoneMult), 'outside ZL on phone');

      CheckEquals(5, Score(CW, 'ZL', 3, zoneMult), 'own branch still scores');
      CheckFalse(zoneMult, 'our own branch earns no branch multiplier');

      (* MY ZONE unset: the arm's StrToIntDef gave 0, and so does MyZone. *)
      FillChar(station, SizeOf(station), 0);
      obj.SetStation(station);
      Score(CW, 'ZL', 0, zoneMult);
      CheckFalse(zoneMult, 'an unset MY ZONE is 0, and matches a zone-0 contact');
      Score(CW, 'ZL', 3, zoneMult);
      CheckTrue(zoneMult, 'an unset MY ZONE does not match branch 3');

      CheckEquals('JW-FD', obj.CabrilloName, 'Cabrillo name');
      CheckEquals('JW-FD', obj.ADIFContestId, 'ADIF id');
      CheckEquals(1, Length(obj.FormerADIFContestIds), 'one former ADIF id');
      if Length(obj.FormerADIFContestIds) = 1 then
         begin
         CheckEquals('NZ FIELD DAY', obj.FormerADIFContestIds[0],
                     'the enum spelling export wrote before the rename');
         end;
      CheckEquals('Jock White Memorial Field Day', obj.FriendlyName, 'friendly name');
      CheckEquals(0, obj.WA7BNMId, 'not on the calendar: 0 disables the menu item');
      CheckEquals(Ord(BranchZones), Ord(obj.ZoneMultiplierType), 'branch multipliers');
   finally
      obj.Free;
      end;
end;

(* A QSO's points from aContest, worked with aCall in aCountry on aContinent,
   on aBand, RECORDED at aHour:aMinute UTC -- the time a time-of-day rule
   must read (design Q21). *)
function PointsAtRecordedTime(aContest: TContestBase; aBand: BandType;
                              const aCall, aCountry: ShortString;
                              aContinent: ContinentType;
                              aHour, aMinute: byte): integer;
var
   qso: ContestExchange;
begin
   FillChar(qso, SizeOf(qso), 0);
   qso.Band := aBand;
   qso.Mode := CW;
   qso.Callsign := aCall;
   qso.QTH.CountryID := aCountry;
   qso.QTH.Continent := aContinent;
   qso.tSysTime.qtYear := 26;
   qso.tSysTime.qtMonth := 10;
   qso.tSysTime.qtDay := 3;
   qso.tSysTime.qtHour := aHour;
   qso.tSysTime.qtMinute := aMinute;
   qso.QSOPoints := 99;
   aContest.ScoreQSO(qso);
   Result := qso.QSOPoints;
end;

(* THE CROATIAN DX CONTEST DOUBLES BY THE HOUR THE QSO WAS RECORDED IN.

   NY4I, 2026-10-01: "the event source is the wall clock recorded in the
   QSO". The legacy arm read the PC's clock at scoring time, so a rescore at
   23:30 UTC doubled every QSO. THIS TEST CANNOT PASS IF ANY CLOCK IS READ:
   it asserts the day value and the night value for the same contact in one
   run, and whatever hour the machine says, one of the two would be wrong.

   The window is 23:00-04:59 UTC, and both edges are pinned. The rest is the
   arm transcribed: a DL station working a W on 20 m is 3 (another continent,
   not 9A); a 9A station's own two steps EXIT before the doubling, so they
   never double -- which the arm always did, and is kept. *)
procedure TContestFactoryTests.Test_CroatianDoublesByTheQSOsRecordedHour;
var
   obj: TContestBase;
   station: TStationContext;

   function Points(aHour, aMinute: byte): integer;
   begin
      Result := PointsAtRecordedTime(obj, Band20, 'W1AW', 'K', NorthAmerica,
                                     aHour, aMinute);
   end;

begin
   BeginTest('Test_CroatianDoublesByTheQSOsRecordedHour');
   obj := MakeContest(CROATIAN);
   CheckTrue(obj <> nil, 'Croatian has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckTrue(obj.ClassParent = TContestBase, 'Croatian sits on TContestBase');
      CheckEquals('TContestCroatian', obj.ClassName, 'Croatian is its own class');

      FillChar(station, SizeOf(station), 0);
      station.MyCountry := 'DL';
      station.MyContinent := Europe;
      obj.SetStation(station);

      CheckEquals(3, Points(12, 0), 'midday: the day value');
      CheckEquals(3, Points(22, 59), '22:59 is still day');
      CheckEquals(6, Points(23, 0), '23:00 doubles');
      CheckEquals(6, Points(0, 0), '00:00 doubles');
      CheckEquals(6, Points(4, 59), '04:59 still doubles');
      CheckEquals(3, Points(5, 0), '05:00 is day again');

      (* The other steps, at night, so the doubling is visible. *)
      CheckEquals(12, PointsAtRecordedTime(obj, Band80, 'W1AW', 'K', NorthAmerica, 2, 0),
                  'another continent on 80 m: 6, doubled');
      CheckEquals(2, PointsAtRecordedTime(obj, Band20, 'F5ABC', 'F', Europe, 2, 0),
                  'our own continent on 20 m: 1, doubled');
      CheckEquals(2, PointsAtRecordedTime(obj, Band20, '9A1A', '9A', Europe, 2, 0),
                  'a 9A on our own continent: step 4 overwrites step 3, doubled');
      CheckEquals(12, PointsAtRecordedTime(obj, Band40, 'W1AW', 'K', NorthAmerica, 2, 0),
                  'another continent on 40 m: 6, doubled');
      CheckEquals(1, PointsAtRecordedTime(obj, Band20, '9A1A', '9A', Europe, 12, 0),
                  'a 9A on our own continent by day: 1');
      CheckEquals(0, PointsAtRecordedTime(obj, Band30, 'W1AW', 'K', NorthAmerica, 2, 0),
                  'a band outside the six scores 0, and 0 doubled is 0');

      (* A 9A STATION'S STEPS EXIT BEFORE THE DOUBLING. *)
      station.MyCountry := '9A';
      obj.SetStation(station);
      CheckEquals(1, PointsAtRecordedTime(obj, Band20, '9A1A', '9A', Europe, 2, 0),
                  '9A working 9A at night: 1, never doubled');
      CheckEquals(6, PointsAtRecordedTime(obj, Band20, 'W1AW', 'K', NorthAmerica, 2, 0),
                  '9A working another continent at night: 6, never doubled');
      CheckEquals(4, PointsAtRecordedTime(obj, Band80, 'DL1ABC', 'DL', Europe, 12, 0),
                  '9A working Europe on 80 m by day: 4');

      CheckEquals('CROATIAN', obj.CabrilloName, 'Croatian Cabrillo name');
      CheckEquals('CROATIAN', obj.ADIFContestId, 'Croatian ADIF id');
      CheckEquals('Croatian DX Contest', obj.FriendlyName, 'Croatian friendly name');
   finally
      obj.Free;
      end;
end;

(* UK/EI DX DOUBLES A UK OR EI STATION'S POINTS BY THE HOUR THE QSO WAS
   RECORDED IN -- the same defect and the same fix as Croatian (design Q21).
   Its window is 01:00-04:59 UTC, both edges pinned, and day and night are
   asserted in one run so no clock can satisfy both. Only a UK/EI station
   doubles; 80 and 40 m double again on top. *)
procedure TContestFactoryTests.Test_UKEIDoublesByTheQSOsRecordedHour;
var
   obj: TContestBase;
   station: TStationContext;

   function Points(aHour, aMinute: byte): integer;
   begin
      Result := PointsAtRecordedTime(obj, Band20, 'W1AW', 'K', NorthAmerica,
                                     aHour, aMinute);
   end;

begin
   BeginTest('Test_UKEIDoublesByTheQSOsRecordedHour');
   obj := MakeContest(UKEI);
   CheckTrue(obj <> nil, 'UK/EI has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      FillChar(station, SizeOf(station), 0);
      station.MyCountry := 'G';
      station.MyContinent := Europe;
      obj.SetStation(station);

      CheckEquals(4, Points(12, 0), 'a G working outside Europe at midday: 4');
      CheckEquals(4, Points(0, 59), '00:59 is still day');
      CheckEquals(8, Points(1, 0), '01:00 doubles');
      CheckEquals(8, Points(4, 59), '04:59 still doubles');
      CheckEquals(4, Points(5, 0), '05:00 is day again');
      CheckEquals(4, Points(23, 30), '23:30 is day for UK/EI');

      CheckEquals(16, PointsAtRecordedTime(obj, Band40, 'W1AW', 'K', NorthAmerica, 2, 0),
                  '40 m at night: 4, doubled by the hour, doubled by the band');
      CheckEquals(8, PointsAtRecordedTime(obj, Band40, 'W1AW', 'K', NorthAmerica, 12, 0),
                  '40 m by day: doubled by the band only');
      CheckEquals(4, PointsAtRecordedTime(obj, Band20, 'DL1ABC', 'DL', Europe, 2, 0),
                  'a G working Europe at night: 2, doubled');

      (* ONLY A UK/EI STATION DOUBLES BY THE HOUR. *)
      station.MyCountry := 'DL';
      obj.SetStation(station);
      CheckEquals(2, PointsAtRecordedTime(obj, Band20, 'W1AW', 'K', NorthAmerica, 2, 0),
                  'a DL station at night: 2, not doubled');
      CheckEquals(2, PointsAtRecordedTime(obj, Band20, 'W1AW', 'K', NorthAmerica, 12, 0),
                  'a DL station by day: 2');
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
   Test_IdahoCreditsOnlyItsSixBands;
   Test_IdahoQRPScoresFiveOnEveryMode;
   Test_EveryOtherContestStillCreditsEveryBand;
   Test_FixedPointContestsTranscribeTheirArms;
   Test_MovedRowValuesStillMatchTheArray;
   Test_ADIFIdsResolveOldAndNew;
   Test_NoADIFIdIsClaimedTwice;
   Test_NRAUAndJockWhiteRowsAreNotShifted;
   Test_IdentityIsWhatTheExportersWroteBeforeM1;
   Test_EveryContestResolvesItsOwnADIFId;
   Test_OnlyRSGBRoloSharesACurrentADIFId;
   Test_ZoneModeIsCQOrITUForEveryContest;
   Test_FieldDayHasNoDXMultiplier;
   Test_EveryQSOPartyNamesBothDomesticFiles;
   Test_ShippedDomFilePathHasItsSeparator;
   Test_DomFileKeysAreEnumDOM2sRule;
   Test_AnInStateStationIsFoundInItsCountyFile;
   Test_ScoreQSORunsBandThenOverridesThenTheRule;
   Test_MarksDupesIsTheRowsDupePolicy;
   Test_EveryClassSitsOnTheBaseOrAFamily;
   Test_NRAUBalticIsOneContestInTwoModes;
   Test_SprintSSBIsItsOwnContest;
   Test_LocustScoresItsLegacyArm;
   Test_JockWhiteScoresItsLegacyArm;
   Test_CroatianDoublesByTheQSOsRecordedHour;
   Test_UKEIDoublesByTheQSOsRecordedHour;
end;

end.
