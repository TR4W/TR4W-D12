unit uTestSelfSpot;
{$I ..\..\src\tr4w.inc}

(* SELF-SPOTTING (issue 188): THE DECISION AND THE CONTEST'S ANSWER.

  uSelfSpotRule is a pure leaf, so every refusal NY4I asked for (2026-11-19) is
  pinned here with no radio, cluster or clock:

    - a contest that does not allow it never sends, by any trigger;
    - never in S&P;
    - the interval never goes below the contest's stated minimum, whatever the
      operator's setting;
    - the macro and the menu need the VFO to have moved 300 Hz; the automatic
      trigger does not (it exists to repeat on one frequency);
    - Sweepstakes is the first contest to allow it, at 10 minutes, and no
      other class does. *)

interface

uses
   uTR4WTestFramework;

type
   TSelfSpotTests = class(TTestCase)
   protected
      procedure Test_ContestThatDoesNotAllowNeverSends;
      procedure Test_SearchAndPounceNeverSends;
      procedure Test_NoCallNoFrequencyNoLinkRefuse;
      procedure Test_FirstSpotGoesByEveryTrigger;
      procedure Test_IntervalIsTheLargerOfSettingAndContestMinimum;
      procedure Test_IntervalBoundaryIsExact;
      procedure Test_ManualTriggersNeedThreeHundredHertz;
      procedure Test_AutoDoesNotNeedTheVFOToMove;
      procedure Test_ClockStepBackwardsIsTooSoonNotSend;
      procedure Test_RefusalOrderNamesTheMostBasicReasonFirst;
      procedure Test_SpotFrequencyRoundsToTheNearestHundred;
      procedure Test_TheContestDefaultIsNoAndNoMinimum;
      procedure Test_OnlySweepstakesAllowsItAndAtTenMinutes;
      procedure Test_ANilContestAnswersNo;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, DateUtils,
   VC,                        (* NoContest *)
   uSelfSpotRule,
   uContestBase,
   uContestRegistry,          (* TContestIdentityList *)
   uContestARRLSSBase,
   uContestARRLSSCW,
   uContestARRLSSSSB,
   uTestRegisteredContests;   (* ContestsToWalk *)

function Noon: TDateTime;
begin
   Result := EncodeDate(2026, 11, 21) + EncodeTime(12, 0, 0, 0);
end;

function After(aMinutes, aSeconds: integer): TDateTime;
begin
   Result := IncSecond(Noon, aMinutes * 60 + aSeconds);
end;

(* The verdict for a station that is fit to spot (allowed, running, call,
  frequency, link) except for whatever the test then changes. *)
function Ask(aTrigger: TSelfSpotTrigger; aSetting, aMinimum: integer;
             aHaveLast: boolean; aLastFreq, aFreq: integer;
             const aNow: TDateTime): TSelfSpotVerdict;
begin
   Result := SelfSpotVerdictFor(aTrigger, True, aMinimum, aSetting,
                                False, True, aFreq, True,
                                aHaveLast, Noon, aNow, aLastFreq);
end;

procedure TSelfSpotTests.Test_ContestThatDoesNotAllowNeverSends;
var
   t: TSelfSpotTrigger;
begin
   BeginTest('Test_ContestThatDoesNotAllowNeverSends');
   for t := Low(TSelfSpotTrigger) to High(TSelfSpotTrigger) do
      begin
      CheckEquals(Ord(ssvContestDoesNotAllow),
                  Ord(SelfSpotVerdictFor(t, False, 0, 10, False, True,
                                         14025000, True, False, Noon, Noon, 0)),
                  'a contest that does not allow it refuses every trigger');
      end;
end;

procedure TSelfSpotTests.Test_SearchAndPounceNeverSends;
var
   t: TSelfSpotTrigger;
begin
   BeginTest('Test_SearchAndPounceNeverSends');
   for t := Low(TSelfSpotTrigger) to High(TSelfSpotTrigger) do
      begin
      CheckEquals(Ord(ssvSearchAndPounce),
                  Ord(SelfSpotVerdictFor(t, True, 10, 10, True, True,
                                         14025000, True, False, Noon, Noon, 0)),
                  'S&P refuses every trigger');
      end;
end;

procedure TSelfSpotTests.Test_NoCallNoFrequencyNoLinkRefuse;
begin
   BeginTest('Test_NoCallNoFrequencyNoLinkRefuse');
   CheckEquals(Ord(ssvNoCall),
               Ord(SelfSpotVerdictFor(sstMenu, True, 10, 10, False, False,
                                      14025000, True, False, Noon, Noon, 0)),
               'no call');
   CheckEquals(Ord(ssvNoFrequency),
               Ord(SelfSpotVerdictFor(sstMenu, True, 10, 10, False, True,
                                      0, True, False, Noon, Noon, 0)),
               'no frequency');
   CheckEquals(Ord(ssvNoLink),
               Ord(SelfSpotVerdictFor(sstMenu, True, 10, 10, False, True,
                                      14025000, False, False, Noon, Noon, 0)),
               'no cluster and no network: the spot would be dropped silently');
