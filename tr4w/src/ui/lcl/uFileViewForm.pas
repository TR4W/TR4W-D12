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
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uFileViewForm;
{$I ..\..\tr4w.inc}

(*
  THE FILE VIEWER, AS AN LCL FORM.

  It shows the file TR4W just wrote -- a Cabrillo log, a summary sheet, a
  report -- and offers to open it in the operator's editor, show it in
  Explorer, copy it, or mail it to the contest sponsor.

  A TMemo REPLACES A RICHEDIT, and that removes a whole subsystem rather than
  porting it.  The old window created a RICHED32 control, built an _editstream
  record with a callback, and pushed the file through EM_STREAMIN with SF_TEXT
  -- a rich-text control used exclusively to display PLAIN TEXT.  Everything it
  needed goes with it: the stream record, the TEditStreamCallBack type, the
  OpenCallback that wrapped ReadFile, the SF_/EM_ constants, and the
  RichEditOperation refcount this window took on RICHED32.DLL.
  RichEditOperation itself stays -- the MMTTY window is its other user.

  THE MENU IS DESIGNED, its captions are not.  E_MENU_ARRAY's text became
  resourcestrings on 2026-08-27 precisely because NY4I saw this menu
  untranslated, so retyping the English into the .lfm would undo that -- which
  is the trap CLAUDE.md records for every conversion up to 2026-08-29.  The
  .lfm text is a placeholder and HandleShow assigns the real captions from the
  same constants the Win32 menu used.

  IT IS A VIEWER, SO THE MEMO IS READ-ONLY AND FIXED-PITCH.  Cabrillo is a
  column format and a proportional face makes it unreadable; by PITCH rather
  than by naming a font, for the reason in uAltPForm's header.
*)

interface

uses
   Classes,
   SysUtils,
   Forms,
   Controls,
   StdCtrls,
   Menus,
   uTR4WStrings;

type
   { PUBLISHED for streaming: a control binds to a field only when the field is
     published and its name matches the component's Name, and an event binds
     only when the handler is a published method, because TWriter stores it BY
     NAME.  Both directions are checked by Lint-FormFields, which gates the
     build. }
   TfrmFileView = class(TForm)
      memView: TMemo;
      mnuMain: TMainMenu;
      mnuFile: TMenuItem;
      mnuOpenInEditor: TMenuItem;
      mnuExplore: TMenuItem;
      mnuSendLog: TMenuItem;
      mnuSep1: TMenuItem;
      mnuExit: TMenuItem;
      mnuEdit: TMenuItem;
      mnuCopy: TMenuItem;
      mnuSelectAll: TMenuItem;

      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var Action: TCloseAction);
      procedure HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
      procedure OpenInEditorClick(Sender: TObject);
      procedure ExploreClick(Sender: TObject);
      procedure SendLogClick(Sender: TObject);
      procedure ExitClick(Sender: TObject);
      procedure CopyClick(Sender: TObject);
      procedure SelectAllClick(Sender: TObject);
   private
      procedure ApplyCaptions;
      procedure LoadPreviewFile;
   end;

// The full-log viewer.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.  This body changed when the dialog became an LCL form
// and nothing at any call site did.
procedure ShowFileViewWindow;

implementation

{$R *.lfm}

uses
   Graphics,
   LCLType,               { VK_ESCAPE }
   VC,                    { Contest, ContestsArray }
   PostUnit,              { PreviewFileNameAddress, PreviewFileIsCabrillo }
   uFileView,             { SendMail -- the MAPI half, which is not a window }
   uMenu,                 { OpenInDefaultTextEditor, RunExplorer }
   uLCLFormHelpers,       { ApplyContentMinimumSize, ShowModalOverWin32Parent }
   uHostedFormWindows,
   MainUnit,              { logger }
   Log4D;

var
   GForm: TfrmFileView = nil;

{ The file being shown.  A PAnsiChar global set by whichever export just ran;
  nil is possible if the window is opened before one has. }
function PreviewFileName: AnsiString;
begin
   if PreviewFileNameAddress = nil then
      begin
      Result := '';
      end
   else
      begin
      Result := AnsiString(PreviewFileNameAddress);
      end;
end;

