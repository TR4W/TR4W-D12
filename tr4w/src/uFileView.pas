{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
unit uFileView;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface
uses
  VC,
  TF,
  uMenu,
  (* NO Windows AT ALL NOW. It was gated here this morning as "genuinely
    Windows: this unit sends a file by MAPI" -- which was true until the mail
    path was deleted a few hours later. Nothing else in the unit wanted it, so
    the gate went with the feature rather than outliving it. *)
  Tree,
  LogWind,
  PostUnit,
  uTR4WStrings,
  uAnsiStr;

(* THE MAPI MAIL PATH IS DELETED (2026-09-08) -- the constants, the four
  record types, the three function pointer types, SendMail itself, and the
  Mapi32.dll loading.

  NY4I: "The MAPI utilities are to let the user send email presumably to the
  Contest sponsor but that is not really how this works anymore. So I do not
  believe we need to even offer it if we have trouble finding a cross-platform
  MAPI class that will use the email client setup on the local system."

  AND THERE IS NO SUCH CLASS, which was the question he asked next -- whether
  Indy could do it without going to full SMTP. It cannot, and that is not a gap
  in Indy: the only MAPI in the vendored tree is IdCoderTNEF, which DECODES
  winmail.dat attachments out of a RECEIVED message. Indy implements wire
  protocols; handing a message to whichever mail client the operator has
  configured is an OS integration, not a protocol.

  The portable way to reach the local client is a `mailto:` URI through the OS
  -- OpenURL already does exactly that here -- but mailto CANNOT ATTACH A FILE,
  and attaching the Cabrillo was the entire point. Sponsors take web uploads
  now.

  Its one live caller was the file viewer's "Send log" menu item, which goes
  with it. The bug-report caller in MainUnit had already been commented out;
  NY4I plans a GitHub issue-form link on a menu instead, which needs none of
  this. *)

(* THE RICH-EDIT STREAMING MACHINERY IS DELETED, not ported (2026-09-01).

   The viewer created a RICHED32 control, built an _editstream record with a
   callback, and pushed the file through EM_STREAMIN with SF_TEXT -- a
   rich-text control used exclusively to display PLAIN TEXT.
   ui/lcl/uFileViewForm shows the same file in a read-only TMemo, so the
   stream record, TEditStreamCallBack, OpenCallback (a wrapper round
   ReadFile), the
   SF_/EM_/ReadError constants and the RichEditViewer handle all go with it.

   MainUnit.RichEditOperation STAYS.  This window was one of its two callers
   and no longer takes a reference on RICHED32.DLL; the MMTTY window is the
   other and still does. *)


// the full-log viewer.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
procedure ShowFullLog;

implementation

uses MainUnit, uFileViewForm;

procedure ShowFullLog;
begin
   ShowFileViewWindow;
end;
end.

