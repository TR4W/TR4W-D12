unit uExternalLoggerGrid;
(* THE PREFERENCES > EXTERNAL LOGGER GRID IS THE EDITOR (issue 220).

   One row per definition: Order, Logger, Provider, Enabled (a checkbox), the
   connection State, and two hidden columns, Id and the state's ordinal. They
   live in the grid because a dragged row carries its cells with it, so the
   row always knows which definition it is and which colour it paints; there is
   no parallel list to fall out of step.

   ENABLED IS THE SEND-NEW-QSOS FLAG, ONE FACT IN ONE PLACE (issue 226): the
   checkbox, the popup item and the editor's Active box all call
   TExternalLoggerConfig.SetActive, so Order (a dash = off) cannot disagree
   with the box. The LCL draws the box from the cell's text ('1'/'0'); the
   click is ours, because the LCL's own toggle needs goEditing and writes the
   cell before the model has had its say. A change reaches the Preferences
   working copy only; Save writes it and a RESTART applies it -- the running
   composite (uExternalLoggers) is immutable by design, so the State column
   says "Restart TR4W to apply" until then.

   THE STATE COLUMN is read-only text, derived by DeriveExternalLoggerState
   from a snapshot of the running service (OnQueryState, set by the owner) and
   refreshed by a timer every few seconds, never per paint. The colour is
   OnPrepareCanvas reading the hidden ordinal; the text carries the meaning, so
   colour is never the only signal.

   The model is the TExternalLoggerConfig handed to Bind (the Preferences
   working copy). Every change goes through that class, then the grid is
   rewritten from it, so the grid never holds a fact the model does not.

   Dragging is the LCL's own: goRowMoving, grabbed by the FIXED column (here the
   Order cell -- the LCL only starts a row move from a fixed column), reported
   by OnColRowMoved. Move up / Move down in the popup call the grid's own
   MoveColRow, so they take exactly the path a drag takes.

   Active loggers show first, in delivery order; inactive ones follow. A row
   dropped across that line snaps back to its group on the rewrite. *)
{$I ..\..\tr4w.inc}
interface
uses Classes, SysUtils, Controls, Forms, Grids, Menus, ExtCtrls, Graphics,
   uExternalLoggerConfig, uExternalLoggerService, uExternalDelivery;
const
   LOGGER_COL_ORDER     = 0;
   LOGGER_COL_NAME      = 1;
   LOGGER_COL_PROVIDER  = 2;
   LOGGER_COL_ENABLED   = 3;
   LOGGER_COL_STATE     = 4;
   LOGGER_COL_ID        = 5;
   LOGGER_COL_STATEKIND = 6;
   (* How often the State column is re-read. A few seconds: each read opens
      one read-only connection per row. *)
   LOGGER_STATE_REFRESH_MS = 5000;
