unit uIntercomForm;

{ THE INTERCOM WINDOW, AS AN LCL FORM.

  It was a Win32 dialog holding one list box, created in WM_INITDIALOG and
  re-aligned to the client area on every WM_SIZE.  Align := alClient replaces
  the WM_SIZE handler outright.

  THE LIST BOX WAS NEVER OWNER-DRAWN, despite being built by a function called
  CreateOwnerDrawListBox: LB_STYLE_3 (TF.pas:64) is LBS_NOTIFY, MULTIPLESEL,
  HASSTRINGS, NOINTEGRALHEIGHT and the window bits -- no LBS_OWNERDRAW anywhere.
  So this is an ordinary TListBox with MultiSelect, and nothing was lost. }

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, LCLType, Forms, Controls, StdCtrls;

type
   TfrmIntercom = class(TForm)
      lstMessages: TListBox;
      procedure HandleCreate(Sender: TObject);
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleKeyDown(Sender: TObject; var Key: word;
                              Shift: TShiftState);
      procedure MessagesDblClick(Sender: TObject);
   end;

var
   TR4WIntercomForm: TfrmIntercom = nil;

function CreateTR4WIntercomWindow: HWND;

implementation

{$R *.lfm}

uses
   VC,                { tw_INTERCOMWINDOW_INDEX }
   uIntercom,         { LoadIntercomHistory }
   MainUnit,          { CloseTR4WWindow, ProcessMenu }
   uLCLFormHelpers;   { OwnFormByMainWindow }

procedure TfrmIntercom.HandleCreate(Sender: TObject);
begin
   // ONCE, not on every open: the form object is reused, so this would append
   // the whole file again each time the operator reopened the window.
   LoadIntercomHistory;
end;

procedure TfrmIntercom.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   // HIDE, NOT FREE -- CloseTR4WWindow owns the lifetime.
   CloseAction := caHide;
   CloseTR4WWindow(tw_INTERCOMWINDOW_INDEX);
end;

{ ESCAPE CLOSES IT.  A Win32 DialogBox did this for free; a TForm does not. }
procedure TfrmIntercom.HandleKeyDown(Sender: TObject; var Key: word;
                                     Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure TfrmIntercom.MessagesDblClick(Sender: TObject);
begin
   // What LBN_DBLCLK did.
   ProcessMenu(menu_send_message);
end;

function CreateTR4WIntercomWindow: HWND;
begin
   if TR4WIntercomForm = nil then
      begin
      TR4WIntercomForm := TfrmIntercom.Create(nil);
      end;

   OwnFormByMainWindow(TR4WIntercomForm);

   Result := TR4WIntercomForm.Handle;
end;

end.
