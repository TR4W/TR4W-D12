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
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uTestAudio;
{$I ..\..\src\tr4w.inc}

(* THE AUDIO DECISIONS, TESTED WITHOUT MAKING A SOUND.

  NY4I, 2026-09-08: "write a unit to handle it all and we can test it
  independently." This is the independent half.

  WHAT IS TESTABLE HERE IS EVERY DECISION uAudio MAKES: whether a request is
  attempted at all, which helper a Unix box would choose and in what order,
  what each helper is called, and which tone requests are refused. None of it
  opens a device, so it runs on the build machine and in CI.

  WHAT IS DELIBERATELY NOT TESTED: that a sound comes out. That needs a
  speaker and an operator, and no unit test can stand in for it -- which is
  the same line the radio work draws between the unit tests and the bench.

  THE PROBE INJECTION IS THE WHOLE TRICK. ChooseUnixPlayer takes a function
  that answers "is this executable available", so a test supplies its own
  answer and the result does not depend on what happens to be installed on
  the machine running the suite. A test that asked the real PATH would pass
  or fail for reasons that have nothing to do with the code. *)

interface

uses
   uTR4WTestFramework;

type
   TAudioTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_CanPlayFile_RejectsEmptyAndMissing;
      procedure Test_CanPlayFile_AcceptsAFileThatExists;
      procedure Test_PlayerOrder_PrefersAplay;
      procedure Test_PlayerOrder_FallsBackInOrder;
      procedure Test_PlayerNone_WhenNothingInstalled;
      procedure Test_PlayerNone_WhenNoProbeGiven;
      procedure Test_PlayerExecutableNames;
      procedure Test_ToneRange;
      procedure Test_ToneDurationMustBeNonZero;
   end;

implementation

uses
   SysUtils,
   uAudio;

{ ---- probes the tests inject, standing in for "what is installed" ---- }

function ProbeNothing(const aName: string): boolean;
begin
   Result := False;
end;

function ProbeEverything(const aName: string): boolean;
begin
   Result := True;
end;

function ProbeOnlyPaplay(const aName: string): boolean;
begin
   Result := aName = 'paplay';
end;

function ProbeOnlyAfplay(const aName: string): boolean;
begin
   Result := aName = 'afplay';
end;

procedure TAudioTests.RunAllTests;
begin
   Test_CanPlayFile_RejectsEmptyAndMissing;
   Test_CanPlayFile_AcceptsAFileThatExists;
   Test_PlayerOrder_PrefersAplay;
   Test_PlayerOrder_FallsBackInOrder;
   Test_PlayerNone_WhenNothingInstalled;
   Test_PlayerNone_WhenNoProbeGiven;
   Test_PlayerExecutableNames;
   Test_ToneRange;
   Test_ToneDurationMustBeNonZero;
end;

procedure TAudioTests.Test_CanPlayFile_RejectsEmptyAndMissing;
begin
   BeginTest('Test_CanPlayFile_RejectsEmptyAndMissing');

   { An empty path is the interesting one: the DVP builds its filename by
     concatenation, so an unset path arrives here as '' rather than as
     something obviously wrong. }
   CheckFalse(CanPlayFile(''), 'empty path is refused');
   CheckFalse(CanPlayFile('no-such-file-anywhere.wav'),
              'a file that is not there is refused');
end;

procedure TAudioTests.Test_CanPlayFile_AcceptsAFileThatExists;
var
   path: string;
   f:    TextFile;
