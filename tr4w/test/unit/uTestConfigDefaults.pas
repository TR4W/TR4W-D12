unit uTestConfigDefaults;
{$I ..\..\src\tr4w.inc}
{
  THE COMPILED-IN DEFAULTS OF THE CONFIG RECORD.

  WHY THIS EXISTS. Settings are migrating out of tr4w.ini into settings\tr4w.json,
  and each one moves from a global -- often a TYPED CONSTANT carrying a non-zero
  initial value -- into a field of the Config record. A record field defaults to
  ZERO. So the migration silently changes behaviour for every station with no
  settings file unless the initial value is carried across by hand, and nothing
  reports the loss: not the compiler, which sees a legal field; not the golden
  corpus, which runs headless and skips the settings apply entirely
  (tr4w.dpr:971); and not the operator, who sees a plausible number.

  That is the standing rule in CLAUDE.md -- a silently-defaulted field reads as a
  legal zero, so the exhaustive pin test goes in with the move.

  WHAT IS PINNED, AND WHY THESE VALUES. Every default is the value the global it
  replaced actually carried, read from the declaration being deleted, NOT chosen
  here. Where the help file states a meaning it is quoted, because a bare number
  gives a future reader nothing to check against.

  WHAT THIS CANNOT SEE. It proves the compiled-in starting point only. Whether a
  stored value reaches the field is the apply layer's job and is covered by
  Lint-ConfigOwnership -- uCFG cannot be linked into this exe, since it drags the
  whole program's globals with it.
}

interface

uses
   SysUtils, uTR4WTestFramework, uConfigValues;

type
   TConfigDefaultsTests = class(TTestCase)
   protected
      procedure Test_KeyingAndPTTDefaults;
      procedure Test_NonZeroDefaultsAreNotZero;
      procedure Test_EarlierMigrationsStillHoldTheirDefaults;
      procedure Test_TwoRadioAndNetworkDefaults;
      procedure Test_OperatingAndPTTDefaults;
   public
      procedure RunAllTests; override;
   end;

implementation

procedure TConfigDefaultsTests.Test_KeyingAndPTTDefaults;
begin
   // Migrated 2026-08-14 from typed constants in LOGK1EA and LOGSTUFF.
   BeginTest('the CW keying, paddle and PTT defaults are the ones the globals had');

   CheckFalse(Config.AllCWMessagesChainable,     'AllCWMessagesChainable was False');
   CheckFalse(Config.TuneWithDits,               'TuneWithDits was False');
   CheckFalse(Config.SendCompleteFourLetterCall, 'SendCompleteFourLetterCall was False');
   CheckFalse(Config.NoPollDuringPTT,            'NoPollDuringPTT was False');
   CheckFalse(Config.SwapPaddles,                'SwapPaddles was False');

   // PaddleSpeed 0 is MEANINGFUL, not merely the zero a record starts with: it
   // means the paddle follows the keyboard speed. Pinned so nobody "fixes" it
   // to a plausible 25 WPM.
   CheckEquals(0,   Config.PaddleSpeed,       'PaddleSpeed 0 = follow the keyboard speed');

   CheckTrue(Config.PTTEnable,                'PTTEnable was a typed constant = True');
   CheckEquals(15,  Config.PTTTurnOnDelay,    'PTTTurnOnDelay was 15');
   CheckEquals(700, Config.PaddleMonitorTone, 'PaddleMonitorTone was 700 Hz');
   CheckEquals(13,  Config.PaddlePTTHoldCount,'PaddlePTTHoldCount was 13 dit counts');
end;

procedure TConfigDefaultsTests.Test_NonZeroDefaultsAreNotZero;
begin
   // THE FAILURE MODE, STATED DIRECTLY. Above asserts the exact values; this
   // says what going wrong would MEAN, so a failure here reads as a symptom an
   // operator would report rather than a number that changed.
   //
   // Omit PTTEnable from the record initialiser and the transmitter is never
   // keyed. Omit PaddleMonitorTone and the sidetone is 0 Hz -- silence. Omit
   // PaddlePTTHoldCount and PTT drops between characters, which on an amplifier
   // is hot switching. None of those is a compile error.
   BeginTest('nothing that must not be zero has fallen back to zero');

   CheckTrue(Config.PTTEnable,
             'PTT disabled by default = the radio never transmits');
   CheckTrue(Config.PaddleMonitorTone > 0,
             'a 0 Hz sidetone = the operator hears nothing');
   CheckTrue(Config.PaddlePTTHoldCount > 0,
             'a 0 hold count = PTT drops between characters');
   CheckTrue(Config.PTTTurnOnDelay > 0,
             'a 0 turn-on delay = CW starts before the amplifier is keyed');
