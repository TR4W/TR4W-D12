unit uTestCWKeyer;
{$I ..\..\src\tr4w.inc}

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
  uConfigValues,
   SysUtils, uTR4WTestFramework, uCWKeyerBase, uWinKey, uYCCCSO2R,
   LogRadio, LogCW,
   Tree,       // CodeSpeed
   LogWind,    // CWEnabled, DisplayedCodeSpeed
   MainUnit,   // CWByCATBufferTerminator
   VC;         // Config.CWEnable, tAutoSendMode, InterfacedRadioType

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
      procedure Test_AMessageOnAnInhibitedRadioWarnsAtOnce;
      procedure Test_EachKeyerStatesTheRadioItKeys;
      procedure Test_CATRoutingFollowsTheSwap;
      procedure Test_SendStringAndStopKeysOneRadio;
      procedure Test_NoKeyUpIsNotedWhenCATKeysNothing;
      procedure Test_AFaultInTheReviewNeverReachesKeying;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Log4D,
   ExtCtrls,            (* TTimer -- the CW-by-CAT busy window a slot needs *)
   uFactoryRadioBase,   (* TFactoryRadioBase *)
   uRadioElecraftK4,    (* TK4Radio -- the recording radio's base *)
   uSettingsModel,      (* Settings.Ptt *)
   uCrashLog,           (* InstallCrashLog -- the main thread on record *)
   uPanelUpdate,        (* CurrentStatusText -- what the status panel was given *)
   uRadioState,         (* TXInhibitAlert -- what the PTT indicator paints from *)
   uTXInhibitView,      (* TXInhibitAlertOf, ResetTXInhibitAlerts *)
   uTestLogCapture,     (* TCaptureAppender *)
   uTestTXInhibitAlert; (* SetSettledTXState *)

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
      (* What KeyedRadio answers -- @Radio1 unless a test says otherwise. *)
      Keyed: RadioPtr;
      constructor Create(const tag: string);
      procedure SendString(const Msg: Str160; Tone: integer); override;
      procedure SendChar(ch: Char); override;
      function StillBeingSent: boolean; override;
      function DeleteLastChar: boolean; override;
      procedure Flush; override;
      procedure SetSpeed(wpm: integer); override;
      function KeyedRadio: RadioPtr; override;
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
   Keyed := @Radio1;
end;

function TSpyKeyer.KeyedRadio: RadioPtr;
begin
   Result := Keyed;
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
   savedEnable := Config.CWEnable;
   savedEnabled := CWEnabled;
   savedMode := ActiveMode;
   try
      // ActiveMode MUST be set: it defaults to Digital under MMTTYMODE
      // (logwind.pas:485), and AddStringToBuffer's MMTTY branch exits before
      // any keyer is reached.  Leaving it at the default made these checks
      // silently exercise nothing.
      ActiveMode := CW;
      Config.CWEnable := True;
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
      Config.CWEnable := savedEnable;
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

(* ISSUE #97, TRIGGER 1 THROUGH THE FACADE: a CW message on a radio that reports
  TX inhibited is warned the moment it is handed to the keyer -- before the
  radio says anything about TX -- on the radio the message KEYS (KeyersSwapped
  picks the inactive one), once per key-up, and never across a down link.  The
  message still goes: this is a warning, not a block. *)
function TXInhibitWarnings(aCapture: TCaptureAppender): integer;
var
   i: integer;
begin
   Result := 0;
   for i := 0 to aCapture.Lines.Count - 1 do
      begin
      if Pos('[TX inhibit]', aCapture.Lines[i]) > 0 then
         begin
         Inc(Result);
         end;
      end;
end;

procedure TCWKeyerTests.Test_AMessageOnAnInhibitedRadioWarnsAtOnce;
const
   REASON = 'TX test mode';
var
   saved: TSavedKeyers;
   spyCAT, spyWK, spyYCCC, spyCPU: TSpyKeyer;
   savedWk: LongBool;
   savedYccc, savedCWByCAT, savedEnable, savedEnabled, savedSwapped: boolean;
   savedDisc1, savedDisc2: boolean;
   savedStatus1, savedStatus2: RadioStatusRecord;
   savedMode: ModeType;
   savedLevel: TLogLevel;
   capture: TCaptureAppender;
   keep: ILogAppender;
begin
   BeginTest('trigger 1: a CW message on an inhibited radio warns at once, on the keyed radio');
   InstallCrashLog;      (* the main thread on record, so the review runs NOW *)
   saved := InstallSpies(spyCAT, spyWK, spyYCCC, spyCPU);
   savedWk := wkActive;
   savedYccc := ycccActive;
   savedCWByCAT := Radio1.CWByCAT;
   savedEnable := Config.CWEnable;
   savedEnabled := CWEnabled;
   savedSwapped := KeyersSwapped;
   savedMode := ActiveMode;
   savedDisc1 := Radio1.RadioDisconnected;
   savedDisc2 := Radio2.RadioDisconnected;
   savedStatus1 := ReadRadioStatus(@Radio1);
   savedStatus2 := ReadRadioStatus(@Radio2);

   capture := TCaptureAppender.Create('tx-inhibit');
   keep := capture;
   savedLevel := logger.Level;
   logger.Level := Log4D.Warn;
   logger.AddAppender(keep);
   try
      ActiveMode := CW;
      Config.CWEnable := True;
      CWEnabled := True;
      wkActive := False;
      ycccActive := False;
      Radio1.CWByCAT := False;
      KeyersSwapped := False;
      Radio1.RadioDisconnected := False;
      Radio2.RadioDisconnected := False;
      CheckTrue(ActiveRadioPtr = @Radio1, 'precondition: radio 1 is active');
      ResetTXInhibitAlerts;

      (* Radio 1 receiving, in TX test mode.  No TX report will come. *)
      SetSettledTXState(@Radio1, False, True, REASON);
      SetSettledTXState(@Radio2, False, False, '');

      AddStringToBuffer('CQ TEST', 700);
      CheckTrue(TXInhibitAlertOf(@Radio1).Showing,
                'the alert is up the moment the message is handed over -- not ' +
                'behind the radio''s TX report');
      CheckTrue(RadioState.TXInhibitAlert, 'and the PTT indicator is told');
      CheckEquals('TX INHIBITED: ' + REASON, CurrentStatusText(stoRadio1),
                  'radio 1''s status panel carries the sentence');
      CheckEquals(1, TXInhibitWarnings(capture), 'one Warn line for the key-up');

      AddStringToBuffer(' NY4I', 700);     (* the next piece of the same message *)
      CheckEquals(1, TXInhibitWarnings(capture),
                  'a second piece of the message is the same key-up -- no second line');
      CheckEquals('CPU.SendString(CQ TEST,700);CPU.SendString( NY4I,700);', SpyLog,
                  'the message still goes -- a warning, not a block');

      (* SO2R: the KEYER says it keys radio 2 (TCWKeyer.KeyedRadio -- which
        radio each real adapter names is pinned in
        Test_EachKeyerStatesTheRadioItKeys), and radio 2 is in test mode. *)
      ResetTXInhibitAlerts;
      capture.Lines.Clear;
      SetSettledTXState(@Radio1, False, False, '');
      SetSettledTXState(@Radio2, False, True, REASON);
      spyCPU.Keyed := @Radio2;
      AddStringToBuffer('TEST', 700);
      CheckFalse(TXInhibitAlertOf(@Radio1).Showing, 'radio 1 is not the one keyed');
      CheckTrue(TXInhibitAlertOf(@Radio2).Showing,
                'the radio checked is the one the keyer keys');
      CheckEquals('TX INHIBITED: ' + REASON, CurrentStatusText(stoRadio2),
                  'on radio 2''s status panel');
      CheckEquals(1, TXInhibitWarnings(capture), 'one Warn line');

      (* Not inhibited: an ordinary message, nothing raised. *)
      spyCPU.Keyed := @Radio1;
      ResetTXInhibitAlerts;
      capture.Lines.Clear;
      SetSettledTXState(@Radio2, False, False, '');
      AddStringToBuffer('TEST', 700);
      CheckFalse(TXInhibitAlertOf(@Radio1).Showing, 'not inhibited: no alert');
      CheckFalse(RadioState.TXInhibitAlert, 'and the indicator is not told');
      CheckEquals(0, TXInhibitWarnings(capture), 'and nothing is logged');

      (* A DOWN LINK IS NOT BELIEVED: the slot still says inhibited from the
        last session, but the radio is disconnected. *)
      ResetTXInhibitAlerts;
      SetSettledTXState(@Radio1, False, True, REASON);
      Radio1.RadioDisconnected := True;
      AddStringToBuffer('TEST', 700);
      CheckFalse(TXInhibitAlertOf(@Radio1).Showing,
                 'a stale "inhibited" across a dropped link is not warned');
      CheckEquals(0, TXInhibitWarnings(capture), 'and nothing is logged');

      (* CW disabled: nothing keys, so nothing is warned. *)
      Radio1.RadioDisconnected := False;
      ResetTXInhibitAlerts;
      CWEnabled := False;
      AddStringToBuffer('TEST', 700);
      CheckFalse(TXInhibitAlertOf(@Radio1).Showing, 'CW off: nothing keyed, nothing warned');

      (* AN EMPTY STRING KEYS NOTHING -- the sidetone toggle sends one
        (MainUnit.tr4w_toggle_sidetone). *)
      CWEnabled := True;
      ResetTXInhibitAlerts;
      capture.Lines.Clear;
      AddStringToBuffer('', 700);
      CheckFalse(TXInhibitAlertOf(@Radio1).Showing, 'an empty string keys nothing: no alert');
      CheckFalse(TXInhibitAlertOf(@Radio1).ProgramKeyUp, 'and no key-up is noted');
      CheckEquals(0, TXInhibitWarnings(capture), 'and nothing is logged');
   finally
      logger.RemoveAppender(keep);
      logger.Level := savedLevel;
      keep := nil;
      SetSettledTXState(@Radio1, savedStatus1.TXOn, savedStatus1.TXInhibited,
                        string(savedStatus1.TXInhibitReason));
      SetSettledTXState(@Radio2, savedStatus2.TXOn, savedStatus2.TXInhibited,
                        string(savedStatus2.TXInhibitReason));
      Radio1.RadioDisconnected := savedDisc1;
      Radio2.RadioDisconnected := savedDisc2;
      ResetTXInhibitAlerts;
      wkActive := savedWk;
      ycccActive := savedYccc;
      Radio1.CWByCAT := savedCWByCAT;
      Config.CWEnable := savedEnable;
      CWEnabled := savedEnabled;
      KeyersSwapped := savedSwapped;
      ActiveMode := savedMode;
      RestoreKeyers(saved, spyCAT, spyWK, spyYCCC, spyCPU);
   end;
end;

(* ---------------------------------------------------------------------------
  ISSUE #97 REVIEW (2026-10-26): which radio each keyer keys, the CW-by-CAT
  routing, SendStringAndStop's terminator, and a TX-inhibit fault never
  reaching a keying path.  These drive the REAL adapters against two radio
  slots that carry a recording K4: nothing reaches a port, and what the CAT
  keyer hands its driver is written down.
  --------------------------------------------------------------------------- *)

type
   (* A K4 that keys nothing and writes down what it was asked to do. *)
   TRecordingK4 = class(TK4Radio)
   public
      Log: string;
      procedure Transmit; override;
      procedure Receive; override;
      procedure BufferCW(cwChars: string); override;
      procedure SendCW; override;
   end;

procedure TRecordingK4.Transmit;
begin
   Log := Log + 'Transmit;';
end;

procedure TRecordingK4.Receive;
begin
   Log := Log + 'Receive;';
end;

procedure TRecordingK4.BufferCW(cwChars: string);
begin
   Log := Log + 'BufferCW(' + cwChars + ');';
end;

procedure TRecordingK4.SendCW;
begin
   Log := Log + 'SendCW;';
end;

type
   (* Two CAT-capable slots with recording radios, and everything they change. *)
   TTwoRadioFixture = class(TObject)
   private
      (* Each slot's fields these tests write, so they can be put back. *)
      FFactory: array[1..2] of TFactoryRadioBase;
      FTimer: array[1..2] of TTimer;
      FCWByCAT, FSending, FSawTX, FDisconnected: array[1..2] of boolean;
      FBuffer: array[1..2] of string;
      FPTT: array[1..2] of PTTStatusType;
      FSwapped, FEnable, FEnabled, FPttEnable, FPttVia, FPttNoPoll: boolean;
      FWk: LongBool;
      FYccc: boolean;
      FMode: ModeType;
      FSpeed: integer;
      procedure SaveSlot(const aIndex: integer; rig: RadioPtr);
      procedure RestoreSlot(const aIndex: integer; rig: RadioPtr);
   public
      Rec1, Rec2: TRecordingK4;
      constructor Create;
      destructor Destroy; override;
   end;

procedure TTwoRadioFixture.SaveSlot(const aIndex: integer; rig: RadioPtr);
begin
   FFactory[aIndex] := rig^.tFactoryObject;
   FTimer[aIndex] := rig^.tmrCWByCAT;
   FCWByCAT[aIndex] := rig^.CWByCAT;
   FSending[aIndex] := rig^.CWByCAT_Sending;
   FSawTX[aIndex] := rig^.CWByCAT_SawTX;
   FDisconnected[aIndex] := rig^.RadioDisconnected;
   FBuffer[aIndex] := rig^.CWByCATBuffer;
   FPTT[aIndex] := rig^.tPTTStatus;
end;

procedure TTwoRadioFixture.RestoreSlot(const aIndex: integer; rig: RadioPtr);
begin
   if rig^.tmrCWByCAT <> FTimer[aIndex] then
      begin
      rig^.tmrCWByCAT.Free;
      end;
   rig^.tFactoryObject := FFactory[aIndex];
   rig^.tmrCWByCAT := FTimer[aIndex];
   rig^.CWByCAT := FCWByCAT[aIndex];
   rig^.CWByCAT_Sending := FSending[aIndex];
   rig^.CWByCAT_SawTX := FSawTX[aIndex];
   rig^.RadioDisconnected := FDisconnected[aIndex];
   rig^.CWByCATBuffer := FBuffer[aIndex];
   rig^.tPTTStatus := FPTT[aIndex];
end;

constructor TTwoRadioFixture.Create;

   procedure Arm(rig: RadioPtr; rec: TRecordingK4);
   begin
      rig^.tFactoryObject := rec;
      (* The CW-by-CAT busy window, built as LOGRADIO builds it: disabled and
        with no handler, so it can never fire in a test. *)
      rig^.tmrCWByCAT := TTimer.Create(nil);
      rig^.tmrCWByCAT.Enabled := False;
      rig^.CWByCAT := True;
      rig^.CWByCAT_Sending := False;
      rig^.CWByCAT_SawTX := False;
      rig^.RadioDisconnected := False;
      rig^.CWByCATBuffer := '';
   end;

begin
   inherited Create;
   SaveSlot(1, @Radio1);
   SaveSlot(2, @Radio2);
   FSwapped := KeyersSwapped;
   FEnable := Config.CWEnable;
   FEnabled := CWEnabled;
   FWk := wkActive;
   FYccc := ycccActive;
   FMode := ActiveMode;
   FSpeed := DisplayedCodeSpeed;
   FPttEnable := Settings.Ptt.Enable;
   FPttVia := Settings.Ptt.ViaCommands;
   FPttNoPoll := Settings.Ptt.NoPollDuring;

   Rec1 := TRecordingK4.Create;
   Rec2 := TRecordingK4.Create;
   Arm(@Radio1, Rec1);
   Arm(@Radio2, Rec2);
   KeyersSwapped := False;
   Config.CWEnable := True;
   CWEnabled := True;
   wkActive := False;
   ycccActive := False;
   ActiveMode := CW;
   DisplayedCodeSpeed := 25;     (* the busy window divides by it *)
   InstallCrashLog;              (* the main thread on record *)
   ResetTXInhibitAlerts;
end;

destructor TTwoRadioFixture.Destroy;
begin
   RestoreSlot(1, @Radio1);
   RestoreSlot(2, @Radio2);
   KeyersSwapped := FSwapped;
   Config.CWEnable := FEnable;
   CWEnabled := FEnabled;
   wkActive := FWk;
   ycccActive := FYccc;
   ActiveMode := FMode;
   DisplayedCodeSpeed := FSpeed;
   Settings.Ptt.Enable := FPttEnable;
   Settings.Ptt.ViaCommands := FPttVia;
   Settings.Ptt.NoPollDuring := FPttNoPoll;
   TXInhibitFaultInjection := False;
   ResetTXInhibitAlerts;
   Rec1.Free;
   Rec2.Free;
   inherited Destroy;
end;

(* ITEM 3: EACH KEYER STATES THE RADIO IT KEYS, swapped and not.  CW-by-CAT and
  the WinKeyer follow the swap; the CPU keyer drives the active radio's line
  whatever the swap says; the YCCC box keys its own TX radio; and a CAT radio
  whose CAT keying is off keys nothing. *)
procedure TCWKeyerTests.Test_EachKeyerStatesTheRadioItKeys;
var
   fx: TTwoRadioFixture;
   base: TCWKeyer;
begin
   BeginTest('each keyer states the radio it keys, with the keyers swapped and not');
   CheckTrue(ActiveRadioPtr = @Radio1, 'precondition: radio 1 is active');
   fx := TTwoRadioFixture.Create;
   base := TCWKeyer.Create;
   try
      CheckTrue(base.KeyedRadio = nil, 'the base names no radio');

      KeyersSwapped := False;
      CheckTrue(KeyerCAT.KeyedRadio = @Radio1, 'CAT, not swapped: radio 1');
      CheckTrue(KeyerWinKey.KeyedRadio = @Radio1, 'WinKeyer, not swapped: radio 1');
      CheckTrue(KeyerCPU.KeyedRadio = @Radio1, 'CPU keyer, not swapped: radio 1');

      KeyersSwapped := True;
      CheckTrue(KeyerCAT.KeyedRadio = @Radio2, 'CAT, swapped: radio 2');
      CheckTrue(KeyerWinKey.KeyedRadio = @Radio2,
                'WinKeyer, swapped: radio 2 (wkSetKeyerOutput(InActiveRadioPtr))');
      CheckTrue(KeyerCPU.KeyedRadio = @Radio1,
                'CPU keyer, swapped: STILL radio 1 -- it drives the active radio''s line');

      Radio2.CWByCAT := False;
      CheckTrue(KeyerCAT.KeyedRadio = nil,
                'CAT, swapped onto a radio whose CAT keying is off: nothing is keyed');
      Radio2.CWByCAT := True;

      (* The box keys its TX radio, not the swap's.  Only where the box exists:
        off Windows uYCCCSO2R has no HID, YCCCSetActiveRadio does nothing and
        YCCCTxRadio is documented as 1 -- the box is never opened there, so
        radio 1 is the right answer and the test must not ask for 2 (issue
        #141: it failed on Linux for that reason). *)
{$IFDEF WINDOWS}
      KeyersSwapped := False;
      YCCCSetActiveRadio(2);
      CheckTrue(KeyerYCCC.KeyedRadio = @Radio2, 'YCCC switched to radio 2, not swapped: radio 2');
      KeyersSwapped := True;
      YCCCSetActiveRadio(1);
      CheckTrue(KeyerYCCC.KeyedRadio = @Radio1, 'YCCC switched to radio 1, swapped: radio 1');
{$ELSE}
      KeyersSwapped := False;
      YCCCSetActiveRadio(2);
      CheckTrue(KeyerYCCC.KeyedRadio = @Radio1,
                'no YCCC box off Windows: radio 1 whatever it was told');
{$ENDIF}
   finally
      YCCCSetActiveRadio(1);
      base.Free;
      fx.Free;
   end;
end;

(* ITEM 3, THE PIN: CW-by-CAT's routing is unchanged by the move onto
  KeyerOutputRadioPtr -- the text lands in the swapped radio's buffer, and only
  there. *)
procedure TCWKeyerTests.Test_CATRoutingFollowsTheSwap;
var
   fx: TTwoRadioFixture;
begin
   BeginTest('CW-by-CAT routes text to the active radio, or the inactive one when swapped');
   fx := TTwoRadioFixture.Create;
   try
      KeyersSwapped := False;
      KeyerCAT.SendString('ABC', 700);
      CheckEquals('ABC', Radio1.CWByCATBuffer, 'not swapped: radio 1 holds the text');
      CheckEquals('', Radio2.CWByCATBuffer, 'and radio 2 nothing');

      Radio1.CWByCATBuffer := '';
      KeyersSwapped := True;
      KeyerCAT.SendString('XYZ', 700);
      CheckEquals('XYZ', Radio2.CWByCATBuffer, 'swapped: radio 2 holds the text');
      CheckEquals('', Radio1.CWByCATBuffer, 'and radio 1 nothing');
   finally
      fx.Free;
   end;
end;

(* ITEM 4: SendStringAndStop with the keyers swapped sends its text AND its
  terminator to the same radio, so the message goes out.  It sent the
  terminator to ActiveRadioPtr, and the swapped radio's text waited for one
  that never came. *)
procedure TCWKeyerTests.Test_SendStringAndStopKeysOneRadio;
var
   fx: TTwoRadioFixture;
begin
   BeginTest('SendStringAndStop with the keyers swapped: text and terminator reach one radio');
   fx := TTwoRadioFixture.Create;
   try
      KeyersSwapped := True;
      SendStringAndStop('QRV');
      CheckTrue((Pos('BufferCW(QRV', fx.Rec2.Log) = 1) and (Pos('SendCW;', fx.Rec2.Log) > 0),
                'radio 2 -- the swapped radio -- got the text AND keyed it: ' + fx.Rec2.Log);
      CheckEquals('', Radio2.CWByCATBuffer, 'nothing is left waiting in its buffer');
      CheckEquals('', fx.Rec1.Log, 'and radio 1 was not touched');

      fx.Rec2.Log := '';
      KeyersSwapped := False;
      SendStringAndStop('QRU');
      CheckTrue((Pos('BufferCW(QRU', fx.Rec1.Log) = 1) and (Pos('SendCW;', fx.Rec1.Log) > 0),
                'not swapped: radio 1 keys it: ' + fx.Rec1.Log);
      CheckEquals('', fx.Rec2.Log, 'and radio 2 nothing');
   finally
      fx.Free;
   end;
end;

(* ITEM 2, THE CAT HALF: the active radio keys by CAT, the keyers are swapped
  onto radio 2, and radio 2's CAT keying is OFF -- so CWByCATSend sends
  nothing, and no key-up may be noted on either radio, even with radio 2 in
  test mode. *)
procedure TCWKeyerTests.Test_NoKeyUpIsNotedWhenCATKeysNothing;
var
   fx: TTwoRadioFixture;
begin
   BeginTest('a CW-by-CAT message that keys no radio notes no key-up');
   fx := TTwoRadioFixture.Create;
   try
      SetSettledTXState(@Radio2, False, True, 'TX test mode');
      Radio2.CWByCAT := False;
      KeyersSwapped := True;
      AddStringToBuffer('TEST', 700);
      CheckEquals('', fx.Rec2.Log, 'precondition: radio 2 was not keyed');
      CheckFalse(TXInhibitAlertOf(@Radio2).Showing, 'radio 2 is not warned');
      CheckFalse(TXInhibitAlertOf(@Radio2).ProgramKeyUp, 'no key-up noted on radio 2');
      CheckFalse(TXInhibitAlertOf(@Radio1).ProgramKeyUp, 'nor on radio 1');
   finally
      SetSettledTXState(@Radio2, False, False, '');
      fx.Free;
   end;
end;

(* ITEM 1: A FAULT IN THE TX-INHIBIT REVIEW NEVER REACHES A KEYING PATH.  With
  the review forced to raise, PTTOn still keys and PTTOff still unkeys, and
  AddStringToBuffer still sends -- each with an Error line, and nothing
  raised to the caller. *)
procedure TCWKeyerTests.Test_AFaultInTheReviewNeverReachesKeying;
var
   fx: TTwoRadioFixture;
   saved: TSavedKeyers;
   spyCAT, spyWK, spyYCCC, spyCPU: TSpyKeyer;
   capture: TCaptureAppender;
   keep: ILogAppender;
   savedLevel: TLogLevel;
   raised: string;

   function Faults: integer;
   var
      i: integer;
   begin
      Result := 0;
      for i := 0 to capture.Lines.Count - 1 do
         begin
         if Pos('keying carries on', capture.Lines[i]) > 0 then
            begin
            Inc(Result);
            end;
         end;
   end;

begin
   BeginTest('a fault in the TX-inhibit review: PTT still keys and unkeys, CW still goes');
   fx := TTwoRadioFixture.Create;
   capture := TCaptureAppender.Create('tx-inhibit-fault');
   keep := capture;
   savedLevel := logger.Level;
   logger.Level := Log4D.Warn;
   logger.AddAppender(keep);
   try
      (* PTT by CAT command on radio 1, the recording K4. *)
      Radio1.CWByCAT := False;
      Settings.Ptt.Enable := True;
      Settings.Ptt.ViaCommands := True;
      Settings.Ptt.NoPollDuring := False;
      Radio1.tPTTStatus := PTT_OFF;
      TXInhibitFaultInjection := True;

      raised := '';
      try
         PTTOn;
      except
         on E: Exception do
            begin
            raised := E.Message;
            end;
      end;
      CheckEquals('', raised, 'PTTOn must not raise a TX-inhibit fault');
      CheckEquals('Transmit;', fx.Rec1.Log, 'the radio was keyed');
      CheckTrue(Radio1.tPTTStatus = PTT_ON, 'and PTT is on');
      CheckEquals(1, Faults, 'the fault is logged at Error');

      raised := '';
      try
         PTTOff;
      except
         on E: Exception do
            begin
            raised := E.Message;
            end;
      end;
      CheckEquals('', raised, 'PTTOff must not raise a TX-inhibit fault');
      CheckEquals('Transmit;Receive;', fx.Rec1.Log, 'the radio was unkeyed');
      CheckTrue(Radio1.tPTTStatus = PTT_OFF, 'and PTT is off');
      CheckEquals(2, Faults, 'that fault is logged too');

      (* CW through the facade, on a spy keyer. *)
      Radio2.CWByCAT := False;
      saved := InstallSpies(spyCAT, spyWK, spyYCCC, spyCPU);
      try
         raised := '';
         try
            AddStringToBuffer('CQ', 700);
         except
            on E: Exception do
               begin
               raised := E.Message;
               end;
         end;
         CheckEquals('', raised, 'AddStringToBuffer must not raise a TX-inhibit fault');
         CheckEquals('CPU.SendString(CQ,700);', SpyLog, 'and the CW was still sent');
         CheckEquals(3, Faults, 'with the fault logged');
      finally
         RestoreKeyers(saved, spyCAT, spyWK, spyYCCC, spyCPU);
      end;
   finally
      TXInhibitFaultInjection := False;
      logger.RemoveAppender(keep);
      logger.Level := savedLevel;
      keep := nil;
      fx.Free;
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
   Test_AMessageOnAnInhibitedRadioWarnsAtOnce;
   Test_EachKeyerStatesTheRadioItKeys;
   Test_CATRoutingFollowsTheSwap;
   Test_SendStringAndStopKeysOneRadio;
   Test_NoKeyUpIsNotedWhenCATKeysNothing;
   Test_AFaultInTheReviewNeverReachesKeying;
end;

end.
