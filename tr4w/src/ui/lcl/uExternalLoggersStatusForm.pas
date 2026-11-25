unit uExternalLoggersStatusForm;
(* THE EXTERNAL LOGGERS WINDOW (NY4I, 2026-11-24: "while testing this, I find
   myself constantly going into the external loggers settings page. This means
   we do need an external window which shows the status of the external
   loggers, ability to resend, and a button to edit or add new ones which opens
   the settings leaf").

   A tool window like the Band Map or HamScore: non-modal, never takes focus
   from the call window, kept in the window layout store, closed with the
   program. It is a VIEW: every fact it shows comes from somewhere that already
   answers it.

   - THE ROWS are uExternalLoggerStatusModel.BuildLoggerStatusRows over the
     SAVED configuration (the settings file, re-read when its time changes --
     the Preferences working copy's unsaved edits have different delivery ids)
     and the running program's answer (uExternalLoggerGrid.QueryExternalLoggerState,
     the same function Preferences asks). Every five seconds, and only while
     the window is showing: each state read opens a connection per row.
   - THE STATE TEXT is ExternalLoggerStateText, the Preferences grid's, so the
     two windows cannot word a state two ways; the colour is its
     ExternalLoggerStateColour, applied from OnPrepareCanvas to the State
     column (text carries the meaning; colour repeats it).
   - RESYNC is uExternalLoggerResendUI.ResyncLogger, the Preferences button's:
     the same preflight, confirmation and summary.
   - EDIT / ADD opens Preferences on the External Logger page with the selected
     logger's row selected (ShowPreferencesAtExternalLogger); the editor is the
     page's own. Double-clicking a row does the same.

   The data is IN the grid's cells (Order, Logger, Provider, Enabled, State and
   two hidden columns: the definition's id and the state's ordinal), so there
   is no list beside the control to fall out of step. *)
{$I ..\..\tr4w.inc}
interface
uses
   Classes, SysUtils, LCLType, Forms, Controls, StdCtrls, ExtCtrls, Grids,
   uRadioConfigStore, uExternalLoggerService, uExternalDelivery;
const
   EXTLOGS_COL_ORDER    = 0;
   EXTLOGS_COL_NAME     = 1;
   EXTLOGS_COL_PROVIDER = 2;
   EXTLOGS_COL_ENABLED  = 3;
   EXTLOGS_COL_STATE    = 4;
   (* The definition's id, and the state's ordinal: data, not display. *)
   EXTLOGS_COL_ID       = 5;
   EXTLOGS_COL_KIND     = 6;
   EXTLOGS_REFRESH_MS   = 5000;
   EXTLOGS_MIN_WIDTH    = 440;
   EXTLOGS_MIN_HEIGHT   = 200;