type
   (* The owner's window onto the running program: the snapshot of the service
      running aDeliveryId (False when there is none) and that destination's
      durable queue counts (zero when no log is open). Main thread. *)
   TLoggerStateQuery = function(const aDeliveryId: string;
      out aSnapshot: TExternalLoggerSnapshot;
      out aCounts: TDeliveryCounts): boolean of object;

   TExternalLoggerGrid = class(TComponent)
   private
      FGrid: TStringGrid;
      FConfig: TExternalLoggerConfig;
      FPopup: TPopupMenu;
      FEditItem, FSendItem, FUpItem, FDownItem, FRemoveItem: TMenuItem;
      FOnChanged: TNotifyEvent;
      FOnQueryState: TLoggerStateQuery;
      FTimer: TTimer;
      FMovedId: string;
      FDownCol, FDownRow: integer;
      FSwallowUp: boolean;
      function AddItem(const aCaption: string; aHandler: TNotifyEvent): TMenuItem;
      function IdAt(aRow: integer): string;
      function NeighbourInSameGroup(aDelta: integer): boolean;
      procedure Changed;
      procedure SetOnQueryState(aValue: TLoggerStateQuery);
      procedure StateTick(aSender: TObject);
      procedure PrepareStateColour(aSender: TObject; aCol, aRow: integer;
         aState: TGridDrawState);
      procedure GridMouseDown(aSender: TObject; aButton: TMouseButton;
         aShift: TShiftState; aX, aY: integer);
      procedure GridMouseUp(aSender: TObject; aButton: TMouseButton;
         aShift: TShiftState; aX, aY: integer);
      procedure GridKeyDown(aSender: TObject; var aKey: word; aShift: TShiftState);
      procedure GridDblClick(aSender: TObject);
      procedure RowMoved(aSender: TObject; aIsColumn: boolean; aFromIndex, aToIndex: integer);
      procedure ReselectMoved(aData: PtrInt);
      procedure PopupOpening(aSender: TObject);
      procedure EditClick(aSender: TObject);
      procedure SendClick(aSender: TObject);
      procedure UpClick(aSender: TObject);
      procedure DownClick(aSender: TObject);
      procedure RemoveClick(aSender: TObject);
   public
      constructor Create(aOwner: TComponent; const aGrid: TStringGrid); reintroduce;
      destructor Destroy; override;
      procedure Bind(const aConfig: TExternalLoggerConfig);
      (* Rewrite every row from the model; aSelectId (if any) is selected. *)
      procedure Refresh(const aSelectId: string = '');
      (* Rewrites only the State cells (text and ordinal) from the running
         service. Never touches the rows, the selection or the model. *)
      procedure RefreshStates;
      function SelectedId: string;
      function AddLogger: boolean;
      procedure EditSelected;
      procedure ToggleSendSelected;
      procedure MoveSelected(aDelta: integer);
      procedure RemoveSelected(aAsk: boolean = True);
      property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
      (* Setting it starts the refresh timer; nil stops it. *)
      property OnQueryState: TLoggerStateQuery read FOnQueryState write SetOnQueryState;
   end;

(* The colour a state paints in. Text carries the meaning; this repeats it. *)
function ExternalLoggerStateColour(aState: TExternalLoggerState): TColor;

implementation
uses Dialogs, LCLType, uAppStrings, uExternalLoggersForm;

function ExternalLoggerStateColour(aState: TExternalLoggerState): TColor;
begin
   case aState of
      elsDisabled:
         begin
         Result := clGrayText;
         end;
      elsRestartNeeded:
         begin
         Result := RGBToColor(170, 95, 0);
         end;
      elsIdle:
         begin
         Result := RGBToColor(0, 120, 0);
         end;
      elsSending:
         begin
         Result := RGBToColor(0, 70, 200);
         end;
      elsRetrying:
         begin
         Result := RGBToColor(190, 110, 0);
         end;
      elsPaused:
         begin
         Result := RGBToColor(150, 60, 0);
         end;
      elsFailed:
         begin
         Result := RGBToColor(190, 0, 0);
         end;
   else
      begin
      Result := clWindowText;
      end;
   end;
end;

(* The text for a state. The reason is a fixed delivery code, never server
   text. Old uncertain or failed rows ride along as counts. *)
function StateText(aState: TExternalLoggerState;
   const aSnapshot: TExternalLoggerSnapshot; const aCounts: TDeliveryCounts): string;
var
   code: string;
begin
   code := aSnapshot.Code;
   if code = '' then
      begin
      code := 'UNSPECIFIED';
      end;
   case aState of
      elsDisabled:
         begin
         Result := SLoggerStateDisabled;
         end;
      elsRestartNeeded:
         begin
         Result := SLoggerStateRestart;
         end;
      elsIdle:
         begin
         Result := SLoggerStateIdle;
         end;
      elsSending:
         begin
         Result := UnicodeFormat(SLoggerStateSending,
            [aCounts.Pending + aCounts.InFlight + aSnapshot.QueueDepth]);
         end;
      elsRetrying:
         begin
         Result := UnicodeFormat(SLoggerStateRetrying, [code]);
         end;
      elsPaused:
         begin
         Result := UnicodeFormat(SLoggerStatePaused, [code]);
         end;
      elsFailed:
         begin
         Result := UnicodeFormat(SLoggerStateFailed, [code]);
         end;
   else
      begin
      Result := '';
      end;
   end;
   if (aState in [elsIdle, elsSending, elsRetrying, elsPaused, elsFailed]) and
      ((aCounts.Uncertain > 0) or (aCounts.Failed > 0)) then
      begin
      Result := UnicodeFormat(SLoggerStateCounts,
         [Result, aCounts.Uncertain, aCounts.Failed]);
      end;
end;

constructor TExternalLoggerGrid.Create(aOwner: TComponent; const aGrid: TStringGrid);
var
   i: integer;
