unit uTestHPTimer;

(* THE HIGH-RESOLUTION CLOCK -- uHPTimer's measurement half.

  Two kinds of test, kept apart on purpose:

  THE ARITHMETIC is pinned with SYNTHETIC ratios and tick counts, so what it
  proves does not depend on the test host's clock. Apple Silicon's 125/3 and
  a month of Linux nanoseconds are checked on a Windows box. Those are the
  cases a wrong conversion gets wrong, and the host clock would never show
  them.

  THE LIVE CLOCK is checked for the properties that hold on any machine:
  monotonic, a positive and stable rate, and an interval that agrees with the
  RTL's millisecond clock. That last one is what catches a WRONG TIMEBASE --
  hardcoding 1/1 on Apple Silicon reads every interval 41.67x too long, and
  no amount of monotonicity would notice.

  THE LIVE BRACKETS ARE DELIBERATELY WIDE. CI runners are noisy and a
  flaky clock test gets ignored, so the bounds are tight enough to catch a
  wrong timebase (off by 24x, 41x or 1000x) and loose enough for a busy
  runner. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   THPTimerTests = class(TTestCase)
   private
      procedure CheckInt64(const aExpected, aActual: Int64; const aMsg: string);
      function ScaleRaises(const aTicks, aNumer, aDenom: Int64): boolean;
   protected
      (* pure arithmetic *)
      procedure TestReduceRatio;
      procedure TestReduceRejectsNonPositive;
      procedure TestQPCTenMegahertz;
      procedure TestLinuxNanoseconds;
      procedure TestAppleSiliconTimebase;
      procedure TestIntelMacTimebase;
      procedure TestIrreducibleAcpiRatio;
      procedure TestTruncatesTowardZero;
      procedure TestNegativeIsSymmetric;
      procedure TestLargeTickCountsDoNotOverflow;
      procedure TestUnrepresentableInputsRaise;
      (* the live clock *)
      procedure TestTimebaseIsAvailable;
      procedure TestTicksPerSecondPositiveAndStable;
      procedure TestOneSecondOfTicksIsOneMillionMicroseconds;
      procedure TestMonotonicNonDecreasing;
      procedure TestElapsedOverSleepIsSane;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uHPTimer;

const
   US_PER_S = Int64(1000000);

procedure THPTimerTests.CheckInt64(const aExpected, aActual: Int64; const aMsg: string);
begin
   (* The framework's CheckEquals is Integer-only and would truncate these
     silently -- which is the very defect class this suite exists to catch. *)
   Check(aExpected = aActual,
         Format('%s: expected %d, got %d', [aMsg, aExpected, aActual]));
end;

function THPTimerTests.ScaleRaises(const aTicks, aNumer, aDenom: Int64): boolean;
begin
   Result := False;
   try
      HPScaleTicks(aTicks, aNumer, aDenom);
   except
      on EHPTimerError do
         begin
         Result := True;
         end;
   end;
end;

(* ---- pure arithmetic --------------------------------------------------- *)

procedure THPTimerTests.TestReduceRatio;
var
   n, d: Int64;
begin
   BeginTest('TestReduceRatio');

   n := 1000000;
   d := 10000000;
   HPReduceRatio(n, d);
   CheckInt64(1, n, 'QPC 10 MHz numerator');
   CheckInt64(10, d, 'QPC 10 MHz denominator');

   (* Apple Silicon: us = ticks * 125 / (3 * 1000) = ticks / 24. *)
   n := 125;
   d := 3000;
   HPReduceRatio(n, d);
   CheckInt64(1, n, 'Apple Silicon numerator');
   CheckInt64(24, d, 'Apple Silicon denominator');

   (* The 3.579545 MHz ACPI PM timer shares only a factor of 5 with 10^6. *)
   n := 1000000;
   d := 3579545;
   HPReduceRatio(n, d);
   CheckInt64(200000, n, 'ACPI numerator');
   CheckInt64(715909, d, 'ACPI denominator');

   n := 7;
   d := 7;
   HPReduceRatio(n, d);
   CheckInt64(1, n, 'equal terms numerator');
   CheckInt64(1, d, 'equal terms denominator');
end;

procedure THPTimerTests.TestReduceRejectsNonPositive;
var
   n, d: Int64;
   raised: boolean;
begin
   BeginTest('TestReduceRejectsNonPositive');
   n := 0;
   d := 5;
   raised := False;
   try
      HPReduceRatio(n, d);
   except
      on EHPTimerError do
         begin
         raised := True;
         end;
   end;
   Check(raised, 'a zero numerator must raise, not divide by zero');
end;

procedure THPTimerTests.TestQPCTenMegahertz;
begin
   BeginTest('TestQPCTenMegahertz');
   CheckInt64(US_PER_S, HPScaleTicks(10000000, 1, 10), 'one second of QPC');
   CheckInt64(40000,    HPScaleTicks(400000, 1, 10),   'a 40 ms dit');
end;

procedure THPTimerTests.TestLinuxNanoseconds;
begin
   BeginTest('TestLinuxNanoseconds');
   CheckInt64(US_PER_S, HPScaleTicks(1000000000, 1, 1000), 'one second of ns');
   CheckInt64(30000,    HPScaleTicks(30000000, 1, 1000),   'a 30 ms dit');
end;

procedure THPTimerTests.TestAppleSiliconTimebase;
var
   n, d: Int64;
begin
   BeginTest('TestAppleSiliconTimebase');
   (* Built the way the Darwin arm builds it, from numer/denom = 125/3, so the
     test pins the DERIVATION and not only a pre-reduced answer. *)
   n := 125;
   d := Int64(3) * 1000;
   HPReduceRatio(n, d);
   CheckInt64(US_PER_S, HPScaleTicks(24000000, n, d), 'one second of a 24 MHz counter');
   CheckInt64(40000,    HPScaleTicks(960000, n, d),   'a 40 ms dit at 24 MHz');

   (* THE DEFECT THIS EXISTS TO PREVENT: treating the ticks as nanoseconds
     (a hardcoded 1/1) makes one real second read as 24 ms. *)
   Check(HPScaleTicks(24000000, 1, 1000) <> US_PER_S,
         'a hardcoded 1/1 timebase must NOT agree on Apple Silicon');
end;

procedure THPTimerTests.TestIntelMacTimebase;
var
   n, d: Int64;
begin
   BeginTest('TestIntelMacTimebase');
   n := 1;
   d := Int64(1) * 1000;
   HPReduceRatio(n, d);
   CheckInt64(US_PER_S, HPScaleTicks(1000000000, n, d), 'one second at 1/1');
end;

procedure THPTimerTests.TestIrreducibleAcpiRatio;
begin
   BeginTest('TestIrreducibleAcpiRatio');
   (* A ratio that does NOT reduce to 1/N exercises the remainder term. *)
   CheckInt64(US_PER_S, HPScaleTicks(3579545, 200000, 715909), 'one second of ACPI ticks');
   (* 1 tick = 0.279 us, truncated. *)
   CheckInt64(0, HPScaleTicks(1, 200000, 715909), 'one ACPI tick');
   (* 4 ticks = 1.117 us. *)
   CheckInt64(1, HPScaleTicks(4, 200000, 715909), 'four ACPI ticks');
end;

procedure THPTimerTests.TestTruncatesTowardZero;
begin
   BeginTest('TestTruncatesTowardZero');
   CheckInt64(0, HPScaleTicks(23, 1, 24), '23 ticks at 24 MHz is under a microsecond');
   CheckInt64(1, HPScaleTicks(24, 1, 24), '24 ticks is exactly one');
   CheckInt64(1, HPScaleTicks(47, 1, 24), '47 ticks truncates to one');
   CheckInt64(0, HPScaleTicks(0, 1, 24),  'zero ticks');
end;

procedure THPTimerTests.TestNegativeIsSymmetric;
begin
   BeginTest('TestNegativeIsSymmetric');
   CheckInt64(-US_PER_S, HPScaleTicks(-24000000, 1, 24), 'minus one second');
   CheckInt64(-1, HPScaleTicks(-47, 1, 24), 'negative truncates toward zero too');
   CheckInt64(-US_PER_S, HPScaleTicks(-3579545, 200000, 715909), 'minus one ACPI second');
end;

procedure THPTimerTests.TestLargeTickCountsDoNotOverflow;
const
   SECONDS_30_DAYS = Int64(30) * 86400;
   SECONDS_1_YEAR  = Int64(365) * 86400;
   SECONDS_100_Y   = Int64(100) * 365 * 86400;
begin
   BeginTest('TestLargeTickCountsDoNotOverflow');
   (* THE OVERFLOW CLAIM, pinned. Each of these makes the naive
     ticks * 10^6 div rate overflow Int64 -- a month of Linux nanoseconds is
     2.6e15 ticks, times 10^6 is 2.6e21. *)
   CheckInt64(SECONDS_30_DAYS * US_PER_S,
              HPScaleTicks(SECONDS_30_DAYS * 1000000000, 1, 1000),
              '30 days of Linux nanoseconds');
   CheckInt64(SECONDS_30_DAYS * US_PER_S,
              HPScaleTicks(SECONDS_30_DAYS * 24000000, 1, 24),
              '30 days of Apple Silicon ticks');
   CheckInt64(SECONDS_30_DAYS * US_PER_S,
              HPScaleTicks(SECONDS_30_DAYS * 10000000, 1, 10),
              '30 days of QPC');
   CheckInt64(SECONDS_1_YEAR * US_PER_S,
              HPScaleTicks(SECONDS_1_YEAR * 3579545, 200000, 715909),
              'a year of the irreducible ACPI ratio');
   CheckInt64(SECONDS_100_Y * US_PER_S,
              HPScaleTicks(SECONDS_100_Y * 1000000000, 1, 1000),
              'a century of nanoseconds');
   (* The largest possible tick count still converts when the result fits. *)
   CheckInt64(High(Int64) div 1000, HPScaleTicks(High(Int64), 1, 1000),
              'High(Int64) nanoseconds');
end;

procedure THPTimerTests.TestUnrepresentableInputsRaise;
begin
   BeginTest('TestUnrepresentableInputsRaise');
   Check(ScaleRaises(1, 1, 0),  'a zero denominator must raise');
   Check(ScaleRaises(1, 0, 1),  'a zero numerator must raise');
   Check(ScaleRaises(1, -1, 1), 'a negative numerator must raise');
   (* numer * denom would overflow the remainder product: refused up front. *)
   Check(ScaleRaises(1, High(Int64) div 2, 3),
         'a ratio whose terms multiply past Int64 must raise');
   (* A result that does not fit must raise, never wrap. *)
   Check(ScaleRaises(High(Int64), 2, 1), 'an overflowing RESULT must raise');
   Check(ScaleRaises(Low(Int64), 2, 1),  'an overflowing negative result must raise');
end;

(* ---- the live clock ---------------------------------------------------- *)

procedure THPTimerTests.TestTimebaseIsAvailable;
begin
   BeginTest('TestTimebaseIsAvailable');
   Check(Pos('UNAVAILABLE', HPTimebaseDescription) = 0,
         'the platform timebase must initialise: ' + HPTimebaseDescription);
end;

procedure THPTimerTests.TestTicksPerSecondPositiveAndStable;
var
   first, second: Int64;
begin
   BeginTest('TestTicksPerSecondPositiveAndStable');
   first  := HPTicksPerSecond;
   second := HPTicksPerSecond;
   (* 1 MHz floor: anything coarser is not a high-resolution clock, and every
     real source is well above it (QPC 10 MHz, Apple 24 MHz, Linux 1 GHz). *)
   Check(first >= 1000000,
         Format('ticks per second must be >= 1 MHz, got %d (%s)',
                [first, HPTimebaseDescription]));
   CheckInt64(first, second, 'ticks per second is stable across calls');
end;

procedure THPTimerTests.TestOneSecondOfTicksIsOneMillionMicroseconds;
begin
   BeginTest('TestOneSecondOfTicksIsOneMillionMicroseconds');
   (* Exact on every supported platform: QPF and 10^9 are exact, and both
     Darwin timebases in the field give an integral rate. *)
   CheckInt64(US_PER_S, HPTicksToMicroseconds(HPTicksPerSecond),
              'HPTicksPerSecond ticks converted, ' + HPTimebaseDescription);
end;

procedure THPTimerTests.TestMonotonicNonDecreasing;
const
   READS = 200000;
var
   i, backwards: integer;
   previous, current: Int64;
begin
   BeginTest('TestMonotonicNonDecreasing');
   backwards := 0;
   previous := HPTicks;
   for i := 1 to READS do
      begin
      current := HPTicks;
      if current < previous then
         begin
         Inc(backwards);
         end;
      previous := current;
      end;
   CheckEquals(0, backwards, 'reads that went backwards in ' + IntToStr(READS));
end;

procedure THPTimerTests.TestElapsedOverSleepIsSane;
const
   SLEEP_MS = 200;
var
   hpStart, msStart, msElapsed: Int64;
   usElapsed, hpMs, difference: Int64;
begin
   BeginTest('TestElapsedOverSleepIsSane');
   msStart := Int64(GetTickCount64);
   hpStart := HPTicks;
   Sleep(SLEEP_MS);
   usElapsed := HPElapsedMicroseconds(hpStart);
   msElapsed := Int64(GetTickCount64) - msStart;
   hpMs := usElapsed div 1000;

   (* Bracket 1: against the REQUEST. Sleep may overshoot on a busy runner by
     a lot, and on Windows can land up to one 15.6 ms tick early -- so 150 ms
     to 5 s. A timebase error of 24x, 41x or 1000x lands far outside. *)
   Check((usElapsed >= 150000) and (usElapsed <= 5000000),
         Format('Sleep(%d) measured %d us; expected 150000..5000000 (%s)',
                [SLEEP_MS, usElapsed, HPTimebaseDescription]));

   (* Bracket 2: against the RTL's own millisecond clock over the SAME
     interval, which cancels the scheduler's noise -- both clocks saw the
     same overshoot. What is left is GetTickCount64's granularity (up to
     ~16 ms at each end on Windows), so 50 ms is generous. This is the check
     that proves the RATE, not merely that time moved forward. *)
   difference := hpMs - msElapsed;
   Check((difference >= -50) and (difference <= 50),
         Format('HP clock %d ms vs GetTickCount64 %d ms over one Sleep(%d); differ by %d (%s)',
                [hpMs, msElapsed, SLEEP_MS, difference, HPTimebaseDescription]));
end;

procedure THPTimerTests.RunAllTests;
begin
   TestReduceRatio;
   TestReduceRejectsNonPositive;
   TestQPCTenMegahertz;
   TestLinuxNanoseconds;
   TestAppleSiliconTimebase;
   TestIntelMacTimebase;
   TestIrreducibleAcpiRatio;
   TestTruncatesTowardZero;
   TestNegativeIsSymmetric;
   TestLargeTickCountsDoNotOverflow;
   TestUnrepresentableInputsRaise;
   TestTimebaseIsAvailable;
   TestTicksPerSecondPositiveAndStable;
   TestOneSecondOfTicksIsOneMillionMicroseconds;
   TestMonotonicNonDecreasing;
   TestElapsedOverSleepIsSane;
end;

end.
