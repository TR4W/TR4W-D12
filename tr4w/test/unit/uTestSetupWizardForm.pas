unit uTestSetupWizardForm;

(* THE SETUP WIZARD'S WINDOW, STREAMED FROM ITS .lfm AND DRIVEN.

  uTestSetupWizard pins the rules; this pins that the window follows them --
  that the .lfm wires the checklist and Next, that the plan the checklist
  makes is the order the pages appear in, and that the button reads "Create
  configuration" exactly on the page before the result.

  NEVER PRESSES "Create configuration": that writes the settings file.  And
  never leaves a page that would ask a question in a modal box (an empty
  callsign, a ticked radio with nothing set up) -- a modal in a test run is
  a hang. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework,
   uSetupWizardForm;

type
   TSetupWizardFormTests = class(TTestCase)
   private
      function NewForm: TfrmSetupWizard;
   protected
      procedure TestStartsOnStation;
      procedure TestNothingTickedCommitsFromTheChecklist;
      procedure TestTickedPagesFollowTheCanonicalOrder;
      procedure TestUntickingRemovesThePage;
      procedure TestShowsOffScreen;
      procedure TestACallbookReplyFillsOnlyTheStationPage;
      (* Issue 334. *)
      procedure TestNewItemsAreUntickedAndInOrder;
      procedure TestLoggerPageHostsTheEditor;
      procedure TestShownLoggerPageFitsItsNote;
      procedure TestRotatorPageAsksTheDriver;
      procedure TestWSJTXPageShowsWhatIsStored;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   Controls,             (* TControl *)
   Forms,
   ExtCtrls,             (* TPanel -- the hosted editor's content *)
   uCallbookBase,        (* TCallbookRecord -- a reply, handed in by hand *)
   uAppStrings,
   uSettingsModel,       (* Settings.Wsjtx -- what the WSJT-X page must show *)
   uRotatorRegistry,     (* RegisteredCount *)
   uLCLFormHelpers,      (* SelectByTag *)
   uExternalLoggersForm, (* TExternalLoggersForm -- the editor the page hosts *)
   uTestShowOffScreen;   (* ShowOffScreen *)

function TSetupWizardFormTests.NewForm: TfrmSetupWizard;
begin
   (* The widget set must be initialised before a control needs a window --
     the New Contest form tests' rule. *)
   if Application <> nil then
      begin
      Application.Initialize;
      end;
   Result := TfrmSetupWizard.Create(nil);
   Result.edtCall.Text := 'W1AW';
end;

procedure TSetupWizardFormTests.TestStartsOnStation;
var
   frm: TfrmSetupWizard;
begin
   BeginTest('TestStartsOnStation');
   frm := NewForm;
   try
      Check(frm.pgPages.ActivePage = frm.tsStation, 'opens on the Station page');
      CheckFalse(frm.btnBack.Enabled, 'nothing to go back to');
      CheckEquals(string(SWizNext), string(frm.btnNext.Caption), 'Next, not Create');
      CheckEquals('Step 1 of 3', string(frm.lblStep.Caption),
                  'Station, checklist and the result');
      CheckFalse(frm.pgPages.ShowTabs, 'the page control shows no tabs');
   finally
      frm.Free;
   end;
end;

procedure TSetupWizardFormTests.TestNothingTickedCommitsFromTheChecklist;
var
   frm: TfrmSetupWizard;
begin
   BeginTest('TestNothingTickedCommitsFromTheChecklist');
   frm := NewForm;
   try
      frm.btnNextClick(frm.btnNext);
      Check(frm.pgPages.ActivePage = frm.tsChecklist, 'Next goes to the checklist');
      CheckTrue(frm.btnBack.Enabled, 'Back is available');
      CheckEquals(string(SWizCreate), string(frm.btnNext.Caption),
                  'with nothing ticked, the checklist is the commit page');

      frm.btnBackClick(frm.btnBack);
      Check(frm.pgPages.ActivePage = frm.tsStation, 'Back returns to Station');
      CheckEquals('W1AW', string(frm.edtCall.Text), 'Back keeps what was typed');
   finally
      frm.Free;
   end;
end;

procedure TSetupWizardFormTests.TestTickedPagesFollowTheCanonicalOrder;
var
   frm: TfrmSetupWizard;
begin
   BeginTest('TestTickedPagesFollowTheCanonicalOrder');
   frm := NewForm;
   try
      frm.btnNextClick(frm.btnNext);

      (* Ticked cluster FIRST, radio second -- the radio page still comes
        first.  Checked raises OnChange, so this also fails if the .lfm stops
        wiring the checklist. *)
      frm.chkCluster.Checked := True;
      frm.chkRadio.Checked := True;
      CheckEquals('Step 2 of 5', string(frm.lblStep.Caption),
                  'two pages added to the plan');
      CheckEquals(string(SWizNext), string(frm.btnNext.Caption),
                  'the checklist no longer commits');

      frm.btnNextClick(frm.btnNext);
      Check(frm.pgPages.ActivePage = frm.tsRadio,
            'radio before cluster, whatever the click order');
      (* The hosted editor's panel, and the wizard's own two CW choices under
        it (hidden until a radio that offers them is chosen). *)
      CheckEquals(3, frm.tsRadio.ControlCount,
                  'the radio editor is the page itself, not a button to one');
   finally
      frm.Free;
   end;
end;

procedure TSetupWizardFormTests.TestUntickingRemovesThePage;
var
   frm: TfrmSetupWizard;
begin
   BeginTest('TestUntickingRemovesThePage');
   frm := NewForm;
   try
      frm.btnNextClick(frm.btnNext);
      frm.chkRadio.Checked := True;
      frm.chkCluster.Checked := True;
      frm.chkRadio.Checked := False;
      CheckEquals('Step 2 of 4', string(frm.lblStep.Caption),
                  'unticking takes the radio page out of the plan');

      frm.btnNextClick(frm.btnNext);
      Check(frm.pgPages.ActivePage = frm.tsCluster, 'straight to the cluster page');
      CheckEquals(string(SWizCreate), string(frm.btnNext.Caption),
                  'the last ticked page commits');
   finally
      frm.Free;
   end;
end;

(* SHOWN, NOT ONLY STREAMED: OnShow runs, the window gets a handle and the
  cluster page reads the public directory -- the show-time paths a streamed
  form never takes.  Off screen, and Hide rather than Close, which frees. *)
procedure TSetupWizardFormTests.TestShowsOffScreen;
var
   frm: TfrmSetupWizard;
begin
   BeginTest('TestShowsOffScreen');
   frm := NewForm;
   try
      ShowOffScreen(frm);
      CheckTrue(frm.Visible, 'the wizard shows');
      Check(frm.pgPages.ActivePage = frm.tsStation, 'on the Station page');

      frm.btnNextClick(frm.btnNext);
      frm.chkCluster.Checked := True;
      frm.btnNextClick(frm.btnNext);
      Application.ProcessMessages;
      Check(frm.pgPages.ActivePage = frm.tsCluster, 'the cluster page shows');
      CheckEquals('W1AW', string(frm.edtLogin.TextHint),
                  'a blank login is shown to mean the station callsign');
      frm.Hide;
   finally
      frm.Free;
   end;
end;

(* A LATE CALLBOOK REPLY (review M15). The reply can arrive many seconds after
  the question; if the operator has gone on, the boxes it would fill are on a
  page they have left, and Create would save them unseen. ApplyCallbook is the
  main-thread end of the real lookup -- the relay calls exactly this -- so a
  reply is handed to it directly, with no network. *)
procedure TSetupWizardFormTests.TestACallbookReplyFillsOnlyTheStationPage;
var
   frm: TfrmSetupWizard;
   rec: TCallbookRecord;
begin
   BeginTest('TestACallbookReplyFillsOnlyTheStationPage');
   rec := TCallbookRecord.Create;
   frm := NewForm;
   try
      rec.Found     := True;
      rec.Call      := 'W1AW';
      rec.FirstName := 'HIRAM';
      rec.Grid      := 'FN31pr';

      frm.edtName.Text := '';
      frm.edtGrid.Text := '';
      frm.btnNextClick(frm.btnNext);
      Check(frm.pgPages.ActivePage = frm.tsChecklist, 'gone on to the checklist');
      frm.ApplyCallbook(rec);
      CheckEquals('', string(frm.edtName.Text),
                  'a reply after the Station page is left fills nothing');
      CheckEquals('', string(frm.edtGrid.Text), 'nor the grid');

      frm.btnBackClick(frm.btnBack);
      Check(frm.pgPages.ActivePage = frm.tsStation, 'back on the Station page');
      frm.ApplyCallbook(rec);
      CheckEquals('Hiram', string(frm.edtName.Text),
                  'on the Station page the empty name is filled');
      CheckEquals('FN31pr', string(frm.edtGrid.Text), 'and the grid');
   finally
      frm.Free;
      rec.Free;
   end;
end;

procedure TSetupWizardFormTests.TestNewItemsAreUntickedAndInOrder;
var
   frm: TfrmSetupWizard;
begin
   BeginTest('TestNewItemsAreUntickedAndInOrder');
   frm := NewForm;
   try
      CheckFalse(frm.chkLogger.Checked, 'the external logger starts unticked');
      CheckFalse(frm.chkRotator.Checked, 'the rotator starts unticked');
      CheckFalse(frm.chkWSJTX.Checked, 'WSJT-X starts unticked');
      CheckEquals(string(SWizItemLogger), string(frm.chkLogger.Caption),
                  'the caption is the catalogue''s, not the .lfm placeholder');

      frm.btnNextClick(frm.btnNext);
      (* Ticked last-first: the pages still come in canonical order. *)
      frm.chkWSJTX.Checked := True;
      frm.chkRotator.Checked := True;
      frm.chkCluster.Checked := True;
      CheckEquals('Step 2 of 6', string(frm.lblStep.Caption), 'three pages added');
      frm.btnNextClick(frm.btnNext);
      Check(frm.pgPages.ActivePage = frm.tsCluster, 'the cluster first');
      frm.chkCluster.Checked := False;   // its page would ask for a server
      frm.btnBackClick(frm.btnBack);
      frm.btnNextClick(frm.btnNext);
      Check(frm.pgPages.ActivePage = frm.tsRotator, 'then the rotator');
   finally
      frm.Free;
   end;
end;

(* THE EXTERNAL LOGGER PAGE IS THE EDITOR ITSELF: its content panel is the
  page's one child, owned by a TExternalLoggersForm, and nothing has been
  written -- Create is never pressed here. *)
procedure TSetupWizardFormTests.TestLoggerPageHostsTheEditor;
var
   frm: TfrmSetupWizard;
   hosted: TControl;
begin
   BeginTest('TestLoggerPageHostsTheEditor');
   frm := NewForm;
   try
      frm.btnNextClick(frm.btnNext);
      frm.chkLogger.Checked := True;
      CheckEquals('Step 2 of 4', string(frm.lblStep.Caption), 'one page added');
      frm.btnNextClick(frm.btnNext);
      Check(frm.pgPages.ActivePage = frm.tsLogger, 'the logger page shows');
      CheckEquals(1, frm.tsLogger.ControlCount, 'one child: the editor''s panel');
      hosted := frm.tsLogger.Controls[0];
      CheckTrue(hosted is TPanel, 'a panel');
      CheckTrue(hosted.Owner is TExternalLoggersForm,
                'owned by the external logger editor -- the editor, not a copy of it');
      CheckEquals('pnlContent', hosted.Name, 'its content panel');
      CheckTrue(TExternalLoggersForm(hosted.Owner).chkActive.Checked,
                'switched on: ticking the item was the choice to send');
      CheckTrue(frm.ClientWidth >= hosted.Width, 'the window is wide enough for it');
      CheckEquals(string(SWizCreate), string(frm.btnNext.Caption),
                  'the only ticked page commits');

      (* Unticking destroys the editor; re-ticking starts a new one. *)
      frm.btnBackClick(frm.btnBack);
      frm.chkLogger.Checked := False;
      CheckEquals(0, frm.tsLogger.ControlCount, 'the editor went with the tick');
   finally
      frm.Free;
   end;
end;

(* SHOWN, the hosted editor's long note is laid out at its WRAPPED height:
  a wrapped label measures only once its parent has a window, which a
  streamed form never gives it.  The note ends above the status line, and the
  panel lies inside its page. *)
procedure TSetupWizardFormTests.TestShownLoggerPageFitsItsNote;
var
   frm: TfrmSetupWizard;
   editor: TExternalLoggersForm;
   pw, ph: integer;
begin
   BeginTest('TestShownLoggerPageFitsItsNote');
   frm := NewForm;
   try
      ShowOffScreen(frm);
      frm.btnNextClick(frm.btnNext);
      frm.chkLogger.Checked := True;
      frm.btnNextClick(frm.btnNext);
      Application.ProcessMessages;
      Check(frm.pgPages.ActivePage = frm.tsLogger, 'the logger page shows');
      editor := TExternalLoggersForm(frm.tsLogger.Controls[0].Owner);
      ControlPreferredSize(editor.lblNote, pw, ph);
      CheckTrue(editor.lblNote.Height >= ph,
                'the note is as tall as it wraps: ' + IntToStr(editor.lblNote.Height)
                + ' < ' + IntToStr(ph));
      CheckTrue(editor.lblNote.Top + editor.lblNote.Height <= editor.lblStatus.Top,
                'the note ends above the status line');
      CheckTrue(editor.pnlContent.Top + editor.pnlContent.Height <= frm.tsLogger.ClientHeight,
                'the panel lies inside its page: ' + IntToStr(editor.pnlContent.Height)
                + ' in ' + IntToStr(frm.tsLogger.ClientHeight));
      CheckTrue(editor.pnlContent.Left + editor.pnlContent.Width <= frm.tsLogger.ClientWidth,
                'and is not cut off on the right');
      frm.Hide;
   finally
      frm.Free;
   end;
end;

(* SERIAL OR NETWORK IS THE DRIVER'S ANSWER: the port for a serial rotator,
  the address and UDP port for PstRotator -- the rule Preferences follows. *)
procedure TSetupWizardFormTests.TestRotatorPageAsksTheDriver;
var
   frm: TfrmSetupWizard;
begin
   BeginTest('TestRotatorPageAsksTheDriver');
   frm := NewForm;
   try
      frm.btnNextClick(frm.btnNext);
      frm.chkRotator.Checked := True;
      frm.btnNextClick(frm.btnNext);
      Check(frm.pgPages.ActivePage = frm.tsRotator, 'the rotator page shows');
      CheckEquals(RegisteredCount, frm.cbxRotatorType.Items.Count,
                  'every registered rotator type, from the registry');
      CheckEquals(-1, frm.cbxRotatorType.ItemIndex, 'none chosen for the operator');
      CheckTrue(frm.cbxRotatorPort.Items.Count >= 1, 'the port list is filled');

      SelectByTag(frm.cbxRotatorType, 'PSTROTATOR');
      frm.RotatorTypeChange(frm.cbxRotatorType);
      CheckFalse(frm.cbxRotatorPort.Enabled, 'PstRotator has no serial port');
      CheckTrue(frm.edtRotatorIP.Enabled and frm.edtRotatorUDP.Enabled,
                'it has an address and a UDP port');

      SelectByTag(frm.cbxRotatorType, 'YAESU');
      frm.RotatorTypeChange(frm.cbxRotatorType);
      CheckTrue(frm.cbxRotatorPort.Enabled, 'a Yaesu is on a serial port');
      CheckFalse(frm.edtRotatorIP.Enabled, 'and has no address');

      (* Unticking forgets the choice. *)
      frm.btnBackClick(frm.btnBack);
      frm.chkRotator.Checked := False;
      CheckEquals(-1, frm.cbxRotatorType.ItemIndex, 'a re-ticked rotator starts blank');
   finally
      frm.Free;
   end;
end;

(* THE WSJT-X PAGE SHOWS THE STORED SETTINGS -- on a new install the model's
  default, which is ON -- and unticking the item puts back what is stored. *)
procedure TSetupWizardFormTests.TestWSJTXPageShowsWhatIsStored;
var
   frm: TfrmSetupWizard;
begin
   BeginTest('TestWSJTXPageShowsWhatIsStored');
   frm := NewForm;
   try
      frm.btnNextClick(frm.btnNext);
      frm.chkWSJTX.Checked := True;
      frm.btnNextClick(frm.btnNext);
      Check(frm.pgPages.ActivePage = frm.tsWSJTX, 'the WSJT-X page shows');
      CheckTrue(Settings.Wsjtx.Enabled = frm.chkWSJTXEnable.Checked,
                'the box shows the stored switch');
      CheckEquals(IntToStr(Settings.Wsjtx.BroadcastPort), string(frm.edtWSJTXPort.Text),
                  'the box shows the stored port');

      frm.chkWSJTXEnable.Checked := not Settings.Wsjtx.Enabled;
      frm.edtWSJTXPort.Text := '9999';
      frm.btnBackClick(frm.btnBack);
      frm.chkWSJTX.Checked := False;
      CheckTrue(Settings.Wsjtx.Enabled = frm.chkWSJTXEnable.Checked,
                'unticked: back to what is stored');
      CheckEquals(IntToStr(Settings.Wsjtx.BroadcastPort), string(frm.edtWSJTXPort.Text),
                  'the port too');
   finally
      frm.Free;
   end;
end;

procedure TSetupWizardFormTests.RunAllTests;
begin
   TestNewItemsAreUntickedAndInOrder;
   TestLoggerPageHostsTheEditor;
   TestShownLoggerPageFitsItsNote;
   TestRotatorPageAsksTheDriver;
   TestWSJTXPageShowsWhatIsStored;
   TestStartsOnStation;
   TestNothingTickedCommitsFromTheChecklist;
   TestTickedPagesFollowTheCanonicalOrder;
   TestUntickingRemovesThePage;
   TestShowsOffScreen;
   TestACallbookReplyFillsOnlyTheStationPage;
end;

end.
