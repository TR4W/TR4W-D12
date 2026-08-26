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

{ THE MMTTY WINDOW, as an LCL form.

  THE LAST Win32 tool window.  With this one converted, no tw_ window is a
  dialog any more.

  IT KEEPS A WIN32 RICHEDIT INSIDE IT, AND THAT IS A DECISION, NOT AN OVERSIGHT.

  The colour in this window is not decoration.  mmttyProcessChar selects the
  callsign it has just decoded and applies CFE_BOLD, then crTextColor $000000FF
  -- RED -- when CallIsADupe says so, so an operator watching the decode sees a
  dupe flagged in the stream.  The LCL has no rich-text control in core, and
  this Lazarus has no TRichMemo.  A TMemo would mean deleting that behaviour to
  improve a lint count, which is the wrong trade.

  NY4I settled it: "MMTTY is strictly a Windows program. Doesn't that dictate
  that Windows is permissible here. Whatever we end up with for RTTY on Mac and
  Linux will have their own specifications."  That is right, and it is a
  stronger argument than portability-by-habit: this window HOSTS an
  out-of-process Windows executable, so there is no cross-platform version of
  it to protect.  A Linux RTTY path will be a different engine with its own
  display, not this window ported.

  So the FORM is LCL -- which is what the migration actually targets -- and one
  CHILD CONTROL stays Win32.  A RichEdit is a standard Windows control, not a
  Win32 dialog, and hosting one in a form is a different thing from keeping a
  dialog procedure.

  THE RICHEDIT IS BUILT ON EVERY SHOW, not once.  CloseTR4WWindow calls
  DestroyWindow on the form's handle, so the child goes with it and the next
  open gets a NEW handle from the LCL.  Creating it once and caching the handle
  would leave a dangling child after the first close -- the same lifetime trap
  that made caNone leave five windows unclosable. }
unit uMMTTYForm;

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, LCLType, Forms, Controls;

type
   TfrmMMTTY = class(TForm)
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleShow(Sender: TObject);
      procedure HandleResize(Sender: TObject);
      procedure HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
   end;

var
   TR4WMMTTYForm: TfrmMMTTY = nil;

function CreateTR4WMMTTYWindow: HWND;

implementation

{$R *.lfm}

uses
   Windows,           { MoveWindow / SendMessage -- the hosted RichEdit }
   VC,                { tw_MMTTYWINDOW_INDEX }
   TF,                { CreateRichEdit }
   MainUnit,          { CloseTR4WWindow, RichEditOperation }
   uPlatformProcess,  { RunWindowsUtility -- the only launcher, see MainUnit:49 }
   uMMTTY,            { the MMTTY record and its protocol }
   uLCLFormHelpers;   { OwnFormByMainWindow }

function CreateTR4WMMTTYWindow: HWND;
begin
   if TR4WMMTTYForm = nil then
      begin
      TR4WMMTTYForm := TfrmMMTTY.Create(Application);
      end;

   OwnFormByMainWindow(TR4WMMTTYForm);
   Result := TR4WMMTTYForm.Handle;
end;

{ WHAT WM_INITDIALOG DID.

  MMTTY is launched here rather than at start-up because the window opening IS
  the request for it, and HandleClose posts RXM_EXIT -- open and close stay
  symmetric, exactly as the dialog had it. }
procedure TfrmMMTTY.HandleShow(Sender: TObject);
begin
   // MMTTY is a Windows program and out-of-process, so it stays on the
   // Windows-utility route rather than pretending to be portable.  The path is
   // quoted because this IS a command line -- the one shape RunProgram's
   // argument list cannot express.
   //   -t  FFT spectrum, waterfall and XY scope
   //   -s  control menus as well
   //   -u  control buttons
   //   -r  control menus in addition to the above
   RunWindowsUtility(SysUtils.Format('"%s" -t -s -u -r',
                                     [string(PAnsiChar(TR4W_MMTTYPATH))]));

   MMTTY.mmttyMSG := RegisterWindowMessage('MMTTY');
   MMTTY.MMTTYRichEdit := CreateRichEdit(Handle);

   MMTTY.mmttyCallProcess.cpEnable := True;

   MMTTY.mmttyCF.cbSize := SizeOf(TCharFormatA);
   MMTTY.mmttyCF.szFaceName := 'Lucida Console';
   MMTTY.mmttyCF.dwMask := CFM_COLOR + CFM_FACE + CFM_BOLD;
   SendMessage(MMTTY.MMTTYRichEdit, EM_SETCHARFORMAT, SCF_SELECTION,
               integer(@MMTTY.mmttyCF));

   HandleResize(Sender);
end;

{ WAS tListBoxClientAlign(hwnddlg), which found the control with
  GetDlgItem(parent, 101) -- CreateRichEdit gives it that id.  The handle is
  already held, so it is sized directly: a control id is a number the compiler
  cannot check, and this window has no reason to look one up. }
procedure TfrmMMTTY.HandleResize(Sender: TObject);
begin
   if MMTTY.MMTTYRichEdit = 0 then
      begin
      Exit;
      end;

   { THE ONE UNAVOIDABLE ONE.  A foreign HWND is not a TControl, so the LCL
     cannot lay it out -- Align, Anchors and Parent all address TControls.  The
     SIZE comes from the LCL (ClientWidth/ClientHeight); only the placing of a
     non-LCL child needs the API. }
   Windows.MoveWindow(MMTTY.MMTTYRichEdit, 0, 0, ClientWidth, ClientHeight, True);
end;

{ WHAT WM_DESTROY AND WM_NCDESTROY DID -- AND THE ORDER IS THE WHOLE POINT.

  The dialog split this across TWO messages, and that split was load-bearing:

     WM_DESTROY    PostMmttyMessage(RXM_EXIT) + clear the record
     WM_NCDESTROY  RichEditOperation(False)

  WM_NCDESTROY arrives AFTER the window and all its children are gone.  Folding
  both into one handler that runs BEFORE CloseTR4WWindow crashed TR4W on the
  first close (NY4I, 2026-08-25) -- the log simply STOPS, with no shutdown line,
  which is what a hard kill looks like.

  RichEditOperation(False) is a FreeLibrary('RICHED32.DLL') once the last user
  goes (MainUnit).  Calling it while the RichEdit control is still alive unmaps
  the code its window procedure lives in, and the DestroyWindow moments later
  runs into the hole.

  So: tell MMTTY to exit, forget the state, DESTROY THE WINDOW -- which takes
  the RichEdit child with it -- and only then release the library. }
procedure TfrmMMTTY.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   PostMmttyMessage(RXM_EXIT, 0);
   FillChar(MMTTY, SizeOf(MMTTY), 0);   { RTL, not Windows.ZeroMemory }

   { caHIDE, NOT caNone -- caNone leaves the form visible as far as the LCL is
     concerned while CloseTR4WWindow destroys the handle underneath it, and the
     widget set then recreates it.  Five windows shipped with that defect and
     could not be closed at all (ec3448a6). }
   CloseAction := caHide;
   CloseTR4WWindow(tw_MMTTYWINDOW_INDEX);

   { AFTER the destroy, never before -- see the note above. }
   RichEditOperation(False);
end;

procedure TfrmMMTTY.HandleKeyDown(Sender: TObject; var Key: Word;
                                  Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

end.
