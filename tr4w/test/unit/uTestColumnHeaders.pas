unit uTestColumnHeaders;
{$I ..\..\src\tr4w.inc}

(*
  NO COLUMN HEADER (issue 352): uColumnHeaders and TLogGrid.ShowHeader.

  The setting was saved and read by nothing. It now hides the heading row of
  every TLogGrid (D7's CreateEditableLog windows) and of the Network and
  Stations list views (D7's CreateListView windows).

  THE TRAP THESE PIN is the row arithmetic. The heading is TLogGrid's one
  fixed row, and a record is row - FixedRows; a grid that hid the header but
  still counted 1 + records, or that flipped FixedRows in the wrong order on an
  empty log (the LCL refuses FixedRows > RowCount), would shift every QSO by a
  row or raise. Real controls, on a form that is never shown: no handle is
  needed to read FixedRows, RowCount, Row or ShowColumnHeaders.

  Every test puts Settings.MainWindow.NoColumnHeader back as it found it.
*)

interface

uses
   uTR4WTestFramework;

type
   TColumnHeaderTests = class(TTestCase)
   protected
      procedure Test_LogGrid_HidingTheHeaderShiftsNoRecord;
      procedure Test_LogGrid_AnEmptyLogTogglesBothWays;
      procedure Test_LogGrid_ANewGridReadsTheSetting;
      procedure Test_ListView_FollowsTheSetting;
      procedure Test_OpenWindows_ReachesAGridOnAnOpenForm;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Forms, ComCtrls,
   uSettingsModel, uLogGrid, uColumnHeaders;

procedure InitWidgetSet;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;
end;

function NewGrid(const aForm: TForm): TLogGrid;
begin
   Result := TLogGrid.Create(aForm);
   Result.Parent := aForm;
end;

procedure SetHidden(const aHidden: boolean);
begin
   Settings.MainWindow.NoColumnHeader := aHidden;
end;

procedure TColumnHeaderTests.Test_LogGrid_HidingTheHeaderShiftsNoRecord;
var
   before: boolean;
   form:   TForm;
   grid:   TLogGrid;
begin
   BeginTest('LogGrid: hiding the heading row moves no record and keeps the selection');
   InitWidgetSet;
   before := Settings.MainWindow.NoColumnHeader;
   form := TForm.CreateNew(nil);
   try
      SetHidden(False);
      grid := NewGrid(form);
      grid.RecordCount := 3;
      CheckEquals(1, grid.FixedRows, 'shown: one fixed row');
      CheckEquals(4, grid.RowCount, 'shown: the header plus three records');

      grid.SelectedRecord := 1;
      CheckEquals(2, grid.Row, 'shown: record 1 is row 2');

      SetHidden(True);
      ApplyColumnHeaders(grid);
      CheckFalse(grid.ShowHeader, 'hidden: ShowHeader reads False');
      CheckEquals(0, grid.FixedRows, 'hidden: no fixed row');
      CheckEquals(3, grid.RowCount, 'hidden: three rows for three records');
      CheckEquals(1, integer(grid.SelectedRecord), 'hidden: the selection stayed on record 1');
      CheckEquals(1, grid.Row, 'hidden: record 1 is row 1');

      grid.SelectedRecord := 0;
      CheckEquals(0, grid.Row, 'hidden: record 0 is row 0');
      CheckEquals(0, integer(grid.SelectedRecord), 'hidden: row 0 reads back as record 0');

      grid.RecordCount := 5;
      CheckEquals(5, grid.RowCount, 'hidden: a new record count adds no header row');

      SetHidden(False);
      ApplyColumnHeaders(grid);
      CheckTrue(grid.ShowHeader, 'shown again: ShowHeader reads True');
      CheckEquals(1, grid.FixedRows, 'shown again: one fixed row');
      CheckEquals(6, grid.RowCount, 'shown again: the header plus five records');
      CheckEquals(0, integer(grid.SelectedRecord), 'shown again: the selection stayed on record 0');
   finally
      SetHidden(before);
      form.Free;
   end;
end;

procedure TColumnHeaderTests.Test_LogGrid_AnEmptyLogTogglesBothWays;
var
   before: boolean;
   form:   TForm;
   grid:   TLogGrid;
   raised: string;
begin
   BeginTest('LogGrid: an empty log hides and shows its heading without an exception');
   InitWidgetSet;
   before := Settings.MainWindow.NoColumnHeader;
   form := TForm.CreateNew(nil);
   raised := '';
   try
      try
         SetHidden(False);
         grid := NewGrid(form);
         grid.RecordCount := 0;

         grid.ShowHeader := False;
         CheckEquals(0, grid.FixedRows, 'hidden: no fixed row');
         CheckEquals(0, grid.RowCount, 'hidden: an empty log has no rows');
         CheckEquals(-1, integer(grid.SelectedRecord), 'hidden: nothing selected');

         (* The order that matters: FixedRows := 1 against RowCount 0 raises. *)
         grid.ShowHeader := True;
         CheckEquals(1, grid.FixedRows, 'shown: one fixed row');
         CheckEquals(1, grid.RowCount, 'shown: the header row only');
      except
         on e: Exception do
            begin
            raised := e.ClassName + ': ' + e.Message;
            end;
      end;
      CheckEquals('', raised, 'toggling an empty log raised nothing');
   finally
      SetHidden(before);
      form.Free;
   end;
end;

procedure TColumnHeaderTests.Test_LogGrid_ANewGridReadsTheSetting;
var
   before: boolean;
   form:   TForm;
   grid:   TLogGrid;
begin
   BeginTest('LogGrid: a grid built while the setting is on has no heading row from the start');
   InitWidgetSet;
   before := Settings.MainWindow.NoColumnHeader;
   form := TForm.CreateNew(nil);
   try
      SetHidden(True);
      grid := NewGrid(form);
      CheckFalse(grid.ShowHeader, 'a new grid read the setting');
      grid.RecordCount := 2;
      CheckEquals(2, grid.RowCount, 'two records, no header row');

      SetHidden(False);
      grid := NewGrid(form);
      CheckTrue(grid.ShowHeader, 'a new grid with the setting off has its header');
   finally
      SetHidden(before);
      form.Free;
   end;
end;

procedure TColumnHeaderTests.Test_ListView_FollowsTheSetting;
var
   before: boolean;
   list:   TListView;
begin
   BeginTest('ListView: ShowColumnHeaders follows NO COLUMN HEADER both ways');
   InitWidgetSet;
   before := Settings.MainWindow.NoColumnHeader;
   list := TListView.Create(nil);
   try
      list.ViewStyle := vsReport;

      SetHidden(True);
      ApplyColumnHeaders(list);
      CheckFalse(list.ShowColumnHeaders, 'on: the headings are hidden');

      SetHidden(False);
      ApplyColumnHeaders(list);
      CheckTrue(list.ShowColumnHeaders, 'off: the headings are shown');
   finally
      SetHidden(before);
      list.Free;
   end;
end;

procedure TColumnHeaderTests.Test_OpenWindows_ReachesAGridOnAnOpenForm;
var
   before: boolean;
   form:   TForm;
   grid:   TLogGrid;
begin
   BeginTest('OpenWindows: the live re-apply reaches a TLogGrid on any form');
   InitWidgetSet;
   before := Settings.MainWindow.NoColumnHeader;
   form := TForm.CreateNew(nil);
   try
      SetHidden(False);
      grid := NewGrid(form);
      grid.RecordCount := 4;

      SetHidden(True);
      ApplyColumnHeadersToOpenWindows;
      CheckFalse(grid.ShowHeader, 'on: the open grid lost its heading');
      CheckEquals(4, grid.RowCount, 'on: four rows for four records');

      SetHidden(False);
      ApplyColumnHeadersToOpenWindows;
      CheckTrue(grid.ShowHeader, 'off: the open grid has its heading back');
      CheckEquals(5, grid.RowCount, 'off: the header plus four records');
   finally
      SetHidden(before);
      ApplyColumnHeadersToOpenWindows;
      form.Free;
   end;
end;

procedure TColumnHeaderTests.RunAllTests;
begin
   Test_LogGrid_HidingTheHeaderShiftsNoRecord;
   Test_LogGrid_AnEmptyLogTogglesBothWays;
   Test_LogGrid_ANewGridReadsTheSetting;
   Test_ListView_FollowsTheSetting;
   Test_OpenWindows_ReachesAGridOnAnOpenForm;
end;

end.
