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
   LogRadio, LogCW,
   Tree,       // CodeSpeed
   LogWind,    // CWEnabled, DisplayedCodeSpeed
   MainUnit,   // CWByCATBufferTerminator
   VC;         // CWEnable, tAutoSendMode, InterfacedRadioType

type
   TCWKeyerTests = class(TTestCase)
   protected
      procedure Test_SelectionPrecedence;
      procedure Test_WinKeyerAsyncFallback;
      procedure Test_CATNeedsCapabilityAndConfig;
      procedure Test_CapabilityPins;
      procedure Test_FacadeSendRouting;
      procedure Test_FacadeBusyAndDeleteRouting;
      procedure Test_FlushOrderAndBroadcast;
      procedure Test_SetSpeedBroadcast;
      procedure Test_ProfileDrivenSelectionIsNotAConflict;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   // Records what the facade routed where.  Installed by swapping the KeyerXXX
   // slot vars -- the facade holds no cached reference, so a swap takes effect
   // immediately and is undone in the test's finally block.
   TSpyKeyer = class(TCWKeyer)
   private
      FTag: string;
   public
      BusyResult: boolean;
      DeleteResult: boolean;
      constructor Create(const tag: string);
      procedure SendString(const Msg: Str160; Tone: integer); override;
      procedure SendChar(ch: Char); override;
      function StillBeingSent: boolean; override;
      function DeleteLastChar: boolean; override;
      procedure Flush; override;
      procedure SetSpeed(wpm: integer); override;
   end;

var
   SpyLog: string = '';

constructor TSpyKeyer.Create(const tag: string);
begin
   inherited Create;
   FTag := tag;
   FName := 'spy:' + tag;
   BusyResult := False;
   DeleteResult := False;
end;

procedure TSpyKeyer.SendString(const Msg: Str160; Tone: integer);
begin
   SpyLog := SpyLog + Format('%s.SendString(%s,%d);', [FTag, string(Msg), Tone]);
end;

procedure TSpyKeyer.SendChar(ch: Char);
begin
   SpyLog := SpyLog + Format('%s.SendChar(%s);', [FTag, ch]);
end;

function TSpyKeyer.StillBeingSent: boolean;
begin
   SpyLog := SpyLog + FTag + '.Busy;';
   Result := BusyResult;
end;

function TSpyKeyer.DeleteLastChar: boolean;
begin
   SpyLog := SpyLog + FTag + '.Delete;';
   Result := DeleteResult;
end;

procedure TSpyKeyer.Flush;
begin
   SpyLog := SpyLog + FTag + '.Flush;';
end;

procedure TSpyKeyer.SetSpeed(wpm: integer);
begin
   SpyLog := SpyLog + Format('%s.SetSpeed(%d);', [FTag, wpm]);
end;

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

// ---------------------------------------------------------------------------
// A2 facade tests: LogCW's public procedures must ROUTE to the selected keyer
// (send/busy/delete) and BROADCAST to all of them (flush/speed), in the
// historical order.  Spies replace the real adapters so nothing touches
// hardware; the four slots and every global are restored in finally.
// ---------------------------------------------------------------------------

type
   TSavedKeyers = record
      cat, wk, yccc, cpu: TCWKeyer;
   end;

function InstallSpies(out spyCAT, spyWK, spyYCCC, spyCPU: TSpyKeyer): TSavedKeyers;
begin
   Result.cat := KeyerCAT;
   Result.wk := KeyerWinKey;
   Result.yccc := KeyerYCCC;
   Result.cpu := KeyerCPU;
   spyCAT := TSpyKeyer.Create('CAT');
   spyWK := TSpyKeyer.Create('WK');
   spyYCCC := TSpyKeyer.Create('YCCC');
   spyCPU := TSpyKeyer.Create('CPU');
   KeyerCAT := spyCAT;
   KeyerWinKey := spyWK;
   KeyerYCCC := spyYCCC;
   KeyerCPU := spyCPU;
   SpyLog := '';
end;

procedure RestoreKeyers(const saved: TSavedKeyers;
                        spyCAT, spyWK, spyYCCC, spyCPU: TSpyKeyer);
begin
   KeyerCAT := saved.cat;
   KeyerWinKey := saved.wk;
   KeyerYCCC := saved.yccc;
   KeyerCPU := saved.cpu;
   spyCAT.Free;
   spyWK.Free;
   spyYCCC.Free;
   spyCPU.Free;
end;

procedure TCWKeyerTests.Test_FacadeSendRouting;
var
   saved: TSavedKeyers;
   spyCAT, spyWK, spyYCCC, spyCPU: TSpyKeyer;
   savedWk: LongBool;
   savedYccc, savedCWByCAT, savedEnable, savedEnabled: boolean;
   savedModel: InterfacedRadioType;
   savedMode: ModeType;
