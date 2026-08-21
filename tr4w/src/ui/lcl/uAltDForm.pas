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
unit uAltDForm;
{$I ..\..\tr4w.inc}

{
  THE ALT-D DUPE-CHECK BOX, AS AN LCL FORM.  Phase 4a of the Win32-to-LCL
  migration, and the first modal converted.

  It was a DialogBoxIndirectParam template built at run time by AltDDlgProc:
  CreateStatic + CreateEdit + CreateOKCancelButtons, a WM_CTLCOLOREDIT arm to
  paint the edit yellow, and a SetWindowLong subclass on the edit to filter
  keystrokes.  ALL OF THAT IS DELETED, not wrapped -- that is the migration's
  standing rule, and the double-caret defect on the main window is what happens
  when it is not followed.  Each hand-rolled behaviour became the property or
  event the control already has:

    ES_UPPERCASE            -> CharCase = ecUpperCase
    ES_CENTER               -> Alignment = taCenter
    EM_LIMITTEXT 12         -> MaxLength = 12
    WM_CTLCOLOREDIT yellow  -> edtCall.Color, set in HandleShow
    the SetWindowLong subclass on the edit  -> OnKeyPress
    EN_CHANGE routed to the parent          -> OnChange on the control
    control ids 1 and 2 from CreateOKCancelButtons -> Default / Cancel + ModalResult

  MODALITY IS PRESERVED, NOT REVISITED.  It was modal; it is ShowModal.  Whether
  it SHOULD be modal is a separate decision, taken on the bench.
}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Graphics;

type
  TfrmAltD = class(TForm)
    lblPrompt: TLabel;
    edtCall: TEdit;
    btnOK: TButton;
    btnCancel: TButton;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure edtCallChange(Sender: TObject);
    procedure edtCallKeyPress(Sender: TObject; var Key: AnsiChar);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    procedure RefreshPartials;
  end;

// The Alt-D dupe-check box.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.  This body changed when the dialog became an LCL form
// and nothing at any call site did.
procedure ShowAltD;

implementation

{$R *.lfm}

uses
  uLCLFormHelpers,   // ShowModalOverWin32Parent -- ownership and centring
  Windows,
  VC,
  TF,
  Tree,                // KeyboardCallsignChar
  uConfigValues,       // Config.AltDBufferEnable
  uCallsigns,          // CallsignsList
  uMaster,             // ClearMasterListBox
  LogStuff,            // DupeInfoCall, SCPMinimumLetters
  LogEdit,             // VisibleLog
  LogRadio,            // InActiveRadioPtr
  uDupeSheet,          // ClearAltD
  LogWind,
  MainUnit,            // tClearDupeInfoCall, logger
  uHostedFormWindows,
  Log4D;

var
  frmAltD: TfrmAltD = nil;

procedure TfrmAltD.HandleShow(Sender: TObject);
begin
   RegisterHostedFormHandle(Self.Handle);

   Caption := RC_DUPECHECKOAR;

   // The prompt names the INACTIVE radio's band and mode, so it is composed
   // here rather than typed in the designer -- it changes between openings.
   lblPrompt.Caption := Format(TC_ENTERCALLTOBECHECKEDON,
                               [BandStringsArray[InActiveRadioPtr.BandMemory],
                                ModeStringArray[InActiveRadioPtr.ModeMemory]]);

   // WM_CTLCOLOREDIT painted this yellow; the control has a Color.  Same
   // palette entry, so the shade is unchanged.
   edtCall.Color := TColor(tr4wColorsArray[trYellow]);

   if Config.AltDBufferEnable then
      begin
      edtCall.Text := DupeInfoCall;
      end
   else
      begin
      edtCall.Text := '';
      end;

   edtCall.SetFocus;
   edtCall.SelStart := Length(edtCall.Text);
end;

procedure TfrmAltD.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

procedure TfrmAltD.RefreshPartials;
begin
   DupeInfoCall := edtCall.Text;

   if SCPMinimumLetters > 0 then
      begin
      ClearMasterListBox;
      VisibleLog.SuperCheckPartial(DupeInfoCall, True, InActiveRadioPtr);
      end;

   CallsignsList.CreatePartialsList(DupeInfoCall);
end;

procedure TfrmAltD.edtCallChange(Sender: TObject);
begin
   RefreshPartials;
end;

{ The edit used to be subclassed with SetWindowLong(GWL_WNDPROC) purely to run
  this one test.  KeyboardCallsignChar TAKES ITS KEY BY var AND CAN REPLACE IT
  -- it maps QuestionMarkChar to '?' and SlashMarkChar to '/' (tree.pas:5152) --
  so the substitution is written back, exactly as the entry fields on the main
  window do it. }
procedure TfrmAltD.edtCallKeyPress(Sender: TObject; var Key: AnsiChar);
var
   vk: wParam;
begin
   vk := Ord(Key);
   if KeyboardCallsignChar(vk, False) = False then
      begin
      Key := #0;
      end
   else
      begin
      Key := AnsiChar(Byte(vk));
      end;
end;

procedure TfrmAltD.btnOKClick(Sender: TObject);
begin
   Close;
end;

procedure TfrmAltD.btnCancelClick(Sender: TObject);
begin
   tClearDupeInfoCall;
   ClearAltD;                    // 4.53.7
   Close;
end;

procedure ShowAltD;
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.  Logging the phase is what makes such a report
   // actionable.
   try
      if frmAltD = nil then
         begin
         frmAltD := TfrmAltD.Create(Application);
         end;
      // THROUGH THE ONE DOOR, parent 0.  There is no raw Win32 parent to
      // disable here, but ShowModalOverWin32Parent is also where the main
      // window is made the owner and the form is centred over it -- see
      // OwnFormByMainWindow.  A bare ShowModal skips both.
      ShowModalOverWin32Parent(frmAltD, 0);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowAltD failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