begin
   inherited Create(aOwner);
   FGrid := aGrid;
   FDownCol := -1;
   FDownRow := -1;
   FGrid.FixedCols := 1;
   FGrid.FixedRows := 1;
   FGrid.Options := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine,
      goRowSelect, goRowMoving];
   (* The Order column is the FIXED one (a row drag starts there) and is not a
      TGridColumn; the six columns after it are, because a checkbox is a column
      property. *)
   FGrid.Columns.Clear;
   for i := LOGGER_COL_NAME to LOGGER_COL_STATEKIND do
      begin
      FGrid.Columns.Add;
      FGrid.Columns[i - 1].ReadOnly := True;
      end;
   FGrid.Columns[LOGGER_COL_ENABLED - 1].ButtonStyle := cbsCheckboxColumn;
   FGrid.Columns[LOGGER_COL_ENABLED - 1].ValueChecked := '1';
   FGrid.Columns[LOGGER_COL_ENABLED - 1].ValueUnchecked := '0';
   FGrid.Columns[LOGGER_COL_ENABLED - 1].Alignment := taCenter;
   FGrid.ColWidths[LOGGER_COL_ORDER] := 60;
   FGrid.ColWidths[LOGGER_COL_NAME] := 190;
   FGrid.ColWidths[LOGGER_COL_PROVIDER] := 110;
   FGrid.ColWidths[LOGGER_COL_ENABLED] := 70;
   FGrid.ColWidths[LOGGER_COL_STATE] := 200;
   FGrid.ColWidths[LOGGER_COL_ID] := 0;
   FGrid.ColWidths[LOGGER_COL_STATEKIND] := 0;
   FGrid.OnColRowMoved := RowMoved;
   FGrid.OnMouseDown := GridMouseDown;
   FGrid.OnMouseUp := GridMouseUp;
   FGrid.OnKeyDown := GridKeyDown;
   FGrid.OnDblClick := GridDblClick;
   FGrid.OnPrepareCanvas := PrepareStateColour;
   FTimer := TTimer.Create(Self);
   FTimer.Enabled := False;
   FTimer.Interval := LOGGER_STATE_REFRESH_MS;
   FTimer.OnTimer := StateTick;
   FPopup := TPopupMenu.Create(Self);
   FPopup.OnPopup := PopupOpening;
   FEditItem := AddItem(SLoggerGridEdit, EditClick);
   FSendItem := AddItem(SLoggerGridSend, SendClick);
   FSendItem.AutoCheck := False;
   FUpItem := AddItem(SLoggerGridMoveUp, UpClick);
   FDownItem := AddItem(SLoggerGridMoveDown, DownClick);
   FRemoveItem := AddItem(SLoggerGridRemove, RemoveClick);
   FGrid.PopupMenu := FPopup;
end;

destructor TExternalLoggerGrid.Destroy;
begin
   (* A queued reselect must not outlive the grid. *)
   FTimer.Enabled := False;
   Application.RemoveAsyncCalls(Self);
   inherited Destroy;
end;

procedure TExternalLoggerGrid.SetOnQueryState(aValue: TLoggerStateQuery);
begin
   FOnQueryState := aValue;
   FTimer.Enabled := Assigned(aValue);
end;

(* Only while the page is on screen: a hidden Preferences page has nobody to
   tell, and each read opens a connection per row. *)
procedure TExternalLoggerGrid.StateTick(aSender: TObject);
begin
   if FGrid.Showing then
      begin
      RefreshStates;
      end;
end;

procedure TExternalLoggerGrid.PrepareStateColour(aSender: TObject; aCol, aRow: integer;
   aState: TGridDrawState);
var
   kind: integer;
begin
   if (aCol <> LOGGER_COL_STATE) or (aRow < FGrid.FixedRows) or (gdSelected in aState) then
      begin
      Exit;
      end;
   (* A selected row keeps the theme's colours: coloured text on the selection
      colour is unreadable, and the text says the same thing. *)
   kind := StrToIntDef(AnsiString(FGrid.Cells[LOGGER_COL_STATEKIND, aRow]), -1);
   if (kind >= Ord(Low(TExternalLoggerState))) and (kind <= Ord(High(TExternalLoggerState))) then
      begin
      FGrid.Canvas.Font.Color := ExternalLoggerStateColour(TExternalLoggerState(kind));
      end;
