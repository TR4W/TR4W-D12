unit uTestSplitReassert;

{
  SPLIT THAT THE RADIO ITSELF UNDOES, and the redundant mode command that
  provoked it.

  THE DEFECT THIS PINS (NY4I's bench, 2026-08-25, two sessions).  Pressing '-'
  set the K4's VFO B correctly and then did not go into split.  The log showed
  TR4W sending exactly the right three commands --

     FB00007020000;   MD$3;   FT1;

  -- the K4 accepting the split (it reported FT1, and TR4W raised the SPLIT MODE
  banner), and then, with NOTHING further sent by TR4W, the radio answering the
  MODE command with its entire sub-receiver state and ending that burst with
  FT0.  Split was on for about 145 ms, which is why it read as never happening.

  TWO THINGS WERE WRONG AND BOTH ARE PINNED HERE.

  1. VFO B WAS ALREADY IN CW.  MD$3; commanded a mode the radio was already in.
     That command had no business being on the wire at all, and it is what
     provoked the state burst.  TR4W did not always send it: TK4Radio.SetFrequency
     gained an unconditional SetMode on 2026-01-05 (6f89fd80), and the D7 tree
     writes FA/FB and nothing else.  So this is a regression with a date, which
     is exactly what NY4I suspected when he said he had never seen the behaviour
     before.

  2. WIRE ORDER CANNOT FIX IT.  FT1; was already last.  The rig's side effect
     lands AFTER it has accepted and acknowledged the split, so the only remedy
     is to notice the contradiction and re-assert.  HamLib carries the same
     workaround for this family (rigs/kenwood/k3.c: "split can get turned off
     when modes are changing").

  WHY THESE CASES.  A silently-defaulted capability reads as a legal False, and
  a budget that is never spent reads as a working re-assert -- neither produces
  a diagnostic and neither is visible without a radio on the bench.  The
  exhaustive check at the end is the one that matters most: it fails if the K4
  ever loses the flag, which would restore the original defect in total silence.

  No transport: capabilities are set in the constructor and the rest is
  arithmetic on the radio object, so this only builds radio objects.
}

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TSplitReassertTests = class(TTestCase)
   protected
      procedure TestFreshRadioHasNothingCommanded;
      procedure TestReassertsOnceWhenContradicted;
      procedure TestBudgetIsSpentSoItCannotLoop;
      procedure TestNewCommandRefreshesTheBudget;
      procedure TestAgreeingReportDoesNotReassert;
      procedure TestCommandingSplitOffDisarmsIt;
      procedure TestRadioWithoutTheTraitNeverReasserts;
      procedure TestModeAlreadySetMatchesPerVFO;
      procedure TestModeNoneIsNeverAlreadySet;
      procedure TestDataModesAreNeverAlreadySet;
      procedure TestOnlyTheK4DeclaresTheTrait;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uFactoryRadioBase, uRadioRegistry, uRadioElecraftK4, VC;

type
   // Reaches the protected VFO array.  A descendant may touch its inherited
   // protected members from another unit, and the test needs to say "the radio
   // is already in CW" without a transport to say it through.
   TRadioProbe = class(TFactoryRadioBase);

// The K4 is the radio the defect was found on and the only one that declares
// the trait.  Built through the registry so the test exercises the same
// construction path the application uses.
function NewK4: TFactoryRadioBase;
begin
   Result := uRadioRegistry.CreateInstance(K4);
end;

procedure TSplitReassertTests.TestFreshRadioHasNothingCommanded;
var
   r: TFactoryRadioBase;
begin
   BeginTest('TestFreshRadioHasNothingCommanded');
   r := NewK4;
   try
      CheckFalse(r.SplitNeedsReassert(False),
                 'a radio nobody has commanded must not re-assert anything');
   finally
      r.Free;
   end;
end;

procedure TSplitReassertTests.TestReassertsOnceWhenContradicted;
var
   r: TFactoryRadioBase;
begin
   BeginTest('TestReassertsOnceWhenContradicted');
   r := NewK4;
   try
      r.NoteSplitCommanded(True);
      CheckTrue(r.SplitNeedsReassert(False),
                'split commanded on, radio reports off -- re-assert');
   finally
      r.Free;
   end;
end;

procedure TSplitReassertTests.TestBudgetIsSpentSoItCannotLoop;
var
   r: TFactoryRadioBase;
begin
   BeginTest('TestBudgetIsSpentSoItCannotLoop');
   r := NewK4;
   try
      r.NoteSplitCommanded(True);
      CheckTrue(r.SplitNeedsReassert(False), 'the first contradiction re-asserts');
      // A radio that will not go into split at all reports off again, and again.
      // Without a spent budget that is a command loop against the rig.
      CheckFalse(r.SplitNeedsReassert(False), 'the second does NOT');
      CheckFalse(r.SplitNeedsReassert(False), 'and neither does the third');
   finally
      r.Free;
   end;
end;

procedure TSplitReassertTests.TestNewCommandRefreshesTheBudget;
var
   r: TFactoryRadioBase;
begin
   BeginTest('TestNewCommandRefreshesTheBudget');
   r := NewK4;
   try
      r.NoteSplitCommanded(True);
      CheckTrue(r.SplitNeedsReassert(False), 'first command, budget available');
      CheckFalse(r.SplitNeedsReassert(False), 'budget now spent');

      // The operator presses '-' again.  This is a NEW command and deserves the
      // same one re-assert; the previous attempt must not disarm it.
      r.NoteSplitCommanded(True);
      CheckTrue(r.SplitNeedsReassert(False),
                'a fresh split command gets a fresh re-assert');
   finally
      r.Free;
   end;
end;

procedure TSplitReassertTests.TestAgreeingReportDoesNotReassert;
var
   r: TFactoryRadioBase;
begin
   BeginTest('TestAgreeingReportDoesNotReassert');
   r := NewK4;
   try
      r.NoteSplitCommanded(True);
      CheckFalse(r.SplitNeedsReassert(True),
                 'the radio agrees it is in split -- nothing to correct');
      // And the budget must survive: the contradiction may still be coming, 145 ms
      // later, which is precisely the case this exists for.
      CheckTrue(r.SplitNeedsReassert(False),
                'the late contradiction still gets its one re-assert');
   finally
      r.Free;
   end;
end;

procedure TSplitReassertTests.TestCommandingSplitOffDisarmsIt;
var
   r: TFactoryRadioBase;
begin
   BeginTest('TestCommandingSplitOffDisarmsIt');
   r := NewK4;
   try
      r.NoteSplitCommanded(True);
      // The operator presses '-' again to leave split.  A report of "split off"
      // is now what we ASKED for, and re-asserting here would fight them.
      r.NoteSplitCommanded(False);
      CheckFalse(r.SplitNeedsReassert(False),
                 'split commanded OFF -- a report of off is agreement, not conflict');
   finally
      r.Free;
   end;
end;

procedure TSplitReassertTests.TestRadioWithoutTheTraitNeverReasserts;
var
   r: TFactoryRadioBase;
begin
   BeginTest('TestRadioWithoutTheTraitNeverReasserts');
   // The K3 shares the Elecraft base and the FT command but has NOT been watched
   // on a bench, so it does not declare the trait -- and must therefore never
   // re-assert, however the bookkeeping is driven.
   r := uRadioRegistry.CreateInstance(K3);
   try
      CheckFalse(r.Supports(rcSplitClearedByModeChange),
                 'the K3 does not declare the trait');
      r.NoteSplitCommanded(True);
      CheckFalse(r.SplitNeedsReassert(False),
                 'and so it never re-asserts, trait gates the whole mechanism');
   finally
      r.Free;
   end;
end;

procedure TSplitReassertTests.TestModeAlreadySetMatchesPerVFO;
var
   r: TFactoryRadioBase;
begin
   BeginTest('TestModeAlreadySetMatchesPerVFO');
   r := NewK4;
   try
      TRadioProbe(r).vfo[nrVFOB].mode := rmCW;

      CheckTrue(r.ModeAlreadySet(rmCW, nrVFOB),
                'VFO B is in CW, so commanding CW again is redundant');
      CheckFalse(r.ModeAlreadySet(rmUSB, nrVFOB),
                 'a DIFFERENT mode must still be commanded');
      // The bug was on VFO B; VFO A must not inherit the answer.
      CheckFalse(r.ModeAlreadySet(rmCW, nrVFOA),
                 'the two VFOs carry their own modes');
   finally
      r.Free;
   end;
end;

procedure TSplitReassertTests.TestModeNoneIsNeverAlreadySet;
var
   r: TFactoryRadioBase;
begin
   BeginTest('TestModeNoneIsNeverAlreadySet');
   r := NewK4;
   try
      TRadioProbe(r).vfo[nrVFOB].mode := rmNone;
      // rmNone means "no mode was asked for".  If it compared equal to an
      // unknown VFO mode the guard would suppress the FIRST mode command after
      // start-up, which is the one that matters most.
      CheckFalse(r.ModeAlreadySet(rmNone, nrVFOB),
                 'rmNone is not a mode and is never already set');
   finally
      r.Free;
   end;
end;

procedure TSplitReassertTests.TestDataModesAreNeverAlreadySet;
var
   r: TFactoryRadioBase;
begin
   BeginTest('TestDataModesAreNeverAlreadySet');
   r := NewK4;
   try
      // MD alone does not describe a data mode -- the sub-mode arrives
      // separately (DT on Elecraft) -- so two QSOs that are both "data" can
      // still need different frames.  Skipping on the mode alone would drop a
      // command that mattered, and that is worse than a redundant one.
      TRadioProbe(r).vfo[nrVFOB].mode := rmData;
      CheckFalse(r.ModeAlreadySet(rmData, nrVFOB), 'rmData always commands');

      TRadioProbe(r).vfo[nrVFOB].mode := rmFSK;
      CheckFalse(r.ModeAlreadySet(rmFSK, nrVFOB), 'rmFSK always commands');

      TRadioProbe(r).vfo[nrVFOB].mode := rmPSK;
      CheckFalse(r.ModeAlreadySet(rmPSK, nrVFOB), 'rmPSK always commands');

      TRadioProbe(r).vfo[nrVFOB].mode := rmAFSK;
      CheckFalse(r.ModeAlreadySet(rmAFSK, nrVFOB), 'rmAFSK always commands');
   finally
      r.Free;
   end;
end;

procedure TSplitReassertTests.TestOnlyTheK4DeclaresTheTrait;
var
   m: InterfacedRadioType;
   r: TFactoryRadioBase;
   declared: string;
   checked: integer;
begin
   BeginTest('TestOnlyTheK4DeclaresTheTrait');
   // THE ONE THAT MATTERS.  If the K4 ever loses this flag the original defect
   // comes back with nothing failing anywhere near the change; and if another
   // radio gains it without a bench session behind it, this says so.
   declared := '';
   checked := 0;
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if not uRadioRegistry.IsRegistered(m) then
         begin
         Continue;
         end;
      r := uRadioRegistry.CreateInstance(m);
      if r = nil then
         begin
         Continue;
         end;
      try
         Inc(checked);
         if r.Supports(rcSplitClearedByModeChange) then
            begin
            declared := declared + uRadioRegistry.DisplayName(m) + ' ';
            end;
      finally
         r.Free;
      end;
      end;

   Check(checked > 0, 'the registry produced no radios to check');
   CheckEquals('Elecraft K4 ', declared,
               'exactly one radio declares rcSplitClearedByModeChange, and it is ' +
               'the K4 -- the only one watched on a bench');
end;

procedure TSplitReassertTests.RunAllTests;
begin
   TestFreshRadioHasNothingCommanded;
   TestReassertsOnceWhenContradicted;
   TestBudgetIsSpentSoItCannotLoop;
   TestNewCommandRefreshesTheBudget;
   TestAgreeingReportDoesNotReassert;
   TestCommandingSplitOffDisarmsIt;
   TestRadioWithoutTheTraitNeverReasserts;
   TestModeAlreadySetMatchesPerVFO;
   TestModeNoneIsNeverAlreadySet;
   TestDataModesAreNeverAlreadySet;
   TestOnlyTheK4DeclaresTheTrait;
end;

end.
