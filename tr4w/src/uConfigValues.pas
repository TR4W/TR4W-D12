{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
 This file is part of TR4W  (SRC)
 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uConfigValues;
{$I tr4w.inc}

{
  THE LIVE CONFIGURATION VALUES -- the "cfg object" (NY4I).

  Step 3 of retiring the ini is that a migrated setting's controlling variable
  stops being a global and is reached through the configuration object instead.
  This is that object: one record variable, one field per migrated setting,
  replacing one scattered global each.

  WHY A RECORD VARIABLE AND NOT A CLASS.  Not a stylistic choice -- CFGCA and
  ArrayRecordArray are const arrays holding the ADDRESS of each setting's
  storage, and CheckCommand writes through that address.  A compile-time
  initialiser can take @SomeVar.Field, whose offset is known when the program is
  linked; it cannot take the address of a field of an object that will not exist
  until run time.  So as long as CheckCommand is the applier, the storage must be
  statically addressable.

  The existing @CD.CountryString row is the same construction and has always
  compiled, which is what established this works before anything was moved.

  WHAT THIS BUYS, given that `Config` is itself one global.  The thirty settings
  in question are today thirty unrelated variables scattered across LOGWIND,
  VC and half the TRDOS core -- writable from anywhere, with nothing naming them
  as configuration and no way to enumerate them.  Gathering them here makes them
  one named thing, gives every call site a reason to say Config.X out loud, and
  leaves exactly one place to change when the applier stops being CheckCommand.
  That last step is what finally removes the address-taking, and it cannot
  happen until the rows have moved.

  WHAT DOES NOT BELONG HERE.  Per-QSO or per-contest state.  This record is for
  values an operator SETS, and it should stay small enough to read at a glance.
}

interface

uses
   { FOR FileNameType ONLY, and it must be THAT type and not a lookalike.
     It is array[0..MAX_PATH-1] of AnsiChar (VC.pas:188) -- a character
     buffer, not a string. CheckCommand writes through @Config.<field>
     with no idea what is on the other side, so re-declaring the array
     here with a hardcoded 260 would work until the day MAX_PATH moved,
     and then write past the end of the field in silence.

     This unit was deliberately dependency-free. VC does not reference it
     back, so there is no cycle, and the test executable already links VC. }
   VC;

type
   { One field per migrated setting.  Add a field in the same commit that flips
     the row -- an orphan field is harmless, a missing one does not compile. }
   TR4WConfig = record
      { CW SPEED INCREMENT -- how far a speed-up/slow-down keystroke moves.
        Was a typed constant in LOGWIND.PAS, reached by nine call sites across
        MainUnit and LOGSTUFF.  Range 1..10, enforced by the CFGCA row. }
      CodeSpeedIncrement: integer;

      { HAMSCORE -- live score posting to scoredistributor.net (issues #783,
        #931).  Was five variables in uHamScore.pas.

        THE TYPES MUST MATCH THE OLD DECLARATIONS EXACTLY.  CheckCommand writes
        through @Config.<field> with no idea what is on the other side, so a
        ctString row aimed at anything other than a ShortString would write 256
        bytes into whatever fits there.  Nothing would report it: not the
        compiler, which sees only a pointer, and not a test, because the damage
        lands in the NEXT field.  These four are ShortString and Boolean because
        that is what they were. }
      HamScoreEnable: boolean;
      HamScoreURL: ShortString;
      HamScoreUsername: ShortString;
      HamScorePassword: ShortString;
      HamScoreSendContactInfo: boolean;

      { SO2R / two-radio, CW and scoreboard settings migrated 2026-08-14.
        Types copied verbatim from the declarations they replace -- CheckCommand
        writes through @Config.<field> and cannot see a mismatch. }
      AltDBufferEnable: boolean;
      AltDCQEnable: boolean;
      AlwaysCallBlindCQ: boolean;
      SkipActiveBand: boolean;
      CWSpeedFromDataBase: boolean;
      KeypadCWMemories: boolean;
      SayHiEnable: boolean;
      SayHiRateCutOff: integer;
      LeadingZeroCharacter: AnsiChar;
      tDitDahRatio: integer;
      GetScoresSeverPostingAddress: ShortString;
      GetScoresSeverReadingAddress: ShortString;
      tConnectionAtStartup: boolean;

      { CW KEYING, migrated 2026-08-14. These five differ from everything above:
        THE SESSION MUTATES THEM. Weight, FarnsworthEnable and FarnsworthSpeed are
        changed by CW-buffer control codes mid-message (LOGK1EA), and CWEnable and
        CWTone by live keystrokes. So the stored value is what the session STARTS
        with; a change made while operating is not written back. That was already
        true and simply undocumented.

        Weight is REAL, not integer, and its CFGCA bounds are stored x10 --
        crMin:5/crMax:15 means 0.5..1.5 (uCFG.pas:1526 divides by ten), which is
        why a default of 1.0 sits correctly in the middle of a 5..15 row. }
      CWEnable: boolean;
      CWTone: integer;
      FarnsworthEnable: boolean;
      FarnsworthSpeed: integer;
      Weight: REAL;

      { TWO RADio MODE -- the sole mode knob. SINGLE RADIO MODE, its
        deprecated inverse, was withdrawn in the same commit. }
      TwoRadioMode: boolean;

      { LEADING ZEROS -- a CW setting (NY4I), not a contest one: it shapes the
        string the keyer sends. Contest .cfg files DO set it (six of them,
        both CQ-WPX among them) and such a line wins while that contest is
        loaded -- see CommandCameFromContestCFG. }
      LeadingZeros: integer;

      { CW KEYING, PADDLE AND PTT -- migrated 2026-08-14.

        Category A by the plan's own test: no code assigns any of them (the
        apparent writers in CFGDEF.PAS are all commented out), and none of the
        74 contest .cfg files names one. The config table was their only writer.

        FOUR OF THEM WERE TYPED CONSTANTS WITH NON-ZERO DEFAULTS, and that is
        the trap in this batch. A record field defaults to zero, so moving them
        without carrying the value across would disable PTT outright, drop the
        paddle sidetone to 0 Hz and set the PTT hold to nothing -- silently, on
        every station with no settings file, with nothing to report it. The
        initialiser below is the whole safeguard. }
      AllCWMessagesChainable: boolean;
      TuneWithDits: boolean;
      SendCompleteFourLetterCall: boolean;
      PTTEnable: boolean;
      PTTTurnOnDelay: integer;
      NoPollDuringPTT: boolean;
      SwapPaddles: boolean;
      PaddleSpeed: integer;
      PaddleMonitorTone: integer;
      PaddlePTTHoldCount: integer;

      { TWO-RADIO AND MULTI-OP, migrated 2026-08-15.

        Defaults copied from the declarations they replace, NOT chosen here.
        InBandLock and WaitForStrength were typed constants = True; losing that
        turns the in-band guard off and stops the SO2R code waiting for a signal
        report, neither of which announces itself. }
      InBandLock: boolean;
      QSYInactiveRadio: boolean;
      SwapRadioRelaySense: boolean;
      WaitForStrength: boolean;
      MultiMultsOnly: boolean;
      IntercomFileEnable: boolean;

      { OPERATING AND PTT, migrated 2026-08-15.

        Five of these ten were typed constants = True. A record field defaults to
        zero, so carrying the value across by hand is the whole safeguard, and
        uTestConfigDefaults pins every one in the same commit. }
      PTTViaCommand: boolean;
      PTTLockout: boolean;
      AutoCallTerminate: boolean;
      AutoReturnToCQMode: boolean;
      EscapeExitsSearchAndPounce: boolean;
      LeaveCursorInCallWindow: boolean;
      LogWithSingleEnter: boolean;
      SpaceBarDupeCheckEnable: boolean;
      ConfirmEditChanges: boolean;
      AutoQSONumberDecrement: boolean;

      { SUPER CHECK PARTIAL, BAND MAP AND LOG FILES, migrated 2026-08-15.

        UpdateRestartFileEnable is the odd one: its declaration carries no
        initialiser, but CFGDEF.PAS:577 assigns True in
        SetConfigurationDefaultValues. That runs ONCE at startup and BEFORE the
        config files, so it is an initial default and not a competing owner --
        checked rather than assumed, because a defaults routine that ran on
        contest change would silently reset the setting instead. The record
        default matches it, and the assignment now writes the same field. }
      PossibleCallEnable: boolean;
      PartialCallEnable: boolean;
      WildCardPartials: boolean;
      NameFlagEnable: boolean;
      CallWindowShowAllSpots: boolean;
      SwapPacketSpotRadios: boolean;
      CheckLogFileSize: boolean;
      UnknownCountryFileEnable: boolean;
      UpdateRestartFileEnable: boolean;

      { The function-key button captions, migrated 2026-08-15.

        NOT held with the Appearance group even though it changes what is drawn.
        What it gates is one string prefix in uFunctionKeys ('F1' above the
        message text); it does not touch the grid the LCL conversion replaces,
        and the page it belongs on -- CW Settings, where those messages are
        configured -- already exists. }
      IncludeFKeyNumber: boolean;

      { The old Appearance menu, migrated 2026-08-15.

        NY4I: "You can move these items to the Appearance tab and we can get rid
        of the old Appearance form in TR4W." That form is RunOptionsDialog
        (cfAppearance) -- the Ctrl-J grid filtered to one cfFunc -- reached from
        the Appearance menu item.

        ROW COUNT and WINDOW SIZE are NOT here: both are ckArray rows whose
        target is an ArrayRecordArray entry rather than crAddress, which is a
        different move. REMINDER is not a scalar setting at all. The menu item
        cannot go until all three are dealt with. }
      NoBorder: boolean;
      NoCaption: boolean;
      NoColumnHeader: boolean;
      ShowGridlines: boolean;

      { AUDIO -- MP3 recording and the digital voice keyer, migrated 2026-08-15.

        THE FOUR PATHS ARE FileNameType, which is array[0..MAX_PATH-1] of
        AnsiChar (VC.pas:188) -- a CHARACTER ARRAY, not a string. CheckCommand
        writes through @Config.<field> knowing nothing about what is there, so
        declaring these as string would have it write a string header over the
        first bytes of a buffer and scribble past whatever follows. Nothing
        would report it: not the compiler, which sees a pointer, and not a test,
        because the damage lands in the NEXT field. The type is copied verbatim
        from the declarations being replaced. }
      MP3RecorderEnable: boolean;
      MP3Path: FileNameType;
      MP3Player: FileNameType;
      DVKEnable: boolean;
      DVKLocalizedMessagesEnable: boolean;
      DVKPath: FileNameType;
      DVKRecorder: FileNameType;
      UseRecordedSigns: boolean;
   end;

var
   { Initialised to the SAME defaults the globals carried, so a station with no
     settings file behaves exactly as before.  A zero here would not be a
     neutral starting point -- a speed increment of zero means the speed-up and
     slow-down keys quietly stop working. }
   Config: TR4WConfig = (
      CodeSpeedIncrement: 3;

      HamScoreEnable: False;
      // Issue #920: the RTC 3.0 endpoint per the spec.  An operator may point
      // HAMSCORE URL at hamscore.com/postxml/index.php (which also serves 3.0)
      // or any future mirror.  Plain HTTP is the spec default; an https:// URL
      // takes the existing TIdHTTP + TLS path transparently.
      HamScoreURL: 'http://scoredistributor.net/';
      HamScoreUsername: '';   // empty falls back to MY CALL
      HamScorePassword: '';
      HamScoreSendContactInfo: True;

      AltDBufferEnable: False;
      AltDCQEnable: False;
      AlwaysCallBlindCQ: False;
      SkipActiveBand: False;
      CWSpeedFromDataBase: False;
      KeypadCWMemories: False;
      SayHiEnable: False;
      SayHiRateCutOff: 200;
      LeadingZeroCharacter: 'T';
      tDitDahRatio: 3;
      GetScoresSeverPostingAddress: '';
      GetScoresSeverReadingAddress: '';
      tConnectionAtStartup: False;

      CWEnable: True;
      CWTone: 700;
      FarnsworthEnable: False;
      FarnsworthSpeed: 25;
      Weight: 1.0;

      TwoRadioMode: False;

      LeadingZeros: 3;

      AllCWMessagesChainable: False;
      TuneWithDits: False;
      SendCompleteFourLetterCall: False;
      { True, 15, 700 and 13 are NOT arbitrary -- they are the values the typed
        constants in LOGK1EA carried, kept so a station with no settings file
        behaves exactly as it did before. }
      PTTEnable: True;
      PTTTurnOnDelay: 15;
      NoPollDuringPTT: False;
      SwapPaddles: False;
      PaddleSpeed: 0;
      PaddleMonitorTone: 700;
      PaddlePTTHoldCount: 13;
      InBandLock: True;
      QSYInactiveRadio: False;
      SwapRadioRelaySense: False;
      WaitForStrength: True;
      MultiMultsOnly: False;
      IntercomFileEnable: False;
      PTTViaCommand: True;
      PTTLockout: False;
      AutoCallTerminate: False;
      AutoReturnToCQMode: True;
      EscapeExitsSearchAndPounce: True;
      LeaveCursorInCallWindow: False;
      LogWithSingleEnter: False;
      SpaceBarDupeCheckEnable: True;
      ConfirmEditChanges: True;
      AutoQSONumberDecrement: False;
      PossibleCallEnable: True;
      PartialCallEnable: True;
      WildCardPartials: True;
      NameFlagEnable: True;
      CallWindowShowAllSpots: False;
      SwapPacketSpotRadios: False;
      CheckLogFileSize: False;
      UnknownCountryFileEnable: False;
      UpdateRestartFileEnable: True;
      IncludeFKeyNumber: False;
      NoBorder: False;
      NoCaption: False;
      NoColumnHeader: False;
      ShowGridlines: False;
      MP3RecorderEnable: False;
      MP3Path: '';
      MP3Player: '';
      DVKEnable: False;
      DVKLocalizedMessagesEnable: False;
      DVKPath: '';
      DVKRecorder: '';
      UseRecordedSigns: False
   );

implementation

end.
