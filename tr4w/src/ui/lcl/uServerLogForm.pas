{
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
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uServerLogForm;
{$I ..\..\tr4w.inc}

{
  THE SERVER-LOG SYNCHRONIZE DIALOG, AS AN LCL FORM.

  Dialog 73, and THE LAST Win32 dialog template in the program. It downloads the
  multi-op server's log over a second socket, shows it arriving, and offers to
  replace the local log with it. Reached from the log-comparison form's
  Synchronize button.

  THE LIST IS A TLogGrid (2026-09-06), AND THE REASON IT WAS NOT HAD EXPIRED.

  This said the list was "the shared EDITABLE LOG control -- CreateEditableLog,
  the same one the main window uses -- and that control is deliberately
  deferred until the log moves to SQLite: about 150 ListView_* call sites
  depend on its handle, 19 of them on the editable log itself". NY4I,
  2026-09-06: "This does not make much sense. sqlite is already the database."

  He was right, and every clause of it was false by then:

    * The main window's log is a TLogGrid and both edit windows are forms, so
      CreateEditableLog had ONE live caller -- this one. Nothing was shared and
      nothing would have forked.
    * SQLite IS the store. docs/SQLITE_MIGRATION_TASKS.md: "B4 IS DONE. Every
      log READ goes through uLogSource and the default is the database."
    * ListView_* was 34 mentions across 13 files, FOUR of them live, all inside
      CreateEditableLog itself. Not 150.

  And the deferral never applied here in the first place: this window does not
  show the CONTEST log. It shows the multi-op server's log, downloaded over a
  second socket into TR4W_SYN_FILENAME. Where the local log lives is beside the
  point.

  THE GRID IS VIRTUAL BECAUSE THE FILLER IS A WORKER THREAD. RunSyncThread put
  rows in one at a time with ListView_InsertItem, which was safe by accident;
  an LCL control cannot be touched off the main thread. So the worker fills a
  preallocated array (uGetServerLog) and the grid asks for the rows it paints.
  Read the note on the row store there before changing either half.

  THE CAPTIONS COME FROM THE RC_ CONSTANTS, NOT FROM THE .lfm.

  This is the trap every earlier conversion fell into. The Win32 code assigned
  captions from RC_/TC_ constants, which is what the catalogues translate; a
  designed form carries its caption in the .lfm, and re-typing the English there
  leaves the translation unreachable with nothing to warn you. Measured
  2026-08-26: 469 .lfm captions ship as English in every language.

  So the .lfm text is a DESIGNER PLACEHOLDER and HandleShow overwrites all of
  it. These six RC_ names had never been translatable at all -- their text
  reached the screen from the compiled .RES, so pas2res deliberately left them
  out (see its header). Naming them from Pascal here is what promotes them: the
  generator emits every RC_ a source file references, so they enter
  uTR4WStrings and then the catalogues on the next regeneration.

  ALL THIRTEEN CONTROLS ARE HERE. The 'sent records' field (111/112) looks dead
  from this unit -- nothing in uGetServerLog writes it -- and its writer is in a
  different unit again: uNet.CommitChangesInLocalLog, which RunSyncThread calls
  before it opens the socket. Worth remembering as a general caution about
  Win32 dialogs: a control id is written by SetDlgItemInt from ANYWHERE that
  has the window handle, so "grep this unit" is not how you find out whether a
  field is live. The compiler found this one.

  Its English caption was 'Sended records:'; corrected to 'Sent records:' in the
  same change, which is free exactly once -- the string had never been
  translatable, so no catalogue is orphaned by editing the msgid. After the
  next harvest it would not have been.

  ON THE WORKER THREAD. RunSyncThread is a raw thread and it reports progress
  while this form is open. It does NOT touch these controls: it calls
  uGetServerLog.ReportSyncProgress, which SendMessage's to this form's handle,
  and Windows marshals that onto the main thread before the handler runs. That
  is the same mechanism the headless path already used, and it is why the
  handler may assign an LCL property directly. Do not "simplify" it into a
  direct call.
}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, LCLType,
  (* Messages was here for TMessage, which the class declaration no longer
    names -- the sync progress arrives as an LCL event now (2026-09-08). *)
  uGetServerLog,   // WM_USER_SYNC_PROGRESS -- a `message` directive is part of
                   // the class DECLARATION, so its constant has to resolve in
                   // the interface; this cannot move to the implementation uses
  uLogGrid,        // TLogGrid and TLogGridRow -- both named in the class
                   // declaration below, so this cannot move down either
  uTR4WStrings;

type
  TfrmServerLog = class(TForm)
    lblQSOsCaption: TLabel;
    lblQSOs: TLabel;
    lblBytesCaption: TLabel;
    lblBytes: TLabel;
    lblRecordsCaption: TLabel;
    lblRecords: TLabel;
    lblSentCaption: TLabel;
    lblSent: TLabel;
    btnGetLog: TButton;
    btnCreateNewLog: TButton;
    chkShowContent: TCheckBox;
    btnClose: TButton;
    pnlLog: TPanel;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure btnGetLogClick(Sender: TObject);
    procedure btnCreateNewLogClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure chkShowContentChange(Sender: TObject);
  private
    FReplaceLog: boolean;
    { The downloaded server log.  Built in code rather than in the .lfm: TLogGrid
      is not a registered designer component, and the main window's log is built
      the same way. }
    FLog: TLogGrid;
    procedure BuildLogGrid;
    procedure LogFetchRows(Sender: TObject; const aFirstIndex: Int64;
                           var aRows: array of TLogGridRow);
    { Progress from the download thread.  See the note on the worker thread in
      the unit header: this arrives via SendMessage and therefore runs on the
      main thread. }
    procedure ApplySyncProgress(const aField, aValue: integer);
  end;

{ Opens the dialog modally.  THE SEAM: the caller does not know what this is,
  only that the window opens -- the same shape as ShowLogCompare. }
procedure ShowServerLogSync;

implementation

{$R *.lfm}

uses
  (* Windows was here for CreateFileA / CloseHandle / GetLastError on the
    sync file; all three are SysUtils' now. *)
  uLCLFormHelpers,    // ShowModalOverWin32Parent -- ownership and centring
  VC,                 // TR4W_SYN_FILENAME
  TF,                 // tCreateThread
  MainUnit,           // LogRowTextFor, logger
  Log4D;

var
  frmServerLog: TfrmServerLog = nil;

(* FORWARD: HandleShow installs this, and it is defined beside the method it
  delegates to, further down. *)
procedure ApplyServerLogSyncProgress(aField: integer; aValue: integer); forward;

procedure TfrmServerLog.HandleShow(Sender: TObject);
begin
   // EVERY caption, from the constants the catalogues translate.  The .lfm text
   // is a designer placeholder -- see the unit header.
   Caption                    := string(RC_SYNLOG2);
   lblQSOsCaption.Caption     := string(RC_RECVQSOS);
   lblBytesCaption.Caption    := string(RC_RECVBYTES);
   lblRecordsCaption.Caption  := string(RC_RECVRECORDS);
   lblSentCaption.Caption     := string(RC_SENDRECORDS);
   btnGetLog.Caption          := string(RC_GETSERVLOG);
   btnCreateNewLog.Caption    := string(RC_CREATEAUNL);
   chkShowContent.Caption     := string(RC_SHOWSERVLOGC);
   btnClose.Caption           := string(CLOSE_WORD);

   FReplaceLog := False;

   lblQSOs.Caption    := '0';
   lblBytes.Caption   := '0';
   lblRecords.Caption := '0';
   lblSent.Caption    := '0';

   btnCreateNewLog.Enabled := False;
   chkShowContent.Checked  := showresverlogcontent;

   AmountQSOsFromServer := 0;
   FillChar(SynQSOTotalArray, SizeOf(SynQSOTotalArray), 0);

   BuildLogGrid;

   // The thread reports here.  Set LAST, so a report cannot arrive before the
   // controls it names have been initialised.
   SyncProgressHandler := @ApplyServerLogSyncProgress;
end;

procedure TfrmServerLog.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   // FIRST, and before anything is torn down: the worker may still be running,
   // and a report arriving after this point must find no window to talk to
   // rather than a half-destroyed one.  ReportSyncProgress is a no-op on 0.
   SyncProgressHandler := nil;

   if NewServerLogHandle <> INVALID_HANDLE_VALUE then
      begin
      FileClose(NewServerLogHandle);
      NewServerLogHandle := INVALID_HANDLE_VALUE;
      end;

   // AFTER the window is gone, as the dialog did: the original replaced the log
   // from its WM_COMMAND arm and then fell into the close path.  Doing it here
   // keeps that order -- LoadinLog repaints the main window's own log, and it
   // should not do that behind a dialog that is about to vanish.
   if FReplaceLog then
      begin
      FReplaceLog := False;
      ReplaceLogByServerLog(True);
      end;

   Action := caHide;
end;

(* THE GRID, PARENTED TO THE PANEL. The panel reserves the space in the
  designer, so the grid cannot land on top of a button, and aligning to it
  means the grid follows when the form is resized.

  lgsFitAndFill rather than the main window's declared widths: this window is
  resizable and has no layout computed around the log's column widths, so
  leaving a band of empty grid down the right-hand side would be the defect
  NY4I named on 2026-09-04.

  Wired INSIDE the class, unqualified: Lint-FormEvents does not count a dotted
  name as wiring, because that is also how an implementation header is spelled. *)
procedure TfrmServerLog.BuildLogGrid;
begin
   if FLog <> nil then
      begin
      Exit;
      end;

   FLog := TLogGrid.Create(Self);
   FLog.Parent      := pnlLog;
   FLog.Align       := alClient;
   FLog.Sizing      := lgsFitAndFill;
   FLog.OnFetchRows := LogFetchRows;
   FLog.BuildColumns;
end;

(* ONE RUN OF ROWS, FROM THE ARRAY THE DOWNLOAD THREAD FILLED.

  LogRowTextFor is the same routine the main window's log and the export use,
  so the server's log is read in the columns the operator already knows. The
  X-QSO and deleted flags come back with the row rather than being asked for
  separately -- they are properties of the QSO, not of the display, which is
  what lets the grid grey a row without the per-item lParam smuggling the list
  view needed. *)
procedure TfrmServerLog.LogFetchRows(Sender: TObject; const aFirstIndex: Int64;
                                     var aRows: array of TLogGridRow);
var
   i:   integer;
   rec: ContestExchange;
begin
   for i := Low(aRows) to High(aRows) do
      begin
      aRows[i].Valid := TryGetServerLogRow(aFirstIndex + (i - Low(aRows)), rec);
      if not aRows[i].Valid then
         begin
         Continue;
         end;

      LogRowTextFor(rec, aRows[i].Text);
      aRows[i].Deleted := rec.ceQSO_Deleted;
      aRows[i].XQSO    := rec.ceXQSO;
      end;
end;

(* THE UNIT-LEVEL WRAPPER the worker calls.

  SyncProgressHandler is a plain procedure type, because the worker thread has
  no object to call. This is the one place that knows the form exists, and it
  runs on the main thread -- uGetServerLog.ReportSyncProgress marshals. *)
procedure ApplyServerLogSyncProgress(aField: integer; aValue: integer);
begin
   if frmServerLog <> nil then
      begin
      frmServerLog.ApplySyncProgress(aField, aValue);
      end;
end;

procedure TfrmServerLog.ApplySyncProgress(const aField, aValue: integer);
begin
   case aField of
      SYNC_FIELD_RECORDS:
         begin
         lblRecords.Caption := IntToStr(aValue);
         (* AND THIS IS WHERE THE GRID LEARNS HOW MUCH THERE IS. The worker
           reports every ten records; telling the grid here is what makes the
           rows appear as they arrive, and it is the ONLY count the grid is
           given -- so it can never ask for a row the worker has not written.
           See the row store in uGetServerLog. *)
         if (FLog <> nil) and showresverlogcontent then
            begin
            FLog.RecordCount := aValue;
            end;
         end;
      SYNC_FIELD_BYTES:
         begin
         lblBytes.Caption := IntToStr(aValue);
         end;
      SYNC_FIELD_QSOS:
         begin
         lblQSOs.Caption := IntToStr(aValue);
         end;
      SYNC_FIELD_SENT:
         begin
         lblSent.Caption := IntToStr(aValue);
         end;
      SYNC_FIELD_ENABLE_REPLACE:
         begin
         btnCreateNewLog.Enabled := True;
         end;
   end;
end;

procedure TfrmServerLog.btnGetLogClick(Sender: TObject);
begin
   SyncMode := True;
   btnGetLog.Enabled := False;

   { FileCreate is CREATE_ALWAYS -- create or truncate -- and returns -1
     where CreateFileA returned INVALID_HANDLE_VALUE. }
   NewServerLogHandle := FileCreate(TR4W_SYN_FILENAME);
   if NewServerLogHandle = THandle(-1) then
      begin
      // REPORTED, not a silent close.  The dialog used `goto CloseLabel` here,
      // so a log file that could not be created looked exactly like the
      // operator pressing Close.
      logger.Error('Server-log sync: cannot create %s (error %d)',
                   [string(TR4W_SYN_FILENAME), SysUtils.GetLastOSError]);
      Close;
      Exit;
      end;

   if not ThreadStarted(LogSyncThreadID) then
      begin
      tCreateThread(@RunSyncThread, LogSyncThreadID);
      logger.Info('Created LogSync thread with threadid of %d', [LogSyncThreadID]);
      end;
end;

procedure TfrmServerLog.btnCreateNewLogClick(Sender: TObject);
begin
   FReplaceLog := True;
   Close;
end;

procedure TfrmServerLog.btnCloseClick(Sender: TObject);
begin
   Close;
end;

procedure TfrmServerLog.chkShowContentChange(Sender: TObject);
begin
   showresverlogcontent := chkShowContent.Checked;
end;

procedure ShowServerLogSync;
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmServerLog = nil then
         begin
         frmServerLog := TfrmServerLog.Create(Application);
         end;
      ShowModalOverWin32Parent(frmServerLog);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowServerLogSync failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
