(*
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
 *)

(* WHAT A CONTEST LOG IS CALLED.

  CONTEST CREATION HAS NO AUTOMATED COVERAGE AT ALL -- the corpus is handed
  ready-made logs and never makes one, and no UI harness drives the new-contest
  dialog. Naming is the part of it that can be tested without a dialog, so it
  was extracted into a pure function for exactly that reason rather than being
  left as string formatting inside a form. *)
unit uTestLogNaming;

{$I tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogNamingTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure TestTheOrdinaryCase;
      procedure TestTheDateSortsCorrectly;
      procedure TestAMissingCallsignIsOmitted;
      procedure TestPathCharactersCannotEscapeTheName;
      procedure TestASlashedCallDoesNotRunTogether;
      procedure TestAnEmptyContestStillNamesAFile;
      procedure TestAFreeDefaultIsTheAnswer;
      procedure TestATakenDefaultGetsNumberTwo;
      procedure TestTwoTakenGetNumberThree;
      procedure TestAGapIsFilled;
      procedure TestTheNumberGoesBeforeTheExtension;
      procedure TestASanitisedNameIsNumberedAsItIs;
      procedure TestTheDirectoryIsJoinedWithOneSeparator;
      procedure TestTheDiskIsAsked;
   end;

implementation

uses
   Classes,     (* TStringList -- the fake directory *)
   SysUtils, uLogNaming;

procedure TLogNamingTests.TestTheOrdinaryCase;
begin
   BeginTest('TestTheOrdinaryCase');
   CheckEquals('ARRL-DX-CW 2026-02-21 NY4I.db',
               ContestLogFileName('ARRL-DX-CW', EncodeDate(2026, 2, 21), 'NY4I'),
               'contest, then date, then call');
end;

procedure TLogNamingTests.TestTheDateSortsCorrectly;
var
   feb, nov: string;
begin
   BeginTest('TestTheDateSortsCorrectly');
   (* yyyy-mm-dd, so a directory listing puts two runnings of one contest in
      chronological order. Any other order sorts February after November. *)
   feb := ContestLogFileName('CQ-WW-SSB', EncodeDate(2026, 2, 1), 'NY4I');
   nov := ContestLogFileName('CQ-WW-SSB', EncodeDate(2026, 11, 1), 'NY4I');
   CheckTrue(feb < nov, 'February sorts before November: ' + feb + ' vs ' + nov);
end;

procedure TLogNamingTests.TestAMissingCallsignIsOmitted;
begin
   BeginTest('TestAMissingCallsignIsOmitted');
   (* The dialog can ask for a name before the callsign has been typed. A
      trailing separator with nothing after it is a worse name than none. *)
   CheckEquals('ARRL-FD 2026-06-27.db',
               ContestLogFileName('ARRL-FD', EncodeDate(2026, 6, 27), ''),
               'no callsign, no trailing space');
end;

procedure TLogNamingTests.TestPathCharactersCannotEscapeTheName;
var
   n: string;
begin
   BeginTest('TestPathCharactersCannotEscapeTheName');
   (* THE ONE THAT MATTERS. The contest name comes from a field an operator
      types into. A backslash or a colon in it would otherwise build a path
      rather than a name, and ".." would climb out of the logs directory. *)
   n := ContestLogFileName('..' + chr(92) + '..' + chr(92) + 'evil:name',
                           EncodeDate(2026, 1, 2), 'NY4I');
   CheckTrue(Pos(chr(92), n) = 0, 'no backslash survives: ' + n);
   CheckTrue(Pos('/', n) = 0, 'no forward slash survives: ' + n);
   CheckTrue(Pos(':', n) = 0, 'no colon survives: ' + n);
end;

procedure TLogNamingTests.TestASlashedCallDoesNotRunTogether;
begin
   BeginTest('TestASlashedCallDoesNotRunTogether');
   (* W1AW/4 is an ordinary callsign and one of the corpus operators. The slash
      cannot stay, and dropping it silently would give "W1AW4" -- a different,
      real callsign. It becomes a separator. *)
   CheckEquals('ARRL-SS-SSB 2026-11-07 W1AW 4.db',
               ContestLogFileName('ARRL-SS-SSB', EncodeDate(2026, 11, 7), 'W1AW/4'),
               'the slash separates rather than vanishing');
end;

procedure TLogNamingTests.TestAnEmptyContestStillNamesAFile;
begin
   BeginTest('TestAnEmptyContestStillNamesAFile');
   (* Called from a dialog while it is being filled in, so every field can be
      empty. The answer must still be a legal file name. *)
   CheckEquals('CONTEST 2026-01-02.db',
               ContestLogFileName('', EncodeDate(2026, 1, 2), ''),
               'a placeholder rather than ".db"');
end;

(* ---------------------------------------------------------------------------
  FirstFreeLogFileName (issue 276). The fake directory is a list of full
  paths; every path the function asks about is recorded, so a test can see
  that the directory was joined correctly.
  --------------------------------------------------------------------------- *)

var
   GTakenPaths: TStringList = nil;
   GAskedPaths: TStringList = nil;

function FakeTaken(const aPath: string): boolean;
begin
   GAskedPaths.Add(aPath);
   Result := GTakenPaths.IndexOf(aPath) >= 0;
end;

(* A fresh fake directory holding aNames, each under aDir. *)
procedure FakeDirectoryHolds(const aDir: string; const aNames: array of string);
var
   i: integer;
begin
   if GTakenPaths = nil then
      begin
      GTakenPaths := TStringList.Create;
      GAskedPaths := TStringList.Create;
      end;
   GTakenPaths.Clear;
   GAskedPaths.Clear;
   for i := Low(aNames) to High(aNames) do
      begin
      GTakenPaths.Add(aDir + aNames[i]);
      end;
end;

const
   FAKE_DIR = 'LOGS' + PathDelim;
   CW_OPEN  = 'CWOPEN 2026-11-11 W1AW.db';

procedure TLogNamingTests.TestAFreeDefaultIsTheAnswer;
begin
   BeginTest('TestAFreeDefaultIsTheAnswer');
   FakeDirectoryHolds(FAKE_DIR, []);
   CheckEquals(CW_OPEN, FirstFreeLogFileName(FAKE_DIR, CW_OPEN, @FakeTaken),
               'nothing there: the default, unnumbered');
   CheckEquals(1, GAskedPaths.Count, 'one question is enough');
end;

procedure TLogNamingTests.TestATakenDefaultGetsNumberTwo;
begin
   BeginTest('TestATakenDefaultGetsNumberTwo');
   (* The second CW Open session of the day. *)
   FakeDirectoryHolds(FAKE_DIR, [CW_OPEN]);
   CheckEquals('CWOPEN 2026-11-11 W1AW 2.db',
               FirstFreeLogFileName(FAKE_DIR, CW_OPEN, @FakeTaken),
               'the default is taken: number 2, space-separated');
end;

procedure TLogNamingTests.TestTwoTakenGetNumberThree;
begin
   BeginTest('TestTwoTakenGetNumberThree');
   (* The third session. *)
   FakeDirectoryHolds(FAKE_DIR, [CW_OPEN, 'CWOPEN 2026-11-11 W1AW 2.db']);
   CheckEquals('CWOPEN 2026-11-11 W1AW 3.db',
               FirstFreeLogFileName(FAKE_DIR, CW_OPEN, @FakeTaken),
               'the default and 2 are taken: number 3');
end;

procedure TLogNamingTests.TestAGapIsFilled;
begin
   BeginTest('TestAGapIsFilled');
   (* "X 2.db" renamed away by the operator: the first free number is 2, not
      the one after the highest. *)
   FakeDirectoryHolds(FAKE_DIR, [CW_OPEN, 'CWOPEN 2026-11-11 W1AW 3.db']);
   CheckEquals('CWOPEN 2026-11-11 W1AW 2.db',
               FirstFreeLogFileName(FAKE_DIR, CW_OPEN, @FakeTaken),
               'X.db and X 3.db exist: X 2.db');
end;

procedure TLogNamingTests.TestTheNumberGoesBeforeTheExtension;
var
   n: string;
begin
   BeginTest('TestTheNumberGoesBeforeTheExtension');
   FakeDirectoryHolds(FAKE_DIR, [CW_OPEN]);
   n := FirstFreeLogFileName(FAKE_DIR, CW_OPEN, @FakeTaken);
   CheckEquals('.db', ExtractFileExt(n), 'still a .db: ' + n);
   CheckTrue(Pos('.db', n) = Length(n) - 2, 'one .db, at the end: ' + n);
   CheckTrue(Pos(PathDelim, n) = 0, 'a name, not a path: ' + n);
end;

procedure TLogNamingTests.TestASanitisedNameIsNumberedAsItIs;
var
   expected: string;
begin
   BeginTest('TestASanitisedNameIsNumberedAsItIs');
   (* W1AW/4 is sanitised to "W1AW 4" by ContestLogFileName; the number is
      added after it and the sanitised text is left alone. *)
   expected := ContestLogFileName('ARRL-SS-SSB', EncodeDate(2026, 11, 7), 'W1AW/4');
   FakeDirectoryHolds(FAKE_DIR, [expected]);
   CheckEquals('ARRL-SS-SSB 2026-11-07 W1AW 4 2.db',
               FirstFreeLogFileName(FAKE_DIR, expected, @FakeTaken),
               'the sanitised name, then the number');
end;

procedure TLogNamingTests.TestTheDirectoryIsJoinedWithOneSeparator;
begin
   BeginTest('TestTheDirectoryIsJoinedWithOneSeparator');
   (* ContestDir ends with a separator; a caller that passes one without must
      get the same questions, never "LOGSCWOPEN..." and never a doubled one. *)
   FakeDirectoryHolds(FAKE_DIR, [CW_OPEN]);
   CheckEquals('CWOPEN 2026-11-11 W1AW 2.db',
               FirstFreeLogFileName('LOGS', CW_OPEN, @FakeTaken),
               'no trailing separator: joined with one');
   CheckEquals(FAKE_DIR + CW_OPEN, GAskedPaths[0], 'the first question is the full path');
end;

procedure TLogNamingTests.TestTheDiskIsAsked;
var
   dir, first, second: string;
begin
   BeginTest('TestTheDiskIsAsked');
   (* The overload the program calls, against a real scratch folder. *)
   dir := IncludeTrailingPathDelimiter(GetTempDir) +
          'tr4w_lognaming_' + IntToStr(GetProcessID) + PathDelim;
   ForceDirectories(dir);
   first := dir + CW_OPEN;
   second := dir + 'CWOPEN 2026-11-11 W1AW 2.db';
   try
      CheckEquals(CW_OPEN, FirstFreeLogFileName(dir, CW_OPEN),
                  'an empty folder: the default');
      FileClose(FileCreate(first));
      CheckEquals('CWOPEN 2026-11-11 W1AW 2.db', FirstFreeLogFileName(dir, CW_OPEN),
                  'the default on disk: number 2');
      CheckTrue(FileExists(first), 'the existing file is left where it was');
   finally
      DeleteFile(first);
      DeleteFile(second);
      RemoveDir(dir);
   end;
end;

procedure TLogNamingTests.RunAllTests;
begin
   TestTheOrdinaryCase;
   TestTheDateSortsCorrectly;
   TestAMissingCallsignIsOmitted;
   TestPathCharactersCannotEscapeTheName;
   TestASlashedCallDoesNotRunTogether;
   TestAnEmptyContestStillNamesAFile;
   TestAFreeDefaultIsTheAnswer;
   TestATakenDefaultGetsNumberTwo;
   TestTwoTakenGetNumberThree;
   TestAGapIsFilled;
   TestTheNumberGoesBeforeTheExtension;
   TestASanitisedNameIsNumberedAsItIs;
   TestTheDirectoryIsJoinedWithOneSeparator;
   TestTheDiskIsAsked;
end;

initialization

finalization
   GTakenPaths.Free;
   GAskedPaths.Free;

end.
