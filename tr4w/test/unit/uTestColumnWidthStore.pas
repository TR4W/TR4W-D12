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
unit uTestColumnWidthStore;
{$I ..\..\src\tr4w.inc}

(*
  THE COLUMN WIDTHS AN OPERATOR DRAGGED (issue 234).

  The store (uColumnWidthStore), the file section (uTR4WConfigFile), the grid
  helpers (uLCLFormHelpers) and TLogGrid's own list.

  NO TEST HERE WRITES THE PROGRAM'S SETTINGS FILE. The file tests use temp
  files; the grid tests use a store they hold, or the in-memory pending marks,
  which each test clears behind itself. A flush is never called.
*)

interface

uses
   Classes,
   uTR4WTestFramework;

type
   TColumnWidthStoreTests = class(TTestCase)
   private
      FTempFiles: TStringList;
      (* The contest log the store is pointed at, and what it was pointed at
        before -- see StartContestLog. *)
      FSavedSilent: boolean;
      FSavedLogName: string;
      (* aGrid is a TLogGrid; TObject because uLogGrid is used only below. *)
      procedure CheckFills(const aGrid: TObject; const aWhat: string);
      function ContestLogName(const aLeaf: string): string;
      procedure StartContestLog(const aDb: string);
      procedure OpenContestLog(const aDb: string);
      procedure StopContestLog;
   protected
      procedure Test_Store_RoundTripIsKeyedByGridAndToken;
      procedure Test_Store_RefusesBlankNamesAndNonPositiveWidths;
      procedure Test_Store_DamagedEntriesAreSkippedAndAQuotedNumberReads;
      procedure Test_File_UnknownGridsAndTokensSurviveASave;
      procedure Test_Clamp_NeverNarrowerThanHeaderOrMinimum;
      procedure Test_Grid_ATokenMismatchAndAnUnevenListAreHarmless;
      procedure Test_Grid_WidthsAreStoredAt96Dpi;
      procedure Test_Grid_ARestoredWidthIsNoNarrowerThanItsHeader;
      procedure Test_LogGrid_ADragIsKeptWhateverTheContestFileIs;
      procedure Test_LogGrid_EachGridReadsOnlyItsOwnHome;
      procedure Test_Flush_AMarkReachesTheFileAndAFreshGridReadsIt;
      procedure Test_ContestDb_RejectedRowsAreReadNow;
      procedure Test_ContestDb_ADragRoundTripsThroughTheDatabase;
      procedure Test_ContestDb_TwoContestsKeepTheirOwnWidths;
      procedure Test_ContestDb_OldAndOddRowsAreHarmless;
      procedure Test_LogGridFill_NoWidthsOverridden;
      procedure Test_LogGridFill_SomeWidthsOverridden;
      procedure Test_LogGridFill_EveryWidthOverridden;
      procedure Test_LogGridFill_AfterADragAndAResize;
   public
      constructor Create(const AName: string);
      destructor Destroy; override;
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Forms, Controls, Grids,
   uJSON, uFileText, uColumnWidthStore, uTR4WConfigFile, uLCLFormHelpers,
   uLogGrid, VC, utils_text, uTestShowOffScreen,
   (* The main log's widths in a real contest database: the store's open and
     close, against a temp log. *)
   uContestRegistry, uLogDatabase, uLogRepository, uLogStore,
   uTestLatestContest;   (* MakeTestContestLog / ScrubTestLog *)

type
   (* Reaches TLogGrid's protected HeaderSized -- what the LCL calls when a
     divider is dragged or double-clicked. *)
   TLogGridProbe = class(TLogGrid)
   public
      procedure Sized(const aCol: integer);
   end;

procedure TLogGridProbe.Sized(const aCol: integer);
begin
   HeaderSized(True, aCol);
end;

type
   (* Which log columns are enabled -- the contest's choice, a global the
     LogGrid tests change and must put back. *)
   TColumnEnables = array[LogColumnsType] of boolean;

function SaveColumnEnables: TColumnEnables;
var
   c: LogColumnsType;
begin
   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      Result[c] := ColumnsArray[c].Enable;
      end;
end;

procedure RestoreColumnEnables(const aSaved: TColumnEnables);
var
   c: LogColumnsType;
begin
   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      ColumnsArray[c].Enable := aSaved[c];
      end;
end;

(* Only these two columns shown, Callsign first. *)
procedure ShowOnlyCallsignAndFreq;
var
   c: LogColumnsType;
begin
   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      ColumnsArray[c].Enable := c in [logColCallsign, logColFreq];
      end;
end;

(* THE OPEN CONTEST'S MAIN-LOG WIDTHS ARE PROGRAM STATE, so a test that sets
  them takes a copy first and puts it back. The copy is returned EMPTYING the
  store, so the test starts from none. *)
function SaveContestWidths: TColumnWidthStore;
begin
   Result := TColumnWidthStore.Create;
   Result.MergeFrom(ContestColumnWidths);
   ContestColumnWidths.Clear;
end;

procedure RestoreContestWidths(var aSaved: TColumnWidthStore);
begin
   ContestColumnWidths.Clear;
   ContestColumnWidths.MergeFrom(aSaved);
   FreeAndNil(aSaved);
end;

(* A width in the contest's store, as its database's row would put it. *)
procedure SetContestWidth(const aColumn: LogColumnsType; const aWidth96: integer);
begin
   ContestColumnWidths.SetWidth(CONTEST_LOG_COLUMNS_NAME,
                                ColumnCanonicalName[aColumn], aWidth96);
end;

constructor TColumnWidthStoreTests.Create(const AName: string);
begin
   inherited Create(AName);
   FTempFiles := TStringList.Create;
end;

destructor TColumnWidthStoreTests.Destroy;
var
   i: integer;
begin
   for i := 0 to FTempFiles.Count - 1 do
      begin
      DeleteFileIfExists(FTempFiles[i]);
      end;
   FTempFiles.Free;
   inherited Destroy;
end;

procedure InitWidgetSet;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;
end;

(* A string grid on a form, with a header row of captions. Not shown. *)
function MakeGrid(const aForm: TForm; const aCaptions: array of string): TStringGrid;
var
   i: integer;
