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
   uTR4WTestFramework, uExternalLoggerService, uExternalDelivery;

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
      procedure CheckDerive(const aWhat: string; aExpected: TExternalLoggerState;
         aEnabled, aKnown, aActive, aBusy, aHalted, aHasResult: boolean;
         aOutcome: TDeliveryOutcome; const aCode: string; aQueue: integer;
         aPending, aFailed: Int64);
      procedure Test_State_DerivationTable;
      procedure Test_Grid_BuildsTheColumns;
      procedure Test_Grid_CheckboxClickTogglesTheDefinitionAndTheSavedList;
      procedure Test_Grid_SpaceTogglesAndAnotherCellDoesNot;
      procedure Test_Grid_StateColumnShowsTextAndKindPerRow;
      procedure Test_Grid_StateColoursAreDistinct;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, Controls, Forms, Grids, Types, fpjson, uExternalLoggerConfig,
   uExternalLoggerGrid;

type
   TChangeCounter = class
   public
      Count: integer;
      procedure Changed(aSender: TObject);
   end;

   (* Stands in for the running program: what the service and the log would
      say about each destination (by DELIVERY id). *)
   TFakeStates = class
   public
      Ids: TStringList;
      Snapshots: array of TExternalLoggerSnapshot;
      Counts: array of TDeliveryCounts;
      constructor Create;
      destructor Destroy; override;
      procedure Add(const aId: string; const aSnapshot: TExternalLoggerSnapshot;
         const aCounts: TDeliveryCounts);
      function Query(const aDeliveryId: string; out aSnapshot: TExternalLoggerSnapshot;
         out aCounts: TDeliveryCounts): boolean;
   end;

constructor TFakeStates.Create;
begin
   inherited Create;
   Ids := TStringList.Create;
end;

destructor TFakeStates.Destroy;
begin
   Ids.Free;
   inherited Destroy;
end;

procedure TFakeStates.Add(const aId: string; const aSnapshot: TExternalLoggerSnapshot;
   const aCounts: TDeliveryCounts);
begin
   Ids.Add(AnsiString(aId));
   SetLength(Snapshots, Ids.Count);
   SetLength(Counts, Ids.Count);
   Snapshots[Ids.Count - 1] := aSnapshot;
   Counts[Ids.Count - 1] := aCounts;
end;

function TFakeStates.Query(const aDeliveryId: string;
   out aSnapshot: TExternalLoggerSnapshot; out aCounts: TDeliveryCounts): boolean;
var
   i: integer;
begin
   aSnapshot := Default(TExternalLoggerSnapshot);
   aCounts := Default(TDeliveryCounts);
   i := Ids.IndexOf(AnsiString(aDeliveryId));
   Result := i >= 0;
   if Result then
      begin
      aSnapshot := Snapshots[i];
      aCounts := Counts[i];
      end;
end;

(* The centre of a cell, where a click lands. *)
function CellCentre(const aGrid: TStringGrid; aCol, aRow: integer): TPoint;
var
   r: TRect;
begin
   r := aGrid.CellRect(aCol, aRow);
   Result.X := (r.Left + r.Right) div 2;
   Result.Y := (r.Top + r.Bottom) div 2;
end;