end;

procedure TConfigDefaultsTests.Test_EarlierMigrationsStillHoldTheirDefaults;
begin
   // The same class of value from the earlier batches. They are cheap to assert
   // and they are the ones a careless edit to the record initialiser -- adding a
   // field in the middle, say -- would disturb.
   BeginTest('the defaults migrated before this batch are still intact');

   CheckEquals(3,   Config.CodeSpeedIncrement, 'a 0 step = the speed keys stop working');
   CheckEquals(700, Config.CWTone,             'CW sidetone 700 Hz');
   CheckTrue(Config.CWEnable,                  'CW on by default');
   CheckEquals(25,  Config.FarnsworthSpeed,    'Farnsworth character speed 25');
   CheckEquals(3,   Config.tDitDahRatio,       'a 0 dit/dah ratio is not sendable');
   CheckEquals(3,   Config.LeadingZeros,       'serial numbers pad to 3');
   CheckEquals(200, Config.SayHiRateCutOff,    'say-hi cutoff 200');

   // Weight is REAL and its CFGCA bounds are stored x10 (5..15 = 0.5..1.5), so
   // 1.0 sits in the middle rather than at an edge.
   CheckTrue(Abs(Config.Weight - 1.0) < 0.0001, 'CW weight 1.0');
end;

procedure TConfigDefaultsTests.Test_TwoRadioAndNetworkDefaults;
begin
   // Migrated 2026-08-15. Two of the six were typed constants = True, and those
   // are the ones that matter: a False InBandLock stops the guard that prevents
   // both radios landing on one band, and a False WaitForStrength stops the SO2R
   // path waiting for a signal report. Neither announces itself.
   BeginTest('the two-radio and multi-op defaults survived the move');

   CheckTrue(Config.InBandLock,       'InBandLock was a typed constant = True');
   CheckTrue(Config.WaitForStrength,  'WaitForStrength was a typed constant = True');

   CheckFalse(Config.QSYInactiveRadio,    'QSYInactiveRadio was False');
   CheckFalse(Config.SwapRadioRelaySense, 'SwapRadioRelaySense was False');
   CheckFalse(Config.MultiMultsOnly,      'MultiMultsOnly was False');
   CheckFalse(Config.IntercomFileEnable,  'IntercomFileEnable was False');
end;

procedure TConfigDefaultsTests.Test_OperatingAndPTTDefaults;
begin
   // Migrated 2026-08-15. FIVE of these ten were typed constants = True, which
   // is the whole reason this test exists: a record field starts at zero, and
   // each of the five turns a working default into an off switch.
   //
   // PTTViaCommand False stops a CAT-keyed radio transmitting at all. The other
   // four change how the log behaves under the operator's hands mid-contest.
   BeginTest('the operating and PTT defaults survived the move');

   CheckTrue(Config.PTTViaCommand,             'PTTViaCommand was True');
   CheckTrue(Config.AutoReturnToCQMode,        'AutoReturnToCQMode was True');
   CheckTrue(Config.EscapeExitsSearchAndPounce,'EscapeExitsSearchAndPounce was True');
   CheckTrue(Config.SpaceBarDupeCheckEnable,   'SpaceBarDupeCheckEnable was True');
   CheckTrue(Config.ConfirmEditChanges,        'ConfirmEditChanges was True');

   CheckFalse(Config.PTTLockout,             'PTTLockout was False');
   CheckFalse(Config.AutoCallTerminate,      'AutoCallTerminate was False');
   CheckFalse(Config.LeaveCursorInCallWindow,'LeaveCursorInCallWindow was False');
   CheckFalse(Config.LogWithSingleEnter,     'LogWithSingleEnter was False');
   CheckFalse(Config.AutoQSONumberDecrement, 'AutoQSONumberDecrement was False');
end;

procedure TConfigDefaultsTests.RunAllTests;
begin
   Test_KeyingAndPTTDefaults;
   Test_NonZeroDefaultsAreNotZero;
   Test_EarlierMigrationsStillHoldTheirDefaults;
   Test_TwoRadioAndNetworkDefaults;
   Test_OperatingAndPTTDefaults;
end;

end.
