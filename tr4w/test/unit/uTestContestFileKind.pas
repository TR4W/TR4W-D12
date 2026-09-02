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

(* WHAT KIND OF FILE IS THIS -- tests over REAL BYTES.

  EVERY FIXTURE IS WRITTEN BYTE BY BYTE rather than described, because the
  whole unit is a claim about bytes. A test that built its PNG by writing the
  text 'PNG' would pass while the real thing failed, which is the failure the
  unit exists to prevent.

  THE ONE THAT MATTERS MOST IS THE PNG. NY4I, 2026-09-02: opening one
  "appeared to die quietly".

  ---------------------------------------------------------------------------
  A TRAP IN THIS TEST FRAMEWORK, PAID FOR ONCE HERE SO NOBODY PAYS AGAIN.

  SetUp AND TearDown ARE NOT SYMMETRIC. SetUp runs from BeginTest, so once per
  TEST. TearDown runs from Check -- uTR4WTestFramework.pas:143, and again at
  :168 and :183 for the CheckEquals overloads -- so once per ASSERTION.

  A suite whose TearDown removed its fixture directory therefore destroyed it
  halfway through any test with two assertions, and the next line failed with
  "The system cannot find the path specified". That surfaced as an UNHANDLED
  EXCEPTION, exit code 217, NO message on stderr, and the run stopping at
  suite 63 of 78 -- so the 15 suites after it never ran and their ~1,900
  passes silently left the total. The visible output ended mid-test, because
  the crash discarded the buffered stdout that would have said so.

  SO: NO FILESYSTEM CLEANUP IN TearDown. This suite creates what it needs at
  the point of use and cleans up once, from RunAllTests, which it controls.
  --------------------------------------------------------------------------- *)
unit uTestContestFileKind;

