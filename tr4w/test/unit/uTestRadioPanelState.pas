unit uTestRadioPanelState;

(* THE RADIO PANEL'S ACTIVE-RADIO LABEL AND ACTIVE-VFO WEIGHT -- the rules in
  uRadioPanelState (UI refresh proposal, "Radio display", 2026-11-22).

  - The "Active" label shows on the active radio's panel and on no other, in
    either SO2R order, and on neither panel when no radio is active.
  - The VFO weight follows the RIG's A/B state, never the active radio: the
    readout of the VFO the rig names stays bold, the other drops to regular,
    and an unknown VFO leaves both bold, as designed. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TRadioPanelStateTests = class(TTestCase)
   protected
      procedure Test_TheActiveLabelIsOnTheActiveRadiosPanelOnly;
      procedure Test_ASwapMovesTheActiveLabel;
      procedure Test_NoActiveRadioShowsNoLabel;
      procedure Test_TheRigsVFOKeepsTheBold;
      procedure Test_AnUnknownVFOLeavesBothBold;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uRadioPanelState;

procedure TRadioPanelStateTests.Test_TheActiveLabelIsOnTheActiveRadiosPanelOnly;
begin
   BeginTest('Test_TheActiveLabelIsOnTheActiveRadiosPanelOnly');
   CheckTrue(RadioPanelShowsActive(1, 1), 'radio 1 active: radio 1 panel shows it');
   CheckFalse(RadioPanelShowsActive(2, 1), 'radio 1 active: radio 2 panel does not');
   CheckFalse(RadioPanelShowsActive(0, 0), 'no panel slot is never active');
   CheckFalse(RadioPanelShowsActive(3, 3), 'a slot past 2 is never active');
end;

procedure TRadioPanelStateTests.Test_ASwapMovesTheActiveLabel;
begin
   BeginTest('Test_ASwapMovesTheActiveLabel');
   CheckTrue(RadioPanelShowsActive(2, 2), 'radio 2 active: radio 2 panel shows it');
   CheckFalse(RadioPanelShowsActive(1, 2), 'radio 2 active: radio 1 panel does not');
end;

procedure TRadioPanelStateTests.Test_NoActiveRadioShowsNoLabel;
begin
   BeginTest('Test_NoActiveRadioShowsNoLabel');
   CheckFalse(RadioPanelShowsActive(1, 0), 'no active radio: radio 1 panel');
   CheckFalse(RadioPanelShowsActive(2, 0), 'no active radio: radio 2 panel');
end;

procedure TRadioPanelStateTests.Test_TheRigsVFOKeepsTheBold;
begin
   BeginTest('Test_TheRigsVFOKeepsTheBold');
   (* The rig on VFO A: A enabled, B greyed. *)
   CheckTrue(VFOReadoutIsBold(True, False), 'VFO A readout, rig on A');
   CheckFalse(VFOReadoutIsBold(False, True), 'VFO B readout, rig on A');
end;

procedure TRadioPanelStateTests.Test_AnUnknownVFOLeavesBothBold;
begin
   BeginTest('Test_AnUnknownVFOLeavesBothBold');
   CheckTrue(VFOReadoutIsBold(True, True), 'both named (vfoUnknown): bold, as designed');
   CheckTrue(VFOReadoutIsBold(False, False), 'neither named: bold, as designed');
end;

procedure TRadioPanelStateTests.RunAllTests;
begin
   Test_TheActiveLabelIsOnTheActiveRadiosPanelOnly;
   Test_ASwapMovesTheActiveLabel;
   Test_NoActiveRadioShowsNoLabel;
   Test_TheRigsVFOKeepsTheBold;
   Test_AnUnknownVFOLeavesBothBold;
end;

end.