type
   TfrmExternalLoggersStatus = class(TForm)
      grdLoggers: TStringGrid;
      pnlButtons: TPanel;
      btnResync: TButton;
      btnEdit: TButton;
      btnClose: TButton;
      tmrRefresh: TTimer;
      procedure HandleCreate(Sender: TObject);
      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleResize(Sender: TObject);
      procedure HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
      procedure RefreshTick(Sender: TObject);
      procedure ResyncClick(Sender: TObject);
      procedure EditClick(Sender: TObject);
      procedure CloseClick(Sender: TObject);
      procedure GridDblClick(Sender: TObject);
      procedure GridSelection(Sender: TObject; aCol, aRow: integer);
      procedure GridPrepareCanvas(Sender: TObject; aCol, aRow: integer;
         aState: TGridDrawState);
   private
      FStore: TRadioConfigStore;
      FConfigAge: longint;
      function SelectedId: string;
      function SelectedState: TExternalLoggerState;
      procedure LoadSavedConfig(aForce: boolean);
      function QueryState(const aDeliveryId: string;
         out aSnapshot: TExternalLoggerSnapshot;
         out aCounts: TDeliveryCounts): boolean;
      procedure FitColumns;
      procedure UpdateButtons;
   public
      destructor Destroy; override;
      (* Re-reads the saved configuration if it changed, and every row's state. *)
      procedure RefreshNow;
   end;

var
   TR4WExternalLoggersForm: TfrmExternalLoggersStatus = nil;

procedure CreateTR4WExternalLoggersWindow;

implementation

{$R *.lfm}

uses
   VC,                        (* tw_EXTLOGGERSWINDOW_INDEX *)
   MainUnit,                  (* CloseTR4WWindow, FrmSetFocus, logger -- FIRST of its group *)
   Graphics, uAppStrings, uExternalLoggerConfig, uExternalLoggerStatusModel,
   uExternalLoggerGrid,       (* QueryExternalLoggerState, ExternalLoggerStateColour *)
   uExternalLoggerResendUI,   (* ResyncLogger *)
   uPrefsForm,                (* ShowPreferencesAtExternalLogger *)
   uTR4WConfigFile,           (* TR4WConfigFileName *)
   uLCLFormHelpers;           (* LeaveFormUnowned *)

destructor TfrmExternalLoggersStatus.Destroy;
begin
   FreeAndNil(FStore);
   inherited Destroy;
end;

procedure TfrmExternalLoggersStatus.HandleCreate(Sender: TObject);
begin
   (* Run-time text from uAppStrings; the .lfm text is a placeholder. *)
   Caption := UTF8Encode(SLoggersWindowTitle);
   btnResync.Caption := UTF8Encode(SLoggersWindowResync);
   btnEdit.Caption := UTF8Encode(SLoggersWindowEdit);
   btnClose.Caption := UTF8Encode(SDeliveryClose);
   grdLoggers.Cells[EXTLOGS_COL_ORDER, 0] := UTF8Encode(SLoggerGridOrder);
   grdLoggers.Cells[EXTLOGS_COL_NAME, 0] := UTF8Encode(SLoggerGridLogger);
   grdLoggers.Cells[EXTLOGS_COL_PROVIDER, 0] := UTF8Encode(SLoggerGridProvider);
   grdLoggers.Cells[EXTLOGS_COL_ENABLED, 0] := UTF8Encode(SLoggerGridEnabled);
   grdLoggers.Cells[EXTLOGS_COL_STATE, 0] := UTF8Encode(SLoggerGridState);
   grdLoggers.ColWidths[EXTLOGS_COL_ORDER] := 56;
   grdLoggers.ColWidths[EXTLOGS_COL_NAME] := 150;
   grdLoggers.ColWidths[EXTLOGS_COL_PROVIDER] := 90;
   grdLoggers.ColWidths[EXTLOGS_COL_ENABLED] := 64;
   grdLoggers.ColWidths[EXTLOGS_COL_STATE] := 200;
   grdLoggers.ColWidths[EXTLOGS_COL_ID] := 0;
   grdLoggers.ColWidths[EXTLOGS_COL_KIND] := 0;
   Constraints.MinWidth := EXTLOGS_MIN_WIDTH;
   Constraints.MinHeight := EXTLOGS_MIN_HEIGHT;
   tmrRefresh.Interval := EXTLOGS_REFRESH_MS;
end;

procedure TfrmExternalLoggersStatus.HandleShow(Sender: TObject);
begin
   LoadSavedConfig(True);
   RefreshNow;
   tmrRefresh.Enabled := True;
end;

procedure TfrmExternalLoggersStatus.HandleClose(Sender: TObject;
   var CloseAction: TCloseAction);
begin
   (* HIDE, NOT FREE -- CloseTR4WWindow owns the lifetime, and the object is
      reused when the operator opens the window again. *)
   CloseAction := caHide;
   tmrRefresh.Enabled := False;
   CloseTR4WWindow(tw_EXTLOGGERSWINDOW_INDEX);
end;

procedure TfrmExternalLoggersStatus.HandleResize(Sender: TObject);
begin
   FitColumns;
end;

(* THE STATE COLUMN TAKES WHAT THE OTHERS LEAVE, so the grid fills its window
   and a long state ("Paused: plain http not allowed ...") has the room there is.
   Never narrower than 150. *)
procedure TfrmExternalLoggersStatus.FitColumns;
var
   c, slack: integer;
begin
   slack := grdLoggers.ClientWidth;
   for c := 0 to EXTLOGS_COL_STATE - 1 do
      begin
      slack := slack - grdLoggers.ColWidths[c];
      end;
   if slack < 150 then
      begin
      slack := 150;
      end;
   grdLoggers.ColWidths[EXTLOGS_COL_STATE] := slack;
end;

(* ESCAPE CLOSES IT, as the other tool windows do. *)
procedure TfrmExternalLoggersStatus.HandleKeyDown(Sender: TObject; var Key: word;
   Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure TfrmExternalLoggersStatus.RefreshTick(Sender: TObject);
begin
   if Showing then
      begin
      RefreshNow;
      end;
end;

function TfrmExternalLoggersStatus.SelectedId: string;
var
   r: integer;
begin
   Result := '';
   r := grdLoggers.Row;
   if (r >= grdLoggers.FixedRows) and (r < grdLoggers.RowCount) then
      begin
      Result := string(grdLoggers.Cells[EXTLOGS_COL_ID, r]);
      end;
end;

function TfrmExternalLoggersStatus.SelectedState: TExternalLoggerState;
var
   kind: integer;
begin
   Result := elsIdle;
   kind := StrToIntDef(AnsiString(grdLoggers.Cells[EXTLOGS_COL_KIND, grdLoggers.Row]), -1);
   if (kind >= Ord(Low(TExternalLoggerState))) and (kind <= Ord(High(TExternalLoggerState))) then
      begin
      Result := TExternalLoggerState(kind);
      end;
end;

function TfrmExternalLoggersStatus.QueryState(const aDeliveryId: string;
   out aSnapshot: TExternalLoggerSnapshot; out aCounts: TDeliveryCounts): boolean;
begin
   Result := QueryExternalLoggerState(aDeliveryId, aSnapshot, aCounts);
end;

(* THE SAVED CONFIGURATION, re-read only when the file's time changed (reading
   it asks the OS vault for the keys, so not every five seconds). The Edit QSO
   window reads it the same way. A file that cannot be read leaves the old
   list, and says so in the log. *)
procedure TfrmExternalLoggersStatus.LoadSavedConfig(aForce: boolean);
var
   age: longint;
   fresh: TRadioConfigStore;
   error: string;
begin
   if not FileExists(TR4WConfigFileName) then
      begin
      Exit;
      end;
   age := FileAge(TR4WConfigFileName);
   if (not aForce) and (FStore <> nil) and (age = FConfigAge) then
      begin
      Exit;
      end;
   fresh := TRadioConfigStore.Create;
   if fresh.LoadFromFile(TR4WConfigFileName, error) then
      begin
      FreeAndNil(FStore);
      FStore := fresh;
      FConfigAge := age;
      end
   else
      begin
      fresh.Free;
      if logger <> nil then
         begin
         logger.Error('[ExternalLoggers] the settings file could not be read (%s); ' +
                      'the list is unchanged', [error]);
         end;
      end;
end;

procedure TfrmExternalLoggersStatus.RefreshNow;
var
   rows: TLoggerStatusRows;
   row: TLoggerStatusRow;
   i: integer;
   keepId: string;
   selectRow: integer;
   config: TExternalLoggerConfig;
begin
   LoadSavedConfig(False);
   keepId := SelectedId;
   selectRow := -1;
   config := nil;
   if FStore <> nil then
      begin
      config := FStore.ExternalLoggers;
      end;
   rows := TLoggerStatusRows.Create(True);
   grdLoggers.BeginUpdate;
   try
      BuildLoggerStatusRows(config, QueryState, rows);
      if rows.Count = 0 then
         begin
         grdLoggers.RowCount := grdLoggers.FixedRows + 1;
         grdLoggers.Rows[grdLoggers.FixedRows].Clear;
         grdLoggers.Cells[EXTLOGS_COL_NAME, grdLoggers.FixedRows] := UTF8Encode(SLoggerGridNone);
         end
      else
         begin
         grdLoggers.RowCount := grdLoggers.FixedRows + rows.Count;
         for i := 0 to rows.Count - 1 do
            begin
            row := rows[i];
            grdLoggers.Cells[EXTLOGS_COL_ORDER, grdLoggers.FixedRows + i] := UTF8Encode(row.OrderText);
            grdLoggers.Cells[EXTLOGS_COL_NAME, grdLoggers.FixedRows + i] := UTF8Encode(row.Name);
            grdLoggers.Cells[EXTLOGS_COL_PROVIDER, grdLoggers.FixedRows + i] := UTF8Encode(row.Provider);
            if row.Enabled then
               begin
               grdLoggers.Cells[EXTLOGS_COL_ENABLED, grdLoggers.FixedRows + i] := UTF8Encode(SLoggersWindowOn);
               end
            else
               begin
               grdLoggers.Cells[EXTLOGS_COL_ENABLED, grdLoggers.FixedRows + i] := UTF8Encode(SLoggersWindowOff);
               end;
            grdLoggers.Cells[EXTLOGS_COL_STATE, grdLoggers.FixedRows + i] := UTF8Encode(row.StateText);
            grdLoggers.Cells[EXTLOGS_COL_ID, grdLoggers.FixedRows + i] := UTF8Encode(row.Id);
            grdLoggers.Cells[EXTLOGS_COL_KIND, grdLoggers.FixedRows + i] :=
               AnsiString(IntToStr(Ord(row.State)));
            if (keepId <> '') and (row.Id = keepId) then
               begin
               selectRow := grdLoggers.FixedRows + i;
               end;
            end;
         if selectRow < 0 then
            begin
            selectRow := grdLoggers.FixedRows;
            end;
         grdLoggers.Row := selectRow;
         end;
   finally
      grdLoggers.EndUpdate;
      rows.Free;
   end;
   FitColumns;
   UpdateButtons;
end;

procedure TfrmExternalLoggersStatus.UpdateButtons;
var
   def: TExternalLoggerDefinition;
begin
   btnResync.Enabled := LoggerStatusCanResync(SelectedId);
   (* THE BUTTON NAMES THE LOGGER IT ACTS ON (NY4I, 2026-11-25): the selected
      row only, never the others. *)
   def := nil;
   if btnResync.Enabled and (FStore <> nil) then
      begin
      def := FStore.ExternalLoggers.Find(SelectedId);
      end;
   if def <> nil then
      begin
      btnResync.Caption := UTF8Encode(UnicodeFormat(SLoggersWindowResyncNamed, [def.Name]));
      btnResync.Hint := UTF8Encode(UnicodeFormat(SLoggersWindowResyncHint, [def.Name]));
      end
   else
      begin
      btnResync.Caption := UTF8Encode(SLoggersWindowResyncNone);
      btnResync.Hint := '';
      end;
   btnResync.ShowHint := btnResync.Hint <> '';
end;

procedure TfrmExternalLoggersStatus.GridSelection(Sender: TObject; aCol, aRow: integer);
begin
   UpdateButtons;
end;

(* The text carries the meaning; the colour repeats it, and a selected row keeps
   the theme's colours (coloured text on the selection colour is unreadable). *)
procedure TfrmExternalLoggersStatus.GridPrepareCanvas(Sender: TObject; aCol,
   aRow: integer; aState: TGridDrawState);
var
   kind: integer;
begin
   if (aCol <> EXTLOGS_COL_STATE) or (aRow < grdLoggers.FixedRows) or
      (gdSelected in aState) then
      begin
      Exit;
      end;
   kind := StrToIntDef(AnsiString(grdLoggers.Cells[EXTLOGS_COL_KIND, aRow]), -1);
   if (kind >= Ord(Low(TExternalLoggerState))) and (kind <= Ord(High(TExternalLoggerState))) then
      begin
      grdLoggers.Canvas.Font.Color := ExternalLoggerStateColour(TExternalLoggerState(kind));
      end;
end;

procedure TfrmExternalLoggersStatus.ResyncClick(Sender: TObject);
var
   id: string;
begin
   id := SelectedId;
   if (not LoggerStatusCanResync(id)) or (FStore = nil) then
      begin
      Exit;
      end;
   ResyncLogger(FStore.ExternalLoggers.Find(id), SelectedState);
   RefreshNow;
   FrmSetFocus;
end;

(* EDIT / ADD opens Preferences ON the External Logger page, the selected
   logger's row selected; the page's own grid is the editor. Preferences takes
   the focus, as it should: that is where the operator is going. *)
procedure TfrmExternalLoggersStatus.EditClick(Sender: TObject);
begin
   ShowPreferencesAtExternalLogger(SelectedId);
end;

procedure TfrmExternalLoggersStatus.GridDblClick(Sender: TObject);
begin
   if SelectedId <> '' then
      begin
      EditClick(Sender);
      end;
end;

procedure TfrmExternalLoggersStatus.CloseClick(Sender: TObject);
begin
   Close;
end;

procedure CreateTR4WExternalLoggersWindow;
begin
   if TR4WExternalLoggersForm = nil then
      begin
      TR4WExternalLoggersForm := TfrmExternalLoggersStatus.Create(nil);
      end;
   LeaveFormUnowned(TR4WExternalLoggersForm);
end;

end.
