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
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
*)
unit uServerLogForm;
{$I ..\..\tr4w.inc}

(*
  THE SERVER-LOG SYNCHRONIZE WINDOW, AS AN LCL FORM.

  Dialog 73, and THE LAST Win32 dialog template in the program. It downloads the
  multi-op server's log over a second socket, shows it arriving, and ADDS the
  QSOs this log lacks. Reached from Net > Synchronize.

  IT NO LONGER REPLACES ANYTHING (Phase 1, C6, 2026-10-27). In D7 the second
  button was "Create and use new log": it copied the downloaded file over the
  .TRW, so every QSO only this station held was gone. Now it is
  uGetServerLog.AddServerLogToLog: INSERT ONLY, a verified backup first, one
  transaction, a rescore after. The rules are uNetCatchUp's header. The Difference-
  in-logs dialog that used to open this window (a CRC32 comparison of two .TRW
  files) is gone with the comparison.

  THE LIST IS A TLogGrid (2026-09-06), AND THE REASON IT WAS NOT HAD EXPIRED.

  This said the list was "the shared EDITABLE LOG control -- CreateEditableLog,
  the same one the main window uses -- and that control is deliberately
  deferred until the log moves to SQLite: about 150 ListView_* call sites
  depend on its handle, 19 of them on the editable log itself". NY4I,
  2026-09-06: "This does not make much sense. sqlite is already the database."

  He was right, and every clause of it was false by then. And the deferral never
  applied here in the first place: this window does not show the CONTEST log.
  It shows the multi-op server's log, downloaded over a second socket.

  THE GRID IS VIRTUAL, AND ITS ROWS ARE THE DOWNLOAD. The worker thread fills a
  memory image (uNetCatchUp.TServerLogImage) and hands it over whole; the grid
  asks for the rows it paints through uGetServerLog.TryGetServerLogRow, on the
  main thread, and is told how many exist when the download is complete. Read
  the note there before changing either half.

  THE CAPTIONS COME FROM THE RC_ CONSTANTS, NOT FROM THE .lfm.

  This is the trap every earlier conversion fell into. The Win32 code assigned
  captions from RC_/TC_ constants, which is what the catalogues translate; a
  designed form carries its caption in the .lfm, and re-typing the English there
  leaves the translation unreachable with nothing to warn you. Measured
  2026-08-26: 469 .lfm captions ship as English in every language.

  So the .lfm text is a DESIGNER PLACEHOLDER and HandleShow overwrites all of
  it. The two captions this change adds are resourcestrings (uAppStrings).

  ON THE WORKER THREAD. The download is a raw thread and it reports progress
  while this form is open. It does NOT touch these controls: it calls
  uGetServerLog.ReportSyncProgress, which queues the report to the main thread,
  where SyncProgressHandler runs. Do not "simplify" it into a direct call.
*)

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, LCLType,
  uLogGrid,        (* TLogGrid and TLogGridRow -- both named in the class
                     declaration below, so this cannot move down *)
  uTR4WStrings;

type
  TfrmServerLog = class(TForm)
    lblQSOsCaption: TLabel;
    lblQSOs: TLabel;
    lblBytesCaption: TLabel;
    lblBytes: TLabel;
    lblRecordsCaption: TLabel;
    lblRecords: TLabel;
    btnGetLog: TButton;
    btnAddMissing: TButton;
    chkShowContent: TCheckBox;
    btnClose: TButton;
    pnlLog: TPanel;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure btnGetLogClick(Sender: TObject);
    procedure btnAddMissingClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure chkShowContentChange(Sender: TObject);
  private
    FAddMissing: boolean;
    (* The downloaded server log.  Built in code rather than in the .lfm: TLogGrid
      is not a registered designer component, and the main window's log is built
      the same way. *)
    FLog: TLogGrid;
    procedure BuildLogGrid;
    procedure LogFetchRows(Sender: TObject; const aFirstIndex: Int64;
                           var aRows: array of TLogGridRow);
    (* Progress from the download thread.  See the note on the worker thread in
      the unit header: this arrives queued and therefore runs on the main
      thread. *)
    procedure ApplySyncProgress(const aField, aValue: integer);
  end;

