unit uTestStatusAndNotice;
{$I ..\..\src\tr4w.inc}

(* THE TWO CHANNELS THE MAIN WINDOW HAS FOR TELLING THE OPERATOR SOMETHING.

  Until 2026-09-26 there was one -- pnlQuickCommand's caption, written from ~120
  call sites -- and it carried both kinds of message:

     a NOTICE    an EVENT announcement.  "142 QSOs imported".
     a STATUS    a projection of a CONDITION.  "Auth failed - check
                 credentials", which is true until an operator fixes it.

  MIXING THEM MEANT "SET BY ONE PATH, CLEARED BY ANOTHER" WAS ALWAYS POSSIBLE,
  and NY4I measured it: a corrected IC-7760 password connected while the banner
  still read the old authentication failure, because the radio had been REBUILT
  and the thread that wrote the message no longer existed to clear it.

  SO THE ASSERTIONS HERE ARE ABOUT THE SPLIT, not about either channel's text.
  A status must not arm a timer; a notice must; and one owner's panel must be
  unreachable from another owner.  Test_ClearingOneOwnerLeavesTheOthersAlone is
  the one that makes the whole change worth doing -- it is the defect above,
  expressed as something that can no longer happen.

  THE FORM IS LOADED FROM ITS RESOURCE, NOT BUILT IN CODE.  VERIFYING A DESIGNED
  FORM BY REBUILDING IT IN CODE PROVES NOTHING ABOUT THE FORM: the status strip
  and the notice timer live in uMainForm.lfm, and a hand-built TStatusBar with
  four panels would pass while the .lfm carried three.
  Test_TheStripHasOnePanelPerOwner asks the streamed form. *)

interface

uses
   SysUtils, Classes, Forms, ComCtrls,
   uTR4WTestFramework,
   VC,              (* TStatusOwner, mweQuickCommand *)
   LogRadio,        (* RadioStatusOwner, Radio1, Radio2 *)
   uCrashLog,       (* InstallCrashLog -- see EnsureMainForm; it is what puts
                      the MAIN THREAD on record *)
   uPanelUpdate,    (* PostStatusText / CurrentStatusText -- the marshalled
                      writer and the cache a view reads when it opens *)
   uRadioPolling,   (* ShowRadioLinkFailure -- the condition/remedy split *)
   uMainForm;       (* the form, the panels and the notice timer *)