begin
   Result := TStringGrid.Create(aForm);
   Result.Parent := aForm;
   Result.FixedCols := 0;
   Result.FixedRows := 1;
   Result.ColCount := Length(aCaptions);
   Result.RowCount := 2;
   for i := 0 to High(aCaptions) do
      begin
      Result.Cells[i, 0] := UTF8Encode(aCaptions[i]);
      Result.ColWidths[i] := 40;
      end;
end;

procedure TColumnWidthStoreTests.Test_Store_RoundTripIsKeyedByGridAndToken;
var
   a, b: TColumnWidthStore;
   obj: TJSONObject;
   w: integer;
begin
   BeginTest('Store: a round trip keeps each width under its grid and token');
   a := TColumnWidthStore.Create;
   b := TColumnWidthStore.Create;
   try
      a.SetWidth('MainLog', 'CALLSIGN', 96);
      a.SetWidth('MainLog', 'FREQ', 70);
      a.SetWidth('ExternalLoggers', 'Logger', 210);
      a.SetWidth('mainlog', 'callsign', 99);   (* the same entry, by case *)

      obj := a.ToJSON;
      try
         CheckEquals(2, obj.Count, 'one JSON object per grid, not per spelling');
         b.FromJSON(obj);
      finally
         obj.Free;
      end;

      CheckEquals(3, b.EntryCount, 'three entries came back');
      w := 0;
      CheckTrue(b.TryGetWidth('MainLog', 'CALLSIGN', w), 'MainLog CALLSIGN is there');
      CheckEquals(99, w, 'holding the last width set');
      CheckTrue(b.TryGetWidth('MAINLOG', 'freq', w), 'found whatever the case');
      CheckEquals(70, w, 'FREQ');
      CheckTrue(b.TryGetWidth('ExternalLoggers', 'Logger', w), 'the other grid');
      CheckEquals(210, w, 'its own width');

      w := 1234;
      CheckFalse(b.TryGetWidth('MainLog', 'NAME', w), 'an absent token reports False');
      CheckEquals(1234, w, 'and leaves the caller''s value alone');
      CheckFalse(b.TryGetWidth('NoSuchGrid', 'CALLSIGN', w), 'an absent grid reports False');
   finally
      b.Free;
      a.Free;
   end;
end;

procedure TColumnWidthStoreTests.Test_Store_RefusesBlankNamesAndNonPositiveWidths;
var
   store: TColumnWidthStore;
begin
   BeginTest('Store: a blank name or a width of zero or less is refused');
   store := TColumnWidthStore.Create;
   try
      store.SetWidth('', 'CALLSIGN', 90);
      store.SetWidth('MainLog', ' ', 90);
      store.SetWidth('MainLog', 'CALLSIGN', 0);
      store.SetWidth('MainLog', 'FREQ', -4);
      CheckEquals(0, store.EntryCount, 'nothing was stored');
   finally
      store.Free;
   end;
end;

procedure TColumnWidthStoreTests.Test_Store_DamagedEntriesAreSkippedAndAQuotedNumberReads;
var
   store: TColumnWidthStore;
   value: TJSONValue;
   w: integer;
begin
   BeginTest('Store: a damaged grid or width is skipped; a quoted number reads');
   store := TColumnWidthStore.Create;
   try
      value := TJSONObject.ParseJSONValue(
         '{"G":"oops","H":{"A":"96","B":"wide","C":-5,"D":80}}');
      try
         CheckTrue(value is TJSONObject, 'the fixture parses');
         store.FromJSON(TJSONObject(value));
      finally
         value.Free;
      end;

      CheckEquals(2, store.EntryCount, 'only A and D were taken');
      w := 0;
      CheckTrue(store.TryGetWidth('H', 'A', w), 'the quoted width reads');
      CheckEquals(96, w, 'as its number');
      CheckTrue(store.TryGetWidth('H', 'D', w), 'the plain width reads');
      CheckEquals(80, w, 'as its number');
   finally
      store.Free;
   end;
end;

procedure TColumnWidthStoreTests.Test_File_UnknownGridsAndTokensSurviveASave;
var
   store: TColumnWidthStore;
   fn, text: string;
   w: integer;
begin
   BeginTest('File: a save keeps every grid and token it was not given, and the other sections');
   fn := CombinePath(TempDirectory, 'tr4wcols_' + TGUID.NewGuid.ToString + '.json');
   FTempFiles.Add(fn);
   WriteAllTextUTF8(fn, '{"version": 1, "windows": {"Main": {"left": 1, "top": 2, ' +
                        '"right": 3, "bottom": 4, "visible": true}}}');

   store := TColumnWidthStore.Create;
   try
      CheckFalse(LoadColumnWidths(fn, store), 'no columns section reports False');
      CheckEquals(0, store.EntryCount, 'and leaves the store empty');

      (* A newer build's grid, and a token this build's log does not show. *)
      store.SetWidth('GridFromTheFuture', 'X', 10);
      store.SetWidth('MainLog', 'KIDS', 55);
      SaveColumnWidths(fn, store);

      (* Now save as a build that knows neither. *)
      store.Clear;
      store.SetWidth('MainLog', 'CALLSIGN', 90);
      SaveColumnWidths(fn, store);

      store.Clear;
      CheckTrue(LoadColumnWidths(fn, store), 'the section loads');
      w := 0;
      CheckTrue(store.TryGetWidth('GridFromTheFuture', 'X', w), 'the unknown grid survived');
      CheckEquals(10, w, 'with its width');
      CheckTrue(store.TryGetWidth('MainLog', 'KIDS', w), 'the unknown token survived');
      CheckEquals(55, w, 'with its width');
      CheckTrue(store.TryGetWidth('MainLog', 'CALLSIGN', w), 'and the new one beside them');
      CheckEquals(90, w, 'with its width');

      text := ReadAllTextUTF8(fn);
      CheckTrue(Pos('"version"', text) > 0, 'the version key is still there');
      CheckTrue(Pos('"windows"', text) > 0, 'and the windows section');
   finally
      store.Free;
   end;
end;

