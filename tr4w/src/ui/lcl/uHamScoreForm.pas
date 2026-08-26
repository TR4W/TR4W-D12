unit uHamScoreForm;

{ THE HAMSCORE STATUS WINDOW, AS AN LCL FORM.

  It was a Win32 dialog: six statics, a multi-line read-only edit, two buttons,
  a one-second SetTimer, a WM_SIZE handler that repositioned every control by
  hand, and a WM_GETMINMAXINFO that clamped the minimum size.  Anchors and
  Constraints do the last two, so HamScoreLayoutControls has no successor here.

  WHAT DID NOT MOVE: the uploader.  The form asks uHamScore for a snapshot and
  renders it.  Nothing about queue depth, cycle times or the RTC protocol lives
  in this unit, which is the same split the state-model work is heading for --
  the window is a view, not the owner. }

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, LCLType, Forms, Controls, StdCtrls, ExtCtrls;

type
   TfrmHamScore = class(TForm)
      lblURL: TLabel;
      lblUser: TLabel;
      lblQueueTitle: TLabel;
      lblQueueValue: TLabel;
      lblLastRun: TLabel;
      lblStatusTitle: TLabel;
      memStatus: TMemo;
      btnPushNow: TButton;
      btnResync: TButton;
      tmrRefresh: TTimer;
      procedure HandleCreate(Sender: TObject);
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleShow(Sender: TObject);
      procedure PushNowClick(Sender: TObject);
      procedure ResyncClick(Sender: TObject);
      procedure RefreshTick(Sender: TObject);
      procedure HandleKeyDown(Sender: TObject; var Key: word;
                              Shift: TShiftState);
   private
      procedure Refresh;
   end;

var
   TR4WHamScoreForm: TfrmHamScore = nil;

function CreateTR4WHamScoreWindow: HWND;

implementation

{$R *.lfm}

uses
   VC,                { tw_HAMSCOREWINDOW_INDEX }
   MainUnit,          { CloseTR4WWindow, FrmSetFocus }
   uHamScore,         { the uploader -- snapshot and the two actions }
   uLCLFormHelpers;   { OwnFormByMainWindow }

procedure TfrmHamScore.HandleCreate(Sender: TObject);
begin
   // What WM_GETMINMAXINFO enforced with ptMinTrackSize, said once.
   Constraints.MinWidth  := HAMSCORE_MIN_WIDTH;
   Constraints.MinHeight := HAMSCORE_MIN_HEIGHT;

   tmrRefresh.Interval := HAMSCORE_REFRESH_MS;
end;

procedure TfrmHamScore.HandleShow(Sender: TObject);
begin
   // The dialog refreshed once inside WM_INITDIALOG before the first tick, so
   // the window never appeared holding placeholder text.
   Refresh;
   tmrRefresh.Enabled := True;
end;

procedure TfrmHamScore.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   // HIDE, NOT FREE -- CloseTR4WWindow owns the lifetime, and the object is
   // reused when the operator opens the window again.
   CloseAction := caHide;
   tmrRefresh.Enabled := False;
   CloseTR4WWindow(tw_HAMSCOREWINDOW_INDEX);
end;

procedure TfrmHamScore.Refresh;
var
   snap: THamScoreStatus;
begin
   snap := HamScoreStatusSnapshot;

   // ASSIGNED UNCONDITIONALLY.  The dialog went through SetTextIfChanged to
   // avoid the flicker a SetWindowText caused every second; TControl.SetCaption
   // already compares and does nothing when the text is unchanged, so the guard
   // has a successor built into the widget set.
   lblURL.Caption        := snap.URL;
   lblUser.Caption       := snap.User;
   lblQueueValue.Caption := snap.Queue;
   lblLastRun.Caption    := snap.LastRun;

   // A MEMO, NOT A CAPTION: this is the only field that can hold a long server
   // error, which is why it was a multi-line read-only edit rather than a
   // static.  Text compares internally the same way.
   if memStatus.Text <> snap.Status then
      begin
      memStatus.Text := snap.Status;
      end;
end;

procedure TfrmHamScore.RefreshTick(Sender: TObject);
begin
   Refresh;
end;

{ ESCAPE CLOSES IT.  A Win32 DialogBox did this for free; an LCL form does not,
  and neither of these windows has a Cancel button to carry it. }
procedure TfrmHamScore.HandleKeyDown(Sender: TObject; var Key: word;
                                        Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure TfrmHamScore.PushNowClick(Sender: TObject);
begin
   memStatus.Text := HamScorePushNow;
   FrmSetFocus;
end;

procedure TfrmHamScore.ResyncClick(Sender: TObject);
begin
   memStatus.Text := HamScoreResyncQueued;
   FrmSetFocus;
end;

function CreateTR4WHamScoreWindow: HWND;
begin
   if TR4WHamScoreForm = nil then
      begin
      TR4WHamScoreForm := TfrmHamScore.Create(nil);
      end;

   OwnFormByMainWindow(TR4WHamScoreForm);

   Result := TR4WHamScoreForm.Handle;
end;

end.
