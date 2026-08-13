unit uTestWinTimer;
{$I ..\..\src\tr4w.inc}

{
  Pins TWinTimer, the WM_TIMER timer that replaced VCL's TTimer in LOGRADIO.

  WHY THESE TESTS EXIST.  The one consumer is tmrCWByCAT -- the CW-by-CAT busy
  window -- so a behaviour difference here does not show up as a compile error
  or a crash.  It shows up as CW timing being subtly wrong on the air, which is
  the worst way to find out.  The VCL quirks are therefore pinned deliberately,
  including the one that looks like a bug (setting Interval RESTARTS a running
  timer rather than extending it) because LOGRADIO.AddTimeToCWByCATTimer is
  written around it.

  THE MESSAGE PUMP.  WM_TIMER is delivered to the thread's message queue, and a
  console test EXE has no loop -- so these tests pump one themselves.  That is
  also a faithful test of the real arrangement: in TR4W the timer's window is
  serviced by the main loop in tr4w.dpr.
}

interface

uses
   Windows, Messages, SysUtils, Classes,
   uTR4WTestFramework, uWinTimer;

type
   TWinTimerTests = class(TTestCase)
   private
      FFired: integer;
      FLastSender: TObject;
      FDisableOnFire: boolean;
      procedure HandleTimer(Sender: TObject);
      // Pump messages until the timer has fired `wanted` times or `budgetMs`
      // elapses.  Returns how long it actually took.
      function PumpUntilFired(wanted: integer; budgetMs: Cardinal): Cardinal;
   protected
      procedure Test_StartsDisabled;
      procedure Test_FiresAndPassesItselfAsSender;
      procedure Test_HandlerCanDisableFromInside;
      procedure Test_ZeroIntervalDoesNotFire;
      procedure Test_DisabledDoesNotFire;
      procedure Test_SettingIntervalRestartsARunningTimer;
      procedure Test_DestroyWhileRunningIsSafe;
   public
      procedure RunAllTests; override;
   end;

implementation

procedure TWinTimerTests.HandleTimer(Sender: TObject);
begin
   Inc(FFired);
   FLastSender := Sender;
   if FDisableOnFire then
      begin
      // Exactly what LOGRADIO's OnTimerTick does, to get one-shot behaviour.
      TWinTimer(Sender).Enabled := False;
      end;
end;

function TWinTimerTests.PumpUntilFired(wanted: integer; budgetMs: Cardinal): Cardinal;
var
   started: Cardinal;
   msg: TMsg;
begin
   started := GetTickCount;
   while (FFired < wanted) and (GetTickCount - started < budgetMs) do
      begin
      while PeekMessage(msg, 0, 0, 0, PM_REMOVE) do
         begin
         TranslateMessage(msg);
         DispatchMessage(msg);
         end;
      Sleep(1);
      end;
   Result := GetTickCount - started;
end;

procedure TWinTimerTests.Test_StartsDisabled;
var
   t: TWinTimer;
begin
   BeginTest('Test_StartsDisabled');
   // DELIBERATE DIFFERENCE from VCL TTimer, which is born Enabled with
   // Interval 1000 and starts a real timer you then switch off.  Every TR4W
   // call site assigns Enabled := False straight after Create, so nothing
   // changes for them -- and a timer that does nothing until asked is safer.
   t := TWinTimer.Create(nil);
   try
      CheckFalse(t.Enabled, 'a new timer is disabled');
      CheckEquals(1000, t.Interval, 'Interval still defaults to TTimer''s 1000');
   finally
      t.Free;
   end;
end;

procedure TWinTimerTests.Test_FiresAndPassesItselfAsSender;
var
   t: TWinTimer;
begin
   BeginTest('Test_FiresAndPassesItselfAsSender');
   FFired := 0;
   FLastSender := nil;
   FDisableOnFire := False;
   t := TWinTimer.Create(nil);
   try
      t.OnTimer := HandleTimer;
      t.Interval := 20;
      t.Enabled := True;
      PumpUntilFired(1, 2000);
      CheckTrue(FFired >= 1, 'the timer fired');
      // Sender must be the timer itself, or `TWinTimer(Sender).Enabled := False`
      // in LOGRADIO's handler would be operating on the wrong object.
      CheckTrue(FLastSender = t, 'Sender is the timer object');
   finally
      t.Free;
   end;
end;

procedure TWinTimerTests.Test_HandlerCanDisableFromInside;
var
   t: TWinTimer;
