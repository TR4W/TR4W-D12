unit uExternalLoggerGrid;
(* THE PREFERENCES > EXTERNAL LOGGER GRID IS THE EDITOR (issue 220).

   One row per definition: Order, Logger, Provider, Send new QSOs, and a hidden
   Id column. The Id lives in the grid because a dragged row carries its cells
   with it, so the row always knows which definition it is; there is no
   parallel list of ids to fall out of step.

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
uses Classes, SysUtils, Controls, Forms, Grids, Menus, uExternalLoggerConfig;
const
   LOGGER_COL_ORDER    = 0;
   LOGGER_COL_NAME     = 1;
   LOGGER_COL_PROVIDER = 2;
   LOGGER_COL_SEND     = 3;
   LOGGER_COL_ID       = 4;
type
   TExternalLoggerGrid = class(TComponent)
   private
      FGrid: TStringGrid;
      FConfig: TExternalLoggerConfig;
      FPopup: TPopupMenu;
      FEditItem, FSendItem, FUpItem, FDownItem, FRemoveItem: TMenuItem;
      FOnChanged: TNotifyEvent;
      FMovedId: string;
      function AddItem(const aCaption: string; aHandler: TNotifyEvent): TMenuItem;
      function IdAt(aRow: integer): string;
      function NeighbourInSameGroup(aDelta: integer): boolean;
      procedure Changed;
      procedure GridMouseDown(aSender: TObject; aButton: TMouseButton;
         aShift: TShiftState; aX, aY: integer);
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
      function SelectedId: string;
      function AddLogger: boolean;
      procedure EditSelected;
      procedure ToggleSendSelected;
      procedure MoveSelected(aDelta: integer);
      procedure RemoveSelected(aAsk: boolean = True);
      property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
   end;

implementation
uses Dialogs, uAppStrings, uExternalLoggersForm;

constructor TExternalLoggerGrid.Create(aOwner: TComponent; const aGrid: TStringGrid);
begin
   inherited Create(aOwner);
   FGrid := aGrid;
   FGrid.ColCount := 5;
   FGrid.FixedCols := 1;
   FGrid.FixedRows := 1;
   FGrid.Options := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine,
      goRowSelect, goRowMoving];
   FGrid.ColWidths[LOGGER_COL_ORDER] := 60;
   FGrid.ColWidths[LOGGER_COL_NAME] := 235;
   FGrid.ColWidths[LOGGER_COL_PROVIDER] := 145;
   FGrid.ColWidths[LOGGER_COL_SEND] := 180;
   FGrid.ColWidths[LOGGER_COL_ID] := 0;
   FGrid.OnColRowMoved := RowMoved;
   FGrid.OnMouseDown := GridMouseDown;
   FGrid.OnDblClick := GridDblClick;
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
   Application.RemoveAsyncCalls(Self);
   inherited Destroy;
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
   FGrid.Cells[LOGGER_COL_NAME, 0] := UTF8Encode(SLoggerGridLogger);
   FGrid.Cells[LOGGER_COL_PROVIDER, 0] := UTF8Encode(SLoggerGridProvider);
   FGrid.Cells[LOGGER_COL_SEND, 0] := UTF8Encode(SLoggerGridSend);
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
            FGrid.Cells[LOGGER_COL_SEND, i + 1] := UTF8Encode(SLoggerGridYes);
            end
         else
            begin
            FGrid.Cells[LOGGER_COL_ORDER, i + 1] := '-';
            FGrid.Cells[LOGGER_COL_SEND, i + 1] := UTF8Encode(SLoggerGridNo);
            end;
         FGrid.Cells[LOGGER_COL_NAME, i + 1] := UTF8Encode(definition.Name);
         FGrid.Cells[LOGGER_COL_PROVIDER, i + 1] := UTF8Encode(definition.ProviderId);
         FGrid.Cells[LOGGER_COL_ID, i + 1] := AnsiString(definition.Id);
         if (aSelectId <> '') and (definition.Id = aSelectId) then
            begin
            selectRow := i + 1;
            end;
         end;
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
   FGrid.Row := row;
   if col = LOGGER_COL_SEND then
      begin
      ToggleSendSelected;
      end
   else
      begin
      EditSelected;
      end;
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
