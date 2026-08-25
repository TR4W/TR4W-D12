unit uTestSpotAge;

{ THE BAND MAP SPOT AGE.

  Written WITH the change that introduced it, because every one of these cases
  is a defect the previous implementation actually had:

    * seconds discarded at capture, so two spots one second apart shared an age
      and expired on the same tick -- the reason a 1-minute decay emptied the
      whole map at once rather than ageing spots off individually;
    * a stamp in the future reading as very old, which is what an NTP step
      backwards would do to every spot in the list simultaneously;
    * calendar arithmetic that assumed 30-day months, so a spot held across a
      31-day month end read as ZERO minutes old and one across February jumped
      about three days. }

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TSpotAgeTests = class(TTestCase)
   protected
      procedure TestSameInstantIsZero;
      procedure TestOneSecondResolution;
      procedure TestSecondsWithinOneMinuteAreDistinct;
      procedure TestWholeMinutes;
      procedure TestFutureStampIsZeroNotHuge;
      procedure TestAcrossMidnight;
      procedure TestAcrossThirtyOneDayMonthEnd;
      procedure TestAcrossFebruaryMonthEnd;
      procedure TestRoundsToNearestSecond;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, DateUtils, uSpotAge;

procedure TSpotAgeTests.TestSameInstantIsZero;
var
   t: TDateTime;
begin
   BeginTest('TestSameInstantIsZero');
   t := EncodeDate(2026, 8, 25) + EncodeTime(14, 30, 0, 0);
   CheckEquals(0, AgeSeconds(t, t), 'a spot stamped now is age zero');
end;

procedure TSpotAgeTests.TestOneSecondResolution;
var
   stamp, now_: TDateTime;
begin
   BeginTest('TestOneSecondResolution');
   stamp := EncodeDate(2026, 8, 25) + EncodeTime(14, 30, 0, 0);
   now_  := EncodeDate(2026, 8, 25) + EncodeTime(14, 30, 1, 0);
   CheckEquals(1, AgeSeconds(stamp, now_), 'one second must be one second');
end;

procedure TSpotAgeTests.TestSecondsWithinOneMinuteAreDistinct;
var
   early, late, now_: TDateTime;
begin
   BeginTest('TestSecondsWithinOneMinuteAreDistinct');
   { THE ORIGINAL DEFECT.  These two spots arrive 58 seconds apart inside the
     same clock minute.  The old stamp threw the seconds away, so both carried
     the same age and both expired on the same tick -- which is why NY4I's map
     cleared all at once instead of ageing spots off one by one. }
   early := EncodeDate(2026, 8, 25) + EncodeTime(14, 30, 1, 0);
   late  := EncodeDate(2026, 8, 25) + EncodeTime(14, 30, 59, 0);
   now_  := EncodeDate(2026, 8, 25) + EncodeTime(14, 31, 0, 0);

   CheckEquals(59, AgeSeconds(early, now_), 'the earlier spot');
   CheckEquals(1,  AgeSeconds(late,  now_), 'the later spot');
   Check(AgeSeconds(early, now_) <> AgeSeconds(late, now_),
         'two spots in the same clock minute must NOT share an age');
end;

procedure TSpotAgeTests.TestWholeMinutes;
var
   stamp, now_: TDateTime;
begin
   BeginTest('TestWholeMinutes');
   stamp := EncodeDate(2026, 8, 25) + EncodeTime(10, 0, 0, 0);
   now_  := EncodeDate(2026, 8, 25) + EncodeTime(10, 6, 0, 0);
   CheckEquals(360, AgeSeconds(stamp, now_), 'six minutes is 360 seconds');
end;

procedure TSpotAgeTests.TestFutureStampIsZeroNotHuge;
var
   stamp, now_: TDateTime;
begin
   BeginTest('TestFutureStampIsZeroNotHuge');
   { SecondSpan is ABSOLUTE, so used alone this would report 3600 and the spot
     would be expired by any decay time under an hour.  A clock stepping
     backwards would do this to EVERY spot at once. }
   stamp := EncodeDate(2026, 8, 25) + EncodeTime(15, 0, 0, 0);
   now_  := EncodeDate(2026, 8, 25) + EncodeTime(14, 0, 0, 0);
   CheckEquals(0, AgeSeconds(stamp, now_),
               'a stamp in the future is age zero, never a large age');
end;

procedure TSpotAgeTests.TestAcrossMidnight;
var
   stamp, now_: TDateTime;
begin
   BeginTest('TestAcrossMidnight');
   stamp := EncodeDate(2026, 8, 25) + EncodeTime(23, 58, 0, 0);
   now_  := EncodeDate(2026, 8, 26) + EncodeTime(0, 2, 0, 0);
   CheckEquals(240, AgeSeconds(stamp, now_), 'four minutes across midnight');
end;

procedure TSpotAgeTests.TestAcrossThirtyOneDayMonthEnd;
var
   stamp, now_: TDateTime;
begin
   BeginTest('TestAcrossThirtyOneDayMonthEnd');
   { The old scalar folded months in as 30 days, so 31 August -> 1 September
     cancelled exactly and a spot from the previous evening read as ZERO
     minutes old -- ageless, and never expiring. }
   stamp := EncodeDate(2026, 8, 31) + EncodeTime(23, 50, 0, 0);
   now_  := EncodeDate(2026, 9, 1)  + EncodeTime(0, 10, 0, 0);
   CheckEquals(1200, AgeSeconds(stamp, now_),
               'twenty minutes across a 31-day month end');
end;

procedure TSpotAgeTests.TestAcrossFebruaryMonthEnd;
var
   stamp, now_: TDateTime;
begin
   BeginTest('TestAcrossFebruaryMonthEnd');
   { And February ran the other way: the same twenty minutes read as roughly
     three days, so every spot expired instantly. }
   stamp := EncodeDate(2026, 2, 28) + EncodeTime(23, 50, 0, 0);
   now_  := EncodeDate(2026, 3, 1)  + EncodeTime(0, 10, 0, 0);
   CheckEquals(1200, AgeSeconds(stamp, now_),
               'twenty minutes across February');
end;

procedure TSpotAgeTests.TestRoundsToNearestSecond;
var
   stamp, now_: TDateTime;
begin
   BeginTest('TestRoundsToNearestSecond');
   stamp := EncodeDate(2026, 8, 25) + EncodeTime(12, 0, 0, 0);
   now_  := EncodeDate(2026, 8, 25) + EncodeTime(12, 0, 2, 600);
   CheckEquals(3, AgeSeconds(stamp, now_), '2.6 seconds rounds to 3');
end;

procedure TSpotAgeTests.RunAllTests;
begin
   TestSameInstantIsZero;
   TestOneSecondResolution;
   TestSecondsWithinOneMinuteAreDistinct;
   TestWholeMinutes;
   TestFutureStampIsZeroNotHuge;
   TestAcrossMidnight;
   TestAcrossThirtyOneDayMonthEnd;
   TestAcrossFebruaryMonthEnd;
   TestRoundsToNearestSecond;
end;

end.