begin
   // T4: AddStringToBuffer routes to the SELECTED keyer, and the CWByCAT
   // terminator reaches the CAT keyer even when the CW enables are off (it is
   // a control sentinel, not on-air content -- that bypass is deliberate).
   BeginTest('facade send routing follows the selected keyer');
   saved := InstallSpies(spyCAT, spyWK, spyYCCC, spyCPU);
   savedWk := wkActive;
   savedYccc := ycccActive;
   savedCWByCAT := Radio1.CWByCAT;
   savedModel := Radio1.RadioModel;
   savedEnable := CWEnable;
   savedEnabled := CWEnabled;
   savedMode := ActiveMode;
   try
      // ActiveMode MUST be set: it defaults to Digital under MMTTYMODE
      // (LOGWIND.PAS:485), and AddStringToBuffer's MMTTY branch exits before
      // any keyer is reached.  Leaving it at the default made these checks
      // silently exercise nothing.
      ActiveMode := CW;
      CWEnable := True;
      CWEnabled := True;
      wkActive := False;
      ycccActive := False;
      Radio1.CWByCAT := False;

      SpyLog := '';
      AddStringToBuffer('TEST', 700);
      CheckEquals('CPU.SendString(TEST,700);', SpyLog, 'plain message -> CPU keyer');

      wkActive := True;
      SpyLog := '';
      AddStringToBuffer('TEST', 700);
      CheckEquals('WK.SendString(TEST,700);', SpyLog, 'WinKeyer open -> WinKeyer');

      // Terminator with the enables OFF: must still reach the CAT keyer.
      wkActive := False;
      CWEnabled := False;
      SpyLog := '';
      AddStringToBuffer(CWByCATBufferTerminator, 700);
      CheckTrue(Pos('CAT.SendString', SpyLog) = 1,
                'the CWByCAT terminator bypasses the enable gates: ' + SpyLog);

      // Plain message with the enables off: nothing is keyed at all.
      SpyLog := '';
      AddStringToBuffer('TEST', 700);
      CheckEquals('', SpyLog, 'CW disabled -> no keyer is called');
   finally
      wkActive := savedWk;
      ycccActive := savedYccc;
      Radio1.CWByCAT := savedCWByCAT;
      Radio1.RadioModel := savedModel;
      CWEnable := savedEnable;
      CWEnabled := savedEnabled;
      ActiveMode := savedMode;
      RestoreKeyers(saved, spyCAT, spyWK, spyYCCC, spyCPU);
   end;
end;

procedure TCWKeyerTests.Test_FacadeBusyAndDeleteRouting;
var
   saved: TSavedKeyers;
   spyCAT, spyWK, spyYCCC, spyCPU: TSpyKeyer;
   savedWk: LongBool;
   savedYccc, savedCWByCAT: boolean;
begin
   // T5: the busy and delete predicates hit EXACTLY the selected keyer -- the
   // old chains asked each backend in turn, so this pins the exclusivity.
   BeginTest('facade busy/delete route to exactly the selected keyer');
   saved := InstallSpies(spyCAT, spyWK, spyYCCC, spyCPU);
   savedWk := wkActive;
   savedYccc := ycccActive;
   savedCWByCAT := Radio1.CWByCAT;
   try
      Radio1.CWByCAT := False;
      wkActive := False;
      ycccActive := True;
      spyYCCC.BusyResult := True;
      spyYCCC.DeleteResult := True;

      SpyLog := '';
      CheckTrue(CWStillBeingSent, 'busy answer comes from the selected keyer');
      CheckEquals('YCCC.Busy;', SpyLog, 'only the YCCC spy was asked');

      SpyLog := '';
      CheckTrue(DeleteLastCharacter, 'delete answer comes from the selected keyer');
      CheckEquals('YCCC.Delete;', SpyLog, 'only the YCCC spy was asked');
   finally
      wkActive := savedWk;
      ycccActive := savedYccc;
      Radio1.CWByCAT := savedCWByCAT;
      RestoreKeyers(saved, spyCAT, spyWK, spyYCCC, spyCPU);
   end;
end;

procedure TCWKeyerTests.Test_FlushOrderAndBroadcast;
var
   saved: TSavedKeyers;
   spyCAT, spyWK, spyYCCC, spyCPU: TSpyKeyer;
   savedAutoSend: boolean;