type
   TStatusAndNoticeTests = class(TTestCase)
   private
      (* The designed main window, streamed once.  See EnsureMainForm. *)
      procedure EnsureMainForm;
      procedure ReleaseMainForm;
      (* Drain the LCL's async queue -- which is what PostStatusText hands to --
        for up to budgetMs, or until aOwner's panel reads aWanted. *)
      function  DrainUntilStatus(const aOwner: TStatusOwner;
                                 const aWanted: string;
                                 const aBudgetMs: Cardinal): boolean;
      procedure Drain;
   protected
      procedure Test_TheStripHasOnePanelPerOwner;
      procedure Test_TheNoticeTimerIsAThirtySecondOneShot;
      procedure Test_ANoticeSetsTheCaptionAndArmsTheTimer;
      procedure Test_ASecondNoticeRestartsTheWipe;
      procedure Test_TheWipeClearsTheCaption;
      procedure Test_AnEmptyNoticeClearsAndDisarms;
      procedure Test_AStatusArmsNoTimer;
      procedure Test_ClearingOneOwnerLeavesTheOthersAlone;
      procedure Test_AStatusWrittenOffTheMainThreadLands;
      procedure Test_PostStatusTextSaysWhetherItTravelled;
      procedure Test_RadioStatusOwnerAnswersForBothSlots;
      procedure Test_ThePanelsSpanTheStrip;
      procedure Test_TheConditionGoesToTheStatusAndTheRemedyToTheNotice;
      procedure Test_TheRemedyIsNotRepeatedOnARetry;
      procedure Test_APanelOpeningLaterCanReadTheCondition;
   public
      procedure RunAllTests; override;
   end;

implementation

(* A WORKER THREAD THAT WRITES ONE STATUS AND EXITS.

  IT EXITS ON PURPOSE, IMMEDIATELY.  That is the case the transport choice is
  about: TThread.Queue stamps an entry with the calling thread's id and
  TThread.Destroy purges by it, so this thread would delete its own pending
  write -- and a radio polling thread is destroyed on every reconnect, which is
  exactly when a link-failure message matters.  QueueAsyncCall is not tied to a
  thread's lifetime, and this test fails if that ever changes. *)
type
   TStatusWriterThread = class(TThread)
   private
      FOwner: TStatusOwner;
      FText:  string;
   protected
      procedure Execute; override;
   public
      constructor Create(const aOwner: TStatusOwner; const aText: string);
   end;

constructor TStatusWriterThread.Create(const aOwner: TStatusOwner;
                                       const aText: string);
begin
   FOwner := aOwner;
   FText  := aText;
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TStatusWriterThread.Execute;
begin
   PostStatusText(FOwner, FText);
end;

(* ---------------------------------------------------------------------- *)

procedure TStatusAndNoticeTests.EnsureMainForm;
begin
   if TR4WMainForm <> nil then
      begin
      Exit;
      end;

   (* Create(nil) STREAMS uMainForm.lfm and nothing else: this form has no
     OnCreate, so none of TR4W's startup runs and no window handle is
     allocated.  BindMainElements is what makes SetElementText able to reach
     pnlQuickCommand -- it is the same call CreateMainWindow makes.

     FREED AT THE END OF THE SUITE -- see ReleaseMainForm for why that matters
     to somebody else's tests. *)
   (* WITHOUT THIS EVERY GUARD IN uMainForm SAYS "OFF THE MAIN THREAD", AND
     THAT IS A FACT ABOUT THIS BINARY, NOT ABOUT THE CODE UNDER TEST.
     uCrashLog.OnMainThread compares against GMainThreadId, which is recorded by
     InstallCrashLog and is 0 until something calls it -- BOTH shipping programs
     call InstallCrashLogLCL (the app from uProgramMain, tr4wserver from its own
     program body), and that installs the RTL half too, so both are fine.  This
     said "tr4wserver calls InstallCrashLog" until 2026-09-28; it does not, and
     for a while it called neither.  A test binary that skips it finds
     SetElementText deferring every write and SetStatusText dropping every one,
     with nothing in the log to say so, because ReportOffMainThread also stays
     quiet while GMainThreadId is 0.  Idempotent. *)
   InstallCrashLog;

   (* AND THE WIDGET SET HAS TO BE INITIALISED, which a test binary never
     does for itself: without it the first control that needs a window dies with
     "Failed to create win32 control, error 1407: Cannot find window class",
     because the classes are registered by Application.Initialize.  It starts no
     message loop -- Application.Run is what does that -- so this stays a
     console test. *)
   if Application <> nil then
      begin
      Application.Initialize;
      end;

   TR4WMainForm := TTR4WMainForm.Create(nil);
   BindMainElements;

   (* AND THE PANEL NEEDS A WINDOW, because ControlUsable asks HandleAllocated
     -- deliberately, after a startup crash in 2026-08 that came of dropping
     that half of the guard.  The LCL creates a control's window lazily, and
     this form is never shown, so the test has to give the control what a
     running program gives it.  Reading .Handle is what forces it. *)
   if MainElement(mweQuickCommand) <> nil then
      begin
      MainElement(mweQuickCommand).HandleNeeded;
      end;
end;

(* PUT THE PROCESS BACK AS IT WAS FOUND, AND THIS IS NOT TIDINESS.

  TWO OTHER SUITES ASSERT AGAINST TR4WMainForm BEING NIL -- uTestEditingKeys
  pins that the main window is exempt from the editing-key rule, and says in its
  own comment that a console test can only ask it that way.  Leaving a form
  behind failed three of their assertions, which is the clearest possible
  demonstration that a suite must not leave global state behind.

  BindMainElements with no form clears GElements, so nothing is left pointing at
  the freed panels. *)
procedure TStatusAndNoticeTests.ReleaseMainForm;
var
   frm: TTR4WMainForm;
begin
   if TR4WMainForm = nil then
      begin
      Exit;
      end;

   frm := TR4WMainForm;
   TR4WMainForm := nil;
   BindMainElements;
   frm.Free;
end;

procedure TStatusAndNoticeTests.Drain;
begin
   if Application <> nil then
      begin
      Application.ProcessMessages;
      end;
end;

function TStatusAndNoticeTests.DrainUntilStatus(const aOwner: TStatusOwner;
                                                const aWanted: string;
                                                const aBudgetMs: Cardinal): boolean;
var
   (* QWord with GetTickCount64: `deadline := now + timeout` wraps past its own
     start on a 32-bit counter and ends the wait immediately. *)
   started: QWord;
begin
   started := GetTickCount64;
   repeat
      Drain;
      Result := StatusText(aOwner) = aWanted;
      if Result then
         begin
         Exit;
         end;
      Sleep(1);
   until GetTickCount64 - started >= aBudgetMs;

   Result := StatusText(aOwner) = aWanted;
end;

procedure TStatusAndNoticeTests.Test_TheStripHasOnePanelPerOwner;
begin
   EnsureMainForm;

   CheckTrue(TR4WMainForm.sbStatus <> nil,
             'uMainForm.lfm must carry sbStatus');

   (* ONE PER OWNER IS THE WHOLE DESIGN.  A strip with fewer panels than owners
     would silently give two subsystems the same panel back, which is the shared
     caption again with extra steps. *)
   CheckEquals(Ord(High(TStatusOwner)) + 1,
               TR4WMainForm.sbStatus.Panels.Count,
               'one status panel per TStatusOwner');

   CheckFalse(TR4WMainForm.sbStatus.SimplePanel,
              'SimplePanel would collapse all four into one caption');
end;

procedure TStatusAndNoticeTests.Test_TheNoticeTimerIsAThirtySecondOneShot;
begin
   EnsureMainForm;

   CheckTrue(TR4WMainForm.tmrQuickCommandNotice <> nil,
             'uMainForm.lfm must carry tmrQuickCommandNotice');

   (* THE DESIGNED VALUES, because both were wrong in the mechanism this
     replaced: the old wipe was 30 s and armed from any thread, and a timer that
     ships ENABLED would wipe the first notice of the session early. *)
   CheckEquals(30000, TR4WMainForm.tmrQuickCommandNotice.Interval,
               'the 30 s wipe NY4I asked to keep');
   CheckFalse(TR4WMainForm.tmrQuickCommandNotice.Enabled,
              'it is armed by a notice, not by loading the form');
end;

procedure TStatusAndNoticeTests.Test_ANoticeSetsTheCaptionAndArmsTheTimer;
begin
   EnsureMainForm;

   ShowQuickCommandNotice('142 QSOs imported');

   CheckEquals('142 QSOs imported',
               string(MainElement(mweQuickCommand).Caption),
               'a notice goes on pnlQuickCommand');
   CheckTrue(QuickCommandNoticeArmed,
             'and arms the wipe -- a notice has no condition to be cleared by');
end;

procedure TStatusAndNoticeTests.Test_ASecondNoticeRestartsTheWipe;
var
   saved: integer;
begin
   EnsureMainForm;

   (* A 30 s assertion is not a test.  Shorten the interval, and put it back:
     the designed value is pinned by its own case above. *)
   saved := TR4WMainForm.tmrQuickCommandNotice.Interval;
   try
      TR4WMainForm.tmrQuickCommandNotice.Interval := 120;

      ShowQuickCommandNotice('first');
      DrainUntilStatus(stoRadio1, '@never', 80);   (* 80 ms of pumping *)

      ShowQuickCommandNotice('second');
      DrainUntilStatus(stoRadio1, '@never', 80);   (* 160 ms since 'first' *)

      (* WITHOUT THE RESTART the countdown started at 'first' and has expired,
        so the caption would be blank 160 ms in.  With it, 'second' has only
        had 80 ms of its own 120. *)
      CheckEquals('second', string(MainElement(mweQuickCommand).Caption),
                  'the second notice RESTARTS the wipe rather than inheriting '
                  + 'what was left of the first one''s');
      CheckTrue(QuickCommandNoticeArmed, 'and the wipe is still armed');
   finally
      TR4WMainForm.tmrQuickCommandNotice.Enabled := False;
      TR4WMainForm.tmrQuickCommandNotice.Interval := saved;
   end;
end;

procedure TStatusAndNoticeTests.Test_TheWipeClearsTheCaption;
var
   saved:   integer;
   started: QWord;
begin
   EnsureMainForm;

   saved := TR4WMainForm.tmrQuickCommandNotice.Interval;
   try
      TR4WMainForm.tmrQuickCommandNotice.Interval := 60;
      ShowQuickCommandNotice('this should go away');

      started := GetTickCount64;
      while (MainElement(mweQuickCommand).Caption <> '') and
            (GetTickCount64 - started < 3000) do
         begin
         Drain;
         Sleep(1);
         end;

      CheckEquals('', string(MainElement(mweQuickCommand).Caption),
                  'the wipe fires and clears the notice');
      CheckFalse(QuickCommandNoticeArmed,
                 'ONE SHOT: it disarms itself rather than wiping every 30 s');
   finally
      TR4WMainForm.tmrQuickCommandNotice.Enabled := False;
      TR4WMainForm.tmrQuickCommandNotice.Interval := saved;
   end;
end;

procedure TStatusAndNoticeTests.Test_AnEmptyNoticeClearsAndDisarms;
begin
   EnsureMainForm;

   ShowQuickCommandNotice('something');
   CheckTrue(QuickCommandNoticeArmed, 'armed by the notice');

   (* QuickDisplay('') has always meant "clear it", and there is nothing left to
     wipe -- so arming a timer for it would keep the main thread waking up for
     thirty seconds to do nothing. *)
   ShowQuickCommandNotice('');

   CheckEquals('', string(MainElement(mweQuickCommand).Caption), 'cleared');
   CheckFalse(QuickCommandNoticeArmed, 'and the wipe is disarmed, not armed');
end;

procedure TStatusAndNoticeTests.Test_AStatusArmsNoTimer;
begin
   EnsureMainForm;

   ShowQuickCommandNotice('');            (* a known, disarmed starting point *)
   CheckFalse(QuickCommandNoticeArmed, 'precondition');

   SetStatusText(stoRadio1, 'IC7760: Auth failed - check credentials');

   (* THE ASSERTION THE WHOLE SPLIT EXISTS FOR.  A condition that auto-wipes is
     a condition an operator stops being told about while it is still true. *)
   CheckFalse(QuickCommandNoticeArmed,
              'a STATUS never arms the wipe -- it stays until the condition ends');
   CheckEquals('IC7760: Auth failed - check credentials',
               StatusText(stoRadio1), 'and it is on Radio 1''s own panel');
   CheckEquals('', string(MainElement(mweQuickCommand).Caption),
               'and not on the notice panel');

   SetStatusText(stoRadio1, '');
end;

procedure TStatusAndNoticeTests.Test_ClearingOneOwnerLeavesTheOthersAlone;
begin
   EnsureMainForm;

   SetStatusText(stoRadio1, 'radio one');
   SetStatusText(stoRadio2, 'radio two');
   SetStatusText(stoCluster, 'cluster');
   SetStatusText(stoNetwork, 'network');

   (* Radio 1 recovers.  THIS IS THE 2026-09-26 DEFECT MADE UNREPRESENTABLE:
     with one shared caption, whichever subsystem spoke last owned it, so a
     recovery could wipe somebody else's live condition and a notice could wipe
     a failure that was still true. *)
   SetStatusText(stoRadio1, '');

   CheckEquals('', StatusText(stoRadio1), 'Radio 1 cleared its own panel');
   CheckEquals('radio two', StatusText(stoRadio2), 'Radio 2 untouched');
   CheckEquals('cluster', StatusText(stoCluster), 'the cluster untouched');
   CheckEquals('network', StatusText(stoNetwork), 'the network untouched');

   SetStatusText(stoRadio2, '');
   SetStatusText(stoCluster, '');
   SetStatusText(stoNetwork, '');
end;

procedure TStatusAndNoticeTests.Test_AStatusWrittenOffTheMainThreadLands;
var
   th: TStatusWriterThread;
begin
   EnsureMainForm;
   SetStatusText(stoRadio2, '');

   th := TStatusWriterThread.Create(stoRadio2, 'from the polling thread');
   try
      th.WaitFor;         (* and the thread is GONE before anything is drained *)
   finally
      th.Free;
   end;

   CheckTrue(DrainUntilStatus(stoRadio2, 'from the polling thread', 3000),
             'a status posted from a worker thread that has since EXITED still '
             + 'reaches its panel -- see TStatusWriterThread for why that is '
             + 'the case worth testing');

   SetStatusText(stoRadio2, '');
end;

procedure TStatusAndNoticeTests.Test_PostStatusTextSaysWhetherItTravelled;
begin
   EnsureMainForm;

   (* THIS IS WHAT REPLACED RadioObject.LinkFailureShown.  "Is there a message
     on screen for this radio" is answered by the writer's own record of what it
     handed over, under its own lock -- not by a boolean kept beside the
     control, which is the shape CLAUDE.md says to remove and which could not
     survive the radio being rebuilt. *)
   CheckTrue(PostStatusText(stoCluster, 'connected to dxc.example:7300'),
             'a new value travels');
   CheckFalse(PostStatusText(stoCluster, 'connected to dxc.example:7300'),
              'the same value again is coalesced away -- a poll must not flood '
              + 'the main thread');
   CheckTrue(PostStatusText(stoCluster, ''),
             'and there WAS something to clear, so the clear travels');
   CheckFalse(PostStatusText(stoCluster, ''),
              'clearing an empty panel reports nothing happened -- which is how '
              + 'a recovery that recovered nothing stays out of the log');

   Drain;
end;

procedure TStatusAndNoticeTests.Test_RadioStatusOwnerAnswersForBothSlots;
begin
   (* NO FORM NEEDED: this is the mapping, and it is the one place that answers
     "which panel is this rig's".  A rig pointer that is neither answers Radio 1
     rather than raising -- on the polling thread, a diagnostic message is not
     worth an exception. *)
   CheckEquals(Ord(stoRadio1), Ord(RadioStatusOwner(@Radio1)), 'Radio 1');
   CheckEquals(Ord(stoRadio2), Ord(RadioStatusOwner(@Radio2)), 'Radio 2');
   CheckEquals(Ord(stoRadio1), Ord(RadioStatusOwner(nil)),
               'an unknown rig falls back to Radio 1 rather than raising');
end;

(* THE FOUR PANELS SHARE THE STRIP, WHATEVER WIDTH IT IS.

  A TStatusBar PANEL HAS A FIXED WIDTH AND DOES NOT FOLLOW ITS PARENT, and the
  .lfm's four add up to exactly the DESIGN-TIME client width of 806.  The running
  window is sized from the layout instead (ws * 46, a font measurement), so the
  panels overran the client area and the last one clipped -- NY4I, bench,
  2026-09-26: "we overran the border for radio 2 just a bit".

  ASSERTED AT TWO WIDTHS, one narrower than the design and one wider, because a
  single width cannot tell "recomputed" from "happens to match". *)
procedure TStatusAndNoticeTests.Test_ThePanelsSpanTheStrip;
var
   bar: TStatusBar;

   procedure CheckSpansAt(const aWidth: integer);
   var
      i: integer;
      total: integer;
   begin
      bar.Width := aWidth;
      LayOutStatusPanels;

      total := 0;
      for i := 0 to bar.Panels.Count - 1 do
         begin
         CheckTrue(bar.Panels[i].Width > 0,
                   Format('panel %d has a width at strip width %d', [i, aWidth]));
         total := total + bar.Panels[i].Width;
         end;

      CheckEquals(bar.Width, total,
                  Format('the panels span the strip exactly at width %d -- no '
                         + 'overrun and no gap from integer division',
                         [aWidth]));
   end;

begin
   EnsureMainForm;
   bar := TR4WMainForm.sbStatus;

   CheckSpansAt(782);      (* ws = 17: narrower than the designed 806 *)
   CheckSpansAt(829);      (* ws = 18, and not divisible by four *)
end;

(* THE CONDITION IS WHAT HOLDS; THE REMEDY IS AN EVENT.

  ONE STRING WENT TO BOTH SURFACES UNTIL NOW, which is why the status read
  "IC7760: Auth failed - check credentials" and clipped mid-word.  Widening the
  panel was not the fix: "Auth failed" is WHAT IS TRUE and belongs on a panel
  that holds it; "check credentials" is WHAT TO DO and belongs on the notice
  channel, which beeps once and expires. *)
procedure TStatusAndNoticeTests.Test_TheConditionGoesToTheStatusAndTheRemedyToTheNotice;
var
   savedName: Str20;      (* the field's OWN type -- assigning a ShortString
                           back into a string[20] is a narrowing conversion *)
   savedSlot: integer;
begin
   EnsureMainForm;

   savedName := Radio1.RadioName;
   savedSlot := Radio1.tRadioPanelSlot;
   try
      Radio1.RadioName := 'TESTRIG';
      (* No panel open, so nothing is posted to a radio panel's label -- this
        test is about the two MAIN-WINDOW channels. *)
      Radio1.tRadioPanelSlot := 0;

      SetStatusText(stoRadio1, '');
      PostStatusText(stoRadio1, '');
      ShowQuickCommandNotice('');
      Drain;

      ShowRadioLinkFailure(@Radio1, 'Auth failed', 'check credentials');

      CheckTrue(DrainUntilStatus(stoRadio1, 'TESTRIG: Auth failed', 3000),
                'the STATUS panel gets the condition and only the condition -- '
                + 'no remedy, so it fits');

      CheckEquals('TESTRIG: Auth failed - check credentials',
                  string(MainElement(mweQuickCommand).Caption),
                  'and the fuller sentence, remedy included, goes to the NOTICE '
                  + 'channel, which beeps and expires');

      CheckTrue(QuickCommandNoticeArmed,
                'the remedy is an EVENT, so it is armed to expire; the condition '
                + 'on the panel is not');
   finally
      Radio1.RadioName := savedName;
      Radio1.tRadioPanelSlot := savedSlot;
      PostStatusText(stoRadio1, '');
      ShowQuickCommandNotice('');
      Drain;
   end;
end;

(* ONCE PER RUN OF FAILURES, NOT ONCE PER RETRY.

  A network radio retries after an authentication rejection, so a beep and a
  notice on every attempt would be a beep every 60 s for as long as the password
  is wrong.  The gate is SetRadioStatus's return value -- an unchanged condition
  coalesces away -- and both the beep and the notice sit inside it.  The beep
  property arrived in 62e6781b; this pins that adding the notice did not lose
  it. *)
procedure TStatusAndNoticeTests.Test_TheRemedyIsNotRepeatedOnARetry;
var
   savedName: Str20;      (* the field's OWN type -- assigning a ShortString
                           back into a string[20] is a narrowing conversion *)
   savedSlot: integer;
begin
   EnsureMainForm;

   savedName := Radio1.RadioName;
   savedSlot := Radio1.tRadioPanelSlot;
   try
      Radio1.RadioName := 'TESTRIG';
      Radio1.tRadioPanelSlot := 0;
      PostStatusText(stoRadio1, '');
      Drain;

      ShowRadioLinkFailure(@Radio1, 'Auth failed', 'check credentials');
      CheckTrue(DrainUntilStatus(stoRadio1, 'TESTRIG: Auth failed', 3000),
                'the first failure reports');

      (* A SECOND, IDENTICAL FAILURE.  The notice is cleared first so that a
        notice arriving again is visible as a change rather than as the same
        text still sitting there. *)
      ShowQuickCommandNotice('');
      Drain;

      ShowRadioLinkFailure(@Radio1, 'Auth failed', 'check credentials');
      Drain;

      CheckEquals('', string(MainElement(mweQuickCommand).Caption),
                  'a retry with the same condition raises NO second notice -- '
                  + 'and therefore no second beep');

      CheckEquals('TESTRIG: Auth failed', StatusText(stoRadio1),
                  'while the condition is still on the panel, because it is '
                  + 'still true');
   finally
      Radio1.RadioName := savedName;
      Radio1.tRadioPanelSlot := savedSlot;
      PostStatusText(stoRadio1, '');
      ShowQuickCommandNotice('');
      Drain;
   end;
end;

(* A RADIO PANEL OPENED AFTER THE FAILURE CAN STILL SEE IT.

  NY4I, bench, 2026-09-26: "i opened radio 2 window AFTER I stated the program
  and received the status message. The newly opened radio 2 window does not have
  the AUTH FAILED like radio 1 which was open."  A view that is only ever PUSHED
  to is blank if it missed the push -- the same root shape as the stale banner --
  and for Radio 2 nothing was even posted, because tRadioPanelSlot is 0 while
  the panel is closed.

  WHAT IS ASSERTED IS WHAT THE OPENING PANEL READS.  RadioPanelStatusText is
  the single source: uPanelUpdate's cache, the same one SetRadioStatus wrote and
  ClearRadioLinkFailure interrogates -- no field on the form, which is the
  LinkFailureShown shape that was deleted.  The one call site that hands it to
  the label is uRadioPanelForm.SyncPanelStatusFromCondition; constructing that
  form needs a parented, handle-allocated window and is not something a console
  test should build.

  AND THE UNPREFIXED CASE, IN THE SAME TEST, because it is the rule that keeps
  an opened panel agreeing with an open one: the split warning writes the radio's
  status panel with no "<name>: ", the radio panel shows split as an INDICATOR
  instead, so RadioPanelStatusText must answer empty for it. *)
procedure TStatusAndNoticeTests.Test_APanelOpeningLaterCanReadTheCondition;
var
   savedName: Str20;      (* the field's OWN type -- assigning a ShortString
                           back into a string[20] is a narrowing conversion *)
   savedSlot: integer;
begin
   EnsureMainForm;

   savedName := Radio2.RadioName;
   savedSlot := Radio2.tRadioPanelSlot;
   try
      Radio2.RadioName := '9700-IP';
      Radio2.tRadioPanelSlot := 0;      (* the panel is CLOSED -- his case *)
      PostStatusText(stoRadio2, '');
      Drain;

      CheckEquals('', RadioPanelStatusText(@Radio2),
                  'nothing wrong, nothing to show');

      ShowRadioLinkFailure(@Radio2, 'Auth failed', 'check credentials');
      Drain;

      CheckEquals('9700-IP: Auth failed', CurrentStatusText(stoRadio2),
                  'the condition is recorded for this owner even with no panel '
                  + 'open to receive it');

      CheckEquals('AUTH FAILED', RadioPanelStatusText(@Radio2),
                  'so a panel opening NOW reads the condition, in its own short '
                  + 'voice, without having witnessed the failure');

      (* The split warning: same panel, no name prefix, and not this label's. *)
      PostStatusText(stoRadio2, 'Warning: You are in SPLIT MODE !!!');
      Drain;
      CheckEquals('', RadioPanelStatusText(@Radio2),
                  'a status with no "<name>: " prefix is not the radio panel''s '
                  + '-- the split warning is an indicator there, not a sentence');

      CheckTrue(ClearRadioLinkFailure(@Radio2),
                'and clearing reports that something was there');
      Drain;
      CheckEquals('', RadioPanelStatusText(@Radio2), 'cleared');
   finally
      Radio2.RadioName := savedName;
      Radio2.tRadioPanelSlot := savedSlot;
      PostStatusText(stoRadio2, '');
      Drain;
   end;
end;

procedure TStatusAndNoticeTests.RunAllTests;
begin
   Test_TheStripHasOnePanelPerOwner;
   Test_TheNoticeTimerIsAThirtySecondOneShot;
   Test_ANoticeSetsTheCaptionAndArmsTheTimer;
   Test_ASecondNoticeRestartsTheWipe;
   Test_TheWipeClearsTheCaption;
   Test_AnEmptyNoticeClearsAndDisarms;
   Test_AStatusArmsNoTimer;
   Test_ClearingOneOwnerLeavesTheOthersAlone;
   Test_AStatusWrittenOffTheMainThreadLands;
   Test_PostStatusTextSaysWhetherItTravelled;
   Test_RadioStatusOwnerAnswersForBothSlots;
   Test_ThePanelsSpanTheStrip;
   Test_TheConditionGoesToTheStatusAndTheRemedyToTheNotice;
   Test_TheRemedyIsNotRepeatedOnARetry;
   Test_APanelOpeningLaterCanReadTheCondition;
   ReleaseMainForm;
end;

end.
