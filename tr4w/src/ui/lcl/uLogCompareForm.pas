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
unit uLogCompareForm;
{$I ..\..\tr4w.inc}

{
  THE LOG COMPARISON DIALOG, AS AN LCL FORM.  Phase 4b.

  Shown when a multi-op client's log does not match the server's: size, record
  count, CRC32, the unsent-QSO counters and the contest, server against local.
  From here the operator can synchronize, clear every log, or walk away.

  A LATENT BUG IS FIXED BY THE CONVERSION, not despite it.

  `OpenGetServerLogDlg` -- the flag saying "the operator pressed Synchronize, so
  open the server-log dialog after this one closes" -- was a LOCAL VARIABLE OF
  THE DlgProc. A DlgProc is called once per message, so the flag existed only
  for the duration of one call. That works when Synchronize is pressed, because
  its arm sets the flag and then `goto ExitAndClose` lands in the WM_CLOSE arm
  WITHIN THE SAME CALL.

  It does not work when the window is closed any other way. A WM_CLOSE arriving
  on its own reads the flag UNINITIALISED -- whatever was on the stack -- and a
  non-zero value opens the server-log dialog nobody asked for.

  The commented-out `// OpenGetServerLogDlg := False;` at the end of
  WM_INITDIALOG shows someone saw the symptom and reached for the obvious fix.
  It would not have worked either: initialising a local in one call says nothing
  about its value in the next.

  Here it is a field, set False in OnShow and True only by the Synchronize
  button, so it means what it says however the form is closed.
}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ComCtrls, LCLType,
  VC;   // PLogFileInformation -- named in the class declaration below, so it
        // belongs in the INTERFACE uses, not the implementation one

type
  TfrmLogCompare = class(TForm)
    lvCompare: TListView;
    btnSynchronize: TButton;
    btnClearAllLogs: TButton;
    btnExit: TButton;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure btnSynchronizeClick(Sender: TObject);
    procedure btnClearAllLogsClick(Sender: TObject);
    procedure btnExitClick(Sender: TObject);
  private
    FInfo: PLogFileInformation;
    FOpenServerLogDlg: boolean;
    procedure AddRow(const aLabel, aServer, aLocal: string);
  end;

// the log-comparison dialog.  Two call sites in uNet pass the same shape.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.
procedure ShowLogCompare(const aInitParam: lParam);

implementation

{$R *.lfm}

uses
  uLCLFormHelpers,   // ShowModalOverWin32Parent -- ownership and centring
  Windows,
  TF,               // tDialogBox -- the server-log dialog is still Win32
  PostUnit,         // Contest, ContestExchange
  LogDupe,
  uNet,             // DifferentContests, tUSQ, tUSQE
  uGetServerLog,    // GetServerLogDlgProc -- still a Win32 dialog
  MainUnit,         // OpenLogFile / CloseLogFile, ProcessMenu, logger
  uHostedFormWindows,
  Log4D;

var
  frmLogCompare: TfrmLogCompare = nil;

procedure TfrmLogCompare.AddRow(const aLabel, aServer, aLocal: string);
var
  item: TListItem;
begin
   item := lvCompare.Items.Add;
   item.Caption := aLabel;
   item.SubItems.Add(aServer);
   item.SubItems.Add(aLocal);
end;

procedure TfrmLogCompare.HandleShow(Sender: TObject);
var
  col: TListColumn;