end;

procedure TSelfSpotTests.Test_FirstSpotGoesByEveryTrigger;
var
   t: TSelfSpotTrigger;
begin
   BeginTest('Test_FirstSpotGoesByEveryTrigger');
   for t := Low(TSelfSpotTrigger) to High(TSelfSpotTrigger) do
      begin
      CheckEquals(Ord(ssvSend),
                  Ord(Ask(t, 10, 10, False, 0, 14025000, Noon)),
                  'nothing sent yet, so nothing to be too soon after');
      end;
end;

procedure TSelfSpotTests.Test_IntervalIsTheLargerOfSettingAndContestMinimum;
begin
   BeginTest('Test_IntervalIsTheLargerOfSettingAndContestMinimum');
   CheckEquals(10, SelfSpotEffectiveMinutes(10, 10), 'equal');
   CheckEquals(10, SelfSpotEffectiveMinutes(5, 10),
               'a setting below the contest minimum is lifted to it');
   CheckEquals(15, SelfSpotEffectiveMinutes(15, 10),
               'a longer setting is kept');
   CheckEquals(1, SelfSpotEffectiveMinutes(0, 0),
               'no setting and no minimum is still never zero');

   (* THE INVARIANT, through the decision: setting 1 minute, contest 10 --
     five minutes after the last spot is still too soon. *)
   CheckEquals(Ord(ssvTooSoon),
               Ord(Ask(sstAuto, 1, 10, True, 14025000, 14025000, After(5, 0))),
               'the interval never goes below the contest minimum');
end;

procedure TSelfSpotTests.Test_IntervalBoundaryIsExact;
begin
   BeginTest('Test_IntervalBoundaryIsExact');
   CheckEquals(Ord(ssvTooSoon),
               Ord(Ask(sstAuto, 10, 10, True, 14025000, 14025000, After(9, 59))),
               '9 min 59 s after is too soon');
   CheckEquals(Ord(ssvSend),
               Ord(Ask(sstAuto, 10, 10, True, 14025000, 14025000, After(10, 0))),
               'exactly 10 minutes goes');
   CheckEquals(Ord(ssvTooSoon),
               Ord(Ask(sstAuto, 15, 10, True, 14025000, 14025000, After(14, 59))),
               'a 15 minute setting holds past the contest 10');
end;

procedure TSelfSpotTests.Test_ManualTriggersNeedThreeHundredHertz;
begin
   BeginTest('Test_ManualTriggersNeedThreeHundredHertz');
   CheckEquals(Ord(ssvNotMoved),
               Ord(Ask(sstMacro, 10, 10, True, 14025000, 14025299, After(11, 0))),
               'the macro: 299 Hz up is not enough');
   CheckEquals(Ord(ssvSend),
               Ord(Ask(sstMacro, 10, 10, True, 14025000, 14025300, After(11, 0))),
               'the macro: 300 Hz up is enough');
   CheckEquals(Ord(ssvNotMoved),
               Ord(Ask(sstMacro, 10, 10, True, 14025000, 14024701, After(11, 0))),
               'the macro: 299 Hz DOWN is not enough either');
   CheckEquals(Ord(ssvSend),
               Ord(Ask(sstMacro, 10, 10, True, 14025000, 14024700, After(11, 0))),
               'the macro: 300 Hz down is enough');
   CheckEquals(Ord(ssvNotMoved),
               Ord(Ask(sstMenu, 10, 10, True, 14025000, 14025000, After(11, 0))),
               'the menu item is the same hot key by another route');
   CheckEquals(Ord(ssvTooSoon),
               Ord(Ask(sstMacro, 10, 10, True, 14025000, 14030000, After(2, 0))),
               'a 5 kHz QSY does not buy a spot inside the interval');
end;

procedure TSelfSpotTests.Test_AutoDoesNotNeedTheVFOToMove;
begin
   BeginTest('Test_AutoDoesNotNeedTheVFOToMove');
   CheckEquals(Ord(ssvSend),
               Ord(Ask(sstAuto, 10, 10, True, 14025000, 14025000, After(10, 0))),
               'a station running on one frequency is re-spotted at the interval');
end;

