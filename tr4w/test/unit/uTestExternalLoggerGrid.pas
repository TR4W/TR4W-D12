unit uTestExternalLoggerGrid;
{$I ..\..\src\tr4w.inc}

(*
  PREFERENCES > EXTERNAL LOGGER: THE GRID IS THE EDITOR (issue 220).

  Two layers, both without a mouse:

  - the model (TExternalLoggerConfig): display order, activation, reorder
    write-back, removal. This is where the delivery order lives, so it is
    pinned directly.
  - the grid (TExternalLoggerGrid) on a bare TStringGrid in a form that is
    streamed and never shown. A drag is the grid's own MoveColRow -- the call
    the LCL makes at mouse-up -- so OnColRowMoved runs exactly as it does for
    a real drag.

  NOT covered here, and bench-only (docs/BENCH_QUEUE.md): the real mouse drag
  from the Order cell, the right-click popup, and the modal editor.
  TPrefsForm itself is not constructed by any test; the page is covered by the
  form lints.
*)

interface

uses
   uTR4WTestFramework;

type
   TExternalLoggerGridTests = class(TTestCase)
   protected
      procedure Test_Model_DisplayOrderIsActiveFirst;
      procedure Test_Model_SetActiveAppendsAndIsIdempotent;
      procedure Test_Model_ApplyOrderWritesBackDeliveryOrder;
      procedure Test_Model_RemoveLeavesTheOthers;
      procedure Test_Model_NewNameIsUnique;
      procedure Test_Grid_RowsShowOrderAndSend;
      procedure Test_Grid_AnEmptyLibraryShowsAPlaceholder;
      procedure Test_Grid_DragWritesTheNewOrderBack;
      procedure Test_Grid_DropAcrossTheActiveLineSnapsBack;
      procedure Test_Grid_MoveSelectedStaysInItsGroup;
      procedure Test_Grid_ToggleSendAndRemove;
      procedure Test_Grid_EditsOnACopyLeaveTheOriginal;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, Forms, Grids, uExternalLoggerConfig, uExternalLoggerGrid;

type
   TChangeCounter = class
   public
      Count: integer;
      procedure Changed(aSender: TObject);
   end;

procedure TChangeCounter.Changed(aSender: TObject);
begin
   Inc(Count);
end;

procedure InitWidgetSet;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;
end;

(* Three DXKeeper definitions on distinct ports (so the shared-destination
   question never opens a dialog in a test). a and b are active, in that
   order; c is not. *)
procedure FillConfig(const aConfig: TExternalLoggerConfig);
var
   i: integer;
   definition: TExternalLoggerDefinition;
begin
   aConfig.Clear;
   aConfig.Present := True;
   for i := 0 to 2 do
      begin
      definition := TExternalLoggerDefinition.Create;
      definition.Id := string(Chr(Ord('a') + i));
      definition.Name := 'Logger ' + string(Chr(Ord('A') + i));
      definition.ProviderId := 'DXKEEPER';
      definition.Address := '127.0.0.1';
      definition.Port := 52001 + i;
      aConfig.Definitions.Add(definition);
      end;
   aConfig.ActiveIds.Add('a');
   aConfig.ActiveIds.Add('b');
end;

function ActiveText(const aConfig: TExternalLoggerConfig): string;
var
   id: AnsiString;
begin
   Result := '';
   for id in aConfig.ActiveIds do
      begin
      Result := Result + string(id);
      end;
end;

function DefinitionText(const aConfig: TExternalLoggerConfig): string;
var
   definition: TExternalLoggerDefinition;
begin
   Result := '';
   for definition in aConfig.Definitions do
      begin
      Result := Result + definition.Id;
      end;
end;

(* The ids the grid holds, top to bottom. *)
function GridIds(const aGrid: TStringGrid): string;
var
   row: integer;
begin
   Result := '';
   for row := aGrid.FixedRows to aGrid.RowCount - 1 do
      begin
      Result := Result + string(aGrid.Cells[LOGGER_COL_ID, row]);
      end;
end;

function GridOrders(const aGrid: TStringGrid): string;
var
   row: integer;
begin
   Result := '';
   for row := aGrid.FixedRows to aGrid.RowCount - 1 do
      begin
      Result := Result + string(aGrid.Cells[LOGGER_COL_ORDER, row]);
      end;
end;

(* ----------------------------------------------------------------------- *)
(* The model                                                               *)
(* ----------------------------------------------------------------------- *)

procedure TExternalLoggerGridTests.Test_Model_DisplayOrderIsActiveFirst;
var
   config: TExternalLoggerConfig;
   ids: TStringList;