procedure TColumnWidthStoreTests.Test_Clamp_NeverNarrowerThanHeaderOrMinimum;
begin
   BeginTest('Clamp: the saved width, but never under the header or the minimum');
   CheckEquals(100, ClampRestoredWidth(100, 50, 8), 'a wide saved width stands');
   CheckEquals(50, ClampRestoredWidth(10, 50, 8), 'a narrow one opens to the header');
   CheckEquals(8, ClampRestoredWidth(3, 0, 8), 'and never under the minimum');
   CheckEquals(150, ClampRestoredWidth(90, 60, 150), 'a column minimum beats the header');
end;

procedure TColumnWidthStoreTests.Test_Grid_ATokenMismatchAndAnUnevenListAreHarmless;
var
   form: TForm;
   grid: TStringGrid;
   store: TColumnWidthStore;
begin
   BeginTest('Grid: a token that matches nothing, and a token list shorter or longer than the grid, touch nothing else');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   store := TColumnWidthStore.Create;
   try
      grid := MakeGrid(form, ['A', 'B', 'C']);
      store.SetWidth('G', 'CALLSIGN', 120);
      store.SetWidth('G', 'B', 90);

      CheckEquals(0, ApplyGridColumnWidths(grid, 'G', ['NAME', 'FREQ', 'OP'], store),
                  'no token matches, so nothing is applied');
      CheckEquals(40, grid.ColWidths[0], 'column 0 untouched');
      CheckEquals(40, grid.ColWidths[1], 'column 1 untouched');

      CheckEquals(0, ApplyGridColumnWidths(grid, 'OtherGrid', ['', 'B'], store),
                  'another grid''s name matches nothing');

      (* SHORTER: only the columns the list names. *)
      CheckEquals(1, ApplyGridColumnWidths(grid, 'G', ['', 'B'], store),
                  'a short list applies the one it has');
      CheckEquals(90, grid.ColWidths[1], 'B took its width');
      CheckEquals(40, grid.ColWidths[2], 'C, past the list, is untouched');

      (* LONGER: tokens past the last column are ignored, not an error. *)
      grid.ColWidths[1] := 40;
      CheckEquals(1, ApplyGridColumnWidths(grid, 'G', ['', 'B', '', 'CALLSIGN', 'X'], store),
                  'a long list applies only what the grid has');
      CheckEquals(90, grid.ColWidths[1], 'B again');

      (* And a capture out of range writes nothing. *)
      store.Clear;
      CaptureGridColumnWidth(grid, 'G', ['', 'B'], 2, store);
      CaptureGridColumnWidth(grid, 'G', ['', 'B'], 7, store);
      CaptureGridColumnWidth(grid, 'G', ['', 'B'], 0, store);
      CheckEquals(0, store.EntryCount, 'no token, no entry');
   finally
      store.Free;
      form.Free;
   end;
end;

procedure TColumnWidthStoreTests.Test_Grid_WidthsAreStoredAt96Dpi;
var
   wide, plain: TForm;
   gridWide, gridPlain, gridAgain: TStringGrid;
   store: TColumnWidthStore;
   w: integer;
begin
   BeginTest('Grid: a width is stored at 96 dpi and scaled back to the form it is restored on');
   InitWidgetSet;
   wide := TForm.CreateNew(nil);
   plain := TForm.CreateNew(nil);
   store := TColumnWidthStore.Create;
   try
      (* A 150% form: 150 of its pixels are 100 at 96 dpi. *)
      wide.PixelsPerInch := 144;
      plain.PixelsPerInch := 96;
      gridWide := MakeGrid(wide, ['A', 'B']);
      gridWide.ColWidths[1] := 150;

      CaptureGridColumnWidth(gridWide, 'G', ['', 'B'], 1, store);
      w := 0;
      CheckTrue(store.TryGetWidth('G', 'B', w), 'the width was captured');
      CheckEquals(100, w, 'stored at 96 dpi');

      gridPlain := MakeGrid(plain, ['A', 'B']);
      ApplyGridColumnWidths(gridPlain, 'G', ['', 'B'], store);
      CheckEquals(100, gridPlain.ColWidths[1], 'restored at 100% as 100');

      gridAgain := MakeGrid(wide, ['A', 'B']);
      ApplyGridColumnWidths(gridAgain, 'G', ['', 'B'], store);
      CheckEquals(150, gridAgain.ColWidths[1], 'restored at 150% as the 150 it was dragged to');
   finally
      store.Free;
      plain.Free;
      wide.Free;
   end;
end;

procedure TColumnWidthStoreTests.Test_Grid_ARestoredWidthIsNoNarrowerThanItsHeader;
var
   form: TForm;
   grid: TStringGrid;
   store: TColumnWidthStore;
   header: integer;
begin
   BeginTest('Grid: a saved width narrower than a (translated, longer) header opens to the header');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   store := TColumnWidthStore.Create;
   try
      (* As if saved under a short English header and read back under a long
        translation of it. *)
      grid := MakeGrid(form, ['A', 'Hintergrundfarbe der Zeile']);
      ShowOffScreen(form);
      header := grid.Canvas.TextWidth(grid.Cells[1, 0]);
      store.SetWidth('G', 'Background', 20);
      ApplyGridColumnWidths(grid, 'G', ['', 'Background'], store);
      CheckTrue(grid.ColWidths[1] >= header,
                Format('the column (%d) is at least its header text (%d)',
                       [grid.ColWidths[1], header]));
   finally
      store.Free;
      form.Free;
   end;
end;

(* THE DEFECT THIS ISSUE OPENED ON. MainUnit.SaveColumnWidthToConfig returned
  before recording a dragged width unless the contest file was a text .cfg, so
  for every .db contest a drag was lost. The grid now keeps it itself. *)
procedure TColumnWidthStoreTests.Test_LogGrid_ADragIsKeptWhateverTheContestFileIs;
const
   GRID_NAME = 'UnitTestLogGrid234';
var
   form: TForm;
   grid, again: TLogGridProbe;
   saved: TColumnEnables;
   oldCfg: string;
   w: integer;