{$I tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   (* A dynamic array of Byte, named here so the interface does not depend on
     which RTL unit happens to supply TBytes. *)
   TByteList = array of Byte;

   TContestFileKindTests = class(TTestCase)
   private
      function FixtureDir: string;
      function WriteFixture(const aName: string;
                            const aBytes: array of Byte): string;
      function SQLiteHeader(aApplicationId: LongWord): TByteList;
      function TextBytes(const aText: AnsiString): TByteList;
      procedure RemoveFixtures;
   public
      procedure RunAllTests; override;

      procedure TestOurDatabaseIsRecognised;
      procedure TestUnstampedDatabaseIsAccepted;
      procedure TestForeignDatabaseIsRejected;
      procedure TestTruncatedDatabaseIsRejected;
      procedure TestPNGIsUnrecognised;
      procedure TestTextConfigIsText;
      procedure TestEmptyFileIsText;
      procedure TestMissingFileIsMissing;
      procedure TestExtensionDoesNotDecide;
   end;

implementation

uses
   Classes, SysUtils, uContestFileKind, uLogSchema;

(* THE SYSTEM TEMP DIRECTORY, NOT BESIDE THE EXE. The test exe lives in
  tr4w\test\unit, which is SOURCE -- fixtures written there would show up as
  untracked files in every git status. *)
function TContestFileKindTests.FixtureDir: string;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w-filekind-tests' +
             PathDelim;
end;

procedure TContestFileKindTests.RemoveFixtures;
var
   found: TSearchRec;
begin
   if FindFirst(FixtureDir + '*', faAnyFile, found) = 0 then
      begin
      try
         repeat
            if (found.Name <> '.') and (found.Name <> '..') then
               begin
               SysUtils.DeleteFile(FixtureDir + found.Name);
               end;
         until FindNext(found) <> 0;
      finally
         FindClose(found);
      end;
      end;

   RemoveDir(FixtureDir);
end;

(* ForceDirectories HERE, at the point of use, rather than in SetUp -- see the
  trap in the unit header. This routine must work no matter what has been torn
  down since the test started. *)
function TContestFileKindTests.WriteFixture(const aName: string;
                                            const aBytes: array of Byte): string;
var
   f: TFileStream;
begin
   ForceDirectories(FixtureDir);
   Result := FixtureDir + aName;

   f := TFileStream.Create(Result, fmCreate);
   try
      if Length(aBytes) > 0 then
         begin
         f.WriteBuffer(aBytes[0], Length(aBytes));
         end;
   finally
      f.Free;
   end;
end;

(* A 100-BYTE SQLITE HEADER, which is the whole of what the classifier reads.
  Not a real database -- it does not need to be, and building one would drag
  the database layer into a test of a leaf unit. *)
function TContestFileKindTests.SQLiteHeader(aApplicationId: LongWord): TByteList;
const
   MAGIC = 'SQLite format 3';
var
   i: integer;
begin
   SetLength(Result, 100);
   for i := 0 to High(Result) do
      begin
      Result[i] := 0;
      end;

   for i := 1 to Length(MAGIC) do
      begin
      Result[i - 1] := Ord(MAGIC[i]);
      end;
   (* Result[15] stays 0 -- the header string's own terminator. *)

   (* Big-endian at offset 68, the way the file format stores it. *)
   Result[68] := (aApplicationId shr 24) and $FF;
   Result[69] := (aApplicationId shr 16) and $FF;
   Result[70] := (aApplicationId shr 8)  and $FF;
   Result[71] :=  aApplicationId         and $FF;
end;

function TContestFileKindTests.TextBytes(const aText: AnsiString): TByteList;
var
   i: integer;
begin
   SetLength(Result, Length(aText));
   for i := 1 to Length(aText) do
      begin
      Result[i - 1] := Ord(aText[i]);
      end;
end;

procedure TContestFileKindTests.TestOurDatabaseIsRecognised;
var
   p: string;
begin
   BeginTest('TestOurDatabaseIsRecognised');
   p := WriteFixture('ours.db', SQLiteHeader(LOG_APPLICATION_ID));
   CheckEquals(Ord(cfkTR4WDatabase), Ord(ClassifyContestFile(p)),
               'a database stamped TR4W is one of ours');
end;

(* ZERO IS ACCEPTED, and this test is the reason that is a decision rather than
  an oversight. Every database made before we started stamping -- including by
  earlier builds of THIS program -- has application_id 0, and refusing those
  would make an operator's existing logs unopenable over a cosmetic check.
  TLogDatabase takes the same view when it opens: it rejects only a NON-ZERO
  id that is not ours. The two must agree, or this would pass files that then
  fail to open. *)
procedure TContestFileKindTests.TestUnstampedDatabaseIsAccepted;
var
   p: string;
begin
   BeginTest('TestUnstampedDatabaseIsAccepted');
   p := WriteFixture('unstamped.db', SQLiteHeader(0));
   CheckEquals(Ord(cfkTR4WDatabase), Ord(ClassifyContestFile(p)),
               'an unstamped database is accepted, not rejected');
end;

(* 'TR4Q' -- TR4QT's own application_id (Database.h:49). A TR4QT log is not an
  interop target, so the two must be DISTINGUISHABLE rather than merely
  different. *)
procedure TContestFileKindTests.TestForeignDatabaseIsRejected;
var
   p: string;
begin
   BeginTest('TestForeignDatabaseIsRejected');
   p := WriteFixture('tr4qt.db', SQLiteHeader($54523451));
   CheckEquals(Ord(cfkForeignDatabase), Ord(ClassifyContestFile(p)),
               'another program''s database is not ours');
end;

procedure TContestFileKindTests.TestTruncatedDatabaseIsRejected;
var
   full: TByteList;
   head: TByteList;
   p:    string;
   i:    integer;
begin
   BeginTest('TestTruncatedDatabaseIsRejected');
   full := SQLiteHeader(LOG_APPLICATION_ID);
   SetLength(head, 40);
   for i := 0 to High(head) do
      begin
      head[i] := full[i];
      end;

   p := WriteFixture('truncated.db', head);
   CheckEquals(Ord(cfkForeignDatabase), Ord(ClassifyContestFile(p)),
               'claims to be SQLite but is too short to hold a header');
end;

(* THE ONE NY4I HIT. A real PNG signature followed by the start of an IHDR
  chunk -- the zero bytes are in the chunk length at offset 8, which is what
  tells the classifier this is not text. *)
procedure TContestFileKindTests.TestPNGIsUnrecognised;
var
   p: string;
begin
   BeginTest('TestPNGIsUnrecognised');
   p := WriteFixture('screenshot.png',
                     [$89, $50, $4E, $47, $0D, $0A, $1A, $0A,
                      $00, $00, $00, $0D, $49, $48, $44, $52,
                      $00, $00, $01, $00, $00, $00, $01, $00]);
   CheckEquals(Ord(cfkUnrecognised), Ord(ClassifyContestFile(p)),
               'a .png is not a contest file and must be reported as such');
end;

procedure TContestFileKindTests.TestTextConfigIsText;
var
   p: string;
begin
   BeginTest('TestTextConfigIsText');
   p := WriteFixture('contest.cfg',
                     TextBytes('MY CALL = NY4I'#13#10'CONTEST = ARRLDX'#13#10));
   CheckEquals(Ord(cfkTextConfig), Ord(ClassifyContestFile(p)),
               'an ordinary .cfg still parses as it always did');
end;

(* A freshly created .cfg is empty for the moment before anything is written to
  it. Reporting "not a valid contest file" for one would be a regression
  against today's behaviour, which parses it to nothing. *)
procedure TContestFileKindTests.TestEmptyFileIsText;
var
   p:     string;
   empty: TByteList;
begin
   BeginTest('TestEmptyFileIsText');
   SetLength(empty, 0);
   p := WriteFixture('brandnew.cfg', empty);
   CheckEquals(Ord(cfkTextConfig), Ord(ClassifyContestFile(p)),
               'an empty file keeps today''s behaviour');
end;

procedure TContestFileKindTests.TestMissingFileIsMissing;
begin
   BeginTest('TestMissingFileIsMissing');
   CheckEquals(Ord(cfkMissing),
               Ord(ClassifyContestFile(FixtureDir + 'no-such-file.cfg')),
               'a file that is not there');
   CheckEquals(Ord(cfkMissing), Ord(ClassifyContestFile('')),
               'an empty name is not a file');
end;

(* THE POINT OF CLASSIFYING BY CONTENT, in both directions and in one test.

  An operator who renames a log to .cfg still has a database, and it still must
  not be line-parsed. A text file someone named .db is still text, and handing
  it to the database layer would fail for a reason nobody could act on. The
  extension decides nothing.

  THIS IS THE TEST THAT FOUND THE TearDown TRAP -- see the unit header. It has
  two assertions and writes a file between them, which is exactly the shape
  that a per-assertion TearDown breaks. *)
procedure TContestFileKindTests.TestExtensionDoesNotDecide;
var
   p: string;
begin
   BeginTest('TestExtensionDoesNotDecide');
   p := WriteFixture('renamed-log.cfg', SQLiteHeader(LOG_APPLICATION_ID));
   CheckEquals(Ord(cfkTR4WDatabase), Ord(ClassifyContestFile(p)),
               'a database named .cfg is still a database');

   p := WriteFixture('not-really.db', TextBytes('MY CALL = NY4I'#13#10));
   CheckEquals(Ord(cfkTextConfig), Ord(ClassifyContestFile(p)),
               'a text file named .db is still text');
end;

procedure TContestFileKindTests.RunAllTests;
begin
   (* CLEANUP LIVES HERE, not in TearDown, and runs once. See the unit
     header for what putting it in TearDown cost. *)
   try
      TestOurDatabaseIsRecognised;
      TestUnstampedDatabaseIsAccepted;
      TestForeignDatabaseIsRejected;
      TestTruncatedDatabaseIsRejected;
      TestPNGIsUnrecognised;
      TestTextConfigIsText;
      TestEmptyFileIsText;
      TestMissingFileIsMissing;
      TestExtensionDoesNotDecide;
   finally
      RemoveFixtures;
   end;
end;

end.
