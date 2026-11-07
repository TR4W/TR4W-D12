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
   SysUtils, Classes, Forms, ComCtrls, Graphics,
   uTR4WTestFramework,
   uTR4WStrings,    (* TC_CONNECTEDTO and its three siblings -- the PREFIXES
                      both the cluster console and the two status panels use *)
   VC,              (* TStatusOwner, mweQuickCommand *)
   LogRadio,        (* RadioStatusOwner, Radio1, Radio2 *)
   uCrashLog,       (* InstallCrashLog -- see EnsureMainForm; it is what puts
                      the MAIN THREAD on record *)
   uPanelUpdate,    (* PostStatusText / CurrentStatusText -- the marshalled
                      writer and the cache a view reads when it opens; and
                      StatusSubsystemName, the one statement of "a panel names
                      its owner" that a test can reach *)
   uRadioPolling,   (* ShowRadioLinkFailure -- the condition/remedy split *)
   uElementPanel,   (* TElementPanel -- the need-strip cells *)
   uMainGrids,      (* BindMainGrids / SetMultNeedBands -- the need strips *)
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
      procedure Test_EveryStatusNamesItsOwnSubsystem;
      procedure Test_NoStatusOverrunsItsPanel;
      procedure Test_ANotNeededBandIsAnEmptyCellNotAHiddenOne;
      procedure Test_LoggingAQSOTakesItsBandOutOfTheNeedsStrips;
      procedure Test_TheQSONeedsStripOffersOnlyTheContestsBands;
      procedure Test_TheTotalsHeadersNameOnlyTheContestsBands;
      procedure Test_TheSweepstakesMultHeaderNamesTheSection;
      procedure Test_TheMultHeaderIsTheMultiplierInEveryDomesticFileContest;
      procedure Test_TheMultHeaderPinsOfIssue207;
      procedure Test_AnInhibitedKeyUpTurnsThePTTIndicator;
      procedure Test_ARadioSpeedChangeIsDrawnOnTheMainThread;
      procedure Test_ANoticeFromAWorkerThreadIsHandedOverWhole;
      procedure Test_TheCWThreadLeavesTheAutoCQRepeatToTheMainThread;
      procedure Test_TheDVKPlaybackEndIsDrawnOnTheMainThread;
      procedure Test_NoKeyingThreadBodyNamesTheUIWork;
      procedure HandleRadioMessage(sMessage: string);
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uSettingsModel,     (* Settings.Qso / Settings.Mult -- by band, not by mode *)
   uCTYDAT,            (* ctyLoadInCountryFile, ctyLocateCall *)
   uMults,             (* mo -- the multiplier sheet the Mult strip reads *)
   uCallsigns,         (* ClearAllDupeSheets -- the dupe sheet the QSO strip reads *)
   uContestRegistry,   (* ContestHandleOf *)
   uContestFactory,    (* ReleaseActiveContest *)
   LogWind,            (* ActiveBand, ActiveMode *)
   LogStuff,           (* StationInformationCall, the "already shown" latch *)
   LogDupe,            (* Sheet, ClearContestExchange, NumberDifferentMults *)
   LogEdit,            (* ShowStationInformation, SetDXQTHAndPrefix, AddQSOToDupeSheets *)
   LogSubs2,           (* RefreshNeedsAfterLoggedQSO -- issue #100 *)
   PostUnit,           (* Contest -- the active contest's handle *)
   ExtCtrls,           (* TPanel -- MainElement's type *)
   Log4D,              (* TLogLevel, ILogAppender *)
   Tree,               (* PTTStatusString -- the indicator's ordinary text *)
   MainUnit,           (* logger, PTTIndicatorBack, RefreshMainWindowElementColors *)
   uAppStrings,        (* STXInhibitedStatus, STXInhibitedIndicator *)
   uRadioState,        (* RadioState.PTTOn -- what the bridge paints from *)
   uStateBridge,       (* InstallStateBridge -- the PTT indicator's painter *)
   uTXInhibitView,     (* ReviewTXInhibit, ResetTXInhibitAlerts -- issue #97 *)
   uTestLogCapture,    (* TCaptureAppender *)
   uTestTXInhibitAlert, (* SetSettledTXState *)
   uFactoryRadioBase,  (* TFactoryRadioBase -- the speed-reporting probe, #108 *)
   LogDom,             (* DomQTHTable -- issue 207's domestic table *)
   ZoneCont,           (* DomesticCountries -- issue 207 *)
   uContestBase,       (* ContestUsesDomesticFile, TSessionDefaults -- issue 207 *)
   uContestSession,    (* ContestSession -- the exchange kind the remembered text reads *)
   uAppPaths,          (* ExistingDataFile -- issue 207 *)
   uTestContestObjects, (* ShippedDomDir -- issue 207 *)
   uTestShippedDom,    (* LoadShippedDomFollowingIncludes -- issue 207 *)
   uTestContestKindPin, (* MatrixStation, SessionContestName -- issue 207 *)
   LogK1EA,           (* CWBufferStart/End, tWaitForNextChar, DVPOn -- issue #132 *)
   LOGDVP,             (* tDVPPlayThreadproc, DVPMessagesArray -- issue #132 *)
   uAppTimers,         (* AppTimerRunning(atAutoCQ) -- issue #132 *)
   uCWKeyerBase,       (* KeyerCPU -- the CW thread's real starter, issue #132 *)
   uTotal;             (* UpdateTotals2, ClearTotals -- the totals headers *)

(* ISSUE #108: A RADIO THAT IS UP AND REPORTS A KEYER SPEED, AND NOTHING ELSE.

  Connected and operational from the first call, no polling of its own, every
  query the base's do-nothing, and the speed set once through the same door a
  driver uses (NoteCWSpeedFromRadio).  Run under the SHIPPED polling thread
  (uRadioPolling.BeginPolling), so what is tested is the poller's real pass. *)
type
   TSpeedReportingRadio = class(TFactoryRadioBase)
   protected
      function GetISConnected: boolean; override;
   public
      constructor CreateProbe(AHandler: TProcessMsgRef; ASpeed: integer);
      procedure SetCWSpeed(speed: integer); override;
   end;

   (* Puts one notice up from a worker thread, then exits. *)
   TNoticeWriterThread = class(TThread)
   private
      FText: string;
   protected
      procedure Execute; override;
   public
      constructor Create(const aText: string);
   end;

var
   (* The probe's slot.  A global, because RadioObject is an old-style object
     and its polling thread is handed @Self -- the address must outlive the
     test.  Not Radio1: the test makes it the ACTIVE radio and puts it back. *)
   gSpeedRig: RadioObject;

constructor TSpeedReportingRadio.CreateProbe(AHandler: TProcessMsgRef; ASpeed: integer);
begin
   inherited Create(AHandler);
   requiresPolling := False;
   NoteCWSpeedFromRadio(ASpeed);
end;

function TSpeedReportingRadio.GetISConnected: boolean;
begin
   Result := True;
end;

procedure TSpeedReportingRadio.SetCWSpeed(speed: integer);
begin
   (* Never pushed to: the probe's slot has CW SPEED SYNC on. *)
end;

constructor TNoticeWriterThread.Create(const aText: string);
begin
   FText := aText;
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TNoticeWriterThread.Execute;
begin
   ShowQuickCommandNotice(FText);
end;

(* ISSUE #132: RUNS THE SHIPPED DVK PLAYBACK THREAD BODY, ONCE, ON A WORKER.
  LogSend starts it with tCreateThread; what is under test is the body, and a
  TThread gives the test a Finished to wait on. *)
type
   TDVPPlaybackThread = class(TThread)
   protected
      procedure Execute; override;
   public
      constructor Create;
   end;

constructor TDVPPlaybackThread.Create;
begin
   FreeOnTerminate := False;
   inherited Create(False);
end;

procedure TDVPPlaybackThread.Execute;
begin
   tDVPPlayThreadproc(nil);
end;

(* PASCAL SOURCE WITH ITS COMMENTS AND STRING LITERALS BLANKED, for the source
  guard below: a comment that explains what MOVED OUT of a thread names the
  routine, and must not read as a call.  Brace, paren-star and line comments;
  a quote toggles a literal, which also gets '' right. *)
function CodeOnly(const aSource: string): string;
var
   i, n: integer;
   inBrace, inParen, inLine, inString: boolean;
   c: Char;
begin
   Result := '';
   n := Length(aSource);
   inBrace := False;
   inParen := False;
   inLine := False;
   inString := False;
   i := 1;
   while i <= n do
      begin
      c := aSource[i];
      if inBrace then
         begin
         inBrace := c <> '}';
         end
      else if inParen then
         begin
         if (c = '*') and (i < n) and (aSource[i + 1] = ')') then
            begin
            inParen := False;
            Inc(i);
            end;
         end
      else if inLine then
         begin
         if (c = #10) or (c = #13) then
            begin
            inLine := False;
            Result := Result + c;
            end;
         end
      else if inString then
         begin
         inString := c <> '''';
         end
      else if c = '{' then
         begin
         inBrace := True;
         end
      else if (c = '(') and (i < n) and (aSource[i + 1] = '*') then
         begin
         inParen := True;
         Inc(i);
         end
      else if (c = '/') and (i < n) and (aSource[i + 1] = '/') then
         begin
         inLine := True;
         end
      else if c = '''' then
         begin
         inString := True;
         end
      else
         begin
         Result := Result + c;
         end;
      Inc(i);
      end;
end;

(* THE BODY OF ONE ROUTINE IN A SOURCE FILE, comments stripped: from aHeader
  (which must be unique) to the first column-zero "end;". '' if absent. *)
function RoutineBody(const aRelativePath, aHeader: string): string;
var
   lines: TStringList;
   text: string;
   p, q: integer;
begin
   Result := '';
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ExpandFileName(ExtractFilePath(ParamStr(0)) +
                         '..' + PathDelim + '..' + PathDelim + 'src' + PathDelim +
                         aRelativePath)));
      text := lines.Text;
   finally
      lines.Free;
   end;
   p := Pos(aHeader, text);
   if p = 0 then
      begin
      Exit;
      end;
   text := Copy(text, p, Length(text));
   q := Pos(LineEnding + 'end;', text);
   if q = 0 then
      begin
      Exit;
      end;
   Result := CodeOnly(Copy(text, 1, q));
end;

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
   (* The need strips too: with no form, BindMainGrids forgets its panels. *)
   BindMainGrids;
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

(* A STATUS PANEL SAYS WHOSE CONDITION IT IS SHOWING.

  THE STRIP CARRIES NO LABELS.  Four panels, three of them usually empty, so
  position is the only other thing that identifies an owner -- and NY4I could
  not use it, the day after the strip reached the bench: "'Connected to host' is
  not specific enough. What host? Do you mean connected to DX Cluster? Connected
  to radio host (via IP)?"

  WHAT IS ASSERTED IS THE PROPERTY, NOT THE WORDING.  Re-typing the expected
  sentences here would assert only that this file and uTelnet hold the same
  literal.  So: each owner has a name, the two names differ, and neither is one
  of the two generic nouns that were there for a day.

  AND IT ASKS THE PRODUCTION CODE, WHICH TOOK MOVING ONE LINE.  uTelnet's writer
  is implementation-private and uNet's has side effects on the network window,
  so a test can reach neither; uPanelUpdate.StatusSubsystemName is the single
  statement of the rule that both of them now ask, and that this can ask too.

  THE RADIO OWNERS ARE IN IT BECAUSE THEY ARE THE HALF THAT WAS ALREADY RIGHT,
  and the rule is one rule.  A radio names itself from its own RadioName, which
  is why StatusSubsystemName answers EMPTY for those two slots rather than
  guessing at a rig this unit cannot see. *)
procedure TStatusAndNoticeTests.Test_EveryStatusNamesItsOwnSubsystem;
var
   cluster:   string;
   network:   string;
   savedName: Str20;      (* the field's OWN type -- see the test above *)
   savedSlot: integer;
begin
   EnsureMainForm;

   cluster := StatusSubsystemName(stoCluster);
   network := StatusSubsystemName(stoNetwork);

   CheckTrue(cluster <> '',
             'the Cluster panel has a subsystem name to state');
   CheckTrue(network <> '',
             'the Network panel has a subsystem name to state');
   CheckTrue(cluster <> network,
             'and the two names differ, or the panels still do not say which '
             + 'is which');

   (* THE TWO WORDS THAT WERE THERE FOR A DAY.  They are bounded, which was the
     problem they were solving, and they identify nothing, which is the problem
     they caused.  Named as literals on purpose: this guards against them
     coming back, so it must not be written in terms of whatever is there now. *)
   CheckFalse(SameText(cluster, 'host'),
              'the Cluster panel names the cluster, not a generic "host"');
   CheckFalse(SameText(network, 'server'),
              'the Network panel names the network, not a generic "server"');

   (* A RADIO SLOT HAS NO FIXED NAME, and asking for one would be a second
     answer to "which rig is in slot 1". *)
   CheckEquals('', StatusSubsystemName(stoRadio1),
               'a radio slot has no fixed subsystem name -- the RADIO supplies '
               + 'it');
   CheckEquals('', StatusSubsystemName(stoRadio2),
               'and the same for slot 2');

   savedName := Radio1.RadioName;
   savedSlot := Radio1.tRadioPanelSlot;
   try
      Radio1.RadioName        := 'TESTRIG';
      Radio1.tRadioPanelSlot  := 0;

      PostStatusText(stoRadio1, '');
      ShowQuickCommandNotice('');
      Drain;

      ShowRadioLinkFailure(@Radio1, 'Auth failed', 'check credentials');
      Drain;

      CheckEquals(1, Pos('TESTRIG', CurrentStatusText(stoRadio1)),
                  'a radio''s status leads with the radio''s own name, which is '
                  + 'the half of the strip that was never ambiguous');
   finally
      Radio1.RadioName       := savedName;
      Radio1.tRadioPanelSlot := savedSlot;
      PostStatusText(stoRadio1, '');
      ShowQuickCommandNotice('');
      Drain;
   end;
end;

(* AND IT FITS THE PANEL IT IS SHOWN IN.

  A PANEL DOES NOT SCROLL, HAS NO TOOLTIP AND CLIPS MID-WORD.  NY4I reported an
  overrun within an hour of the strip going on the bench, so lengthening a
  status is not free: naming the subsystem instead of a generic noun added six
  characters to every cluster line and one to every network line.

  MEASURED IN PIXELS, NOT CHARACTERS.  The rule beside VC.TStatusOwner says
  "about twenty-five characters", which is a rule of thumb for a writer; what
  decides whether text clips is its width in the strip's own font.  A bitmap's
  canvas carries that font rather than the strip's, because a TStatusBar paints
  its panels itself and its canvas is only valid inside that paint -- the FONT
  is the part that matters and it is the same object.

  AT BOTH RUNNING WIDTHS for the reason Test_ThePanelsSpanTheStrip uses them:
  the window is sized from a font measurement, so 782 and 829 are both real.

  THE ALLOWANCE IS PANEL_PADDING.  A status-bar panel insets its text by a few
  pixels each side and the amount is the widget set's business; 8 is a
  deliberate under-estimate of the room, so this errs towards failing.

  MEASURED ON THIS MACHINE, 2026-09-28, AT THE NARROW WIDTH (panel = 195 px,
  so avail = 187):

     Connected to Network             120 px
     Connecting to Network            124 px
     Connected to DX Cluster          130 px
     Connecting to DX Cluster         134 px
     Failed to connect to Network     153 px
     Failed to connect to DX Cluster  163 px
     ** DISCONNECTED from Network     177 px
     ** DISCONNECTED from DX Cluster  187 px   <-- exactly at the allowance

  THAT LAST ONE IS THE ONE TO WATCH, AND IT IS DELIBERATELY LEFT ALONE.
  TC_DISCONNECTEDFROM is '** DISCONNECTED from ' -- a console line's attention
  marker, shouting, in a panel that has no traffic to stand out from.  It is
  ALSO the only string in the set with no margin.  It was not changed because
  the three surfaces that report a transition -- the telnet console, the
  network window's caption and these panels -- share these four prefixes on
  purpose, so they cannot word one differently; a panel-only spelling means a
  new translatable string AND either a second prefix parameter through
  uNet.ShowConnectionStatus or a hidden comparison against a constant.  Same
  call as TC_SPLIT_WARN in 6509e862: left at the limit, measured, and said out
  loud rather than fixed by inventing a constant. *)
procedure TStatusAndNoticeTests.Test_NoStatusOverrunsItsPanel;
const
   PANEL_PADDING = 8;
var
   bar:   TStatusBar;
   probe: TBitmap;

   procedure CheckFitsAt(const aStripWidth: integer; const aOwner: TStatusOwner;
                         const aText: string);
   var
      avail: integer;
      px:    integer;
   begin
      bar.Width := aStripWidth;
      LayOutStatusPanels;

      avail := bar.Panels[Ord(aOwner)].Width - PANEL_PADDING;
      px    := probe.Canvas.TextWidth(aText);

      CheckTrue(px <= avail,
                Format('"%s" is %d px wide and its panel offers %d at strip '
                       + 'width %d', [aText, px, avail, aStripWidth]));
   end;

   procedure CheckOwnerAtBothWidths(const aOwner: TStatusOwner);
   var
      name: string;
   begin
      name := StatusSubsystemName(aOwner);

      CheckFitsAt(782, aOwner, TC_CONNECTINGTO      + name);
      CheckFitsAt(782, aOwner, TC_CONNECTEDTO       + name);
      CheckFitsAt(782, aOwner, TC_FAILEDTOCONNECTTO + name);
      CheckFitsAt(782, aOwner, TC_DISCONNECTEDFROM  + name);

      CheckFitsAt(829, aOwner, TC_CONNECTINGTO      + name);
      CheckFitsAt(829, aOwner, TC_CONNECTEDTO       + name);
      CheckFitsAt(829, aOwner, TC_FAILEDTOCONNECTTO + name);
      CheckFitsAt(829, aOwner, TC_DISCONNECTEDFROM  + name);
   end;

begin
   EnsureMainForm;
   bar := TR4WMainForm.sbStatus;

   probe := TBitmap.Create;
   try
      probe.Canvas.Font.Assign(bar.Font);

      CheckOwnerAtBothWidths(stoCluster);
      CheckOwnerAtBothWidths(stoNetwork);
   finally
      probe.Free;
   end;
end;

(* A BAND THAT IS NOT NEEDED IS AN EMPTY CELL, NOT A HIDDEN ONE.

  NY4I, CQ WW SSB 2026-10-24: "Mult needs for D4K", and the 15 m cell -- the
  one band not needed -- showed a block of dark stripes instead of plain
  background. The cell had just been HIDDEN, which left its rectangle for the
  form to repaint. The strips no longer hide a cell; this pins that, and that
  what each cell means is in its own Caption and Color where it can be read. *)
procedure TStatusAndNoticeTests.Test_ANotNeededBandIsAnEmptyCellNotAHiddenOne;
var
   cell:  array[Band160..Band10] of TElementPanel;
   band:  BandType;
   mask:  Cardinal;
   multBack: integer;
begin
   EnsureMainForm;
   BindMainGrids;

   cell[Band160] := TR4WMainForm.FindComponent('pnlMultNeedR1_160') as TElementPanel;
   cell[Band80]  := TR4WMainForm.FindComponent('pnlMultNeedR1_80') as TElementPanel;
   cell[Band40]  := TR4WMainForm.FindComponent('pnlMultNeedR1_40') as TElementPanel;
   cell[Band20]  := TR4WMainForm.FindComponent('pnlMultNeedR1_20') as TElementPanel;
   cell[Band15]  := TR4WMainForm.FindComponent('pnlMultNeedR1_15') as TElementPanel;
   cell[Band10]  := TR4WMainForm.FindComponent('pnlMultNeedR1_10') as TElementPanel;

   for band := Band160 to Band10 do
      begin
      if cell[band] = nil then
         begin
         CheckTrue(False, 'uMainForm.lfm has every mult-need cell of row 1');
         Exit;
         end;
      end;

   multBack := tr4wColorsArray[TWindows[mweNewMultStatus].mweBackG];

   (* Bound and nothing needed yet: six empty cells, all shown. *)
   for band := Band160 to Band10 do
      begin
      CheckTrue(cell[band].Visible, 'a cell is shown from the moment it is bound');
      CheckEquals('', cell[band].Caption, 'nothing is needed before a call is typed');
      end;

   (* The screenshot: every band but 15 m. *)
   mask := 0;
   for band := Band160 to Band10 do
      begin
      if band <> Band15 then
         begin
         mask := mask or (1 shl Ord(band));
         end;
      end;
   SetMultNeedBands(Both, mask);

   CheckTrue(cell[Band15].Visible, 'the band not needed is still SHOWN -- never hidden');
   CheckEquals('', cell[Band15].Caption, 'the band not needed has no text');
   CheckTrue(cell[Band15].ParentColor, 'the band not needed takes the form''s colour');
   CheckEquals('20', Trim(string(cell[Band20].Caption)), 'a needed band reads its name');
   CheckEquals('10', Trim(string(cell[Band10].Caption)), 'a needed band reads its name');
   CheckEquals(multBack, integer(cell[Band20].Color), 'a needed band has the new-mult colour');
   CheckFalse(cell[Band20].ParentColor, 'a needed band does not take the form''s colour');

   (* And back: 15 m needed again gets its name and its colour back. *)
   SetMultNeedBands(Both, mask or (1 shl Ord(Band15)));
   CheckEquals('15', Trim(string(cell[Band15].Caption)), 'needed again, the cell reads 15');
   CheckEquals(multBack, integer(cell[Band15].Color), 'needed again, the cell is the new-mult colour');
   CheckFalse(cell[Band15].ParentColor, 'needed again, the cell no longer follows the form');

   (* Nothing needed: every cell empty, every cell still shown. *)
   SetMultNeedBands(Both, 0);
   for band := Band160 to Band10 do
      begin
      CheckTrue(cell[band].Visible, 'no band needed hides no cell');
      CheckEquals('', cell[band].Caption, 'no band needed leaves every cell empty');
      end;
end;

(* A LOGGED QSO TAKES ITS BAND OUT OF BOTH NEEDS STRIPS -- issue #100.

  NY4I, CQ WW SSB 2026-10-25 23:29Z: PJ4K logged on 20 m SSB as a new country,
  and afterwards "QSO needs for PJ4K" and "Mult needs for PJ4K" both still read
  160 80 40 20. The sheets had the QSO; nothing asked the strips again. The
  post-log ShowStationInformation in TryLogContact met its own "already shown"
  latch (StationInformationCall, cleared only after it) and returned at once.

  SO THIS TEST TAKES THE PATH THE OPERATOR TOOK: ShowStationInformation on the
  typed call (which sets that latch), the QSO onto the same sheets LogContact
  writes and in its order, then LogContact's post-log step. The database and
  the network are not reached -- RefreshNeedsAfterLoggedQSO is that step, made
  public for this.

  AND IT MUST NOT OVERWRITE THE NEXT CALL. Tail-ending, the strips already show
  the station being worked next when the previous QSO is logged; a peer's QSO
  arrives while this operator looks at someone else. Neither may replace what
  is on screen. *)
procedure TStatusAndNoticeTests.Test_LoggingAQSOTakesItsBandOutOfTheNeedsStrips;
var
   savedContest:      TContestHandle;
   savedQsoByBand:    boolean;
   savedQsoByMode:    boolean;
   savedMultByBand:   boolean;
   savedMultByMode:   boolean;
   savedNumberMults:  Byte;
   savedActiveBand:   BandType;
   savedActiveMode:   ModeType;
   savedLatch:        CallString;
   savedRestart:      RestartInfo;
   ctyPath:           string;
   qsoNeed20:         TElementPanel;
   qsoNeed40:         TElementPanel;
   multNeed20:        TElementPanel;
   multNeed40:        TElementPanel;

   (* One SSB QSO, onto the sheets as LogContact puts it there: the flags, the
     multiplier sheet, the dupe sheet. The country, DX QTH and zone are what
     ParametersOkay would have left on the record. *)
   procedure LogOnTheSheets(const aCall: CallString; aBand: BandType);
   var
      rx: ContestExchange;
   begin
      ClearContestExchange(rx);
      rx.ceRecordKind := rkQSO;
      rx.Callsign := aCall;
      rx.Band := aBand;
      rx.Mode := Phone;
      ctyLocateCall(aCall, rx.QTH);
      rx.Zone := rx.QTH.Zone;
      SetDXQTHAndPrefix(rx);
      Sheet.SetMultFlags(rx);
      Sheet.AddQSOToSheets(@rx, False);
      AddQSOToDupeSheets(rx, False);
   end;

   function Cell(const aName: string): TElementPanel;
   begin
      Result := TR4WMainForm.FindComponent(aName) as TElementPanel;
   end;

   function Reads(const aPanel: TElementPanel): string;
   begin
      Result := Trim(string(aPanel.Caption));
   end;

begin
   BeginTest('Test_LoggingAQSOTakesItsBandOutOfTheNeedsStrips');

   EnsureMainForm;
   BindMainGrids;

   qsoNeed20  := Cell('pnlQSONeedR1_20');
   qsoNeed40  := Cell('pnlQSONeedR1_40');
   multNeed20 := Cell('pnlMultNeedR1_20');
   multNeed40 := Cell('pnlMultNeedR1_40');
   if (qsoNeed20 = nil) or (qsoNeed40 = nil) or
      (multNeed20 = nil) or (multNeed40 = nil) then
      begin
      CheckTrue(False, 'uMainForm.lfm has the 20 m and 40 m need cells of row 1');
      Exit;
      end;

   (* The country and zone come from the shipped CTY.DAT, as uTestOffBandCredit
     loads it. *)
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat loads');

   savedContest     := Contest;
   savedQsoByBand   := Settings.Qso.ByBand;
   savedQsoByMode   := Settings.Qso.ByMode;
   savedMultByBand  := Settings.Mult.ByBand;
   savedMultByMode  := Settings.Mult.ByMode;
   savedNumberMults := NumberDifferentMults;
   savedActiveBand  := ActiveBand;
   savedActiveMode  := ActiveMode;
   savedLatch       := StationInformationCall;
   savedRestart     := tRestartInfo;
   try
      (* CQ WW SSB as NY4I ran it: QSOs and multipliers per band, not per mode;
        a DX and a zone multiplier. NumberDifferentMults is counted once at
        start-up by LogCfg, which a test binary never runs -- with it at 0 the
        Mult strip is never written at all. *)
      Contest := ContestHandleOf(CQWWSSB);
      Settings.Qso.ByBand := True;
      Settings.Qso.ByMode := False;
      Settings.Mult.ByBand := True;
      Settings.Mult.ByMode := False;
      NumberDifferentMults := 2;
      ActiveBand := Band20;
      ActiveMode := Phone;
      mo.ClearAllMults;
      ClearAllDupeSheets;
      StationInformationCall := '';

      (* THE CALL IS TYPED AND ENTER IS PRESSED: everything is needed. *)
      ShowStationInformation('PJ4K');
      CheckEquals('20', Reads(qsoNeed20), 'before the QSO, PJ4K is a needed QSO on 20 m');
      CheckEquals('20', Reads(multNeed20), 'before the QSO, PJ4K is a needed mult on 20 m');

      (* THE QSO IS LOGGED, then LogContact's post-log step. *)
      LogOnTheSheets('PJ4K', Band20);
      RefreshNeedsAfterLoggedQSO('PJ4K', True, False);

      CheckEquals('', Reads(qsoNeed20), 'after the 20 m QSO, PJ4K is no longer needed on 20 m');
      CheckEquals('', Reads(multNeed20), 'after the 20 m QSO, PJ4 is no longer a mult on 20 m');
      CheckEquals('40', Reads(qsoNeed40), 'and PJ4K is still a needed QSO on 40 m');
      CheckEquals('40', Reads(multNeed40), 'and PJ4 is still a needed mult on 40 m');

      (* TAIL-ENDING: the strips show the NEXT call, DL1ABC, when PJ4K's 40 m
        QSO is logged. They must keep showing DL1ABC. *)
      ShowNeedsForCall('DL1ABC');
      LogOnTheSheets('PJ4K', Band40);
      RefreshNeedsAfterLoggedQSO('PJ4K', True, True);
      CheckTrue(Pos('DL1ABC', string(TR4WMainForm.pnlQSONeedsHeader.Caption)) > 0,
                'tail-ending: the QSO strip still names the next call');
      CheckEquals('40', Reads(qsoNeed40),
                  'tail-ending: the next call''s 40 m is still shown needed');

      (* A PEER'S QSO: the same, for the call this operator is looking at. *)
      LogOnTheSheets('PJ4K', Band40);
      RefreshNeedsAfterLoggedQSO('PJ4K', False, False);
      CheckTrue(Pos('DL1ABC', string(TR4WMainForm.pnlMultNeedsHeader.Caption)) > 0,
                'a peer''s QSO: the Mult strip still names this operator''s call');
   finally
      mo.ClearAllMults;
      ClearAllDupeSheets;
      tRestartInfo := savedRestart;
      StationInformationCall := savedLatch;
      ActiveMode := savedActiveMode;
      ActiveBand := savedActiveBand;
      NumberDifferentMults := savedNumberMults;
      Settings.Mult.ByMode := savedMultByMode;
      Settings.Mult.ByBand := savedMultByBand;
      Settings.Qso.ByMode := savedQsoByMode;
      Settings.Qso.ByBand := savedQsoByBand;
      Contest := savedContest;
      ReleaseActiveContest;
      end;
end;

(* THE QSO NEEDS STRIP OFFERS ONLY THE BANDS THE CONTEST USES -- NY4I, Florida
  QSO Party 2026-11-07: "QSO needs for <call>" listed 160 and 80, which the
  Florida class does not use, while the Mult strip correctly left them blank.
  An off-band QSO never reaches the dupe sheet, so the dupe question alone
  said "needed" there for every call; LOGEDIT's CreateModeSpecificQSOInfo now
  clears those bands through CreditedBands, as the Mult strip's mask is.

  ShowQSOStatus is asked directly -- the QSO strip's own writer -- so neither
  ShowNeedsForCall's contest gate nor the domestic path is in the way. By
  mode, so BOTH rows are judged. Three contests: Florida (40-10 only), CQ WW
  (all six) and ARRL 160 (160 only). The hard-coded checks state the
  expectation independently; the per-cell loop then holds every cell of both
  rows to the class's own UsesBand. (The strip has no WARC cells -- it is
  160..10 -- so a WARC contest has nothing more to show here.) *)
procedure TStatusAndNoticeTests.Test_TheQSONeedsStripOffersOnlyTheContestsBands;
var
   savedContest:    TContestHandle;
   savedQsoByBand:  boolean;
   savedQsoByMode:  boolean;
   savedActiveBand: BandType;
   savedActiveMode: ModeType;
   call:            CallString;

   function Cell(const aRow: integer; const aBand: BandType): TElementPanel;
   begin
      Result := TR4WMainForm.FindComponent(
                   Format('pnlQSONeedR%d_%s',
                          [aRow, string(BandStringsArrayWithOutSpaces[aBand])]))
                as TElementPanel;
   end;

   function Reads(const aRow: integer; const aBand: BandType): string;
   begin
      Result := Trim(string(Cell(aRow, aBand).Caption));
   end;

   (* Every cell of both rows against the class's UsesBand. *)
   procedure CheckEveryCellFollowsTheClass(const aName: string);
   var
      row:  integer;
      band: BandType;
   begin
      for row := 1 to 2 do
         begin
         for band := Band160 to Band10 do
            begin
            if ContestIdentity(Contest).UsesBand(band) then
               begin
               CheckEquals(Trim(string(BandStringsArrayWithOutSpaces[band])),
                           Reads(row, band),
                           Format('%s row %d: a band the contest uses reads its name', [aName, row]));
               end
            else
               begin
               CheckEquals('', Reads(row, band),
                           Format('%s row %d: a band the contest does not use is an empty cell', [aName, row]));
               end;
            end;
         end;
   end;

var
   row:  integer;
   band: BandType;
begin
   BeginTest('Test_TheQSONeedsStripOffersOnlyTheContestsBands');

   EnsureMainForm;
   BindMainGrids;

   for row := 1 to 2 do
      begin
      for band := Band160 to Band10 do
         begin
         if Cell(row, band) = nil then
            begin
            CheckTrue(False, 'uMainForm.lfm has every QSO-need cell of rows 1 and 2');
            Exit;
            end;
         end;
      end;

   savedContest    := Contest;
   savedQsoByBand  := Settings.Qso.ByBand;
   savedQsoByMode  := Settings.Qso.ByMode;
   savedActiveBand := ActiveBand;
   savedActiveMode := ActiveMode;
   try
      (* QSOs per band and per mode; the operator on 20 m, so the strip walks
        160..10 (from 6 m it walks the VHF bands instead). *)
      Settings.Qso.ByBand := True;
      Settings.Qso.ByMode := True;
      ActiveBand := Band20;
      ActiveMode := CW;
      ClearAllDupeSheets;
      call := 'W1AW';

      (* FLORIDA: the defect. *)
      Contest := ContestHandleOf(FLORIDAQSOPARTY);
      VisibleLog.ShowQSOStatus(call);
      CheckEquals('', Reads(1, Band160), 'Florida, CW row: 160 m is not offered');
      CheckEquals('', Reads(1, Band80),  'Florida, CW row: 80 m is not offered');
      CheckEquals('', Reads(2, Band160), 'Florida, SSB row: 160 m is not offered');
      CheckEquals('', Reads(2, Band80),  'Florida, SSB row: 80 m is not offered');
      CheckEquals('40', Reads(1, Band40), 'Florida, CW row: 40 m is needed');
      CheckEquals('10', Reads(2, Band10), 'Florida, SSB row: 10 m is needed');
      CheckEveryCellFollowsTheClass('Florida');

      (* CQ WW: every one of the six. *)
      Contest := ContestHandleOf(CQWWSSB);
      VisibleLog.ShowQSOStatus(call);
      CheckEquals('160', Reads(1, Band160), 'CQ WW: 160 m is offered');
      CheckEquals('80',  Reads(2, Band80),  'CQ WW: 80 m is offered');
      CheckEveryCellFollowsTheClass('CQ WW');

      (* ARRL 160: the other way round -- 160 m and nothing else. *)
      Contest := ContestHandleOf(ARRL160);
      VisibleLog.ShowQSOStatus(call);
      CheckEquals('160', Reads(1, Band160), 'ARRL 160: 160 m is offered');
      CheckEquals('', Reads(1, Band40),     'ARRL 160: 40 m is not');
      CheckEveryCellFollowsTheClass('ARRL 160');
   finally
      ClearAllDupeSheets;
      ActiveMode := savedActiveMode;
      ActiveBand := savedActiveBand;
      Settings.Qso.ByMode := savedQsoByMode;
      Settings.Qso.ByBand := savedQsoByBand;
      Contest := savedContest;
      ReleaseActiveContest;
      end;
end;

(* THE TOTALS GRID NAMES ONLY THE BANDS THE CONTEST USES -- the same Florida
  report. The band columns are at fixed positions, so a band the contest does
  not use keeps its column with no header (its cells could only read 0: an
  off-band QSO counts toward no total). The All column is a key, not a band,
  and always keeps its header. *)
procedure TStatusAndNoticeTests.Test_TheTotalsHeadersNameOnlyTheContestsBands;
var
   savedContest:    TContestHandle;
   savedActiveBand: BandType;
   savedActiveMode: ModeType;

   function Head(const aColumn: integer): string;
   var
      c: TComponent;
   begin
      c := TR4WMainForm.FindComponent(Format('pnlTotalHead_%d', [aColumn]));
      if c is TElementPanel then
         begin
         Result := Trim(string(TElementPanel(c).Caption));
         end
      else
         begin
         Result := '<missing>';
         end;
   end;

begin
   BeginTest('Test_TheTotalsHeadersNameOnlyTheContestsBands');

   EnsureMainForm;
   BindMainGrids;

   savedContest    := Contest;
   savedActiveBand := ActiveBand;
   savedActiveMode := ActiveMode;
   try
      ActiveBand := Band20;
      ActiveMode := CW;

      (* Columns 1..6 are 160..10, column 7 is All. *)
      Contest := ContestHandleOf(FLORIDAQSOPARTY);
      UpdateTotals2;
      CheckEquals('', Head(1), 'Florida: the 160 m column has no header');
      CheckEquals('', Head(2), 'Florida: the 80 m column has no header');
      CheckEquals(Trim(string(BandStringsArrayWithOutSpaces[Band40])), Head(3),
                  'Florida: 40 m keeps its column and its header');
      CheckEquals(Trim(string(BandStringsArrayWithOutSpaces[Band10])), Head(6),
                  'Florida: 10 m keeps its column and its header');
      CheckEquals(Trim(string(BandStringsArrayWithOutSpaces[AllBands])), Head(7),
                  'Florida: the All column keeps its header');

      Contest := ContestHandleOf(CQWWSSB);
      UpdateTotals2;
      CheckEquals(Trim(string(BandStringsArrayWithOutSpaces[Band160])), Head(1),
                  'CQ WW: the 160 m column is named');
      CheckEquals(Trim(string(BandStringsArrayWithOutSpaces[Band80])), Head(2),
                  'CQ WW: the 80 m column is named');
   finally
      ClearTotals(0);
      ActiveMode := savedActiveMode;
      ActiveBand := savedActiveBand;
      Contest := savedContest;
      ReleaseActiveContest;
      end;
end;

(* THE SWEEPSTAKES "MULT NEEDS FOR" HEADER NAMES THE SECTION -- NY4I bench,
  ARRL SS SSB, 2026-11-04. After W7ST (33M 18 UT) was logged it read
  "Mult needs for 18 UT :". LogContact remembers the exchange as check +
  section and its post-log step (RefreshNeedsAfterLoggedQSO -> ShowNeedsForCall)
  showed that text whole; the contest's DomesticMultiplierHint now answers the
  section. The same header is shown when a worked call is typed again
  (ShowStationInformation -> ShowNeedsForCall), which is where "32 IN" came
  from. Section multipliers count once per contest: not by band, not by mode. *)
procedure TStatusAndNoticeTests.Test_TheSweepstakesMultHeaderNamesTheSection;
var
   savedContest:      TContestHandle;
   savedMultByBand:   boolean;
   savedMultByMode:   boolean;
   savedNumberMults:  Byte;
   savedList:         TCallsignsList;
   savedTable:        TDomQTHTable;
   savedMults:        TMultsObject;
   header:            string;
begin
   BeginTest('Test_TheSweepstakesMultHeaderNamesTheSection');

   EnsureMainForm;
   BindMainGrids;

   savedContest     := Contest;
   savedMultByBand  := Settings.Mult.ByBand;
   savedMultByMode  := Settings.Mult.ByMode;
   savedNumberMults := NumberDifferentMults;
   savedList        := CallsignsList;
   CallsignsList    := TCallsignsList.Create;
   savedTable       := DomQTHTable;
   savedMults       := mo;
   (* THE SESSION'S SECTION TABLE, as a real SS log loads it: since issue
      209 option 1 a remembered text the table maps nothing in names the
      call, so the test must have the table the header maps through. *)
   DomQTHTable      := TDomQTHTable.Create;
   mo               := TMultsObject.Create;
   try
      Contest := ContestHandleOf(ARRLSSSSB);
      ReleaseActiveContest;
      LoadShippedDomFollowingIncludes(DomQTHTable, 'arrlsect.dom', True, 0);
      Settings.Mult.ByBand := False;
      Settings.Mult.ByMode := False;
      NumberDifferentMults := 1;
      mo.ClearAllMults;

      (* WHAT LogContact REMEMBERS FOR W7ST, and its post-log step. *)
      CallsignsList.AddIniitialExchange('W7ST', '18 UT');
      TR4WMainForm.pnlMultNeedsHeader.Caption := '';
      RefreshNeedsAfterLoggedQSO('W7ST', True, False);
      header := string(TR4WMainForm.pnlMultNeedsHeader.Caption);
      CheckTrue(Pos('UT', header) > 0, 'the header names the section: ' + header);
      CheckTrue(Pos('18', header) = 0, 'the header holds no check: ' + header);

      (* A WORKED CALL TYPED AGAIN -- the "32 IN" NY4I saw first. *)
      CallsignsList.AddIniitialExchange('W9XX', '32 IN');
      TR4WMainForm.pnlMultNeedsHeader.Caption := '';
      ShowNeedsForCall('W9XX');
      header := string(TR4WMainForm.pnlMultNeedsHeader.Caption);
      CheckTrue(Pos('IN', header) > 0, 'the typed call''s header names the section: ' + header);
      CheckTrue(Pos('32', header) = 0, 'the typed call''s header holds no check: ' + header);
   finally
      mo.Free;
      mo := savedMults;
      DomQTHTable.Free;
      DomQTHTable := savedTable;
      CallsignsList.Free;
      CallsignsList := savedList;
      NumberDifferentMults := savedNumberMults;
      Settings.Mult.ByMode := savedMultByMode;
      Settings.Mult.ByBand := savedMultByBand;
      Contest := savedContest;
      ReleaseActiveContest;
      end;
end;

(* ---------------------------------------------------------------------------
   ISSUE 207 -- THE "MULT NEEDS FOR" HEADER NAMES THE MULTIPLIER.

   The header is built from the exchange the log REMEMBERS for a call (the
   prefill text: name + QTH, class + section, serial + state, an alias as
   typed), so until 2026-11-05 it read 'TOM CA', '2A CT', 'WF' and the needs
   strip looked that text up on the multiplier sheet -- never found, every band
   needed. LOGDUPE.DomesticMultiplierOfRememberedExchange maps it to the
   multiplier key; the header shows the key upper-cased.

   ONE SESSION AT A TIME, as FoundContest would leave it for what these read:
   the contest, a fresh domestic table AND multiplier list (the loader writes
   every multiplier into mo.DomList, so a shared one would carry the last
   contest's keys), the exchange kind its US station runs, its field list,
   a US station's country, an empty call history.
   --------------------------------------------------------------------------- *)

var
   gNeedsSavedContest: TContestHandle;
   gNeedsSavedTable: TDomQTHTable;
   gNeedsSavedList: TCallsignsList;
   gNeedsSavedQualified: TQualifiedDupeSheet;
   gNeedsSavedMults: TMultsObject;
   gNeedsSavedFields: ExchangeInformationRecord;
   gNeedsSavedExchange: ExchangeType;
   gNeedsSavedInitial: InitialExchangeType;
   gNeedsSavedCountry: string;
   gNeedsSavedFilename: string;
   gNeedsSavedCountries: TStringList;
   gNeedsSavedNumberMults: Byte;
   gNeedsSavedByBand: boolean;
   gNeedsSavedByMode: boolean;
   gNeedsSavedDomByBand: TAdditionalMultByBand;
   gNeedsSavedBand: BandType;
   gNeedsSavedMode: ModeType;

procedure SaveNeedsSession;
var
   i: integer;
begin
   gNeedsSavedContest := Contest;
   gNeedsSavedTable := DomQTHTable;
   gNeedsSavedList := CallsignsList;
   gNeedsSavedQualified := QualifiedDupes;
   gNeedsSavedMults := mo;
   gNeedsSavedFields := ExchangeInformation;
   gNeedsSavedExchange := ContestSession.Exchange;
   gNeedsSavedInitial := ContestSession.InitialExchange;
   gNeedsSavedCountry := Settings.My.Country;
   gNeedsSavedFilename := Settings.Contest.DomesticFilename;
   gNeedsSavedNumberMults := NumberDifferentMults;
   gNeedsSavedByBand := Settings.Mult.ByBand;
   gNeedsSavedByMode := Settings.Mult.ByMode;
   gNeedsSavedDomByBand := DomesticMultByBand;
   gNeedsSavedBand := ActiveBand;
   gNeedsSavedMode := ActiveMode;
   gNeedsSavedCountries := TStringList.Create;
   for i := 0 to DomesticCountries.Count - 1 do
      begin
      gNeedsSavedCountries.Add(DomesticCountries.IDs[i]);
      end;
   DomQTHTable := nil;
   mo := nil;
   CallsignsList := nil;
   QualifiedDupes := nil;
   Settings.My.DeriveCountry('K');
end;

(* aContest's session, its file aDomFile ('' for none) loaded into a fresh
   table and list. Frees the previous session's objects. *)
procedure OpenNeedsSession(aContest: TContestHandle; const aDomFile: string;
                           const aCountries: array of string);
var
   i: integer;
   stated: TSessionDefaults;
   kind: ExchangeType;
begin
   DomQTHTable.Free;
   mo.Free;
   CallsignsList.Free;
   QualifiedDupes.Free;
   DomQTHTable := TDomQTHTable.Create;
   mo := TMultsObject.Create;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;

   DomesticCountries.Clear;
   for i := Low(aCountries) to High(aCountries) do
      begin
      DomesticCountries.Add(CallString(aCountries[i]));
      end;

   Contest := aContest;
   ReleaseActiveContest;
   if aDomFile <> '' then
      begin
      LoadShippedDomFollowingIncludes(DomQTHTable, aDomFile, True, 0);
      end;
   Settings.Contest.DomesticFilename := aDomFile;

   (* THE EXCHANGE KIND, as ApplyContestTraits + ApplySessionDefaults resolve
      it for a US station -- the remembered text's builder reads it. *)
   kind := ContestIdentity(aContest).ExchangeKind;
   stated := TSessionDefaults.Create;
   try
      ContestIdentity(aContest).DescribeSession(
         MatrixStation('K0AAA', 'K', NorthAmerica, 'KS', 'KS', 'EM17', False,
                       SessionContestName(aContest, False)), stated);
      if stated.IsStated(svExchange) then
         begin
         kind := stated.Exchange;
         end;
   finally
      stated.Free;
      end;
   ContestSession.WriteExchange(kind);
   ExchangeInformation := ContestReceivedExchangeFields(ActiveContest(Contest));
end;

procedure RestoreNeedsSession;
var
   i: integer;
begin
   DomQTHTable.Free;
   mo.Free;
   CallsignsList.Free;
   QualifiedDupes.Free;
   DomQTHTable := gNeedsSavedTable;
   mo := gNeedsSavedMults;
   CallsignsList := gNeedsSavedList;
   QualifiedDupes := gNeedsSavedQualified;
   DomesticCountries.Clear;
   for i := 0 to gNeedsSavedCountries.Count - 1 do
      begin
      DomesticCountries.Add(CallString(gNeedsSavedCountries[i]));
      end;
   gNeedsSavedCountries.Free;
   ExchangeInformation := gNeedsSavedFields;
   ContestSession.WriteExchange(gNeedsSavedExchange);
   ContestSession.WriteInitialExchange(gNeedsSavedInitial);
   Settings.My.DeriveCountry(gNeedsSavedCountry);
   Settings.Contest.DomesticFilename := gNeedsSavedFilename;
   NumberDifferentMults := gNeedsSavedNumberMults;
   Settings.Mult.ByBand := gNeedsSavedByBand;
   Settings.Mult.ByMode := gNeedsSavedByMode;
   DomesticMultByBand := gNeedsSavedDomByBand;
   ActiveBand := gNeedsSavedBand;
   ActiveMode := gNeedsSavedMode;
   Contest := gNeedsSavedContest;
   ReleaseActiveContest;
end;

(* A QSO from W1AW with every field a field list can mark filled with a value
   that is NOT a QTH -- the name, class, age, check, zone, chapter, power and
   precedence the remembered text can join to the QTH -- and aQTH as typed.
   The domestic multiplier is what the loaded table gives aQTH. *)
procedure NeedsQSO(const aQTH: string; out aRX: ContestExchange);
begin
   ClearContestExchange(aRX);
   aRX.ceRecordKind := rkQSO;
   aRX.Callsign := 'W1AW';
   aRX.Band := Band20;
   aRX.Mode := CW;
   aRX.Name := 'TOM';
   aRX.ceClass := '2A';
   aRX.Age := 45;
   aRX.Check := 18;
   aRX.Zone := 5;
   aRX.Chapter := 'TAC';
   aRX.Power := 'KW';
   aRX.Precedence := 'A';
   (* ASCII aliases from a .dom file, at most ten characters (the caller
      skips longer ones), so the narrowing is bounded. *)
   aRX.QTHString := ShortString(aQTH);
   FoundDomesticQTH(aRX);
end;

(* The header ShowNeedsForCall leaves for aCall, whose remembered exchange is
   aRemembered. *)
function HeaderFor(const aCall: string; const aRemembered: string): string;
begin
   CallsignsList.AddIniitialExchange(aCall, aRemembered);
   TR4WMainForm.pnlMultNeedsHeader.Caption := '';
   ShowNeedsForCall(CallString(aCall));
   Result := string(TR4WMainForm.pnlMultNeedsHeader.Caption);
end;

(* The header ShowDomesticMultiplierStatus writes for aKey -- the expected
   caption, in whatever language the catalogue holds. *)
function HeaderNaming(const aKey: string): string;
begin
   TR4WMainForm.pnlMultNeedsHeader.Caption := '';
   VisibleLog.ShowDomesticMultiplierStatus(Str10(aKey));
   Result := string(TR4WMainForm.pnlMultNeedsHeader.Caption);
end;

(* THE TABLE OF ISSUE 207, KEPT: every registered contest that looks its QTH
   up in its domestic file, every alias of its file (the top file; its
   INCLUDEs are other contests' top files), a QSO carrying it, the remembered
   text the log builds, and the header. The header must name the QSO's
   multiplier, upper-cased, and the text the strip looks up must be the key
   exactly as the list spells it.

   Not asked, and counted so a reader sees them: an alias longer than ten
   characters or holding a blank (cut to a Str10, never found -- issue 208),
   an alias the table does not give a multiplier, and a QSO
   whose remembered text does not hold the QTH at all (RF Championship
   remembers no QTH; issue 211). A ONE-CHARACTER KEY IS ASKED like any
   other since issue 209 (the header's two-character guard is gone), and
   counted. *)
procedure TStatusAndNoticeTests.Test_TheMultHeaderIsTheMultiplierInEveryDomesticFileContest;
var
   handles: TContestHandleList;
   h: integer;
   fileName: string;
   path: string;
   lines: TStringList;
   items: TStringList;
   i, j, p: integer;
   alias: string;
   rx: ContestExchange;
   remembered: string;
   header: string;
   expected: string;
   lookup: string;
   contests: integer;
   asked: integer;
   failures: integer;
   report: string;
   skippedLong: integer;
   askedOneCharacter: integer;
   skippedUnknown: integer;
   skippedNotRemembered: integer;
begin
   BeginTest('Test_TheMultHeaderIsTheMultiplierInEveryDomesticFileContest');
   EnsureMainForm;
   BindMainGrids;

   contests := 0;
   asked := 0;
   failures := 0;
   report := '';
   skippedLong := 0;
   askedOneCharacter := 0;
   skippedUnknown := 0;
   skippedNotRemembered := 0;
   handles := KnownContests;
   SaveNeedsSession;
   lines := TStringList.Create;
   items := TStringList.Create;
   try
      items.Delimiter := ',';
      items.StrictDelimiter := True;
      for h := Low(handles) to High(handles) do
         begin
         fileName := ContestIdentity(handles[h]).DomesticFileName;
         if fileName = '' then
            begin
            Continue;
            end;
         fileName := fileName + '.dom';
         path := ExistingDataFile(ShippedDomDir + fileName);
         if not FileExists(path) then
            begin
            Continue;
            end;
         OpenNeedsSession(handles[h], fileName, DomesticCountriesKVEKH6KL);
         if not ContestUsesDomesticFile(ActiveContest(Contest)) then
            begin
            Continue;
            end;
         Inc(contests);
         NumberDifferentMults := 0;

         lines.LoadFromFile(AnsiString(path));
         for i := 0 to lines.Count - 1 do
            begin
            p := Pos('=', string(lines[i]));
            if (p = 0) or (Pos('INCLUDE', UpperCase(string(lines[i]))) = 1) then
               begin
               Continue;
               end;
            items.DelimitedText := AnsiString(Copy(string(lines[i]), p + 1, MaxInt));
            for j := 0 to items.Count - 1 do
               begin
               alias := UpperCase(Trim(string(items[j])));
               if (alias = '') or (alias[1] = '^') then
                  begin
                  Continue;
                  end;
               if (Length(alias) > 10) or (Pos(' ', alias) > 0) then
                  begin
                  Inc(skippedLong);
                  Continue;
                  end;
               NeedsQSO(alias, rx);
               if rx.DomMultQTH = '' then
                  begin
                  Inc(skippedUnknown);
                  Continue;
                  end;
               remembered := GetInitialExchangeStringFromContestExchange(rx);
               if Pos(alias, remembered) = 0 then
                  begin
                  Inc(skippedNotRemembered);
                  Continue;
                  end;
               Inc(asked);
               if Length(rx.DomMultQTH) = 1 then
                  begin
                  Inc(askedOneCharacter);
                  end;
               expected := HeaderNaming(string(rx.DomMultQTH));
               header := HeaderFor('W1AW', remembered);
               lookup := DomStringParse(Str14(remembered));
               (* NOT ONLY header = expected: both are '' when the gate
                  refuses the key, which is how issue 209 hid. The header
                  must be there and name the key upper-cased. *)
               if (header <> expected) or
                  (expected = '') or
                  (Pos(UpperCase(string(rx.DomMultQTH)), UpperCase(header)) = 0) or
                  (lookup <> string(rx.DomMultQTH)) then
                  begin
                  Inc(failures);
                  if failures <= 12 then
                     begin
                     report := report + sLineBreak + '   ' + ContestId(handles[h]) +
                               ' ' + alias + ': remembered "' + remembered +
                               '" header "' + Trim(header) + '" looked up "' + lookup +
                               '", multiplier "' + string(rx.DomMultQTH) + '"';
                     end;
                  end;
               end;
            end;
         end;
   finally
      items.Free;
      lines.Free;
      RestoreNeedsSession;
      end;

   CheckEquals(0, failures, 'headers that do not name the multiplier:' + report);
   (* THE WALK REACHED THE CONTESTS IT IS ABOUT -- 102 contest-station pairs
      used a file in the issue 207 measurement; this walk, at the US
      station, reached 98 contests and asked 12956 aliases on 2026-11-05.
      Floors, so a walk that stops finding them fails. *)
   CheckTrue(contests >= 90, 'domestic-file contests walked: ' + IntToStr(contests));
   CheckTrue(asked >= 12000, 'aliases asked: ' + IntToStr(asked));
   CheckTrue(askedOneCharacter > 0, 'one-character keys asked (issue 209): ' + IntToStr(askedOneCharacter));
   logger.info('[issue 207] %d contests, %d aliases asked (%d of them one-character keys); not asked: %d long or blank, %d unknown, %d not in the remembered text',
               [contests, asked, askedOneCharacter, skippedLong, skippedUnknown, skippedNotRemembered]);
end;

(* THE PINS NAMED ON ISSUE 207, through the header and the strip. *)
procedure TStatusAndNoticeTests.Test_TheMultHeaderPinsOfIssue207;
var
   rx: ContestExchange;
   header: string;
   multNeed20: TElementPanel;

   procedure LogIt(var aRX: ContestExchange);
   begin
      ctyLocateCall(aRX.Callsign, aRX.QTH);
      SetDXQTHAndPrefix(aRX);
      Sheet.SetMultFlags(aRX);
      Sheet.AddQSOToSheets(@aRX, False);
      AddQSOToDupeSheets(aRX, False);
   end;

   (* One MWC QSO from aCall, scored by the class: its multiplier is aKey,
      the header names it before and after, and the 20 m cell goes from
      needed to worked. *)
   procedure MWCPin(const aCall: string; const aKey: string);
   var
      qso: ContestExchange;
      shown: string;
   begin
      ClearContestExchange(qso);
      qso.ceRecordKind := rkQSO;
      qso.Callsign := CallString(aCall);
      qso.Band := Band20;
      qso.Mode := CW;
      ActiveContest(Contest).ScoreQSO(qso);
      CheckEquals(aKey, string(qso.DomMultQTH), 'MWC ' + aCall + ': the multiplier is the last character');
      shown := HeaderNaming(string(qso.DomMultQTH));
      CheckTrue(Pos(' ' + aKey, shown) > 0, 'MWC ' + aCall + ': the header names ' + aKey + ': ' + shown);
      CheckEquals('20', Trim(string(multNeed20.Caption)), 'MWC ' + aCall + ': before the QSO, ' + aKey + ' is needed on 20 m');
      LogIt(qso);
      shown := HeaderNaming(string(qso.DomMultQTH));
      CheckTrue(Pos(' ' + aKey, shown) > 0, 'MWC ' + aCall + ': after the QSO the header still names ' + aKey);
      CheckEquals('', Trim(string(multNeed20.Caption)), 'MWC ' + aCall + ': after the QSO, ' + aKey + ' is worked: the cell is empty');
   end;

   (* One zone-only station and one HQ station in aContest, through the
      logging tail and a retype -- see the caller. *)
   procedure IARUZonePin(aContest: TContestHandle; const aName: string);
   var
      qso: ContestExchange;
      multNeed40: TElementPanel;
      shown: string;
   begin
      multNeed40 := TR4WMainForm.FindComponent('pnlMultNeedR1_40') as TElementPanel;
      OpenNeedsSession(aContest, 'iaruhq.dom', DomesticCountriesKVEKH6KL);
      Settings.Mult.ByBand := True;
      Settings.Mult.ByMode := False;
      NumberDifferentMults := 1;
      ActiveBand := Band20;
      ActiveMode := CW;
      ClearContestExchange(qso);
      qso.ceRecordKind := rkQSO;
      qso.Callsign := 'K1ABC';
      qso.Band := Band40;
      qso.Mode := CW;
      qso.Zone := 8;
      ctyLocateCall(qso.Callsign, qso.QTH);
      SetDXQTHAndPrefix(qso);
      ActiveContest(Contest).ScoreQSO(qso);
      CallsignsList.AddIniitialExchange('K1ABC', GetInitialExchangeStringFromContestExchange(qso));
      CheckEquals('8 ', CallsignsList.GetIniitialExchange('K1ABC'), aName + ': the log remembers the zone alone');
      Sheet.SetMultFlags(qso);
      Sheet.AddQSOToSheets(@qso, True);
      AddQSOToDupeSheets(qso, False);
      RefreshNeedsAfterLoggedQSO('K1ABC', True, False);
      shown := string(TR4WMainForm.pnlMultNeedsHeader.Caption);
      CheckTrue(Pos('K1ABC', shown) > 0, aName + ' K1ABC logged: the header names the call: ' + shown);
      ShowNeedsForCall('K1ABC');
      shown := string(TR4WMainForm.pnlMultNeedsHeader.Caption);
      CheckTrue(Pos('K1ABC', shown) > 0, aName + ' K1ABC retyped: the header names the call: ' + shown);
      CheckEquals('', Trim(string(multNeed40.Caption)), aName + ' K1ABC retyped: zone 8 is worked on 40 m');

      CallsignsList.AddIniitialExchange('W1AW', 'ARRL');
      ShowNeedsForCall('W1AW');
      shown := string(TR4WMainForm.pnlMultNeedsHeader.Caption);
      CheckTrue(Pos(' ARRL', shown) > 0, aName + ' W1AW: an HQ header is unchanged: ' + shown);
   end;

   (* ISSUE 213, NY4I's bench (IARU HF, 2026-11-05): W1AW logged on 160 m CW
      with zone 7 -- CTY.DAT says ITU 8 -- and retyped on 80 m. The strip
      showed 160 needed, following the call's zone. A PRIOR CONTACT'S ZONE
      TRUMPS THE CALL'S; with several, the MOST RECENTLY LOGGED one; with
      none, the call's. The call-window MULT flag (DetermineIfNewMult) asks
      the same lookup. *)
   (* aCall remembered as aRemembered in aContest: the header names aHeaderKey
      (upper case), or the call when aHeaderKey is ''. *)
   procedure BareFieldPin(aContest: TContestHandle; const aDomFile: string;
                          const aCall: string; const aRemembered: string;
                          const aHeaderKey: string);
   var
      shown: string;
      what: string;
   begin
      OpenNeedsSession(aContest, aDomFile, DomesticCountriesKVEKH6KL);
      what := ContestId(aContest) + ' ' + aCall + ' remembered "' + aRemembered + '"';
      shown := HeaderFor(aCall, aRemembered);
      if aHeaderKey = '' then
         begin
         CheckTrue(Pos(aCall, shown) > 0, what + ': the header names the call: ' + shown);
         CheckEquals('', DomStringParse(Str14(aRemembered)), what + ': no hint');
         end
      else
         begin
         CheckTrue(Pos(' ' + aHeaderKey, UpperCase(shown)) > 0, what + ': the header names ' + aHeaderKey + ': ' + shown);
         CheckTrue(Pos(aCall, shown) = 0, what + ': not the call: ' + shown);
         end;
   end;

   procedure PriorZonePin;
   var
      qso: ContestExchange;
      multNeed160: TElementPanel;

      procedure LogZone(const aCall: string; aBand: BandType; aZone: integer);
      begin
         ClearContestExchange(qso);
         qso.ceRecordKind := rkQSO;
         qso.Callsign := CallString(aCall);
         qso.Band := aBand;
         qso.Mode := CW;
         qso.Zone := aZone;
         ctyLocateCall(qso.Callsign, qso.QTH);
         SetDXQTHAndPrefix(qso);
         ActiveContest(Contest).ScoreQSO(qso);
         CallsignsList.AddIniitialExchange(aCall, GetInitialExchangeStringFromContestExchange(qso));
         Sheet.SetMultFlags(qso);
         Sheet.AddQSOToSheets(@qso, True);
         AddQSOToDupeSheets(qso, False);
      end;

   begin
      multNeed160 := TR4WMainForm.FindComponent('pnlMultNeedR1_160') as TElementPanel;
      OpenNeedsSession(ContestHandleOf(IARU), 'iaruhq.dom', DomesticCountriesKVEKH6KL);
      Settings.Mult.ByBand := True;
      Settings.Mult.ByMode := False;
      NumberDifferentMults := 1;
      ActiveBand := Band80;
      ActiveMode := CW;
      CheckEquals(8, integer(ctyGetITUZone('W1AW')), 'the control: CTY.DAT gives W1AW ITU zone 8');

      LogZone('W1AW', Band160, 7);
      ShowNeedsForCall('W1AW');
      CheckEquals('', Trim(string(multNeed160.Caption)),
                  'IARU W1AW logged zone 7 on 160, retyped on 80: 160 is worked (zone 7)');
      CheckFalse(VisibleLog.DetermineIfNewMult('W1AW', Band160, CW),
                 'IARU W1AW: no new multiplier on 160 -- the MULT flag agrees with the strip');

      (* No prior contact: the call's zone, 8, not worked on 160. *)
      ShowNeedsForCall('W2XYZ');
      CheckEquals('160', Trim(string(multNeed160.Caption)),
                  'IARU W2XYZ, never worked: its CTY zone 8 is needed on 160');
      CheckTrue(VisibleLog.DetermineIfNewMult('W2XYZ', Band160, CW),
                'IARU W2XYZ: a new multiplier on 160');

      (* Several prior contacts: the most recently logged zone. W1AW again,
         on 40 m with zone 6: zone 6 is not worked on 160. *)
      LogZone('W1AW', Band40, 6);
      ShowNeedsForCall('W1AW');
      CheckEquals('160', Trim(string(multNeed160.Caption)),
                  'IARU W1AW last logged zone 6: zone 6 is needed on 160');
   end;

begin
   BeginTest('Test_TheMultHeaderPinsOfIssue207');
   EnsureMainForm;
   BindMainGrids;
   multNeed20 := TR4WMainForm.FindComponent('pnlMultNeedR1_20') as TElementPanel;
   CheckTrue(multNeed20 <> nil, 'uMainForm.lfm has the 20 m mult need cell of row 1');
   CheckTrue(ctyLoadInCountryFile(ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
                                  PathDelim + 'target' + PathDelim + 'cty.dat', False, False, True),
             'cty.dat loads');

   SaveNeedsSession;
   try
      (* SWEEPSTAKES 'WF': arrlsect.dom files it as 'WcF = WC, WF, WCF'. The
         header shows WCF; the strip looks up WcF, so it goes worked. *)
      OpenNeedsSession(ContestHandleOf(ARRLSSSSB), 'arrlsect.dom', DomesticCountriesARRLSections);
      Settings.Mult.ByBand := False;
      Settings.Mult.ByMode := False;
      NumberDifferentMults := 1;
      ActiveBand := Band20;
      ActiveMode := Phone;
      NeedsQSO('WF', rx);
      rx.Mode := Phone;
      rx.Check := 59;
      CheckEquals('WCF', UpperCase(string(rx.DomMultQTH)), 'WF is the WcF multiplier');
      CheckEquals('59 WF', GetInitialExchangeStringFromContestExchange(rx), 'the remembered text holds the alias as typed');
      CheckEquals('WcF', DomStringParse('59 WF'), 'the strip looks up the key as the list spells it');
      header := HeaderFor('W1AW', '59 WF');
      CheckEquals(HeaderNaming('WcF'), header, 'before the QSO: the header names WCF');
      CheckTrue(Pos('WCF', header) > 0, 'upper-cased: ' + header);
      CheckEquals('20', Trim(string(multNeed20.Caption)), 'before the QSO, WcF is needed on 20 m');
      LogIt(rx);
      TR4WMainForm.pnlMultNeedsHeader.Caption := '';
      RefreshNeedsAfterLoggedQSO('W1AW', True, False);
      CheckTrue(Pos('WCF', string(TR4WMainForm.pnlMultNeedsHeader.Caption)) > 0,
                'after the QSO the header still names WCF');
      CheckEquals('', Trim(string(multNeed20.Caption)), 'after the QSO, WcF is worked: the cell is empty');

      (* NO MULTIPLIER IN THE REMEMBERED TEXT: the call's own status, not the
         previous header left on screen. *)
      TR4WMainForm.pnlMultNeedsHeader.Caption := 'Mult needs for STALE :';
      CallsignsList.AddIniitialExchange('W7ST', '18');
      ShowNeedsForCall('W7ST');
      header := string(TR4WMainForm.pnlMultNeedsHeader.Caption);
      CheckTrue(Pos('W7ST', header) > 0, 'SS 18: the header names the call: ' + header);
      CheckTrue(Pos('STALE', header) = 0, 'SS 18: the previous header is gone: ' + header);

      (* NAQP: the name before the state. 'DE CA' is Del in California -- the
         whole text maps to nothing, and the LAST word the file knows is the
         QTH, so CA (DE is a state too). *)
      OpenNeedsSession(ContestHandleOf(NAQSOCW), 'naqp.dom', DomesticCountriesKVEKH6KL);
      CheckEquals('CA', UpperCase(DomStringParse('TOM CA')), 'NAQP TOM CA: the multiplier');
      CheckEquals('CA', UpperCase(DomStringParse('DE CA')), 'NAQP DE CA: the last word that maps');
      header := HeaderFor('N6ABC', 'TOM CA');
      CheckEquals(HeaderNaming(DomStringParse('TOM CA')), header, 'NAQP TOM CA: the header');
      CheckTrue(Pos('TOM', header) = 0, 'no name in the header: ' + header);
      header := HeaderFor('N6DEL', 'DE CA');
      CheckTrue((Pos(' CA', header) > 0) and (Pos('DE', header) = 0), 'NAQP DE CA: the header names CA: ' + header);

      (* ISSUE 209: A ONE-CHARACTER KEY IS A MULTIPLIER. MWC's multiplier is
         the call's last character (TContestMWC.CalculateQSOPoints) -- W for
         OK1W, C for OK2C. ShowDomesticMultiplierStatus, handed it, names it
         and the strip goes from needed to worked on 20 m; the two-character
         guard refused both. This pins the routine; the live path follows. *)
      OpenNeedsSession(ContestHandleOf(MWC), 'mwc.dom', ['MWC']);
      Settings.Mult.ByBand := True;
      Settings.Mult.ByMode := False;
      NumberDifferentMults := 1;
      ActiveBand := Band20;
      ActiveMode := CW;
      CheckTrue(ContestIsValidDomesticMultiplier(ActiveContest(Contest), 'W'),
                'MWC: W is a multiplier');
      CheckFalse(ContestIsValidDomesticMultiplier(ActiveContest(Contest), ''),
                 'MWC: an empty text is not');
      MWCPin('OK1W', 'W');
      MWCPin('OK2C', 'C');

      (* MWC ON THE LIVE PATH (issue 209, NY4I 2026-11-05: a multiplier
         computed from the call is what the header and strip use, as CQ WW's
         zone is). MWC remembers no exchange text, so ShowNeedsForCall shows
         the CALL's status -- the header names the call, as for CQ WW -- and
         the strip asks the class's DomesticMultiplierFromCall for the
         letter. Measured before the class answered it: the strip was empty
         for every call, fresh, after the QSO and retyped. *)
      OpenNeedsSession(ContestHandleOf(MWC), 'mwc.dom', ['MWC']);
      Settings.Mult.ByBand := True;
      Settings.Mult.ByMode := False;
      NumberDifferentMults := 1;
      ActiveBand := Band20;
      ActiveMode := CW;
      ShowNeedsForCall('OK1W');
      header := string(TR4WMainForm.pnlMultNeedsHeader.Caption);
      CheckTrue(Pos('OK1W', header) > 0, 'MWC OK1W typed: the header names the call: ' + header);
      CheckEquals('20', Trim(string(multNeed20.Caption)), 'MWC OK1W typed: W is needed on 20 m');
      ClearContestExchange(rx);
      rx.ceRecordKind := rkQSO;
      rx.Callsign := 'OK1W';
      rx.Band := Band20;
      rx.Mode := CW;
      ActiveContest(Contest).ScoreQSO(rx);
      LogIt(rx);
      RefreshNeedsAfterLoggedQSO('OK1W', True, False);
      CheckEquals('', Trim(string(multNeed20.Caption)), 'MWC OK1W logged: W is worked on 20 m');
      ShowNeedsForCall('OK5W');
      CheckEquals('', Trim(string(multNeed20.Caption)), 'MWC OK5W typed: its W is worked on 20 m');
      ShowNeedsForCall('OK1Z');
      CheckEquals('20', Trim(string(multNeed20.Caption)), 'MWC OK1Z typed: Z is still needed on 20 m');
      ShowNeedsForCall('OK1W');
      CheckEquals('', Trim(string(multNeed20.Caption)), 'MWC OK1W retyped: still worked');

      (* A GRID CONTEST KEEPS THE OLD ANSWER: WSJT-X hands the first two
         characters of whatever grid it decoded, and one is not a grid
         field. *)
      OpenNeedsSession(ContestHandleOf(WWDIGI), '', []);
      CheckFalse(ContestIsValidDomesticMultiplier(ActiveContest(Contest), 'F'),
                 'WW Digi: one character is not a grid field');
      CheckTrue(ContestIsValidDomesticMultiplier(ActiveContest(Contest), 'FN'),
                'WW Digi: FN is');
      CheckEquals('', HeaderNaming('F'), 'WW Digi: no header for F');
      CheckTrue(Pos('FN', HeaderNaming('FN')) > 0, 'WW Digi: the header names FN');

      (* IARU HF AND WRTC: A ZONE ALONE IS NOT AN HQ (issue 209, NY4I
         2026-11-05) -- the zone comes from the call, as in CQ WW. K1ABC sent
         zone 8 and no HQ on 40 m; the log remembers '8 '. Measured before:
         the header read "8" and every band showed needed. Now the header
         names the call and the strip follows its ITU zone: worked on 40,
         needed on 20. An HQ station's header is unchanged. *)
      IARUZonePin(ContestHandleOf(IARU), 'IARU HF');
      IARUZonePin(ContestHandleOf(WRTC), 'WRTC');

      PriorZonePin;

      (* ISSUE 209 OPTION 1 (NY4I 2026-11-05): A REMEMBERED TEXT THE DOMESTIC
         FILE MAPS NOTHING IN IS A BARE FIELD, NOT A MULTIPLIER -- the header
         names the call. Measured before: 30 domestic-file contests showed
         the field ('6 ' a zone, 'TOM ' a name). YOTA's age IS its
         multiplier (UnmappedHintIsTheMultiplier) and still heads the strip;
         a key that is not its own alias still maps (michigan_cty.dom
         'Presq = PRES'). *)
      BareFieldPin(ContestHandleOf(CQWWRTTY), 's48p14dc.dom', 'XE1ABC', '6 ', '');
      BareFieldPin(ContestHandleOf(CQ160CW), 's48p14dc.dom', 'XE1ABC', '6 ', '');
      BareFieldPin(ContestHandleOf(NAQSOCW), 'naqp.dom', 'N6ABC', 'TOM ', '');
      BareFieldPin(ContestHandleOf(YOTA), 'YOTA.dom', 'DL1ABC', '9', '9');
      BareFieldPin(ContestHandleOf(MICHQSOPARTY), 'michigan_cty.dom', 'W8ABC', 'PRES', 'PRESQ');
   finally
      RestoreNeedsSession;
      end;
end;

(* ISSUE #97 ON THE STREAMED MAIN WINDOW: the PTT indicator and radio 1's status
  panel for a key-up on a radio in TX test mode, driven exactly as the program
  drives them -- the settled status, then the review the polling thread asks
  for (ReviewTXInhibit is the mtTXInhibitAlert job), then the state bridge
  painting from RadioState.

  - key-up while inhibited: the indicator reads INH on the alert colour, and
    the status panel says TX INHIBITED: <reason>;
  - re-reading the same key-up does not log again -- one Warn per key-up;
  - unkey: the indicator and the status panel go back;
  - a second key-up logs a second line;
  - not inhibited: the ordinary ON on the ordinary colour, nothing logged;
  - and the sentence fits radio 1's status panel at the narrow strip width. *)
function CountTXInhibitWarnings(aCapture: TCaptureAppender): integer;
var
   i: integer;
begin
   Result := 0;
   for i := 0 to aCapture.Lines.Count - 1 do
      begin
      if Pos('[TX inhibit]', aCapture.Lines[i]) > 0 then
         begin
         Inc(Result);
         end;
      end;
end;

procedure TStatusAndNoticeTests.Test_AnInhibitedKeyUpTurnsThePTTIndicator;
const
   REASON = 'TX test mode';
   NARROW_STRIP = 782;      (* Test_NoStatusOverrunsItsPanel's narrow width *)
   PANEL_PADDING = 8;
var
   pnl: TPanel;
   capture: TCaptureAppender;
   keep: ILogAppender;
   savedLevel: TLogLevel;
   savedStatus1: RadioStatusRecord;
   savedDisc1: boolean;
   savedPTT1: PTTStatusType;
   sentence: string;
   probe: TBitmap;
   i: integer;

   procedure KeyUp(const aInhibited: boolean);
   begin
      if aInhibited then
         begin
         SetSettledTXState(@Radio1, True, True, REASON);
         end
      else
         begin
         SetSettledTXState(@Radio1, True, False, '');
         end;
      (* What ProcessFilteredStatus and PTTStatusChanged do with TXOn. *)
      Radio1.tPTTStatus := PTT_ON;
      RadioState.PTTOn := True;
      ReviewTXInhibit;
      RefreshMainWindowElementColors;
   end;

   procedure Unkey;
   begin
      SetSettledTXState(@Radio1, False, True, REASON);
      Radio1.tPTTStatus := PTT_OFF;
      RadioState.PTTOn := False;
      ReviewTXInhibit;
      RefreshMainWindowElementColors;
   end;

begin
   BeginTest('Test_AnInhibitedKeyUpTurnsThePTTIndicator');
   EnsureMainForm;
   InstallStateBridge;
   Drain;

   pnl := MainElement(mwePTTStatus);
   CheckTrue(pnl = TR4WMainForm.pnlPTTStatus, 'mwePTTStatus is the designed pnlPTTStatus');
   pnl.HandleNeeded;
   CheckTrue(ActiveRadioPtr = @Radio1, 'precondition: radio 1 is active');

   sentence := Format(STXInhibitedStatus, [REASON]);
   savedStatus1 := ReadRadioStatus(@Radio1);
   savedDisc1 := Radio1.RadioDisconnected;
   savedPTT1 := Radio1.tPTTStatus;

   capture := TCaptureAppender.Create('tx-inhibit');
   keep := capture;
   savedLevel := logger.Level;
   logger.Level := Log4D.Warn;
   logger.AddAppender(keep);
   try
      Radio1.RadioDisconnected := False;
      ResetTXInhibitAlerts;

      (* TRIGGER 2: the radio reports TX -- a footswitch TR4W never saw. *)
      KeyUp(True);
      CheckEquals(STXInhibitedIndicator, pnl.Caption,
                  'the PTT indicator says the key-up is inhibited');
      CheckTrue(PTTIndicatorBack = AlertColor,
                'its background is the alert role, not radio 1''s TX red');
      CheckEquals(tr4wColorsArray[AlertColor], pnl.Color, 'and the panel is painted so');
      CheckTrue(DrainUntilStatus(stoRadio1, sentence, 2000),
                'radio 1''s status panel says "' + sentence + '", got "' +
                StatusText(stoRadio1) + '"');
      CheckEquals(1, CountTXInhibitWarnings(capture), 'one Warn line for the key-up');

      for i := 1 to 5 do
         begin
         ReviewTXInhibit;      (* the same key-up, re-read *)
         end;
      CheckEquals(1, CountTXInhibitWarnings(capture),
                  'one line per KEY-UP, not per status update');

      Unkey;
      CheckEquals(PTTStatusString[PTT_OFF], pnl.Caption, 'unkey: the indicator says OFF');
      CheckEquals(tr4wColorsArray[TWindows[mwePTTStatus].mweBackG], pnl.Color,
                  'and is back on its own background');
      CheckTrue(DrainUntilStatus(stoRadio1, '', 2000),
                'and the status panel is cleared, got "' + StatusText(stoRadio1) + '"');

      KeyUp(True);
      CheckEquals(2, CountTXInhibitWarnings(capture), 'the next key-up logs again');
      Unkey;

      (* NOT INHIBITED: an ordinary key-up looks as it always has. *)
      KeyUp(False);
      CheckEquals(PTTStatusString[PTT_ON], pnl.Caption, 'not inhibited: the ordinary ON');
      CheckTrue(PTTIndicatorBack = trRed, 'on radio 1''s ordinary TX colour');
      CheckEquals('', StatusText(stoRadio1), 'nothing on the status panel');
      CheckEquals(2, CountTXInhibitWarnings(capture), 'and nothing logged');
      Unkey;

      (* THE SENTENCE FITS radio 1's panel at the narrow strip width. *)
      probe := TBitmap.Create;
      try
         probe.Canvas.Font.Assign(TR4WMainForm.sbStatus.Font);
         TR4WMainForm.sbStatus.Width := NARROW_STRIP;
         LayOutStatusPanels;
         CheckTrue(probe.Canvas.TextWidth(sentence) <=
                   TR4WMainForm.sbStatus.Panels[Ord(stoRadio1)].Width - PANEL_PADDING,
                   '"' + sentence + '" fits radio 1''s status panel');
      finally
         probe.Free;
      end;
   finally
      logger.RemoveAppender(keep);
      logger.Level := savedLevel;
      keep := nil;
      SetSettledTXState(@Radio1, savedStatus1.TXOn, savedStatus1.TXInhibited,
                        string(savedStatus1.TXInhibitReason));
      Radio1.RadioDisconnected := savedDisc1;
      Radio1.tPTTStatus := savedPTT1;
      RadioState.PTTOn := False;
      ResetTXInhibitAlerts;
      Drain;
   end;
end;

procedure TStatusAndNoticeTests.HandleRadioMessage(sMessage: string);
begin
   (* The probe reports nothing worth asserting. *)
end;

(* ISSUE #108: THE RADIO POLLING THREAD WRITES NO CONTROL.

  A radio with CW SPEED SYNC on reports 27 WPM; the shipped polling thread
  sees it.  The live speed must change and the WPM panel must show it -- and
  the panel must be written on the MAIN thread.  The poller called
  DisplayCodeSpeed itself, which assigns pnlCodeSpeed.Caption from the poller;
  TElementPanel reports that through uCrashLog.ReportOffMainThread, and this
  test fails on the count.  The panel gets a real window first, so the old
  write really went through the widget set (a cross-thread WM_SETTEXT, which
  Drain's ProcessMessages answers). *)
procedure TStatusAndNoticeTests.Test_ARadioSpeedChangeIsDrawnOnTheMainThread;
const
   WANTED = 27;
   BUDGET_MS = 3000;
var
   probe: TSpeedReportingRadio;
   savedActive: RadioPtr;
   savedSpeed: integer;
   savedMode: ModeType;
   savedCWEnabled: boolean;
   reportsBefore: LongInt;
   started: QWord;
   shown: boolean;
   handler: TProcessMsgRef;
begin
   BeginTest('Test_ARadioSpeedChangeIsDrawnOnTheMainThread');
   EnsureMainForm;
   MainElement(mweCodeSpeed).HandleNeeded;

   savedActive := ActiveRadioPtr;
   savedSpeed := CodeSpeed;
   savedMode := ActiveMode;
   savedCWEnabled := CWEnabled;
   try
      ActiveMode := CW;
      CWEnabled := True;
      CodeSpeed := 20;
      SetElementText(mweCodeSpeed, '');

      gSpeedRig.RadioName := 'SPEEDRIG';
      gSpeedRig.tRadioPanelSlot := 0;
      gSpeedRig.CWSpeedSync := True;
      gSpeedRig.PollingStopRequested := False;
      handler := HandleRadioMessage;
      probe := TSpeedReportingRadio.CreateProbe(handler, WANTED);
      gSpeedRig.tFactoryObject := probe;
      ActiveRadioPtr := @gSpeedRig;
      Drain;

      reportsBefore := OffMainThreadReportCount;
      gSpeedRig.StartPollingThread;

      started := GetTickCount64;
      repeat
         Drain;
         Sleep(1);
         shown := (CodeSpeed = WANTED) and
                  (string(MainElement(mweCodeSpeed).Caption) = '27 WPM');
      until shown or (GetTickCount64 - started >= BUDGET_MS);

      (* Stopped before asserting, so nothing the poller does afterwards can
        move the count under the assertion. *)
      gSpeedRig.ShutDownRadioInterface;
      Drain;

      CheckEquals(WANTED, CodeSpeed, 'the live speed follows the radio');
      CheckEquals('27 WPM', string(MainElement(mweCodeSpeed).Caption),
                  'the WPM panel shows the radio''s speed');
      CheckEquals(WANTED, gSpeedRig.SpeedMemory,
                  'and the radio remembers it (DisplayCodeSpeed stores SpeedMemory)');
      CheckEquals(reportsBefore, OffMainThreadReportCount,
                  'the polling thread wrote a control: every write must run on the ' +
                  'main thread, through a uMainThreadWork job (issue #108)');
   finally
      if gSpeedRig.tFactoryObject <> nil then
         begin
         gSpeedRig.ShutDownRadioInterface;
         end;
      ActiveRadioPtr := savedActive;
      CodeSpeed := savedSpeed;
      ActiveMode := savedMode;
      CWEnabled := savedCWEnabled;
      SetElementText(mweCodeSpeed, '');
      Drain;
   end;
end;

(* ISSUE #108: A NOTICE FROM A WORKER THREAD IS HANDED OVER, NOT REPORTED.

  ShowQuickCommandNotice is the marshalling seam for a notice -- the radio
  poller's link-failure remedy goes through it.  It used to write the caption
  through SetElementText from the worker, which deferred it but reported the
  caller as a stray control write.  Now the text and the wipe make one hop, and
  the report count must not move. *)
procedure TStatusAndNoticeTests.Test_ANoticeFromAWorkerThreadIsHandedOverWhole;
const
   NOTICE_TEXT = 'from a worker thread';
var
   writer: TNoticeWriterThread;
   reportsBefore: LongInt;
   started: QWord;
begin
   BeginTest('Test_ANoticeFromAWorkerThreadIsHandedOverWhole');
   EnsureMainForm;
   ShowQuickCommandNotice('');
   Drain;

   reportsBefore := OffMainThreadReportCount;
   writer := TNoticeWriterThread.Create(NOTICE_TEXT);
   try
      writer.WaitFor;
   finally
      writer.Free;
   end;
   CheckEquals(reportsBefore, OffMainThreadReportCount,
               'a notice from a worker thread was reported as a stray control write');

   started := GetTickCount64;
   repeat
      Drain;
      Sleep(1);
   until (string(MainElement(mweQuickCommand).Caption) = NOTICE_TEXT) or
         (GetTickCount64 - started >= 2000);

   CheckEquals(NOTICE_TEXT, string(MainElement(mweQuickCommand).Caption),
               'the notice reached the panel');
   CheckTrue(QuickCommandNoticeArmed, 'and its wipe is armed, on the main thread');

   ShowQuickCommandNotice('');
   Drain;
end;

(* ISSUE #132: THE CW THREAD ARMS NO TIMER -- THE MAIN THREAD DOES.

  The SHIPPED CW thread, started by the CPU keyer's own SendString with an
  empty message: it finds an empty ring and runs straight to its end, where it
  used to call tStartAutoCQ itself.  That enabled an LCL TTimer from the CW
  thread -- on Windows a SetTimer owned by a thread with no message loop that
  is about to exit, so the auto-CQ repeat could not fire.

  Two halves, and the first is the one that fails on the old code: with the
  thread finished and the main thread NOT YET DRAINED, the auto-CQ timer must
  not be running and nothing may have been reported; after the drain it must
  be running.  PTT is disabled, the radio is in TR0 (no swap) and the delay is
  the longest the setting allows, so nothing keys and the repeat cannot fire
  inside the test. *)
procedure TStatusAndNoticeTests.Test_TheCWThreadLeavesTheAutoCQRepeatToTheMainThread;
const
   BUDGET_MS = 3000;
var
   savedAutoCQ: boolean;
   savedAutoSend: boolean;
   savedWaitForNext: boolean;
   savedPTT: boolean;
   savedDelay: TAutoCqDelay;
   savedTwoRadio: TRMode;
   savedSync: boolean;
   savedSpeed: integer;
   reportsBefore: LongInt;
   started: QWord;
begin
   BeginTest('Test_TheCWThreadLeavesTheAutoCQRepeatToTheMainThread');
   EnsureMainForm;
   CheckTrue(ActiveRadioPtr <> nil, 'there is an active radio');
   CheckTrue(KeyerCPU <> nil, 'the CPU keyer exists');
   CheckFalse(KeyerCPU.StillBeingSent, 'no CW thread is running before the test');
   StopAppTimer(atAutoCQ);
   Drain;

   savedAutoCQ := tAutoCQMode;
   savedAutoSend := tAutoSendMode;
   savedWaitForNext := tWaitForNextChar;
   savedPTT := Settings.Ptt.Enable;
   savedDelay := Settings.Cq.AutoDelay;
   savedTwoRadio := ActiveRadioPtr^.tTwoRadioMode;
   savedSync := ActiveRadioPtr^.CWSpeedSync;
   savedSpeed := CodeSpeed;
   try
      Settings.Ptt.Enable := False;
      Settings.Cq.AutoDelay := High(TAutoCqDelay);
      tAutoCQMode := True;
      tAutoSendMode := False;
      tWaitForNextChar := False;
      ActiveRadioPtr^.tTwoRadioMode := TR0;
      ActiveRadioPtr^.CWSpeedSync := False;
      CWBufferStart := CWBufferEnd;

      reportsBefore := OffMainThreadReportCount;
      KeyerCPU.SendString('', 0);

      started := GetTickCount64;
      while KeyerCPU.StillBeingSent and (GetTickCount64 - started < BUDGET_MS) do
         begin
         Sleep(1);
         end;
      CheckFalse(KeyerCPU.StillBeingSent, 'the CW thread ran to its end');
      (* ClearThread is near the end, not at it: give the last statements
        time to run before judging what they did. *)
      Sleep(100);

      CheckFalse(AppTimerRunning(atAutoCQ),
                 'the CW thread armed the auto-CQ timer itself: it must ask the ' +
                 'main thread (mtCWMessageEnded, issue #132)');
      CheckEquals(reportsBefore, OffMainThreadReportCount,
                  'the CW thread touched a control or a timer off the main thread');

      started := GetTickCount64;
      repeat
         Drain;
         Sleep(1);
      until AppTimerRunning(atAutoCQ) or (GetTickCount64 - started >= BUDGET_MS);
      CheckTrue(AppTimerRunning(atAutoCQ),
                'and the main thread armed it, as the message ended');
   finally
      StopAppTimer(atAutoCQ);
      tAutoCQMode := savedAutoCQ;
      tAutoSendMode := savedAutoSend;
      tWaitForNextChar := savedWaitForNext;
      Settings.Ptt.Enable := savedPTT;
      Settings.Cq.AutoDelay := savedDelay;
      ActiveRadioPtr^.tTwoRadioMode := savedTwoRadio;
      ActiveRadioPtr^.CWSpeedSync := savedSync;
      CodeSpeed := savedSpeed;
      Drain;
   end;
end;

(* ISSUE #132: A DVK MESSAGE'S END IS DRAWN ON THE MAIN THREAD.

  The SHIPPED playback thread body over a one-slot message that plays nothing
  (no .WAV, recorded signs off), so it runs straight to its end.  That end used
  to call tStartAutoCQ, DisplayCodeSpeed (the 'DVK ON / OFF' panel) and
  BackToInactiveRadioAfterQSO from the playback thread.  The panel gets a real
  window first, so the old write really went through the widget set and
  TElementPanel reported it.  WINDOWS ONLY: off Windows the playback thread is
  a stub that returns at once, and voice keying says so on screen. *)
procedure TStatusAndNoticeTests.Test_TheDVKPlaybackEndIsDrawnOnTheMainThread;
{$IFDEF WINDOWS}
const
   BUDGET_MS = 3000;
var
   player: TDVPPlaybackThread;
   savedAutoCQ: boolean;
   savedPTT: boolean;
   savedDelay: TAutoCqDelay;
   savedTwoRadio: TRMode;
   savedMode: ModeType;
   savedDvk: boolean;
   savedSigns: boolean;
   savedDVPOn: boolean;
   reportsBefore: LongInt;
   started: QWord;
   done: boolean;
{$ENDIF}
begin
   BeginTest('Test_TheDVKPlaybackEndIsDrawnOnTheMainThread');
{$IFDEF WINDOWS}
   EnsureMainForm;
   CheckTrue(ActiveRadioPtr <> nil, 'there is an active radio');
   MainElement(mweCodeSpeed).HandleNeeded;
   StopAppTimer(atAutoCQ);
   Drain;

   savedAutoCQ := tAutoCQMode;
   savedPTT := Settings.Ptt.Enable;
   savedDelay := Settings.Cq.AutoDelay;
   savedTwoRadio := ActiveRadioPtr^.tTwoRadioMode;
   savedMode := ActiveMode;
   savedDvk := Settings.Dvk.Enable;
   savedSigns := Settings.Dvk.UseRecordedSigns;
   savedDVPOn := DVPOn;
   try
      Settings.Ptt.Enable := False;
      Settings.Cq.AutoDelay := High(TAutoCqDelay);
      Settings.Dvk.UseRecordedSigns := False;
      tAutoCQMode := True;
      ActiveRadioPtr^.tTwoRadioMode := TR0;
      ActiveMode := Phone;
      Settings.Dvk.Enable := True;
      DVPOn := True;
      DVPMessagesArray[1] := 'X';      (* plays nothing: no .WAV, no signs *)
      DVPMessagesArrayIndex := 2;      (* one slot *)
      SetElementText(mweCodeSpeed, '');
      Drain;

      reportsBefore := OffMainThreadReportCount;
      player := TDVPPlaybackThread.Create;
      try
         (* DRAINED WHILE IT RUNS: the old body's cross-thread caption write
           waited for the main thread, and a plain WaitFor would deadlock
           against it rather than fail. *)
         started := GetTickCount64;
         repeat
            Drain;
            Sleep(1);
            done := player.Finished;
         until done or (GetTickCount64 - started >= BUDGET_MS);
         CheckTrue(done, 'the playback thread ran to its end');
         player.WaitFor;
      finally
         player.Free;
      end;

      started := GetTickCount64;
      repeat
         Drain;
         Sleep(1);
      until ((string(MainElement(mweCodeSpeed).Caption) = 'DVK OFF') and
             AppTimerRunning(atAutoCQ)) or
            (GetTickCount64 - started >= BUDGET_MS);

      CheckEquals(reportsBefore, OffMainThreadReportCount,
                  'the playback thread touched a control or a timer off the main ' +
                  'thread: it must ask the main thread (mtDVPMessageEnded, issue #132)');
      CheckEquals('DVK OFF', string(MainElement(mweCodeSpeed).Caption),
                  'the panel says the DVK is off, drawn after DVPOn was cleared');
      CheckTrue(AppTimerRunning(atAutoCQ), 'and the auto-CQ repeat is armed');
   finally
      StopAppTimer(atAutoCQ);
      DVPMessagesArrayIndex := 1;
      DVPMessagesArray[1] := '';
      tAutoCQMode := savedAutoCQ;
      Settings.Ptt.Enable := savedPTT;
      Settings.Cq.AutoDelay := savedDelay;
      Settings.Dvk.UseRecordedSigns := savedSigns;
      ActiveRadioPtr^.tTwoRadioMode := savedTwoRadio;
      ActiveMode := savedMode;
      Settings.Dvk.Enable := savedDvk;
      DVPOn := savedDVPOn;
      SetElementText(mweCodeSpeed, '');
      Drain;
   end;
{$ELSE}
   CheckTrue(True, 'no DVK playback thread off Windows');
{$ENDIF}
end;

(* ISSUE #132: NO KEYING THREAD BODY NAMES THE UI WORK IT HANDS OVER.

  A SOURCE GUARD, for the half no test can drive: the WinKeyer reader needs a
  keyer on a serial port, and the CW thread's auto call terminate needs the
  whole entry window.  Comments are stripped first -- each body says in a
  comment what moved out of it.  The behavioural tests above cover the CW
  thread's end and the DVK's end. *)
procedure TStatusAndNoticeTests.Test_NoKeyingThreadBodyNamesTheUIWork;
const
   UI_WORK: array[0..5] of string = (
      'RETURNINCQOPMODE', 'BACKTOINACTIVERADIOAFTERQSO', 'TSTARTAUTOCQ',
      'DISPLAYCODESPEED', 'STARTAPPTIMER', 'ATTACHTHREADINPUT');

   procedure CheckBody(const aWhat, aBody: string);
   var
      i: integer;
   begin
      CheckTrue(aBody <> '', aWhat + ' is where the guard expects it');
      for i := Low(UI_WORK) to High(UI_WORK) do
         begin
         CheckEquals(0, Pos(UI_WORK[i], UpperCase(aBody)),
                     aWhat + ' calls ' + UI_WORK[i] + ' on its own thread');
         end;
   end;

begin
   BeginTest('Test_NoKeyingThreadBodyNamesTheUIWork');
   CheckBody('CWThreadProc',
             RoutineBody('trdos' + PathDelim + 'logk1ea.pas',
                         'function CWThreadProc(aParameter: Pointer): DWORD; stdcall;' +
                         LineEnding + 'label'));
   CheckBody('AutoCallTerminateIsDue',
             RoutineBody('trdos' + PathDelim + 'logk1ea.pas',
                         'function AutoCallTerminateIsDue: boolean;' +
                         LineEnding + 'begin'));
   CheckBody('wkReadThreadProc',
             RoutineBody('uWinKey.pas',
                         'function wkReadThreadProc(aParameter: Pointer): DWORD; stdcall;' +
                         LineEnding + 'label'));
   CheckBody('tDVPPlayThreadproc',
             RoutineBody('trdos' + PathDelim + 'logdvp.pas',
                         'function tDVPPlayThreadproc(aParameter: Pointer): DWORD; stdcall;' +
                         LineEnding + 'label'));
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
   Test_EveryStatusNamesItsOwnSubsystem;
   Test_NoStatusOverrunsItsPanel;
   Test_ANotNeededBandIsAnEmptyCellNotAHiddenOne;
   Test_LoggingAQSOTakesItsBandOutOfTheNeedsStrips;
   Test_TheQSONeedsStripOffersOnlyTheContestsBands;
   Test_TheTotalsHeadersNameOnlyTheContestsBands;
   Test_TheSweepstakesMultHeaderNamesTheSection;
   Test_TheMultHeaderIsTheMultiplierInEveryDomesticFileContest;
   Test_TheMultHeaderPinsOfIssue207;
   Test_AnInhibitedKeyUpTurnsThePTTIndicator;
   Test_ARadioSpeedChangeIsDrawnOnTheMainThread;
   Test_ANoticeFromAWorkerThreadIsHandedOverWhole;
   Test_TheCWThreadLeavesTheAutoCQRepeatToTheMainThread;
   Test_TheDVKPlaybackEndIsDrawnOnTheMainThread;
   Test_NoKeyingThreadBodyNamesTheUIWork;
   ReleaseMainForm;
end;

end.