begin
   // T6: flush is a BROADCAST, not a route -- every backend, in the exact
   // historical order, and tAutoSendMode cleared between CAT and CPU.
   BeginTest('flush broadcasts to all four keyers in the historical order');
   saved := InstallSpies(spyCAT, spyWK, spyYCCC, spyCPU);
   savedAutoSend := tAutoSendMode;
   try
      tAutoSendMode := True;
      SpyLog := '';
      FlushCWBuffer;
      CheckEquals('CAT.Flush;CPU.Flush;WK.Flush;YCCC.Flush;', SpyLog,
                  'flush order must match the pre-factory sequence');
      CheckFalse(tAutoSendMode, 'flush clears autosend mode');
   finally
      tAutoSendMode := savedAutoSend;
      RestoreKeyers(saved, spyCAT, spyWK, spyYCCC, spyCPU);
   end;
end;

procedure TCWKeyerTests.Test_SetSpeedBroadcast;
var
   saved: TSavedKeyers;
   spyCAT, spyWK, spyYCCC, spyCPU: TSpyKeyer;
   savedCode, savedDisplayed: integer;
   savedSync: boolean;
begin
   // T7: SetSpeed broadcasts to CPU/WinKeyer/YCCC (never the CAT keyer -- radio
   // speed-sync is a separate concern handled in the facade), and Speed = 0
   // updates only the displayed speed.
   BeginTest('SetSpeed broadcasts to CPU/WK/YCCC and never the CAT keyer');
   saved := InstallSpies(spyCAT, spyWK, spyYCCC, spyCPU);
   savedCode := CodeSpeed;
   savedDisplayed := DisplayedCodeSpeed;
   savedSync := Radio1.CWSpeedSync;
   try
      Radio1.CWSpeedSync := False;   // keep the radio out of it
      SpyLog := '';
      SetSpeed(28);
      CheckEquals(28, CodeSpeed, 'CodeSpeed updated');
      CheckEquals(28, DisplayedCodeSpeed, 'DisplayedCodeSpeed updated');
      CheckEquals('CPU.SetSpeed(28);WK.SetSpeed(28);YCCC.SetSpeed(28);', SpyLog,
                  'speed broadcast order, CAT excluded');

      SpyLog := '';
      SetSpeed(0);
      CheckEquals(0, DisplayedCodeSpeed, 'Speed 0 still updates the display');
      CheckEquals(28, CodeSpeed, 'Speed 0 does NOT change the real code speed');
      CheckEquals('', SpyLog, 'Speed 0 calls no keyer');
   finally
      CodeSpeed := savedCode;
      DisplayedCodeSpeed := savedDisplayed;
      Radio1.CWSpeedSync := savedSync;
      RestoreKeyers(saved, spyCAT, spyWK, spyYCCC, spyCPU);
   end;
end;

procedure TCWKeyerTests.Test_ProfileDrivenSelectionIsNotAConflict;
var
   savedProfileDriven, savedEnable, savedCWByCAT: boolean;
   savedModel: InterfacedRadioType;
begin
   // The CW-by-CAT-plus-hardware-keyer warning predates station profiles.  A
   // profile names ONE CW output per slot and writes it as the per-radio
   // CWByCAT that ActiveCWKeyer already tests, so a K3 on a WinKeyer alongside
   // a 7100 on CAT resolves by radio with nothing left to guess (NY4I,
   // 2026-08-08).  Without a profile the ini states both facts globally and
   // cannot say which wins -- that station must still be warned.
   BeginTest('a profile-driven keyer selection is a statement, not a conflict');
   savedProfileDriven := KeyerSelectionIsProfileDriven;
   savedEnable        := WinKeySettings.wksWinKey2Enable;
   savedCWByCAT       := Radio1.CWByCAT;
   savedModel         := Radio1.RadioModel;
   try
      // The exact combination NY4I saw: CAT on a capable radio AND a WinKeyer.
      Radio1.RadioModel := K3;
      Radio1.CWByCAT := True;
      WinKeySettings.wksWinKey2Enable := True;

      KeyerSelectionIsProfileDriven := False;
      CheckTrue(CATAndHardwareKeyerIsAmbiguous,
                'with no profile the ini cannot say which wins -- still warn');

      KeyerSelectionIsProfileDriven := True;
      CheckFalse(CATAndHardwareKeyerIsAmbiguous,
                 'a profile stated the output per slot -- nothing to warn about');
   finally
      Radio1.RadioModel := savedModel;
      Radio1.CWByCAT := savedCWByCAT;
      WinKeySettings.wksWinKey2Enable := savedEnable;
      KeyerSelectionIsProfileDriven := savedProfileDriven;
   end;
end;

procedure TCWKeyerTests.RunAllTests;
begin
   Test_SelectionPrecedence;
   Test_WinKeyerAsyncFallback;
   Test_CATNeedsCapabilityAndConfig;
   Test_CapabilityPins;
   Test_FacadeSendRouting;
   Test_FacadeBusyAndDeleteRouting;
   Test_FlushOrderAndBroadcast;
   Test_SetSpeedBroadcast;
   Test_ProfileDrivenSelectionIsNotAConflict;
end;

end.
