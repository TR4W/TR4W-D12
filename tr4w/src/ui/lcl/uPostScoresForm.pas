unit uPostScoresForm;

{ THE POST-SCORES WINDOW, AS AN LCL FORM.

  It was a Win32 dialog built in GetScoresDlgProc's WM_INITDIALOG: two buttons,
  one static, and a five-minute SetTimer.  Nothing about it needed a dialog
  procedure.

  ONE THING HERE IS NOT A STRAIGHT TRANSLATION.  The status line was written by
  ShowGetScoresStatus with SetDlgItemTextA, and that call is made FROM THE
  UPLOAD WORKER THREAD -- CreateConnectionAndSendReportToGetScores runs under
  tCreateThread.  Against a Win32 static that was safe BY ACCIDENT: SetDlgItemText
  is a kernel call and Windows marshals it to the window's own thread.  Assigning
  an LCL Caption does no such thing, so the hop is now explicit and the worker
  keeps calling one routine that is correct from either side. }

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, LCLType, Forms, Controls, StdCtrls, ExtCtrls;

type
   TfrmPostScores = class(TForm)
      lblStatus: TLabel;
      btnPostNow: TButton;
      btnShowScores: TButton;
      tmrPost: TTimer;
      procedure HandleCreate(Sender: TObject);
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure PostNowClick(Sender: TObject);
      procedure ShowScoresClick(Sender: TObject);
      procedure PostTick(Sender: TObject);
      procedure HandleKeyDown(Sender: TObject; var Key: word;
                              Shift: TShiftState);
   end;

var
   TR4WPostScoresForm: TfrmPostScores = nil;

function CreateTR4WPostScoresWindow: HWND;

{ THE STATUS LINE, SAFE FROM ANY THREAD.  Does nothing when the window is not
  open, which is what the old SetDlgItemTextA against a zero handle did. }
procedure PostScoresShowStatus(const aText: string);

implementation

{$R *.lfm}

uses
   SyncObjs,
   MainUnit,          { CloseTR4WWindow, FrmSetFocus }
   VC,                { RC_POSTNOW, RC_GOTOGS }
   uConfigValues,     { Config.GetScoresSeverReadingAddress }
   TF,                { OpenUrl }
   uGetScores,        { RunPOSTGetScoresThread }
   uLCLFormHelpers;   { OwnFormByMainWindow }

{ ---------------------------------------------------- the cross-thread hop -- }

type
   { QueueAsyncCall wants a METHOD, so one object owns the hop -- the same shape
     uMainForm's deferrer and uStateBridge use. }
   TStatusHop = class(TObject)
      procedure Apply(Data: PtrInt);
   end;

var
   GHop: TStatusHop = nil;
   GLock: TCriticalSection = nil;
   GPending: string = '';

procedure TStatusHop.Apply(Data: PtrInt);
var
   text: string;
begin
   GLock.Acquire;
   try
      text := GPending;
   finally
      GLock.Release;
   end;

   if TR4WPostScoresForm <> nil then
      begin
      TR4WPostScoresForm.lblStatus.Caption := text;
      end;
end;

procedure PostScoresShowStatus(const aText: string);
begin
   if GLock = nil then
      begin
      GLock := TCriticalSection.Create;
      end;

   GLock.Acquire;
   try
      GPending := aText;
   finally
      GLock.Release;
   end;

   if GHop = nil then
      begin
      GHop := TStatusHop.Create;
      end;

   // Application can be gone on the way out, and QueueAsyncCall RAISES on a
   // shut-down queue rather than returning False -- the trap uPanelUpdate
   // documents.
   if (Application = nil) or Application.Terminated then
      begin
      Exit;
      end;
   Application.QueueAsyncCall(GHop.Apply, 0);
end;

{ ------------------------------------------------------------- the form ---- }

procedure TfrmPostScores.HandleCreate(Sender: TObject);
begin
   // CAPTIONS FROM THE LANGUAGE CONSTANTS, not typed into the designer.  A
   // caption baked into the .lfm is a second copy of a translated string that
   // keeps working while it drifts from the one the program actually uses.
   btnPostNow.Caption    := string(RC_POSTNOW);
   btnShowScores.Caption := string(RC_GOTOGS);
   lblStatus.Caption     := '';

   // The cycle the dialog started with SetTimer(hwnddlg, 1, 1000 * 60 * 5, nil).
   tmrPost.Interval := 1000 * 60 * 5;
   tmrPost.Enabled  := True;
end;

procedure TfrmPostScores.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   // HIDE, NOT FREE.  CloseTR4WWindow owns the lifetime -- it destroys the
   // handle and clears the array entry -- and the object is reused on reopen.
   CloseAction := caHide;
   tmrPost.Enabled := False;
   CloseTR4WWindow(tw_POSTSCORESWINDOW_INDEX);
end;

{ ESCAPE CLOSES IT.  A Win32 DialogBox did this for free; an LCL form does not,
  and neither of these windows has a Cancel button to carry it. }
procedure TfrmPostScores.HandleKeyDown(Sender: TObject; var Key: word;
                                        Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure TfrmPostScores.PostNowClick(Sender: TObject);
begin
   RunPOSTGetScoresThread;
   FrmSetFocus;
end;

procedure TfrmPostScores.ShowScoresClick(Sender: TObject);
begin
   OpenUrl(string(Config.GetScoresSeverReadingAddress));
   FrmSetFocus;
end;

procedure TfrmPostScores.PostTick(Sender: TObject);
begin
   RunPOSTGetScoresThread;
end;

function CreateTR4WPostScoresWindow: HWND;
begin
   if TR4WPostScoresForm = nil then
      begin
      TR4WPostScoresForm := TfrmPostScores.Create(nil);
      end;

   OwnFormByMainWindow(TR4WPostScoresForm);

   Result := TR4WPostScoresForm.Handle;
end;

finalization
   FreeAndNil(GHop);
   FreeAndNil(GLock);

end.
