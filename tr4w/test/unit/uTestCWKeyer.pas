unit uTestCWKeyer;

{
  CW keyer factory -- selection and capability tests (plan T1-T3, T8).

  FLAGS ONLY -- no hardware opens, no threads: ActiveCWKeyer is a pure
  function of four globals (Radio1.CWByCAT + capability, wkActive,
  ycccActive), and these tests drive exactly those.  Fixture facts:
  ActiveRadioPtr is the typed const @Radio1, and uRadioRegistry.SupportsFor
  answers instance-free -- both hold without app startup.

  Every test saves and restores the globals it touches in try..finally, so
  test order cannot leak state.
}

interface

uses
   SysUtils, uTR4WTestFramework, uCWKeyerBase, uWinKey, uYCCCSO2R,
   LogRadio, VC;

type
   TCWKeyerTests = class(TTestCase)
   protected
      procedure Test_SelectionPrecedence;
      procedure Test_WinKeyerAsyncFallback;
      procedure Test_CATNeedsCapabilityAndConfig;
      procedure Test_CapabilityPins;
   public
      procedure RunAllTests; override;
   end;

implementation

procedure TCWKeyerTests.Test_SelectionPrecedence;
var
   savedWkActive: LongBool;
   savedYccc: boolean;
   savedCWByCAT: boolean;
   savedModel: InterfacedRadioType;
begin
   // T1: the pinned AddStringToBuffer order -- CAT -> WinKeyer -> YCCC -> CPU.
   BeginTest('selection precedence: CAT -> WinKeyer -> YCCC -> CPU');
   savedWkActive := wkActive;
   savedYccc := ycccActive;
   savedCWByCAT := Radio1.CWByCAT;
   savedModel := Radio1.RadioModel;
   try
      wkActive := False;
      ycccActive := False;
      Radio1.CWByCAT := False;

      CheckTrue(ActiveCWKeyer = KeyerCPU, 'everything off -> CPU keyer');

      ycccActive := True;
      CheckTrue(ActiveCWKeyer = KeyerYCCC, 'YCCC active -> YCCC');

      wkActive := True;
      CheckTrue(ActiveCWKeyer = KeyerWinKey, 'WinKeyer open outranks YCCC');

      Radio1.CWByCAT := True;
      Radio1.RadioModel := K3;   // has rcCWByCAT
      CheckTrue(ActiveCWKeyer = KeyerCAT, 'eligible CW-by-CAT outranks everything');
   finally
      wkActive := savedWkActive;
      ycccActive := savedYccc;
      Radio1.CWByCAT := savedCWByCAT;
      Radio1.RadioModel := savedModel;
   end;
end;

procedure TCWKeyerTests.Test_WinKeyerAsyncFallback;
var
   savedWkActive: LongBool;
   savedYccc: boolean;
   savedEnable: boolean;
   savedCWByCAT: boolean;
begin
   // T2 -- the trickiest correctness point, pinned: wkActive only goes True in
   // the read thread AFTER a successful echo test.  A WinKeyer that is ENABLED
   // but never opened must fall through to the next keyer, exactly as today.
   // A static selection on wksWinKey2Enable would break this.
   BeginTest('an enabled-but-unopened WinKeyer falls through (wksWinKey2Enable ignored)');
   savedWkActive := wkActive;
   savedYccc := ycccActive;
   savedEnable := WinKeySettings.wksWinKey2Enable;
   savedCWByCAT := Radio1.CWByCAT;
   try
      Radio1.CWByCAT := False;
      WinKeySettings.wksWinKey2Enable := True;   // configured...
      wkActive := False;                          // ...but the echo test never passed
      ycccActive := True;
      CheckTrue(ActiveCWKeyer = KeyerYCCC,
                'selection must test wkActive (live), never wksWinKey2Enable (config)');
   finally
      wkActive := savedWkActive;
      ycccActive := savedYccc;
      WinKeySettings.wksWinKey2Enable := savedEnable;
      Radio1.CWByCAT := savedCWByCAT;
   end;
end;

procedure TCWKeyerTests.Test_CATNeedsCapabilityAndConfig;
var
   savedWkActive: LongBool;
   savedYccc: boolean;
   savedCWByCAT: boolean;
   savedModel: InterfacedRadioType;
begin
   // T3: CW-by-CAT requires BOTH the operator's config AND the radio's
   // rcCWByCAT capability -- either alone must not select the CAT keyer.
   BeginTest('CAT selection needs config AND capability');
   savedWkActive := wkActive;
   savedYccc := ycccActive;
   savedCWByCAT := Radio1.CWByCAT;
   savedModel := Radio1.RadioModel;
   try
      wkActive := False;
      ycccActive := False;

      Radio1.CWByCAT := True;
      Radio1.RadioModel := FT747GX;   // no rcCWByCAT
      CheckTrue(ActiveCWKeyer = KeyerCPU,
                'config on a radio without the capability must not select CAT');

      Radio1.CWByCAT := False;
      Radio1.RadioModel := K3;        // has rcCWByCAT
      CheckTrue(ActiveCWKeyer = KeyerCPU,
                'capability without the config must not select CAT');
   finally
      wkActive := savedWkActive;
      ycccActive := savedYccc;
      Radio1.CWByCAT := savedCWByCAT;
      Radio1.RadioModel := savedModel;
   end;
end;

procedure TCWKeyerTests.Test_CapabilityPins;
begin
   // T8: capability declarations pinned so a refactor cannot silently drop one.
   BeginTest('capability pins: tune, chaining, delete-last-char');
   CheckTrue(KeyerWinKey.Supports(ckTune), 'only the WinKeyer tunes today');
   CheckFalse(KeyerCPU.Supports(ckTune), 'CPU keyer has no tune (TuneWithDits is dead)');
   CheckFalse(KeyerYCCC.Supports(ckTune), 'YCCC has no tune arm');
   CheckFalse(KeyerCAT.Supports(ckTune), 'tune is pinned to the WinKeyer even under CAT');
   CheckTrue(KeyerCAT.Supports(ckMessageChaining), 'CAT messages chain via the terminator');
   CheckTrue(KeyerCAT.Supports(ckDeleteLastChar), 'CAT retracts via DeleteLastCWCharacter');
   CheckTrue(KeyerWinKey.Supports(ckDeleteLastChar), 'WinKeyer retracts via BACKSPACE');
   CheckTrue(KeyerYCCC.Supports(ckDeleteLastChar), 'YCCC retracts via YCCCDeleteLastChar');
   CheckTrue(KeyerCPU.Supports(ckDeleteLastChar), 'CPU keyer retracts from its buffer');
end;

procedure TCWKeyerTests.RunAllTests;
begin
   Test_SelectionPrecedence;
   Test_WinKeyerAsyncFallback;
   Test_CATNeedsCapabilityAndConfig;
   Test_CapabilityPins;
end;

end.