begin
   BeginTest('Test_CanPlayFile_AcceptsAFileThatExists');

   { Any existing file will do -- CanPlayFile answers "would this be
     attempted", not "is this valid audio". Distinguishing those is the
     player's job and it reports its own failure. }
   path := GetTempFileName;
   AssignFile(f, path);
   Rewrite(f);
   WriteLn(f, 'not really a wav');
   CloseFile(f);
   try
      CheckTrue(CanPlayFile(path), 'an existing file is attempted');
   finally
      SysUtils.DeleteFile(path);
   end;

   CheckFalse(CanPlayFile(path), 'and is refused again once deleted');
end;

procedure TAudioTests.Test_PlayerOrder_PrefersAplay;
begin
   BeginTest('Test_PlayerOrder_PrefersAplay');

   { With everything installed, aplay wins: it talks to ALSA directly and is
     present on a bare Linux install, so it has the fewest moving parts. }
   CheckEquals(Ord(upAplay), Ord(ChooseUnixPlayer(@ProbeEverything)),
               'aplay is preferred when all three exist');
end;

procedure TAudioTests.Test_PlayerOrder_FallsBackInOrder;
begin
   BeginTest('Test_PlayerOrder_FallsBackInOrder');

   CheckEquals(Ord(upPaplay), Ord(ChooseUnixPlayer(@ProbeOnlyPaplay)),
               'paplay when aplay is absent');
   CheckEquals(Ord(upAfplay), Ord(ChooseUnixPlayer(@ProbeOnlyAfplay)),
               'afplay when it is the only one -- the macOS case');
end;

procedure TAudioTests.Test_PlayerNone_WhenNothingInstalled;
begin
   BeginTest('Test_PlayerNone_WhenNothingInstalled');

   { The answer must be a value, not a guess: PlayFile logs and returns False
     rather than running something that is not there. }
   CheckEquals(Ord(upNone), Ord(ChooseUnixPlayer(@ProbeNothing)),
               'no player when none is installed');
   CheckEquals('', UnixPlayerExecutable(upNone),
               'and upNone names no executable');
end;

procedure TAudioTests.Test_PlayerNone_WhenNoProbeGiven;
begin
   BeginTest('Test_PlayerNone_WhenNoProbeGiven');

   { A nil probe is a caller error, and the safe answer is "no player" rather
     than a call through a nil pointer. }
   CheckEquals(Ord(upNone), Ord(ChooseUnixPlayer(nil)),
               'a nil probe yields upNone, not a crash');
end;

procedure TAudioTests.Test_PlayerExecutableNames;
begin
   BeginTest('Test_PlayerExecutableNames');

   { Pinned because they are what actually gets executed -- a typo here is a
     feature that silently does nothing on one platform. }
   CheckEquals('aplay',  UnixPlayerExecutable(upAplay),  'aplay');
   CheckEquals('paplay', UnixPlayerExecutable(upPaplay), 'paplay');
   CheckEquals('afplay', UnixPlayerExecutable(upAfplay), 'afplay');
end;

procedure TAudioTests.Test_ToneRange;
begin
   BeginTest('Test_ToneRange');

   { 37..32767 Hz is what Windows.Beep documents. Outside it the call fails,
     so refusing here turns a silent no-op into a logged reason. }
   CheckFalse(IsSaneTone(36, 100),    '36 Hz is below the minimum');
   CheckTrue(IsSaneTone(37, 100),     '37 Hz is the minimum and is allowed');
   CheckTrue(IsSaneTone(32767, 100),  '32767 Hz is the maximum and is allowed');
   CheckFalse(IsSaneTone(32768, 100), '32768 Hz is above the maximum');

   { The tones TR4W actually asks for, from tDoABeep and QuickBeep. }
   CheckTrue(IsSaneTone(300, 60),   'ThreeHarmonics low tone');
   CheckTrue(IsSaneTone(2000, 75),  'Beepsingle');
   CheckTrue(IsSaneTone(1500, 150), 'Warning');
   CheckTrue(IsSaneTone(1000, 300), 'QuickBeep');
end;

procedure TAudioTests.Test_ToneDurationMustBeNonZero;
begin
   BeginTest('Test_ToneDurationMustBeNonZero');

   { A zero duration is a caller bug that would otherwise be invisible -- the
     call succeeds and nothing is heard. }
   CheckFalse(IsSaneTone(1000, 0), 'zero duration is refused');
   CheckTrue(IsSaneTone(1000, 1),  'one millisecond is allowed');
end;

end.
