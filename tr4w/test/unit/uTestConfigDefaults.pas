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
  (tr4w.lpr:971); and not the operator, who sees a plausible number.

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
   SysUtils, uTR4WTestFramework, uConfigValues,
   uSettingsModel,   // TR4WSettings -- the settings that have left the record
   VC;   // FileNameType, for the buffer-size pins

type
   TConfigDefaultsTests = class(TTestCase)
   protected
      procedure Test_CWKeyingDefaults;
      procedure Test_NonZeroDefaultsAreNotZero;
      procedure Test_EarlierMigrationsStillHoldTheirDefaults;
      procedure Test_TwoRadioAndNetworkDefaults;
      procedure Test_OperatingAndPTTDefaults;
      procedure Test_PTTAndPaddleDefaultsLeftTheRecord;
      procedure Test_SCPBandMapAndFileDefaults;
      procedure Test_AppearanceAndFKeyDefaults;
      procedure Test_AudioDefaultsAndBufferSizes;
   public
      procedure RunAllTests; override;
   end;

implementation

procedure TConfigDefaultsTests.Test_PTTAndPaddleDefaultsLeftTheRecord;
var
   s: TR4WSettings;
begin
   (* THE FIVE PTT SETTINGS LEFT THE Config RECORD ON 2026-09-11, for
     TPttSettings in uSettingsModel.  These assertions came with them.

     A MOVE IS WHEN A DEFAULT IS EASIEST TO LOSE, which is the whole reason
     this suite exists: a record field starts at zero and a class field starts
     at zero, so a default that lived in an initialiser and was not copied into
     the new constructor becomes False or 0 in silence.  Three of these five
     were True.

     ON A FRESH OBJECT, not the singleton.  The running Settings has whatever
     the config load put in it; only a new one shows what the constructor
     carries. *)
   BeginTest('the PTT and paddle defaults survived the move out of the record');
   s := TR4WSettings.Create;
   try
      CheckTrue (s.Ptt.Enable,        'PTTEnable was a typed constant = True');
      CheckTrue (s.Ptt.ViaCommands,   'PTTViaCommand was True');
      CheckFalse(s.Ptt.Lockout,       'PTTLockout was False');
      CheckFalse(s.Ptt.NoPollDuring,  'NoPollDuringPTT was False');
      CheckEquals(15, s.Ptt.TurnOnDelay, 'PTTTurnOnDelay was 15');

      (* THE PADDLE WENT THE SAME WAY, and PaddleSpeed 0 is the one to read
        twice: it is MEANINGFUL, not the zero a record starts with -- it means
        the paddle follows the keyboard speed.  Pinned so nobody "fixes" it to
        a plausible 25 WPM. *)
      CheckFalse(s.Paddle.Swap,               'SwapPaddles was False');
      CheckEquals(0,   s.Paddle.Speed,        'PaddleSpeed 0 = follow the keyboard speed');
      CheckEquals(700, s.Paddle.MonitorTone,  'PaddleMonitorTone was 700 Hz');
      CheckEquals(13,  s.Paddle.PttHoldCount, 'PaddlePTTHoldCount was 13 dit counts');
   finally
      s.Free;
   end;
end;