procedure TfrmFileView.ApplyCaptions;
begin
   { FROM THE CONSTANTS, not from the designer.  These are the same
     resourcestrings E_MENU_ARRAY carries, so the menu stays translated -- it
     is the menu NY4I found in English on 2026-08-27, and typing the words
     into the .lfm would put it straight back there. }
   mnuFile.Caption         := RC_FILE;
   mnuOpenInEditor.Caption := TC_EDITOR_OPENINEDITOR;
   mnuExplore.Caption      := TC_EDITOR_EXPLORE;
   mnuExit.Caption         := RC_EXIT;
   mnuEdit.Caption         := TC_EDITOR_EDIT;

   { The accelerator text is gone from the caption on purpose.  The Win32 menu
     appended #9'Ctrl+C' by hand; a TMenuItem with a ShortCut draws that itself,
     and a hand-typed copy would be a second place to keep it right. }
   mnuCopy.Caption      := TC_EDITOR_COPY;
   mnuSelectAll.Caption := TC_EDITOR_SELECTALL;

   { Only a Cabrillo file can be mailed to a sponsor, and only when the contest
     table names one.  Hidden rather than greyed: an item offering to send a log
     to nobody says nothing useful. }
   mnuSendLog.Visible := PreviewFileIsCabrillo and
                         (ContestsArray[Contest].Email <> nil);
   if mnuSendLog.Visible then
      begin
      mnuSendLog.Caption := AnsiString(SysUtils.Format(TC_EDITOR_SENDLOGTO,
                               [AnsiString(ContestsArray[Contest].Email)]));
      end;
end;

procedure TfrmFileView.LoadPreviewFile;
var
   name: AnsiString;
begin
   memView.Lines.Clear;

   name := PreviewFileName;
   if (name = '') or (not FileExists(string(name))) then
      begin
      { SAID, not shown as an empty window.  The old code opened the file in a
        WM_TIMER handler and simply Exit'ed when tOpenFileForRead failed, so a
        missing file looked exactly like an empty one. }
      if logger <> nil then
         begin
         logger.Warn('[FileView] nothing to show: ' + string(name));
         end;
      Exit;
      end;

   { AnsiString, unconverted: TStrings.LoadFromFile takes the LCL's own string
     type and handing it this unit's UnicodeString would narrow at the call. }
   memView.Lines.LoadFromFile(name);
end;

procedure TfrmFileView.HandleShow(Sender: TObject);
begin
   RegisterHostedFormHandle(Self.Handle);

   ApplyCaptions;

   { The window is titled with the file it is showing, as SetWindowTextA did. }
   Caption := PreviewFileName;

   { Cabrillo is a column format; a proportional face makes it unreadable. }
   memView.Font.Pitch := fpFixed;

   LoadPreviewFile;

   ApplyContentMinimumSize(Self);

   { REPORTED, so a harness can see it -- see Test-CabrilloSummary and the
     Alt-P precedent: a converted window that opens correctly and shows nothing
     is invisible to the corpus, the unit tests and every lint. }
   if logger <> nil then
      begin
      logger.Debug(SysUtils.Format('[FileView] %d line(s), cabrillo=%s, file=%s',
                      [memView.Lines.Count, BoolToStr(PreviewFileIsCabrillo, True),
                       string(PreviewFileName)]));
      end;
end;

procedure TfrmFileView.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   { The Win32 WM_CLOSE arm did exactly this before EndDialog: the flag is
     about the file just previewed, not about the window. }
   PreviewFileIsCabrillo := False;

   { Released rather than kept: a report can be megabytes, and the viewer is
     opened once at the end of an export.  The Win32 dialog was destroyed on
     close and took its RichEdit with it. }
   memView.Lines.Clear;

   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

procedure TfrmFileView.HandleKeyDown(Sender: TObject; var Key: word;
                                     Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure TfrmFileView.OpenInEditorClick(Sender: TObject);
begin
   // Issue #986 -- the system default text editor, not Notepad.
   OpenInDefaultTextEditor(PreviewFileNameAddress);
end;

procedure TfrmFileView.ExploreClick(Sender: TObject);
begin
   RunExplorer(PreviewFileNameAddress);
end;

procedure TfrmFileView.SendLogClick(Sender: TObject);
begin
   SendMail(ContestsArray[Contest].Email, False);
end;

procedure TfrmFileView.ExitClick(Sender: TObject);
begin
   Close;
end;

procedure TfrmFileView.CopyClick(Sender: TObject);
begin
   memView.CopyToClipboard;
end;

procedure TfrmFileView.SelectAllClick(Sender: TObject);
begin
   memView.SelectAll;
end;

procedure ShowFileViewWindow;
begin
   { The try/except is permanent and deliberate: under FPC an exception that
     escapes into the main loop is a bare RTE with no class, and it takes the
     contest log down with it.  Logging the phase is what makes such a report
     actionable. }
   try
      if GForm = nil then
         begin
         GForm := TfrmFileView.Create(Application);
         end;
      ShowModalOverWin32Parent(GForm, 0);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowFileViewWindow failed: ' + E.ClassName + ': ' +
                         E.Message);
            end;
         end;
   end;
end;

end.
