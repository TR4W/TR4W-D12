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

(* THE DOMESTIC TABLE (LOGDOM.TDomQTHTable) -- 2026-10-16.

  LOADING A .dom INTO A TABLE THAT ALREADY HOLDS ONE. The table was 36
  hand-built linked lists, and the loop that emptied them before a top-level
  load (D7's, line for line) stepped to the next record and THEN read its
  NextRecord -- a read through nil at the end of every list. This test was
  run once against that loop and failed with EAccessViolation on the second
  load; the lists are gone (the table owns a dictionary), so the crash has
  nothing left to happen in, and this pins that a reload REPLACES the table.

  AND THE LOOKUP RULES THE DICTIONARY HAS TO KEEP (see the class's
  declaration): the first of two equal aliases wins, an alias is stored
  truncated to ten characters, and one starting with anything but 0-9 or
  A-Z, or an empty one, is not stored.

  A PRIVATE TABLE, never the live DomQTHTable: ReadDomQTHFile fills the
  table it is called on. The multipliers the files name still go to the
  sheet's domestic list (EnumDOMFILE's own write), so they are taken out. *)
unit uTestDomQTHTableReload;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TDomQTHTableReloadTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_ASecondLoadReplacesTheFirst;
      procedure Test_TheStoreKeepsTheListsRules;
      procedure Test_AnIncludeWithoutFileIsReportedNotSkipped;
      procedure Test_AnIncludeResolvesBesideTheIncludingFile;
      procedure Test_AShippedIncludeStillResolves;
      procedure Test_AMissingIncludeIsReportedNotWaitedOn;
      procedure Test_AnIncludeCycleEnds;
   end;

implementation