begin
   BeginTest('Model: active loggers show first in delivery order, then the rest');
   config := TExternalLoggerConfig.Create;
   ids := TStringList.Create;
   try
      FillConfig(config);
      config.ActiveIds.Clear;
      config.ActiveIds.Add('c');
      config.ActiveIds.Add('a');
      config.DisplayOrder(ids);
      CheckEquals('cab', string(ids[0]) + string(ids[1]) + string(ids[2]), 'c, a, then inactive b');
      CheckEquals(1, config.ActivePosition('c'), 'first to send');
      CheckEquals(2, config.ActivePosition('a'), 'second to send');
      CheckEquals(0, config.ActivePosition('b'), 'inactive has no position');
   finally
      ids.Free;
      config.Free;
   end;
end;

procedure TExternalLoggerGridTests.Test_Model_SetActiveAppendsAndIsIdempotent;
var
   config: TExternalLoggerConfig;
begin
   BeginTest('Model: activating appends to the delivery order and keeps an existing place');
   config := TExternalLoggerConfig.Create;
   try
      FillConfig(config);
      config.SetActive('c', True);
      CheckEquals('abc', ActiveText(config), 'appended last');
      config.SetActive('a', True);
      CheckEquals('abc', ActiveText(config), 'already active: not moved to the end');
      config.SetActive('a', False);
      CheckEquals('bc', ActiveText(config), 'deactivated');
      config.SetActive('nobody', True);
      CheckEquals('bc', ActiveText(config), 'an unknown id is ignored');
   finally
      config.Free;
   end;
end;

procedure TExternalLoggerGridTests.Test_Model_ApplyOrderWritesBackDeliveryOrder;
var
   config: TExternalLoggerConfig;
   ids: TStringList;
begin
   BeginTest('Model: a new view order becomes the definition order and the delivery order');
   config := TExternalLoggerConfig.Create;
   ids := TStringList.Create;
   try
      FillConfig(config);
      ids.Add('a');
      ids.Add('b');
      ids.Add('c');
      CheckFalse(config.ApplyOrder(ids), 'the same order changes nothing');
      ids.Clear;
      ids.Add('c');
      ids.Add('b');
      ids.Add('a');
      CheckTrue(config.ApplyOrder(ids), 'reported as changed');
      CheckEquals('cba', DefinitionText(config), 'definitions follow the view');
      CheckEquals('ba', ActiveText(config), 'delivery order is the active subset in view order');
      CheckEquals('Logger C', config.Find('c').Name, 'the objects survived the reorder');
      ids.Clear;
      ids.Add('a');
      CheckTrue(config.ApplyOrder(ids), 'a partial view');
      CheckEquals('acb', DefinitionText(config), 'unnamed ids follow, in their old order');
   finally
      ids.Free;
      config.Free;
   end;
end;

procedure TExternalLoggerGridTests.Test_Model_RemoveLeavesTheOthers;
var
   config: TExternalLoggerConfig;
begin
   BeginTest('Model: removing a definition drops it from both lists and touches nothing else');
   config := TExternalLoggerConfig.Create;
   try
      FillConfig(config);
      config.RemoveDefinition('a');
      CheckEquals('bc', DefinitionText(config));
      CheckEquals('b', ActiveText(config));
      config.RemoveDefinition('nobody');
      CheckEquals('bc', DefinitionText(config), 'an unknown id is ignored');
   finally
      config.Free;
   end;
end;

procedure TExternalLoggerGridTests.Test_Model_NewNameIsUnique;
var
   config: TExternalLoggerConfig;
begin
   BeginTest('Model: a new definition name never collides with an existing one');
   config := TExternalLoggerConfig.Create;
   try
      FillConfig(config);
      config.Find('a').Name := 'Logger 4';
      CheckEquals('Logger 5', config.NewDefinitionName, 'Logger 4 is taken');
      config.Find('b').Name := 'logger 5';
      CheckEquals('Logger 6', config.NewDefinitionName, 'compared without case');
   finally
      config.Free;
   end;
end;

(* ----------------------------------------------------------------------- *)
(* The grid                                                                *)
(* ----------------------------------------------------------------------- *)

procedure TExternalLoggerGridTests.Test_Grid_RowsShowOrderAndSend;
var
   form: TForm;
   grid: TStringGrid;
   view: TExternalLoggerGrid;
   config: TExternalLoggerConfig;
