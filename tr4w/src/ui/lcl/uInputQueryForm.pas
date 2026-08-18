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
unit uInputQueryForm;
{$I ..\..\tr4w.inc}

{
  THE ONE-LINE INPUT QUERY, AS AN LCL FORM.  Phase 4a, third modal converted.

  A prompt, an icon, one edit and OK/Cancel -- but the edit is CONFIGURED PER
  OPENING by a set of one-shot globals the caller sets first, and that is the
  whole substance of this dialog:

    tInputDialogLowerCase   -> CharCase (ES_UPPERCASE unless set)
    tInputDialogInteger     -> NumbersOnly (was ES_NUMBER, poked in with
                               SetWindowLong(GWL_STYLE) after creation)
    tInputDialogPassword    -> PasswordChar (was EM_SETPASSWORDCHAR, which the
                               original notes is the ONLY Win32 way to convert
                               an existing edit -- the LCL just has a property)
    tInputDialogWarning     -> which stock icon is shown
    tInputDialogPreviousValue -> the pre-filled text
    IQMaxInputLength        -> MaxLength (was EM_LIMITTEXT)

  THE FLAGS ARE ONE-SHOT AND ARE CLEARED WHEN READ, exactly as before.  So is
  tInputDialogPreviousValue, and so is IQresult -- which is what makes closing
  with the window button read as an empty answer rather than a stale one.

  MODALITY IS PRESERVED VIA ShowModalOverWin32Parent, and that is not
  decoration.  This dialog's parent is settingswindowhandle when the legacy
  Settings window is open (LOGWIND.PAS:1992), and LCL's ShowModal disables LCL
  forms only.  See the helper's comment.
}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  LCLType;   // HWND -- ShowInputQuery keeps the caller's Win32 parent

type
  TfrmInputQuery = class(TForm)
    imgIcon: TImage;
    lblPrompt: TLabel;
    edtValue: TEdit;
    btnOK: TButton;
    btnCancel: TButton;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  end;

// the one-line input query.  Parent is explicit: LOGWIND picks between the
// active window and tr4whandle before calling.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.  This body changed when the dialog became an LCL form
// and nothing at any call site did.
procedure ShowInputQuery(const aParent: HWND);

implementation

{$R *.lfm}

uses
  Windows,     // LoadIcon -- see HandleShow
  VC,          // the tInputDialog* one-shot flags
  TF,          // IQPrompt, tLoadKeyboardLayout
  MainUnit,    // tLoadKeyboardLayout, logger
  uInputQuery, // IQresult, IQMaxInputLength -- still the caller's contract
  uLCLFormHelpers,
  uHostedFormWindows,
  Log4D;

var
  frmInputQuery: TfrmInputQuery = nil;

procedure TfrmInputQuery.HandleShow(Sender: TObject);
begin
   RegisterHostedFormHandle(Self.Handle);

   Caption := 'TR4W';
   lblPrompt.Caption := string(IQPrompt);

   // THE STOCK ICON IS A WINDOWS CALL, and it is the only one in this form.
   // The LCL has no cross-platform stock-dialog-icon API, so this needs a
   // per-platform answer the day a Mac or Linux build is attempted -- named
   // here in one place rather than hidden, the same treatment as the
   // left/right shift test in TTR4WEntryEvents.
   //
   // The original computed the ordinal by PChar arithmetic on IDI_QUESTION,
   // which broke under a 2-byte PWideChar; it already had to be rewritten in
   // integer space once.  Choosing between two named constants cannot break
   // that way at all.
   if tInputDialogWarning then
      begin
      // IDI_EXCLAMATION, not IDI_WARNING: the Win32 headers define WARNING as
      // an alias for EXCLAMATION and FPC's Windows unit carries only the
      // latter.  Same icon, same ordinal (32515).
      imgIcon.Picture.Icon.Handle := LoadIcon(0, IDI_EXCLAMATION);
      end
   else
      begin
      imgIcon.Picture.Icon.Handle := LoadIcon(0, IDI_QUESTION);
      end;

   if tInputDialogLowerCase then
      begin
      edtValue.CharCase := ecNormal;
      end
   else
      begin
      edtValue.CharCase := ecUpperCase;
      end;

   edtValue.NumbersOnly := tInputDialogInteger;
   edtValue.MaxLength   := IQMaxInputLength;

   if tInputDialogPassword then
      begin
      // '*' matches the listview's PASSWORD_MASK, so the operator sees the same
      // masking in both places.  Issue #783.
      edtValue.PasswordChar := '*';
      end
   else
      begin
      edtValue.PasswordChar := #0;
      end;

   edtValue.Text := string(tInputDialogPreviousValue);

   // CLEARED ON READ, exactly as the WM_INITDIALOG arm did.  These are one-shot
   // requests from the caller, not settings: leaving one set would silently
   // apply it to the NEXT unrelated question -- a password mask on a prompt for
   // a callsign, or an integer-only filter on free text.
   tInputDialogWarning   := False;
   tInputDialogInteger   := False;
   tInputDialogLowerCase := False;
   tInputDialogPassword  := False;
   FillChar(tInputDialogPreviousValue, SizeOf(tInputDialogPreviousValue), 0);
   FillChar(IQresult, SizeOf(IQresult), 0);

   edtValue.SetFocus;
   edtValue.SelectAll;
end;

procedure TfrmInputQuery.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   // Closing with the window button answers nothing: IQresult was zeroed in
   // HandleShow and neither button ran, so the caller reads ''.  That is what
   // the original did by falling through WM_CLOSE without touching IQresult.
   tLoadKeyboardLayout;
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

procedure TfrmInputQuery.btnOKClick(Sender: TObject);
begin
   IQresult := edtValue.Text;
   Close;
end;

procedure TfrmInputQuery.btnCancelClick(Sender: TObject);
begin
   IQresult := '';
   Close;
end;

procedure ShowInputQuery(const aParent: HWND);
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmInputQuery = nil then
         begin
         frmInputQuery := TfrmInputQuery.Create(Application);
         end;

      ShowModalOverWin32Parent(frmInputQuery, aParent);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowInputQuery failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
