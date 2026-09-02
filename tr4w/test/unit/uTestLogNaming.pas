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
   end;

implementation

uses
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

procedure TLogNamingTests.RunAllTests;
begin
   TestTheOrdinaryCase;
   TestTheDateSortsCorrectly;
   TestAMissingCallsignIsOmitted;
   TestPathCharactersCannotEscapeTheName;
   TestASlashedCallDoesNotRunTogether;
   TestAnEmptyContestStillNamesAFile;
end;

end.
