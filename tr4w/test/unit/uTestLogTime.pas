unit uTestLogTime;

(* THE ONE LOG TIMESTAMP (NY4I, 2026-11-23): UTC, ISO order, 24-hour, with a Z.
  Pinned here so the format cannot drift and a log never again carries a local
  time with no zone. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogTimeTests = class(TTestCase)
   protected
      procedure RunAllTests; override;
      procedure Test_FormatIsIsoWithAZ;
      procedure Test_TwentyFourHourClock;
      procedure Test_NowIsUtcNotLocal;
      procedure Test_Log4DLineCarriesTheEventsUtcTime;
   end;

implementation

uses
   SysUtils, DateUtils, uLogTime, Log4D, uLogConfig;

procedure TLogTimeTests.RunAllTests;
begin
   Test_FormatIsIsoWithAZ;
   Test_TwentyFourHourClock;
   Test_NowIsUtcNotLocal;
   Test_Log4DLineCarriesTheEventsUtcTime;
end;

procedure TLogTimeTests.Test_FormatIsIsoWithAZ;
begin
   BeginTest('Test_FormatIsIsoWithAZ');
   CheckEquals('2026-11-23 02:58:27.466Z',
               LogTimeText(EncodeDateTime(2026, 11, 23, 2, 58, 27, 466)),
               'year first, milliseconds, and the UTC marker');
end;

procedure TLogTimeTests.Test_TwentyFourHourClock;
begin
   BeginTest('Test_TwentyFourHourClock');
   CheckEquals('2026-11-23 23:05:09.007Z',
               LogTimeText(EncodeDateTime(2026, 11, 23, 23, 5, 9, 7)),
               'an evening hour is 23, not 11, with no AM/PM');
   CheckEquals('2026-01-02 00:00:00.000Z',
               LogTimeText(EncodeDateTime(2026, 1, 2, 0, 0, 0, 0)),
               'midnight is 00, not 12');
end;

procedure TLogTimeTests.Test_NowIsUtcNotLocal;
var
   a, b: TDateTime;
begin
   BeginTest('Test_NowIsUtcNotLocal');
   a := LogUtcNow;
   b := LocalTimeToUniversal(Now);
   CheckTrue(Abs(a - b) * 86400 < 5,
             'LogUtcNow agrees with the local clock converted to UTC (within 5 s)');
   CheckEquals('Z', Copy(LogNowText, Length(LogNowText), 1),
               'the current stamp ends in Z');
   CheckEquals(24, Length(LogNowText), 'and is the fixed-width ISO form');
end;

procedure TLogTimeTests.Test_Log4DLineCarriesTheEventsUtcTime;
var
   layout: ILogLayout;
   ev: TLogEvent;
   line: string;
begin
   BeginTest('Test_Log4DLineCarriesTheEventsUtcTime');
   layout := CreateTR4WLogLayout;
   ev := TLogEvent.Create(TLogLogger.GetLogger('LogTimeTests'), Info, 'hello', nil,
                          EncodeDateTime(2026, 11, 23, 2, 58, 27, 466));
   try
      line := layout.Format(ev);
   finally
      ev.Free;
   end;
   CheckTrue(Pos('2026-11-23 02:58:27.466Z', line) = 1,
             'the line starts with the EVENT''s UTC time, not the time it was formatted: ' + line);
end;

end.
