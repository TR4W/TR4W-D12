unit uMP3RecorderForm;

{ THE MP3 RECORDER WINDOW, AS AN LCL FORM.

  A label, a peak meter, a Record check box and a button -- built by hand in
  WM_INITDIALOG, with the LAME DLL loaded in the same breath.

  THE INTERESTING PART IS THE METER.  The elapsed time and the peak level were
  written straight into the controls from waveInProc -- the multimedia CALLBACK
  THREAD -- once per captured buffer.  SetDlgItemText and SendMessage are kernel
  calls, so Windows marshalled them and it worked by accident.  Assigning an LCL
  Caption or Position from that thread does not.

  QueueAsyncCall PER BUFFER WOULD BE WRONG TOO: buffers arrive many times a
  second and each hop would post work to the main queue whether or not anything
  changed.  So the audio side now publishes two plain integers and this form
  polls them on a timer.  Integer reads and writes are atomic on i386, no lock
  is needed for a value that is only ever displayed, and the meter updates at a
  rate a human can see rather than at the rate the sound card fills buffers. }

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, LCLType, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls;

type
   TfrmMP3Recorder = class(TForm)
      lblElapsed: TLabel;
      pbPeak: TProgressBar;
      chkRecord: TCheckBox;
      btnControl: TButton;
      tmrMeter: TTimer;
      procedure HandleCreate(Sender: TObject);
      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleKeyDown(Sender: TObject; var Key: word;
                              Shift: TShiftState);
      procedure RecordClick(Sender: TObject);
      procedure ControlClick(Sender: TObject);
      procedure MeterTick(Sender: TObject);
   end;

var
   TR4WMP3RecorderForm: TfrmMP3Recorder = nil;

function CreateTR4WMP3RecorderWindow: HWND;

implementation

{$R *.lfm}

uses
   VC,                { tw_MP3RECORDER, RC_MP3_RECENABLE }
   MainUnit,          { CloseTR4WWindow, ProcessMenu }
   TF,                { MillisecondsToFormattedString }
   uMP3Recorder,      { the recorder itself }
   uLCLFormHelpers;   { OwnFormByMainWindow }

procedure TfrmMP3Recorder.HandleCreate(Sender: TObject);
begin
   chkRecord.Caption := string(RC_MP3_RECENABLE);
   pbPeak.Min := 0;
   pbPeak.Max := PeakProgressBarMaxValue;
   lblElapsed.Caption := '';
end;

procedure TfrmMP3Recorder.HandleShow(Sender: TObject);
begin
   // WHAT WM_INITDIALOG DID BEYOND BUILDING CONTROLS.  The DLL load reports its
   // own failure and leaves the window open with recording unavailable, which
   // is what the dialog did after its `goto 1`.
   MP3RecorderWindowOpened;

   Caption := SysUtils.Format('MP3 Recorder (%ukbps)', [RecorderBitrate]);
   chkRecord.Checked := MP3RecorderIsRecording;
   tmrMeter.Enabled := True;
end;

procedure TfrmMP3Recorder.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   CloseAction := caHide;
   tmrMeter.Enabled := False;
   MP3RecorderWindowClosed;
   CloseTR4WWindow(tw_MP3RECORDER);
end;

{ ESCAPE CLOSES IT.  A Win32 DialogBox did this for free; a TForm does not. }
procedure TfrmMP3Recorder.HandleKeyDown(Sender: TObject; var Key: word;
                                        Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure TfrmMP3Recorder.RecordClick(Sender: TObject);
begin
   SwapRecorderStatus;
end;

procedure TfrmMP3Recorder.ControlClick(Sender: TObject);
begin
   ProcessMenu(menu_recording_control);
end;

procedure TfrmMP3Recorder.MeterTick(Sender: TObject);
var
   elapsed: cardinal;
   peak: integer;
   text: string;
begin
   elapsed := MP3RecorderElapsedMS;
   peak    := MP3RecorderPeakLevel;

   if elapsed = 0 then
      begin
      text := '';
      end
   else
      begin
      text := string(MillisecondsToFormattedString(elapsed, False));
      end;

   // ASSIGNED UNCONDITIONALLY: TControl.SetCaption already compares and does
   // nothing when the text has not changed, and TProgressBar.Position likewise.
   lblElapsed.Caption := text;
   if peak > pbPeak.Max then
      begin
      peak := pbPeak.Max;
      end;
   pbPeak.Position := peak;
end;

function CreateTR4WMP3RecorderWindow: HWND;
begin
   if TR4WMP3RecorderForm = nil then
      begin
      TR4WMP3RecorderForm := TfrmMP3Recorder.Create(nil);
      end;

   OwnFormByMainWindow(TR4WMP3RecorderForm);

   Result := TR4WMP3RecorderForm.Handle;
end;

end.