begin
   BeginTest('Grid: Order shows the delivery position for active loggers and a dash for the rest');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   config := TExternalLoggerConfig.Create;
   try
      grid := TStringGrid.Create(form);
      grid.Parent := form;
      view := TExternalLoggerGrid.Create(form, grid);
      FillConfig(config);
      view.Bind(config);
      view.Refresh;
      CheckEquals(4, grid.RowCount, 'header and three loggers');
      CheckEquals('abc', GridIds(grid));
      CheckEquals('12-', GridOrders(grid), 'a=1 b=2 c=inactive');
      CheckEquals('Yes', string(grid.Cells[LOGGER_COL_SEND, 1]));
      CheckEquals('Yes', string(grid.Cells[LOGGER_COL_SEND, 2]));
      CheckEquals('No', string(grid.Cells[LOGGER_COL_SEND, 3]));
      CheckEquals('Logger C', string(grid.Cells[LOGGER_COL_NAME, 3]));
      CheckEquals('DXKEEPER', string(grid.Cells[LOGGER_COL_PROVIDER, 3]));
      CheckEquals(1, grid.FixedCols, 'the Order column is the fixed column a row drag starts from');
      CheckTrue(goRowMoving in grid.Options, 'the LCL moves rows itself');
      CheckEquals(0, grid.ColWidths[LOGGER_COL_ID], 'the id column is hidden');
      config.ActiveIds.Clear;
      view.Refresh;
      CheckEquals('---', GridOrders(grid), 'with no active ids every Order is a dash');
   finally
      config.Free;
      form.Free;
   end;
end;

procedure TExternalLoggerGridTests.Test_Grid_AnEmptyLibraryShowsAPlaceholder;
var
   form: TForm;
   grid: TStringGrid;
   view: TExternalLoggerGrid;
   config: TExternalLoggerConfig;
   counter: TChangeCounter;
begin
   BeginTest('Grid: an empty library shows a placeholder row that no action touches');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   config := TExternalLoggerConfig.Create;
   counter := TChangeCounter.Create;
   try
      grid := TStringGrid.Create(form);
      grid.Parent := form;
      view := TExternalLoggerGrid.Create(form, grid);
      view.OnChanged := counter.Changed;
      config.Present := True;
      view.Bind(config);
      view.Refresh;
      CheckEquals(2, grid.RowCount);
      CheckEquals('No loggers configured', string(grid.Cells[LOGGER_COL_NAME, 1]));
      CheckEquals('', view.SelectedId, 'the placeholder is not a logger');
      view.ToggleSendSelected;
      view.RemoveSelected(False);
      view.MoveSelected(1);
      CheckEquals(0, counter.Count, 'no action fired on the placeholder');
   finally
      counter.Free;
      config.Free;
      form.Free;
   end;
end;

procedure TExternalLoggerGridTests.Test_Grid_DragWritesTheNewOrderBack;
var
   form: TForm;
   grid: TStringGrid;
   view: TExternalLoggerGrid;
   config: TExternalLoggerConfig;
   counter: TChangeCounter;
begin
   BeginTest('Grid: dragging a row writes the new delivery order to the model');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   config := TExternalLoggerConfig.Create;
   counter := TChangeCounter.Create;
   try
      grid := TStringGrid.Create(form);
      grid.Parent := form;
      view := TExternalLoggerGrid.Create(form, grid);
      view.OnChanged := counter.Changed;
      FillConfig(config);
      view.Bind(config);
      view.Refresh;
      grid.MoveColRow(False, 1, 2);   (* the call the LCL makes at mouse-up *)
      Application.ProcessMessages;    (* the reselect is queued behind the move *)
      CheckEquals('ba', ActiveText(config), 'delivery order is now b, a');
      CheckEquals('bac', DefinitionText(config));
      CheckEquals('bac', GridIds(grid), 'the grid kept its rows');
      CheckEquals('12-', GridOrders(grid), 'Order was rewritten to the new positions');
      CheckEquals('a', view.SelectedId, 'the moved row (a, now second) stays selected');
      CheckEquals(1, counter.Count, 'one change reported');
   finally
      counter.Free;
      config.Free;
      form.Free;
   end;
end;

procedure TExternalLoggerGridTests.Test_Grid_DropAcrossTheActiveLineSnapsBack;
var
   form: TForm;
   grid: TStringGrid;
   view: TExternalLoggerGrid;
   config: TExternalLoggerConfig;
   counter: TChangeCounter;
begin
   BeginTest('Grid: an inactive row dropped among the active ones snaps back and changes no delivery order');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   config := TExternalLoggerConfig.Create;
   counter := TChangeCounter.Create;
   try
      grid := TStringGrid.Create(form);
      grid.Parent := form;
      view := TExternalLoggerGrid.Create(form, grid);
      view.OnChanged := counter.Changed;
      FillConfig(config);
      view.Bind(config);
      view.Refresh;
      grid.MoveColRow(False, 3, 1);   (* c, inactive, dropped above a *)
      CheckEquals('ab', ActiveText(config), 'delivery order unchanged');
      CheckEquals('12-', GridOrders(grid), 'c is back below the active loggers');
      CheckEquals('abc', GridIds(grid), 'rows are in group order again');
   finally
      counter.Free;
      config.Free;
      form.Free;
   end;