uses
   Classes,
   SysUtils,
   VC,
   uMults,
   LogDom,
   (* The loader's warning, captured (#88 round 3). *)
   Log4D,
   uTestLogCapture,
   (* ShippedDomDir -- the tree's dom folder. *)
   uTestContestObjects;

const
   MULT_Z = 'ZZRLD';
   MULT_Q = 'QQRLD';
   MULT_N = 'NNRLD';

function WriteDomFile(const aName: string; const aLines: array of string): string;
var
   lines: TStringList;
   i: integer;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir(False)) + aName;
   lines := TStringList.Create;
   try
      for i := Low(aLines) to High(aLines) do
         begin
         lines.Add(AnsiString(aLines[i]));
         end;
      lines.SaveToFile(AnsiString(Result));
   finally
      lines.Free;
   end;
end;

(* Takes a multiplier a file named out of the sheet's domestic list, unless
   it was there before. *)
procedure RemoveTestMultiplier(const aMult: string; aWasThere: boolean);
var
   index: integer;
begin
   if aWasThere then
      begin
      Exit;
      end;
   if mo.DomList.FindMult(aMult, index) then
      begin
      mo.DomList.Delete(index);
      end;
end;

procedure TDomQTHTableReloadTests.Test_ASecondLoadReplacesTheFirst;
var
   table: TDomQTHTable;
   first, second: string;
   hadZ, hadQ, hadN: boolean;
   index: integer;
   raisedText: string;
   loaded: boolean;
begin
   BeginTest('Test_ASecondLoadReplacesTheFirst');

   hadZ := mo.DomList.FindMult(MULT_Z, index);
   hadQ := mo.DomList.FindMult(MULT_Q, index);
   hadN := mo.DomList.FindMult(MULT_N, index);
   (* Two records under Z and one under Q: under the lists, a chain to step
      along and an end to stop at. *)
   first := WriteDomFile('tr4w_dom_reload_1.dom',
                         [MULT_Z + ' = ZZRA, ZZRB', MULT_Q + ' = QQRA']);
   second := WriteDomFile('tr4w_dom_reload_2.dom', [MULT_N + ' = NNRA']);
   table := TDomQTHTable.Create;
   try
      CheckTrue(table.ReadDomQTHFile(first, False), 'the file loads into an empty table');
      CheckTrue(table.HasPrefix('ZZRA') and table.HasPrefix('ZZRB') and
                table.HasPrefix('QQRA'), 'and holds its three aliases');

      (* THE CASE THAT READ THROUGH NIL: the same file into the full table. *)
      raisedText := '';
      loaded := False;
      try
         loaded := table.ReadDomQTHFile(first, False);
      except
         on E: Exception do
            begin
            raisedText := E.ClassName + ': ' + E.Message;
            end;
      end;
      CheckEquals('', raisedText, 'a second load into a populated table raises nothing');
      CheckTrue(loaded, 'and loads');
      CheckTrue(table.HasPrefix('ZZRA') and table.HasPrefix('ZZRB') and
                table.HasPrefix('QQRA'), 'and holds the same three aliases');

      (* A DIFFERENT file REPLACES the table -- nothing of the first is left. *)
      CheckTrue(table.ReadDomQTHFile(second, False), 'another file loads over it');
      CheckTrue(table.HasPrefix('NNRA'), 'and its alias is there');
      CheckFalse(table.HasPrefix('ZZRA') or table.HasPrefix('ZZRB') or
                 table.HasPrefix('QQRA'), 'and none of the first file''s is');
   finally
      table.Free;
      DeleteFile(first);
      DeleteFile(second);
      RemoveTestMultiplier(MULT_Z, hadZ);
      RemoveTestMultiplier(MULT_Q, hadQ);
      RemoveTestMultiplier(MULT_N, hadN);
   end;
end;

procedure TDomQTHTableReloadTests.Test_TheStoreKeepsTheListsRules;
var
   table: TDomQTHTable;
   entry: TDomQTHEntry;
begin
   BeginTest('Test_TheStoreKeepsTheListsRules');

   table := TDomQTHTable.Create;
   try
      (* THE FIRST OF TWO EQUAL ALIASES WINS -- the walk stopped at it. *)
      table.AddNewPrefixRecord('ABC', 'FIRST', 'M1');
      table.AddNewPrefixRecord('ABC', 'SECOND', 'M2');
      CheckTrue(table.FindAlias('ABC', entry), 'the alias is found');
      CheckEquals('FIRST', string(entry.DomQTH), 'and answers with the first record');
      CheckEquals('M1', string(entry.Multiplier), 'and its multiplier');

      (* TRUNCATED TO TEN, as string[10] stored it: the eleven-character
         alias is found by its first ten and not by itself, and so is a
         long name. *)
      table.AddNewPrefixRecord('ABCDEFGHIJK', 'ABCDEFGHIJKLMN', 'M3');
      CheckTrue(table.FindAlias('ABCDEFGHIJ', entry), 'a long alias is stored as its first ten');
      CheckEquals('ABCDEFGHIJ', string(entry.DomQTH), 'and its name is truncated too');
      CheckFalse(table.HasPrefix('ABCDEFGHIJK'), 'and it is not found as itself');

      (* EXACT, not a prefix match and not case-folded. *)
      CheckFalse(table.HasPrefix('AB'), 'a shorter text is not an alias');
      CheckFalse(table.HasPrefix('ABCD'), 'nor a longer one');

      (* ONLY 0-9 AND A-Z BEGIN A STORED ALIAS; an empty one is not stored. *)
      table.AddNewPrefixRecord('9XY', 'NINE', 'M4');
      CheckTrue(table.HasPrefix('9XY'), 'a digit begins an alias');
      table.AddNewPrefixRecord('#XY', 'HASH', 'M5');
      CheckFalse(table.HasPrefix('#XY'), 'a # does not');
      table.AddNewPrefixRecord('abc', 'LOWER', 'M6');
      CheckFalse(table.HasPrefix('abc'), 'nor a lowercase letter');
      table.AddNewPrefixRecord('', 'EMPTY', 'M7');
      CheckFalse(table.HasPrefix(''), 'and an empty alias is not stored');
   finally
      table.Free;
   end;
end;

(* AN INCLUDE THE LOADER WILL NOT FOLLOW IS REPORTED -- #88 round 3
   (2026-10-26). Only `INCLUDE FILE <name>` includes a file; nc.dom's
   `INCLUDE S50.DOM` was skipped in silence since D7, and no NC entrant could
   log a US state. The loader still does not follow such a line (guessing
   at another spelling would make a file mean what this reader tolerates),
   but it WARNS, naming the file and the line, and the rest of the file
   loads. The predicate is pinned on its own, the shapes Lint-DomCoverage
   checks the same way. *)
procedure TDomQTHTableReloadTests.Test_AnIncludeWithoutFileIsReportedNotSkipped;
var
   capture: TCaptureAppender;
   keep: ILogAppender;
   lg: TLogLogger;
   savedLevel: TLogLevel;
   table: TDomQTHTable;
   path: string;
   hadZ: boolean;
   index: integer;
begin
   BeginTest('Test_AnIncludeWithoutFileIsReportedNotSkipped');

   CheckFalse(DomLineIsAnUnfollowedInclude('INCLUDE FILE S50.DOM'), 'INCLUDE FILE is followed');
   CheckFalse(DomLineIsAnUnfollowedInclude('   INCLUDE FILE S50.DOM'), 'after leading blanks too');
   CheckFalse(DomLineIsAnUnfollowedInclude(#9'INCLUDE FILE S50.DOM'), 'and a tab');
   CheckTrue(DomLineIsAnUnfollowedInclude('INCLUDE S50.DOM'), 'INCLUDE without FILE is not');
   CheckTrue(DomLineIsAnUnfollowedInclude('include file s50.dom'), 'nor is a lower-case one -- the reader is case-sensitive');
   CheckTrue(DomLineIsAnUnfollowedInclude('Include'), 'nor the word alone');
   CheckFalse(DomLineIsAnUnfollowedInclude('INCLUDED states'), 'a header word that only begins INCLUDE is no include');
   CheckFalse(DomLineIsAnUnfollowedInclude('Maryland includes the District of Columbia'), 'nor prose');
   CheckFalse(DomLineIsAnUnfollowedInclude('[INCLUDE FILE ARIZONA_CTY.DOM]'), 'nor a bracketed, disabled line');
   CheckFalse(DomLineIsAnUnfollowedInclude(''), 'nor an empty line');

   hadZ := mo.DomList.FindMult(MULT_Z, index);
   path := WriteDomFile('tr4w_dom_include_without_file.dom',
                        ['INCLUDE S50.DOM', 'include file p13.dom', MULT_Z + ' = ZZRA']);
   capture := TCaptureAppender.Create('capture');
   keep := capture;
   lg := TLogLogger.GetLogger('LogDom');
   savedLevel := lg.Level;
   lg.Level := Log4D.Warn;
   lg.AddAppender(keep);
   table := TDomQTHTable.Create;
   try
      CheckTrue(table.ReadDomQTHFile(path, False), 'the file loads');
      CheckTrue(table.HasPrefix('ZZRA'), 'and its entry after the two lines is read');
      CheckFalse(table.HasPrefix('CT') or table.HasPrefix('ON'), 'neither include was followed');
      CheckEquals(2, capture.Lines.Count, 'each unfollowed include is REPORTED: ' + capture.Lines.Text);
      CheckTrue(Pos('INCLUDE S50.DOM', capture.Lines.Text) > 0, 'naming the line: ' + capture.Lines.Text);
      CheckTrue(Pos('tr4w_dom_include_without_file.dom', capture.Lines.Text) > 0,
                'and the file: ' + capture.Lines.Text);
   finally
      table.Free;
      lg.RemoveAppender(keep);
      lg.Level := savedLevel;
      keep := nil;
      DeleteFile(path);
      RemoveTestMultiplier(MULT_Z, hadZ);
   end;
end;

(* ---------------------------------------------------------------------------
   INCLUDE FILE THROUGH THE REAL LOADER -- issue #138 (2026-10-27).

   A real `INCLUDE FILE S50.DOM` planted in a county file HUNG the suite: the
   loader looked for S50.DOM in the WORKING directory's dom folder (this
   suite runs in tr4w/test/unit, which has none), and the missing file was
   reported through TF.showwarning -- a modal MessageDlg, with nobody to
   dismiss it. These tests read the real loader with NO silencing of their
   own, so a regression to a modal hangs them again rather than passing
   quietly: the suite runs with VC.WarningsHaveNoOperator set
   (tr4w_unit_tests.lpr), which TF.showwarning reads -- the fix for that
   half. Without it these tests hung the suite (the fail-first run).

   Each test reads into a PRIVATE table and a PRIVATE sheet (EnumDOMFILE
   writes every multiplier to mo.DomList), and captures the LogDom logger.
   --------------------------------------------------------------------------- *)
type
   TDomIncludeFixture = class
   private
      FDir: string;
      FFiles: TStringList;
      FSavedSheet: TMultsObject;
      FSavedCounties: boolean;
      FLogger: TLogLogger;
      FSavedLevel: TLogLevel;
      FCapture: TCaptureAppender;
      FKeep: ILogAppender;
   public
      Table: TDomQTHTable;
      constructor Create(const aDirName: string);
      destructor Destroy; override;
      (* aName in this fixture's directory, holding aLines; its full path. *)
      function Write(const aName: string; const aLines: array of string): string;
      function Captured: TStringList;
   end;

constructor TDomIncludeFixture.Create(const aDirName: string);
begin
   inherited Create;
   FDir := IncludeTrailingPathDelimiter(GetTempDir(False)) + aDirName + PathDelim;
   ForceDirectories(FDir);
   FFiles := TStringList.Create;
   FSavedSheet := mo;
   FSavedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   FCapture := TCaptureAppender.Create('capture');
   FKeep := FCapture;
   FLogger := TLogLogger.GetLogger('LogDom');
   FSavedLevel := FLogger.Level;
   FLogger.Level := Log4D.Warn;
   FLogger.AddAppender(FKeep);
   Table := TDomQTHTable.Create;
end;

destructor TDomIncludeFixture.Destroy;
var
   i: integer;
begin
   Table.Free;
   FLogger.RemoveAppender(FKeep);
   FLogger.Level := FSavedLevel;
   FKeep := nil;
   mo.Free;
   mo := FSavedSheet;
   MultipliersIsCounties := FSavedCounties;
   for i := 0 to FFiles.Count - 1 do
      begin
      DeleteFile(FFiles[i]);
      end;
   FFiles.Free;
   RemoveDir(FDir);
   inherited Destroy;
end;

function TDomIncludeFixture.Write(const aName: string; const aLines: array of string): string;
var
   lines: TStringList;
   i: integer;
begin
   Result := FDir + aName;
   lines := TStringList.Create;
   try
      for i := Low(aLines) to High(aLines) do
         begin
         lines.Add(AnsiString(aLines[i]));
         end;
      lines.SaveToFile(AnsiString(Result));
   finally
      lines.Free;
   end;
   FFiles.Add(Result);
end;

function TDomIncludeFixture.Captured: TStringList;
begin
   Result := FCapture.Lines;
end;

(* AN INCLUDE IS LOOKED FOR BESIDE THE FILE THAT NAMES IT FIRST. In the
   program the two are one place -- a shipped .dom is read from the dom
   folder and includes its neighbours -- so nothing there changes; a .dom
   read from anywhere else (this suite's temp copy, an operator's own file)
   finds its neighbour instead of the working directory's dom folder. The
   file is on disk in lower case and named in upper case, as the shipped
   files are, which is the case-tolerant lookup's job on Linux. *)
procedure TDomQTHTableReloadTests.Test_AnIncludeResolvesBesideTheIncludingFile;
var
   fixture: TDomIncludeFixture;
   top: string;
begin
   BeginTest('Test_AnIncludeResolvesBesideTheIncludingFile');

   fixture := TDomIncludeFixture.Create('tr4w_dom_include_sibling');
   try
      fixture.Write('tr4w_sibling.dom', [MULT_Q + ' = QQRA']);
      top := fixture.Write('tr4w_top.dom', [MULT_Z + ' = ZZRA', 'INCLUDE FILE TR4W_SIBLING.DOM',
                                            MULT_N + ' = NNRA']);
      CheckTrue(fixture.Table.ReadDomQTHFile(top, False), 'the file loads');
      CheckTrue(fixture.Table.HasPrefix('ZZRA'), 'its own entry before the include');
      CheckTrue(fixture.Table.HasPrefix('QQRA'), 'the included file''s entry, found beside it');
      CheckTrue(fixture.Table.HasPrefix('NNRA'), 'and its own entry after the include');
      CheckEquals(0, fixture.Captured.Count, 'and nothing is reported: ' + fixture.Captured.Text);
   finally
      fixture.Free;
   end;
end;

(* A SHIPPED FILE'S INCLUDES STILL RESOLVE through the real loader, two
   levels deep: colorado.dom includes S50.DOM (which includes S48.DOM and
   ALASKA.DOM), P13.DOM and COLORADO_CTY.DOM. Read by its full path from a
   working directory with no dom folder -- the shape that hung. *)
procedure TDomQTHTableReloadTests.Test_AShippedIncludeStillResolves;
var
   fixture: TDomIncludeFixture;
begin
   BeginTest('Test_AShippedIncludeStillResolves');

   fixture := TDomIncludeFixture.Create('tr4w_dom_include_shipped');
   try
      CheckTrue(fixture.Table.ReadDomQTHFile(ShippedDomDir + 'colorado.dom', False),
                'colorado.dom loads');
      CheckTrue(fixture.Table.HasPrefix('TX'), 'Texas, from S48.DOM through S50.DOM');
      CheckTrue(fixture.Table.HasPrefix('AK'), 'Alaska, from ALASKA.DOM through S50.DOM');
      CheckTrue(fixture.Table.HasPrefix('NL'), 'Newfoundland and Labrador, from P13.DOM');
      CheckTrue(fixture.Table.HasPrefix('ARA'), 'Arapahoe, from COLORADO_CTY.DOM');
      CheckEquals(0, fixture.Captured.Count, 'and nothing is reported: ' + fixture.Captured.Text);
   finally
      fixture.Free;
   end;
end;

(* A MISSING INCLUDED FILE IS REPORTED -- an Error naming the file that
   names it, the line, and where it was looked for -- and the rest of the
   file loads, as D7's loader went on. It is never a wait: this test
   returning at all is half of what it pins. *)
procedure TDomQTHTableReloadTests.Test_AMissingIncludeIsReportedNotWaitedOn;
var
   fixture: TDomIncludeFixture;
   top: string;
   text: string;
begin
   BeginTest('Test_AMissingIncludeIsReportedNotWaitedOn');

   fixture := TDomIncludeFixture.Create('tr4w_dom_include_missing');
   try
      top := fixture.Write('tr4w_names_a_missing_file.dom',
                           ['INCLUDE FILE TR4W_NO_SUCH_INCLUDE.DOM', MULT_Z + ' = ZZRA']);
      CheckTrue(fixture.Table.ReadDomQTHFile(top, False), 'the file itself still loads');
      CheckTrue(fixture.Table.HasPrefix('ZZRA'), 'with its entry after the include');
      text := fixture.Captured.Text;
      CheckEquals(1, fixture.Captured.Count, 'the missing file is reported once: ' + text);
      CheckTrue(Pos('ERROR', UpperCase(text)) > 0, 'as an error: ' + text);
      CheckTrue(Pos('tr4w_names_a_missing_file.dom', text) > 0, 'naming the file that names it: ' + text);
      CheckTrue(Pos('"INCLUDE FILE TR4W_NO_SUCH_INCLUDE.DOM"', text) > 0, 'and the line: ' + text);
      CheckTrue(Pos('dom' + PathDelim + 'TR4W_NO_SUCH_INCLUDE.DOM', text) > 0,
                'and where it was looked for: ' + text);
   finally
      fixture.Free;
   end;
end;

(* AN INCLUDE CYCLE ENDS. A file that includes itself re-entered the loader
   until the stack ran out; nesting is bounded now, and the line that would
   go deeper is reported, once, instead of followed. *)
procedure TDomQTHTableReloadTests.Test_AnIncludeCycleEnds;
var
   fixture: TDomIncludeFixture;
   top: string;
   text: string;
begin
   BeginTest('Test_AnIncludeCycleEnds');

   fixture := TDomIncludeFixture.Create('tr4w_dom_include_cycle');
   try
      top := fixture.Write('tr4w_cycle.dom', ['INCLUDE FILE TR4W_CYCLE.DOM', MULT_Z + ' = ZZRA']);
      CheckTrue(fixture.Table.ReadDomQTHFile(top, False), 'the file loads');
      CheckTrue(fixture.Table.HasPrefix('ZZRA'), 'with its entry');
      text := fixture.Captured.Text;
      CheckEquals(1, fixture.Captured.Count, 'the line that would go deeper is reported once: ' + text);
      (* Any case: the deepest read is the INCLUDE's own spelling on
         Windows, the file's on disk elsewhere. *)
      CheckTrue(Pos('TR4W_CYCLE.DOM', UpperCase(text)) > 0, 'naming the file: ' + text);
      CheckTrue(Pos('"INCLUDE FILE TR4W_CYCLE.DOM"', text) > 0, 'and the line: ' + text);
   finally
      fixture.Free;
   end;
end;

procedure TDomQTHTableReloadTests.RunAllTests;
begin
   Test_ASecondLoadReplacesTheFirst;
   Test_TheStoreKeepsTheListsRules;
   Test_AnIncludeWithoutFileIsReportedNotSkipped;
   Test_AnIncludeResolvesBesideTheIncludingFile;
   Test_AShippedIncludeStillResolves;
   Test_AMissingIncludeIsReportedNotWaitedOn;
   Test_AnIncludeCycleEnds;
end;

end.
