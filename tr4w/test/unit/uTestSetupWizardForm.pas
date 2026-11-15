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
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Forms,
   uAppStrings,
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

procedure TSetupWizardFormTests.RunAllTests;
begin
   TestStartsOnStation;
   TestNothingTickedCommitsFromTheChecklist;
   TestTickedPagesFollowTheCanonicalOrder;
   TestUntickingRemovesThePage;
   TestShowsOffScreen;
end;

end.