procedure TSelfSpotTests.Test_ClockStepBackwardsIsTooSoonNotSend;
begin
   BeginTest('Test_ClockStepBackwardsIsTooSoonNotSend');
   (* uSpotAge.AgeSeconds reads a stamp in the future as age zero. For a rate
     limit that is the safe direction: wait for the clock to catch up. *)
   CheckEquals(Ord(ssvTooSoon),
               Ord(Ask(sstAuto, 10, 10, True, 14025000, 14025000, After(-30, 0))),
               'a clock stepped back does not let a spot through');
end;

procedure TSelfSpotTests.Test_RefusalOrderNamesTheMostBasicReasonFirst;
begin
   BeginTest('Test_RefusalOrderNamesTheMostBasicReasonFirst');
   CheckEquals(Ord(ssvContestDoesNotAllow),
               Ord(SelfSpotVerdictFor(sstMacro, False, 0, 10, True, False,
                                      0, False, True, Noon, Noon, 14025000)),
               'the contest says no before S&P, call, frequency or link do');
   CheckEquals(Ord(ssvSearchAndPounce),
               Ord(SelfSpotVerdictFor(sstMacro, True, 10, 10, True, False,
                                      0, False, True, Noon, Noon, 14025000)),
               'S&P before the rest');
end;

procedure TSelfSpotTests.Test_SpotFrequencyRoundsToTheNearestHundred;
begin
   BeginTest('Test_SpotFrequencyRoundsToTheNearestHundred');
   CheckEquals(14025000, SpotFrequencyRoundedHz(14025049), '49 Hz rounds down');
   CheckEquals(14025100, SpotFrequencyRoundedHz(14025050), '50 Hz rounds up');
   CheckEquals(14025000, SpotFrequencyRoundedHz(14025000), 'exact');
   CheckEquals(7100100, SpotFrequencyRoundedHz(7100099), '99 Hz rounds up');
end;

procedure TSelfSpotTests.Test_TheContestDefaultIsNoAndNoMinimum;
var
   rules: TContestBase;
begin
   BeginTest('Test_TheContestDefaultIsNoAndNoMinimum');
   rules := TContestBase.Create(NoContest);
   try
      CheckFalse(rules.AllowsSelfSpotting,
                 'the base does not spot an operator whose rules were never read');
      CheckEquals(0, rules.SelfSpotMinimumMinutes, 'and states no minimum');
   finally
      rules.Free;
   end;
end;

procedure TSelfSpotTests.Test_OnlySweepstakesAllowsItAndAtTenMinutes;
var
   all: TContestIdentityList;
   k, sweepstakes: integer;
begin
   BeginTest('Test_OnlySweepstakesAllowsItAndAtTenMinutes');
   all := ContestsToWalk;
   sweepstakes := 0;
   for k := 0 to High(all) do
      begin
      if all[k].AllowsSelfSpotting then
         begin
         CheckTrue(all[k] is TContestARRLSSBase,
                   all[k].DisplayName + ' allows self-spotting but is not'
                   + ' Sweepstakes: each contest that allows it is stated'
                   + ' from its sponsor''s rules, with its source');
         CheckEquals(10, all[k].SelfSpotMinimumMinutes,
                     all[k].DisplayName + ' states its minimum interval');
         inc(sweepstakes);
         end
      else
         begin
         CheckEquals(0, all[k].SelfSpotMinimumMinutes,
                     all[k].DisplayName + ' does not allow it, so it has no'
                     + ' interval to state');
         end;
      end;
   CheckEquals(2, sweepstakes, 'Sweepstakes CW and Sweepstakes SSB');
end;

procedure TSelfSpotTests.Test_ANilContestAnswersNo;
begin
   BeginTest('Test_ANilContestAnswersNo');
   CheckFalse(ContestAllowsSelfSpotting(nil), 'the classless contest');
   CheckEquals(0, ContestSelfSpotMinimumMinutes(nil), 'no minimum');
end;

procedure TSelfSpotTests.RunAllTests;
begin
   Test_ContestThatDoesNotAllowNeverSends;
   Test_SearchAndPounceNeverSends;
   Test_NoCallNoFrequencyNoLinkRefuse;
   Test_FirstSpotGoesByEveryTrigger;
   Test_IntervalIsTheLargerOfSettingAndContestMinimum;
   Test_IntervalBoundaryIsExact;
   Test_ManualTriggersNeedThreeHundredHertz;
   Test_AutoDoesNotNeedTheVFOToMove;
   Test_ClockStepBackwardsIsTooSoonNotSend;
   Test_RefusalOrderNamesTheMostBasicReasonFirst;
   Test_SpotFrequencyRoundsToTheNearestHundred;
   Test_TheContestDefaultIsNoAndNoMinimum;
   Test_OnlySweepstakesAllowsItAndAtTenMinutes;
   Test_ANilContestAnswersNo;
end;

end.