begin
   BeginTest('LogGrid: a dragged width is kept, at 96 dpi, with a .db contest open');
   InitWidgetSet;
   saved := SaveColumnEnables;
   oldCfg := CharBufferText(TR4W_CFG_FILENAME);
   form := TForm.CreateNew(nil);
   try
      ShowOnlyCallsignAndFreq;
      SetCharBuffer(TR4W_CFG_FILENAME, CombinePath(TempDirectory, 'contest234.db'));
      PendingColumnWidths.Clear;

      form.ClientWidth := 600;
      form.ClientHeight := 200;
      grid := TLogGridProbe.Create(form);
      grid.Parent := form;
      grid.Align := alClient;
      grid.LayoutName := GRID_NAME;
      grid.BuildColumns;
      ShowOffScreen(form);

      grid.ColWidths[0] := 137;
      grid.Sized(0);

      w := 0;
      CheckTrue(PendingColumnWidths.TryGetWidth(GRID_NAME, 'CALLSIGN', w),
                'the drag was marked under the grid and the column token');
      CheckEquals(grid.ScaleFormTo96(137), w, 'at 96 dpi');

      grid.SizeColumns;
      CheckEquals(137, grid.ColWidths[0], 'and the grid keeps it when it re-sizes');

      (* A second grid of the same name -- the window reopened before the
        autosave wrote the mark -- comes back with the width. *)
      again := TLogGridProbe.Create(form);
      again.Parent := form;
      again.Align := alBottom;
      again.Height := 60;
      again.LayoutName := GRID_NAME;
      again.BuildColumns;
      Application.ProcessMessages;
      again.SizeColumns;
      (* Through 96 dpi and back, so at most the LCL's own rounding. *)
      CheckEquals(again.Scale96ToForm(grid.ScaleFormTo96(137)), again.ColWidths[0],
                  'a fresh grid restores the width');
   finally
      PendingColumnWidths.Clear;
      SetCharBuffer(TR4W_CFG_FILENAME, oldCfg);
      RestoreColumnEnables(saved);
      form.Free;
   end;
end;

(* EACH GRID READS AND WRITES ONLY ITS OWN HOME (NY4I, 2026-11-06). The main
  log (WidthsPerContest) is the open contest's: it ignores the per-user store,
  and its drag marks nothing for settings\tr4w.json. Every other log grid is
  the user's: it ignores the contest's widths, and its drag is marked. *)
procedure TColumnWidthStoreTests.Test_LogGrid_EachGridReadsOnlyItsOwnHome;
const
   GRID_NAME = 'UnitTestLogGrid234b';
var
   form: TForm;
   perUser, perContest: TLogGridProbe;
   saved: TColumnEnables;
   contestBefore: TColumnWidthStore;
   w: integer;
begin
   BeginTest('LogGrid: the main log reads only the contest''s widths, the others only the user''s');
   InitWidgetSet;
   saved := SaveColumnEnables;
   contestBefore := SaveContestWidths;
   form := TForm.CreateNew(nil);
   try
      ShowOnlyCallsignAndFreq;
      PendingColumnWidths.Clear;

      (* The contest says Freq is 88; the user says Callsign is 140. *)
      SetContestWidth(logColFreq, 88);
      NoteColumnWidth(GRID_NAME, 'CALLSIGN', 140);

      form.ClientWidth := 600;
      form.ClientHeight := 200;
      perUser := TLogGridProbe.Create(form);
      perUser.Parent := form;
      perUser.Align := alTop;
      perUser.Height := 80;
      perUser.LayoutName := GRID_NAME;
      perUser.BuildColumns;

      perContest := TLogGridProbe.Create(form);
      perContest.Parent := form;
      perContest.Align := alClient;
      perContest.LayoutName := GRID_NAME;   (* set, and NOT used *)
      perContest.WidthsPerContest := True;
      perContest.BuildColumns;

      ShowOffScreen(form);
      perUser.SizeColumns;
      perContest.SizeColumns;

      CheckEquals(140, perUser.ColWidths[0], 'the per-user grid has the user''s Callsign');
      CheckTrue(perUser.ColWidths[1] <> 88, 'and not the contest''s Freq');
      CheckEquals(88, perContest.ColWidths[1], 'the main log has the contest''s Freq');
      CheckTrue(perContest.ColWidths[0] <> 140, 'and not the user''s Callsign');

      (* A DRAG ON THE MAIN LOG MARKS NOTHING FOR THE SETTINGS FILE. *)
      PendingColumnWidths.Clear;
      perContest.ColWidths[0] := 133;
      perContest.Sized(0);
      CheckFalse(ColumnWidthsPending, 'the main log''s drag is not pending for tr4w.json');
      w := 0;
      CheckTrue(ContestColumnWidths.TryGetWidth(CONTEST_LOG_COLUMNS_NAME, 'CALLSIGN', w),
                'it is in the contest''s store');
      CheckEquals(133, w, 'at 96 dpi');

      (* AND A DRAG ON ANY OTHER LOG GRID STILL IS. *)
      perUser.ColWidths[1] := 111;
      perUser.Sized(1);
      CheckTrue(PendingColumnWidths.TryGetWidth(GRID_NAME, 'FREQ', w),
                'the per-user grid''s drag is pending for tr4w.json');
      CheckEquals(111, w, 'with its width');
      CheckFalse(ContestColumnWidths.TryGetWidth(CONTEST_LOG_COLUMNS_NAME, 'FREQ', w) and
                 (w = 111), 'and it did not reach the contest''s store');
   finally
      PendingColumnWidths.Clear;
      RestoreContestWidths(contestBefore);
      RestoreColumnEnables(saved);
      form.Free;
   end;
end;

(* THE PRODUCTION PATH, END TO END: a mark, the flush every close and the
  autosave call, and a fresh grid -- a string grid and a TLogGrid -- that has
  only the FILE to read.

  THE SETTINGS FILE IS REDIRECTED FIRST, and the test refuses to flush unless
  TR4WConfigFileName really landed in its own temp folder: a --settings switch
  would win over the redirect, and a flush there would write a real file. *)
procedure TColumnWidthStoreTests.Test_Flush_AMarkReachesTheFileAndAFreshGridReadsIt;
const
   GRID_NAME = 'UnitTestFlush234';
var
   form: TForm;
   grid, fresh: TStringGrid;
   logGrid: TLogGridProbe;
   saved: TColumnEnables;
   oldIni, dir, fn: string;
   store: TColumnWidthStore;
   w: integer;
begin
   BeginTest('Flush: a marked width is written to the settings file and a fresh grid reads it back');
   InitWidgetSet;
   saved := SaveColumnEnables;
   oldIni := CharBufferText(TR4W_INI_FILENAME);
   dir := CombinePath(TempDirectory, 'tr4wcols_' + TGUID.NewGuid.ToString);
   form := TForm.CreateNew(nil);
   store := TColumnWidthStore.Create;
   try
      SetCharBuffer(TR4W_INI_FILENAME, CombinePath(dir, 'tr4w.ini'));
      fn := TR4WConfigFileName;
      if Pos(dir, fn) <> 1 then
         begin
         CheckTrue(False, 'the settings file was not redirected (' + fn +
                          ') -- a --settings switch? The flush half is skipped');
         Exit;
         end;
      FTempFiles.Add(fn);
      PendingColumnWidths.Clear;

      (* A string grid's drag, as its OnHeaderSized marks it. *)
      grid := MakeGrid(form, ['A', 'B']);
      grid.ColWidths[1] := 133;
      SaveGridColumnWidth(grid, GRID_NAME, ['', 'B'], 1);
      CheckTrue(ColumnWidthsPending, 'the drag is pending');

      (* And a log grid's drag, as TLogGrid.HeaderSized marks it. *)
      NoteColumnWidth(GRID_NAME, 'CALLSIGN', 121);

      FlushColumnWidths;
      CheckFalse(ColumnWidthsPending, 'the flush cleared the marks');
      CheckTrue(LoadColumnWidths(fn, store), 'the file has a columns section');
      w := 0;
      CheckTrue(store.TryGetWidth(GRID_NAME, 'B', w), 'holding the string grid''s width');
      CheckEquals(grid.ScaleFormTo96(133), w, 'at 96 dpi');
      CheckTrue(store.TryGetWidth(GRID_NAME, 'CALLSIGN', w), 'and the log grid''s');
      CheckEquals(121, w, 'as marked');

      (* Fresh grids, with nothing pending: only the file can answer. *)
      fresh := MakeGrid(form, ['A', 'B']);
      CheckEquals(1, RestoreGridColumnWidths(fresh, GRID_NAME, ['', 'B']),
                  'the fresh string grid restored one column');
      CheckEquals(fresh.Scale96ToForm(grid.ScaleFormTo96(133)), fresh.ColWidths[1],
                  'at the dragged width');

      ShowOnlyCallsignAndFreq;
      form.ClientWidth := 600;
      form.ClientHeight := 200;
      logGrid := TLogGridProbe.Create(form);
      logGrid.Parent := form;
      logGrid.Align := alBottom;
      logGrid.Height := 80;
      logGrid.LayoutName := GRID_NAME;
      logGrid.BuildColumns;
      ShowOffScreen(form);
      logGrid.SizeColumns;
      CheckEquals(logGrid.Scale96ToForm(121), logGrid.ColWidths[0],
                  'the fresh log grid read its width from the file');
   finally
      PendingColumnWidths.Clear;
      SetCharBuffer(TR4W_INI_FILENAME, oldIni);
      RestoreColumnEnables(saved);
      store.Free;
      form.Free;
      if DirectoryExists(dir) then
         begin
         DeleteFileIfExists(CombinePath(dir, 'tr4w.json'));
         RemoveDir(dir);
         end;
   end;
end;

(* ---------------------------- the main log's widths, in a contest database *)

(* THE TEST'S CONTEST SET-UP for LogStoreApplyContestConfigWith: nothing. The
  widths do not depend on the contest being set up, and a real set-up would
  rewrite program state other suites read. *)
function SetUpNothing(const aContestId: ShortString): boolean;
begin
   Result := True;
end;

function TColumnWidthStoreTests.ContestLogName(const aLeaf: string): string;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_cw234_' +
             IntToStr(GetProcessID) + '_' + aLeaf + '.db';
   ScrubTestLog(Result);
end;

(* WHATEVER AN EARLIER SUITE LEFT OPEN IS CLOSED WITHOUT A CAPTURE first, so
  nothing is written into a file that is not this test's. *)
procedure TColumnWidthStoreTests.StartContestLog(const aDb: string);
begin
   FSavedSilent := tSilentExport;
   FSavedLogName := CharBufferText(TR4W_LOG_FILENAME);
   tSilentExport := True;
   LogStoreClose;
   OpenContestLog(aDb);
end;

(* THE PRODUCTION OPEN of aDb -- the replay startup runs -- after closing the
  log that is open WITH its capture, as the program's exit does. *)
procedure TColumnWidthStoreTests.OpenContestLog(const aDb: string);
begin
   LogStoreClose;
   SetCharBuffer(TR4W_LOG_FILENAME, ChangeFileExt(aDb, '.trw'));
   (* WRITES WANTED: the close capture stands down for a batch run, which is
     what tSilentExport says. *)
   tSilentExport := False;
   LogStoreApplyContestConfigWith(@SetUpNothing);
end;

procedure TColumnWidthStoreTests.StopContestLog;
begin
   tSilentExport := True;
   LogStoreClose;
   SetCharBuffer(TR4W_LOG_FILENAME, FSavedLogName);
   tSilentExport := FSavedSilent;
end;

(* Rows written into a closed log, as an earlier build's capture left them. *)
procedure SeedConfigRows(const aDb: string; const aRows: array of string);
var
   db: TLogDatabase;
   repo: TLogRepository;
   i: integer;
begin
   db := TLogDatabase.Create;
   try
      db.Open(aDb);
      repo := TLogRepository.Create(db);
      try
         for i := 0 to High(aRows) div 2 do
            begin
            repo.SaveConfigValue(AnsiString(aRows[i * 2]), AnsiString(aRows[i * 2 + 1]),
                                 AnsiString('contest'));
            end;
         repo.Commit;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
end;

(* A config row of a closed log, or '' when it has none. *)
function StoredConfigValue(const aDb, aCommand: string): string;
var
   db: TLogDatabase;
   repo: TLogRepository;
   rows: TStringList;
begin
   db := TLogDatabase.Create;
   rows := TStringList.Create;
   try
      db.Open(aDb);
      repo := TLogRepository.Create(db);
      try
         repo.LoadContestConfig(rows);
      finally
         repo.Free;
      end;
      Result := string(rows.Values[AnsiString(aCommand)]);
   finally
      rows.Free;
      db.Free;
   end;
end;

function ContestWidth(const aToken: string): integer;
begin
   Result := 0;
   if not ContestColumnWidths.TryGetWidth(CONTEST_LOG_COLUMNS_NAME, aToken, Result) then
      begin
      Result := 0;
      end;
end;

(* THE DEFECT, REPRODUCED. The rows the two corpus logs hold (arrl_fd_2026,
  cqwpx_cw_2026) are refused at every open -- '"COLUMN WIDTH CALLSIGN" is an
  action, not a setting -- ignored' -- because the replay's renderable guard
  asks the settings object, which owns no COLUMN WIDTH command. Before the fix
  the store stayed empty here. *)
procedure TColumnWidthStoreTests.Test_ContestDb_RejectedRowsAreReadNow;
var
   fn: string;
   contestBefore: TColumnWidthStore;
begin
   BeginTest('ContestDb: the COLUMN WIDTH rows a contest database holds reach the main log''s store');
   contestBefore := SaveContestWidths;
   fn := ContestLogName('replay');
   try
      MakeTestContestLog(fn, ContestHandleOf(CQWPXCW), '');
      SeedConfigRows(fn, ['COLUMN WIDTH DATE', '99', 'COLUMN WIDTH CALLSIGN', '109',
                          'COLUMN WIDTH FREQ', '95']);
      StartContestLog(fn);
      CheckTrue(LogStoreIsUsable, 'the store opened the log');
      CheckEquals(99,  ContestWidth('DATE'), 'DATE came back');
      CheckEquals(109, ContestWidth('CALLSIGN'), 'CALLSIGN came back');
      CheckEquals(95,  ContestWidth('FREQ'), 'FREQ came back');
   finally
      StopContestLog;
      ScrubTestLog(fn);
      RestoreContestWidths(contestBefore);
   end;
end;

(* A DRAG ON THE MAIN LOG, INTO THE DATABASE AND BACK: the store's close
  capture writes it, the next open reads it, a fresh main-log grid shows it --
  and the settings file is never told. *)
procedure TColumnWidthStoreTests.Test_ContestDb_ADragRoundTripsThroughTheDatabase;
var
   fn: string;
   form: TForm;
   grid, fresh: TLogGridProbe;
   saved: TColumnEnables;
   contestBefore: TColumnWidthStore;
begin
   BeginTest('ContestDb: a main-log drag is written into the contest database and read back on its next open');
   InitWidgetSet;
   saved := SaveColumnEnables;
   contestBefore := SaveContestWidths;
   fn := ContestLogName('roundtrip');
   form := TForm.CreateNew(nil);
   try
      ShowOnlyCallsignAndFreq;
      PendingColumnWidths.Clear;
      MakeTestContestLog(fn, ContestHandleOf(CQWPXCW), '');
      StartContestLog(fn);
      CheckTrue(LogStoreIsUsable, 'the store opened the log');
      CheckEquals(0, ContestColumnWidths.EntryCount, 'a new log has no widths');

      form.ClientWidth := 600;
      form.ClientHeight := 200;
      grid := TLogGridProbe.Create(form);
      grid.Parent := form;
      grid.Align := alClient;
      grid.WidthsPerContest := True;
      grid.BuildColumns;
      ShowOffScreen(form);

      grid.ColWidths[0] := 137;
      grid.Sized(0);
      CheckFalse(ColumnWidthsPending, 'nothing is pending for settings\tr4w.json');
      FreeAndNil(grid);

      (* THE CLOSE, capture and all -- what the exit and an Open Log relaunch
        run -- and the store is emptied with the log. *)
      LogStoreClose;
      CheckEquals(0, ContestColumnWidths.EntryCount, 'the closed log''s widths went with it');
      CheckEquals('137', StoredConfigValue(fn, 'COLUMN WIDTH CALLSIGN'),
                  'the database holds the dragged width, at 96 dpi');
      CheckEquals('', StoredConfigValue(fn, 'COLUMN WIDTH FREQ'),
                  'and no row for a column nobody dragged');

      (* THE NEXT RUN. *)
      OpenContestLog(fn);
      CheckEquals(137, ContestWidth('CALLSIGN'), 'the open read it back');
      fresh := TLogGridProbe.Create(form);
      fresh.Parent := form;
      fresh.Align := alClient;
      fresh.WidthsPerContest := True;
      fresh.BuildColumns;
      Application.ProcessMessages;
      fresh.SizeColumns;
      CheckEquals(137, fresh.ColWidths[0], 'a fresh main-log grid opens at the dragged width');
   finally
      StopContestLog;
      ScrubTestLog(fn);
      PendingColumnWidths.Clear;
      RestoreContestWidths(contestBefore);
      RestoreColumnEnables(saved);
      form.Free;
   end;
end;

(* TWO CONTESTS, DIFFERENT COLUMNS, ONE PROCESS: each open has only its own
  log's widths, and a width one contest holds for a column the other does
  not show leaks nowhere. *)
procedure TColumnWidthStoreTests.Test_ContestDb_TwoContestsKeepTheirOwnWidths;
var
   fnA, fnB: string;
   contestBefore: TColumnWidthStore;
begin
   BeginTest('ContestDb: two contests opened in turn each have only their own log''s widths');
   contestBefore := SaveContestWidths;
   fnA := ContestLogName('contestA');
   fnB := ContestLogName('contestB');
   try
      MakeTestContestLog(fnA, ContestHandleOf(CQWPXCW), '');
      MakeTestContestLog(fnB, ContestHandleOf(ARRLDXCW), '');
      (* A shows a serial number, B a power: tokens of different column sets. *)
      SeedConfigRows(fnA, ['COLUMN WIDTH CALLSIGN', '120', 'COLUMN WIDTH QSR', '61']);
      SeedConfigRows(fnB, ['COLUMN WIDTH FREQ', '88', 'COLUMN WIDTH PWR', '44']);

      StartContestLog(fnA);
      CheckEquals(120, ContestWidth('CALLSIGN'), 'A: its Callsign');
      CheckEquals(0, ContestWidth('FREQ'), 'A: none of B''s Freq');

      OpenContestLog(fnB);
      CheckEquals(88, ContestWidth('FREQ'), 'B: its Freq');
      CheckEquals(0, ContestWidth('CALLSIGN'), 'B: none of A''s Callsign');
      CheckEquals(2, ContestColumnWidths.EntryCount, 'B: exactly its own two rows');

      (* B's close writes B's widths into B, and A is untouched. *)
      LogStoreClose;
      CheckEquals('', StoredConfigValue(fnB, 'COLUMN WIDTH CALLSIGN'),
                  'A''s width was not written into B');
      CheckEquals('', StoredConfigValue(fnA, 'COLUMN WIDTH FREQ'),
                  'and B''s not into A');
   finally
      StopContestLog;
      ScrubTestLog(fnA);
      ScrubTestLog(fnB);
      RestoreContestWidths(contestBefore);
   end;
end;

(* WHAT AN OLDER BUILD OR A HAND EDIT CAN LEAVE: a token no column has (a
  newer build's column -- kept and written back), a September row that held a
  character count rather than pixels (opens at least as wide as its header),
  and values that are not widths (refused, and the grid keeps its default). *)
procedure TColumnWidthStoreTests.Test_ContestDb_OldAndOddRowsAreHarmless;
var
   fn: string;
   form: TForm;
   grid: TLogGridProbe;
   saved: TColumnEnables;
   contestBefore: TColumnWidthStore;
   header: integer;
begin
   BeginTest('ContestDb: an unknown token survives, a tiny legacy width opens to its header, a non-width is refused');
   InitWidgetSet;
   saved := SaveColumnEnables;
   contestBefore := SaveContestWidths;
   fn := ContestLogName('oddrows');
   form := TForm.CreateNew(nil);
   try
      ShowOnlyCallsignAndFreq;
      MakeTestContestLog(fn, ContestHandleOf(CQWPXCW), '');
      SeedConfigRows(fn, ['COLUMN WIDTH BOGUS', '50',
                          'COLUMN WIDTH CALLSIGN', '9',
                          'COLUMN WIDTH FREQ', 'wide',
                          'COLUMN WIDTH DATE', '0']);
      StartContestLog(fn);
      CheckEquals(50, ContestWidth('BOGUS'), 'the unknown token is kept');
      CheckEquals(9, ContestWidth('CALLSIGN'), 'the legacy count is read as it is');
      CheckEquals(0, ContestWidth('FREQ'), 'a word is not a width');
      CheckEquals(0, ContestWidth('DATE'), 'nor is zero');

      form.ClientWidth := 600;
      form.ClientHeight := 200;
      grid := TLogGridProbe.Create(form);
      grid.Parent := form;
      grid.Align := alClient;
      grid.WidthsPerContest := True;
      grid.BuildColumns;
      ShowOffScreen(form);
      grid.SizeColumns;
      grid.Canvas.Font.Assign(grid.Font);
      header := grid.Canvas.TextWidth(LclText(ColumnsArray[logColCallsign].Text));
      CheckTrue(grid.ColWidths[0] >= header,
                Format('Callsign (%d) is at least its header (%d), not 9 px',
                       [grid.ColWidths[0], header]));
      CheckTrue(grid.ColWidths[1] > 8, 'Freq keeps a readable default');

      (* The close writes the unknown token back, so a newer build's column
        survives this build. *)
      FreeAndNil(grid);
      LogStoreClose;
      CheckEquals('50', StoredConfigValue(fn, 'COLUMN WIDTH BOGUS'),
                  'the unknown token survived the capture');
   finally
      StopContestLog;
      ScrubTestLog(fn);
      RestoreContestWidths(contestBefore);
      RestoreColumnEnables(saved);
      form.Free;
   end;
end;

(* A LOG GRID ALWAYS FILLS ITS CLIENT WIDTH (NY4I's bench, 2026-11-06: the
  main log ended short of the right edge, a white band beside Op).

  Eight columns of a main-log grid (WidthsPerContest), the chosen widths
  given through the contest's store -- the main log is where the band was
  seen. The fill arithmetic does not know which home a width came from. *)
const
   FILL_COLUMNS: array[0 .. 7] of LogColumnsType =
      (logColBand, logColDate, logColTime, logColNumberSent,
       logColCallsign, logColDXMult, logColQTH, logColPoints);

procedure ShowOnlyFillColumns;
var
   c: LogColumnsType;
   i: integer;
begin
   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      ColumnsArray[c].Enable := False;
      end;
   for i := Low(FILL_COLUMNS) to High(FILL_COLUMNS) do
      begin
      ColumnsArray[FILL_COLUMNS[i]].Enable := True;
      end;
end;

function SumOfColumnWidths(const aGrid: TLogGrid): integer;
var
   i: integer;
begin
   Result := 0;
   for i := 0 to aGrid.ColCount - 1 do
      begin
      Inc(Result, aGrid.ColWidths[i]);
      end;
end;

(* A fit-and-fill log grid filling a shown form of the given client width. *)
function MakeFillGrid(const aForm: TForm; const aWidth: integer): TLogGridProbe;
begin
   aForm.ClientWidth := aWidth;
   aForm.ClientHeight := 200;
   Result := TLogGridProbe.Create(aForm);
   Result.Parent := aForm;
   Result.Align := alClient;
   Result.Sizing := lgsFitAndFill;
   Result.WidthsPerContest := True;
   Result.BuildColumns;
   ShowOffScreen(aForm);
end;

(* Resize the form and let the grid re-size itself, as an operator would. *)
procedure ResizeFillForm(const aForm: TForm; const aWidth: integer);
begin
   aForm.ClientWidth := aWidth;
   Application.ProcessMessages;
end;

procedure TColumnWidthStoreTests.CheckFills(const aGrid: TObject; const aWhat: string);
begin
   CheckEquals(TLogGrid(aGrid).ClientWidth, SumOfColumnWidths(TLogGrid(aGrid)),
               aWhat + ': the columns fill the client width');
end;

procedure TColumnWidthStoreTests.Test_LogGridFill_NoWidthsOverridden;
var
   form: TForm;
   grid: TLogGridProbe;
   saved: TColumnEnables;
   contestBefore: TColumnWidthStore;
begin
   BeginTest('LogGridFill: with no width overridden the columns fill the grid at two widths');
   InitWidgetSet;
   saved := SaveColumnEnables;
   contestBefore := SaveContestWidths;
   form := TForm.CreateNew(nil);
   try
      ShowOnlyFillColumns;
      grid := MakeFillGrid(form, 900);
      CheckFills(grid, 'at 900');
      ResizeFillForm(form, 1200);
      CheckFills(grid, 'at 1200');
   finally
      RestoreContestWidths(contestBefore);
      RestoreColumnEnables(saved);
      form.Free;
   end;
end;

procedure TColumnWidthStoreTests.Test_LogGridFill_SomeWidthsOverridden;
var
   form: TForm;
   grid: TLogGridProbe;
   saved: TColumnEnables;
   contestBefore: TColumnWidthStore;
begin
   BeginTest('LogGridFill: with some widths overridden they are kept and the rest fill the grid');
   InitWidgetSet;
   saved := SaveColumnEnables;
   contestBefore := SaveContestWidths;
   form := TForm.CreateNew(nil);
   try
      ShowOnlyFillColumns;
      SetContestWidth(logColDate, 90);
      SetContestWidth(logColCallsign, 110);
      grid := MakeFillGrid(form, 900);
      CheckFills(grid, 'at 900');
      CheckEquals(90, grid.ColWidths[1], 'Date keeps its width');
      CheckEquals(110, grid.ColWidths[4], 'Callsign keeps its width');
      ResizeFillForm(form, 1200);
      CheckFills(grid, 'at 1200');
      CheckEquals(90, grid.ColWidths[1], 'Date still keeps its width');
      CheckEquals(110, grid.ColWidths[4], 'Callsign still keeps its width');
   finally
      RestoreContestWidths(contestBefore);
      RestoreColumnEnables(saved);
      form.Free;
   end;
end;

(* THE CASE THAT LEFT THE BAND: nothing free to take the surplus. *)
procedure TColumnWidthStoreTests.Test_LogGridFill_EveryWidthOverridden;
var
   form: TForm;
   grid: TLogGridProbe;
   saved: TColumnEnables;
   contestBefore: TColumnWidthStore;
   i: integer;
begin
   BeginTest('LogGridFill: with every width overridden the last column takes the slack');
   InitWidgetSet;
   saved := SaveColumnEnables;
   contestBefore := SaveContestWidths;
   form := TForm.CreateNew(nil);
   try
      ShowOnlyFillColumns;
      for i := Low(FILL_COLUMNS) to High(FILL_COLUMNS) do
         begin
         SetContestWidth(FILL_COLUMNS[i], 60);
         end;
      grid := MakeFillGrid(form, 900);
      CheckFills(grid, 'at 900');
      for i := 0 to grid.ColCount - 2 do
         begin
         CheckEquals(60, grid.ColWidths[i],
                     Format('column %d keeps its width', [i]));
         end;
      CheckTrue(grid.ColWidths[grid.ColCount - 1] > 60, 'the last column grew');
      ResizeFillForm(form, 1200);
      CheckFills(grid, 'at 1200');
      CheckEquals(60, grid.ColWidths[0], 'the first column still keeps its width');
   finally
      RestoreContestWidths(contestBefore);
      RestoreColumnEnables(saved);
      form.Free;
   end;
end;

procedure TColumnWidthStoreTests.Test_LogGridFill_AfterADragAndAResize;
var
   form: TForm;
   grid: TLogGridProbe;
   saved: TColumnEnables;
   contestBefore: TColumnWidthStore;
   dragged: integer;
begin
   BeginTest('LogGridFill: a dragged column keeps its width and the grid still fills, before and after a resize');
   InitWidgetSet;
   saved := SaveColumnEnables;
   contestBefore := SaveContestWidths;
   form := TForm.CreateNew(nil);
   try
      ShowOnlyFillColumns;
      grid := MakeFillGrid(form, 900);
      dragged := grid.ColWidths[4] - 30;
      grid.ColWidths[4] := dragged;
      grid.Sized(4);
      CheckEquals(dragged, grid.ColWidths[4], 'the drag stands');
      CheckFills(grid, 'after the drag');
      ResizeFillForm(form, 1200);
      CheckEquals(dragged, grid.ColWidths[4], 'the drag survives a resize');
      CheckFills(grid, 'after the resize');
   finally
      RestoreContestWidths(contestBefore);
      RestoreColumnEnables(saved);
      form.Free;
   end;
end;

procedure TColumnWidthStoreTests.RunAllTests;
begin
   Test_Store_RoundTripIsKeyedByGridAndToken;
   Test_Store_RefusesBlankNamesAndNonPositiveWidths;
   Test_Store_DamagedEntriesAreSkippedAndAQuotedNumberReads;
   Test_File_UnknownGridsAndTokensSurviveASave;
   Test_Clamp_NeverNarrowerThanHeaderOrMinimum;
   Test_Grid_ATokenMismatchAndAnUnevenListAreHarmless;
   Test_Grid_WidthsAreStoredAt96Dpi;
   Test_Grid_ARestoredWidthIsNoNarrowerThanItsHeader;
   Test_LogGrid_ADragIsKeptWhateverTheContestFileIs;
   Test_LogGrid_EachGridReadsOnlyItsOwnHome;
   Test_Flush_AMarkReachesTheFileAndAFreshGridReadsIt;
   Test_ContestDb_RejectedRowsAreReadNow;
   Test_ContestDb_ADragRoundTripsThroughTheDatabase;
   Test_ContestDb_TwoContestsKeepTheirOwnWidths;
   Test_ContestDb_OldAndOddRowsAreHarmless;
   Test_LogGridFill_NoWidthsOverridden;
   Test_LogGridFill_SomeWidthsOverridden;
   Test_LogGridFill_EveryWidthOverridden;
   Test_LogGridFill_AfterADragAndAResize;
end;

end.