end;

procedure TExternalLoggerGridTests.Test_Grid_MoveSelectedStaysInItsGroup;
var
   form: TForm;
   grid: TStringGrid;
   view: TExternalLoggerGrid;
   config: TExternalLoggerConfig;
begin
   BeginTest('Grid: Move up and Move down act within the active or the inactive group');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   config := TExternalLoggerConfig.Create;
   try
      grid := TStringGrid.Create(form);
      grid.Parent := form;
      view := TExternalLoggerGrid.Create(form, grid);
      FillConfig(config);
      view.Bind(config);
      view.Refresh;
      grid.Row := 2;                       (* b, the last active *)
      view.MoveSelected(1);                (* next row is inactive c *)
      CheckEquals('ab', ActiveText(config), 'b cannot move into the inactive group');
      view.MoveSelected(-1);
      Application.ProcessMessages;
      CheckEquals('ba', ActiveText(config), 'b moves above a');
      CheckEquals('b', view.SelectedId, 'and stays selected');
      grid.Row := 1;
      view.MoveSelected(-1);
      CheckEquals('ba', ActiveText(config), 'the first row cannot move up');
   finally
      config.Free;
      form.Free;
   end;
end;

procedure TExternalLoggerGridTests.Test_Grid_ToggleSendAndRemove;
var
   form: TForm;
   grid: TStringGrid;
   view: TExternalLoggerGrid;
   config: TExternalLoggerConfig;
begin
   BeginTest('Grid: Send new QSOs toggles in place; Remove drops the row and leaves the rest');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   config := TExternalLoggerConfig.Create;
   try
      grid := TStringGrid.Create(form);
      grid.Parent := form;
      view := TExternalLoggerGrid.Create(form, grid);
      FillConfig(config);
      view.Bind(config);
      view.Refresh;
      grid.Row := 3;
      view.ToggleSendSelected;
      CheckEquals('abc', ActiveText(config), 'c was appended to the delivery order');
      CheckEquals('123', GridOrders(grid));
      CheckEquals('Yes', string(grid.Cells[LOGGER_COL_SEND, 3]));
      grid.Row := 1;
      view.ToggleSendSelected;
      CheckEquals('bc', ActiveText(config), 'a left the delivery order');
      CheckEquals('bca', GridIds(grid), 'a moved down to the inactive group');
      CheckEquals('12-', GridOrders(grid));
      CheckEquals('a', view.SelectedId, 'the toggled row stays selected where it landed');
      view.RemoveSelected(False);
      CheckEquals('bc', DefinitionText(config), 'only the selected row went');
      CheckEquals('bc', ActiveText(config), 'the others keep their delivery order');
      CheckEquals(3, grid.RowCount, 'header and two loggers');
   finally
      config.Free;
      form.Free;
   end;
end;

procedure TExternalLoggerGridTests.Test_Grid_EditsOnACopyLeaveTheOriginal;
var
   form: TForm;
   grid: TStringGrid;
   view: TExternalLoggerGrid;
   original, working: TExternalLoggerConfig;
begin
   BeginTest('Grid: edits land on the working copy, so Cancel (dropping the copy) discards them');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   original := TExternalLoggerConfig.Create;
   working := TExternalLoggerConfig.Create;
   try
      grid := TStringGrid.Create(form);
      grid.Parent := form;
      view := TExternalLoggerGrid.Create(form, grid);
      FillConfig(original);
      working.Assign(original);
      view.Bind(working);
      view.Refresh;
      grid.MoveColRow(False, 1, 2);
      Application.ProcessMessages;
      grid.Row := 3;
      view.ToggleSendSelected;
      CheckEquals('bac', ActiveText(working), 'the copy changed');
      CheckEquals('ab', ActiveText(original), 'the original did not');
      CheckEquals('abc', DefinitionText(original));
   finally
      working.Free;
      original.Free;
      form.Free;
   end;
end;

procedure TExternalLoggerGridTests.RunAllTests;
begin
   Test_Model_DisplayOrderIsActiveFirst;
   Test_Model_SetActiveAppendsAndIsIdempotent;
   Test_Model_ApplyOrderWritesBackDeliveryOrder;
   Test_Model_RemoveLeavesTheOthers;
   Test_Model_NewNameIsUnique;
   Test_Grid_RowsShowOrderAndSend;
   Test_Grid_AnEmptyLibraryShowsAPlaceholder;
   Test_Grid_DragWritesTheNewOrderBack;
   Test_Grid_DropAcrossTheActiveLineSnapsBack;
   Test_Grid_MoveSelectedStaysInItsGroup;
   Test_Grid_ToggleSendAndRemove;
   Test_Grid_EditsOnACopyLeaveTheOriginal;
end;

end.