end;

procedure TExternalLoggerGrid.RefreshStates;
var
   row: integer;
   definition: TExternalLoggerDefinition;
   snapshot: TExternalLoggerSnapshot;
   counts: TDeliveryCounts;
   known: boolean;
   state: TExternalLoggerState;
begin
   if FConfig = nil then
      begin
      Exit;
      end;
   for row := FGrid.FixedRows to FGrid.RowCount - 1 do
      begin
      definition := FConfig.Find(IdAt(row));
      if definition = nil then
         begin
         FGrid.Cells[LOGGER_COL_STATE, row] := '';
         FGrid.Cells[LOGGER_COL_STATEKIND, row] := '';
         Continue;
         end;
      snapshot := Default(TExternalLoggerSnapshot);
      counts := Default(TDeliveryCounts);
      known := Assigned(FOnQueryState) and
         FOnQueryState(definition.DeliveryId, snapshot, counts);
      state := DeriveExternalLoggerState(FConfig.ActivePosition(definition.Id) > 0,
         known, snapshot, counts);
      FGrid.Cells[LOGGER_COL_STATE, row] := UTF8Encode(StateText(state, snapshot, counts));
      FGrid.Cells[LOGGER_COL_STATEKIND, row] := AnsiString(IntToStr(Ord(state)));
      end;
end;

function TExternalLoggerGrid.AddItem(const aCaption: string; aHandler: TNotifyEvent): TMenuItem;
begin
   Result := TMenuItem.Create(FPopup);
   Result.Caption := UTF8Encode(aCaption);
   Result.OnClick := aHandler;
   FPopup.Items.Add(Result);
end;

procedure TExternalLoggerGrid.Bind(const aConfig: TExternalLoggerConfig);
begin
   FConfig := aConfig;
end;

function TExternalLoggerGrid.IdAt(aRow: integer): string;
begin
   Result := '';
   if (aRow >= FGrid.FixedRows) and (aRow < FGrid.RowCount) then
      begin
      Result := string(FGrid.Cells[LOGGER_COL_ID, aRow]);
      end;
end;

function TExternalLoggerGrid.SelectedId: string;
begin
   Result := IdAt(FGrid.Row);
end;

procedure TExternalLoggerGrid.Changed;
begin
   if Assigned(FOnChanged) then
      begin
      FOnChanged(Self);
      end;
end;

procedure TExternalLoggerGrid.Refresh(const aSelectId: string);
var
   ids: TStringList;
   definition: TExternalLoggerDefinition;
   position, i, selectRow: integer;
begin
   FGrid.Cells[LOGGER_COL_ORDER, 0] := UTF8Encode(SLoggerGridOrder);
   FGrid.Columns[LOGGER_COL_NAME - 1].Title.Caption := UTF8Encode(SLoggerGridLogger);
   FGrid.Columns[LOGGER_COL_PROVIDER - 1].Title.Caption := UTF8Encode(SLoggerGridProvider);
   FGrid.Columns[LOGGER_COL_ENABLED - 1].Title.Caption := UTF8Encode(SLoggerGridEnabled);
   FGrid.Columns[LOGGER_COL_STATE - 1].Title.Caption := UTF8Encode(SLoggerGridState);
   ids := TStringList.Create;
   try
      selectRow := FGrid.Row;
      if FConfig <> nil then
         begin
         FConfig.DisplayOrder(ids);
         end;
      if ids.Count = 0 then
         begin
         FGrid.RowCount := 2;
         FGrid.Rows[1].Clear;
         FGrid.Cells[LOGGER_COL_NAME, 1] := UTF8Encode(SLoggerGridNone);
         Exit;
         end;
      FGrid.RowCount := ids.Count + 1;
      for i := 0 to ids.Count - 1 do
         begin
         definition := FConfig.Find(string(ids[i]));
         position := FConfig.ActivePosition(definition.Id);
         if position > 0 then
            begin
            FGrid.Cells[LOGGER_COL_ORDER, i + 1] := AnsiString(IntToStr(position));
            FGrid.Cells[LOGGER_COL_ENABLED, i + 1] := '1';
            end
         else
            begin
            FGrid.Cells[LOGGER_COL_ORDER, i + 1] := '-';
            FGrid.Cells[LOGGER_COL_ENABLED, i + 1] := '0';
            end;
         FGrid.Cells[LOGGER_COL_NAME, i + 1] := UTF8Encode(definition.Name);
         FGrid.Cells[LOGGER_COL_PROVIDER, i + 1] := UTF8Encode(definition.ProviderId);
         FGrid.Cells[LOGGER_COL_ID, i + 1] := AnsiString(definition.Id);
         if (aSelectId <> '') and (definition.Id = aSelectId) then
            begin
            selectRow := i + 1;
            end;
         end;
      RefreshStates;
      if selectRow < 1 then
         begin
         selectRow := 1;
         end;
      if selectRow >= FGrid.RowCount then
         begin
         selectRow := FGrid.RowCount - 1;
         end;
      FGrid.Row := selectRow;
   finally
      ids.Free;
   end;
