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

  WHY THE LIST IS STILL A RAW WIN32 LISTVIEW. It is the shared EDITABLE LOG
  control -- CreateEditableLog, the same one the main window uses -- and that
  control is deliberately deferred until the log moves to SQLite: about 150
  ListView_* call sites depend on its handle, 19 of them on the editable log
  itself (docs/ROADMAP.md). Converting it here would fork it. So the form hosts
  it in pnlLog and hands out the handle, exactly as the dialog did.

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
  Messages,     // TMessage -- named in the class declaration below
  uGetServerLog,   // WM_USER_SYNC_PROGRESS -- a `message` directive is part of
                   // the class DECLARATION, so its constant has to resolve in
                   // the interface; this cannot move to the implementation uses
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
    btnHelp: TButton;
    btnClose: TButton;
    pnlLog: TPanel;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure btnGetLogClick(Sender: TObject);
    procedure btnCreateNewLogClick(Sender: TObject);
    procedure btnHelpClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure chkShowContentChange(Sender: TObject);
  private
    FReplaceLog: boolean;
    { Progress from the download thread.  See the note on the worker thread in
      the unit header: this arrives via SendMessage and therefore runs on the
      main thread. }
    procedure WMSyncProgress(var aMsg: TMessage); message WM_USER_SYNC_PROGRESS;
  end;

{ Opens the dialog modally.  THE SEAM: the caller does not know what this is,
  only that the window opens -- the same shape as ShowLogCompare. }
procedure ShowServerLogSync;

implementation

{$R *.lfm}

uses
  Windows,
  uLCLFormHelpers,    // ShowModalOverWin32Parent -- ownership and centring
  VC,                 // TR4W_SYN_FILENAME
  TF,                 // tCreateThread
  MainUnit,           // CreateEditableLog, ShowHelp, logger
  Log4D;

var
  frmServerLog: TfrmServerLog = nil;

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
   btnHelp.Caption            := string(HELP_WORD);
   btnClose.Caption           := string(CLOSE_WORD);

   FReplaceLog := False;

   lblQSOs.Caption    := '0';
   lblBytes.Caption   := '0';
   lblRecords.Caption := '0';
   lblSent.Caption    := '0';

   btnCreateNewLog.Enabled := False;
   chkShowContent.Checked  := showresverlogcontent;

   AmountQSOsFromServer := 0;
   Windows.ZeroMemory(@SynQSOTotalArray, SizeOf(SynQSOTotalArray));

   // The editable log, hosted rather than converted.  Parented to the PANEL,
   // not to the form: a panel has a real window handle and reserves the space
   // in the designer, so the raw child cannot land on top of a button.
   ServerLogListView := CreateEditableLog(pnlLog.Handle, 0, 0,
                                          pnlLog.Width, pnlLog.Height, True);

   // The thread reports here.  Set LAST, so a report cannot arrive before the
   // controls it names have been initialised.
   ServerLogFormWnd := Self.Handle;
end;

procedure TfrmServerLog.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   // FIRST, and before anything is torn down: the worker may still be running,
   // and a report arriving after this point must find no window to talk to
   // rather than a half-destroyed one.  ReportSyncProgress is a no-op on 0.
   ServerLogFormWnd := 0;

   if NewServerLogHandle <> INVALID_HANDLE_VALUE then
      begin
      CloseHandle(NewServerLogHandle);
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

procedure TfrmServerLog.WMSyncProgress(var aMsg: TMessage);
begin
   case aMsg.WParam of
      SYNC_FIELD_RECORDS:
         begin
         lblRecords.Caption := IntToStr(aMsg.LParam);
         end;
      SYNC_FIELD_BYTES:
         begin
         lblBytes.Caption := IntToStr(aMsg.LParam);
         end;
      SYNC_FIELD_QSOS:
         begin
         lblQSOs.Caption := IntToStr(aMsg.LParam);
         end;
      SYNC_FIELD_SENT:
         begin
         lblSent.Caption := IntToStr(aMsg.LParam);
         end;
      SYNC_FIELD_ENABLE_REPLACE:
         begin
         btnCreateNewLog.Enabled := True;
         end;
   end;
   aMsg.Result := 0;
end;

procedure TfrmServerLog.btnGetLogClick(Sender: TObject);
begin
   SyncMode := True;
   btnGetLog.Enabled := False;

   NewServerLogHandle := CreateFileA(TR4W_SYN_FILENAME,
                                     GENERIC_READ or GENERIC_WRITE,
                                     FILE_SHARE_READ or FILE_SHARE_WRITE,
                                     nil, CREATE_ALWAYS,
                                     FILE_ATTRIBUTE_ARCHIVE, 0);
   if NewServerLogHandle = INVALID_HANDLE_VALUE then
      begin
      // REPORTED, not a silent close.  The dialog used `goto CloseLabel` here,
      // so a log file that could not be created looked exactly like the
      // operator pressing Close.
      logger.Error('Server-log sync: cannot create %s (error %d)',
                   [string(TR4W_SYN_FILENAME), Windows.GetLastError]);
      Close;
      Exit;
      end;

   if LogSyncThreadID = 0 then
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

procedure TfrmServerLog.btnHelpClick(Sender: TObject);
begin
   // QUALIFIED: TControl publishes a parameterless ShowHelp, so an unqualified
   // call inside a form method resolves to the LCL's and fails on the argument.
   MainUnit.ShowHelp('rulogsynchronize');
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
      ShowModalOverWin32Parent(frmServerLog, 0);
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
