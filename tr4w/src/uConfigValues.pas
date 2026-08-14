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

      TwoRadioMode: False
   );

implementation

end.