(* Opens the dialog modally.  THE SEAM: the caller does not know what this is,
  only that the window opens. *)
procedure ShowServerLogSync;

implementation

{$R *.lfm}

uses
  uLCLFormHelpers,    // ShowModalOverWin32Parent -- ownership and centring
  uGetServerLog,      // the download, the rows, the merge, the progress seam
  uAppStrings,        // SServerLogAdd, SServerLogAddMissing
  MainUnit,           // LogRowTextFor, logger
  uContestRegistry,   // LoggedQSOIsXQSO -- a row greys an X-QSO (Q98 S1)
  VC,                 // ContestExchange
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
   btnGetLog.Caption          := string(RC_GETSERVLOG);
   btnAddMissing.Caption      := SServerLogAdd;
   chkShowContent.Caption     := string(RC_SHOWSERVLOGC);
   btnClose.Caption           := string(CLOSE_WORD);

   FAddMissing := False;

   lblQSOs.Caption    := '0';
   lblBytes.Caption   := '0';
   lblRecords.Caption := '0';

   btnGetLog.Enabled     := True;
   btnAddMissing.Enabled := False;
   chkShowContent.Checked := showresverlogcontent;

   BuildLogGrid;
   // An earlier download is gone (HandleClose released it): show none.
   FLog.RecordCount := 0;

   // The thread reports here.  Set LAST, so a report cannot arrive before the
   // controls it names have been initialised.
   SyncProgressHandler := @ApplyServerLogSyncProgress;
end;

procedure TfrmServerLog.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   // FIRST, and before anything is torn down: the worker may still be running,
   // and a report arriving after this point must find no window to talk to
   // rather than a half-destroyed one.  ReportSyncProgress is a no-op on nil.
   SyncProgressHandler := nil;

   // AFTER the window is gone, as the dialog did: LoadinLog repaints the main
   // window's own log, and it should not do that behind a dialog that is about
   // to vanish.  The merge is INSERT ONLY -- see the unit header.
   if FAddMissing then
      begin
      FAddMissing := False;
      if ServerLogWindowImage <> nil then
         begin
         AddServerLogToLog(ServerLogWindowImage);
         end;
      end;

   // The download belongs to the window: it goes with it.
   ReleaseServerLogImage;

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

(* ONE RUN OF ROWS, FROM THE IMAGE THE DOWNLOAD FILLED.

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
      aRows[i].XQSO    := LoggedQSOIsXQSO(rec);
      end;
end;

(* THE UNIT-LEVEL WRAPPER the worker's reports arrive at.

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
         (* THE DOWNLOAD IS WHOLE: this is reported once, on the main thread, and
           it is the ONLY count the grid is given, so it can never ask for a row
           that is not there. A fetch can be repeated now. *)
         lblRecords.Caption := IntToStr(aValue);
         btnGetLog.Enabled := True;
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
      SYNC_FIELD_ENABLE_REPLACE:
         begin
         (* aValue is how many QSOs the log lacks. *)
         btnAddMissing.Caption := SysUtils.Format(SServerLogAddMissing, [aValue]);
         btnAddMissing.Enabled := True;
         end;
      SYNC_FIELD_FAILED:
         begin
         btnGetLog.Enabled := True;
         end;
   end;
end;

procedure TfrmServerLog.btnGetLogClick(Sender: TObject);
begin
   btnGetLog.Enabled := False;
   btnAddMissing.Enabled := False;
   btnAddMissing.Caption := SServerLogAdd;
   lblBytes.Caption := '0';

   // A fetch that was not started (one is already under way, or no contest is
   // selected) must not leave the button dead.
   if not StartServerCatchUp(cuInWindow) then
      begin
      logger.Info('Server-log sync: the download was not started');
      btnGetLog.Enabled := True;
      end;
end;

procedure TfrmServerLog.btnAddMissingClick(Sender: TObject);
begin
   FAddMissing := True;
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