begin
   BeginTest('Test_HandlerCanDisableFromInside');
   // This IS the CW-by-CAT pattern: arm for the length of the message, fire
   // once, switch off.  Disabling from inside the handler must be safe and must
   // actually stop it -- if it fired repeatedly, CWByCAT_Sending would be
   // cleared over and over.
   FFired := 0;
   FDisableOnFire := True;
   t := TWinTimer.Create(nil);
   try
      t.OnTimer := HandleTimer;
      t.Interval := 15;
      t.Enabled := True;
      PumpUntilFired(1, 2000);
      CheckEquals(1, FFired, 'fired exactly once');
      CheckFalse(t.Enabled, 'the handler''s Enabled := False took effect');

      // And it stays off: keep pumping, nothing more arrives.
      PumpUntilFired(2, 300);
      CheckEquals(1, FFired, 'still once after further pumping');
   finally
      t.Free;
   end;
end;

procedure TWinTimerTests.Test_ZeroIntervalDoesNotFire;
var
   t: TWinTimer;
begin
   BeginTest('Test_ZeroIntervalDoesNotFire');
   // VCL semantics: Interval 0 means no timer, even when Enabled.
   FFired := 0;
   FDisableOnFire := False;
   t := TWinTimer.Create(nil);
   try
      t.OnTimer := HandleTimer;
      t.Interval := 0;
      t.Enabled := True;
      PumpUntilFired(1, 250);
      CheckEquals(0, FFired, 'Interval 0 never fires');
   finally
      t.Free;
   end;
end;

procedure TWinTimerTests.Test_DisabledDoesNotFire;
var
   t: TWinTimer;
begin
   BeginTest('Test_DisabledDoesNotFire');
   FFired := 0;
   FDisableOnFire := False;
   t := TWinTimer.Create(nil);
   try
      t.OnTimer := HandleTimer;
      t.Interval := 15;
      t.Enabled := False;
      PumpUntilFired(1, 250);
      CheckEquals(0, FFired, 'a disabled timer never fires');
   finally
      t.Free;
   end;
end;

procedure TWinTimerTests.Test_SettingIntervalRestartsARunningTimer;
var
   t: TWinTimer;
   elapsed: Cardinal;
begin
   BeginTest('Test_SettingIntervalRestartsARunningTimer');
   // THE QUIRK, PINNED.  In the VCL, assigning Interval to a running timer
   // kills and recreates it, so the countdown starts again -- it does not add
   // to the time remaining.  LOGRADIO.AddTimeToCWByCATTimer sets
   // Interval := Interval + ms to lengthen the CW busy window and depends on
   // exactly this; the comment there ("does not work properly") is about this
   // behaviour.  If a future rewrite makes Interval extend rather than restart,
   // CW busy windows silently shorten, and this test is what says so.
   FFired := 0;
   FDisableOnFire := False;
   t := TWinTimer.Create(nil);
   try
      t.OnTimer := HandleTimer;
      t.Interval := 400;
      t.Enabled := True;

      // 100 ms in, extend it the way AddTimeToCWByCATTimer does.  If Interval
      // merely extended the remaining time, the total wait would be ~700 ms
      // from the start; because it RESTARTS, it is ~800 ms from here.
      PumpUntilFired(1, 100);
      CheckEquals(0, FFired, 'has not fired yet at 100 ms of a 400 ms timer');
      t.Interval := t.Interval + 400;
      CheckEquals(800, t.Interval, 'Interval is the sum, as the caller expects');

      elapsed := PumpUntilFired(1, 3000);
      CheckTrue(FFired >= 1, 'fired after the restart');
      // Generous bound: this asserts "it restarted", not a precise deadline --
      // WM_TIMER is not a real-time facility and the pump adds jitter.
      CheckTrue(elapsed >= 600,
                'waited about the new interval from the reset, not the old remainder');
   finally
      t.Free;
   end;
end;

procedure TWinTimerTests.Test_DestroyWhileRunningIsSafe;
var
   t: TWinTimer;
   msg: TMsg;
   i: integer;
begin
   BeginTest('Test_DestroyWhileRunningIsSafe');
   // TR4W frees radio objects (and their timers) on a port change or shutdown,
   // possibly with the timer armed.  Destroy must kill the timer and release
   // the hidden window; a stale WM_TIMER arriving afterwards must not reach a
   // freed object.
   FFired := 0;
   FDisableOnFire := False;
   t := TWinTimer.Create(nil);
   t.OnTimer := HandleTimer;
   t.Interval := 10;
   t.Enabled := True;
   t.Free;

   for i := 1 to 50 do
      begin
      while PeekMessage(msg, 0, 0, 0, PM_REMOVE) do
         begin
         TranslateMessage(msg);
         DispatchMessage(msg);
         end;
      Sleep(1);
      end;
   CheckEquals(0, FFired, 'no callback after Free');
end;

procedure TWinTimerTests.RunAllTests;
begin
   Test_StartsDisabled;
   Test_FiresAndPassesItselfAsSender;
   Test_HandlerCanDisableFromInside;
   Test_ZeroIntervalDoesNotFire;
   Test_DisabledDoesNotFire;
   Test_SettingIntervalRestartsARunningTimer;
   Test_DestroyWhileRunningIsSafe;
end;

end.