procedure TConfigDefaultsTests.Test_CWKeyingDefaults;
begin
   (* Migrated 2026-08-14 from typed constants in LOGK1EA and LOGSTUFF.
     THE PADDLE AND PTT ROWS THIS TEST WAS NAMED FOR HAVE LEFT THE RECORD --
     see Test_PTTAndPaddleDefaultsLeftTheRecord, which is where their
     assertions went. What remains here is the CW message behaviour. *)
   BeginTest('the CW keying defaults are the ones the globals had');

   (* THESE FIVE LEFT THE RECORD TOO, into TCwSettings, and the assertions
     came with them -- the defaults are the point of this test and they have
     to be asserted wherever the value now lives.

     THE OTHER FIVE CW COMMANDS DID NOT MOVE, and the reason is worth having
     beside the ones that did: CW ENABLE, CW TONE, FARNSWORTH ENABLE,
     FARNSWORTH SPEED and WEIGHT are mutated by the SESSION -- control codes
     mid-message, and live keystrokes -- so a published property would start
     persisting a mid-contest adjustment. See TCwSettings. *)
   CheckFalse(Settings.Cw.AllMessagesChainable,      'AllMessagesChainable was False');
   CheckFalse(Settings.Cw.TuneWithDits,              'TuneWithDits was False');
   CheckFalse(Settings.Cw.SendCompleteFourLetterCall, 'SendCompleteFourLetterCall was False');
   CheckFalse(Settings.Cw.SpeedFromDatabase,         'SpeedFromDatabase was False');
   CheckFalse(Settings.Cw.KeypadMemories,            'KeypadMemories was False');
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

   CheckTrue(Settings.Ptt.Enable,
             'PTT disabled by default = the radio never transmits');
   CheckTrue(Settings.Paddle.MonitorTone > 0,
             'a 0 Hz sidetone = the operator hears nothing');
   CheckTrue(Settings.Paddle.PttHoldCount > 0,
             'a 0 hold count = PTT drops between characters');
   CheckTrue(Settings.Ptt.TurnOnDelay > 0,
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

   (* MOVED to TSo2rSettings. The two True defaults are the load-bearing
     ones and the reason this test exists: both were typed constants, so a
     record that starts zeroed would have silently turned them off. *)
   CheckTrue(Settings.So2r.InBandLockout,   'InBandLockout was a typed constant = True');
   CheckTrue(Settings.So2r.WaitForStrength, 'WaitForStrength was a typed constant = True');

   CheckFalse(Settings.So2r.QsyInactiveRadio, 'QsyInactiveRadio was False');
   CheckFalse(Settings.So2r.SwapRelaySense,   'SwapRelaySense was False');
   CheckFalse(Settings.So2r.TwoRadioMode,     'TwoRadioMode was False');
   CheckFalse(Settings.So2r.SkipActiveBand,   'SkipActiveBand was False');
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

   CheckTrue(Settings.Cq.AutoReturnToMode,        'AutoReturnToCQMode was True');
   CheckTrue(Settings.Cq.EscapeExitsSearchAndPounce,'EscapeExitsSearchAndPounce was True');
   CheckTrue(Settings.CallWindow.SpaceBarDupeCheck, 'SpaceBarDupeCheck was True');
   CheckTrue(Config.ConfirmEditChanges,        'ConfirmEditChanges was True');

   CheckFalse(Settings.Cq.AutoCallTerminate,      'AutoCallTerminate was False');
   CheckFalse(Settings.CallWindow.LeaveCursor, 'LeaveCursor was False');
   CheckFalse(Config.LogWithSingleEnter,     'LogWithSingleEnter was False');
   CheckFalse(Config.AutoQSONumberDecrement, 'AutoQSONumberDecrement was False');
end;

procedure TConfigDefaultsTests.Test_SCPBandMapAndFileDefaults;
begin
   // Migrated 2026-08-15. Five of the nine were True.
   //
   // UpdateRestartFileEnable is the one worth reading twice: its DECLARATION
   // carried no initialiser, so the obvious default is False -- but
   // cfgdef.pas:577 assigns True in SetConfigurationDefaultValues, which runs
   // once at startup and before the config files. Taking the declaration at face
   // value would have stopped the restart file being maintained, silently.
   BeginTest('the SCP, band map and log-file defaults survived the move');

   (* MOVED to TPossibleCallSettings, and the three KEYS came with it --
     they were never asserted here because they were bare globals rather
     than Config fields, which is exactly the kind of gap a migration is
     a good moment to close. *)
   CheckTrue(Settings.PossibleCall.Enable,   'PossibleCall.Enable was True');
   CheckEquals(';', Settings.PossibleCall.AcceptKey, 'accept key');
   CheckEquals(',', Settings.PossibleCall.LeftKey,   'left key');
   CheckEquals('.', Settings.PossibleCall.RightKey,  'right key');
   CheckTrue(Settings.CallWindow.PartialCallEnable, 'PartialCallEnable was True');
   CheckTrue(Settings.CallWindow.WildcardPartials,  'WildcardPartials was True');
   CheckTrue(Config.NameFlagEnable,          'NameFlagEnable was True');
   CheckTrue(Config.UpdateRestartFileEnable, 'set True by CFGDEF, not by its declaration');

   CheckFalse(Settings.CallWindow.ShowAllSpots, 'ShowAllSpots was False');
   (* Alt-D came across in the same commit and was never asserted here. *)
   CheckFalse(Settings.AltD.BufferEnable, 'AltD.BufferEnable was False');
   CheckFalse(Settings.AltD.CqEnable,     'AltD.CqEnable was False');
   CheckFalse(Settings.So2r.SwapPacketSpotRadios, 'SwapPacketSpotRadios was False');
   CheckFalse(Config.CheckLogFileSize,        'CheckLogFileSize was False');
   CheckFalse(Config.UnknownCountryFileEnable,'UnknownCountryFileEnable was False');
end;

procedure TConfigDefaultsTests.Test_AppearanceAndFKeyDefaults;
begin
   // Migrated 2026-08-15, all five False. Pinned anyway: False is the RIGHT
   // value here, and a test that only guards non-zero defaults would leave
   // nothing to notice if one of these were flipped while shuffling the record.
   BeginTest('the appearance and F-key defaults survived the move');

   CheckFalse(Config.NoBorder,          'NoBorder was False');
   CheckFalse(Config.NoCaption,         'NoCaption was False');
   CheckFalse(Config.NoColumnHeader,    'NoColumnHeader was False');
   CheckFalse(Config.ShowGridlines,     'ShowGridlines was False');
   CheckFalse(Config.IncludeFKeyNumber, 'IncludeFKeyNumber was False');
end;

procedure TConfigDefaultsTests.Test_AudioDefaultsAndBufferSizes;
begin
   // Migrated 2026-08-15. The booleans are ordinary; the FOUR PATHS are not.
   //
   // FileNameType is array[0..MAX_PATH-1] of AnsiChar (VC.pas:188) -- a
   // character BUFFER, not a string. CheckCommand writes through
   // @Config.<field> knowing nothing about what is there, so a field declared
   // as string would take a string header where bytes were expected and the
   // write would run past it into whatever follows. The compiler cannot see it
   // (it has a pointer) and no functional test would either, because the damage
   // lands in the NEXT field.
   //
   // So the SIZE is what gets pinned, not the value: this fails the moment
   // someone re-types one of these as string or re-declares the array with a
   // literal length that no longer matches MAX_PATH.
   BeginTest('the audio defaults, and the path fields are real MAX_PATH buffers');

   CheckFalse(Config.DVKEnable,                  'DVKEnable was False');
   CheckFalse(Config.DVKLocalizedMessagesEnable, 'DVKLocalizedMessagesEnable was False');
   CheckFalse(Config.UseRecordedSigns,           'UseRecordedSigns was False');
   CheckFalse(Config.MP3RecorderEnable,          'MP3RecorderEnable was False');

   CheckEquals(SizeOf(FileNameType), SizeOf(Config.MP3Path),     'MP3Path is a FileNameType buffer');
   CheckEquals(SizeOf(FileNameType), SizeOf(Config.MP3Player),   'MP3Player is a FileNameType buffer');
   CheckEquals(SizeOf(FileNameType), SizeOf(Config.DVKPath),     'DVKPath is a FileNameType buffer');
   CheckEquals(SizeOf(FileNameType), SizeOf(Config.DVKRecorder), 'DVKRecorder is a FileNameType buffer');

   // And they start empty, which is what makes "no folder configured" detectable.
   CheckEquals(0, Length(StrPas(Config.MP3Path)), 'MP3Path starts empty');
   CheckEquals(0, Length(StrPas(Config.DVKPath)), 'DVKPath starts empty');
end;

procedure TConfigDefaultsTests.RunAllTests;
begin
   Test_CWKeyingDefaults;
   Test_NonZeroDefaultsAreNotZero;
   Test_EarlierMigrationsStillHoldTheirDefaults;
   Test_TwoRadioAndNetworkDefaults;
   Test_OperatingAndPTTDefaults;
   Test_PTTAndPaddleDefaultsLeftTheRecord;
   Test_SCPBandMapAndFileDefaults;
   Test_AppearanceAndFKeyDefaults;
   Test_AudioDefaultsAndBufferSizes;
end;

end.