end;

function TExternalLoggerGrid.AddLogger: boolean;
begin
   Result := (FConfig <> nil) and EditExternalLoggerDefinition(FConfig, '');
   if Result then
      begin
      Changed;
      Refresh(FConfig.Definitions[FConfig.Definitions.Count - 1].Id);
      end;
end;

procedure TExternalLoggerGrid.EditSelected;
var
   id: string;
begin
   id := SelectedId;
   if (FConfig <> nil) and (FConfig.Find(id) <> nil) and
      EditExternalLoggerDefinition(FConfig, id) then
      begin
      Changed;
      Refresh(id);
      end;
end;

procedure TExternalLoggerGrid.ToggleSendSelected;
var
   id: string;
   wasActive: boolean;
begin
   id := SelectedId;
   if (FConfig = nil) or (FConfig.Find(id) = nil) then
      begin
      Exit;
      end;
   wasActive := FConfig.ActivePosition(id) > 0;
   FConfig.SetActive(id, not wasActive);
   (* Switching ON takes the editor's checks, so the grid cannot activate what
      the editor would refuse. Switching off needs none. *)
   if (not wasActive) and not ExternalLoggerConfigAcceptable(FConfig) then
      begin
      FConfig.SetActive(id, False);
      (* The box was just clicked on; put it back to what the model says. *)
      Refresh(id);
      Exit;
      end;
   Changed;
   Refresh(id);
end;

function TExternalLoggerGrid.NeighbourInSameGroup(aDelta: integer): boolean;
var
   here, there: string;
begin
   here := SelectedId;
   there := IdAt(FGrid.Row + aDelta);
   Result := (FConfig <> nil) and (here <> '') and (there <> '') and
      ((FConfig.ActivePosition(here) > 0) = (FConfig.ActivePosition(there) > 0));
end;

