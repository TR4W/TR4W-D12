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
  This suite does not construct TPrefsForm (uTestPrefsPlacement builds it, for
  the editor count only); the page is covered by the form lints. The Colours grid, which fills its row the same way (issue 234),
  is built here on a bare grid through uPrefsForm's own column and sizing
  routines.
*)

interface

uses
   Forms, Grids, uTR4WTestFramework, uExternalLoggerService, uExternalDelivery;

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
      procedure CheckColumnsFill(const aForm: TForm; const aGrid: TStringGrid;
         aFormWidth: integer; const aWhere: string);
      procedure Test_Grid_ColumnsFillTheGridAtAnyWidth;
      procedure Test_Grid_HeaderDragResizesAndHiddenColumnsStayHidden;
      procedure Test_Grid_ADraggedWidthComesBackInAFreshGrid;
      procedure CheckColoursFill(const aForm: TForm; const aGrid: TStringGrid;
         aFormWidth: integer; const aWhere: string);
      procedure Test_ColoursGrid_SampleFillsTheRowAndIsNotKept;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, Controls, StdCtrls, Types, fpjson, uExternalLoggerConfig,
   uExternalLoggerGrid, uTestShowOffScreen,
   uPrefsForm,        (* the Colours grid's columns and sizing, on a bare grid -- issue 234 *)
   uLCLFormHelpers;   (* PendingColumnWidths -- a drag marks one; cleared behind each test *)

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

(* ----------------------------------------------------------------------- *)
(* Issue 226 follow-up: the columns fill the grid, on a SHOWN form          *)
(* ----------------------------------------------------------------------- *)

(* The sum of every column's width, hidden ones included (they must be 0). *)
function SumOfColumnWidths(const aGrid: TStringGrid): integer;
var
   col: integer;
begin
   Result := 0;
   for col := 0 to aGrid.ColCount - 1 do
      begin
      Result := Result + aGrid.ColWidths[col];
      end;
end;

(* Resize the FORM (the grid follows its anchors, as on the Preferences
   page), let the LCL lay it out, and check the columns fill the grid. *)
procedure TExternalLoggerGridTests.CheckColumnsFill(const aForm: TForm;
   const aGrid: TStringGrid; aFormWidth: integer; const aWhere: string);
var
   where: string;
begin
   aForm.ClientWidth := aFormWidth;
   Application.ProcessMessages;
   where := Format(' (%s: form %d, grid %d, client %d, columns %d, Connection %d)',
      [aWhere, aForm.ClientWidth, aGrid.Width, aGrid.ClientWidth,
      SumOfColumnWidths(aGrid), aGrid.ColWidths[LOGGER_COL_STATE]]);
   WriteLn('  [LoggerGrid]', where);
   CheckEquals(aGrid.ClientWidth, SumOfColumnWidths(aGrid),
      'the columns fill the client width' + where);
   CheckEquals(60, aGrid.ColWidths[LOGGER_COL_ORDER], 'Order keeps its width' + where);
   CheckEquals(190, aGrid.ColWidths[LOGGER_COL_NAME], 'Logger keeps its width' + where);
   CheckEquals(110, aGrid.ColWidths[LOGGER_COL_PROVIDER], 'Provider keeps its width' + where);
   CheckEquals(70, aGrid.ColWidths[LOGGER_COL_ENABLED], 'Enabled keeps its width' + where);
   CheckEquals(0, aGrid.ColWidths[LOGGER_COL_ID], 'the id stays hidden' + where);
   CheckEquals(0, aGrid.ColWidths[LOGGER_COL_STATEKIND], 'the state ordinal stays hidden' + where);
end;

procedure TExternalLoggerGridTests.Test_Grid_ColumnsFillTheGridAtAnyWidth;
const
   GRID_LEFT = 12;
   GRID_MARGIN = 12;
var
   form: TForm;
   grid: TStringGrid;
   view: TExternalLoggerGrid;
   config: TExternalLoggerConfig;
   definition: TExternalLoggerDefinition;
   i, fewRowsClient: integer;
begin
   BeginTest('Grid: the columns fill the grid''s client width at two widths, and the row count never moves the client width');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   config := TExternalLoggerConfig.Create;
   try
      form.ClientWidth := 674;
      form.ClientHeight := 300;
      grid := TStringGrid.Create(form);
      (* As uPrefsForm.lfm places grdExternalLoggers. *)
      grid.SetBounds(GRID_LEFT, 44, form.ClientWidth - GRID_LEFT - GRID_MARGIN, 220);
      grid.Anchors := [akTop, akLeft, akRight];
      grid.Parent := form;
      view := TExternalLoggerGrid.Create(form, grid);
      (* THE INVARIANT BY CONSTRUCTION: an automatic bar shown or hidden after
         the fill leaves the row one bar-width off (FillGridFromColumn), and
         whether a later pass heals it is machine timing -- it failed on the
         CI runner and passed here. *)
      CheckTrue(grid.ScrollBars = ssVertical,
         'the fill grid''s vertical bar is permanent, so ClientWidth cannot follow the row count');
      FillConfig(config);
      view.Bind(config);
      view.Refresh;
      ShowOffScreen(form);
      CheckColumnsFill(form, grid, 674, 'designed width');
      CheckColumnsFill(form, grid, 900, 'wider');
      fewRowsClient := grid.ClientWidth;
      (* Enough rows to overflow 220 px: the bar was already there, so the
         client width stays and the fill with it. *)
      for i := 3 to 24 do
         begin
         definition := TExternalLoggerDefinition.Create;
         definition.Id := 'x' + IntToStr(i);
         definition.Name := 'Logger ' + IntToStr(i);
         definition.ProviderId := 'DXKEEPER';
         definition.Address := '127.0.0.1';
         definition.Port := 52001 + i;
         config.Definitions.Add(definition);
         end;
      view.Refresh;
      Application.ProcessMessages;
      CheckTrue(grid.RowCount * grid.DefaultRowHeight > grid.ClientHeight,
         'the rows overflow the grid');
      CheckColumnsFill(form, grid, 900, 'wider, rows overflow');
      CheckEquals(fewRowsClient, grid.ClientWidth,
         'the overflowing rows did not move the client width (' +
         IntToStr(fewRowsClient) + ' -> ' + IntToStr(grid.ClientWidth) + ')');
      CheckColumnsFill(form, grid, 674, 'designed width, rows overflow');
      (* And back: the extra loggers removed, the rows fit again. *)
      FillConfig(config);
      view.Refresh;
      Application.ProcessMessages;
      CheckTrue(grid.RowCount * grid.DefaultRowHeight < grid.ClientHeight,
         'the rows fit the grid again');
      CheckColumnsFill(form, grid, 674, 'designed width, rows fit again');
      CheckColumnsFill(form, grid, 900, 'wider, rows fit again');
      CheckEquals(fewRowsClient, grid.ClientWidth,
         'fewer rows did not move the client width either');
   finally
      config.Free;
      form.Free;
   end;
end;

type
   (* A TStringGrid that can be driven with the mouse calls the LCL itself makes
      (MouseMove / MouseDown / MouseUp are protected), and that records which
      column the LCL reported as sized. The view's OnHeaderSized still runs:
      HeaderSized is what raises it. *)
   TSizingProbeGrid = class(TStringGrid)
   public
      SizedCount, SizedIndex: integer;
      procedure HeaderSized(IsColumn: Boolean; index: Integer); override;
      procedure Drag(aFromX, aToX, aY: integer);
   end;

procedure TSizingProbeGrid.HeaderSized(IsColumn: Boolean; index: Integer);
begin
   if IsColumn then
      begin
      Inc(SizedCount);
      SizedIndex := index;
      end;
   inherited HeaderSized(IsColumn, index);
end;

(* Hover (the LCL arms the sizing cursor), press, move, release. *)
procedure TSizingProbeGrid.Drag(aFromX, aToX, aY: integer);
begin
   MouseMove([], aFromX, aY);
   MouseDown(mbLeft, [ssLeft], aFromX, aY);
   MouseMove([ssLeft], aToX, aY);
   MouseUp(mbLeft, [], aToX, aY);
end;

(* goColSizing on a grid whose columns fill it: a dragged divider keeps its
   width and the fill column absorbs the difference; the fixed Order column is
   not sizable; and dragging the Connection column's right edge, which the LCL
   hands to the last zero-width column after it, does not reveal a hidden
   column. *)
procedure TExternalLoggerGridTests.Test_Grid_HeaderDragResizesAndHiddenColumnsStayHidden;
var
   form: TForm;
   grid: TSizingProbeGrid;
   view: TExternalLoggerGrid;
   config: TExternalLoggerConfig;
   headerY, stateBefore, x, grown: integer;
   where: string;
begin
   BeginTest('Grid: a header divider drags; Connection absorbs it; Order and the hidden columns do not size');
   InitWidgetSet;
   form := TForm.CreateNew(nil);
   config := TExternalLoggerConfig.Create;
   try
      form.ClientWidth := 900;
      form.ClientHeight := 300;
      grid := TSizingProbeGrid.Create(form);
      grid.SetBounds(12, 44, form.ClientWidth - 24, 220);
      grid.Anchors := [akTop, akLeft, akRight];
      grid.Parent := form;
      view := TExternalLoggerGrid.Create(form, grid);
      FillConfig(config);
      view.Bind(config);
      view.Refresh;
      CheckTrue(goColSizing in grid.Options, 'header dividers drag, as in a stock LCL grid');
      CheckFalse(goFixedColSizing in grid.Options, 'the fixed Order column is not sizable');
      CheckTrue(Assigned(grid.OnHeaderSized), 'the view guards the hidden columns');
      ShowOffScreen(form);
      grid.SetFocus;
      Application.ProcessMessages;
      CheckTrue(grid.Focused, 'the grid took focus; TCustomGrid.MouseDown ignores a press without it');
      headerY := grid.RowHeights[0] div 2;
      stateBefore := grid.ColWidths[LOGGER_COL_STATE];
      (* THE PRECONDITION, named: every check below is relative to this fill,
         so a fill that is already wrong must fail here rather than as
         "Connection gave up exactly what Logger took". *)
      where := Format(' (before the drag: Connection %d, columns %d, client %d)',
         [stateBefore, SumOfColumnWidths(grid), grid.ClientWidth]);
      WriteLn('  [LoggerGrid]', where);
      CheckTrue(grid.ScrollBars = ssVertical, 'the vertical bar is permanent' + where);
      CheckEquals(grid.ClientWidth, SumOfColumnWidths(grid),
         'the columns fill the client width before any drag' + where);

      (* Logger's right divider, dragged 40 px to the right. *)
      x := grid.ColWidths[LOGGER_COL_ORDER] + grid.ColWidths[LOGGER_COL_NAME] - 1;
      grid.Drag(x, x + 40, headerY);
      Application.ProcessMessages;
      where := Format(' (focused %s, sized %d x%d, Logger %d, Connection %d -> %d, columns %d, client %d)',
         [BoolToStr(grid.Focused, True), grid.SizedIndex, grid.SizedCount,
         grid.ColWidths[LOGGER_COL_NAME], stateBefore, grid.ColWidths[LOGGER_COL_STATE],
         SumOfColumnWidths(grid), grid.ClientWidth]);
      WriteLn('  [LoggerGrid] Logger drag', where);
      CheckEquals(1, grid.SizedCount, 'the LCL ran a column resize' + where);
      CheckEquals(LOGGER_COL_NAME, grid.SizedIndex, 'it sized Logger' + where);
      (* The LCL sizes to the pointer: the new right edge is where it let go. *)
      grown := (x + 40) - grid.ColWidths[LOGGER_COL_ORDER] - 190;
      CheckTrue(grown > 30, 'Logger grew by about the drag' + where);
      CheckEquals(190 + grown, grid.ColWidths[LOGGER_COL_NAME], 'Logger ends at the pointer' + where);
      CheckEquals(stateBefore - grown, grid.ColWidths[LOGGER_COL_STATE],
         'Connection gave up exactly what Logger took' + where);
      CheckEquals(grid.ClientWidth, SumOfColumnWidths(grid), 'still no gap' + where);
      CheckEquals(0, grid.ColWidths[LOGGER_COL_ID], 'the id stays hidden' + where);
      CheckEquals(0, grid.ColWidths[LOGGER_COL_STATEKIND], 'the ordinal stays hidden' + where);

      (* The Order column's divider: nothing happens. *)
      x := grid.ColWidths[LOGGER_COL_ORDER] + 1;
      grid.Drag(x, x + 40, headerY);
      Application.ProcessMessages;
      CheckEquals(60, grid.ColWidths[LOGGER_COL_ORDER], 'Order keeps its width');
      CheckEquals(1, grid.SizedCount, 'no resize was reported');

      (* Connection's right edge, dragged to the right. *)
      x := grid.ClientWidth - 2;
      grid.Drag(x, x + 40, headerY);
      Application.ProcessMessages;
      where := Format(' (sized %d x%d, Id %d, ordinal %d, Connection %d, columns %d, client %d)',
         [grid.SizedIndex, grid.SizedCount, grid.ColWidths[LOGGER_COL_ID],
         grid.ColWidths[LOGGER_COL_STATEKIND], grid.ColWidths[LOGGER_COL_STATE],
         SumOfColumnWidths(grid), grid.ClientWidth]);
      WriteLn('  [LoggerGrid] Connection edge drag', where);
      CheckEquals(2, grid.SizedCount, 'the LCL ran a column resize' + where);
      CheckEquals(LOGGER_COL_STATEKIND, grid.SizedIndex,
         'the LCL picked the hidden ordinal column (why the guard exists)' + where);
      CheckEquals(0, grid.ColWidths[LOGGER_COL_ID], 'the id stays hidden' + where);
      CheckEquals(0, grid.ColWidths[LOGGER_COL_STATEKIND], 'the ordinal is hidden again' + where);
      CheckEquals(stateBefore - grown, grid.ColWidths[LOGGER_COL_STATE],
         'Connection is unchanged' + where);
      CheckEquals(grid.ClientWidth, SumOfColumnWidths(grid), 'still no gap' + where);
   finally
      (* The Logger drag marked a width (issue 234); nothing here may let it
         reach the settings file. *)
      PendingColumnWidths.Clear;
      config.Free;
      form.Free;
   end;
end;

(* ISSUE 234: a dragged Logger width is marked under the grid's name and a
   token, never Connection's or a hidden column's, and a FRESH grid -- the
   Preferences window opened again -- comes back with it while the fill still
   closes the row. Restored from the unwritten marks, so no file is read for
   the width and none is written. *)
procedure TExternalLoggerGridTests.Test_Grid_ADraggedWidthComesBackInAFreshGrid;
var
   form, form2: TForm;
   grid: TSizingProbeGrid;
   grid2: TStringGrid;
   view, view2: TExternalLoggerGrid;
   config: TExternalLoggerConfig;
   headerY, x, dragged, w: integer;
begin
   BeginTest('Grid: a dragged Logger width is kept, and a fresh grid restores it with the fill intact');
   InitWidgetSet;
   PendingColumnWidths.Clear;
   form := TForm.CreateNew(nil);
   form2 := TForm.CreateNew(nil);
   config := TExternalLoggerConfig.Create;
   try
      form.ClientWidth := 900;
      form.ClientHeight := 300;
      grid := TSizingProbeGrid.Create(form);
      grid.SetBounds(12, 44, form.ClientWidth - 24, 220);
      grid.Anchors := [akTop, akLeft, akRight];
      grid.Parent := form;
      view := TExternalLoggerGrid.Create(form, grid);
      FillConfig(config);
      view.Bind(config);
      view.Refresh;
      ShowOffScreen(form);
      grid.SetFocus;
      Application.ProcessMessages;
      headerY := grid.RowHeights[0] div 2;

      x := grid.ColWidths[LOGGER_COL_ORDER] + grid.ColWidths[LOGGER_COL_NAME] - 1;
      grid.Drag(x, x + 40, headerY);
      Application.ProcessMessages;
      dragged := grid.ColWidths[LOGGER_COL_NAME];
      CheckTrue(dragged > 220, 'Logger was dragged wider (' + IntToStr(dragged) + ')');

      w := 0;
      CheckTrue(PendingColumnWidths.TryGetWidth(LOGGER_GRID_COLUMNS_NAME, 'Logger', w),
         'the drag was marked under the grid name and the Logger token');
      CheckEquals(grid.ScaleFormTo96(dragged), w, 'at 96 dpi');
      CheckEquals(1, PendingColumnWidths.EntryCount,
         'and only Logger: Connection, which gave up the width, is the fill''s');

      (* The window opened again: a new grid, the designed widths, then the
         restore the owner calls. *)
      form2.ClientWidth := 900;
      form2.ClientHeight := 300;
      grid2 := TStringGrid.Create(form2);
      grid2.SetBounds(12, 44, form2.ClientWidth - 24, 220);
      grid2.Anchors := [akTop, akLeft, akRight];
      grid2.Parent := form2;
      view2 := TExternalLoggerGrid.Create(form2, grid2);
      view2.Bind(config);
      view2.Refresh;
      CheckEquals(190, grid2.ColWidths[LOGGER_COL_NAME], 'a new grid starts at the designed width');
      view2.RestoreColumnWidths;
      ShowOffScreen(form2);
      CheckEquals(grid2.Scale96ToForm(grid.ScaleFormTo96(dragged)), grid2.ColWidths[LOGGER_COL_NAME],
         'and comes back at the dragged one');
      CheckEquals(110, grid2.ColWidths[LOGGER_COL_PROVIDER], 'Provider was not dragged, so is designed');
      CheckEquals(0, grid2.ColWidths[LOGGER_COL_ID], 'the id stays hidden');
      CheckEquals(0, grid2.ColWidths[LOGGER_COL_STATEKIND], 'the ordinal stays hidden');
      CheckEquals(grid2.ClientWidth, SumOfColumnWidths(grid2), 'the fill still closes the row' +
         Format(' (fresh grid: Logger %d, Connection %d, columns %d, client %d)',
         [grid2.ColWidths[LOGGER_COL_NAME], grid2.ColWidths[LOGGER_COL_STATE],
         SumOfColumnWidths(grid2), grid2.ClientWidth]));
   finally
      PendingColumnWidths.Clear;
      config.Free;
      form2.Free;
      form.Free;
   end;
end;

(* The Colours grid (Preferences > Appearance > Colors) after a form resize:
   the row ends at the grid's client edge, which already leaves out the
   vertical scrollbar, and only Sample moved. *)
procedure TExternalLoggerGridTests.CheckColoursFill(const aForm: TForm;
   const aGrid: TStringGrid; aFormWidth: integer; const aWhere: string);
var
   where: string;
begin
   aForm.ClientWidth := aFormWidth;
   Application.ProcessMessages;
   where := Format(' (%s: form %d, grid %d, client %d, columns %d, Sample %d, min %d)',
      [aWhere, aForm.ClientWidth, aGrid.Width, aGrid.ClientWidth,
      SumOfColumnWidths(aGrid), aGrid.ColWidths[COLORS_COL_SAMPLE],
      aGrid.Columns[COLORS_COL_SAMPLE].MinSize]);
   WriteLn('  [ColoursGrid]', where);
   CheckEquals(aGrid.ClientWidth, SumOfColumnWidths(aGrid),
      'the Colours columns fill the client width' + where);
   CheckTrue(aGrid.ColWidths[COLORS_COL_SAMPLE] >= aGrid.Columns[COLORS_COL_SAMPLE].MinSize,
      'Sample is never narrower than its measured width' + where);
end;

(* ISSUE 234, NY4I's bench: the Colours grid's four columns stopped short of
   its right edge, leaving a white band. Built as BuildColorsSection builds it
   (aligned in a 12 px margin, fifty-odd rows, so the vertical bar shows),
   sized as the page sizes it -- before the form is shown -- then measured at
   the designed width and wider. Sample takes the slack and is never kept;
   the three measured columns keep their widths and stay kept. *)
procedure TExternalLoggerGridTests.Test_ColoursGrid_SampleFillsTheRowAndIsNotKept;
const
   ROWS = 52;
var
   form: TForm;
   grid: TSizingProbeGrid;
   row, elementWidth, textWidth, backWidth, sampleBefore, headerY, x, w: integer;
   where: string;
begin
   BeginTest('Colours grid: Sample fills the row to the right edge at any width, and its width is not kept');
   InitWidgetSet;
   PendingColumnWidths.Clear;
   form := TForm.CreateNew(nil);
   try
      form.ClientWidth := 674;
      form.ClientHeight := 300;
      grid := TSizingProbeGrid.Create(form);
      grid.Parent := form;
      grid.Align := alClient;
      grid.BorderSpacing.Around := 12;
      (* No ScrollBars: BuildColorsSection sets none, and the fill sets its
         own (checked below). *)
      grid.FixedRows := 1;
      grid.FixedCols := 0;
      grid.Options := grid.Options + [goEditing, goVertLine, goHorzLine, goColSizing];
      AddColorsGridColumns(grid);
      CheckEquals(4, grid.ColCount, 'the Columns collection alone makes four columns');
      CheckEquals('', COLORS_COLUMN_TOKENS[COLORS_COL_SAMPLE],
         'Sample, the fill column, has no token');
      grid.RowCount := ROWS;
      for row := 1 to ROWS - 1 do
         begin
         grid.Cells[COLORS_COL_ELEMENT, row] := 'Element ' + IntToStr(row);
         grid.Cells[COLORS_COL_FG, row] := 'LIGHT GRAY';
         grid.Cells[COLORS_COL_BG, row] := 'WHITE';
         grid.Cells[COLORS_COL_SAMPLE, row] := 'W1AW 599 14.025';
         end;
      SizeColorsGridColumns(grid);
      CheckTrue(grid.ScrollBars = ssVertical,
         'the Colours grid''s vertical bar is permanent, so the fill never follows a bar shown late');
      elementWidth := grid.ColWidths[COLORS_COL_ELEMENT];
      textWidth := grid.ColWidths[COLORS_COL_FG];
      backWidth := grid.ColWidths[COLORS_COL_BG];
      ShowOffScreen(form);
      CheckTrue(grid.RowCount * grid.DefaultRowHeight > grid.ClientHeight,
         'the rows overflow the grid, so the vertical scrollbar is up');
      CheckColoursFill(form, grid, 674, 'designed width');
      CheckColoursFill(form, grid, 900, 'wider');
      CheckEquals(elementWidth, grid.ColWidths[COLORS_COL_ELEMENT], 'Element keeps its width');
      CheckEquals(textWidth, grid.ColWidths[COLORS_COL_FG], 'Text keeps its width');
      CheckEquals(backWidth, grid.ColWidths[COLORS_COL_BG], 'Background keeps its width');

      (* A drag of Text's divider: Text keeps it and Sample gives it up. *)
      grid.SetFocus;
      Application.ProcessMessages;
      headerY := grid.RowHeights[0] div 2;
      sampleBefore := grid.ColWidths[COLORS_COL_SAMPLE];
      x := elementWidth + textWidth - 1;
      grid.Drag(x, x + 40, headerY);
      Application.ProcessMessages;
      where := Format(' (sized %d x%d, Text %d -> %d, Sample %d -> %d, columns %d, client %d)',
         [grid.SizedIndex, grid.SizedCount, textWidth, grid.ColWidths[COLORS_COL_FG],
         sampleBefore, grid.ColWidths[COLORS_COL_SAMPLE], SumOfColumnWidths(grid),
         grid.ClientWidth]);
      WriteLn('  [ColoursGrid] Text drag', where);
      CheckEquals(COLORS_COL_FG, grid.SizedIndex, 'the LCL sized Text' + where);
      CheckTrue(grid.ColWidths[COLORS_COL_FG] > textWidth + 30, 'Text grew by about the drag' + where);
      CheckEquals(sampleBefore - (grid.ColWidths[COLORS_COL_FG] - textWidth),
         grid.ColWidths[COLORS_COL_SAMPLE], 'Sample gave up exactly what Text took' + where);
      CheckEquals(grid.ClientWidth, SumOfColumnWidths(grid), 'still no gap' + where);

      (* What ColorGridHeaderSized does, for each kind of column. *)
      SaveGridColumnWidth(grid, COLORS_GRID_COLUMNS_NAME, COLORS_COLUMN_TOKENS, COLORS_COL_SAMPLE);
      CheckEquals(0, PendingColumnWidths.EntryCount, 'a Sample width is never marked');
      SaveGridColumnWidth(grid, COLORS_GRID_COLUMNS_NAME, COLORS_COLUMN_TOKENS, COLORS_COL_FG);
      w := 0;
      CheckTrue(PendingColumnWidths.TryGetWidth(COLORS_GRID_COLUMNS_NAME, 'Text', w),
         'a Text width is marked under the grid name and its token');
      CheckEquals(grid.ScaleFormTo96(grid.ColWidths[COLORS_COL_FG]), w, 'at 96 dpi');
      CheckEquals(1, PendingColumnWidths.EntryCount, 'and nothing else');
   finally
      (* Nothing here may reach the settings file. *)
      PendingColumnWidths.Clear;
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
   Test_Grid_ColumnsFillTheGridAtAnyWidth;
   Test_Grid_HeaderDragResizesAndHiddenColumnsStayHidden;
   Test_Grid_ADraggedWidthComesBackInAFreshGrid;
   Test_ColoursGrid_SampleFillsTheRowAndIsNotKept;
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