begin
   RegisterHostedFormHandle(Self.Handle);

   Caption                := RC_DIFFINLOG;
   btnSynchronize.Caption := string(RC_SYNCHRONIZE);
   btnClearAllLogs.Caption := string(RC_CLEARALLLOGS);
   btnExit.Caption        := string(EXIT_WORD);

   // FALSE HERE, and this is the whole of the fix described in the unit header:
   // a field set on every opening, rather than a local read uninitialised.
   FOpenServerLogDlg := False;

   // The original opened and immediately closed the log file before drawing
   // anything, and bailed out if it could not.  Preserved: it is a liveness
   // check on the local log, and drawing a comparison against a log that cannot
   // be opened would be worse than showing nothing.
   if not OpenLogFile then
      begin
      Close;
      Exit;
      end;
   CloseLogFile;

   lvCompare.Items.BeginUpdate;
   try
      lvCompare.Items.Clear;
      lvCompare.Columns.Clear;

      col := lvCompare.Columns.Add;
      col.Caption := '';
      col.Width   := 130;

      col := lvCompare.Columns.Add;
      col.Caption := string(TC_SERVERLOG);
      col.Width   := 150;

      col := lvCompare.Columns.Add;
      col.Caption := string(TC_LOCALLOG);
      col.Width   := 150;

      if FInfo = nil then
         begin
         Exit;
         end;

      AddRow(string(TC_SIZEBYTES),
             IntToStr(FInfo^.liServerLogSize),
             IntToStr(FInfo^.liLocalLogSize));

      // The record count discounts one: the log's first record is a header.
      AddRow(string(TC_RECORDS),
             IntToStr(FInfo^.liServerLogSize div SizeOf(ContestExchange) - 1),
             IntToStr(FInfo^.liLocalLogSize div SizeOf(ContestExchange) - 1));

      AddRow('CRC32',
             '0x' + LowerCase(Format('%x', [integer(FInfo^.liSeverCRC32)])),
             '0x' + LowerCase(Format('%x', [integer(FInfo^.liLocalCRC32)])));

      // USQ and USQE are LOCAL-only counters -- the server column stays blank,
      // as it did.
      AddRow('USQ',  '', IntToStr(tUSQ));
      AddRow('USQE', '', IntToStr(tUSQE));

      AddRow('Contest',
             string(ContestTypeSA[FInfo^.liContest]),
             string(ContestTypeSA[Contest]));

      // SYNCHRONIZING ACROSS DIFFERENT CONTESTS IS THE ONE THING THIS DIALOG
      // MUST NOT ALLOW -- it would merge one contest's QSOs into another's log.
      // DUMMYCONTEST is the server not having told us yet, which is not a
      // mismatch.
      DifferentContests := FInfo^.liContest <> Contest;
      if FInfo^.liContest = DUMMYCONTEST then
         begin
         DifferentContests := False;
         end;

      btnSynchronize.Enabled := not DifferentContests;
   finally
      lvCompare.Items.EndUpdate;
   end;
end;

procedure TfrmLogCompare.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;

   // AFTER this window has gone, as before: the original called EndDialog and
   // only then opened the server-log dialog.
   if FOpenServerLogDlg then
      begin
      FOpenServerLogDlg := False;
      tDialogBox(73, @GetServerLogDlgProc);
      end;
end;

procedure TfrmLogCompare.btnSynchronizeClick(Sender: TObject);
begin
   FOpenServerLogDlg := True;
   Close;
end;

procedure TfrmLogCompare.btnClearAllLogsClick(Sender: TObject);
begin
   ProcessMenu(menu_clearserverlog);
   Close;
end;

procedure TfrmLogCompare.btnExitClick(Sender: TObject);
begin
   Close;
end;

procedure ShowLogCompare(const aInitParam: lParam);
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmLogCompare = nil then
         begin
         frmLogCompare := TfrmLogCompare.Create(Application);
         end;

      // The init param IS the server's log information -- uNet passes the
      // record's address through the dialog's lParam.
      frmLogCompare.FInfo := PLogFileInformation(aInitParam);
      // THROUGH THE ONE DOOR, parent 0.  There is no raw Win32 parent to
      // disable here, but ShowModalOverWin32Parent is also where the main
      // window is made the owner and the form is centred over it -- see
      // OwnFormByMainWindow.  A bare ShowModal skips both.
      ShowModalOverWin32Parent(frmLogCompare, 0);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowLogCompare failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