procedure TExternalLoggerGrid.MoveSelected(aDelta: integer);
begin
   if NeighbourInSameGroup(aDelta) then
      begin
      (* The grid's own move: it fires OnColRowMoved, which writes the model. *)
      FGrid.MoveColRow(False, FGrid.Row, FGrid.Row + aDelta);
      end;
end;

procedure TExternalLoggerGrid.RowMoved(aSender: TObject; aIsColumn: boolean;
   aFromIndex, aToIndex: integer);
var
   ids: TStringList;
   i: integer;
   moved: string;
begin
   if aIsColumn or (FConfig = nil) then
      begin
      Exit;
      end;
   moved := IdAt(aToIndex);
   ids := TStringList.Create;
   try
      for i := FGrid.FixedRows to FGrid.RowCount - 1 do
         begin
         if IdAt(i) <> '' then
            begin
            ids.Add(AnsiString(IdAt(i)));
            end;
         end;
      if FConfig.ApplyOrder(ids) then
         begin
         Changed;
         end;
   finally
      ids.Free;
   end;
   (* Rewritten even when nothing changed: a row dropped across the active /
      inactive line must snap back. Only cells are written, never RowCount or
      the selection: the grid is still finishing its own move, and AFTER this
      event it re-maps the selected row through the move, so a Row assigned
      here is moved a second time. The selection is put right once the grid is
      done (ReselectMoved). *)
   Refresh;
   FMovedId := moved;
   Application.RemoveAsyncCalls(Self);
   Application.QueueAsyncCall(ReselectMoved, 0);
end;

procedure TExternalLoggerGrid.ReselectMoved(aData: PtrInt);
begin
   if FMovedId <> '' then
      begin
      Refresh(FMovedId);
      FMovedId := '';
      end;
end;

procedure TExternalLoggerGrid.RemoveSelected(aAsk: boolean);
var
   id: string;
begin
   id := SelectedId;
   if (FConfig = nil) or (FConfig.Find(id) = nil) then
      begin
      Exit;
      end;
   if aAsk and (MessageDlg(UTF8Encode(SLoggerGridRemoveAsk), mtConfirmation,
      [mbYes, mbNo], 0) <> mrYes) then
      begin
      Exit;
      end;
   FConfig.RemoveDefinition(id);
   Changed;
   Refresh;
end;

procedure TExternalLoggerGrid.GridMouseDown(aSender: TObject; aButton: TMouseButton;
   aShift: TShiftState; aX, aY: integer);
var
   col, row: integer;
begin
   (* The LCL does not move the selection on a right click; the popup acts on
      the selected row, so make it the row under the pointer. *)
   if aButton = mbRight then
      begin
      FGrid.MouseToCell(aX, aY, col, row);
      if row >= FGrid.FixedRows then
         begin
         FGrid.Row := row;
         end;
      end
   else if aButton = mbLeft then
      begin
      (* Remember where the press began: the box is toggled on RELEASE, and
         only if it is released on the cell it was pressed on. *)
      FGrid.MouseToCell(aX, aY, FDownCol, FDownRow);
      end;
end;

(* THE CHECKBOX CLICK. On release, not on press: toggling can move the row
   between the active and the inactive group, and the grid has finished its
   own press handling by now. *)
procedure TExternalLoggerGrid.GridMouseUp(aSender: TObject; aButton: TMouseButton;
   aShift: TShiftState; aX, aY: integer);
var
   col, row: integer;
begin
   if FSwallowUp then
      begin
      FSwallowUp := False;
      Exit;
      end;
   if aButton <> mbLeft then
      begin
      Exit;
      end;
   FGrid.MouseToCell(aX, aY, col, row);
   if (col = LOGGER_COL_ENABLED) and (row >= FGrid.FixedRows) and
      (col = FDownCol) and (row = FDownRow) and (IdAt(row) <> '') then
      begin
      FGrid.Row := row;
      ToggleSendSelected;
      end;
   FDownCol := -1;
   FDownRow := -1;
end;

procedure TExternalLoggerGrid.GridKeyDown(aSender: TObject; var aKey: word;
   aShift: TShiftState);
begin
   if (aKey = VK_SPACE) and (aShift = []) and (SelectedId <> '') then
      begin
      aKey := 0;
      ToggleSendSelected;
      end;
end;

procedure TExternalLoggerGrid.GridDblClick(aSender: TObject);
var
   p: TPoint;
   col, row: integer;
begin
   p := FGrid.ScreenToClient(Mouse.CursorPos);
   FGrid.MouseToCell(p.X, p.Y, col, row);
   if row < FGrid.FixedRows then
      begin
      Exit;
      end;
   if col = LOGGER_COL_ENABLED then
      begin
      (* The press before this already toggled. The release after it must not
         toggle again: the row it would hit may no longer be the same logger. *)
      FSwallowUp := True;
      Exit;
      end;
   FGrid.Row := row;
   EditSelected;
end;

procedure TExternalLoggerGrid.PopupOpening(aSender: TObject);
var
   id: string;
   known: boolean;
begin
   id := SelectedId;
   known := (FConfig <> nil) and (FConfig.Find(id) <> nil);
   FEditItem.Enabled := known;
   FSendItem.Enabled := known;
   FSendItem.Checked := known and (FConfig.ActivePosition(id) > 0);
   FUpItem.Enabled := NeighbourInSameGroup(-1);
   FDownItem.Enabled := NeighbourInSameGroup(1);
   FRemoveItem.Enabled := known;
end;

procedure TExternalLoggerGrid.EditClick(aSender: TObject);
begin
   EditSelected;
end;

procedure TExternalLoggerGrid.SendClick(aSender: TObject);
begin
   ToggleSendSelected;
end;

procedure TExternalLoggerGrid.UpClick(aSender: TObject);
begin
   MoveSelected(-1);
end;

procedure TExternalLoggerGrid.DownClick(aSender: TObject);
begin
   MoveSelected(1);
end;

procedure TExternalLoggerGrid.RemoveClick(aSender: TObject);
begin
   RemoveSelected;
end;

end.