(* A left click: press and release on one cell, through the grid's own events. *)
procedure ClickCell(const aGrid: TStringGrid; aCol, aRow: integer);
var
   p: TPoint;
begin
   p := CellCentre(aGrid, aCol, aRow);
   aGrid.OnMouseDown(aGrid, mbLeft, [ssLeft], p.X, p.Y);
   aGrid.OnMouseUp(aGrid, mbLeft, [], p.X, p.Y);
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

(* One column's cells, top to bottom, run together. *)
function GridCellsOf(const aGrid: TStringGrid; aCol: integer): string;
var
   row: integer;
begin
   Result := '';
   for row := aGrid.FixedRows to aGrid.RowCount - 1 do
      begin
      Result := Result + string(aGrid.Cells[aCol, row]);
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
      CheckEquals('1', string(grid.Cells[LOGGER_COL_ENABLED, 1]));
      CheckEquals('1', string(grid.Cells[LOGGER_COL_ENABLED, 2]));
      CheckEquals('0', string(grid.Cells[LOGGER_COL_ENABLED, 3]));
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
      CheckEquals('1', string(grid.Cells[LOGGER_COL_ENABLED, 3]));
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

(* ----------------------------------------------------------------------- *)
(* Issue 226: the Enabled checkbox and the connection State                *)
(* ----------------------------------------------------------------------- *)

procedure TExternalLoggerGridTests.CheckDerive(const aWhat: string;
   aExpected: TExternalLoggerState; aEnabled, aKnown, aActive, aBusy, aHalted,
   aHasResult: boolean; aOutcome: TDeliveryOutcome; const aCode: string;
   aQueue: integer; aPending, aFailed: Int64);
var
   snapshot: TExternalLoggerSnapshot;
   counts: TDeliveryCounts;
begin
   snapshot := Default(TExternalLoggerSnapshot);
   snapshot.Active := aActive;
   snapshot.Busy := aBusy;
   snapshot.Halted := aHalted;
   snapshot.HasResult := aHasResult;
   snapshot.LastOutcome := aOutcome;
   snapshot.Code := aCode;
   snapshot.QueueDepth := aQueue;
   counts := Default(TDeliveryCounts);
   counts.Pending := aPending;
   counts.Failed := aFailed;
   CheckEquals(Ord(aExpected),
      Ord(DeriveExternalLoggerState(aEnabled, aKnown, snapshot, counts)), aWhat);
end;

procedure TExternalLoggerGridTests.Test_State_DerivationTable;
begin
   BeginTest('State: every input combination derives the state the operator should read');
   (*                what                         expected          enab  known active busy  halted result outcome      code                 queue pend fail *)
   CheckDerive('off, not running',               elsDisabled,      False, False, False, False, False, False, doConfirmed, '',                    0, 0, 0);
   CheckDerive('on, not running (restart)',      elsRestartNeeded, True,  False, False, False, False, False, doConfirmed, '',                    0, 0, 0);
   CheckDerive('switched off here, running on',  elsRestartNeeded, False, True,  True,  False, False, False, doConfirmed, '',                    0, 0, 0);
   CheckDerive('switched on here, running off',  elsRestartNeeded, True,  True,  False, False, False, False, doConfirmed, '',                    0, 0, 0);
   CheckDerive('off and running off',            elsDisabled,      False, True,  False, False, False, False, doConfirmed, '',                    0, 0, 0);
   CheckDerive('on, nothing yet',                elsIdle,          True,  True,  True,  False, False, False, doConfirmed, '',                    0, 0, 0);
   CheckDerive('a request is out',               elsSending,       True,  True,  True,  True,  False, False, doConfirmed, '',                    0, 0, 0);
   CheckDerive('work waiting',                   elsSending,       True,  True,  True,  False, False, True,  doConfirmed, '',                    0, 3, 0);
   CheckDerive('in-memory queue waiting',        elsSending,       True,  True,  True,  False, False, False, doConfirmed, '',                    2, 0, 0);
   CheckDerive('last delivery confirmed',        elsIdle,          True,  True,  True,  False, False, True,  doConfirmed, '',                    0, 0, 0);
   CheckDerive('last delivery to be retried',    elsRetrying,      True,  True,  True,  False, False, True,  doRetry,     'WRL_CA_BUNDLE_MISSING', 0, 1, 0);
   CheckDerive('last delivery refused',          elsFailed,        True,  True,  True,  False, False, True,  doFailed,    'WRL_BAD_REQUEST',     0, 0, 1);
   CheckDerive('last delivery uncertain',        elsIdle,          True,  True,  True,  False, False, True,  doUncertain, 'WRL_NO_ANSWER',       0, 0, 0);
   CheckDerive('old failed rows alone',          elsIdle,          True,  True,  True,  False, False, False, doConfirmed, '',                    0, 0, 5);
   CheckDerive('halted on credentials',          elsPaused,        True,  True,  True,  False, True,  True,  doRetry,     'WRL_AUTH_POLICY',     0, 1, 0);
   CheckDerive('halted, setup required',         elsPaused,        True,  True,  True,  False, True,  False, doConfirmed, 'LOGGER_SETUP_REQUIRED', 0, 0, 0);
   CheckDerive('the worker died',                elsFailed,        True,  True,  True,  False, True,  False, doConfirmed, 'DELIVERY_STOPPED',    0, 0, 0);
   CheckDerive('halted beats a request in flight', elsPaused,      True,  True,  True,  True,  True,  False, doConfirmed, 'AUTHENTICATION_REQUIRED', 0, 0, 0);
   CheckDerive('off beats a stale halt',         elsDisabled,      False, True,  False, False, True,  True,  doRetry,     'WRL_AUTH_POLICY',     0, 1, 0);
end;

procedure TExternalLoggerGridTests.Test_Grid_BuildsTheColumns;
var
   form: TForm;
   grid: TStringGrid;
   view: TExternalLoggerGrid;
   config: TExternalLoggerConfig;
begin
   BeginTest('Grid: Enabled is a checkbox column, State is text, and two columns stay hidden');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   config := TExternalLoggerConfig.Create;
   try
      grid := TStringGrid.Create(form);
      grid.Parent := form;
      (* What the Preferences LFM streams into the grid before the view builds
         its columns (uPrefsForm.lfm: ColCount 5, FixedCols 1, RowCount 2). *)
      grid.ColCount := 5;
      grid.RowCount := 2;
      grid.FixedCols := 1;
      grid.FixedRows := 1;
      view := TExternalLoggerGrid.Create(form, grid);
      FillConfig(config);
      view.Bind(config);
      view.Refresh;
      CheckEquals(7, grid.ColCount, 'Order, Logger, Provider, Enabled, State, Id, state ordinal');
      CheckEquals(6, grid.Columns.Count, 'every column but the fixed Order column');
      CheckTrue(grid.Columns[LOGGER_COL_ENABLED - 1].ButtonStyle = cbsCheckboxColumn,
         'the LCL draws a real checkbox');
      CheckTrue(grid.Columns[LOGGER_COL_ENABLED - 1].ValueChecked = '1');
      CheckEquals('Enabled', string(grid.Columns[LOGGER_COL_ENABLED - 1].Title.Caption));
      CheckEquals('Connection', string(grid.Columns[LOGGER_COL_STATE - 1].Title.Caption));
      CheckEquals('Logger', string(grid.Columns[LOGGER_COL_NAME - 1].Title.Caption));
      CheckEquals(0, grid.ColWidths[LOGGER_COL_ID], 'the id is hidden');
      CheckEquals(0, grid.ColWidths[LOGGER_COL_STATEKIND], 'the state ordinal is hidden');
      CheckTrue(grid.ColWidths[LOGGER_COL_STATE] > 100, 'the state text has room');
      CheckEquals('110', GridCellsOf(grid, LOGGER_COL_ENABLED), 'a: on, b: on, c: off');
      CheckFalse(goEditing in grid.Options, 'text cells are not editable; the click is ours');
   finally
      config.Free;
      form.Free;
   end;
end;

procedure TExternalLoggerGridTests.Test_Grid_CheckboxClickTogglesTheDefinitionAndTheSavedList;
var
   form: TForm;
   grid: TStringGrid;
   view: TExternalLoggerGrid;
   config, reloaded: TExternalLoggerConfig;
   counter: TChangeCounter;
   saved: TJSONObject;
begin
   BeginTest('Grid: clicking the Enabled box flips the one flag, reports a change, and the saved list follows');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   config := TExternalLoggerConfig.Create;
   reloaded := TExternalLoggerConfig.Create;
   counter := TChangeCounter.Create;
   saved := TJSONObject.Create;
   try
      grid := TStringGrid.Create(form);
      grid.Parent := form;
      view := TExternalLoggerGrid.Create(form, grid);
      view.OnChanged := counter.Changed;
      FillConfig(config);
      view.Bind(config);
      view.Refresh;
      ClickCell(grid, LOGGER_COL_ENABLED, 3);   (* c, off -> on *)
      CheckEquals('abc', ActiveText(config), 'c joined the delivery order: the same flag as Order');
      CheckEquals('111', GridCellsOf(grid, LOGGER_COL_ENABLED), 'the box follows the model');
      CheckEquals('123', GridOrders(grid), 'and so does Order');
      CheckEquals(1, counter.Count, 'one change reported (Dirty and the restart note)');
      ClickCell(grid, LOGGER_COL_ENABLED, 1);   (* a, on -> off *)
      CheckEquals('bc', ActiveText(config));
      CheckEquals('bca', GridIds(grid), 'a dropped to the inactive group');
      CheckEquals('110', GridCellsOf(grid, LOGGER_COL_ENABLED));
      CheckEquals(2, counter.Count);
      (* The Preferences Save writes the working copy; read back it says the same. *)
      config.SaveJSON(saved);
      reloaded.LoadJSON(saved);
      CheckEquals('bc', ActiveText(reloaded), 'the persisted list');
      CheckEquals(3, reloaded.Definitions.Count, 'a switched-off definition is kept');
      (* A release on some other cell is not a click on the box. *)
      grid.OnMouseDown(grid, mbLeft, [ssLeft], CellCentre(grid, LOGGER_COL_ENABLED, 1).X,
         CellCentre(grid, LOGGER_COL_ENABLED, 1).Y);
      grid.OnMouseUp(grid, mbLeft, [], CellCentre(grid, LOGGER_COL_NAME, 2).X,
         CellCentre(grid, LOGGER_COL_NAME, 2).Y);
      CheckEquals('bc', ActiveText(config), 'pressed on the box, released elsewhere');
      ClickCell(grid, LOGGER_COL_NAME, 1);
      CheckEquals('bc', ActiveText(config), 'a click on the name toggles nothing');
      CheckEquals(2, counter.Count);
   finally
      saved.Free;
      counter.Free;
      reloaded.Free;
      config.Free;
      form.Free;
   end;
end;

procedure TExternalLoggerGridTests.Test_Grid_SpaceTogglesAndAnotherCellDoesNot;
var
   form: TForm;
   grid: TStringGrid;
   view: TExternalLoggerGrid;
   config: TExternalLoggerConfig;
   key: word;
begin
   BeginTest('Grid: Space toggles the selected row; the placeholder row has nothing to toggle');
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
      key := 32;
      grid.OnKeyDown(grid, key, []);
      CheckEquals('abc', ActiveText(config), 'Space on c');
      CheckEquals(0, key, 'the key was consumed');
      key := 65;
      grid.OnKeyDown(grid, key, []);
      CheckEquals('abc', ActiveText(config), 'another key does nothing');
      config.Clear;
      config.Present := True;
      view.Refresh;
      key := 32;
      grid.OnKeyDown(grid, key, []);
      ClickCell(grid, LOGGER_COL_ENABLED, 1);
      CheckEquals(0, config.Definitions.Count, 'the placeholder is not a logger');
   finally
      config.Free;
      form.Free;
   end;
end;

procedure TExternalLoggerGridTests.Test_Grid_StateColumnShowsTextAndKindPerRow;
var
   form: TForm;
   grid: TStringGrid;
   view: TExternalLoggerGrid;
   config: TExternalLoggerConfig;
   states: TFakeStates;
   snapshot: TExternalLoggerSnapshot;
   counts: TDeliveryCounts;
begin
   BeginTest('Grid: the State column says disabled, idle, paused with its reason, sending, and restart');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   config := TExternalLoggerConfig.Create;
   states := TFakeStates.Create;
   try
      grid := TStringGrid.Create(form);
      grid.Parent := form;
      view := TExternalLoggerGrid.Create(form, grid);
      FillConfig(config);
      view.Bind(config);
      (* a: running, idle, two old failed rows.  b: running, halted on policy.
         c: switched off and not running. *)
      snapshot := Default(TExternalLoggerSnapshot);
      snapshot.Active := True;
      counts := Default(TDeliveryCounts);
      counts.Failed := 2;
      states.Add(config.Find('a').DeliveryId, snapshot, counts);
      snapshot.Halted := True;
      snapshot.Code := 'WRL_AUTH_POLICY';
      counts := Default(TDeliveryCounts);
      states.Add(config.Find('b').DeliveryId, snapshot, counts);
      CheckFalse(Assigned(view.OnQueryState), 'no source yet');
      view.OnQueryState := states.Query;
      view.Refresh;
      CheckEquals('Idle (0 uncertain, 2 failed)', string(grid.Cells[LOGGER_COL_STATE, 1]),
         'old failures ride along as counts and do not turn the row red');
      CheckEquals(IntToStr(Ord(elsIdle)), string(grid.Cells[LOGGER_COL_STATEKIND, 1]));
      CheckEquals('Paused: WRL_AUTH_POLICY', string(grid.Cells[LOGGER_COL_STATE, 2]));
      CheckEquals(IntToStr(Ord(elsPaused)), string(grid.Cells[LOGGER_COL_STATEKIND, 2]));
      CheckEquals('Disabled', string(grid.Cells[LOGGER_COL_STATE, 3]), 'a switched-off row');
      CheckEquals(IntToStr(Ord(elsDisabled)), string(grid.Cells[LOGGER_COL_STATEKIND, 3]));
      (* The service reports work; only the State cells are rewritten. *)
      states.Snapshots[0].Busy := True;
      states.Counts[0].Pending := 3;
      grid.Row := 2;
      view.RefreshStates;
      CheckEquals('Sending (3 pending) (0 uncertain, 2 failed)', string(grid.Cells[LOGGER_COL_STATE, 1]));
      CheckEquals(2, grid.Row, 'a state refresh leaves the selection alone');
      (* Switching c on here: the running service never heard of it. *)
      grid.Row := 3;
      view.ToggleSendSelected;
      CheckEquals('Restart TR4W to apply', string(grid.Cells[LOGGER_COL_STATE, 3]));
      CheckEquals(IntToStr(Ord(elsRestartNeeded)), string(grid.Cells[LOGGER_COL_STATEKIND, 3]));
      (* Switching a off here: the service is still running it. *)
      grid.Row := 1;
      view.ToggleSendSelected;
      CheckEquals('a', view.SelectedId);
      CheckEquals('Restart TR4W to apply', string(grid.Cells[LOGGER_COL_STATE, grid.Row]));
      view.OnQueryState := nil;
      view.RefreshStates;
      CheckEquals('Restart TR4W to apply', string(grid.Cells[LOGGER_COL_STATE, 1]),
         'with no source every enabled row is "not running"');
   finally
      states.Free;
      config.Free;
      form.Free;
   end;
end;

procedure TExternalLoggerGridTests.Test_Grid_StateColoursAreDistinct;
var
   a, b: TExternalLoggerState;
begin
   BeginTest('Grid: each state has its own colour, so colour can repeat what the text says');
   for a := Low(TExternalLoggerState) to High(TExternalLoggerState) do
      begin
      for b := Succ(a) to High(TExternalLoggerState) do
         begin
         CheckTrue(ExternalLoggerStateColour(a) <> ExternalLoggerStateColour(b),
            'states ' + IntToStr(Ord(a)) + ' and ' + IntToStr(Ord(b)));
         end;
      end;
end;

procedure TExternalLoggerGridTests.RunAllTests;
begin
   Test_State_DerivationTable;
   Test_Grid_BuildsTheColumns;
   Test_Grid_CheckboxClickTogglesTheDefinitionAndTheSavedList;
   Test_Grid_SpaceTogglesAndAnotherCellDoesNot;
   Test_Grid_StateColumnShowsTextAndKindPerRow;
   Test_Grid_StateColoursAreDistinct;
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
